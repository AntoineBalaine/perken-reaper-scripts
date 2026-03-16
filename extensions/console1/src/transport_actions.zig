const std = @import("std");
const c1 = @import("c1.zig");
const reaper = @import("reaper.zig").reaper;
const pReaper = @import("pReaper.zig");
const log = std.log.scoped(.transport);
const utils = @import("utils.zig");
const actions = @import("actions.zig");
const track_list_actions = @import("tracklist_actions.zig");
const RprCmds = @import("reaper_cmds.zig");
const Globals = @import("globals.zig").Globals;

pub const AutomationMode = @import("action_types.zig").AutomationMode;
pub const TransportAction = @import("action_types.zig").TransportAction;
pub const TransportState = @import("action_types.zig").TransportState;

pub fn transportAction(globals: *Globals, action: TransportAction) void {
    switch (action) {
        .automation_mode => |mode| reaper.SetAutomationMode(@intFromEnum(mode), false),
        .grid => |new_pos| {
            var pos_rel: u8 = globals.state.transport.grid;
            if (utils.calculateClampedDelta(c_int, &globals.state.transport.grid, &pos_rel, new_pos, 127, null)) |delta| {
                globals.state.transport.grid = pos_rel;

                if (delta > 0) {
                    pReaper.Main_OnCommand(.{ RprCmds.ID_GRID_BY2, 0 });
                } else if (delta < 0) {
                    pReaper.Main_OnCommand(.{ RprCmds.ID_GRID_BY1_5, 0 });
                }

                actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Out_Pan, .value = globals.state.transport.grid } } });
                log.debug("Transport grid: abs={d} delta={d}", .{ globals.state.transport.grid, delta });
            }
        },
        .snap_tgl => {
            const snap: c_int = if (reaper.GetToggleCommandState(RprCmds.OPT_TGL_SNAP) == 1) 0 else 1;
            pReaper.Main_OnCommand(.{ RprCmds.OPT_TGL_SNAP, snap });
        },
        .jog => |new_pos| {
            var pos_rel: u8 = globals.state.transport.jog;
            if (utils.calculateNewScrollPosition(c_int, &globals.state.transport.jog, &pos_rel, new_pos, 127, null)) |delta| {
                globals.state.transport.jog = pos_rel;

                const use_grid = reaper.GetToggleCommandState(RprCmds.OPT_TGL_GRID) == 1 and reaper.GetToggleCommandState(RprCmds.OPT_TGL_SNAP) == 1;
                if (!use_grid) {
                    // Regular jogging behavior
                    pReaper.CSurf_OnRewFwd(.{ 127, delta });
                } else {
                    // adapted from amalgama
                    reaper.PreventUIRefresh(1);
                    defer reaper.PreventUIRefresh(-1);
                    const cursor_pos = reaper.GetCursorPosition();
                    var grid_pos: f64 = undefined;

                    // Move to next/previous grid line based on delta
                    // Save snap state
                    pReaper.Main_OnCommand(.{ RprCmds.OPT_SAVE_SNAP, 0 });
                    pReaper.Main_OnCommand(.{ RprCmds.OPT_TGL_SNAP, 0 });
                    var dropFrameOut: bool = false;
                    const grid_duration = if (reaper.GetToggleCommandState(41885) == 1)
                        0.4 / reaper.TimeMap_curFrameRate(0, &dropFrameOut)
                    else blk: {
                        var division: f64 = undefined;
                        _ = reaper.GetSetProjectGrid(0, false, &division, null, null);
                        const tmsgn_cnt = reaper.CountTempoTimeSigMarkers(0);
                        var tempo: f64 = undefined;
                        if (tmsgn_cnt == 0) {
                            tempo = reaper.Master_GetTempo();
                        } else {
                            const ptidx = reaper.FindTempoTimeSigMarker(0, cursor_pos);
                            var timeposOut: f64 = undefined;
                            var measureposOut: c_int = undefined;
                            var beatposOut: f64 = undefined;
                            var timesig_numOut: c_int = undefined;
                            var timesig_denomOut: c_int = undefined;
                            var lineartempoOut: bool = undefined;
                            _ = reaper.GetTempoTimeSigMarker(
                                0,
                                ptidx,
                                &timeposOut,
                                &measureposOut,
                                &beatposOut,
                                &tempo,
                                &timesig_numOut,
                                &timesig_denomOut,
                                &lineartempoOut,
                            );
                        }
                        break :blk 60.0 / tempo * division;
                    };

                    const snapped = reaper.SnapToGrid(0, cursor_pos);
                    if (delta > 0) {
                        grid_pos = if (snapped > cursor_pos)
                            snapped
                        else blk: {
                            var next_pos = cursor_pos;
                            while (reaper.SnapToGrid(0, next_pos) <= cursor_pos) {
                                next_pos += grid_duration;
                            }
                            break :blk reaper.SnapToGrid(0, next_pos);
                        };
                    } else if (cursor_pos > 0) {
                        grid_pos = if (snapped < cursor_pos)
                            snapped
                        else blk: {
                            var pos = cursor_pos;
                            while (pos >= cursor_pos) {
                                pos -= grid_duration;
                                if (pos >= grid_duration) {
                                    const grid = reaper.SnapToGrid(0, pos);
                                    if (grid < cursor_pos) break :blk grid;
                                } else {
                                    break :blk 0;
                                }
                            }
                            break :blk 0;
                        };
                    }
                    // Set cursor position
                    reaper.SetEditCurPos(grid_pos, true, true);
                    pReaper.Main_OnCommand(.{ RprCmds.OPT_RSTR_SNAP, 0 });
                }
                if (new_pos != globals.state.transport.jog) {
                    actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Eq_LoMidGain, .value = globals.state.transport.jog } } });
                }
                log.debug("Transport jog: abs={d} delta={d}", .{ globals.state.transport.jog, delta });
            }
        },
        .jog_marker => |new_pos| {
            var pos_rel: u8 = globals.state.transport.jog_marker;
            if (utils.calculateNewScrollPosition(c_int, &globals.state.transport.jog_marker, &pos_rel, new_pos, 127, null)) |delta| {
                globals.state.transport.jog_marker = pos_rel;
                if (delta > 0) {
                    pReaper.Main_OnCommand(.{ RprCmds.ID_MARKER_NEXT, 0 });
                } else if (delta < 0) {
                    pReaper.Main_OnCommand(.{ RprCmds.ID_MARKER_PREV, 0 });
                }
                if (new_pos != globals.state.transport.jog_marker) {
                    actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Eq_HiMidGain, .value = globals.state.transport.jog_marker } } });
                }
            }
        },

        .jog_item => |new_pos| {
            var pos_rel: u8 = globals.state.transport.jog_item;
            if (utils.calculateNewScrollPosition(c_int, &globals.state.transport.jog_item, &pos_rel, new_pos, 127, null)) |delta| {
                globals.state.transport.jog_item = pos_rel;
                pReaper.Main_OnCommand(.{ reaper.NamedCommandLookup(RprCmds._SWS_SAVEALLSELITEMS1), 0 });
                defer pReaper.Main_OnCommand(.{ reaper.NamedCommandLookup(RprCmds._SWS_RESTALLSELITEMS1), 0 });
                pReaper.Main_OnCommand(.{ RprCmds.SEL_TR_ITMS, 0 });
                if (delta > 0) {
                    pReaper.Main_OnCommand(.{ RprCmds.ID_ITM_TRSNT_NEXT, 0 });
                } else if (delta < 0) {
                    pReaper.Main_OnCommand(.{ RprCmds.ID_ITM_TRSNT_PREV, 0 });
                }
                if (new_pos != globals.state.transport.jog_item) {
                    actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Eq_HiGain, .value = globals.state.transport.jog_item } } });
                }
            }
        },

        .zoom_horizontal => |new_pos| {
            var pos_rel: u8 = globals.state.transport.zoom_horizontal;
            if (utils.calculateClampedDelta(c_int, &globals.state.transport.zoom_horizontal, &pos_rel, new_pos, 127, null)) |delta| {
                globals.state.transport.zoom_horizontal = pos_rel;
                pReaper.CSurf_OnZoom(.{ delta, 0 });
                actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Out_Drive, .value = globals.state.transport.zoom_horizontal } } });
            }
        },

        .zoom_vertical => |new_pos| {
            var pos_rel: u8 = globals.state.transport.zoom_vertical;
            if (utils.calculateClampedDelta(c_int, &globals.state.transport.zoom_vertical, &pos_rel, new_pos, 127, null)) |delta| {
                globals.state.transport.zoom_vertical = pos_rel;
                pReaper.CSurf_OnZoom(.{ 0, delta });
                actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Out_DriveChar, .value = globals.state.transport.zoom_vertical } } });
            }
        },
        .loop_end => pReaper.Main_OnCommand(.{ RprCmds.ID_LOOP_SETEND, 0 }),
        .loop_start => pReaper.Main_OnCommand(.{ RprCmds.ID_LOOP_SETSTART, 0 }),
        .loop_toggle => pReaper.Main_OnCommand(.{ RprCmds.IDC_REPEAT, 0 }),
        .marker_set => pReaper.Main_OnCommand(.{ RprCmds.ID_INSERT_MARKER, 0 }),
        .play => pReaper.CSurf_OnPlay(.{}),
        .rate => |new_pos| {
            globals.state.transport.rate = new_pos;
            const normalized = utils.ccToNormalizedRate(new_pos);
            const new_rate = reaper.Master_NormalizePlayRate(normalized, true);
            pReaper.CSurf_OnPlayRateChange(.{new_rate});
            actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Inpt_HiCut, .value = new_pos } } });
            log.debug("Transport rate: cc={d} norm={d} rate={d}", .{ new_pos, normalized, new_rate });
        },
        .rec => pReaper.CSurf_OnRecord(.{}),
        .rec_arm => {
            if (globals.state.current_tr_id) |tr_id| {
                _ = pReaper.CSurf_OnRecArmChange(.{ reaper.CSurf_TrackFromID(tr_id, false), 0 });
            }
        },
        .stop => pReaper.CSurf_OnStop(.{}),
        .tr_sel => |new_pos| {
            log.debug("trsprt tr_sel: old={d} new={d}", .{ globals.state.transport.tr_sel, new_pos });
            const num_tracks = reaper.GetNumTracks() + 1;
            var pos_rel: u8 = if (globals.state.current_tr_id) |id| @intCast(id) else 0;
            if (utils.calculateNewScrollPosition(c_int, &globals.state.transport.tr_sel, &pos_rel, new_pos, num_tracks, 1)) |_| {
                globals.state.transport.tr_sel = pos_rel;

                const new_tr_id = pos_rel;

                _ = track_list_actions.setReaperTrackSelection(globals, new_tr_id);
                globals.state.current_tr_id = new_tr_id;

                if (new_pos != globals.state.transport.tr_sel) {
                    actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = c1.CCs.Out_Vol, .value = globals.state.transport.tr_sel } } });
                }
            }
        },
        // .scrub => {},
        else => {},
    }
}
