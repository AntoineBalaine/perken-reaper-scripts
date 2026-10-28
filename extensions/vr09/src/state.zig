//! What the plugin keeps in a REAPER project, and the preset files.
//!
//! The project stores the state the keyboard should be in (`desired`, the
//! scene), the values of the control change parameters, and the settings of
//! the audio loop, so that opening the project puts the keyboard back in the
//! patch the project was made with. The same scene, as the dump JSON of
//! `vr09.py`, is what a preset file holds.
const std = @import("std");
const engine = @import("engine.zig");
const dump = @import("dump.zig");
const fileio = @import("fileio.zig");
const catalog = @import("catalog.zig");
const scenes = @import("scenes.zig");

const Atomic = std.atomic.Value;

pub const preset_extension = ".vr09";
/// Dumps made by `vr09.py` are plain JSON files; they load as presets too.
pub const preset_extensions = [_][]const u8{ ".vr09", ".json" };

pub fn dbToGain(db: f32) f32 {
    if (db <= -60) return 0;
    return std.math.pow(f32, 10, db / 20);
}

/// The loop's settings and the preset name. The user interface and the host
/// write them on the main thread and the audio thread reads them, so each is
/// an atomic; a float is kept as its bits.
pub const Settings = struct {
    loop_enabled: Atomic(bool) = Atomic(bool).init(false),
    send_db_bits: Atomic(u32) = Atomic(u32).init(@bitCast(@as(f32, 0))),
    return_db_bits: Atomic(u32) = Atomic(u32).init(@bitCast(@as(f32, 0))),
    out_channel: Atomic(i32) = Atomic(i32).init(-1),
    in_channel: Atomic(i32) = Atomic(i32).init(-1),
    latency_frames: Atomic(u32) = Atomic(u32).init(0),
    latency_rate: Atomic(u32) = Atomic(u32).init(0),
    /// Set once the plugin has chosen the keyboard's MIDI device for its
    /// track, so that it never overrides what the user chose afterwards.
    autoconnect_done: Atomic(bool) = Atomic(bool).init(false),
    /// Whether SysEx goes to the host without its F0 and F7, for a host that
    /// adds them itself. The spec does not say, so the user can switch it.
    sysex_bare: Atomic(bool) = Atomic(bool).init(false),
    /// Whether the track's MIDI (notes, controllers, pitch bend) is passed on
    /// to the keyboard. On by default, so that the track's items play the
    /// keyboard. A track that records the keyboard's own MIDI while monitoring
    /// it would make the keyboard sound its notes twice: the user turns it off
    /// there, because the host does not tell live input from playback.
    pass_midi: Atomic(bool) = Atomic(bool).init(true),
    /// Whether the current patch splits the keyboard at middle C, which
    /// decides the part each note goes to (see split.zig).
    split: Atomic(bool) = Atomic(bool).init(false),
    preset_name: [64:0]u8 = [_:0]u8{0} ** 64,
    /// The name under which the current patch's split is remembered. It is the patch's name, except for a scene
    /// of the library, whose name the player may change while its patch keeps the key it was loaded under.
    split_key: [64:0]u8 = [_:0]u8{0} ** 64,

    pub fn sendDb(self: *const Settings) f32 {
        return @bitCast(self.send_db_bits.load(.monotonic));
    }

    pub fn returnDb(self: *const Settings) f32 {
        return @bitCast(self.return_db_bits.load(.monotonic));
    }

    pub fn setSendDb(self: *Settings, db: f32) void {
        self.send_db_bits.store(@bitCast(db), .monotonic);
    }

    pub fn setReturnDb(self: *Settings, db: f32) void {
        self.return_db_bits.store(@bitCast(db), .monotonic);
    }

    /// Names the current patch, and takes the name as the key of its split.
    pub fn setPresetName(self: *Settings, name: []const u8) void {
        @memset(&self.preset_name, 0);
        const n = @min(name.len, self.preset_name.len - 1);
        @memcpy(self.preset_name[0..n], name[0..n]);
        self.setSplitKey(name);
    }

    pub fn setSplitKey(self: *Settings, key: []const u8) void {
        @memset(&self.split_key, 0);
        const n = @min(key.len, self.split_key.len - 1);
        @memcpy(self.split_key[0..n], key[0..n]);
    }

    pub fn splitKey(self: *const Settings) [:0]const u8 {
        return std.mem.sliceTo(&self.split_key, 0);
    }

    pub fn presetName(self: *const Settings) [:0]const u8 {
        return std.mem.sliceTo(&self.preset_name, 0);
    }
};

const magic = "VR09";
const version: u32 = 1;

pub const StateError = error{ BadMagic, UnsupportedVersion, Truncated };

/// Writes the project state: the scene, the CC values and the settings.
pub fn write(writer: anytype, shared: *const engine.Shared, settings: *const Settings, scene_list: *const scenes.List) !void {
    try writer.writeAll(magic);
    try writer.writeInt(u32, version, .little);

    var scene: dump.Dump = undefined;
    shared.desiredSnapshot(&scene);
    var bits: [(dump.total_bytes + 7) / 8]u8 = [_]u8{0} ** ((dump.total_bytes + 7) / 8);
    for (scene.known, 0..) |k, i| {
        if (k) bits[i / 8] |= @as(u8, 1) << @intCast(i % 8);
    }
    try writer.writeAll(&bits);
    try writer.writeAll(&scene.values);

    var cc: [engine.param_count]u8 = undefined;
    for (&cc, 0..) |*v, i| v.* = shared.cc_values[i].load(.monotonic);
    try writer.writeAll(&cc);

    var flags: u8 = 0;
    if (settings.loop_enabled.load(.monotonic)) flags |= 1;
    if (shared.follow_panel.load(.monotonic)) flags |= 2;
    if (shared.recall_on_load.load(.monotonic)) flags |= 4;
    if (settings.autoconnect_done.load(.monotonic)) flags |= 8;
    if (settings.sysex_bare.load(.monotonic)) flags |= 16;
    if (settings.pass_midi.load(.monotonic)) flags |= 32;
    if (settings.split.load(.monotonic)) flags |= 64;
    // Projects saved before pass_midi defaulted to on lack this bit; they
    // then get the new default instead of a stored "off".
    flags |= 128;
    try writer.writeByte(flags);
    try writer.writeInt(u32, settings.send_db_bits.load(.monotonic), .little);
    try writer.writeInt(u32, settings.return_db_bits.load(.monotonic), .little);
    try writer.writeInt(i32, settings.out_channel.load(.monotonic), .little);
    try writer.writeInt(i32, settings.in_channel.load(.monotonic), .little);
    try writer.writeInt(u32, settings.latency_frames.load(.monotonic), .little);
    try writer.writeInt(u32, settings.latency_rate.load(.monotonic), .little);
    const name = settings.presetName();
    try writer.writeByte(@intCast(name.len));
    try writer.writeAll(name);
    try scene_list.write(writer);
}

/// Reads what `write` wrote. The scene replaces the desired state and marks it
/// restored, so that the engine recalls it once the keyboard answers.
pub fn read(reader: anytype, shared: *engine.Shared, settings: *Settings, scene_list: *scenes.List) !void {
    var head: [4]u8 = undefined;
    reader.readNoEof(&head) catch return error.Truncated;
    if (!std.mem.eql(u8, &head, magic)) return error.BadMagic;
    const v = reader.readInt(u32, .little) catch return error.Truncated;
    if (v != version) return error.UnsupportedVersion;

    var scene = dump.Dump{};
    var bits: [(dump.total_bytes + 7) / 8]u8 = undefined;
    reader.readNoEof(&bits) catch return error.Truncated;
    reader.readNoEof(&scene.values) catch return error.Truncated;
    for (&scene.known, 0..) |*k, i| k.* = bits[i / 8] & (@as(u8, 1) << @intCast(i % 8)) != 0;

    var cc: [engine.param_count]u8 = undefined;
    reader.readNoEof(&cc) catch return error.Truncated;

    const flags = reader.readByte() catch return error.Truncated;
    const send_bits = reader.readInt(u32, .little) catch return error.Truncated;
    const return_bits = reader.readInt(u32, .little) catch return error.Truncated;
    const out_channel = reader.readInt(i32, .little) catch return error.Truncated;
    const in_channel = reader.readInt(i32, .little) catch return error.Truncated;
    const latency = reader.readInt(u32, .little) catch return error.Truncated;
    const rate = reader.readInt(u32, .little) catch return error.Truncated;
    const name_len = reader.readByte() catch return error.Truncated;
    var name: [64]u8 = undefined;
    if (name_len >= name.len) return error.Truncated;
    reader.readNoEof(name[0..name_len]) catch return error.Truncated;
    // Because the scenes come after everything a first version wrote, a state without them is still read.
    // A cut or damaged scene section keeps the scenes read before it and must not cost the patch.
    scene_list.read(reader) catch {};

    shared.loadDesired(&scene);
    for (cc, 0..) |value, i| shared.cc_values[i].store(value, .monotonic);
    settings.loop_enabled.store(flags & 1 != 0, .monotonic);
    shared.follow_panel.store(flags & 2 != 0, .monotonic);
    shared.recall_on_load.store(flags & 4 != 0, .monotonic);
    settings.autoconnect_done.store(flags & 8 != 0, .monotonic);
    settings.sysex_bare.store(flags & 16 != 0, .monotonic);
    settings.pass_midi.store(flags & 128 == 0 or flags & 32 != 0, .monotonic);
    settings.split.store(flags & 64 != 0, .monotonic);
    settings.send_db_bits.store(send_bits, .monotonic);
    settings.return_db_bits.store(return_bits, .monotonic);
    settings.out_channel.store(out_channel, .monotonic);
    settings.in_channel.store(in_channel, .monotonic);
    settings.latency_frames.store(latency, .monotonic);
    settings.latency_rate.store(rate, .monotonic);
    settings.setPresetName(name[0..name_len]);
    shared.restored.store(scene.knownCount() > 0, .release);
}

// ---- presets ----

/// Keeps letters, digits, spaces, dashes, underscores and dots, because the
/// name becomes a file name on every operating system.
pub fn sanitizeName(out: []u8, name: []const u8) [:0]const u8 {
    var n: usize = 0;
    for (name) |c| {
        // The last byte is kept for the terminator.
        if (n + 1 >= out.len) break;
        const ok = std.ascii.isAlphanumeric(c) or c == ' ' or c == '-' or c == '_' or c == '.' or c >= 0x80;
        out[n] = if (ok) c else '_';
        n += 1;
    }
    const trimmed = std.mem.trim(u8, out[0..n], " .");
    const end = trimmed.ptr - out.ptr + trimmed.len;
    out[end] = 0;
    return out[end - trimmed.len .. end :0];
}

/// The list of the patches that split the keyboard (see split.zig).
pub fn splitsPath(buf: []u8, resource_path: []const u8) ![]const u8 {
    return std.fmt.bufPrint(buf, "{s}{c}Data{c}Perken{c}vr09{c}splits.txt", .{ resource_path, std.fs.path.sep, std.fs.path.sep, std.fs.path.sep, std.fs.path.sep });
}

/// The preset folder inside REAPER's resource folder.
pub fn presetFolder(buf: []u8, resource_path: []const u8) ![]const u8 {
    return std.fmt.bufPrint(buf, "{s}{c}Data{c}Perken{c}vr09{c}presets", .{ resource_path, std.fs.path.sep, std.fs.path.sep, std.fs.path.sep, std.fs.path.sep });
}

/// The folder of the keyboard's Registrations, which build-install.sh fills.
pub fn registrationFolder(buf: []u8, resource_path: []const u8) ![]const u8 {
    return std.fmt.bufPrint(buf, "{s}{c}Data{c}Perken{c}vr09{c}registrations", .{ resource_path, std.fs.path.sep, std.fs.path.sep, std.fs.path.sep, std.fs.path.sep });
}

/// The folder that REAPER uses when nothing says otherwise, for the preset
/// discovery that runs before any REAPER function is reachable.
pub fn defaultResourcePath(buf: []u8) ?[]const u8 {
    const builtin = @import("builtin");
    var env: [fileio.max_path]u8 = undefined;
    if (fileio.getenv("REAPER_RESOURCE_PATH", &env)) |p| return std.fmt.bufPrint(buf, "{s}", .{p}) catch null;
    switch (builtin.os.tag) {
        .macos => {
            const home = fileio.getenv("HOME", &env) orelse return null;
            return std.fmt.bufPrint(buf, "{s}/Library/Application Support/REAPER", .{home}) catch null;
        },
        .windows => {
            const appdata = fileio.getenv("APPDATA", &env) orelse return null;
            return std.fmt.bufPrint(buf, "{s}\\REAPER", .{appdata}) catch null;
        },
        else => {
            const home = fileio.getenv("HOME", &env) orelse return null;
            return std.fmt.bufPrint(buf, "{s}/.config/REAPER", .{home}) catch null;
        },
    }
}

pub const PresetError = error{ NotADump, InvalidJson, OutOfMemory, FileNotFound, NameTooLong };

pub fn loadPresetFile(allocator: std.mem.Allocator, path: []const u8, out: *dump.Dump) !void {
    const bytes = try fileio.readAll(allocator, path);
    defer allocator.free(bytes);
    try dump.parseJson(allocator, bytes, out);
}

pub fn savePresetFile(allocator: std.mem.Allocator, path: []const u8, scene: *const dump.Dump) !void {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    try dump.writeJson(allocator, scene, buf.writer());
    try buf.append('\n');
    try fileio.writeAll(path, buf.items);
}

/// The path of the preset `name` in `folder`, trying the extensions in turn
/// when the name has none.
pub fn presetPath(buf: []u8, folder: []const u8, name: []const u8) ![]const u8 {
    if (fileio.hasExtension(name, &preset_extensions)) {
        return std.fmt.bufPrint(buf, "{s}{c}{s}", .{ folder, std.fs.path.sep, name });
    }
    return std.fmt.bufPrint(buf, "{s}{c}{s}{s}", .{ folder, std.fs.path.sep, name, preset_extension });
}

pub fn displayName(file_name: []const u8) []const u8 {
    for (preset_extensions) |ext| {
        if (fileio.hasExtension(file_name, &.{ext})) return file_name[0 .. file_name.len - ext.len];
    }
    return file_name;
}

test "the project state survives a round trip" {
    const allocator = std.testing.allocator;
    const shared = try allocator.create(engine.Shared);
    defer allocator.destroy(shared);
    shared.* = .{};
    var settings = Settings{};

    var scene = dump.Dump{};
    _ = scene.set(.kb, 0x02 << 14 | 5, 7);
    _ = scene.set(.kb, 0x01 << 14 | 0x03 << 7 | 1, 99);
    shared.loadDesired(&scene);
    shared.cc_values[3].store(42, .monotonic);
    settings.loop_enabled.store(true, .monotonic);
    settings.setSendDb(-6);
    settings.out_channel.store(2, .monotonic);
    settings.in_channel.store(4, .monotonic);
    settings.latency_frames.store(1234, .monotonic);
    settings.latency_rate.store(48000, .monotonic);
    settings.setPresetName("Jazz Roll");
    shared.recall_on_load.store(false, .monotonic);

    const list = try allocator.create(scenes.List);
    defer allocator.destroy(list);
    list.* = .{};
    var patch = dump.Dump{};
    _ = patch.set(.kb, 0x02 << 14 | 5, 3);
    _ = try list.add("Verse", &patch);

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();
    try write(buf.writer(), shared, &settings, list);

    const shared2 = try allocator.create(engine.Shared);
    defer allocator.destroy(shared2);
    shared2.* = .{};
    var settings2 = Settings{};
    const list2 = try allocator.create(scenes.List);
    defer allocator.destroy(list2);
    list2.* = .{};
    var stream = std.io.fixedBufferStream(buf.items);
    try read(stream.reader(), shared2, &settings2, list2);
    try std.testing.expectEqual(@as(u8, 1), list2.count);
    try std.testing.expectEqualStrings("Verse", list2.get(1).?.name());
    try std.testing.expectEqual(@as(?u8, 3), list2.get(1).?.patch.get(.kb, 0x02 << 14 | 5));

    try std.testing.expectEqual(@as(?u8, 7), shared2.getDesired(.kb, 0x02 << 14 | 5));
    try std.testing.expectEqual(@as(?u8, 99), shared2.getDesired(.kb, 0x01 << 14 | 0x03 << 7 | 1));
    try std.testing.expectEqual(@as(?u8, null), shared2.getDesired(.kb, 0x02 << 14 | 6));
    try std.testing.expectEqual(@as(u8, 42), shared2.cc_values[3].load(.monotonic));
    try std.testing.expect(settings2.loop_enabled.load(.monotonic));
    try std.testing.expectEqual(@as(f32, -6), settings2.sendDb());
    try std.testing.expectEqual(@as(i32, 2), settings2.out_channel.load(.monotonic));
    try std.testing.expectEqual(@as(u32, 1234), settings2.latency_frames.load(.monotonic));
    try std.testing.expectEqualStrings("Jazz Roll", settings2.presetName());
    try std.testing.expect(!shared2.recall_on_load.load(.monotonic));
    try std.testing.expect(shared2.restored.load(.acquire));
}

test "a stream that is not ours or is cut short is refused" {
    const allocator = std.testing.allocator;
    const shared = try allocator.create(engine.Shared);
    defer allocator.destroy(shared);
    shared.* = .{};
    var settings = Settings{};
    const list = try allocator.create(scenes.List);
    defer allocator.destroy(list);
    list.* = .{};
    var bad = std.io.fixedBufferStream("NOPE....");
    try std.testing.expectError(error.BadMagic, read(bad.reader(), shared, &settings, list));
    var short = std.io.fixedBufferStream("VR09\x01\x00\x00\x00abc");
    try std.testing.expectError(error.Truncated, read(short.reader(), shared, &settings, list));
}

test "names become safe file names" {
    var buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings("Pad_ 1", sanitizeName(&buf, "Pad/ 1"));
    try std.testing.expectEqualStrings("a_b", sanitizeName(&buf, " a:b. "));
    try std.testing.expectEqualStrings("", sanitizeName(&buf, "..."));
    try std.testing.expectEqualStrings("Pad 1", displayName("Pad 1.vr09"));
    try std.testing.expectEqualStrings("1-1_MassiveOrgDF", displayName("1-1_MassiveOrgDF.json"));
}

test "a preset file round trips through the dump format" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(base);
    var path_buf: [fileio.max_path]u8 = undefined;
    const path = try presetPath(&path_buf, base, "Test");
    var scene = dump.Dump{};
    _ = scene.set(.kb, 0x02 << 14 | 5, 7);
    try savePresetFile(allocator, path, &scene);
    var loaded = dump.Dump{};
    try loadPresetFile(allocator, path, &loaded);
    try std.testing.expectEqual(@as(?u8, 7), loaded.get(.kb, 0x02 << 14 | 5));
}

test "dbToGain" {
    try std.testing.expectEqual(@as(f32, 0), dbToGain(-60));
    try std.testing.expectApproxEqAbs(@as(f32, 1), dbToGain(0), 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5012), dbToGain(-6), 1e-3);
}
