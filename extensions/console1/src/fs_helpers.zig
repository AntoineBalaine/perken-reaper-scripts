const std = @import("std");
const reaper = @import("reaper.zig").reaper;
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

pub fn joinStrings(buffer: []u8, strings: []const []const u8) []const u8 {
    var path_list = std.ArrayListUnmanaged(u8).initBuffer(buffer);
    for (strings) |s| {
        path_list.appendSliceAssumeCapacity(s);
    }
    return path_list.items;
}

test "joinStrings" {
    const testing = std.testing;

    var buffer: [100]u8 = undefined;
    const result = joinStrings(&buffer, &.{ "hello", "world" });
    try testing.expectEqualStrings("helloworld", result);

    const result2 = joinStrings(&buffer, &.{ "path", "/", "to", "/", "file" });
    try testing.expectEqualStrings("path/to/file", result2);
}

const default_preferences = @embedFile("resources/preferences.ini");
const default_mappings = struct {
    const comp_recomp = @embedFile("resources/maps/COMP/VST: ReaComp (Cockos).ini");
    const eq_reaeq = @embedFile("resources/maps/EQ/VST: ReaEQ (Cockos).ini");
    const gate_reagate = @embedFile("resources/maps/GATE/VST: ReaGate (Cockos).ini");
    const input = struct {
        const rbj = @embedFile("resources/maps/INPUT/JS: RBJ Highpass_Lowpass Filters.ini");
        const vol_adj = @embedFile("resources/maps/INPUT/JS: Volume Adjustment.ini");
        const vol_pan = @embedFile("resources/maps/INPUT/JS: Volume_Pan Smoother v5.ini");
    };
    const output = struct {
        const analog = @embedFile("resources/maps/OUTPT/JS: ReaAnalog.ini");
        const saturation = @embedFile("resources/maps/OUTPT/JS: Saturation.ini");
    };
};

/// check for existence of config files, create them if necessary
pub fn ensureConfigPath() !void {
    const reaper_path = reaper.GetResourcePath();
    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;

    // First ensure Perken directory exists
    const perken_path = joinStrings(&path_buffer, &.{
        std.mem.sliceTo(reaper_path, 0),
        std.fs.path.sep_str,
        "Data",
        std.fs.path.sep_str,
        "Perken",
    });
    try ensureDir(perken_path);

    // Then ensure Console1 directory exists
    const resource_path = joinStrings(&path_buffer, &.{
        std.mem.sliceTo(reaper_path, 0),
        std.fs.path.sep_str,
        "Data",
        std.fs.path.sep_str,
        "Perken",
        std.fs.path.sep_str,
        "Console1",
    });
    try ensureDir(resource_path);

    // Create preferences file
    const pref_path = joinStrings(&path_buffer, &.{
        std.mem.sliceTo(reaper_path, 0),
        std.fs.path.sep_str,
        "Data",
        std.fs.path.sep_str,
        "Perken",
        std.fs.path.sep_str,
        "Console1",
        std.fs.path.sep_str,
        "preferences.ini",
    });
    try ensureFile(pref_path, default_preferences);

    // create maps directory
    const maps_path = joinStrings(&path_buffer, &.{
        std.mem.sliceTo(reaper_path, 0),
        std.fs.path.sep_str,
        "Data",
        std.fs.path.sep_str,
        "Perken",
        std.fs.path.sep_str,
        "Console1",
        std.fs.path.sep_str,
        "maps",
    });
    try ensureDir(maps_path);

    // Define directory structure and default files
    const structure = .{
        .{ "COMP", "VST: ReaComp (Cockos).ini", default_mappings.comp_recomp },
        .{ "EQ", "VST: ReaEQ (Cockos).ini", default_mappings.eq_reaeq },
        .{ "GATE", "VST: ReaGate (Cockos).ini", default_mappings.gate_reagate },
        .{ "INPUT", "JS: RBJ Highpass_Lowpass Filters.ini", default_mappings.input.rbj },
        .{ "INPUT", "JS: Volume Adjustment.ini", default_mappings.input.vol_adj },
        .{ "INPUT", "JS: Volume_Pan Smoother v5.ini", default_mappings.input.vol_pan },
        .{ "OUTPT", "JS: ReaAnalog.ini", default_mappings.output.analog },
        .{ "OUTPT", "JS: Saturation.ini", default_mappings.output.saturation },
    };

    // Create directories and files
    inline for (structure) |item| {
        const dir_path = joinStrings(&path_buffer, &.{
            std.mem.sliceTo(reaper_path, 0),
            std.fs.path.sep_str,
            "Data",
            std.fs.path.sep_str,
            "Perken",
            std.fs.path.sep_str,
            "Console1",
            std.fs.path.sep_str,
            "maps",
            std.fs.path.sep_str,
            item[0],
        });
        try ensureDir(dir_path);

        const file_path = joinStrings(&path_buffer, &.{
            std.mem.sliceTo(reaper_path, 0),
            std.fs.path.sep_str,
            "Data",
            std.fs.path.sep_str,
            "Perken",
            std.fs.path.sep_str,
            "Console1",
            std.fs.path.sep_str,
            "maps",
            std.fs.path.sep_str,
            item[0],
            std.fs.path.sep_str,
            item[1],
        });
        try ensureFile(file_path, item[2]);
    }
}

fn ensureDir(path: []const u8) !void {
    std.fs.cwd().access(path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            try std.fs.makeDirAbsolute(path);
        } else {
            return err;
        }
    };
}

fn ensureFile(path: []const u8, contents: []const u8) !void {
    const file = std.fs.createFileAbsolute(path, .{ .exclusive = true }) catch |err| {
        if (err == error.PathAlreadyExists) {
            // File already exists, we can skip
            return;
        }
        return err;
    };
    defer file.close();
    try file.writeAll(contents);
}
