//! The keyboard view of the whichkey window. It draws the board described by
//! keyboard.zig, and puts on every cap what that key does next: the current
//! context, the pending key sequence and the held modifiers all change it.
//!
//! The modifier layer is the union of the modifiers held right now (polled
//! every frame, because a lone modifier press sends no key message) and the
//! Shift/Alt/Ctrl buttons above the board, which latch a layer for the mouse.
//! Hovering a cap shows the full action name; clicking it types the key.
const std = @import("std");
const imgui = @import("reaper_imgui");
const palette = @import("ui_palette");
const utils = @import("utils");
const keymod = @import("key.zig");
const keyboard = @import("keyboard.zig");
const config = @import("config.zig");
const vim = @import("vim.zig");
const ui = @import("ui.zig");

const rgba = palette.rgba;

/// Session state of the view. The config gives the starting view, layout and
/// board; the buttons above the board change them until REAPER restarts.
pub const ViewState = struct {
    view: ?keyboard.View = null,
    layout: ?keyboard.Layout = null,
    board: ?keyboard.Board = null,
    latched: keyboard.Layer = .{},
};

pub var view_state: ViewState = .{};

const MAX_COMPLETIONS = 512;
const GAP: f64 = 3;
const MAX_UNIT: f64 = 76;
/// Below this cap width the labels are unreadable, so the window falls back
/// to the list view.
const MIN_UNIT: f64 = 34;
const PAD: f64 = 4;

const cap_fill = rgba(0x3B3B3BFF);
const cap_fill_hovered = rgba(0x4C4C4CFF);
const cap_fill_unbound = rgba(0x2B2B2BFF);
const cap_border_unbound = rgba(0x404040FF);
const char_color = rgba(0x9AA3A3FF);
const char_color_unbound = rgba(0x5A5F5FFF);

/// The dark-theme colors of the keymap viewer page, so that the window and
/// the page read the same.
pub fn categoryColor(cat: keyboard.Category) c_int {
    return switch (cat) {
        .select, .selector => rgba(0x6AA6E8FF),
        .extend => rgba(0x4FCFC8FF),
        .jump, .motion => rgba(0xD6C26AFF),
        .pitch => rgba(0xEE8B72FF),
        .time => rgba(0xC79AE0FF),
        .length => rgba(0xEBB25AFF),
        .quant => rgba(0x7FCF7FFF),
        .edit => rgba(0xC9C7BFFF),
        .view => rgba(0x98A0B0FF),
        .mode => rgba(0xEE7DB4FF),
        .operator => palette.accent,
        .command => palette.key,
        .group => palette.green,
    };
}

pub fn currentView(b: *const config.Bindings) keyboard.View {
    return view_state.view orelse b.view;
}

pub fn toggleView(b: *const config.Bindings) void {
    view_state.view = switch (currentView(b)) {
        .list => .keyboard,
        .keyboard => .list,
    };
}

/// What one cap shows: its binding (if any), the text and the color.
pub const CapInfo = struct {
    key: ?keymod.Key = null,
    completion: ?vim.Completion = null,
    category: keyboard.Category = .command,
    text: []const u8 = "",
};

/// Everything the cap loop needs, gathered once per frame and passed down, so
/// that the drawing functions take one argument for the frame.
pub const Frame = struct {
    ctx: imgui.ContextPtr,
    bindings: *const config.Bindings,
    draw_list: imgui.DrawListPtr,
    layer: keyboard.Layer,
    completions: []const vim.Completion,
    unit: f64,
    cap_h: f64,
    line_h: f64,
    used: [@typeInfo(keyboard.Category).@"enum".field_names.len]bool = @splat(false),
    label_buf: [192:0]u8 = undefined,
};

/// Draws the keyboard view. Returns false when the window is too narrow for
/// it, so that the caller draws the list instead.
pub fn render(ctx: imgui.ContextPtr, b: *const config.Bindings) bool {
    const layout = view_state.layout orelse b.layout;
    const board = view_state.board orelse b.board;

    var avail_w: f64 = 0;
    var avail_h: f64 = 0;
    imgui.api.GetContentRegionAvail(ctx, &avail_w, &avail_h);
    const units = keyboard.boardWidth(layout, board);
    const unit = @min(MAX_UNIT, avail_w / units);
    if (unit < MIN_UNIT) return false;

    const held = vim.heldModifiers();
    var comp_buf: [MAX_COMPLETIONS]vim.Completion = undefined;
    const line_h = imgui.api.GetTextLineHeight(ctx);
    var frame = Frame{
        .ctx = ctx,
        .bindings = b,
        .draw_list = imgui.api.GetWindowDrawList(ctx),
        .layer = .{
            .shift = held.shift or view_state.latched.shift,
            .ctrl = held.ctrl or view_state.latched.ctrl,
            .alt = held.alt or view_state.latched.alt,
        },
        .completions = vim.completions(&comp_buf),
        .unit = unit,
        .cap_h = @max(unit * 0.8, 3 * line_h + 2 * PAD),
        .line_h = line_h,
    };

    var ox: f64 = 0;
    var oy: f64 = 0;
    imgui.api.GetCursorScreenPos(ctx, &ox, &oy);
    const rows = keyboard.rows(layout);
    for (rows, 0..) |row, ri| {
        const y = oy + @as(f64, @floatFromInt(ri)) * (frame.cap_h + GAP);
        var x = ox + unit * (if (board == .ortho) row.ortho else row.staggered);
        for (row.caps, 0..) |cap, ci| {
            x += cap.gap * unit;
            drawCap(&frame, cap, x, y, ri * 100 + ci);
            x += cap.width * unit;
        }
    }
    const height = @as(f64, @floatFromInt(rows.len)) * (frame.cap_h + GAP);
    imgui.api.SetCursorScreenPos(ctx, ox, oy + height);
    imgui.api.Dummy(ctx, units * unit, 0);

    renderLegend(&frame);
    return true;
}

/// The buttons of the side column, under the mode and the pending keys: the
/// view switch, and while the keyboard shows, the layers and the board. A
/// layer button is shown pressed while its modifier is held or latched.
pub fn renderButtons(ctx: imgui.ContextPtr, b: *const config.Bindings) void {
    const current = currentView(b);
    imgui.api.Dummy(ctx, 0, 4);

    if (iconButton(ctx, ui.Icon.grid, "Show the keys on a keyboard", current == .keyboard)) view_state.view = .keyboard;
    if (iconButton(ctx, ui.Icon.list, "Show the keys as a list", current == .list)) view_state.view = .list;
    if (current != .keyboard) return;

    imgui.api.Dummy(ctx, 0, 4);
    const held = vim.heldModifiers();
    if (layerButton(ctx, "Shift", "Show the Shift layer", held.shift, view_state.latched.shift))
        view_state.latched.shift = !view_state.latched.shift;
    if (layerButton(ctx, "Alt", "Show the Alt layer", held.alt, view_state.latched.alt))
        view_state.latched.alt = !view_state.latched.alt;
    if (layerButton(ctx, "Ctrl", "Show the Ctrl layer", held.ctrl, view_state.latched.ctrl))
        view_state.latched.ctrl = !view_state.latched.ctrl;

    imgui.api.Dummy(ctx, 0, 4);
    const layout = view_state.layout orelse b.layout;
    const board = view_state.board orelse b.board;
    if (sideButton(ctx, if (layout == .bepo) "B\xc3\x89" else "QW", "Switch between the B\xc3\x89PO and QWERTY layouts", false))
        view_state.layout = if (layout == .bepo) .qwerty else .bepo;
    if (iconButton(ctx, ui.Icon.board, "Switch between the ortholinear and the staggered board", board == .ortho))
        view_state.board = if (board == .ortho) .staggered else .ortho;
}

const BUTTON_H: f64 = 22;

/// A full-width text button of the side column. `on` paints it pressed. The
/// tooltip is shown by the caller, because the icon buttons have the icon font
/// pushed while they draw, and a tooltip drawn then would use it for its text.
fn buttonOnly(ctx: imgui.ContextPtr, label: [:0]const u8, tip: [:0]const u8, on: bool) bool {
    var id: [64:0]u8 = undefined;
    if (on) {
        imgui.api.PushStyleColor(ctx, imgui.Col_Button, palette.accent_dim);
        imgui.api.PushStyleColor(ctx, imgui.Col_Text, palette.key);
    }
    var w: f64 = ui.SIDE_W;
    var h: f64 = BUTTON_H;
    const clicked = imgui.api.Button(ctx, utils.safePrint(&id, "{s}##side_{s}", .{ label, tip }), &w, &h);
    if (on) {
        var n: c_int = 2;
        imgui.api.PopStyleColor(ctx, &n);
    }
    return clicked;
}

fn showButtonTooltip(ctx: imgui.ContextPtr, tip: [:0]const u8) void {
    if (imgui.api.IsItemHovered(ctx, &imgui.HoveredFlags_DelayNormal)) imgui.api.SetTooltip(ctx, tip);
}

fn sideButton(ctx: imgui.ContextPtr, label: [:0]const u8, tip: [:0]const u8, on: bool) bool {
    const clicked = buttonOnly(ctx, label, tip, on);
    showButtonTooltip(ctx, tip);
    return clicked;
}

/// The same, with the label drawn in the icon font. The font is popped before
/// the tooltip, so that the tooltip text uses the regular font.
fn iconButton(ctx: imgui.ContextPtr, glyph: [:0]const u8, tip: [:0]const u8, on: bool) bool {
    if (ui.icon_font != null) imgui.api.PushFont(ctx, ui.icon_font);
    const clicked = buttonOnly(ctx, glyph, tip, on);
    if (ui.icon_font != null) imgui.api.PopFont(ctx);
    showButtonTooltip(ctx, tip);
    return clicked;
}

fn layerButton(ctx: imgui.ContextPtr, label: [:0]const u8, tip: [:0]const u8, held: bool, latched: bool) bool {
    return sideButton(ctx, label, tip, held or latched);
}

/// Finds what a cap does on the current layer.
pub fn capInfo(frame: *Frame, cap: keyboard.Cap) CapInfo {
    const k = keyboard.keyOf(cap, frame.layer) orelse return .{};
    var info = CapInfo{ .key = k };
    for (frame.completions) |comp| {
        if (comp.key.eql(k)) {
            info.completion = comp;
            break;
        }
    }
    const comp = info.completion orelse return info;
    const is_group = comp.value == null;
    info.category = keyboard.fallbackCategory(comp.action_type, is_group);
    if (comp.value) |v| {
        if (frame.bindings.labels.get(v.name)) |label| {
            info.text = label.text;
            if (label.category) |cat| info.category = cat;
            return info;
        }
        info.text = shortName(frame, v);
        return info;
    }
    info.text = utils.safePrint(&frame.label_buf, "+{s}", .{comp.label orelse "..."});
    return info;
}

/// A label for an action without a `[labels]` entry: the action name split
/// into words, or REAPER's own name for a raw command id.
fn shortName(frame: *Frame, v: anytype) []const u8 {
    if (std.mem.startsWith(u8, v.name, "cmd:") or v.def.desc != null) {
        return ui.displayName(v, vim.activeContext(), &frame.label_buf);
    }
    return keyboard.humanize(v.name, &frame.label_buf);
}

fn drawCap(frame: *Frame, cap: keyboard.Cap, x: f64, y: f64, id: usize) void {
    const ctx = frame.ctx;
    const w = cap.width * frame.unit - GAP;
    const h = frame.cap_h;
    const info = capInfo(frame, cap);
    const bound = info.completion != null;

    var id_buf: [24:0]u8 = undefined;
    imgui.api.SetCursorScreenPos(ctx, x, y);
    const clicked = imgui.api.InvisibleButton(ctx, utils.safePrint(&id_buf, "##cap{d}", .{id}), w, h, null);
    const hovered = imgui.api.IsItemHovered(ctx, null);

    const color = categoryColor(info.category);
    const fill = if (!bound) cap_fill_unbound else if (hovered) cap_fill_hovered else cap_fill;
    var rounding: f64 = 5;
    imgui.api.DrawList_AddRectFilled(frame.draw_list, x, y, x + w, y + h, fill, &rounding, null);
    var thickness: f64 = 1;
    imgui.api.DrawList_AddRect(frame.draw_list, x, y, x + w, y + h, if (bound) color else cap_border_unbound, &rounding, null, &thickness);

    var no_clip = false;
    imgui.api.DrawList_PushClipRect(frame.draw_list, x + 1, y + 1, x + w - 1, y + h - 1, &no_clip);
    defer imgui.api.DrawList_PopClipRect(frame.draw_list);

    var char_buf: [16:0]u8 = undefined;
    const glyph = if (cap.named != null) cap.glyph else keyboard.charOf(cap, frame.layer);
    imgui.api.DrawList_AddText(frame.draw_list, x + PAD, y + PAD - 1, if (bound) char_color else char_color_unbound, utils.safePrint(&char_buf, "{s}", .{glyph}));

    if (bound) {
        frame.used[@backingInt(info.category)] = true;
        drawLabel(frame, info.text, x + PAD, y + PAD + frame.line_h, w - 2 * PAD, color);
    }

    if (hovered and bound) showTooltip(frame, info);
    if (clicked and bound) vim.typeKey(info.key.?);
}

/// Draws a label on up to two lines, broken at spaces, and ends the second
/// line with "..." when the label does not fit.
fn drawLabel(frame: *Frame, text: []const u8, x: f64, y: f64, max_w: f64, color: c_int) void {
    var line_buf: [192:0]u8 = undefined;
    var rest = std.mem.trim(u8, text, " ");
    var line_y = y;
    var line: usize = 0;
    while (rest.len > 0 and line < 2) : (line += 1) {
        const last = line == 1;
        const cut = if (last) rest.len else breakAt(frame.ctx, rest, max_w, &line_buf);
        var trim_buf: [256]u8 = undefined;
        const shown = if (last) ui.fitDesc(frame.ctx, rest, max_w, &trim_buf) else utils.safePrint(&line_buf, "{s}", .{rest[0..cut]});
        var z_buf: [256:0]u8 = undefined;
        imgui.api.DrawList_AddText(frame.draw_list, x, line_y, color, utils.safePrint(&z_buf, "{s}", .{shown}));
        rest = std.mem.trimStart(u8, rest[cut..], " ");
        line_y += frame.line_h;
    }
}

/// The length of the longest run of whole words of `text` that fits in
/// `max_w`. When even the first word is too wide, that word is returned whole
/// and the clip rectangle cuts it.
fn breakAt(ctx: imgui.ContextPtr, text: []const u8, max_w: f64, buf: [:0]u8) usize {
    var best: usize = 0;
    var i: usize = 0;
    while (i <= text.len) : (i += 1) {
        if (i < text.len and text[i] != ' ') continue;
        const candidate = utils.safePrint(buf, "{s}", .{text[0..i]});
        if (ui.textWidth(ctx, candidate) > max_w) break;
        best = i;
    }
    if (best == 0) {
        best = std.mem.indexOfScalar(u8, text, ' ') orelse text.len;
    }
    return best;
}

fn showTooltip(frame: *Frame, info: CapInfo) void {
    const ctx = frame.ctx;
    if (!imgui.api.BeginTooltip(ctx)) return;
    defer imgui.api.EndTooltip(ctx);
    var line: [256:0]u8 = undefined;
    var kbuf: [16]u8 = undefined;
    const notation = keymod.format(info.key.?, &kbuf);
    var pbuf: [96]u8 = undefined;
    const pending = vim.pending(&pbuf);
    ui.textColored(ctx, palette.key, utils.safePrint(&line, "{s}{s}", .{ pending, notation }));
    const comp = info.completion.?;
    if (comp.value) |v| {
        var dbuf: [192:0]u8 = undefined;
        imgui.api.Text(ctx, utils.safePrint(&line, "{s}", .{ui.displayName(v, vim.activeContext(), &dbuf)}));
        if (!std.mem.eql(u8, v.name, ui.displayName(v, vim.activeContext(), &dbuf)))
            imgui.api.Text(ctx, utils.safePrint(&line, "{s}", .{v.name}));
    } else {
        imgui.api.Text(ctx, utils.safePrint(&line, "menu: {s}", .{comp.label orelse "..."}));
    }
    ui.textColored(ctx, categoryColor(info.category), utils.safePrint(&line, "{s}", .{info.category.title()}));
}

/// One line naming the colors that the board uses.
fn renderLegend(frame: *Frame) void {
    const ctx = frame.ctx;
    var first = true;
    var line: [48:0]u8 = undefined;
    for (frame.used, 0..) |used, i| {
        if (!used) continue;
        const cat: keyboard.Category = @fromBackingInt(@intCast(i));
        if (!first) imgui.api.SameLine(ctx, null, null);
        first = false;
        ui.textColored(ctx, categoryColor(cat), utils.safePrint(&line, "{s}", .{cat.title()}));
    }
}
