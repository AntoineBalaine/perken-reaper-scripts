const std = @import("std");
const ctrler = @import("controller.zig");
const Controller = ctrler.Controller;
const reaper = @import("../reaper.zig").reaper;
const fs_helpers = @import("fs_helpers.zig");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const ini = @import("ini");
const UserSettings = types.UserSettings;

// const Module = struct {
//     name: []const u8,
//     default: []const u8,
//     mappings: []const []const u8,
// };

// const Prefs = struct { name: []const u8, modes: [][]const u8, modules: []Module, userSettings: UserSettings, mappings: std.StringHashMap([]const u8) };

// fn readConfigFiles(allocator: Allocator, path: []const u8) !void {
//     const mappings = std.StringHashMap([]const u8).init(allocator);
//     const dir = try std.fs.openDirAbsolute(path, .{ .iterate = true });
//     defer dir.close();
//     const prefs = Prefs{};
//
//     const walker = try dir.walk(allocator);
//     defer walker.deinit();
//     while (try walker.next()) |entry| {
//         switch (entry.kind) {
//             .file => {
//                 // If the walker recurses through everything, I expect for it to be able to go through the mappings sub-directory
//                 if (std.mem.eql(std.fs.path.dirname, "mappings") and std.mem.eql(std.fs.path.extension(entry.path), ".json")) {
//                     // load the file into memory.
//                     const contents = try fs_helpers.readFile(allocator, entry.path);
//                     mappings.put(entry.basename, contents);
//                     // store it in the controller config
//                 } else if (std.mem.eql(entry.basename, "config.ini")) {
//                     const file = try std.fs.cwd().openFile(entry.path, .{});
//                     defer file.close();
//
//                     const parser = ini.parse(allocator, file.reader());
//                     ini.readToStruct(&prefs, parser, allocator);
//
//                     prefs.mappings = mappings;
//                 } else if (std.mem.eql(entry.basename, "fx-tags.ini")) {
//                     const file = try std.fs.cwd().openFile(entry.path, .{});
//                     defer file.close();
//
//                     const parser = ini.parse(allocator, file.reader());
//                     ini.readToStruct(&prefs, parser, allocator);
//                     prefs.fxTags = try parseFxTags(allocator, contents);
//                 }
//             },
//             else => {},
//         }
//     }
// }

pub fn getControllerPath(controller_name: []const u8) ![]const u8 {
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

    // const config = try readConfigFiles(allocator, configDir);
    // _ = config;
    return configDir;
}

const ConfigLoaderError = error{
    NoConfigName,
    FileUnfound,
};

// return the paths of controller config, default channel strip, and realearn mapping for it.
// pub fn load(allocator: Allocator, controller: Controller) ![]const u8 {
//     if (std.mem.eql(u8, controller.name, "")) {
//         return ConfigLoaderError.NoConfigName;
//     }
//
//     const rv = try getControllerPath(allocator, controller.name);
//
//     return rv;
// }
