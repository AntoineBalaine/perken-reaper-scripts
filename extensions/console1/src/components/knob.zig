const std = @import("std");
const imgui = @import("../reaper_imgui.zig");

const knob_size = 40.0;
const MAXVAL = 1.0;
const MINVAL = 0.0;

pub const ControlScale = enum(u2) {
    linear,
    logarithmic,
};

pub const YControlFlags = packed struct {
    invisible: bool,
    increment: bool,
    scale: ControlScale,
};

pub const Size = struct {
    w: f64,
    h: f64,
};
pub const Knob = struct {
    id: [:0]const u8,
    value: f64 = 0.5,
    radius: f64 = 20.0,
    flags: ControlFlags = .{},
    pos: Position,
};
pub const Position = struct {
    x: f64,
    y: f64,
};
pub const TrackStart = enum(u2) { left, right, center };
pub const ControlFlags = packed struct {
    selected: bool = false,
    trackStart: TrackStart = .left,
};
pub const Rectangle = struct {
    min_x: f64,
    min_y: f64,
    max_x: f64,
    max_y: f64,
};

inline fn angle_min() f64 {
    return std.math.pi * 0.75;
}
inline fn angle_max() f64 {
    return std.math.pi * 2.25;
}

inline fn t(val: f64, min: f64, max: f64) f64 {
    return (val - min) / (max - min);
}

inline fn angle(value: f64, min: f64, max: f64) f64 {
    return angle_min() + (angle_max() - angle_min()) * t(value, min, max);
}

inline fn angle_default() f64 {
    return (angle_max() + angle_min()) / 2;
}

inline fn center(drawCursor: f64, radius: f64) f64 {
    return drawCursor + radius;
}
pub fn drawWidget(
    ctx: imgui.ContextPtr,
    value: *f64,
    id: [:0]const u8,
    flags: ControlFlags,
) !void {
    const drwls = try imgui.GetWindowDrawList(.{ctx});
    const radius = knob_size / 2;

    var cur_pos = Position{ .x = undefined, .y = undefined };
    try imgui.GetCursorScreenPos(.{ ctx, &cur_pos.x, &cur_pos.y });
    const widget_rect = Rectangle{
        .min_x = cur_pos.x,
        .min_y = cur_pos.y,
        .max_x = cur_pos.x + radius * 2,
        .max_y = cur_pos.y + radius * 2 + try imgui.GetTextLineHeightWithSpacing(.{ctx}),
    };

    {
        try imgui.PushClipRect(.{ ctx, widget_rect.min_x, widget_rect.min_y, widget_rect.max_x, widget_rect.max_y, true });
        defer imgui.PopClipRect(.{ctx}) catch {};

        // Draw background color
        try imgui.DrawList_AddRectFilled(.{ drwls, widget_rect.min_x, widget_rect.min_y, widget_rect.max_x, widget_rect.max_y, 0xFFFFFF22 });

        // Draw "Empty" button in the center of the adjusted ClipRect
        const center_x = widget_rect.min_x + radius; // use radius => assume clipRect.w == diameter
        const center_y = widget_rect.min_y + radius; // use radius => assume control is at top of clipRect

        try imgui.SetCursorScreenPos(.{ ctx, center_x - radius, center_y - radius });

        const rv = try YControl(ctx, id, value, radius * 2, radius * 2, MINVAL, MAXVAL, .{
            .invisible = true,
            .increment = false,
            .scale = .logarithmic,
        });

        const angle_ = angle(value.*, 0.0, 1.0);
        var wiper_start: f64 = undefined;
        var wiper_end: f64 = undefined;
        switch (flags.trackStart) {
            .left => {
                wiper_start = angle_min();
                wiper_end = angle_;
            },
            .right => {
                wiper_start = angle_max();
                wiper_end = angle_;
            },
            .center => {
                wiper_start = angle_;
                wiper_end = angle_default();
            },
        }
        const isHovered = rv[0];

        const active = rv[1];

        const drwLs = try imgui.GetWindowDrawList(.{ctx});
        var circleColor = try imgui.GetStyleColor(.{ ctx, imgui.Col_TitleBg });
        var dotColor = try imgui.GetStyleColor(.{ ctx, if (active) imgui.Col_SliderGrabActive else imgui.Col_SliderGrab });

        if (isHovered and !active) {
            dotColor = adjustBrightness(dotColor, -30, false);
            circleColor = adjustBrightness(circleColor, 50, false);
        } else {
            dotColor = adjustBrightness(dotColor, 50, false);
            circleColor = adjustBrightness(circleColor, -30, false);
        }

        try Circle(drwLs, circleColor, center_x, center_y, 0.6, true, 32, radius);
        try Arc(drwLs, 0.85, 0.41, wiper_start, wiper_end, dotColor, 2, center_x, center_y, radius);
        try Triangle(drwLs, angle_, dotColor, center_x, center_y, 0.2, true, 0.45, radius, false);

        // Draw the value label below the button
        const label_y = center_y + radius + 5.0; // Add some padding
        var buf: [24]u8 = undefined;
        const val_fmt = try std.fmt.bufPrintZ(&buf, "{d:.2}", .{value.*});
        var txt_size: Size = .{ .w = undefined, .h = undefined };
        try imgui.CalcTextSize(.{ ctx, val_fmt.ptr, &txt_size.w, &txt_size.h });
        try imgui.DrawList_AddText(.{ drwls, center_x - txt_size.w / 2.0, label_y, try imgui.GetStyleColor(.{ ctx, imgui.Col_Text }), val_fmt });
    }

    try imgui.SetCursorScreenPos(.{ ctx, widget_rect.min_x, widget_rect.min_y });
    try imgui.Dummy(.{
        ctx,
        widget_rect.max_x - widget_rect.min_x,
        widget_rect.max_y - widget_rect.min_y,
    });
}

pub fn YControl(ctx: imgui.ContextPtr, id: [:0]const u8, value: *f64, w: f64, h: f64, min_val: f64, max_val: f64, flags: YControlFlags) !std.meta.Tuple(&[_]type{ bool, bool }) {
    try imgui.SetNextItemAllowOverlap(.{ctx});
    if (flags.invisible) {
        _ = try imgui.InvisibleButton(.{ ctx, id, w, h });
    } else {
        _ = try imgui.Button(.{ ctx, "", w, h });
    }

    const isHovered = try imgui.IsItemHovered(.{ctx});

    // Handle click-drag to change the value
    var speed: f64 = 200.0;
    if (try imgui.IsKeyDown(.{ ctx, imgui.Mod_Shift }) or try imgui.IsKeyDown(.{ ctx, imgui.Mod_Alt })) {
        speed = 2000.0;
    }

    if (try imgui.IsItemActive(.{ctx})) {
        var delta_x: f64 = undefined;
        var delta_y: f64 = undefined;
        try imgui.GetMouseDragDelta(.{
            ctx,
            &delta_x,
            &delta_y,
            null,
            null,
        });
        if (delta_y != 0) {
            // Clamp the final value within the min_val and max_val bounds
            value.* = try calculateNewValue(value.*, delta_y, min_val, max_val, speed, flags);
            try imgui.ResetMouseDragDelta(.{ ctx, imgui.MouseButton_Left });
        }

        return .{ isHovered, true };
    } else {
        return .{ isHovered, false };
    }
}

fn calculateNewValue(current_value: f64, delta_y: f64, min_val: f64, max_val: f64, speed: f64, flags: YControlFlags) !f64 {
    var new_value: f64 = current_value;

    if (flags.scale == .logarithmic) {
        const log_min = std.math.log2(min_val + 1);
        const log_max = std.math.log2(max_val + 1);
        const log_value = std.math.log2(new_value + 1);
        const log_step = (log_max - log_min) / speed;

        if (flags.increment) {
            new_value = std.math.exp2(log_value + delta_y * log_step) - 1;
        } else {
            new_value = std.math.exp2(log_value - delta_y * log_step) - 1;
        }
    } else {
        const step = (max_val - min_val) / speed;
        if (flags.increment) {
            new_value = new_value + delta_y * step;
        } else {
            new_value = new_value - delta_y * step;
        }
    }

    return @min(@max(new_value, min_val), max_val);
}

fn Circle(drwLs: imgui.DrawListPtr, color: c_int, center_x: f64, center_y: f64, size: f64, filled: bool, segments: c_int, radius: f64) !void {
    const circleRadius = size * radius;
    if (filled) {
        try imgui.DrawList_AddCircleFilled(.{ drwLs, center_x, center_y, circleRadius, color, segments });
    } else {
        try imgui.DrawList_AddCircle(.{ drwLs, center_x, center_y, circleRadius, color, segments });
    }
}

fn Arc(drwLs: imgui.DrawListPtr, radius_ratio: f64, size: f64, startAngle: f64, endAngle: f64, color: c_int, trackSize: ?f64, center_x: f64, center_y: f64, radius: f64) !void {
    const trSize = if (trackSize) |tr| tr else size * (radius_ratio + 0.1) * 0.5 + 0.0001;
    const trackRadius = radius_ratio * radius;
    try imgui.DrawList_PathArcTo(.{ drwLs, center_x, center_y, trackRadius * 0.95, startAngle, endAngle });
    try imgui.DrawList_PathStroke(.{ drwLs, color, null, trSize });
    try imgui.DrawList_PathClear(.{drwLs});
}

fn Triangle(drwLs: imgui.DrawListPtr, angle_: f64, color: c_int, center_x: f64, center_y: f64, radiusRatio: f64, filled: bool, offsetRatio: f64, radius: f64, outward: bool) !void {
    const dot_radius = radiusRatio * radius;
    const dot_offset = offsetRatio * radius;
    const x = center_x + @cos(angle_) * dot_offset;
    const y = center_y + @sin(angle_) * dot_offset;
    const vertices = getVertices(x, y, dot_radius, angle_, outward);
    const c = vertices[0];
    const b = vertices[1];
    const a = vertices[2];
    if (filled) {
        try imgui.DrawList_AddTriangleFilled(.{ drwLs, c.x, c.y, b.x, b.y, a.x, a.y, color });
    } else {
        try imgui.DrawList_AddTriangle(.{ drwLs, c.x, c.y, b.x, b.y, a.x, a.y, color });
    }
}
const vertex = struct {
    x: f64,
    y: f64,
};

const f64x3 = @Vector(3, f64);
/// tldr: using simd vectors here, though it’s only 6% faster than the scalar version.
inline fn getVertices(centerX: f64, centerY: f64, radius: f64, angle_: f64, outward: bool) [3]vertex {
    const tr = std.math.pi / 3.0;
    const angles = f64x3{
        if (outward) angle_ + 1 * 2 * tr + std.math.pi else angle_ + 1 * 2 * tr,
        if (outward) angle_ + 2 * 2 * tr + std.math.pi else angle_ + 2 * 2 * tr,
        if (outward) angle_ + 3 * 2 * tr + std.math.pi else angle_ + 3 * 2 * tr,
    };
    const cos_vals = @cos(angles);
    const sin_vals = @sin(angles);

    const rad_vec: f64x3 = @splat(radius);
    const x_vals = @as(f64x3, @splat(centerX)) + rad_vec * cos_vals; //  centerX + (radius * cos_vals);
    const y_vals = @as(f64x3, @splat(centerY)) + rad_vec * sin_vals; //  centerY + (radius * sin_vals);

    return [3]vertex{
        vertex{ .x = x_vals[0], .y = y_vals[0] },
        vertex{ .x = x_vals[1], .y = y_vals[1] },
        vertex{ .x = x_vals[2], .y = y_vals[2] },
    };
}

const RGBA = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};
inline fn fixBrightness(channel: u8, delta: i8) u8 {
    return if (delta >= 0) std.math.add(u8, channel, @intCast(@abs(delta))) catch 255 else std.math.sub(u8, channel, @intCast(@abs(delta))) catch 0;
}

pub inline fn adjustBrightness(color: c_int, amt: i8, no_alpha: bool) c_int {
    var rgba: RGBA = @bitCast(color);
    rgba.r = fixBrightness(rgba.r, amt);
    rgba.g = fixBrightness(rgba.g, amt);
    rgba.b = fixBrightness(rgba.b, amt);
    if (!no_alpha) {
        rgba.a = fixBrightness(rgba.a, amt);
    }
    return @as(c_int, @bitCast(rgba));
}

pub fn getWidgetRect(ctx: imgui.ContextPtr, widget: *Knob) !Rectangle {
    return Rectangle{
        .min_x = widget.pos.x,
        .min_y = widget.pos.y,
        .max_x = widget.pos.x + widget.radius * 2,
        .max_y = widget.pos.y + widget.radius * 2 + try imgui.GetTextLineHeightWithSpacing(.{ctx}),
    };
}

pub fn getScreenWidgetRect(ctx: imgui.ContextPtr, widget_pos: Position, widget_radius: f64, win_pos: Position) !Rectangle {
    return Rectangle{
        .min_x = win_pos.x + widget_pos.x,
        .min_y = win_pos.y + widget_pos.y,
        .max_x = win_pos.x + widget_pos.x + widget_radius * 2,
        .max_y = win_pos.y + widget_pos.y + widget_radius * 2 + try imgui.GetTextLineHeightWithSpacing(.{ctx}),
    };
}
