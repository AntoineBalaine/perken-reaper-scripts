const std = @import("std");
const ctrler = @import("controller.zig");
const Controller = ctrler.Controller;
const ControllerConfig = @import("types.zig").ControllerConfig;
const reaper = @import("../reaper.zig").reaper;
const fs_helpers = @import("fs_helpers.zig");
const Allocator = std.mem.Allocator;
const types = @import("types.zig");
const ini = @import("ini");
const UserSettings = types.UserSettings;

const Module = struct {
    name: []const u8,
    default: []const u8,
    mappings: []const []const u8,
};

const Prefs = struct { name: []const u8, modes: [][]const u8, modules: []Module, userSettings: UserSettings, mappings: std.StringHashMap([]const u8) };

const Sect = struct {
    section: []const u8,
    enumerations: [][]const u8,
};
fn serializeSection(allocator: Allocator, parser: ini.Parser(std.io.GenericReader)) !?Prefs {
    const sections = std.ArrayList(Sect).init(Allocator);
    while (true) {
        const record = try parser.next();
        var curSection: ?[]const u8 = null;
        var enumerations: [][]const u8 = std.ArrayList([]const u8).init(allocator);
        switch (record) {
            .property => |kv| {
                kv.key;
                kv.value;
            },
            .section => |heading| {
                if (curSection != null) {
                    sections.append(Sect{ .section = curSection, .enumerations = enumerations });
                    curSection = heading;
                    enumerations = std.ArrayList([]const u8).init(allocator);
                }
            },
            .enumeration => {
                enumerations.append(record);
            },
        }
        @panic("unreachable"); // TODO finish this
    }
}

fn parsePrefs(allocator: Allocator, ctrlrPth: []const u8) !Prefs {
    const file = try std.fs.openFileAbsolute(&ctrlrPth, .{});
    defer file.close();
    const reader = file.reader();

    var parser = ini.parse(allocator, reader);
    defer parser.deinit();
    const prefs = Prefs{ .modules = undefined, .userSettings = undefined };
    _ = prefs;
    const section: [128]u8 = undefined;

    const ModuleList = std.ArrayList(Module).init(allocator);
    while (try parser.next()) |record| {
        switch (record) {
            .property => |kv| {
                if (std.mem.eql(section, "module")) {
                    const Case = std.meta.FieldEnum(Module);
                    const case = std.meta.stringToEnum(Case, kv.key) orelse continue;
                    switch (case) {
                        .name => {
                            const spanned = std.mem.span(kv.value);
                            _ = spanned;
                        },
                        .default => {},
                        .mappings => {},
                    }
                }
            },
            .section => |heading| {
                @memcpy(section, heading);
                if (std.mem.eq(heading, "module")) {
                    // allocator.create()
                    ModuleList.append(Module{});
                }
            },
            .enumeration => {},
        }
    }
    @panic("unreachable");
}

const fileTypes = union(enum) {
    fxTags,
    config,
    mappings,
};

fn readConfigFiles(allocator: Allocator, path: []const u8) ![]const u8 {
    const mappings = std.StringHashMap([]const u8).init(allocator);
    var prefs: Prefs = undefined;
    const dir = try std.fs.openDirAbsolute(path, .{ .iterate = true });
    defer dir.close();

    const walker = try dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        switch (entry.kind) {
            .file => {
                // If the walker recurses through everything, I expect for it to be able to go through the mappings sub-directory
                if (std.mem.eql(std.fs.path.dirname, "mappings") and std.mem.eql(std.fs.path.extension(entry.path), ".json")) {
                    // load the file into memory.
                    const contents = try fs_helpers.readFile(allocator, entry.path);
                    mappings.put(entry.basename, contents);
                    // store it in the controller config
                } else if (std.mem.eql(entry.basename, "config.ini")) {
                    const contents = try fs_helpers.readFile(allocator, entry.path);
                    prefs = try parsePrefs(allocator, contents);
                    prefs.mappings = mappings;
                } else if (std.mem.eql(entry.basename, "fx-tags.ini")) {
                    const contents = try fs_helpers.readFile(allocator, entry.path);
                    _ = contents; // autofix
                    // prefs.fxTags = try parseFxTags(allocator, contents);
                }
            },
            else => {},
        }
    }
}

fn getControllerPath(allocator: Allocator, controller_name: []const u8) ![]const u8 {
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

    const config = try readConfigFiles(allocator, configDir);
    _ = config;
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

    const rv = try getControllerPath(allocator, controller.name);
    // const channelStripPath = rv[0];
    // const realearnPath = rv[1];
    // const controllerConfigPath = rv[2];

    return rv;
}
