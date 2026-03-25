const std = @import("std");
const ini = @import("ini");
const StringPool = @import("string_pool.zig").StringPool;

/// Reads preset names from a REAPER user preset INI file.
/// The file format has [General] with NbPresets, and [PresetN] sections
/// each containing a Name= field. We collect all Name values and intern
/// them into the provided StringPool, returning a slice of offsets.
pub fn readPresetNames(allocator: std.mem.Allocator, preset_strings: *StringPool, file_path: [:0]const u8) ![]const u32 {
    const file = std.fs.openFileAbsolute(file_path, .{}) catch |err| {
        if (err == error.FileNotFound) return &.{};
        return err;
    };
    defer file.close();

    var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer temp_arena.deinit();

    var parser = ini.parse(temp_arena.allocator(), file.reader());
    defer parser.deinit();

    var offsets = std.ArrayList(u32).init(allocator);
    errdefer offsets.deinit();

    var in_preset_section = false;

    while (try parser.next()) |record| {
        switch (record) {
            .section => |header| {
                in_preset_section = std.mem.startsWith(u8, header, "Preset");
            },
            .property => |kv| {
                if (in_preset_section and std.mem.eql(u8, kv.key, "Name") and kv.value.len > 0) {
                    const sentinel_value = @as([:0]const u8, @ptrCast(kv.value.ptr[0..kv.value.len :0]));
                    const offset = try preset_strings.intern(sentinel_value);
                    try offsets.append(offset);
                }
            },
            .enumeration => {},
        }
    }

    return offsets.toOwnedSlice();
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
    const abs_path_z = @as([:0]const u8, @ptrCast(abs_path.ptr[0..abs_path.len :0]));

    var preset_strings = StringPool.init(testing.allocator);
    defer preset_strings.deinit();

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
    const abs_path_z = @as([:0]const u8, @ptrCast(abs_path.ptr[0..abs_path.len :0]));

    var preset_strings = StringPool.init(testing.allocator);
    defer preset_strings.deinit();

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
    const abs_path_z = @as([:0]const u8, @ptrCast(abs_path.ptr[0..abs_path.len :0]));

    var preset_strings = StringPool.init(testing.allocator);
    defer preset_strings.deinit();

    const offsets = try readPresetNames(testing.allocator, &preset_strings, abs_path_z);
    defer testing.allocator.free(offsets);

    // Because Preset1 has no Name field, only one preset should be returned
    try testing.expectEqual(@as(usize, 1), offsets.len);
    try testing.expectEqualStrings("Valid Preset", preset_strings.get(offsets[0]));
}

test "readPresetNames: nonexistent file returns empty slice" {
    const testing = std.testing;

    var preset_strings = StringPool.init(testing.allocator);
    defer preset_strings.deinit();

    const offsets = try readPresetNames(testing.allocator, &preset_strings, "/nonexistent/path/to/presets.ini");
    defer testing.allocator.free(offsets);

    try testing.expectEqual(@as(usize, 0), offsets.len);
}
