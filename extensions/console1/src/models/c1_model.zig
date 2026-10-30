const std = @import("std");
const c1 = @import("../c1.zig");
const C1Model = @This();

// Use a fixed-size array indexed by CC values
values: [256]u7,

// Singleton instance for tests
pub var instance: ?@This() = null;
pub const default: @This() = .{ .values = @splat(0) };

/// Initialize a new C1Model with all values set to 0
/// Reset the model to its initial state
pub fn reset(self: *C1Model) void {
    // Reset all values to 0
    @memset(&self.values, 0);
}

test reset {
    var model: C1Model = .default;
    model.updateValue(c1.CCs.Out_mute, 1);
    try std.testing.expectEqual(@as(u7, 127), model.getValue(c1.CCs.Out_mute));
    model.reset();
    try std.testing.expectEqual(@as(u7, 0), model.getValue(c1.CCs.Out_mute));
}
/// Update the value of a control
/// For buttons, only accepts 0 or 127
/// For knobs, accepts any value between 0 and 127
pub fn updateValue(self: *C1Model, cc: c1.CCs, value: u7) void {
    const validValue: u7 = if (cc.isBtn())
        if (value > 0) 127 else 0
    else
        value;

    // Store in the array using the CC enum value as index
    self.values[@backingInt(cc) % std.enums.values(c1.CCs).len] = validValue;
}

test updateValue {
    var model: C1Model = .default;

    // Test updating a knob value
    model.updateValue(c1.CCs.Out_Vol, 64);
    try std.testing.expectEqual(@as(u7, 64), model.getValue(c1.CCs.Out_Vol));

    // Test updating a button value (should be either 0 or 127)
    model.updateValue(c1.CCs.Out_mute, 1);
    try std.testing.expectEqual(@as(u7, 127), model.getValue(c1.CCs.Out_mute));

    model.updateValue(c1.CCs.Out_mute, 0);
    try std.testing.expectEqual(@as(u7, 0), model.getValue(c1.CCs.Out_mute));
}

/// Get the current value of a control
pub fn getValue(self: *const C1Model, cc: c1.CCs) u7 {
    return self.values[@backingInt(cc) % std.enums.values(c1.CCs).len];
}

test getValue {
    var model: C1Model = .default;
    try std.testing.expectEqual(@as(u7, 0), model.getValue(c1.CCs.Out_Vol));
}
