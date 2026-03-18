const std = @import("std");
const imgui = @import("reaper_imgui");
const knob = @import("knob.zig");
const adjustBrightness = knob.adjustBrightness;
const Circle = knob.Circle;
const Arc = knob.Arc;
const Triangle = knob.Triangle;
const ControlFlags = knob.ControlFlags;
const Size = knob.Size;
const Position = knob.Position;
const Rectangle = knob.Rectangle;
const YControlFlags = knob.YControlFlags;
const angle = knob.angle;
const angle_min = knob.angle_min;
const angle_max = knob.angle_max;
const angle_default = knob.angle_default;
const statemachine = @import("../statemachine.zig");
const CCs = @import("../c1.zig").CCs;
const constants = @import("../constants.zig");
const TranslationStore = @import("../translations.zig").TranslationStore;
const tr = @import("../translations.zig").tr;

pub const Res = union(enum) { click, param_idx: u32, remove_mapping, value_changed: f32 };

pub fn drawWidget(
    ctx: imgui.ContextPtr,
    value: f64,
    label_id: knob.LabelId,
    flags: ControlFlags,
    comptime cc: CCs,
    assignment_label: [:0]const u8,
    param_store: *const statemachine.ParamStore,
    translations: *const TranslationStore,
) anyerror!?Res {
    const drwls = try imgui.GetWindowDrawList(.{ctx});
    const radius = constants.knob_size / 2;
    var clicked = false;
    var rv: ?Res = null;

    // Calculate text size for label
    var label_size: Size = .{ .w = undefined, .h = undefined };
    try imgui.CalcTextSize(.{ ctx, label_id.label, &label_size.w, &label_size.h });
    const text_padding = 2.0;

    var cur_pos = Position{ .x = undefined, .y = undefined };
    try imgui.GetCursorScreenPos(.{ ctx, &cur_pos.x, &cur_pos.y });

    const combo_width = constants.knob_size * 2;
    const total_width = @max(@max(radius * 2, label_size.w), combo_width);
    const val_disp: f64 = if (flags.no_val_display) 1 else 2;

    var frm_pdg: f64 = undefined;
    var var_dummy: f64 = undefined;
    try imgui.GetStyleVar(.{ ctx, imgui.StyleVar_FramePadding, &frm_pdg, &var_dummy });

    const widget_rect = Rectangle{
        .min_x = cur_pos.x,
        .min_y = cur_pos.y,
        .max_x = cur_pos.x + total_width,
        .max_y = cur_pos.y + radius * val_disp + label_size.h + text_padding * val_disp + try imgui.GetTextLineHeightWithSpacing(.{ctx}) + frm_pdg * 2,
    };

    {
        try imgui.PushClipRect(.{ ctx, widget_rect.min_x, widget_rect.min_y, widget_rect.max_x, widget_rect.max_y, true });
        defer imgui.PopClipRect(.{ctx}) catch {};

        // Draw background color
        try imgui.DrawList_AddRectFilled(.{ drwls, widget_rect.min_x, widget_rect.min_y, widget_rect.max_x, widget_rect.max_y, 0xFFFFFF22 });

        // Draw label at top
        try imgui.DrawList_AddText(.{ drwls, widget_rect.min_x + (total_width - label_size.w) / 2, widget_rect.min_y + text_padding, try imgui.GetStyleColor(.{ ctx, imgui.Col_Text }), label_id.label });

        // Draw "Empty" button in the center of the adjusted ClipRect
        const center_x = widget_rect.min_x + total_width / 2; // centered based on total width
        const center_y = widget_rect.min_y + label_size.h + text_padding * 2 + radius; // adjusted for label

        try imgui.SetCursorScreenPos(.{ ctx, center_x - radius, center_y - radius });

        const yctrl_rv = try YControl(ctx, label_id.id, radius * 2, radius * 2, .{ .invisible = true, .increment = false, .scale = .linear });
        const hovered = yctrl_rv[0];
        clicked = yctrl_rv[1];

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

        const angle_ = angle(value, 0.0, 1.0);
        var wiper_start: f64 = undefined;
        var wiper_end: f64 = undefined;
        switch (flags.trackStart) {
            .left => {
                wiper_start = angle_min();
                wiper_end = angle_;
            },
            .right => {
                wiper_start = angle_max();
                wiper_end = angle_;
            },
            .center => {
                wiper_start = angle_;
                wiper_end = angle_default();
            },
        }

        const drwLs = try imgui.GetWindowDrawList(.{ctx});
        var circleColor = try imgui.GetStyleColor(.{ ctx, imgui.Col_TitleBg });
        var dotColor = try imgui.GetStyleColor(.{ ctx, if (clicked) imgui.Col_SliderGrabActive else imgui.Col_SliderGrab });

        if (hovered and !clicked) {
            dotColor = adjustBrightness(dotColor, -30, false);
            circleColor = adjustBrightness(circleColor, 50, false);
        } else {
            dotColor = adjustBrightness(dotColor, 50, false);
            circleColor = adjustBrightness(circleColor, -30, false);
        }

        // Apply additional dimming if disabled
        if (flags.disabled) {
            dotColor = adjustBrightness(dotColor, -70, false);
            circleColor = adjustBrightness(circleColor, -70, false);
        }

        try Circle(drwLs, circleColor, center_x, center_y, 0.6, true, 32, radius);
        try Arc(drwLs, 0.85, 0.41, wiper_start, wiper_end, dotColor, 2, center_x, center_y, radius);
        try Triangle(drwLs, angle_, dotColor, center_x, center_y, 0.2, true, 0.45, radius, false);
    }

    if (try paramsCombo(ctx, cc, assignment_label, param_store, translations)) |v| {
        rv = v;
    }

    try imgui.SetCursorScreenPos(.{ ctx, widget_rect.min_x, widget_rect.min_y });
    try imgui.Dummy(.{
        ctx,
        widget_rect.max_x - widget_rect.min_x,
        widget_rect.max_y - widget_rect.min_y,
    });
    return rv;
}

pub fn YControl(ctx: imgui.ContextPtr, id: [:0]const u8, w: f64, h: f64, flags: YControlFlags) !std.meta.Tuple(&[_]type{ bool, bool }) {
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

pub fn paramsCombo(
    ctx: imgui.ContextPtr,
    comptime cc: CCs,
    assignment_label: [:0]const u8,
    param_store: *const statemachine.ParamStore,
    translations: *const TranslationStore,
) !?Res {
    var rv: ?Res = null;
    try imgui.PushItemWidth(.{ ctx, constants.knob_size * 2 });
    defer imgui.PopItemWidth(.{ctx}) catch {};
    const combo_id = std.fmt.comptimePrint("##combo_{s}", .{@tagName(cc)});
    if (try imgui.BeginCombo(.{ ctx, combo_id, assignment_label, null })) {
        defer imgui.EndCombo(.{ctx}) catch {};

        // Add "none" option to clear mapping
        if (try imgui.Selectable(.{ ctx, tr(translations, .mapping_none) })) {
            rv = .remove_mapping;
        }

        // List all available parameters
        for (0..param_store.len()) |i| {
            const param_name = param_store.getName(i);
            if (try imgui.Selectable(.{ ctx, param_name })) {
                rv = .{ .param_idx = @intCast(i) };
            }
        }
    }
    return rv;
}
