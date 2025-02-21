const std = @import("std");
const ModulesList = @import("statemachine.zig").ModulesList;
const imgui = @import("reaper_imgui.zig");
const Reaper = @import("reaper.zig");
const reaper = Reaper.reaper;
const styles = @import("styles.zig");
const logger = @import("logger.zig");
const debug_panel = @import("debug_panel.zig");
const Globals = @import("globals.zig").Globals;
const extension = @import("console1_extension.zig");
const fx_ctrl_panel = @import("fx_ctrl_panel.zig");
const SettingsPanel = @import("settings_panel.zig");
const ButtonsBar = @import("ButtonsBar.zig").ButtonsBar;
const fxParser = @import("fx_parser.zig");
const fx_sel_panel = @import("fx_sel_panel.zig");
const actions = @import("actions.zig");
const mapping_panel = @import("mapping_panel.zig");
const Theme = @import("theme/Theme.zig");
const track_list_panel = @import("track_list_panel.zig");
const c1 = @import("c1.zig");

const log = std.log.scoped(.imgui_loop);
const plugin_name = "CONSOLE1";
pub var ctx: imgui.ContextPtr = null;
var text = std.mem.zeroes([255:0]u8);
var windowFlags: c_int = undefined;
var imgui_init: bool = false;
fn init() !void {
    // try imgui.init(reaper.plugin_getapi);
    imgui.init(reaper.plugin_getapi) catch |err| {
        log.err("Failed to initialize ImGui: {s}\n", .{@errorName(err)});
        return err;
    };

    const ctx_flags = imgui.ConfigFlags_DockingEnable;
    ctx = try imgui.CreateContext(.{ plugin_name, ctx_flags });

    // only query the theme upon first run
    try Theme.init(ctx, true);

    windowFlags =
        imgui.WindowFlags_NoCollapse +
        imgui.WindowFlags_NoTitleBar +
        imgui.WindowFlags_NoNav + imgui.WindowFlags_NoFocusOnAppearing;
    try styles.init(ctx);

    imgui_init = true;
}

var buf: [128:0]u8 = undefined;

fn main(globals: *Globals) !?actions.ModeAction {
    if (ctx == null) {
        try init();
    }

    var open: bool = true;
    try imgui.SetConfigVar(.{ ctx, imgui.ConfigVar_WindowsMoveFromTitleBarOnly, 1.0 });
    const PopStyle = try styles.PushStyle(ctx, .rack);
    defer PopStyle(ctx) catch {};

    var rv: ?actions.ModeAction = null;

    try imgui.SetNextWindowDockID(.{ ctx, styles.Docker.BOTTOM });
    if (try imgui.Begin(.{ ctx, plugin_name, &open, windowFlags })) {
        defer imgui.End(.{ctx}) catch {};
        open = try ButtonsBar(ctx, globals);
        try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + 10 });
        if (styles.rack_style_open) {
            try styles.StyleEditor(ctx, .rack);
        }
        if (styles.main_style_open) {
            try styles.StyleEditor(ctx, .main);
        }
        switch (globals.state.current_mode) {
            .fx_ctrl => {
                if (try fx_ctrl_panel.drawFxControlPanel(ctx, globals)) |ctrl_input| {
                    rv = .{ .fx_ctrl = .{ .panel_input = ctrl_input } };
                }
                if (globals.preferences.show_track_list) {
                    try imgui.SameLine(.{ctx});
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + 20 });

                    if (try track_list_panel.drawTrackListTwoColumns(ctx, &globals.state)) |tr_cc| {
                        const track_id = @intFromEnum(tr_cc) - @intFromEnum(c1.CCs.Tr_tr1);
                        if (track_id < globals.state.fx_ctrl.track_list.name_count) {
                            const tr_id = globals.state.fx_ctrl.track_list.track_names[track_id].id;
                            rv = .{ .track_list = .{ .track_select = tr_id } };
                        }
                    }
                }
            },
            .settings => {
                if (globals.settings_panel) |*panel| {
                    if (try panel.draw(ctx, &globals.mappings_list)) |val| {
                        switch (val) {
                            .val_update => |update| rv = .{ .midi_out = .{ .settings_changed = update } },
                            .close_save => rv = .{ .settings = .save },
                            .close_cancel => rv = .{ .settings = .cancel },
                        }
                    }
                }
            },
            .default_fx_sel => {
                if (globals.settings_panel) |*panel| {
                    if (try panel.draw(ctx, &globals.mappings_list)) |val| {
                        switch (val) {
                            .val_update => |update| rv = .{ .midi_out = .{ .settings_changed = update } },
                            .close_save => rv = .{ .settings = .save },
                            .close_cancel => rv = .{ .settings = .cancel },
                        }
                    }
                }
                const module = globals.state.default_fx_sel.current_category;
                const list = globals.mappings_list.list.get(module);
                if (try fx_sel_panel.ModulePopup(ctx, module, list, globals.state.default_fx_sel.scroll_position_rel, false, &globals.drwls_splitter)) |sel_action| {
                    rv = .{ .fx_sel = sel_action };
                }
            },
            .fx_sel => {
                if (try fx_ctrl_panel.drawFxControlPanel(ctx, globals)) |ctrl_input| {
                    switch (ctrl_input.cc) {
                        .Out_Vol => rv = .{ .fx_sel = .{ .scroll = @intFromFloat(ctrl_input.value * 127.0) } },
                        .Out_solo => {
                            const mappings = globals.mappings_list.list.get(globals.state.fx_sel.current_category);
                            const fx_name = mappings.unmanaged.keys()[globals.state.fx_sel.scroll_position_rel];
                            rv = .{ .fx_sel = .{ .plugin = .{ .name = @ptrCast(fx_name) } } };
                        },
                        .Out_mute => rv = .{ .fx_sel = .close_browser },
                        else => {},
                    }
                }

                if (globals.preferences.show_track_list) {
                    try imgui.SameLine(.{ctx});
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + 20 });
                    if (try track_list_panel.drawTrackListTwoColumns(ctx, &globals.state)) |tr_cc| {
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
                if (try fx_sel_panel.ModulePopup(ctx, module, list, globals.state.fx_sel.scroll_position_rel, true, &globals.drwls_splitter)) |sel_action| {
                    rv = .{ .fx_sel = sel_action };
                }
            },
            .mapping_panel => {
                if (try mapping_panel.drawMappingPanel(ctx, globals)) |map_action| {
                    rv = .{ .mapping = map_action };
                }
            },
            .transport => {
                if (try fx_ctrl_panel.drawFxControlPanel(ctx, globals)) |ctrl_input| {
                    const val: u8 = @intFromFloat(ctrl_input.value * 127.0);
                    switch (ctrl_input.cc) {
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

                    if (try track_list_panel.drawTrackListTwoColumns(ctx, &globals.state)) |tr_cc| {
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
        try debug_panel.drawDebugPanel(ctx, &globals.state, &globals.event_log);
    }

    if (!open)
        reset();

    return rv;
}

pub fn register() void {
    _ = reaper.plugin_register("timer", @constCast(@ptrCast(&onTimer)));
}

pub fn reset() void {
    ctx = null;
    _ = reaper.plugin_register("-timer", @constCast(@ptrCast(&onTimer)));
}

fn onTimer() callconv(.C) void {
    var globals = extension.getGlobals();
    _ = &globals;
    if (main(globals)) |maybe_action| {
        if (maybe_action) |action| {
            actions.dispatch(globals, action);
        }
    } else |err| {
        reset();
        log.err("Error in main loop: {s}\n", .{@errorName(err)});

        if (imgui.last_error) |last_err| {
            log.err("last_error: {s}", .{std.mem.span(last_err)});
        }

        if (err == error.Imgui) {
            _ = reaper.ShowMessageBox("ImGui error occurred", plugin_name, 0);
        }
        actions.dispatch(globals, .{ .change_mode = .fx_ctrl });
    }
}
