const std = @import("std");
const reaper = @import("reaper.zig").reaper;
pub fn volToU8(vol: f64) u8 {
    var d: f64 = (reaper.DB2SLIDER(VAL2DB(vol)) * 127.0 / 1000.0);
    d = if (d < 0.0) 0.0 else if (d > 127.0) 127.0 else d;
    const t: u8 = @intFromFloat(d + 0.5);
    return t;
}

pub inline fn DB2VAL(x: f64) f64 {
    return std.math.exp((x) * LN10_OVER_TWENTY);
}
const TWENTY_OVER_LN10 = 8.6858896380650365530225783783321;
const LN10_OVER_TWENTY = 0.11512925464970228420089957273422;
pub inline fn VAL2DB(x: f64) f64 {
    if (x < 0.0000000298023223876953125) return -150.0;
    const v: f64 = std.math.log(@TypeOf(x), 10, x) * TWENTY_OVER_LN10;
    return if (v < -150.0) -150.0 else v;
}

pub fn getTrackIndex(track: reaper.MediaTrack) ?usize {
    const track_number = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER");
    if (track_number <= 0) return null; // Master track or invalid
    return @intFromFloat(track_number - 1); // Convert 1-based to 0-based
}
