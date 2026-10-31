//! The parts of a window that has the look of the panel: its heading engraved in the font and the orange of the module labels,
//! cards that hold its lists, and rows that light up under the mouse and under the cursor of the controller. The windows of
//! the plugin browser and of the presets draw them. Their cards are independent: they are as tall as their rows, and they do
//! not take part in the heights that the modules of the main panel share.
const std = @import("std");
const imgui = @import("reaper_imgui");
const panel_theme = @import("panel_theme");
const module_plate = @import("module_plate.zig");
const c1_theme = @import("../theme/c1_theme.zig");

/// The space that a card takes around its rows besides what the plate gives it: the padding of the face on its two sides.
const face_padding = 12.0;

/// Draws a text as the names of the modules are engraved in the panel: in the font and the orange of their labels, over a
/// dark copy of itself that is a pixel lower.
pub fn drawEngraved(ctx: imgui.ContextPtr, text: [:0]const u8) !void {
    try imgui.PushFont(.{ ctx, c1_theme.fonts.TAB });
    defer imgui.PopFont(.{ctx}) catch {};
    var x: f64 = undefined;
    var y: f64 = undefined;
    try imgui.GetCursorScreenPos(.{ ctx, &x, &y });
    var w: f64 = undefined;
    var h: f64 = undefined;
    try imgui.CalcTextSize(.{ ctx, text, &w, &h });
    const dl = try imgui.GetWindowDrawList(.{ctx});
    try imgui.DrawList_AddText(.{ dl, x + 1, y + 1, panel_theme.text_engraved_shadow, text });
    try imgui.DrawList_AddText(.{ dl, x, y, panel_theme.tab_text, text });
    try imgui.Dummy(.{ ctx, w, h });
}

/// Marks the row that was just drawn as the one that the cursor of the controller is on: the amber wash that the mouse gives
/// the row under it, a little stronger.
pub fn drawCursor(ctx: imgui.ContextPtr) !void {
    var x1: f64 = undefined;
    var y1: f64 = undefined;
    var x2: f64 = undefined;
    var y2: f64 = undefined;
    try imgui.GetItemRectMin(.{ ctx, &x1, &y1 });
    try imgui.GetItemRectMax(.{ ctx, &x2, &y2 });
    const dl = try imgui.GetWindowDrawList(.{ctx});
    try imgui.DrawList_AddRectFilled(.{ dl, x1, y1, x2, y2, panel_theme.amber_soft, 3 });
}

/// A small arrow at the right edge of the row that was just drawn, which says that the row opens a menu.
fn drawArrow(ctx: imgui.ContextPtr) !void {
    var x1: f64 = undefined;
    var y1: f64 = undefined;
    var x2: f64 = undefined;
    var y2: f64 = undefined;
    try imgui.GetItemRectMin(.{ ctx, &x1, &y1 });
    try imgui.GetItemRectMax(.{ ctx, &x2, &y2 });
    const dl = try imgui.GetWindowDrawList(.{ctx});
    const cx = x2 - 12;
    const cy = (y1 + y2) / 2;
    try imgui.DrawList_AddTriangleFilled(.{ dl, cx - 2.5, cy - 4, cx - 2.5, cy + 4, cx + 3, cy, panel_theme.text_dim });
}

/// One row of a list, in the font and the color of the window: a menu has an arrow at its right edge. The row is lit when the
/// mouse is on it, as the entries of a combo are, and when the cursor of the controller is on it. When it is the cursor's row
/// and the list has to scroll to it, `scroll_changed` is cleared. It returns whether the row was clicked.
pub fn row(ctx: imgui.ContextPtr, label: [:0]const u8, is_menu: bool, is_cursor: bool, scroll_changed: ?*bool) !bool {
    const clicked = try imgui.Selectable(.{ ctx, label });
    if (is_menu) try drawArrow(ctx);
    if (is_cursor) {
        try drawCursor(ctx);
        if (scroll_changed) |changed| {
            if (changed.*) {
                try imgui.SetScrollHereY(.{ ctx, 0.5 });
                changed.* = false;
            }
        }
    }
    return clicked;
}

/// The pixels that a card takes around its rows: the room for its label, and its edges.
pub fn cardOverhead(ctx: imgui.ContextPtr) !f64 {
    try imgui.PushFont(.{ ctx, c1_theme.fonts.TAB });
    defer imgui.PopFont(.{ctx}) catch {};
    var w: f64 = undefined;
    var h: f64 = undefined;
    try imgui.CalcTextSize(.{ ctx, "Ag", &w, &h });
    var spacing_x: f64 = undefined;
    var spacing_y: f64 = undefined;
    try imgui.GetStyleVar(.{ ctx, imgui.StyleVar_ItemSpacing, &spacing_x, &spacing_y });
    // The label's line, the padding of the face on its two sides, and the space before the next item.
    return h + 4 + face_padding + spacing_y;
}

pub const Card = struct {
    plate: module_plate.Plate,
    /// Whether the region of the rows is visible, which is when its rows are to be drawn.
    visible: bool,
};

/// Starts a card, with its label engraved at its top and its rows in a region of their own that scrolls. `endCard` must
/// follow. The card is as wide as the window, and as tall as `rows_height` and its label.
pub fn beginCard(ctx: imgui.ContextPtr, id: [:0]const u8, title: [:0]const u8, rows_height: f64) !Card {
    var available_w: f64 = undefined;
    var available_h: f64 = undefined;
    try imgui.GetContentRegionAvail(.{ ctx, &available_w, &available_h });
    // The label of a card is in capitals, as those of the modules are.
    var title_buf: [128:0]u8 = undefined;
    const length = @min(title.len, title_buf.len - 1);
    for (title[0..length], 0..) |letter, i| title_buf[i] = std.ascii.toUpper(letter);
    title_buf[length] = 0;
    const plate = try module_plate.Plate.begin(ctx, .{
        .slots = &.{},
        .columns = 1,
        .widest_label = "Ag",
        .title = title_buf[0..length :0],
        .title_font = c1_theme.fonts.TAB,
        .min_width = @max(available_w - face_padding, 120),
        .min_content_h = rows_height,
        .independent = true,
    });
    try imgui.SetCursorScreenPos(.{ ctx, plate.origin.x, plate.origin.y });
    const visible = try imgui.BeginChild(.{ ctx, id, plate.width, rows_height, null, imgui.WindowFlags_None });
    return .{ .plate = plate, .visible = visible };
}

pub fn endCard(ctx: imgui.ContextPtr, plate: module_plate.Plate) !void {
    try imgui.EndChild(.{ctx});
    try plate.end(ctx);
}
