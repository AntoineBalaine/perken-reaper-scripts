//! A ReaScript API for debugging the plugin from a Lua script in REAPER.
//!
//! `VR09_Command(track, fxindex, command, arg)` returns a JSON string, so a
//! developer can read the plugin's state, and drive its settings, from a
//! terminal through a Lua bridge. The commands are `state`, `log`, `devices`,
//! `set`, `reconnect`, `load_registration` and `open_panel`. They run on
//! REAPER's main thread, read atomics and shared state, and never wait for the
//! audio thread.
//!
//! REAPER registers a ReaScript function with three entries of
//! `plugin_register`: `API_<name>` (the C function), `APIdef_<name>` (the
//! signature, as four NUL separated strings: return type, argument types,
//! argument names, help) and `APIvararg_<name>` (a wrapper that takes its
//! arguments as an array, which is what the scripting languages call).
const std = @import("std");
const Reaper = @import("reaper").reaper;
const clap = @import("clap.zig");
const c = clap.c;
const plugin = @import("plugin.zig");
const state = @import("state.zig");
const fileio = @import("fileio.zig");
const glue = @import("reaper_glue.zig");
const ui = @import("ui.zig");
const registrations = @import("registrations.zig");
const scenes = @import("scenes.zig");
const dump = @import("dump.zig");

const Plugin = plugin.Plugin;

// ---- the log's ring buffer ----

pub const log_lines = 256;
pub const log_line_cap = 200;

/// The last lines the plugin logged. Because the logging threads differ, a
/// mutex guards it; the critical sections copy a few hundred bytes.
pub const LogRing = struct {
    lines: [log_lines][log_line_cap]u8 = undefined,
    lens: [log_lines]u8 = [_]u8{0} ** log_lines,
    total: u64 = 0,
    mutex: std.Thread.Mutex = .{},

    pub fn push(self: *LogRing, text: []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const slot: usize = @intCast(self.total % log_lines);
        const n = @min(text.len, log_line_cap);
        @memcpy(self.lines[slot][0..n], text[0..n]);
        self.lens[slot] = @intCast(n);
        self.total += 1;
    }

    /// Writes the last `count` lines, oldest first, as a JSON array.
    pub fn writeLast(self: *LogRing, w: anytype, count: usize) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        const have: usize = @intCast(@min(self.total, log_lines));
        const n = @min(count, have);
        try w.writeByte('[');
        var i: usize = 0;
        while (i < n) : (i += 1) {
            const seq: usize = @intCast(self.total - n + i);
            const slot = seq % log_lines;
            if (i > 0) try w.writeByte(',');
            try jsonString(w, self.lines[slot][0..self.lens[slot]]);
        }
        try w.writeByte(']');
    }
};

pub var ring: LogRing = .{};

/// The logging function of the library (see `std_options` in `clap_entry.zig`):
/// the default one, and a copy of each line into the ring.
pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    var buf: [log_line_cap]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, "[{s}] ({s}): " ++ format, .{ @tagName(level), @tagName(scope) } ++ args) catch buf[0..];
    ring.push(text);
    std.log.defaultLog(level, scope, format, args);
}

// ---- JSON and argument helpers ----

pub fn jsonString(w: anytype, s: []const u8) !void {
    try std.json.encodeJsonString(s, .{}, w);
}

pub const Setting = enum { pass_midi, sysex_bare, autoconnect_done, split };

pub const SetArg = struct { setting: Setting, value: bool };

pub const ArgError = error{ BadSetting, BadValue, BadFileName };

fn parseBool(text: []const u8) ?bool {
    const yes = [_][]const u8{ "1", "true", "on", "yes" };
    const no = [_][]const u8{ "0", "false", "off", "no" };
    for (yes) |y| if (std.ascii.eqlIgnoreCase(text, y)) return true;
    for (no) |n| if (std.ascii.eqlIgnoreCase(text, n)) return false;
    return null;
}

/// Reads `name=value`.
pub fn parseSet(arg: []const u8) ArgError!SetArg {
    const eq = std.mem.indexOfScalar(u8, arg, '=') orelse return error.BadSetting;
    const name = std.mem.trim(u8, arg[0..eq], " ");
    const setting = std.meta.stringToEnum(Setting, name) orelse return error.BadSetting;
    const value = parseBool(std.mem.trim(u8, arg[eq + 1 ..], " ")) orelse return error.BadValue;
    return .{ .setting = setting, .value = value };
}

/// The number of log lines asked for; 50 when the argument is empty or bad.
pub fn parseCount(arg: []const u8) usize {
    const n = std.fmt.parseInt(usize, std.mem.trim(u8, arg, " "), 10) catch return 50;
    return std.math.clamp(n, 1, log_lines);
}

/// A file name of the registrations folder: no folder part, so that a script
/// cannot make the plugin read elsewhere.
pub fn checkFileName(name: []const u8) ArgError![]const u8 {
    if (name.len == 0 or std.mem.indexOfAny(u8, name, "/\\") != null or std.mem.indexOfScalar(u8, name, 0) != null) return error.BadFileName;
    if (std.mem.eql(u8, name, ".") or std.mem.eql(u8, name, "..")) return error.BadFileName;
    return name;
}

/// The device field of `I_MIDIHWOUT`, or null when the track has no output.
pub fn decodeMidiOut(raw: f64) ?u32 {
    if (raw < 0) return null;
    const bits: u32 = @intFromFloat(raw);
    return (bits >> 5) & 127;
}

pub const MidiIn = struct { is_midi: bool, all_devices: bool, device: ?u32, channel: u32 };

/// The fields of `I_RECINPUT` for a MIDI input.
pub fn decodeRecInput(raw: f64) MidiIn {
    if (raw < 0) return .{ .is_midi = false, .all_devices = false, .device = null, .channel = 0 };
    const bits: u32 = @intFromFloat(raw);
    if (bits & 4096 == 0) return .{ .is_midi = false, .all_devices = false, .device = null, .channel = 0 };
    const dev = (bits >> 5) & 127;
    return .{ .is_midi = true, .all_devices = dev == 63, .device = if (dev == 62 or dev == 63) null else dev, .channel = bits & 31 };
}

fn writeOptional(w: anytype, v: ?u32) !void {
    if (v) |n| try w.print("{d}", .{n}) else try w.writeAll("null");
}

fn writeError(w: anytype, message: []const u8) !void {
    try w.writeAll("{\"ok\":false,\"error\":");
    try jsonString(w, message);
    try w.writeByte('}');
}

// ---- finding the instance ----

fn contextFn(host: [*c]const c.clap_host_t) ?*const fn ([*c]const c.clap_host_t, c_int) callconv(.C) ?*anyopaque {
    const get_ext = host.*.get_extension orelse return null;
    const ptr = get_ext(host, "cockos.reaper_extension") orelse return null;
    const info: *Reaper.plugin_info_t = @constCast(@ptrCast(@alignCast(ptr)));
    const get_func = info.getFunc orelse return null;
    const f = get_func("clap_get_reaper_context") orelse return null;
    return @ptrCast(@alignCast(f));
}

/// The plugin's index in its track's FX chain, or null when REAPER does not
/// say. REAPER answers with the index plus one, cast to a pointer, so that
/// zero means unknown.
pub fn fxIndexOf(p: *Plugin) ?u32 {
    const f = contextFn(p.host) orelse return null;
    const v = @intFromPtr(f(p.host, @intFromEnum(glue.Context.fx_index)));
    if (v == 0) return null;
    return @intCast((v - 1) & 0xFFFFFF);
}

/// The instance for a track and an FX index: the one on that track at that
/// index, else the first on that track. A null track gives the first
/// instance. Null when the track holds none.
fn findInstance(track: ?*anyopaque, fx_index: c_int) ?*Plugin {
    var on_track: ?*Plugin = null;
    for (plugin.instances) |maybe| {
        const p = maybe orelse continue;
        if (track == null) return p;
        if (p.track == null) p.track = glue.trackOf(p.host);
        const mine: ?*anyopaque = @ptrCast(p.track);
        if (mine != track) continue;
        if (on_track == null) on_track = p;
        if (fx_index >= 0 and fxIndexOf(p) == @as(u32, @intCast(fx_index & 0xFFFFFF))) return p;
    }
    return on_track;
}

// ---- the commands ----

fn cmdState(w: anytype, p: *Plugin) !void {
    const s = p.shared;
    const st = &p.settings;
    const found = p.track != null;
    try w.print("{{\"ok\":true,\"track_found\":{},", .{found});
    if (found) {
        const out_raw = Reaper.GetMediaTrackInfo_Value(p.track, "I_MIDIHWOUT");
        const in_raw = Reaper.GetMediaTrackInfo_Value(p.track, "I_RECINPUT");
        const in = decodeRecInput(in_raw);
        try w.print("\"I_MIDIHWOUT\":{d},\"I_RECINPUT\":{d},\"midi_out_device\":", .{ out_raw, in_raw });
        try writeOptional(w, decodeMidiOut(out_raw));
        try w.writeAll(",\"midi_in_device\":");
        try writeOptional(w, in.device);
        try w.print(",\"midi_in_is_midi\":{},\"midi_in_all_devices\":{},\"midi_in_channel\":{d},", .{ in.is_midi, in.all_devices, in.channel });
        try w.print("\"armed\":{},\"monitoring\":{d},", .{ glue.trackArmed(p.track), glue.trackMonitoring(p.track) });
    }
    if (fxIndexOf(p)) |i| try w.print("\"fx_index\":{d},", .{i});
    try w.print("\"pass_midi\":{},\"split\":{},\"sysex_bare\":{},\"autoconnect_done\":{},", .{
        st.pass_midi.load(.monotonic),
        st.split.load(.monotonic),
        st.sysex_bare.load(.monotonic),
        st.autoconnect_done.load(.monotonic),
    });
    try w.print("\"loop_enabled\":{},\"loop_state\":\"{s}\",", .{ st.loop_enabled.load(.monotonic), loopStateName(p.loop_state.load(.monotonic)) });
    try w.print("\"midi_dropped\":{d},\"tx\":{d},\"rx\":{d},\"bad_checksum\":{d},", .{
        s.midi_dropped.load(.monotonic),
        s.tx_count.load(.monotonic),
        s.rx_count.load(.monotonic),
        s.bad_count.load(.monotonic),
    });
    try w.print("\"host_sysex_in\":{d},\"host_sysex_out\":{d},\"host_sysex_refused\":{d},", .{
        s.host_sysex_in.load(.monotonic),
        s.host_sysex_out.load(.monotonic),
        s.host_sysex_refused.load(.monotonic),
    });
    const mode: @import("roland.zig").MidiInMode = @enumFromInt(s.mode.load(.monotonic));
    try w.print("\"connected\":{},\"mode\":\"{s}\",\"known_bytes\":{d},\"blocks_failed\":{d},", .{
        s.connected.load(.monotonic),
        @tagName(mode),
        s.mirror_known.load(.monotonic),
        s.blocks_failed.load(.monotonic),
    });
    try w.writeAll("\"patch_name\":");
    try jsonString(w, st.presetName());
    try w.print(",\"scene\":{d},\"scenes\":{d}", .{ p.scene.load(.monotonic), p.scene_list.count });
    try w.print(",\"panel_open\":{},\"frames_drawn\":{d},\"ui_contexts\":{d},\"ui_ctx_valid\":{},\"ticks\":{d},", .{ p.ui.open, p.ui.frame, p.ui.contexts_created, ui.contextValid(p), p.ticks });
    try w.print("\"instances\":{d},\"devices_out\":{d},\"devices_in\":{d},\"device_names_out\":", .{ instanceCount(), glue.deviceCount(.output), glue.deviceCount(.input) });
    try writeDeviceNames(w, .output);
    try w.writeAll(",\"device_names_in\":");
    try writeDeviceNames(w, .input);
    try w.writeByte('}');
}

fn instanceCount() usize {
    var n: usize = 0;
    for (plugin.instances) |maybe| {
        if (maybe != null) n += 1;
    }
    return n;
}

fn loopStateName(value: u8) []const u8 {
    const audio = @import("audio.zig");
    const e = std.meta.intToEnum(audio.LoopState, value) catch return "unknown";
    return @tagName(e);
}

/// The names as REAPER reports them; null for a device that is absent.
fn writeDeviceNames(w: anytype, dir: glue.Direction) !void {
    try w.writeByte('[');
    var buf: [128]u8 = undefined;
    // The absent devices after the last present one are left out.
    var shown: usize = 0;
    for (0..glue.deviceCount(dir)) |i| {
        if (glue.deviceName(dir, i, &buf) != null) shown = i + 1;
    }
    for (0..shown) |i| {
        if (i > 0) try w.writeByte(',');
        if (glue.deviceName(dir, i, &buf)) |name| try jsonString(w, name) else try w.writeAll("null");
    }
    try w.writeByte(']');
}

fn cmdDevices(w: anytype) !void {
    try w.writeAll("{\"ok\":true,\"outputs\":");
    try writeDeviceNames(w, .output);
    try w.writeAll(",\"inputs\":");
    try writeDeviceNames(w, .input);
    try w.writeByte('}');
}

fn cmdSet(w: anytype, p: *Plugin, arg: []const u8) !void {
    const a = parseSet(arg) catch |err| return writeError(w, switch (err) {
        error.BadSetting => "set takes name=value with name pass_midi, sysex_bare, autoconnect_done or split",
        else => "the value must be 1, 0, true, false, on or off",
    });
    const st = &p.settings;
    switch (a.setting) {
        .pass_midi => st.pass_midi.store(a.value, .monotonic),
        .sysex_bare => st.sysex_bare.store(a.value, .monotonic),
        .autoconnect_done => st.autoconnect_done.store(a.value, .monotonic),
        .split => plugin.setPatchSplit(p, a.value),
    }
    try w.print("{{\"ok\":true,\"{s}\":{}}}", .{ @tagName(a.setting), a.value });
}

fn cmdReconnect(w: anytype, p: *Plugin) !void {
    // As the panel's button does.
    const queued = p.shared.sendCommand(.reconnect);
    p.settings.autoconnect_done.store(false, .monotonic);
    p.ticks = 0;
    try w.print("{{\"ok\":true,\"queued\":{}}}", .{queued});
}

fn cmdLoadRegistration(w: anytype, p: *Plugin, arg: []const u8) !void {
    const name = checkFileName(arg) catch return writeError(w, "load_registration takes a file name of Data/Perken/vr09/registrations");
    if (!glue.ready) return writeError(w, "REAPER's API is not available");
    const parsed = registrations.parseFileName(name) orelse return writeError(w, "the name must look like <bank>-<slot>_<Name>.json");
    var owned: [fileio.max_path]u8 = undefined;
    if (name.len > owned.len) return writeError(w, "the name is too long");
    @memcpy(owned[0..name.len], name);
    const file_name = owned[0..name.len];
    const entry = registrations.Entry{ .bank = parsed.bank, .slot = parsed.slot, .file_name = file_name, .name = file_name[file_name.len - registrations.extension.len - parsed.name.len .. file_name.len - registrations.extension.len] };
    p.loadRegistration(entry) catch |err| {
        try w.writeAll("{\"ok\":false,\"error\":");
        try jsonString(w, @errorName(err));
        try w.writeByte('}');
        return;
    };
    try w.writeAll("{\"ok\":true,\"loaded\":");
    try jsonString(w, name);
    try w.writeByte('}');
}

// ---- the session's scenes ----

fn writeSceneList(w: anytype, p: *Plugin) !void {
    try w.print("{{\"ok\":true,\"count\":{d},\"current\":{d},\"scenes\":[", .{ p.scene_list.count, p.scene.load(.monotonic) });
    var i: usize = 1;
    while (i <= p.scene_list.count) : (i += 1) {
        if (i > 1) try w.writeByte(',');
        const scene = p.scene_list.get(i).?;
        try w.print("{{\"position\":{d},\"patch_id\":{d},\"name\":", .{ i, scene.patch_id });
        try jsonString(w, scene.name());
        try w.writeAll(",\"label\":");
        try jsonString(w, scene.label());
        try w.writeByte('}');
    }
    try w.writeAll("]}");
}

/// The text before and after the first `|`; the second is empty without one.
const Pair = struct { head: []const u8, tail: []const u8 };

/// Up to four fields separated by `|`, trimmed; missing ones are empty.
fn splitFields(arg: []const u8) [4][]const u8 {
    var fields = [_][]const u8{ "", "", "", "" };
    var it = std.mem.splitScalar(u8, arg, '|');
    var i: usize = 0;
    while (it.next()) |field| : (i += 1) {
        if (i == fields.len) break;
        fields[i] = std.mem.trim(u8, field, " ");
    }
    return fields;
}

fn parsePatchId(text: []const u8) u16 {
    return std.fmt.parseInt(u16, text, 10) catch 0;
}

fn splitPair(arg: []const u8) Pair {
    const at = std.mem.indexOfScalar(u8, arg, '|') orelse return .{ .head = std.mem.trim(u8, arg, " "), .tail = "" };
    return .{ .head = std.mem.trim(u8, arg[0..at], " "), .tail = std.mem.trim(u8, arg[at + 1 ..], " ") };
}

/// `scene_add`: `<patch>|<name>|<patch id>|<label>`, the last three optional (the ID and label say which
/// patch of the library the scene came from, for the panel). The patch is `current` (the plugin's state now),
/// or `registrations/<file>` or `presets/<file>` of the Data/Perken/vr09 folder.
fn cmdSceneAdd(w: anytype, p: *Plugin, arg: []const u8) !void {
    const fields = splitFields(arg);
    const pair = Pair{ .head = fields[0], .tail = fields[1] };
    const patch = try plugin.allocator.create(dump.Dump);
    defer plugin.allocator.destroy(patch);
    patch.* = .{};
    var default_name: []const u8 = undefined;
    if (std.mem.eql(u8, pair.head, "current")) {
        p.shared.desiredSnapshot(patch);
        default_name = p.settings.presetName();
    } else {
        if (!glue.ready) return writeError(w, "REAPER's API is not available");
        const slash = std.mem.indexOfScalar(u8, pair.head, '/') orelse return writeError(w, "scene_add: use current, registrations/<file> or presets/<file>");
        const file = checkFileName(pair.head[slash + 1 ..]) catch return writeError(w, "scene_add: the file name must not have a folder part");
        var folder_buf: [fileio.max_path]u8 = undefined;
        const folder_result = if (std.mem.eql(u8, pair.head[0..slash], "registrations"))
            state.registrationFolder(&folder_buf, glue.resourcePath())
        else if (std.mem.eql(u8, pair.head[0..slash], "presets"))
            state.presetFolder(&folder_buf, glue.resourcePath())
        else
            return writeError(w, "scene_add: use current, registrations/<file> or presets/<file>");
        const folder = folder_result catch return writeError(w, "the folder is too long");
        var path_buf: [fileio.max_path]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "{s}{c}{s}", .{ folder, std.fs.path.sep, file }) catch return writeError(w, "the path is too long");
        state.loadPresetFile(plugin.allocator, path, patch) catch |err| return writeError(w, @errorName(err));
        default_name = state.displayName(file);
    }
    const name = if (pair.tail.len > 0) pair.tail else default_name;
    const position = p.scene_list.addFrom(name, patch, parsePatchId(fields[2]), fields[3]) catch return writeError(w, "the scene list is full");
    try w.print("{{\"ok\":true,\"position\":{d}}}", .{position});
}

/// `scene_add_tone`: "<part> <tone number> <bank MSB> <bank LSB>|<name>|<patch id>|<label>". The scene holds
/// only that tone.
fn cmdSceneAddTone(w: anytype, p: *Plugin, arg: []const u8) !void {
    const fields = splitFields(arg);
    const pair = Pair{ .head = fields[0], .tail = fields[1] };
    var words = std.mem.tokenizeScalar(u8, pair.head, ' ');
    const part = words.next() orelse return writeError(w, "scene_add_tone takes <part> <number> <msb> <lsb>|<name>");
    var numbers: [3]u8 = undefined;
    for (&numbers) |*n| {
        const word = words.next() orelse return writeError(w, "scene_add_tone takes <part> <number> <msb> <lsb>|<name>");
        n.* = std.fmt.parseInt(u8, word, 10) catch return writeError(w, "the tone numbers must be from 0 to 127");
    }
    const patch = try plugin.allocator.create(dump.Dump);
    defer plugin.allocator.destroy(patch);
    patch.* = .{};
    if (!scenes.toneDump(patch, part, numbers[0], numbers[1], numbers[2])) {
        return writeError(w, "the part must be upper_piano, upper_piano_dual2, lower_piano, upper_synth, upper_synth_dual2 or lower_synth");
    }
    const name = if (pair.tail.len > 0) pair.tail else part;
    const position = p.scene_list.addFrom(name, patch, parsePatchId(fields[2]), fields[3]) catch return writeError(w, "the scene list is full");
    try w.print("{{\"ok\":true,\"position\":{d}}}", .{position});
}

/// `load_tone`: "<part> <tone number> <bank MSB> <bank LSB>". Writes that tone to the keyboard, as selecting a
/// tone scene does, without adding a scene.
fn cmdLoadTone(w: anytype, p: *Plugin, arg: []const u8) !void {
    const fields = splitFields(arg);
    var words = std.mem.tokenizeScalar(u8, fields[0], ' ');
    const part = words.next() orelse return writeError(w, "load_tone takes <part> <number> <msb> <lsb>");
    var numbers: [3]u8 = undefined;
    for (&numbers) |*n| {
        const word = words.next() orelse return writeError(w, "load_tone takes <part> <number> <msb> <lsb>");
        n.* = std.fmt.parseInt(u8, word, 10) catch return writeError(w, "the tone numbers must be from 0 to 127");
    }
    const patch = try plugin.allocator.create(dump.Dump);
    defer plugin.allocator.destroy(patch);
    patch.* = .{};
    if (!scenes.toneDump(patch, part, numbers[0], numbers[1], numbers[2])) {
        return writeError(w, "the part must be upper_piano, upper_piano_dual2, lower_piano, upper_synth, upper_synth_dual2 or lower_synth");
    }
    p.loadScene(patch, if (fields[1].len > 0) fields[1] else part);
    try w.writeAll("{\"ok\":true}");
}

fn writeMapping(w: anytype, count: usize, map: *const scenes.Mapping) !void {
    try w.writeAll(",\"map\":[");
    for (map[0..count], 0..) |m, i| {
        if (i > 0) try w.writeByte(',');
        try w.print("{d}", .{m});
    }
    try w.writeByte(']');
}

fn cmdSceneRemove(w: anytype, p: *Plugin, arg: []const u8) !void {
    const position = std.fmt.parseInt(u8, std.mem.trim(u8, arg, " "), 10) catch return writeError(w, "scene_remove takes a position");
    const count = p.scene_list.count;
    var map: scenes.Mapping = undefined;
    if (!p.removeScene(position, &map)) return writeError(w, "there is no scene at that position");
    try w.writeAll("{\"ok\":true");
    try writeMapping(w, count, &map);
    try w.writeByte('}');
}

/// `scene_move`: "<from>,<to>".
fn cmdSceneMove(w: anytype, p: *Plugin, arg: []const u8) !void {
    const comma = std.mem.indexOfScalar(u8, arg, ',') orelse return writeError(w, "scene_move takes <from>,<to>");
    const from = std.fmt.parseInt(u8, std.mem.trim(u8, arg[0..comma], " "), 10) catch return writeError(w, "scene_move takes <from>,<to>");
    const to = std.fmt.parseInt(u8, std.mem.trim(u8, arg[comma + 1 ..], " "), 10) catch return writeError(w, "scene_move takes <from>,<to>");
    const count = p.scene_list.count;
    var map: scenes.Mapping = undefined;
    if (!p.moveScene(from, to, &map)) return writeError(w, "both positions must hold a scene");
    try w.writeAll("{\"ok\":true");
    try writeMapping(w, count, &map);
    try w.writeByte('}');
}

/// `scene_rename`: "<position>|<name>".
fn cmdSceneRename(w: anytype, p: *Plugin, arg: []const u8) !void {
    const pair = splitPair(arg);
    const position = std.fmt.parseInt(u8, pair.head, 10) catch return writeError(w, "scene_rename takes <position>|<name>");
    if (!p.scene_list.rename(position, pair.tail)) return writeError(w, "there is no scene at that position");
    try w.writeAll("{\"ok\":true}");
}

/// `scene_select`: loads a scene, as the Scene parameter does.
fn cmdSceneSelect(w: anytype, p: *Plugin, arg: []const u8) !void {
    const position = std.fmt.parseInt(u8, std.mem.trim(u8, arg, " "), 10) catch return writeError(w, "scene_select takes a position");
    p.selectScene(position) catch return writeError(w, "there is no scene at that position");
    try w.print("{{\"ok\":true,\"scene\":{d}}}", .{position});
}

fn cmdSceneClear(w: anytype, p: *Plugin) !void {
    p.scene_list.clear();
    p.scene.store(0, .monotonic);
    p.rescanParamValues();
    try w.writeAll("{\"ok\":true}");
}

fn cmdOpenPanel(w: anytype, p: *Plugin) !void {
    ui.open(p);
    try w.print("{{\"ok\":true,\"panel_open\":{}}}", .{p.ui.open});
}

/// Reads every block of the keyboard into the plugin's state, as the panel's
/// "Read the keyboard" button does. `job` and `progress` tell when it is done.
fn cmdCapture(w: anytype, p: *Plugin) !void {
    const queued = p.shared.sendCommand(.capture_keyboard);
    try w.print("{{\"ok\":true,\"queued\":{}}}", .{queued});
}

fn cmdJob(w: anytype, p: *Plugin) !void {
    const s = p.shared;
    const job: @import("engine.zig").JobKind = @enumFromInt(s.job.load(.monotonic));
    try w.print("{{\"ok\":true,\"job\":\"{s}\",\"done\":{d},\"total\":{d}}}", .{ @tagName(job), s.progress_done.load(.monotonic), s.progress_total.load(.monotonic) });
}

/// Writes the plugin's state to an absolute path, in the JSON of vr09.py, so
/// that the research repo's `vr09.py diff` can compare two of them.
fn cmdExport(w: anytype, p: *Plugin, arg: []const u8) !void {
    if (arg.len == 0 or !std.fs.path.isAbsolute(arg)) return writeError(w, "export: give an absolute path");
    const scene = try plugin.allocator.create(@import("dump.zig").Dump);
    defer plugin.allocator.destroy(scene);
    p.shared.desiredSnapshot(scene);
    state.savePresetFile(plugin.allocator, arg, scene) catch |err| return writeError(w, @errorName(err));
    try w.writeAll("{\"ok\":true}");
}

fn cmdTab(w: anytype, p: *Plugin, arg: []const u8) !void {
    if (!ui.selectTab(p, arg)) return writeError(w, "tab: use controls, patches, audio or midi");
    try w.writeAll("{\"ok\":true}");
}

fn cmdLog(w: anytype, arg: []const u8) !void {
    try w.print("{{\"ok\":true,\"total\":{d},\"lines\":", .{ring.total});
    try ring.writeLast(w, parseCount(arg));
    try w.writeByte('}');
}

/// Runs a command and writes its JSON.
pub fn dispatch(w: anytype, track: ?*anyopaque, fx_index: c_int, command: []const u8, arg: []const u8) !void {
    if (std.mem.eql(u8, command, "devices")) return cmdDevices(w);
    if (std.mem.eql(u8, command, "log")) return cmdLog(w, arg);
    const known = [_][]const u8{ "state", "set", "reconnect", "load_registration", "open_panel", "tab", "capture", "job", "export", "load_tone", "scenes", "scene_add", "scene_add_tone", "scene_remove", "scene_move", "scene_rename", "scene_select", "scene_clear" };
    for (known) |k| {
        if (std.mem.eql(u8, command, k)) break;
    } else {
        try writeError(w, "unknown command: use state, log, devices, set, reconnect, load_registration, open_panel, tab, capture, job, export, load_tone, scenes, scene_add, scene_add_tone, scene_remove, scene_move, scene_rename, scene_select or scene_clear");
        return;
    }
    const p = findInstance(track, fx_index) orelse return writeError(w, "no VR-09 instance on that track");
    if (std.mem.eql(u8, command, "state")) return cmdState(w, p);
    if (std.mem.eql(u8, command, "set")) return cmdSet(w, p, arg);
    if (std.mem.eql(u8, command, "reconnect")) return cmdReconnect(w, p);
    if (std.mem.eql(u8, command, "load_registration")) return cmdLoadRegistration(w, p, arg);
    if (std.mem.eql(u8, command, "tab")) return cmdTab(w, p, arg);
    if (std.mem.eql(u8, command, "capture")) return cmdCapture(w, p);
    if (std.mem.eql(u8, command, "job")) return cmdJob(w, p);
    if (std.mem.eql(u8, command, "export")) return cmdExport(w, p, arg);
    if (std.mem.eql(u8, command, "load_tone")) return cmdLoadTone(w, p, arg);
    if (std.mem.eql(u8, command, "scenes")) return writeSceneList(w, p);
    if (std.mem.eql(u8, command, "scene_add")) return cmdSceneAdd(w, p, arg);
    if (std.mem.eql(u8, command, "scene_add_tone")) return cmdSceneAddTone(w, p, arg);
    if (std.mem.eql(u8, command, "scene_remove")) return cmdSceneRemove(w, p, arg);
    if (std.mem.eql(u8, command, "scene_move")) return cmdSceneMove(w, p, arg);
    if (std.mem.eql(u8, command, "scene_rename")) return cmdSceneRename(w, p, arg);
    if (std.mem.eql(u8, command, "scene_select")) return cmdSceneSelect(w, p, arg);
    if (std.mem.eql(u8, command, "scene_clear")) return cmdSceneClear(w, p);
    return cmdOpenPanel(w, p);
}

// ---- the registration with REAPER ----

/// The reply's buffer. ReaScript copies the string on return, and only the
/// main thread calls.
var out: [128 * 1024]u8 = undefined;

fn cstr(p: ?[*:0]const u8) []const u8 {
    return if (p) |s| std.mem.span(s) else "";
}

/// The C function: `const char* VR09_Command(MediaTrack*, int, const char*, const char*)`.
fn apiCommand(track: ?*anyopaque, fx_index: c_int, command: ?[*:0]const u8, arg: ?[*:0]const u8) callconv(.C) [*:0]const u8 {
    var fbs = std.io.fixedBufferStream(out[0 .. out.len - 1]);
    dispatch(fbs.writer(), track, fx_index, cstr(command), cstr(arg)) catch {
        fbs.reset();
        writeError(fbs.writer(), "the reply is too long") catch {};
    };
    out[fbs.pos] = 0;
    return @ptrCast(&out);
}

/// The wrapper the scripting languages call, with the arguments in an array.
fn apiVararg(args: [*c]?*anyopaque, count: c_int) callconv(.C) ?*anyopaque {
    const n: usize = if (count < 0) 0 else @intCast(count);
    const track = if (n > 0) args[0] else null;
    const fx: c_int = if (n > 1) @intCast(@as(isize, @bitCast(@intFromPtr(args[1])))) else 0;
    const command: ?[*:0]const u8 = if (n > 2) @ptrCast(args[2]) else null;
    const arg: ?[*:0]const u8 = if (n > 3) @ptrCast(args[3]) else null;
    return @constCast(@ptrCast(apiCommand(track, fx, command, arg)));
}

const api_def: [:0]const u8 = "const char*\x00MediaTrack*,int,const char*,const char*\x00track,fxindex,command,arg\x00" ++
    "Debugging the VR-09 plugin. command is state, log (arg: line count), devices, set (arg: name=value), " ++
    "reconnect, load_registration (arg: file name) or open_panel; the reply is JSON. " ++
    "A null track chooses the first instance.";

var registered = false;

/// Registers the function, once. Called when the first instance loads.
pub fn register() void {
    if (registered or !glue.ready) return;
    registered = true;
    _ = Reaper.plugin_register("API_VR09_Command", @constCast(@ptrCast(&apiCommand)));
    _ = Reaper.plugin_register("APIdef_VR09_Command", @constCast(@ptrCast(api_def.ptr)));
    _ = Reaper.plugin_register("APIvararg_VR09_Command", @constCast(@ptrCast(&apiVararg)));
}

pub fn unregister() void {
    if (!registered) return;
    registered = false;
    _ = Reaper.plugin_register("-API_VR09_Command", @constCast(@ptrCast(&apiCommand)));
    _ = Reaper.plugin_register("-APIdef_VR09_Command", @constCast(@ptrCast(api_def.ptr)));
    _ = Reaper.plugin_register("-APIvararg_VR09_Command", @constCast(@ptrCast(&apiVararg)));
}

// ---- tests ----

test "set arguments are parsed" {
    const a = try parseSet("pass_midi=1");
    try std.testing.expectEqual(Setting.pass_midi, a.setting);
    try std.testing.expect(a.value);
    try std.testing.expect(!(try parseSet(" sysex_bare = Off ")).value);
    try std.testing.expectEqual(Setting.autoconnect_done, (try parseSet("autoconnect_done=true")).setting);
    try std.testing.expectError(error.BadSetting, parseSet("pass_midi"));
    try std.testing.expectError(error.BadSetting, parseSet("volume=1"));
    try std.testing.expectError(error.BadValue, parseSet("pass_midi=maybe"));
}

test "the log count is clamped" {
    try std.testing.expectEqual(@as(usize, 50), parseCount(""));
    try std.testing.expectEqual(@as(usize, 10), parseCount("10"));
    try std.testing.expectEqual(@as(usize, log_lines), parseCount("100000"));
    try std.testing.expectEqual(@as(usize, 1), parseCount("0"));
}

test "a registration file name has no folder part" {
    _ = try checkFileName("1-1_Piano.json");
    try std.testing.expectError(error.BadFileName, checkFileName("../x.json"));
    try std.testing.expectError(error.BadFileName, checkFileName("a/b.json"));
    try std.testing.expectError(error.BadFileName, checkFileName(".."));
    try std.testing.expectError(error.BadFileName, checkFileName(""));
}

test "the track's routing fields are decoded" {
    try std.testing.expectEqual(@as(?u32, null), decodeMidiOut(-1));
    try std.testing.expectEqual(@as(?u32, 3), decodeMidiOut(@floatFromInt(3 << 5 | 2)));
    const i = decodeRecInput(@floatFromInt(4096 | (5 << 5) | 1));
    try std.testing.expect(i.is_midi);
    try std.testing.expectEqual(@as(?u32, 5), i.device);
    try std.testing.expectEqual(@as(u32, 1), i.channel);
    const all = decodeRecInput(@floatFromInt(4096 | (63 << 5)));
    try std.testing.expect(all.all_devices);
    try std.testing.expectEqual(@as(?u32, null), all.device);
    try std.testing.expect(!decodeRecInput(2).is_midi);
}

test "strings are escaped in the JSON" {
    var buf: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try jsonString(fbs.writer(), "a\"b\\c\n");
    try std.testing.expectEqualStrings("\"a\\\"b\\\\c\\n\"", fbs.getWritten());
}

test "the log ring keeps the last lines in order" {
    var r = LogRing{};
    for (0..log_lines + 5) |i| {
        var b: [16]u8 = undefined;
        r.push(std.fmt.bufPrint(&b, "line {d}", .{i}) catch unreachable);
    }
    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try r.writeLast(fbs.writer(), 2);
    try std.testing.expectEqualStrings("[\"line 259\",\"line 260\"]", fbs.getWritten());
}

test "an unknown command gives a JSON error" {
    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try dispatch(fbs.writer(), null, 0, "nonsense", "");
    try std.testing.expect(std.mem.startsWith(u8, fbs.getWritten(), "{\"ok\":false,\"error\":\"unknown command"));
}

test "the log command wraps the lines" {
    ring.push("hello");
    var buf: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try dispatch(fbs.writer(), null, 0, "log", "1");
    try std.testing.expect(std.mem.indexOf(u8, fbs.getWritten(), "\"lines\":[\"hello\"]") != null);
}
