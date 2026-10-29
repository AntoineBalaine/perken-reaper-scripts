const std = @import("std");
const imgui = @import("reaper_imgui");
const theme = @import("panel_theme");

/// The diameter of a knob, LED ring included. The panels size their spacing from it.
pub const knob_size = 54.0;
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
pub const ControlFlags = struct {
    selected: bool = false,
    trackStart: TrackStart = .left,
    /// Indicates if the knob is disabled.
    /// Note: Actual interaction prevention should be handled by ImGui's begin/endDisabled at the caller level.
    disabled: bool = false,
    /// When true, the knob will not display the value label below it.
    no_val_display: bool = false,
    /// When non-null, the knob draws a filled rectangle behind the widget with this color.
    knob_bg: ?c_int = null,
};
pub const Rectangle = struct {
    min_x: f64,
    min_y: f64,
    max_x: f64,
    max_y: f64,
};

pub const KnobResult = union(enum) {
    active,
    value_dclick,
    value_submit: f64,
    value_cancel,
};

pub const EditMode = ?*[24]u8;

pub const LabelId = struct {
    label: [:0]const u8,
    id: [:0]const u8,
    /// When non-null, displayed below the knob instead of the formatted normalized float.
    value_text: ?[:0]const u8 = null,
};

pub inline fn angle_min() f64 {
    return std.math.pi * 0.75;
}
pub inline fn angle_max() f64 {
    return std.math.pi * 2.25;
}

pub inline fn t(val: f64, min: f64, max: f64) f64 {
    return (val - min) / (max - min);
}

pub inline fn angle(value: f64, min: f64, max: f64) f64 {
    return angle_min() + (angle_max() - angle_min()) * t(value, min, max);
}

pub inline fn angle_default() f64 {
    return (angle_max() + angle_min()) / 2;
}

pub inline fn center(drawCursor: f64, radius: f64) f64 {
    return drawCursor + radius;
}
/// The height of a knob widget: its label, its padding and the knob. A panel that places knobs at fixed
/// positions needs it to size its rows.
pub fn widgetHeight(label_height: f64) f64 {
    return centerOffsetY(label_height) + knob_size / 2 + label_text_padding;
}

/// How far the center of the knob is under the top of its widget, for a label of the given height.
pub fn centerOffsetY(label_height: f64) f64 {
    return label_height + label_text_padding - label_knob_overlap + knob_size / 2;
}

/// How far the line of the label overlaps the room of the knob. Because the line height of the font holds
/// space under the letters and the ring of LEDs is thinner than the knob, the label can come this close.
const label_knob_overlap = 3.0;

const label_text_padding = 2.0;

pub fn drawWidget(
    ctx: imgui.ContextPtr,
    value: *f64,
    label_id: LabelId,
    flags: ControlFlags,
    max_width: ?f64,
    edit_mode: EditMode,
) !?KnobResult {
    const drwls = try imgui.GetWindowDrawList(.{ctx});
    const radius = knob_size / 2;
    var result: ?KnobResult = null;

    // Calculate text size for label
    var label_size: Size = .{ .w = undefined, .h = undefined };
    try imgui.CalcTextSize(.{ ctx, label_id.label, &label_size.w, &label_size.h });
    const text_padding = label_text_padding;

    var cur_pos = Position{ .x = undefined, .y = undefined };
    try imgui.GetCursorScreenPos(.{ ctx, &cur_pos.x, &cur_pos.y });

    // A width that is given is the width of the widget, and a longer label overhangs it on both sides: a panel
    // that places the knobs on fixed positions needs the cap to stay at the middle of the width it asked for.
    const total_width = if (max_width) |max_w| @max(max_w, radius * 2) else @max(radius * 2, label_size.w);
    const overhang = @max(0.0, (label_size.w - total_width) / 2);

    const widget_rect = Rectangle{
        .min_x = cur_pos.x,
        .min_y = cur_pos.y,
        .max_x = cur_pos.x + total_width,
        .max_y = cur_pos.y + widgetHeight(label_size.h),
    };

    {
        try imgui.PushClipRect(.{ ctx, widget_rect.min_x - overhang, widget_rect.min_y, widget_rect.max_x + overhang, widget_rect.max_y, true });

        // Draw background color
        if (flags.knob_bg) |bg| {
            try imgui.DrawList_AddRectFilled(.{ drwls, widget_rect.min_x, widget_rect.min_y, widget_rect.max_x, widget_rect.max_y, bg });
        }

        // Draw label at top
        try imgui.DrawList_AddText(.{
            drwls,
            widget_rect.min_x + (total_width - label_size.w) / 2,
            widget_rect.min_y + text_padding,
            try imgui.GetStyleColor(.{ ctx, imgui.Col_Text }),
            label_id.label,
        });

        // Draw "Empty" button in the center of the adjusted ClipRect
        const center_x = widget_rect.min_x + total_width / 2; // centered based on total width
        const center_y = widget_rect.min_y + centerOffsetY(label_size.h);

        try imgui.SetCursorScreenPos(.{ ctx, center_x - radius, center_y - radius });

        const rv = try YControl(ctx, label_id.id, value, radius * 2, radius * 2, MINVAL, MAXVAL, .{
            .invisible = true,
            .increment = false,
            .scale = .logarithmic,
        });

        const isHovered = rv[0];
        const active = rv[1];

        if (active) result = .active;

        const drwLs = try imgui.GetWindowDrawList(.{ctx});
        try drawCapKnob(drwLs, center_x, center_y, radius, value.*, flags.trackStart, .{ .hovered = isHovered, .active = active, .disabled = flags.disabled });

        // The popups are not clipped to the widget, as they stand over the label and above the knob.
        try imgui.PopClipRect(.{ctx});

        // The value is not printed under the knob: it shows in a popup above the knob while the knob is
        // held, and a right click on the knob opens the box in which a value is typed.
        if (!flags.no_val_display and !flags.disabled) {
            if (edit_mode) |edit_buf| {
                const edit_w = @max(total_width, 64.0);
                const frame_h = try imgui.GetFrameHeight(.{ctx});
                try imgui.SetCursorScreenPos(.{ ctx, center_x - edit_w / 2, center_y - radius - frame_h - 4 });
                try imgui.PushItemWidth(.{ ctx, edit_w });
                defer imgui.PopItemWidth(.{ctx}) catch {};
                try imgui.SetKeyboardFocusHere(.{ctx});

                var val_edit_id_buf: [48]u8 = undefined;
                const val_edit_id = std.mem.printSentinel(&val_edit_id_buf, "##val_edit_{s}", .{label_id.id}, 0) catch "##val_edit";

                const enter_pressed = try imgui.InputText(.{
                    ctx,
                    val_edit_id,
                    @as([*]u8, @ptrCast(edit_buf)),
                    @as(c_int, @intCast(edit_buf.len)),
                    imgui.InputTextFlags_EnterReturnsTrue | imgui.InputTextFlags_AutoSelectAll,
                    null,
                });

                if (enter_pressed) {
                    const text = std.mem.sliceTo(edit_buf, 0);
                    if (std.fmt.parseFloat(f64, text)) |parsed| {
                        result = .{ .value_submit = std.math.clamp(parsed, 0.0, 1.0) };
                    } else |_| {
                        result = .value_cancel;
                    }
                } else if (try imgui.IsKeyPressed(.{ ctx, imgui.Key_Escape })) {
                    result = .value_cancel;
                }
            } else {
                if (isHovered and try imgui.IsMouseClicked(.{ ctx, imgui.MouseButton_Right })) {
                    result = .value_dclick;
                }
                if (active) {
                    var buf: [24]u8 = undefined;
                    const val_fmt: [:0]const u8 = if (label_id.value_text) |vt| (if (vt.len == 0) "-" else vt) else try std.mem.printSentinel(&buf, "{d:.2}", .{value.*}, 0);
                    try drawValuePopup(ctx, center_x, center_y - radius, val_fmt);
                }
            }
        }
    }

    try imgui.SetCursorScreenPos(.{ ctx, widget_rect.min_x, widget_rect.min_y });
    try imgui.Dummy(.{
        ctx,
        widget_rect.max_x - widget_rect.min_x,
        widget_rect.max_y - widget_rect.min_y,
    });
    return result;
}

pub fn YControl(ctx: imgui.ContextPtr, id: [:0]const u8, value: *f64, w: f64, h: f64, min_val: f64, max_val: f64, flags: YControlFlags) !@Tuple(&[_]type{ bool, bool }) {
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

    // Double-click resets to the midpoint (0.5 normalized). REAPER does
    // not expose a parameter's true default value, so the midpoint is the
    // best available approximation.
    if (isHovered and try imgui.IsMouseDoubleClicked(.{ ctx, imgui.MouseButton_Left })) {
        value.* = (min_val + max_val) / 2.0;
        return .{ isHovered, true };
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

pub fn Circle(drwLs: imgui.DrawListPtr, color: c_int, center_x: f64, center_y: f64, size: f64, filled: bool, segments: c_int, radius: f64) !void {
    const circleRadius = size * radius;
    if (filled) {
        try imgui.DrawList_AddCircleFilled(.{ drwLs, center_x, center_y, circleRadius, color, segments });
    } else {
        try imgui.DrawList_AddCircle(.{ drwLs, center_x, center_y, circleRadius, color, segments });
    }
}

pub fn Arc(drwLs: imgui.DrawListPtr, radius_ratio: f64, size: f64, startAngle: f64, endAngle: f64, color: c_int, trackSize: ?f64, center_x: f64, center_y: f64, radius: f64) !void {
    const trSize = if (trackSize) |tr| tr else size * (radius_ratio + 0.1) * 0.5 + 0.0001;
    const trackRadius = radius_ratio * radius;
    try imgui.DrawList_PathArcTo(.{ drwLs, center_x, center_y, trackRadius * 0.95, startAngle, endAngle });
    try imgui.DrawList_PathStroke(.{ drwLs, color, null, trSize });
    try imgui.DrawList_PathClear(.{drwLs});
}

pub fn Triangle(drwLs: imgui.DrawListPtr, angle_: f64, color: c_int, center_x: f64, center_y: f64, radiusRatio: f64, filled: bool, offsetRatio: f64, radius: f64, outward: bool) !void {
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

/// The value of a knob in a small dark box with an orange outline, whose bottom edge is at `bottom`. It
/// is drawn over everything else in the window.
fn drawValuePopup(ctx: imgui.ContextPtr, center_x: f64, bottom: f64, text: [:0]const u8) !void {
    const dl = try imgui.GetForegroundDrawList(.{ctx});
    var size: Size = .{ .w = undefined, .h = undefined };
    try imgui.CalcTextSize(.{ ctx, text, &size.w, &size.h });
    const w = size.w + 18;
    const h = size.h + 8;
    const x1 = center_x - w / 2;
    const y2 = bottom + 2;
    const y1 = y2 - h;
    try imgui.DrawList_AddRectFilled(.{ dl, x1 + 1, y1 + 3, x1 + w + 1, y2 + 3, hexColor(0x00000099), 6 });
    try imgui.DrawList_AddRectFilled(.{ dl, x1, y1, x1 + w, y2, hexColor(0x0B0B0DF2), 6 });
    try imgui.DrawList_AddRectFilled(.{ dl, x1, y1, x1 + w, y2, faded(led_orange, 0x22), 6 });
    try imgui.DrawList_AddRect(.{ dl, x1, y1, x1 + w, y2, led_orange, 6, null, 1.2 });
    try imgui.DrawList_AddText(.{ dl, center_x - size.w / 2, y1 + 4, led_orange, text });
}

// ---- the skeuomorphic drawing: a rubber cap in a well, ringed by small orange LEDs, and a domed key ----

pub const led_orange: c_int = @bitCast(@as(u32, 0xFF8A24FF));
const led_count = 11;

pub const CapState = struct {
    hovered: bool = false,
    active: bool = false,
    disabled: bool = false,
};

fn hexColor(hex: u32) c_int {
    return @bitCast(hex);
}

/// The color with its alpha (the last byte of 0xRRGGBBAA) replaced.
fn faded(color: c_int, alpha: u32) c_int {
    const bits: u32 = @bitCast(color);
    return @bitCast((bits & 0xFFFFFF00) | alpha);
}

/// The color with each channel moved by `delta`, alpha untouched.
fn shade(color: c_int, delta: i32) c_int {
    const bits: u32 = @bitCast(color);
    var out: u32 = bits & 0xFF;
    inline for (.{ 24, 16, 8 }) |shift| {
        const channel: i32 = @intCast((bits >> shift) & 0xFF);
        const moved: u32 = @intCast(std.math.clamp(channel + delta, 0, 255));
        out |= moved << shift;
    }
    return @bitCast(out);
}

/// Draws a knob of the given radius around (cx, cy): a ring of eleven small LEDs that light up to the
/// value, over a well that holds a domed rubber cap with a pointer. The radius of the widget is the
/// radius of the outer edge of the LEDs.
pub fn drawCapKnob(dl: imgui.DrawListPtr, cx: f64, cy: f64, radius: f64, value: f64, track_start: TrackStart, state: CapState) !void {
    std.debug.assert(radius > 0);
    const ring_r = radius * 0.86;
    const led_r = @max(1.1, radius * 0.07);
    const cap_r = radius * 0.6;
    const well_r = cap_r + 2;

    const lo: f64, const hi: f64, const empty: bool = switch (track_start) {
        .left => .{ 0, value, value < 0.001 },
        .right => .{ value, 1, value > 0.999 },
        .center => .{ @min(value, 0.5), @max(value, 0.5), false },
    };
    const half_step = 0.5 / @as(f64, led_count - 1);
    for (0..led_count) |i| {
        const f = @as(f64, @floatFromInt(i)) / (led_count - 1);
        const a = angle_min() + (angle_max() - angle_min()) * f;
        const x = cx + @cos(a) * ring_r;
        const y = cy + @sin(a) * ring_r;
        const lit = !state.disabled and !empty and f >= lo - half_step and f <= hi + half_step;
        if (lit) {
            try imgui.DrawList_AddCircleFilled(.{ dl, x, y, led_r + 1.6, faded(led_orange, 0x2A), 0 });
            try imgui.DrawList_AddCircleFilled(.{ dl, x, y, led_r, led_orange, 0 });
        } else {
            try imgui.DrawList_AddCircleFilled(.{ dl, x, y, led_r - 0.2, hexColor(0x060607FF), 0 });
            try imgui.DrawList_AddCircle(.{ dl, x, y, led_r - 0.2, hexColor(0xFFFFFF14), 0 });
        }
    }

    // The well, with a faint light on its lower lip.
    try imgui.DrawList_AddCircleFilled(.{ dl, cx, cy, well_r, theme.slot_bg, 0 });
    try imgui.DrawList_AddCircle(.{ dl, cx, cy + 0.5, well_r, hexColor(0xFFFFFF18), 0 });

    // The cap sinks one pixel while it is held. From the back to the front: its shadow, its body, its
    // dome, and the shine on the dome.
    const sink: f64 = if (state.active) 1 else 0;
    const y = cy + sink;
    try imgui.DrawList_AddCircleFilled(.{ dl, cx + 0.8, y + 1.8 - sink, cap_r + 0.5, hexColor(0x000000AA), 0 });
    try imgui.DrawList_AddCircleFilled(.{ dl, cx, y, cap_r, theme.knob_body, 0 });
    try imgui.DrawList_AddCircleFilled(.{ dl, cx - 0.6, y - 0.8, cap_r - 1.8, theme.knob_top, 0 });
    try imgui.DrawList_AddCircleFilled(.{ dl, cx - 0.9, y - 1.4, cap_r - 4, hexColor(0xFFFFFF0C), 0 });
    try imgui.DrawList_AddCircleFilled(.{ dl, cx - cap_r * 0.35, y - cap_r * 0.4, cap_r * 0.2, hexColor(0xFFFFFF22), 0 });
    const edge = if (state.hovered or state.active) faded(led_orange, 0xAA) else theme.knob_edge;
    try imgui.DrawList_AddCircle(.{ dl, cx, y, cap_r, edge, 0 });

    const a = angle(value, 0.0, 1.0);
    try imgui.DrawList_AddLine(.{
        dl,
        cx + @cos(a) * cap_r * 0.35,
        y + @sin(a) * cap_r * 0.35,
        cx + @cos(a) * cap_r * 0.85,
        y + @sin(a) * cap_r * 0.85,
        if (state.disabled) theme.text_dim else theme.text,
        2,
    });

    if (state.disabled) {
        try imgui.DrawList_AddCircleFilled(.{ dl, cx, cy, ring_r + led_r + 1, hexColor(0x00000066), 0 });
    }
}

/// Draws a round key of the given radius around (cx, cy): a dome of the base color in a darker rim,
/// with a shadow under it and a shine on it. It sinks while it is held, glows orange under the mouse, and
/// is dim while disabled.
pub fn drawRoundKey(dl: imgui.DrawListPtr, cx: f64, cy: f64, radius: f64, base: c_int, state: CapState) !void {
    std.debug.assert(radius > 0);
    const sink: f64 = if (state.active) 0.8 else 0;
    const y = cy + sink;
    const delta: i32 = if (state.disabled) -70 else if (state.active) -30 else 0;
    const dome = shade(base, delta);

    const lit = !state.disabled and (state.hovered or state.active);
    // A white key glows orange, and a key that has a color glows in it.
    const glow = if (base == -1) led_orange else base;
    if (lit) try imgui.DrawList_AddCircleFilled(.{ dl, cx, y, radius + 2.5, faded(glow, if (state.active) 0x66 else 0x40), 0 });
    if (!state.active) try imgui.DrawList_AddCircleFilled(.{ dl, cx + 0.5, cy + 1.5, radius + 0.5, hexColor(0x000000AA), 0 });
    try imgui.DrawList_AddCircleFilled(.{ dl, cx, y, radius, if (lit) glow else shade(dome, -120), 0 });
    try imgui.DrawList_AddCircleFilled(.{ dl, cx, y, radius - 0.8, shade(dome, -70), 0 });
    try imgui.DrawList_AddCircleFilled(.{ dl, cx - radius * 0.14, y - radius * 0.2, radius * 0.68, dome, 0 });
    if (lit) try imgui.DrawList_AddCircleFilled(.{ dl, cx, y, radius - 0.8, faded(glow, if (state.active) 0x70 else 0x38), 0 });
    if (!state.disabled) {
        try imgui.DrawList_AddCircleFilled(.{ dl, cx - radius * 0.3, y - radius * 0.38, @max(0.9, radius * 0.2), hexColor(0xFFFFFFB0), 0 });
    }
}
