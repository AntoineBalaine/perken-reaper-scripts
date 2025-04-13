const std = @import("std");

const c1 = @import("../c1.zig");
const C1Model = @This();

// Use a fixed-size array indexed by CC values
values: [256]u8 = [_]u8{0} ** 256,
pub fn init() C1Model {
    return C1Model{};
}

pub fn updateValue(self: *C1Model, cc: c1.CCs, value: u8) void {
    const validValue: u8 = if (cc.isBtn())
        if (value > 0) 127 else 0
    else
        std.math.clamp(value, 0, 127);

    // Store in the array using the CC enum value as index
    // std.math.rem(usize, @intFromEnum, std.enums.values(c1.CC).len)
    self.values[@intFromEnum(cc) % std.enums.values(c1.CC).len] = validValue;
}

pub fn getValue(self: *const C1Model, cc: c1.CCs) u8 {
    return self.values[@intFromEnum(cc) % std.enums.values(c1.CC).len];
}

pub fn reset(self: *C1Model) void {
    // Reset all values to 0
    @memset(&self.values, 0);
}
