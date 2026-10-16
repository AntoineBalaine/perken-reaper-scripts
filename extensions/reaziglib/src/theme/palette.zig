//! The colors of ReaVim's ReaImGui windows: Console1's main palette
//! (reaperConsole1 default_reaper_theme.ini). The whichkey window and the
//! action palette both take their colors from here, so that they look alike
//! and a change to the palette reaches both.
const imgui = @import("reaper_imgui");

/// A style color slot and the value to push for it. The slot is a pointer
/// because ReaImGui resolves the slot numbers when it loads, not at compile
/// time.
pub const ColorPair = struct { col: *c_int, val: c_int };

/// 0xRRGGBBAA to the packed value ReaImGui expects.
pub fn rgba(comptime hex: u32) c_int {
    return @bitCast(hex);
}

pub const window_bg = rgba(0x333333FF);
pub const text = rgba(0x818989FF);
pub const border = rgba(0x4F4F4FFF);
pub const title_bg = rgba(0x464646FF);
pub const title_bg_active = rgba(0x606060FF);
pub const frame_bg = rgba(0x333333FF);
pub const accent = rgba(0xFF00A5FF); // ActiveToggle
pub const green = rgba(0x13BD99FF); // ButtonActive
pub const key = rgba(0xC1FFE1FF); // ButtonHovered, opaque
pub const accent_dim = rgba(0xFF00A566); // accent at 40% for text selection

/// The window itself: background, regular text, borders and title bar.
pub const window_colors = [_]ColorPair{
    .{ .col = &imgui.Col_WindowBg, .val = window_bg },
    .{ .col = &imgui.Col_Text, .val = text },
    .{ .col = &imgui.Col_Border, .val = border },
    .{ .col = &imgui.Col_TitleBg, .val = title_bg },
    .{ .col = &imgui.Col_TitleBgActive, .val = title_bg_active },
    .{ .col = &imgui.Col_FrameBg, .val = frame_bg },
};

/// A text field sets every color it uses, because the inherited defaults
/// gave dark text on the dark frame: typed text uses the bright key color,
/// the hint the regular text color, on a frame lighter than the window.
/// `border_color` lets the caller highlight the field.
pub fn fieldColors(border_color: c_int) [7]ColorPair {
    return .{
        .{ .col = &imgui.Col_Text, .val = key },
        .{ .col = &imgui.Col_TextDisabled, .val = text },
        .{ .col = &imgui.Col_FrameBg, .val = title_bg },
        .{ .col = &imgui.Col_FrameBgHovered, .val = title_bg_active },
        .{ .col = &imgui.Col_FrameBgActive, .val = title_bg_active },
        .{ .col = &imgui.Col_TextSelectedBg, .val = accent_dim },
        .{ .col = &imgui.Col_Border, .val = border_color },
    };
}

/// Selectable rows: the selected row is lighter than the window, the hovered
/// one in between, and a pressed one takes the accent.
pub const list_colors = [_]ColorPair{
    .{ .col = &imgui.Col_Header, .val = title_bg_active },
    .{ .col = &imgui.Col_HeaderHovered, .val = title_bg },
    .{ .col = &imgui.Col_HeaderActive, .val = accent_dim },
    .{ .col = &imgui.Col_ScrollbarBg, .val = window_bg },
    .{ .col = &imgui.Col_ScrollbarGrab, .val = title_bg_active },
};

pub fn push(ctx: imgui.ContextPtr, pairs: []const ColorPair) void {
    for (pairs) |p| imgui.api.PushStyleColor(ctx, p.col.*, p.val);
}

pub fn pop(ctx: imgui.ContextPtr, count: usize) void {
    var n: c_int = @intCast(count);
    imgui.api.PopStyleColor(ctx, &n);
}

test "rgba packs the hex value unchanged" {
    const std = @import("std");
    try std.testing.expectEqual(@as(c_int, @bitCast(@as(u32, 0x333333FF))), window_bg);
}
