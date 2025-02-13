const std = @import("std");
const ModulesList = @import("statemachine.zig").ModulesList;
const imgui = @import("reaper_imgui.zig");
const Reaper = @import("reaper.zig");
const reaper = Reaper.reaper;
const styles = @import("styles.zig");
const logger = @import("logger.zig");
const debug_panel = @import("debug_panel.zig");
const globals = @import("globals.zig");
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

fn main() !void {
    if (ctx == null) {
        try init();
    }

    var open: bool = true;

    try imgui.SetConfigVar(.{ ctx, imgui.ConfigVar_WindowsMoveFromTitleBarOnly, 1.0 });
    const PopStyle = try styles.PushStyle(ctx, .rack);
    defer PopStyle(ctx) catch {};

    try imgui.SetNextWindowDockID(.{ ctx, styles.Docker.BOTTOM });
    if (try imgui.Begin(.{ ctx, plugin_name, &open, windowFlags })) {
        defer imgui.End(.{ctx}) catch {};
        open = try ButtonsBar(ctx);
        try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + 10 });
        if (styles.rack_style_open) {
            try styles.StyleEditor(ctx, .rack);
        }
        if (styles.main_style_open) {
            try styles.StyleEditor(ctx, .main);
        }
        switch (globals.state.current_mode) {
            .fx_ctrl => {
                if (try fx_ctrl_panel.drawFxControlPanel(ctx, &globals.state)) |ctrl_input| {
                    actions.dispatch(&globals.state, .{ .fx_ctrl = .{ .panel_input = ctrl_input } });
                }
                if (globals.preferences.show_track_list) {
                    try imgui.SameLine(.{ctx});
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + 20 });

                    if (try track_list_panel.drawTrackListTwoColumns(ctx, &globals.state)) |tr_cc| {
                        const track_id = @intFromEnum(tr_cc) - @intFromEnum(c1.CCs.Tr_tr1);
                        if (track_id < globals.state.fx_ctrl.track_list.name_count) {
                            const tr_id = globals.state.fx_ctrl.track_list.track_names[track_id].id;
                            actions.dispatch(&globals.state, .{ .track_list = .{ .track_select = tr_id } });
                        }
                    }
                }
            },
            .settings => {
                if (globals.settings_panel) |*panel| {
                    if (try panel.draw(ctx)) |val| {
                        switch (val) {
                            .val_update => |update| actions.dispatch(&globals.state, .{ .midi_out = .{ .settings_changed = update } }),
                            .close_save => actions.dispatch(&globals.state, .{ .settings = .save }),
                            .close_cancel => actions.dispatch(&globals.state, .{ .settings = .cancel }),
                        }
                    }
                }
            },
            .default_fx_sel => {
                if (globals.settings_panel) |*panel| {
                    if (try panel.draw(ctx)) |val| {
                        switch (val) {
                            .val_update => |update| actions.dispatch(&globals.state, .{ .midi_out = .{ .settings_changed = update } }),
                            .close_save => actions.dispatch(&globals.state, .{ .settings = .save }),
                            .close_cancel => actions.dispatch(&globals.state, .{ .settings = .cancel }),
                        }
                    }
                }
                const module = globals.state.default_fx_sel.current_category;
                const list = globals.mappings_list.list.get(module);
                if (try fx_sel_panel.ModulePopup(ctx, module, list, globals.state.default_fx_sel.scroll_position_rel, false)) |sel_action| {
                    actions.dispatch(&globals.state, .{ .fx_sel = sel_action });
                }
            },
            .fx_sel => {
                if (try fx_ctrl_panel.drawFxControlPanel(ctx, &globals.state)) |ctrl_input| {
                    switch (ctrl_input.cc) {
                        .Out_Vol => actions.dispatch(&globals.state, .{ .fx_sel = .{ .scroll = @intFromFloat(ctrl_input.value * 127.0) } }),
                        .Out_solo => {
                            const mappings = globals.mappings_list.list.get(globals.state.fx_sel.current_category);
                            const fx_name = mappings.unmanaged.keys()[globals.state.fx_sel.scroll_position_rel];
                            actions.dispatch(&globals.state, .{ .fx_sel = .{ .plugin = .{ .name = @ptrCast(fx_name) } } });
                        },
                        .Out_mute => actions.dispatch(&globals.state, .{ .fx_sel = .close_browser }),
                        else => {},
                    }
                }

                if (globals.preferences.show_track_list) {
                    try imgui.SameLine(.{ctx});
                    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + 20 });
                    if (try track_list_panel.drawTrackListTwoColumns(ctx, &globals.state)) |tr_cc| {
                        switch (tr_cc) {
                            .Tr_tr1 => actions.dispatch(&globals.state, .{ .fx_sel = .{ .toggle_module_browser = .INPUT } }),
                            .Tr_tr2 => actions.dispatch(&globals.state, .{ .fx_sel = .{ .toggle_module_browser = .GATE } }),
                            .Tr_tr3 => actions.dispatch(&globals.state, .{ .fx_sel = .{ .toggle_module_browser = .EQ } }),
                            .Tr_tr4 => actions.dispatch(&globals.state, .{ .fx_sel = .{ .toggle_module_browser = .COMP } }),
                            .Tr_tr5 => actions.dispatch(&globals.state, .{ .fx_sel = .{ .toggle_module_browser = .OUTPT } }),
                            else => {},
                        }
                    }
                }

                const module = globals.state.fx_sel.current_category;
                const list = globals.mappings_list.list.get(module);
                if (try fx_sel_panel.ModulePopup(ctx, module, list, globals.state.fx_sel.scroll_position_rel, true)) |sel_action| {
                    actions.dispatch(&globals.state, .{ .fx_sel = sel_action });
                }
            },
            .mapping_panel => {
                if (try mapping_panel.drawMappingPanel(ctx, &globals.state)) |map_action| {
                    actions.dispatch(&globals.state, .{ .mapping = map_action });
                }
            },
            .transport => {
                if (try fx_ctrl_panel.drawFxControlPanel(ctx, &globals.state)) |ctrl_input| {
                    const val: u8 = @intFromFloat(ctrl_input.value * 127.0);
                    switch (ctrl_input.cc) {
                        .Out_Vol => actions.dispatch(&globals.state, .{ .transport = .{ .tr_sel = val } }),
                        .Out_Drive => actions.dispatch(&globals.state, .{ .transport = .{ .zoom_horizontal = val } }),
                        .Out_DriveChar => actions.dispatch(&globals.state, .{ .transport = .{ .zoom_vertical = val } }),
                        .Out_Pan => actions.dispatch(&globals.state, .{ .transport = .{ .grid = val } }),
                        .Eq_eq => actions.dispatch(&globals.state, .{ .transport = .loop_toggle }),
                        .Eq_lp_shape => actions.dispatch(&globals.state, .{ .transport = .loop_start }),
                        .Eq_hp_shape => actions.dispatch(&globals.state, .{ .transport = .loop_end }),
                        .Eq_LoGain => actions.dispatch(&globals.state, .{ .transport = .{ .scrub = val } }),
                        .Eq_LoMidGain => actions.dispatch(&globals.state, .{ .transport = .{ .jog = val } }),
                        .Eq_HiMidGain => actions.dispatch(&globals.state, .{ .transport = .{ .jog_marker = val } }),
                        .Eq_HiGain => actions.dispatch(&globals.state, .{ .transport = .{ .jog_item = val } }),
                        .Comp_comp => actions.dispatch(&globals.state, .{ .transport = .marker_set }),
                        .Inpt_HiCut => actions.dispatch(&globals.state, .{ .transport = .{ .rate = val } }),
                        .Out_solo => actions.dispatch(&globals.state, .{ .transport = .snap_tgl }),
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
                                actions.dispatch(&globals.state, .{ .fx_sel = .{ .toggle_module_browser = module } });
                            },
                            .Tr_tr6 => actions.dispatch(&globals.state, .{ .transport = .{ .automation_mode = .trim } }),
                            .Tr_tr7 => actions.dispatch(&globals.state, .{ .transport = .{ .automation_mode = .read } }),
                            .Tr_tr8 => actions.dispatch(&globals.state, .{ .transport = .{ .automation_mode = .latch } }),
                            .Tr_tr9 => actions.dispatch(&globals.state, .{ .transport = .{ .automation_mode = .preview } }),
                            .Tr_tr10 => actions.dispatch(&globals.state, .{ .transport = .{ .automation_mode = .write } }),
                            .Tr_tr17 => actions.dispatch(&globals.state, .{ .transport = .play }),
                            .Tr_tr18 => actions.dispatch(&globals.state, .{ .transport = .stop }),
                            .Tr_tr19 => actions.dispatch(&globals.state, .{ .transport = .rec }),
                            .Tr_tr20 => actions.dispatch(&globals.state, .{ .settings = .open }),
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
}

pub fn register() void {
    _ = reaper.plugin_register("timer", @constCast(@ptrCast(&onTimer)));
}

pub fn reset() void {
    ctx = null;
    _ = reaper.plugin_register("-timer", @constCast(@ptrCast(&onTimer)));
}

fn onTimer() callconv(.C) void {
    main() catch |err| {
        reset();
        log.err("Error in main loop: {s}\n", .{@errorName(err)});
        if (err == error.Imgui or imgui.last_error != null) {
            const msg: [:0]const u8 = "ImGui error occurred";
            _ = reaper.ShowMessageBox(msg, plugin_name, 0);
        }
        actions.dispatch(&globals.state, .{ .change_mode = .fx_ctrl });
    };
}
