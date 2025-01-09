const std = @import("std");
const c1 = @import("internals/c1.zig");
const Conf = @import("internals/config.zig");
const reaper = @import("reaper.zig").reaper;
const track_mod = @import("internals/track.zig");
const ModulesOrder = track_mod.ModulesOrder;
const SCRouting = track_mod.SCRouting;
const statemachine = @import("statemachine.zig");
const logger = @import("logger.zig");
const Mode = statemachine.Mode;
const State = statemachine.State;
const allocator: std.mem.Allocator = undefined;
const valid_transitions = statemachine.valid_transitions;
// Base actions that can occur in any mode
const SystemAction = union(enum) {
    // Track-related
    track_selected: reaper.MediaTrack,
    last_touched_track: reaper.MediaTrack,
    track_list_changed,

    // Transport
    play_state_changed: struct {
        playing: bool,
        paused: bool,
    },

    // FX-related
    fx_chain_changed: reaper.MediaTrack,
    fx_param_changed: ParamChg,
    fx_window_state: WinChg,
};
pub const ParamChg = struct {
    track: reaper.MediaTrack,
    fx_index: i32,
    param_index: i32,
    value: f64,
};
pub const WinChg = struct {
    track: reaper.MediaTrack,
    fx_index: i32,
    is_open: bool,
};
// Mode-specific actions
const ModeAction = union(enum) {
    // FX Control Mode
    fx_ctrl: union(enum) {
        set_param: struct {
            cc: c1.CCs,
            value: u7,
        },
        set_volume: f64,
        set_pan: f64,
        toggle_mute,
        toggle_solo,
        set_routing_order: ModulesOrder,
        set_sidechain: SCRouting,
    },

    // FX Selection Mode
    fx_sel: union(enum) {
        select_category: Conf.ModulesList,
        select_fx: []const u8,
        scroll: i32,
    },

    // Mapping Mode
    mapping: union(enum) {
        start_midi_learn,
        assign_param: struct {
            cc: c1.CCs,
            param: u32,
        },
        clear_mapping: c1.CCs,
        save_mappings,
        cancel_mapping,
    },

    // Settings Mode
    settings: union(enum) {
        set_show_plugin_ui: bool,
        set_manual_routing: bool,
        set_default_fx: struct {
            module: Conf.ModulesList,
            fx_name: []const u8,
        },
    },

    // Mode transitions
    change_mode: Mode,
};

// Combined action type for state updates
pub const Action = union(enum) {
    system: SystemAction,
    mode: ModeAction,
};

// Top-level update function
pub fn handleAction(state: *State, action: Action) void {
    logger.log(.debug, "Handling action: {s}", .{@tagName(action)}, null, allocator);

    switch (action) {
        .system => |sys_action| handleSystemAction(state, sys_action),
        .mode => |mode_action| handleModeAction(state, mode_action),
    }
}

fn handleSystemAction(state: *State, action: SystemAction) void {
    logger.log(.debug, "sys action: {s}", .{@tagName(action)}, null, allocator);
    switch (action) {
        .track_selected => |track| {
            // Update selected tracks map
            const id = reaper.CSurf_TrackToID(track, false);
            state.selectedTracks.put(allocator, id, {}) catch return;
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
        .fx_chain_changed => |track| {
            // Revalidate FX chain for current track
            validateFxChain(state, track);
        },
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
        else => {},
    }
}

fn handleModeAction(state: *State, action: ModeAction) void {
    switch (action) {
        .change_mode => |new_mode| {
            // Validate mode transition
            if (validateTransition(state.current_mode, new_mode)) {
                const old_mode = state.current_mode;
                state.current_mode = new_mode;
                logger.log(
                    .info,
                    "Mode changed: {s} -> {s}",
                    .{ @tagName(old_mode), @tagName(new_mode) },
                    null,
                    allocator,
                );
            }
        },
        .fx_ctrl => |fx_action| switch (fx_action) {
            .set_param => |param| {
                if (state.current_mode != .fx_ctrl) return;

                // Update parameter value and send to DAW
                updateFxParameter(state, param.cc, param.value);
            },
            .set_volume => |vol| {
                if (state.last_touched_tr_id) |id| {
                    const track = reaper.CSurf_TrackFromID(id, false);
                    _ = reaper.CSurf_OnVolumeChange(track, vol, false);
                }
            },
            else => {},
            // ... other fx_ctrl actions
        },
        .fx_sel => |sel_action| switch (sel_action) {
            .select_category => |category| {
                if (state.current_mode != .fx_sel) return;
                state.fx_sel.current_category = category;
                // Update GUI list
            },
            else => {},
            // ... other fx_sel actions
        },
        .mapping => |map_action| switch (map_action) {
            .start_midi_learn => {
                if (state.current_mode != .mapping_panel) return;
                state.mapping.midi_learn_active = true;
                // Update GUI state
            },
            else => {},
            // ... other mapping actions
        },
        .settings => |set_action| switch (set_action) {
            .set_show_plugin_ui => |show| {
                state.fx_ctrl.show_plugin_ui = show;
                // Update settings file
            },
            else => {},
            // ... other settings actions
        },
    }
}

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

fn updateFxParameter(state: *State, cc: c1.CCs, value: u7) void {
    _ = value; // autofix
    _ = cc; // autofix
    _ = state; // autofix
    // Your existing parameter update logic
    unreachable;
}

fn validateTransition(from: Mode, to: Mode) bool {
    const valid = valid_transitions.get(from) orelse return false;
    return for (valid) |valid_to| {
        if (valid_to == to) break true;
    } else false;
}

fn updateFxControlTrack(state: *State, track: reaper.MediaTrack) void {
    _ = track; // autofix
    _ = state; // autofix
    unreachable;
}

test {
    std.testing.refAllDecls(@This());
}
