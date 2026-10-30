//! OpenTerminalInProjectDir: opens a shell in the folder of the current
//! project, so that a script, git or a file tool can be run next to the
//! project's files.
//!
//! Because a project that was never saved has no folder of its own, the
//! action falls back to the project's recording path, and tells the user when
//! even that is unknown.
const std = @import("std");
const globals = @import("globals.zig");
const builtin = @import("builtin");
const Reaper = @import("reaper").reaper;
const actions = @import("actions.zig");
const config = @import("config.zig");
const batch_rename = @import("batch_rename.zig");

const log = std.log.scoped(.terminal);

const dialog_title = "Perken: Open project path in terminal";

/// The folder of the project file, or null when the project was not saved.
pub fn projectFolder(path: []const u8) ?[]const u8 {
    if (path.len == 0) return null;
    return std.fs.path.dirname(path);
}

/// The launcher script that the terminal runs: it moves to the project folder
/// and replaces itself with the user's login shell.
pub fn writeScript(w: anytype, dir: []const u8) !void {
    try w.writeAll("#!/bin/sh\ncd ");
    try batch_rename.writeShellQuoted(w, dir);
    try w.writeAll(" || exit 1\nexec \"${SHELL:-/bin/sh}\" -l\n");
}

/// The shell command line that starts the terminal on the launcher script.
/// Because the [rename] terminal setting is a command that receives a script
/// as its last argument (Terminal.app opens a .command file; Ghostty and
/// x-terminal-emulator take it after -e), this action follows the same rule,
/// so one setting serves both actions. The line ends with "&" so that the
/// shell returns right away (see batch_rename.runDetached).
pub fn commandLine(w: anytype, terminal: []const u8, script: []const u8) !void {
    try w.print("{s} ", .{terminal});
    try batch_rename.writeShellQuoted(w, script);
    try w.writeAll(" >/dev/null 2>&1 &");
}

fn showError(message: [:0]const u8) void {
    _ = Reaper.ShowMessageBox(message, dialog_title, 0);
}

fn openTerminal(_: *actions.RunCtx) void {
    const io = globals.io();
    // The shell is started through /bin/sh, which Windows does not have.
    if (builtin.os.tag == .windows) {
        return showError("Because this action starts the shell through /bin/sh, it is not available on Windows yet.");
    }

    var file_buf: [std.fs.max_path_bytes:0]u8 = undefined;
    file_buf[0] = 0;
    _ = Reaper.EnumProjects(-1, &file_buf, @intCast(file_buf.len));
    var dir: []const u8 = projectFolder(std.mem.sliceTo(&file_buf, 0)) orelse "";

    var rec_buf: [std.fs.max_path_bytes:0]u8 = undefined;
    if (dir.len == 0) {
        rec_buf[0] = 0;
        Reaper.GetProjectPath(@ptrCast(&rec_buf), @intCast(rec_buf.len));
        dir = std.mem.sliceTo(&rec_buf, 0);
    }
    if (dir.len == 0) {
        return showError("Because the project has not been saved, it has no folder yet. Save the project first.");
    }

    // The script lives next to the batch-rename files, under REAPER's
    // resource path, and is rewritten on every call.
    const resource = std.mem.span(Reaper.GetResourcePath());
    var script_buf: [std.fs.max_path_bytes]u8 = undefined;
    const script = std.fmt.bufPrint(&script_buf, "{s}/Data/Perken/shell.command", .{resource}) catch {
        return showError("Because the REAPER resource path is too long, the shell was not opened.");
    };
    var body_buf: [std.fs.max_path_bytes * 2]u8 = undefined;
    var body: std.Io.Writer = .fixed(&body_buf);
    writeScript(&body, dir) catch {
        return showError("Because the project path is too long, the shell was not opened.");
    };
    const file = std.Io.Dir.cwd().createFile(io, script, .{ .permissions = .executable_file }) catch |err| {
        log.warn("cannot write {s}: {s}", .{ script, @errorName(err) });
        return showError("Because the launcher script could not be written, the shell was not opened.");
    };
    file.writeStreamingAll(io, body.buffered()) catch {};
    file.close(io);

    var settings = config.load(std.heap.c_allocator, io);
    defer settings.deinit();

    var cmd_buf: [std.fs.max_path_bytes * 3]u8 = undefined;
    var fbs: std.Io.Writer = .fixed(&cmd_buf);
    commandLine(&fbs, settings.rename_terminal, script) catch {
        return showError("Because the terminal command is too long, the shell was not opened.");
    };
    log.info("opening a shell in {s}", .{dir});
    batch_rename.runDetached(io, fbs.buffered());
}

pub const entries = [_]actions.Entry{
    .{
        .name = "OpenTerminalInProjectDir",
        .def = .{
            .steps = &.{.{ .func = &openTerminal }},
            .desc = "Open project path in terminal",
        },
    },
};

test "projectFolder is the folder of the project file" {
    try std.testing.expectEqualStrings("/music/song", projectFolder("/music/song/song.rpp").?);
    try std.testing.expect(projectFolder("") == null);
}

test "the launcher script enters the quoted folder and starts a login shell" {
    var buf: [256]u8 = undefined;
    var fbs: std.Io.Writer = .fixed(&buf);
    try writeScript(&fbs, "/music/it's here");
    try std.testing.expectEqualStrings(
        "#!/bin/sh\ncd '/music/it'\\''s here' || exit 1\nexec \"${SHELL:-/bin/sh}\" -l\n",
        fbs.buffered(),
    );
}

test "commandLine gives the script to the terminal as its last argument" {
    var buf: [256]u8 = undefined;
    var fbs: std.Io.Writer = .fixed(&buf);
    try commandLine(&fbs, "open -na Ghostty.app --args -e", "/r/shell.command");
    try std.testing.expectEqualStrings("open -na Ghostty.app --args -e '/r/shell.command' >/dev/null 2>&1 &", fbs.buffered());
}
