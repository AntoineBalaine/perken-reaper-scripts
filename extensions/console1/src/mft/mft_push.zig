//! What a click on an encoder of a page does to the parameter that the page maps to its push.
//!
//! Because the maps say only which parameter or which band a push is for, the choice of the next value is here, with no call into REAPER,
//! so that the unit tests can reach it. The calls that read and write the values are in `mft_fx.zig`.
const std = @import("std");

/// The shapes that a click on the push of a band of ReaEQ goes through, by the number that ReaEQ stores for a band type: low shelf, band, high
/// shelf, low pass, high pass and notch. A band that has another shape goes to the first of them.
pub const band_types = [_]u8{ 0, 8, 1, 3, 4, 6 };

/// The shape that follows `current` in `band_types`, going back to the first after the last.
pub fn nextBandType(current: u8) u8 {
    for (band_types, 0..) |shape, i| {
        if (shape == current) return band_types[(i + 1) % band_types.len];
    }
    return band_types[0];
}

/// The name that ReaEQ gives to a band type, for the pop-up that follows a click.
pub fn bandTypeName(band_type: u8) [:0]const u8 {
    return switch (band_type) {
        0 => "Low Shelf",
        1 => "High Shelf",
        2, 8, 10 => "Band",
        3 => "Low Pass",
        4 => "High Pass",
        5 => "All Pass",
        6 => "Notch",
        7 => "Band Pass",
        else => "Other",
    };
}

/// What REAPER knows of the way that a parameter is stepped.
pub const Stepping = struct {
    /// The distance between two values, in normalized units, or 0 for a parameter that has no steps.
    step: f64 = 0.0,
    /// Whether the parameter is an on and off switch.
    toggle: bool = false,
};

/// The value that a click gives to a parameter. Because a switch and a parameter without steps have nothing to count through, a click turns
/// them on when they are in the lower half and off otherwise. A parameter with steps goes one step up, and back to the lowest after the
/// highest.
pub fn nextParamValue(current: f64, stepping: Stepping) f64 {
    std.debug.assert(!std.math.isNan(current));
    if (stepping.toggle or stepping.step <= 0.0) return if (current < 0.5) 1.0 else 0.0;
    const next = current + stepping.step;
    // The sum of steps is not exact, so a value that is within a hundredth of a step of the end counts as the end.
    if (next > 1.0 + stepping.step * 0.01) return 0.0;
    return std.math.clamp(next, 0.0, 1.0);
}

/// The step of a parameter in normalized units. Because REAPER gives the step in the units of the plugin (1 for a list of choices from 0 to 7), it is divided
/// by the range of the parameter; a range that is empty, or a step that is not positive, is no step.
pub fn normalizedStep(step: f64, min: f64, max: f64) f64 {
    const range = max - min;
    if (!(range > 0.0) or !(step > 0.0)) return 0.0;
    return @min(step / range, 1.0);
}

/// A parameter with more steps than this turns as the parameters without steps do, since a turn of its knob would take too long otherwise.
pub const max_turn_steps = 64;

/// How many ticks of an encoder move a stepped parameter by one step, which makes a list of choices go one choice at a time.
pub const ticks_per_step = 4;

/// Whether a turn moves the parameter by its steps: a switch, and a parameter with few steps.
pub fn turnsBySteps(stepping: Stepping) bool {
    if (stepping.toggle) return true;
    return stepping.step > 0.0 and stepping.step * max_turn_steps >= 1.0 - 1e-9;
}

/// Adds the ticks of a turn to those that have not made a step yet, and returns the steps that they make. The ticks that are left keep the sign of the turn.
pub fn countTicks(pending: *i16, delta: i8) i32 {
    const total: i32 = @as(i32, pending.*) + delta;
    const steps = @divTrunc(total, ticks_per_step);
    pending.* = @intCast(total - steps * ticks_per_step);
    return steps;
}

/// The value that `steps` steps of a turn give a stepped parameter, from the step that the value is nearest to, within the range.
pub fn steppedValue(current: f64, stepping: Stepping, steps: i32) f64 {
    std.debug.assert(turnsBySteps(stepping));
    const step: f64 = if (stepping.toggle) 1.0 else stepping.step;
    const nearest = @round(current / step);
    return std.math.clamp((nearest + @as(f64, @floatFromInt(steps))) * step, 0.0, 1.0);
}

test "a stepped parameter: its step is normalized, a few ticks make one step, and the value stays in its range" {
    const t = std.testing;
    try t.expectApproxEqAbs(@as(f64, 1.0 / 7.0), normalizedStep(1, 0, 7), 1e-9);
    try t.expectEqual(@as(f64, 0.0), normalizedStep(1, 3, 3));
    try t.expect(turnsBySteps(.{ .step = 1.0 / 7.0 }));
    try t.expect(turnsBySteps(.{ .toggle = true }));
    try t.expect(!turnsBySteps(.{ .step = 0.001 }));
    try t.expect(!turnsBySteps(.{}));
    var pending: i16 = 0;
    try t.expectEqual(@as(i32, 0), countTicks(&pending, 3));
    try t.expectEqual(@as(i32, 1), countTicks(&pending, 2));
    try t.expectEqual(@as(i16, 1), pending);
    try t.expectEqual(@as(i32, 0), countTicks(&pending, -4));
    try t.expectEqual(@as(i16, -3), pending);
    const seventh = Stepping{ .step = 1.0 / 7.0 };
    try t.expectApproxEqAbs(@as(f64, 3.0 / 7.0), steppedValue(2.0 / 7.0 + 0.01, seventh, 1), 1e-9);
    try t.expectEqual(@as(f64, 1.0), steppedValue(1.0, seventh, 2));
    try t.expectEqual(@as(f64, 0.0), steppedValue(0.0, seventh, -1));
    try t.expectEqual(@as(f64, 1.0), steppedValue(0.0, .{ .toggle = true }, 1));
}

test "bandTypeName: every shape of the cycle has a name" {
    const t = std.testing;
    for (band_types) |shape| try t.expect(!std.mem.eql(u8, bandTypeName(shape), "Other"));
    try t.expectEqualStrings("Low Shelf", bandTypeName(0));
    try t.expectEqualStrings("Notch", bandTypeName(6));
}

test "nextBandType: goes through the shapes in order, and a shape that is not in the list goes to the first" {
    const t = std.testing;
    try t.expectEqual(@as(u8, 8), nextBandType(0));
    try t.expectEqual(@as(u8, 1), nextBandType(8));
    try t.expectEqual(@as(u8, 0), nextBandType(6));
    try t.expectEqual(@as(u8, 0), nextBandType(10));
}

test "nextParamValue: a switch toggles, and a parameter with steps counts up and wraps" {
    const t = std.testing;
    try t.expectEqual(@as(f64, 1.0), nextParamValue(0.0, .{ .toggle = true }));
    try t.expectEqual(@as(f64, 0.0), nextParamValue(1.0, .{ .toggle = true }));
    try t.expectEqual(@as(f64, 1.0), nextParamValue(0.2, .{}));
    try t.expectApproxEqAbs(@as(f64, 0.5), nextParamValue(0.25, .{ .step = 0.25 }), 1e-9);
    try t.expectEqual(@as(f64, 0.0), nextParamValue(1.0, .{ .step = 0.25 }));
    // The last step of a sum that is not exact still counts as the end.
    try t.expectApproxEqAbs(@as(f64, 1.0), nextParamValue(0.9, .{ .step = 0.1 }), 1e-9);
}
