const imgui = @import("../reaper_imgui.zig");
const knob = @import("knob.zig");
const Position = knob.Position;

/// VerticalSeparator draws a vertical line from the current cursor position
/// to the bottom of the current window or specified height.
/// It also creates a dummy component to occupy space.
pub fn vSeparator(
    ctx: imgui.ContextPtr,
    color: c_int,
    @"thickness?": ?f64,
) !void {
    const draw_list = try imgui.GetWindowDrawList(.{ctx});
    const thickness: f64 = if (@"thickness?") |thcknss| thcknss else 1.0;
    // Get current cursor position
    var cur_scr_pos = Position{ .x = undefined, .y = undefined };
    try imgui.GetCursorScreenPos(.{ ctx, &cur_scr_pos.x, &cur_scr_pos.y });

    var rect_max = Position{ .x = undefined, .y = undefined };
    try imgui.GetItemRectMax(.{ ctx, &rect_max.x, &rect_max.y });

    // Draw the vertical line
    try imgui.DrawList_AddLine(.{
        draw_list,
        cur_scr_pos.x, // Center the line within the width
        cur_scr_pos.y,
        cur_scr_pos.x,
        rect_max.y,
        color,
        thickness,
    });

    // Create a dummy component to occupy space
    try imgui.Dummy(.{ ctx, thickness, rect_max.y });
}
