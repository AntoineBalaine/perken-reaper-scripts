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
const csurf_actions = @import("csurf_actions.zig");
const CsurfAction = csurf_actions.CsurfAction;
const csurfActions = csurf_actions.csurfActions;
const imgui_loop = @import("imgui_loop.zig");
const log = std.log.scoped(.dispatch);
const tr_ls_act = @import("tracklist_actions.zig");
const TrackListAction = tr_ls_act.TrackListAction;
const trackListAction = tr_ls_act.trackListAction;

const valid_transitions = statemachine.valid_transitions;
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
    Csurf: CsurfAction,
    // Mode transitions
    change_mode: Mode,
    set_fx_ctrl_gui,
    track_list: TrackListAction,
};

// Top-level update function
pub fn dispatch(state: *State, action: ModeAction) void {
    log.debug("Handling action: {s}", .{@tagName(action)});
    switch (action) {
        .change_mode => |new_mode| {
            const old_mode = state.current_mode;
            switch (new_mode) {
                .suspended => {
                    // Stop GUI when suspending
                    imgui_loop.reset();
                    state.current_mode = .suspended;
                },
                .fx_ctrl => {
                    switch (old_mode) {
                        .suspended => {
                            if (state.fx_ctrl_gui_visible) imgui_loop.register();
                        },
                        else => if (!state.fx_ctrl_gui_visible) imgui_loop.reset(),
                    }
                    state.current_mode = .fx_ctrl;
                },
                else => {
                    switch (old_mode) {
                        .fx_ctrl => if (!state.fx_ctrl_gui_visible) imgui_loop.register(),
                        else => {},
                    }
                    state.current_mode = new_mode;
                },
            }
            log.info(
                "Mode changed: {s} -> {s} evt: {}",
                .{
                    @tagName(old_mode),
                    @tagName(new_mode),
                    logger.Event{ .state_change = .{ .new_mode = new_mode, .old_mode = old_mode } },
                },
            );
        },
        .set_fx_ctrl_gui => {
            state.fx_ctrl_gui_visible = !state.fx_ctrl_gui_visible;
            if (state.fx_ctrl_gui_visible) {
                imgui_loop.register();
            } else {
                imgui_loop.reset();
            }
        },
        else => |mode_action| {
            if (state.current_mode == .suspended) return;
            switch (mode_action) {
                .fx_ctrl => |fx_action| fxCtrlActions(state, fx_action),
                .fx_sel => |sel_action| fx_sel_actions.fxSelActions(state, sel_action),
                .mapping => |map_action| mappingActions(state, map_action),
                .settings => |set_action| settings_actions.settingsActions(state, set_action),
                .Csurf => |set_action| csurfActions(state, set_action),
                .track_list => |tr_action| trackListAction(state, tr_action),
                else => unreachable,
            }
        },
    }
}

fn validateTransition(from: Mode, to: Mode) bool {
    const valid = valid_transitions.get(from) orelse return false;
    return for (valid) |valid_to| {
        if (valid_to == to) break true;
    } else false;
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
