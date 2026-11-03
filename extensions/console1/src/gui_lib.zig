const std = @import("std");
const statemachine = @import("statemachine.zig");
const ModulesList = statemachine.ModulesList;
const imgui = @import("reaper_imgui");
const styles = @import("styles.zig");
const styles_components = @import("styles_components.zig");
const logger = @import("logger.zig");
const debug_panel = @import("debug_panel.zig");
const UiState = @import("ui_state.zig").UiState;
const fx_ctrl_panel = @import("fx_ctrl_panel.zig");
const fx_sel_panel = @import("fx_sel_panel.zig");
const actions = @import("action_types.zig");
const mapping_panel = @import("mapping_panel.zig");
const presets_panel = @import("presets_panel.zig");
const module_selection_panel = @import("module_selection_panel.zig");
const track_list_panel = @import("track_list_panel.zig");
const c1 = @import("c1.zig");
const theme_editor = @import("theme_editor.zig");

const plugin_name = "CONSOLE1";

pub const GuiError = error{
    WindowClosed,
};

/// What the row of the track list does while shift is held, which is what the shift of the controller does: the browser
/// of the plugins of a module on the first six rows, the creation of a mapping on the seventh, and the settings on the last one. It matches `shiftLabel`.
fn shiftAction(cc: c1.CCs) ?actions.ModeAction {
    return switch (cc) {
        .Tr_tr1 => .{ .fx_sel = .{ .toggle_module_browser = .STRIP } },
        .Tr_tr2 => .{ .fx_sel = .{ .toggle_module_browser = .GATE } },
        .Tr_tr3 => .{ .fx_sel = .{ .toggle_module_browser = .EQ } },
        .Tr_tr4 => .{ .fx_sel = .{ .toggle_module_browser = .COMP } },
        .Tr_tr5 => .{ .fx_sel = .{ .toggle_module_browser = .INPUT } },
        .Tr_tr6 => .{ .fx_sel = .{ .toggle_module_browser = .OUTPT } },
        .Tr_tr7 => .{ .mapping_panel = .create_mapping },
        .Tr_tr20 => .{ .settings = .open },
        else => null,
    };
}

/// How much of a tick the drag of a jog knob has made, for each knob.
var jog_progress: [128]f64 = @splat(0);

/// How far a jog knob is dragged, in the 127 steps of its position, for one tick.
const jog_tick_steps = 2.0;

/// The tick that the drag of a jog knob of the panel makes in this frame, if it makes one. `value` is where the drag put the knob, and
/// `position` is where the knob was: their difference is what the mouse moved it by in this frame, which is added to what the knob
/// has moved since its last tick. A tick is one step of the console's knob, a finer one while shift is held.
pub fn jogTick(shift_held: bool, cc: c1.CCs, value: f64, position: u8) ?actions.ModeAction {
    const progress = &jog_progress[@backingInt(cc)];
    progress.* += value * 127.0 - @as(f64, @floatFromInt(position));
    const direction: i8 = if (progress.* >= jog_tick_steps) 1 else if (progress.* <= -jog_tick_steps) -1 else return null;
    progress.* -= @as(f64, @floatFromInt(direction)) * jog_tick_steps;
    return .{ .transport = .{ .knob_by = .{ .cc = cc, .delta = direction, .fine = shift_held } } };
}

/// The mapping panel, in its own child region with independent scrolling. Because its widgets use PushClipRect and custom draw
/// list operations that crash when scrolled off-screen in the main window, it is not drawn in the window itself.
fn drawMappingContent(ctx: imgui.ContextPtr, ui: *UiState, rv: *?actions.ModeAction) !void {
    if (try imgui.BeginChild(.{ ctx, "##mapping_panel_content", 0, 0, null, imgui.WindowFlags_None })) {
        const map_action: ?actions.MappingPanelAction = switch (ui.state.mapping_panel.mode) {
            .browse => |*browse_state| try module_selection_panel.drawModuleSelectionPanel(
                ctx,
                browse_state,
                ui.drwls_splitter,
                ui.translations,
            ),
            .assign => |*assign_set| try mapping_panel.drawMappingPanel(
                ctx,
                assign_set,
                ui.translations,
            ),
        };
        if (map_action) |action| {
            rv.* = .{ .mapping_panel = action };
        }
    }
    imgui.EndChild(.{ctx}) catch {};
}

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

    try imgui.SetNextWindowDockID(.{ ctx, styles.Docker.BOTTOM, imgui.Cond_FirstUseEver });
    if (try imgui.Begin(.{ ctx, plugin_name, &open, win_flags })) {
        defer imgui.End(.{ctx}) catch {};
        try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + 10 });
        switch (ui.state.current_mode) {
            .fx_ctrl => {
                if (try fx_ctrl_panel.drawFxControlPanel(ctx, ui, ui.translations)) |ctrl_input| {
                    // While shift is held, the Preset button saves a preset, which is the alternative that it shows.
                    if (ctrl_input.cc == .Inpt_preset and ui.shift_held) {
                        rv = .{ .presets = .{ .enter = .save } };
                    } else {
                        rv = .{ .fx_ctrl = .{ .panel_input = ctrl_input } };
                    }
                }
                if (ui.preferences.show_track_list) {
                    try imgui.SameLine(.{ctx});

                    if (try track_list_panel.drawTrackListTwoColumns(ctx, ui.state, ui.shift_held, style_manager, ui.translations)) |tr_cc| {
                        switch (tr_cc) {
                            .Tr_pg_up => rv = .{ .track_list = .{ .page_change = .up } },
                            .Tr_pg_dn => rv = .{ .track_list = .{ .page_change = .down } },
                            else => {
                                // While shift is held, a row that shows an alternative use does that use.
                                if (ui.shift_held and shiftAction(tr_cc) != null) {
                                    rv = shiftAction(tr_cc);
                                } else {
                                    const track_id = @backingInt(tr_cc) - @backingInt(c1.CCs.Tr_tr1);
                                    if (track_id < ui.state.fx_ctrl.track_list.name_count) {
                                        const tr_id = ui.state.fx_ctrl.track_list.track_names[track_id].id;
                                        rv = .{ .track_list = .{ .track_select = tr_id } };
                                    }
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
                // Because the browser that was opened from the assignment of a module is a step of the mapping, the mapping panel stays
                // in the window under it, and the panel of the FX controls does not take its place.
                if (ui.state.fx_sel.return_to_mapping and std.meta.activeTag(ui.state.mapping_panel.mode) == .assign) {
                    try drawMappingContent(ctx, ui, &rv);
                } else {
                    if (try fx_ctrl_panel.drawFxControlPanel(ctx, ui, ui.translations)) |ctrl_input| {
                        switch (ctrl_input.cc) {
                            .Out_Vol => rv = .{ .fx_sel = .{ .scroll = @intFromFloat(ctrl_input.value * 127.0) } },
                            .Out_solo => rv = .{ .fx_sel = .confirm },
                            // Cancel steps out of a menu, or out of the mappings of a plugin, before it closes the browser.
                            .Out_mute => rv = if (ui.state.fx_sel.menu_depth > 0 or ui.state.fx_sel.sub_mode == .select_mapping)
                                .{ .fx_sel = .back }
                            else
                                .{ .fx_sel = .close_browser },
                            else => rv = .{ .fx_ctrl = .{ .panel_input = ctrl_input } },
                        }
                    }

                    if (ui.preferences.show_track_list) {
                        try imgui.SameLine(.{ctx});
                        if (try track_list_panel.drawTrackListTwoColumns(ctx, ui.state, ui.shift_held, style_manager, ui.translations)) |tr_cc| {
                            switch (tr_cc) {
                                .Tr_tr1 => rv = .{ .fx_sel = .{ .toggle_module_browser = .INPUT } },
                                .Tr_tr2 => rv = .{ .fx_sel = .{ .toggle_module_browser = .GATE } },
                                .Tr_tr3 => rv = .{ .fx_sel = .{ .toggle_module_browser = .EQ } },
                                .Tr_tr4 => rv = .{ .fx_sel = .{ .toggle_module_browser = .COMP } },
                                .Tr_tr5 => rv = .{ .fx_sel = .{ .toggle_module_browser = .OUTPT } },
                                .Tr_tr6 => rv = .{ .fx_sel = .{ .toggle_module_browser = .STRIP } },
                                .Tr_tr20 => rv = .{ .settings = .open },
                                else => {},
                            }
                        }
                    }
                }

                const module = ui.state.fx_sel.current_category;
                const list = ui.mappings_list.list.get(module);
                const current_index = switch (ui.state.fx_sel.sub_mode) {
                    // Because the browser has levels, the cursor is the one of the level that is open.
                    .browse_fx => ui.state.fx_sel.cursorPtr().*,
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
            .mapping_panel => try drawMappingContent(ctx, ui, &rv),
            .presets => {
                if (try imgui.BeginChild(.{ ctx, "##presets_content", 0, 0, null, imgui.WindowFlags_None })) {
                    if (try presets_panel.drawPresetsPanel(ctx, &ui.state.presets, ui.drwls_splitter, ui.translations)) |presets_action| {
                        rv = .{ .presets = presets_action };
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
                        .Out_Vol => rv = .{ .transport = .{ .tr_sel = val } },
                        .Out_Drive => rv = .{ .transport = .{ .zoom_horizontal = val } },
                        .Out_DriveChar => rv = .{ .transport = .{ .zoom_vertical = val } },
                        .Out_Pan => rv = .{ .transport = .{ .grid = val } },
                        .Eq_lp_shape => rv = .{ .transport = .loop_toggle },
                        // The button starts the loop, and ends it while shift is held on the controller.
                        .Eq_hp_shape => rv = .{ .transport = if (ui.shift_held) .loop_end else .loop_start },
                        // Because the knobs of the jogs turn the way the knobs of the console do, they send ticks, as the console does, and
                        // not the position of the knob: the drag of the mouse is cut into ticks.
                        .Eq_LoGain => if (jogTick(ui.shift_held, .Eq_LoGain, ctrl_input.value, ui.state.transport.scrub)) |tick| {
                            rv = tick;
                        },
                        .Eq_LoMidGain => if (jogTick(ui.shift_held, .Eq_LoMidGain, ctrl_input.value, ui.state.transport.jog)) |tick| {
                            rv = tick;
                        },
                        .Comp_Attack => if (jogTick(ui.shift_held, .Comp_Attack, ctrl_input.value, ui.state.transport.jog_marker)) |tick| {
                            rv = tick;
                        },
                        .Eq_HiGain => if (jogTick(ui.shift_held, .Eq_HiGain, ctrl_input.value, ui.state.transport.jog_item)) |tick| {
                            rv = tick;
                        },
                        .Comp_comp => rv = .{ .transport = .marker_set },
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

                    if (try track_list_panel.drawTrackListTwoColumns(ctx, ui.state, ui.shift_held, style_manager, ui.translations)) |tr_cc| {
                        switch (tr_cc) {
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

test "the drag of a jog knob is cut into ticks, each in the direction of the drag, and a finer one with shift" {
    jog_progress = @splat(0);
    // A drag that is shorter than a tick makes none, and the rest is kept for the next frame.
    try std.testing.expect(jogTick(false, .Eq_LoMidGain, 61.0 / 127.0, 60) == null);
    const up = jogTick(false, .Eq_LoMidGain, 62.0 / 127.0, 60).?;
    try std.testing.expectEqual(@as(i8, 1), up.transport.knob_by.delta);
    try std.testing.expectEqual(c1.CCs.Eq_LoMidGain, up.transport.knob_by.cc);
    try std.testing.expect(!up.transport.knob_by.fine);

    // The other way, with shift.
    jog_progress = @splat(0);
    const down = jogTick(true, .Eq_HiGain, 56.0 / 127.0, 60).?;
    try std.testing.expectEqual(@as(i8, -1), down.transport.knob_by.delta);
    try std.testing.expect(down.transport.knob_by.fine);

    // A knob that does not move makes no tick, and each knob keeps its own progress.
    jog_progress = @splat(0);
    _ = jogTick(false, .Eq_LoGain, 61.0 / 127.0, 60);
    try std.testing.expect(jogTick(false, .Eq_HiGain, 60.0 / 127.0, 60) == null);
}
