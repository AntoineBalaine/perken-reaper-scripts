//! std.log backend, same pattern as reaperConsole1/src/logger.zig: colored,
//! scope-prefixed output to stderr (visible when REAPER is launched from a terminal).
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
    const scope_prefix = "(" ++ switch (scope) {
        .extension,
        .accel,
        .config,
        .engine,
        .swell,
        .default,
        => @tagName(scope),
        else => @compileError("Unknown scope: " ++ @tagName(scope)),
    } ++ "): ";

    const color = switch (level) {
        .debug => Color.blue,
        .info => Color.green,
        .warn => Color.yellow,
        .err => Color.red,
    };

    const prefix = color ++ "[" ++ @tagName(level) ++ "] " ++ scope_prefix;

    // Because the locked stderr writer is buffered, unlockStderr flushes what the print left in the buffer.
    var buffer: [256]u8 = undefined;
    const locked = std.debug.lockStderr(&buffer);
    defer std.debug.unlockStderr();
    const stderr = &locked.file_writer.interface;
    stderr.print(prefix ++ format ++ Color.reset ++ "\n", args) catch return;
}
