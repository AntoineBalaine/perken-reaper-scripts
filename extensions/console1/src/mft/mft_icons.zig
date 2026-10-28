//! The icons of the MFT panel. They are drawn with geometry (lines,
//! circles, arcs and triangles), so that they need neither a font nor an image. Each one is drawn around a center,
//! inside a square of `r` pixels from the center, in two colors: the one of the strokes, and the accent of the details
//! that move or point.
const std = @import("std");
const imgui = @import("reaper_imgui");
const widgets = @import("panel_widgets");
const palette = @import("ui_palette");

const rgba = palette.rgba;
const Dl = imgui.DrawListPtr;

pub const Icon = enum {
    jog,
    play_pause,
    zoom_h,
    zoom_v,
    rate,
    grid,
    track,
    marker,
    chain,
    hide,
    fxsel,
    mute,
    solo,
    phase,
};

/// The icon of the rotation of each of the eight top encoders in transport mode.
pub const transport = [8]Icon{ .jog, .play_pause, .zoom_h, .zoom_v, .rate, .grid, .track, .marker };

const pi = std.math.pi;

/// The jog wheel: a ring with a hub, and an arrow on each side of it.
fn jog(dl: Dl, cx: f64, cy: f64, r: f64, color: c_int, accent: c_int) void {
    widgets.circle(dl, cx, cy, r * 0.5, color, 2);
    widgets.circleFilled(dl, cx, cy, r * 0.12, color);
    imgui.api.DrawList_AddTriangleFilled(dl, cx - r, cy, cx - r * 0.66, cy - r * 0.3, cx - r * 0.66, cy + r * 0.3, accent);
    imgui.api.DrawList_AddTriangleFilled(dl, cx + r, cy, cx + r * 0.66, cy - r * 0.3, cx + r * 0.66, cy + r * 0.3, accent);
}

/// Play and pause: the play triangle, and the two bars of the pause. Nothing else is drawn, so that it cannot be read
/// as a stop.
fn playPause(dl: Dl, cx: f64, cy: f64, r: f64, color: c_int, accent: c_int) void {
    imgui.api.DrawList_AddTriangleFilled(dl, cx - r * 0.95, cy - r * 0.6, cx - r * 0.95, cy + r * 0.6, cx - r * 0.05, cy, accent);
    widgets.rectFilled(dl, cx + r * 0.3, cy - r * 0.6, cx + r * 0.55, cy + r * 0.6, color, 1);
    widgets.rectFilled(dl, cx + r * 0.75, cy - r * 0.6, cx + r * 1.0, cy + r * 0.6, color, 1);
}

/// A magnifying glass: the lens, and its handle.
fn lens(dl: Dl, cx: f64, cy: f64, r: f64, color: c_int) void {
    widgets.circle(dl, cx, cy, r * 0.5, color, 2);
    widgets.line(dl, cx + r * 0.36, cy + r * 0.36, cx + r * 0.82, cy + r * 0.82, color, 3);
}

/// The horizontal zoom: a lens, and a double arrow under it that points left and right.
fn zoomH(dl: Dl, cx: f64, cy: f64, r: f64, color: c_int, accent: c_int) void {
    lens(dl, cx - r * 0.2, cy - r * 0.3, r * 0.8, color);
    const y = cy + r * 0.85;
    widgets.line(dl, cx - r * 0.7, y, cx + r * 0.7, y, accent, 2);
    imgui.api.DrawList_AddTriangleFilled(dl, cx - r * 0.95, y, cx - r * 0.65, y - r * 0.2, cx - r * 0.65, y + r * 0.2, accent);
    imgui.api.DrawList_AddTriangleFilled(dl, cx + r * 0.95, y, cx + r * 0.65, y - r * 0.2, cx + r * 0.65, y + r * 0.2, accent);
}

/// The vertical zoom: a lens, and a double arrow beside it that points up and down.
fn zoomV(dl: Dl, cx: f64, cy: f64, r: f64, color: c_int, accent: c_int) void {
    lens(dl, cx - r * 0.4, cy - r * 0.2, r * 0.8, color);
    const x = cx + r * 0.85;
    widgets.line(dl, x, cy - r * 0.7, x, cy + r * 0.7, accent, 2);
    imgui.api.DrawList_AddTriangleFilled(dl, x, cy - r * 0.95, x - r * 0.2, cy - r * 0.65, x + r * 0.2, cy - r * 0.65, accent);
    imgui.api.DrawList_AddTriangleFilled(dl, x, cy + r * 0.95, x - r * 0.2, cy + r * 0.65, x + r * 0.2, cy + r * 0.65, accent);
}

/// The play rate: a gauge with its scale and a needle.
fn rate(dl: Dl, cx: f64, cy: f64, r: f64, color: c_int, accent: c_int) void {
    const from = pi * 0.8;
    const to = pi * 2.2;
    widgets.arc(dl, cx, cy + r * 0.2, r * 0.9, from, to, color, 2);
    for (0..5) |i| {
        const a = from + (to - from) * @as(f64, @floatFromInt(i)) / 4;
        widgets.line(dl, cx + @cos(a) * r * 0.9, cy + r * 0.2 + @sin(a) * r * 0.9, cx + @cos(a) * r * 0.68, cy + r * 0.2 + @sin(a) * r * 0.68, color, 1);
    }
    const needle = from + (to - from) * 0.55;
    widgets.line(dl, cx, cy + r * 0.2, cx + @cos(needle) * r * 0.75, cy + r * 0.2 + @sin(needle) * r * 0.75, accent, 2);
    widgets.circleFilled(dl, cx, cy + r * 0.2, r * 0.12, accent);
}

/// The grid: a square cut by two lines each way.
fn grid(dl: Dl, cx: f64, cy: f64, r: f64, color: c_int, accent: c_int) void {
    const a = r * 0.85;
    widgets.rect(dl, cx - a, cy - a, cx + a, cy + a, color, 2, 2);
    for ([2]f64{ -a / 3, a / 3 }) |offset| {
        widgets.line(dl, cx + offset, cy - a, cx + offset, cy + a, accent, 1);
        widgets.line(dl, cx - a, cy + offset, cx + a, cy + offset, accent, 1);
    }
}

/// The track select: three tracks one above the other, and an arrow that goes down.
fn track(dl: Dl, cx: f64, cy: f64, r: f64, color: c_int, accent: c_int) void {
    var i: i32 = -1;
    while (i <= 1) : (i += 1) {
        const y = cy + @as(f64, @floatFromInt(i)) * r * 0.55;
        widgets.rectFilled(dl, cx - r * 0.95, y - r * 0.15, cx + r * 0.35, y + r * 0.15, if (i == 0) accent else color, 2);
    }
    widgets.line(dl, cx + r * 0.7, cy - r * 0.7, cx + r * 0.7, cy + r * 0.45, color, 2);
    imgui.api.DrawList_AddTriangleFilled(dl, cx + r * 0.7, cy + r * 0.95, cx + r * 0.45, cy + r * 0.45, cx + r * 0.95, cy + r * 0.45, color);
}

/// The marker jog: a flag on a pole, and under it a double arrow that points left and right, the directions in which
/// the jog moves from marker to marker.
fn marker(dl: Dl, cx: f64, cy: f64, r: f64, color: c_int, accent: c_int) void {
    widgets.line(dl, cx - r * 0.3, cy - r * 0.95, cx - r * 0.3, cy + r * 0.4, color, 2);
    imgui.api.DrawList_AddTriangleFilled(dl, cx - r * 0.3, cy - r * 0.95, cx + r * 0.9, cy - r * 0.55, cx - r * 0.3, cy - r * 0.1, accent);
    const y = cy + r * 0.85;
    widgets.line(dl, cx - r * 0.7, y, cx + r * 0.7, y, color, 2);
    imgui.api.DrawList_AddTriangleFilled(dl, cx - r * 0.95, y, cx - r * 0.65, y - r * 0.2, cx - r * 0.65, y + r * 0.2, color);
    imgui.api.DrawList_AddTriangleFilled(dl, cx + r * 0.95, y, cx + r * 0.65, y - r * 0.2, cx + r * 0.65, y + r * 0.2, color);
}

// ---- the icons of the side keys, small ones ----

/// The chain: two links, one through the other.
fn chain(dl: Dl, cx: f64, cy: f64, r: f64, color: c_int, _: c_int) void {
    widgets.rect(dl, cx - r, cy - r * 0.5, cx + r * 0.25, cy + r * 0.5, color, r * 0.5, 1.6);
    widgets.rect(dl, cx - r * 0.25, cy - r * 0.5, cx + r, cy + r * 0.5, color, r * 0.5, 1.6);
}

/// Hide: an eye with a line across it.
fn hide(dl: Dl, cx: f64, cy: f64, r: f64, color: c_int, _: c_int) void {
    widgets.arc(dl, cx, cy + r * 0.6, r * 1.05, pi * 1.25, pi * 1.75, color, 1.6);
    widgets.arc(dl, cx, cy - r * 0.6, r * 1.05, pi * 0.25, pi * 0.75, color, 1.6);
    widgets.circleFilled(dl, cx, cy, r * 0.28, color);
    widgets.line(dl, cx - r, cy + r * 0.85, cx + r, cy - r * 0.85, color, 1.6);
}

/// The plugin selector: a chip with pins on its two sides.
fn fxsel(dl: Dl, cx: f64, cy: f64, r: f64, color: c_int, _: c_int) void {
    widgets.rect(dl, cx - r * 0.55, cy - r * 0.65, cx + r * 0.55, cy + r * 0.65, color, 2, 1.6);
    var i: i32 = -1;
    while (i <= 1) : (i += 1) {
        const y = cy + @as(f64, @floatFromInt(i)) * r * 0.4;
        widgets.line(dl, cx - r * 0.95, y, cx - r * 0.55, y, color, 1.4);
        widgets.line(dl, cx + r * 0.55, y, cx + r * 0.95, y, color, 1.4);
    }
    widgets.circleFilled(dl, cx, cy, r * 0.16, color);
}

/// Mute: a loudspeaker with a cross.
fn mute(dl: Dl, cx: f64, cy: f64, r: f64, color: c_int, _: c_int) void {
    widgets.rectFilled(dl, cx - r, cy - r * 0.32, cx - r * 0.4, cy + r * 0.32, color, 0);
    imgui.api.DrawList_AddTriangleFilled(dl, cx - r * 0.4, cy - r * 0.32, cx + r * 0.2, cy - r * 0.85, cx + r * 0.2, cy + r * 0.85, color);
    imgui.api.DrawList_AddTriangleFilled(dl, cx - r * 0.4, cy - r * 0.32, cx + r * 0.2, cy + r * 0.85, cx - r * 0.4, cy + r * 0.32, color);
    widgets.line(dl, cx + r * 0.5, cy - r * 0.4, cx + r * 1.05, cy + r * 0.4, color, 1.6);
    widgets.line(dl, cx + r * 0.5, cy + r * 0.4, cx + r * 1.05, cy - r * 0.4, color, 1.6);
}

/// Solo: headphones.
fn solo(dl: Dl, cx: f64, cy: f64, r: f64, color: c_int, _: c_int) void {
    widgets.arc(dl, cx, cy + r * 0.1, r * 0.85, pi, pi * 2, color, 1.8);
    widgets.rectFilled(dl, cx - r * 1.0, cy + r * 0.05, cx - r * 0.5, cy + r * 0.9, color, 2);
    widgets.rectFilled(dl, cx + r * 0.5, cy + r * 0.05, cx + r * 1.0, cy + r * 0.9, color, 2);
}

/// Phase: the sign of an inverted phase, a circle with a line across it.
fn phase(dl: Dl, cx: f64, cy: f64, r: f64, color: c_int, _: c_int) void {
    widgets.circle(dl, cx, cy, r * 0.7, color, 1.7);
    widgets.line(dl, cx - r * 0.95, cy + r * 0.95, cx + r * 0.95, cy - r * 0.95, color, 1.7);
}

/// Draws the flat icon, with no volume.
fn drawFlat(dl: Dl, icon: Icon, cx: f64, cy: f64, r: f64, color: c_int, accent: c_int) void {
    switch (icon) {
        .jog => jog(dl, cx, cy, r, color, accent),
        .play_pause => playPause(dl, cx, cy, r, color, accent),
        .zoom_h => zoomH(dl, cx, cy, r, color, accent),
        .zoom_v => zoomV(dl, cx, cy, r, color, accent),
        .rate => rate(dl, cx, cy, r, color, accent),
        .grid => grid(dl, cx, cy, r, color, accent),
        .track => track(dl, cx, cy, r, color, accent),
        .marker => marker(dl, cx, cy, r, color, accent),
        .chain => chain(dl, cx, cy, r, color, accent),
        .hide => hide(dl, cx, cy, r, color, accent),
        .fxsel => fxsel(dl, cx, cy, r, color, accent),
        .mute => mute(dl, cx, cy, r, color, accent),
        .solo => solo(dl, cx, cy, r, color, accent),
        .phase => phase(dl, cx, cy, r, color, accent),
    }
}

// ---- the volume of an icon ----

/// The tone of a color made darker: each channel is multiplied by `factor`, and the opacity is kept.
pub fn shade(color: c_int, factor: f64) c_int {
    const bits: u32 = @bitCast(color);
    const r: u32 = @intFromFloat(@floor(@as(f64, @floatFromInt((bits >> 24) & 0xFF)) * factor));
    const g: u32 = @intFromFloat(@floor(@as(f64, @floatFromInt((bits >> 16) & 0xFF)) * factor));
    const b: u32 = @intFromFloat(@floor(@as(f64, @floatFromInt((bits >> 8) & 0xFF)) * factor));
    return @bitCast((r << 24) | (g << 16) | (b << 8) | (bits & 0xFF));
}

/// How far the icon is extruded: the number of stacked copies that make its side, and the offset of the farthest one,
/// down and to the right, in pixels. The side is darker the farther it is from the face.
const wall_layers = 4;
const wall_dx: f64 = 1.1;
const wall_dy: f64 = 1.7;
/// How much of the face's brightness the nearest and the farthest copy keep.
const wall_near: f64 = 0.62;
const wall_far: f64 = 0.30;

/// The soft shadow that the icon throws on the surface, as two copies farther than the wall: their offsets and
/// opacities.
const Shadow = struct { dx: f64, dy: f64, alpha: u32 };
const shadows = [2]Shadow{ .{ .dx = 2.1, .dy = 3.0, .alpha = 0x2A }, .{ .dx = 1.5, .dy = 2.3, .alpha = 0x44 } };

/// The light edge on the upper left of the face.
const rim = rgba(0xFFFFFF58);
const rim_dx: f64 = -0.55;
const rim_dy: f64 = -0.7;

/// Draws an icon around the center (cx, cy), `r` pixels from the center to the edge of its square. With `depth`, the
/// icon has volume, as if it were cut out of a thick piece of material and stood on the surface: from the back to the
/// front, it is drawn as two soft shadows, then as a stack of copies that grow brighter toward the face and form its
/// side wall, then as a light edge that shows on the upper left of the face, and then as the face itself. The shadows
/// are black, or a faded `shadow_color` when it is given, such as the accent of the mode in use.
pub fn draw(dl: Dl, icon: Icon, cx: f64, cy: f64, r: f64, color: c_int, accent: c_int, depth: bool, shadow_color: ?c_int) void {
    if (depth) {
        for (shadows) |shadow| {
            // A black shadow is the opacity alone, and a tinted one takes the color with that opacity.
            const tone: c_int = if (shadow_color) |tint| widgets.faded(tint, shadow.alpha) else @bitCast(shadow.alpha);
            drawFlat(dl, icon, cx + shadow.dx, cy + shadow.dy, r, tone, tone);
        }
        var layer: u32 = wall_layers;
        while (layer >= 1) : (layer -= 1) {
            const t = @as(f64, @floatFromInt(layer)) / wall_layers;
            const factor = wall_near + (wall_far - wall_near) * t;
            drawFlat(dl, icon, cx + wall_dx * t, cy + wall_dy * t, r, shade(color, factor), shade(accent, factor));
        }
        drawFlat(dl, icon, cx + rim_dx, cy + rim_dy, r, rim, rim);
    }
    drawFlat(dl, icon, cx, cy, r, color, accent);
}

test "every icon draws flat and with volume, and leaves the stacks balanced" {
    const MockImGui = @import("mock_imgui").MockImGui;
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    inline for (@typeInfo(Icon).@"enum".fields) |field| {
        const icon: Icon = @enumFromInt(field.value);
        draw(null, icon, 50, 50, 14, rgba(0xD6D2C6FF), rgba(0xD6D2C6FF), false, null);
        draw(null, icon, 50, 50, 14, rgba(0xD6D2C6FF), rgba(0x4FD68AFF), true, rgba(0x4FD68AFF));
    }
    try mock.assertBalanced();
}

test "the shade of a color keeps its opacity and darkens its channels" {
    const shaded: u32 = @bitCast(shade(rgba(0x80C0FF7F), 0.5));
    try std.testing.expectEqual(@as(u32, 0x40607F7F), shaded);
}
