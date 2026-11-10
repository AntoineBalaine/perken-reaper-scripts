//! What the rings of the controller should show, and the bookkeeping that keeps the controller in step with REAPER.
//!
//! Because a ring is only a number that the controller keeps until it is told another one, the extension has to send a ring again
//! whenever what it stands for changes: when the module switches, when the track changes, and when the parameter moves in REAPER
//! (with the mouse, the automation or another surface). To send as little as possible, the last byte that went to each ring is kept,
//! and a ring is sent only when its byte differs.
//!
//! This file has no MIDI output of its own, because the unit tests cannot link the C headers that sending needs. The sending is in
//! `midi_out_mft.zig`, which calls the functions here.
const std = @import("std");
const reaper = @import("reaper").reaper;
const mft_fx = @import("mft_fx.zig");

pub const SlotRouting = mft_fx.SlotRouting;

/// How many rings the controller has.
pub const ring_count = 16;

/// The byte of a ring for a normalized parameter value. Because REAPER reports a parameter that it cannot read as -1 or as NaN,
/// and a ring must stay inside 0 to 127, those values are an empty ring.
pub fn ringByte(normalized: f64) u8 {
    if (std.math.isNan(normalized) or normalized <= 0.0) return 0;
    if (normalized >= 1.0) return 127;
    return @intFromFloat(normalized * 127.0);
}

/// The encoders of the TRANSPORT page whose rings show the volume and the pan of the track: the fifth and the sixth of the bottom row.
pub const transport_volume_ring = 12;
pub const transport_pan_ring = 13;

/// The ring of a track volume (a linear factor). Because 0 dB is the position that matters, it is at noon, the middle of the ring: the lower
/// half goes from -60 dB to 0 dB and the upper half from 0 dB to +12 dB, which is the range that the turns of the volume knob stay in.
pub fn volumeRingByte(volume: f64) u8 {
    if (std.math.isNan(volume)) return 0;
    const db = 20.0 * @log10(@max(volume, 1e-6));
    const position = if (db <= 0.0) 0.5 * (db + 60.0) / 60.0 else 0.5 + 0.5 * db / 12.0;
    return ringByte(position);
}

/// The ring of a pan from -1 (left) to 1 (right): the middle is the middle of the ring.
pub fn panRingByte(pan: f64) u8 {
    if (std.math.isNan(pan)) return 0;
    return ringByte((pan + 1.0) / 2.0);
}

/// The FX and the parameter that a notification of REAPER names. REAPER packs them in one integer, the FX index in its high 16 bits
/// and the parameter index in its low 16.
pub const FxParam = struct { fx_index: u16, param: u16 };

pub fn decodeFxParam(packed_value: c_int) FxParam {
    const bits: u32 = @bitCast(packed_value);
    return .{ .fx_index = @intCast(bits >> 16), .param = @intCast(bits & 0xFFFF) };
}

pub const Feedback = struct {
    /// The last byte that was sent to each ring, or null when it is not known what the ring shows, which is the case after the
    /// controller connects and after a color test.
    rings: [ring_count]?u8 = @splat(null),
    /// The routing that the rings were computed from, so that the notification of one parameter finds its encoder without reading
    /// the maps again.
    routing: SlotRouting = .{},

    /// Forgets what the rings show, so that the next synchronization sends all of them.
    pub fn invalidate(self: *Feedback) void {
        self.rings = @splat(null);
    }
};

/// The bytes that the sixteen rings should show for a routing: the encoder of each mapped slot shows its parameter, and the others
/// are empty.
pub fn wantedFrame(track: reaper.MediaTrack, routing: *const SlotRouting) [ring_count]u8 {
    var frame: [ring_count]u8 = @splat(0);
    for (routing.targets, 0..) |target, slot| {
        const t = target orelse continue;
        frame[slot] = ringByte(reaper.TrackFX_GetParamNormalized(track, t.fx_index, @intCast(t.param)));
    }
    return frame;
}

/// Compares the bytes that the rings should show with the ones that were sent, keeps the new bytes in `cache`, and writes the index
/// of every ring that has to be sent into `changed`. It returns how many there are.
pub fn diffRings(cache: *[ring_count]?u8, wanted: *const [ring_count]u8, changed: *[ring_count]u8) usize {
    var count: usize = 0;
    for (wanted, 0..) |byte, slot| {
        if (cache[slot] == byte) continue;
        cache[slot] = byte;
        changed[count] = @intCast(slot);
        count += 1;
    }
    return count;
}

/// The encoder that a parameter belongs to, or null when no encoder of the routing moves it.
pub fn slotForParam(routing: *const SlotRouting, fx_index: u16, param: u16) ?u4 {
    for (routing.targets, 0..) |target, slot| {
        const t = target orelse continue;
        if (t.fx_index == @as(c_int, fx_index) and t.param == param) return @intCast(slot);
    }
    return null;
}

test "ringByte: the ends, the middle, and the values that REAPER uses for a parameter it cannot read" {
    const t = std.testing;
    try t.expectEqual(@as(u8, 0), ringByte(0.0));
    try t.expectEqual(@as(u8, 127), ringByte(1.0));
    try t.expectEqual(@as(u8, 63), ringByte(0.5));
    try t.expectEqual(@as(u8, 0), ringByte(-1.0));
    try t.expectEqual(@as(u8, 0), ringByte(std.math.nan(f64)));
    try t.expectEqual(@as(u8, 127), ringByte(1.5));
}

test "volumeRingByte and panRingByte: the ends and the middle of the fader and of the pan" {
    const t = std.testing;
    try t.expectEqual(@as(u8, 0), volumeRingByte(0.0));
    try t.expectEqual(@as(u8, 127), volumeRingByte(4.0));
    // Unity gain is at noon, and -30 dB and +6 dB are the middles of the two halves.
    try t.expectEqual(@as(u8, 63), volumeRingByte(1.0));
    try t.expectEqual(@as(u8, 31), volumeRingByte(std.math.pow(f64, 10.0, -30.0 / 20.0)));
    try t.expectEqual(@as(u8, 95), volumeRingByte(std.math.pow(f64, 10.0, 6.0 / 20.0)));
    try t.expect(volumeRingByte(0.5) < volumeRingByte(1.0));
    try t.expectEqual(@as(u8, 0), volumeRingByte(std.math.nan(f64)));
    try t.expectEqual(@as(u8, 0), panRingByte(-1.0));
    try t.expectEqual(@as(u8, 63), panRingByte(0.0));
    try t.expectEqual(@as(u8, 127), panRingByte(1.0));
}

test "decodeFxParam: the FX index is the high half and the parameter the low half" {
    const t = std.testing;
    const small = decodeFxParam((3 << 16) | 7);
    try t.expectEqual(@as(u16, 3), small.fx_index);
    try t.expectEqual(@as(u16, 7), small.param);
    // Because the high bit of a large index makes the integer negative, the halves must be read from the bits.
    const large = decodeFxParam(@bitCast(@as(u32, 0xFFFE_0010)));
    try t.expectEqual(@as(u16, 0xFFFE), large.fx_index);
    try t.expectEqual(@as(u16, 0x0010), large.param);
}

test "diffRings: only the rings that changed are sent, and a second call sends nothing" {
    const t = std.testing;
    var cache: [ring_count]?u8 = @splat(null);
    var wanted: [ring_count]u8 = @splat(0);
    wanted[2] = 64;
    var changed: [ring_count]u8 = undefined;

    // Nothing is known at first, so every ring is sent, even the empty ones: they have to be cleared.
    try t.expectEqual(@as(usize, ring_count), diffRings(&cache, &wanted, &changed));
    try t.expectEqual(@as(usize, 0), diffRings(&cache, &wanted, &changed));

    wanted[2] = 65;
    wanted[9] = 1;
    try t.expectEqual(@as(usize, 2), diffRings(&cache, &wanted, &changed));
    try t.expectEqual(@as(u8, 2), changed[0]);
    try t.expectEqual(@as(u8, 9), changed[1]);
}

test "Feedback.invalidate: the next synchronization sends every ring again" {
    const t = std.testing;
    var fb = Feedback{};
    const wanted: [ring_count]u8 = @splat(5);
    var changed: [ring_count]u8 = undefined;
    _ = diffRings(&fb.rings, &wanted, &changed);
    try t.expectEqual(@as(usize, 0), diffRings(&fb.rings, &wanted, &changed));
    fb.invalidate();
    try t.expectEqual(@as(usize, ring_count), diffRings(&fb.rings, &wanted, &changed));
}

test "slotForParam: finds the encoder that moves a parameter, and nothing for another one" {
    const t = std.testing;
    var routing = SlotRouting{};
    routing.targets[1] = .{ .fx_index = 4, .param = 9 };
    routing.targets[6] = .{ .fx_index = 2, .param = 0 };
    try t.expectEqual(@as(?u4, 1), slotForParam(&routing, 4, 9));
    try t.expectEqual(@as(?u4, 6), slotForParam(&routing, 2, 0));
    try t.expectEqual(@as(?u4, null), slotForParam(&routing, 4, 8));
    try t.expectEqual(@as(?u4, null), slotForParam(&routing, 5, 9));
}
