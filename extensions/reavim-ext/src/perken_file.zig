//! The small files the extension owns under <resource>/Data/Perken: the
//! on/off state (reavim.ini) and the macro registers (macros.ini). Because
//! std.fs's *Absolute calls overflow the stack at REAPER's call depth on
//! Windows (see main.zig's loadBindings), Windows goes through win_file.
const std = @import("std");
const builtin = @import("builtin");
const Reaper = @import("reaper").reaper;
const win_file = @import("win_file.zig");
const state = @import("state.zig");

const dir_rel = "Data/Perken";

fn dirPath(buf: []u8) ?[]const u8 {
    const resource = std.mem.span(Reaper.GetResourcePath());
    return std.fmt.bufPrint(buf, "{s}/{s}", .{ resource, dir_rel }) catch null;
}

fn filePath(buf: []u8, name: []const u8) ?[]const u8 {
    const resource = std.mem.span(Reaper.GetResourcePath());
    return std.fmt.bufPrint(buf, "{s}/{s}/{s}", .{ resource, dir_rel, name }) catch null;
}

/// Writes `content` to Data/Perken/<name>, creating the folder when needed.
pub fn write(name: []const u8, content: []const u8) void {
    // Tests run without REAPER, so there is no resource path to write under.
    if (builtin.is_test) return;
    var dbuf: [std.fs.max_path_bytes]u8 = undefined;
    const dir = dirPath(&dbuf) orelse return;
    var pbuf: [std.fs.max_path_bytes]u8 = undefined;
    const path = filePath(&pbuf, name) orelse return;

    if (builtin.os.tag == .windows) {
        _ = win_file.makeDir(dir); // ok if it already exists (Data/ always does)
        _ = win_file.writeFile(path, content);
        return;
    }
    const io = state.io();
    std.Io.Dir.createDirAbsolute(io, dir, .default_dir) catch {}; // ok if it already exists
    const file = std.Io.Dir.createFileAbsolute(io, path, .{}) catch return;
    defer file.close(io);
    file.writeStreamingAll(io, content) catch {};
}

/// Reads Data/Perken/<name> into `buf`; null when the file is missing.
/// A file longer than the buffer is truncated to it.
pub fn readInto(name: []const u8, buf: []u8) ?[]const u8 {
    if (builtin.is_test) return null;
    var pbuf: [std.fs.max_path_bytes]u8 = undefined;
    const path = filePath(&pbuf, name) orelse return null;
    if (builtin.os.tag == .windows) return win_file.readFileInto(path, buf);
    const io = state.io();
    const file = std.Io.Dir.openFileAbsolute(io, path, .{}) catch return null;
    defer file.close(io);
    const n = file.readPositionalAll(io, buf, 0) catch return null;
    return buf[0..n];
}
