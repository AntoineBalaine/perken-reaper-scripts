const std = @import("std");
const c1 = @import("c1.zig");
const statemachine = @import("statemachine.zig");
const logger = @import("logger.zig");
const Mode = statemachine.Mode;
const Globals = @import("globals.zig").Globals;
const ModulesList = statemachine.ModulesList;
const mappingPanelActions = @import("mapping_actions.zig").mappingPanelActions;
const settings_actions = @import("settings_actions.zig");
const fx_sel_actions = @import("fx_sel_actions.zig");
const fxCtrlActions = @import("fx_ctrl_actions.zig").fxCtrlActions;
const csurfActions = @import("csurf_actions.zig").csurfActions;
const imgui_loop = @import("imgui_loop.zig");
const log = std.log.scoped(.dispatch);
const trackListAction = @import("tracklist_actions.zig").trackListAction;
const midi_out = @import("midi_out.zig");
const transportAction = @import("transport_actions.zig").transportAction;
const default_fx_sel_actions = @import("default_fx_sel_actions.zig");
const theme_dump = @import("theme_dump.zig");

const valid_transitions = statemachine.valid_transitions;

// Re-export ModeAction from the shared types file so that existing code
// that does @import("actions.zig").ModeAction continues to work.
pub const ModeAction = @import("action_types.zig").ModeAction;

// Top-level update function
pub fn dispatch(app: *Globals, action: ModeAction) void {
    // log.debug("Handling action: {s}", .{@tagName(action)});
    switch (action) {
        .change_mode => |new_mode| {
            if (!validateTransition(app.state.current_mode, new_mode)) {
                log.err(
                    "Invalid mode transition: {s} -> {s}",
                    .{ @tagName(app.state.current_mode), @tagName(new_mode) },
                );
                return;
            }
            const old_mode = app.state.current_mode;
            switch (new_mode) {
                .suspended => {
                    // Stop GUI when suspending
                    imgui_loop.reset();
                    app.state.current_mode = .suspended;
                },
                .fx_ctrl => {
                    switch (old_mode) {
                        .suspended => {
                            if (app.state.fx_ctrl_gui_visible) imgui_loop.register();
                        },
                        else => if (!app.state.fx_ctrl_gui_visible) imgui_loop.reset(),
                    }
                    app.state.current_mode = .fx_ctrl;
                },
                else => {
                    switch (old_mode) {
                        .fx_ctrl => if (!app.state.fx_ctrl_gui_visible) imgui_loop.register(),
                        else => {},
                    }
                    app.state.current_mode = new_mode;
                },
            }
            log.debug(
                "Mode changed: {s} -> {s} evt: {}",
                .{
                    @tagName(old_mode),
                    @tagName(new_mode),
                    logger.Event{ .state_change = .{ .new_mode = new_mode, .old_mode = old_mode } },
                },
            );

            midi_out.sendMidiFeedback(app, .{ .mode_entry = new_mode });
        },
        .set_fx_ctrl_gui => {
            app.state.fx_ctrl_gui_visible = !app.state.fx_ctrl_gui_visible;
            if (app.state.fx_ctrl_gui_visible) {
                imgui_loop.register();
            } else {
                imgui_loop.reset();
            }
        },
        else => |mode_action| {
            if (app.state.current_mode == .suspended) return;
            switch (mode_action) {
                .fx_ctrl => |fx_action| fxCtrlActions(app, fx_action),
                .fx_sel => |sel_action| fx_sel_actions.fxSelActions(app, sel_action),
                .mapping_panel => |mp_action| mappingPanelActions(app, mp_action),
                .settings => |set_action| settings_actions.settingsActions(app, set_action),
                .default_fx_sel => |sel_action| default_fx_sel_actions.defaultFxSelActions(app, sel_action),
                .Csurf => |set_action| csurfActions(app, set_action),
                .track_list => |tr_action| trackListAction(app, tr_action),
                .midi_out => |m_out_action| midi_out.sendMidiFeedback(app, m_out_action),
                .transport => |trspt_act| transportAction(app, trspt_act),
                .save_theme => {
                    const io = Globals.hostIo();
                    theme_dump.saveThemeToFile(io);
                },
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
