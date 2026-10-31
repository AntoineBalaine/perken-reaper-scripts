//! The knob and the combo of a control in the mapping panel. The combo takes the place that the label has in the panel of the
//! FX controls, over the cap, and is as tall as a line of text, so that a knob has the measures that it has there.
const std = @import("std");
const imgui = @import("reaper_imgui");
const knob = @import("knob");
const panel_theme = @import("panel_theme");
const ControlFlags = knob.ControlFlags;
const Size = knob.Size;
const Position = knob.Position;
const Rectangle = knob.Rectangle;
const YControlFlags = knob.YControlFlags;
const statemachine = @import("../statemachine.zig");
const CCs = @import("../c1.zig").CCs;
const constants = @import("../constants.zig");
const TranslationStore = @import("../translations.zig").TranslationStore;
const tr = @import("../translations.zig").tr;
const combo_style = @import("combo_style.zig");

pub const Res = union(enum) { click, param_idx: u32, remove_mapping, value_changed: f32 };

/// A knob with its combo over the cap, where its label is in the panel of the FX controls. `width` is the width of the
/// widget, which is the one that the plate gives to the knobs of the module. `assigned` is the name of the parameter that the
/// control is mapped to, and is null when it is not mapped: the combo then shows the label of the control, dimmed.
pub fn drawWidget(
    ctx: imgui.ContextPtr,
    value: f64,
    label_id: knob.LabelId,
    flags: ControlFlags,
    width: f64,
    comptime cc: CCs,
    assigned: ?[:0]const u8,
    param_store: ?*const statemachine.ParamStore,
    translations: *const TranslationStore,
) anyerror!?Res {
    const drwls = try imgui.GetWindowDrawList(.{ctx});
    const radius = knob.knob_size / 2;
    var rv: ?Res = null;

    var line: Size = .{ .w = undefined, .h = undefined };
    try imgui.CalcTextSize(.{ ctx, "Ag", &line.w, &line.h });

    var cur_pos = Position{ .x = undefined, .y = undefined };
    try imgui.GetCursorScreenPos(.{ ctx, &cur_pos.x, &cur_pos.y });

    const total_width = @max(width, radius * 2);
    const widget_rect = Rectangle{
        .min_x = cur_pos.x,
        .min_y = cur_pos.y,
        .max_x = cur_pos.x + total_width,
        .max_y = cur_pos.y + knob.widgetHeight(line.h),
    };

    if (flags.knob_bg) |bg| {
        try imgui.DrawList_AddRectFilled(.{ drwls, widget_rect.min_x, widget_rect.min_y, widget_rect.max_x, widget_rect.max_y, bg, 6 });
    }

    // The combo is over the cap, in the line of the label.
    if (try paramsCombo(ctx, cc, label_id.label, assigned, total_width, param_store, translations)) |v| {
        rv = v;
    }

    // The cap answers the mouse over the width of the widget, from under the combo.
    const center_x = widget_rect.min_x + total_width / 2;
    const center_y = widget_rect.min_y + knob.centerOffsetY(line.h);
    try imgui.SetCursorScreenPos(.{ ctx, widget_rect.min_x, widget_rect.min_y + line.h });
    const yctrl_rv = try YControl(ctx, label_id.id, total_width, widget_rect.max_y - widget_rect.min_y - line.h, .{ .invisible = true, .increment = false, .scale = .linear });
    const hovered = yctrl_rv[0];
    const clicked = yctrl_rv[1];

    if (try imgui.IsItemActive(.{ctx})) {
        var delta_x: f64 = undefined;
        var delta_y: f64 = undefined;
        try imgui.GetMouseDragDelta(.{ ctx, &delta_x, &delta_y, null, null });
        if (delta_y != 0) {
            var speed: f64 = 200.0;
            if (try imgui.IsKeyDown(.{ ctx, imgui.Mod_Shift }) or try imgui.IsKeyDown(.{ ctx, imgui.Mod_Alt })) {
                speed = 2000.0;
            }
            const new_val = std.math.clamp(value - delta_y / speed, 0.0, 1.0);
            rv = .{ .value_changed = @floatCast(new_val) };
            try imgui.ResetMouseDragDelta(.{ ctx, imgui.MouseButton_Left });
        }
    } else if (clicked) {
        rv = .click;
    }

    try knob.drawCapKnob(drwls, center_x, center_y, radius, value, flags.trackStart, .{ .hovered = hovered, .active = clicked, .disabled = flags.disabled });

    try imgui.SetCursorScreenPos(.{ ctx, widget_rect.min_x, widget_rect.min_y });
    try imgui.Dummy(.{
        ctx,
        widget_rect.max_x - widget_rect.min_x,
        widget_rect.max_y - widget_rect.min_y,
    });
    return rv;
}

pub fn YControl(ctx: imgui.ContextPtr, id: [:0]const u8, w: f64, h: f64, flags: YControlFlags) !@Tuple(&[_]type{ bool, bool }) {
    try imgui.SetNextItemAllowOverlap(.{ctx});
    var clicked: bool = false;

    if (flags.invisible) {
        clicked = try imgui.InvisibleButton(.{ ctx, id, w, h });
    } else {
        clicked = try imgui.Button(.{ ctx, "", w, h });
    }

    const isHovered = try imgui.IsItemHovered(.{ctx});
    return .{ isHovered, clicked };
}

/// The room that the chevron takes at the right edge of a combo.
const chevron_room = 14.0;

/// Writes the text of the combo that was just drawn, cut before the chevron, and draws the chevron at its right edge.
fn drawPreview(ctx: imgui.ContextPtr, text: [:0]const u8, dimmed: bool) !void {
    var x1: f64 = undefined;
    var y1: f64 = undefined;
    var x2: f64 = undefined;
    var y2: f64 = undefined;
    try imgui.GetItemRectMin(.{ ctx, &x1, &y1 });
    try imgui.GetItemRectMax(.{ ctx, &x2, &y2 });
    var text_w: f64 = undefined;
    var text_h: f64 = undefined;
    try imgui.CalcTextSize(.{ ctx, text, &text_w, &text_h });
    const dl = try imgui.GetWindowDrawList(.{ctx});
    try imgui.PushClipRect(.{ ctx, x1 + 1, y1, x2 - chevron_room, y2, true });
    try imgui.DrawList_AddText(.{ dl, x1 + 4, (y1 + y2) / 2 - text_h / 2, if (dimmed) panel_theme.text_dim else panel_theme.text, text });
    try imgui.PopClipRect(.{ctx});
    try drawChevron(dl, x2, y1, y2, panel_theme.text_dim);
}

/// The room that the chevron takes at the right edge of a combo or of a button that opens something.
pub const chevron_width = chevron_room;

/// A chevron that points down, at the right edge of a frame whose right edge is `x2`.
pub fn drawChevron(dl: imgui.DrawListPtr, x2: f64, y1: f64, y2: f64, color: c_int) !void {
    const cx = x2 - chevron_room / 2 - 1;
    const cy = (y1 + y2) / 2;
    try imgui.DrawList_AddLine(.{ dl, cx - 3, cy - 1.5, cx, cy + 1.5, color, 1.3 });
    try imgui.DrawList_AddLine(.{ dl, cx, cy + 1.5, cx + 3, cy - 1.5, color, 1.3 });
}

/// The combo of a control, as tall as a line of text and without the arrow, so that it takes the place of a label. It lists
/// the parameters of the plugin, and `none` to remove the mapping. `control_label` is shown dimmed while nothing is mapped, so
/// that the control can still be told from the others.
pub fn paramsCombo(
    ctx: imgui.ContextPtr,
    comptime cc: CCs,
    control_label: [:0]const u8,
    assigned: ?[:0]const u8,
    width: f64,
    param_store: ?*const statemachine.ParamStore,
    translations: *const TranslationStore,
) !?Res {
    var rv: ?Res = null;
    const combo_id = std.fmt.comptimePrint("##combo_{s}", .{@tagName(cc)});

    combo_style.pushTransparent(ctx);
    defer combo_style.pop(ctx);
    // The frame is as tall as the text.
    panel_theme.pushVar2(ctx, imgui.StyleVar_FramePadding, 4, 0);
    defer {
        var one: c_int = 1;
        imgui.api.PopStyleVar(ctx, &one);
    }

    try imgui.SetNextItemWidth(.{ ctx, width });
    // The text is drawn over the frame below, and not by the combo, so that it stops before the chevron at the right edge.
    const open = try imgui.BeginCombo(.{ ctx, combo_id, "", imgui.ComboFlags_NoArrowButton });
    try drawPreview(ctx, assigned orelse control_label, assigned == null);

    if (!open) {
        // A name that is cut by the width of the combo is read in full here.
        if (try imgui.IsItemHovered(.{ ctx, imgui.HoveredFlags_None })) {
            var buf: [256:0]u8 = undefined;
            const text = std.mem.printSentinel(&buf, "{s}: {s}", .{ control_label, assigned orelse tr(translations, .mapping_none) }, 0) catch control_label;
            try imgui.SetTooltip(.{ ctx, text });
        }
        return rv;
    }
    defer imgui.EndCombo(.{ctx}) catch {};

    // The list has the regular spacing of its rows.
    try imgui.Spacing(.{ctx});
    if (try imgui.Selectable(.{ ctx, tr(translations, .mapping_none) })) {
        rv = .remove_mapping;
    }

    // Because a module that has no FX has no parameters, its list is the "none" row only.
    if (param_store) |store| {
        for (0..store.len()) |i| {
            const param_name = store.getName(i);
            if (try imgui.Selectable(.{ ctx, param_name })) {
                rv = .{ .param_idx = @intCast(i) };
            }
        }
    }
    return rv;
}
