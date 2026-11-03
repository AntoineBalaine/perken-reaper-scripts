//! The library of the keyboard's Registrations: dumps named
//! `<bank>-<slot>_<Name>.json`, as the roland-vr09 project stores them.
const std = @import("std");
const fileio = @import("fileio.zig");

pub const extension = ".json";
pub const slots_per_bank = 4;
/// The keyboard has 25 banks of 4 registrations. A file of a higher bank would have a patch value that belongs
/// to the tones, so it is not a registration.
pub const max_banks = 25;

pub const Parsed = struct { bank: u8, slot: u8, name: []const u8 };

/// Reads `<bank>-<slot>_<Name>.json`. Other files of the same folder (scans,
/// checks) do not have this shape and give null. Underscores in the name
/// become spaces only when the entry is shown, not here.
pub fn parseFileName(file_name: []const u8) ?Parsed {
    if (!fileio.hasExtension(file_name, &.{extension})) return null;
    const stem = file_name[0 .. file_name.len - extension.len];
    const dash = std.mem.indexOfScalar(u8, stem, '-') orelse return null;
    const under = std.mem.indexOfScalarPos(u8, stem, dash, '_') orelse return null;
    const bank = std.fmt.parseInt(u8, stem[0..dash], 10) catch return null;
    const slot = std.fmt.parseInt(u8, stem[dash + 1 .. under], 10) catch return null;
    if (bank == 0 or bank > max_banks or slot == 0 or slot > slots_per_bank) return null;
    return .{ .bank = bank, .slot = slot, .name = stem[under + 1 ..] };
}

/// The value of the Patch parameter that selects a registration, which is its position in the keyboard's banks:
/// "1-1" is 1 and "25-4" is 100.
pub fn patchValue(parsed: Parsed) u32 {
    return (@as(u32, parsed.bank) - 1) * slots_per_bank + parsed.slot;
}

/// The name for display: underscores read as spaces.
pub fn displayName(buf: [:0]u8, name: []const u8) [:0]const u8 {
    const n = @min(buf.len, name.len);
    for (name[0..n], 0..) |c, i| buf[i] = if (c == '_') ' ' else c;
    buf[n] = 0;
    return buf[0..n :0];
}

/// The patch name of a registration, "<bank>-<slot> <Name>", under which its
/// split is remembered.
pub fn patchName(buf: []u8, parsed: Parsed) []const u8 {
    return std.fmt.bufPrint(buf, "{d}-{d} {s}", .{ parsed.bank, parsed.slot, parsed.name }) catch parsed.name;
}

test "registration file names are parsed" {
    const p = parseFileName("10-3_BrassOrgan.json").?;
    try std.testing.expectEqual(@as(u8, 10), p.bank);
    try std.testing.expectEqual(@as(u8, 3), p.slot);
    try std.testing.expectEqualStrings("BrassOrgan", p.name);
    try std.testing.expectEqualStrings("Nylon-Grande", parseFileName("4-2_Nylon-Grande.json").?.name);
    try std.testing.expectEqualStrings("Band5__9", parseFileName("18-1_Band5__9.json").?.name);
    try std.testing.expect(parseFileName("scan_panel11.json") == null);
    try std.testing.expect(parseFileName("reg1.json") == null);
    try std.testing.expect(parseFileName("1-5_TooHigh.json") == null);
    try std.testing.expect(parseFileName("0-1_Zero.json") == null);
    try std.testing.expect(parseFileName("26-1_TooHigh.json") == null);
    try std.testing.expect(parseFileName("25-4_Last.json") != null);
    try std.testing.expect(parseFileName("1-1_Name.vr09") == null);
    try std.testing.expect(parseFileName("x-1_Name.json") == null);
}

test "a registration is selected by its position in the banks" {
    try std.testing.expectEqual(@as(u32, 1), patchValue(parseFileName("1-1_A.json").?));
    try std.testing.expectEqual(@as(u32, 8), patchValue(parseFileName("2-4_A.json").?));
    try std.testing.expectEqual(@as(u32, 37), patchValue(parseFileName("10-1_A.json").?));
}

test "a registration is named for the split list" {
    var buf: [96]u8 = undefined;
    try std.testing.expectEqualStrings("2-1 Sweet_Dream", patchName(&buf, parseFileName("2-1_Sweet_Dream.json").?));
}

test "display names read underscores as spaces" {
    var buf: [32:0]u8 = undefined;
    try std.testing.expectEqualStrings("Follow you", displayName(&buf, "Follow_you"));
}
