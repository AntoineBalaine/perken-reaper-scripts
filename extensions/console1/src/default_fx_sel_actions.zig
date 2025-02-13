const std = @import("std");
const statemachine = @import("statemachine.zig");
const State = statemachine.State;
const globals = @import("globals.zig");
const ModulesList = statemachine.ModulesList;
const dispatch = @import("actions.zig").dispatch;
const log = std.log.scoped(.default_fx_sel_actions);

pub fn defaultFxSelActions(state: *State, sel_action: @import("fx_sel_actions.zig").FxSelActions) void {
    switch (sel_action) {
        .close_browser => {
            onExit(state);
            dispatch(state, .{ .change_mode = .settings });
        },
        .toggle_module_browser => |module| {
            if (state.current_mode == .default_fx_sel and module == state.default_fx_sel.current_category) {
                onExit(state);
                dispatch(state, .{ .change_mode = .settings });
            } else {
                state.default_fx_sel.current_category = module;
                dispatch(state, .{ .change_mode = .default_fx_sel });
            }
        },
        .plugin => |plugin| {
            globals.settings_panel.?.temp_settings.default_fx.set(state.default_fx_sel.current_category, plugin.name);
            onExit(state);
            dispatch(state, .{ .change_mode = .settings });
        },
        .scroll => |new_pos| {
            const fx_count: i32 = @intCast(switch (state.default_fx_sel.current_category) {
                inline else => |impl| globals.mappings_list.list.get(impl).count(),
            });

            if (@import("utils.zig").calculateNewScrollPosition(
                i32,
                &state.default_fx_sel.scroll_position_abs,
                &state.default_fx_sel.scroll_position_rel,
                new_pos,
                @intCast(fx_count),
                1,
            )) |delta| {
                log.debug("FxSel scroll: abs={d} delta={d} rel={d}/{d}", .{
                    state.default_fx_sel.scroll_position_abs,
                    delta,
                    state.default_fx_sel.scroll_position_rel,
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
