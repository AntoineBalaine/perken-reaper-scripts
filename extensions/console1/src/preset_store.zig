//! REAPER's user presets of a plug-in: the names that the preset file of the plug-in has, and a new preset written into
//! it. REAPER has no call that saves a preset, so the file is written here, in the format that REAPER's own "Save
//! preset" produces:
//!
//!   [General]
//!   NbPresets=2
//!
//!   [Preset0]
//!   Data=<hex of the state><two hex digits of checksum>
//!   Data_1=...                      (only for a state longer than 32768 hex digits)
//!   Name=My preset
//!   Len=<bytes of the state>
//!
//! The state comes from the chunk of the track: the base64 lines of a VST, or the slider line of a JS. The way of doing
//! this was published for REAPER scripts by EUGEN27771 ("Save VST Preset to preset file", Cockos forum, thread 178127),
//! and the checksum and length rules were checked against 1092 of the 1100 presets of a REAPER preset folder.
const std = @import("std");

const Allocator = std.mem.Allocator;

pub const FxKind = enum { vst, js };

/// The part of a track chunk that one plug-in takes: its first line, the lines in between and the closing line.
pub const FxBlock = struct {
    kind: FxKind,
    /// The lines between the first and the last one, trimmed, each without its newline.
    lines: []const []const u8,
};

const hex_digits = "0123456789ABCDEF";

fn appendHex(list: *std.ArrayList(u8), allocator: Allocator, bytes: []const u8) !void {
    for (bytes) |byte| {
        try list.append(allocator, hex_digits[byte >> 4]);
        try list.append(allocator, hex_digits[byte & 0xF]);
    }
}

fn base64Value(char: u8) ?u6 {
    return switch (char) {
        'A'...'Z' => @intCast(char - 'A'),
        'a'...'z' => @intCast(char - 'a' + 26),
        '0'...'9' => @intCast(char - '0' + 52),
        '+' => 62,
        '/' => 63,
        else => null,
    };
}

/// Decodes one line of base64 into the hex digits of its bytes. The line may end with padding.
fn appendBase64AsHex(list: *std.ArrayList(u8), allocator: Allocator, line: []const u8) !void {
    var index: usize = 0;
    while (index < line.len) : (index += 4) {
        const group = line[index..@min(index + 4, line.len)];
        var values: [4]?u6 = .{ null, null, null, null };
        for (group, 0..) |char, position| values[position] = base64Value(char);
        const first = values[0] orelse return error.InvalidBase64;
        const second = values[1] orelse return error.InvalidBase64;
        try appendHex(list, allocator, &.{(@as(u8, first) << 2) | (@as(u8, second) >> 4)});
        if (values[2]) |third| {
            try appendHex(list, allocator, &.{(@as(u8, second) << 4) | (@as(u8, third) >> 2)});
            if (values[3]) |fourth| {
                try appendHex(list, allocator, &.{(@as(u8, third) << 6) | @as(u8, fourth)});
            }
        }
    }
}

/// The last two hex digits of the sum of the bytes, which is how REAPER guards every Data line. A sum below 16 is a
/// single digit, as the scripts that write presets have it and as the files of REAPER do.
pub fn checksum(hex: []const u8, buffer: *[2]u8) []const u8 {
    std.debug.assert(hex.len % 2 == 0);
    var sum: usize = 0;
    var index: usize = 0;
    while (index < hex.len) : (index += 2) {
        sum += std.fmt.parseInt(u8, hex[index .. index + 2], 16) catch unreachable;
    }
    // The sum is written in hex first and the last two digits are kept, so a sum of 0x100 is "00" and one of 5 is "5".
    var full: [20]u8 = undefined;
    const text = std.fmt.bufPrint(&full, "{X}", .{sum}) catch unreachable;
    const kept = text[text.len -| 2..];
    @memcpy(buffer[0..kept.len], kept);
    return buffer[0..kept.len];
}

/// The hex of the state to put in a preset of this plug-in, with `name` as its name. The caller owns the result.
pub fn presetHex(allocator: Allocator, block: FxBlock, name: []const u8) ![]u8 {
    var hex: std.ArrayList(u8) = .empty;
    errdefer hex.deinit(allocator);
    switch (block.kind) {
        .js => {
            // The slider line, with no separator, and then the name.
            for (block.lines) |line| try appendHex(&hex, allocator, line);
            try appendHex(&hex, allocator, name);
        },
        .vst => {
            if (block.lines.len == 0) return error.EmptyChunk;
            // The last line of a VST chunk holds the name of its program, which the name of the preset replaces.
            for (block.lines[0 .. block.lines.len - 1]) |line| try appendBase64AsHex(&hex, allocator, line);
            try appendHex(&hex, allocator, &.{0});
            try appendHex(&hex, allocator, name);
            try hex.appendSlice(allocator, "0010000000");
        },
    }
    return hex.toOwnedSlice(allocator);
}

/// Finds the plug-in at `fx_index` of the FX chain in the chunk of a track. Only a VST (VST3 included) and a JS are
/// known, so null is also what any other kind of plug-in gives. The lines point into the chunk, and the slice of them is
/// owned by the caller.
pub fn extractFxBlock(allocator: Allocator, track_chunk: []const u8, fx_index: usize) !?FxBlock {
    var lines = std.mem.splitScalar(u8, track_chunk, '\n');
    var in_chain = false;
    var depth: usize = 0;
    var current: ?usize = null;
    var fx_count: usize = 0;
    var kind: ?FxKind = null;
    var body: std.ArrayList([]const u8) = .empty;
    errdefer body.deinit(allocator);

    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (!in_chain) {
            if (isBlockStart(line, "FXCHAIN")) {
                in_chain = true;
                depth = 1;
            }
            continue;
        }
        if (line.len > 0 and line[0] == '<') {
            if (depth == 1) {
                current = fx_count;
                fx_count += 1;
                if (current.? == fx_index) {
                    kind = if (isBlockStart(line, "VST")) .vst else if (isBlockStart(line, "JS")) .js else null;
                    if (kind == null) return null;
                }
            }
            depth += 1;
            continue;
        }
        if (std.mem.eql(u8, line, ">")) {
            depth -= 1;
            if (depth == 1 and current != null and current.? == fx_index) {
                return .{ .kind = kind.?, .lines = try body.toOwnedSlice(allocator) };
            }
            if (depth == 0) return null;
            continue;
        }
        if (depth == 2 and current != null and current.? == fx_index) try body.append(allocator, line);
    }
    body.deinit(allocator);
    return null;
}

fn isBlockStart(line: []const u8, name: []const u8) bool {
    if (line.len < 1 + name.len or line[0] != '<') return false;
    if (!std.mem.startsWith(u8, line[1..], name)) return false;
    return line.len == 1 + name.len or line[1 + name.len] == ' ';
}

/// The names of the presets of a preset file, in the order of the file. The slices point into `content`.
pub fn presetNames(allocator: Allocator, content: []const u8) ![]const []const u8 {
    var names: std.ArrayList([]const u8) = .empty;
    errdefer names.deinit(allocator);
    var in_preset = false;
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trimEnd(u8, raw, "\r");
        if (line.len > 0 and line[0] == '[') {
            in_preset = std.mem.startsWith(u8, line, "[Preset");
        } else if (in_preset and std.mem.startsWith(u8, line, "Name=")) {
            try names.append(allocator, line["Name=".len..]);
        }
    }
    return names.toOwnedSlice(allocator);
}

pub fn contains(names: []const []const u8, name: []const u8) bool {
    for (names) |existing| if (std.mem.eql(u8, existing, name)) return true;
    return false;
}

/// The longest run of hex digits on one Data line.
const data_line_length = 32768;

fn appendPresetBlock(out: *std.ArrayList(u8), allocator: Allocator, number: usize, hex: []const u8, name: []const u8) !void {
    try out.print(allocator, "[Preset{d}]\n", .{number});
    var start: usize = 0;
    var part: usize = 0;
    while (start < hex.len) : (part += 1) {
        const end = @min(start + data_line_length, hex.len);
        var sum_buffer: [2]u8 = undefined;
        if (part == 0) try out.appendSlice(allocator, "Data=") else try out.print(allocator, "Data_{d}=", .{part});
        try out.appendSlice(allocator, hex[start..end]);
        try out.appendSlice(allocator, checksum(hex[start..end], &sum_buffer));
        try out.append(allocator, '\n');
        start = end;
    }
    try out.print(allocator, "Name={s}\nLen={d}\n", .{ name, hex.len / 2 });
}

/// The content of the preset file after the preset `name` was written to it: the preset of that name is replaced, or a
/// new one is added at the end. `existing` is the content of the file, or null when there is none. The caller owns
/// the result.
pub fn withPreset(allocator: Allocator, existing: ?[]const u8, name: []const u8, hex: []const u8) ![]u8 {
    std.debug.assert(name.len > 0 and std.mem.indexOfAny(u8, name, "\r\n") == null);
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    const content = existing orelse {
        try out.appendSlice(allocator, "[General]\nNbPresets=1\n\n");
        try appendPresetBlock(&out, allocator, 0, hex, name);
        return out.toOwnedSlice(allocator);
    };

    // Split into blocks that start with a [section] line, keeping the text of each as it is.
    const Block = struct { text: []const u8, preset_number: ?usize, name: ?[]const u8 };
    var blocks: std.ArrayList(Block) = .empty;
    defer blocks.deinit(allocator);
    var start: usize = 0;
    var cursor: usize = 0;
    while (cursor <= content.len) {
        const line_end = std.mem.indexOfScalarPos(u8, content, cursor, '\n') orelse content.len;
        const line = std.mem.trimEnd(u8, content[cursor..line_end], "\r");
        const is_header = line.len > 0 and line[0] == '[';
        if (is_header and cursor > start) {
            try blocks.append(allocator, .{ .text = content[start..cursor], .preset_number = null, .name = null });
            start = cursor;
        }
        cursor = line_end + 1;
    }
    if (start < content.len) try blocks.append(allocator, .{ .text = content[start..], .preset_number = null, .name = null });
    for (blocks.items) |*block| {
        const header_end = std.mem.indexOfScalar(u8, block.text, '\n') orelse block.text.len;
        const header = std.mem.trimEnd(u8, block.text[0..header_end], "\r");
        if (std.mem.startsWith(u8, header, "[Preset") and header.len > "[Preset]".len - 1) {
            block.preset_number = std.fmt.parseInt(usize, header["[Preset".len .. header.len - 1], 10) catch null;
            var block_lines = std.mem.splitScalar(u8, block.text, '\n');
            while (block_lines.next()) |raw| {
                const line = std.mem.trimEnd(u8, raw, "\r");
                if (std.mem.startsWith(u8, line, "Name=")) block.name = line["Name=".len..];
            }
        }
    }

    var preset_count: usize = 0;
    var replaced = false;
    for (blocks.items) |block| if (block.preset_number != null) {
        preset_count += 1;
    };
    for (blocks.items) |block| {
        if (block.preset_number) |number| {
            if (block.name != null and std.mem.eql(u8, block.name.?, name)) {
                try appendPresetBlock(&out, allocator, number, hex, name);
                try out.append(allocator, '\n');
                replaced = true;
                continue;
            }
        }
        if (std.mem.startsWith(u8, block.text, "[General]") and !replaced) {
            // The count is written when the new preset is known to be added, below.
            try out.appendSlice(allocator, block.text);
            continue;
        }
        try out.appendSlice(allocator, block.text);
    }
    if (replaced) return out.toOwnedSlice(allocator);

    // A new preset: it goes at the end, and the count in [General] goes up.
    if (out.items.len > 0 and out.items[out.items.len - 1] != '\n') try out.append(allocator, '\n');
    if (out.items.len > 0 and !std.mem.endsWith(u8, out.items, "\n\n")) try out.append(allocator, '\n');
    try appendPresetBlock(&out, allocator, preset_count, hex, name);
    const updated = try setPresetCount(allocator, out.items, preset_count + 1);
    out.deinit(allocator);
    return updated;
}

/// Rewrites the `NbPresets=` line of [General], or adds the section when the file has none.
fn setPresetCount(allocator: Allocator, content: []const u8, count: usize) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var found = false;
    var lines = std.mem.splitScalar(u8, content, '\n');
    var first = true;
    while (lines.next()) |line| {
        if (!first) try out.append(allocator, '\n');
        first = false;
        if (std.mem.startsWith(u8, line, "NbPresets=")) {
            try out.print(allocator, "NbPresets={d}", .{count});
            found = true;
        } else {
            try out.appendSlice(allocator, line);
        }
    }
    if (found) return out.toOwnedSlice(allocator);
    out.clearRetainingCapacity();
    try out.print(allocator, "[General]\nNbPresets={d}\n\n", .{count});
    try out.appendSlice(allocator, content);
    return out.toOwnedSlice(allocator);
}

// Tests -------------------------------------------------------------------------------------------------------------

const testing = std.testing;

test "the checksum is the last two hex digits of the sum of the bytes" {
    var buffer: [2]u8 = undefined;
    // 0x2D + 0x20 = 0x4D
    try testing.expectEqualStrings("4D", checksum("2D20", &buffer));
    try testing.expectEqualStrings("00", checksum("FF01", &buffer));
    // A sum below 16 is a single digit, as in the files of REAPER.
    try testing.expectEqualStrings("5", checksum("0203", &buffer));
    try testing.expectEqualStrings("0", checksum("", &buffer));
}

test "a JS preset is the slider line and the name, as REAPER saves it" {
    // The first preset of REAPER's js-guitar_chorus.ini: "SuperSaw", Len 182, a slider line and then the name.
    const dashes = comptime blk: {
        var bytes: [58 * 2]u8 = undefined;
        for (0..58) |i| {
            bytes[2 * i] = '-';
            bytes[2 * i + 1] = ' ';
        }
        break :blk bytes;
    };
    const sliders = "12.000000 5.000000 0.900000 1.000000 0.000000 -100.000000 " ++ dashes;
    const hex = try presetHex(testing.allocator, .{ .kind = .js, .lines = &.{sliders} }, "SuperSaw");
    defer testing.allocator.free(hex);
    try testing.expectEqual(@as(usize, 182 * 2), hex.len);
    try testing.expect(std.mem.startsWith(u8, hex, "31322E3030303030302035"));
    try testing.expect(std.mem.endsWith(u8, hex, "5375706572536177"));
}

test "a VST preset is the decoded lines of the chunk, with the name in place of the last line" {
    // "AAEC" is 00 01 02, "AwQF" is 03 04 05, and the last line is replaced.
    const hex = try presetHex(testing.allocator, .{ .kind = .vst, .lines = &.{ "AAEC", "AwQF", "ignored==" } }, "Pad");
    defer testing.allocator.free(hex);
    try testing.expectEqualStrings("000102030405" ++ "00" ++ "506164" ++ "0010000000", hex);
}

test "base64 with padding decodes to the right number of bytes" {
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(testing.allocator);
    try appendBase64AsHex(&list, testing.allocator, "TWE="); // "Ma"
    try appendBase64AsHex(&list, testing.allocator, "TQ=="); // "M"
    try testing.expectEqualStrings("4D614D", list.items);
}

const sample_chunk =
    \\<TRACK
    \\NAME "Bass"
    \\<FXCHAIN
    \\SHOW 0
    \\LASTSEL 1
    \\<JS "Cockos/guitar_chorus" ""
    \\1.5 2 - - -
    \\>
    \\<VST "VST: ReaComp (Cockos)" reacomp.vst.so 0 "" 1919247213<5653> ""
    \\AAEC
    \\AwQF
    \\UHJvZw==
    \\>
    \\<CLAP "CLAP: Something" x 0 ""
    \\AAAA
    \\>
    \\>
    \\<FXCHAIN_REC
    \\<JS "other" ""
    \\9 9
    \\>
    \\>
    \\>
;

test "the plug-ins of the chain are found by their position, and other kinds are not known" {
    const first = (try extractFxBlock(testing.allocator, sample_chunk, 0)).?;
    defer testing.allocator.free(first.lines);
    try testing.expectEqual(FxKind.js, first.kind);
    try testing.expectEqual(@as(usize, 1), first.lines.len);
    try testing.expectEqualStrings("1.5 2 - - -", first.lines[0]);

    const second = (try extractFxBlock(testing.allocator, sample_chunk, 1)).?;
    defer testing.allocator.free(second.lines);
    try testing.expectEqual(FxKind.vst, second.kind);
    try testing.expectEqual(@as(usize, 3), second.lines.len);

    try testing.expectEqual(@as(?FxBlock, null), try extractFxBlock(testing.allocator, sample_chunk, 2));
    try testing.expectEqual(@as(?FxBlock, null), try extractFxBlock(testing.allocator, sample_chunk, 3));
}

test "the names of a preset file are listed in order" {
    const content = "[General]\nNbPresets=2\n\n[Preset0]\nData=00\nName=First one\nLen=0\n\n[Preset1]\nName=Second\nData=0\nLen=0\n";
    const names = try presetNames(testing.allocator, content);
    defer testing.allocator.free(names);
    try testing.expectEqual(@as(usize, 2), names.len);
    try testing.expectEqualStrings("First one", names[0]);
    try testing.expectEqualStrings("Second", names[1]);
    try testing.expect(contains(names, "Second"));
    try testing.expect(!contains(names, "Third"));
}

test "a preset written to a new file makes the file REAPER expects" {
    const written = try withPreset(testing.allocator, null, "Mine", "0102");
    defer testing.allocator.free(written);
    try testing.expectEqualStrings("[General]\nNbPresets=1\n\n[Preset0]\nData=01023\nName=Mine\nLen=2\n", written);
}

test "a new preset is added at the end and the count goes up" {
    const content = "[General]\nNbPresets=1\n\n[Preset0]\nData=0A0A14\nName=Old\nLen=2\n";
    const written = try withPreset(testing.allocator, content, "New", "FF");
    defer testing.allocator.free(written);
    try testing.expectEqualStrings(
        "[General]\nNbPresets=2\n\n[Preset0]\nData=0A0A14\nName=Old\nLen=2\n\n[Preset1]\nData=FFFF\nName=New\nLen=1\n",
        written,
    );
    const names = try presetNames(testing.allocator, written);
    defer testing.allocator.free(names);
    try testing.expect(contains(names, "Old") and contains(names, "New"));
}

test "a preset of an existing name is replaced in place" {
    const content = "[General]\nNbPresets=2\n\n[Preset0]\nData=01\nName=A\nLen=1\n\n[Preset1]\nData=02\nName=B\nLen=1\n";
    const written = try withPreset(testing.allocator, content, "A", "0303");
    defer testing.allocator.free(written);
    try testing.expect(std.mem.indexOf(u8, written, "NbPresets=2") != null);
    try testing.expect(std.mem.indexOf(u8, written, "Data=03036\nName=A\nLen=2") != null);
    try testing.expect(std.mem.indexOf(u8, written, "Data=02\nName=B\nLen=1") != null);
    const names = try presetNames(testing.allocator, written);
    defer testing.allocator.free(names);
    try testing.expectEqual(@as(usize, 2), names.len);
}

test "a state longer than one Data line is split, and every line has its checksum" {
    const hex = try testing.allocator.alloc(u8, data_line_length + 4);
    defer testing.allocator.free(hex);
    @memset(hex, '1');
    const written = try withPreset(testing.allocator, null, "Big", hex);
    defer testing.allocator.free(written);
    try testing.expect(std.mem.indexOf(u8, written, "\nData_1=1111") != null);
    try testing.expect(std.mem.indexOf(u8, written, "Len=16386") != null);
}
