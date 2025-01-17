const std = @import("std");
const c1 = @import("c1.zig");
const reaper = @import("reaper.zig").reaper;
const fx_ctrl_state = @import("fx_ctrl_state.zig");
const ModulesOrder = fx_ctrl_state.ModulesOrder;
const SCRouting = fx_ctrl_state.SCRouting;
const statemachine = @import("statemachine.zig");
const logger = @import("logger.zig");
const Mode = statemachine.Mode;
const State = statemachine.State;
const globals = @import("globals.zig");
const SettingsPanel = @import("settings_panel.zig");
const mappings = @import("mappings.zig");
const MappingPanel = @import("mapping_panel.zig").MappingPanel;
const ModulesList = statemachine.ModulesList;
const constants = @import("constants.zig");
const onMidiEvent_FxCtrl = @import("csurf/midi_events_fxctrl.zig").onMidiEvent_FxCtrl;
const MappingAction = @import("mapping_actions.zig").MappingAction;
const mappingActions = @import("mapping_actions.zig").mappingActions;
const settings_actions = @import("settings_actions.zig");
const SettingsActions = settings_actions.SettingsActions;
const fx_sel_actions = @import("fx_sel_actions.zig");
const FxSelActions = fx_sel_actions.FxSelActions;
const fx_ctrl_actions = @import("fx_ctrl_actions.zig");
const FxCtrlAction = fx_ctrl_actions.FxCtrlAction;
const fxCtrlActions = fx_ctrl_actions.fxCtrlActions;

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
pub const ModeAction = union(enum) {
    // FX Control Mode
    fx_ctrl: FxCtrlAction,

    // FX Selection Mode
    fx_sel: FxSelActions,

    // Mapping Mode
    mapping: MappingAction,

    // Settings Mode
    settings: SettingsActions,
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
                    .{ .state_change = .{ .new_mode = new_mode, .old_mode = old_mode } },
                    globals.allocator,
                );
            }
        },
        .fx_ctrl => |fx_action| fxCtrlActions(state, fx_action),
        .fx_sel => |sel_action| {
            fx_sel_actions.fxSelActions(state, sel_action);
        },
        .mapping => |map_action| {
            mappingActions(state, map_action);
        },
        .settings => |set_action| {
            settings_actions.settingsActions(state, set_action);
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

// Helper function to validate CC against module type
fn isValidCCForModule(cc: c1.CCs, module: ModulesList) bool {
    const cc_name = @tagName(cc);
    return switch (module) {
        .COMP => std.mem.startsWith(u8, cc_name, "Comp_"),
        .EQ => std.mem.startsWith(u8, cc_name, "Eq_"),
        .INPUT => std.mem.startsWith(u8, cc_name, "Inpt_"),
        .OUTPT => std.mem.startsWith(u8, cc_name, "Out_"),
        .GATE => std.mem.startsWith(u8, cc_name, "Shp_"),
    };
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
