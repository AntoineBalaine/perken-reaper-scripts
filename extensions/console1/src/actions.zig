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
const MappingPanel = @import("mapping_panel.zig").MappingPanel;

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
        select_fx: [:0]const u8,
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
            fx_name: [:0]const u8,
            category: [:0]const u8,
        },
    },

    // Mapping Mode
    mapping: union(enum) {
        // Parameter selection
        select_parameter: ?u32, // null to deselect

        // Control selection
        select_control: ?c1.CCs, // null to deselect

        // MIDI learn
        toggle_midi_learn: void,

        // Mapping operations
        add_mapping: struct {
            param: u8,
            control: c1.CCs,
        },
        remove_mapping: c1.CCs, // Remove mapping for this control

        // Panel operations
        save_mapping: void, // Save current mappings to MapStore
        cancel_mapping: void, // Discard changes and exit mapping mode
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
    logger.log(.debug, "Handling action: {s}", .{@tagName(action)}, null, globals.allocator);
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
                    globals.allocator,
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
            .select_fx => |fx_name| {
                // Check if mapping exists
                if (switch (globals.map_store.get(fx_name, state.fx_sel.current_category)) {
                    inline else => |impl| impl == null,
                }) {
                    createEmptyMapping(state, fx_name) catch return;
                    // Open mapping panel
                    if (state.last_touched_tr_id) |track_id| {
                        switch (state.fx_sel.current_category) {
                            inline else => |variant| {
                                const fxMap = @field(state.fx_ctrl.fxMap, @tagName(variant));

                                if (fxMap == null) return;
                                if (fxMap) |map| {
                                    enterMappingMode(track_id, map[0]) catch {};
                                    dispatch(state, .{ .change_mode = .mapping_panel });
                                }
                            },
                        }
                    }
                }
            },
            .close_module_browser => {
                dispatch(state, .{ .change_mode = .fx_ctrl });
            },
            else => {},
            // ... other fx_sel actions
        },
        .mapping => |map_action| switch (map_action) {
            .select_parameter => |maybe_param| {
                logger.log(.debug, "Selected parameter: {?}", .{maybe_param}, null, globals.allocator);
                state.mapping.selected_parameter = maybe_param;
                // If we're in MIDI learn mode and a parameter is selected,
                // we're ready to receive MIDI input
            },
            .select_control => |maybe_control| {
                logger.log(.debug, "Selected control: {s}", .{if (maybe_control) |cc| @tagName(cc) else "none"}, null, globals.allocator);
                state.mapping.selected_control = maybe_control;
                // If both parameter and control are selected, could auto-add mapping
            },
            .toggle_midi_learn => {
                logger.log(.debug, "MIDI learn {s}", .{if (state.mapping.midi_learn_active) "disabled" else "enabled"}, null, globals.allocator);
                state.mapping.midi_learn_active = !state.mapping.midi_learn_active;
                if (!state.mapping.midi_learn_active) {
                    // Clear selection when exiting MIDI learn mode?
                    state.mapping.selected_control = null;
                }
            },
            .add_mapping => |mapping| {
                logger.log(.info, "Added mapping: {s} -> param {d}", .{ @tagName(mapping.control), mapping.param }, null, globals.allocator);
                // Add to current_mappings based on module type
                switch (state.mapping.current_mappings) {
                    .COMP => |*comp| switch (mapping.control) {
                        .Comp_Attack => comp.Comp_Attack = mapping.param,
                        .Comp_DryWet => comp.Comp_DryWet = mapping.param,
                        .Comp_Ratio => comp.Comp_Ratio = mapping.param,
                        .Comp_Release => comp.Comp_Release = mapping.param,
                        .Comp_Thresh => comp.Comp_Thresh = mapping.param,
                        .Comp_comp => comp.Comp_comp = mapping.param,
                        else => {},
                    },
                    .EQ => |*eq| switch (mapping.control) {
                        .Eq_HiFrq => eq.Eq_HiFrq = mapping.param,
                        .Eq_HiGain => eq.Eq_HiGain = mapping.param,
                        .Eq_HiMidFrq => eq.Eq_HiMidFrq = mapping.param,
                        .Eq_HiMidGain => eq.Eq_HiMidGain = mapping.param,
                        .Eq_HiMidQ => eq.Eq_HiMidQ = mapping.param,
                        .Eq_LoFrq => eq.Eq_LoFrq = mapping.param,
                        .Eq_LoGain => eq.Eq_LoGain = mapping.param,
                        .Eq_LoMidFrq => eq.Eq_LoMidFrq = mapping.param,
                        .Eq_LoMidGain => eq.Eq_LoMidGain = mapping.param,
                        .Eq_LoMidQ => eq.Eq_LoMidQ = mapping.param,
                        .Eq_eq => eq.Eq_eq = mapping.param,
                        .Eq_hp_shape => eq.Eq_hp_shape = mapping.param,
                        .Eq_lp_shape => eq.Eq_lp_shape = mapping.param,
                        else => {},
                    },
                    .INPUT => |*input| switch (mapping.control) {
                        .Inpt_Gain => input.Inpt_Gain = mapping.param,
                        .Inpt_HiCut => input.Inpt_HiCut = mapping.param,
                        .Inpt_LoCut => input.Inpt_LoCut = mapping.param,
                        .Inpt_disp_mode => input.Inpt_disp_mode = mapping.param,
                        .Inpt_disp_on => input.Inpt_disp_on = mapping.param,
                        .Inpt_filt_to_comp => input.Inpt_filt_to_comp = mapping.param,
                        .Inpt_phase_inv => input.Inpt_phase_inv = mapping.param,
                        .Inpt_preset => input.Inpt_preset = mapping.param,
                        else => {},
                    },
                    .OUTPT => |*output| switch (mapping.control) {
                        .Out_Drive => output.Out_Drive = mapping.param,
                        .Out_DriveChar => output.Out_DriveChar = mapping.param,
                        .Out_Pan => output.Out_Pan = mapping.param,
                        .Out_Vol => output.Out_Vol = mapping.param,
                        else => {},
                    },
                    .GATE => |*gate| switch (mapping.control) {
                        .Shp_Gate => gate.Shp_Gate = mapping.param,
                        .Shp_GateRelease => gate.Shp_GateRelease = mapping.param,
                        .Shp_Punch => gate.Shp_Punch = mapping.param,
                        .Shp_hard_gate => gate.Shp_hard_gate = mapping.param,
                        .Shp_shape => gate.Shp_shape = mapping.param,
                        .Shp_sustain => gate.Shp_sustain = mapping.param,
                        else => {},
                    },
                }
                // Clear selections after mapping
                state.mapping.selected_parameter = null;
                state.mapping.selected_control = null;
            },
            .remove_mapping => |control| {
                logger.log(.info, "Removed mapping for control: {s}", .{@tagName(control)}, null, globals.allocator);
                // Remove from current_mappings based on module type
                switch (state.mapping.current_mappings) {
                    .COMP => |*comp| switch (control) {
                        .Comp_Attack => comp.Comp_Attack = mappings.UNMAPPED_PARAM,
                        .Comp_DryWet => comp.Comp_DryWet = mappings.UNMAPPED_PARAM,
                        .Comp_Ratio => comp.Comp_Ratio = mappings.UNMAPPED_PARAM,
                        .Comp_Release => comp.Comp_Release = mappings.UNMAPPED_PARAM,
                        .Comp_Thresh => comp.Comp_Thresh = mappings.UNMAPPED_PARAM,
                        .Comp_comp => comp.Comp_comp = mappings.UNMAPPED_PARAM,
                        else => {},
                    },
                    .EQ => |*eq| switch (control) {
                        .Eq_HiFrq => eq.Eq_HiFrq = mappings.UNMAPPED_PARAM,
                        .Eq_HiGain => eq.Eq_HiGain = mappings.UNMAPPED_PARAM,
                        .Eq_HiMidFrq => eq.Eq_HiMidFrq = mappings.UNMAPPED_PARAM,
                        .Eq_HiMidGain => eq.Eq_HiMidGain = mappings.UNMAPPED_PARAM,
                        .Eq_HiMidQ => eq.Eq_HiMidQ = mappings.UNMAPPED_PARAM,
                        .Eq_LoFrq => eq.Eq_LoFrq = mappings.UNMAPPED_PARAM,
                        .Eq_LoGain => eq.Eq_LoGain = mappings.UNMAPPED_PARAM,
                        .Eq_LoMidFrq => eq.Eq_LoMidFrq = mappings.UNMAPPED_PARAM,
                        .Eq_LoMidGain => eq.Eq_LoMidGain = mappings.UNMAPPED_PARAM,
                        .Eq_LoMidQ => eq.Eq_LoMidQ = mappings.UNMAPPED_PARAM,
                        .Eq_eq => eq.Eq_eq = mappings.UNMAPPED_PARAM,
                        .Eq_hp_shape => eq.Eq_hp_shape = mappings.UNMAPPED_PARAM,
                        .Eq_lp_shape => eq.Eq_lp_shape = mappings.UNMAPPED_PARAM,
                        else => {},
                    },
                    .INPUT => |*input| switch (control) {
                        .Inpt_Gain => input.Inpt_Gain = mappings.UNMAPPED_PARAM,
                        .Inpt_HiCut => input.Inpt_HiCut = mappings.UNMAPPED_PARAM,
                        .Inpt_LoCut => input.Inpt_LoCut = mappings.UNMAPPED_PARAM,
                        .Inpt_disp_mode => input.Inpt_disp_mode = mappings.UNMAPPED_PARAM,
                        .Inpt_disp_on => input.Inpt_disp_on = mappings.UNMAPPED_PARAM,
                        .Inpt_filt_to_comp => input.Inpt_filt_to_comp = mappings.UNMAPPED_PARAM,
                        .Inpt_phase_inv => input.Inpt_phase_inv = mappings.UNMAPPED_PARAM,
                        .Inpt_preset => input.Inpt_preset = mappings.UNMAPPED_PARAM,
                        else => {},
                    },
                    .OUTPT => |*output| switch (control) {
                        .Out_Drive => output.Out_Drive = mappings.UNMAPPED_PARAM,
                        .Out_DriveChar => output.Out_DriveChar = mappings.UNMAPPED_PARAM,
                        .Out_Pan => output.Out_Pan = mappings.UNMAPPED_PARAM,
                        .Out_Vol => output.Out_Vol = mappings.UNMAPPED_PARAM,
                        else => {},
                    },
                    .GATE => |*gate| switch (control) {
                        .Shp_Gate => gate.Shp_Gate = mappings.UNMAPPED_PARAM,
                        .Shp_GateRelease => gate.Shp_GateRelease = mappings.UNMAPPED_PARAM,
                        .Shp_Punch => gate.Shp_Punch = mappings.UNMAPPED_PARAM,
                        .Shp_hard_gate => gate.Shp_hard_gate = mappings.UNMAPPED_PARAM,
                        .Shp_shape => gate.Shp_shape = mappings.UNMAPPED_PARAM,
                        .Shp_sustain => gate.Shp_sustain = mappings.UNMAPPED_PARAM,
                        else => {},
                    },
                }
            },
            .save_mapping => {
                logger.log(.info, "Saved mappings for FX: {s}", .{state.mapping.target_fx}, null, globals.allocator);
                // Save to MapStore
                switch (state.mapping.current_mappings) {
                    .INPUT => |input| globals.map_store.INPUT.put(globals.allocator, state.mapping.target_fx, input) catch {},
                    .GATE => |gate| globals.map_store.GATE.put(globals.allocator, state.mapping.target_fx, gate) catch {},
                    .EQ => |eq| globals.map_store.EQ.put(globals.allocator, state.mapping.target_fx, eq) catch {},
                    .COMP => |comp| globals.map_store.COMP.put(globals.allocator, state.mapping.target_fx, comp) catch {},
                    .OUTPT => |outpt| globals.map_store.OUTPT.put(globals.allocator, state.mapping.target_fx, outpt) catch {},
                }

                globals.map_store.saveToFile(state.mapping) catch {
                    logger.log(.warning, "Failed to save mapping {s} to file", .{state.mapping.target_fx}, null, globals.allocator);
                };

                // Clean up mapping panel
                if (globals.mapping_panel) |*panel| {
                    panel.deinit();
                    globals.mapping_panel = null;
                }
                dispatch(state, .{ .change_mode = .fx_ctrl });
            },
            .cancel_mapping => {
                logger.log(.info, "Cancelled mapping for FX: {s}", .{state.mapping.target_fx}, null, globals.allocator);
                // Clean up mapping state
                state.mapping.selected_parameter = null;
                state.mapping.selected_control = null;
                state.mapping.midi_learn_active = false;

                // Free allocated memory
                state.mapping.deinit(globals.allocator);

                // Clean up mapping panel
                if (globals.mapping_panel) |*panel| {
                    panel.deinit();
                    globals.mapping_panel = null;
                }

                // Switch back to previous mode
                dispatch(state, .{ .change_mode = .fx_ctrl });
            },
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
                state.selectedTracks.put(globals.allocator, id, {}) catch return;
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

/// Create empty mapping in MapStore
fn createEmptyMapping(state: *State, fx_name: [:0]const u8) !void {
    switch (state.fx_sel.current_category) {
        .INPUT => try globals.map_store.INPUT.put(globals.allocator, try globals.allocator.dupeZ(u8, fx_name), mappings.Inpt{}),
        .GATE => try globals.map_store.GATE.put(globals.allocator, try globals.allocator.dupeZ(u8, fx_name), mappings.Shp{}),
        .EQ => try globals.map_store.EQ.put(globals.allocator, try globals.allocator.dupeZ(u8, fx_name), mappings.Eq{}),
        .COMP => try globals.map_store.COMP.put(globals.allocator, try globals.allocator.dupeZ(u8, fx_name), mappings.Comp{}),
        .OUTPT => try globals.map_store.OUTPT.put(globals.allocator, try globals.allocator.dupeZ(u8, fx_name), mappings.Outpt{}),
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

// Helper function to validate CC against module type
fn isValidCCForModule(cc: c1.CCs, module: Conf.ModulesList) bool {
    const cc_name = @tagName(cc);
    return switch (module) {
        .COMP => std.mem.startsWith(u8, cc_name, "Comp_"),
        .EQ => std.mem.startsWith(u8, cc_name, "Eq_"),
        .INPUT => std.mem.startsWith(u8, cc_name, "Inpt_"),
        .OUTPT => std.mem.startsWith(u8, cc_name, "Out_"),
        .GATE => std.mem.startsWith(u8, cc_name, "Shp_"),
    };
}

pub fn enterMappingMode(track_id: c_int, fx_number: i32) !void {
    const media_track =
        reaper.CSurf_TrackFromID(track_id, false);
    if (globals.mapping_panel == null) {
        globals.mapping_panel = MappingPanel.init(globals.allocator);
    }
    try globals.mapping_panel.?.loadParameters(media_track, fx_number);
}

test {
    std.testing.refAllDecls(@This());
}

// test "MappingState - initialization and basic operations" {
//     const testing = std.testing;
//     const gpa = testing.allocator;
//
//     // Test init
//     const fx_name = "Test FX";
//     var mapping_state = try statemachine.MappingState.init(gpa, fx_name, .COMP);
//     defer mapping_state.deinit(gpa);
//
//     try testing.expectEqualStrings(fx_name, mapping_state.target_fx);
//     try testing.expect(mapping_state.current_mappings == .COMP);
//     try testing.expect(mapping_state.selected_parameter == null);
//     try testing.expect(mapping_state.selected_control == null);
//     try testing.expect(mapping_state.midi_learn_active == false);
// }
//
// test "MappingActions - parameter and control selection" {
//     const testing = std.testing;
//     const gpa = testing.allocator;
//
//     var state = State.init(gpa);
//     defer state.deinit(gpa);
//
//     // Initialize mapping state
//     state.mapping = try statemachine.MappingState.init(gpa, "Test FX", .COMP);
//     state.current_mode = .mapping_panel;
//
//     // Test parameter selection
//     dispatch(&state, .{ .mapping = .{ .select_parameter = 1 } });
//     try testing.expect(state.mapping.selected_parameter.? == 1);
//
//     // Test parameter deselection
//     dispatch(&state, .{ .mapping = .{ .select_parameter = null } });
//     try testing.expect(state.mapping.selected_parameter == null);
//
//     // Test control selection
//     dispatch(&state, .{ .mapping = .{ .select_control = .Comp_Attack } });
//     try testing.expect(state.mapping.selected_control.? == .Comp_Attack);
//
//     // Test control deselection
//     dispatch(&state, .{ .mapping = .{ .select_control = null } });
//     try testing.expect(state.mapping.selected_control == null);
// }
//
// test "MappingActions - MIDI learn toggle" {
//     const testing = std.testing;
//     const gpa = testing.allocator;
//
//     var state = State.init(gpa);
//     defer state.deinit(gpa);
//
//     state.mapping = try statemachine.MappingState.init(gpa, "Test FX", .COMP);
//     state.current_mode = .mapping_panel;
//
//     // Test MIDI learn activation
//     dispatch(&state, .{ .mapping = .toggle_midi_learn });
//     try testing.expect(state.mapping.midi_learn_active == true);
//
//     // Test MIDI learn deactivation
//     dispatch(&state, .{ .mapping = .toggle_midi_learn });
//     try testing.expect(state.mapping.midi_learn_active == false);
//     try testing.expect(state.mapping.selected_control == null);
// }
//
// test "MappingActions - add and remove mappings" {
//     const testing = std.testing;
//     const gpa = testing.allocator;
//
//     var state = State.init(gpa);
//     defer state.deinit(gpa);
//
//     state.mapping = try statemachine.MappingState.init(gpa, "Test FX", .COMP);
//     state.current_mode = .mapping_panel;
//
//     // Test adding mapping
//     dispatch(&state, .{
//         .mapping = .{
//             .add_mapping = .{
//                 .param = 1,
//                 .control = .Comp_Attack,
//             },
//         },
//     });
//
//     // Verify mapping was added
//     switch (state.mapping.current_mappings) {
//         .COMP => |comp| try testing.expect(comp.Comp_Attack == 1),
//         else => try testing.expect(false),
//     }
//
//     // Test removing mapping
//     dispatch(&state, .{
//         .mapping = .{
//             .remove_mapping = .Comp_Attack,
//         },
//     });
//
//     // Verify mapping was removed
//     switch (state.mapping.current_mappings) {
//         .COMP => |comp| try testing.expect(comp.Comp_Attack == mappings.UNMAPPED_PARAM),
//         else => try testing.expect(false),
//     }
// }
//
// test "MappingActions - save and cancel" {
//     const testing = std.testing;
//     const gpa = testing.allocator;
//
//     // Initialize global state (required for save operation)
//     globals.allocator = gpa;
//     globals.map_store = mappings.init(gpa);
//     defer globals.map_store.deinit();
//
//     var state = State.init(gpa);
//     defer state.deinit(gpa);
//
//     state.mapping = try statemachine.MappingState.init(gpa, "Test FX", .COMP);
//     state.current_mode = .mapping_panel;
//
//     // Add a mapping
//     dispatch(&state, .{
//         .mapping = .{
//             .add_mapping = .{
//                 .param = 1,
//                 .control = .Comp_Attack,
//             },
//         },
//     });
//
//     // Test save mapping
//     dispatch(&state, .{
//         .mapping = .save_mapping,
//     });
//
//     // Verify mode changed and mapping was saved
//     try testing.expect(state.current_mode == .fx_ctrl);
//     if (globals.map_store.COMP.get("Test FX")) |saved_mapping| {
//         try testing.expect(saved_mapping.Comp_Attack == 1);
//     } else {
//         try testing.expect(false);
//     }
//
//     // Test cancel mapping
//     state.mapping = try statemachine.MappingState.init(gpa, "Test FX 2", .COMP);
//     state.current_mode = .mapping_panel;
//     dispatch(&state, .{
//         .mapping = .cancel_mapping,
//     });
//
//     try testing.expect(state.current_mode == .fx_ctrl);
//     try testing.expect(globals.map_store.COMP.get("Test FX 2") == null);
// }
