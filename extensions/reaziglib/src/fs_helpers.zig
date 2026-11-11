const std = @import("std");
const reaper = @import("reaper").reaper;
const Allocator = std.mem.Allocator;
const log = std.log.scoped(.fs_helpers);

/// FileSystemOps provides an interface for filesystem operations that can be mocked in tests.
/// Because tests need to avoid actual I/O operations, this interface allows swapping out
/// real implementations with mock implementations that track calls without performing I/O.
/// This follows the same pattern as std.mem.Allocator with a context pointer and vtable.
pub const FileSystemOps = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    /// The std.Io that the files returned by createFileAbsolute belong to. Because a std.Io.File is
    /// written and closed through a std.Io, callers write and close those files with this one.
    io: std.Io,

    pub const VTable = struct {
        makeDirAbsolute: *const fn (ptr: *anyopaque, path: []const u8) anyerror!void,
        createFileAbsolute: *const fn (ptr: *anyopaque, path: []const u8, flags: std.Io.Dir.CreateFileOptions) anyerror!std.Io.File,
        access: *const fn (ptr: *anyopaque, path: []const u8, options: std.Io.Dir.AccessOptions) anyerror!void,
    };

    pub fn makeDirAbsolute(self: FileSystemOps, path: []const u8) !void {
        return self.vtable.makeDirAbsolute(self.ptr, path);
    }

    pub fn createFileAbsolute(self: FileSystemOps, path: []const u8, flags: std.Io.Dir.CreateFileOptions) !std.Io.File {
        return self.vtable.createFileAbsolute(self.ptr, path, flags);
    }

    pub fn access(self: FileSystemOps, path: []const u8, options: std.Io.Dir.AccessOptions) !void {
        return self.vtable.access(self.ptr, path, options);
    }
};

/// RealFileSystem provides actual filesystem operations.
/// Because real filesystem operations only need the std.Io that performs them, we use a static instance
/// that holds it.
pub const RealFileSystem = struct {
    io: std.Io = undefined,

    pub fn makeDirAbsolute(ptr: *anyopaque, path: []const u8) !void {
        const self: *RealFileSystem = @ptrCast(@alignCast(ptr));
        return std.Io.Dir.createDirAbsolute(self.io, path, .default_dir);
    }

    pub fn createFileAbsolute(ptr: *anyopaque, path: []const u8, flags: std.Io.Dir.CreateFileOptions) !std.Io.File {
        const self: *RealFileSystem = @ptrCast(@alignCast(ptr));
        return std.Io.Dir.createFileAbsolute(self.io, path, flags);
    }

    pub fn access(ptr: *anyopaque, path: []const u8, options: std.Io.Dir.AccessOptions) !void {
        const self: *RealFileSystem = @ptrCast(@alignCast(ptr));
        return std.Io.Dir.cwd().access(self.io, path, options);
    }

    pub const vtable = FileSystemOps.VTable{
        .makeDirAbsolute = makeDirAbsolute,
        .createFileAbsolute = createFileAbsolute,
        .access = access,
    };

    pub var instance: RealFileSystem = .{};

    pub fn fileSystemOps(io: std.Io) FileSystemOps {
        instance.io = io;
        return .{
            .ptr = &instance,
            .vtable = &vtable,
            .io = io,
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
        pub fn mockResourcePath() callconv(.c) [*:0]const u8 {
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

pub fn ensureDir(fs_ops: FileSystemOps, path: []const u8) !void {
    fs_ops.access(path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            try fs_ops.makeDirAbsolute(path);
        } else {
            return err;
        }
    };
}

pub fn ensureFile(fs_ops: FileSystemOps, path: []const u8, contents: []const u8) !void {
    const file = fs_ops.createFileAbsolute(path, .{ .exclusive = true }) catch |err| {
        if (err == error.PathAlreadyExists) {
            // File already exists, we can skip
            return;
        }
        return err;
    };
    defer file.close(fs_ops.io);
    try file.writeStreamingAll(fs_ops.io, contents);
}

/// Characters that Windows forbids in file and folder names. Because GitHub's
/// artifact upload rejects the same ones, and macOS and Linux forbid only
/// '/', these are the characters a map folder name must avoid to work
/// everywhere.
pub const forbidden_name_chars = "<>:\"/\\|?*";

/// Turns an FX name into a folder name that every filesystem accepts.
/// Because Windows forbids `< > : " / \ | ? *` and control characters in
/// names, each of them becomes '_'; because Windows also drops trailing
/// spaces and dots, those are trimmed. A name left empty (or one that was only
/// dots, such as "..", which would point at the parent folder) becomes "_".
pub fn sanitizeFxName(buf: *[512:0]u8, fx_name: []const u8) ![:0]const u8 {
    if (fx_name.len > buf.len) return error.NoSpaceLeft;
    var len: usize = 0;
    for (fx_name) |c| {
        buf[len] = if (c < 0x20 or std.mem.indexOfScalar(u8, forbidden_name_chars, c) != null) '_' else c;
        len += 1;
    }
    while (len > 0 and (buf[len - 1] == ' ' or buf[len - 1] == '.')) len -= 1;
    if (len == 0) {
        buf[0] = '_';
        len = 1;
    }
    buf[len] = 0;
    return buf[0..len :0];
}

/// Renames each subfolder of `parent_dir` whose name sanitizeFxName would
/// change. Because versions before the Windows-safe naming replaced only '/',
/// users' disks still hold folders such as "JS: ReaAnalog"; sanitizing such a
/// name gives the same result as sanitizing the FX name itself, so after this
/// the folders sit where lookups expect them. We move the folders rather than
/// let lookups create empty ones next to them, because users may have edited
/// the maps inside. A folder is left alone when the sanitized name already
/// exists, and a missing `parent_dir` is not an error.
pub fn migrateFolderNames(io: std.Io, parent_dir: []const u8) !void {
    var dir = std.Io.Dir.openDirAbsolute(io, parent_dir, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer dir.close(io);

    // Because renaming while iterating can skip or repeat entries, we collect
    // the names first.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var names: std.ArrayList([]const u8) = .empty;
    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
        if (entry.kind != .directory) continue;
        try names.append(arena.allocator(), try arena.allocator().dupe(u8, entry.name));
    }

    var buf: [512:0]u8 = undefined;
    for (names.items) |name| {
        const sanitized = try sanitizeFxName(&buf, name);
        if (std.mem.eql(u8, name, sanitized)) continue;
        if (dir.access(io, sanitized, .{})) |_| continue else |_| {}
        try dir.rename(name, dir, sanitized, io);
    }
}

/// Applies migrateFolderNames to `root_dir` and every folder below it.
/// Because Console1's maps nest FX folders at several depths
/// (maps/<source>/<MODULE>/<fx>/ and maps/STRIP/<fx>/), we walk the whole tree.
pub fn migrateFolderNamesRecursive(io: std.Io, root_dir: []const u8) !void {
    try migrateFolderNames(io, root_dir);

    var dir = std.Io.Dir.openDirAbsolute(io, root_dir, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return err,
    };
    defer dir.close(io);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var children: std.ArrayList([]const u8) = .empty;
    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
        if (entry.kind != .directory) continue;
        try children.append(arena.allocator(), try std.fs.path.join(arena.allocator(), &.{ root_dir, entry.name }));
    }
    for (children.items) |child| try migrateFolderNamesRecursive(io, child);
}

test "sanitizeFxName" {
    const testing = std.testing;

    const TestCase = struct {
        input: []const u8,
        expected: []const u8,
    };

    const test_cases = [_]TestCase{
        .{ .input = "VST: My/Plugin", .expected = "VST_ My_Plugin" },
        .{ .input = "VST: Plugin/With/Many/Slashes", .expected = "VST_ Plugin_With_Many_Slashes" },
        .{ .input = "JS: Amphitrite Compressor (chmaha)", .expected = "JS_ Amphitrite Compressor (chmaha)" },
        .{ .input = "JS: NW8 \"A\" Plate Reverb (chmaha)", .expected = "JS_ NW8 _A_ Plate Reverb (chmaha)" },
        .{ .input = "JS: Orpheus Console Sub|Aux Out (chmaha)", .expected = "JS_ Orpheus Console Sub_Aux Out (chmaha)" },
        .{ .input = "a<b>c\\d?e*f\tg", .expected = "a_b_c_d_e_f_g" },
        .{ .input = "VST: Trailing. . ", .expected = "VST_ Trailing" },
        .{ .input = "..", .expected = "_" },
        .{ .input = "", .expected = "_" },
        .{ .input = "Plain name (Cockos)", .expected = "Plain name (Cockos)" },
    };

    var buf: [512:0]u8 = undefined;

    for (test_cases) |case| {
        const result = try sanitizeFxName(&buf, case.input);
        try testing.expectEqualStrings(case.expected, result);
    }
}

test "sanitizeFxName rejects names longer than the buffer" {
    var buf: [512:0]u8 = undefined;
    const long: [513]u8 = @splat('a');
    try std.testing.expectError(error.NoSpaceLeft, sanitizeFxName(&buf, &long));
}

test "migrateFolderNames renames legacy folders once" {
    const testing = std.testing;
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const parent = path_buf[0..try tmp.dir.realPath(io, &path_buf)];

    try tmp.dir.createDirPath(io, "JS: Volume_Pan Smoother v5");
    try tmp.dir.writeFile(io, .{ .sub_path = "JS: Volume_Pan Smoother v5/default.ini", .data = "edited" });
    try tmp.dir.createDirPath(io, "reacomp");
    // Because the sanitized name of this one already exists, it stays put.
    try tmp.dir.createDirPath(io, "JS: Taken");
    try tmp.dir.createDirPath(io, "JS_ Taken");

    try migrateFolderNames(io, parent);
    const content = try tmp.dir.readFileAlloc(io, "JS_ Volume_Pan Smoother v5/default.ini", testing.allocator, .limited(64));
    defer testing.allocator.free(content);
    try testing.expectEqualStrings("edited", content);
    try testing.expectError(error.FileNotFound, tmp.dir.access(io, "JS: Volume_Pan Smoother v5", .{}));
    try tmp.dir.access(io, "reacomp", .{});
    try tmp.dir.access(io, "JS: Taken", .{});

    // Because nothing is left to rename, a second run changes nothing.
    try migrateFolderNames(io, parent);
    try migrateFolderNames(io, "/nonexistent-perken-test-dir");
}

test "migrateFolderNamesRecursive renames nested folders" {
    const testing = std.testing;
    const io = testing.io;
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const root = path_buf[0..try tmp.dir.realPath(io, &path_buf)];

    try tmp.dir.createDirPath(io, "chmaha/COMP/JS: Amphitrite Compressor (chmaha)");
    try tmp.dir.createDirPath(io, "STRIP/JS: Evolution Channel Strip (chmaha)");
    try migrateFolderNamesRecursive(io, root);
    try tmp.dir.access(io, "chmaha/COMP/JS_ Amphitrite Compressor (chmaha)", .{});
    try tmp.dir.access(io, "STRIP/JS_ Evolution Channel Strip (chmaha)", .{});
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
            .dirs_created = .empty,
            .files_created = .empty,
            .temp_dir = std.testing.tmpDir(.{}),
        };
    }

    pub fn deinit(self: *MockFileSystem) void {
        for (self.dirs_created.items) |dir| {
            self.allocator.free(dir);
        }
        self.dirs_created.deinit(self.allocator);

        for (self.files_created.items) |file| {
            self.allocator.free(file);
        }
        self.files_created.deinit(self.allocator);

        self.temp_dir.cleanup();
    }

    pub fn makeDirAbsolute(ptr: *anyopaque, path: []const u8) !void {
        const self: *MockFileSystem = @ptrCast(@alignCast(ptr));
        const owned = try self.allocator.dupe(u8, path);
        try self.dirs_created.append(self.allocator, owned);
    }

    pub fn createFileAbsolute(ptr: *anyopaque, path: []const u8, flags: std.Io.Dir.CreateFileOptions) !std.Io.File {
        const self: *MockFileSystem = @ptrCast(@alignCast(ptr));
        const owned_path = try self.allocator.dupe(u8, path);
        try self.files_created.append(self.allocator, owned_path);

        const file = try self.temp_dir.dir.createFile(std.testing.io, "test_file", flags);
        return file;
    }

    pub fn access(ptr: *anyopaque, path: []const u8, options: std.Io.Dir.AccessOptions) !void {
        _ = ptr;
        _ = path;
        _ = options;
    }

    pub const vtable = FileSystemOps.VTable{
        .makeDirAbsolute = makeDirAbsolute,
        .createFileAbsolute = createFileAbsolute,
        .access = access,
    };

    pub fn fileSystemOps(self: *MockFileSystem) FileSystemOps {
        return .{
            .ptr = self,
            .vtable = &vtable,
            .io = std.testing.io,
        };
    }
};
