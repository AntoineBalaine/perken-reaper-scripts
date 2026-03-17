const std = @import("std");
const reaper = @import("reaper.zig").reaper;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.fs_helpers);

/// FileSystemOps provides an interface for filesystem operations that can be mocked in tests.
/// Because tests need to avoid actual I/O operations, this interface allows swapping out
/// real implementations with mock implementations that track calls without performing I/O.
/// This follows the same pattern as std.mem.Allocator with a context pointer and vtable.
pub const FileSystemOps = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        makeDirAbsolute: *const fn (ptr: *anyopaque, path: []const u8) anyerror!void,
        createFileAbsolute: *const fn (ptr: *anyopaque, path: []const u8, flags: std.fs.File.CreateFlags) anyerror!std.fs.File,
        access: *const fn (ptr: *anyopaque, path: []const u8, flags: std.fs.File.OpenFlags) anyerror!void,
    };

    pub fn makeDirAbsolute(self: FileSystemOps, path: []const u8) !void {
        return self.vtable.makeDirAbsolute(self.ptr, path);
    }

    pub fn createFileAbsolute(self: FileSystemOps, path: []const u8, flags: std.fs.File.CreateFlags) !std.fs.File {
        return self.vtable.createFileAbsolute(self.ptr, path, flags);
    }

    pub fn access(self: FileSystemOps, path: []const u8, flags: std.fs.File.OpenFlags) !void {
        return self.vtable.access(self.ptr, path, flags);
    }
};

/// RealFileSystem provides actual filesystem operations.
/// Because real filesystem operations are stateless, we use a static instance.
pub const RealFileSystem = struct {
    fn makeDirAbsolute(ptr: *anyopaque, path: []const u8) !void {
        _ = ptr;
        return std.fs.makeDirAbsolute(path);
    }

    fn createFileAbsolute(ptr: *anyopaque, path: []const u8, flags: std.fs.File.CreateFlags) !std.fs.File {
        _ = ptr;
        return std.fs.createFileAbsolute(path, flags);
    }

    fn access(ptr: *anyopaque, path: []const u8, flags: std.fs.File.OpenFlags) !void {
        _ = ptr;
        return std.fs.cwd().access(path, flags);
    }

    const vtable = FileSystemOps.VTable{
        .makeDirAbsolute = makeDirAbsolute,
        .createFileAbsolute = createFileAbsolute,
        .access = access,
    };

    var instance: RealFileSystem = .{};

    pub fn fileSystemOps() FileSystemOps {
        return .{
            .ptr = &instance,
            .vtable = &vtable,
        };
    }
};

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
    const comp_reacomp = @embedFile("resources/maps/factory/COMP/reacomp/default.ini");
    const eq_reaeq = @embedFile("resources/maps/factory/EQ/reaeq/default.ini");
    const gate_reagate = @embedFile("resources/maps/factory/GATE/reagate/default.ini");
    const rbj_filters = @embedFile("resources/maps/factory/INPUT/rbj_filters/default.ini");
    const vol_adj = @embedFile("resources/maps/factory/INPUT/vol_adj/default.ini");
    const vol_pan = @embedFile("resources/maps/factory/INPUT/vol_pan/default.ini");
    const reaanalog = @embedFile("resources/maps/factory/OUTPT/reaanalog/default.ini");
    const saturation = @embedFile("resources/maps/factory/OUTPT/saturation/default.ini");
};

/// check for existence of config files, create them if necessary
pub fn ensureConfigPath(fs_ops: FileSystemOps) !void {
    const reaper_path = reaper.GetResourcePath();
    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;

    // First ensure Perken directory exists
    const perken_path = joinStrings(&path_buffer, &.{
        std.mem.sliceTo(reaper_path, 0),
        std.fs.path.sep_str,
        "Data",
        std.fs.path.sep_str,
        "Perken",
    });
    try ensureDir(fs_ops, perken_path);

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
    try ensureDir(fs_ops, resource_path);

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
    try ensureFile(fs_ops, pref_path, default_preferences);

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
    try ensureDir(fs_ops, maps_path);

    // Create defaults directory inside maps
    const defaults_path = joinStrings(&path_buffer, &.{
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
        "factory",
    });
    try ensureDir(fs_ops, defaults_path);

    // Write default mapping files into maps/defaults/{name}/default.ini
    // Because each mapping needs a unique filename (the filename becomes the
    // mapping name), and all defaults use "default" as the mapping name, we
    // put each in its own subdirectory.
    const structure = .{
        .{ "COMP", "reacomp", default_mappings.comp_reacomp },
        .{ "EQ", "reaeq", default_mappings.eq_reaeq },
        .{ "GATE", "reagate", default_mappings.gate_reagate },
        .{ "INPUT", "rbj_filters", default_mappings.rbj_filters },
        .{ "INPUT", "vol_adj", default_mappings.vol_adj },
        .{ "INPUT", "vol_pan", default_mappings.vol_pan },
        .{ "OUTPT", "reaanalog", default_mappings.reaanalog },
        .{ "OUTPT", "saturation", default_mappings.saturation },
    };

    var buf2: [std.fs.max_path_bytes]u8 = undefined;
    var buf3: [std.fs.max_path_bytes]u8 = undefined;
    inline for (structure) |item| {
        const module_dir = joinStrings(&path_buffer, &.{
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
            "factory",
            std.fs.path.sep_str,
            item[0],
        });
        try ensureDir(fs_ops, module_dir);

        const fx_dir = joinStrings(&buf2, &.{
            module_dir,
            std.fs.path.sep_str,
            item[1],
        });
        try ensureDir(fs_ops, fx_dir);

        const file_path = joinStrings(&buf3, &.{
            fx_dir,
            std.fs.path.sep_str,
            "default.ini",
        });
        try ensureFile(fs_ops, file_path, item[2]);
    }
}

fn ensureDir(fs_ops: FileSystemOps, path: []const u8) !void {
    fs_ops.access(path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            try fs_ops.makeDirAbsolute(path);
        } else {
            return err;
        }
    };
}

fn ensureFile(fs_ops: FileSystemOps, path: []const u8, contents: []const u8) !void {
    const file = fs_ops.createFileAbsolute(path, .{ .exclusive = true }) catch |err| {
        if (err == error.PathAlreadyExists) {
            // File already exists, we can skip
            return;
        }
        return err;
    };
    defer file.close();
    try file.writeAll(contents);
}

/// Copy embedded default files to a target directory for testing.
/// Tests need actual mapping files in the temp directory.
pub fn copyEmbeddedFilesToDir(fs_ops: FileSystemOps, target_path: []const u8) !void {
    var buf1: [std.fs.max_path_bytes]u8 = undefined;
    var buf2: [std.fs.max_path_bytes]u8 = undefined;
    var buf3: [std.fs.max_path_bytes]u8 = undefined;
    const console1_path = joinStrings(&buf1, &.{
        target_path, std.fs.path.sep_str, "Data",     std.fs.path.sep_str,
        "Perken",    std.fs.path.sep_str, "Console1",
    });

    // Create directory hierarchy
    try ensureDir(fs_ops, target_path);
    const data_path = joinStrings(&buf2, &.{ target_path, std.fs.path.sep_str, "Data" });
    try ensureDir(fs_ops, data_path);
    const perken_path = joinStrings(&buf3, &.{ data_path, std.fs.path.sep_str, "Perken" });
    try ensureDir(fs_ops, perken_path);
    try ensureDir(fs_ops, console1_path);

    // Write preferences
    const pref_path = joinStrings(&buf2, &.{ console1_path, std.fs.path.sep_str, "preferences.ini" });
    try ensureFile(fs_ops, pref_path, default_preferences);

    // Create maps directory and all default mappings
    const maps_path = joinStrings(&buf2, &.{ console1_path, std.fs.path.sep_str, "maps" });
    try ensureDir(fs_ops, maps_path);

    // Create defaults directory
    const defaults_path = joinStrings(&buf3, &.{ maps_path, std.fs.path.sep_str, "factory" });
    try ensureDir(fs_ops, defaults_path);

    const structure = .{
        .{ "COMP", "reacomp", default_mappings.comp_reacomp },
        .{ "EQ", "reaeq", default_mappings.eq_reaeq },
        .{ "GATE", "reagate", default_mappings.gate_reagate },
        .{ "INPUT", "rbj_filters", default_mappings.rbj_filters },
        .{ "INPUT", "vol_adj", default_mappings.vol_adj },
        .{ "INPUT", "vol_pan", default_mappings.vol_pan },
        .{ "OUTPT", "reaanalog", default_mappings.reaanalog },
        .{ "OUTPT", "saturation", default_mappings.saturation },
    };

    var buf4: [std.fs.max_path_bytes]u8 = undefined;
    var buf5: [std.fs.max_path_bytes]u8 = undefined;
    inline for (structure) |item| {
        const module_dir = joinStrings(&buf2, &.{ defaults_path, std.fs.path.sep_str, item[0] });
        try ensureDir(fs_ops, module_dir);
        const fx_dir = joinStrings(&buf4, &.{ module_dir, std.fs.path.sep_str, item[1] });
        try ensureDir(fs_ops, fx_dir);
        const file_path = joinStrings(&buf5, &.{ fx_dir, std.fs.path.sep_str, "default.ini" });
        try ensureFile(fs_ops, file_path, item[2]);
    }
}

pub fn sanitizeFxName(buf: *[512:0]u8, fx_name: []const u8) ![:0]const u8 {
    const base_name = try std.fmt.bufPrintZ(buf, "{s}", .{fx_name});
    _ = std.mem.replace(u8, base_name, "/", "_", buf);
    return base_name;
}

test "sanitizeFxName" {
    const testing = std.testing;

    const TestCase = struct {
        input: []const u8,
        expected: []const u8,
    };

    const test_cases = [_]TestCase{
        .{ .input = "VST: My/Plugin", .expected = "VST: My_Plugin" },
        .{ .input = "VST: Plugin/With/Many/Slashes", .expected = "VST: Plugin_With_Many_Slashes" },
        .{ .input = "VST: Some:Plugin/Name", .expected = "VST: Some:Plugin_Name" },
        .{ .input = "", .expected = "" },
    };

    var buf: [512:0]u8 = undefined;

    for (test_cases) |case| {
        const result = try sanitizeFxName(&buf, case.input);
        try testing.expectEqualStrings(case.expected, result);
    }
}

/// MockFileSystem for testing - tracks operations and uses temp directory
pub const MockFileSystem = struct {
    allocator: std.mem.Allocator,
    dirs_created: std.ArrayList([]const u8),
    files_created: std.ArrayList([]const u8),
    temp_dir: std.testing.TmpDir,

    pub fn init(allocator: std.mem.Allocator) !MockFileSystem {
        return MockFileSystem{
            .allocator = allocator,
            .dirs_created = std.ArrayList([]const u8).init(allocator),
            .files_created = std.ArrayList([]const u8).init(allocator),
            .temp_dir = std.testing.tmpDir(.{}),
        };
    }

    pub fn deinit(self: *MockFileSystem) void {
        for (self.dirs_created.items) |dir| {
            self.allocator.free(dir);
        }
        self.dirs_created.deinit();

        for (self.files_created.items) |file| {
            self.allocator.free(file);
        }
        self.files_created.deinit();

        self.temp_dir.cleanup();
    }

    fn makeDirAbsolute(ptr: *anyopaque, path: []const u8) !void {
        const self: *MockFileSystem = @ptrCast(@alignCast(ptr));
        const owned = try self.allocator.dupe(u8, path);
        try self.dirs_created.append(owned);
    }

    fn createFileAbsolute(ptr: *anyopaque, path: []const u8, flags: std.fs.File.CreateFlags) !std.fs.File {
        const self: *MockFileSystem = @ptrCast(@alignCast(ptr));
        const owned_path = try self.allocator.dupe(u8, path);
        try self.files_created.append(owned_path);

        const file = try self.temp_dir.dir.createFile("test_file", flags);
        return file;
    }

    fn access(ptr: *anyopaque, path: []const u8, flags: std.fs.File.OpenFlags) !void {
        _ = ptr;
        _ = path;
        _ = flags;
    }

    const vtable = FileSystemOps.VTable{
        .makeDirAbsolute = makeDirAbsolute,
        .createFileAbsolute = createFileAbsolute,
        .access = access,
    };

    pub fn fileSystemOps(self: *MockFileSystem) FileSystemOps {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }
};
