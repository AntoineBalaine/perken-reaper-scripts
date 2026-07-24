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
const mft_transport = @import("../mft_transport.zig");
const mft_settings = @import("../mft_settings.zig");
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

    // Transport mode drives its own continuous functions; settings mode has none
    // yet. Only a mappable module routes to FX parameters.
    switch (globals.mft.active_module) {
        .TRANSPORT => return mft_transport.onRotate(slot, delta),
        .SETTINGS => return settingsRotate(globals, slot, delta),
        else => {},
    }

    const fine: f32 = if (globals.mft.isHeld(cc)) mft.FINE_SENSITIVITY_MULTIPLIER else 1.0;
    const delta_f32 = @as(f32, @floatFromInt(delta)) * mft.BASE_SENSITIVITY * fine * globals.preferences.sensitivity;

    const module = MappableModule.fromActive(globals.mft.active_module) orelse return;
    const track = globals.current_track orelse return;
    const routing = mft_fx.resolveModule(globals, track, module);
    const target = routing.targets[slot] orelse return;

    globals.mft.last_fx_index = target.fx_index;
    const current = reaper.TrackFX_GetParamNormalized(track, target.fx_index, @intCast(target.param));
    const new_val = std.math.clamp(current + @as(f64, delta_f32), 0.0, 1.0);
    _ = reaper.TrackFX_SetParamNormalized(track, target.fx_index, @intCast(target.param), new_val);

    if (globals.m_midi_out) |mo| {
        midi_out.sendRingUpdate(mo, slot, @floatCast(new_val));
    }
}

fn wrapHue(cur: u8, delta: i8) u8 {
    return @intCast(@mod(@as(i16, cur) + delta, 128));
}

// Settings mode: encoder 1 scrolls the highlighted row, encoder 2 adjusts the
// selected value. Text (plugin name) rows are edited with the keyboard in the
// panel, so encoder 2 has no effect on them.
fn settingsRotate(globals: *MftGlobals, slot: u3, delta: i8) void {
    switch (slot) {
        0 => {
            const n = @as(i16, globals.mft.settings_cursor) + delta;
            globals.mft.settings_cursor = @intCast(@mod(n, mft_settings.ITEM_COUNT));
        },
        1 => adjustSelectedSetting(globals, delta),
        else => {},
    }
}

fn adjustSelectedSetting(globals: *MftGlobals, delta: i8) void {
    const p = &globals.preferences;
    const hue: ?u8 = switch (globals.mft.settings_cursor) {
        0 => blk: {
            p.color_io = wrapHue(p.color_io, delta);
            break :blk p.color_io;
        },
        1 => blk: {
            p.color_gate = wrapHue(p.color_gate, delta);
            break :blk p.color_gate;
        },
        2 => blk: {
            p.color_eq = wrapHue(p.color_eq, delta);
            break :blk p.color_eq;
        },
        3 => blk: {
            p.color_comp = wrapHue(p.color_comp, delta);
            break :blk p.color_comp;
        },
        4 => blk: {
            p.sensitivity = std.math.clamp(p.sensitivity + @as(f32, @floatFromInt(delta)) * 0.05, 0.1, 4.0);
            break :blk null;
        },
        else => null, // plugin-name rows: keyboard only
    };
    if (hue) |h| {
        if (globals.m_midi_out) |mo| midi_out.sendAllColors(mo, h);
    }
}

fn onEncoderButton(cc: u8, val: u8, globals: *MftGlobals) void {
    const pressed = val == 127;
    if (cc < 8) {
        // Presses on the top two rows depend on the active mode. In a mappable
        // module they arm fine-tune; in transport mode they drive transport.
        switch (globals.mft.active_module) {
            .TRANSPORT => if (pressed) mft_transport.onPress(@intCast(cc)),
            .SETTINGS => {},
            else => if (pressed) globals.mft.setHeld(cc) else globals.mft.clearHeld(cc),
        }
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
            mft_fx.ensureModuleFx(globals, track, mappable);
        }
    }

    if (globals.m_midi_out) |mo| {
        midi_out.sendModuleColor(mo, globals.preferences.colorForModule(module));
    }
}

fn onSideButton(cc: u8, val: u8, globals: *MftGlobals) void {
    if (val != 127) return;
    const track = globals.current_track orelse return;
    // Side buttons on channel 4, CCs 8-13: L1-L3 then R1-R3.
    // L1 toggles the active module's plugin window; R1-R3 mute, solo, phase.
    switch (cc) {
        mft.SIDE_BUTTON_CCS[0] => { // L1
            if (MappableModule.fromActive(globals.mft.active_module)) |module| {
                if (mft_fx.moduleFxToShow(globals, track, module, globals.mft.last_fx_index)) |fx| {
                    mft_fx.toggleFxChain(track, fx);
                }
            }
        },
        mft.SIDE_BUTTON_CCS[3] => mft_fx.toggleMute(track), // R1
        mft.SIDE_BUTTON_CCS[4] => mft_fx.toggleSolo(track), // R2
        mft.SIDE_BUTTON_CCS[5] => mft_fx.togglePhase(track), // R3
        else => {},
    }
}
