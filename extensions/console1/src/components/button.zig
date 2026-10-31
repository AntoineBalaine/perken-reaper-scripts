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

/// The symbols that a round button can carry: those of a transport.
pub const Icon = enum { play, stop, rec };

/// Draws a symbol of the transport at the center of a button of the given radius. The symbol is dark on the dome,
/// and red for the record button.
fn drawIcon(dl: imgui.DrawListPtr, cx: f64, cy: f64, radius: f64, icon: Icon, disabled: bool) !void {
    const s = radius * 0.42;
    const dark: u32 = if (disabled) 0x55555577 else 0x2A2A2EFF;
    const red: u32 = if (disabled) 0x80303077 else 0xD83A3AFF;
    switch (icon) {
        .play => try imgui.DrawList_AddTriangleFilled(.{ dl, cx - s * 0.6, cy - s, cx - s * 0.6, cy + s, cx + s * 1.1, cy, @as(c_int, @bitCast(dark)) }),
        .stop => try imgui.DrawList_AddRectFilled(.{ dl, cx - s * 0.85, cy - s * 0.85, cx + s * 0.85, cy + s * 0.85, @as(c_int, @bitCast(dark)), 1 }),
        .rec => try imgui.DrawList_AddCircleFilled(.{ dl, cx, cy, s * 0.95, @as(c_int, @bitCast(red)), 0 }),
    }
}

/// The space between a label and the alternative label that stands after it on the same line.
pub const alt_gap = 8.0;

/// A second text with the label of a button, in a color of its own: the use that the button has while shift is held. It is
/// on a line under the label, or on the same line, after the label, when `same_line` is true.
pub const AltLabel = struct { text: [:0]const u8, color: c_int, same_line: bool = false };

pub fn roundButton(
    ctx: imgui.ContextPtr,
    label: [:0]const u8,
    id: [:0]const u8,
    tooltip: ?[:0]const u8,
    provided_radius: ?f64,
    text_position: ?TextPosition,
    disabled: ?bool,
    color: ?c_int,
    /// The button is shown pressed while this is true, as a toggle that is on is.
    latched: ?bool,
    /// A small symbol drawn on the button.
    icon: ?Icon,
    /// The color of the label, which is the color of the text of the theme when it is null.
    label_color: ?c_int,
    /// A second line under the label.
    alt_label: ?AltLabel,
) !bool {
    const is_disabled = disabled orelse false;
    const radius = if (provided_radius) |rad| rad else default_radius;
    const text_pos = if (text_position) |pos| pos else TextPosition.above;
    const draw_list = try imgui.GetWindowDrawList(.{ctx});
    var rv: bool = false;

    // Check if label is empty
    const has_label = label.len > 0 or alt_label != null;

    // Calculate text size for label, which is the size of the two lines together when there is a second one
    var first_size: Size = .{ .w = 0, .h = 0 };
    var alt_size: Size = .{ .w = 0, .h = 0 };
    if (label.len > 0) try imgui.CalcTextSize(.{ ctx, label, &first_size.w, &first_size.h });
    if (alt_label) |alt| try imgui.CalcTextSize(.{ ctx, alt.text, &alt_size.w, &alt_size.h });
    const alt_same_line = if (alt_label) |alt| alt.same_line else false;
    const label_size: Size = if (alt_same_line)
        .{ .w = first_size.w + alt_gap + alt_size.w, .h = @max(first_size.h, alt_size.h) }
    else
        .{ .w = @max(first_size.w, alt_size.w), .h = first_size.h + alt_size.h };
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

            // Because the lines of a label above or below the key are centered, each line moves by the room that the
            // widest one leaves it. The lines of a label at the right start at the same edge.
            const centered = text_pos != .right;
            if (label.len > 0) {
                try imgui.DrawList_AddText(.{
                    draw_list,
                    label_pos_x + if (centered) (label_size.w - first_size.w) / 2 else 0,
                    label_pos_y,
                    label_color orelse try imgui.GetStyleColor(.{ ctx, imgui.Col_Text }),
                    label,
                });
            }
            if (alt_label) |alt| {
                try imgui.DrawList_AddText(.{
                    draw_list,
                    if (alt.same_line) label_pos_x + first_size.w + alt_gap else label_pos_x + if (centered) (label_size.w - alt_size.w) / 2 else 0,
                    if (alt.same_line) label_pos_y else label_pos_y + first_size.h,
                    alt.color,
                    alt.text,
                });
            }

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
        try knob.drawRoundKey(draw_list, center_x, center_y, radius, color orelse -1, .{ .hovered = isHovered, .active = held or (latched orelse false), .disabled = is_disabled });
        if (icon) |symbol| {
            const sunk: f64 = if (held or (latched orelse false)) 0.8 else 0;
            try drawIcon(draw_list, center_x, center_y + sunk, radius, symbol, is_disabled);
        }
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
