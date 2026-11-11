//! The acceleration of the knobs. Because the unit sends one tick for each detent, whatever the speed, a full turn of
//! the range takes 127 ticks, which is slow for a large move. The faster a knob turns, the more each tick counts.
const std = @import("std");
const c1 = @import("../c1.zig");

const Accel = @This();

/// A tick that comes after a longer pause than this starts again from the plain step.
const reset_gap_ms = 300;
/// The multiplier of a tick that comes within `gap_ms` of the previous tick of the same knob, in the direction that the
/// knob turned. A burst of ticks that arrive in the same poll have a gap of 0, so that they get the largest one.
const steps = [_]struct { gap_ms: u64, multiplier: i8 }{
    .{ .gap_ms = 40, .multiplier = 6 },
    .{ .gap_ms = 80, .multiplier = 3 },
    .{ .gap_ms = 150, .multiplier = 2 },
};

last_ms: [256]u64 = @splat(0),
last_delta: [256]i8 = @splat(0),

/// The delta of a tick of `cc`, scaled by the speed of the knob. The fine adjust of shift is never accelerated, because
/// its purpose is precision, and a change of direction starts again from the plain step.
pub fn scale(self: *Accel, cc: c1.CCs, delta: i8, fine: bool, now_ms: u64) i8 {
    std.debug.assert(delta == 1 or delta == -1);
    const index = @backingInt(cc);
    const same_direction = self.last_delta[index] == delta;
    const gap = now_ms -| self.last_ms[index];
    self.last_ms[index] = now_ms;
    self.last_delta[index] = delta;
    if (fine or !same_direction or gap > reset_gap_ms) return delta;
    for (steps) |step| {
        if (gap <= step.gap_ms) return delta * step.multiplier;
    }
    return delta;
}

test "a slow knob keeps the plain step, and a fast one grows it" {
    var accel: Accel = .{};
    try std.testing.expectEqual(@as(i8, 1), accel.scale(.Inpt_Gain, 1, false, 1000));
    try std.testing.expectEqual(@as(i8, 1), accel.scale(.Inpt_Gain, 1, false, 1400));
    try std.testing.expectEqual(@as(i8, 2), accel.scale(.Inpt_Gain, 1, false, 1520));
    try std.testing.expectEqual(@as(i8, 3), accel.scale(.Inpt_Gain, 1, false, 1590));
    try std.testing.expectEqual(@as(i8, 6), accel.scale(.Inpt_Gain, 1, false, 1620));
    try std.testing.expectEqual(@as(i8, 6), accel.scale(.Inpt_Gain, 1, false, 1620));
}

test "a change of direction, shift and another knob start from the plain step" {
    var accel: Accel = .{};
    _ = accel.scale(.Inpt_Gain, 1, false, 1000);
    try std.testing.expectEqual(@as(i8, 6), accel.scale(.Inpt_Gain, 1, false, 1010));
    try std.testing.expectEqual(@as(i8, -1), accel.scale(.Inpt_Gain, -1, false, 1020));
    try std.testing.expectEqual(@as(i8, -6), accel.scale(.Inpt_Gain, -1, false, 1030));
    try std.testing.expectEqual(@as(i8, -1), accel.scale(.Inpt_Gain, -1, true, 1040));
    try std.testing.expectEqual(@as(i8, 1), accel.scale(.Eq_HiGain, 1, false, 1050));
}
