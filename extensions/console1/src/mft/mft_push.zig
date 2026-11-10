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
