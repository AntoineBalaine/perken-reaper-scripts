const std = @import("std");
const c1 = @import("c1.zig");
const reaper = @import("reaper.zig").reaper;
const statemachine = @import("statemachine.zig");
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
                globals.state.selectedTracks.put(globals.arena, tr_id, {}) catch return;
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
                const module = std.meta.activeTag(globals.state.mapping_panel.mode.assign.current_mappings);
                if (globals.state.fx_ctrl.track_state.module_locations.get(module)) |mod_loc| {
                    if (mod_loc.fx_index == prm_chg.fx_index) {
                        actions.dispatch(globals, .{ .mapping_panel = .{ .assign_midi_learned_param = @intCast(prm_chg.param_index) } });
                    }
                }
            }

            if (globals.state.current_mode == .fx_ctrl or
                globals.state.current_mode == .mapping_panel or
                globals.state.current_mode == .fx_sel)
            {
                // Check if we have a current track and it matches the notification track
                const tr_id = reaper.CSurf_TrackToID(prm_chg.track, false);
                if (globals.state.current_tr_id != null and globals.state.current_tr_id.? == tr_id) {
                    // Find the module and parameter that corresponds to this FX and parameter index
                    var cc: ?c1.CCs = null;

                    blk: inline for (comptime std.enums.values(statemachine.ModulesList)) |field| {
                        if (globals.state.fx_ctrl.track_state.module_locations.get(field)) |mod_map| {
                            const idx = mod_map.fx_index;
                            if (idx == prm_chg.fx_index) {
                                if (mod_map.mapping) |mapping| {
                                    const map_variant = @field(mapping, @tagName(field));
                                    inline for (@typeInfo(@TypeOf(map_variant)).@"struct".fields) |param_field| {
                                        if (comptime std.mem.eql(u8, param_field.name, "version")) continue;

                                        const param_idx = @field(map_variant, param_field.name);
                                        if (param_idx != null and param_idx.? == prm_chg.param_index) {
                                            cc = @field(c1.CCs, param_field.name);
                                            break :blk;
                                        }
                                    }
                                }
                            }
                        }
                    }

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

                        // Send MIDI feedback to update the console's knob LEDs
                        actions.dispatch(globals, .{ .midi_out = .{ .set_param = .{ .cc = control_cc, .value = @intFromFloat(prm_chg.value * 127.0) } } });
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
        else => {},
    }
}
