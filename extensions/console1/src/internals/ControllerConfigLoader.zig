const std = @import("std");
const ctrler = @import("controller.zig");
const Controller = ctrler.Controller;
const ControllerConfig = @import("types.zig").ControllerConfig;
const reaper = @import("../reaper.zig").reaper;
const fs_helpers = @import("fs_helpers.zig");
const Allocator = std.mem.Allocator;

fn parseJSON(allocator: Allocator, path: []const u8) !std.json.Parsed(ControllerConfig) {
    const data = try std.fs.cwd().readFileAlloc(allocator, path, 512);
    defer allocator.free(data);
    return std.json.parseFromSlice(ControllerConfig, allocator, data, .{ .allocate = .alloc_always });
}

fn buildPaths(allocator: Allocator, controller_name: [*:0]const u8) ![3][]const u8 {
    const controllerConfigDirectory = try fs_helpers.getControllerConfigPath(allocator, controller_name);
    defer allocator.free(controllerConfigDirectory);
    const rfx_extension = ".RfxChain";

    // read the channelStripPath inside the controllerConfigDirectory
    // is it possible to do `controller_name ++ "_channelStrip" ++ rfx_extension;`?
    const chanStripFname = try std.fmt.allocPrint(allocator, "{s}_channelStrip{s}", .{ controller_name, rfx_extension });
    defer allocator.free(chanStripFname);
    const chanStripPath = try std.fs.path.join(allocator, &[_][]const u8{ controllerConfigDirectory, chanStripFname });
    const realearnFname = try std.fmt.allocPrint(allocator, "{s}_realearn{s}", .{ controller_name, rfx_extension });
    defer allocator.free(realearnFname);
    const realearnPath = try std.fs.path.join(allocator, &[_][]const u8{ controllerConfigDirectory, realearnFname });
    const configFname = try std.fmt.allocPrint(allocator, "{s}_config.json", .{controller_name});
    defer allocator.free(configFname);
    const controllerConfigPath = try std.fs.path.join(allocator, &[_][]const u8{ controllerConfigDirectory, configFname });
    return [_][]const u8{ chanStripPath, realearnPath, controllerConfigPath };
}

fn validateConfig(allocator: Allocator, controller_name: [*:0]const u8, controllerConfigPath: []const u8) !std.json.Parsed(ControllerConfig) {
    // read the config
    const config = parseJSON(allocator, controllerConfigPath) catch |err| {
        const msg = "Invalid config file for controller";

        const buf = try std.fmt.allocPrintZ(allocator, "{s} {s}", .{ msg, controller_name, "\n" });
        defer allocator.free(buf);
        _ = reaper.MB(buf, "Error", 0);
        return err;
    };
    return config;
}

const ConfigLoaderError = error{
    NoConfigName,
    FileUnfound,
};

/// return the paths of controller config, default channel strip, and realearn mapping for it.
pub fn load(allocator: Allocator, controller: Controller) !std.json.Parsed(ControllerConfig) {
    if (std.mem.eql(u8, std.mem.span(controller.name), "")) {
        return ConfigLoaderError.NoConfigName;
    }

    const rv = try buildPaths(allocator, controller.name);

    const channelStripPath = rv[0];
    const realearnPath = rv[1];
    const controllerConfigPath = rv[2];
    errdefer {
        allocator.free(channelStripPath);
        allocator.free(realearnPath);
        allocator.free(controllerConfigPath);
    }

    const validatedConfig = try validateConfig(allocator, controller.name, controllerConfigPath);
    defer allocator.free(controllerConfigPath);

    return validatedConfig;
}
