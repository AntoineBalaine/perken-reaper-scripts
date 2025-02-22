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
var win_flags: c_int = undefined;

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

    win_flags =
        imgui.WindowFlags_NoCollapse +
        imgui.WindowFlags_NoTitleBar +
        imgui.WindowFlags_NoNav + imgui.WindowFlags_NoFocusOnAppearing;
    try styles.init(ctx);
}

pub fn register() void {
    _ = reaper.plugin_register("timer", @constCast(@ptrCast(&onTimer)));
}

pub fn reset() void {
    ctx = null;
    _ = reaper.plugin_register("-timer", @constCast(@ptrCast(&onTimer)));
}

fn handleGuiError(err: anyerror) void {
    reset();

    if (err == error.WindowClosed) {
        return;
    }

    // Handle actual errors
    log.err("Error in main loop: {s}\n", .{@errorName(err)});
    if (imgui.last_error) |last_err| {
        log.err("last_error: {s}", .{std.mem.span(last_err)});
    }
    if (err == error.Imgui) {
        _ = reaper.ShowMessageBox("ImGui error occurred", plugin_name, 0);
    }
    actions.dispatch(extension.getGlobals(), .{ .change_mode = .fx_ctrl });
}

fn onTimer() callconv(.C) void {
    var globals = extension.getGlobals();
    _ = &globals;
    if (ctx == null) {
        init() catch |err| handleGuiError(err);
    }
    if (@import("gui_lib.zig").main(ctx, globals, win_flags)) |maybe_action| {
        if (maybe_action) |action| {
            actions.dispatch(globals, action);
        }
    } else |err| {
        handleGuiError(err);
    }
}
