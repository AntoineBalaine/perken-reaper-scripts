//! The components of a hardware-style panel, ported from the VR-09 design lab's `widgets.lua`: the card that
//! frames a group, the engraved title, the lamp, the display, the push button, the toggle, the knobs, the
//! drawbar, the envelope screen, the picker and the tabs.
//!
//! The Zig calls mirror the Lua ones (`ImGui.DrawList_AddLine` there, `imgui.api.DrawList_AddLine`
//! here), so that a component that looks right in the lab is copied here call by call. Because a
//! frame is drawn by one thread, the few things that a card shares with its content live in a `Panel`,
//! the context object that every component takes as its first argument.
const std = @import("std");
const imgui = @import("reaper_imgui");
const palette = @import("ui_palette");
const theme = @import("panel_theme");
const panel_fonts = @import("panel_fonts");

const rgba = palette.rgba;

/// The height that each card's content needs, as it was measured when the card was last drawn. Cards that
/// sit in a row take the tallest of these, so that the row has an even edge. The titles are kept as hashes,
/// because the table has a fixed size and the titles are short.
const natural_capacity = 64;
const NaturalHeight = struct { key: u64 = 0, height: f64 = 0 };

/// A panel being drawn: the context that every component takes as its first argument. It holds the ImGui
/// context, the fonts, what a card shares with the components inside it (its accent, the colors it pushed and
/// its title), the knob drag that is going on and the heights that the cards measured. Because the state is
/// in the object and not in the module, each window has its own, and a window can be drawn at any time
/// without disturbing another. The window makes one, and sets `ctx` and `fonts` before it draws a panel.
pub const Panel = struct {
    /// The ReaImGui context of the window being drawn.
    ctx: imgui.ContextPtr = null,
    /// The fonts of the window being drawn.
    fonts: panel_fonts.Fonts = .{},
    /// The accent of the card being drawn, which the lit parts of its controls take, or null when the card has
    /// none. `beginCard` sets it and `endCard` clears it.
    accent: ?c_int = null,
    /// How many colors the card being drawn has pushed, which `endCard` pops.
    card_colors: c_int = 2,
    /// The title of the card being drawn.
    card_title: [96:0]u8 = [_:0]u8{0} ** 96,
    /// The knob drag that is going on: a drag moves the value relative to where it started.
    drag: Drag = .{},
    /// The heights that the cards needed when they were last drawn.
    heights: [natural_capacity]NaturalHeight = [_]NaturalHeight{.{}} ** natural_capacity,
};

fn titleKey(title: []const u8) u64 {
    return std.hash.Wyhash.hash(0, title);
}

/// The height that the card with this title needed when it was last drawn, or null before that.
pub fn naturalHeight(panel: *const Panel, title: []const u8) ?f64 {
    const key = titleKey(title);
    for (panel.heights) |entry| {
        if (entry.key == key) return entry.height;
    }
    return null;
}

fn rememberHeight(panel: *Panel, title: []const u8, height: f64) void {
    const key = titleKey(title);
    var free: ?usize = null;
    for (&panel.heights, 0..) |*entry, i| {
        if (entry.key == key) {
            entry.height = height;
            return;
        }
        if (entry.key == 0 and free == null) free = i;
    }
    if (free) |i| panel.heights[i] = .{ .key = key, .height = height };
}

/// The accent of the card being drawn, or the amber when it has none.
pub fn accent(panel: *const Panel) c_int {
    return panel.accent orelse theme.amber;
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

/// An arc stroked as a line, from one angle to another. ImGui's angles start at the right and grow clockwise on
/// the screen. Because the path is stroked at once, no path is left open in the draw list.
pub fn arc(dl: imgui.DrawListPtr, cx: f64, cy: f64, radius: f64, from: f64, to: f64, color: c_int, thickness: f64) void {
    var flags: c_int = imgui.DrawFlags_None;
    var t = thickness;
    imgui.api.DrawList_PathArcTo(dl, cx, cy, radius, from, to, null);
    imgui.api.DrawList_PathStroke(dl, color, &flags, &t);
}

/// The size of a text in the current font.
pub const TextSize = struct { w: f64, h: f64 };

pub fn textSize(panel: *Panel, text: [:0]const u8) TextSize {
    const ctx = panel.ctx;
    var w: f64 = 0;
    var h: f64 = 0;
    imgui.api.CalcTextSize(ctx, text, &w, &h, null, null);
    return .{ .w = w, .h = h };
}

pub const Point = struct { x: f64, y: f64 };

pub fn cursorScreenPos(panel: *Panel) Point {
    const ctx = panel.ctx;
    var x: f64 = 0;
    var y: f64 = 0;
    imgui.api.GetCursorScreenPos(ctx, &x, &y);
    return .{ .x = x, .y = y };
}

// ---- the fonts ----

/// The labels are drawn in their own font. Returns true when the font was pushed, and then the caller
/// pops it with `popFont`.
pub fn pushLabelFont(panel: *Panel) bool {
    const ctx = panel.ctx;
    if (panel.fonts.label == null) return false;
    imgui.api.PushFont(ctx, panel.fonts.label);
    return true;
}

/// The card titles are drawn in a heavier face of their own, and in the label font when there is no
/// title font.
pub fn pushTitleFont(panel: *Panel) bool {
    const ctx = panel.ctx;
    const font = if (panel.fonts.title != null) panel.fonts.title else panel.fonts.label;
    if (font == null) return false;
    imgui.api.PushFont(ctx, font);
    return true;
}

pub fn popFont(panel: *Panel, pushed: bool) void {
    const ctx = panel.ctx;
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
pub fn engravedText(panel: *Panel, text: [:0]const u8, color: ?c_int) void {
    const ctx = panel.ctx;
    const pushed = pushTitleFont(panel);
    const dl = imgui.api.GetWindowDrawList(ctx);
    const at = cursorScreenPos(panel);
    imgui.api.DrawList_AddText(dl, at.x, at.y + 1, theme.text_engraved_shadow, text);
    imgui.api.DrawList_AddText(dl, at.x, at.y, color orelse theme.text_dim, text);
    const size = textSize(panel, text);
    imgui.api.Dummy(ctx, size.w, size.h + 1);
    popFont(panel, pushed);
}

// ---- the lamp and the display ----

/// A lamp, lit in the given color or dark, as big as a line of text, so that text can follow it.
pub fn lamp(panel: *Panel, color: c_int, lit: bool) void {
    const ctx = panel.ctx;
    const at = cursorScreenPos(panel);
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
pub fn display(panel: *Panel, text: [:0]const u8, color: c_int, min_width: f64) void {
    const ctx = panel.ctx;
    const at = cursorScreenPos(panel);
    const pushed = pushLabelFont(panel);
    const size = textSize(panel, text);
    const width = @max(min_width, size.w + 20);
    const height = size.h + 10;
    imgui.api.Dummy(ctx, width, height);
    const dl = imgui.api.GetWindowDrawList(ctx);
    rectFilled(dl, at.x, at.y, at.x + width, at.y + height, theme.slot_bg, 3);
    rect(dl, at.x, at.y, at.x + width, at.y + height, theme.slot_edge, 3, 1);
    line(dl, at.x + 3, at.y + height + 1, at.x + width - 3, at.y + height + 1, theme.panel_edge_light, 1);
    imgui.api.DrawList_AddText(dl, at.x + 10, at.y + 5, color, text);
    drawGlass(dl, at.x, at.y, at.x + width, at.y + height);
    popFont(panel, pushed);
}

// ---- the push button and the toggle ----

/// The id of a widget that has no label of its own in ImGui: a prefix and the visible label.
fn widgetId(buf: []u8, prefix: []const u8, label: []const u8) [:0]const u8 {
    return std.fmt.bufPrintZ(buf, "##{s}{s}", .{ prefix, label }) catch "##widget";
}

/// A push button: a raised key of dark metal with a lit upper edge, that sinks while it is held, with
/// the accent over it when the mouse is on it or it is held. Returns true when it was clicked.
pub fn pushButton(panel: *Panel, label: [:0]const u8, min_width: f64) bool {
    const ctx = panel.ctx;
    const pushed = pushLabelFont(panel);
    defer popFont(panel, pushed);
    const size = textSize(panel, label);
    const width = @max(min_width, size.w + 28);
    const height = size.h + 12;
    const at = cursorScreenPos(panel);
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
        rectFilled(dl, at.x, top, at.x + width, bottom, faded(accent(panel), 0x40), 4);
    } else if (hovered) {
        rectFilled(dl, at.x, top, at.x + width, bottom, faded(accent(panel), 0x22), 4);
    }
    rect(dl, at.x, top, at.x + width, bottom, if (hovered or held) accent(panel) else theme.knob_edge, 4, 1);
    line(dl, at.x + 5, top + 1.5, at.x + width - 5, top + 1.5, rgba(0xFFFFFF30), 1);
    imgui.api.DrawList_AddText(dl, at.x + (width - size.w) / 2, top + (height - size.h) / 2, if (held) accent(panel) else theme.text, label);
    return clicked;
}

const toggle_w: f64 = 30;
const toggle_h: f64 = 16;

/// A toggle with a label: a rocker whose thumb slides to the right and lights up in the accent when
/// the value is on. Returns true when the user changed the value, and `value` then holds the new one.
pub fn toggle(panel: *Panel, label: [:0]const u8, value: *bool) bool {
    const ctx = panel.ctx;
    const text_line = imgui.api.GetTextLineHeight(ctx);
    const text_w = textSize(panel, label).w;
    const height = @max(text_line, toggle_h) + 4;
    const at = cursorScreenPos(panel);
    var id: [128]u8 = undefined;
    const clicked = imgui.api.InvisibleButton(ctx, widgetId(&id, "toggle", label), toggle_w + 10 + text_w, height, null);
    const hot = imgui.api.IsItemHovered(ctx, null);
    if (clicked) value.* = !value.*;
    const on = value.*;

    const dl = imgui.api.GetWindowDrawList(ctx);
    const ty = at.y + (height - toggle_h) / 2;
    rectFilled(dl, at.x, ty, at.x + toggle_w, ty + toggle_h, if (on) faded(accent(panel), 0x55) else theme.slot_bg, toggle_h / 2);
    rect(dl, at.x, ty, at.x + toggle_w, ty + toggle_h, if (hot) accent(panel) else theme.knob_edge, toggle_h / 2, 1);
    const thumb_x = if (on) at.x + toggle_w - toggle_h / 2 else at.x + toggle_h / 2;
    const thumb_y = ty + toggle_h / 2;
    if (on) circleFilled(dl, thumb_x, thumb_y, toggle_h / 2 + 1, faded(accent(panel), 0x44));
    circleFilled(dl, thumb_x + 0.5, thumb_y + 1.5, toggle_h / 2 - 3, rgba(0x00000099));
    circleFilled(dl, thumb_x, thumb_y, toggle_h / 2 - 3, if (on) accent(panel) else theme.knob_top);
    circleFilled(dl, thumb_x - 1.5, thumb_y - 1.5, 1.2, rgba(0xFFFFFF66));
    imgui.api.DrawList_AddText(dl, at.x + toggle_w + 10, at.y + (height - text_line) / 2, theme.text, label);
    return clicked;
}

// ---- the card ----

/// A framed section of the panel, with its title engraved on top. A card may have an accent color,
/// which tints its top and its title and is taken by the lit parts of the controls it holds. A card
/// that is given a width or a height keeps it, and otherwise it grows with what it holds. Returns true
/// when the card is drawn, and then `endCard` must follow.
pub fn beginCard(panel: *Panel, title: []const u8, width: ?f64, height: ?f64, card_accent: ?c_int) bool {
    const ctx = panel.ctx;
    panel.accent = card_accent;
    imgui.api.PushStyleColor(ctx, imgui.Col_ChildBg, theme.panel_bg);
    imgui.api.PushStyleColor(ctx, imgui.Col_Border, theme.panel_edge_dark);
    // In a card with an accent, the widgets that are not drawn by hand light up with the accent: a
    // light shade of it when the mouse is over them, and the accent itself while they are clicked.
    panel.card_colors = 2;
    if (card_accent) |tint| {
        const hover = faded(tint, 0x40);
        imgui.api.PushStyleColor(ctx, imgui.Col_FrameBgHovered, hover);
        imgui.api.PushStyleColor(ctx, imgui.Col_FrameBgActive, tint);
        imgui.api.PushStyleColor(ctx, imgui.Col_ButtonHovered, faded(tint, 0x55));
        imgui.api.PushStyleColor(ctx, imgui.Col_ButtonActive, tint);
        imgui.api.PushStyleColor(ctx, imgui.Col_HeaderHovered, hover);
        imgui.api.PushStyleColor(ctx, imgui.Col_HeaderActive, tint);
        panel.card_colors = 8;
    }
    var flags: c_int = imgui.ChildFlags_Border;
    if (width == null) flags |= imgui.ChildFlags_AutoResizeX;
    if (height == null) flags |= imgui.ChildFlags_AutoResizeY;
    var window_flags: c_int = imgui.WindowFlags_NoScrollbar;
    var w: f64 = width orelse 0;
    var h: f64 = height orelse 0;
    var id: [128:0]u8 = undefined;
    const visible = imgui.api.BeginChild(ctx, widgetId(&id, "card", title), &w, &h, &flags, &window_flags);
    const kept = @min(title.len, panel.card_title.len - 1);
    @memcpy(panel.card_title[0..kept], title[0..kept]);
    panel.card_title[kept] = 0;
    if (visible) {
        var upper: [96:0]u8 = undefined;
        const shown = std.ascii.upperString(upper[0..kept], title[0..kept]);
        upper[shown.len] = 0;
        engravedText(panel, upper[0..shown.len :0], card_accent);
        imgui.api.Spacing(ctx);
    } else {
        // Because `endCard` does not follow a card that is not drawn, its colors are popped here.
        var count = panel.card_colors;
        imgui.api.PopStyleColor(ctx, &count);
        panel.accent = null;
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
fn drawCardSurface(panel: *Panel, card_accent: ?c_int) void {
    const ctx = panel.ctx;
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

pub fn endCard(panel: *Panel) void {
    const ctx = panel.ctx;
    // The content ends where the cursor is, less the spacing that follows the last item, and the card's
    // bottom padding is added; the 2 pixels keep the card from cutting its last line.
    var spacing_x: f64 = 0;
    var spacing_y: f64 = 0;
    imgui.api.GetStyleVar(ctx, imgui.StyleVar_ItemSpacing, &spacing_x, &spacing_y);
    var padding_x: f64 = 0;
    var padding_y: f64 = 0;
    imgui.api.GetStyleVar(ctx, imgui.StyleVar_WindowPadding, &padding_x, &padding_y);
    rememberHeight(panel, std.mem.sliceTo(&panel.card_title, 0), imgui.api.GetCursorPosY(ctx) - spacing_y + padding_y + 2);
    drawCardSurface(panel, panel.accent);
    panel.accent = null;
    imgui.api.EndChild(ctx);
    var count = panel.card_colors;
    imgui.api.PopStyleColor(ctx, &count);
}

// ---- what a control draws ----

/// What a control needs to know about its parameter. The catalog's parameters and the extras that the
/// panel adds both fill it in.
pub const Control = struct {
    id: []const u8,
    low: i32,
    high: i32,
    /// A value stored as 52 to 76 and shown as -12 to +12 has a shift of -64.
    shift: i32 = 0,
    /// A value stored as 54 to 74 and shown as -100 to +100 has a scale of 10 and a shift of -64.
    scale: i32 = 1,
    /// Whether a sign is shown before the value.
    signed: bool = false,
    unit: []const u8 = "",
    /// The position that an alt-click brings the control to, when the parameter has one of its own.
    default: ?i32 = null,
    /// The reason the unit does not take this parameter. A control that has one is drawn dim and does
    /// not move.
    disabled: ?[:0]const u8 = null,
    /// What the panel shows for each value from `low`, for a type. A control that has names turns between
    /// stops, and a name of "(unused)" is a value that the keyboard does not use.
    names: []const []const u8 = &.{},
    /// The values of the names, in their order, for a parameter whose values are not consecutive.
    values: []const i32 = &.{},
};

/// The result of a control: whether the user changed the value, and the value after the change.
pub const Change = struct { changed: bool, value: i32 };

/// The position that a knob goes back to on an alt-click: the parameter's own default when it has one,
/// the middle of the range for a value that rests there, and the lowest value otherwise, because the
/// catalog does not hold a default for each one.
pub fn defaultValue(control: Control, bipolar: bool) i32 {
    if (control.default) |d| return d;
    if (bipolar) return @divFloor(control.low + control.high + 1, 2);
    return control.low;
}

fn altIsDown(panel: *Panel) bool {
    const ctx = panel.ctx;
    return (imgui.api.GetKeyMods(ctx) & imgui.Mod_Alt) != 0;
}

fn shiftIsDown(panel: *Panel) bool {
    const ctx = panel.ctx;
    return (imgui.api.GetKeyMods(ctx) & imgui.Mod_Shift) != 0;
}

/// The text of a control's value: the value plus the control's `shift`, times its `scale`, with a sign
/// when the control is `signed`, and its unit.
pub fn shownValue(buf: []u8, control: Control, value: i32) [:0]const u8 {
    const shown = (value + control.shift) * control.scale;
    const sign: []const u8 = if (control.signed and shown >= 0) "+" else "";
    return std.fmt.bufPrintZ(buf, "{s}{d}{s}", .{ sign, shown, control.unit }) catch "?";
}

/// Shows the text in a tooltip while the mouse is over the last item.
pub fn tooltip(panel: *Panel, text: [:0]const u8) void {
    const ctx = panel.ctx;
    if (!imgui.api.IsItemHovered(ctx, null)) return;
    if (imgui.api.BeginTooltip(ctx)) {
        var wrap: f64 = 320;
        imgui.api.PushTextWrapPos(ctx, &wrap);
        imgui.api.Text(ctx, text);
        imgui.api.PopTextWrapPos(ctx);
        imgui.api.EndTooltip(ctx);
    }
}

// ---- the text under a control ----

const label_lines_max = 4;
const label_line_cap = 96;

/// Draws a label centered under a control, on as many lines as the control reserves, so that the
/// controls of one row keep the same height whatever their label. The label is broken into lines that
/// fit the width.
pub fn centeredLabel(panel: *Panel, text: []const u8, width: f64, reserved_lines: usize) void {
    const ctx = panel.ctx;
    const pushed = pushLabelFont(panel);
    defer popFont(panel, pushed);

    var lines: [label_lines_max][label_line_cap:0]u8 = undefined;
    var count: usize = 0;
    var current: [label_line_cap:0]u8 = undefined;
    var current_len: usize = 0;
    var words = std.mem.tokenizeAny(u8, text, " \t");
    while (words.next()) |word| {
        var candidate: [label_line_cap:0]u8 = undefined;
        const joined = (if (current_len == 0)
            std.fmt.bufPrintZ(&candidate, "{s}", .{word})
        else
            std.fmt.bufPrintZ(&candidate, "{s} {s}", .{ current[0..current_len], word })) catch continue;
        if (current_len > 0 and textSize(panel, joined).w > width) {
            if (count < label_lines_max) {
                @memcpy(lines[count][0..current_len], current[0..current_len]);
                lines[count][current_len] = 0;
                count += 1;
            }
            const first = std.fmt.bufPrintZ(&current, "{s}", .{word}) catch continue;
            current_len = first.len;
        } else {
            @memcpy(current[0..joined.len], joined);
            current[joined.len] = 0;
            current_len = joined.len;
        }
    }
    if (current_len > 0 and count < label_lines_max) {
        @memcpy(lines[count][0..current_len], current[0..current_len]);
        lines[count][current_len] = 0;
        count += 1;
    }

    const base = imgui.api.GetCursorPosX(ctx);
    var i: usize = 0;
    while (i < reserved_lines) : (i += 1) {
        if (i < count) {
            const shown: [:0]const u8 = std.mem.sliceTo(&lines[i], 0);
            imgui.api.SetCursorPosX(ctx, base + (width - textSize(panel, shown).w) / 2);
            imgui.api.TextColored(ctx, theme.label, shown);
        } else {
            imgui.api.Dummy(ctx, 1, imgui.api.GetTextLineHeight(ctx));
        }
    }
}

/// A value centered over a control, in the label font.
pub fn centeredValue(panel: *Panel, text: [:0]const u8, width: f64, color: ?c_int) void {
    const ctx = panel.ctx;
    const pushed = pushLabelFont(panel);
    defer popFont(panel, pushed);
    imgui.api.SetCursorPosX(ctx, imgui.api.GetCursorPosX(ctx) + (width - textSize(panel, text).w) / 2);
    imgui.api.TextColored(ctx, color orelse accent(panel), text);
}

// ---- the drawbar ----

const drawbar_w: f64 = 40;
const drawbar_h: f64 = 150;
const cap_h: f64 = 20;

/// The color of a drawbar's cap and of its contour. Because a tonewheel organ's drawbars come in three colors,
/// the caller says which one a drawbar has.
pub const Cap = struct { body: c_int, edge: c_int };

/// A drawbar pulled out of the panel: the value above it, a slot with a tick for each step, a stem and a
/// cap that slides down as the value rises, and the footage under it. The user drags the cap, or clicks
/// anywhere in the slot to bring the cap there. A disabled drawbar is drawn dim and does not move.
pub fn drawbar(panel: *Panel, control: Control, value: i32, name: []const u8, cap_colors: Cap, disabled: bool) Change {
    const ctx = panel.ctx;
    imgui.api.BeginGroup(ctx);

    // The value is drawn in the label font, like the numbers of the knobs.
    var value_buf: [16]u8 = undefined;
    const value_text = std.fmt.bufPrintZ(&value_buf, "{d}", .{value}) catch "?";
    centeredValue(panel, value_text, drawbar_w, if (disabled) theme.text_dim else accent(panel));

    const at = cursorScreenPos(panel);
    _ = imgui.api.InvisibleButton(ctx, "##drawbar", drawbar_w, drawbar_h, null);

    const top = at.y + cap_h / 2 + 2;
    const bottom = at.y + drawbar_h - cap_h / 2 - 2;
    const low: f64 = @floatFromInt(control.low);
    const span: f64 = @floatFromInt(control.high - control.low);
    var result = value;
    if (!disabled and imgui.api.IsItemActive(ctx)) {
        var mx: f64 = 0;
        var my: f64 = 0;
        imgui.api.GetMousePos(ctx, &mx, &my);
        const t = std.math.clamp((my - top) / (bottom - top), 0, 1);
        result = @intFromFloat(@floor(low + t * span + 0.5));
    }

    const dl = imgui.api.GetWindowDrawList(ctx);
    const cx = at.x + drawbar_w / 2;

    // The slot, cut into the panel.
    rectFilled(dl, cx - 5, top - 6, cx + 5, bottom + 6, theme.slot_bg, 4);
    rect(dl, cx - 5, top - 6, cx + 5, bottom + 6, theme.slot_edge, 4, 1);

    // The ticks, one for each step of the drawbar.
    const steps: i32 = control.high - control.low;
    var i: i32 = 0;
    while (i <= steps) : (i += 1) {
        const ty = top + (bottom - top) * @as(f64, @floatFromInt(i)) / span;
        line(dl, at.x + 2, ty, cx - 8, ty, theme.text_dim, 1);
        line(dl, cx + 8, ty, at.x + drawbar_w - 2, ty, theme.text_dim, 1);
    }

    // The stem runs from the top of the slot down to the cap.
    const pos = top + (bottom - top) * @as(f64, @floatFromInt(result - control.low)) / span;
    rectFilled(dl, cx - 2, top - 4, cx + 2, pos, if (disabled) faded(theme.stem, 0x55) else theme.stem, 1);

    // The cap, with a lit edge on its top and a dark line under it so that it stands out of the panel.
    const cap_x1 = at.x + 3;
    const cap_x2 = at.x + drawbar_w - 3;
    const cap_y1 = pos - cap_h / 2;
    const cap_y2 = pos + cap_h / 2;
    rectFilled(dl, cap_x1, cap_y1 + 2, cap_x2, cap_y2 + 2, rgba(0x00000099), 3);
    var cap = cap_colors;
    if (disabled) cap = .{ .body = faded(cap.body, 0x55), .edge = faded(cap.edge, 0x55) };
    rectFilled(dl, cap_x1, cap_y1, cap_x2, cap_y2, cap.body, 3);
    rect(dl, cap_x1, cap_y1, cap_x2, cap_y2, cap.edge, 3, 1);
    line(dl, cap_x1 + 3, cap_y1 + 2, cap_x2 - 3, cap_y1 + 2, rgba(0xFFFFFF55), 1);
    line(dl, cap_x1 + 3, pos, cap_x2 - 3, pos, cap.edge, 1);
    if (!disabled and (imgui.api.IsItemHovered(ctx, null) or imgui.api.IsItemActive(ctx))) {
        rect(dl, cap_x1, cap_y1, cap_x2, cap_y2, accent(panel), 3, 1);
    }

    var name_buf: [64:0]u8 = undefined;
    const shown_name = std.fmt.bufPrintZ(&name_buf, "{s}", .{name}) catch "";
    const pushed = pushLabelFont(panel);
    imgui.api.SetCursorPosX(ctx, imgui.api.GetCursorPosX(ctx) + (drawbar_w - textSize(panel, shown_name).w) / 2);
    imgui.api.TextColored(ctx, if (disabled) theme.text_dim else theme.label, shown_name);
    popFont(panel, pushed);
    imgui.api.EndGroup(ctx);
    return .{ .changed = result != value, .value = result };
}

// ---- the knob and the switch ----

const knob_w: f64 = 76;
const knob_d: f64 = 46;
const knob_label_lines = 2;

/// The knob sweeps 270 degrees, from the lower left through the top to the lower right. ImGui's angles
/// start at the right and grow clockwise on screen.
const knob_from: f64 = std.math.pi * 0.75;
const knob_to: f64 = std.math.pi * 2.25;

/// How far the mouse travels to sweep the whole range, and the same with shift held for fine steps.
const knob_drag: f64 = 150;
const knob_drag_fine: f64 = 600;

/// The scale printed around the knob: this many intervals, with a longer tick at each end.
const knob_ticks: i32 = 10;

/// A drag moves the value relative to where it started, so the start of the drag is kept here. Only one
/// control is dragged at a time, so one record is enough.
pub const Drag = struct {
    /// False after an alt-click, because the click sets the value and the drag that follows must not
    /// move it again.
    armed: bool = false,
    /// The value that the drag started from, and the mouse position at which the speed last changed.
    value: i32 = 0,
    dy0: f64 = 0,
    fine: bool = false,
};

/// The picture of a knob: the ring that fills up to the value, the scale around it, the metal cap and its pointer. The
/// interactive knob and the display-only dial both draw it. `at` is the top left of the knob's area, `lit` is the
/// color of the ring, and `hot` outlines the cap in the accent, as it is while the mouse is on a knob.
fn drawKnobFace(panel: *Panel, at: Point, control: Control, value: i32, bipolar: bool, lit: c_int, hot: bool) void {
    const ctx = panel.ctx;
    const range: f64 = @floatFromInt(control.high - control.low);
    const dl = imgui.api.GetWindowDrawList(ctx);
    const cx = at.x + knob_w / 2;
    const cy = at.y + 4 + knob_d / 2;
    const r = knob_d / 2;
    const t = @as(f64, @floatFromInt(value - control.low)) / range;
    const angle = knob_from + t * (knob_to - knob_from);

    // The ring: a dark track cut into the panel, and the lit part up to the value.
    var flags: c_int = imgui.DrawFlags_None;
    var thickness: f64 = 5;
    imgui.api.DrawList_PathArcTo(dl, cx, cy, r, knob_from, knob_to, null);
    imgui.api.DrawList_PathStroke(dl, theme.slot_bg, &flags, &thickness);
    const fill_from = if (bipolar) (knob_from + knob_to) / 2 else knob_from;
    if (angle != fill_from) {
        thickness = 3;
        imgui.api.DrawList_PathArcTo(dl, cx, cy, r, @min(fill_from, angle), @max(fill_from, angle), null);
        imgui.api.DrawList_PathStroke(dl, lit, &flags, &thickness);
    }

    // The scale around the ring. A bipolar knob has a longer tick in the middle too.
    var i: i32 = 0;
    while (i <= knob_ticks) : (i += 1) {
        const a = knob_from + (knob_to - knob_from) * @as(f64, @floatFromInt(i)) / knob_ticks;
        const long = i == 0 or i == knob_ticks or (bipolar and i == @divFloor(knob_ticks, 2));
        const inner = r + 3;
        const outer = r + (if (long) @as(f64, 8) else 6);
        line(dl, cx + @cos(a) * inner, cy + @sin(a) * inner, cx + @cos(a) * outer, cy + @sin(a) * outer, if (long) theme.label else theme.text_dim, 1);
    }

    // The body stands out of the panel, with a shadow under it and a lit edge on its upper left.
    const body = r - 7;
    circleFilled(dl, cx + 1, cy + 3, body + 1, rgba(0x00000099));
    circleFilled(dl, cx, cy, body, theme.knob_body);
    circleFilled(dl, cx - 1, cy - 1, body - 4, theme.knob_top);
    circle(dl, cx, cy, body, if (hot) accent(panel) else theme.knob_edge, 1);

    // The metal of the cap: two fine concentric grooves, a lit edge on its upper left, and a shine.
    circle(dl, cx, cy, body - 3, rgba(0xFFFFFF14), 1);
    circle(dl, cx, cy, body - 6, rgba(0x00000040), 1);
    thickness = 1.5;
    imgui.api.DrawList_PathArcTo(dl, cx, cy, body - 0.5, std.math.pi, std.math.pi * 1.5, null);
    imgui.api.DrawList_PathStroke(dl, rgba(0xFFFFFF40), &flags, &thickness);
    circleFilled(dl, cx - body * 0.35, cy - body * 0.4, body * 0.22, rgba(0xFFFFFF1E));

    // The pointer runs from near the center toward the ring.
    const cos_a = @cos(angle);
    const sin_a = @sin(angle);
    line(dl, cx + cos_a * body * 0.25, cy + sin_a * body * 0.25, cx + cos_a * body * 0.9, cy + sin_a * body * 0.9, theme.text, 2);
}

/// A rotary knob: the value above it, a ring that fills as the value rises, a pointer, and the label
/// under it. The user drags up or down, or turns the mouse wheel over it. When `bipolar` is true, the
/// value rests in the middle of the range, so that the ring fills from the top, to the left or to the
/// right of it, and a tick marks the middle. The caller pushes an id for each knob.
pub fn knob(panel: *Panel, control: Control, value: i32, label: []const u8, bipolar: bool) Change {
    const ctx = panel.ctx;
    const disabled = control.disabled != null;
    const lit = if (disabled) theme.text_dim else accent(panel);
    imgui.api.BeginGroup(ctx);
    var value_buf: [48]u8 = undefined;
    centeredValue(panel, shownValue(&value_buf, control, value), knob_w, lit);

    const at = cursorScreenPos(panel);
    _ = imgui.api.InvisibleButton(ctx, "##knob", knob_w, knob_d + 8, null);
    if (control.disabled) |reason| tooltip(panel, reason);
    const range: f64 = @floatFromInt(control.high - control.low);
    var result = value;
    const fine = shiftIsDown(panel);
    if (!disabled and imgui.api.IsItemActivated(ctx)) {
        if (altIsDown(panel)) {
            panel.drag = .{};
            result = defaultValue(control, bipolar);
        } else {
            panel.drag = .{ .armed = true, .value = value, .dy0 = 0, .fine = fine };
        }
    }
    if (!disabled and imgui.api.IsItemActive(ctx) and panel.drag.armed) {
        var dx: f64 = 0;
        var dy: f64 = 0;
        var button: c_int = imgui.MouseButton_Left;
        var threshold: f64 = 0;
        imgui.api.GetMouseDragDelta(ctx, &dx, &dy, &button, &threshold);
        // Because holding shift slows the drag, pressing or releasing it starts a new drag from the
        // current value, so that the knob does not jump.
        if (panel.drag.fine != fine) panel.drag = .{ .armed = true, .value = value, .dy0 = dy, .fine = fine };
        const speed = if (fine) knob_drag_fine else knob_drag;
        const moved = @as(f64, @floatFromInt(panel.drag.value)) - (dy - panel.drag.dy0) * range / speed;
        result = @intFromFloat(@floor(std.math.clamp(moved, @as(f64, @floatFromInt(control.low)), @as(f64, @floatFromInt(control.high))) + 0.5));
    } else if (!disabled and imgui.api.IsItemHovered(ctx, null)) {
        var wheel_x: f64 = 0;
        var wheel_y: f64 = 0;
        imgui.api.GetMouseWheel(ctx, &wheel_x, &wheel_y);
        if (wheel_y != 0) {
            const step: i32 = @max(1, @as(i32, @intFromFloat(@floor(range / 40))));
            result = std.math.clamp(value + (if (wheel_y > 0) step else -step), control.low, control.high);
        }
    }

    const hot = !disabled and (imgui.api.IsItemHovered(ctx, null) or imgui.api.IsItemActive(ctx));
    drawKnobFace(panel, at, control, result, bipolar, lit, hot);

    // While the user drags the knob, its value is shown by the mouse, since the hand covers the knob.
    if (!disabled and imgui.api.IsItemActive(ctx)) {
        var tip_buf: [96:0]u8 = undefined;
        var shown_buf: [48]u8 = undefined;
        const tip = std.fmt.bufPrintZ(&tip_buf, "{s}: {s}", .{ label, shownValue(&shown_buf, control, result) }) catch "";
        imgui.api.SetTooltip(ctx, tip);
    }

    var upper: [label_line_cap * 2]u8 = undefined;
    const caption = std.ascii.upperString(&upper, label[0..@min(label.len, upper.len)]);
    centeredLabel(panel, caption, knob_w, knob_label_lines);
    imgui.api.EndGroup(ctx);
    return .{ .changed = result != value, .value = result };
}

/// A knob that only shows a value: the same picture as `knob`, without the mouse. A panel that mirrors a controller
/// draws its encoders with it, because the player turns the real ones. `lit` is the color of the ring and of the value,
/// or the card's accent when it is null. Nothing is returned, since nothing can change.
pub fn dial(panel: *Panel, control: Control, value: i32, label: []const u8, lit: ?c_int) void {
    const ctx = panel.ctx;
    const color = lit orelse accent(panel);
    imgui.api.BeginGroup(ctx);
    var value_buf: [48]u8 = undefined;
    centeredValue(panel, shownValue(&value_buf, control, value), knob_w, color);
    const at = cursorScreenPos(panel);
    imgui.api.Dummy(ctx, knob_w, knob_d + 8);
    drawKnobFace(panel, at, control, std.math.clamp(value, control.low, control.high), false, color, false);
    var upper: [label_line_cap * 2]u8 = undefined;
    const caption = std.ascii.upperString(&upper, label[0..@min(label.len, upper.len)]);
    centeredLabel(panel, caption, knob_w, knob_label_lines);
    imgui.api.EndGroup(ctx);
}

/// A switch with a lamp, for a parameter that is either 0 or 1. The lamp is lit and the on text is shown
/// when the value is 1.
pub fn switchControl(panel: *Panel, value: i32, label: []const u8, on_text: [:0]const u8, off_text: [:0]const u8) Change {
    const ctx = panel.ctx;
    imgui.api.BeginGroup(ctx);
    // An empty line takes the place of the knobs' value, so that both line up in a row.
    imgui.api.Dummy(ctx, 1, imgui.api.GetTextLineHeight(ctx));

    const at = cursorScreenPos(panel);
    _ = imgui.api.InvisibleButton(ctx, "##switch", knob_w, knob_d + 8, null);
    var result = value;
    if (imgui.api.IsItemClicked(ctx, null)) result = 1 - value;

    const dl = imgui.api.GetWindowDrawList(ctx);
    const on = result == 1;
    const x1 = at.x + 6;
    const y1 = at.y + 4;
    const x2 = at.x + knob_w - 6;
    const y2 = at.y + 4 + knob_d;
    rectFilled(dl, x1, y1 + 2, x2, y2 + 2, rgba(0x00000099), 5);
    rectFilled(dl, x1, y1, x2, y2, if (on) theme.knob_top else theme.knob_body, 5);
    const hot = imgui.api.IsItemHovered(ctx, null);
    rect(dl, x1, y1, x2, y2, if (hot) accent(panel) else theme.knob_edge, 5, 1);

    // The lamp: a glow around it when it is lit.
    const lx = (x1 + x2) / 2;
    const ly = y1 + 14;
    if (on) circleFilled(dl, lx, ly, 9, faded(accent(panel), 0x55));
    circleFilled(dl, lx, ly, 5, if (on) accent(panel) else theme.slot_bg);
    circle(dl, lx, ly, 5, theme.slot_edge, 1);

    const state = if (on) on_text else off_text;
    imgui.api.DrawList_AddText(dl, lx - textSize(panel, state).w / 2, y2 - 18, accent(panel), state);

    centeredLabel(panel, label, knob_w, knob_label_lines);
    imgui.api.EndGroup(ctx);
    return .{ .changed = result != value, .value = result };
}

// ---- the knob with named stops ----

/// Because a knob with more stops than this has no room for a label at each one, it shows the name of
/// the selected stop in a display under the knob instead.
const stop_labels_max = 8;

/// How far the mouse travels to move the knob by one stop, with a label at each stop and without.
const stop_drag_labelled: f64 = 18;
const stop_drag_plain: f64 = 6;

const stops_cap = 64;
const stop_name_cap = 40;

const Stop = struct { value: i32, name: [stop_name_cap:0]u8 };

/// The stops of a control: the values that have a name, in order. A name of "(unused)" is a value the
/// keyboard does not use, so it is not a stop. Returns how many were written to `out`.
fn stopsOf(control: Control, out: *[stops_cap]Stop) usize {
    var count: usize = 0;
    for (control.names, 0..) |name, i| {
        if (std.mem.eql(u8, name, "(unused)")) continue;
        if (count == stops_cap) break;
        const value: i32 = if (i < control.values.len) control.values[i] else control.low + @as(i32, @intCast(i));
        out[count].value = value;
        _ = std.fmt.bufPrintZ(&out[count].name, "{s}", .{name}) catch {
            @memcpy(out[count].name[0 .. stop_name_cap - 1], name[0 .. stop_name_cap - 1]);
            out[count].name[stop_name_cap - 1] = 0;
        };
        count += 1;
    }
    return count;
}

fn stopIndex(stops: []const Stop, value: i32) usize {
    for (stops, 0..) |stop, i| {
        if (stop.value == value) return i;
    }
    return 0;
}

fn stopName(stop: *const Stop) [:0]const u8 {
    return std.mem.sliceTo(&stop.name, 0);
}

/// The angle of a stop on the knob's sweep.
fn stopAngle(index: usize, count: usize) f64 {
    const t: f64 = if (count > 1) @as(f64, @floatFromInt(index)) / @as(f64, @floatFromInt(count - 1)) else 0.5;
    return knob_from + t * (knob_to - knob_from);
}

const StopSide = enum { left, right, top };

/// The side of the knob that the label of a stop is on.
fn stopSide(angle: f64) StopSide {
    const c = @cos(angle);
    if (c > 0.35) return .right;
    if (c < -0.35) return .left;
    return .top;
}

const StopMargins = struct { left: f64 = 0, right: f64 = 0, top: f64 = 0 };

/// Measures what the stop knob needs around the knob for its labels, in the label font: the width on its
/// left and its right, and the height above it.
fn stopMargins(panel: *Panel, stops: []const Stop, labelled: bool) StopMargins {
    const ctx = panel.ctx;
    var margins = StopMargins{};
    if (!labelled) return margins;
    const text_line = imgui.api.GetTextLineHeight(ctx);
    for (stops, 0..) |*stop, i| {
        const text_w = textSize(panel, stopName(stop)).w;
        switch (stopSide(stopAngle(i, stops.len))) {
            .left => margins.left = @max(margins.left, text_w + 8),
            .right => margins.right = @max(margins.right, text_w + 8),
            .top => margins.top = text_line + 4,
        }
    }
    return margins;
}

const LabelBox = struct { x1: f64, y1: f64, x2: f64, y2: f64 };

/// Where the label of a stop sits, relative to the center of the knob.
fn stopLabelBox(panel: *Panel, stop: *const Stop, index: usize, count: usize, text_line: f64) LabelBox {
    const r = knob_d / 2;
    const angle = stopAngle(index, count);
    const text_w = textSize(panel, stopName(stop)).w;
    const ax = @cos(angle) * (r + 9);
    const ay = @sin(angle) * (r + 9);
    const side = stopSide(angle);
    const bx = switch (side) {
        .left => ax - text_w,
        .top => ax - text_w / 2,
        .right => ax,
    };
    const by = if (side == .top) ay - text_line - 1 else ay - text_line / 2;
    return .{ .x1 = bx, .y1 = by, .x2 = bx + text_w, .y2 = by + text_line };
}

/// Whether two labels of the stops would be drawn over each other. Because the names are written around
/// the knob, a knob with long names crowds them on one side, and then its names go in a list instead.
fn labelsOverlap(panel: *Panel, stops: []const Stop, text_line: f64) bool {
    var boxes: [stops_cap]LabelBox = undefined;
    for (stops, 0..) |*stop, i| boxes[i] = stopLabelBox(panel, stop, i, stops.len, text_line);
    for (0..stops.len) |i| {
        for (i + 1..stops.len) |j| {
            const a = boxes[i];
            const b = boxes[j];
            if (a.x1 < b.x2 + 2 and b.x1 < a.x2 + 2 and a.y1 < b.y2 + 1 and b.y1 < a.y2 + 1) return true;
        }
    }
    return false;
}

/// A knob that turns between named stops: a dot on its ring at each stop, and the name of each stop
/// written beside its dot, with the selected one lit. The user drags up or down, turns the mouse wheel,
/// or clicks a name. A knob with more stops than `stop_labels_max`, or one that the caller asks to be an
/// `as_list`, shows the selected name in a display under it, that opens the list, instead of a label at
/// each stop. The value in the result is the value of the selected stop.
pub fn stopKnob(panel: *Panel, control: Control, value: i32, label: []const u8, as_list: bool) Change {
    const ctx = panel.ctx;
    const disabled = control.disabled != null;
    const tint = if (disabled) theme.text_dim else accent(panel);
    var stops: [stops_cap]Stop = undefined;
    const count = stopsOf(control, &stops);
    if (count == 0) return .{ .changed = false, .value = value };
    const index = stopIndex(stops[0..count], value);
    var result = index;

    imgui.api.BeginGroup(ctx);
    // A normal knob has its value above it; the stop knob leaves the same room, so that both line up.
    const room_above = imgui.api.GetTextLineHeightWithSpacing(ctx);
    const pushed = pushLabelFont(panel);
    const text_line = imgui.api.GetTextLineHeight(ctx);
    // The caller may ask for the display and the list even with few stops, when the names are long, and a
    // knob whose names would overlap takes them too.
    const labelled = count <= stop_labels_max and !as_list and !labelsOverlap(panel, stops[0..count], text_line);
    const margins = stopMargins(panel, stops[0..count], labelled);
    const top = @max(margins.top, room_above);

    const r = knob_d / 2;
    var display_w: f64 = 0;
    if (!labelled) {
        for (stops[0..count]) |*stop| display_w = @max(display_w, textSize(panel, stopName(stop)).w + 32);
    }
    // The caption is in capitals, like the lettering of the panel.
    var caption_buf: [label_line_cap:0]u8 = undefined;
    const caption_len = @min(label.len, caption_buf.len - 1);
    _ = std.ascii.upperString(caption_buf[0..caption_len], label[0..caption_len]);
    caption_buf[caption_len] = 0;
    const caption: [:0]const u8 = caption_buf[0..caption_len :0];
    const label_w = textSize(panel, caption).w;
    const width = @max(@max(margins.left + 2 * r + 8 + margins.right, display_w), @max(label_w, knob_w));
    const height = top + 2 * r + 8 + (if (labelled) @as(f64, 0) else text_line + 12) + text_line + 8;

    const origin = cursorScreenPos(panel);
    const cx = if (labelled) origin.x + width / 2 + (margins.left - margins.right) / 2 else origin.x + width / 2;
    const cy = origin.y + top + r + 4;

    // The buttons come first: the knob, and a label for each stop that selects it when clicked.
    var clicked: ?usize = null;
    var id: [64:0]u8 = undefined;
    imgui.api.PushID(ctx, std.fmt.bufPrintZ(&id, "{s}", .{control.id}) catch "stop");
    imgui.api.SetCursorScreenPos(ctx, cx - r - 4, cy - r - 4);
    _ = imgui.api.InvisibleButton(ctx, "##stopknob", 2 * r + 8, 2 * r + 8, null);
    if (control.disabled) |reason| tooltip(panel, reason);
    const hot = !disabled and (imgui.api.IsItemHovered(ctx, null) or imgui.api.IsItemActive(ctx));
    if (!disabled and imgui.api.IsItemActivated(ctx)) {
        if (altIsDown(panel)) {
            panel.drag = .{};
            result = stopIndex(stops[0..count], defaultValue(control, false));
        } else {
            panel.drag = .{ .armed = true, .value = @intCast(index) };
        }
    }
    if (!disabled and imgui.api.IsItemActive(ctx) and panel.drag.armed) {
        var dx: f64 = 0;
        var dy: f64 = 0;
        var button: c_int = imgui.MouseButton_Left;
        var threshold: f64 = 0;
        imgui.api.GetMouseDragDelta(ctx, &dx, &dy, &button, &threshold);
        const per_stop = if (labelled) stop_drag_labelled else stop_drag_plain;
        const moved = @as(f64, @floatFromInt(panel.drag.value)) - @floor(dy / per_stop + 0.5);
        result = @intFromFloat(std.math.clamp(moved, 0, @as(f64, @floatFromInt(count - 1))));
    } else if (!disabled and imgui.api.IsItemHovered(ctx, null)) {
        var wheel_x: f64 = 0;
        var wheel_y: f64 = 0;
        imgui.api.GetMouseWheel(ctx, &wheel_x, &wheel_y);
        if (wheel_y > 0 and index + 1 < count) result = index + 1;
        if (wheel_y < 0 and index > 0) result = index - 1;
    }

    // The display of a knob with many stops is also a combo: a click on it opens the list of all stops.
    const display_x = cx - display_w / 2;
    const display_y = cy + r + 6;
    const display_h = text_line + 6;
    var display_hot = false;
    if (!labelled) {
        imgui.api.SetCursorScreenPos(ctx, display_x, display_y);
        _ = imgui.api.InvisibleButton(ctx, "##stopcombo", display_w, display_h, null);
        display_hot = !disabled and imgui.api.IsItemHovered(ctx, null);
        if (!disabled and imgui.api.IsItemClicked(ctx, null)) imgui.api.OpenPopup(ctx, "##stoplist", null);
    }

    var boxes: [stops_cap]Point = undefined;
    if (labelled) {
        for (stops[0..count], 0..) |*stop, i| {
            const angle = stopAngle(i, count);
            const side = stopSide(angle);
            const text_w = textSize(panel, stopName(stop)).w;
            const ax = cx + @cos(angle) * (r + 9);
            const ay = cy + @sin(angle) * (r + 9);
            const bx = switch (side) {
                .left => ax - text_w,
                .top => ax - text_w / 2,
                .right => ax,
            };
            const by = if (side == .top) ay - text_line - 1 else ay - text_line / 2;
            boxes[i] = .{ .x = bx, .y = by };
            imgui.api.SetCursorScreenPos(ctx, bx, by);
            var stop_id: [16:0]u8 = undefined;
            const clicked_here = imgui.api.InvisibleButton(ctx, std.fmt.bufPrintZ(&stop_id, "##stop{d}", .{i}) catch "##stop", text_w, text_line, null);
            if (!disabled and clicked_here) clicked = i;
        }
    }
    imgui.api.PopID(ctx);
    if (clicked) |i| result = i;

    // Drawn last, with the stop this frame's input has just chosen.
    const dl = imgui.api.GetWindowDrawList(ctx);
    const angle = stopAngle(result, count);
    var flags: c_int = imgui.DrawFlags_None;
    var thickness: f64 = 5;
    imgui.api.DrawList_PathArcTo(dl, cx, cy, r, knob_from, knob_to, null);
    imgui.api.DrawList_PathStroke(dl, theme.slot_bg, &flags, &thickness);
    for (0..count) |i| {
        const a = stopAngle(i, count);
        const lit = i == result;
        const dx = @cos(a) * r;
        const dy = @sin(a) * r;
        if (lit) circleFilled(dl, cx + dx, cy + dy, 5, faded(tint, 0x55));
        circleFilled(dl, cx + dx, cy + dy, if (lit) 2.8 else 1.8, if (lit) tint else theme.text_dim);
    }

    const body = r - 7;
    circleFilled(dl, cx + 1, cy + 3, body + 1, rgba(0x00000099));
    circleFilled(dl, cx, cy, body, theme.knob_body);
    circleFilled(dl, cx - 1, cy - 1, body - 4, theme.knob_top);
    circle(dl, cx, cy, body, if (hot) tint else theme.knob_edge, 1);
    const cos_a = @cos(angle);
    const sin_a = @sin(angle);
    line(dl, cx + cos_a * body * 0.25, cy + sin_a * body * 0.25, cx + cos_a * body * 0.9, cy + sin_a * body * 0.9, theme.text, 2);

    if (labelled) {
        for (stops[0..count], 0..) |*stop, i| {
            imgui.api.DrawList_AddText(dl, boxes[i].x, boxes[i].y, if (i == result) tint else theme.label, stopName(stop));
        }
    } else {
        // The display under the knob: a recessed screen with the selected name in the accent color, and a
        // caret that shows it opens a list.
        rectFilled(dl, display_x, display_y, display_x + display_w, display_y + display_h, theme.slot_bg, 3);
        rect(dl, display_x, display_y, display_x + display_w, display_y + display_h, if (display_hot) tint else theme.slot_edge, 3, 1);
        const name = stopName(&stops[result]);
        imgui.api.DrawList_AddText(dl, display_x + (display_w - 14) / 2 - textSize(panel, name).w / 2, display_y + 3, tint, name);
        drawGlass(dl, display_x, display_y, display_x + display_w, display_y + display_h);
        const tx = display_x + display_w - 11;
        const ty = display_y + display_h / 2;
        imgui.api.DrawList_AddTriangleFilled(dl, tx - 4, ty - 2, tx + 4, ty - 2, tx, ty + 3, if (display_hot) tint else theme.text_dim);
    }

    const caption_y = cy + r + 8 + (if (labelled) @as(f64, 0) else text_line + 12) - 2;
    imgui.api.DrawList_AddText(dl, cx - label_w / 2, caption_y, theme.label, caption);

    // The list of every stop, under the display, with the selected one in the accent color. It must be
    // begun under the same id as the click that opened it.
    if (!labelled) {
        imgui.api.PushID(ctx, std.fmt.bufPrintZ(&id, "{s}", .{control.id}) catch "stop");
        var appearing: c_int = imgui.Cond_Appearing;
        imgui.api.SetNextWindowPos(ctx, display_x, display_y + display_h + 2, &appearing, null, null);
        if (imgui.api.BeginPopup(ctx, "##stoplist", null)) {
            for (stops[0..count], 0..) |*stop, i| {
                // Because a click changes `result` in the middle of the loop, whether the item is the
                // selected one is read once, so that the color pushed is the color popped.
                const selected = i == result;
                if (selected) imgui.api.PushStyleColor(ctx, imgui.Col_Text, tint);
                var item_id: [64:0]u8 = undefined;
                const item = std.fmt.bufPrintZ(&item_id, "{s}##s{d}", .{ stopName(stop), i }) catch "?";
                if (imgui.api.Selectable(ctx, item, null, null, null, null)) result = i;
                if (selected) {
                    var one: c_int = 1;
                    imgui.api.PopStyleColor(ctx, &one);
                }
            }
            imgui.api.EndPopup(ctx);
        }
        imgui.api.PopID(ctx);
    }
    popFont(panel, pushed);

    // Because ImGui wants an item after every move of the cursor, the control's own space is taken last.
    imgui.api.SetCursorScreenPos(ctx, origin.x, origin.y);
    imgui.api.Dummy(ctx, width, height);
    imgui.api.EndGroup(ctx);
    return .{ .changed = result != index, .value = stops[result].value };
}

// ---- the brackets over a row of knobs ----

/// A line that looks cut into the panel: a dark copy one pixel below, the light line over it.
fn engravedLine(dl: imgui.DrawListPtr, x1: f64, y1: f64, x2: f64, y2: f64) void {
    line(dl, x1, y1 + 1, x2, y2 + 1, theme.text_engraved_shadow, 1);
    line(dl, x1, y1, x2, y2, theme.text_dim, 1);
}

/// One bracket over a row of knobs: it spans the knobs from `from` to `to`, counted from 1.
pub const Bracket = struct { label: []const u8, from: usize, to: usize };

/// A row above a row of `count` knobs, with one bracket for each entry of `brackets`: a line that spans
/// the knobs from the entry's `from` to its `to`, with its caption engraved in the line, as the
/// silkscreen of a hardware panel groups its knobs.
pub fn bracketRow(panel: *Panel, brackets: []const Bracket, count: usize) void {
    const ctx = panel.ctx;
    const pushed = pushLabelFont(panel);
    defer popFont(panel, pushed);
    var spacing: f64 = 0;
    var spacing_y: f64 = 0;
    imgui.api.GetStyleVar(ctx, imgui.StyleVar_ItemSpacing, &spacing, &spacing_y);
    const pitch = knob_w + spacing;
    const origin = cursorScreenPos(panel);
    const height = imgui.api.GetTextLineHeight(ctx) + 4;
    imgui.api.Dummy(ctx, @as(f64, @floatFromInt(count)) * pitch - spacing, height);

    const dl = imgui.api.GetWindowDrawList(ctx);
    const ymid = origin.y + height / 2;
    for (brackets) |b| {
        const x1 = origin.x + @as(f64, @floatFromInt(b.from - 1)) * pitch + 4;
        const x2 = origin.x + @as(f64, @floatFromInt(b.to)) * pitch - spacing - 4;
        var text_buf: [64:0]u8 = undefined;
        const n = @min(b.label.len, text_buf.len - 1);
        _ = std.ascii.upperString(text_buf[0..n], b.label[0..n]);
        text_buf[n] = 0;
        const text: [:0]const u8 = text_buf[0..n :0];
        const size = textSize(panel, text);
        const text_x = (x1 + x2) / 2 - size.w / 2;
        // The line is broken around the caption, unless the caption fills the whole bracket.
        if (text_x - 6 > x1) {
            engravedLine(dl, x1, ymid, text_x - 6, ymid);
            engravedLine(dl, text_x + size.w + 6, ymid, x2, ymid);
        }
        engravedLine(dl, x1, ymid, x1, ymid + 5);
        engravedLine(dl, x2, ymid, x2, ymid + 5);
        imgui.api.DrawList_AddText(dl, text_x, ymid - size.h / 2 + 1, theme.text_engraved_shadow, text);
        imgui.api.DrawList_AddText(dl, text_x, ymid - size.h / 2, theme.text_dim, text);
    }
}

// ---- the envelope screen ----

/// The screen is drawn for a plot this wide, and it is stretched when the card gives it more room.
const env_w: f64 = 240;
const env_h: f64 = 120;
const env_pad_x: f64 = 14;
const env_pad_top: f64 = 34;
const env_pad_bottom: f64 = 14;

/// Because the screen is a schematic of how the three values shape a note, a segment is drawn `env_min`
/// pixels wide when its value is at its lowest, and `env_span` pixels wider when it is at its highest.
/// The note's hold between the decay and the release has a width and a level of its own.
const env_min: f64 = 6;
const env_span: f64 = 48;
const env_hold: f64 = 36;
const env_sustain: f64 = 0.55;

/// The strength of the curve's glow, a quarter of the accent's.
const env_glow: u32 = 0x44;

fn envelopeWidth(control: Control, value: i32, scale: f64) f64 {
    const t = @as(f64, @floatFromInt(value - control.low)) / @as(f64, @floatFromInt(control.high - control.low));
    return (env_min + t * env_span) * scale;
}

fn envelopeValue(control: Control, width: f64, scale: f64) i32 {
    const t = std.math.clamp((width / scale - env_min) / env_span, 0, 1);
    const span: f64 = @floatFromInt(control.high - control.low);
    return @intFromFloat(@floor(@as(f64, @floatFromInt(control.low)) + t * span + 0.5));
}

const EnvGeom = struct { left: f64, right: f64, top: f64, bottom: f64, scale: f64 };

/// The five corners of the curve: the start, the top of the attack, the end of the decay, the end of the
/// hold, and the end of the release.
fn envelopePoints(geom: EnvGeom, attack: f64, decay: f64, release: f64) [5]Point {
    const top_x = geom.left + attack;
    const decay_x = top_x + decay;
    const hold_x = decay_x + env_hold * geom.scale;
    const sustain_y = geom.bottom - (geom.bottom - geom.top) * env_sustain;
    return .{
        .{ .x = geom.left, .y = geom.bottom },
        .{ .x = top_x, .y = geom.top },
        .{ .x = decay_x, .y = sustain_y },
        .{ .x = hold_x, .y = sustain_y },
        .{ .x = hold_x + release, .y = geom.bottom },
    };
}

/// The new values of an envelope screen. A value changed when its flag is set.
pub const EnvelopeChange = struct { values: [3]i32, changed: [3]bool = .{ false, false, false } };

/// The screen of an envelope: a dark recessed display that draws the attack, the decay and the release
/// of a note as a glowing curve. Each of the three values has a handle on the curve, which the user drags
/// sideways to change the value, or double-clicks or alt-clicks to bring back to the middle.
/// `controls` holds the three parameters in the order attack, decay, release, and `values` their values.
pub fn envelope(panel: *Panel, controls: [3]Control, values: [3]i32) EnvelopeChange {
    const ctx = panel.ctx;
    const at = cursorScreenPos(panel);
    // The screen takes the room the card leaves; the 2 pixels keep the card from showing a scrollbar.
    var avail_w: f64 = 0;
    var avail_h: f64 = 0;
    imgui.api.GetContentRegionAvail(ctx, &avail_w, &avail_h);
    const width = if (avail_w >= 120) avail_w else env_w;
    const height = if (avail_h >= 60) avail_h - 2 else env_h;
    var geom = EnvGeom{ .left = at.x + env_pad_x, .right = at.x + width - env_pad_x, .top = at.y + env_pad_top, .bottom = at.y + height - env_pad_bottom, .scale = 1 };
    geom.scale = (geom.right - geom.left) / (env_w - 2 * env_pad_x);

    var points = envelopePoints(geom, envelopeWidth(controls[0], values[0], geom.scale), envelopeWidth(controls[1], values[1], geom.scale), envelopeWidth(controls[2], values[2], geom.scale));

    // Each handle sits on a corner of the curve, and its value is the distance from where its segment
    // starts, which is the previous corner (or the previous segment's end for the release).
    const corners = [3]usize{ 1, 2, 4 };
    const origins = [3]f64{ points[0].x, points[1].x, points[3].x };
    var result = EnvelopeChange{ .values = values };
    var hot: ?usize = null;
    var id: [64:0]u8 = undefined;
    imgui.api.PushID(ctx, std.fmt.bufPrintZ(&id, "{s}", .{controls[0].id}) catch "envelope");
    for (0..3) |i| {
        imgui.api.SetCursorScreenPos(ctx, points[corners[i]].x - 9, points[corners[i]].y - 9);
        var handle_id: [16:0]u8 = undefined;
        _ = imgui.api.InvisibleButton(ctx, std.fmt.bufPrintZ(&handle_id, "##handle{d}", .{i}) catch "##handle", 18, 18, null);
        const active = imgui.api.IsItemActive(ctx);
        const hovered = imgui.api.IsItemHovered(ctx, null);
        if (imgui.api.IsItemActivated(ctx) and altIsDown(panel)) {
            // An alt-click brings the handle back to the middle, as it does for a knob.
            result.values[i] = defaultValue(controls[i], true);
            result.changed[i] = true;
        } else if (active and !altIsDown(panel)) {
            var mx: f64 = 0;
            var my: f64 = 0;
            imgui.api.GetMousePos(ctx, &mx, &my);
            const v = envelopeValue(controls[i], mx - origins[i], geom.scale);
            if (v != values[i]) {
                result.values[i] = v;
                result.changed[i] = true;
            }
        } else if (hovered and imgui.api.IsMouseDoubleClicked(ctx, imgui.MouseButton_Left)) {
            result.values[i] = defaultValue(controls[i], true);
            result.changed[i] = true;
        }
        if (active or hovered) {
            hot = i;
            imgui.api.SetMouseCursor(ctx, imgui.MouseCursor_ResizeEW);
        }
    }
    imgui.api.PopID(ctx);
    // Because ImGui wants an item after every move of the cursor, the screen's own space is taken last:
    // the cursor goes back to the screen's corner, and a Dummy as large as the screen follows.
    imgui.api.SetCursorScreenPos(ctx, at.x, at.y);
    imgui.api.Dummy(ctx, width, height);

    // The curve is drawn with the values this frame's drag has just set, so that it follows the mouse.
    const a = result.values[0];
    const d = result.values[1];
    const r = result.values[2];
    points = envelopePoints(geom, envelopeWidth(controls[0], a, geom.scale), envelopeWidth(controls[1], d, geom.scale), envelopeWidth(controls[2], r, geom.scale));

    const dl = imgui.api.GetWindowDrawList(ctx);
    rectFilled(dl, at.x, at.y, at.x + width, at.y + height, theme.slot_bg, 5);
    rect(dl, at.x, at.y, at.x + width, at.y + height, theme.slot_edge, 5, 1);
    line(dl, at.x + 5, at.y + height + 1, at.x + width - 5, at.y + height + 1, theme.panel_edge_light, 1);

    for (0..9) |i| {
        const gx = geom.left + (geom.right - geom.left) * @as(f64, @floatFromInt(i)) / 8;
        line(dl, gx, geom.top, gx, geom.bottom, theme.screen_grid, 1);
    }
    for (0..3) |i| {
        const gy = geom.top + (geom.bottom - geom.top) * @as(f64, @floatFromInt(i)) / 2;
        line(dl, geom.left, gy, geom.right, gy, theme.screen_grid, 1);
    }

    // The curve, drawn twice: a wide faint line for the glow, and the line itself over it.
    var flags: c_int = imgui.DrawFlags_None;
    for (0..2) |pass| {
        for (points) |point| imgui.api.DrawList_PathLineTo(dl, point.x, point.y);
        var thickness: f64 = if (pass == 0) 6 else 2;
        imgui.api.DrawList_PathStroke(dl, if (pass == 0) faded(accent(panel), env_glow) else accent(panel), &flags, &thickness);
    }

    for (0..3) |i| {
        const px = points[corners[i]].x;
        const py = points[corners[i]].y;
        if (hot != null and hot.? == i) {
            circleFilled(dl, px, py, 6, accent(panel));
        } else {
            circleFilled(dl, px, py, 5, theme.knob_top);
            circle(dl, px, py, 5, accent(panel), 1.5);
        }
    }

    // The three values are read at the top of the screen, in the label font.
    const pushed = pushLabelFont(panel);
    var readout: [48:0]u8 = undefined;
    const text = std.fmt.bufPrintZ(&readout, "A {d:>3}  D {d:>3}  R {d:>3}", .{ a, d, r }) catch "";
    imgui.api.DrawList_AddText(dl, at.x + env_pad_x, at.y + 5, accent(panel), text);
    popFont(panel, pushed);
    drawGlass(dl, at.x, at.y, at.x + width, at.y + height);
    return result;
}

// ---- the picker ----

/// Begins a picker: a recessed screen with the chosen text in the accent color and a caret, like the display
/// of a knob with many stops and of the tone picker. A click on it opens a list. Returns true while the list is
/// open, and then the caller draws its items with `pickItem` and ends it with `endPickList`.
/// `id` must be unique in the window.
pub fn beginPickList(panel: *Panel, id: [:0]const u8, preview: [:0]const u8, width: f64) bool {
    const ctx = panel.ctx;
    const pushed = pushLabelFont(panel);
    const text_line = imgui.api.GetTextLineHeight(ctx);
    const at = cursorScreenPos(panel);
    const height = text_line + 12;
    var button_id: [96:0]u8 = undefined;
    _ = imgui.api.InvisibleButton(ctx, std.fmt.bufPrintZ(&button_id, "##pick{s}", .{id}) catch "##pick", width, height, null);
    const hot = imgui.api.IsItemHovered(ctx, null);
    var popup_id: [96:0]u8 = undefined;
    const popup = std.fmt.bufPrintZ(&popup_id, "##picklist{s}", .{id}) catch "##picklist";
    if (imgui.api.IsItemClicked(ctx, null)) imgui.api.OpenPopup(ctx, popup, null);
    const dl = imgui.api.GetWindowDrawList(ctx);
    rectFilled(dl, at.x, at.y, at.x + width, at.y + height, theme.slot_bg, 3);
    rect(dl, at.x, at.y, at.x + width, at.y + height, if (hot) accent(panel) else theme.slot_edge, 3, 1);
    imgui.api.DrawList_AddText(dl, at.x + 10, at.y + 6, accent(panel), preview);
    const cx = at.x + width - 12;
    const cy = at.y + height / 2;
    imgui.api.DrawList_AddTriangleFilled(dl, cx - 4, cy - 2, cx + 4, cy - 2, cx, cy + 3, if (hot) accent(panel) else theme.text_dim);
    drawGlass(dl, at.x, at.y, at.x + width, at.y + height);
    popFont(panel, pushed);
    var appearing: c_int = imgui.Cond_Appearing;
    imgui.api.SetNextWindowPos(ctx, at.x, at.y + height + 2, &appearing, null, null);
    return imgui.api.BeginPopup(ctx, popup, null);
}

/// One item of a picker's list. The chosen one is in the accent color, and an item that cannot be chosen is
/// dim. Returns true when the item was clicked.
pub fn pickItem(panel: *Panel, label: [:0]const u8, selected: bool, enabled: bool) bool {
    const ctx = panel.ctx;
    if (selected) imgui.api.PushStyleColor(ctx, imgui.Col_Text, accent(panel));
    if (!enabled) imgui.api.BeginDisabled(ctx, null);
    const clicked = imgui.api.Selectable(ctx, label, null, null, null, null);
    if (!enabled) imgui.api.EndDisabled(ctx);
    if (selected) {
        var one: c_int = 1;
        imgui.api.PopStyleColor(ctx, &one);
    }
    return clicked and enabled;
}

pub fn endPickList(panel: *Panel) void {
    const ctx = panel.ctx;
    imgui.api.EndPopup(ctx);
}

// ---- the tabs ----

/// Begins a tab, with its name drawn in the tab font and the tab color. Because ImGui draws the name when the
/// tab begins, the font and the color are popped at once, and the tab's content keeps the usual ones.
pub fn beginTab(panel: *Panel, label: [:0]const u8, flags: ?*c_int) bool {
    const ctx = panel.ctx;
    const font = panel.fonts.tab;
    if (font != null) imgui.api.PushFont(ctx, font);
    imgui.api.PushStyleColor(ctx, imgui.Col_Text, theme.tab_text);
    const is_open = imgui.api.BeginTabItem(ctx, label, null, flags);
    var one: c_int = 1;
    imgui.api.PopStyleColor(ctx, &one);
    if (font != null) imgui.api.PopFont(ctx);
    return is_open;
}

// Because Zig only compiles the functions that something calls, this test makes the whole module compile,
// including the components that the panel does not draw yet.
test "two panels do not share what a card measured" {
    var first = Panel{};
    var second = Panel{};
    rememberHeight(&first, "Reverb", 120);
    try std.testing.expectEqual(@as(?f64, 120), naturalHeight(&first, "Reverb"));
    try std.testing.expectEqual(@as(?f64, null), naturalHeight(&second, "Reverb"));
    rememberHeight(&second, "Reverb", 90);
    try std.testing.expectEqual(@as(?f64, 120), naturalHeight(&first, "Reverb"));
}

test "a card's accent belongs to its panel" {
    var first = Panel{};
    const second = Panel{};
    first.accent = 0x11223344;
    try std.testing.expectEqual(@as(c_int, 0x11223344), accent(&first));
    try std.testing.expectEqual(theme.amber, accent(&second));
}

test "a dial draws a value without taking part in the mouse, and the stacks balance" {
    const MockImGui = @import("mock_imgui").MockImGui;
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var panel = Panel{};
    const control = Control{ .id = "k", .low = 0, .high = 100, .unit = "%" };
    dial(&panel, control, 40, "Cutoff", theme.green);
    // A value outside the range is held to it, and a dial with no color takes the card's accent.
    dial(&panel, control, 250, "Resonance", null);
    dial(&panel, control, 0, "K3", theme.text_dim);
    try mock.assertBalanced();
}

test "the drawing calls draw into a list and leave the stacks balanced" {
    const MockImGui = @import("mock_imgui").MockImGui;
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    const dl: imgui.DrawListPtr = null;
    arc(dl, 5, 5, 4, std.math.pi, std.math.pi * 1.5, theme.text, 1.5);
    try mock.assertBalanced();
}

test "every component compiles" {
    std.testing.refAllDecls(@This());
}
