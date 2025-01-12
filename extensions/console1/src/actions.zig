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
const globals = @import("globals.zig");
const SettingsPanel = @import("settings_panel.zig");
const config = @import("internals/config.zig");
const mappings = @import("internals/mappings.zig");

const allocator: std.mem.Allocator = undefined;
const valid_transitions = statemachine.valid_transitions;
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
        select_fx: []const u8,
        scroll: i32,
        open_module_browser: config.ModulesList, // Which module's browser to show
        close_module_browser,

        // Mapped FX selection
        select_mapped_fx: struct {
            module: config.ModulesList,
            fx_name: []const u8,
        },

        // Regular browser selection
        select_category_fx: struct {
            module: config.ModulesList,
            fx_name: []const u8,
            category: []const u8,
        },
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
        open, // Request to open settings
        save, // Save and close
        cancel, // Cancel and close
        set_show_plugin_ui: bool,
        set_manual_routing: bool,
        set_log_to_file: bool,
        set_log_level: logger.LogLevel,
        set_default_fx: struct {
            module: Conf.ModulesList,
            fx_name: []const u8,
        },
    },
    Csurf: union(enum) {
        csurf_track_selected: reaper.MediaTrack,
        csurf_last_touched_track: reaper.MediaTrack,
        csurf_track_list_changed,
        csurf_play_state_changed: struct {
            playing: bool,
            paused: bool,
        },
        csurf_fx_chain_changed: reaper.MediaTrack,
        csurf_fx_param_changed: ParamChg,
        csurf_fx_window_state: WinChg,
    },
    // Mode transitions
    change_mode: Mode,
};

// Top-level update function
pub fn dispatch(state: *State, action: ModeAction) void {
    logger.log(.debug, "Handling action: {s}", .{@tagName(action)}, null, allocator);
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
            .open_module_browser => |module| {
                state.fx_sel.current_category = module;
                dispatch(state, .{ .change_mode = .fx_sel });
            },
            .select_mapped_fx => |selection| {
                try loadModuleMapping(selection.module, selection.fx_name);
                try updateTrackFx(selection.module, selection.fx_name);
                // Dispatch mode change instead of direct assignment
                dispatch(state, .{ .change_mode = .fx_ctrl });
            },
            .select_category_fx => |selection| {
                if (!hasMappingFor(selection.module, selection.fx_name)) {
                    state.mapping.target_fx = selection.fx_name;
                    state.mapping.current_mappings = switch (selection.module) {
                        .COMP => .{ .COMP = mappings.Comp{} },
                        .EQ => .{ .EQ = mappings.Eq{} },
                        .GATE => .{ .GATE = mappings.Shp{} },
                        .OUTPT => .{ .OUTPT = mappings.Outpt{} },
                        .INPUT => .{ .INPUT = mappings.Inpt{} },
                    };
                    dispatch(state, .{ .change_mode = .mapping_panel });
                } else {
                    try loadModuleMapping(selection.module, selection.fx_name);
                    try updateTrackFx(selection.module, selection.fx_name);
                    dispatch(state, .{ .change_mode = .fx_ctrl });
                }
            },
            .close_module_browser => {
                dispatch(state, .{ .change_mode = .fx_ctrl });
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
            .open => {
                if (globals.settings_panel == null) {
                    globals.settings_panel = SettingsPanel.init(&globals.preferences, globals.allocator) catch null;
                }
                state.current_mode = .settings;
                dispatch(state, .{ .change_mode = .settings });
            },
            .save => {
                if (globals.settings_panel) |*panel| {
                    panel.save() catch {
                        // if the panel fails to save to disk, just keep going?
                    };
                    panel.deinit();
                    globals.settings_panel = null;
                }
                dispatch(state, .{ .change_mode = .fx_ctrl });
            },
            .cancel => {
                if (globals.settings_panel) |*panel| {
                    panel.deinit();
                    globals.settings_panel = null;
                }
                state.current_mode = .fx_ctrl; // or previous mode
            },
            .set_show_plugin_ui => |show| {
                state.fx_ctrl.show_plugin_ui = show;
                // Update settings file
            },
            .set_log_to_file => |enable| {
                globals.preferences.log_to_file = enable;
                globals.updateLoggerState() catch {
                    // if writing to log file fails, continue anyway?
                };
            },
            .set_log_level => |level| {
                globals.preferences.log_level = level;
            },

            else => {},
            // ... other settings actions
        },
        .Csurf => |set_action| switch (set_action) {
            .csurf_track_selected => |track| {
                // Update selected tracks map
                const id = reaper.CSurf_TrackToID(track, false);
                state.selectedTracks.put(allocator, id, {}) catch return;
            },
            .csurf_last_touched_track => |track| {
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
            .csurf_fx_chain_changed => |track| {
                // Revalidate FX chain for current track
                validateFxChain(state, track);
            },
            .csurf_fx_param_changed => |param| {
                if (state.current_mode == .fx_ctrl) {
                    updateControllerFeedback(state, param);
                }
            },
            .csurf_play_state_changed => |transport| {
                // Update metering state
                if (transport.playing and !transport.paused) {
                    // Start meters update timer
                } else {
                    // Stop meters update timer
                }
            },
            else => {},
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

fn loadModuleMapping(module: config.ModulesList, fx_name: []const u8) !void {
    _ = module;
    _ = fx_name;
    unreachable;
}

fn updateTrackFx(module: config.ModulesList, fx_name: []const u8) !void {
    _ = module;
    _ = fx_name;
    unreachable;
}
fn hasMappingFor(module: config.ModulesList, fx_name: []const u8) bool {
    _ = module;
    _ = fx_name;
    unreachable;
}
