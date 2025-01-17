const std = @import("std");
const reaper = @import("reaper.zig").reaper;
const globals = @import("globals.zig");
const actions = @import("actions.zig");
const gui = @import("imgui_loop.zig");
const constants = @import("constants.zig");
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
        actions.dispatch(&globals.state, .{ .set_fx_ctrl_gui = !globals.state.fx_ctrl_gui_visible });
        return 1;
    }

    return 0;
}

// Registration helper
pub fn registerCommands() void {
    const suspend_action: reaper.custom_action_register_t = .{
        .section = 0,
        .id_str = "C1_SUSPEND",
        .name = "Console1: Suspend/Resume",
    };
    suspend_cmd_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&suspend_action)));

    const toggle_gui_action: reaper.custom_action_register_t = .{
        .section = 0,
        .id_str = "C1_TenOGGLE_GUI",
        .name = "Console1: Toggle FX Control Window",
    };
    toggle_gui_cmd_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&toggle_gui_action)));
}

pub export fn toggleActionHook(command_id: [*:0]const u8) callconv(.C) c_int {
    const cmd = std.mem.span(command_id);

    if (std.mem.eql(u8, cmd, constants.ActionID.SUSPEND)) {
        // Check if we're disconnected
        return if (globals.state.current_mode == .suspended) 1 else 0;
    }

    if (std.mem.eql(u8, cmd, constants.ActionID.TOGGLE_FXCTRL_GUI)) {
        // Only valid when not suspended
        if (globals.state.current_mode == .suspended) {
            return -1;
        }
        return if (globals.state.fx_ctrl_gui_visible) 1 else 0;
    }

    return -1; // Not our action
}
