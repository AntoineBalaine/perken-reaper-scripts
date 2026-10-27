//! The panel's colors and styles, ported from the design lab's `theme.lua`.
//!
//! The look imitates a hardware organ: a dark metal face, engraved labels, recessed slots, and caps in
//! the colors of a tonewheel organ's drawbars. Colors are 0xRRGGBBAA. Because the lab is where the
//! look is designed, a change of color is made there first and copied here.
const imgui = @import("reaper_imgui");
const palette = @import("ui_palette");

const rgba = palette.rgba;
const ColorPair = palette.ColorPair;

// The face of the instrument and the surfaces cut into it.
pub const window_bg = rgba(0x1E1E20FF);
pub const panel_bg = rgba(0x2A2A2DFF);
pub const panel_edge_light = rgba(0x4A4A4EFF);
pub const panel_edge_dark = rgba(0x101011FF);
pub const slot_bg = rgba(0x0E0E0FFF);
pub const slot_edge = rgba(0x050505FF);
/// The faint grid on the screens that draw a curve.
pub const screen_grid = rgba(0x1E1E21FF);

pub const text = rgba(0xD6D2C6FF);
pub const text_dim = rgba(0x8C8A82FF);
/// The labels under the knobs, which must be readable at a glance.
pub const label = rgba(0xBCB9AEFF);
/// The names of the tabs, in the orange of the VR-09's panel lettering (R246 G170 B80).
pub const tab_text = rgba(0xF6AA50FF);
pub const text_engraved_shadow = rgba(0x0A0A0BFF);
pub const border = rgba(0x3A3A3EFF);
/// The outline of the checkboxes, the combos and the other framed widgets, light enough to be seen on
/// the dark frame.
pub const frame_border = rgba(0x76767CFF);
pub const title_bg = rgba(0x2A2A2DFF);
pub const title_bg_active = rgba(0x36363AFF);
pub const frame_bg = rgba(0x151517FF);
pub const frame_bg_hover = rgba(0x202023FF);

pub const green = rgba(0x4FD68AFF);
pub const red = rgba(0xE05050FF);
pub const amber = rgba(0xF0B840FF);
pub const grey = rgba(0x8C8A82FF);

/// The amber at a given opacity, for the hovered and the pressed states of the controls.
pub const amber_faint = rgba(0xF0B84040);
pub const amber_soft = rgba(0xF0B84055);
pub const amber_bright = rgba(0xFFD060FF);

/// The caps of the drawbars: white, brown and black, as on a tonewheel organ.
pub const cap_white = rgba(0xEAE6D8FF);
pub const cap_brown = rgba(0x7B4B2CFF);
pub const cap_black = rgba(0x1C1C1EFF);
pub const stem = rgba(0xB8B4A8FF);

/// The surface of the cards: a gradient from a lit top to a shaded bottom, a fine brushed grain, a
/// bevel on the edges, and screws in the corners.
pub const card_light = rgba(0xFFFFFF0E);
pub const card_shade = rgba(0x00000028);
pub const card_grain = rgba(0xFFFFFF06);
pub const card_bevel_light = rgba(0xFFFFFF1C);
pub const card_bevel_dark = rgba(0x00000070);
pub const screw_body = rgba(0x5C5C62FF);
pub const screw_light = rgba(0x9A9AA2FF);
pub const screw_slot = rgba(0x1A1A1CFF);

/// The accent of each effect's card. It takes the place of the amber on the lit parts of the controls
/// inside the card.
pub const fx = struct {
    pub const reverb = rgba(0x4FB0E8FF);
    pub const chorus = rgba(0x4FD6A8FF);
    pub const mfx = rgba(0xB67CF0FF);
    pub const delay = rgba(0xF07A5AFF);
    pub const compressor = rgba(0xE86AA8FF);
};

/// The accent of each part of the instrument, in the cards of the Synth, Mixer and Controllers tabs.
pub const part = struct {
    pub const upper = rgba(0x5AC8F0FF);
    pub const lower = rgba(0xF08C5AFF);
    pub const backing = rgba(0xF0B840FF);
    pub const master = rgba(0xC8C4B8FF);
    /// The organ keeps the amber that the lit parts of the controls have by default.
    pub const organ = rgba(0xF0B840FF);
    /// The ivory of a piano's keys.
    pub const piano = rgba(0xF2EBD3FF);
};

/// The knobs and switches: a body of dark metal with a slightly lighter top and a thin edge.
pub const knob_body = rgba(0x232326FF);
pub const knob_top = rgba(0x3A3A3FFF);
pub const knob_edge = rgba(0x56565BFF);

/// Because a black cap disappears into the dark slot and panel, each cap has a discreet contour of a
/// lighter tone of its own color, which is only strong enough to show the black cap's lower edge.
pub const cap_white_edge = rgba(0x8A877CFF);
pub const cap_brown_edge = rgba(0x9C6A44FF);
pub const cap_black_edge = rgba(0x6A6862FF);

/// The colors that the window pushes for each frame.
pub const window_colors = [_]ColorPair{
    .{ .col = &imgui.Col_WindowBg, .val = window_bg },
    .{ .col = &imgui.Col_ChildBg, .val = rgba(0x00000000) },
    .{ .col = &imgui.Col_Text, .val = text },
    .{ .col = &imgui.Col_Border, .val = frame_border },
    .{ .col = &imgui.Col_TitleBg, .val = title_bg },
    .{ .col = &imgui.Col_TitleBgActive, .val = title_bg_active },
    .{ .col = &imgui.Col_FrameBg, .val = frame_bg },
    .{ .col = &imgui.Col_FrameBgHovered, .val = amber_faint },
    .{ .col = &imgui.Col_FrameBgActive, .val = amber },
    .{ .col = &imgui.Col_SliderGrab, .val = amber },
    .{ .col = &imgui.Col_SliderGrabActive, .val = amber_bright },
    .{ .col = &imgui.Col_CheckMark, .val = amber },
    .{ .col = &imgui.Col_Button, .val = rgba(0x3A3A3EFF) },
    .{ .col = &imgui.Col_ButtonHovered, .val = amber_soft },
    .{ .col = &imgui.Col_ButtonActive, .val = amber },
    .{ .col = &imgui.Col_Header, .val = rgba(0x3A3A3EFF) },
    .{ .col = &imgui.Col_HeaderHovered, .val = amber_faint },
    .{ .col = &imgui.Col_HeaderActive, .val = amber },
    .{ .col = &imgui.Col_Separator, .val = border },
    .{ .col = &imgui.Col_Tab, .val = panel_bg },
    .{ .col = &imgui.Col_TabHovered, .val = rgba(0x4A4A4EFF) },
    .{ .col = &imgui.Col_TabSelected, .val = rgba(0x3E3E42FF) },
    .{ .col = &imgui.Col_PlotHistogram, .val = amber },
};

/// How many style variables `push` pushes, and `pop` takes off.
pub const var_count: c_int = 9;

/// Pushes a style variable that has one value.
pub fn pushVar(ctx: imgui.ContextPtr, style_var: c_int, value: f64) void {
    imgui.api.PushStyleVar(ctx, style_var, value, null);
}

/// Pushes a style variable that has two values, such as a padding.
pub fn pushVar2(ctx: imgui.ContextPtr, style_var: c_int, x: f64, y: f64) void {
    var second = y;
    imgui.api.PushStyleVar(ctx, style_var, x, &second);
}

/// Pushes the colors and the styles for one frame. `pop` takes them off.
pub fn push(ctx: imgui.ContextPtr) void {
    palette.push(ctx, &window_colors);
    pushVar(ctx, imgui.StyleVar_WindowRounding, 0);
    pushVar(ctx, imgui.StyleVar_FrameRounding, 3);
    pushVar(ctx, imgui.StyleVar_FrameBorderSize, 1);
    pushVar(ctx, imgui.StyleVar_ChildRounding, 6);
    pushVar(ctx, imgui.StyleVar_TabRounding, 3);
    pushVar(ctx, imgui.StyleVar_GrabRounding, 3);
    pushVar2(ctx, imgui.StyleVar_WindowPadding, 12, 12);
    pushVar2(ctx, imgui.StyleVar_ItemSpacing, 8, 8);
    pushVar2(ctx, imgui.StyleVar_FramePadding, 8, 4);
}

/// Takes off what `push` pushed.
pub fn pop(ctx: imgui.ContextPtr) void {
    var vars = var_count;
    imgui.api.PopStyleVar(ctx, &vars);
    palette.pop(ctx, window_colors.len);
}
