const std = @import("std");
const ctrler = @import("controller.zig");
const Controller = ctrler.Controller;
const ControllerConfig = @import("types.zig").ControllerConfig;
const reaper = @import("../reaper.zig").reaper;
const fs_helpers = @import("fs_helpers.zig");
const Allocator = std.mem.Allocator;

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

const ConfigLoaderError = error{
    NoConfigName,
    FileUnfound,
};

/// return the paths of controller config, default channel strip, and realearn mapping for it.
pub fn load(allocator: Allocator, controller: Controller) ![3][]const u8 {
    if (std.mem.eql(u8, std.mem.span(controller.name), "")) {
        return ConfigLoaderError.NoConfigName;
    }

    const rv = try buildPaths(allocator, controller.name);
    //
    // const channelStripPath = rv[0];
    // const realearnPath = rv[1];
    // const controllerConfigPath = rv[2];

    return rv;
}
