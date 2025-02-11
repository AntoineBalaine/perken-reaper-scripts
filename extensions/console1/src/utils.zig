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

pub fn calculateDelta(comptime T: type, old_pos_abs: u8, new_pos: u8) T {
    if ((old_pos_abs == 127 or old_pos_abs == 0) and new_pos == old_pos_abs) {
        return if (old_pos_abs == 127) 1 else -1;
    }
    return @as(T, @intCast(new_pos)) - @as(T, @intCast(old_pos_abs));
}

pub fn calculateNewScrollPosition(
    comptime T: type,
    pos_abs: *u8,
    pos_rel: anytype,
    new_pos: u8,
    wrap_count: T,
    max_increment: ?T,
) ?T {
    if (wrap_count == 0) return null;

    const PosRelType = @typeInfo(@TypeOf(pos_rel));
    if (PosRelType != .Pointer) {
        @compileError("pos_rel must be a pointer");
    }
    if (@typeInfo(PosRelType.Pointer.child) != .Int) {
        @compileError("pos_rel must point to an integer type");
    }

    const old_pos_abs = pos_abs.*;
    pos_abs.* = new_pos;

    var delta = calculateDelta(T, old_pos_abs, new_pos);

    if (max_increment) |max_inc| {
        if (@abs(delta) > max_inc) {
            delta = if (delta > 0) max_inc else -max_inc;
        }
    }

    const new_pos_rel = @as(T, @intCast(pos_rel.*)) + @as(T, @intCast(delta));

    if (new_pos_rel >= wrap_count) {
        pos_rel.* = @intCast(@rem(new_pos_rel, wrap_count));
    } else if (new_pos_rel < 0) {
        const wrapped = wrap_count - @rem(@as(T, @intCast(@abs(new_pos_rel))), wrap_count);
        pos_rel.* = @intCast(if (wrapped == wrap_count) 0 else wrapped);
    } else {
        pos_rel.* = @intCast(new_pos_rel);
    }
    return delta;
}
