const std = @import("std");
const reaper = @import("../reaper.zig").reaper;
const Controller = @import("controller.zig");

/// iterate over buttons in the controller, and register an action that matches them.
pub fn registerButtonActions(allocator: std.mem.Allocator, controller: *Controller.Controller) !void {
    const action_ids = try allocator.alloc(c_int, controller.buttons.len);
    for (controller.buttons, 0..) |button_field, idx| {
        const action_id_str = try std.mem.concatWithSentinel(allocator, u8, &[_][]const u8{ "PRKN_", std.mem.span(controller.name), "_", button_field }, 0);
        const action_name = try std.mem.concatWithSentinel(allocator, u8, &[_][]const u8{
            //
            std.mem.span(controller.name), "_", button_field,
        }, 0);
        // PRKN_C1_BtnNumber
        const action = reaper.custom_action_register_t{
            //
            .section = 0,
            .id_str = action_id_str,
            .name = action_name,
        };
        const action_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&action)));
        action_ids[idx] = action_id;
    }
    controller.action_ids = action_ids;
}
