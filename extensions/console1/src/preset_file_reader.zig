const std = @import("std");
const ini = @import("ini");
const StringPool = @import("string_pool").StringPool;

/// Reads preset names from a REAPER user preset INI file.
///
/// The expected file format is:
///   [General]
///   NbPresets=<count>
///
///   [Preset0]
///   Name=<preset name>
///   Data=<hex-encoded plugin state>
///   Len=<byte length of decoded data>
///
///   [Preset1]
///   ...
///
/// We collect all Name values from [PresetN] sections and intern
/// them into the provided StringPool, returning a slice of offsets.
pub fn readPresetNames(allocator: std.mem.Allocator, preset_strings: *StringPool, file_path: [:0]const u8) ![]const StringPool.StringRef {
    const file = std.fs.openFileAbsolute(file_path, .{}) catch |err| {
        if (err == error.FileNotFound) return &.{};
        return err;
    };
    defer file.close();

    var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer temp_arena.deinit();

    var parser = ini.parse(temp_arena.allocator(), file.reader());
    defer parser.deinit();

    var offsets = std.ArrayList(StringPool.StringRef).init(allocator);
    errdefer offsets.deinit();

    var in_preset_section = false;

    while (try parser.next()) |record| {
        switch (record) {
            .section => |header| {
                in_preset_section = std.mem.startsWith(u8, header, "Preset");
            },
            .property => |kv| {
                if (in_preset_section and std.mem.eql(u8, kv.key, "Name") and kv.value.len > 0) {
                    const offset = try preset_strings.intern(allocator, kv.value);
                    try offsets.append(offset);
                }
            },
            .enumeration => {},
        }
    }

    return offsets.toOwnedSlice();
}

pub const PresetData = struct {
    data: [:0]const u8,
    len: u32,
};

/// Groups the preset data fields read from a map file during installation.
pub const MapPresetInfo = struct {
    name: [:0]const u8,
    file: [:0]const u8,
    data: [:0]const u8,
    len: u32,
};

/// Groups the preset data fields that get written to the map file.
/// Used as a parameter when saving a mapping with embedded preset data.
pub const EmbeddedPreset = struct {
    file: [:0]const u8,
    data: [:0]const u8,
    len: u32,
};

/// Reads the Data and Len fields for a specific preset from a REAPER user preset INI file.
/// Returns null if the file doesn't exist or the preset name is not found.
pub fn readPresetData(allocator: std.mem.Allocator, file_path: [:0]const u8, preset_name: [:0]const u8) !?PresetData {
    const file = std.fs.openFileAbsolute(file_path, .{}) catch |err| {
        if (err == error.FileNotFound) return null;
        return err;
    };
    defer file.close();

    var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer temp_arena.deinit();

    var parser = ini.parse(temp_arena.allocator(), file.reader());
    defer parser.deinit();

    var in_preset_section = false;
    var name_matches = false;
    // Because REAPER writes Data before Name in its preset files, we capture
    // the Data value into the temp arena first. We only dupe it into the
    // caller's allocator when we confirm the Name matches.
    var section_data: ?[]const u8 = null;
    var section_len: ?u32 = null;

    while (try parser.next()) |record| {
        switch (record) {
            .section => |header| {
                if (in_preset_section and name_matches and section_data != null) {
                    return PresetData{
                        .data = try allocator.dupeZ(u8, section_data.?),
                        .len = section_len orelse 0,
                    };
                }
                in_preset_section = std.mem.startsWith(u8, header, "Preset");
                name_matches = false;
                section_data = null;
                section_len = null;
            },
            .property => |kv| {
                if (!in_preset_section) continue;
                if (std.mem.eql(u8, kv.key, "Name") and std.mem.eql(u8, kv.value, preset_name)) {
                    name_matches = true;
                } else if (std.mem.eql(u8, kv.key, "Data")) {
                    section_data = try temp_arena.allocator().dupe(u8, kv.value);
                } else if (std.mem.eql(u8, kv.key, "Len")) {
                    section_len = std.fmt.parseInt(u32, kv.value, 10) catch null;
                }
            },
            .enumeration => {},
        }
    }

    if (in_preset_section and name_matches and section_data != null) {
        return PresetData{
            .data = try allocator.dupeZ(u8, section_data.?),
            .len = section_len orelse 0,
        };
    }

    return null;
}

test "readPresetNames: parses well-formed preset INI" {
    const testing = std.testing;

    // Because we need a real file on disk for the INI parser,
    // we write a temporary file
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const content =
        \\[General]
        \\NbPresets=3
        \\[Preset0]
        \\Name=Clean Guitar
        \\Data=ABCDEF
        \\[Preset1]
        \\Name=Distorted Lead
        \\Data=123456
        \\[Preset2]
        \\Name=Ambient Pad
        \\Data=789ABC
    ;
    const file = try tmp_dir.dir.createFile("test_presets.ini", .{});
    try file.writeAll(content);
    file.close();

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const abs_path = try tmp_dir.dir.realpath("test_presets.ini", &path_buf);
    const abs_path_z = try testing.allocator.dupeZ(u8, abs_path);
    defer testing.allocator.free(abs_path_z);

    var preset_strings: StringPool = .empty;
    defer preset_strings.deinit(testing.allocator);

    const offsets = try readPresetNames(testing.allocator, &preset_strings, abs_path_z);
    defer testing.allocator.free(offsets);

    try testing.expectEqual(@as(usize, 3), offsets.len);
    try testing.expectEqualStrings("Clean Guitar", preset_strings.get(offsets[0]));
    try testing.expectEqualStrings("Distorted Lead", preset_strings.get(offsets[1]));
    try testing.expectEqualStrings("Ambient Pad", preset_strings.get(offsets[2]));
}

test "readPresetNames: empty preset file returns empty slice" {
    const testing = std.testing;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const content =
        \\[General]
        \\NbPresets=0
    ;
    const file = try tmp_dir.dir.createFile("empty_presets.ini", .{});
    try file.writeAll(content);
    file.close();

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const abs_path = try tmp_dir.dir.realpath("empty_presets.ini", &path_buf);
    const abs_path_z = try testing.allocator.dupeZ(u8, abs_path);
    defer testing.allocator.free(abs_path_z);

    var preset_strings: StringPool = .empty;
    defer preset_strings.deinit(testing.allocator);

    const offsets = try readPresetNames(testing.allocator, &preset_strings, abs_path_z);
    defer testing.allocator.free(offsets);

    try testing.expectEqual(@as(usize, 0), offsets.len);
}

test "readPresetNames: preset section without Name field is skipped" {
    const testing = std.testing;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const content =
        \\[General]
        \\NbPresets=2
        \\[Preset0]
        \\Name=Valid Preset
        \\Data=ABCDEF
        \\[Preset1]
        \\Data=123456
    ;
    const file = try tmp_dir.dir.createFile("missing_name.ini", .{});
    try file.writeAll(content);
    file.close();

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const abs_path = try tmp_dir.dir.realpath("missing_name.ini", &path_buf);
    const abs_path_z = try testing.allocator.dupeZ(u8, abs_path);
    defer testing.allocator.free(abs_path_z);

    var preset_strings: StringPool = .empty;
    defer preset_strings.deinit(testing.allocator);

    const offsets = try readPresetNames(testing.allocator, &preset_strings, abs_path_z);
    defer testing.allocator.free(offsets);

    // Because Preset1 has no Name field, only one preset should be returned
    try testing.expectEqual(@as(usize, 1), offsets.len);
    try testing.expectEqualStrings("Valid Preset", preset_strings.get(offsets[0]));
}

test "readPresetNames: nonexistent file returns empty slice" {
    const testing = std.testing;

    var preset_strings: StringPool = .empty;
    defer preset_strings.deinit(testing.allocator);

    const offsets = try readPresetNames(testing.allocator, &preset_strings, "/nonexistent/path/to/presets.ini");
    defer testing.allocator.free(offsets);

    try testing.expectEqual(@as(usize, 0), offsets.len);
}

test "readPresetNames: handles Data lines exceeding INI parser line limit" {
    const testing = std.testing;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    // Build a file where Data exceeds the INI parser's 4096-byte line limit,
    // matching the format of REAPER's user preset files (Data before Name).
    const file = try tmp_dir.dir.createFile("long_data.ini", .{});
    try file.writeAll("[General]\nNbPresets=2\n");
    try file.writeAll("[Preset0]\n");
    try file.writeAll("Data=");
    // Write 8000 hex chars (well over the 4096 limit)
    var i: usize = 0;
    while (i < 8000) : (i += 1) {
        try file.writeAll("A");
    }
    try file.writeAll("\nLen=4000\nName=Long Data Preset\n");
    try file.writeAll("[Preset1]\nName=Short Preset\nData=AABB\nLen=2\n");
    file.close();

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const abs_path = try tmp_dir.dir.realpath("long_data.ini", &path_buf);
    const abs_path_z = try testing.allocator.dupeZ(u8, abs_path);
    defer testing.allocator.free(abs_path_z);

    var preset_strings: StringPool = .empty;
    defer preset_strings.deinit(testing.allocator);

    const offsets = try readPresetNames(testing.allocator, &preset_strings, abs_path_z);
    defer testing.allocator.free(offsets);

    // Both presets should be found despite the first one having a too-long Data line
    try testing.expectEqual(@as(usize, 2), offsets.len);
    try testing.expectEqualStrings("Long Data Preset", preset_strings.get(offsets[0]));
    try testing.expectEqualStrings("Short Preset", preset_strings.get(offsets[1]));
}

test "readPresetData: returns matching preset data" {
    const testing = std.testing;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const content =
        \\[General]
        \\NbPresets=2
        \\[Preset0]
        \\Name=First Preset
        \\Data=AABBCCDD
        \\Len=4
        \\[Preset1]
        \\Name=Second Preset
        \\Data=11223344EEFF
        \\Len=6
    ;
    const file = try tmp_dir.dir.createFile("presets_data.ini", .{});
    try file.writeAll(content);
    file.close();

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const abs_path = try tmp_dir.dir.realpath("presets_data.ini", &path_buf);
    const abs_path_z = try testing.allocator.dupeZ(u8, abs_path);
    defer testing.allocator.free(abs_path_z);

    var test_arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer test_arena.deinit();

    const result = try readPresetData(test_arena.allocator(), abs_path_z, "Second Preset");
    try testing.expect(result != null);
    try testing.expectEqualStrings("11223344EEFF", result.?.data);
    try testing.expectEqual(@as(u32, 6), result.?.len);
}

test "readPresetData: returns null for non-matching name" {
    const testing = std.testing;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const content =
        \\[General]
        \\NbPresets=1
        \\[Preset0]
        \\Name=Existing Preset
        \\Data=AABB
        \\Len=2
    ;
    const file = try tmp_dir.dir.createFile("presets_nomatch.ini", .{});
    try file.writeAll(content);
    file.close();

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const abs_path = try tmp_dir.dir.realpath("presets_nomatch.ini", &path_buf);
    const abs_path_z = try testing.allocator.dupeZ(u8, abs_path);
    defer testing.allocator.free(abs_path_z);

    const result = try readPresetData(testing.allocator, abs_path_z, "Nonexistent Preset");
    try testing.expect(result == null);
}

test "readPresetData: returns null for nonexistent file" {
    const testing = std.testing;

    const result = try readPresetData(testing.allocator, "/nonexistent/path/presets.ini", "Some Preset");
    try testing.expect(result == null);
}
