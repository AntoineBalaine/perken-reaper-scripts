const std = @import("std");
const ctrler = @import("controller.zig");
const Controller = ctrler.Controller;
const ControllerConfig = @import("types.zig").ControllerConfig;
const reaper = @import("../reaper.zig").reaper;
const fs_helpers = @import("fs_helpers.zig");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");

const UserSettings = types.UserSettings;

const Module = struct {
    name: []const u8,
    default: []const u8,
    mappings: []const []const u8,
};

const Prefs = struct { modules: []Module, userSettings: UserSettings };

fn buildPaths(allocator: Allocator, controller_name: []const u8) ![]const u8 {
    var configDir: [std.fs.max_path_bytes]u8 = undefined;

    const resourcePath = reaper.GetResourcePath();
    const paths = [_][]const u8{ std.mem.sliceTo(resourcePath, 0), "Data", "Perken", "Controllers", controller_name };

    var len: u8 = 0;
    for (paths, 0..) |path, idx| {
        @memcpy(configDir[len..], path);
        if (idx < paths.len - 1) {
            @memcpy(configDir[len + path.len ..], &[1]u8{std.fs.path.sep});
        }
        len += @intCast(path.len);
    }

    const configFname = try std.mem.concat(allocator, u8, &[_][]const u8{ controller_name[0..len], "_config.ini" });
    defer allocator.free(configFname);
    const controllerConfigPath = try std.fs.path.join(allocator, &[_][]const u8{ &configDir, configFname });
    return controllerConfigPath;
}

const ConfigLoaderError = error{
    NoConfigName,
    FileUnfound,
};

/// return the paths of controller config, default channel strip, and realearn mapping for it.
pub fn load(allocator: Allocator, controller: Controller) ![]const u8 {
    if (std.mem.eql(u8, controller.name, "")) {
        return ConfigLoaderError.NoConfigName;
    }

    const rv = try buildPaths(allocator, controller.name);
    // const channelStripPath = rv[0];
    // const realearnPath = rv[1];
    // const controllerConfigPath = rv[2];

    return rv;
}
