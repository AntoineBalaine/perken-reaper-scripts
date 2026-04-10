const std = @import("std");
const reaper = @import("reaper").reaper;

const BrowseForSaveFileFn = *fn (
    defext: [*:0]const u8,
    file: [*]u8,
    file_len: c_int,
    title: [*:0]const u8,
    filter: [*:0]const u8,
) callconv(.C) bool;

var browse_fn: ?BrowseForSaveFileFn = null;
var resolved: bool = false;

fn resolve() ?BrowseForSaveFileFn {
    if (resolved) return browse_fn;
    resolved = true;
    const ptr = reaper.plugin_getapi("BrowseForSaveFile") orelse return null;
    browse_fn = @ptrCast(@alignCast(ptr));
    return browse_fn;
}

/// Opens the native file picker for saving a file. Returns the selected
/// path as a sentinel-terminated slice into `buf`, or null if the user
/// cancelled or the SWELL function is unavailable.
pub fn browseForSaveFile(
    title: [:0]const u8,
    initial_file: [:0]const u8,
    filter: [:0]const u8,
    buf: []u8,
) ?[:0]const u8 {
    const func = resolve() orelse return null;
    if (buf.len == 0) return null;

    // Copy initial_file into buf as the starting value
    const copy_len = @min(initial_file.len, buf.len - 1);
    @memcpy(buf[0..copy_len], initial_file[0..copy_len]);
    buf[copy_len] = 0;

    const selected = func(
        "",
        buf.ptr,
        @intCast(buf.len),
        title.ptr,
        filter.ptr,
    );

    if (!selected) return null;

    // Find the sentinel in the buffer
    const len = std.mem.indexOfScalar(u8, buf, 0) orelse return null;
    return buf[0..len :0];
}

/// Validates that a file path resides within the expected layouts
/// directory. Returns true if the path starts with the directory prefix.
pub fn isPathInsideDir(path: []const u8, dir: []const u8) bool {
    if (dir.len == 0) return false;
    if (path.len < dir.len) return false;
    // Normalize: ensure the directory check includes a trailing separator
    if (std.mem.startsWith(u8, path, dir)) {
        if (dir.len == path.len) return true;
        if (dir[dir.len - 1] == '/' or dir[dir.len - 1] == '\\') return true;
        if (path[dir.len] == '/' or path[dir.len] == '\\') return true;
    }
    return false;
}

// Tests

test "swell: isPathInsideDir accepts valid subpaths" {
    try std.testing.expect(isPathInsideDir("/home/user/layouts/fx.json", "/home/user/layouts"));
    try std.testing.expect(isPathInsideDir("/home/user/layouts/sub/fx.json", "/home/user/layouts"));
    try std.testing.expect(isPathInsideDir("/home/user/layouts/", "/home/user/layouts/"));
}

test "swell: isPathInsideDir rejects paths outside directory" {
    try std.testing.expect(!isPathInsideDir("/home/user/other/fx.json", "/home/user/layouts"));
    try std.testing.expect(!isPathInsideDir("/home/user/layout", "/home/user/layouts"));
    try std.testing.expect(!isPathInsideDir("", "/home/user/layouts"));
    try std.testing.expect(!isPathInsideDir("/any/path", ""));
}
