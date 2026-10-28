//! Sends the track's notes to the keyboard's parts the way its own keys do.
//!
//! In MIDI IN Mode 2 the keyboard plays its Lower part from channel 3 and its
//! Upper part from channel 4, whatever its split. A patch that splits the
//! keyboard at middle C therefore needs the notes below middle C on channel 3
//! and the others on channel 4. The keyboard does not report whether a patch
//! splits (no readable address changes with its split buttons), so each patch
//! carries the setting in a list kept by the plugin, `splits.txt`, one patch
//! name per line.

const std = @import("std");
const fileio = @import("fileio.zig");

/// Middle C (C4). The keyboard always splits there.
pub const split_note: u8 = 60;
const lower_channel: u8 = 2;
const upper_channel: u8 = 3;
const none: u8 = 0xFF;

/// Only the channels of the keyboard's own parts are routed (1, 3 and 4, the
/// first being the default of a new MIDI item); the drums on 11 and the GM2
/// channels pass unchanged.
fn routed(channel: u8) bool {
    return channel == 0 or channel == lower_channel or channel == upper_channel;
}

/// Runs on the audio thread. It remembers the channel each held note went to,
/// so that its note off follows it even if the split changes meanwhile.
pub const Router = struct {
    held: [16][128]u8 = @splat(@splat(none)),

    /// Writes the messages to send for `msg` into `out` and returns how many.
    pub fn route(self: *Router, split: bool, msg: [3]u8, out: *[2][3]u8) usize {
        const kind = msg[0] & 0xF0;
        const channel = msg[0] & 0x0F;
        if (msg[0] >= 0xF0 or !routed(channel)) {
            out[0] = msg;
            return 1;
        }
        switch (kind) {
            0x80, 0x90, 0xA0 => {
                const pitch = msg[1] & 0x7F;
                const is_on = kind == 0x90 and msg[2] > 0;
                const is_off = kind == 0x80 or (kind == 0x90 and msg[2] == 0);
                var target = self.held[channel][pitch];
                if (is_on or target == none) target = partFor(split, pitch);
                if (is_on) self.held[channel][pitch] = target;
                if (is_off) self.held[channel][pitch] = none;
                out[0] = .{ kind | target, msg[1], msg[2] };
                return 1;
            },
            else => {
                // Controllers, pressure and pitch bend reach every part that
                // plays, so a sustain pedal holds both halves of a split.
                out[0] = .{ kind | upper_channel, msg[1], msg[2] };
                if (!split) return 1;
                out[1] = .{ kind | lower_channel, msg[1], msg[2] };
                return 2;
            },
        }
    }
};

fn partFor(split: bool, pitch: u8) u8 {
    return if (split and pitch < split_note) lower_channel else upper_channel;
}

// ---- the list of split patches ----

pub fn isSplit(allocator: std.mem.Allocator, path: []const u8, name: []const u8) bool {
    if (name.len == 0) return false;
    const text = fileio.readAll(allocator, path) catch return false;
    defer allocator.free(text);
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (std.mem.eql(u8, std.mem.trimRight(u8, line, "\r"), name)) return true;
    }
    return false;
}

/// Adds the patch to the list, or removes it, rewriting the file.
pub fn setSplit(allocator: std.mem.Allocator, path: []const u8, name: []const u8, on: bool) !void {
    if (name.len == 0) return;
    const old = fileio.readAll(allocator, path) catch |err| switch (err) {
        error.FileNotFound => try allocator.dupe(u8, ""),
        else => return err,
    };
    defer allocator.free(old);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    var lines = std.mem.splitScalar(u8, old, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trimRight(u8, raw, "\r");
        if (line.len == 0 or std.mem.eql(u8, line, name)) continue;
        try out.appendSlice(allocator, line);
        try out.append(allocator, '\n');
    }
    if (on) {
        try out.appendSlice(allocator, name);
        try out.append(allocator, '\n');
    }
    if (std.fs.path.dirname(path)) |dir| try fileio.makePath(dir);
    try fileio.writeAll(path, out.items);
}

test "without a split every note goes to the upper part" {
    var r = Router{};
    var out: [2][3]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 1), r.route(false, .{ 0x90, 48, 100 }, &out));
    try std.testing.expectEqual([3]u8{ 0x93, 48, 100 }, out[0]);
}

test "with a split the notes below middle C go to the lower part" {
    var r = Router{};
    var out: [2][3]u8 = undefined;
    _ = r.route(true, .{ 0x90, 59, 100 }, &out);
    try std.testing.expectEqual([3]u8{ 0x92, 59, 100 }, out[0]);
    _ = r.route(true, .{ 0x90, 60, 100 }, &out);
    try std.testing.expectEqual([3]u8{ 0x93, 60, 100 }, out[0]);
}

test "a note off follows its note on when the split changes" {
    var r = Router{};
    var out: [2][3]u8 = undefined;
    _ = r.route(true, .{ 0x90, 40, 100 }, &out);
    _ = r.route(false, .{ 0x80, 40, 0 }, &out);
    try std.testing.expectEqual([3]u8{ 0x82, 40, 0 }, out[0]);
    _ = r.route(false, .{ 0x80, 40, 0 }, &out);
    try std.testing.expectEqual([3]u8{ 0x83, 40, 0 }, out[0]);
}

test "controllers reach both parts of a split, other channels pass unchanged" {
    var r = Router{};
    var out: [2][3]u8 = undefined;
    try std.testing.expectEqual(@as(usize, 2), r.route(true, .{ 0xB0, 64, 127 }, &out));
    try std.testing.expectEqual([3]u8{ 0xB3, 64, 127 }, out[0]);
    try std.testing.expectEqual([3]u8{ 0xB2, 64, 127 }, out[1]);
    try std.testing.expectEqual(@as(usize, 1), r.route(true, .{ 0x9A, 36, 90 }, &out));
    try std.testing.expectEqual([3]u8{ 0x9A, 36, 90 }, out[0]);
}

test "the list of split patches is kept in a file" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const dir = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(dir);
    const path = try std.fs.path.join(std.testing.allocator, &.{ dir, "splits.txt" });
    defer std.testing.allocator.free(path);
    const a = std.testing.allocator;
    try std.testing.expect(!isSplit(a, path, "1-2 JazzRoll OF"));
    try setSplit(a, path, "1-2 JazzRoll OF", true);
    try setSplit(a, path, "3-1 Other", true);
    try std.testing.expect(isSplit(a, path, "1-2 JazzRoll OF"));
    try setSplit(a, path, "1-2 JazzRoll OF", false);
    try std.testing.expect(!isSplit(a, path, "1-2 JazzRoll OF"));
    try std.testing.expect(isSplit(a, path, "3-1 Other"));
}
