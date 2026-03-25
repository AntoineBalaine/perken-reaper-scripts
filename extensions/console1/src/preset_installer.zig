const std = @import("std");
const ini = @import("ini");
const preset_file_reader = @import("preset_file_reader.zig");
const MappingsList = @import("mappings_list.zig");
const log = std.log.scoped(.mappings);

pub const InstallResult = struct {
    installed: u32 = 0,
    skipped: u32 = 0,
    files_written: u32 = 0,
};

/// Reads the fx_preset, fx_preset_file, fx_preset_data, and fx_preset_len fields
/// from a map file. Returns null if any of the preset data fields are missing.
pub fn readMapPresetInfo(allocator: std.mem.Allocator, map_file_path: [:0]const u8) !?preset_file_reader.MapPresetInfo {
    const file = std.fs.openFileAbsolute(map_file_path, .{}) catch |err| {
        if (err == error.FileNotFound) return null;
        return err;
    };
    defer file.close();

    var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer temp_arena.deinit();

    var parser = ini.parse(temp_arena.allocator(), file.reader());
    defer parser.deinit();

    // Because the INI parser's kv.value points into the parser's internal buffer
    // which is freed when temp_arena is deinitialized, we must dupe the values
    // during parsing rather than after the loop ends.
    var found_name: ?[:0]const u8 = null;
    var found_file: ?[:0]const u8 = null;
    var found_data: ?[:0]const u8 = null;
    var found_len: ?u32 = null;

    while (try parser.next()) |record| {
        switch (record) {
            .property => |kv| {
                if (std.mem.eql(u8, kv.key, "fx_preset")) {
                    found_name = try allocator.dupeZ(u8, kv.value);
                } else if (std.mem.eql(u8, kv.key, "fx_preset_file")) {
                    found_file = try allocator.dupeZ(u8, kv.value);
                } else if (std.mem.eql(u8, kv.key, "fx_preset_data")) {
                    found_data = try allocator.dupeZ(u8, kv.value);
                } else if (std.mem.eql(u8, kv.key, "fx_preset_len")) {
                    found_len = std.fmt.parseInt(u32, kv.value, 10) catch null;
                }
            },
            .section => {},
            .enumeration => {},
        }
    }

    // Because all four fields must be present for the preset data to be usable,
    // we return null if any is missing. We must also free any already-allocated
    // strings to avoid leaks.
    if (found_name == null or found_file == null or found_data == null) {
        if (found_name) |n| allocator.free(n);
        if (found_file) |f| allocator.free(f);
        if (found_data) |d| allocator.free(d);
        return null;
    }

    return preset_file_reader.MapPresetInfo{
        .name = found_name.?,
        .file = found_file.?,
        .data = found_data.?,
        .len = found_len orelse 0,
    };
}

/// Installs embedded presets from map files into REAPER's preset directory.
/// For each FX in the mappings list, we collect embedded preset data from map files,
/// deduplicate against existing presets in the target REAPER preset file, and append
/// any new ones.
pub fn installPresets(
    allocator: std.mem.Allocator,
    mappings_list: *MappingsList,
    preset_dir: [:0]const u8,
) !InstallResult {
    var result = InstallResult{};

    // Because MappingsList organizes mappings as EnumArray(ModulesList, ModuleMap)
    // where ModuleMap = ArrayHashMap(fx_name_offset -> ArrayList(MapEntry)),
    // we iterate through all modules and their FX entries.
    inline for (comptime std.enums.values(@import("statemachine.zig").ModulesList)) |module| {
        const module_map = mappings_list.list.getPtr(module);
        var fx_iter = module_map.iterator();

        while (fx_iter.next()) |fx_entry| {
            const mapping_entries = fx_entry.value_ptr.items;

            // Phase 1: collect hashes and map paths for this FX
            var hash_to_path = std.AutoHashMap(u64, [:0]const u8).init(allocator);
            defer hash_to_path.deinit();

            var preset_filename: ?[:0]const u8 = null;

            for (mapping_entries) |entry| {
                const map_path = mappings_list.strings.get(entry.path_offset);
                const info = readMapPresetInfo(allocator, map_path) catch continue orelse continue;
                defer allocator.free(info.name);
                defer allocator.free(info.file);

                const data_hash = std.hash.Wyhash.hash(0, info.data);
                hash_to_path.put(data_hash, map_path) catch continue;

                if (preset_filename == null) {
                    preset_filename = allocator.dupeZ(u8, info.file) catch continue;
                }

                allocator.free(info.data);
            }

            if (hash_to_path.count() == 0) continue;

            const pf = preset_filename orelse continue;
            defer allocator.free(pf);

            // Phase 2: deduplicate against existing preset file
            var target_path_buf: [std.fs.max_path_bytes:0]u8 = undefined;
            const target_path = std.fmt.bufPrintZ(&target_path_buf, "{s}/{s}", .{ preset_dir, pf }) catch continue;

            var existing_count: u32 = 0;
            if (std.fs.openFileAbsolute(target_path, .{})) |existing_file| {
                defer existing_file.close();

                var parse_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                defer parse_arena.deinit();

                var parser = ini.parse(parse_arena.allocator(), existing_file.reader());
                defer parser.deinit();

                var in_preset_section = false;
                var section_data: ?[]const u8 = null;

                while (parser.next() catch null) |record| {
                    switch (record) {
                        .section => |header| {
                            // Because we need to hash the previous section's data before
                            // moving on, we process it here
                            if (in_preset_section) {
                                if (section_data) |sd| {
                                    const h = std.hash.Wyhash.hash(0, sd);
                                    if (hash_to_path.contains(h)) {
                                        _ = hash_to_path.remove(h);
                                        result.skipped += 1;
                                    }
                                }
                            }
                            in_preset_section = std.mem.startsWith(u8, header, "Preset");
                            section_data = null;
                        },
                        .property => |kv| {
                            if (in_preset_section and std.mem.eql(u8, kv.key, "Data")) {
                                section_data = kv.value;
                            }
                            if (std.mem.eql(u8, kv.key, "NbPresets")) {
                                existing_count = std.fmt.parseInt(u32, kv.value, 10) catch 0;
                            }
                        },
                        .enumeration => {},
                    }
                }
                // Because the last section has no following header, we process it here
                if (in_preset_section) {
                    if (section_data) |sd| {
                        const h = std.hash.Wyhash.hash(0, sd);
                        if (hash_to_path.contains(h)) {
                            _ = hash_to_path.remove(h);
                            result.skipped += 1;
                        }
                    }
                }
            } else |_| {}

            if (hash_to_path.count() == 0) continue;

            // Phase 3: append new presets
            appendPresetsToFile(allocator, target_path, &hash_to_path, &existing_count, &result) catch |err| {
                log.err("Failed to append presets to {s}: {}", .{ target_path, err });
                continue;
            };
        }
    }

    return result;
}

fn appendPresetsToFile(
    allocator: std.mem.Allocator,
    target_path: [:0]const u8,
    hash_to_path: *std.AutoHashMap(u64, [:0]const u8),
    existing_count: *u32,
    result: *InstallResult,
) !void {
    // Because we need to update NbPresets in [General], we read the existing content,
    // append new sections, and rewrite the file
    var content = std.ArrayList(u8).init(allocator);
    defer content.deinit();

    // Read existing content if the file exists
    if (std.fs.openFileAbsolute(target_path, .{})) |existing_file| {
        defer existing_file.close();
        const stat = try existing_file.stat();
        try content.ensureTotalCapacity(@intCast(stat.size + 4096));
        var buf: [4096]u8 = undefined;
        while (true) {
            const n = try existing_file.read(&buf);
            if (n == 0) break;
            try content.appendSlice(buf[0..n]);
        }
    } else |_| {
        // Because the file doesn't exist, we create the [General] header
        try content.appendSlice("[General]\nNbPresets=0\n");
    }

    // Append new preset sections
    var new_count: u32 = 0;
    var iter = hash_to_path.iterator();
    while (iter.next()) |entry| {
        const map_path = entry.value_ptr.*;
        const info = readMapPresetInfo(allocator, map_path) catch continue orelse continue;
        defer allocator.free(info.name);
        defer allocator.free(info.file);
        defer allocator.free(info.data);

        var section_buf: [64]u8 = undefined;
        const section_header = std.fmt.bufPrint(&section_buf, "\n[Preset{d}]\n", .{existing_count.*}) catch continue;
        try content.appendSlice(section_header);
        try content.writer().print("Name={s}\n", .{info.name});
        try content.writer().print("Data={s}\n", .{info.data});
        try content.writer().print("Len={d}\n", .{info.len});
        existing_count.* += 1;
        new_count += 1;
        result.installed += 1;
    }

    if (new_count == 0) return;

    // Update NbPresets in the content buffer
    const nb_presets_key = "NbPresets=";
    if (std.mem.indexOf(u8, content.items, nb_presets_key)) |pos| {
        const value_start = pos + nb_presets_key.len;
        // Find the end of the current value (next newline)
        const value_end = std.mem.indexOfScalarPos(u8, content.items, value_start, '\n') orelse content.items.len;
        // Replace the old value with the new count
        var count_buf: [16]u8 = undefined;
        const count_str = std.fmt.bufPrint(&count_buf, "{d}", .{existing_count.*}) catch return;
        try content.replaceRange(value_start, value_end - value_start, count_str);
    }

    // Create parent directory if needed
    if (std.fs.path.dirname(target_path)) |dir_path| {
        std.fs.makeDirAbsolute(dir_path) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };
    }

    // Write the complete file
    const out_file = try std.fs.createFileAbsolute(target_path, .{ .truncate = true });
    defer out_file.close();
    try out_file.writeAll(content.items);

    result.files_written += 1;
}

test "readMapPresetInfo: returns data from map with embedded preset" {
    const testing = std.testing;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const content =
        \\version=1
        \\module=COMP
        \\fx_name=VST: ReaComp (Cockos)
        \\fx_preset=My Preset
        \\Comp_Thresh=0
        \\fx_preset_file=vst-reacomp.ini
        \\fx_preset_data=AABBCCDD
        \\fx_preset_len=4
    ;
    const file = try tmp_dir.dir.createFile("test_map.ini", .{});
    try file.writeAll(content);
    file.close();

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const abs_path = try tmp_dir.dir.realpath("test_map.ini", &path_buf);
    const abs_path_z = try testing.allocator.dupeZ(u8, abs_path);
    defer testing.allocator.free(abs_path_z);

    const maybe_info = try readMapPresetInfo(testing.allocator, abs_path_z);
    try testing.expect(maybe_info != null);
    const info = maybe_info.?;
    defer testing.allocator.free(info.name);
    defer testing.allocator.free(info.file);
    defer testing.allocator.free(info.data);

    try testing.expectEqualStrings("My Preset", info.name);
    try testing.expectEqualStrings("vst-reacomp.ini", info.file);
    try testing.expectEqualStrings("AABBCCDD", info.data);
    try testing.expectEqual(@as(u32, 4), info.len);
}

test "readMapPresetInfo: returns null when preset data is missing" {
    const testing = std.testing;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const content =
        \\version=1
        \\module=COMP
        \\fx_name=VST: ReaComp (Cockos)
        \\fx_preset=My Preset
        \\Comp_Thresh=0
    ;
    const file = try tmp_dir.dir.createFile("no_data_map.ini", .{});
    try file.writeAll(content);
    file.close();

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const abs_path = try tmp_dir.dir.realpath("no_data_map.ini", &path_buf);
    const abs_path_z = try testing.allocator.dupeZ(u8, abs_path);
    defer testing.allocator.free(abs_path_z);

    const info = try readMapPresetInfo(testing.allocator, abs_path_z);
    try testing.expect(info == null);
}

test "readMapPresetInfo: returns null for nonexistent file" {
    const testing = std.testing;

    const info = try readMapPresetInfo(testing.allocator, "/nonexistent/path/map.ini");
    try testing.expect(info == null);
}
