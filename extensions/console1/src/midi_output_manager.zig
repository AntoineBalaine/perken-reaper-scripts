const std = @import("std");
const Reaper = @import("../reaper.zig");
const reaper = Reaper.reaper;
const MediaTrack = Reaper.reaper.MediaTrack;
const c1 = @import("../c1.zig");
const c = @cImport({
    @cDefine("SWELL_PROVIDED_BY_APP", "");
    @cInclude("csurf/control_surface_wrapper.h");
    @cInclude("../WDL/swell/swell-types.h");
    @cInclude("../WDL/swell/swell-functions.h");
    @cInclude("../WDL/win32_utf8.h");
    @cInclude("../WDL/wdltypes.h");
    @cInclude("resource.h");
    @cInclude("csurf/midi_wrapper.h");
});

// Structured way to send CC messages
pub fn sendCC(midiout: ?*reaper.midi_Output, cc: c1.CCs, value: u8) void {
    if (midiout.midiout) |out| {
        c.MidiOut_Send(out, 0xb0, @intFromEnum(cc), value, -1);
    }
}

// Higher level functions for specific feedback types
pub fn updateParam(midiout: ?*reaper.midi_Output, cc: c1.CCs, normalized_value: f64) void {
    const midi_value = @as(u7, @intFromFloat(normalized_value * 127));
    midiout.sendCC(cc, midi_value);
}

pub fn updateTrackSelection(midiout: ?*reaper.midi_Output, track_number: u8, selected: bool) void {
    const cc = @as(c1.CCs, @enumFromInt(@as(u8, 0x15) + track_number - 1));
    midiout.sendCC(cc, if (selected) 0x7f else 0x0);
}

pub fn sendNormalizedValue(midiout: ?*reaper.midi_Output, cc: c1.CCs, normalized: f64) void {
    const midi_value: u8 = @intFromFloat(normalized * 127);
    midiout.sendCC(cc, midi_value);
}

pub fn sendBoolValue(midiout: ?*reaper.midi_Output, cc: c1.CCs, value: bool) void {
    midiout.sendCC(cc, if (value) 0x7f else 0x0);
}

// Track-specific helpers
pub fn sendTrackSelection(midiout: ?*reaper.midi_Output, track_number: u8, selected: bool) void {
    const cc = @as(c1.CCs, @enumFromInt(@as(u8, 0x15) + track_number - 1));
    midiout.sendBoolValue(cc, selected);
}

const TWENTY_OVER_LN10 = 8.6858896380650365530225783783321;
fn VAL2DB(x: f64) f64 {
    if (x < 0.0000000298023223876953125) return -150.0;
    const v: f64 = std.math.log(@TypeOf(x), 10, x) * TWENTY_OVER_LN10;
    return if (v < -150.0) -150.0 else v;
}

// Used for converting dB volume to MIDI CC value
// Called in selectTrk() when sending Out_Vol feedback
pub fn volToMidi(vol: f64) u8 {
    var d: f64 = (reaper.DB2SLIDER(VAL2DB(vol)) * 127.0 / 1000.0);
    d = if (d < 0.0) 0.0 else if (d > 127.0) 127.0 else d;
    return @intFromFloat(d + 0.5);
}

// Used for converting pan position (-1.0 to 1.0) to MIDI CC value
// Called in selectTrk() when sending Out_Pan feedback
pub fn panToMidi(pan: f64) u8 {
    // Shift range from [-1,1] to [0,1], then scale to MIDI range
    return @intFromFloat((pan + 1.0) / 2.0 * 127.0);
}

// Used for converting normalized parameter value (0.0 to 1.0) to MIDI CC value
// Called in selectTrk() when sending fx parameter feedback
pub fn normalizedToMidi(normalized: f64) u8 {
    return @intFromFloat(normalized * 127.0);
}

// Used for converting track ID to track button CC value
// Called in selectTrk() for track selection feedback
pub fn trackIdToMidi(id: c_int, page_offset: c_int) u8 {
    _ = page_offset; // autofix
    return @intCast(@rem(id, 20) + 0x15 - 1);
}

// Used for converting boolean state to MIDI CC value
// Called in selectTrk() for mute/solo feedback
pub fn boolToMidi(value: bool) u8 {
    return if (value) 0x7f else 0x0;
}

// used for converting track number (1-based) to track button CC value (0x15-based)
// used in: selectTrk() for track selection LED
pub fn trackNumToMidi(track_num: usize) u8 {
    _ = track_num; // autofix
    unreachable;
}

// used for converting gain reduction value in dB to MIDI value (0-127)
// used in: Run() for compressor meter
pub fn dbToMidi(db_value: f64) u8 {
    _ = db_value; // autofix
    unreachable;
}

// used for converting peak meter value (0.0-1.0) to MIDI value (0-127)
// used in: Run() for input/output meters
pub fn peakToMidi(peak: f64) u8 {
    _ = peak; // autofix
    unreachable;
}
