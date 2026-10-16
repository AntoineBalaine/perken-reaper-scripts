const std = @import("std");
const builtin = @import("builtin");
const c = @cImport({
    @cDefine("WDL_ALLOW_UNSIGNED_DEFAULT_CHAR", "1");
    if (builtin.os.tag != .windows) {
        @cDefine("SWELL_PROVIDED_BY_APP", "");
    }
    @cInclude("csurf/control_surface_wrapper.h");
    if (builtin.os.tag == .windows) {
        @cInclude("windows.h");
    } else {
        @cInclude("WDL/swell/swell-types.h");
        @cInclude("WDL/swell/swell-functions.h");
    }
    @cInclude("WDL/win32_utf8.h");
    @cInclude("WDL/wdltypes.h");
    @cInclude("resource.h");
    @cInclude("csurf/midi_wrapper.h");
});
const reaper = @import("reaper").reaper;
const mft = @import("mft.zig");

// Ring position on channel 1: the normalized parameter value scaled to 0-127.
pub fn sendRingUpdate(midi_out: reaper.midi_Output, slot: u3, normalized: f32) void {
    std.debug.assert(normalized >= 0.0 and normalized <= 1.0);
    const val: u8 = @intFromFloat(normalized * 127.0);
    c.MidiOut_Send(midi_out, 0xb0 | mft.ENCODER_ROT_CHANNEL, @intCast(@as(u8, slot)), val, -1);
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
