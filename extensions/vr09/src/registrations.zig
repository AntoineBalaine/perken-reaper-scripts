//! The library of the keyboard's Registrations: dumps named
//! `<bank>-<slot>_<Name>.json`, as the roland-vr09 project stores them.
const std = @import("std");
const fileio = @import("fileio.zig");

pub const extension = ".json";
pub const slots_per_bank = 4;

pub const Entry = struct {
    bank: u8,
    slot: u8,
    /// The file name, with its extension.
    file_name: []u8,
    /// The part of the file name after the underscore, without extension.
    name: []const u8,
};

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
    if (bank == 0 or slot == 0 or slot > slots_per_bank) return null;
    return .{ .bank = bank, .slot = slot, .name = stem[under + 1 ..] };
}

/// Orders by bank, then slot: "10-1" comes after "9-4", which a plain
/// comparison of the file names would not do.
pub fn lessEntry(_: void, a: Entry, b: Entry) bool {
    if (a.bank != b.bank) return a.bank < b.bank;
    return a.slot < b.slot;
}

/// The name for display: underscores read as spaces.
pub fn displayName(buf: []u8, name: []const u8) []const u8 {
    const n = @min(buf.len, name.len);
    for (name[0..n], 0..) |c, i| buf[i] = if (c == '_') ' ' else c;
    return buf[0..n];
}

pub const Library = struct {
    entries: std.ArrayList(Entry),

    pub fn deinit(self: *Library, allocator: std.mem.Allocator) void {
        for (self.entries.items) |e| allocator.free(e.file_name);
        self.entries.deinit();
    }
};

/// Lists the registrations of `folder`, sorted. A missing folder gives an
/// empty library.
pub fn scan(allocator: std.mem.Allocator, folder: []const u8) !Library {
    var files = try fileio.listFiles(allocator, folder, &.{extension});
    defer fileio.freeList(allocator, &files);
    var lib = Library{ .entries = std.ArrayList(Entry).init(allocator) };
    errdefer lib.deinit(allocator);
    for (files.items) |file_name| {
        const parsed = parseFileName(file_name) orelse continue;
        const owned = try allocator.dupe(u8, file_name);
        errdefer allocator.free(owned);
        try lib.entries.append(.{
            .bank = parsed.bank,
            .slot = parsed.slot,
            .file_name = owned,
            .name = owned[owned.len - extension.len - parsed.name.len .. owned.len - extension.len],
        });
    }
    std.mem.sort(Entry, lib.entries.items, {}, lessEntry);
    return lib;
}

/// The patch name of a registration, "<bank>-<slot> <Name>", under which its
/// split is remembered.
pub fn patchName(buf: []u8, entry: Entry) []const u8 {
    return std.fmt.bufPrint(buf, "{d}-{d} {s}", .{ entry.bank, entry.slot, entry.name }) catch entry.name;
}

/// Whether the entry matches the filter typed by the user (case-insensitive,
/// on the name or on "bank-slot").
pub fn matches(entry: Entry, filter: []const u8) bool {
    if (filter.len == 0) return true;
    if (std.ascii.indexOfIgnoreCase(entry.name, filter) != null) return true;
    var key: [16]u8 = undefined;
    const text = std.fmt.bufPrint(&key, "{d}-{d}", .{ entry.bank, entry.slot }) catch return false;
    return std.ascii.indexOfIgnoreCase(text, filter) != null;
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
    try std.testing.expect(parseFileName("1-1_Name.vr09") == null);
    try std.testing.expect(parseFileName("x-1_Name.json") == null);
}

test "registrations are ordered by bank then slot" {
    var entries = [_]Entry{
        .{ .bank = 10, .slot = 1, .file_name = &.{}, .name = "" },
        .{ .bank = 2, .slot = 4, .file_name = &.{}, .name = "" },
        .{ .bank = 2, .slot = 1, .file_name = &.{}, .name = "" },
        .{ .bank = 1, .slot = 3, .file_name = &.{}, .name = "" },
    };
    std.mem.sort(Entry, &entries, {}, lessEntry);
    try std.testing.expectEqual(@as(u8, 1), entries[0].bank);
    try std.testing.expectEqual(@as(u8, 1), entries[1].slot);
    try std.testing.expectEqual(@as(u8, 4), entries[2].slot);
    try std.testing.expectEqual(@as(u8, 10), entries[3].bank);
}

test "the filter matches the name or the position" {
    const e = Entry{ .bank = 12, .slot = 3, .file_name = &.{}, .name = "DIMPnooBrill" };
    try std.testing.expect(matches(e, ""));
    try std.testing.expect(matches(e, "pnoo"));
    try std.testing.expect(matches(e, "12-3"));
    try std.testing.expect(!matches(e, "organ"));
}

test "a registration is named for the split list" {
    var file = "2-1_Sweet_Dream.json".*;
    const entry = Entry{ .bank = 2, .slot = 1, .file_name = &file, .name = "Sweet_Dream" };
    var buf: [96]u8 = undefined;
    try std.testing.expectEqualStrings("2-1 Sweet_Dream", patchName(&buf, entry));
}

test "display names read underscores as spaces" {
    var buf: [32]u8 = undefined;
    try std.testing.expectEqualStrings("Follow you", displayName(&buf, "Follow_you"));
}

test "a folder is scanned and sorted" {
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    for ([_][]const u8{ "10-1_B.json", "2-1_A.json", "verify.json", "2-2_C.vr09" }) |n| {
        try tmp.dir.writeFile(.{ .sub_path = n, .data = "{}" });
    }
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const folder = try tmp.dir.realpath(".", &path_buf);
    var lib = try scan(allocator, folder);
    defer lib.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 2), lib.entries.items.len);
    try std.testing.expectEqualStrings("A", lib.entries.items[0].name);
    try std.testing.expectEqualStrings("B", lib.entries.items[1].name);
}
