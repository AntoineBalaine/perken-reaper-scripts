const std = @import("std");
const fs_helpers = @import("fs_helpers.zig");
const ModulesList = @import("statemachine.zig").ModulesList;
const testing = std.testing;

/// Get all mapping file paths for a given FX by reading the directory on disk.
/// Returns a list of mapping names (without .ini extension) owned by the caller.
pub fn getMappingNames(
    allocator: std.mem.Allocator,
    controller_dir: [*:0]const u8,
    fx_name: [:0]const u8,
    module: ModulesList,
) ![][:0]const u8 {
    var name_buf: [512:0]u8 = undefined;
    const sanitized_name = try fs_helpers.sanitizeFxName(&name_buf, fx_name);

    var dir_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = fs_helpers.joinStrings(&dir_path_buf, &.{
        std.mem.span(controller_dir),
        std.fs.path.sep_str,
        "maps",
        std.fs.path.sep_str,
        @tagName(module),
        std.fs.path.sep_str,
        sanitized_name,
    });

    // Because the directory might not exist, we handle that case
    var dir = std.fs.openDirAbsolute(dir_path, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) {
            return &[_][:0]const u8{};
        }
        return err;
    };
    defer dir.close();

    var list = std.ArrayList([:0]const u8).init(allocator);
    errdefer list.deinit();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .file) {
            // Remove .ini extension
            if (std.mem.endsWith(u8, entry.name, ".ini")) {
                const name_without_ext = entry.name[0 .. entry.name.len - 4];
                const owned_name = try allocator.dupeZ(u8, name_without_ext);
                try list.append(owned_name);
            }
        }
    }

    return list.toOwnedSlice();
}

test "getMappingNames - returns empty list for FX with no mappings" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var mem: [std.fs.max_path_bytes]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);
    const config_path = try std.fs.path.resolve(allocator, &.{ pth, "src/resources/" });
    const config_path_z = try allocator.dupeZ(u8, config_path);

    const nonexistent_fx = "VST: NonexistentPlugin";
    const names = try getMappingNames(allocator, config_path_z, nonexistent_fx, .COMP);
    defer allocator.free(names);

    try testing.expectEqual(@as(usize, 0), names.len);
}

test "getMappingNames - returns correct list of mapping files" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var mem: [std.fs.max_path_bytes]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);
    const config_path = try std.fs.path.resolve(allocator, &.{ pth, "src/resources/" });
    const config_path_z = try allocator.dupeZ(u8, config_path);

    const test_fx = "VST: ReaComp (Cockos)";

    const names = try getMappingNames(allocator, config_path_z, test_fx, .COMP);
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
