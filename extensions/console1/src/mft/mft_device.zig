//! The MIDI Fighter Twister drawn as an object: a dark metal body with a
//! recessed faceplate, sixteen encoders in four rows of four, each with a ring of eleven LEDs around a metal cap, and
//! three keys on each side. The top eight encoders show the parameters of the mode, or the transport functions, and
//! the bottom eight select the mode.
//!
//! Because the panel mirrors the controller, nothing here answers the mouse except the two buttons of the corner,
//! which belong to the window and not to the controller. Because the controller is the one that turns the encoders, presses
//! the keys and picks the modes, the panel shows that state through `View` and does not answer the mouse for them.
const std = @import("std");
const imgui = @import("reaper_imgui");
const theme = @import("panel_theme");
const widgets = @import("panel_widgets");
const palette = @import("ui_palette");
const icons = @import("mft_icons.zig");
const mft_transport = @import("mft_transport.zig");
const MftActiveModule = @import("mft_state.zig").MftActiveModule;

const rgba = palette.rgba;
const Dl = imgui.DrawListPtr;
const pi = std.math.pi;

// ---- the sizes of the device, in pixels ----

/// The distance from one encoder to the next, across.
const pitch: f64 = 118;
/// The ring of LEDs, the well that the cap sits in, and the cap. `ring_r` is the room that the ring takes in the
/// layout, and stays a little larger than the circle that the LEDs sit on.
const ring_r: f64 = 36;
const well_r: f64 = 30;
const cap_r: f64 = 23;
pub const side_w: f64 = 76;
const side_h: f64 = 34;
pub const side_gap: f64 = 14;
/// `header_row_h` is the height of the card of the mode, which sets the height of the row; `header_h` is the room from
/// the top of the device to the first row of encoders.
pub const pad: f64 = 22;
pub const header_h: f64 = 46;
const footer_h: f64 = 8;
const header_row_h: f64 = 26;
const led_count = 11;
/// The ring starts at the lower left and ends at the lower right.
const sweep_from: f64 = pi * 0.75;
const sweep_to: f64 = pi * 2.25;

/// The white of the LEDs is soft, and not as bright as the lettering.
const white = rgba(0xBFBFBFFF);
/// The radius of a white LED of the ring, and the radius of the circle that the LEDs sit on: just outside the well of
/// the cap.
const led_r: f64 = 2.4;
const led_ring_r: f64 = 34;

const label_w: f64 = 94;
const label_h: f64 = 36;
/// How many pixels the lettering of the encoders is lifted from where it would be centered, in the window under a
/// knob and above it.
const text_up: f64 = 2;
const glyph_w: f64 = 10;
const glyph_gap: f64 = 5;
/// How many pixels the bottom of a pop-up is above the circle that the LEDs sit on. A negative number puts it over the
/// LEDs: -8 puts it over the top of the ring and of the well, and stops it 3 pixels above the cap.
const bubble_gap: f64 = -8;
const corner: f64 = 24;
const title = "MIDI FIGHTER TWISTER";

/// Where the value of a knob is shown.
pub const ValueMode = enum {
    /// Under the name of the parameter, in the window under the knob.
    label,
    /// Above the knob, which needs a line of room over the ring.
    above,
    /// In a pop-up over the knob, while the knob is held or has just been turned.
    popup,
};

/// The distance from one row to the next. Because a value printed over a knob needs a line of room above the ring,
/// the rows are closer when it is, and the room above the ring is larger.
pub fn rowHeight(mode: ValueMode) f64 {
    return if (mode == .above) 128 else 136;
}

/// The distance from the top of a row to the center of its encoder, less the radius of the ring.
pub fn rowTop(mode: ValueMode) f64 {
    return if (mode == .above) 30 else 14;
}

/// The room for the formatted value of a parameter, with its terminator.
pub const formatted_len = 31;

/// The eight top encoders of the active module, as the panel reads them each frame.
pub const KnobInfo = struct {
    vals: [8]f64 = [_]f64{0.0} ** 8,
    mapped: [8]bool = [_]bool{false} ** 8,
    name_bufs: [8][64:0]u8 = undefined,
    has_name: [8]bool = [_]bool{false} ** 8,
    /// Where each mapped parameter lives, so that the panel can ask the plugin for its formatted value.
    fx_index: [8]c_int = [_]c_int{0} ** 8,
    param: [8]c_int = [_]c_int{0} ** 8,
    /// The value as the plugin formats it ("-12.0 dB"), for the encoders that show one. An encoder without one shows
    /// the percentage.
    formatted_bufs: [8][formatted_len:0]u8 = undefined,
    has_formatted: [8]bool = [_]bool{false} ** 8,

    pub fn formatted(self: *const KnobInfo, slot: usize) [:0]const u8 {
        return std.mem.sliceTo(&self.formatted_bufs[slot], 0);
    }

    pub fn name(self: *const KnobInfo, slot: usize) [:0]const u8 {
        return std.mem.sliceTo(&self.name_bufs[slot], 0);
    }
};

/// Everything the device shows in one frame. The panel fills it from the controller, and the device draws it.
pub const View = struct {
    active: MftActiveModule,
    /// The color of each module, in the order of `MftActiveModule`.
    colors: [6]c_int,
    knobs: KnobInfo = .{},
    /// The encoders that are held down, one bit each, as `MftState.held_encoders` has them.
    held: u16 = 0,
    /// The top encoders whose value is shown in a pop-up, one bit each: the ones that the mouse is over, that are held or
    /// have just been turned, and those that were a moment ago.
    show_value: u8 = 0,
    /// Whether mute, solo and phase are on for the track, in the order of the keys on the right.
    side_lit: [3]bool = [_]bool{false} ** 3,
    /// The transport encoders whose turn and whose press are lit, one bit each: the controller was used lately.
    turn_lit: u8 = 0,
    press_lit: u8 = 0,
    /// The keys on the left that are held or were a moment ago.
    left_lit: [3]bool = [_]bool{false} ** 3,
    collapsed: bool = false,
    value_mode: ValueMode = .popup,

    pub fn color(self: *const View, module: MftActiveModule) c_int {
        return self.colors[@intFromEnum(module)];
    }
};

/// What the player did with the buttons of the corner during the frame, and where the device ended, so that the panel
/// can draw what follows it.
pub const Response = struct {
    close: bool = false,
    fold: bool = false,
    /// The left edge of the device, and the bottom edge of its body.
    left: f64 = 0,
    bottom: f64 = 0,
};

// ---- text ----

/// Writes the uppercase copy of a text into the buffer, cut to the room that the buffer has.
fn upperZ(buf: []u8, source: []const u8) [:0]const u8 {
    const n = @min(source.len, buf.len - 1);
    _ = std.ascii.upperString(buf[0..n], source[0..n]);
    buf[n] = 0;
    return buf[0..n :0];
}

/// Text centered on `cx`, with a dark copy one pixel below it, like lettering printed on the panel.
fn printedText(kit: *widgets.Panel, dl: Dl, cx: f64, y: f64, text: [:0]const u8, color: c_int) void {
    const w = widgets.textSize(kit, text).w;
    imgui.api.DrawList_AddText(dl, cx - w / 2, y + 1, rgba(0x00000099), text);
    imgui.api.DrawList_AddText(dl, cx - w / 2, y, color, text);
}

/// The color at a fraction of the strength that a base opacity has, for an LED that is dimmer than another.
fn fadedBy(color: c_int, base: u32, strength: f64) c_int {
    return widgets.faded(color, @intFromFloat(@floor(@as(f64, @floatFromInt(base)) * strength)));
}

// ---- the body ----

const screw_angles = [4]f64{ 0.4, 1.2, 2.1, 2.9 };

fn drawScrew(dl: Dl, x: f64, y: f64, angle: f64) void {
    widgets.circleFilled(dl, x + 1, y + 1, 4, rgba(0x000000AA));
    widgets.circleFilled(dl, x, y, 4, theme.screw_body);
    widgets.circle(dl, x, y, 4, theme.card_bevel_dark, 1);
    widgets.circleFilled(dl, x - 1.2, y - 1.2, 1, theme.screw_light);
    const dx = @cos(angle) * 2.8;
    const dy = @sin(angle) * 2.8;
    widgets.line(dl, x - dx, y - dy, x + dx, y + dy, theme.screw_slot, 1.5);
}

/// The case: anodized metal with a lit upper edge, a faint brushed grain, a bevel all around and a screw in each
/// corner.
pub fn drawBody(dl: Dl, x: f64, y: f64, w: f64, h: f64) void {
    widgets.rectFilled(dl, x + 3, y + 7, x + w + 3, y + h + 7, rgba(0x00000088), 18);
    widgets.rectFilled(dl, x, y, x + w, y + h, rgba(0x1A1A1CFF), 16);
    imgui.api.DrawList_AddRectFilledMultiColor(dl, x + 10, y + 3, x + w - 10, y + h * 0.55, rgba(0xFFFFFF16), rgba(0xFFFFFF16), rgba(0xFFFFFF00), rgba(0xFFFFFF00));
    var ly = y + 8;
    while (ly <= y + h - 8) : (ly += 3) widgets.line(dl, x + 10, ly, x + w - 10, ly, rgba(0xFFFFFF05), 1);
    widgets.rect(dl, x, y, x + w, y + h, rgba(0x040405FF), 16, 2);
    widgets.rect(dl, x + 2, y + 2, x + w - 2, y + h - 2, rgba(0xFFFFFF1E), 15, 1);
    drawScrew(dl, x + 13, y + 13, screw_angles[0]);
    drawScrew(dl, x + w - 13, y + 13, screw_angles[1]);
    drawScrew(dl, x + 13, y + h - 13, screw_angles[2]);
    drawScrew(dl, x + w - 13, y + h - 13, screw_angles[3]);
}

/// The faceplate of the encoders, cut into the case: a dark shade along its upper edge and a lit one along its lower.
pub fn drawFaceplate(dl: Dl, x: f64, y: f64, w: f64, h: f64) void {
    widgets.rectFilled(dl, x, y, x + w, y + h, rgba(0x0E0E10FF), 10);
    widgets.rect(dl, x, y, x + w, y + h, rgba(0x000000DD), 10, 2);
    widgets.line(dl, x + 10, y + h + 1.5, x + w - 10, y + h + 1.5, rgba(0xFFFFFF26), 1);
}

// ---- an encoder ----

/// What an encoder shows.
pub const Encoder = struct {
    /// 0 to 1, where the ring ends and the pointer points; null for a ring that shows nothing.
    value: ?f64 = null,
    /// The color of the mode's LED, which is the accent of the cap's details.
    color: c_int,
    /// The cap is held down.
    pressed: bool = false,
    /// An icon to draw on the cap instead of the pointer.
    icon: ?icons.Icon = null,
};

/// Draws one encoder around (cx, cy): a ring of eleven white LEDs around a round rubber cap that sits in a well. The
/// LEDs light up to the value, and only a value lights them.
pub fn drawEncoder(dl: Dl, cx: f64, cy: f64, e: Encoder) void {
    // The ring: the LEDs are white, and lit up to the value.
    for (0..led_count) |i| {
        const t = @as(f64, @floatFromInt(i)) / (led_count - 1);
        const a = sweep_from + (sweep_to - sweep_from) * t;
        const x = cx + @cos(a) * led_ring_r;
        const y = cy + @sin(a) * led_ring_r;
        const lit = if (e.value) |value| t <= value + 0.001 else false;
        if (lit) {
            widgets.circleFilled(dl, x, y, led_r + 2.5, widgets.faded(white, 0x1C));
            widgets.circleFilled(dl, x, y, led_r, white);
        } else {
            widgets.circleFilled(dl, x, y, led_r - 0.4, rgba(0x060607FF));
            widgets.circle(dl, x, y, led_r - 0.4, rgba(0xFFFFFF14), 1);
        }
    }

    // The well the cap sits in.
    widgets.circleFilled(dl, cx, cy, well_r, rgba(0x070708FF));
    widgets.circle(dl, cx, cy, well_r, rgba(0x000000FF), 2);
    widgets.circle(dl, cx, cy + 1, well_r + 1, rgba(0xFFFFFF18), 1);

    // The cap has the layers of the knobs of the shared panel kit, which give it its volume. From the back to the
    // front: a shadow, the body, a lighter dome shifted toward the upper left, a veil of the mode's color, the edge,
    // three fine grooves, a lit arc on the upper left of the edge, and a shine. It stands out of the well and sinks a
    // little when it is pressed, and its edge takes the color of the mode while it is pressed.
    const sink: f64 = if (e.pressed) 1.5 else 0;
    const r = cap_r - sink * 0.5;
    const y = cy + sink;
    widgets.circleFilled(dl, cx + 1, cy + 3 - sink, r + 1, rgba(0x00000099));
    widgets.circleFilled(dl, cx, y, r, theme.knob_body);
    widgets.circleFilled(dl, cx - 1, y - 1, r - 4, theme.knob_top);
    widgets.circleFilled(dl, cx - 1.5, y - 2, r - 9, rgba(0xFFFFFF0C));
    widgets.circleFilled(dl, cx, y, r - 4, widgets.faded(e.color, if (e.pressed) 0x3A else 0x14));
    widgets.circle(dl, cx, y, r, if (e.pressed) e.color else theme.knob_edge, 1);
    widgets.circle(dl, cx, y, r - 3, rgba(0xFFFFFF14), 1);
    widgets.circle(dl, cx, y, r - 6, rgba(0x00000040), 1);
    widgets.circle(dl, cx, y, r - 9, rgba(0xFFFFFF0C), 1);
    widgets.arc(dl, cx, y, r - 0.5, pi, pi * 1.5, rgba(0xFFFFFF40), 1.5);
    widgets.circleFilled(dl, cx - r * 0.35, y - r * 0.4, r * 0.22, rgba(0xFFFFFF1E));

    if (e.icon) |icon| {
        // The icon is the off-white of the labels, and stands out of the rubber; its shadow is the color of the mode.
        icons.draw(dl, icon, cx, y, r * 0.62, theme.text, theme.text, true, e.color);
    } else if (e.value) |value| {
        // The pointer is a white line from near the center toward the ring, with the LED's color on its tip.
        const a = sweep_from + (sweep_to - sweep_from) * value;
        const c = @cos(a);
        const s = @sin(a);
        widgets.line(dl, cx + c * r * 0.3, y + s * r * 0.3, cx + c * r * 0.86, y + s * r * 0.86, white, 2);
        widgets.circleFilled(dl, cx + c * r * 0.86, y + s * r * 0.86, 2.2, e.color);
    }
}

// ---- a side key ----

/// The icon and the color scheme of a side key. A key that stays on (mute, solo, phase) is a toggle: when it is off
/// its icon and lettering are a dimmed tone of its color, and when it is on the key is washed with the color, its
/// outline and lettering are bright, and a glow comes out of it. The red, the yellow, the blue and the green are those
/// of mute, solo, phase and the plugin selector; the chain and the hide keys are neutral.
pub const SideKey = struct {
    /// The function of the key, in capitals. The number of the key (L1, R2) is not printed, because the position of
    /// the key already says it.
    name: [:0]const u8,
    icon: icons.Icon,
    color: c_int,
    toggle: bool = false,
};

pub const left_keys = [3]SideKey{
    .{ .name = "CHAIN", .icon = .chain, .color = rgba(0xE6E6E6FF) },
    .{ .name = "HIDE", .icon = .hide, .color = rgba(0xE6E6E6FF) },
    .{ .name = "FXSEL", .icon = .fxsel, .color = theme.green },
};

pub const right_keys = [3]SideKey{
    .{ .name = "MUTE", .icon = .mute, .color = theme.red, .toggle = true },
    .{ .name = "SOLO", .icon = .solo, .color = theme.amber, .toggle = true },
    .{ .name = "PHASE", .icon = .phase, .color = rgba(0x4FA0E8FF), .toggle = true },
};

/// A rubber key with an icon and its label. It is lit while the track has its function on, or the key is held.
pub fn drawSideKey(kit: *widgets.Panel, dl: Dl, x: f64, y: f64, key: SideKey, on: bool) void {
    const color = key.color;
    widgets.rectFilled(dl, x, y + 2, x + side_w, y + side_h + 2, rgba(0x000000AA), 6);
    widgets.rectFilled(dl, x, y, x + side_w, y + side_h, theme.knob_top, 6);
    imgui.api.DrawList_AddRectFilledMultiColor(dl, x + 2, y + 2, x + side_w - 2, y + side_h / 2, rgba(0xFFFFFF18), rgba(0xFFFFFF18), rgba(0xFFFFFF00), rgba(0xFFFFFF00));
    if (on) {
        widgets.rectFilled(dl, x - 2, y - 2, x + side_w + 2, y + side_h + 2, widgets.faded(color, 0x22), 8);
        widgets.rectFilled(dl, x, y, x + side_w, y + side_h, widgets.faded(color, 0x4A), 6);
    } else if (key.toggle) {
        // A key that can stay on shows its color faintly even when it is off, so that the keys can be told apart.
        widgets.rectFilled(dl, x, y, x + side_w, y + side_h, widgets.faded(color, 0x12), 6);
    }
    widgets.rect(dl, x, y, x + side_w, y + side_h, if (on) color else theme.knob_edge, 6, 1);
    widgets.line(dl, x + 6, y + 1.5, x + side_w - 6, y + 1.5, rgba(0xFFFFFF30), 1);

    // The icon on the left, and the function of the key on the right. Because the words differ in width, the icon and
    // the word are centered together in the key, and the word is centered in the height of the key by the size of its
    // text.
    const tone = if (on) color else widgets.faded(color, 0x99);
    const pushed = widgets.pushLabelFont(kit);
    const size = widgets.textSize(kit, key.name);
    const icon_w: f64 = 14;
    const gap: f64 = 7;
    const left = x + (side_w - (icon_w + gap + size.w)) / 2;
    icons.draw(dl, key.icon, left + icon_w / 2, y + side_h / 2, 7, tone, tone, false, null);
    printedText(kit, dl, left + icon_w + gap + size.w / 2, y + (side_h - size.h) / 2, key.name, if (on) color else theme.label);
    widgets.popFont(kit, pushed);
}

/// Draws the six side keys. The mute, solo and phase keys are lit while the track has them on.
fn drawSideKeys(kit: *widgets.Panel, dl: Dl, view: *const View, x0: f64, x1: f64, gy: f64) void {
    const row_h = rowHeight(view.value_mode);
    const top = rowTop(view.value_mode);
    for (0..3) |row| {
        const cy = gy + row_h * @as(f64, @floatFromInt(row)) + ring_r + top;
        const y = cy - side_h / 2;
        drawSideKey(kit, dl, x0, y, left_keys[row], view.left_lit[row]);
        drawSideKey(kit, dl, x1, y, right_keys[row], view.side_lit[row]);
    }
}

// ---- the cells ----

/// The window of the color LED under an encoder: dark glass that the LED lights in `color`, as much as `strength` (0
/// for an LED that is off).
pub fn drawLedWindow(dl: Dl, cx: f64, y: f64, color: c_int, strength: f64) void {
    const x1 = cx - label_w / 2;
    const x2 = cx + label_w / 2;
    widgets.rectFilled(dl, x1, y, x2, y + label_h, rgba(0x08080AFF), 5);
    if (strength > 0) {
        const top = fadedBy(color, 0x14, strength);
        const bottom = fadedBy(color, 0x58, strength);
        imgui.api.DrawList_AddRectFilledMultiColor(dl, x1 + 1, y + 1, x2 - 1, y + label_h - 1, top, top, bottom, bottom);
        widgets.rectFilled(dl, x1 + 8, y + label_h - 3, x2 - 8, y + label_h - 1, fadedBy(color, 0xCC, strength), 1);
    }
    widgets.rect(dl, x1, y, x2, y + label_h, rgba(0x000000DD), 5, 1);
    widgets.line(dl, x1 + 5, y + label_h + 1, x2 - 5, y + label_h + 1, rgba(0xFFFFFF1E), 1);
}

/// The lettering under an encoder, where the controller's color LED is. The LED lights a small window in the color of
/// the mode, `strength` being how bright it is (0 for an LED that is off), and the lettering is printed over it: the
/// name of the parameter, and under it its value.
pub fn drawLedLabel(kit: *widgets.Panel, dl: Dl, cx: f64, y: f64, first: ?[:0]const u8, second: ?[:0]const u8, color: c_int, strength: f64) void {
    drawLedWindow(dl, cx, y, color, strength);
    const pushed = widgets.pushLabelFont(kit);
    defer widgets.popFont(kit, pushed);
    if (first) |name| {
        // The name is always on the top line, with a thin line under it. When the knob has no second line, the bottom
        // half is left empty: it is the place of the press, and of the mapping.
        var upper: [96]u8 = undefined;
        printedText(kit, dl, cx, y + 3 - text_up, upperZ(&upper, name), if (strength > 0) theme.text else theme.text_dim);
        widgets.line(dl, cx - label_w / 2 + 6, y + label_h / 2, cx + label_w / 2 - 6, y + label_h / 2, rgba(0xFFFFFF22), 1);
    }
    if (second) |value| printedText(kit, dl, cx, y + 18 - text_up, value, if (strength > 0) color else theme.text_dim);
}

/// The sign of a press: a ring with a dot in it, which reads as a button.
fn pressGlyph(dl: Dl, x: f64, y: f64, color: c_int) void {
    widgets.circle(dl, x, y, 4.4, color, 1.4);
    widgets.circleFilled(dl, x, y, 1.8, color);
}

/// The sign of a turn: an arc with an arrowhead at its end.
fn turnGlyph(dl: Dl, x: f64, y: f64, color: c_int) void {
    const from = pi * 0.15;
    const to = pi * 1.65;
    const radius: f64 = 4.4;
    widgets.arc(dl, x, y, radius, from, to, color, 1.4);
    // The arrowhead sits on the end of the arc and points along it, clockwise on the screen.
    const ex = x + @cos(to) * radius;
    const ey = y + @sin(to) * radius;
    const tx = -@sin(to);
    const ty = @cos(to);
    const nx = @cos(to);
    const ny = @sin(to);
    imgui.api.DrawList_AddTriangleFilled(dl, ex + tx * 3.6, ey + ty * 3.6, ex + nx * 2.8 - tx * 0.4, ey + ny * 2.8 - ty * 0.4, ex - nx * 2.8 - tx * 0.4, ey - ny * 2.8 - ty * 0.4, color);
}

const Glyph = *const fn (Dl, f64, f64, c_int) void;

/// One line of the two-zone window: a glyph, then the word, centered together on `cx`. A line that is `lit` is washed
/// with the color of the mode, and its word is bright.
fn drawZoneLine(kit: *widgets.Panel, dl: Dl, cx: f64, top: f64, bottom: f64, glyph: Glyph, text: [:0]const u8, color: c_int, lit: bool, text_color: c_int) void {
    const text_w = widgets.textSize(kit, text).w;
    if (lit) widgets.rectFilled(dl, cx - label_w / 2 + 3, top, cx + label_w / 2 - 3, bottom, widgets.faded(color, 0x55), 3);
    const left = cx - (glyph_w + glyph_gap + text_w) / 2;
    glyph(dl, left + glyph_w / 2, (top + bottom) / 2, if (lit) color else widgets.faded(color, 0xB0));
    printedText(kit, dl, left + glyph_w + glyph_gap + text_w / 2, (top + bottom) / 2 - 8 - text_up, text, if (lit) theme.text else text_color);
}

/// The window under a knob that does two things: what a turn does on the top line, with the sign of a turn, and what a
/// press does under it, with the sign of a press, the two separated by a thin line. The press line is lit while the
/// encoder is held. A knob that only has a press (a mode button) has the press line alone, still in the bottom half,
/// and the top half empty; `strength` is how bright the LED is.
pub fn drawDualLabel(kit: *widgets.Panel, dl: Dl, cx: f64, y: f64, turn_text: ?[:0]const u8, press_text: [:0]const u8, color: c_int, strength: f64, turn_lit: bool, press_lit: bool, press_color: c_int) void {
    drawLedWindow(dl, cx, y, color, strength);
    const pushed = widgets.pushLabelFont(kit);
    defer widgets.popFont(kit, pushed);
    const x1 = cx - label_w / 2;
    const x2 = cx + label_w / 2;
    // The top half is the place of what a turn does, which is also where the mapping of the knob is shown; it stays
    // empty for a knob that is only pressed. The press is always in the bottom half, under the line.
    if (turn_text) |turn| {
        var upper: [64]u8 = undefined;
        drawZoneLine(kit, dl, cx, y + 2, y + label_h / 2, turnGlyph, upperZ(&upper, turn), color, turn_lit, theme.text);
    }
    widgets.line(dl, x1 + 6, y + label_h / 2, x2 - 6, y + label_h / 2, rgba(0xFFFFFF22), 1);
    drawZoneLine(kit, dl, cx, y + label_h / 2, y + label_h - 2, pressGlyph, press_text, color, press_lit, press_color);
}

/// The pop-up of a value: a small dark rounded box, outlined and lettered in the color of the mode. `top` is where its
/// bottom edge is.
const Bubble = struct { cx: f64, top: f64, text: [formatted_len:0]u8, color: c_int };

fn drawBubble(kit: *widgets.Panel, dl: Dl, bubble: *const Bubble) void {
    const pushed = widgets.pushLabelFont(kit);
    defer widgets.popFont(kit, pushed);
    const text = std.mem.sliceTo(&bubble.text, 0);
    const size = widgets.textSize(kit, text);
    const w = size.w + 22;
    const h = size.h + 10;
    const x1 = bubble.cx - w / 2;
    const y2 = bubble.top;
    const y1 = y2 - h;
    widgets.rectFilled(dl, x1 + 1, y1 + 3, x1 + w + 1, y2 + 3, rgba(0x00000099), 6);
    widgets.rectFilled(dl, x1, y1, x1 + w, y2, rgba(0x0B0B0DF2), 6);
    widgets.rectFilled(dl, x1, y1, x1 + w, y2, widgets.faded(bubble.color, 0x22), 6);
    widgets.rect(dl, x1, y1, x1 + w, y2, bubble.color, 6, 1.2);
    imgui.api.DrawList_AddText(dl, bubble.cx - size.w / 2, y1 + 5, bubble.color, text);
}

/// Where the cells of one frame put the pop-ups, which are drawn last so that no cell covers them.
const Bubbles = struct {
    items: [8]Bubble = undefined,
    len: usize = 0,

    pub fn add(self: *Bubbles, bubble: Bubble) void {
        std.debug.assert(self.len < self.items.len);
        self.items[self.len] = bubble;
        self.len += 1;
    }
};

/// The geometry of one cell of the grid.
const Cell = struct { cx: f64, cy: f64, label_y: f64 };

pub fn cellAt(idx: usize, gx: f64, gy: f64, mode: ValueMode) Cell {
    const col: f64 = @floatFromInt(idx % 4);
    const row: f64 = @floatFromInt(idx / 4);
    const cy = gy + rowHeight(mode) * row + ring_r + rowTop(mode);
    return .{ .cx = gx + pitch * (col + 0.5), .cy = cy, .label_y = cy + ring_r + 6 };
}

fn isHeld(view: *const View, idx: usize) bool {
    return (view.held >> @intCast(idx)) & 1 == 1;
}

/// Which of the top eight knobs the mouse is over, one bit each. Because the pop-up of a value must also stay for a
/// moment after the mouse leaves, the panel asks this before the device is drawn, and keeps the time. `origin` is where
/// the device will be drawn, which is the cursor now. Only the window under the mouse counts, so that a window above
/// this one hides the knobs under it.
pub fn hoveredKnobs(kit: *widgets.Panel, origin: widgets.Point, view: *const View) u8 {
    if (view.collapsed) return 0;
    const ctx = kit.ctx;
    if (!imgui.api.IsWindowHovered(ctx, null)) return 0;
    const gx = origin.x + pad + side_w + side_gap;
    const gy = origin.y + pad + header_h;
    const reach = ring_r + 6;
    var bits: u8 = 0;
    for (0..8) |idx| {
        const cell = cellAt(idx, gx, gy, view.value_mode);
        if (imgui.api.IsMouseHoveringRect(ctx, cell.cx - reach, cell.cy - reach, cell.cx + reach, cell.cy + reach, null)) {
            bits |= @as(u8, 1) << @intCast(idx);
        }
    }
    return bits;
}

/// One of the top eight encoders, which show the transport functions in transport mode, the mapped parameters in the
/// modules that map some, and nothing in the settings mode.
fn drawKnobCell(kit: *widgets.Panel, dl: Dl, view: *const View, idx: usize, cell: Cell, bubbles: *Bubbles) void {
    const mode_color = view.color(view.active);
    const held = isHeld(view, idx);
    switch (view.active) {
        .TRANSPORT => {
            const bit = @as(u8, 1) << @intCast(idx);
            const pressed = held or view.press_lit & bit != 0;
            drawEncoder(dl, cell.cx, cell.cy, .{ .value = 0.5, .color = mode_color, .pressed = pressed, .icon = icons.transport[idx] });
            drawDualLabel(kit, dl, cell.cx, cell.label_y, mft_transport.rotationLabel(idx), mft_transport.pressLabel(idx), mode_color, 1, view.turn_lit & bit != 0, pressed, theme.text_dim);
        },
        .SETTINGS => {
            // The settings mode: the encoders move the form, so the ring shows nothing and the LED is off.
            drawEncoder(dl, cell.cx, cell.cy, .{ .color = mode_color, .pressed = held });
            drawLedLabel(kit, dl, cell.cx, cell.label_y, null, null, mode_color, 0);
        },
        else => {
            const info = &view.knobs;
            const mapped = info.mapped[idx];
            const value = std.math.clamp(info.vals[idx], 0.0, 1.0);
            drawEncoder(dl, cell.cx, cell.cy, .{ .value = if (mapped) value else null, .color = mode_color, .pressed = held });
            if (!mapped) {
                drawLedLabel(kit, dl, cell.cx, cell.label_y, null, null, mode_color, 0);
                return;
            }
            var name_buf: [16:0]u8 = undefined;
            const name: [:0]const u8 = if (info.has_name[idx]) info.name(idx) else std.fmt.bufPrintZ(&name_buf, "K{d}", .{idx + 1}) catch "K";
            // The plugin's own text is shown when the panel has it, and the percentage otherwise.
            var value_buf: [16:0]u8 = undefined;
            const percent: i32 = @intFromFloat(@round(value * 100.0));
            const percent_text = std.fmt.bufPrintZ(&value_buf, "{d}%", .{percent}) catch "?";
            const value_text: [:0]const u8 = if (info.has_formatted[idx]) info.formatted(idx) else percent_text;
            switch (view.value_mode) {
                .above => {
                    // The value is printed over the ring, in the color of the mode, and the window under the knob
                    // keeps the name.
                    const pushed = widgets.pushLabelFont(kit);
                    printedText(kit, dl, cell.cx, cell.cy - led_ring_r - 22 - text_up, value_text, mode_color);
                    widgets.popFont(kit, pushed);
                    drawLedLabel(kit, dl, cell.cx, cell.label_y, name, null, mode_color, 1);
                },
                .popup => {
                    // The value shows in a bubble over the knob while the knob is held or has just been turned.
                    if ((view.show_value >> @intCast(idx)) & 1 == 1 or held) {
                        var bubble = Bubble{ .cx = cell.cx, .top = cell.cy - led_ring_r - bubble_gap, .text = undefined, .color = mode_color };
                        std.debug.assert(value_text.len <= formatted_len);
                        @memcpy(bubble.text[0 .. value_text.len + 1], value_text[0 .. value_text.len + 1]);
                        bubbles.add(bubble);
                    }
                    drawLedLabel(kit, dl, cell.cx, cell.label_y, name, null, mode_color, 1);
                },
                .label => drawLedLabel(kit, dl, cell.cx, cell.label_y, name, value_text, mode_color, 1),
            }
        },
    }
}

/// The module that a bottom-row encoder selects, or null for the two reserved cells.
pub fn moduleForCell(idx: usize) ?MftActiveModule {
    return switch (idx) {
        8 => .IO,
        9 => .GATE,
        10 => .EQ,
        11 => .COMP,
        12 => .SETTINGS,
        13 => .TRANSPORT,
        else => null,
    };
}

/// One of the bottom eight encoders: the first six select a module, and light their LED in its color, brighter for the
/// module in use. The last two are reserved.
fn drawModuleCell(kit: *widgets.Panel, dl: Dl, view: *const View, idx: usize, cell: Cell) void {
    const module = moduleForCell(idx) orelse {
        drawEncoder(dl, cell.cx, cell.cy, .{ .color = theme.text_dim, .pressed = isHeld(view, idx) });
        drawLedLabel(kit, dl, cell.cx, cell.label_y, null, null, theme.text_dim, 0);
        return;
    };
    const color = view.color(module);
    const active = module == view.active;
    const held = isHeld(view, idx);
    // The ring stays dark: its LEDs are for showing a value. The module in use is shown by the sunk cap, the lit window
    // and the color of its word.
    drawEncoder(dl, cell.cx, cell.cy, .{ .color = color, .pressed = held or active });
    // The word under a module button says what a click does, so it is written as a press: with the sign of a press, and
    // lit while the button is held. The module in use is in the color of the module.
    drawDualLabel(kit, dl, cell.cx, cell.label_y, null, @tagName(module), color, if (active) 1 else 0.4, false, held, if (active) color else theme.text_dim);
}

/// Draws the sixteen encoders. The LED color of the module in use is the accent of its knobs.
fn drawCells(kit: *widgets.Panel, dl: Dl, view: *const View, gx: f64, gy: f64) void {
    var bubbles = Bubbles{};
    for (0..16) |idx| {
        const cell = cellAt(idx, gx, gy, view.value_mode);
        if (idx < 8) {
            drawKnobCell(kit, dl, view, idx, cell, &bubbles);
        } else {
            drawModuleCell(kit, dl, view, idx, cell);
        }
    }
    for (bubbles.items[0..bubbles.len]) |*bubble| drawBubble(kit, dl, bubble);
}

// ---- the buttons of the corner ----

const Glyphs = enum { close, chevron_up, chevron_down };

fn drawCornerGlyph(dl: Dl, glyph: Glyphs, cx: f64, cy: f64, color: c_int) void {
    switch (glyph) {
        .close => {
            widgets.line(dl, cx - 4, cy - 4, cx + 4, cy + 4, color, 1.9);
            widgets.line(dl, cx - 4, cy + 4, cx + 4, cy - 4, color, 1.9);
        },
        // A chevron points up when the device is open (a click folds it), and down when it is folded (a click opens
        // it).
        .chevron_up, .chevron_down => {
            const up = glyph == .chevron_up;
            const tip: f64 = if (up) -2.5 else 2.5;
            const side: f64 = if (up) 2.5 else -2.5;
            widgets.line(dl, cx - 5, cy + side, cx, cy + tip, color, 1.9);
            widgets.line(dl, cx, cy + tip, cx + 5, cy + side, color, 1.9);
        },
    }
}

/// A small raised key with a glyph on it, that takes the hover color under the mouse. Returns true when it was
/// clicked.
fn drawCornerButton(kit: *widgets.Panel, dl: Dl, id: [:0]const u8, x: f64, y: f64, glyph: Glyphs, hover_color: c_int) bool {
    const ctx = kit.ctx;
    imgui.api.SetCursorScreenPos(ctx, x, y);
    const clicked = imgui.api.InvisibleButton(ctx, id, corner, corner, null);
    const hovered = imgui.api.IsItemHovered(ctx, null);
    const held = imgui.api.IsItemActive(ctx);
    const sink: f64 = if (held) 1 else 0;
    if (!held) widgets.rectFilled(dl, x, y + 2, x + corner, y + corner + 2, rgba(0x000000AA), 5);
    widgets.rectFilled(dl, x, y + sink, x + corner, y + corner + sink, if (held) theme.knob_body else theme.knob_top, 5);
    imgui.api.DrawList_AddRectFilledMultiColor(dl, x + 2, y + sink + 2, x + corner - 2, y + sink + corner / 2, rgba(0xFFFFFF18), rgba(0xFFFFFF18), rgba(0xFFFFFF00), rgba(0xFFFFFF00));
    widgets.rect(dl, x, y + sink, x + corner, y + corner + sink, if (hovered) hover_color else theme.knob_edge, 5, 1);
    drawCornerGlyph(dl, glyph, x + corner / 2, y + corner / 2 + sink, if (hovered) hover_color else theme.label);
    return clicked;
}

// ---- the header ----

/// The header row. On the left, the card of the module in use, as wide as the longest name of a module (TRANSPORT), so
/// that it keeps its width when the module changes. In the middle, the name of the controller, centered on the device,
/// with the green lamp next to it; the lamp tells in a pop-up what the panel is. `x` and `y` are the top left of the
/// device.
fn drawHeader(kit: *widgets.Panel, dl: Dl, view: *const View, x: f64, y: f64, body_w: f64) void {
    const ctx = kit.ctx;
    const pushed = widgets.pushLabelFont(kit);
    var widest: f64 = 0;
    inline for (@typeInfo(MftActiveModule).@"enum".fields) |field| {
        widest = @max(widest, widgets.textSize(kit, field.name).w);
    }
    widgets.popFont(kit, pushed);
    imgui.api.SetCursorScreenPos(ctx, x + pad, y + pad);
    widgets.display(kit, @tagName(view.active), view.color(view.active), widest + 20);

    const cx = x + body_w / 2;
    const font = kit.fonts.tab;
    if (font != null) imgui.api.PushFont(ctx, font);
    const size = widgets.textSize(kit, title);
    printedText(kit, dl, cx, y + pad + (header_row_h - size.h) / 2, title, theme.text_dim);
    if (font != null) imgui.api.PopFont(ctx);
    const lamp = imgui.api.GetTextLineHeight(ctx);
    imgui.api.SetCursorScreenPos(ctx, cx - size.w / 2 - 8 - lamp, y + pad + (header_row_h - lamp) / 2);
    widgets.lamp(kit, theme.green, true);
    widgets.tooltip(kit, "online, mirroring the controller");
}

// ---- the whole device ----

/// Draws the device at the cursor: the body, the header, the buttons of the corner and, unless it is folded, the
/// keys and the encoders. A folded device is its header row alone. Returns what the buttons of the corner asked for,
/// and where the device ends.
pub fn draw(kit: *widgets.Panel, view: *const View) Response {
    const ctx = kit.ctx;
    const origin = widgets.cursorScreenPos(kit);
    const row_h = rowHeight(view.value_mode);
    const grid_w = 4 * pitch;
    const body_w = pad * 2 + (side_w + side_gap) * 2 + grid_w;
    const body_h = if (view.collapsed) pad * 2 + header_row_h else pad + header_h + 4 * row_h + footer_h + pad;
    imgui.api.Dummy(ctx, body_w, body_h);
    const dl = imgui.api.GetWindowDrawList(ctx);
    drawBody(dl, origin.x, origin.y, body_w, body_h);
    drawHeader(kit, dl, view, origin.x, origin.y, body_w);

    // The buttons of the top right corner: fold or open the device, and close the panel.
    var response = Response{ .left = origin.x, .bottom = origin.y + body_h };
    const close_x = origin.x + body_w - pad - corner;
    const corner_y = origin.y + pad + 1;
    response.close = drawCornerButton(kit, dl, "##cornerclose", close_x, corner_y, .close, theme.red);
    const chevron: Glyphs = if (view.collapsed) .chevron_down else .chevron_up;
    response.fold = drawCornerButton(kit, dl, "##cornerfold", close_x - 6 - corner, corner_y, chevron, theme.amber);

    // A folded device ends here, and nothing is under it.
    if (view.collapsed) return response;

    const gx = origin.x + pad + side_w + side_gap;
    const gy = origin.y + pad + header_h;
    drawFaceplate(dl, gx - 4, gy - 4, grid_w + 8, 4 * row_h + 2);
    drawSideKeys(kit, dl, view, origin.x + pad, origin.x + body_w - pad - side_w, gy);
    drawCells(kit, dl, view, gx, gy);
    return response;
}

fn testView(module: MftActiveModule, value_mode: ValueMode) View {
    var colors: [6]c_int = undefined;
    for (&colors, 0..) |*each, i| each.* = rgba(0x4FD68AFF) + @as(c_int, @intCast(i)) * 0x100;
    var view = View{ .active = module, .colors = colors, .value_mode = value_mode };
    // The first encoder has a parameter mapped, with a name, the second one without a name, and the others nothing.
    view.knobs.mapped[0] = true;
    view.knobs.vals[0] = 0.5;
    view.knobs.has_name[0] = true;
    @memcpy(view.knobs.name_bufs[0][0..5], "Gain\x00");
    view.knobs.has_formatted[0] = true;
    @memcpy(view.knobs.formatted_bufs[0][0..9], "-12.0 dB\x00");
    view.knobs.mapped[1] = true;
    view.knobs.vals[1] = 2.0;
    view.held = 0b101;
    view.show_value = 0b11;
    view.side_lit = .{ true, false, true };
    view.turn_lit = 0b110;
    view.press_lit = 0b011;
    view.left_lit = .{ false, true, false };
    return view;
}

test "the device leaves the stacks balanced in every module, in every way of showing a value, open and folded" {
    const MockImGui = @import("mock_imgui").MockImGui;
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var kit = widgets.Panel{};
    for ([_]MftActiveModule{ .IO, .TRANSPORT, .SETTINGS }) |module| {
        for ([_]ValueMode{ .label, .above, .popup }) |value_mode| {
            var view = testView(module, value_mode);
            _ = draw(&kit, &view);
            view.collapsed = true;
            const response = draw(&kit, &view);
            try std.testing.expect(response.bottom >= response.left);
        }
    }
    try mock.assertBalanced();
}

test "a folded device is shorter than an open one, and an open one with its values above is shorter than with them in the label" {
    const MockImGui = @import("mock_imgui").MockImGui;
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var kit = widgets.Panel{};
    var view = testView(.IO, .popup);
    const open = draw(&kit, &view);
    view.collapsed = true;
    const folded = draw(&kit, &view);
    try std.testing.expect(folded.bottom < open.bottom);
    view.collapsed = false;
    view.value_mode = .above;
    const above = draw(&kit, &view);
    try std.testing.expect(above.bottom < open.bottom);
}

test "only the six first bottom cells select a module" {
    try std.testing.expectEqual(@as(?MftActiveModule, .IO), moduleForCell(8));
    try std.testing.expectEqual(@as(?MftActiveModule, .TRANSPORT), moduleForCell(13));
    try std.testing.expectEqual(@as(?MftActiveModule, null), moduleForCell(14));
    try std.testing.expectEqual(@as(?MftActiveModule, null), moduleForCell(0));
}
