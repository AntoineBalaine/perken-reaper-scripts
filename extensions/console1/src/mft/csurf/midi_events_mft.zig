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
const mft = @import("../mft.zig");
const MftGlobals = @import("../mft_globals.zig").MftGlobals;
const MftActiveModule = @import("../mft_state.zig").MftActiveModule;
const MODULE_COLORS = @import("../mft_state.zig").MODULE_COLORS;

pub fn OnMidiEvent(evt: *c.MIDI_event_t, globals: *MftGlobals) void {
    const msg = c.MIDI_event_message(evt);
    const status = msg[0] & 0xf0;
    const chan = msg[0] & 0x0f;
    const cc = if (status == 0xb0) msg[1] else msg[0];
    const val = if (status == 0xb0) msg[2] else msg[1];

    switch (chan) {
        mft.ENCODER_ROT_CHANNEL => onEncoderRotation(cc, val, globals),
        mft.ENCODER_BTN_CHANNEL => onEncoderButton(cc, val, globals),
        mft.SIDE_BTN_CHANNEL => onSideButton(cc, val, globals),
        else => {},
    }
}

fn onEncoderRotation(cc: u8, val: u8, globals: *MftGlobals) void {
    if (cc >= 8) return;
    const delta = mft.decodeTwosComplement(val);
    const sensitivity: f32 = if (globals.mft.isHeld(cc)) mft.FINE_SENSITIVITY_MULTIPLIER else 1.0;
    const delta_f32 = @as(f32, @floatFromInt(delta)) * mft.BASE_SENSITIVITY * sensitivity;
    _ = delta_f32;
    // TODO phase 4: look up mapping for active module, apply delta to FX parameter, send ring update
}

fn onEncoderButton(cc: u8, val: u8, globals: *MftGlobals) void {
    const pressed = val == 127;
    if (cc < 8) {
        if (pressed) globals.mft.setHeld(cc) else globals.mft.clearHeld(cc);
        return;
    }
    if (!pressed) return;
    const module: MftActiveModule = switch (cc) {
        8 => .IO,
        9 => .GATE,
        10 => .EQ,
        11 => .COMP,
        12 => .SETTINGS,
        13 => .TRANSPORT,
        else => return,
    };
    globals.mft.active_module = module;
    if (globals.m_midi_out) |midi_out| {
        sendModuleColor(midi_out, module);
    }
}

fn onSideButton(cc: u8, val: u8, globals: *MftGlobals) void {
    _ = cc;
    _ = val;
    _ = globals;
    // TODO phase 4.9: track previous / next
}

fn sendModuleColor(midi_out: reaper.midi_Output, module: MftActiveModule) void {
    const color = MODULE_COLORS.get(module);
    for (0..16) |i| {
        c.MidiOut_Send(midi_out, 0xb2, @intCast(i), color, -1);
    }
}
