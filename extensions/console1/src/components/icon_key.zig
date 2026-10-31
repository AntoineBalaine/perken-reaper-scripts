//! A small raised key with a symbol of the icon font on it, as the keys at the right of the title of a plate in the mapping panel are,
//! which the settings use for their save and cancel keys, so that all of them have the same shape.
const imgui = @import("reaper_imgui");
const Knobs = @import("knob");
const panel_theme = @import("panel_theme");
const palette = @import("ui_palette");
const c1_theme = @import("../theme/c1_theme.zig");

/// A body of dark metal with a lit top edge and a shadow under it, which sinks when it is pressed. It glows orange while `lit`, as the
/// toggles of the panel do, and its edge lights in amber under the mouse. The symbol is in the color of the text, or in `glyph_color`
/// when it has one. It returns whether the key was pressed. A key that is not enabled is dark and does nothing.
pub fn draw(
    ctx: imgui.ContextPtr,
    id: [:0]const u8,
    x: f64,
    y: f64,
    w: f64,
    h: f64,
    icon: [:0]const u8,
    enabled: bool,
    lit: bool,
    tooltip: ?[:0]const u8,
    glyph_color: ?c_int,
) !bool {
    try imgui.SetCursorScreenPos(.{ ctx, x, y });
    if (!enabled) try imgui.BeginDisabled(.{ctx});
    const clicked = try imgui.InvisibleButton(.{ ctx, id, w, h });
    // Because a key that is off still says what it is for, the mouse over it is read even when it is disabled.
    const over = try imgui.IsItemHovered(.{ ctx, imgui.HoveredFlags_AllowWhenDisabled });
    const hovered = enabled and over;
    const pressed = enabled and try imgui.IsItemActive(.{ctx});
    if (!enabled) try imgui.EndDisabled(.{ctx});

    const dl = try imgui.GetWindowDrawList(.{ctx});
    const sink: f64 = if (pressed) 1 else 0;
    const top = y + sink;
    const bottom = y + h + sink;
    if (lit and enabled) try imgui.DrawList_AddRectFilled(.{ dl, x - 2, top - 2, x + w + 2, bottom + 2, palette.rgba(0xFF8A2430), 6 });
    if (!pressed) try imgui.DrawList_AddRectFilled(.{ dl, x + 0.5, y + 1.8, x + w + 0.5, y + h + 1.8, palette.rgba(0x000000AA), 4 });
    try imgui.DrawList_AddRectFilled(.{ dl, x, top, x + w, bottom, if (enabled) panel_theme.knob_edge else panel_theme.border, 4 });
    const body_top = if (!enabled) panel_theme.knob_body else if (pressed) panel_theme.knob_body else panel_theme.knob_top;
    const body_bottom = if (pressed) panel_theme.knob_top else panel_theme.knob_body;
    try imgui.DrawList_AddRectFilledMultiColor(.{ dl, x + 1, top + 1, x + w - 1, bottom - 1, body_top, body_top, body_bottom, body_bottom });
    if (enabled and !pressed) try imgui.DrawList_AddLine(.{ dl, x + 3, top + 1.5, x + w - 3, top + 1.5, panel_theme.card_bevel_light, 1 });
    if (lit and enabled or hovered) try imgui.DrawList_AddRect(.{ dl, x, top, x + w, bottom, if (lit and enabled) Knobs.led_orange else panel_theme.amber, 4, null, 1.2 });
    {
        try imgui.PushFont(.{ ctx, c1_theme.fonts.ICON_FONT_SMALL });
        defer imgui.PopFont(.{ctx}) catch {};
        var glyph_w: f64 = undefined;
        var glyph_h: f64 = undefined;
        try imgui.CalcTextSize(.{ ctx, icon, &glyph_w, &glyph_h });
        const own = glyph_color orelse panel_theme.text;
        const color = if (!enabled) panel_theme.text_dim else if (lit) Knobs.led_orange else if (hovered) panel_theme.amber_bright else own;
        const glyph_x = x + (w - glyph_w) / 2;
        const glyph_y = top + (h - glyph_h) / 2;
        // The symbol is engraved on the key: a dark copy of it a pixel lower.
        try imgui.DrawList_AddText(.{ dl, glyph_x, glyph_y + 1, panel_theme.text_engraved_shadow, icon });
        try imgui.DrawList_AddText(.{ dl, glyph_x, glyph_y, color, icon });
    }
    if (over) {
        if (tooltip) |text| try imgui.SetTooltip(.{ ctx, text });
    }
    return enabled and clicked;
}
