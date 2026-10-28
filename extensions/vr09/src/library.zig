//! The library of patches: the rows of the patch table, which hold the keyboard's registrations, its single
//! tones and the player's own presets, and the way a row becomes a patch that an action can carry.
//!
//! A row holds no text. Its name, its group, its number and its file name are IDs in the plugin's strings (see
//! `strings.zig`), where each distinct text is stored once, so that a row takes a few bytes and the table takes
//! as much memory as it has rows.
//!
//! The plugin reads the registrations folder and the presets folder once, the first time something needs the
//! rows (the panel is drawn, or a scene template looks for a patch), and keeps the rows until it is destroyed.
//! When the plugin saves or deletes a preset, it adds or removes that one row, so that the rows stay as the
//! folder is. The folders are read again only when the player presses the Refresh button, because a file that
//! was added by hand is not seen otherwise.
//!
//! Because a performer picks a sound by name, the registrations and the single tones share one table. A row has
//! a value, the one of the plugin's Patch parameter that would select it, and a value never changes once
//! given: the registrations take 1 to 100, the tones take 101 and up in the order of `tones.zig`, which only
//! grows at its end, and the presets take an ID that comes from their name. A scene template holds these values.
const std = @import("std");
const plugin = @import("plugin.zig");
const registrations = @import("registrations.zig");
const tones = @import("tones.zig");
const state_files = @import("state.zig");
const types = @import("action_types.zig");
const strings = @import("strings.zig");
const fileio = @import("fileio.zig");
const glue = @import("reaper_glue.zig");

const Plugin = plugin.Plugin;

const first_tone_value: u32 = 101;
const preset_id_first: u32 = 1000;
const preset_id_span: u32 = 60000;

pub const Kind = enum { registration, tone, preset };

pub const Row = struct {
    kind: Kind,
    /// The tone list of a tone: 0 for the pianos, 1 for the synths, 2 for the drum kits.
    list: u8 = 0,
    /// The value of the Patch parameter that selects the row. It is also what identifies the row.
    value: u32,
    /// The position of a tone in its list. The other rows have 0.
    tone_index: u32 = 0,
    name: strings.Ref,
    group: strings.Ref,
    number: strings.Ref,
    /// The file name of a registration or a preset, and the empty text for a tone.
    file: strings.Ref,
};

/// The rows of the table. The plugin owns one.
pub const Library = struct {
    rows: std.ArrayListUnmanaged(Row) = .empty,
    /// How many of the rows are registrations, so that the panel can say when the folder is missing.
    registration_count: u32 = 0,
    /// False until the folders have been read the first time.
    built: bool = false,

    pub fn deinit(self: *Library, allocator: std.mem.Allocator) void {
        self.rows.deinit(allocator);
    }
};

/// The patch ID of a preset: a hash of its name (FNV-1a), brought into the range of the IDs. The same name gives
/// the same ID on every computer, so a template that holds it finds it again.
pub fn presetId(name: []const u8) u32 {
    var h: u32 = 2166136261;
    for (name) |byte| h = (h ^ byte) *% 16777619;
    return preset_id_first + h % preset_id_span;
}

// ---- the rows, from their sources ----

fn registrationRow(p: *Plugin, parsed: registrations.Parsed, file_name: [:0]const u8) Row {
    var display: [strings.max_text:0]u8 = undefined;
    var number: [8:0]u8 = undefined;
    return .{
        .kind = .registration,
        .value = registrations.patchValue(parsed),
        .name = p.strings.intern(registrations.displayName(&display, parsed.name)),
        .group = strings.empty,
        .number = p.strings.intern(std.fmt.bufPrintZ(&number, "{d}-{d}", .{ parsed.bank, parsed.slot }) catch ""),
        .file = p.strings.intern(file_name),
    };
}

fn toneRow(p: *Plugin, list: u8, i: usize) Row {
    const tone = toneOf(list, i);
    return .{
        .kind = .tone,
        .list = list,
        .value = first_tone_value + @as(u32, @intCast(toneOffset(list) + i)),
        .tone_index = @intCast(i),
        .name = p.strings.intern(tone.name),
        .group = p.strings.intern(tone.group),
        .number = strings.empty,
        .file = strings.empty,
    };
}

fn presetRow(p: *Plugin, file_name: [:0]const u8) Row {
    var buf: [strings.max_text:0]u8 = undefined;
    const display = displayZ(&buf, file_name);
    return .{
        .kind = .preset,
        .value = presetId(display),
        .name = p.strings.intern(display),
        .group = p.strings.intern("USER"),
        .number = strings.empty,
        .file = p.strings.intern(file_name),
    };
}

/// The name of a preset file without its extension. Because the cut leaves no terminator after the name, the
/// name is copied to the buffer, with one.
fn displayZ(buf: *[strings.max_text:0]u8, file_name: []const u8) [:0]const u8 {
    const name = state_files.displayName(file_name);
    const n = @min(name.len, strings.max_text);
    @memcpy(buf[0..n], name[0..n]);
    buf[n] = 0;
    return buf[0..n :0];
}

fn toneOf(list: u8, i: usize) *const tones.Tone {
    return switch (list) {
        0 => &tones.piano[i],
        1 => &tones.synth[i],
        else => &tones.drum[i],
    };
}

/// How many tones come before the first of a list in the order of the IDs: the pianos, the synths, the drum
/// kits.
fn toneOffset(list: u8) usize {
    return switch (list) {
        0 => 0,
        1 => tones.piano.len,
        else => tones.piano.len + tones.synth.len,
    };
}

fn lessName(_: void, a: [:0]u8, b: [:0]u8) bool {
    return std.ascii.lessThanIgnoreCase(a, b);
}

fn lessValue(_: void, a: Row, b: Row) bool {
    return a.value < b.value;
}

/// Adds a row for each registration file of `folder`, in the order of the keyboard's banks. Because "10-1" comes
/// after "9-4", the order is the one of the values, and not the one of the file names. The files that do not have
/// the shape of a registration (the scans and the checks) are left out.
pub fn appendRegistrations(p: *Plugin, library: *Library, folder: []const u8) void {
    var files = fileio.listFiles(plugin.allocator, folder, &.{registrations.extension}) catch return;
    defer fileio.freeList(plugin.allocator, &files);
    const first = library.rows.items.len;
    for (files.items) |file_name| {
        const parsed = registrations.parseFileName(file_name) orelse continue;
        library.rows.append(plugin.allocator, registrationRow(p, parsed, file_name)) catch break;
    }
    std.mem.sort(Row, library.rows.items[first..], {}, lessValue);
    library.registration_count = @intCast(library.rows.items.len - first);
}

/// A value for a preset that no other preset has. The value that comes from the name is taken as it is, unless
/// another preset already has it, as two files of the same name do (`Pad.vr09` and `Pad.json`), or as two names
/// that hash to the same number do. Then the next free value of the presets' range is used. Because a value
/// identifies its row, in the table and in a scene template, two rows must never share one.
fn uniquePresetValue(others: []const Row, wanted: u32) u32 {
    var value = wanted;
    var tries: u32 = 0;
    while (tries < preset_id_span) : (tries += 1) {
        var taken = false;
        for (others) |row| {
            if (row.kind == .preset and row.value == value) {
                taken = true;
                break;
            }
        }
        if (!taken) return value;
        value = preset_id_first + (value - preset_id_first + 1) % preset_id_span;
    }
    return value;
}

/// Adds a row for each preset file of `folder`, in the order of their names. Because the rows keep the file names
/// as IDs in the strings, the list of the files is freed as soon as the rows are made.
pub fn appendPresets(p: *Plugin, library: *Library, folder: []const u8) void {
    var files = fileio.listFiles(plugin.allocator, folder, &state_files.preset_extensions) catch return;
    defer fileio.freeList(plugin.allocator, &files);
    std.mem.sort([:0]u8, files.items, {}, lessName);
    for (files.items) |file_name| {
        var row = presetRow(p, file_name);
        row.value = uniquePresetValue(library.rows.items, row.value);
        library.rows.append(plugin.allocator, row) catch return;
    }
}

/// Reads the registrations and the presets, and makes every row of the table: the registrations, the tones, and
/// then the player's presets. `rows` calls it the first time, and the Refresh button calls it again.
pub fn build(p: *Plugin, library: *Library) void {
    library.rows.clearRetainingCapacity();
    library.registration_count = 0;
    library.built = true;
    var buf: [fileio.max_path]u8 = undefined;
    if (glue.ready) {
        if (state_files.registrationFolder(&buf, glue.resourcePath())) |folder| appendRegistrations(p, library, folder) else |_| {}
    }
    const lists = [_][]const tones.Tone{ &tones.piano, &tones.synth, &tones.drum };
    for (lists, 0..) |list, list_index| {
        for (0..list.len) |i| library.rows.append(plugin.allocator, toneRow(p, @intCast(list_index), i)) catch return;
    }
    if (glue.ready) {
        if (state_files.presetFolder(&buf, glue.resourcePath())) |folder| appendPresets(p, library, folder) else |_| {}
    }
}

/// The rows of the table, which are read from the folders the first time they are asked for.
pub fn rows(p: *Plugin) []const Row {
    if (!p.library.built) build(p, &p.library);
    return p.library.rows.items;
}

/// Adds the row of a preset that the plugin has just written. The row goes where the order of the names puts it
/// among the presets, and nothing is added when the file already has a row, because saving over a preset leaves
/// its row as it was. Nothing is done before the first read, which finds the file by itself.
pub fn addPreset(p: *Plugin, file_name: [:0]const u8) void {
    const library = &p.library;
    if (!library.built) return;
    var row = presetRow(p, file_name);
    for (library.rows.items) |existing| {
        if (existing.kind == .preset and existing.file == row.file) return;
    }
    row.value = uniquePresetValue(library.rows.items, row.value);
    var at = library.rows.items.len;
    for (library.rows.items, 0..) |existing, i| {
        if (existing.kind != .preset) continue;
        if (std.ascii.lessThanIgnoreCase(p.strings.get(row.name), p.strings.get(existing.name))) {
            at = i;
            break;
        }
    }
    library.rows.insert(plugin.allocator, at, row) catch {};
}

/// Takes out the row of a preset that the plugin has just deleted.
pub fn removePreset(p: *Plugin, file_name: []const u8) void {
    const library = &p.library;
    for (library.rows.items, 0..) |row, i| {
        if (row.kind == .preset and std.mem.eql(u8, p.strings.get(row.file), file_name)) {
            _ = library.rows.orderedRemove(i);
            return;
        }
    }
}

// ---- the patches ----

/// The patch that a row stands for, with the source that the dispatcher reads its bytes from. The pianos go to
/// the upper piano part and the synths to the upper synth part, and a drum kit is not supported yet.
pub fn patchOf(p: *Plugin, row: Row) types.Patch {
    const source: types.PatchSource = switch (row.kind) {
        .registration => .{ .registration = row.file },
        .preset => .{ .preset = row.file },
        .tone => blk: {
            const part = switch (row.list) {
                0 => "upper_piano",
                1 => "upper_synth",
                else => break :blk .unsupported,
            };
            const tone = toneOf(row.list, row.tone_index);
            break :blk .{ .tone = .{ .part = p.strings.intern(part), .number = tone.number, .msb = tone.msb, .lsb = tone.lsb } };
        },
    };
    return .{ .source = source, .name = row.name, .id = @intCast(row.value), .label = row.name };
}

/// The row with this patch ID, found in the rows of the table, or null when there is none. A scene template
/// names its patches by these IDs.
pub fn rowById(p: *Plugin, id: u32) ?Row {
    for (rows(p)) |row| {
        if (row.value == id) return row;
    }
    return null;
}

/// The patch with this ID, or null.
pub fn patchById(p: *Plugin, id: u32) ?types.Patch {
    const row = rowById(p, id) orelse return null;
    return patchOf(p, row);
}

pub fn typeName(row: Row) [:0]const u8 {
    return switch (row.kind) {
        .registration => "Registration",
        .tone => "Tone",
        .preset => "Preset",
    };
}

test "a preset's ID comes from its name and stays in range" {
    const a = presetId("Warm Pad");
    try std.testing.expectEqual(a, presetId("Warm Pad"));
    try std.testing.expect(a >= preset_id_first and a < preset_id_first + preset_id_span);
    try std.testing.expect(presetId("Warm Pad") != presetId("Warm Pad 2"));
}

test "a row is small, because it holds IDs and no text" {
    try std.testing.expect(@sizeOf(Row) <= 32);
}

test "the IDs of the tones follow the order of the lists" {
    try std.testing.expectEqual(@as(usize, 0), toneOffset(0));
    try std.testing.expectEqual(tones.piano.len, toneOffset(1));
    try std.testing.expectEqual(tones.piano.len + tones.synth.len, toneOffset(2));
}

test "every declaration compiles" {
    std.testing.refAllDecls(@This());
}
