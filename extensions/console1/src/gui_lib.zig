const ModulesList = @import("statemachine.zig").ModulesList;
const imgui = @import("reaper_imgui.zig");
const styles = @import("styles.zig");
const styles_components = @import("styles_components.zig");
const logger = @import("logger.zig");
const debug_panel = @import("debug_panel.zig");
const Globals = @import("globals.zig").Globals;
const fx_ctrl_panel = @import("fx_ctrl_panel.zig");
const ButtonsBar = @import("ButtonsBar.zig").ButtonsBar;
const fx_sel_panel = @import("fx_sel_panel.zig");
const preset_browser_panel = @import("preset_browser_panel.zig");
const actions = @import("actions.zig");
const mapping_panel = @import("mapping_panel.zig");
const track_list_panel = @import("track_list_panel.zig");
const c1 = @import("c1.zig");

const plugin_name = "CONSOLE1";
// In gui_lib.zig
pub const GuiError = error{
    WindowClosed,
    // ... other specific errors
};

pub fn main(
    ctx: imgui.ContextPtr,
    globals: *Globals,
    win_flags: c_int,
    style_manager: *styles.StyleManager,
) !?actions.ModeAction {
    var open: bool = true;
    try imgui.SetConfigVar(.{ ctx, imgui.ConfigVar_WindowsMoveFromTitleBarOnly, 1.0 });
    const PopStyle = try styles_components.PushStyle(ctx, .rack, style_manager);
    defer PopStyle(ctx) catch {};

    var rv: ?actions.ModeAction = null;

    try imgui.SetNextWindowDockID(.{ ctx, styles.Docker.BOTTOM });
    if (try imgui.Begin(.{ ctx, plugin_name, &open, win_flags })) {
        defer imgui.End(.{ctx}) catch {};
        open = try ButtonsBar(ctx, globals, style_manager);
        try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + 10 });
        if (style_manager.rack_style_open.*) {
            try styles_components.StyleEditor(ctx, .rack, style_manager);
        }
        if (style_manager.main_style_open.*) {
            try styles_components.StyleEditor(ctx, .main, style_manager);
        }
        switch (globals.state.current_mode) {
            .fx_ctrl => {
                if (try fx_ctrl_panel.drawFxControlPanel(ctx, globals, &globals.translations)) |ctrl_input| {
                    rv = .{ .fx_ctrl = .{ .panel_input = ctrl_input } };
                }
                if (globals.preferences.show_track_list) {
                    try imgui.SameLine(.{ctx});
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + 20 });

                    if (try track_list_panel.drawTrackListTwoColumns(ctx, &globals.state, style_manager, &globals.translations)) |tr_cc| {
                        switch (tr_cc) {
                            .Tr_pg_up => rv = .{ .track_list = .{ .page_change = .up } },
                            .Tr_pg_dn => rv = .{ .track_list = .{ .page_change = .down } },
                            else => {
                                const track_id = @intFromEnum(tr_cc) - @intFromEnum(c1.CCs.Tr_tr1);
                                if (track_id < globals.state.fx_ctrl.track_list.name_count) {
                                    const tr_id = globals.state.fx_ctrl.track_list.track_names[track_id].id;
                                    rv = .{ .track_list = .{ .track_select = tr_id } };
                                }
                            },
                        }
                    }
                }
            },
            .settings => {
                if (globals.settings_panel) |*panel| {
                    if (try panel.draw(ctx, &globals.mappings_list, style_manager, &globals.translations)) |val| {
                        switch (val) {
                            .val_update => |update| rv = .{ .settings = .{ .update_val = update } },
                            .close_save => rv = .{ .settings = .save },
                            .close_cancel => rv = .{ .settings = .cancel },
                        }
                    }
                }
            },
            .default_fx_sel => {
                if (globals.settings_panel) |*panel| {
                    if (try panel.draw(ctx, &globals.mappings_list, style_manager, &globals.translations)) |val| {
                        switch (val) {
                            .val_update => |update| rv = .{ .settings = .{ .update_val = update } },
                            .close_save => rv = .{ .settings = .save },
                            .close_cancel => rv = .{ .settings = .cancel },
                        }
                    }
                }
                const module = globals.state.default_fx_sel.current_category;
                const list = globals.mappings_list.list.get(module);
                if (try fx_sel_panel.ModulePopup(
                    ctx,
                    module,
                    list,
                    globals.state.default_fx_sel.scroll_position_rel,
                    false,
                    &globals.drwls_splitter,
                    style_manager,
                    &globals.translations,
                )) |sel_action| {
                    rv = .{ .fx_sel = sel_action };
                }
            },
            .fx_sel => {
                if (try fx_ctrl_panel.drawFxControlPanel(ctx, globals, &globals.translations)) |ctrl_input| {
                    switch (ctrl_input.cc) {
                        .Out_Vol => rv = .{ .fx_sel = .{ .scroll = @intFromFloat(ctrl_input.value * 127.0) } },
                        .Out_solo => {
                            const mappings = globals.mappings_list.list.get(globals.state.fx_sel.current_category);
                            const fx_name = mappings.keys()[globals.state.fx_sel.scroll_position_rel];
                            rv = .{ .fx_sel = .{ .plugin = .{ .name = @ptrCast(fx_name) } } };
                        },
                        .Out_mute => rv = .{ .fx_sel = .close_browser },
                        else => {},
                    }
                }

                if (globals.preferences.show_track_list) {
                    try imgui.SameLine(.{ctx});
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + 20 });
                    if (try track_list_panel.drawTrackListTwoColumns(ctx, &globals.state, style_manager, &globals.translations)) |tr_cc| {
                        switch (tr_cc) {
                            .Tr_tr1 => rv = .{ .fx_sel = .{ .toggle_module_browser = .INPUT } },
                            .Tr_tr2 => rv = .{ .fx_sel = .{ .toggle_module_browser = .GATE } },
                            .Tr_tr3 => rv = .{ .fx_sel = .{ .toggle_module_browser = .EQ } },
                            .Tr_tr4 => rv = .{ .fx_sel = .{ .toggle_module_browser = .COMP } },
                            .Tr_tr5 => rv = .{ .fx_sel = .{ .toggle_module_browser = .OUTPT } },
                            else => {},
                        }
                    }
                }

                const module = globals.state.fx_sel.current_category;
                const list = globals.mappings_list.list.get(module);
                if (try fx_sel_panel.ModulePopup(ctx, module, list, globals.state.fx_sel.scroll_position_rel, true, &globals.drwls_splitter, style_manager, &globals.translations)) |sel_action| {
                    rv = .{ .fx_sel = sel_action };
                }
            },
            .preset_browser => {
                // Because we want to show the fx_ctrl panel in the background while browsing presets,
                // we render it first (similar to fx_sel mode).
                if (try fx_ctrl_panel.drawFxControlPanel(ctx, globals, &globals.translations)) |ctrl_input| {
                    switch (ctrl_input.cc) {
                        .Out_Vol => rv = .{ .preset_browser = .{ .scroll = @intFromFloat(ctrl_input.value * 127.0) } },
                        .Out_solo => {
                            const browser_state = globals.state.preset_browser;
                            if (browser_state.available_presets.len > 0) {
                                const preset_name = browser_state.available_presets[browser_state.scroll_position_rel];
                                rv = .{ .preset_browser = .{ .select_preset = .{ .mapping_name = preset_name } } };
                            }
                        },
                        .Out_mute => rv = .{ .preset_browser = .close },
                        else => {},
                    }
                }

                // Show the preset browser popup on top
                if (try preset_browser_panel.PresetBrowserPopup(
                    ctx,
                    globals,
                    &globals.drwls_splitter,
                    style_manager,
                    &globals.translations,
                )) |browser_action| {
                    rv = .{ .preset_browser = browser_action };
                }
            },
            .mapping_panel => {
                if (try mapping_panel.mappingPanel(ctx, globals, &globals.translations)) |map_action| {
                    rv = .{ .mapping = map_action };
                }
            },
            .transport => {
                if (try fx_ctrl_panel.drawFxControlPanel(ctx, globals, &globals.translations)) |ctrl_input| {
                    const val: u8 = @intFromFloat(ctrl_input.value * 127.0);
                    switch (ctrl_input.cc) {
                        .Inpt_disp_mode => rv = .{ .change_mode = .fx_ctrl },
                        .Inpt_disp_on => rv = .set_fx_ctrl_gui,
                        .Out_Vol => rv = .{ .transport = .{ .tr_sel = val } },
                        .Out_Drive => rv = .{ .transport = .{ .zoom_horizontal = val } },
                        .Out_DriveChar => rv = .{ .transport = .{ .zoom_vertical = val } },
                        .Out_Pan => rv = .{ .transport = .{ .grid = val } },
                        .Eq_eq => rv = .{ .transport = .loop_toggle },
                        .Eq_lp_shape => rv = .{ .transport = .loop_start },
                        .Eq_hp_shape => rv = .{ .transport = .loop_end },
                        .Eq_LoGain => rv = .{ .transport = .{ .scrub = val } },
                        .Eq_LoMidGain => rv = .{ .transport = .{ .jog = val } },
                        .Eq_HiMidGain => rv = .{ .transport = .{ .jog_marker = val } },
                        .Eq_HiGain => rv = .{ .transport = .{ .jog_item = val } },
                        .Comp_comp => rv = .{ .transport = .marker_set },
                        .Inpt_HiCut => rv = .{ .transport = .{ .rate = val } },
                        .Out_solo => rv = .{ .transport = .snap_tgl },
                        else => {},
                    }
                }
                if (globals.preferences.show_track_list) {
                    try imgui.SameLine(.{ctx});
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + 20 });

                    if (try track_list_panel.drawTrackListTwoColumns(ctx, &globals.state, style_manager, &globals.translations)) |tr_cc| {
                        switch (tr_cc) {
                            .Tr_tr1, .Tr_tr2, .Tr_tr3, .Tr_tr4, .Tr_tr5 => |cc_| {
                                const module: ModulesList = switch (cc_) {
                                    .Tr_tr1 => .INPUT,
                                    .Tr_tr2 => .GATE,
                                    .Tr_tr3 => .EQ,
                                    .Tr_tr4 => .COMP,
                                    .Tr_tr5 => .OUTPT,
                                    else => unreachable,
                                };
                                rv = .{ .fx_sel = .{ .toggle_module_browser = module } };
                            },
                            .Tr_tr6 => rv = .{ .transport = .{ .automation_mode = .trim } },
                            .Tr_tr7 => rv = .{ .transport = .{ .automation_mode = .read } },
                            .Tr_tr8 => rv = .{ .transport = .{ .automation_mode = .latch } },
                            .Tr_tr9 => rv = .{ .transport = .{ .automation_mode = .preview } },
                            .Tr_tr10 => rv = .{ .transport = .{ .automation_mode = .write } },
                            .Tr_tr17 => rv = .{ .transport = .play },
                            .Tr_tr18 => rv = .{ .transport = .stop },
                            .Tr_tr19 => rv = .{ .transport = .rec },
                            .Tr_tr20 => rv = .{ .settings = .open },
                            else => {},
                        }
                    }
                }
            },
            else => {},
        }
    }
    // Add debug panel
    if (logger.debug_window_active) {
        try debug_panel.drawDebugPanel(ctx, &globals.state);
    }

    if (!open)
        return error.WindowClosed;

    return rv;
}
