//! perken-utilities settings, read from
//! <resource>/Data/Perken/perken-utilities.ini.
//!
//! The file is optional: every setting has a default. It is read when a
//! feature that needs it starts (e.g. a batch rename), not at load, so that
//! edits apply without restarting REAPER.
//!
//! ```ini
//! [rename]
//! terminal = open -a iTerm      ; receives the launcher script as last argument
//!                               ; (also used by "Search actions with fzf" and
//!                               ; "Open project path in terminal")
//! editor = nvim                 ; unset: $VISUAL, else $EDITOR, else vim
//! close_terminal = true         ; macOS: close the Terminal.app window afterwards
//!
//! [abc]
//! command = /path/to/abcls      ; default: found by search (global npm install, nvm, login shell)
//! clipboard = pbcopy            ; reads the ABC text from its standard input
//! editor = open -a "Visual Studio Code"   ; default: the system opener (open, xdg-open)
//! quantize = true               ; snap the notes to sixteenths and triplets first
//! ```
const std = @import("std");
const builtin = @import("builtin");
const ini = @import("ini");
const Reaper = @import("reaper").reaper;

const log = std.log.scoped(.config);

pub const file_rel = "Data/Perken/perken-utilities.ini";

/// macOS opens the batch-rename script in Terminal.app, which runs it through
/// the user's login shell. Other platforms use the Debian-style terminal
/// alternative.
pub const default_terminal: []const u8 = switch (builtin.os.tag) {
    .macos => "open -a Terminal",
    else => "x-terminal-emulator -e",
};
/// An empty editor means "the user's default editor" ($VISUAL / $EDITOR).
pub const default_editor: []const u8 = "";
/// Terminal.app is the only terminal the auto-close knows how to drive, and
/// it only exists on macOS.
pub const default_close_terminal = builtin.os.tag == .macos;

/// An empty command means "search for the abcls CLI", because REAPER started
/// from the Finder has a minimal PATH, in which a bare `abcls` is not found.
/// The user can give a path in the [abc] section instead.
pub const default_abc_command: []const u8 = "";
/// The program that copies its standard input to the system clipboard.
pub const default_abc_clipboard: []const u8 = switch (builtin.os.tag) {
    .macos => "pbcopy",
    .windows => "clip",
    else => "xclip -selection clipboard",
};
/// The program that opens a file. Because the system knows which editor the
/// user chose for ABC files, we default to its own opener, and the [abc]
/// section can name a specific editor instead.
pub const default_abc_editor: []const u8 = switch (builtin.os.tag) {
    .macos => "open",
    else => "xdg-open",
};

/// Because the CLI writes note lengths as they are, notes off the grid become
/// unreadable ties, so the export snaps them to the take's grid by default.
pub const default_abc_quantize = true;

pub const Settings = struct {
    arena: std.heap.ArenaAllocator,
    rename_terminal: []const u8 = default_terminal,
    rename_editor: []const u8 = default_editor,
    rename_close_terminal: bool = default_close_terminal,
    abc_command: []const u8 = default_abc_command,
    abc_clipboard: []const u8 = default_abc_clipboard,
    abc_editor: []const u8 = default_abc_editor,
    abc_quantize: bool = default_abc_quantize,

    pub fn deinit(self: *Settings) void {
        self.arena.deinit();
    }
};

pub const Section = enum { rename, abc, unknown };

/// Parses a boolean setting: true/false, yes/no, on/off or 1/0.
pub fn parseBool(v: []const u8) ?bool {
    const truthy = [_][]const u8{ "true", "yes", "on", "1" };
    const falsy = [_][]const u8{ "false", "no", "off", "0" };
    for (truthy) |t| if (std.ascii.eqlIgnoreCase(v, t)) return true;
    for (falsy) |f| if (std.ascii.eqlIgnoreCase(v, f)) return false;
    return null;
}

pub fn parse(gpa: std.mem.Allocator, reader: *std.Io.Reader) !Settings {
    var settings = Settings{ .arena = std.heap.ArenaAllocator.init(gpa) };
    errdefer settings.deinit();
    const arena = settings.arena.allocator();

    var parser = ini.parse(gpa, reader, ";#");
    defer parser.deinit();

    var section: Section = .unknown;
    while (try parser.next()) |record| {
        switch (record) {
            .section => |name| {
                if (std.mem.eql(u8, name, "rename")) {
                    section = .rename;
                } else if (std.mem.eql(u8, name, "abc")) {
                    section = .abc;
                } else {
                    section = .unknown;
                    log.warn("unknown section [{s}] in {s} — skipped", .{ name, file_rel });
                }
            },
            .property => |kv| switch (section) {
                .unknown => {},
                .abc => {
                    const v = std.mem.trim(u8, kv.value, " \t");
                    if (v.len == 0) {
                        log.warn("empty [abc] value for '{s}' — skipped", .{kv.key});
                        continue;
                    }
                    if (std.mem.eql(u8, kv.key, "command")) {
                        settings.abc_command = try arena.dupe(u8, v);
                    } else if (std.mem.eql(u8, kv.key, "clipboard")) {
                        settings.abc_clipboard = try arena.dupe(u8, v);
                    } else if (std.mem.eql(u8, kv.key, "editor")) {
                        settings.abc_editor = try arena.dupe(u8, v);
                    } else if (std.mem.eql(u8, kv.key, "quantize")) {
                        settings.abc_quantize = parseBool(v) orelse {
                            log.warn("bad [abc] quantize '{s}' (use true/false) — skipped", .{v});
                            continue;
                        };
                    } else {
                        log.warn("unknown [abc] key '{s}' — skipped", .{kv.key});
                    }
                },
                .rename => {
                    const v = std.mem.trim(u8, kv.value, " \t");
                    if (v.len == 0) {
                        log.warn("empty [rename] value for '{s}' — skipped", .{kv.key});
                        continue;
                    }
                    if (std.mem.eql(u8, kv.key, "terminal")) {
                        settings.rename_terminal = try arena.dupe(u8, v);
                    } else if (std.mem.eql(u8, kv.key, "editor")) {
                        settings.rename_editor = try arena.dupe(u8, v);
                    } else if (std.mem.eql(u8, kv.key, "close_terminal")) {
                        settings.rename_close_terminal = parseBool(v) orelse {
                            log.warn("bad [rename] close_terminal '{s}' (use true/false) — skipped", .{v});
                            continue;
                        };
                    } else {
                        log.warn("unknown [rename] key '{s}' — skipped", .{kv.key});
                    }
                },
            },
            .enumeration => {},
        }
    }
    return settings;
}

/// Reads the settings file under REAPER's resource path. A missing or
/// unreadable file yields the defaults. Callers must not use this on Windows,
/// where std.fs's *Absolute calls can overflow the stack at the depth REAPER
/// calls into an extension (see reavim-ext's win_file.zig).
pub fn load(gpa: std.mem.Allocator, io: std.Io) Settings {
    const defaults = Settings{ .arena = std.heap.ArenaAllocator.init(gpa) };
    const resource = std.mem.span(Reaper.GetResourcePath());
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ resource, file_rel }) catch return defaults;
    const file = std.Io.Dir.openFileAbsolute(io, path, .{}) catch return defaults;
    defer file.close(io);
    var file_buffer: [4096]u8 = undefined;
    var file_reader = file.reader(io, &file_buffer);
    return parse(gpa, &file_reader.interface) catch |err| {
        log.err("failed to parse {s}: {s} — using defaults", .{ path, @errorName(err) });
        return defaults;
    };
}

test "rename settings default and override" {
    var fbs_d: std.Io.Reader = .fixed("");
    var d = try parse(std.testing.allocator, &fbs_d);
    defer d.deinit();
    try std.testing.expectEqualStrings(default_terminal, d.rename_terminal);
    try std.testing.expectEqualStrings("", d.rename_editor);
    try std.testing.expectEqual(default_close_terminal, d.rename_close_terminal);

    var fbs_o: std.Io.Reader = .fixed(
        \\[rename]
        \\terminal = open -a iTerm
        \\editor = nvim -u NONE
        \\close_terminal = false
        \\
    );
    var o = try parse(std.testing.allocator, &fbs_o);
    defer o.deinit();
    try std.testing.expectEqualStrings("open -a iTerm", o.rename_terminal);
    try std.testing.expectEqualStrings("nvim -u NONE", o.rename_editor);
    try std.testing.expect(!o.rename_close_terminal);
}

test "abc settings default and override" {
    var fbs_d: std.Io.Reader = .fixed("");
    var d = try parse(std.testing.allocator, &fbs_d);
    defer d.deinit();
    try std.testing.expectEqualStrings(default_abc_command, d.abc_command);
    try std.testing.expectEqualStrings(default_abc_clipboard, d.abc_clipboard);
    try std.testing.expectEqualStrings(default_abc_editor, d.abc_editor);

    var fbs_o: std.Io.Reader = .fixed(
        \\[abc]
        \\command = /opt/bin/abcls
        \\clipboard = wl-copy
        \\editor = code
        \\
    );
    var o = try parse(std.testing.allocator, &fbs_o);
    defer o.deinit();
    try std.testing.expectEqualStrings("/opt/bin/abcls", o.abc_command);
    try std.testing.expectEqualStrings("wl-copy", o.abc_clipboard);
    try std.testing.expectEqualStrings("code", o.abc_editor);
}

test "parseBool accepts the usual spellings" {
    try std.testing.expectEqual(@as(?bool, true), parseBool("Yes"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("off"));
    try std.testing.expectEqual(@as(?bool, null), parseBool("maybe"));
}
