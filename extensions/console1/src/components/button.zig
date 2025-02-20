const std = @import("std");
const imgui = @import("../reaper_imgui.zig");
const knob = @import("knob.zig");
const Size = knob.Size;
const Position = knob.Position;
const Rectangle = knob.Rectangle;

pub const TextPosition = enum {
    above, // default
    right,
    // You can add more positions like 'left', 'below' if needed
};

pub fn roundButton(
    ctx: imgui.ContextPtr,
    label: [:0]const u8,
    id: [:0]const u8,
    tooltip: ?[:0]const u8,
    provided_radius: ?f64,
    text_position: ?TextPosition,
) !bool {
    const radius = if (provided_radius) |rad| rad else 5.0;
    const text_pos = if (text_position) |pos| pos else TextPosition.above;
    const draw_list = try imgui.GetWindowDrawList(.{ctx});
    var rv: bool = false;

    // Calculate text size for label
    var label_size: Size = .{ .w = undefined, .h = undefined };
    try imgui.CalcTextSize(.{ ctx, label, &label_size.w, &label_size.h });
    const text_padding = 2.0;

    // Get current cursor position
    var cur_pos = Position{ .x = undefined, .y = undefined };
    try imgui.GetCursorScreenPos(.{ ctx, &cur_pos.x, &cur_pos.y });

    // Calculate total widget dimensions based on text position
    const button_size = radius * 2;
    const total_width = switch (text_pos) {
        .above => @max(button_size, label_size.w),
        .right => button_size + text_padding * 2 + label_size.w,
    };
    const total_height = switch (text_pos) {
        .above => button_size + label_size.h + text_padding * 2 + try imgui.GetTextLineHeightWithSpacing(.{ctx}),
        .right => @max(button_size, label_size.h),
    };

    const widget_rect = Rectangle{
        .min_x = cur_pos.x,
        .min_y = cur_pos.y,
        .max_x = cur_pos.x + total_width,
        .max_y = cur_pos.y + total_height,
    };

    {
        try imgui.PushClipRect(.{ ctx, widget_rect.min_x, widget_rect.min_y, widget_rect.max_x, widget_rect.max_y, true });
        defer imgui.PopClipRect(.{ctx}) catch {};

        // Calculate circle position
        const center_x = switch (text_pos) {
            .above => widget_rect.min_x + total_width / 2,
            .right => widget_rect.min_x + radius,
        };
        const center_y = switch (text_pos) {
            .above => widget_rect.min_y + label_size.h + text_padding * 2 + radius,
            .right => widget_rect.min_y + total_height / 2,
        };

        // Calculate label position
        const label_pos_x = switch (text_pos) {
            .above => widget_rect.min_x + (total_width - label_size.w) / 2,
            .right => center_x + radius + text_padding * 2,
        };
        const label_pos_y = switch (text_pos) {
            .above => widget_rect.min_y + text_padding,
            .right => center_y - label_size.h / 2,
        };

        // Draw label
        try imgui.DrawList_AddText(.{
            draw_list,
            label_pos_x,
            label_pos_y,
            try imgui.GetStyleColor(.{ ctx, imgui.Col_Text }),
            label,
        });

        // Add invisible button over label for tooltip
        try imgui.SetCursorScreenPos(.{ ctx, label_pos_x, label_pos_y });
        if (try imgui.InvisibleButton(.{ ctx, "##label", label_size.w, label_size.h })) {}

        if (tooltip) |tip| {
            if (try imgui.IsItemHovered(.{ ctx, imgui.HoveredFlags_None })) {
                try imgui.SetTooltip(.{ ctx, tip });
            }
        }

        // Draw circle
        try imgui.DrawList_AddCircleFilled(.{
            draw_list,
            center_x,
            center_y,
            radius,
            0xFFFFFFFF,
            0,
            2.0,
        });

        // Position and create the invisible button
        try imgui.SetCursorScreenPos(.{ ctx, center_x - radius, center_y - radius });
        rv = try imgui.InvisibleButton(.{ ctx, id, button_size, button_size });
    }

    // Create dummy space for entire widget
    try imgui.SetCursorScreenPos(.{ ctx, widget_rect.min_x, widget_rect.min_y });
    try imgui.Dummy(.{
        ctx,
        widget_rect.max_x - widget_rect.min_x,
        widget_rect.max_y - widget_rect.min_y,
    });

    return rv;
}
