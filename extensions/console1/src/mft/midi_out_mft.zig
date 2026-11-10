const std = @import("std");
const builtin = @import("builtin");
// The C declarations, translated by the build from src/csurf/c_bindings.h.
const c = @import("c");
const reaper = @import("reaper").reaper;
const mft = @import("mft.zig");
const MftGlobals = @import("mft_globals.zig").MftGlobals;
const MappableModule = @import("mft_mappings.zig").MappableModule;
const mft_fx = @import("mft_fx.zig");
const mft_feedback = @import("mft_feedback.zig");
const settings_rows = @import("mft_settings_rows.zig");

// Ring position on channel 1: a byte from 0 to 127. The byte is kept in `globals.feedback`, and a ring that already shows it is not sent
// again.
pub fn setRing(globals: *MftGlobals, slot: u4, byte: u8) void {
    const midi_out = globals.m_midi_out orelse return;
    std.debug.assert(byte <= 127);
    if (globals.feedback.rings[slot] == byte) return;
    globals.feedback.rings[slot] = byte;
    c.MidiOut_Send(midi_out, 0xb0 | mft.ENCODER_ROT_CHANNEL, @intCast(@as(u8, slot)), byte, -1);
}

// Makes the rings show what the active module's parameters are on the current track: each mapped encoder shows its parameter, and the
// others are empty. With `force`, the controller is told every ring again, which is needed when the module or the track changed and
// when the controller connects. Because the routing is read again here, it is also what a change of the FX chain calls.
pub fn syncRings(globals: *MftGlobals, force: bool) void {
    if (globals.m_midi_out == null) return;
    const fb = &globals.feedback;
    if (force) fb.invalidate();
    fb.routing = .{};
    var wanted: [mft_feedback.ring_count]u8 = @splat(0);
    // The FX SEL mode has no parameters on its encoders, so its rings are empty.
    if (globals.mft.fxsel == null) {
        if (globals.current_track) |track| {
            if (MappableModule.fromActive(globals.mft.active_module)) |module| {
                fb.routing = mft_fx.resolveModule(globals, track, module);
                wanted = mft_feedback.wantedFrame(track, &fb.routing);
            } else if (globals.mft.active_module == .AUTO) {
                // The knobs of the AUTO page that have a parameter of an FX show it, as those of a module do.
                fb.routing = mft_fx.resolveAuto(globals, track);
                wanted = mft_feedback.wantedFrame(track, &fb.routing);
            }
        }
        // On the SETTINGS page, the ring of the first encoder says where the highlight of the rows is, and the ring of the second the value of that row.
        if (globals.mft.active_module == .SETTINGS) {
            const cursor: usize = @min(globals.mft.settings_cursor, settings_rows.row_count - 1);
            wanted[0] = mft_feedback.ringByte(@as(f64, @floatFromInt(cursor)) / @as(f64, @floatFromInt(settings_rows.row_count - 1)));
            wanted[1] = mft_feedback.ringByte(settings_rows.fraction(&globals.preferences, settings_rows.rows[cursor]));
        }
    }
    // On the transport page the rings of the volume and the pan show those of the track.
    if (globals.mft.fxsel == null and globals.mft.active_module == .TRANSPORT) {
        if (globals.current_track) |track| {
            wanted[mft_feedback.transport_volume_ring] = mft_feedback.volumeRingByte(reaper.GetMediaTrackInfo_Value(track, "D_VOL"));
            wanted[mft_feedback.transport_pan_ring] = mft_feedback.panRingByte(reaper.GetMediaTrackInfo_Value(track, "D_PAN"));
        }
    }
    var changed: [mft_feedback.ring_count]u8 = undefined;
    const count = mft_feedback.diffRings(&fb.rings, &wanted, &changed);
    const midi_out = globals.m_midi_out.?;
    for (changed[0..count]) |slot| {
        c.MidiOut_Send(midi_out, 0xb0 | mft.ENCODER_ROT_CHANNEL, slot, wanted[slot], -1);
    }
}

// The meters of the active page, which REAPER does not report as notifications, so the run loop of the surface asks for them. On the compressor
// page, the ring of the ninth encoder shows the gain reduction of the compressor, unless the map gives that encoder a parameter.
pub fn syncMeters(globals: *MftGlobals) void {
    if (globals.m_midi_out == null or globals.mft.fxsel != null or globals.mft.active_module != .COMP) return;
    const track = globals.current_track orelse return;
    const routing = &globals.feedback.routing;
    if (routing.targets[mft_feedback.gain_reduction_ring] != null) return;
    // Any encoder that the map routes names the plugin of the page.
    var fx_index: ?c_int = null;
    for (routing.targets) |maybe_target| {
        if (maybe_target) |target| {
            fx_index = target.fx_index;
            break;
        }
    }
    const fx = fx_index orelse return;
    var buf: [32:0]u8 = undefined;
    if (!reaper.TrackFX_GetNamedConfigParm(track, fx, "GainReduction_dB", &buf, buf.len)) return;
    const db = std.fmt.parseFloat(f64, std.mem.sliceTo(&buf, 0)) catch return;
    setRing(globals, mft_feedback.gain_reduction_ring, mft_feedback.gainReductionRingByte(db));
}

// The volume or the pan of a track moved in REAPER. On the transport page, the ring of that knob follows when the track is the current one.
pub fn syncTrackMix(globals: *MftGlobals, track: reaper.MediaTrack, volume: ?f64, pan: ?f64) void {
    if (track != globals.current_track or globals.mft.fxsel != null or globals.mft.active_module != .TRANSPORT) return;
    if (volume) |v| setRing(globals, mft_feedback.transport_volume_ring, mft_feedback.volumeRingByte(v));
    if (pan) |p| setRing(globals, mft_feedback.transport_pan_ring, mft_feedback.panRingByte(p));
}

// A parameter moved in REAPER (REAPER's SETFXPARAM notification). Its ring follows when one of the encoders of the active module moves it.
pub fn syncParam(globals: *MftGlobals, track: reaper.MediaTrack, fx_index: u16, param: u16, value: f64) void {
    if (track != globals.current_track or globals.mft.fxsel != null) return;
    const slot = mft_feedback.slotForParam(&globals.feedback.routing, fx_index, param) orelse return;
    setRing(globals, slot, mft_feedback.ringByte(value));
}

// Color on channel 2: a hue position on the 0-127 wheel for each of the 16 knobs. The top rows show the color of the active page, and each
// encoder of the bottom row the color of its own page.
pub fn sendPageColors(midi_out: reaper.midi_Output, hues: [16]u8) void {
    for (hues, 0..) |hue, i| {
        c.MidiOut_Send(midi_out, 0xb0 | mft.COLOR_CHANNEL, @intCast(i), hue, -1);
    }
}

// Turn every ring and color LED off. Used on connect and disconnect.
pub fn clearAll(midi_out: reaper.midi_Output) void {
    for (0..16) |i| {
        c.MidiOut_Send(midi_out, 0xb0 | mft.ENCODER_ROT_CHANNEL, @intCast(i), 0x0, -1);
        c.MidiOut_Send(midi_out, 0xb0 | mft.COLOR_CHANNEL, @intCast(i), 0x0, -1);
    }
}

// Set every knob to one hue. Used by the LED test to sweep colors.
pub fn sendAllColors(midi_out: reaper.midi_Output, hue: u8) void {
    for (0..16) |i| {
        c.MidiOut_Send(midi_out, 0xb0 | mft.COLOR_CHANNEL, @intCast(i), hue, -1);
    }
}

// Set every ring to one position. Used by the LED test to sweep the rings.
pub fn sendAllRings(midi_out: reaper.midi_Output, val: u8) void {
    for (0..16) |i| {
        c.MidiOut_Send(midi_out, 0xb0 | mft.ENCODER_ROT_CHANNEL, @intCast(i), val, -1);
    }
}
