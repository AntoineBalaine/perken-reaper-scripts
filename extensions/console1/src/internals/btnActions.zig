const std = @import("std");
const reaper = @import("../reaper.zig").reaper;
const Controller = @import("controller.zig");

/// iterate over buttons in the controller, and register an action that matches them.
pub fn registerButtonActions(allocator: std.mem.Allocator, controller: Controller.Controller) !void {
    const action_ids: [controller.buttons.len]c_int = try allocator.create([controller.buttons.len]c_int{});
    for (@typeInfo(@TypeOf(controller.buttons)).Struct.fields, 0..) |button_field, idx| {
        const action_id_str = "PRKN_" ++ controller.name ++ "_" ++ button_field.name;
        const action_name = controller.name ++ "_" ++ button_field.name;
        // PRKN_C1_BtnNumber
        const action = reaper.custom_action_register_t{ .section = 0, .id_str = action_id_str, .name = action_name };
        const action_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&action)));
        action_ids[idx] = action_id;
    }
    controller.action_ids = action_ids;
}
