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
const Globals = @import("globals.zig").Globals;
const onMidiEvent_FxCtrl = @import("csurf/midi_events_fxctrl.zig").onMidiEvent_FxCtrl;
const fx_sel_actions = @import("fx_sel_actions.zig");
const FxSelActions = fx_sel_actions.FxSelActions;
const Mode = statemachine.Mode;
const State = statemachine.State;
const ModulesList = statemachine.ModulesList;
const actions = @import("actions.zig");
const pReaper = @import("pReaper.zig");

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
    on_track_entry: MediaTrack,
    fx_win_disp: MediaTrack,
};

pub fn fxCtrlActions(globals: *Globals, fx_action: FxCtrlAction) void {
    switch (fx_action) {
        .midi_input => |input| {
            log.debug(
                "MIDI input: {s} -> {d} evt: {}",
                .{ @tagName(input.cc), input.value, logger.Event{ .midi_input = .{ .cc = input.cc, .value = input.value } } },
            );
            onMidiEvent_FxCtrl(input.cc, input.value, globals);
        },
        .panel_input => |input| {
            globals.state.fx_ctrl.values.getPtr(input.cc).?.param.normalized = input.value;
            actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = input.cc, .value = @intFromFloat(@min(input.value, 1.0) * 127) } } });
        },
        .on_track_entry => |media_track| onTrackEntry(globals, media_track),
        .fx_win_disp => |media_track| handleFxWindowDisplay(globals, media_track),
        else => {},
        // ... other fx_ctrl actions
    }
}

/// Handles FX window visibility when switching tracks
/// Closes FX window of previous track and opens FX window of new track if display mode is active
fn handleFxWindowDisplay(globals: *Globals, media_track: MediaTrack) void {
    const count = reaper.GetNumTracks() + 1;
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        const tr = reaper.CSurf_TrackFromID(i, false);
        pReaper.TrackFX_Show(.{ tr, -1, 0 }); // no valid index required for closing FX chain
    }
    if (globals.state.fx_ctrl.display) |_| {
        pReaper.TrackFX_Show(.{ media_track, 0, 1 });
    }
}

/// Main track selection handler for Console1
/// Validates track's FX chain, updates window display,
/// and synchronizes all controller feedback (LEDs, knobs) with track state
fn onTrackEntry(globals: *Globals, media_track: MediaTrack) void {
    log.debug("track entry", .{});
    const id = reaper.CSurf_TrackToID(media_track, constants.g_csurf_mcpmode);

    globals.state.fx_ctrl.validateTrack(null, media_track, null, globals.preferences.manual_routing, globals.preferences.default_fx, &globals.map_store) catch {
        log.err("track validation failed: track {d}", .{id});
    };

    handleFxWindowDisplay(globals, media_track);

    actions.dispatch(globals, .{ .midi_out = .{ .mode_entry = .fx_ctrl } });
}
