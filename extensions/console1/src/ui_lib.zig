const imgui = @import("reaper_imgui");
const gui_lib = @import("gui_lib.zig");
const UiState = @import("ui_state.zig").UiState;
const styles = @import("styles.zig");
const action_types = @import("action_types.zig");
const c1_theme = @import("theme/c1_theme.zig");
const std = @import("std");

const log = std.log.scoped(.ui_lib);

// Because we return a ModeAction pointer across the C ABI boundary, we
// need a static location to store the value between frames.
var last_action: action_types.ModeAction = undefined;

export fn ui_init(plugin_getapi_opaque: *anyopaque) callconv(.c) bool {
    const plugin_getapi: *fn ([*:0]const u8) callconv(.c) ?*anyopaque = @ptrCast(@alignCast(plugin_getapi_opaque));
    imgui.init(plugin_getapi) catch return false;
    return true;
}

// Return codes:
// 0 = render error (window closed or ImGui error)
// 1 = rendered, no action
// 2 = rendered, action available in last_action
export fn ui_render(
    ctx: imgui.ContextPtr,
    win_flags: c_int,
    ui_state: *UiState,
    style_manager: *styles.StyleManager,
) callconv(.c) c_int {
    // Because the host and UI lib are separate compilation units, the UI lib
    // has its own copy of c1_theme.fonts that needs to be synced from the host's
    // font pointers each frame.
    c1_theme.fonts.MAIN = ui_state.main_font;
    c1_theme.fonts.ICON_FONT_SMALL = ui_state.icon_font;

    if (gui_lib.main(ctx, ui_state, win_flags, style_manager)) |maybe_action| {
        if (maybe_action) |action| {
            last_action = action;
            return 2;
        }
        return 1;
    } else |err| {
        // Because the host takes every 0 for a closed window, an error is
        // reported here, or a failing frame would look like a closed window.
        if (err != error.WindowClosed) {
            log.err("ui_render failed: {s}; imgui: {?s}", .{ @errorName(err), imgui.last_error });
        }
        return 0;
    }
}

export fn ui_get_last_action() callconv(.c) *const action_types.ModeAction {
    return &last_action;
}
