//! std.log backend, same pattern as reavim-ext and reaperConsole1: colored,
//! scope-prefixed output to stderr (visible when REAPER is launched from a
//! terminal).
const std = @import("std");

const Color = struct {
    const reset = "\x1b[0m";
    const red = "\x1b[31m";
    const yellow = "\x1b[33m";
    const blue = "\x1b[34m";
    const green = "\x1b[0;32m";
};

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const scope_prefix = "(perken:" ++ @tagName(scope) ++ "): ";

    const color = switch (level) {
        .debug => Color.blue,
        .info => Color.green,
        .warn => Color.yellow,
        .err => Color.red,
    };

    const prefix = color ++ "[" ++ @tagName(level) ++ "] " ++ scope_prefix;

    std.debug.lockStdErr();
    defer std.debug.unlockStdErr();
    const stderr = std.io.getStdErr().writer();
    nosuspend stderr.print(prefix ++ format ++ Color.reset ++ "\n", args) catch return;
}
