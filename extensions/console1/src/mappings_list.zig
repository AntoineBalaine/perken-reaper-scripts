const std = @import("std");
const ModulesList = @import("statemachine.zig").ModulesList;
const log = std.log.scoped(.mapping_list);
const ini = @import("ini");
const fs_helpers = @import("fs_helpers.zig");
const StringPool = @import("string_pool.zig").StringPool;

// Store hierarchical FX names with their mapping names using StringPool offsets
// Keys are FX name offsets (u32), values are arrays of mapping name offsets ([]u32)
// Using ArrayHashMap to maintain insertion order for scrolling/indexing
list: std.EnumArray(ModulesList, std.ArrayHashMapUnmanaged(u32, []u32, std.array_hash_map.AutoContext(u32), false)),
strings: StringPool,

pub fn empty(arena: std.mem.Allocator) @This() {
    return .{
        .list = std.EnumArray(ModulesList, std.ArrayHashMapUnmanaged(u32, []u32, std.array_hash_map.AutoContext(u32), false)).init(.{
            .INPUT = .empty,
            .GATE = .empty,
            .EQ = .empty,
            .COMP = .empty,
            .OUTPT = .empty,
        }),
        .strings = StringPool.init(arena),
    };
}

pub fn init(arena: std.mem.Allocator, resource_path: [:0]const u8) @This() {
    var strings = StringPool.init(arena);
    var list = std.EnumArray(ModulesList, std.ArrayHashMapUnmanaged(u32, []u32, std.array_hash_map.AutoContext(u32), false)).initUndefined();

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    var fx_dir_buffer: [std.fs.max_path_bytes]u8 = undefined;
    inline for (comptime std.enums.values(ModulesList)) |module| {
        inline_blk: {
            list.set(module, .empty);

            const module_path = fs_helpers.joinStrings(&path_buffer, &.{
                resource_path,
                std.fs.path.sep_str,
                "maps",
                std.fs.path.sep_str,
                @tagName(module),
            });

            var module_dir = std.fs.openDirAbsolute(module_path, .{ .iterate = true }) catch {
                break :inline_blk;
            };
            defer module_dir.close();

            var module_iter = module_dir.iterate();
            while (module_iter.next() catch break :inline_blk) |fx_entry| {
                // Each subdirectory is an FX name
                if (fx_entry.kind != .directory) continue;

                // Open FX subdirectory to scan for mapping files
                // Use separate buffer to avoid aliasing with module_path
                const fx_dir_path = fs_helpers.joinStrings(&fx_dir_buffer, &.{
                    module_path,
                    std.fs.path.sep_str,
                    fx_entry.name,
                });

                var fx_dir = std.fs.openDirAbsolute(fx_dir_path, .{ .iterate = true }) catch continue;
                defer fx_dir.close();

                // Read the actual FX name from the first .ini file we find
                // This ensures we use the REAPER FX name, not the directory name
                var actual_fx_name_z: ?[:0]const u8 = null;

                // Collect mapping offsets temporarily
                var mapping_offsets = std.ArrayList(u32).init(arena);
                defer mapping_offsets.deinit();

                var fx_iter = fx_dir.iterate();
                while (fx_iter.next() catch break) |mapping_entry| {
                    if (mapping_entry.kind == .file and std.mem.endsWith(u8, mapping_entry.name, ".ini")) {
                        // Extract mapping name without .ini extension
                        const mapping_name_slice = mapping_entry.name[0 .. mapping_entry.name.len - 4];

                        // Create null-terminated string and intern it
                        var name_buf: [256:0]u8 = undefined;
                        const mapping_name = std.fmt.bufPrintZ(&name_buf, "{s}", .{mapping_name_slice}) catch continue;

                        // Intern mapping name and store offset
                        const mapping_offset = strings.intern(mapping_name) catch continue;
                        mapping_offsets.append(mapping_offset) catch continue;

                        // If we haven't read the FX name yet, read it from this .ini file
                        if (actual_fx_name_z == null) {
                            const ini_path = fs_helpers.joinStrings(&path_buffer, &.{
                                fx_dir_path,
                                std.fs.path.sep_str,
                                mapping_entry.name,
                            });

                            const ini_file = std.fs.openFileAbsolute(ini_path, .{}) catch continue;
                            defer ini_file.close();

                            // Parse the INI file to get fx_name
                            var parser = ini.parse(arena, ini_file.reader());
                            defer parser.deinit();

                            while (parser.next() catch null) |record| {
                                if (record == .property and std.mem.eql(u8, record.property.key, "fx_name")) {
                                    actual_fx_name_z = arena.dupeZ(u8, record.property.value) catch continue;
                                    break;
                                }
                            }
                        }
                    }
                }

                // If we couldn't read fx_name from ini files, skip this FX directory
                const fx_name_z = actual_fx_name_z orelse continue;

                // Intern the actual FX name from the ini file
                const fx_offset = strings.intern(fx_name_z) catch continue;

                // Build slice of mapping offsets and store in arena
                const mapping_offsets_slice = arena.dupe(u32, mapping_offsets.items) catch continue;

                // Insert into hashmap with offsets
                list.getPtr(module).put(arena, fx_offset, mapping_offsets_slice) catch {
                    log.warn("Mappings list: Failed to store fx {s} with {} mappings", .{ fx_name_z, mapping_offsets_slice.len });
                    continue;
                };
            }
        }
    }

    return .{
        .list = list,
        .strings = strings,
    };
}

pub fn deinit(self: *@This()) void {
    self.strings.deinit();
    inline for (comptime std.enums.values(ModulesList)) |module| {
        self.list.getPtr(module).deinit(self.strings.arena.allocator());
    }
}

test "StringPool offsets remain valid after buffer reallocation" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var strings = StringPool.init(allocator);
    defer strings.deinit();

    // Intern multiple strings to force buffer reallocation
    var offsets = std.ArrayList(u32).init(allocator);
    defer offsets.deinit();

    const test_strings = [_][:0]const u8{
        "JS: RBJ Highpass/Lowpass Filters",
        "JS: Volume Adjustment",
        "JS: Volume/Pan Smoother v5",
        "VST: ReaComp (Cockos)",
        "VST: ReaEQ (Cockos)",
        "VST: ReaGate (Cockos)",
        "JS: ReaAnalog",
        "JS: Saturation",
    };

    // Store all offsets
    for (test_strings) |str| {
        const offset = try strings.intern(str);
        try offsets.append(offset);
    }

    // Verify all strings can be retrieved correctly using their offsets
    for (test_strings, 0..) |expected, i| {
        const actual = strings.get(offsets.items[i]);
        try testing.expectEqualStrings(expected, actual);
    }
}

test "mappings_list stores FX names with slashes correctly" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var strings = StringPool.init(allocator);
    defer strings.deinit();

    var list = std.ArrayHashMapUnmanaged(u32, []u32, std.array_hash_map.AutoContext(u32), false){};
    defer list.deinit(allocator);

    // Test that FX names with slashes are stored correctly
    const fx_names = [_][:0]const u8{
        "JS: Volume/Pan Smoother v5",
        "JS: RBJ Highpass/Lowpass Filters",
    };

    var stored_offsets = std.ArrayList(u32).init(allocator);
    defer stored_offsets.deinit();

    for (fx_names) |fx_name| {
        const fx_offset = try strings.intern(fx_name);
        try stored_offsets.append(fx_offset);

        // Create dummy mapping offsets
        const mapping_offset = try strings.intern("default");
        const mapping_offsets = try allocator.alloc(u32, 1);
        mapping_offsets[0] = mapping_offset;

        try list.put(allocator, fx_offset, mapping_offsets);
    }

    // Verify we can retrieve FX names correctly
    try testing.expectEqual(@as(usize, 2), list.count());

    for (fx_names, 0..) |expected_name, i| {
        const fx_offset = stored_offsets.items[i];
        const actual_name = strings.get(fx_offset);
        try testing.expectEqualStrings(expected_name, actual_name);

        // Verify it's in the map
        try testing.expect(list.contains(fx_offset));
    }

    // Clean up mapping arrays
    var it = list.iterator();
    while (it.next()) |entry| {
        allocator.free(entry.value_ptr.*);
    }
}
