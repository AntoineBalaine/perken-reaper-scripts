const std = @import("std");
const reaper = @import("../reaper.zig").reaper;
const Allocator = std.mem.Allocator;
const fs_helpers = @import("fs_helpers.zig");

/// check that realearn can be found in `fxtags.ini`
fn isRealearnInstalled(allocator: Allocator) !bool {
    const resourcePath = reaper.GetResourcePath();
    const file_path = try std.fs.path.join(allocator, &[_][]const u8{ std.mem.span(resourcePath), "reaper-fxtags.ini" });
    defer allocator.free(file_path);
    const fileContents = try fs_helpers.readFile(allocator, file_path);
    defer allocator.free(fileContents);
    const searchString = "realearn";
    var splits = std.mem.splitAny(u8, fileContents, "\n");
    while (splits.next()) |line| {
        var buf: [searchString.len]u8 = undefined;
        _ = std.ascii.lowerString(&buf, line[0..searchString.len]);
        if (std.mem.eql(u8, &buf, searchString)) {
            return true;
        }
    }
    return false;
}

pub const InitError = error{
    RealearnNotInstalled,
};

pub fn init(allocator: Allocator) !void {
    const isInstalled = try isRealearnInstalled(allocator);
    if (!isInstalled) {
        return InitError.RealearnNotInstalled;
    } else {
        std.debug.print("INSTALLED", .{});
    }
}
