const std = @import("std");
const statemachine = @import("statemachine.zig");
const State = statemachine.State;
const Globals = @import("globals.zig").Globals;
const ModulesList = statemachine.ModulesList;
const dispatch = @import("actions.zig").dispatch;
const utils = @import("utils.zig");
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
        .confirm => {
            const category = globals.state.default_fx_sel.current_category;
            const mappings = globals.mappings_list.list.get(category);

            switch (globals.state.default_fx_sel.sub_mode) {
                .browse_fx => {
                    if (mappings.count() == 0) return;
                    const fx_offset = mappings.keys()[globals.state.default_fx_sel.scroll_position_rel];
                    const mapping_offsets = mappings.get(fx_offset) orelse return;
                    const fx_name = globals.mappings_list.strings.get(fx_offset);

                    if (mapping_offsets.items.len == 1) {
                        const mapping_name = globals.mappings_list.strings.get(mapping_offsets.items[0].name_offset);
                        defaultFxSelActions(globals, .{ .plugin = .{ .name = fx_name, .mapping_name = mapping_name } });
                    } else {
                        globals.state.default_fx_sel.sub_mode = .{ .select_mapping = .{
                            .fx_name = fx_name,
                            .fx_string_pool_offset = fx_offset,
                        } };
                    }
                },
                .select_mapping => |sel| {
                    const mapping_offsets = mappings.get(sel.fx_string_pool_offset) orelse return;
                    if (sel.scroll_position_rel >= mapping_offsets.items.len) return;
                    const mapping_name = globals.mappings_list.strings.get(mapping_offsets.items[sel.scroll_position_rel].name_offset);
                    defaultFxSelActions(globals, .{ .plugin = .{ .name = sel.fx_name, .mapping_name = mapping_name } });
                },
            }
        },
        .back => {
            globals.state.default_fx_sel.sub_mode = .browse_fx;
        },
        .scroll => |new_pos| {
            globals.state.default_fx_sel.scroll_changed = true;
            switch (globals.state.default_fx_sel.sub_mode) {
                .browse_fx => {
                    const fx_count: i32 = @intCast(switch (globals.state.default_fx_sel.current_category) {
                        inline else => |impl| globals.mappings_list.list.get(impl).count(),
                    });
                    _ = utils.calculateNewScrollPosition(
                        i32,
                        &globals.state.default_fx_sel.scroll_position_abs,
                        &globals.state.default_fx_sel.scroll_position_rel,
                        new_pos,
                        @intCast(fx_count),
                        1,
                    );
                },
                .select_mapping => |*sel| {
                    const mapping_offsets = globals.mappings_list.list.get(
                        globals.state.default_fx_sel.current_category,
                    ).get(sel.fx_string_pool_offset) orelse return;
                    _ = utils.calculateNewScrollPosition(
                        i32,
                        &sel.scroll_position_abs,
                        &sel.scroll_position_rel,
                        new_pos,
                        @intCast(mapping_offsets.items.len),
                        1,
                    );
                },
            }
        },
        else => {},
    }
}

fn onExit(state: *State) void {
    state.default_fx_sel.current_category = ModulesList.COMP;
    state.default_fx_sel.scroll_position_abs = 0;
    state.default_fx_sel.scroll_position_rel = 0;
    state.default_fx_sel.sub_mode = .browse_fx;
}
