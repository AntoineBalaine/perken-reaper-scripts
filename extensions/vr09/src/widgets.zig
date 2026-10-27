//! The panel's components, ported from the design lab's `widgets.lua`: the card that frames a group,
//! the engraved title, the lamp, the display, the push button and the toggle.
//!
//! The Zig calls mirror the Lua ones (`ImGui.DrawList_AddLine` there, `imgui.api.DrawList_AddLine`
//! here), so that a component that looks right in the lab is copied here call by call. Because a
//! frame is drawn by one thread, one window at a time, the few things that a card shares with its
//! content live in `frame`, and `ui.zig` fills the fonts in before it draws.
const std = @import("std");
const imgui = @import("reaper_imgui");
const palette = @import("ui_palette");
const theme = @import("theme.zig");
const panel_fonts = @import("fonts.zig");

const rgba = palette.rgba;

/// What the components of one frame share.
pub const Frame = struct {
    /// The fonts of the window being drawn.
    fonts: panel_fonts.Fonts = .{},
    /// The accent of the card being drawn, which the lit parts of its controls take, or null when
    /// the card has none. `beginCard` sets it and `endCard` clears it.
    accent: ?c_int = null,
    /// How many colors the card being drawn has pushed, which `endCard` pops.
    card_colors: c_int = 2,
    /// The title of the card being drawn.
    card_title: [96:0]u8 = [_:0]u8{0} ** 96,
};

pub var frame: Frame = .{};

/// The height that each card's content needs, as it was measured when the card was last drawn. Cards
/// that sit in a row take the tallest of these, so that the row has an even edge. The titles are kept
/// as hashes, because the table has a fixed size and the titles are short.
const natural_capacity = 64;
const NaturalHeight = struct { key: u64 = 0, height: f64 = 0 };
var natural_heights: [natural_capacity]NaturalHeight = [_]NaturalHeight{.{}} ** natural_capacity;

fn titleKey(title: []const u8) u64 {
    return std.hash.Wyhash.hash(0, title);
}

/// The height that the card with this title needed when it was last drawn, or null before that.
pub fn naturalHeight(title: []const u8) ?f64 {
    const key = titleKey(title);
    for (natural_heights) |entry| {
        if (entry.key == key) return entry.height;
    }
    return null;
}

fn rememberHeight(title: []const u8, height: f64) void {
    const key = titleKey(title);
    var free: ?usize = null;
    for (&natural_heights, 0..) |*entry, i| {
        if (entry.key == key) {
            entry.height = height;
            return;
        }
        if (entry.key == 0 and free == null) free = i;
    }
    if (free) |i| natural_heights[i] = .{ .key = key, .height = height };
}

/// The accent of the card being drawn, or the amber when it has none.
pub fn accent() c_int {
    return frame.accent orelse theme.amber;
}

/// The same color at a fraction of its strength, for a glow around a lit part.
pub fn faded(color: c_int, alpha: u32) c_int {
    const bits: u32 = @bitCast(color);
    return @bitCast((bits & 0xFFFFFF00) | alpha);
}

// ---- the drawing calls, with the optional arguments filled in ----

pub fn rectFilled(dl: imgui.DrawListPtr, x1: f64, y1: f64, x2: f64, y2: f64, color: c_int, rounding: f64) void {
    var r = rounding;
    imgui.api.DrawList_AddRectFilled(dl, x1, y1, x2, y2, color, &r, null);
}

pub fn rect(dl: imgui.DrawListPtr, x1: f64, y1: f64, x2: f64, y2: f64, color: c_int, rounding: f64, thickness: f64) void {
    var r = rounding;
    var t = thickness;
    imgui.api.DrawList_AddRect(dl, x1, y1, x2, y2, color, &r, null, &t);
}

pub fn line(dl: imgui.DrawListPtr, x1: f64, y1: f64, x2: f64, y2: f64, color: c_int, thickness: f64) void {
    var t = thickness;
    imgui.api.DrawList_AddLine(dl, x1, y1, x2, y2, color, &t);
}

pub fn circleFilled(dl: imgui.DrawListPtr, cx: f64, cy: f64, radius: f64, color: c_int) void {
    imgui.api.DrawList_AddCircleFilled(dl, cx, cy, radius, color, null);
}

pub fn circle(dl: imgui.DrawListPtr, cx: f64, cy: f64, radius: f64, color: c_int, thickness: f64) void {
    var t = thickness;
    imgui.api.DrawList_AddCircle(dl, cx, cy, radius, color, null, &t);
}

/// The size of a text in the current font.
pub const TextSize = struct { w: f64, h: f64 };

pub fn textSize(ctx: imgui.ContextPtr, text: [:0]const u8) TextSize {
    var w: f64 = 0;
    var h: f64 = 0;
    imgui.api.CalcTextSize(ctx, text, &w, &h, null, null);
    return .{ .w = w, .h = h };
}

pub const Point = struct { x: f64, y: f64 };

pub fn cursorScreenPos(ctx: imgui.ContextPtr) Point {
    var x: f64 = 0;
    var y: f64 = 0;
    imgui.api.GetCursorScreenPos(ctx, &x, &y);
    return .{ .x = x, .y = y };
}

// ---- the fonts ----

/// The labels are drawn in their own font. Returns true when the font was pushed, and then the caller
/// pops it with `popFont`.
pub fn pushLabelFont(ctx: imgui.ContextPtr) bool {
    if (frame.fonts.label == null) return false;
    imgui.api.PushFont(ctx, frame.fonts.label);
    return true;
}

/// The card titles are drawn in a heavier face of their own, and in the label font when there is no
/// title font.
pub fn pushTitleFont(ctx: imgui.ContextPtr) bool {
    const font = if (frame.fonts.title != null) frame.fonts.title else frame.fonts.label;
    if (font == null) return false;
    imgui.api.PushFont(ctx, font);
    return true;
}

pub fn popFont(ctx: imgui.ContextPtr, pushed: bool) void {
    if (pushed) imgui.api.PopFont(ctx);
}

// ---- the glass and the engraved text ----

/// The shine of a glass screen over its contents: a light gradient on its upper half, and faint
/// scanlines. Both are drawn over the text, in colors faint enough to leave it readable.
pub fn drawGlass(dl: imgui.DrawListPtr, x1: f64, y1: f64, x2: f64, y2: f64) void {
    imgui.api.DrawList_AddRectFilledMultiColor(dl, x1 + 2, y1 + 2, x2 - 2, (y1 + y2) / 2, rgba(0xFFFFFF18), rgba(0xFFFFFF18), rgba(0xFFFFFF00), rgba(0xFFFFFF00));
    var ly = y1 + 3;
    while (ly <= y2 - 3) : (ly += 3) line(dl, x1 + 2, ly, x2 - 2, ly, rgba(0x00000028), 1);
}

/// Text that looks cut into the panel: a dark copy one pixel below, the light text over it.
pub fn engravedText(ctx: imgui.ContextPtr, text: [:0]const u8, color: ?c_int) void {
    const pushed = pushTitleFont(ctx);
    const dl = imgui.api.GetWindowDrawList(ctx);
    const at = cursorScreenPos(ctx);
    imgui.api.DrawList_AddText(dl, at.x, at.y + 1, theme.text_engraved_shadow, text);
    imgui.api.DrawList_AddText(dl, at.x, at.y, color orelse theme.text_dim, text);
    const size = textSize(ctx, text);
    imgui.api.Dummy(ctx, size.w, size.h + 1);
    popFont(ctx, pushed);
}

// ---- the lamp and the display ----

/// A lamp, lit in the given color or dark, as big as a line of text, so that text can follow it.
pub fn lamp(ctx: imgui.ContextPtr, color: c_int, lit: bool) void {
    const at = cursorScreenPos(ctx);
    const size = imgui.api.GetTextLineHeight(ctx);
    imgui.api.Dummy(ctx, size, size);
    const dl = imgui.api.GetWindowDrawList(ctx);
    const cx = at.x + size / 2;
    const cy = at.y + size / 2;
    if (lit) circleFilled(dl, cx, cy, size / 2 + 1, faded(color, 0x44));
    circleFilled(dl, cx, cy, 5, if (lit) color else theme.slot_bg);
    circle(dl, cx, cy, 5, theme.slot_edge, 1);
    if (lit) circleFilled(dl, cx - 1.5, cy - 1.5, 1.2, rgba(0xFFFFFF99));
}

/// A small recessed screen with a line of text in it, at least `min_width` pixels wide. The text is in
/// the label font.
pub fn display(ctx: imgui.ContextPtr, text: [:0]const u8, color: c_int, min_width: f64) void {
    const at = cursorScreenPos(ctx);
    const pushed = pushLabelFont(ctx);
    const size = textSize(ctx, text);
    const width = @max(min_width, size.w + 20);
    const height = size.h + 10;
    imgui.api.Dummy(ctx, width, height);
    const dl = imgui.api.GetWindowDrawList(ctx);
    rectFilled(dl, at.x, at.y, at.x + width, at.y + height, theme.slot_bg, 3);
    rect(dl, at.x, at.y, at.x + width, at.y + height, theme.slot_edge, 3, 1);
    line(dl, at.x + 3, at.y + height + 1, at.x + width - 3, at.y + height + 1, theme.panel_edge_light, 1);
    imgui.api.DrawList_AddText(dl, at.x + 10, at.y + 5, color, text);
    drawGlass(dl, at.x, at.y, at.x + width, at.y + height);
    popFont(ctx, pushed);
}

// ---- the push button and the toggle ----

/// The id of a widget that has no label of its own in ImGui: a prefix and the visible label.
fn widgetId(buf: []u8, prefix: []const u8, label: []const u8) [:0]const u8 {
    return std.fmt.bufPrintZ(buf, "##{s}{s}", .{ prefix, label }) catch "##widget";
}

/// A push button: a raised key of dark metal with a lit upper edge, that sinks while it is held, with
/// the accent over it when the mouse is on it or it is held. Returns true when it was clicked.
pub fn pushButton(ctx: imgui.ContextPtr, label: [:0]const u8, min_width: f64) bool {
    const pushed = pushLabelFont(ctx);
    defer popFont(ctx, pushed);
    const size = textSize(ctx, label);
    const width = @max(min_width, size.w + 28);
    const height = size.h + 12;
    const at = cursorScreenPos(ctx);
    var id: [128]u8 = undefined;
    const clicked = imgui.api.InvisibleButton(ctx, widgetId(&id, "button", label), width, height, null);
    const hovered = imgui.api.IsItemHovered(ctx, null);
    const held = imgui.api.IsItemActive(ctx);

    const dl = imgui.api.GetWindowDrawList(ctx);
    const sink: f64 = if (held) 1 else 0;
    const top = at.y + sink;
    const bottom = at.y + height + sink;
    if (!held) rectFilled(dl, at.x, top + 2, at.x + width, bottom + 2, rgba(0x00000099), 4);
    rectFilled(dl, at.x, top, at.x + width, bottom, if (held) theme.knob_body else theme.knob_top, 4);
    imgui.api.DrawList_AddRectFilledMultiColor(dl, at.x + 2, top + 2, at.x + width - 2, top + height / 2, rgba(0xFFFFFF18), rgba(0xFFFFFF18), rgba(0xFFFFFF00), rgba(0xFFFFFF00));
    if (held) {
        rectFilled(dl, at.x, top, at.x + width, bottom, faded(accent(), 0x40), 4);
    } else if (hovered) {
        rectFilled(dl, at.x, top, at.x + width, bottom, faded(accent(), 0x22), 4);
    }
    rect(dl, at.x, top, at.x + width, bottom, if (hovered or held) accent() else theme.knob_edge, 4, 1);
    line(dl, at.x + 5, top + 1.5, at.x + width - 5, top + 1.5, rgba(0xFFFFFF30), 1);
    imgui.api.DrawList_AddText(dl, at.x + (width - size.w) / 2, top + (height - size.h) / 2, if (held) accent() else theme.text, label);
    return clicked;
}

const toggle_w: f64 = 30;
const toggle_h: f64 = 16;

/// A toggle with a label: a rocker whose thumb slides to the right and lights up in the accent when
/// the value is on. Returns true when the user changed the value, and `value` then holds the new one.
pub fn toggle(ctx: imgui.ContextPtr, label: [:0]const u8, value: *bool) bool {
    const text_line = imgui.api.GetTextLineHeight(ctx);
    const text_w = textSize(ctx, label).w;
    const height = @max(text_line, toggle_h) + 4;
    const at = cursorScreenPos(ctx);
    var id: [128]u8 = undefined;
    const clicked = imgui.api.InvisibleButton(ctx, widgetId(&id, "toggle", label), toggle_w + 10 + text_w, height, null);
    const hot = imgui.api.IsItemHovered(ctx, null);
    if (clicked) value.* = !value.*;
    const on = value.*;

    const dl = imgui.api.GetWindowDrawList(ctx);
    const ty = at.y + (height - toggle_h) / 2;
    rectFilled(dl, at.x, ty, at.x + toggle_w, ty + toggle_h, if (on) faded(accent(), 0x55) else theme.slot_bg, toggle_h / 2);
    rect(dl, at.x, ty, at.x + toggle_w, ty + toggle_h, if (hot) accent() else theme.knob_edge, toggle_h / 2, 1);
    const thumb_x = if (on) at.x + toggle_w - toggle_h / 2 else at.x + toggle_h / 2;
    const thumb_y = ty + toggle_h / 2;
    if (on) circleFilled(dl, thumb_x, thumb_y, toggle_h / 2 + 1, faded(accent(), 0x44));
    circleFilled(dl, thumb_x + 0.5, thumb_y + 1.5, toggle_h / 2 - 3, rgba(0x00000099));
    circleFilled(dl, thumb_x, thumb_y, toggle_h / 2 - 3, if (on) accent() else theme.knob_top);
    circleFilled(dl, thumb_x - 1.5, thumb_y - 1.5, 1.2, rgba(0xFFFFFF66));
    imgui.api.DrawList_AddText(dl, at.x + toggle_w + 10, at.y + (height - text_line) / 2, theme.text, label);
    return clicked;
}

// ---- the card ----

/// A framed section of the panel, with its title engraved on top. A card may have an accent color,
/// which tints its top and its title and is taken by the lit parts of the controls it holds. A card
/// that is given a width or a height keeps it, and otherwise it grows with what it holds. Returns true
/// when the card is drawn, and then `endCard` must follow.
pub fn beginCard(ctx: imgui.ContextPtr, title: []const u8, width: ?f64, height: ?f64, card_accent: ?c_int) bool {
    frame.accent = card_accent;
    imgui.api.PushStyleColor(ctx, imgui.Col_ChildBg, theme.panel_bg);
    imgui.api.PushStyleColor(ctx, imgui.Col_Border, theme.panel_edge_dark);
    // In a card with an accent, the widgets that are not drawn by hand light up with the accent: a
    // light shade of it when the mouse is over them, and the accent itself while they are clicked.
    frame.card_colors = 2;
    if (card_accent) |tint| {
        const hover = faded(tint, 0x40);
        imgui.api.PushStyleColor(ctx, imgui.Col_FrameBgHovered, hover);
        imgui.api.PushStyleColor(ctx, imgui.Col_FrameBgActive, tint);
        imgui.api.PushStyleColor(ctx, imgui.Col_ButtonHovered, faded(tint, 0x55));
        imgui.api.PushStyleColor(ctx, imgui.Col_ButtonActive, tint);
        imgui.api.PushStyleColor(ctx, imgui.Col_HeaderHovered, hover);
        imgui.api.PushStyleColor(ctx, imgui.Col_HeaderActive, tint);
        frame.card_colors = 8;
    }
    var flags: c_int = imgui.ChildFlags_Border;
    if (width == null) flags |= imgui.ChildFlags_AutoResizeX;
    if (height == null) flags |= imgui.ChildFlags_AutoResizeY;
    var window_flags: c_int = imgui.WindowFlags_NoScrollbar;
    var w: f64 = width orelse 0;
    var h: f64 = height orelse 0;
    var id: [128:0]u8 = undefined;
    const visible = imgui.api.BeginChild(ctx, widgetId(&id, "card", title), &w, &h, &flags, &window_flags);
    const kept = @min(title.len, frame.card_title.len - 1);
    @memcpy(frame.card_title[0..kept], title[0..kept]);
    frame.card_title[kept] = 0;
    if (visible) {
        var upper: [96:0]u8 = undefined;
        const shown = std.ascii.upperString(upper[0..kept], title[0..kept]);
        upper[shown.len] = 0;
        engravedText(ctx, upper[0..shown.len :0], card_accent);
        imgui.api.Spacing(ctx);
    } else {
        // Because `endCard` does not follow a card that is not drawn, its colors are popped here.
        var count = frame.card_colors;
        imgui.api.PopStyleColor(ctx, &count);
        frame.accent = null;
    }
    return visible;
}

/// The angle of the slot of each corner's screw, so that no two screws are alike.
const screw_angles = [4]f64{ 0.4, 1.2, 2.1, 2.9 };

fn drawScrew(dl: imgui.DrawListPtr, x: f64, y: f64, angle: f64) void {
    circleFilled(dl, x + 1, y + 1, 3.2, rgba(0x000000AA));
    circleFilled(dl, x, y, 3.2, theme.screw_body);
    circle(dl, x, y, 3.2, theme.card_bevel_dark, 1);
    circleFilled(dl, x - 1, y - 1, 0.9, theme.screw_light);
    const dx = @cos(angle) * 2.2;
    const dy = @sin(angle) * 2.2;
    line(dl, x - dx, y - dy, x + dx, y + dy, theme.screw_slot, 1.5);
}

/// Draws the surface of the card over its background: a gradient, a brushed grain, a bevel on its
/// edges, and a screw in each corner. Because the card grows with what it holds, this is drawn when it
/// ends, and the colors are so faint that what they cover stays readable.
fn drawCardSurface(ctx: imgui.ContextPtr, card_accent: ?c_int) void {
    const dl = imgui.api.GetWindowDrawList(ctx);
    var x: f64 = 0;
    var y: f64 = 0;
    imgui.api.GetWindowPos(ctx, &x, &y);
    var w: f64 = 0;
    var h: f64 = 0;
    imgui.api.GetWindowSize(ctx, &w, &h);

    // The inside of the rounded corners is left out, so that the square gradient does not show there.
    const x1 = x + 3;
    const y1 = y + 3;
    const x2 = x + w - 3;
    const y2 = y + h - 3;
    imgui.api.DrawList_AddRectFilledMultiColor(dl, x1, y1, x2, y2, theme.card_light, theme.card_light, theme.card_shade, theme.card_shade);
    var ly = y1;
    while (ly <= y2) : (ly += 3) line(dl, x1, ly, x2, ly, theme.card_grain, 1);

    // A card with an accent is washed with it at the top and has a band of it along its top edge.
    if (card_accent) |tint| {
        const wash = faded(tint, 0x30);
        imgui.api.DrawList_AddRectFilledMultiColor(dl, x1, y1, x2, y1 + 34, wash, wash, rgba(0x00000000), rgba(0x00000000));
        rectFilled(dl, x + 10, y + 3, x + w - 10, y + 5, tint, 1);
    }

    line(dl, x + 7, y + 1.5, x + w - 7, y + 1.5, theme.card_bevel_light, 1);
    line(dl, x + 7, y + h - 1.5, x + w - 7, y + h - 1.5, theme.card_bevel_dark, 1);

    drawScrew(dl, x + 8, y + 8, screw_angles[0]);
    drawScrew(dl, x + w - 8, y + 8, screw_angles[1]);
    drawScrew(dl, x + 8, y + h - 8, screw_angles[2]);
    drawScrew(dl, x + w - 8, y + h - 8, screw_angles[3]);
}

pub fn endCard(ctx: imgui.ContextPtr) void {
    // The content ends where the cursor is, less the spacing that follows the last item, and the card's
    // bottom padding is added; the 2 pixels keep the card from cutting its last line.
    var spacing_x: f64 = 0;
    var spacing_y: f64 = 0;
    imgui.api.GetStyleVar(ctx, imgui.StyleVar_ItemSpacing, &spacing_x, &spacing_y);
    var padding_x: f64 = 0;
    var padding_y: f64 = 0;
    imgui.api.GetStyleVar(ctx, imgui.StyleVar_WindowPadding, &padding_x, &padding_y);
    rememberHeight(std.mem.sliceTo(&frame.card_title, 0), imgui.api.GetCursorPosY(ctx) - spacing_y + padding_y + 2);
    drawCardSurface(ctx, frame.accent);
    frame.accent = null;
    imgui.api.EndChild(ctx);
    var count = frame.card_colors;
    imgui.api.PopStyleColor(ctx, &count);
}

// Because Zig only compiles the functions that something calls, this test makes the whole module compile,
// including the components that the panel does not draw yet.
test "every component compiles" {
    std.testing.refAllDecls(@This());
}
