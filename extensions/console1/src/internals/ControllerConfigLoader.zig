const std = @import("std");
const ctrler = @import("controller.zig");
const Controller = ctrler.Controller;
const ControllerConfig = @import("types.zig").ControllerConfig;
const reaper = @import("../reaper.zig").reaper;
const fs_helpers = @import("fs_helpers.zig");
const Allocator = std.mem.Allocator;

fn readConfig(allocator: Allocator, path: []const u8) !std.json.Parsed(ControllerConfig) {
    const data = try std.fs.cwd().readFileAlloc(allocator, path, 512);
    defer allocator.free(data);
    return std.json.parseFromSlice(ControllerConfig, allocator, data, .{ .allocate = .alloc_always });
}

fn validateFiles(allocator: *Allocator, controller_name: [*:0]const u8) ![3][*:0]const u8 {
    const path = fs_helpers.getControllerConfigPath(allocator, controller_name);
    defer allocator.free(path);
    const rfx_extension = ".RfxChain";

    const channelStripPath = try std.fmt.allocPrint(allocator, "prknCtrl_{s}_channelStrip{s}", .{ controller_name, rfx_extension });

    const realearnPath = try std.fmt.allocPrint(allocator, "prknCtrl_{s}_realearn{s}", .{ controller_name, rfx_extension });
    const configPath = try std.fmt.allocPrint(allocator, "prknCtrl_{s}_config.json", .{controller_name});
    if (!fs_helpers.file_exists(channelStripPath) or !fs_helpers.file_exists(realearnPath) or !fs_helpers.file_exists(configPath)) {
        const msg =
            \\Missing files for controller: 
            \\channel strip fxchain, 
            \\realearn fxchain,  
            \\config file 
        ;

        var buf: [msg.len + controller_name.len]u8 = undefined;
        _ = try std.fmt.bufPrint(&buf, "{s} {s}", .{ msg, .controller_name });
        reaper.MB(buf, "Error", 0);
        return ConfigLoaderError.FileUnfound;
    }
    return [_][*:0]const u8{ channelStripPath, realearnPath, configPath };
}

const ConfigLoaderError = error{
    NoConfigName,
    FileUnfound,
};

///@param controller_name string
///@return ControllerConfig|nil
fn validateConfig(allocator: *Allocator, controller_name: [*:0]const u8) ConfigLoaderError!ControllerConfig {
    const rv = try validateFiles(allocator, controller_name);
    const channelStripPath = rv[0];
    const realearnPath = rv[1];
    const configPath = rv[3];
    defer allocator.free(channelStripPath);
    defer allocator.free(realearnPath);
    defer allocator.free(configPath);

    const config = try readConfig(configPath) catch |err| {
        const msg = "Invalid config file for controller";
        var buf: [msg.len + controller_name.len]u8 = undefined;
        _ = try std.fmt.bufPrintZ(&buf, "{s} {s}", .{ .msg, .controller_name });
        reaper.MB(buf, "Error", 0);
        return err;
    };
    defer config.deinit();

    // TODO make check for contents of data
    config.channelStripPath = channelStripPath;
    config.realearnPath = realearnPath;
    return config;
}

///@param controller ControllerId
///@return ControllerConfig|nil config
pub fn load(allocator: *Allocator, controller: Controller) ConfigLoaderError!ControllerConfig {
    const controller_name = controller.name;
    if (std.mem.eql(u8, controller_name, "") or controller_name == null) {
        return ConfigLoaderError.NoConfigName;
    }
    return validateConfig(allocator, controller_name);
}
