//! The key of a control in the mapping panel, with its combo where the label of the key is in the panel of the FX controls:
//! at its right, or under it. The combo is as tall as a line of text.
const std = @import("std");
const imgui = @import("reaper_imgui");
const knob = @import("knob");
const panel_theme = @import("panel_theme");
const Size = knob.Size;
const Position = knob.Position;
const button = @import("button.zig");
const TextPosition = button.TextPosition;
const mappingKnob = @import("mappingKnob.zig");
const TranslationStore = @import("../translations.zig").TranslationStore;

/// The text that gives the width of the combo of a key. A plate whose slots have keys is given it as the label of those, so
/// that it leaves the room for the combo where the label stands.
pub const combo_label: [:0]const u8 = "Param";

/// The space between a key and its combo, as `roundButton` leaves between a key and its label.
const gap = 4.0;

/// The width of the combo of a key.
pub fn comboWidth(ctx: imgui.ContextPtr) !f64 {
    var w: f64 = undefined;
    var h: f64 = undefined;
    try imgui.CalcTextSize(.{ ctx, combo_label, &w, &h });
    return w;
}

pub fn mappingButton(
    ctx: imgui.ContextPtr,
    /// What the key is, which the combo shows dimmed while nothing is mapped.
    label: [:0]const u8,
    id: [:0]const u8,
    text_position: TextPosition,
    disabled: bool,
    /// The control is the one that the next parameter will be mapped to: it is washed in the amber of the panel.
    selected: bool,
    comptime cc: @import("../c1.zig").CCs,
    assigned: ?[:0]const u8,
    param_store: ?*const @import("../statemachine.zig").ParamStore,
    translations: *const TranslationStore,
) anyerror!?mappingKnob.Res {
    std.debug.assert(text_position == .right or text_position == .below);
    const radius = button.default_radius;
    const draw_list = try imgui.GetWindowDrawList(.{ctx});
    var rv: ?mappingKnob.Res = null;

    var line: Size = .{ .w = undefined, .h = undefined };
    try imgui.CalcTextSize(.{ ctx, "Ag", &line.w, &line.h });
    const combo_w = try comboWidth(ctx);

    var cur_pos = Position{ .x = undefined, .y = undefined };
    try imgui.GetCursorScreenPos(.{ ctx, &cur_pos.x, &cur_pos.y });

    const key_size = radius * 2;
    const width = switch (text_position) {
        .right => key_size + gap + combo_w,
        else => @max(key_size, combo_w),
    };
    const height = switch (text_position) {
        .right => @max(key_size, line.h),
        else => key_size + gap + line.h,
    };
    const center_x = switch (text_position) {
        .right => cur_pos.x + radius,
        else => cur_pos.x + width / 2,
    };
    const center_y = switch (text_position) {
        .right => cur_pos.y + height / 2,
        else => cur_pos.y + radius,
    };
    const combo_x = switch (text_position) {
        .right => cur_pos.x + key_size + gap,
        else => cur_pos.x + (width - combo_w) / 2,
    };
    const combo_y = switch (text_position) {
        .right => center_y - line.h / 2,
        else => cur_pos.y + key_size + gap,
    };

    if (selected) try imgui.DrawList_AddRectFilled(.{ draw_list, cur_pos.x - 2, cur_pos.y - 2, cur_pos.x + width + 2, cur_pos.y + height + 2, panel_theme.amber_faint, 6 });

    try imgui.SetCursorScreenPos(.{ ctx, center_x - radius, center_y - radius });
    var clicked = false;
    if (!disabled) {
        clicked = try imgui.InvisibleButton(.{ ctx, id, key_size, key_size });
    } else {
        try imgui.Dummy(.{ ctx, key_size, key_size });
    }
    const hovered = try imgui.IsItemHovered(.{ ctx, imgui.HoveredFlags_None });
    const held = !disabled and try imgui.IsItemActive(.{ctx});
    try knob.drawRoundKey(draw_list, center_x, center_y, radius, -1, .{ .hovered = hovered, .active = held, .disabled = disabled });
    if (clicked) rv = .click;

    try imgui.SetCursorScreenPos(.{ ctx, combo_x, combo_y });
    if (try mappingKnob.paramsCombo(ctx, cc, label, assigned, combo_w, param_store, translations)) |v| rv = v;

    try imgui.SetCursorScreenPos(.{ ctx, cur_pos.x, cur_pos.y });
    try imgui.Dummy(.{ ctx, width, height });
    return rv;
}
