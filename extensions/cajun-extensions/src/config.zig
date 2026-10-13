//! cajun-extensions settings, read from
//! <resource>/Data/Perken/cajun-extensions.ini.
//!
//! The file is optional: every setting has a default. It is read when a
//! feature that needs it starts (e.g. a batch rename), not at load, so that
//! edits apply without restarting REAPER.
//!
//! ```ini
//! [rename]
//! terminal = open -a iTerm      ; receives the launcher script as last argument
//! editor = nvim                 ; unset: $VISUAL, else $EDITOR, else vim
//! close_terminal = true         ; macOS: close the Terminal.app window afterwards
//! ```
const std = @import("std");
const builtin = @import("builtin");
const ini = @import("ini");
const Reaper = @import("reaper").reaper;

const log = std.log.scoped(.config);

pub const file_rel = "Data/Perken/cajun-extensions.ini";

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

pub const Settings = struct {
    arena: std.heap.ArenaAllocator,
    rename_terminal: []const u8 = default_terminal,
    rename_editor: []const u8 = default_editor,
    rename_close_terminal: bool = default_close_terminal,

    pub fn deinit(self: *Settings) void {
        self.arena.deinit();
    }
};

pub const Section = enum { rename, unknown };

/// Parses a boolean setting: true/false, yes/no, on/off or 1/0.
pub fn parseBool(v: []const u8) ?bool {
    const truthy = [_][]const u8{ "true", "yes", "on", "1" };
    const falsy = [_][]const u8{ "false", "no", "off", "0" };
    for (truthy) |t| if (std.ascii.eqlIgnoreCase(v, t)) return true;
    for (falsy) |f| if (std.ascii.eqlIgnoreCase(v, f)) return false;
    return null;
}

pub fn parse(gpa: std.mem.Allocator, reader: anytype) !Settings {
    var settings = Settings{ .arena = std.heap.ArenaAllocator.init(gpa) };
    errdefer settings.deinit();
    const arena = settings.arena.allocator();

    var parser = ini.parse(gpa, reader);
    defer parser.deinit();

    var section: Section = .unknown;
    while (try parser.next()) |record| {
        switch (record) {
            .section => |name| {
                if (std.mem.eql(u8, name, "rename")) {
                    section = .rename;
                } else {
                    section = .unknown;
                    log.warn("unknown section [{s}] in {s} — skipped", .{ name, file_rel });
                }
            },
            .property => |kv| switch (section) {
                .unknown => {},
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
pub fn load(gpa: std.mem.Allocator) Settings {
    const defaults = Settings{ .arena = std.heap.ArenaAllocator.init(gpa) };
    const resource = std.mem.span(Reaper.GetResourcePath());
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ resource, file_rel }) catch return defaults;
    const file = std.fs.openFileAbsolute(path, .{}) catch return defaults;
    defer file.close();
    return parse(gpa, file.reader()) catch |err| {
        log.err("failed to parse {s}: {s} — using defaults", .{ path, @errorName(err) });
        return defaults;
    };
}

test "rename settings default and override" {
    var fbs_d = std.io.fixedBufferStream("");
    var d = try parse(std.testing.allocator, fbs_d.reader());
    defer d.deinit();
    try std.testing.expectEqualStrings(default_terminal, d.rename_terminal);
    try std.testing.expectEqualStrings("", d.rename_editor);
    try std.testing.expectEqual(default_close_terminal, d.rename_close_terminal);

    var fbs_o = std.io.fixedBufferStream(
        \\[rename]
        \\terminal = open -a iTerm
        \\editor = nvim -u NONE
        \\close_terminal = false
        \\
    );
    var o = try parse(std.testing.allocator, fbs_o.reader());
    defer o.deinit();
    try std.testing.expectEqualStrings("open -a iTerm", o.rename_terminal);
    try std.testing.expectEqualStrings("nvim -u NONE", o.rename_editor);
    try std.testing.expect(!o.rename_close_terminal);
}

test "parseBool accepts the usual spellings" {
    try std.testing.expectEqual(@as(?bool, true), parseBool("Yes"));
    try std.testing.expectEqual(@as(?bool, false), parseBool("off"));
    try std.testing.expectEqual(@as(?bool, null), parseBool("maybe"));
}
