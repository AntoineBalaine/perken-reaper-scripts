//! The library of patches: the rows of the patch table, which hold the keyboard's registrations, its single
//! tones and the player's own presets, and the way a row becomes a patch that an action can carry.
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

const Plugin = plugin.Plugin;

pub const name_cap = 48;
pub const group_cap = 24;
pub const rows_cap = 1024;

const first_tone_value: u32 = 101;
const preset_id_first: u32 = 1000;
const preset_id_span: u32 = 60000;

pub const Kind = enum { registration, tone, preset };

pub const Row = struct {
    kind: Kind,
    key: u64,
    number: [8:0]u8,
    name: [name_cap:0]u8,
    group: [group_cap:0]u8,
    /// The value of the Patch parameter that selects the row.
    value: u32,
    /// The position of the row's source: in the registrations, in the tone list, or in the presets.
    source: usize,
    /// The tone list of a tone: 0 for the pianos, 1 for the synths, 2 for the drum kits.
    list: u8 = 0,
};

/// The rows of the table, in storage of their own because there are several hundred. The patch table keeps one,
/// and rebuilds it when the registrations or the presets have changed (`stale`), and not at every frame.
pub const Library = struct {
    rows: [rows_cap]Row = undefined,
    count: usize = 0,
    /// True until the rows are built, and again when what they list has changed.
    stale: bool = true,
};

fn copyZ(dest: anytype, text: []const u8) void {
    const n = @min(text.len, dest.len);
    @memcpy(dest[0..n], text[0..n]);
    dest[n] = 0;
}

fn hashOf(text: []const u8) u64 {
    return std.hash.Wyhash.hash(0, text);
}

/// The patch ID of a preset: a hash of its name (FNV-1a), brought into the range of the IDs. The same name gives
/// the same ID on every computer, so a template that holds it finds it again.
pub fn presetId(name: []const u8) u32 {
    var h: u32 = 2166136261;
    for (name) |byte| h = (h ^ byte) *% 16777619;
    return preset_id_first + h % preset_id_span;
}

fn addRow(library: *Library, row: Row) void {
    if (library.count == rows_cap) return;
    library.rows[library.count] = row;
    library.count += 1;
}

/// Every patch of the table: the registrations, the tones, and then the player's presets.
pub fn build(p: *Plugin, library: *Library) void {
    library.count = 0;
    library.stale = false;
    const w = &p.ui;
    if (w.reg_library) |lib| {
        for (lib.entries.items, 0..) |entry, i| {
            var row: Row = undefined;
            row.kind = .registration;
            row.source = i;
            row.list = 0;
            var display: [name_cap]u8 = undefined;
            copyZ(&row.name, registrations.displayName(&display, entry.name));
            var number: [8]u8 = undefined;
            copyZ(&row.number, std.fmt.bufPrint(&number, "{d}-{d}", .{ entry.bank, entry.slot }) catch "");
            copyZ(&row.group, "");
            row.value = (@as(u32, entry.bank) - 1) * 4 + entry.slot;
            var key: [24]u8 = undefined;
            row.key = hashOf(std.fmt.bufPrint(&key, "reg{d}", .{i}) catch "reg");
            addRow(library, row);
        }
    }
    var position: u32 = 0;
    const lists = [_][]const tones.Tone{ &tones.piano, &tones.synth, &tones.drum };
    for (lists, 0..) |list, list_index| {
        for (list, 0..) |tone, i| {
            var row: Row = undefined;
            row.kind = .tone;
            row.source = i;
            row.list = @intCast(list_index);
            copyZ(&row.name, tone.name);
            copyZ(&row.number, "");
            copyZ(&row.group, tone.group);
            row.value = first_tone_value + position;
            var key: [24]u8 = undefined;
            row.key = hashOf(std.fmt.bufPrint(&key, "tone{d}-{d}", .{ list_index, i }) catch "tone");
            addRow(library, row);
            position += 1;
        }
    }
    if (w.preset_names) |list| {
        for (list.items, 0..) |file_name, i| {
            var row: Row = undefined;
            row.kind = .preset;
            row.source = i;
            row.list = 0;
            const display = state_files.displayName(file_name);
            copyZ(&row.name, display);
            copyZ(&row.number, "");
            copyZ(&row.group, "USER");
            row.value = presetId(display);
            row.key = hashOf(file_name);
            addRow(library, row);
        }
    }
}

/// Builds the rows again when what they list has changed, and does nothing otherwise.
pub fn ensure(p: *Plugin, library: *Library) void {
    if (library.stale) build(p, library);
}

/// The row with this patch ID, from the last time the rows were built.
pub fn byValue(library: *const Library, value: u32) ?*const Row {
    for (library.rows[0..library.count]) |*row| {
        if (row.value == value) return row;
    }
    return null;
}

pub fn nameOf(row: *const Row) []const u8 {
    return std.mem.sliceTo(&row.name, 0);
}

pub fn groupOf(row: *const Row) []const u8 {
    return std.mem.sliceTo(&row.group, 0);
}

pub fn numberOf(row: *const Row) []const u8 {
    return std.mem.sliceTo(&row.number, 0);
}

pub fn typeOf(row: *const Row) [:0]const u8 {
    return switch (row.kind) {
        .registration => "Registration",
        .tone => "Tone",
        .preset => "Preset",
    };
}

fn toneOf(row: *const Row) *const tones.Tone {
    return switch (row.list) {
        0 => &tones.piano[row.source],
        1 => &tones.synth[row.source],
        else => &tones.drum[row.source],
    };
}

// ---- the patches, from their sources ----

fn registrationPatch(entry: registrations.Entry) types.Patch {
    var display: [name_cap]u8 = undefined;
    const name = types.Text.of(registrations.displayName(&display, entry.name));
    return .{
        .source = .{ .registration = types.Text.of(entry.file_name) },
        .name = name,
        .id = @intCast((@as(u32, entry.bank) - 1) * 4 + entry.slot),
        .label = name,
    };
}

fn presetPatch(file_name: []const u8) types.Patch {
    const name = types.Text.of(state_files.displayName(file_name));
    return .{ .source = .{ .preset = types.Text.of(file_name) }, .name = name, .id = @intCast(presetId(name.slice())), .label = name };
}

/// The tone at a position of one of the lists. The pianos go to the upper piano part and the synths to the upper
/// synth part, and a drum kit is not supported yet.
fn tonePatch(list: u8, i: usize) types.Patch {
    const tone = switch (list) {
        0 => &tones.piano[i],
        1 => &tones.synth[i],
        else => &tones.drum[i],
    };
    const offset: usize = switch (list) {
        0 => 0,
        1 => tones.piano.len,
        else => tones.piano.len + tones.synth.len,
    };
    const name = types.Text.of(tone.name);
    const part: ?[]const u8 = switch (list) {
        0 => "upper_piano",
        1 => "upper_synth",
        else => null,
    };
    return .{
        .source = if (part) |part_name|
            .{ .tone = .{ .part = types.Text.of(part_name), .number = tone.number, .msb = tone.msb, .lsb = tone.lsb } }
        else
            .unsupported,
        .name = name,
        .id = @intCast(first_tone_value + offset + i),
        .label = name,
    };
}

/// The tone with this patch ID, or null when the ID is not one of the tones'. The IDs of the tones follow the
/// order of the pianos, the synths and the drum kits.
pub fn toneById(id: u32) ?types.Patch {
    if (id < first_tone_value) return null;
    var position: usize = id - first_tone_value;
    if (position < tones.piano.len) return tonePatch(0, position);
    position -= tones.piano.len;
    if (position < tones.synth.len) return tonePatch(1, position);
    position -= tones.synth.len;
    if (position < tones.drum.len) return tonePatch(2, position);
    return null;
}

/// The patch that a row stands for, with the source that the dispatcher reads its bytes from.
pub fn patchOf(p: *Plugin, row: *const Row) types.Patch {
    return switch (row.kind) {
        .registration => if (p.ui.reg_library) |lib| registrationPatch(lib.entries.items[row.source]) else unsupported(row),
        .preset => if (p.ui.preset_names) |list| presetPatch(list.items[row.source]) else unsupported(row),
        .tone => tonePatch(row.list, row.source),
    };
}

fn unsupported(row: *const Row) types.Patch {
    const name = types.Text.of(nameOf(row));
    return .{ .source = .unsupported, .name = name, .id = @intCast(row.value), .label = name };
}

/// The patch with this ID, found in the registrations, the tones and the presets themselves, so that a scene
/// template can name its patches by ID without anything having built the table. Null when there is none.
pub fn patchById(p: *Plugin, id: u32) ?types.Patch {
    if (id >= first_tone_value and id < preset_id_first) return toneById(id);
    if (id >= preset_id_first) {
        const list = p.ui.preset_names orelse return null;
        for (list.items) |file_name| {
            if (presetId(state_files.displayName(file_name)) == id) return presetPatch(file_name);
        }
        return null;
    }
    const lib = p.ui.reg_library orelse return null;
    for (lib.entries.items) |entry| {
        if ((@as(u32, entry.bank) - 1) * 4 + entry.slot == id) return registrationPatch(entry);
    }
    return null;
}

test "a preset's ID comes from its name and stays in range" {
    const a = presetId("Warm Pad");
    try std.testing.expectEqual(a, presetId("Warm Pad"));
    try std.testing.expect(a >= preset_id_first and a < preset_id_first + preset_id_span);
    try std.testing.expect(presetId("Warm Pad") != presetId("Warm Pad 2"));
}

test "a tone is found by its ID, in the order of the lists" {
    const first = toneById(101).?;
    try std.testing.expectEqualStrings(tones.piano[0].name, first.name.slice());
    try std.testing.expectEqualStrings("upper_piano", first.source.tone.part.slice());
    const synth = toneById(101 + tones.piano.len).?;
    try std.testing.expectEqualStrings(tones.synth[0].name, synth.name.slice());
    try std.testing.expectEqualStrings("upper_synth", synth.source.tone.part.slice());
    // A drum kit has an ID and a name, and no source that the panel can send.
    const kit = toneById(@intCast(101 + tones.piano.len + tones.synth.len)).?;
    try std.testing.expectEqualStrings(tones.drum[0].name, kit.name.slice());
    try std.testing.expect(kit.source == .unsupported);
    try std.testing.expect(toneById(100) == null);
    try std.testing.expect(toneById(@intCast(101 + tones.piano.len + tones.synth.len + tones.drum.len)) == null);
    try std.testing.expectEqual(@as(u16, 101), first.id);
}

test "every declaration compiles" {
    std.testing.refAllDecls(@This());
}
