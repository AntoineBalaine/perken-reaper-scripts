//! A meter of gain reduction made of a row of round LEDs, as the meters of the Console are. It stands level with the bypass
//! button of its card, in the right half of it. The reduction grows from the right edge to the left,
//! and the color of the LEDs goes from green at the right to red at the left. An LED that is off keeps a faded copy of its own
//! color, and one that is lit shows it in full, with a halo and a shine, as a bulb does. A gauge of the reduction in dB is
//! written above the row in tiny numbers, each over the LED that lights at that reduction.
const std = @import("std");
const imgui = @import("reaper_imgui");
const Knobs = @import("knob");
const panel_theme = @import("panel_theme");
const c1_theme = @import("../theme/c1_theme.zig");
const safePrint = @import("utils").safePrint;

pub const led_count = 8;
const max_led_radius = 4.5;
const min_led_radius = 2.0;
const led_gap = 2.0;
/// The reduction in dB at which each LED lights. The first lights at any reduction, and the steps grow, as the reductions
/// that matter to an ear do.
const thresholds = [led_count]f64{ 0.05, 1.5, 3, 4.5, 6, 10, 15, 20 };

/// The numbers of the gauge, and the LED that each one stands over: the one that lights at that reduction.
const gauge = [_]struct { label: [:0]const u8, led: usize, db: f64 }{
    .{ .label = "0", .led = 0, .db = 0 },
    .{ .label = "-3", .led = 2, .db = 3 },
    .{ .label = "-6", .led = 4, .db = 6 },
    .{ .label = "-10", .led = 5, .db = 10 },
    .{ .label = "-20", .led = 7, .db = 20 },
};
/// The size of the numbers of the gauge, in pixels.
const gauge_font_size = 8.0;
/// The room that the controls under a row of LEDs keep free, which is the height of the LEDs and a margin.
pub const reserved_height: f64 = max_led_radius * 2 + 6;

/// The radius of the LEDs of a row that has this width: as large as fits, within limits.
fn ledRadius(width: f64) f64 {
    return std.math.clamp((width - (led_count - 1) * led_gap) / (led_count * 2), min_led_radius, max_led_radius);
}

/// How many LEDs are lit for a reduction in dB: those whose threshold it has reached.
pub fn litCount(reduction_db: f64) usize {
    const reduction = if (std.math.isFinite(reduction_db)) @abs(reduction_db) else 0;
    var count: usize = 0;
    for (thresholds) |threshold| {
        if (reduction >= threshold) count += 1;
    }
    return count;
}

fn channel(color: u32, shift: u5) f64 {
    return @floatFromInt((color >> shift) & 0xFF);
}

/// The color between two colors, `t` of the way from the first to the second.
fn mix(from: u32, to: u32, t: f64) u32 {
    var result: u32 = 0xFF;
    inline for ([_]u5{ 24, 16, 8 }) |shift| {
        const value = channel(from, shift) + (channel(to, shift) - channel(from, shift)) * t;
        result |= @as(u32, @intFromFloat(@round(value))) << shift;
    }
    return result;
}

/// The color of the LED `index` of `count`, from the first to the last: green, then amber, then orange, and red at the last.
fn colorAt(index: usize, count: usize) c_int {
    const stops = [_]u32{ @bitCast(panel_theme.green), @bitCast(panel_theme.amber), @bitCast(Knobs.led_orange), @bitCast(panel_theme.red) };
    const position = @as(f64, @floatFromInt(index)) / @as(f64, @floatFromInt(count - 1)) * (stops.len - 1);
    const segment: usize = @min(@as(usize, @intFromFloat(position)), stops.len - 2);
    return @bitCast(mix(stops[segment], stops[segment + 1], position - @as(f64, @floatFromInt(segment))));
}

/// The color of the LED `index` of the row of the meter of reduction, counted from the right edge.
pub fn ledColor(index: usize) c_int {
    return colorAt(index, led_count);
}

fn withAlpha(color: c_int, alpha: u32) c_int {
    const bits: u32 = @bitCast(color);
    return @bitCast((bits & 0xFFFFFF00) | alpha);
}

/// The center of the LED `index`. The first LED is at the right edge, and the others follow it to the left, as the reduction
/// grows on the meters of the Console.
fn ledCenterX(right: f64, led_radius: f64, index: usize) f64 {
    return right - led_radius - @as(f64, @floatFromInt(index)) * (led_radius * 2 + led_gap);
}

/// Draws the meter with its right edge at `right`: the row of LEDs, `width` wide and centered on `center_y`, and above it the
/// gauge in tiny numbers. While `show_value` is true and the mouse is over the meter, the reduction is written in a box above
/// it, as the value of a knob is.
pub fn draw(ctx: imgui.ContextPtr, right: f64, center_y: f64, width: f64, reduction_db: f64, show_value: bool) !void {
    const dl = try imgui.GetWindowDrawList(.{ctx});
    const led_radius = ledRadius(width);
    const lit = litCount(reduction_db);

    // The numbers are centered over their LEDs, just above the row. They are drawn at their own size, which is smaller than
    // the one of the labels: the width of a number is its width at the size of the window's font, scaled.
    const window_font_size = try imgui.GetFontSize(.{ctx});
    const gauge_y = center_y - led_radius - gauge_font_size - 2;
    for (gauge) |mark| {
        var text_w: f64 = undefined;
        var text_h: f64 = undefined;
        try imgui.CalcTextSize(.{ ctx, mark.label, &text_w, &text_h });
        const scaled_w = text_w * gauge_font_size / window_font_size;
        const x = ledCenterX(right, led_radius, mark.led);
        try imgui.DrawList_AddTextEx(.{ dl, c1_theme.fonts.MAIN, gauge_font_size, x - scaled_w / 2, gauge_y, panel_theme.text_dim, mark.label });
    }

    if (show_value) {
        const row_width = led_count * led_radius * 2 + (led_count - 1) * led_gap;
        const left = right - row_width;
        if (try imgui.IsMouseHoveringRect(.{ ctx, left - 2, gauge_y, right + 2, center_y + led_radius + 2, null })) {
            var text_buf: [32:0]u8 = undefined;
            const reduction = if (std.math.isFinite(reduction_db)) @abs(reduction_db) else 0;
            const text = safePrint(&text_buf, "{d:.1} dB", .{if (reduction < 0.05) 0 else -reduction});
            try Knobs.drawValuePopup(ctx, left + row_width / 2, gauge_y - 4, text);
        }
    }

    for (0..led_count) |i| {
        const x = ledCenterX(right, led_radius, i);
        const color = ledColor(i);
        if (i < lit) {
            try imgui.DrawList_AddCircleFilled(.{ dl, x, center_y, led_radius + 1.8, withAlpha(color, 0x2A), 0 });
            try imgui.DrawList_AddCircleFilled(.{ dl, x, center_y, led_radius, color, 0 });
            try imgui.DrawList_AddCircleFilled(.{ dl, x - led_radius * 0.3, center_y - led_radius * 0.35, led_radius * 0.35, @as(c_int, @bitCast(@as(u32, 0xFFFFFF77))), 0 });
        } else {
            try imgui.DrawList_AddCircleFilled(.{ dl, x, center_y, led_radius, @as(c_int, @bitCast(@as(u32, 0x060607FF))), 0 });
            try imgui.DrawList_AddCircleFilled(.{ dl, x, center_y, led_radius - 0.4, withAlpha(color, 0x3A), 0 });
            try imgui.DrawList_AddCircle(.{ dl, x, center_y, led_radius, @as(c_int, @bitCast(@as(u32, 0xFFFFFF14))), 0, null });
        }
    }
}

// ---- the meter of the level of the output ----

/// The level in dB at which each LED of the output meter lights, from the bottom up.
const level_thresholds = [_]f64{ -60, -48, -36, -24, -18, -12, -9, -6, -3, 0, 3, 6 };
const level_count = level_thresholds.len;

/// The numbers of the gauge of the output meter, and the LED that each one stands beside.
const level_gauge = [_]struct { label: [:0]const u8, led: usize }{
    .{ .label = "6", .led = 11 },
    .{ .label = "0", .led = 9 },
    .{ .label = "-6", .led = 7 },
    .{ .label = "-12", .led = 5 },
    .{ .label = "-24", .led = 3 },
    .{ .label = "-60", .led = 0 },
};

/// How many LEDs of the output meter are lit for a level in dB: those whose threshold the level has reached.
pub fn levelLitCount(level_db: f64) usize {
    var count: usize = 0;
    for (level_thresholds) |threshold| {
        if (level_db >= threshold) count += 1;
    }
    return count;
}

const level_led_radius = 3.3;
const level_column_gap = 3.0;
/// The space between the two columns and the numbers.
const level_label_gap = 4.0;

/// The width that the output meter needs: its two columns and the numbers beside them.
pub fn levelWidth(ctx: imgui.ContextPtr) !f64 {
    var text_w: f64 = undefined;
    var text_h: f64 = undefined;
    try imgui.CalcTextSize(.{ ctx, "-60", &text_w, &text_h });
    const window_font_size = try imgui.GetFontSize(.{ctx});
    return level_led_radius * 4 + level_column_gap + level_label_gap + text_w * gauge_font_size / window_font_size;
}

/// Draws the output meter from `top` to `bottom`, with its left edge at `left`: a column of round LEDs for each channel, which
/// light from the bottom up, and the numbers of the gauge at their right.
pub fn drawLevel(ctx: imgui.ContextPtr, left: f64, top: f64, bottom: f64, left_db: f64, right_db: f64) !void {
    const dl = try imgui.GetWindowDrawList(.{ctx});
    const first_y = bottom - level_led_radius;
    const last_y = top + level_led_radius;
    const pitch = (first_y - last_y) / @as(f64, @floatFromInt(level_count - 1));
    const columns = [_]struct { x: f64, level: f64 }{
        .{ .x = left + level_led_radius, .level = left_db },
        .{ .x = left + level_led_radius * 3 + level_column_gap, .level = right_db },
    };
    for (columns) |column| {
        const lit = levelLitCount(column.level);
        for (0..level_count) |i| {
            const y = first_y - @as(f64, @floatFromInt(i)) * pitch;
            const color = colorAt(i, level_count);
            if (i < lit) {
                try imgui.DrawList_AddCircleFilled(.{ dl, column.x, y, level_led_radius + 1.6, withAlpha(color, 0x2A), 0 });
                try imgui.DrawList_AddCircleFilled(.{ dl, column.x, y, level_led_radius, color, 0 });
                try imgui.DrawList_AddCircleFilled(.{ dl, column.x - level_led_radius * 0.3, y - level_led_radius * 0.35, level_led_radius * 0.35, @as(c_int, @bitCast(@as(u32, 0xFFFFFF77))), 0 });
            } else {
                try imgui.DrawList_AddCircleFilled(.{ dl, column.x, y, level_led_radius, @as(c_int, @bitCast(@as(u32, 0x060607FF))), 0 });
                try imgui.DrawList_AddCircleFilled(.{ dl, column.x, y, level_led_radius - 0.4, withAlpha(color, 0x3A), 0 });
                try imgui.DrawList_AddCircle(.{ dl, column.x, y, level_led_radius, @as(c_int, @bitCast(@as(u32, 0xFFFFFF14))), 0, null });
            }
        }
    }
    const label_x = left + level_led_radius * 4 + level_column_gap + level_label_gap;
    for (level_gauge) |mark| {
        const y = first_y - @as(f64, @floatFromInt(mark.led)) * pitch;
        try imgui.DrawList_AddTextEx(.{ dl, c1_theme.fonts.MAIN, gauge_font_size, label_x, y - gauge_font_size / 2, panel_theme.text_dim, mark.label });
    }
}

test "the LEDs of the output meter light from the bottom up as the level reaches their thresholds" {
    try std.testing.expectEqual(@as(usize, 0), levelLitCount(-90));
    try std.testing.expectEqual(@as(usize, 1), levelLitCount(-60));
    try std.testing.expectEqual(@as(usize, 10), levelLitCount(0));
    try std.testing.expectEqual(@as(usize, level_count), levelLitCount(6));
    // Because each number of the gauge stands beside the LED that lights at it, 0 dB is the tenth LED.
    try std.testing.expectEqual(@as(f64, 0), level_thresholds[level_gauge[1].led]);
    try std.testing.expectEqual(@as(f64, -24), level_thresholds[level_gauge[4].led]);
}

test "an LED lights when the reduction reaches its threshold, and the gauge stands over the LEDs that light at its numbers" {
    try std.testing.expectEqual(@as(usize, 0), litCount(0));
    try std.testing.expectEqual(@as(usize, 1), litCount(0.5));
    try std.testing.expectEqual(@as(usize, 3), litCount(-3));
    try std.testing.expectEqual(@as(usize, 5), litCount(6));
    try std.testing.expectEqual(@as(usize, led_count), litCount(20));
    try std.testing.expectEqual(@as(usize, led_count), litCount(60));
    try std.testing.expectEqual(@as(usize, 0), litCount(std.math.nan(f64)));
    // Because the number 3 stands over an LED, that LED lights at 3 dB, and so does each of the others.
    for (gauge) |mark| {
        if (mark.db > 0) try std.testing.expectEqual(mark.db, thresholds[mark.led]);
    }
}

test "the colors of the row go from green at the first LED to red at the last" {
    try std.testing.expectEqual(panel_theme.green, ledColor(0));
    try std.testing.expectEqual(panel_theme.red, ledColor(led_count - 1));
}
