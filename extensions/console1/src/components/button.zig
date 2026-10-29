const imgui = @import("reaper_imgui");
const knob = @import("knob");
const Size = knob.Size;
const Position = knob.Position;
const Rectangle = knob.Rectangle;

pub const TextPosition = enum {
    above, // default
    right,
    below,
    // You can add more positions like 'left' if needed
};

/// The radius of a round button that is not given one.
pub const default_radius = 8.5;

pub fn roundButton(
    ctx: imgui.ContextPtr,
    label: [:0]const u8,
    id: [:0]const u8,
    tooltip: ?[:0]const u8,
    provided_radius: ?f64,
    text_position: ?TextPosition,
    disabled: ?bool,
    color: ?c_int,
) !bool {
    const is_disabled = disabled orelse false;
    const radius = if (provided_radius) |rad| rad else default_radius;
    const text_pos = if (text_position) |pos| pos else TextPosition.above;
    const draw_list = try imgui.GetWindowDrawList(.{ctx});
    var rv: bool = false;

    // Check if label is empty
    const has_label = label.len > 0;

    // Calculate text size for label
    var label_size: Size = .{ .w = 0, .h = 0 };
    if (has_label) {
        try imgui.CalcTextSize(.{ ctx, label, &label_size.w, &label_size.h });
    }
    const text_padding = 2.0;

    // Get current cursor position
    var cur_pos = Position{ .x = undefined, .y = undefined };
    try imgui.GetCursorScreenPos(.{ ctx, &cur_pos.x, &cur_pos.y });

    // Calculate total widget dimensions based on text position
    const button_size = radius * 2;
    const total_width = if (!has_label) button_size else switch (text_pos) {
        .above, .below => @max(button_size, label_size.w),
        .right => button_size + text_padding * 2 + label_size.w,
    };
    const total_height = if (!has_label) button_size else switch (text_pos) {
        .above, .below => button_size + label_size.h + text_padding * 2 + try imgui.GetTextLineHeightWithSpacing(.{ctx}),
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
        const center_x = if (!has_label) widget_rect.min_x + radius else switch (text_pos) {
            .above, .below => widget_rect.min_x + total_width / 2,
            .right => widget_rect.min_x + radius,
        };
        const center_y = if (!has_label) widget_rect.min_y + radius else switch (text_pos) {
            .above => widget_rect.min_y + label_size.h + text_padding * 2 + radius,
            .below => widget_rect.min_y + radius,
            .right => widget_rect.min_y + total_height / 2,
        };

        // The area that answers the mouse is the key and its label together, so that the key lights up
        // when the mouse is on the label.
        var hit = Rectangle{
            .min_x = center_x - radius,
            .min_y = center_y - radius,
            .max_x = center_x + radius,
            .max_y = center_y + radius,
        };

        if (has_label) {
            const label_pos_x = switch (text_pos) {
                .above, .below => widget_rect.min_x + (total_width - label_size.w) / 2,
                .right => center_x + radius + text_padding * 2,
            };
            const label_pos_y = switch (text_pos) {
                .above => widget_rect.min_y + text_padding,
                .below => widget_rect.min_y + button_size + text_padding * 2,
                .right => center_y - label_size.h / 2,
            };

            try imgui.DrawList_AddText(.{
                draw_list,
                label_pos_x,
                label_pos_y,
                try imgui.GetStyleColor(.{ ctx, imgui.Col_Text }),
                label,
            });

            hit.min_x = @min(hit.min_x, label_pos_x);
            hit.min_y = @min(hit.min_y, label_pos_y);
            hit.max_x = @max(hit.max_x, label_pos_x + label_size.w);
            hit.max_y = @max(hit.max_y, label_pos_y + label_size.h);
        }

        try imgui.SetCursorScreenPos(.{ ctx, hit.min_x, hit.min_y });
        const pressed = try imgui.InvisibleButton(.{ ctx, id, hit.max_x - hit.min_x, hit.max_y - hit.min_y });
        if (!is_disabled) rv = pressed;

        const isHovered = try imgui.IsItemHovered(.{ ctx, imgui.HoveredFlags_None });
        if (has_label and isHovered) {
            if (tooltip) |tip| try imgui.SetTooltip(.{ ctx, tip });
        }

        const held = !is_disabled and try imgui.IsItemActive(.{ctx});
        try knob.drawRoundKey(draw_list, center_x, center_y, radius, color orelse -1, .{ .hovered = isHovered, .active = held, .disabled = is_disabled });
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
