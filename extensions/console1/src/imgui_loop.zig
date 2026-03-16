const builtin = @import("builtin");
const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Reaper = @import("reaper.zig");
const reaper = Reaper.reaper;
const styles = @import("styles.zig");
const extension = @import("console1_extension.zig");
const actions = @import("actions.zig");
const Theme = @import("theme/Theme.zig");
const reapack = @import("reapack.zig");
const HotReloader = @import("hotreload.zig").HotReloader;
const UiState = @import("ui_state.zig").UiState;
const fx_parser = @import("fx_parser.zig");

const log = std.log.scoped(.imgui_loop);
const plugin_name = "CONSOLE1";
pub var ctx: imgui.ContextPtr = null;
var win_flags: c_int = undefined;
var hot_reloader: ?HotReloader = null;

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

    if (!builtin.is_test) {
        buildUiLibPath();
        const path: [:0]const u8 = std.mem.sliceTo(&ui_lib_path_buf, 0);
        hot_reloader = HotReloader.init(path, @ptrCast(reaper.plugin_getapi));
    }
}

const ui_lib_name = if (@import("builtin").os.tag == .macos) "/reaper_c1_ui.dylib" else "/reaper_c1_ui.so";
var ui_lib_path_buf: [std.fs.max_path_bytes:0]u8 = undefined;

fn buildUiLibPath() void {
    const resource_path = std.mem.span(reaper.GetResourcePath());
    const result = std.fmt.bufPrint(&ui_lib_path_buf, "{s}/UserPlugins{s}", .{
        resource_path,
        ui_lib_name,
    }) catch return;
    ui_lib_path_buf[result.len] = 0;
    log.info("UI lib path: {s}", .{ui_lib_path_buf[0..result.len]});
}

pub fn register() void {
    if (comptime builtin.is_test) {
        return;
    }
    if (isImGuiAvailable()) {
        _ = reaper.plugin_register("timer", @constCast(@ptrCast(&onTimer)));
    } else {
        promptInstallImGui();
    }
}

pub fn reset() void {
    if (comptime builtin.is_test) {
        return;
    }
    if (ctx) |context| {
        const mainFontResource: imgui.ResourcePtr = @ptrCast(Theme.fonts.MAIN);
        imgui.Detach(.{ context, mainFontResource }) catch {};

        const fontelloResource: imgui.ResourcePtr = @ptrCast(Theme.fonts.ICON_FONT_SMALL);
        imgui.Detach(.{ context, fontelloResource }) catch {};
    }

    if (hot_reloader) |*reloader| {
        reloader.deinit();
    }
    hot_reloader = null;

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

/// Allow loading all other extensions prior to starting the gui
var ready = false;

fn onTimer() callconv(.C) void {
    if (!ready) {
        ready = true;
        return;
    }
    var globals = extension.getGlobals();
    _ = &globals;
    if (ctx == null) {
        init() catch |err| handleGuiError(err);
    }
    var style_manager: styles.StyleManager = .{
        .main_style_open = &styles.main_style_open,
        .rack_style_open = &styles.rack_style_open,
        .RackStyle = &styles.RackStyle,
        .MainWinStyle = &styles.MainWinStyle,
    };

    var ui_state = UiState{
        .state = &globals.state,
        .translations = &globals.translations,
        .drwls_splitter = &globals.drwls_splitter,
        .mappings_list = &globals.mappings_list,
        .settings_panel = if (globals.settings_panel) |*panel| panel else null,
        .preferences = &globals.preferences,
        .midi_connected = globals.m_midi_in != null,
        .main_font = Theme.fonts.MAIN,
        .icon_font = Theme.fonts.ICON_FONT_SMALL,
        .fx_plugins_by_type = &fx_parser.pluginsByType,
        .fx_chains = &fx_parser.fx_chains,
        .track_templates = &fx_parser.track_templates,
        .fx_tags = &fx_parser.fx_tags,
    };

    if (hot_reloader) |*reloader| {
        const result = reloader.render(ctx, win_flags, &ui_state, &style_manager);
        switch (result) {
            .action => |action| actions.dispatch(globals, action),
            .render_error => handleGuiError(error.WindowClosed),
            .no_action => {},
        }
    }
}

fn promptInstallImGui() void {
    // 0=OK,1=OKCANCEL,2=ABORTRETRYIGNORE,3=YESNOCANCEL,4=YESNO,5=RETRYCANCEL : ret
    _ = reaper.ShowMessageBox(
        "This extension requires ReaImGui to function fully.\nPlease install it via ReaPack.\n",
        "Missing Dependency",
        0,
    );

    reapack.init(reaper.plugin_getapi) catch {
        _ = reaper.ShowMessageBox(
            "ReaPack is not installed. Please install ReaPack first, then install ReaImGui.\n",
            "Missing Dependencies",
            0,
        );
        return;
    };
    reapack.ReaPack_BrowsePackages("Dear ImGui");
}

fn isImGuiAvailable() bool {
    // Attempt to initialize ImGui and detect if it's available
    imgui.init(reaper.plugin_getapi) catch {
        if (imgui.getError.?()) |err_msg| {
            std.debug.print("imgui err: {s}\n ", .{std.mem.span(err_msg)});
            return false;
        }
        return false;
    };
    return true;
}
