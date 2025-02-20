const std = @import("std");
const imgui = @import("../reaper_imgui.zig");
const knob = @import("knob.zig");
const Size = knob.Size;
const Position = knob.Position;
const Rectangle = knob.Rectangle;
/// Label must contain an id using "##<id>"
// pub fn roundButton(ctx: imgui.ContextPtr, label: [:0]const u8, provided_radius: ?f64) !bool {
//     const radius = if (provided_radius) |rad| rad else 5.0;
//     const draw_list = try imgui.GetWindowDrawList(.{ctx});
//     var pos_x: f64 = undefined;
//     var pos_y: f64 = undefined;
//     try imgui.GetCursorScreenPos(.{ ctx, &pos_x, &pos_y });
//
//     // Draw circle outline
//     try imgui.DrawList_AddCircleFilled(.{
//         draw_list,
//         pos_x + radius, // center x
//         pos_y + radius, // center y
//         radius,
//         0xFFFFFFFF, // color (white)
//         0, // num segments (0 for auto)
//         2.0, // thickness
//     });
//
//     // Make it clickable
//     const button_size = radius * 2;
//     return try imgui.InvisibleButton(.{ ctx, label, button_size, button_size });
// }

pub fn roundButton(
    ctx: imgui.ContextPtr,
    label: [:0]const u8,
    id: [:0]const u8,
    provided_radius: ?f64,
    tooltip: ?[:0]const u8,
) !bool {
    const radius = if (provided_radius) |rad| rad else 5.0;
    const draw_list = try imgui.GetWindowDrawList(.{ctx});
    var rv: bool = false;

    // Calculate text size for label
    var label_size: Size = .{ .w = undefined, .h = undefined };
    try imgui.CalcTextSize(.{ ctx, label, &label_size.w, &label_size.h });
    const text_padding = 2.0;

    // Get current cursor position
    var cur_pos = Position{ .x = undefined, .y = undefined };
    try imgui.GetCursorScreenPos(.{ ctx, &cur_pos.x, &cur_pos.y });

    // Calculate total widget dimensions
    const button_size = radius * 2;
    const total_width = @max(button_size, label_size.w);
    const widget_rect = Rectangle{
        .min_x = cur_pos.x,
        .min_y = cur_pos.y,
        .max_x = cur_pos.x + total_width,
        .max_y = cur_pos.y + button_size + label_size.h + text_padding * 2 + try imgui.GetTextLineHeightWithSpacing(.{ctx}),
    };

    // Create clipping rectangle and draw components
    {
        try imgui.PushClipRect(.{
            ctx,
            widget_rect.min_x,
            widget_rect.min_y,
            widget_rect.max_x,
            widget_rect.max_y,
            true,
        });
        defer imgui.PopClipRect(.{ctx}) catch {};

        // Draw label at top
        try imgui.DrawList_AddText(.{
            draw_list,
            widget_rect.min_x + (total_width - label_size.w) / 2,
            widget_rect.min_y + text_padding,
            try imgui.GetStyleColor(.{ ctx, imgui.Col_Text }),
            label,
        });

        // Draw label at top and create invisible button for tooltip
        const label_pos_x = widget_rect.min_x + (total_width - label_size.w) / 2;
        const label_pos_y = widget_rect.min_y + text_padding;

        try imgui.DrawList_AddText(.{
            draw_list,
            label_pos_x,
            label_pos_y,
            try imgui.GetStyleColor(.{ ctx, imgui.Col_Text }),
            label,
        });

        // Add invisible button over label for tooltip
        try imgui.SetCursorScreenPos(.{ ctx, label_pos_x, label_pos_y });
        _ = try imgui.InvisibleButton(.{ ctx, "##label", label_size.w, label_size.h });

        // Show tooltip if provided and label is hovered
        if (tooltip) |tip| {
            if (try imgui.IsItemHovered(.{ ctx, imgui.HoveredFlags_None })) {
                try imgui.SetTooltip(.{ ctx, tip });
            }
        }

        // Calculate circle position (centered horizontally, below label)
        const center_x = widget_rect.min_x + total_width / 2;
        const center_y = widget_rect.min_y + label_size.h + text_padding * 2 + radius;

        // Draw circle
        try imgui.DrawList_AddCircleFilled(.{
            draw_list,
            center_x,
            center_y,
            radius,
            0xFFFFFFFF, // color (white)
            0, // num segments (0 for auto)
            2.0, // thickness
        });

        // Position and create the invisible button
        try imgui.SetCursorScreenPos(.{ ctx, center_x - radius, center_y - radius });
        rv = try imgui.InvisibleButton(.{ ctx, id, button_size, button_size });
    }

    // Create dummy space for entire widget
    try imgui.Dummy(.{
        ctx,
        widget_rect.max_x - widget_rect.min_x,
        widget_rect.max_y - widget_rect.min_y,
    });

    return rv;
}
