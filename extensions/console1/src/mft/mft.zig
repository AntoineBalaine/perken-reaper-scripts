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

// The six side buttons, discovered on hardware: channel 4, CCs 8-13.
pub const SIDE_BUTTON_CCS = [6]u8{ 8, 9, 10, 11, 12, 13 };

// Decode a relative encoder value into a signed delta. The MFT relative mode is
// centered on 64: one click clockwise sends 65 (0x41), one click
// counter-clockwise sends 63 (0x3F), and faster turns step further from 64
// (confirmed on hardware via the calibration wizard). So the delta is val - 64.
pub fn decodeRelative(val: u8) i8 {
    return @as(i8, @intCast(val)) - 64;
}

test decodeRelative {
    const t = std.testing;
    try t.expectEqual(@as(i8, 0), decodeRelative(64)); // no movement
    try t.expectEqual(@as(i8, 1), decodeRelative(65)); // one click clockwise
    try t.expectEqual(@as(i8, -1), decodeRelative(63)); // one click counter-clockwise
    try t.expectEqual(@as(i8, 63), decodeRelative(127)); // fast clockwise
    try t.expectEqual(@as(i8, -63), decodeRelative(1)); // fast counter-clockwise
}
