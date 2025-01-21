const std = @import("std");
const c1 = @import("c1.zig");
const constants = @import("constants.zig");
const utils = @import("utils.zig");
const reaper = @import("reaper.zig").reaper;
const MediaTrack = reaper.MediaTrack;
const fx_ctrl_state = @import("fx_ctrl_state.zig");
const CONTROLLER_NAME = constants.CONTROLLER_NAME;
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
const actions = @import("actions.zig");

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
            actions.dispatch(&globals.state, .{ .midi_out = .{ .set_param = .{ .cc = input.cc, .value = @intFromFloat(@min(input.value, 1.0) * 127) } } });
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

/// Main track selection handler for Console1
/// Validates track's FX chain, updates window display,
/// and synchronizes all controller feedback (LEDs, knobs) with track state
pub fn updateConsoleForTrack(media_track: MediaTrack) void {
    log.debug("update console", .{});
    const id = reaper.CSurf_TrackToID(media_track, constants.g_csurf_mcpmode);

    if (globals.state.last_touched_tr_id == id) {
        return;
    } else {
        globals.state.last_touched_tr_id = id;
    }

    globals.state.fx_ctrl.validateTrack(null, media_track, null) catch {
        log.err("track validation failed: track {d}", .{id});
    };

    handleFxWindowDisplay(media_track);

    actions.dispatch(&globals.state, .{ .midi_out = .{ .mode_entry = .fx_ctrl } });
}
