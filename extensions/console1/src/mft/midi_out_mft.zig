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

// Ring position on channel 1: a byte from 0 to 127. The byte is kept in `globals.feedback`, and a ring that already shows it is not sent
// again.
pub fn setRing(globals: *MftGlobals, slot: u3, byte: u8) void {
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
    if (MappableModule.fromActive(globals.mft.active_module)) |module| {
        if (globals.current_track) |track| {
            fb.routing = mft_fx.resolveModule(globals, track, module);
            wanted = mft_feedback.wantedFrame(track, &fb.routing);
        }
    }
    var changed: [mft_feedback.ring_count]u8 = undefined;
    const count = mft_feedback.diffRings(&fb.rings, &wanted, &changed);
    const midi_out = globals.m_midi_out.?;
    for (changed[0..count]) |slot| {
        c.MidiOut_Send(midi_out, 0xb0 | mft.ENCODER_ROT_CHANNEL, slot, wanted[slot], -1);
    }
}

// A parameter moved in REAPER (REAPER's SETFXPARAM notification). Its ring follows when one of the encoders of the active module moves it.
pub fn syncParam(globals: *MftGlobals, track: reaper.MediaTrack, fx_index: u16, param: u16, value: f64) void {
    if (track != globals.current_track) return;
    const slot = mft_feedback.slotForParam(&globals.feedback.routing, fx_index, param) orelse return;
    setRing(globals, slot, mft_feedback.ringByte(value));
}

// Color on channel 3: a hue position on the 0-127 wheel, sent to all 16 knobs
// so the whole surface reflects the active module.
pub fn sendModuleColor(midi_out: reaper.midi_Output, hue: u8) void {
    for (0..16) |i| {
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
