const std = @import("std");
const reaper = @import("../reaper.zig").reaper;
const Allocator = std.mem.Allocator;

pub fn getControllerConfigPath(allocator: *Allocator, controller_name: [*:0]const u8) ![]const u8 {
    const resourcePath = reaper.GetResourcePath();
    const file_name = try std.fmt.allocPrint(allocator, "{s}.json", .{controller_name});
    defer allocator.free(file_name);
    var paths = [_][*:0]const u8{ resourcePath, "Data", "Perken", "Controllers", controller_name };
    const file_path = try std.fs.path.join(allocator, &paths);
    return file_path;
}
