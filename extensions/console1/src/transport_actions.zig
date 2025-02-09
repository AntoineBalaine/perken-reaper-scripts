const std = @import("std");
const c1 = @import("c1.zig");
const reaper = @import("reaper.zig").reaper;
const pReaper = @import("pReaper.zig");
const statemachine = @import("statemachine.zig");
const State = statemachine.State;
const log = std.log.scoped(.transport);
const constants = @import("constants.zig");
const csurf = @import("csurf/control_surface.zig");
const utils = @import("utils.zig");
const actions = @import("actions.zig");

const AutomationMode = enum {
    trim,
    read,
    latch,
    preview,
    write,
};

const TransportState = struct {
    jog: u8 = 64,
    jog_item: u8 = 64,
    jog_marker: u8 = 64,
    scrub: u8 = 64,
    zoom_horizontal: u8 = 64,
    zoom_vertical: u8 = 64,
};

pub const TransportAction = union(enum) {
    automation_mode: AutomationMode,
    jog: u8,
    jog_marker: u8,
    jog_item: u8,
    loop_end,
    loop_start,
    loop_toggle,
    marker_set,
    play,
    rate,
    rec,
    rec_arm,
    scrub: u8,
    stop,
    tr_sel,
    zoom_horizontal: u8,
    zoom_vertical: u8,
};

const RprCmds = enum(c_int) {
    IDC_REPEAT = 1068,
    ID_FILE_SAVEAS = 40022,
    ID_FILE_NEWPROJECT = 40023,
    ID_FILE_OPENPROJECT = 40025,
    ID_FILE_SAVEPROJECT = 40026,
    IDC_EDIT_UNDO = 40029,
    IDC_EDIT_REDO = 40030,
    ID_MARKER_PREV = 40172,
    ID_MARKER_NEXT = 40173,
    ID_INSERT_MARKERRGN = 40174,
    ID_INSERT_MARKER = 40157,
    ID_LOOP_SETSTART = 40222,
    ID_LOOP_SETEND = 40223,
    ID_METRONOME = 40364,
    ID_GOTO_MARKER1 = 40161,
    ID_SET_MARKER1 = 40657,
    ID_ITM_TRSNT_NEXT = 40375,
    ID_ITM_TRSNT_PREV = 40376,
};

pub fn transportAction(state: *State, action: TransportAction) void {
    switch (action) {
        .automation_mode => {},
        .jog => |new_pos| {
            var pos_rel: u8 = state.transport.jog;
            if (utils.calculateNewScrollPosition(c_int, &state.transport.jog, &pos_rel, new_pos, 128)) |delta| {
                state.transport.jog = pos_rel;
                pReaper.CSurf_OnRewFwd(.{ 128, delta });
                if (new_pos != state.transport.jog) {
                    actions.dispatch(state, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Eq_LoMidGain, .value = state.transport.jog } } });
                }
                log.debug("Transport jog: abs={d} delta={d}", .{ state.transport.jog, delta });
            }
        },
        .jog_marker => |new_pos| {
            var pos_rel: u8 = state.transport.jog_marker;
            if (utils.calculateNewScrollPosition(c_int, &state.transport.jog_marker, &pos_rel, new_pos, 128)) |delta| {
                state.transport.jog_marker = pos_rel;
                if (delta > 0) {
                    pReaper.Main_OnCommand(.{ @intFromEnum(RprCmds.ID_MARKER_NEXT), 0 });
                } else if (delta < 0) {
                    pReaper.Main_OnCommand(.{ @intFromEnum(RprCmds.ID_MARKER_PREV), 0 });
                }
                if (new_pos != state.transport.jog_marker) {
                    actions.dispatch(state, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Eq_HiMidGain, .value = state.transport.jog_marker } } });
                }
            }
        },

        .jog_item => |new_pos| {
            var pos_rel: u8 = state.transport.jog_item;
            if (utils.calculateNewScrollPosition(c_int, &state.transport.jog_item, &pos_rel, new_pos, 128)) |delta| {
                state.transport.jog_item = pos_rel;
                if (delta > 0) {
                    pReaper.Main_OnCommand(.{ @intFromEnum(RprCmds.ID_ITM_TRSNT_NEXT), 0 });
                } else if (delta < 0) {
                    pReaper.Main_OnCommand(.{ @intFromEnum(RprCmds.ID_ITM_TRSNT_PREV), 0 });
                }
                if (new_pos != state.transport.jog_item) {
                    actions.dispatch(state, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Eq_HiGain, .value = state.transport.jog_item } } });
                }
            }
        },

        .scrub => |new_pos| {
            var pos_rel: u8 = state.transport.scrub;
            if (utils.calculateNewScrollPosition(c_int, &state.transport.scrub, &pos_rel, new_pos, 128)) |delta| {
                state.transport.scrub = pos_rel;
                pReaper.CSurf_OnRewFwd(.{ 1, delta }); // smaller multiplier for finer control
                if (new_pos != state.transport.scrub) {
                    actions.dispatch(state, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Eq_LoGain, .value = state.transport.scrub } } });
                }
            }
        },

        .zoom_horizontal => |new_pos| {
            var pos_rel: u8 = state.transport.zoom_horizontal;
            if (utils.calculateNewScrollPosition(c_int, &state.transport.zoom_horizontal, &pos_rel, new_pos, 128)) |delta| {
                state.transport.zoom_horizontal = pos_rel;
                pReaper.CSurf_OnZoom(delta, 0); // horizontal zoom
                if (new_pos != state.transport.zoom_horizontal) {
                    actions.dispatch(state, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Inpt_LoCut, .value = state.transport.zoom_horizontal } } });
                }
            }
        },

        .zoom_vertical => |new_pos| {
            var pos_rel: u8 = state.transport.zoom_vertical;
            if (utils.calculateNewScrollPosition(c_int, &state.transport.zoom_vertical, &pos_rel, new_pos, 128)) |delta| {
                state.transport.zoom_vertical = pos_rel;
                pReaper.CSurf_OnZoom(0, delta); // vertical zoom
                if (new_pos != state.transport.zoom_vertical) {
                    actions.dispatch(state, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Inpt_HiCut, .value = state.transport.zoom_vertical } } });
                }
            }
        },
        .loop_end => {},
        .loop_start => {},
        .loop_toggle => {},
        .marker_set => {},
        .play => {},
        .rate => {},
        .rec => {},
        .rec_arm => {},
        .scrub => {},
        .stop => {},
        .tr_sel => {},
    }
}
