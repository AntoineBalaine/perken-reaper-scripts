//! The tone picker of the Tones and Drums sections: it chooses one tone of a list of the keyboard's tones. The
//! parts that it is drawn with, the screen, the buttons and the glass, are the shared widgets of reaziglib.
const std = @import("std");
const imgui = @import("reaper_imgui");
const theme = @import("panel_theme");
const widgets = @import("panel_widgets");
const tones = @import("tones.zig");

const tone_w: f64 = 190;
pub const tone_filter_cap = 64;

fn toneMatches(tone: *const tones.Tone, filter: []const u8) bool {
    if (filter.len == 0) return true;
    return std.ascii.indexOfIgnoreCase(tone.name, filter) != null or std.ascii.indexOfIgnoreCase(tone.group, filter) != null;
}

/// Chooses one tone of a list. It shows the chosen tone's name on a display, with a button on each side to
/// step to the previous and the next tone, and the tone's bytes under it. A click on the display opens a
/// list of every tone, grouped, with a field that filters it as the user types. `index` is the chosen
/// tone's position and `filter` the text of the search field. Returns the new position.
pub fn tonePicker(ctx: imgui.ContextPtr, id: [:0]const u8, list: []const tones.Tone, index: usize, filter: *[tone_filter_cap:0]u8) usize {
    const tone = &list[index];
    var result = index;
    imgui.api.PushID(ctx, id);
    defer imgui.api.PopID(ctx);

    if (widgets.pushButton(ctx, "<", 30) and index > 0) result = index - 1;
    imgui.api.SameLine(ctx, null, null);

    // The display: a recessed screen with the name in the accent color, and a caret that says it opens a list.
    const pushed = widgets.pushLabelFont(ctx);
    const text_line = imgui.api.GetTextLineHeight(ctx);
    const at = widgets.cursorScreenPos(ctx);
    const height = text_line + 12;
    _ = imgui.api.InvisibleButton(ctx, "##tone", tone_w, height, null);
    const hot = imgui.api.IsItemHovered(ctx, null);
    if (imgui.api.IsItemClicked(ctx, null)) imgui.api.OpenPopup(ctx, "##tonelist", null);
    const dl = imgui.api.GetWindowDrawList(ctx);
    widgets.rectFilled(dl, at.x, at.y, at.x + tone_w, at.y + height, theme.slot_bg, 3);
    widgets.rect(dl, at.x, at.y, at.x + tone_w, at.y + height, if (hot) widgets.accent() else theme.slot_edge, 3, 1);
    imgui.api.DrawList_AddText(dl, at.x + 10, at.y + 6, widgets.accent(), tone.name);
    const cx = at.x + tone_w - 12;
    const cy = at.y + height / 2;
    imgui.api.DrawList_AddTriangleFilled(dl, cx - 4, cy - 2, cx + 4, cy - 2, cx, cy + 3, if (hot) widgets.accent() else theme.text_dim);
    widgets.drawGlass(dl, at.x, at.y, at.x + tone_w, at.y + height);
    widgets.popFont(ctx, pushed);
    imgui.api.SameLine(ctx, null, null);
    if (widgets.pushButton(ctx, ">", 30) and index + 1 < list.len) result = index + 1;

    // The group and the three bytes that select the tone, in the label font like the other numbers.
    const line_font = widgets.pushLabelFont(ctx);
    var info: [96:0]u8 = undefined;
    const info_text = std.fmt.bufPrintZ(&info, "{s}   tone {d}   bank {d}.{d}", .{ tone.group, tone.number, tone.msb, tone.lsb }) catch "";
    imgui.api.TextColored(ctx, theme.label, info_text);
    widgets.popFont(ctx, line_font);

    // The list of every tone, under the display.
    var appearing: c_int = imgui.Cond_Appearing;
    imgui.api.SetNextWindowPos(ctx, at.x, at.y + height + 2, &appearing, null, null);
    if (imgui.api.BeginPopup(ctx, "##tonelist", null)) {
        if (imgui.api.IsWindowAppearing(ctx)) imgui.api.SetKeyboardFocusHere(ctx, null);
        imgui.api.SetNextItemWidth(ctx, 300);
        var input_flags: c_int = imgui.InputTextFlags_None;
        _ = imgui.api.InputTextWithHint(ctx, "##search", "search by name or group", filter, filter.len, &input_flags, null);
        var list_w: f64 = 300;
        var list_h: f64 = 320;
        if (imgui.api.BeginChild(ctx, "##tonescroll", &list_w, &list_h, null, null)) {
            const needle = std.mem.sliceTo(filter, 0);
            var group: []const u8 = "";
            for (list, 0..) |*t, i| {
                if (!toneMatches(t, needle)) continue;
                // A group's heading is drawn when its first tone that matches the search is.
                if (!std.mem.eql(u8, t.group, group)) {
                    group = t.group;
                    imgui.api.SeparatorText(ctx, t.group);
                }
                var item: [96:0]u8 = undefined;
                const label = std.fmt.bufPrintZ(&item, "{s}##tone{d}", .{ t.name, i }) catch "?";
                var selected = i == index;
                if (imgui.api.Selectable(ctx, label, &selected, null, null, null)) result = i;
            }
            imgui.api.EndChild(ctx);
        }
        imgui.api.EndPopup(ctx);
    }
    return result;
}

test "every declaration compiles" {
    std.testing.refAllDecls(@This());
}
