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
    fx_index: i32,
    param_index: i32,
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
                    .fx_ctrl => updateFxControlTrack(state, track),
                    else => {}, // Other modes might not need track updates
                }
            }
        },
        .fx_chain_changed => |track| actions.dispatch(&globals.state, .{ .fx_ctrl = .{ .update_console_for_track = track } }),
        .fx_param_changed => |param| {
            if (state.current_mode == .fx_ctrl) {
                updateControllerFeedback(state, param);
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

fn updateFxControlTrack(state: *State, track: reaper.MediaTrack) void {
    _ = track; // autofix
    _ = state; // autofix
    unreachable;
}
//
// Helper functions
fn validateFxChain(state: *State, track: reaper.MediaTrack) void {
    _ = track; // autofix
    _ = state; // autofix
    // Your existing FX chain validation logic
    unreachable;
}

fn updateControllerFeedback(state: *State, param: ParamChg) void {
    _ = param; // autofix
    _ = state; // autofix
    // Your existing controller feedback logic
    unreachable;
}
