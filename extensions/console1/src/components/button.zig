const std = @import("std");
const imgui = @import("../reaper_imgui.zig");

/// Label must contain an id using "##<id>"
pub fn roundButton(ctx: imgui.ContextPtr, label: [:0]const u8, provided_radius: ?f64) !bool {
    const radius = if (provided_radius) |rad| rad else 5.0;
    const draw_list = try imgui.GetWindowDrawList(.{ctx});
    var pos_x: f64 = undefined;
    var pos_y: f64 = undefined;
    try imgui.GetCursorScreenPos(.{ ctx, &pos_x, &pos_y });

    // Draw circle outline
    try imgui.DrawList_AddCircleFilled(.{
        draw_list,
        pos_x + radius, // center x
        pos_y + radius, // center y
        radius,
        0xFFFFFFFF, // color (white)
        0, // num segments (0 for auto)
        2.0, // thickness
    });

    // Make it clickable
    const button_size = radius * 2;
    return try imgui.InvisibleButton(.{ ctx, label, button_size, button_size });
}
