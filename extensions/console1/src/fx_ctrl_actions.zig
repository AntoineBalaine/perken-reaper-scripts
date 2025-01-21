const std = @import("std");
const c1 = @import("c1.zig");
const constants = @import("constants.zig");
const utils = @import("utils.zig");
const reaper = @import("reaper.zig").reaper;
const MediaTrack = reaper.MediaTrack;
const fx_ctrl_state = @import("fx_ctrl_state.zig");
const CONTROLLER_NAME = fx_ctrl_state.CONTROLLER_NAME;
const ModulesOrder = fx_ctrl_state.ModulesOrder;
const SCRouting = fx_ctrl_state.SCRouting;
const statemachine = @import("statemachine.zig");
const logger = @import("logger.zig");
const globals = @import("globals.zig");
const onMidiEvent_FxCtrl = @import("csurf/midi_events_fxctrl.zig").onMidiEvent_FxCtrl;
const fx_sel_actions = @import("fx_sel_actions.zig");
const FxSelActions = fx_sel_actions.FxSelActions;
const Mode = statemachine.Mode;
const State = statemachine.State;
const ModulesList = statemachine.ModulesList;

const c = @cImport({
    @cDefine("SWELL_PROVIDED_BY_APP", "");
    @cInclude("csurf/control_surface_wrapper.h");
    @cInclude("WDL/swell/swell-types.h");
    @cInclude("WDL/swell/swell-functions.h");
    @cInclude("WDL/win32_utf8.h");
    @cInclude("WDL/wdltypes.h");
    @cInclude("resource.h");
    @cInclude("csurf/midi_wrapper.h");
});
const log = std.log.scoped(.midi_input);

pub const MidiInput = struct {
    cc: c1.CCs,
    value: u8,
};
pub const WidgetInput = struct {
    cc: c1.CCs,
    value: f64,
};

pub const FxCtrlAction = union(enum) {
    midi_input: MidiInput,
    panel_input: WidgetInput,
    set_volume: f64,
    set_pan: f64,
    toggle_mute,
    toggle_solo,
    set_routing_order: ModulesOrder,
    set_sidechain: SCRouting,
    update_console_for_track: MediaTrack,
};

pub fn fxCtrlActions(state: *State, fx_action: FxCtrlAction) void {
    switch (fx_action) {
        .midi_input => |input| {
            log.debug(
                "MIDI input: {s} -> {d} evt: {}",
                .{ @tagName(input.cc), input.value, logger.Event{ .midi_input = .{ .cc = input.cc, .value = input.value } } },
            );
            onMidiEvent_FxCtrl(input.cc, input.value);
        },
        .panel_input => |input| {
            state.fx_ctrl.values.getPtr(input.cc).?.param.normalized = input.value;

            const right_midi: u8 = @intFromFloat(@min(input.value, 1.0) * 127);
            c.MidiOut_Send(globals.m_midi_out, 0xb0, @intFromEnum(input.cc), right_midi, -1);
        },
        .update_console_for_track => |media_track| updateConsoleForTrack(media_track),

        else => {},
        // ... other fx_ctrl actions
    }
}

/// Handles FX window visibility when switching tracks
/// Closes FX window of previous track and opens FX window of new track if display mode is active
fn handleFxWindowDisplay(media_track: MediaTrack) void {
    if (globals.state.fx_ctrl.display) |_| {
        const prevTr = reaper.CSurf_TrackFromID(globals.state.last_touched_tr_id, constants.g_csurf_mcpmode);
        const currentFX = reaper.TrackFX_GetChainVisible(prevTr);
        reaper.TrackFX_Show(prevTr, currentFX, if (currentFX == -2 or currentFX >= 0) 0 else 1);
        const cntnrIdx = reaper.TrackFX_GetByName(media_track, CONTROLLER_NAME, false) + 1;
        reaper.TrackFX_Show(media_track, cntnrIdx, 1);
    }
}

/// Updates track selection button LEDs on the Console1
/// Turns off LED for previously selected track and turns on LED for newly selected track
fn updateTrackButtons(midiout: reaper.midi_Output, id: c_int) void {
    const c1_tr_id: u8 = @as(u8, @intCast(@rem(globals.state.last_touched_tr_id, 20) + 0x15 - 1));
    c.MidiOut_Send(midiout, 0xb0, c1_tr_id, 0x0, -1);
    const new_cc = @rem(id, 20) + 0x15 - 1;
    c.MidiOut_Send(midiout, 0xb0, @as(u8, @intCast(new_cc)), 0x7f, -1);
}

/// Updates Console1's track control knobs (volume, pan, mute, solo)
/// Reads values from DAW and sends corresponding MIDI messages to controller
fn updateTrackControls(midiout: reaper.midi_Output, media_track: MediaTrack, cc: c1.CCs) void {
    if (cc == c1.CCs.Out_Vol) {
        const volume = reaper.GetMediaTrackInfo_Value(media_track, "D_VOL");
        const volint = utils.volToU8(volume);
        c.MidiOut_Send(midiout, 0xb0, @intFromEnum(cc), volint, -1);
    } else if (cc == c1.CCs.Out_Pan) {
        const pan = reaper.GetMediaTrackInfo_Value(media_track, "D_PAN");
        const val: u8 = @intFromFloat((pan + 1) / 2 * 127);
        c.MidiOut_Send(midiout, 0xb0, @intFromEnum(cc), val, -1);
    } else if (cc == c1.CCs.Out_mute) {
        const mute = reaper.GetMediaTrackInfo_Value(media_track, "B_MUTE");
        c.MidiOut_Send(midiout, 0xb0, @intFromEnum(cc), if (mute == 1) 0x7f else 0x0, -1);
    } else if (cc == c1.CCs.Out_solo) {
        const solo = reaper.GetMediaTrackInfo_Value(media_track, "I_SOLO");
        c.MidiOut_Send(midiout, 0xb0, @intFromEnum(cc), if (solo == 1) 0x7f else 0x0, -1);
    }
}

/// Updates Console1's module parameters based on FX mapping
/// Determines module type from CC name, finds corresponding FX mapping,
/// reads parameter value and sends MIDI feedback to controller
fn updateModuleParams(midiout: reaper.midi_Output, media_track: MediaTrack, comptime cc: c1.CCs) void {
    comptime var variant: ModulesList = undefined;
    if (comptime std.mem.eql(u8, @tagName(cc)[0..4], "Comp")) {
        if (comptime std.mem.eql(u8, @tagName(cc)[4..8], "_Mtr")) return;
        variant = .COMP;
    } else if (comptime std.mem.eql(u8, @tagName(cc)[0..3], "Shp")) {
        if (comptime std.mem.eql(u8, @tagName(cc)[3..7], "_Mtr")) return;
        variant = .GATE;
    } else if (comptime std.mem.eql(u8, @tagName(cc)[0..2], "Eq")) {
        variant = .EQ;
    } else if (comptime std.mem.eql(u8, @tagName(cc)[0..4], "Inpt")) {
        if (comptime std.mem.eql(u8, @tagName(cc)[4..8], "_Mtr")) return;
        variant = .INPUT;
    } else if (comptime std.mem.eql(u8, @tagName(cc)[0..5], "Outpt")) {
        if (comptime std.mem.eql(u8, @tagName(cc)[5..9], "_Mtr")) return;
        variant = .OUTPT;
    } else {
        return;
    }

    const fxMap = @field(globals.state.fx_ctrl.fxMap, @tagName(variant));
    if (fxMap) |fx| {
        const fxIdx = fx[0];
        const mapping = fx[1];
        if (mapping) |map| {
            const fxPrm = @field(map, @tagName(cc));
            const val = reaper.TrackFX_GetParamNormalized(
                media_track,
                globals.state.fx_ctrl.getSubContainerIdx(fxIdx + 1, reaper.TrackFX_GetByName(media_track, CONTROLLER_NAME, false) + 1, media_track),
                fxPrm,
            );
            const conv: u8 = @intFromFloat(val * 127);
            c.MidiOut_Send(midiout, 0xb0, @intFromEnum(cc), conv, -1);
        }
    }
}

/// Main track selection handler for Console1
/// Validates track's FX chain, updates window display,
/// and synchronizes all controller feedback (LEDs, knobs) with track state
pub fn updateConsoleForTrack(media_track: MediaTrack) void {
    log.debug("update console", .{});
    const id = reaper.CSurf_TrackToID(media_track, constants.g_csurf_mcpmode);

    if (globals.state.last_touched_tr_id == id) {
        return;
    }

    globals.state.fx_ctrl.validateTrack(null, media_track, null) catch {
        log.err("track validation failed: track {d}", .{id});
    };

    handleFxWindowDisplay(media_track);

    if (globals.m_midi_out) |midiout| {
        updateTrackButtons(midiout, id);
        globals.state.last_touched_tr_id = id;

        c.MidiOut_Send(midiout, 0xb0, @intFromEnum(c1.CCs.Tr_order), @intFromEnum(globals.state.fx_ctrl.order), -1);

        inline for (comptime std.enums.values(c1.CCs)) |cc| {
            updateTrackControls(midiout, media_track, cc);
            updateModuleParams(midiout, media_track, cc);
        }
    }
}
