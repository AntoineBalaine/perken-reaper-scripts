const std = @import("std");
const reaper = @import("reaper").reaper;
const pReaper = @import("pReaper.zig");
const c1 = @import("c1.zig");

const BandType = enum(c_int) {
    loshelf = 0,
    hishelf = 1,
    band = 8,
    hipass = 4,
    lopass = 3,
};

// The allowed filter types for each shape button. Each press cycles to
// the next type in the sequence, wrapping around at the end.
const lo_band_cycle = [_]BandType{ .loshelf, .band, .hipass };
const hi_band_cycle = [_]BandType{ .hishelf, .band, .lopass };

pub fn cycleReaEqFilterType(mediaTrack: reaper.MediaTrack, fxidx: c_int, cc: c1.CCs) void {
    const bandid: u8 = if (cc == c1.CCs.Eq_lp_shape) 0 else if (cc == c1.CCs.Eq_hp_shape) 3 else return;
    const cycle = if (cc == c1.CCs.Eq_lp_shape) &lo_band_cycle else &hi_band_cycle;

    // Read the current band type
    var bandKeyBuf: [64:0]u8 = undefined;
    _ = std.mem.printSentinel(&bandKeyBuf, "BANDTYPE{d}", .{bandid}, 0) catch return;
    var valueBuf: [64:0]u8 = undefined;
    if (!reaper.TrackFX_GetNamedConfigParm(mediaTrack, fxidx, &bandKeyBuf, &valueBuf, valueBuf.len)) return;

    const current_str = std.mem.span(@as([*:0]const u8, &valueBuf));
    const current_int = std.fmt.parseInt(c_int, current_str, 10) catch return;

    // Find the current type in the cycle and advance to the next one
    var next_idx: usize = 0;
    for (cycle, 0..) |bt, i| {
        if (@backingInt(bt) == current_int) {
            next_idx = (i + 1) % cycle.len;
            break;
        }
    }

    var newValueBuf: [64:0]u8 = undefined;
    _ = std.mem.printSentinel(&newValueBuf, "{d}", .{@backingInt(cycle[next_idx])}, 0) catch return;
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ mediaTrack, fxidx, @as([*:0]u8, &bandKeyBuf), @as([*:0]u8, &newValueBuf) });
}
