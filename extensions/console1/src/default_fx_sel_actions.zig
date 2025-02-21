const std = @import("std");
const statemachine = @import("statemachine.zig");
const State = statemachine.State;
const Globals = @import("globals.zig").Globals;
const ModulesList = statemachine.ModulesList;
const dispatch = @import("actions.zig").dispatch;
const log = std.log.scoped(.default_fx_sel_actions);

pub fn defaultFxSelActions(globals: *Globals, sel_action: @import("fx_sel_actions.zig").FxSelActions) void {
    switch (sel_action) {
        .close_browser => {
            onExit(&globals.state);
            dispatch(globals, .{ .change_mode = .settings });
        },
        .toggle_module_browser => |module| {
            if (globals.state.current_mode == .default_fx_sel and module == globals.state.default_fx_sel.current_category) {
                onExit(&globals.state);
                dispatch(globals, .{ .change_mode = .settings });
            } else {
                globals.state.default_fx_sel.current_category = module;
                dispatch(globals, .{ .change_mode = .default_fx_sel });
            }
        },
        .plugin => |plugin| {
            globals.settings_panel.?.temp_settings.default_fx.set(globals.state.default_fx_sel.current_category, plugin.name);
            onExit(&globals.state);
            dispatch(globals, .{ .change_mode = .settings });
        },
        .scroll => |new_pos| {
            const fx_count: i32 = @intCast(switch (globals.state.default_fx_sel.current_category) {
                inline else => |impl| globals.mappings_list.list.get(impl).count(),
            });

            if (@import("utils.zig").calculateNewScrollPosition(
                i32,
                &globals.state.default_fx_sel.scroll_position_abs,
                &globals.state.default_fx_sel.scroll_position_rel,
                new_pos,
                @intCast(fx_count),
                1,
            )) |delta| {
                log.debug("FxSel scroll: abs={d} delta={d} rel={d}/{d}", .{
                    globals.state.default_fx_sel.scroll_position_abs,
                    delta,
                    globals.state.default_fx_sel.scroll_position_rel,
                    fx_count,
                });
            }
        },
        else => {},
    }
}

fn onExit(state: *State) void {
    state.default_fx_sel.current_category = ModulesList.COMP;
    state.default_fx_sel.scroll_position_abs = 0;
    state.default_fx_sel.scroll_position_rel = 0;
}
