const imgui = @import("reaper_imgui");
const Knobs = @import("knob");

pub fn drawInvertedSlctblColors(
    ctx: imgui.ContextPtr,
    display_text: [:0]const u8,
    g_drwls_splitter: *imgui.DrawListSplitterPtr,
    drw_ls: imgui.DrawListPtr,
) !void {
    var splitter = g_drwls_splitter.*;
    if (splitter == null or !try imgui.ValidatePtr(.{ @as(*anyopaque, @ptrCast(splitter.?)), "ImGui_DrawListSplitter*" })) {
        g_drwls_splitter.* = try imgui.CreateDrawListSplitter(.{drw_ls});
        splitter = g_drwls_splitter.*;
    }

    try imgui.DrawListSplitter_Split(.{ splitter, 2 });
    defer imgui.DrawListSplitter_Merge(.{splitter}) catch {};
    try imgui.DrawListSplitter_SetCurrentChannel(.{ splitter, 0 });

    var prev_min_x: f64 = undefined;
    var prev_min_y: f64 = undefined;
    try imgui.GetItemRectMin(.{ ctx, &prev_min_x, &prev_min_y });

    var prev_max_x: f64 = undefined;
    var prev_max_y: f64 = undefined;
    try imgui.GetItemRectMax(.{ ctx, &prev_max_x, &prev_max_y });

    const bg_color = try imgui.GetStyleColor(.{ ctx, imgui.Col_Text });
    const text_color = try imgui.GetStyleColor(.{ ctx, imgui.Col_WindowBg });

    try imgui.DrawList_AddRectFilled(.{
        drw_ls,
        prev_min_x,
        prev_min_y,
        prev_max_x,
        prev_max_y,
        bg_color,
    });

    try imgui.DrawListSplitter_SetCurrentChannel(.{ splitter, 1 });
    var frame_padding_x: f64 = undefined;
    var frame_padding_y: f64 = undefined;
    try imgui.GetStyleVar(.{ ctx, imgui.StyleVar_FramePadding, &frame_padding_x, &frame_padding_y });
    try imgui.DrawList_AddText(.{
        drw_ls,
        prev_min_x + frame_padding_x,
        prev_min_y + frame_padding_y,
        text_color,
        display_text,
    });
}

/// The accent color of the theme of REAPER, made opaque: the color that a selected row or a header has. Only the button
/// that opens the FX chain uses it.
pub fn themeAccent(ctx: imgui.ContextPtr) !c_int {
    const color: u32 = @bitCast(try imgui.GetStyleColor(.{ ctx, imgui.Col_Header }));
    return @bitCast(color | 0xFF);
}

/// The accent color of the interface: the orange of the lit LEDs and of the labels of the modules. It marks what is
/// the alternative use of a control, and what is lit.
pub fn accentColor() c_int {
    return Knobs.led_orange;
}

/// The accent color of an alternative label: a little faded while shift is not held, so that it looks more saturated when
/// the control is about to do that use.
pub fn altColor(shift_held: bool) c_int {
    const faded_alpha: u32 = 0xB0;
    const bits: u32 = @bitCast(accentColor());
    return @bitCast(if (shift_held) bits else (bits & 0xFFFFFF00) | faded_alpha);
}
