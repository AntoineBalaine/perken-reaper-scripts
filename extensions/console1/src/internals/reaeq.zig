const std = @import("std");
const reaper = @import("../reaper.zig").reaper;
const c1 = @import("c1.zig");
const bandtypes = enum(c_int) {
    allpass = 5,
    band = 8,
    band_alt = 9,
    band_alt2 = 2,
    bandpass = 7,
    hipass = 4,
    hishelf = 1,
    lopass = 3,
    loshelf = 0,
    notch = 6,
    parallel_ban = 10,
};

// Console1 only supports cut, bell, shelf for bands 1 and 4
//
pub fn setReaEqFilterType(mediaTrack: reaper.MediaTrack, fxidx: c_int, cc: c1.CCs, ccval: u8) void {
    var bandTypeBuf: [64:0]u8 = undefined;
    // only allow three types of filters
    // get value from controller?
    const bandid: ?u8 = if (cc == c1.CCs.Eq_hp_shape) 0 else if (cc == c1.CCs.Eq_lp_shape) 3 else null;
    if (bandid == null) return;
    _ = std.fmt.bufPrintZ(&bandTypeBuf, "BANDTYPE{d}", .{bandid.?}) catch {
        return;
    };
    const val = switch (ccval) {
        //shelf
        0x0 => if (cc == c1.CCs.Eq_hp_shape) bandtypes.loshelf else if (cc == c1.CCs.Eq_lp_shape) bandtypes.hishelf else null,
        // bell
        0x3f => bandtypes.band,
        // cut
        0x7f => if (cc == c1.CCs.Eq_hp_shape) bandtypes.hipass else if (cc == c1.CCs.Eq_lp_shape) bandtypes.lopass else null,
        else => null,
    };
    if (val) |value| {
        var valueBuf: [64:0]u8 = undefined;
        _ = std.fmt.bufPrintZ(&valueBuf, "{d}", .{@intFromEnum(value)}) catch {
            return;
        };
        _ = reaper.TrackFX_SetNamedConfigParm(mediaTrack, fxidx, @as([*:0]u8, &bandTypeBuf), @as([*:0]u8, &valueBuf));
    }
}
