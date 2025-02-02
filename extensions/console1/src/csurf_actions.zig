const std = @import("std");
const c1 = @import("c1.zig");
const reaper = @import("reaper.zig").reaper;
const statemachine = @import("statemachine.zig");
const Mode = statemachine.Mode;
const State = statemachine.State;
const globals = @import("globals.zig");
const actions = @import("actions.zig");
pub const WinChg = struct {
    track: reaper.MediaTrack,
    fx_index: i32,
    is_open: bool,
};

pub const ParamChg = struct {
    track: reaper.MediaTrack,
    fx_index: usize,
    param_index: usize,
    value: f64,
};

pub const CsurfAction = union(enum) {
    track_selected: struct { tr: reaper.MediaTrack, selected: bool },
    last_touched_track: reaper.MediaTrack,
    play_state_changed: struct {
        playing: bool,
        paused: bool,
    },
    fx_chain_changed: reaper.MediaTrack,
    fx_param_changed: ParamChg,
    fx_window_state: WinChg,
};

pub fn csurfActions(state: *State, set_action: CsurfAction) void {
    switch (set_action) {
        .track_selected => |selection| {
            // Update selected tracks map
            const tr_id = reaper.CSurf_TrackToID(selection.tr, false);
            if (selection.selected) {
                state.selectedTracks.put(globals.arena, tr_id, {}) catch return;
                // If no current track, use this one
                if (state.current_tr_id == null) {
                    state.current_tr_id = tr_id;
                    actions.dispatch(&globals.state, .{ .fx_ctrl = .{ .on_track_entry = selection.tr } });
                }
            } else {
                _ = state.selectedTracks.orderedRemove(tr_id);
                // If this was our current track, fall back to another selected track
                if (state.current_tr_id == tr_id) {
                    state.current_tr_id = if (state.selectedTracks.count() > 0) state.selectedTracks.keys()[0] else null; // fallback
                    if (state.current_tr_id) |id| {
                        actions.dispatch(&globals.state, .{ .fx_ctrl = .{ .on_track_entry = reaper.CSurf_TrackFromID(id, false) } });
                    }
                }
            }
        },
        .last_touched_track => |track| {
            const tr_id = reaper.CSurf_TrackToID(track, false);
            // Update current_tr_id if:
            // - We have no current track, or
            // - We have multiple tracks selected and this is a different track
            if (state.current_tr_id == null or
                (state.selectedTracks.count() > 1 and state.current_tr_id != tr_id))
            {
                state.current_tr_id = tr_id;
                actions.dispatch(&globals.state, .{ .fx_ctrl = .{ .on_track_entry = track } });
            }
        },
        .fx_chain_changed => |track| actions.dispatch(&globals.state, .{ .fx_ctrl = .{ .on_track_entry = track } }),
        .fx_param_changed => |prm_chg| {
            if (state.current_mode == .fx_ctrl) {
                const container_idx = reaper.TrackFX_GetByName(prm_chg.track, "C1_CHANNEL", false);
                if (container_idx >= 0) {
                    const container_fx_idx = @as(usize, @intCast(container_idx));
                    if (prm_chg.fx_index >= container_fx_idx and prm_chg.fx_index < container_fx_idx + 5) {
                        var cc: c1.CCs = undefined;

                        blk: inline for (comptime std.enums.values(statemachine.ModulesList)) |field| {
                            if (state.fx_ctrl.track_state.module_locations.get(field)) |mod_map| {
                                const idx = mod_map.fx_index;
                                if (idx == prm_chg.fx_index) {
                                    if (mod_map.mapping) |mapping| {
                                        const map_variant = @field(mapping, @tagName(field));
                                        inline for (@typeInfo(@TypeOf(map_variant)).Struct.fields) |param_field| {
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
                        actions.dispatch(&globals.state, .{ .midi_out = .{ .set_param = .{ .cc = cc, .value = @intFromFloat(prm_chg.value * 127.0) } } });
                        // actions.dispatch(state, .{ .midi_out = .{ .set_param = .{
                        //     .cc = @field(state.fx_ctrl.fxMap, @tagName(module))[1].param_index,
                        //     .value = midi_value,
                        // } } });
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
