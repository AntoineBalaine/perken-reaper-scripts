//! Batch rename of the selected tracks in an external editor (the user's
//! $VISUAL or $EDITOR, falling back to vim).
//!
//! REAPER's API is only callable in-process and the editor runs in a separate
//! terminal, so the exchange goes through files under
//! <resource>/Data/Perken/rename/:
//!   1. tracks.txt holds the selected tracks' names, one per line, and the
//!      session remembers each track's GUID in the same order.
//!   2. edit.command is a small shell script that records its terminal
//!      device into `tty`, runs the editor on tracks.txt, and then writes the
//!      editor's exit status into `done`.
//!   3. The configured terminal command is launched with that script.
//!   4. A timer polls for `done`. Once it exists, line N of tracks.txt becomes
//!      the name of track N, inside a single undo block.
//!   5. On macOS, about a second later (once the script and its shell have
//!      exited, so that Terminal.app does not ask to terminate a running
//!      process), close.applescript closes the Terminal.app window whose tab
//!      shows that terminal device.
//!
//! Because the line order is what maps a name to a track, the rename is
//! refused when the line count changed. Quitting the editor with a non-zero
//! status (`:cq` in vim) cancels the rename.
const std = @import("std");
const builtin = @import("builtin");
const Reaper = @import("reaper").reaper;
const actions = @import("actions.zig");
const helpers = @import("ported/helpers.zig");

const log = std.log.scoped(.engine);

/// macOS opens the script in Terminal.app, which runs it through the user's
/// login shell. Other platforms use the Debian-style terminal alternative.
pub const default_terminal: []const u8 = switch (builtin.os.tag) {
    .macos => "open -a Terminal",
    else => "x-terminal-emulator -e",
};
/// An empty editor means "the user's default editor". The script runs in the
/// terminal's login shell, where the user's profile has set $VISUAL and
/// $EDITOR, so it resolves them there rather than from REAPER's environment.
pub const default_editor: []const u8 = "";
const user_editor_expr = "${VISUAL:-${EDITOR:-vim}}";
/// Terminal.app is the only terminal the auto-close knows how to drive, and
/// it only exists on macOS.
pub const default_close_terminal = builtin.os.tag == .macos;

/// The terminal command, which receives the script path as its last argument.
/// It is set from the [rename] section of bindings.ini at load.
pub var terminal: []const u8 = default_terminal;
/// The editor command, which receives the names file as its last argument.
/// Empty selects the user's default editor.
pub var editor: []const u8 = default_editor;
/// Whether to close the Terminal.app window once the editor has exited.
pub var close_terminal: bool = default_close_terminal;

pub const MAX_TRACKS = 1024;
const GUID_LEN = 64;
const MAX_FILE_BYTES = 1024 * 1024;
/// The timer runs at roughly 30Hz, so this polls the done file a few times
/// per second.
const POLL_EVERY_TICKS = 10;
/// The delay between the editor exiting and the window being closed, which
/// lets the launcher script and its login shell exit first.
const CLOSE_DELAY_TICKS = 30;

/// Closes the Terminal.app window whose tab runs on the given tty. It does
/// nothing when Terminal.app is not running (so it never launches it), and
/// leaves windows with several tabs alone, because closing the window would
/// close the user's other tabs too.
const close_script =
    \\on run argv
    \\    set target to item 1 of argv
    \\    if application "Terminal" is not running then return
    \\    tell application "Terminal"
    \\        repeat with w in windows
    \\            if (count of tabs of w) is 1 and tty of tab 1 of w is target then
    \\                close w
    \\                return
    \\            end if
    \\        end repeat
    \\    end tell
    \\end run
    \\
;

pub const Phase = enum { idle, editing, closing };

pub const Session = struct {
    phase: Phase = .idle,
    count: usize = 0,
    guids: [MAX_TRACKS][GUID_LEN]u8 = undefined,
    dir_buf: [std.fs.max_path_bytes]u8 = undefined,
    dir_len: usize = 0,
    ticks: u32 = 0,
    close_at: u32 = 0,
    tty_buf: [64]u8 = undefined,
    tty_len: usize = 0,
    timer_registered: bool = false,

    pub fn dir(self: *const Session) []const u8 {
        return self.dir_buf[0..self.dir_len];
    }
};

pub var session: Session = .{};

/// Builds "<session dir>/<name>" into `buf`.
pub fn sessionPath(buf: []u8, name: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(buf, "{s}/{s}", .{ session.dir(), name }) catch null;
}

/// Writes `s` single-quoted for /bin/sh. A single quote inside `s` closes the
/// quoted span, emits an escaped quote, and reopens the span.
pub fn writeShellQuoted(w: anytype, s: []const u8) !void {
    try w.writeByte('\'');
    for (s) |c| {
        if (c == '\'') {
            try w.writeAll("'\\''");
        } else {
            try w.writeByte(c);
        }
    }
    try w.writeByte('\'');
}

/// Writes one track name per line. Because a newline inside a name would
/// shift every following line onto the wrong track, line breaks inside a
/// name are written as spaces.
pub fn writeNameLine(w: anytype, name: []const u8) !void {
    for (name) |c| {
        try w.writeByte(if (c == '\n' or c == '\r') ' ' else c);
    }
    try w.writeByte('\n');
}

/// Splits the edited file into names. A single trailing newline (which every
/// editor adds) does not count as an extra empty line, and CRLF line endings
/// are accepted. Returns the number of names written into `out`, or null when
/// there are more lines than `out` can hold.
pub fn splitNames(content: []const u8, out: [][]const u8) ?usize {
    var body = content;
    if (body.len > 0 and body[body.len - 1] == '\n') body = body[0 .. body.len - 1];
    var n: usize = 0;
    var it = std.mem.splitScalar(u8, body, '\n');
    while (it.next()) |line| {
        if (n >= out.len) return null;
        out[n] = std.mem.trimRight(u8, line, "\r");
        n += 1;
    }
    return n;
}

/// Entry point for the action: writes the names file and opens the editor.
pub fn start() void {
    const total = Reaper.CountSelectedTracks(0);
    if (total <= 0) {
        log.info("batch rename: no track selected", .{});
        return;
    }

    const resource = std.mem.span(Reaper.GetResourcePath());
    session.dir_len = (std.fmt.bufPrint(&session.dir_buf, "{s}/Data/Perken/rename", .{resource}) catch return).len;
    std.fs.cwd().makePath(session.dir()) catch |err| {
        log.warn("batch rename: cannot create {s}: {s}", .{ session.dir(), @errorName(err) });
        return;
    };

    // A previous session whose terminal was closed never writes its done
    // file, so starting a new rename simply replaces it.
    var done_buf: [std.fs.max_path_bytes]u8 = undefined;
    const done_path = sessionPath(&done_buf, "done") orelse return;
    std.fs.deleteFileAbsolute(done_path) catch {};
    var tty_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const tty_path = sessionPath(&tty_path_buf, "tty") orelse return;
    std.fs.deleteFileAbsolute(tty_path) catch {};

    if (!writeNamesFile()) return;
    if (!writeScript(done_path)) return;
    if (!launchTerminal()) return;

    session.phase = .editing;
    session.ticks = 0;
    if (!session.timer_registered) {
        _ = Reaper.plugin_register("timer", @constCast(@ptrCast(&onTimer)));
        session.timer_registered = true;
    }
    log.info("batch rename: editing {d} track names", .{session.count});
}

pub fn writeNamesFile() bool {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = sessionPath(&path_buf, "tracks.txt") orelse return false;
    const file = std.fs.createFileAbsolute(path, .{}) catch |err| {
        log.warn("batch rename: cannot write {s}: {s}", .{ path, @errorName(err) });
        return false;
    };
    defer file.close();
    var bw = std.io.bufferedWriter(file.writer());
    const w = bw.writer();

    session.count = 0;
    const total = Reaper.CountSelectedTracks(0);
    var i: c_int = 0;
    while (i < total and session.count < MAX_TRACKS) : (i += 1) {
        const tr = Reaper.GetSelectedTrack(0, i) orelse continue;
        const guid_slot = &session.guids[session.count];
        @memset(guid_slot, 0);
        _ = helpers.getTrackString(tr, "GUID", guid_slot) orelse continue;
        var name_buf: [512]u8 = undefined;
        const name = helpers.getTrackString(tr, "P_NAME", &name_buf) orelse "";
        writeNameLine(w, name) catch return false;
        session.count += 1;
    }
    bw.flush() catch return false;
    return session.count > 0;
}

pub fn writeScript(done_path: []const u8) bool {
    var names_buf: [std.fs.max_path_bytes]u8 = undefined;
    const names_path = sessionPath(&names_buf, "tracks.txt") orelse return false;
    var script_buf: [std.fs.max_path_bytes]u8 = undefined;
    const script_path = sessionPath(&script_buf, "edit.command") orelse return false;

    const file = std.fs.createFileAbsolute(script_path, .{ .mode = 0o755 }) catch |err| {
        log.warn("batch rename: cannot write {s}: {s}", .{ script_path, @errorName(err) });
        return false;
    };
    defer file.close();
    var bw = std.io.bufferedWriter(file.writer());
    const w = bw.writer();
    var tty_buf: [std.fs.max_path_bytes]u8 = undefined;
    const tty_path = sessionPath(&tty_buf, "tty") orelse return false;
    w.writeAll("#!/bin/sh\ntty > ") catch return false;
    writeShellQuoted(w, tty_path) catch return false;
    // The editor is spliced in unquoted on purpose, so that it may carry its
    // own arguments (e.g. "nvim -u NONE" or "code --wait").
    const editor_cmd = if (editor.len == 0) user_editor_expr else editor;
    w.print("\n{s} ", .{editor_cmd}) catch return false;
    writeShellQuoted(w, names_path) catch return false;
    w.writeAll("\necho $? > ") catch return false;
    writeShellQuoted(w, done_path) catch return false;
    w.writeAll("\nexit\n") catch return false;
    bw.flush() catch return false;
    return true;
}

/// Runs the terminal command in the background (see runDetached).
pub fn launchTerminal() bool {
    if (builtin.os.tag == .windows) {
        log.warn("batch rename: not supported on Windows yet", .{});
        return false;
    }
    var script_buf: [std.fs.max_path_bytes]u8 = undefined;
    const script_path = sessionPath(&script_buf, "edit.command") orelse return false;

    var cmd_buf: [std.fs.max_path_bytes * 2]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&cmd_buf);
    const w = fbs.writer();
    w.print("{s} ", .{terminal}) catch return false;
    writeShellQuoted(w, script_path) catch return false;
    w.writeAll(" >/dev/null 2>&1 &") catch return false;
    runDetached(fbs.getWritten());
    return true;
}

pub fn stopTimer() void {
    session.phase = .idle;
    if (session.timer_registered) {
        _ = Reaper.plugin_register("-timer", @constCast(@ptrCast(&onTimer)));
        session.timer_registered = false;
    }
}

pub fn onTimer() callconv(.C) void {
    session.ticks += 1;
    switch (session.phase) {
        .idle => {},
        .editing => {
            if (session.ticks % POLL_EVERY_TICKS == 0) pollDone();
        },
        .closing => {
            if (session.ticks < session.close_at) return;
            stopTimer();
            closeTerminalWindow();
        },
    }
}

/// Checks whether the editor has exited; when it has, applies or cancels the
/// rename and then schedules the window close or stops the timer.
pub fn pollDone() void {
    var done_buf: [std.fs.max_path_bytes]u8 = undefined;
    const done_path = sessionPath(&done_buf, "done") orelse return;
    var status_buf: [16]u8 = undefined;
    const status_raw = std.fs.cwd().readFile(done_path, &status_buf) catch return;
    std.fs.deleteFileAbsolute(done_path) catch {};

    const status = std.mem.trim(u8, status_raw, " \t\r\n");
    if (std.mem.eql(u8, status, "0")) {
        applyNames();
    } else {
        log.info("batch rename: editor exited with status {s}, rename cancelled", .{status});
    }

    if (close_terminal and readTty()) {
        session.phase = .closing;
        session.close_at = session.ticks + CLOSE_DELAY_TICKS;
    } else {
        stopTimer();
    }
}

/// Reads the terminal device the launcher script recorded. Returns false
/// when it is missing or is not a device path (e.g. "not a tty").
pub fn readTty() bool {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = sessionPath(&path_buf, "tty") orelse return false;
    const raw = std.fs.cwd().readFile(path, &session.tty_buf) catch return false;
    const tty = std.mem.trim(u8, raw, " \t\r\n");
    if (!std.mem.startsWith(u8, tty, "/dev/")) return false;
    std.mem.copyForwards(u8, &session.tty_buf, tty);
    session.tty_len = tty.len;
    return true;
}

/// Writes close.applescript and runs it in the background with the recorded
/// tty. macOS asks once for permission to let REAPER control Terminal.app;
/// when it is refused, the window simply stays open.
pub fn closeTerminalWindow() void {
    if (builtin.os.tag != .macos) return;
    var script_buf: [std.fs.max_path_bytes]u8 = undefined;
    const script_path = sessionPath(&script_buf, "close.applescript") orelse return;
    std.fs.cwd().writeFile(.{ .sub_path = script_path, .data = close_script }) catch |err| {
        log.warn("batch rename: cannot write {s}: {s}", .{ script_path, @errorName(err) });
        return;
    };

    var cmd_buf: [std.fs.max_path_bytes * 2]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&cmd_buf);
    const w = fbs.writer();
    w.writeAll("osascript ") catch return;
    writeShellQuoted(w, script_path) catch return;
    w.writeByte(' ') catch return;
    writeShellQuoted(w, session.tty_buf[0..session.tty_len]) catch return;
    w.writeAll(" >/dev/null 2>&1 &") catch return;
    runDetached(fbs.getWritten());
}

/// Runs a shell command line through /bin/sh. The command line ends with
/// "&", so the shell exits right away: waiting on it does not block REAPER,
/// and the background process is not left as a zombie child of REAPER.
pub fn runDetached(cmd: []const u8) void {
    const argv = [_][]const u8{ "/bin/sh", "-c", cmd };
    var child = std.process.Child.init(&argv, std.heap.c_allocator);
    child.spawn() catch |err| {
        log.warn("batch rename: cannot run '{s}': {s}", .{ cmd, @errorName(err) });
        return;
    };
    _ = child.wait() catch {};
}

pub fn applyNames() void {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = sessionPath(&path_buf, "tracks.txt") orelse return;
    const content = std.fs.cwd().readFileAlloc(std.heap.c_allocator, path, MAX_FILE_BYTES) catch |err| {
        log.warn("batch rename: cannot read {s}: {s}", .{ path, @errorName(err) });
        return;
    };
    defer std.heap.c_allocator.free(content);

    var names: [MAX_TRACKS][]const u8 = undefined;
    const n = splitNames(content, &names) orelse MAX_TRACKS + 1;
    if (n != session.count) {
        var msg_buf: [256:0]u8 = undefined;
        const msg = std.fmt.bufPrintZ(&msg_buf, "The edited list has {d} lines but {d} tracks were selected.\nNo track was renamed.", .{ n, session.count }) catch return;
        _ = Reaper.ShowMessageBox(msg, "ReaVim: batch rename", 0);
        return;
    }

    Reaper.Undo_BeginBlock();
    var renamed: usize = 0;
    for (names[0..n], session.guids[0..n]) |name, *guid| {
        const tr = findTrackByGuid(std.mem.sliceTo(guid, 0)) orelse continue;
        if (helpers.setTrackString(tr, "P_NAME", name)) renamed += 1;
    }
    Reaper.Undo_EndBlock("ReaVim: batch rename tracks", -1);
    Reaper.UpdateArrange();
    log.info("batch rename: renamed {d}/{d} tracks", .{ renamed, n });
}

/// Tracks are looked up by GUID because the user may have reordered or
/// deleted tracks while the editor was open.
pub fn findTrackByGuid(guid: []const u8) ?Reaper.MediaTrack {
    const total = Reaper.CountTracks(0);
    var i: c_int = 0;
    while (i < total) : (i += 1) {
        const tr = Reaper.GetTrack(0, i) orelse continue;
        var buf: [GUID_LEN]u8 = undefined;
        const g = helpers.getTrackString(tr, "GUID", &buf) orelse continue;
        if (std.mem.eql(u8, g, guid)) return tr;
    }
    return null;
}

pub fn batchRenameAction(_: *actions.RunCtx) void {
    start();
}

pub const entries = [_]actions.Entry{
    .{ .name = "BatchRenameTracks", .def = .{ .steps = &.{.{ .func = &batchRenameAction }}, .desc = "Batch rename tracks in editor" } },
};

test "splitNames: trailing newline, CRLF, empty names" {
    var out: [8][]const u8 = undefined;
    const n = splitNames("Kick\r\nSnare\n\nBass\n", &out).?;
    try std.testing.expectEqual(@as(usize, 4), n);
    try std.testing.expectEqualStrings("Kick", out[0]);
    try std.testing.expectEqualStrings("Snare", out[1]);
    try std.testing.expectEqualStrings("", out[2]);
    try std.testing.expectEqualStrings("Bass", out[3]);

    // Without a trailing newline the count is the same.
    try std.testing.expectEqual(@as(usize, 2), splitNames("a\nb", &out).?);
    // Too many lines for the output buffer.
    var small: [1][]const u8 = undefined;
    try std.testing.expect(splitNames("a\nb\n", &small) == null);
}

test "writeShellQuoted escapes single quotes" {
    var buf: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try writeShellQuoted(fbs.writer(), "/a b/it's");
    try std.testing.expectEqualStrings("'/a b/it'\\''s'", fbs.getWritten());
}

test "writeNameLine flattens embedded line breaks" {
    var buf: [64]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try writeNameLine(fbs.writer(), "Lead\nVox");
    try std.testing.expectEqualStrings("Lead Vox\n", fbs.getWritten());
}
