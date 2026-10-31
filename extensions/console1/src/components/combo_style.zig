//! The look of the combos of the panel: a dark recessed frame, a light outline, and the amber of the panel for what is hovered
//! and chosen. The settings and the mapping panel push it around their combos, so that all of them look alike.
const std = @import("std");
const imgui = @import("reaper_imgui");
const panel_theme = @import("panel_theme");
const palette = @import("ui_palette");

const colors = [_]palette.ColorPair{
    .{ .col = &imgui.Col_FrameBg, .val = panel_theme.frame_bg },
    .{ .col = &imgui.Col_FrameBgHovered, .val = panel_theme.amber_faint },
    .{ .col = &imgui.Col_FrameBgActive, .val = panel_theme.amber_soft },
    .{ .col = &imgui.Col_Border, .val = panel_theme.frame_border },
    .{ .col = &imgui.Col_Button, .val = palette.rgba(0x3A3A3EFF) },
    .{ .col = &imgui.Col_ButtonHovered, .val = panel_theme.amber_soft },
    .{ .col = &imgui.Col_ButtonActive, .val = panel_theme.amber },
    .{ .col = &imgui.Col_Header, .val = palette.rgba(0x3A3A3EFF) },
    .{ .col = &imgui.Col_HeaderHovered, .val = panel_theme.amber_faint },
    .{ .col = &imgui.Col_HeaderActive, .val = panel_theme.amber_soft },
    .{ .col = &imgui.Col_PopupBg, .val = panel_theme.panel_bg },
    .{ .col = &imgui.Col_Text, .val = panel_theme.text },
};
/// A color with another opacity, which is `alpha` out of 255.
pub fn withAlpha(color: c_int, alpha: u8) c_int {
    const bits: u32 = @bitCast(color);
    return @bitCast((bits & 0xFFFFFF00) | alpha);
}

/// The opacity of the outline and of the chevron of the combos that have no fill: lower than the text, so that the edges of
/// the combo do not stand out as much as what is written in it.
pub const outline_alpha: u8 = 0x58;
pub const chevron_alpha: u8 = 0x90;

/// The same colors with a frame that has no fill, for combos that sit on a surface whose color they must keep.
const colors_transparent = blk: {
    var copy = colors;
    std.debug.assert(copy[0].col == &imgui.Col_FrameBg);
    copy[0].val = palette.rgba(0x00000000);
    std.debug.assert(copy[3].col == &imgui.Col_Border);
    copy[3].val = withAlpha(panel_theme.frame_border, outline_alpha);
    break :blk copy;
};
const var_count: c_int = 3;

/// Pushes the style of the combos. `pop` takes it off once the list is closed.
pub fn push(ctx: imgui.ContextPtr) void {
    palette.push(ctx, &colors);
    panel_theme.pushVar(ctx, imgui.StyleVar_FrameRounding, 3);
    panel_theme.pushVar(ctx, imgui.StyleVar_FrameBorderSize, 1);
    panel_theme.pushVar2(ctx, imgui.StyleVar_FramePadding, 8, 4);
}

/// Pushes the style of the combos with a frame that has no fill, so that it shows the color of what it is on. `pop` takes it off.
pub fn pushTransparent(ctx: imgui.ContextPtr) void {
    palette.push(ctx, &colors_transparent);
    panel_theme.pushVar(ctx, imgui.StyleVar_FrameRounding, 3);
    panel_theme.pushVar(ctx, imgui.StyleVar_FrameBorderSize, 1);
    panel_theme.pushVar2(ctx, imgui.StyleVar_FramePadding, 8, 4);
}

pub fn pop(ctx: imgui.ContextPtr) void {
    var vars = var_count;
    imgui.api.PopStyleVar(ctx, &vars);
    palette.pop(ctx, colors.len);
}
