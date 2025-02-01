const std = @import("std");
const reaper = @import("../reaper.zig").reaper;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.fs_helpers);

/// caller must free
pub fn getControllerConfigPath(allocator: Allocator, controller_name: [*:0]const u8) ![]const u8 {
    const resourcePath = reaper.GetResourcePath();
    const paths = [_][]const u8{ std.mem.sliceTo(resourcePath, 0), "Data", "Perken", "Controllers", std.mem.span(controller_name) };
    const file_path = try std.fs.path.join(allocator, &paths);
    return file_path;
}

/// caller must free
pub fn getControllerPath(allocator: Allocator) ![*:0]const u8 {
    const resourcePath = reaper.GetResourcePath();
    const paths = [_][]const u8{ std.mem.sliceTo(resourcePath, 0), "Data", "Perken", "Console1" };

    return try std.fs.path.joinZ(allocator, &paths);
}

test getControllerPath {
    const some_struct = struct {
        pub fn mockResourcePath() callconv(.C) [*:0]const u8 {
            return "home/perken/.config/REAPER/";
        }
    };
    reaper.GetResourcePath = &some_struct.mockResourcePath;

    const allocator = std.testing.allocator;
    const path = try getControllerPath(allocator);
    defer allocator.free(std.mem.span(path));

    const actual: [*:0]const u8 = "home/perken/.config/REAPER/Data/Perken/Console1";
    std.testing.expect(std.mem.eql(u8, std.mem.span(path), std.mem.span(actual))) catch |err| {
        log.err("expected {s}, found {s}\n", .{ actual, path });
        return err;
    };
}

pub fn joinStrings(buffer: []u8, strings: []const []const u8) ![]const u8 {
    var path_list = std.ArrayListUnmanaged(u8).initBuffer(buffer);
    for (strings) |s| {
        path_list.appendSliceAssumeCapacity(s);
    }
    return path_list.items;
}

test "joinStrings" {
    const testing = std.testing;

    var buffer: [100]u8 = undefined;
    const result = try joinStrings(&buffer, &.{ "hello", "world" });
    try testing.expectEqualStrings("helloworld", result);

    const result2 = try joinStrings(&buffer, &.{ "path", "/", "to", "/", "file" });
    try testing.expectEqualStrings("path/to/file", result2);
}
