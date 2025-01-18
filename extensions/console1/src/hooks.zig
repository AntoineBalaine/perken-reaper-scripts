const std = @import("std");
const reaper = @import("reaper.zig").reaper;
const globals = @import("globals.zig");
const actions = @import("actions.zig");
const gui = @import("imgui_loop.zig");
const Mode = @import("statemachine.zig").Mode;

// Store command IDs returned from registration
pub var suspend_cmd_id: c_int = undefined;
pub var toggle_gui_cmd_id: c_int = undefined;

// Command handler
pub fn onCommand(sec: *reaper.KbdSectionInfo, command: c_int, val: c_int, val2hw: c_int, relmode: c_int, hwnd: reaper.HWND) callconv(.C) c_char {
    _ = .{ sec, val, val2hw, relmode, hwnd };

    if (command == suspend_cmd_id) {
        // Toggle suspended state
        const new_mode: Mode = if (globals.state.current_mode == .suspended)
            .fx_ctrl
        else
            .suspended;
        actions.dispatch(&globals.state, .{ .change_mode = new_mode });
        return 1;
    }

    if (command == toggle_gui_cmd_id) {
        actions.dispatch(&globals.state, .set_fx_ctrl_gui);
        return 1;
    }

    return 0;
}

// Registration helper
pub fn registerCommands() void {
    const suspend_action: reaper.custom_action_register_t = .{
        .section = 0,
        .id_str = "C1_SUSPEND",
        .name = "Console1: Suspend",
    };
    suspend_cmd_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&suspend_action)));

    const toggle_gui_action: reaper.custom_action_register_t = .{
        .section = 0,
        .id_str = "C1_HIDE_GUI",
        .name = "Console1: Hide FX Control Window",
    };
    toggle_gui_cmd_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&toggle_gui_action)));

    _ = reaper.plugin_register("toggleaction", @constCast(@ptrCast(&toggleActionHook)));
}

// Returns:
// -1 = action does not belong to this extension, or does not toggle
//  0 = action belongs to this extension and is currently set to "off"
//  1 = action belongs to this extension and is currently set to "on"
pub export fn toggleActionHook(command_id: c_int) callconv(.C) c_int {
    if (command_id == suspend_cmd_id) {
        // Check if we're disconnected
        return if (globals.state.current_mode == .suspended) 1 else 0;
    }

    if (command_id == toggle_gui_cmd_id) {
        // Only valid when not suspended
        return if (globals.state.fx_ctrl_gui_visible) 0 else 1;
    }

    return -1; // Not our action
}
