const std = @import("std");
const imgui = @import("reaper_imgui");
const Theme = @import("theme/Theme.zig");

pub fn drawInvertedSlctblColors(
    ctx: imgui.ContextPtr,
    display_text: [:0]const u8,
    g_drwls_splitter: *imgui.DrawListSplitterPtr,
) !void {
    var splitter = g_drwls_splitter.*;
    const drw_ls = try imgui.GetWindowDrawList(.{ctx});
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

    const bg_color = Theme.clrs.get(std.meta.stringToEnum(Theme.RColorsEnum, "genlist_fg").?).color;
    try imgui.DrawList_AddRectFilled(.{
        drw_ls,
        prev_min_x,
        prev_min_y,
        prev_max_x,
        prev_max_y,
        bg_color,
    });

    try imgui.DrawListSplitter_SetCurrentChannel(.{ splitter, 1 });
    const text_color = Theme.clrs.get(std.meta.stringToEnum(Theme.RColorsEnum, "genlist_bg").?).color;
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
