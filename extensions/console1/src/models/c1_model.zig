const std = @import("std");
const c1 = @import("../c1.zig");
const C1Model = @This();

// Use a fixed-size array indexed by CC values
values: [256]u8 = [_]u8{0} ** 256,

// Singleton instance for tests
pub var instance: ?C1Model = null;

/// Initialize a new C1Model with all values set to 0
pub fn init() C1Model {
    return C1Model{};
}

/// Reset the model to its initial state
pub fn reset(self: *C1Model) void {
    // Reset all values to 0
    @memset(&self.values, 0);
}

/// Update the value of a control
/// For buttons, only accepts 0 or 127
/// For knobs, accepts any value between 0 and 127
pub fn updateValue(self: *C1Model, cc: c1.CCs, value: u8) void {
    const validValue: u8 = if (cc.isBtn())
        if (value > 0) 127 else 0
    else
        std.math.clamp(value, 0, 127);

    // Store in the array using the CC enum value as index
    self.values[@intFromEnum(cc) % std.enums.values(c1.CCs).len] = validValue;
}

/// Get the current value of a control
pub fn getValue(self: *const C1Model, cc: c1.CCs) u8 {
    return self.values[@intFromEnum(cc) % std.enums.values(c1.CCs).len];
}
