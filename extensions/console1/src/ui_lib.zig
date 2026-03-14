const imgui = @import("reaper_imgui.zig");
const gui_lib = @import("gui_lib.zig");
const Globals = @import("globals.zig").Globals;
const styles = @import("styles.zig");
const action_types = @import("action_types.zig");

// Because we return a ModeAction pointer across the C ABI boundary, we
// need a static location to store the value between frames.
var last_action: action_types.ModeAction = undefined;

export fn ui_init(plugin_getapi_opaque: *anyopaque) callconv(.C) bool {
    const plugin_getapi: *fn ([*:0]const u8) callconv(.C) ?*anyopaque = @ptrCast(@alignCast(plugin_getapi_opaque));
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
    globals: *Globals,
    style_manager: *styles.StyleManager,
) callconv(.C) c_int {
    if (gui_lib.main(ctx, globals, win_flags, style_manager)) |maybe_action| {
        if (maybe_action) |action| {
            last_action = action;
            return 2;
        }
        return 1;
    } else |_| {
        return 0;
    }
}

export fn ui_get_last_action() callconv(.C) *const action_types.ModeAction {
    return &last_action;
}
