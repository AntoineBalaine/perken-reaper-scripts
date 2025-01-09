const std = @import("std");
const imgui = @import("../reaper_imgui.zig");
pub fn desaturate(rgba: c_int) !c_int {
    var r: f64 = undefined;
    var g: f64 = undefined;
    var b: f64 = undefined;
    var a: f64 = undefined;
    try imgui.ColorConvertU32ToDouble4(.{ rgba, &r, &g, &b, &a });
    var h: f64 = undefined;
    var s: f64 = undefined;
    var v: f64 = undefined;
    try imgui.ColorConvertRGBtoHSV(.{ r, g, b, &h, &s, &v });
    try imgui.ColorConvertHSVtoRGB(.{ h, s - 0.5, v, &r, &g, &b });
    const rInt: c_int = @intFromFloat(@floor(r * 255.0));
    const gInt: c_int = @intFromFloat(@floor(g * 255.0));
    const bInt: c_int = @intFromFloat(@floor(b * 255.0));

    const rv = rInt << 24 | gInt << 16 | bInt << 8 | 0xFF;
    return rv;
}

const RGBA = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

inline fn fixBrightness(channel: u8, delta: i8) u8 {
    return if (delta >= 0) std.math.add(u8, channel, @intCast(@abs(delta))) catch 255 else std.math.sub(u8, channel, @intCast(@abs(delta))) catch 0;
}

pub inline fn adjustBrightness(color: c_int, amt: i8, no_alpha: bool) c_int {
    var rgba: RGBA = @bitCast(color);
    rgba.r = fixBrightness(rgba.r, amt);
    rgba.g = fixBrightness(rgba.g, amt);
    rgba.b = fixBrightness(rgba.b, amt);
    if (!no_alpha) {
        rgba.a = fixBrightness(rgba.a, amt);
    }
    return @as(c_int, @bitCast(rgba));
}
