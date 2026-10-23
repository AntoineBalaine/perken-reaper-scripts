//! File access for the preset folder and the dump files.
//!
//! Because REAPER calls into the plugin from deep in its own stack, and
//! `std.fs`'s absolute-path functions on Windows do enough work internally
//! to overflow what is left of it (see `reavim-ext/src/win_file.zig`), the
//! Windows branch calls kernel32 directly. On macOS and Linux `std.fs` is
//! known to work at that depth.
const std = @import("std");
const builtin = @import("builtin");

pub const is_windows = builtin.os.tag == .windows;

pub const max_path = 1024;

/// Reads a whole file. The caller owns the returned slice.
pub fn readAll(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    if (is_windows) return win.readAllWin(allocator, path);
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();
    return file.readToEndAlloc(allocator, 16 * 1024 * 1024);
}

pub fn writeAll(path: []const u8, bytes: []const u8) !void {
    if (is_windows) return win.writeAllWin(path, bytes);
    const file = try std.fs.createFileAbsolute(path, .{});
    defer file.close();
    try file.writeAll(bytes);
}

/// Creates the folder and every missing parent.
pub fn makePath(path: []const u8) !void {
    if (is_windows) return win.makePathWin(path);
    std.fs.makeDirAbsolute(path) catch |err| switch (err) {
        error.PathAlreadyExists => return,
        error.FileNotFound => {
            const parent = std.fs.path.dirname(path) orelse return err;
            try makePath(parent);
            std.fs.makeDirAbsolute(path) catch |e| if (e != error.PathAlreadyExists) return e;
        },
        else => return err,
    };
}

pub fn deleteFile(path: []const u8) !void {
    if (is_windows) return win.deleteFileWin(path);
    try std.fs.deleteFileAbsolute(path);
}

pub fn exists(path: []const u8) bool {
    if (is_windows) return win.existsWin(path);
    std.fs.accessAbsolute(path, .{}) catch return false;
    return true;
}

/// The names (without folder) of the files in `dir` whose name ends with one
/// of `extensions`. The caller owns the list and the names.
pub fn listFiles(allocator: std.mem.Allocator, dir: []const u8, extensions: []const []const u8) !std.ArrayList([]u8) {
    var names = std.ArrayList([]u8).init(allocator);
    errdefer freeList(allocator, &names);
    if (is_windows) {
        try win.listFilesWin(allocator, dir, extensions, &names);
        return names;
    }
    var d = std.fs.openDirAbsolute(dir, .{ .iterate = true }) catch return names;
    defer d.close();
    var it = d.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!hasExtension(entry.name, extensions)) continue;
        try names.append(try allocator.dupe(u8, entry.name));
    }
    return names;
}

pub fn freeList(allocator: std.mem.Allocator, list: *std.ArrayList([]u8)) void {
    for (list.items) |n| allocator.free(n);
    list.deinit();
}

pub fn hasExtension(name: []const u8, extensions: []const []const u8) bool {
    for (extensions) |ext| {
        if (name.len > ext.len and std.ascii.eqlIgnoreCase(name[name.len - ext.len ..], ext)) return true;
    }
    return false;
}

/// An environment variable, copied into `buf`. `std.posix.getenv` does not
/// exist on Windows, where the variables are UTF-16.
pub fn getenv(name: [:0]const u8, buf: []u8) ?[]const u8 {
    if (is_windows) return win.getenvWin(name, buf);
    const value = std.posix.getenv(name) orelse return null;
    if (value.len > buf.len) return null;
    @memcpy(buf[0..value.len], value);
    return buf[0..value.len];
}

/// The Windows branch, written against kernel32 only.
const win = if (is_windows) struct {
    const HANDLE = ?*anyopaque;
    const INVALID_HANDLE_VALUE: HANDLE = @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))));
    const GENERIC_READ: u32 = 0x80000000;
    const GENERIC_WRITE: u32 = 0x40000000;
    const FILE_SHARE_READ: u32 = 1;
    const OPEN_EXISTING: u32 = 3;
    const CREATE_ALWAYS: u32 = 2;
    const INVALID_FILE_ATTRIBUTES: u32 = 0xFFFFFFFF;
    const FILE_ATTRIBUTE_DIRECTORY: u32 = 0x10;

    const FILETIME = extern struct { low: u32, high: u32 };
    const WIN32_FIND_DATAA = extern struct {
        attributes: u32,
        creation: FILETIME,
        access: FILETIME,
        write: FILETIME,
        size_high: u32,
        size_low: u32,
        reserved0: u32,
        reserved1: u32,
        file_name: [260]u8,
        alternate: [14]u8,
    };

    extern "kernel32" fn CreateFileA(name: [*:0]const u8, access: u32, share: u32, security: ?*anyopaque, disposition: u32, flags: u32, template: ?*anyopaque) callconv(.C) HANDLE;
    extern "kernel32" fn ReadFile(h: HANDLE, buf: [*]u8, n: u32, read: *u32, overlapped: ?*anyopaque) callconv(.C) c_int;
    extern "kernel32" fn WriteFile(h: HANDLE, buf: [*]const u8, n: u32, written: *u32, overlapped: ?*anyopaque) callconv(.C) c_int;
    extern "kernel32" fn CloseHandle(h: HANDLE) callconv(.C) c_int;
    extern "kernel32" fn GetFileSizeEx(h: HANDLE, size: *i64) callconv(.C) c_int;
    extern "kernel32" fn CreateDirectoryA(name: [*:0]const u8, security: ?*anyopaque) callconv(.C) c_int;
    extern "kernel32" fn DeleteFileA(name: [*:0]const u8) callconv(.C) c_int;
    extern "kernel32" fn GetFileAttributesA(name: [*:0]const u8) callconv(.C) u32;
    extern "kernel32" fn FindFirstFileA(pattern: [*:0]const u8, data: *WIN32_FIND_DATAA) callconv(.C) HANDLE;
    extern "kernel32" fn FindNextFileA(h: HANDLE, data: *WIN32_FIND_DATAA) callconv(.C) c_int;
    extern "kernel32" fn FindClose(h: HANDLE) callconv(.C) c_int;
    extern "kernel32" fn GetEnvironmentVariableA(name: [*:0]const u8, buf: [*]u8, size: u32) callconv(.C) u32;

    pub fn getenvWin(name: [:0]const u8, buf: []u8) ?[]const u8 {
        const n = GetEnvironmentVariableA(name, buf.ptr, @intCast(buf.len));
        if (n == 0 or n >= buf.len) return null;
        return buf[0..n];
    }

    pub fn z(buf: *[max_path]u8, path: []const u8) ![:0]const u8 {
        if (path.len >= buf.len) return error.NameTooLong;
        @memcpy(buf[0..path.len], path);
        buf[path.len] = 0;
        return buf[0..path.len :0];
    }

    pub fn readAllWin(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
        var pb: [max_path]u8 = undefined;
        const p = try z(&pb, path);
        const h = CreateFileA(p, GENERIC_READ, FILE_SHARE_READ, null, OPEN_EXISTING, 0, null);
        if (h == INVALID_HANDLE_VALUE) return error.FileNotFound;
        defer _ = CloseHandle(h);
        var size: i64 = 0;
        if (GetFileSizeEx(h, &size) == 0 or size < 0 or size > 16 * 1024 * 1024) return error.FileTooBig;
        const buf = try allocator.alloc(u8, @intCast(size));
        errdefer allocator.free(buf);
        var done: usize = 0;
        while (done < buf.len) {
            var got: u32 = 0;
            if (ReadFile(h, buf[done..].ptr, @intCast(buf.len - done), &got, null) == 0 or got == 0) return error.ReadFailed;
            done += got;
        }
        return buf;
    }

    pub fn writeAllWin(path: []const u8, bytes: []const u8) !void {
        var pb: [max_path]u8 = undefined;
        const p = try z(&pb, path);
        const h = CreateFileA(p, GENERIC_WRITE, 0, null, CREATE_ALWAYS, 0, null);
        if (h == INVALID_HANDLE_VALUE) return error.AccessDenied;
        defer _ = CloseHandle(h);
        var done: usize = 0;
        while (done < bytes.len) {
            var put: u32 = 0;
            if (WriteFile(h, bytes[done..].ptr, @intCast(bytes.len - done), &put, null) == 0 or put == 0) return error.WriteFailed;
            done += put;
        }
    }

    pub fn existsWin(path: []const u8) bool {
        var pb: [max_path]u8 = undefined;
        const p = z(&pb, path) catch return false;
        return GetFileAttributesA(p) != INVALID_FILE_ATTRIBUTES;
    }

    pub fn makePathWin(path: []const u8) !void {
        if (existsWin(path)) return;
        const parent = std.fs.path.dirname(path);
        if (parent) |pp| {
            if (pp.len > 2) try makePathWin(pp);
        }
        var pb: [max_path]u8 = undefined;
        const p = try z(&pb, path);
        if (CreateDirectoryA(p, null) == 0 and !existsWin(path)) return error.AccessDenied;
    }

    pub fn deleteFileWin(path: []const u8) !void {
        var pb: [max_path]u8 = undefined;
        const p = try z(&pb, path);
        if (DeleteFileA(p) == 0) return error.FileNotFound;
    }

    pub fn listFilesWin(allocator: std.mem.Allocator, dir: []const u8, extensions: []const []const u8, names: *std.ArrayList([]u8)) !void {
        var pb: [max_path]u8 = undefined;
        const pattern = std.fmt.bufPrintZ(&pb, "{s}\\*", .{dir}) catch return error.NameTooLong;
        var data: WIN32_FIND_DATAA = undefined;
        const h = FindFirstFileA(pattern, &data);
        if (h == INVALID_HANDLE_VALUE) return;
        defer _ = FindClose(h);
        while (true) {
            if (data.attributes & FILE_ATTRIBUTE_DIRECTORY == 0) {
                const name = std.mem.sliceTo(&data.file_name, 0);
                if (hasExtension(name, extensions)) try names.append(try allocator.dupe(u8, name));
            }
            if (FindNextFileA(h, &data) == 0) break;
        }
    }
} else struct {};

test "files are written, listed, read back and deleted" {
    if (is_windows) return error.SkipZigTest;
    const allocator = std.testing.allocator;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(base);
    const dir = try std.fmt.allocPrint(allocator, "{s}/a/b", .{base});
    defer allocator.free(dir);
    try makePath(dir);
    try makePath(dir);
    const file = try std.fmt.allocPrint(allocator, "{s}/one.vr09", .{dir});
    defer allocator.free(file);
    try writeAll(file, "hello");
    const other = try std.fmt.allocPrint(allocator, "{s}/two.txt", .{dir});
    defer allocator.free(other);
    try writeAll(other, "x");
    var names = try listFiles(allocator, dir, &.{ ".vr09", ".json" });
    defer freeList(allocator, &names);
    try std.testing.expectEqual(@as(usize, 1), names.items.len);
    try std.testing.expectEqualStrings("one.vr09", names.items[0]);
    const bytes = try readAll(allocator, file);
    defer allocator.free(bytes);
    try std.testing.expectEqualStrings("hello", bytes);
    try std.testing.expect(exists(file));
    try deleteFile(file);
    try std.testing.expect(!exists(file));
}

test "extensions are matched without regard to case" {
    try std.testing.expect(hasExtension("Pad.VR09", &.{".vr09"}));
    try std.testing.expect(!hasExtension(".vr09", &.{".vr09"}));
    try std.testing.expect(!hasExtension("a.txt", &.{".vr09"}));
}
