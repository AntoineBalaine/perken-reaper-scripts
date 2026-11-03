const std = @import("std");
const MappingsList = @import("mappings_list.zig");
const ModulesList = @import("statemachine.zig").ModulesList;
const testing = std.testing;

/// Get all mapping names for a given FX by querying the MappingsList index.
/// Returns a list of mapping names (without .ini extension) owned by the caller.
pub fn getMappingNames(
    allocator: std.mem.Allocator,
    mappings_list: *MappingsList,
    fx_name: [:0]const u8,
    module: ModulesList,
) ![][:0]const u8 {
    const mod_map = mappings_list.list.getPtr(module);

    // Because StringPool does not deduplicate, we search by string value
    var iter = mod_map.iterator();
    while (iter.next()) |map_entry| {
        const stored_fx_name = mappings_list.strings.get(map_entry.key_ptr.*);
        if (std.mem.eql(u8, stored_fx_name, fx_name)) {
            var list: std.ArrayList([:0]const u8) = .empty;
            errdefer list.deinit(allocator);

            for (map_entry.value_ptr.items) |entry| {
                const name = mappings_list.strings.get(entry.name_offset);
                const owned_name = try allocator.dupeSentinel(u8, name, 0);
                try list.append(allocator, owned_name);
            }

            return list.toOwnedSlice(allocator);
        }
    }

    return &[_][:0]const u8{};
}

test "getMappingNames - returns empty list for FX with no mappings" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var mem: [std.fs.max_path_bytes]u8 = undefined;
    const pth = mem[0..try std.Io.Dir.cwd().realPathFile(io, ".", &mem)];
    const config_path = try std.fs.path.resolve(allocator, &.{ pth, "src/resources/" });
    const config_path_z = try allocator.dupeSentinel(u8, config_path, 0);

    var ml = MappingsList.init(allocator, io, config_path_z);
    _ = &ml;

    const nonexistent_fx = "VST: NonexistentPlugin";
    const names = try getMappingNames(allocator, &ml, nonexistent_fx, .COMP);
    defer allocator.free(names);

    try testing.expectEqual(@as(usize, 0), names.len);
}

test "getMappingNames - returns correct list of mapping files" {
    const io = std.testing.io;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var mem: [std.fs.max_path_bytes]u8 = undefined;
    const pth = mem[0..try std.Io.Dir.cwd().realPathFile(io, ".", &mem)];
    const config_path = try std.fs.path.resolve(allocator, &.{ pth, "src/resources/" });
    const config_path_z = try allocator.dupeSentinel(u8, config_path, 0);

    var ml = MappingsList.init(allocator, io, config_path_z);
    _ = &ml;

    const test_fx = "VST: ReaComp (Cockos)";

    const names = try getMappingNames(allocator, &ml, test_fx, .COMP);
    defer {
        for (names) |name| {
            allocator.free(name);
        }
        allocator.free(names);
    }

    // Because the default mapping exists, we should have at least one mapping
    try testing.expect(names.len >= 1);

    // Verify "default" is in the list
    var found_default = false;
    for (names) |name| {
        if (std.mem.eql(u8, name, "default")) {
            found_default = true;
            break;
        }
    }
    try testing.expect(found_default);
}
