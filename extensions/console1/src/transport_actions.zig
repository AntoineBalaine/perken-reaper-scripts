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

pub const TransportState = struct {
    jog: u8 = 64,
    jog_item: u8 = 64,
    jog_marker: u8 = 64,
    zoom_horizontal: u8 = 64,
    zoom_vertical: u8 = 64,
    rate: u8 = 64,
    tr_sel: u8 = 0,
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
    rate: u8,
    rec,
    rec_arm,
    scrub: u8,
    stop,
    tr_sel: u8,
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
    ID_TRK_UNSEL_ALL = 40297,
};

pub fn transportAction(state: *State, action: TransportAction) void {
    switch (action) {
        .automation_mode => {},
        .jog => |new_pos| {
            var pos_rel: u8 = state.transport.jog;
            if (utils.calculateNewScrollPosition(c_int, &state.transport.jog, &pos_rel, new_pos, 127)) |delta| {
                state.transport.jog = pos_rel;
                pReaper.CSurf_OnRewFwd(.{ 127, delta });
                if (new_pos != state.transport.jog) {
                    actions.dispatch(state, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Eq_LoMidGain, .value = state.transport.jog } } });
                }
                log.debug("Transport jog: abs={d} delta={d}", .{ state.transport.jog, delta });
            }
        },
        .jog_marker => |new_pos| {
            var pos_rel: u8 = state.transport.jog_marker;
            if (utils.calculateNewScrollPosition(c_int, &state.transport.jog_marker, &pos_rel, new_pos, 127)) |delta| {
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
            if (utils.calculateNewScrollPosition(c_int, &state.transport.jog_item, &pos_rel, new_pos, 127)) |delta| {
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

        .zoom_horizontal => |new_pos| {
            var pos_rel: u8 = state.transport.zoom_horizontal;
            if (utils.calculateNewScrollPosition(c_int, &state.transport.zoom_horizontal, &pos_rel, new_pos, 127)) |delta| {
                state.transport.zoom_horizontal = pos_rel;
                pReaper.CSurf_OnZoom(.{ delta, 0 }); // horizontal zoom
                if (new_pos != state.transport.zoom_horizontal) {
                    actions.dispatch(state, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Inpt_LoCut, .value = state.transport.zoom_horizontal } } });
                }
            }
        },

        .zoom_vertical => |new_pos| {
            var pos_rel: u8 = state.transport.zoom_vertical;
            if (utils.calculateNewScrollPosition(c_int, &state.transport.zoom_vertical, &pos_rel, new_pos, 127)) |delta| {
                state.transport.zoom_vertical = pos_rel;
                pReaper.CSurf_OnZoom(.{ 0, delta }); // vertical zoom
                if (new_pos != state.transport.zoom_vertical) {
                    actions.dispatch(state, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Inpt_HiCut, .value = state.transport.zoom_vertical } } });
                }
            }
        },
        .loop_end => pReaper.Main_OnCommand(.{ @intFromEnum(RprCmds.ID_LOOP_SETEND), 0 }),
        .loop_start => pReaper.Main_OnCommand(.{ @intFromEnum(RprCmds.ID_LOOP_SETSTART), 0 }),
        .loop_toggle => pReaper.Main_OnCommand(.{ @intFromEnum(RprCmds.IDC_REPEAT), 0 }),
        .marker_set => pReaper.Main_OnCommand(.{ @intFromEnum(RprCmds.ID_INSERT_MARKER), 0 }),
        .play => pReaper.CSurf_OnPlay(.{}),
        .rate => |new_pos| {
            var pos_rel: u8 = state.transport.rate;
            if (utils.calculateNewScrollPosition(i16, &state.transport.rate, &pos_rel, new_pos, 127)) |delta| {
                state.transport.rate = pos_rel;
                const norm_rate: f64 = reaper.Master_NormalizePlayRate(reaper.Master_GetPlayRate(0), false);

                const ROTARY_STEP: f64 = 1.0 / 1024.0;
                const new_norm = norm_rate + (ROTARY_STEP * 2.0 * @as(f64, @floatFromInt(delta)));

                const new_rate = reaper.Master_NormalizePlayRate(new_norm, true);
                pReaper.CSurf_OnPlayRateChange(.{new_rate});

                // Send MIDI feedback if wrapped
                if (new_pos != state.transport.rate) {
                    actions.dispatch(state, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Out_Drive, .value = state.transport.rate } } });
                }

                log.debug("Transport rate: abs={d} delta={d} rate={d}", .{ state.transport.rate, delta, new_rate });
            }
        },
        .rec => pReaper.CSurf_OnRecord(.{}),
        .rec_arm => {
            if (state.current_tr_id) |tr_id| {
                _ = pReaper.CSurf_OnRecArmChange(.{ reaper.CSurf_TrackFromID(tr_id, false), 0 });
            }
        },
        .stop => pReaper.CSurf_OnStop(.{}),
        .tr_sel => |new_pos| {
            const num_tracks = reaper.GetNumTracks();
            var pos_rel: u8 = if (state.current_tr_id) |id| @intCast(id) else 0;
            if (utils.calculateNewScrollPosition(c_int, &state.transport.tr_sel, &pos_rel, new_pos, num_tracks)) |_| {
                state.transport.tr_sel = pos_rel;

                const new_tr_id = pos_rel;

                pReaper.Main_OnCommand(.{ @intFromEnum(RprCmds.ID_TRK_UNSEL_ALL), 0 });
                const new_media_tr = reaper.CSurf_TrackFromID(new_tr_id, false);
                pReaper.CSurf_OnTrackSelection(.{new_media_tr});
                state.current_tr_id = new_tr_id;
                actions.dispatch(state, .{ .fx_ctrl = .{ .on_track_entry = new_media_tr } });

                if (new_pos != state.transport.tr_sel) {
                    actions.dispatch(state, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Inpt_Gain, .value = state.transport.tr_sel } } });
                }
            }
        },
        // .scrub => {},
        else => {},
    }
}
