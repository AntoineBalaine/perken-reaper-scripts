const std = @import("std");
const c1 = @import("c1.zig");
const reaper = @import("reaper.zig").reaper;
const statemachine = @import("statemachine.zig");
const PhysicalModule = statemachine.PhysicalModule;
const TrackState = @import("track_state.zig");
const Globals = @import("globals.zig").Globals;
const actions = @import("actions.zig");
const action_types = @import("action_types.zig");
pub const WinChg = action_types.WinChg;
pub const ParamChg = action_types.ParamChg;
pub const CsurfAction = action_types.CsurfAction;

pub fn csurfActions(globals: *Globals, set_action: CsurfAction) void {
    switch (set_action) {
        .track_selected => |selection| {
            // Update selected tracks map
            const tr_id = reaper.CSurf_TrackToID(selection.tr, false);
            if (selection.selected) {
                globals.state.selectedTracks.put(globals.arena_int.allocator(), tr_id, {}) catch return;
                // If no current track, use this one
                if (globals.state.current_tr_id == null) {
                    globals.state.current_tr_id = tr_id;
                    actions.dispatch(globals, .{ .fx_ctrl = .{ .on_track_entry = selection.tr } });
                }
            } else {
                _ = globals.state.selectedTracks.swapRemove(tr_id);
                // If this was our current track, fall back to another selected track
                if (globals.state.current_tr_id == tr_id) {
                    globals.state.current_tr_id = if (globals.state.selectedTracks.count() > 0) globals.state.selectedTracks.keys()[0] else null; // fallback
                    if (globals.state.current_tr_id) |id| {
                        actions.dispatch(globals, .{ .fx_ctrl = .{ .on_track_entry = reaper.CSurf_TrackFromID(id, false) } });
                    }
                }
            }
        },
        .last_touched_track => |track| {
            const tr_id = reaper.CSurf_TrackToID(track, false);
            // Update current_tr_id if:
            // - We have no current track, or
            // - We have multiple tracks selected and this is a different track
            if (globals.state.current_tr_id == null or
                (globals.state.selectedTracks.count() > 1 and globals.state.current_tr_id != tr_id))
            {
                globals.state.current_tr_id = tr_id;
                actions.dispatch(globals, .{ .fx_ctrl = .{ .on_track_entry = track } });
            }
        },
        .fx_chain_changed => |track| {
            actions.dispatch(globals, .{ .fx_ctrl = .{ .on_track_entry = track } });
        },
        .fx_param_changed => |prm_chg| {
            // Because MIDI learn needs to capture FX parameter changes from the VST UI,
            // we check for it before the normal parameter update logic.
            if (globals.state.current_mode == .mapping_panel and
                std.meta.activeTag(globals.state.mapping_panel.mode) == .assign and
                globals.state.mapping_panel.mode.assign.midi_learn_active)
            {
                const key: u32 = @bitCast(TrackState.ParamKey{
                    .fx_index = @intCast(prm_chg.fx_index),
                    .param_index = @intCast(prm_chg.param_index),
                });
                if (globals.state.fx_ctrl.track_state.reverse_map.get(key) != null) {
                    actions.dispatch(globals, .{ .mapping_panel = .{ .assign_midi_learned_param = @intCast(prm_chg.param_index) } });
                }
            }

            if (globals.state.current_mode == .fx_ctrl or
                globals.state.current_mode == .mapping_panel or
                globals.state.current_mode == .fx_sel)
            {
                // Check if we have a current track and it matches the notification track
                const tr_id = reaper.CSurf_TrackToID(prm_chg.track, false);
                if (globals.state.current_tr_id != null and globals.state.current_tr_id.? == tr_id) {
                    const key: u32 = @bitCast(TrackState.ParamKey{
                        .fx_index = @intCast(prm_chg.fx_index),
                        .param_index = @intCast(prm_chg.param_index),
                    });
                    const cc = globals.state.fx_ctrl.track_state.reverse_map.get(key);

                    // If we found a matching parameter, update the state and send MIDI feedback
                    if (cc) |control_cc| {
                        // Update the FX control state with the new parameter value
                        if (globals.state.fx_ctrl.values.getPtr(control_cc)) |value_ptr| {
                            // Check the active field of the union
                            switch (value_ptr.*) {
                                .param => |*param_value| param_value.normalized = prm_chg.value,
                                .button => |*button_val| button_val.* = prm_chg.value > 0.5,
                                else => {}, // Skip other types
                            }
                        }

                        // Update the formatted value in the label pool
                        var fmt_buf: [256:0]u8 = undefined;
                        if (reaper.TrackFX_GetFormattedParamValue(prm_chg.track, @intCast(prm_chg.fx_index), @intCast(prm_chg.param_index), &fmt_buf, fmt_buf.len)) {
                            globals.state.fx_ctrl.track_state.label_pool.setFmtValue(control_cc, std.mem.span(@as([*:0]const u8, &fmt_buf)));
                        }

                        // Send MIDI feedback to update the console's knob LEDs
                        actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = control_cc, .value = @intFromFloat(prm_chg.value * 127.0) } } });

                        // When filter_to_comp is active, comp filter updates also
                        // need to reach the physical Inpt_HiCut/LoCut LEDs.
                        if (globals.state.fx_ctrl.filter_to_comp) {
                            const physical_cc: ?c1.CCs = if (control_cc == .Comp_HiCut) .Inpt_HiCut else if (control_cc == .Comp_LoCut) .Inpt_LoCut else null;
                            if (physical_cc) |pcc| {
                                actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = pcc, .value = @intFromFloat(prm_chg.value * 127.0) } } });
                            }
                        }
                    }
                }
            }
        },
        .play_state_changed => |transport| {
            // Update metering state
            if (transport.playing and !transport.paused) {
                // Start meters update timer
            } else {
                // Stop meters update timer
            }
        },
        .project_reset => {
            // REAPER fires CSURF_EXT_RESET on project tab switches. All MediaTrack
            // pointers from the previous project are now invalid, so we must clear
            // all track-related state before REAPER sends new track notifications.
            globals.state.current_tr_id = null;
            globals.state.selectedTracks.clearRetainingCapacity();
            globals.state.fx_ctrl.track_state.reverse_map.clearRetainingCapacity();
            globals.state.fx_ctrl.track_state.forward_map.clearRetainingCapacity();
            globals.state.fx_ctrl.track_state.mode = .{ .multi_fx = TrackState.ModuleLocations.initFill(null) };
            globals.state.fx_ctrl.display = null;
            globals.state.fx_ctrl.vol_lastpos = 0;

            // Clear MIDI LEDs and refresh the track list for the new project
            actions.dispatch(globals, .{ .midi_out = .clear_all });
            actions.dispatch(globals, .{ .track_list = .refresh });
        },
        else => {},
    }
}
