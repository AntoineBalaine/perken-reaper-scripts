//! Fuzzy search over every action REAPER knows ("Perken: Search actions with
//! fzf"). Like the batch rename, it runs in a terminal window, because fzf
//! is a terminal program, so the exchange goes through files under
//! <resource>/Data/Perken/actions:
//!
//!   1. list.tsv holds one "<command id><TAB><action name>" line per action
//!      of REAPER's main section (kbd_enumerateActions), extensions and
//!      scripts included.
//!   2. search.command runs fzf on that list, shows only the names, and
//!      writes the chosen line to result.txt, then its exit status to done.
//!   3. A timer polls for done; on status 0 the chosen command id runs.
//!
//! The terminal is the one configured in [rename] terminal (see config.zig).
const std = @import("std");
const builtin = @import("builtin");
const Reaper = @import("reaper").reaper;
const actions = @import("actions.zig");
const config = @import("config.zig");
const batch_rename = @import("batch_rename.zig");

const log = std.log.scoped(.action_search);

/// Because the person is waiting on the chosen action, the done file is
/// checked on every timer tick (once per frame, about 30 times a second), so
/// the action runs as soon as fzf has exited. Each check is one failed file
/// open, and only happens while a search is open.
const POLL_EVERY_TICKS = 1;
/// A safety cap on the enumeration, which ends when REAPER returns 0.
const MAX_ACTIONS = 500_000;

pub const Session = struct {
    dir_buf: [std.fs.max_path_bytes]u8 = undefined,
    dir_len: usize = 0,
    ticks: u32 = 0,
    waiting: bool = false,
    timer_registered: bool = false,

    pub fn dir(self: *const Session) []const u8 {
        return self.dir_buf[0..self.dir_len];
    }
};

pub var session: Session = .{};

/// The [rename] settings, re-read at every search so that edits to the
/// terminal apply without restarting REAPER.
pub var settings: ?config.Settings = null;

pub fn sessionPath(buf: []u8, name: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(buf, "{s}/{s}", .{ session.dir(), name }) catch null;
}

/// Writes one "<id><TAB><name>" line. Because a tab inside a name would
/// split it into extra fields and a line break would split the entry, both
/// are written as spaces.
pub fn writeListLine(w: anytype, id: c_int, name: []const u8) !void {
    try w.print("{d}\t", .{id});
    for (name) |c| {
        try w.writeByte(if (c == '\t' or c == '\n' or c == '\r') ' ' else c);
    }
    try w.writeByte('\n');
}

/// The command id at the start of a chosen line, or null when the line has
/// none (fzf was cancelled, or the file is damaged).
pub fn parseSelection(line: []const u8) ?c_int {
    const end = std.mem.indexOfScalar(u8, line, '\t') orelse line.len;
    const id = std.fmt.parseInt(c_int, std.mem.trim(u8, line[0..end], " \r\n"), 10) catch return null;
    return if (id > 0) id else null;
}

/// REAPER's main actions section. The binding returns it as a pointer to the
/// section pointer, so the function is re-typed to return the pointer itself.
pub fn mainSection() ?Reaper.KbdSectionInfo {
    const f: *const fn (uniqueID: c_int) callconv(.C) ?Reaper.KbdSectionInfo = @ptrCast(Reaper.SectionFromUniqueID);
    return f(0);
}

/// Re-types the binding, which declares `nameOut` as a plain string instead
/// of the pointer to a string that REAPER fills in.
pub fn enumerateActions(section: Reaper.KbdSectionInfo, idx: c_int, name: *?[*:0]const u8) c_int {
    const f: *const fn (section: Reaper.KbdSectionInfo, idx: c_int, nameOut: *?[*:0]const u8) callconv(.C) c_int = @ptrCast(Reaper.kbd_enumerateActions);
    return f(section, idx, name);
}

fn writeListFile(path: []const u8) bool {
    const file = std.fs.createFileAbsolute(path, .{}) catch |err| {
        log.warn("cannot write {s}: {s}", .{ path, @errorName(err) });
        return false;
    };
    defer file.close();
    var bw = std.io.bufferedWriter(file.writer());
    const w = bw.writer();

    const section = mainSection() orelse {
        log.warn("REAPER has no main actions section", .{});
        return false;
    };
    var idx: c_int = 0;
    while (idx < MAX_ACTIONS) : (idx += 1) {
        var name: ?[*:0]const u8 = null;
        const id = enumerateActions(section, idx, &name);
        if (id == 0) break;
        const text = if (name) |n| std.mem.span(n) else "";
        writeListLine(w, id, text) catch return false;
    }
    bw.flush() catch return false;
    return idx > 0;
}

fn writeScript(script_path: []const u8, list_path: []const u8, result_path: []const u8, done_path: []const u8) bool {
    const file = std.fs.createFileAbsolute(script_path, .{ .mode = 0o755 }) catch |err| {
        log.warn("cannot write {s}: {s}", .{ script_path, @errorName(err) });
        return false;
    };
    defer file.close();
    var bw = std.io.bufferedWriter(file.writer());
    const w = bw.writer();
    // Because REAPER (and so the terminal it opens) may not have Homebrew's
    // folders on its PATH, the usual install locations are appended.
    w.writeAll("#!/bin/sh\nPATH=\"$PATH:/opt/homebrew/bin:/usr/local/bin\"\n") catch return false;
    w.writeAll("if ! command -v fzf >/dev/null 2>&1; then\n  echo 'fzf was not found: install it (e.g. brew install fzf).'\n  echo 127 > ") catch return false;
    batch_rename.writeShellQuoted(w, done_path) catch return false;
    w.writeAll("\n  sleep 3\n  exit\nfi\n") catch return false;
    w.writeAll("fzf --delimiter \"$(printf '\\t')\" --with-nth 2.. --layout reverse --prompt 'action > ' < ") catch return false;
    batch_rename.writeShellQuoted(w, list_path) catch return false;
    w.writeAll(" > ") catch return false;
    batch_rename.writeShellQuoted(w, result_path) catch return false;
    w.writeAll("\necho $? > ") catch return false;
    batch_rename.writeShellQuoted(w, done_path) catch return false;
    w.writeAll("\nexit\n") catch return false;
    bw.flush() catch return false;
    return true;
}

pub fn start() void {
    // Because of the same terminal launcher and std.fs depth limits as the
    // batch rename (see batch_rename.start), Windows is refused up front.
    if (builtin.os.tag == .windows) {
        log.warn("action search: not supported on Windows yet", .{});
        return;
    }

    if (settings) |*st| st.deinit();
    settings = config.load(std.heap.c_allocator);

    const resource = std.mem.span(Reaper.GetResourcePath());
    session.dir_len = (std.fmt.bufPrint(&session.dir_buf, "{s}/Data/Perken/actions", .{resource}) catch return).len;
    std.fs.cwd().makePath(session.dir()) catch |err| {
        log.warn("cannot create {s}: {s}", .{ session.dir(), @errorName(err) });
        return;
    };

    var list_buf: [std.fs.max_path_bytes]u8 = undefined;
    var script_buf: [std.fs.max_path_bytes]u8 = undefined;
    var result_buf: [std.fs.max_path_bytes]u8 = undefined;
    var done_buf: [std.fs.max_path_bytes]u8 = undefined;
    const list_path = sessionPath(&list_buf, "list.tsv") orelse return;
    const script_path = sessionPath(&script_buf, "search.command") orelse return;
    const result_path = sessionPath(&result_buf, "result.txt") orelse return;
    const done_path = sessionPath(&done_buf, "done") orelse return;

    // A previous search whose terminal was closed never writes its done
    // file, so a new search replaces it.
    std.fs.deleteFileAbsolute(done_path) catch {};
    std.fs.deleteFileAbsolute(result_path) catch {};

    if (!writeListFile(list_path)) return;
    if (!writeScript(script_path, list_path, result_path, done_path)) return;

    var cmd_buf: [std.fs.max_path_bytes * 2]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&cmd_buf);
    const w = fbs.writer();
    const term = if (settings) |st| st.rename_terminal else config.default_terminal;
    w.print("{s} ", .{term}) catch return;
    batch_rename.writeShellQuoted(w, script_path) catch return;
    w.writeAll(" >/dev/null 2>&1 &") catch return;
    batch_rename.runDetached(fbs.getWritten());

    session.waiting = true;
    session.ticks = 0;
    if (!session.timer_registered) {
        _ = Reaper.plugin_register("timer", @constCast(@ptrCast(&onTimer)));
        session.timer_registered = true;
    }
}

fn stopTimer() void {
    session.waiting = false;
    if (session.timer_registered) {
        _ = Reaper.plugin_register("-timer", @constCast(@ptrCast(&onTimer)));
        session.timer_registered = false;
    }
}

pub fn onTimer() callconv(.C) void {
    if (!session.waiting) return;
    session.ticks += 1;
    if (session.ticks % POLL_EVERY_TICKS == 0) pollDone();
}

/// Checks whether fzf has exited; when it chose an action, runs it.
fn pollDone() void {
    var done_buf: [std.fs.max_path_bytes]u8 = undefined;
    const done_path = sessionPath(&done_buf, "done") orelse return;
    var status_buf: [16]u8 = undefined;
    const status_raw = std.fs.cwd().readFile(done_path, &status_buf) catch return;
    std.fs.deleteFileAbsolute(done_path) catch {};
    stopTimer();

    const status = std.mem.trim(u8, status_raw, " \t\r\n");
    if (!std.mem.eql(u8, status, "0")) {
        log.info("action search: fzf exited with status {s}, nothing to run", .{status});
        return;
    }

    var result_buf: [std.fs.max_path_bytes]u8 = undefined;
    const result_path = sessionPath(&result_buf, "result.txt") orelse return;
    var line_buf: [1024]u8 = undefined;
    const line = std.fs.cwd().readFile(result_path, &line_buf) catch return;
    const id = parseSelection(line) orelse {
        log.warn("action search: no command id in the chosen line", .{});
        return;
    };
    log.info("action search: running command {d}", .{id});
    Reaper.Main_OnCommand(id, 0);
}

fn searchActions(_: *actions.RunCtx) void {
    start();
}

pub const entries = [_]actions.Entry{
    .{ .name = "SearchActions", .def = .{ .steps = &.{.{ .func = &searchActions }}, .desc = "Search actions with fzf" } },
};

test "writeListLine keeps one entry on one line" {
    var buf: [128]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try writeListLine(fbs.writer(), 40707, "Item: Set to\tdefault\ncolor");
    try std.testing.expectEqualStrings("40707\tItem: Set to default color\n", fbs.getWritten());
}

test "parseSelection reads the id before the first tab" {
    try std.testing.expectEqual(@as(?c_int, 40707), parseSelection("40707\tItem: Set to default color\n"));
    try std.testing.expectEqual(@as(?c_int, 7), parseSelection("7"));
    try std.testing.expectEqual(@as(?c_int, null), parseSelection(""));
    try std.testing.expectEqual(@as(?c_int, null), parseSelection("abc\tname"));
    try std.testing.expectEqual(@as(?c_int, null), parseSelection("0\tname"));
}
