//! The plate of a module of the FX control panel: the face on which its knobs and buttons sit at fixed
//! positions, so that a control stays where it is whichever mode is shown.
//!
//! The rows and the stagger are those of the hardware. The slots of a module are measured on a photograph of
//! the Console 1, in its pixels, where a knob is 44 pixels wide, and are scaled to the size of our knobs. The
//! columns are not taken from the photograph: they are one knob width and the spacing of the style apart, as
//! the knobs of a flowing layout would be.
const std = @import("std");
const imgui = @import("reaper_imgui");
const Knobs = @import("knob");
const panel_theme = @import("panel_theme");
const button = @import("button.zig");

pub const Kind = enum {
    knob,
    /// A round button with its label at its right.
    button,
    /// A round button with its label under it.
    button_below,
};

/// A control of a module: the column it is in, its offset from the center of that column in pixels of the
/// photograph, and its height on the photograph.
pub const Slot = struct {
    kind: Kind,
    col: u8 = 0,
    dx: f64 = 0,
    y: f64,
    /// The control sits against the left edge of the plate, whatever the column.
    at_left: bool = false,
    /// The control sits against the top edge of the plate, whatever its height.
    at_top: bool = false,
    /// The control is a button that stands right after the label of the button in this slot (an index of
    /// `Spec.slots`), whatever the column, so that the two never overlap.
    follows: ?u8 = null,
    /// The control is a knob whose cap has its left edge where the control in this slot (an index of `Spec.slots`) has its own.
    align_left_to: ?u8 = null,
};

pub const Spec = struct {
    slots: []const Slot,
    columns: u8,
    /// The label that gives the width of a knob: the longest that the hardware has. A knob is as wide as the
    /// cap, or as this label if it is wider.
    widest_label: [:0]const u8,
    /// The labels of the buttons, in the order of `slots` (an empty one for a knob, or for a button whose label
    /// is not known to the module): the plate is as wide as the right edge of the widest of them needs.
    labels: []const [:0]const u8 = &.{},
    /// A width under which the plate does not go.
    min_width: f64 = 0,
    /// A height of the controls under which the plate does not go, for a plate whose content is not made of slots.
    min_content_h: f64 = 0,
    /// Room added between the columns, over the spacing of the style.
    column_gap: f64 = 0,
    /// The distance under which two columns do not come, for the label of a button that stands at the left of a
    /// column and must not reach the label of the knob of the next column.
    min_pitch: f64 = 0,
    /// The name of the module, written in the line that the plate leaves above its controls.
    title: [:0]const u8 = "",
    /// The font of the title, or null for the current one.
    title_font: imgui.FontPtr = null,
    /// The other titles that the module can have: the plate is as wide as the widest of them and of the title,
    /// so that its width does not change when its title does.
    title_alternatives: []const [:0]const u8 = &.{},
};

/// The height of the controls of the tallest module, on the frame before and on this one: the plates are all as tall as it.
var tallest: f64 = 0;
var frame_tallest: f64 = 0;

/// Must be called once at the start of each frame, before the plates of the modules.
pub fn startFrame() void {
    tallest = frame_tallest;
    frame_tallest = 0;
}

pub const TextPosition = button.TextPosition;

const photo_knob_size = 44.0;
const scale = Knobs.knob_size / photo_knob_size;
/// The rows are closer than on the photograph. Because the label of a knob stands over its cap and the
/// ring of LEDs is open under it, the label of the knob below can come up to the edge of the well of the knob above.
const row_squeeze = 0.82;
const pad = 6.0;
const button_r = button.default_radius;
/// The space between a button and its label, as roundButton leaves it.
const label_gap = 4.0;

pub const Plate = struct {
    start: Point,
    origin: Point,
    /// The width of a knob widget, which the knobs of the module are given.
    knob_w: f64,
    pitch: f64,
    line_h: f64,
    x_shift: f64,
    y_shift: f64,
    /// Where the button that follows another stands, from the left edge of the content before the shift.
    follow_cx: f64 = 0,
    /// Where the knob that is aligned to another control stands, as `follow_cx` is.
    align_cx: f64 = 0,
    width: f64,
    /// The height of the plate: its title's room and its controls'.
    height: f64,

    pub const Point = struct { x: f64, y: f64 };

    /// Measures the module, draws its plate at the cursor and returns what the controls need to be placed.
    /// `end` must follow once the controls are drawn.
    pub fn begin(ctx: imgui.ContextPtr, spec: Spec) !Plate {
        std.debug.assert(spec.columns >= 1);
        var text_w: f64 = undefined;
        var line_h: f64 = undefined;
        try imgui.CalcTextSize(.{ ctx, spec.widest_label, &text_w, &line_h });
        var spacing_x: f64 = undefined;
        var spacing_y: f64 = undefined;
        try imgui.GetStyleVar(.{ ctx, imgui.StyleVar_ItemSpacing, &spacing_x, &spacing_y });

        var plate: Plate = undefined;
        plate.knob_w = @max(Knobs.knob_size, text_w);
        plate.pitch = @max(plate.knob_w + spacing_x + spec.column_gap, spec.min_pitch);
        plate.line_h = line_h;

        // The extent of each control around its center, to find the corner of the content.
        var left: f64 = 0;
        var right: f64 = 0;
        var top: f64 = std.math.inf(f64);
        var bottom: f64 = -std.math.inf(f64);
        // The controls that sit against the left or the top edge come after the others, as the edges are those of
        // the others, and the ones that follow a button come last, as they need where it stands.
        for ([_]u2{ 0, 1, 2 }) |pass| for (spec.slots, 0..) |slot, i| {
            const slot_pass: u2 = if (slot.follows != null or slot.align_left_to != null) 2 else if (slot.at_left or slot.at_top) 1 else 0;
            if (slot_pass != pass) continue;
            std.debug.assert(slot.col < spec.columns);
            const half_w: f64, const up: f64, const down: f64 = switch (slot.kind) {
                .knob => .{ plate.knob_w / 2, Knobs.centerOffsetY(line_h), Knobs.widgetHeight(line_h) - Knobs.centerOffsetY(line_h) },
                .button => .{ button_r, @max(button_r, line_h / 2), @max(button_r, line_h / 2) },
                .button_below => .{ button_r, button_r, button_r + label_gap + line_h },
            };
            const cx = if (slot.follows) |base| blk: {
                const base_slot = spec.slots[base];
                const base_cx = if (base_slot.at_left) left + button_r else plate.knob_w / 2 + @as(f64, @floatFromInt(base_slot.col)) * plate.pitch + base_slot.dx * scale;
                var base_w: f64 = 0;
                var base_h: f64 = undefined;
                if (base < spec.labels.len and spec.labels[base].len > 0) try imgui.CalcTextSize(.{ ctx, spec.labels[base], &base_w, &base_h });
                plate.follow_cx = base_cx + button_r + label_gap + base_w + label_gap * 2 + button_r;
                break :blk plate.follow_cx;
            } else if (slot.align_left_to) |base| blk: {
                const base_slot = spec.slots[base];
                const base_half: f64 = if (base_slot.kind == .knob) plate.knob_w / 2 else button_r;
                const base_cx = if (base_slot.at_left) left + button_r else plate.knob_w / 2 + @as(f64, @floatFromInt(base_slot.col)) * plate.pitch + base_slot.dx * scale;
                // The cap is the knob that is aligned, not its widget, which is wider when its label is.
                plate.align_cx = base_cx - base_half + Knobs.knob_size / 2;
                break :blk plate.align_cx;
            } else if (slot.at_left) left + button_r else plate.knob_w / 2 + @as(f64, @floatFromInt(slot.col)) * plate.pitch + slot.dx * scale;
            const cy = if (slot.at_top) top + up else slot.y * scale * row_squeeze;
            left = @min(left, cx - half_w);
            right = @max(right, cx + half_w);
            if (slot.kind == .button and i < spec.labels.len and spec.labels[i].len > 0) {
                var label_w: f64 = undefined;
                var label_h: f64 = undefined;
                try imgui.CalcTextSize(.{ ctx, spec.labels[i], &label_w, &label_h });
                right = @max(right, cx + button_r + label_gap + label_w);
            }
            top = @min(top, cy - up);
            bottom = @max(bottom, cy + down);
        };
        if (spec.slots.len == 0) {
            top = 0;
            bottom = 0;
        }
        plate.x_shift = -left;
        plate.y_shift = -top;
        var title_w: f64 = 0;
        var title_h: f64 = undefined;
        if (spec.title_font != null) try imgui.PushFont(.{ ctx, spec.title_font });
        defer if (spec.title_font != null) imgui.PopFont(.{ctx}) catch {};
        // The line of the title is there even when the title is empty, so that the controls of a module keep their
        // places when its title changes.
        try imgui.CalcTextSize(.{ ctx, if (spec.title.len > 0) spec.title else "Ag", &title_w, &title_h });
        if (spec.title.len == 0) title_w = 0;
        for (spec.title_alternatives) |alternative| {
            var alternative_w: f64 = undefined;
            var alternative_h: f64 = undefined;
            try imgui.CalcTextSize(.{ ctx, alternative, &alternative_w, &alternative_h });
            title_w = @max(title_w, alternative_w);
        }
        plate.width = @max(@max(right - left, spec.min_width), title_w);

        // The plates are all as tall as the tallest.
        const content = @max(bottom - top, spec.min_content_h);
        frame_tallest = @max(frame_tallest, content);
        const controls_h = @max(content, tallest);
        const header = title_h + 4;
        plate.height = header + controls_h;

        try imgui.GetCursorScreenPos(.{ ctx, &plate.start.x, &plate.start.y });
        try drawFace(ctx, plate.start.x, plate.start.y, plate.width + pad * 2, plate.height + pad * 2);
        if (spec.title.len > 0) {
            const dl = try imgui.GetWindowDrawList(.{ctx});
            const title_y = plate.start.y + pad + 1;
            try imgui.DrawList_AddText(.{ dl, plate.start.x + pad + 2, title_y + 1, panel_theme.text_engraved_shadow, spec.title });
            try imgui.DrawList_AddText(.{ dl, plate.start.x + pad + 2, title_y, panel_theme.tab_text, spec.title });
        }
        plate.origin = .{ .x = plate.start.x + pad, .y = plate.start.y + pad + header };
        return plate;
    }

    /// The center of a control on the screen.
    fn center(self: Plate, slot: Slot) Point {
        return .{
            // The edge of the content is the origin, as the shift brings the leftmost control to it.
            .x = if (slot.follows != null)
                self.origin.x + self.x_shift + self.follow_cx
            else if (slot.align_left_to != null)
                self.origin.x + self.x_shift + self.align_cx
            else if (slot.at_left)
                self.origin.x + button_r
            else
                self.origin.x + self.x_shift + self.knob_w / 2 + @as(f64, @floatFromInt(slot.col)) * self.pitch + slot.dx * scale,
            .y = if (slot.at_top)
                self.origin.y + @max(button_r, self.line_h / 2)
            else
                self.origin.y + self.y_shift + slot.y * scale * row_squeeze,
        };
    }

    /// Puts the cursor where the knob widget must start for its cap to be centered on the slot.
    pub fn knob(self: Plate, ctx: imgui.ContextPtr, slot: Slot) !void {
        std.debug.assert(slot.kind == .knob);
        const c = self.center(slot);
        try imgui.SetCursorScreenPos(.{ ctx, c.x - self.knob_w / 2, c.y - Knobs.centerOffsetY(self.line_h) });
    }

    /// Puts the cursor where a round button with this label and this label position must start for the
    /// button to be centered on the slot.
    pub fn button(self: Plate, ctx: imgui.ContextPtr, slot: Slot, label: [:0]const u8, text_position: TextPosition) !void {
        std.debug.assert(slot.kind != .knob);
        std.debug.assert(text_position == .right or text_position == .below);
        const c = self.center(slot);
        switch (text_position) {
            .below => {
                var label_w: f64 = 0;
                var label_h: f64 = undefined;
                if (label.len > 0) try imgui.CalcTextSize(.{ ctx, label, &label_w, &label_h });
                try imgui.SetCursorScreenPos(.{ ctx, c.x - @max(2 * button_r, label_w) / 2, c.y - button_r });
            },
            else => try imgui.SetCursorScreenPos(.{ ctx, c.x - button_r, c.y - @max(2 * button_r, self.line_h) / 2 }),
        }
    }

    /// Gives the module its room in the flow of the panel.
    pub fn end(self: Plate, ctx: imgui.ContextPtr) !void {
        try imgui.SetCursorScreenPos(.{ ctx, self.start.x, self.start.y });
        try imgui.Dummy(.{ ctx, self.width + pad * 2, self.height + pad * 2 });
    }
};

/// The face of a module: raised from the panel by a dark edge and a lit one.
fn drawFace(ctx: imgui.ContextPtr, x: f64, y: f64, w: f64, h: f64) !void {
    const dl = try imgui.GetWindowDrawList(.{ctx});
    try imgui.DrawList_AddRectFilled(.{ dl, x + 1, y + 3, x + w + 1, y + h + 3, @as(c_int, @bitCast(@as(u32, 0x00000066))), 8 });
    try imgui.DrawList_AddRectFilled(.{ dl, x, y, x + w, y + h, panel_theme.panel_bg, 8 });
    try imgui.DrawList_AddRect(.{ dl, x, y, x + w, y + h, panel_theme.panel_edge_dark, 8, null, 1.5 });
    try imgui.DrawList_AddLine(.{ dl, x + 8, y + 1.5, x + w - 8, y + 1.5, panel_theme.card_bevel_light, 1 });
}

test "every declaration compiles" {
    std.testing.refAllDecls(@This());
}
