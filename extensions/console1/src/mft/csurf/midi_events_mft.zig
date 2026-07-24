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
const mappings = @import("../mft_mappings.zig");
const MappableModule = mappings.MappableModule;
const mft_fx = @import("../mft_fx.zig");
const midi_out = @import("../midi_out_mft.zig");
const log = std.log.scoped(.mft_midi);

pub fn OnMidiEvent(evt: *c.MIDI_event_t, globals: *MftGlobals) void {
    const msg = c.MIDI_event_message(evt);
    const status = msg[0] & 0xf0;
    const chan = msg[0] & 0x0f;
    const cc = if (status == 0xb0) msg[1] else msg[0];
    const val = if (status == 0xb0) msg[2] else msg[1];

    // While calibration is running, every event is captured by the wizard
    // instead of driving parameters or switching modules.
    if (globals.wizard.active) {
        globals.wizard.onMidi(chan, cc, val);
        return;
    }

    switch (chan) {
        mft.ENCODER_ROT_CHANNEL => onEncoderRotation(cc, val, globals),
        mft.ENCODER_BTN_CHANNEL => onEncoderButton(cc, val, globals),
        mft.SIDE_BTN_CHANNEL => onSideButton(cc, val, globals),
        else => {},
    }
}

fn onEncoderRotation(cc: u8, val: u8, globals: *MftGlobals) void {
    if (cc >= 8) return;
    const slot: u3 = @intCast(cc);

    const delta = mft.decodeRelative(val);
    if (delta == 0) return;
    const sensitivity: f32 = if (globals.mft.isHeld(cc)) mft.FINE_SENSITIVITY_MULTIPLIER else 1.0;
    const delta_f32 = @as(f32, @floatFromInt(delta)) * mft.BASE_SENSITIVITY * sensitivity;

    const module = MappableModule.fromActive(globals.mft.active_module) orelse return;
    const track = globals.current_track orelse return;
    const routing = mft_fx.resolveModule(globals, track, module);
    const target = routing.targets[slot] orelse return;

    const current = reaper.TrackFX_GetParamNormalized(track, target.fx_index, @intCast(target.param));
    const new_val = std.math.clamp(current + @as(f64, delta_f32), 0.0, 1.0);
    _ = reaper.TrackFX_SetParamNormalized(track, target.fx_index, @intCast(target.param), new_val);

    if (globals.m_midi_out) |mo| {
        midi_out.sendRingUpdate(mo, slot, @floatCast(new_val));
    }
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

    // Switching to a mappable module auto-inserts its default plugins onto the
    // current track if absent, matching the Console One behavior.
    if (MappableModule.fromActive(module)) |mappable| {
        if (globals.current_track) |track| {
            mft_fx.ensureModuleFx(track, mappable);
        }
    }

    if (globals.m_midi_out) |mo| {
        midi_out.sendModuleColor(mo, module);
    }
}

fn onSideButton(cc: u8, val: u8, globals: *MftGlobals) void {
    _ = cc;
    _ = val;
    _ = globals;
    // Unused by design: the extension follows REAPER's last-touched track, so
    // the side buttons have no function. Hardware calibration found them on
    // channel 4, CCs 8-13 (see mft.SIDE_BUTTON_CCS) if a use is ever assigned.
}
