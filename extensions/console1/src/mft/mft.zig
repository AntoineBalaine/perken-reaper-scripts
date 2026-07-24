const std = @import("std");

pub const ENCODER_ROT_CHANNEL: u8 = 0x00;
pub const ENCODER_BTN_CHANNEL: u8 = 0x01;
pub const SIDE_BTN_CHANNEL: u8 = 0x03;
pub const COLOR_CHANNEL: u8 = 0x02;

pub const BASE_SENSITIVITY: f32 = 1.0 / 127.0;
pub const FINE_SENSITIVITY_MULTIPLIER: f32 = 0.1;

pub const ModuleBtnCC = enum(u8) {
    IO = 8,
    GATE = 9,
    EQ = 10,
    COMP = 11,
    SETTINGS = 12,
    TRANSPORT = 13,
};

pub fn decodeTwosComplement(val: u8) i8 {
    if (val <= 64) return @intCast(val);
    return @as(i8, @truncate(@as(i16, val) - 128));
}

test decodeTwosComplement {
    const t = std.testing;
    try t.expectEqual(@as(i8, 0), decodeTwosComplement(0));
    try t.expectEqual(@as(i8, 1), decodeTwosComplement(1));
    try t.expectEqual(@as(i8, 64), decodeTwosComplement(64));
    try t.expectEqual(@as(i8, -1), decodeTwosComplement(127));
    try t.expectEqual(@as(i8, -63), decodeTwosComplement(65));
}
