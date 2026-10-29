const ModulesList = @import("statemachine.zig").ModulesList;
const imgui = @import("reaper_imgui");
const styles = @import("styles.zig");
const styles_components = @import("styles_components.zig");
const logger = @import("logger.zig");
const debug_panel = @import("debug_panel.zig");
const UiState = @import("ui_state.zig").UiState;
const fx_ctrl_panel = @import("fx_ctrl_panel.zig");
const ButtonsBar = @import("ButtonsBar.zig").ButtonsBar;
const fx_sel_panel = @import("fx_sel_panel.zig");
const actions = @import("action_types.zig");
const mapping_panel = @import("mapping_panel.zig");
const module_selection_panel = @import("module_selection_panel.zig");
const track_list_panel = @import("track_list_panel.zig");
const c1 = @import("c1.zig");
const theme_editor = @import("theme_editor.zig");

const plugin_name = "CONSOLE1";

pub const GuiError = error{
    WindowClosed,
};

pub fn main(
    ctx: imgui.ContextPtr,
    ui: *UiState,
    win_flags: c_int,
    style_manager: *styles.StyleManager,
) !?actions.ModeAction {
    var open: bool = true;
    try imgui.SetConfigVar(.{ ctx, imgui.ConfigVar_WindowsMoveFromTitleBarOnly, 1.0 });
    const PopStyle = try styles_components.PushStyle(ctx, .main, style_manager);
    defer PopStyle(ctx) catch {};

    var rv: ?actions.ModeAction = null;

    try imgui.SetNextWindowDockID(.{ ctx, styles.Docker.BOTTOM });
    if (try imgui.Begin(.{ ctx, plugin_name, &open, win_flags })) {
        defer imgui.End(.{ctx}) catch {};
        const bar_result = try ButtonsBar(ctx, ui.translations);
        open = bar_result.open;
        if (bar_result.action) |action| {
            rv = action;
        }
        try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + 10 });
        switch (ui.state.current_mode) {
            .fx_ctrl => {
                if (try fx_ctrl_panel.drawFxControlPanel(ctx, ui, ui.translations)) |ctrl_input| {
                    rv = .{ .fx_ctrl = .{ .panel_input = ctrl_input } };
                }
                if (ui.preferences.show_track_list) {
                    try imgui.SameLine(.{ctx});

                    if (try track_list_panel.drawTrackListTwoColumns(ctx, ui.state, style_manager, ui.translations)) |tr_cc| {
                        switch (tr_cc) {
                            .Tr_pg_up => rv = .{ .track_list = .{ .page_change = .up } },
                            .Tr_pg_dn => rv = .{ .track_list = .{ .page_change = .down } },
                            else => {
                                const track_id = @backingInt(tr_cc) - @backingInt(c1.CCs.Tr_tr1);
                                if (track_id < ui.state.fx_ctrl.track_list.name_count) {
                                    const tr_id = ui.state.fx_ctrl.track_list.track_names[track_id].id;
                                    rv = .{ .track_list = .{ .track_select = tr_id } };
                                }
                            },
                        }
                    }
                }
            },
            .settings => {
                if (ui.settings_panel) |panel| {
                    if (try panel.draw(ctx, ui.mappings_list, style_manager, ui.translations)) |val| {
                        switch (val) {
                            .val_update => |update| rv = .{ .settings = .{ .update_val = update } },
                            .close_save => rv = .{ .settings = .save },
                            .close_cancel => rv = .{ .settings = .cancel },
                            .install_presets => rv = .{ .settings = .install_presets },
                        }
                    }
                }
            },
            .default_fx_sel => {
                if (ui.settings_panel) |panel| {
                    if (try panel.draw(ctx, ui.mappings_list, style_manager, ui.translations)) |val| {
                        switch (val) {
                            .val_update => |update| rv = .{ .settings = .{ .update_val = update } },
                            .close_save => rv = .{ .settings = .save },
                            .close_cancel => rv = .{ .settings = .cancel },
                            .install_presets => rv = .{ .settings = .install_presets },
                        }
                    }
                }
                const module = ui.state.default_fx_sel.current_category;
                const list = ui.mappings_list.list.get(module);
                const current_index = switch (ui.state.default_fx_sel.sub_mode) {
                    .browse_fx => ui.state.default_fx_sel.scroll_position_rel,
                    .select_mapping => |sel| sel.scroll_position_rel,
                };
                var default_hl = fx_sel_panel.HighlightConfig{
                    .current_index = current_index,
                    .scroll_changed = &ui.state.default_fx_sel.scroll_changed,
                    .g_drwls_splitter = ui.drwls_splitter,
                };
                if (try fx_sel_panel.ModulePopup(
                    ctx,
                    module,
                    list,
                    &ui.mappings_list.strings,
                    ui.state.default_fx_sel.sub_mode,
                    false,
                    style_manager,
                    ui.translations,
                    ui,
                    &default_hl,
                )) |sel_action| {
                    rv = .{ .fx_sel = sel_action };
                }
            },
            .fx_sel => {
                if (try fx_ctrl_panel.drawFxControlPanel(ctx, ui, ui.translations)) |ctrl_input| {
                    switch (ctrl_input.cc) {
                        .Out_Vol => rv = .{ .fx_sel = .{ .scroll = @intFromFloat(ctrl_input.value * 127.0) } },
                        .Out_solo => rv = .{ .fx_sel = .confirm },
                        .Out_mute => rv = switch (ui.state.fx_sel.sub_mode) {
                            .browse_fx => .{ .fx_sel = .close_browser },
                            .select_mapping => .{ .fx_sel = .back },
                        },
                        else => rv = .{ .fx_ctrl = .{ .panel_input = ctrl_input } },
                    }
                }

                if (ui.preferences.show_track_list) {
                    try imgui.SameLine(.{ctx});
                    if (try track_list_panel.drawTrackListTwoColumns(ctx, ui.state, style_manager, ui.translations)) |tr_cc| {
                        switch (tr_cc) {
                            .Tr_tr1 => rv = .{ .fx_sel = .{ .toggle_module_browser = .INPUT } },
                            .Tr_tr2 => rv = .{ .fx_sel = .{ .toggle_module_browser = .GATE } },
                            .Tr_tr3 => rv = .{ .fx_sel = .{ .toggle_module_browser = .EQ } },
                            .Tr_tr4 => rv = .{ .fx_sel = .{ .toggle_module_browser = .COMP } },
                            .Tr_tr5 => rv = .{ .fx_sel = .{ .toggle_module_browser = .OUTPT } },
                            .Tr_tr6 => rv = .{ .fx_sel = .{ .toggle_module_browser = .STRIP } },
                            else => {},
                        }
                    }
                }

                const module = ui.state.fx_sel.current_category;
                const list = ui.mappings_list.list.get(module);
                const current_index = switch (ui.state.fx_sel.sub_mode) {
                    .browse_fx => ui.state.fx_sel.scroll_position_rel,
                    .select_mapping => |sel| sel.scroll_position_rel,
                };
                var fx_hl = fx_sel_panel.HighlightConfig{
                    .current_index = current_index,
                    .scroll_changed = &ui.state.fx_sel.scroll_changed,
                    .g_drwls_splitter = ui.drwls_splitter,
                };
                if (try fx_sel_panel.ModulePopup(
                    ctx,
                    module,
                    list,
                    &ui.mappings_list.strings,
                    ui.state.fx_sel.sub_mode,
                    true,
                    style_manager,
                    ui.translations,
                    ui,
                    &fx_hl,
                )) |sel_action| {
                    rv = .{ .fx_sel = sel_action };
                }
            },
            .mapping_panel => {
                // Because the mapping panel widgets use PushClipRect and
                // custom draw list operations that crash when scrolled
                // off-screen in the main window, we render the mapping
                // panel in its own child region with independent scrolling.
                if (try imgui.BeginChild(.{ ctx, "##mapping_panel_content", 0, 0, null, imgui.WindowFlags_None })) {
                    const map_action: ?actions.MappingPanelAction = switch (ui.state.mapping_panel.mode) {
                        .browse => |*browse_state| try module_selection_panel.drawModuleSelectionPanel(
                            ctx,
                            browse_state,
                            ui.drwls_splitter,
                            ui.translations,
                        ),
                        .assign => |*assign_state| try mapping_panel.drawMappingPanel(
                            ctx,
                            ui.state,
                            assign_state,
                            ui.translations,
                        ),
                    };
                    if (map_action) |action| {
                        rv = .{ .mapping_panel = action };
                    }
                }
                imgui.EndChild(.{ctx}) catch {};
            },
            .transport => {
                if (try fx_ctrl_panel.drawFxControlPanel(ctx, ui, ui.translations)) |ctrl_input| {
                    const val: u8 = @intFromFloat(ctrl_input.value * 127.0);
                    switch (ctrl_input.cc) {
                        .Inpt_disp_mode => rv = .{ .change_mode = .fx_ctrl },
                        .Out_mute => rv = .set_fx_ctrl_gui,
                        .Inpt_disp_on => rv = .{ .fx_sel = .{ .toggle_module_browser = .INPUT } },
                        .Shp_shape => rv = .{ .fx_sel = .{ .toggle_module_browser = .GATE } },
                        .Tr_order => rv = .{ .fx_sel = .{ .toggle_module_browser = .OUTPT } },
                        .Tr_ext_sidechain => rv = .{ .settings = .open },
                        .Out_Vol => rv = .{ .transport = .{ .tr_sel = val } },
                        .Out_Drive => rv = .{ .transport = .{ .zoom_horizontal = val } },
                        .Out_DriveChar => rv = .{ .transport = .{ .zoom_vertical = val } },
                        .Out_Pan => rv = .{ .transport = .{ .grid = val } },
                        .Eq_eq => rv = .{ .fx_sel = .{ .toggle_module_browser = .EQ } },
                        .Eq_lp_shape => rv = .{ .transport = .loop_start },
                        .Eq_hp_shape => rv = .{ .transport = .loop_end },
                        .Eq_LoGain => rv = .{ .transport = .{ .scrub = val } },
                        .Eq_LoMidGain => rv = .{ .transport = .{ .jog = val } },
                        .Eq_HiMidGain => rv = .{ .transport = .{ .jog_marker = val } },
                        .Eq_HiGain => rv = .{ .transport = .{ .jog_item = val } },
                        .Comp_comp => rv = .{ .fx_sel = .{ .toggle_module_browser = .COMP } },
                        .Inpt_HiCut => rv = .{ .transport = .{ .rate = val } },
                        .Out_solo => rv = .{ .transport = .snap_tgl },
                        .Inpt_filt_to_comp => rv = .{ .transport = .play },
                        .Inpt_phase_inv => rv = .{ .transport = .stop },
                        .Inpt_preset => rv = .{ .transport = .rec },
                        else => {},
                    }
                }
                if (ui.preferences.show_track_list) {
                    try imgui.SameLine(.{ctx});

                    if (try track_list_panel.drawTrackListTwoColumns(ctx, ui.state, style_manager, ui.translations)) |tr_cc| {
                        switch (tr_cc) {
                            // Loop and marker set took the places of the browsers of the EQ and the compressor, which
                            // are at the top left of their cards in this mode.
                            .Tr_tr3 => rv = .{ .transport = .loop_toggle },
                            .Tr_tr4 => rv = .{ .transport = .marker_set },
                            .Tr_tr6 => rv = .{ .fx_sel = .{ .toggle_module_browser = .STRIP } },
                            .Tr_tr11 => rv = .{ .transport = .{ .automation_mode = .trim } },
                            .Tr_tr12 => rv = .{ .transport = .{ .automation_mode = .read } },
                            .Tr_tr13 => rv = .{ .transport = .{ .automation_mode = .latch } },
                            .Tr_tr14 => rv = .{ .transport = .{ .automation_mode = .preview } },
                            .Tr_tr15 => rv = .{ .transport = .{ .automation_mode = .write } },
                            else => {},
                        }
                    }
                }
            },
            else => {},
        }
    }
    if (try theme_editor.draw(ctx, style_manager)) |action| {
        switch (action) {
            .save => rv = .save_theme,
        }
    }

    // Add debug panel
    if (logger.debug_window_active) {
        try debug_panel.drawDebugPanel(ctx, ui.state);
    }

    if (!open)
        return error.WindowClosed;

    return rv;
}
