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

fn buildPaths(allocator: *Allocator, controller_name: [*:0]const u8) ![3][*:0]const u8 {
    const controllerConfigDirectory = fs_helpers.getControllerConfigPath(allocator, controller_name);
    defer allocator.free(controllerConfigDirectory);
    const rfx_extension = ".RfxChain";

    // read the channelStripPath inside the controllerConfigDirectory
    // is it possible to do `controller_name ++ "_channelStrip" ++ rfx_extension;`?
    const chanStripFname = try std.fmt.allocPrint(allocator, "{s}_channelStrip{s}", .{ controller_name, rfx_extension });
    defer allocator.free(chanStripFname);
    const chanStripPath = try std.fs.path.join(allocator, &[_][*:0]const u8{ controllerConfigDirectory, chanStripFname });
    const realearnFname = try std.fmt.allocPrint(allocator, "{s}_realearn{s}", .{ controller_name, rfx_extension });
    defer allocator.free(realearnFname);
    const realearnPath = try std.fs.path.join(allocator, &[_][*:0]const u8{ controllerConfigDirectory, realearnFname });
    const configFname = try std.fmt.allocPrint(allocator, "{s}_config.json", .{controller_name});
    defer allocator.free(configFname);
    const configPath = try std.fs.path.join(allocator, &[_][*:0]const u8{ controllerConfigDirectory, configFname });
    return [_][*:0]const u8{ chanStripPath, realearnPath, configPath };
}

const Config_FilePaths = std.meta.Tuple(&.{ std.json.Parsed(ControllerConfig), [*:0]const u8, [*:0]const u8, [*:0]const u8 });

fn validateConfig(allocator: *Allocator, controller_name: [*:0]const u8) !Config_FilePaths {
    const rv = try buildPaths(allocator, controller_name);
    const channelStripPath = rv[0];
    const realearnPath = rv[1];
    const configPath = rv[3];
    errdefer {
        allocator.free(channelStripPath);
        allocator.free(realearnPath);
        allocator.free(configPath);
    }

    // check that file paths exist
    _ = try std.fs.accessAbsolute(channelStripPath, .{}) and std.fs.accessAbsolute(realearnPath, .{}) catch |err| {
        const msg =
            \\Error accessing files for controller: 
            \\channel strip fxchain, 
            \\realearn fxchain,  
            \\ config file 
        ;

        var buf: [msg.len + controller_name.len]u8 = undefined;
        _ = try std.fmt.bufPrint(&buf, "{s} {s}", .{ msg, .controller_name });
        reaper.MB(buf, "Error", 0);
        return err;
    };

    // read the config
    const config = parseJSON(configPath) catch |err| {
        const msg = "Invalid config file for controller";
        var buf: [msg.len + controller_name.len + 1]u8 = undefined;
        _ = try std.fmt.bufPrint(&buf, "{s} {s}", .{ .msg, .controller_name });
        reaper.MB(buf, "Error", 0);
        return err;
    };
    const retval: Config_FilePaths = .{ config, channelStripPath, realearnPath, configPath };
    return retval;
}

const ConfigLoaderError = error{
    NoConfigName,
    FileUnfound,
};

///@param controller ControllerId
///@return ControllerConfig|nil config
pub fn load(allocator: *Allocator, controller: Controller) ConfigLoaderError!ControllerConfig {
    const controller_name = controller.name;
    if (std.mem.eql(u8, controller_name, "") or controller_name == null) {
        return ConfigLoaderError.NoConfigName;
    }
    return validateConfig(allocator, controller_name);
}
