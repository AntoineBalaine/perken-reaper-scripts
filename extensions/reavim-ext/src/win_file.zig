//! Direct user32/kernel32 file I/O for Windows, used in place of std.fs's
//! *Absolute functions at the handful of call sites reached from REAPER's own
//! call chain (loadBindings, vim.zig's on/off persistence, lib_state.zig's
//! bindings-file bootstrap). std.fs.openFileAbsolute and friends do real work
//! internally (UTF-8/UTF-16 conversion, long-path prefixing) that gives them a
//! stack frame big enough to overflow at the depth REAPER calls into this
//! extension at, even though the same call is fine in a standalone program —
//! see the stack-overflow investigation in project notes. The raw win32 calls
//! below have small enough frames to fit in whatever stack room is actually
//! left at that depth.
//!
//! This module is Windows-only; callers gate on builtin.os.tag == .windows
//! and keep using std.fs directly on Linux/macOS, where the original calls
//! are known to work fine.
const std = @import("std");

const HANDLE = ?*anyopaque;
const INVALID_HANDLE_VALUE: HANDLE = @ptrFromInt(@as(usize, @bitCast(@as(isize, -1))));

const GENERIC_READ: u32 = 0x80000000;
const GENERIC_WRITE: u32 = 0x40000000;
const FILE_SHARE_READ: u32 = 1;
const OPEN_EXISTING: u32 = 3;
const CREATE_ALWAYS: u32 = 2;
const INVALID_FILE_ATTRIBUTES: u32 = 0xFFFFFFFF;

const kernel32 = struct {
    extern "kernel32" fn CreateFileA(
        lpFileName: [*:0]const u8,
        dwDesiredAccess: u32,
        dwShareMode: u32,
        lpSecurityAttributes: ?*anyopaque,
        dwCreationDisposition: u32,
        dwFlagsAndAttributes: u32,
        hTemplateFile: ?*anyopaque,
    ) callconv(.C) HANDLE;
    extern "kernel32" fn ReadFile(
        hFile: HANDLE,
        lpBuffer: [*]u8,
        nNumberOfBytesToRead: u32,
        lpNumberOfBytesRead: *u32,
        lpOverlapped: ?*anyopaque,
    ) callconv(.C) c_int;
    extern "kernel32" fn WriteFile(
        hFile: HANDLE,
        lpBuffer: [*]const u8,
        nNumberOfBytesToWrite: u32,
        lpNumberOfBytesWritten: *u32,
        lpOverlapped: ?*anyopaque,
    ) callconv(.C) c_int;
    extern "kernel32" fn CloseHandle(hObject: HANDLE) callconv(.C) c_int;
    extern "kernel32" fn GetFileSizeEx(hFile: HANDLE, lpFileSize: *i64) callconv(.C) c_int;
    extern "kernel32" fn CreateDirectoryA(lpPathName: [*:0]const u8, lpSecurityAttributes: ?*anyopaque) callconv(.C) c_int;
    extern "kernel32" fn GetFileAttributesA(lpFileName: [*:0]const u8) callconv(.C) u32;
};

/// path must be a valid Zig string; a NUL-terminated copy is made on the
/// stack (small — just a path, not a file-content buffer) since CreateFileA
/// needs a [*:0]const u8.
fn withPathZ(path: []const u8, comptime T: type, comptime f: fn ([*:0]const u8) T) ?T {
    var buf: [512]u8 = undefined;
    if (path.len >= buf.len) return null;
    @memcpy(buf[0..path.len], path);
    buf[path.len] = 0;
    return f(buf[0..path.len :0]);
}

fn openForRead(path: []const u8) ?HANDLE {
    const handle = withPathZ(path, HANDLE, struct {
        fn f(p: [*:0]const u8) HANDLE {
            return kernel32.CreateFileA(p, GENERIC_READ, FILE_SHARE_READ, null, OPEN_EXISTING, 0, null);
        }
    }.f) orelse return null;
    if (handle == INVALID_HANDLE_VALUE) return null;
    return handle;
}

/// Reads the whole file into a buffer allocated with `allocator`. Caller owns
/// the returned slice. Returns null on any failure (missing file, read
/// error, allocation failure) — same "just fall back to defaults" contract
/// the std.fs call sites already had.
pub fn readFile(allocator: std.mem.Allocator, path: []const u8) ?[]u8 {
    const handle = openForRead(path) orelse return null;
    defer _ = kernel32.CloseHandle(handle);

    var size: i64 = 0;
    if (kernel32.GetFileSizeEx(handle, &size) == 0) return null;
    if (size < 0 or size > std.math.maxInt(u32)) return null;

    const buf = allocator.alloc(u8, @intCast(size)) catch return null;
    errdefer allocator.free(buf);
    if (buf.len == 0) return buf;

    var total_read: u32 = 0;
    while (total_read < buf.len) {
        var n: u32 = 0;
        if (kernel32.ReadFile(handle, buf.ptr + total_read, @intCast(buf.len - total_read), &n, null) == 0) return null;
        if (n == 0) break; // unexpected EOF before declared size; return what we have
        total_read += n;
    }
    return buf[0..total_read];
}

/// Reads up to `buf.len` bytes into the caller-provided buffer (no heap
/// allocation) — for small, fixed-format files like reavim.ini. Returns the
/// portion actually read, or null on failure.
pub fn readFileInto(path: []const u8, buf: []u8) ?[]const u8 {
    const handle = openForRead(path) orelse return null;
    defer _ = kernel32.CloseHandle(handle);

    var total_read: u32 = 0;
    while (total_read < buf.len) {
        var n: u32 = 0;
        if (kernel32.ReadFile(handle, buf.ptr + total_read, @intCast(buf.len - total_read), &n, null) == 0) return null;
        if (n == 0) break;
        total_read += n;
    }
    return buf[0..total_read];
}

/// Creates (or overwrites) `path` with `content`. Returns true on success.
pub fn writeFile(path: []const u8, content: []const u8) bool {
    const handle = withPathZ(path, HANDLE, struct {
        fn f(p: [*:0]const u8) HANDLE {
            return kernel32.CreateFileA(p, GENERIC_WRITE, 0, null, CREATE_ALWAYS, 0, null);
        }
    }.f) orelse return false;
    if (handle == INVALID_HANDLE_VALUE) return false;
    defer _ = kernel32.CloseHandle(handle);

    var written: u32 = 0;
    while (written < content.len) {
        var n: u32 = 0;
        if (kernel32.WriteFile(handle, content.ptr + written, @intCast(content.len - written), &n, null) == 0) return false;
        if (n == 0) return false;
        written += n;
    }
    return true;
}

/// Creates `path` as a directory. Returns true on success or if it already exists.
pub fn makeDir(path: []const u8) bool {
    const ok = withPathZ(path, c_int, struct {
        fn f(p: [*:0]const u8) c_int {
            return kernel32.CreateDirectoryA(p, null);
        }
    }.f) orelse return false;
    if (ok != 0) return true;
    // ERROR_ALREADY_EXISTS is not surfaced separately here (no GetLastError
    // call); re-check via attributes instead, matching this module's other
    // best-effort, no-error-detail contract.
    return exists(path);
}

/// True if `path` exists (file or directory).
pub fn exists(path: []const u8) bool {
    const attrs = withPathZ(path, u32, struct {
        fn f(p: [*:0]const u8) u32 {
            return kernel32.GetFileAttributesA(p);
        }
    }.f) orelse return false;
    return attrs != INVALID_FILE_ATTRIBUTES;
}
