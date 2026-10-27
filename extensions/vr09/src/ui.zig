//! The plugin's window, drawn with ReaImGui from REAPER's timer.
//!
//! The host asks the plugin to show its interface through the CLAP gui
//! extension. Because a ReaImGui window is its own window, not a view inside
//! the host's, the host's embedded view stays a small placeholder and this
//! window opens beside it. It is drawn about thirty times a second from the
//! timer, and it only talks to the audio thread through `engine.Shared`.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const imgui = @import("reaper_imgui");
const palette = @import("ui_palette");
const plugin = @import("plugin.zig");
const engine = @import("engine.zig");
const catalog = @import("catalog.zig");
const dump = @import("dump.zig");
const state = @import("state.zig");
const placement = @import("placement.zig");
const glue = @import("reaper_glue.zig");
const fileio = @import("fileio.zig");
const audio = @import("audio.zig");
const roland = @import("roland.zig");
const registrations = @import("registrations.zig");
const panel_fonts = @import("fonts.zig");
const theme = @import("theme.zig");

const Plugin = plugin.Plugin;
const log = std.log.scoped(.ui);

const name_cap = 64;
const max_devices = 256;
const device_name_cap = 96;

const ImguiState = enum { unchecked, present, missing };
var imgui_state: ImguiState = .unchecked;

const green = palette.rgba(0x13BD99FF);
const amber = palette.rgba(0xE0A030FF);
const red = palette.rgba(0xE05050FF);
const grey = palette.rgba(0x818989FF);

/// A device name in a fixed buffer, so that the list can be drawn without
/// allocating.
const DeviceName = [device_name_cap:0]u8;

/// The panel's size when it first opens.
const window_width = 640;
const window_height = 560;

/// The part of the plugin that belongs to its window.
pub const Window = struct {
    open: bool = false,
    ctx: imgui.ContextPtr = null,
    fonts: panel_fonts.Fonts = .{},
    frame: u32 = 0,
    errors_logged: u32 = 0,
    /// How many ImGui contexts this window has created, to tell a reopened
    /// window from one that kept its context.
    contexts_created: u32 = 0,
    // The input probe (see `probeInput`).
    probe_lines: u32 = 0,
    probe_last: i64 = 0,

    // The preset list.
    preset_names: ?std.ArrayList([]u8) = null,
    preset_refresh_at: u32 = 0,
    // The window is placed at the mouse once per opening. ImGui's "appearing"
    // condition also fires when the window's OS window is recreated, which
    // made the window jump to the mouse on a click.
    placed: bool = false,
    // A tab to bring to the front on the next frame (0 for none, else the
    // tab's number from 1), so that a script can drive the panel.
    select_tab: u8 = 0,
    preset_selected: i32 = -1,
    preset_filter: [name_cap:0]u8 = [_:0]u8{0} ** name_cap,
    save_name: [name_cap:0]u8 = [_:0]u8{0} ** name_cap,
    export_path: [fileio.max_path:0]u8 = [_:0]u8{0} ** fileio.max_path,
    delete_armed: i32 = -1,

    // The keyboard's Registrations library.
    reg_library: ?registrations.Library = null,
    reg_selected: i32 = -1,
    reg_filter: [name_cap:0]u8 = [_:0]u8{0} ** name_cap,

    // The devices, refreshed a few times a second.
    device_refresh_at: u32 = 0,
    output_names: [max_devices]DeviceName = [_]DeviceName{[_:0]u8{0} ** device_name_cap} ** max_devices,
    output_present: [max_devices]bool = [_]bool{false} ** max_devices,
    input_names: [max_devices]DeviceName = [_]DeviceName{[_:0]u8{0} ** device_name_cap} ** max_devices,
    input_present: [max_devices]bool = [_]bool{false} ** max_devices,

    // The last notice to the user.
    notice: [160:0]u8 = [_:0]u8{0} ** 160,
    notice_until: u32 = 0,
    notice_is_error: bool = false,
};

pub fn open(p: *Plugin) void {
    ensureImgui();
    if (imgui_state == .missing) {
        if (glue.ready) Reaper.ShowConsoleMsg("VR-09: the panel needs ReaImGui (install it with ReaPack).\n");
        return;
    }
    log.info("opening the panel", .{});
    p.ui.open = true;
    p.ui.placed = false;
    p.ui.probe_lines = 0;
    p.ui.probe_last = 0;
    p.ui.preset_refresh_at = 0;
    p.ui.device_refresh_at = 0;
}

/// Whether the window's ImGui context still exists in ReaImGui.
pub fn contextValid(p: *Plugin) bool {
    if (imgui_state != .present or p.ui.ctx == null) return false;
    return imgui.api.ValidatePtr(@ptrCast(p.ui.ctx), "ImGui_Context*");
}

/// Brings a tab to the front: "controls", "patches", "audio" or "midi".
pub fn selectTab(p: *Plugin, name: []const u8) bool {
    const names = [_][]const u8{ "controls", "patches", "audio", "midi" };
    for (names, 1..) |n, i| {
        if (std.mem.eql(u8, n, name)) {
            p.ui.select_tab = @intCast(i);
            return true;
        }
    }
    return false;
}

pub fn close(p: *Plugin) void {
    p.ui.open = false;
    // The pointers are dropped, and ReaImGui destroys the context by itself
    // once it has gone unused for a few frames.
    p.ui.ctx = null;
    p.ui.fonts = .{};
    freePresets(&p.ui);
    freeRegistrations(&p.ui);
}

pub fn shutdown() void {}

fn ensureImgui() void {
    if (imgui_state != .unchecked) return;
    if (!glue.ready) {
        imgui_state = .missing;
        return;
    }
    imgui.init(Reaper.plugin_getapi) catch {
        imgui_state = .missing;
        log.warn("ReaImGui is not available", .{});
        return;
    };
    imgui_state = .present;
}

/// Draws every open window. REAPER's timer calls it.
pub fn drawAll() void {
    if (imgui_state != .present) return;
    for (plugin.instances) |maybe| {
        const p = maybe orelse continue;
        if (!p.ui.open) continue;
        draw(p);
    }
}

fn notice(w: *Window, comptime fmt: []const u8, args: anytype, is_error: bool) void {
    _ = std.fmt.bufPrintZ(&w.notice, fmt, args) catch {
        w.notice[0] = 0;
    };
    w.notice_until = w.frame + 240;
    w.notice_is_error = is_error;
}

fn freePresets(w: *Window) void {
    if (w.preset_names) |*list| {
        fileio.freeList(plugin.allocator, list);
        w.preset_names = null;
    }
}

fn freeRegistrations(w: *Window) void {
    if (w.reg_library) |*lib| {
        lib.deinit(plugin.allocator);
        w.reg_library = null;
    }
    w.reg_selected = -1;
}

fn refreshRegistrations(w: *Window) void {
    freeRegistrations(w);
    if (!glue.ready) return;
    var buf: [fileio.max_path]u8 = undefined;
    const folder = state.registrationFolder(&buf, glue.resourcePath()) catch return;
    w.reg_library = registrations.scan(plugin.allocator, folder) catch null;
}

fn presetFolder(buf: []u8) ?[]const u8 {
    if (!glue.ready) return null;
    return state.presetFolder(buf, glue.resourcePath()) catch null;
}

fn refreshPresets(w: *Window) void {
    freePresets(w);
    var buf: [fileio.max_path]u8 = undefined;
    const folder = presetFolder(&buf) orelse return;
    const list = fileio.listFiles(plugin.allocator, folder, &state.preset_extensions) catch return;
    std.mem.sort([]u8, list.items, {}, lessName);
    w.preset_names = list;
}

fn lessName(_: void, a: []u8, b: []u8) bool {
    return std.ascii.lessThanIgnoreCase(a, b);
}

fn refreshDevices(w: *Window) void {
    refreshDirection(w, .output);
    refreshDirection(w, .input);
}

fn refreshDirection(w: *Window, dir: glue.Direction) void {
    const names = if (dir == .output) &w.output_names else &w.input_names;
    const present = if (dir == .output) &w.output_present else &w.input_present;
    const count = glue.deviceCount(dir);
    for (0..max_devices) |i| {
        present[i] = false;
        if (i >= count) continue;
        var buf: [device_name_cap]u8 = undefined;
        // Because REAPER reports the ports of a JACK setup as absent while
        // they are unconnected, an absent device is listed too, by its number.
        var fallback: [32]u8 = undefined;
        const name = glue.deviceName(dir, i, &buf) orelse
            (std.fmt.bufPrint(&fallback, "device {d} (not present)", .{i}) catch continue);
        const len = @min(name.len, device_name_cap - 1);
        @memcpy(names[i][0..len], name[0..len]);
        names[i][len] = 0;
        present[i] = true;
    }
}

// ---- the window ----

fn draw(p: *Plugin) void {
    const w = &p.ui;
    w.frame +%= 1;
    // ReaImGui destroys a context after a failed assertion, or when a frame
    // goes by without it. Drawing with the stale pointer leaves a frozen
    // window, so a destroyed context is replaced.
    if (w.ctx != null and !imgui.api.ValidatePtr(@ptrCast(w.ctx), "ImGui_Context*")) {
        log.warn("the ImGui context was destroyed; creating a new one", .{});
        w.placed = false;
        w.ctx = null;
        w.fonts = .{};
    }
    if (w.ctx == null) {
        var config: c_int = 0;
        var title_buf: [48:0]u8 = undefined;
        // The name is unique to each context: two contexts of the same name
        // may share a native window, and the end of the old one would take
        // the new one's window with it.
        const title = std.fmt.bufPrintZ(&title_buf, "VR-09 {x}-{d}", .{ @intFromPtr(p), w.contexts_created + 1 }) catch "VR-09";
        w.ctx = imgui.api.CreateContext(title, &config);
        if (w.ctx == null) {
            w.open = false;
            return;
        }
        w.contexts_created += 1;
        log.info("ImGui context {d} created at frame {d}", .{ w.contexts_created, w.frame });
        w.fonts = panel_fonts.create(w.ctx);
    }
    const ctx = w.ctx;
    if (w.frame == 1) log.info("drawing the first frame", .{});
    if (w.frame >= w.preset_refresh_at) {
        refreshPresets(w);
        refreshRegistrations(w);
        w.preset_refresh_at = w.frame +% 150;
    }
    if (w.frame >= w.device_refresh_at) {
        if (glue.ready) refreshDevices(w);
        w.device_refresh_at = w.frame +% 30;
    }

    if (w.fonts.text != null) imgui.api.PushFont(ctx, w.fonts.text);
    theme.push(ctx);
    const mouse = glue.mousePosition();
    if (!w.placed) {
        w.placed = true;
        // The window opens where it fits on the screen: a window that sticks
        // out is moved by the window manager without ImGui being told, and
        // the mouse then lands a few dozen pixels off.
        var at = placement.Point{ .x = mouse.x, .y = mouse.y };
        if (glue.workAreaAt(mouse.x, mouse.y)) |area| {
            at = placement.fitInto(area, mouse.x, mouse.y, window_width, window_height);
            if (at.x != mouse.x or at.y != mouse.y) log.info("the panel opens at {d},{d} instead of {d},{d}, to fit the screen ({d},{d} to {d},{d})", .{ at.x, at.y, mouse.x, mouse.y, area.left, area.top, area.right, area.bottom });
        }
        imgui.api.SetNextWindowPos(ctx, @floatFromInt(at.x), @floatFromInt(at.y), &imgui.Cond_Always, null, null);
    }
    imgui.api.SetNextWindowSize(ctx, window_width, window_height, &imgui.Cond_FirstUseEver);
    var is_open: bool = true;
    var flags: c_int = imgui.WindowFlags_NoSavedSettings | imgui.WindowFlags_NoCollapse;
    var title: [80:0]u8 = undefined;
    const track_number: u32 = if (p.track != null) @intFromFloat(Reaper.GetMediaTrackInfo_Value(p.track, "IP_TRACKNUMBER")) else 0;
    const label = if (track_number > 0)
        std.fmt.bufPrintZ(&title, "VR-09, track {d}##{x}-{d}", .{ track_number, @intFromPtr(p), w.contexts_created }) catch "VR-09"
    else
        std.fmt.bufPrintZ(&title, "VR-09##{x}-{d}", .{ @intFromPtr(p), w.contexts_created }) catch "VR-09";
    if (imgui.api.Begin(ctx, label, &is_open, &flags)) {
        drawContent(p, ctx);
        probeInput(w, ctx);
    }
    imgui.api.End(ctx);
    theme.pop(ctx);
    if (w.fonts.text != null) imgui.api.PopFont(ctx);
    if (!is_open) {
        log.info("ImGui reported the panel closed (frame {d}, context {d})", .{ w.frame, w.contexts_created });
        close(p);
    }
    reportImguiError(w);
}

fn quantize(v: f64) i64 {
    return @intFromFloat(std.math.clamp(@round(v), -100000, 100000));
}

/// The panel can come up deaf to the mouse. Each time what ImGui sees of the
/// mouse changes, a line (at most 40 per opening) puts it beside where REAPER
/// says the mouse is, so that a frozen panel shows whether ImGui sees the
/// mouse in the wrong place, never hovered, or never focused.
fn probeInput(w: *Window, ctx: imgui.ContextPtr) void {
    if (w.probe_lines >= 40) return;
    var mx: f64 = 0;
    var my: f64 = 0;
    imgui.api.GetMousePos(ctx, &mx, &my);
    var wx: f64 = 0;
    var wy: f64 = 0;
    imgui.api.GetWindowPos(ctx, &wx, &wy);
    var ww: f64 = 0;
    var wh: f64 = 0;
    imgui.api.GetWindowSize(ctx, &ww, &wh);
    // Child windows count: the panel's lists are children.
    var hover_flags: c_int = imgui.HoveredFlags_ChildWindows;
    var focus_flags: c_int = imgui.FocusedFlags_ChildWindows;
    const hovered = imgui.api.IsWindowHovered(ctx, &hover_flags);
    const focused = imgui.api.IsWindowFocused(ctx, &focus_flags);
    const down = imgui.api.IsMouseDown(ctx, 0);
    const key = ((quantize(mx) *% 1_000_003 +% quantize(my)) *% 8 +% @as(i64, @intFromBool(hovered)) *% 4 +% @as(i64, @intFromBool(focused)) *% 2 +% @as(i64, @intFromBool(down)));
    if (key == w.probe_last) return;
    w.probe_last = key;
    w.probe_lines += 1;
    const os = glue.mousePosition();
    log.info("input (context {d}, frame {d}): ImGui mouse {d:.0},{d:.0} down {} | window at {d:.0},{d:.0} size {d:.0}x{d:.0} hovered {} focused {} | REAPER mouse {d},{d}", .{ w.contexts_created, w.frame, mx, my, down, wx, wy, ww, wh, hovered, focused, os.x, os.y });
}

/// ReaImGui records an error instead of raising it when a call is misused, so
/// the first few are written to the log.
fn reportImguiError(w: *Window) void {
    checkpoint(w, "end of frame");
}

/// Because ReaImGui keeps only the error of the last call, and a failed
/// assertion destroys the context so that every later call fails too, the
/// sections of the window check it as they go, to name the one that broke.
fn checkpoint(w: *Window, section: []const u8) void {
    const get_error = imgui.getError orelse return;
    const message = get_error() orelse return;
    if (w.errors_logged < 5) {
        w.errors_logged += 1;
        log.warn("ReaImGui reported after {s}: {s}", .{ section, std.mem.span(message) });
    }
}

fn drawContent(p: *Plugin, ctx: imgui.ContextPtr) void {
    drawHeader(p, ctx);
    imgui.api.Separator(ctx);
    if (imgui.api.BeginTabBar(ctx, "##tabs", null)) {
        const select = p.ui.select_tab;
        p.ui.select_tab = 0;
        var flags = [4]c_int{ 0, 0, 0, 0 };
        if (select >= 1 and select <= flags.len) flags[select - 1] = imgui.TabItemFlags_SetSelected;
        if (imgui.api.BeginTabItem(ctx, "Controls", null, &flags[0])) {
            drawControls(p, ctx);
            imgui.api.EndTabItem(ctx);
        }
        if (imgui.api.BeginTabItem(ctx, "Patches", null, &flags[1])) {
            drawPatches(p, ctx);
            imgui.api.EndTabItem(ctx);
        }
        if (imgui.api.BeginTabItem(ctx, "Audio loop", null, &flags[2])) {
            drawAudioLoop(p, ctx);
            imgui.api.EndTabItem(ctx);
        }
        if (imgui.api.BeginTabItem(ctx, "MIDI", null, &flags[3])) {
            drawMidi(p, ctx);
            imgui.api.EndTabItem(ctx);
        }
        imgui.api.EndTabBar(ctx);
    }
    if (p.ui.frame < p.ui.notice_until and p.ui.notice[0] != 0) {
        imgui.api.Separator(ctx);
        imgui.api.TextColored(ctx, if (p.ui.notice_is_error) red else green, &p.ui.notice);
    }
}

// ---- the header ----

fn drawHeader(p: *Plugin, ctx: imgui.ContextPtr) void {
    const s = p.shared;
    const connected = s.connected.load(.acquire);
    const mode: roland.MidiInMode = @enumFromInt(s.mode.load(.monotonic));
    if (connected) {
        switch (mode) {
            .mode2 => imgui.api.TextColored(ctx, green, "Keyboard connected (MIDI IN mode 2)"),
            .mode1 => imgui.api.TextColored(ctx, amber, "Keyboard connected, but in MIDI IN mode 1: switch it to mode 2"),
            .unknown => imgui.api.TextColored(ctx, amber, "Keyboard answers, mode unknown"),
        }
    } else if (!p.processing) {
        imgui.api.TextColored(ctx, grey, "Waiting for the host to run the plugin (record-arm the track)");
    } else {
        imgui.api.TextColored(ctx, red, "The keyboard does not answer: see the MIDI tab");
    }

    const job: engine.JobKind = @enumFromInt(s.job.load(.monotonic));
    if (job != .idle) {
        const done = s.progress_done.load(.monotonic);
        const total = s.progress_total.load(.monotonic);
        var text: [64:0]u8 = undefined;
        const caption = std.fmt.bufPrintZ(&text, "{s} {d}/{d}", .{ if (job == .reading) "Reading" else "Writing", done, total }) catch "";
        const fraction: f64 = if (total == 0) 0 else @as(f64, @floatFromInt(done)) / @as(f64, @floatFromInt(total));
        var width: f64 = -1;
        imgui.api.ProgressBar(ctx, fraction, &width, null, caption);
    }
    const preset = p.settings.presetName();
    var name: [96:0]u8 = undefined;
    const shown = std.fmt.bufPrintZ(&name, "Patch: {s}", .{if (preset.len == 0) "(none)" else preset}) catch "Patch";
    imgui.api.Text(ctx, shown);
}

// ---- the controls ----

fn shortDrawbarName(label: []const u8) []const u8 {
    const marker = "drawbar ";
    const at = std.mem.indexOf(u8, label, marker) orelse return label;
    return label[at + marker.len ..];
}

fn drawControls(p: *Plugin, ctx: imgui.ContextPtr) void {
    // EndChild only follows a BeginChild that returned true (see drawPatches).
    if (!imgui.api.BeginChild(ctx, "##controls", null, null, null, null)) {
        return;
    }
    var shown = [_]bool{false} ** engine.param_count;
    for (catalog.params, 0..) |param, i| {
        if (shown[i]) continue;
        // One header per group, listing every parameter of the group once.
        var header: [96:0]u8 = undefined;
        const title = std.fmt.bufPrintZ(&header, "{s}", .{param.group}) catch continue;
        var flags: c_int = imgui.TreeNodeFlags_DefaultOpen;
        const open_group = imgui.api.CollapsingHeader(ctx, title, null, &flags);
        const is_drawbars = std.mem.indexOf(u8, param.group, "drawbars") != null;
        for (catalog.params[i..], i..) |other, j| {
            if (shown[j] or !std.mem.eql(u8, other.group, param.group)) continue;
            shown[j] = true;
            if (open_group) drawParam(p, ctx, j, is_drawbars);
            if (open_group and is_drawbars) imgui.api.SameLine(ctx, null, null);
        }
        if (open_group and is_drawbars) imgui.api.NewLine(ctx);
    }
    imgui.api.EndChild(ctx);
}

fn drawParam(p: *Plugin, ctx: imgui.ContextPtr, index: usize, as_drawbar: bool) void {
    const param = catalog.params[index];
    var value: c_int = p.shared.paramValue(index);
    var id: [48:0]u8 = undefined;
    imgui.api.PushID(ctx, std.fmt.bufPrintZ(&id, "{s}", .{param.id}) catch "p");
    var changed = false;
    if (as_drawbar) {
        imgui.api.BeginGroup(ctx);
        changed = imgui.api.VSliderInt(ctx, "##v", 34, 120, &value, param.low, param.high, null, null);
        var name: [32:0]u8 = undefined;
        imgui.api.Text(ctx, std.fmt.bufPrintZ(&name, "{s}", .{shortDrawbarName(param.label)}) catch "");
        imgui.api.EndGroup(ctx);
    } else {
        var label: [96:0]u8 = undefined;
        imgui.api.SetNextItemWidth(ctx, 260);
        const text = std.fmt.bufPrintZ(&label, "{s}", .{param.label}) catch "";
        // A type shows its name beside the number.
        var shown: [64:0]u8 = undefined;
        var format: [96:0]u8 = undefined;
        const fmt_text: ?[*:0]const u8 = blk: {
            if (param.names.len == 0) break :blk null;
            const name = engine.valueText(&shown, param, @floatFromInt(value)) orelse break :blk null;
            break :blk (std.fmt.bufPrintZ(&format, "%d  {s}", .{name}) catch break :blk null).ptr;
        };
        changed = imgui.api.SliderInt(ctx, text, &value, param.low, param.high, fmt_text, null);
    }
    imgui.api.PopID(ctx);
    if (changed) {
        if (!p.shared.changeParam(index, @intCast(std.math.clamp(value, 0, 255)))) {
            notice(&p.ui, "Too many changes at once, the last one was dropped.", .{}, true);
        }
    }
}

// ---- the patches ----

fn drawPatches(p: *Plugin, ctx: imgui.ContextPtr) void {
    const w = &p.ui;
    const s = p.shared;

    if (imgui.api.Button(ctx, "Read the keyboard", null, null)) {
        _ = s.sendCommand(.capture_keyboard);
        notice(w, "Reading the keyboard's state into this plugin.", .{}, false);
    }
    imgui.api.SameLine(ctx, null, null);
    if (imgui.api.Button(ctx, "Send to the keyboard", null, null)) {
        _ = s.sendCommand(.recall);
        notice(w, "Writing this plugin's state to the keyboard.", .{}, false);
    }
    if (imgui.api.IsItemHovered(ctx, null)) imgui.api.SetTooltip(ctx, "Only what differs is written: about 0.15 seconds when the keyboard has been read, a few seconds otherwise.");

    checkpoint(w, "patches: buttons");
    var split_on = p.settings.split.load(.monotonic);
    if (imgui.api.Checkbox(ctx, "This patch splits at middle C", &split_on)) plugin.setPatchSplit(p, split_on);
    if (imgui.api.IsItemHovered(ctx, null)) imgui.api.SetTooltip(ctx, "The keyboard cannot report its split. When this is on, the track's notes below middle C go to the Lower part (channel 3) and the others to the Upper part (channel 4); when off, every note goes to the Upper part. The setting is remembered for this patch.");
    var follow = s.follow_panel.load(.monotonic);
    if (imgui.api.Checkbox(ctx, "Follow changes made on the keyboard's panel", &follow)) s.follow_panel.store(follow, .monotonic);
    var recall = s.recall_on_load.load(.monotonic);
    if (imgui.api.Checkbox(ctx, "Send the patch to the keyboard when the project opens", &recall)) s.recall_on_load.store(recall, .monotonic);

    imgui.api.SeparatorText(ctx, "Save");
    imgui.api.SetNextItemWidth(ctx, 280);
    var input_flags: c_int = imgui.InputTextFlags_None;
    _ = imgui.api.InputTextWithHint(ctx, "##save", "patch name", &w.save_name, w.save_name.len, &input_flags, null);
    imgui.api.SameLine(ctx, null, null);
    if (imgui.api.Button(ctx, "Save as preset", null, null)) savePreset(p);
    checkpoint(w, "patches: save");

    drawRegistrations(p, ctx);
    checkpoint(w, "patches: registrations");

    imgui.api.SeparatorText(ctx, "Presets");
    imgui.api.SetNextItemWidth(ctx, 280);
    _ = imgui.api.InputTextWithHint(ctx, "##filter", "filter", &w.preset_filter, w.preset_filter.len, &input_flags, null);
    imgui.api.SameLine(ctx, null, null);
    if (imgui.api.Button(ctx, "Import a file", null, null)) importFile(p);
    if (imgui.api.IsItemHovered(ctx, null)) imgui.api.SetTooltip(ctx, "Loads a dump made by vr09.py, or a preset file from elsewhere.");

    var avail_w: f64 = 0;
    var avail_h: f64 = 0;
    imgui.api.GetContentRegionAvail(ctx, &avail_w, &avail_h);
    var list_h: f64 = @max(avail_h - 150, 120);
    // ReaImGui expects EndChild only when BeginChild returned true: a child
    // pushed below the window's bottom returns false, and an extra EndChild
    // fails an assertion that destroys the whole context.
    if (imgui.api.BeginChild(ctx, "##presets", null, &list_h, null, null)) {
        drawPresetRows(p, ctx);
        imgui.api.EndChild(ctx);
    }
    checkpoint(w, "patches: presets");

    imgui.api.SeparatorText(ctx, "Export");
    imgui.api.SetNextItemWidth(ctx, 420);
    _ = imgui.api.InputTextWithHint(ctx, "##export", "path of the file to write (a dump, as vr09.py reads it)", &w.export_path, w.export_path.len, &input_flags, null);
    imgui.api.SameLine(ctx, null, null);
    if (imgui.api.Button(ctx, "Export", null, null)) exportFile(p);
}

/// The Registrations by bank, four slots each. Because the keyboard cannot
/// select its own Registrations over MIDI, a click on one loads the dump taken
/// from it and writes it to the keyboard, like a preset.
fn drawRegistrations(p: *Plugin, ctx: imgui.ContextPtr) void {
    const w = &p.ui;
    imgui.api.SeparatorText(ctx, "Registrations");
    const lib = w.reg_library orelse {
        imgui.api.TextColored(ctx, grey, "No registrations folder: run build-install.sh vr09 to fill Data/Perken/vr09/registrations.");
        return;
    };
    if (lib.entries.items.len == 0) {
        imgui.api.TextColored(ctx, grey, "The registrations folder holds no <bank>-<slot>_<Name>.json file.");
        return;
    }
    var input_flags: c_int = imgui.InputTextFlags_None;
    imgui.api.SetNextItemWidth(ctx, 280);
    _ = imgui.api.InputTextWithHint(ctx, "##regfilter", "filter by name or bank-slot", &w.reg_filter, w.reg_filter.len, &input_flags, null);
    const filter = std.mem.sliceTo(&w.reg_filter, 0);
    if (imgui.api.IsItemHovered(ctx, null)) imgui.api.SetTooltip(ctx, "Double click a registration to send it to the keyboard. The Scene parameter's lane selects scenes, which are copies of patches. The keyboard's display keeps showing the last registration chosen on its panel.");

    var list_w: f64 = -1;
    var list_h: f64 = 200;
    if (imgui.api.BeginChild(ctx, "##registrations", &list_w, &list_h, null, null)) {
        var i: usize = 0;
        const items = lib.entries.items;
        while (i < items.len) {
            const bank = items[i].bank;
            var end = i;
            var any_match = false;
            while (end < items.len and items[end].bank == bank) : (end += 1) {
                if (registrations.matches(items[end], filter)) any_match = true;
            }
            defer i = end;
            if (!any_match) continue;
            var title: [32:0]u8 = undefined;
            const text = std.fmt.bufPrintZ(&title, "Bank {d}##bank{d}", .{ bank, bank }) catch continue;
            // A filter opens the banks that match, so the result is visible.
            if (filter.len > 0) imgui.api.SetNextItemOpen(ctx, true, null);
            if (!imgui.api.TreeNode(ctx, text, null)) continue;
            for (items[i..end], i..) |entry, index| {
                if (!registrations.matches(entry, filter)) continue;
                var name_buf: [64]u8 = undefined;
                var label: [128:0]u8 = undefined;
                const row = std.fmt.bufPrintZ(&label, "{d}-{d}  {s}##reg{d}", .{ entry.bank, entry.slot, registrations.displayName(&name_buf, entry.name), index }) catch continue;
                var selected = w.reg_selected == @as(i32, @intCast(index));
                var sel_flags: c_int = imgui.SelectableFlags_AllowDoubleClick;
                if (imgui.api.Selectable(ctx, row, &selected, &sel_flags, null, null)) {
                    w.reg_selected = @intCast(index);
                    if (imgui.api.IsMouseDoubleClicked(ctx, 0)) loadRegistration(p, entry);
                }
            }
            imgui.api.TreePop(ctx);
        }
        imgui.api.EndChild(ctx);
    }
    if (w.reg_selected >= 0 and w.reg_selected < lib.entries.items.len) {
        if (imgui.api.Button(ctx, "Load and send registration", null, null)) loadRegistration(p, lib.entries.items[@intCast(w.reg_selected)]);
    }
}

fn loadRegistration(p: *Plugin, entry: registrations.Entry) void {
    p.loadRegistration(entry) catch |err| {
        notice(&p.ui, "Could not load registration {d}-{d}: {s}", .{ entry.bank, entry.slot, @errorName(err) }, true);
        return;
    };
    notice(&p.ui, "Loaded registration {d}-{d}.", .{ entry.bank, entry.slot }, false);
}

fn drawPresetRows(p: *Plugin, ctx: imgui.ContextPtr) void {
    const w = &p.ui;
    const list = w.preset_names orelse {
        imgui.api.TextColored(ctx, grey, "No preset folder yet: save a patch to create it.");
        return;
    };
    const filter = std.mem.sliceTo(&w.preset_filter, 0);
    for (list.items, 0..) |file_name, i| {
        const display = state.displayName(file_name);
        if (filter.len > 0 and std.ascii.indexOfIgnoreCase(display, filter) == null) continue;
        var label: [160:0]u8 = undefined;
        const text = std.fmt.bufPrintZ(&label, "{s}##{d}", .{ display, i }) catch continue;
        var selected = w.preset_selected == @as(i32, @intCast(i));
        var sel_flags: c_int = imgui.SelectableFlags_AllowDoubleClick;
        if (imgui.api.Selectable(ctx, text, &selected, &sel_flags, null, null)) {
            w.preset_selected = @intCast(i);
            w.delete_armed = -1;
            // A double click loads, a single click only selects.
            if (imgui.api.IsMouseDoubleClicked(ctx, 0)) loadPreset(p, file_name);
        }
    }
    if (w.preset_selected >= 0 and w.preset_selected < list.items.len) {
        imgui.api.Separator(ctx);
        const file_name = list.items[@intCast(w.preset_selected)];
        if (imgui.api.Button(ctx, "Load and send", null, null)) loadPreset(p, file_name);
        imgui.api.SameLine(ctx, null, null);
        const armed = w.delete_armed == w.preset_selected;
        if (imgui.api.Button(ctx, if (armed) "Click again to delete" else "Delete", null, null)) {
            if (armed) {
                deletePreset(p, file_name);
            } else {
                w.delete_armed = w.preset_selected;
            }
        }
    }
}

fn loadPreset(p: *Plugin, file_name: []const u8) void {
    var folder_buf: [fileio.max_path]u8 = undefined;
    const folder = presetFolder(&folder_buf) orelse return;
    var path_buf: [fileio.max_path]u8 = undefined;
    const path = state.presetPath(&path_buf, folder, file_name) catch return;
    p.loadPresetFile(path, state.displayName(file_name)) catch |err| {
        notice(&p.ui, "Could not load {s}: {s}", .{ file_name, @errorName(err) }, true);
        return;
    };
    notice(&p.ui, "Loaded {s}.", .{state.displayName(file_name)}, false);
}

fn deletePreset(p: *Plugin, file_name: []const u8) void {
    var folder_buf: [fileio.max_path]u8 = undefined;
    const folder = presetFolder(&folder_buf) orelse return;
    var path_buf: [fileio.max_path]u8 = undefined;
    const path = state.presetPath(&path_buf, folder, file_name) catch return;
    fileio.deleteFile(path) catch |err| {
        notice(&p.ui, "Could not delete {s}: {s}", .{ file_name, @errorName(err) }, true);
        return;
    };
    p.ui.preset_selected = -1;
    p.ui.delete_armed = -1;
    p.ui.preset_refresh_at = 0;
    notice(&p.ui, "Deleted {s}.", .{state.displayName(file_name)}, false);
}

fn savePreset(p: *Plugin) void {
    var clean: [name_cap]u8 = undefined;
    const name = state.sanitizeName(&clean, std.mem.sliceTo(&p.ui.save_name, 0));
    if (name.len == 0) {
        notice(&p.ui, "Type a name for the preset first.", .{}, true);
        return;
    }
    var folder_buf: [fileio.max_path]u8 = undefined;
    const folder = presetFolder(&folder_buf) orelse {
        notice(&p.ui, "REAPER's resource folder is not known.", .{}, true);
        return;
    };
    fileio.makePath(folder) catch |err| {
        notice(&p.ui, "Could not create the preset folder: {s}", .{@errorName(err)}, true);
        return;
    };
    var path_buf: [fileio.max_path]u8 = undefined;
    const path = state.presetPath(&path_buf, folder, name) catch return;
    const scene = plugin.allocator.create(dump.Dump) catch return;
    defer plugin.allocator.destroy(scene);
    p.shared.desiredSnapshot(scene);
    state.savePresetFile(plugin.allocator, path, scene) catch |err| {
        notice(&p.ui, "Could not write {s}: {s}", .{ name, @errorName(err) }, true);
        return;
    };
    p.settings.setPresetName(name);
    p.ui.preset_refresh_at = 0;
    notice(&p.ui, "Saved {s}.", .{name}, false);
}

fn importFile(p: *Plugin) void {
    if (!glue.ready) return;
    var path: [4096]u8 = [_]u8{0} ** 4096;
    if (!Reaper.GetUserFileNameForRead(@ptrCast(&path), "Import a VR-09 dump or preset", "json")) return;
    const chosen = std.mem.sliceTo(&path, 0);
    p.loadPresetFile(chosen, state.displayName(std.fs.path.basename(chosen))) catch |err| {
        notice(&p.ui, "Could not import the file: {s}", .{@errorName(err)}, true);
        return;
    };
    notice(&p.ui, "Imported {s}.", .{std.fs.path.basename(chosen)}, false);
}

fn exportFile(p: *Plugin) void {
    const target = std.mem.sliceTo(&p.ui.export_path, 0);
    if (target.len == 0 or !std.fs.path.isAbsolute(target)) {
        notice(&p.ui, "Type the full path of the file to write.", .{}, true);
        return;
    }
    const scene = plugin.allocator.create(dump.Dump) catch return;
    defer plugin.allocator.destroy(scene);
    p.shared.desiredSnapshot(scene);
    state.savePresetFile(plugin.allocator, target, scene) catch |err| {
        notice(&p.ui, "Could not write the file: {s}", .{@errorName(err)}, true);
        return;
    };
    notice(&p.ui, "Exported to {s}.", .{target}, false);
}

// ---- the audio loop ----

fn drawChannelPairCombo(ctx: imgui.ContextPtr, id: [*:0]const u8, dir: glue.Direction, current: i32, out: *i32) bool {
    var preview: [96:0]u8 = undefined;
    const count = glue.audioChannelCount(dir);
    const preview_text = if (current < 0 or current + 1 >= count)
        std.fmt.bufPrintZ(&preview, "none", .{}) catch "none"
    else
        std.fmt.bufPrintZ(&preview, "{s} + {s}", .{ glue.audioChannelName(dir, @intCast(current)), glue.audioChannelName(dir, @intCast(current + 1)) }) catch "?";
    var changed = false;
    imgui.api.SetNextItemWidth(ctx, 320);
    if (imgui.api.BeginCombo(ctx, id, preview_text, null)) {
        var none_selected = current < 0;
        if (imgui.api.Selectable(ctx, "none", &none_selected, null, null, null)) {
            out.* = -1;
            changed = true;
        }
        var ch: usize = 0;
        while (ch + 1 < count) : (ch += 2) {
            var label: [128:0]u8 = undefined;
            const text = std.fmt.bufPrintZ(&label, "{s} + {s}##{d}", .{ glue.audioChannelName(dir, ch), glue.audioChannelName(dir, ch + 1), ch }) catch continue;
            var selected = current == @as(i32, @intCast(ch));
            if (imgui.api.Selectable(ctx, text, &selected, null, null, null)) {
                out.* = @intCast(ch);
                changed = true;
            }
        }
        imgui.api.EndCombo(ctx);
    }
    return changed;
}

fn drawAudioLoop(p: *Plugin, ctx: imgui.ContextPtr) void {
    if (!glue.ready) {
        imgui.api.TextWrapped(ctx, "The audio loop needs REAPER. In another host the plugin only passes the audio through.");
        return;
    }
    imgui.api.TextWrapped(ctx, "The loop sends this track's audio to the keyboard's audio input and takes the keyboard's output back, the way ReaInsert does for outboard gear. Wire the interface's output to the keyboard's input, and the keyboard's output to the interface's input.");
    imgui.api.Spacing(ctx);

    var enabled = p.settings.loop_enabled.load(.monotonic);
    if (imgui.api.Checkbox(ctx, "Use the audio loop", &enabled)) p.setLoopEnabled(enabled);

    var out_channel = p.settings.out_channel.load(.monotonic);
    imgui.api.Text(ctx, "Send to (interface outputs)");
    if (drawChannelPairCombo(ctx, "##send", .output, out_channel, &out_channel)) {
        p.settings.out_channel.store(out_channel, .monotonic);
        p.applyLoopSettings();
    }
    var in_channel = p.settings.in_channel.load(.monotonic);
    imgui.api.Text(ctx, "Return from (interface inputs)");
    if (drawChannelPairCombo(ctx, "##return", .input, in_channel, &in_channel)) {
        p.settings.in_channel.store(in_channel, .monotonic);
        p.applyLoopSettings();
    }

    var send_db: c_int = @intFromFloat(@round(p.settings.sendDb()));
    imgui.api.SetNextItemWidth(ctx, 320);
    if (imgui.api.SliderInt(ctx, "Send level (dB)", &send_db, -60, 12, null, null)) p.settings.setSendDb(@floatFromInt(send_db));
    var return_db: c_int = @intFromFloat(@round(p.settings.returnDb()));
    imgui.api.SetNextItemWidth(ctx, 320);
    if (imgui.api.SliderInt(ctx, "Return level (dB)", &return_db, -60, 12, null, null)) p.settings.setReturnDb(@floatFromInt(return_db));

    imgui.api.SeparatorText(ctx, "Latency");
    imgui.api.TextWrapped(ctx, "The plugin tells REAPER how long the round trip takes, and REAPER's delay compensation lines the track up. Measuring sends a short click to the keyboard's audio input, so turn the keyboard's volume down first.");
    const ping: audio.PingState = @enumFromInt(p.ping_state.load(.acquire));
    const busy = ping == .listening_noise or ping == .sending or ping == .listening;
    if (busy) imgui.api.BeginDisabled(ctx, null);
    if (imgui.api.Button(ctx, "Measure the round trip", null, null)) p.startPing();
    if (busy) imgui.api.EndDisabled(ctx);
    imgui.api.SameLine(ctx, null, null);
    var text: [128:0]u8 = undefined;
    switch (ping) {
        .idle => {
            const frames = p.settings.latency_frames.load(.monotonic);
            if (frames == 0) {
                imgui.api.TextColored(ctx, grey, "not measured yet");
            } else {
                imgui.api.Text(ctx, latencyText(&text, frames, p.settings.latency_rate.load(.monotonic)));
            }
        },
        .listening_noise, .sending, .listening => imgui.api.TextColored(ctx, amber, "measuring..."),
        .done => imgui.api.TextColored(ctx, green, latencyText(&text, p.settings.latency_frames.load(.monotonic), p.settings.latency_rate.load(.monotonic))),
        .failed => imgui.api.TextColored(ctx, red, "no click came back: check the cables, the channels and that the track is processing"),
    }

    if (p.slot) |slot| {
        imgui.api.SeparatorText(ctx, "Status");
        const loop_state: audio.LoopState = @enumFromInt(p.loop_state.load(.monotonic));
        const status_text = switch (loop_state) {
            .off => "The loop is off: the audio passes through.",
            .no_device => "The audio device is not running (an offline render, or REAPER's audio is stopped): the audio passes through.",
            .no_channels => "Choose a pair of channels to send to and to return from: the audio passes through.",
            .running => "The loop is running.",
        };
        imgui.api.TextColored(ctx, if (loop_state == .running) green else amber, status_text);
        imgui.api.Text(ctx, std.fmt.bufPrintZ(&text, "Dropouts: send {d}, return {d}", .{ slot.out_underruns.load(.monotonic), slot.in_overruns.load(.monotonic) }) catch "");
    } else {
        imgui.api.TextColored(ctx, grey, "The plugin is not active yet.");
    }
}

fn latencyText(buf: []u8, frames: u32, rate: u32) [:0]const u8 {
    const ms: f64 = if (rate == 0) 0 else @as(f64, @floatFromInt(frames)) * 1000.0 / @as(f64, @floatFromInt(rate));
    return std.fmt.bufPrintZ(buf, "{d} samples ({d:.1} ms)", .{ frames, ms }) catch "?";
}

// ---- the MIDI tab ----

fn drawDeviceCombo(w: *Window, ctx: imgui.ContextPtr, id: [*:0]const u8, dir: glue.Direction, current: ?usize, out: *?usize) bool {
    const names = if (dir == .output) &w.output_names else &w.input_names;
    const present = if (dir == .output) &w.output_present else &w.input_present;
    var preview: [128:0]u8 = undefined;
    const preview_text = if (current) |c|
        (if (c < max_devices and present[c]) std.fmt.bufPrintZ(&preview, "{s}", .{std.mem.sliceTo(&names[c], 0)}) catch "?" else std.fmt.bufPrintZ(&preview, "device {d} (not present)", .{c}) catch "?")
    else
        std.fmt.bufPrintZ(&preview, "none", .{}) catch "none";
    var changed = false;
    imgui.api.SetNextItemWidth(ctx, 360);
    if (imgui.api.BeginCombo(ctx, id, preview_text, null)) {
        var none_selected = current == null;
        if (dir == .output and imgui.api.Selectable(ctx, "none", &none_selected, null, null, null)) {
            out.* = null;
            changed = true;
        }
        for (0..max_devices) |i| {
            if (!present[i]) continue;
            var label: [160:0]u8 = undefined;
            const text = std.fmt.bufPrintZ(&label, "{s}##{d}", .{ std.mem.sliceTo(&names[i], 0), i }) catch continue;
            var selected = current != null and current.? == i;
            // Because a track's device field is too narrow for the later
            // entries, they are shown but cannot be chosen.
            var flags: c_int = if (glue.addressable(dir, i)) imgui.SelectableFlags_None else imgui.SelectableFlags_Disabled;
            if (imgui.api.Selectable(ctx, text, &selected, &flags, null, null)) {
                out.* = i;
                changed = true;
            }
        }
        imgui.api.EndCombo(ctx);
    }
    return changed;
}

fn drawMidi(p: *Plugin, ctx: imgui.ContextPtr) void {
    const w = &p.ui;
    const s = p.shared;
    if (!glue.ready or p.track == null) {
        imgui.api.TextWrapped(ctx, "The MIDI routing can only be set from a track's FX chain in REAPER. In another host, or on a take or the monitoring chain, route the plugin's MIDI yourself.");
    } else {
        imgui.api.SeparatorText(ctx, "The track's MIDI devices");
        if (glue.findKeyboard(.output) == null) {
            imgui.api.TextColored(ctx, amber, "No VR-09 found among REAPER's MIDI outputs: plug it in (USB), or choose its device below.");
        }
        imgui.api.Text(ctx, "MIDI output (to the keyboard)");
        var out_dev = glue.trackMidiOutput(p.track);
        if (drawDeviceCombo(w, ctx, "##midiout", .output, out_dev, &out_dev)) {
            glue.setTrackMidiOutput(p.track, out_dev);
            p.settings.autoconnect_done.store(true, .monotonic);
        }
        imgui.api.Text(ctx, "MIDI input (record from the keyboard)");
        var in_dev = glue.trackMidiInput(p.track);
        if (drawDeviceCombo(w, ctx, "##midiin", .input, in_dev, &in_dev)) {
            if (in_dev) |d| glue.setTrackMidiInput(p.track, d);
        }
        if (in_dev == null) imgui.api.TextColored(ctx, grey, "The track's input is not a single MIDI device.");

        const monitoring = glue.trackMonitoring(p.track);
        var armed = glue.trackArmed(p.track);
        if (imgui.api.Checkbox(ctx, "Record-arm the track", &armed)) glue.setTrackArmed(p.track, armed);
        if (imgui.api.IsItemHovered(ctx, null)) imgui.api.SetTooltip(ctx, "REAPER only delivers MIDI input to a track's plugins while the track is armed. The keyboard's replies are MIDI input.");
        var monitor_on = monitoring == 1;
        if (imgui.api.Checkbox(ctx, "Monitor input", &monitor_on)) glue.setTrackMonitoring(p.track, if (monitor_on) 1 else 0);
        if (!armed) {
            imgui.api.TextColored(ctx, amber, "The track is not armed: the keyboard's replies cannot reach the plugin.");
        } else if (monitoring == 0) {
            imgui.api.TextColored(ctx, amber, "The track does not monitor its input: the keyboard's replies cannot reach the plugin.");
        }
    }

    imgui.api.SeparatorText(ctx, "Behavior");
    var pass = p.settings.pass_midi.load(.monotonic);
    if (imgui.api.Checkbox(ctx, "Pass this track's MIDI through to the keyboard", &pass)) p.settings.pass_midi.store(pass, .monotonic);
    if (imgui.api.IsItemHovered(ctx, null)) imgui.api.SetTooltip(ctx, "Off by default. REAPER does not tell the notes you play from the notes the track plays back, and the track must monitor its input for the keyboard's replies to arrive, so the keyboard would sound its own notes twice. Keep the notes on a separate MIDI track, or turn this on and switch the keyboard's Local Control off.");
    const dropped = p.shared.midi_dropped.load(.monotonic);
    if (!pass and dropped > 0) {
        var note: [128:0]u8 = undefined;
        imgui.api.TextColored(ctx, grey, std.fmt.bufPrintZ(&note, "{d} MIDI messages on this track were not passed on.", .{dropped}) catch "");
    }
    var bare = p.settings.sysex_bare.load(.monotonic);
    if (imgui.api.Checkbox(ctx, "Send SysEx without its F0 and F7 bytes", &bare)) p.settings.sysex_bare.store(bare, .monotonic);
    if (imgui.api.IsItemHovered(ctx, null)) imgui.api.SetTooltip(ctx, "Switch this on if the keyboard ignores the plugin's messages: hosts differ on whether they add the framing bytes themselves.");

    imgui.api.SeparatorText(ctx, "Connection");
    if (imgui.api.Button(ctx, "Look for the keyboard again", null, null)) {
        _ = s.sendCommand(.reconnect);
        p.settings.autoconnect_done.store(false, .monotonic);
        p.ticks = 0;
        notice(w, "Asking the keyboard who it is.", .{}, false);
    }
    var text: [160:0]u8 = undefined;
    imgui.api.Text(ctx, std.fmt.bufPrintZ(&text, "SysEx events: from the host {d}, accepted by the host {d}, refused {d}", .{ s.host_sysex_in.load(.monotonic), s.host_sysex_out.load(.monotonic), s.host_sysex_refused.load(.monotonic) }) catch "");
    var trace: [96]u8 = undefined;
    imgui.api.Text(ctx, std.fmt.bufPrintZ(&text, "First received: {s}", .{s.trace_in.format(&trace)}) catch "");
    imgui.api.Text(ctx, std.fmt.bufPrintZ(&text, "First sent: {s}", .{s.trace_out.format(&trace)}) catch "");
    imgui.api.Text(ctx, std.fmt.bufPrintZ(&text, "Messages: sent {d}, received {d}, bad checksums {d}", .{ s.tx_count.load(.monotonic), s.rx_count.load(.monotonic), s.bad_count.load(.monotonic) }) catch "");
    imgui.api.Text(ctx, std.fmt.bufPrintZ(&text, "Known keyboard bytes: {d} of {d}, blocks that never answered: {d}", .{ s.mirror_known.load(.monotonic), dump.total_bytes, s.blocks_failed.load(.monotonic) }) catch "");
}
