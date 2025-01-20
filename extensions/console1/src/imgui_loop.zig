const std = @import("std");

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

const log = std.log.scoped(.imgui_loop);
const plugin_name = "CONSOLE1";
pub var allocator: std.mem.Allocator = undefined;
var ctx: imgui.ContextPtr = null;
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
                    if (try track_list_panel.drawTrackList(ctx, &globals.state)) |track_number| {
                        actions.dispatch(
                            &globals.state,
                            .{ .track_list = .{ .track_select = @as(u8, @intCast(track_number)) } },
                        );
                    }
                }
            },
            .settings => {
                if (globals.settings_panel) |*panel| {
                    switch (panel.draw(ctx) catch |err| {
                        log.err("Error drawing settings panel: {s}", .{@errorName(err)});
                        return err;
                    }) {
                        .stay_open => {},
                        .close_save => {
                            actions.dispatch(&globals.state, .{ .settings = .save });
                        },
                        .close_cancel => {
                            actions.dispatch(&globals.state, .{ .settings = .cancel });
                        },
                    }
                }
            },
            .fx_sel => {
                if (try fx_ctrl_panel.drawFxControlPanel(ctx, &globals.state)) |ctrl_input| {
                    actions.dispatch(&globals.state, .{ .fx_ctrl = .{ .panel_input = ctrl_input } });
                }
                const module = globals.state.fx_sel.current_category;
                const list = switch (module) {
                    .INPUT => globals.mappings_list.list.get(.INPUT),
                    .GATE => globals.mappings_list.list.get(.GATE),
                    .EQ => globals.mappings_list.list.get(.EQ),
                    .COMP => globals.mappings_list.list.get(.COMP),
                    .OUTPT => globals.mappings_list.list.get(.OUTPT),
                };

                if (!try fx_sel_panel.ModulePopup(ctx, module, list, globals.state.fx_sel.scroll_position_rel)) {
                    actions.dispatch(&globals.state, .{ .fx_sel = .close_browser });
                }
            },
            .mapping_panel => {
                try mapping_panel.drawMappingPanel(ctx, &globals.state);
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
    main() catch {
        reset();
        _ = reaper.ShowMessageBox(imgui.last_error.?, plugin_name, 0);
    };
}
