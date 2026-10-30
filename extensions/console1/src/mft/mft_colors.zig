//! The colors of the MFT panel: the conversion from the hue of the controller's color wheel to the color that the
//! panel draws, so that the panel matches the LEDs of the hardware.
const std = @import("std");

/// Converts an HSV color (h in degrees, s and v in 0..1) to a packed 0xRRGGBBAA ImGui color.
pub fn hsvToRgb(h: f32, s: f32, v: f32) c_int {
    const c = v * s;
    const hp = h / 60.0;
    const x = c * (1.0 - @abs(@mod(hp, 2.0) - 1.0));
    var r: f32 = 0;
    var g: f32 = 0;
    var b: f32 = 0;
    if (hp < 1.0) {
        r = c;
        g = x;
    } else if (hp < 2.0) {
        r = x;
        g = c;
    } else if (hp < 3.0) {
        g = c;
        b = x;
    } else if (hp < 4.0) {
        g = x;
        b = c;
    } else if (hp < 5.0) {
        r = x;
        b = c;
    } else {
        r = c;
        b = x;
    }
    const m = v - c;
    const ri: u32 = @intFromFloat(std.math.clamp((r + m) * 255.0, 0.0, 255.0));
    const gi: u32 = @intFromFloat(std.math.clamp((g + m) * 255.0, 0.0, 255.0));
    const bi: u32 = @intFromFloat(std.math.clamp((b + m) * 255.0, 0.0, 255.0));
    return @bitCast((ri << 24) | (gi << 16) | (bi << 8) | 0xFF);
}

/// Maps a position on the MFT color wheel (0 to 127, and any position in between) to an RGB color for the panel. On
/// the wheel red sits near 0x56 (86); increasing hue moves toward blue below it and purple above, so the HSV angle is
/// roughly (86 - hue) * (360 / 128). The settings bars use positions between two hues, so the position is a float.
pub fn hueToRgbAt(hue: f32) c_int {
    const deg = @mod((86.0 - hue) * (360.0 / 128.0), 360.0);
    return hsvToRgb(deg, 1.0, 1.0);
}

/// The color of a hue that the controller stores.
pub fn hueToRgb(hue: u8) c_int {
    return hueToRgbAt(@floatFromInt(hue));
}

test "red sits at 86 on the wheel, and a hue between two hues is a color between them" {
    try std.testing.expectEqual(@as(u32, 0xFF0000FF), @as(u32, @bitCast(hueToRgb(86))));
    try std.testing.expectEqual(hueToRgb(15), hueToRgbAt(15.0));
    try std.testing.expect(hueToRgbAt(15.5) != hueToRgb(15));
}
