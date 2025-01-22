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
    track_list_changed,
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
            const id = reaper.CSurf_TrackToID(selection.tr, false);
            if (selection.selected) {
                state.selectedTracks.put(globals.allocator, id, {}) catch return;
            } else {
                _ = state.selectedTracks.orderedRemove(id);
            }
        },
        .last_touched_track => |track| {
            const id = reaper.CSurf_TrackToID(track, false);
            if (state.last_touched_tr_id != id) {
                state.last_touched_tr_id = id;

                // Update mode-specific state based on new track
                switch (state.current_mode) {
                    .fx_ctrl => actions.dispatch(&globals.state, .{ .fx_ctrl = .{ .update_console_for_track = track } }),
                    else => {}, // Other modes might not need track updates
                }
            }
        },
        .fx_chain_changed => |track| actions.dispatch(&globals.state, .{ .fx_ctrl = .{ .update_console_for_track = track } }),
        .fx_param_changed => |prm_chg| {
            if (state.current_mode == .fx_ctrl) {
                const container_idx = reaper.TrackFX_GetByName(prm_chg.track, "C1_CHANNEL", false);
                if (container_idx >= 0) {
                    const container_fx_idx = @as(usize, @intCast(container_idx));
                    if (prm_chg.fx_index >= container_fx_idx and prm_chg.fx_index < container_fx_idx + 5) {
                        var cc: c1.CCs = undefined;

                        blk: inline for (@typeInfo(@TypeOf(state.fx_ctrl.fxMap)).Struct.fields) |field| {
                            if (@field(state.fx_ctrl.fxMap, field.name)) |mod_map| {
                                const idx = mod_map[0];
                                if (idx == prm_chg.fx_index) {
                                    if (mod_map[1]) |mapping| {
                                        inline for (@typeInfo(@TypeOf(mapping)).Struct.fields) |param_field| {
                                            const param_idx = @field(mapping, param_field.name);
                                            if (param_idx == prm_chg.param_index) {
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
        .track_list_changed => {
            actions.dispatch(&globals.state, .{ .track_list = .refresh });
        },
        else => {},
    }
}
