//! How far one tick of a knob moves a value, in the normalized range 0 to 1. The value of a parameter is not limited to
//! 127 steps here: only the rings and meters of the unit are, and they are drawn from the value that results.
const std = @import("std");

pub const Settings = struct {
    /// The part of the range that one tick moves: 127 ticks for the whole range.
    base_step: f64 = 1.0 / 127.0,
    /// A multiplier for all the knobs.
    sensitivity: f64 = 1.0,
    /// The multiplier while shift is held, which is the fine adjust.
    fine_multiplier: f64 = 0.1,

    pub fn valid(self: Settings) bool {
        return std.math.isFinite(self.base_step) and self.base_step > 0 and
            std.math.isFinite(self.sensitivity) and self.sensitivity > 0 and
            std.math.isFinite(self.fine_multiplier) and self.fine_multiplier > 0;
    }
};

/// The signed step of `delta` ticks. Because the delta is 1 or -1 until acceleration exists, a tick is the base step.
pub fn size(settings: Settings, delta: i8, fine: bool) f64 {
    std.debug.assert(settings.valid());
    const multiplier = settings.base_step * settings.sensitivity * (if (fine) settings.fine_multiplier else 1.0);
    return @as(f64, @floatFromInt(delta)) * multiplier;
}

/// The new normalized value, never outside 0 to 1.
pub fn apply(value: f64, step: f64) f64 {
    return std.math.clamp(value + step, 0.0, 1.0);
}

test "a tick is 1/127 of the range, a tenth of it with shift, and the settings scale it" {
    const defaults: Settings = .{};
    try std.testing.expectApproxEqAbs(1.0 / 127.0, size(defaults, 1, false), 1e-12);
    try std.testing.expectApproxEqAbs(-1.0 / 127.0, size(defaults, -1, false), 1e-12);
    try std.testing.expectApproxEqAbs(0.1 / 127.0, size(defaults, 1, true), 1e-12);
    const hot: Settings = .{ .sensitivity = 2.0, .fine_multiplier = 0.5 };
    try std.testing.expectApproxEqAbs(2.0 / 127.0, size(hot, 1, false), 1e-12);
    try std.testing.expectApproxEqAbs(1.0 / 127.0, size(hot, 1, true), 1e-12);
}

test "the value never leaves 0 to 1" {
    try std.testing.expectEqual(@as(f64, 1.0), apply(0.999, 0.5));
    try std.testing.expectEqual(@as(f64, 0.0), apply(0.001, -0.5));
    try std.testing.expectApproxEqAbs(0.51, apply(0.5, 0.01), 1e-12);
}

test "a full range takes 127 ticks with the default settings" {
    var value: f64 = 0;
    var ticks: usize = 0;
    while (value < 1.0) : (ticks += 1) value = apply(value, size(.{}, 1, false));
    try std.testing.expect(ticks >= 127 and ticks <= 128);
}

test "settings that are not positive are invalid" {
    try std.testing.expect(!(Settings{ .sensitivity = 0 }).valid());
    try std.testing.expect(!(Settings{ .base_step = -1 }).valid());
    try std.testing.expect(!(Settings{ .fine_multiplier = std.math.nan(f64) }).valid());
    try std.testing.expect((Settings{}).valid());
}

/// Moves a list position by `delta` rows and wraps around the `count` rows, as the scroll of the legacy knob did.
pub fn wrap(position: anytype, delta: i32, count: usize) void {
    if (count == 0) return;
    const moved = @mod(@as(i64, @intCast(position.*)) + delta, @as(i64, @intCast(count)));
    position.* = @intCast(moved);
}

test wrap {
    var position: u8 = 0;
    wrap(&position, -1, 5);
    try std.testing.expectEqual(@as(u8, 4), position);
    wrap(&position, 1, 5);
    try std.testing.expectEqual(@as(u8, 0), position);
    wrap(&position, 1, 5);
    try std.testing.expectEqual(@as(u8, 1), position);
    wrap(&position, 1, 0);
    try std.testing.expectEqual(@as(u8, 1), position);
    var big: usize = 3;
    wrap(&big, -7, 4);
    try std.testing.expectEqual(@as(usize, 0), big);
}
