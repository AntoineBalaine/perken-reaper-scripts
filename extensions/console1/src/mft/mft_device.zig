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
const mft_state = @import("mft_state.zig");
const MftActiveModule = mft_state.MftActiveModule;
const page_count = mft_state.page_count;
const pageForEncoder = mft_state.pageForEncoder;
const mft_fxsel = @import("mft_fxsel.zig");
const knob_count = @import("mft_mappings.zig").knob_count;
const push_count = @import("mft_mappings.zig").push_count;

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

/// The distance from one row to the next.
pub const row_height: f64 = 136;

/// The distance from the top of a row to the center of its encoder, less the radius of the ring.
pub const row_top: f64 = 14;

/// The room for the formatted value of a parameter, with its terminator.
pub const formatted_len = 31;

/// The eight top encoders of the active module, as the panel reads them each frame.
pub const KnobInfo = struct {
    vals: [knob_count]f64 = @splat(0.0),
    mapped: [knob_count]bool = @splat(false),
    name_bufs: [knob_count][64:0]u8 = undefined,
    has_name: [knob_count]bool = @splat(false),
    /// Where each mapped parameter lives, so that the panel can ask the plugin for its formatted value.
    fx_index: [knob_count]c_int = @splat(0),
    param: [knob_count]c_int = @splat(0),
    /// The value as the plugin formats it ("-12.0 dB"), for the encoders that show one. An encoder without one shows
    /// the percentage.
    formatted_bufs: [knob_count][formatted_len:0]u8 = undefined,
    has_formatted: [knob_count]bool = @splat(false),
    /// The pushes that have an action, and the word for it, which is the name of the parameter or of what the click changes.
    push_mapped: [push_count]bool = @splat(false),
    /// The knobs that run a REAPER action, which is the case on the AUTO page: they have a name and no value, so their ring shows nothing.
    is_action: [knob_count]bool = @splat(false),
    push_name_bufs: [push_count][32:0]u8 = undefined,

    pub fn formatted(self: *const KnobInfo, slot: usize) [:0]const u8 {
        return std.mem.sliceTo(&self.formatted_bufs[slot], 0);
    }

    pub fn pushName(self: *const KnobInfo, push: usize) [:0]const u8 {
        return std.mem.sliceTo(&self.push_name_bufs[push], 0);
    }

    pub fn name(self: *const KnobInfo, slot: usize) [:0]const u8 {
        return std.mem.sliceTo(&self.name_bufs[slot], 0);
    }
};

/// Everything the device shows in one frame. The panel fills it from the controller, and the device draws it.
pub const View = struct {
    active: MftActiveModule,
    /// The color of each module, in the order of `MftActiveModule`.
    colors: [page_count]c_int,
    knobs: KnobInfo = .{},
    /// The encoders that are held down, one bit each, as `MftState.held_encoders` has them.
    held: u16 = 0,
    /// The encoders whose value is shown in a pop-up, one bit each: the ones that the mouse is over, that are held or
    /// have just been turned, and those that were a moment ago.
    /// On the SETTINGS page: where the highlight of the rows is, the value of the highlighted row (both from 0 to 1), and its name.
    settings: ?SettingsView = null,
    /// While the FX SEL mode is open, what the window of each encoder says, and the color of the mode. Null otherwise.
    fxsel_labels: ?[16]mft_fxsel.Label = null,
    fxsel_color: c_int = 0,
    show_value: u16 = 0,
    /// The pop-up of the last click on a push: the encoder and the text, or null once it has lingered.
    push_note: ?struct { encoder: u8, text: [32:0]u8 } = null,
    /// Whether mute, solo and phase are on for the track, in the order of the keys on the right.
    side_lit: [3]bool = @splat(false),
    /// The transport encoders whose turn and whose press are lit, one bit each: the controller was used lately.
    turn_lit: u8 = 0,
    press_lit: u8 = 0,
    /// The keys on the left that are held or were a moment ago.
    left_lit: [3]bool = @splat(false),
    /// Whether the controller is connected, which the lamp of the header shows.
    online: bool = false,
    collapsed: bool = false,

    pub fn color(self: *const View, module: MftActiveModule) c_int {
        return self.colors[@backingInt(module)];
    }
};

/// What the encoders of the SETTINGS page show.
pub const SettingsView = struct { cursor: f64 = 0, value: f64 = 0, row_label: [:0]const u8 = "-" };

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
    /// How big the encoder is drawn, 1 being the size of the device. The mapping panel draws the encoders of its plates smaller.
    scale: f64 = 1.0,
};

/// Draws one encoder around (cx, cy): a ring of eleven white LEDs around a round rubber cap that sits in a well. The
/// LEDs light up to the value, and only a value lights them.
pub fn drawEncoder(dl: Dl, cx: f64, cy: f64, e: Encoder) void {
    const k = e.scale;
    // The ring: the LEDs are white, and lit up to the value.
    for (0..led_count) |i| {
        const t = @as(f64, @floatFromInt(i)) / (led_count - 1);
        const a = sweep_from + (sweep_to - sweep_from) * t;
        const x = cx + @cos(a) * led_ring_r * k;
        const y = cy + @sin(a) * led_ring_r * k;
        const lit = if (e.value) |value| t <= value + 0.001 else false;
        if (lit) {
            widgets.circleFilled(dl, x, y, (led_r + 2.5) * k, widgets.faded(white, 0x1C));
            widgets.circleFilled(dl, x, y, led_r * k, white);
        } else {
            widgets.circleFilled(dl, x, y, (led_r - 0.4) * k, rgba(0x060607FF));
            widgets.circle(dl, x, y, (led_r - 0.4) * k, rgba(0xFFFFFF14), 1);
        }
    }

    // The well the cap sits in.
    widgets.circleFilled(dl, cx, cy, well_r * k, rgba(0x070708FF));
    widgets.circle(dl, cx, cy, well_r * k, rgba(0x000000FF), 2);
    widgets.circle(dl, cx, cy + k, well_r * k + 1, rgba(0xFFFFFF18), 1);

    // The cap has the layers of the knobs of the shared panel kit, which give it its volume. From the back to the
    // front: a shadow, the body, a lighter dome shifted toward the upper left, a veil of the mode's color, the edge,
    // three fine grooves, a lit arc on the upper left of the edge, and a shine. It stands out of the well and sinks a
    // little when it is pressed, and its edge takes the color of the mode while it is pressed.
    const sink: f64 = if (e.pressed) 1.5 * k else 0;
    const r = cap_r * k - sink * 0.5;
    const y = cy + sink;
    widgets.circleFilled(dl, cx + k, cy + 3 * k - sink, r + k, rgba(0x00000099));
    widgets.circleFilled(dl, cx, y, r, theme.knob_body);
    widgets.circleFilled(dl, cx - k, y - k, r - 4 * k, theme.knob_top);
    widgets.circleFilled(dl, cx - 1.5 * k, y - 2 * k, r - 9 * k, rgba(0xFFFFFF0C));
    widgets.circleFilled(dl, cx, y, r - 4 * k, widgets.faded(e.color, if (e.pressed) 0x3A else 0x14));
    widgets.circle(dl, cx, y, r, if (e.pressed) e.color else theme.knob_edge, 1);
    widgets.circle(dl, cx, y, r - 3 * k, rgba(0xFFFFFF14), 1);
    widgets.circle(dl, cx, y, r - 6 * k, rgba(0x00000040), 1);
    widgets.circle(dl, cx, y, r - 9 * k, rgba(0xFFFFFF0C), 1);
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
        widgets.circleFilled(dl, cx + c * r * 0.86, y + s * r * 0.86, 2.2 * k, e.color);
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

/// The key on the left that depends on the page: it hides the panel on the transport page, bypasses the plugin of the page on the pages
/// that have one, and does nothing on the others.
pub fn middleLeftKey(page: MftActiveModule) SideKey {
    return switch (page) {
        .TRANSPORT => left_keys[1],
        .INPUT, .GATE, .EQ, .COMP, .OUTPUT => .{ .name = "BYPASS", .icon = .bypass, .color = theme.amber, .toggle = true },
        .SETTINGS, .AUTO => .{ .name = "-", .icon = .bypass, .color = theme.text_dim },
    };
}

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
    const row_h = row_height;
    const top = row_top;
    for (0..3) |row| {
        const cy = gy + row_h * @as(f64, @floatFromInt(row)) + ring_r + top;
        const y = cy - side_h / 2;
        drawSideKey(kit, dl, x0, y, if (row == 1) middleLeftKey(view.active) else left_keys[row], view.left_lit[row]);
        drawSideKey(kit, dl, x1, y, right_keys[row], view.side_lit[row]);
    }
}

// ---- the cells ----

/// The window of the color LED under an encoder: dark glass that the LED lights in `color`, as much as `strength` (0
/// for an LED that is off).
pub fn drawLedWindow(dl: Dl, cx: f64, y: f64, color: c_int, strength: f64) void {
    drawLedWindowRect(dl, cx - label_w / 2, y, cx + label_w / 2, label_h, color, strength);
}

/// The same window with the size that the caller chooses: from `x1` to `x2` across, and `height` down from `y`. The mapping panel draws it smaller.
pub fn drawLedWindowRect(dl: Dl, x1: f64, y: f64, x2: f64, height: f64, color: c_int, strength: f64) void {
    widgets.rectFilled(dl, x1, y, x2, y + height, rgba(0x08080AFF), 5);
    if (strength > 0) {
        const top = fadedBy(color, 0x14, strength);
        const bottom = fadedBy(color, 0x58, strength);
        imgui.api.DrawList_AddRectFilledMultiColor(dl, x1 + 1, y + 1, x2 - 1, y + height - 1, top, top, bottom, bottom);
        widgets.rectFilled(dl, x1 + 8, y + height - 3, x2 - 8, y + height - 1, fadedBy(color, 0xCC, strength), 1);
    }
    widgets.rect(dl, x1, y, x2, y + height, rgba(0x000000DD), 5, 1);
    widgets.line(dl, x1 + 5, y + height + 1, x2 - 5, y + height + 1, rgba(0xFFFFFF1E), 1);
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
        const full = upperZ(&upper, name);
        var fit_buf: [96:0]u8 = undefined;
        const shown = fitText(kit, full, label_w - 10, &fit_buf);
        tipWhenCut(kit, shown, full, cx - label_w / 2, y, cx + label_w / 2, y + label_h / 2);
        printedText(kit, dl, cx, y + 3 - text_up, shown, if (strength > 0) theme.text else theme.text_dim);
        widgets.line(dl, cx - label_w / 2 + 6, y + label_h / 2, cx + label_w / 2 - 6, y + label_h / 2, rgba(0xFFFFFF22), 1);
    }
    if (second) |value| printedText(kit, dl, cx, y + 18 - text_up, value, if (strength > 0) color else theme.text_dim);
}

/// The sign of a press: a ring with a dot in it, which reads as a button.
pub fn pressGlyph(dl: Dl, x: f64, y: f64, color: c_int) void {
    widgets.circle(dl, x, y, 4.4, color, 1.4);
    widgets.circleFilled(dl, x, y, 1.8, color);
}

/// The sign of a turn: an arc with an arrowhead at its end.
pub fn turnGlyph(dl: Dl, x: f64, y: f64, color: c_int) void {
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
/// A text cut to a width, with "..." at its end, written into `buf`; the text as it is when it fits. Because a name is cut letter by letter, a letter of several
/// bytes is never cut in two.
pub fn fitText(kit: *widgets.Panel, text: [:0]const u8, max_w: f64, buf: *[96:0]u8) [:0]const u8 {
    if (widgets.textSize(kit, text).w <= max_w) return text;
    var n: usize = @min(text.len, buf.len - 4);
    while (n > 0) : (n -= 1) {
        // A byte that continues a letter is not a place to cut.
        if (n < text.len and text[n] & 0xC0 == 0x80) continue;
        @memcpy(buf[0..n], text[0..n]);
        @memcpy(buf[n .. n + 3], "...");
        buf[n + 3] = 0;
        if (widgets.textSize(kit, buf[0 .. n + 3 :0]).w <= max_w) return buf[0 .. n + 3 :0];
    }
    return "...";
}

/// Shows the whole of a text that was cut, in a tooltip, while the mouse is over the place where it is written.
fn tipWhenCut(kit: *widgets.Panel, shown: [:0]const u8, full: [:0]const u8, x1: f64, y1: f64, x2: f64, y2: f64) void {
    if (shown.ptr == full.ptr) return;
    const ctx = kit.ctx;
    if (imgui.api.IsWindowHovered(ctx, null) and imgui.api.IsMouseHoveringRect(ctx, x1, y1, x2, y2, null)) widgets.tooltip(kit, full);
}

fn drawZoneLine(kit: *widgets.Panel, dl: Dl, cx: f64, top: f64, bottom: f64, glyph: Glyph, full_text: [:0]const u8, color: c_int, lit: bool, text_color: c_int) void {
    // A word that is longer than the window is cut with "...", and the whole of it shows in a tooltip.
    var fit_buf: [96:0]u8 = undefined;
    const text = fitText(kit, full_text, label_w - 8 - glyph_w - glyph_gap, &fit_buf);
    tipWhenCut(kit, text, full_text, cx - label_w / 2, top, cx + label_w / 2, bottom);
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
    items: [knob_count]Bubble = undefined,
    len: usize = 0,

    pub fn add(self: *Bubbles, bubble: Bubble) void {
        std.debug.assert(self.len < self.items.len);
        self.items[self.len] = bubble;
        self.len += 1;
    }
};

/// The geometry of one cell of the grid.
const Cell = struct { cx: f64, cy: f64, label_y: f64 };

pub fn cellAt(idx: usize, gx: f64, gy: f64) Cell {
    const col: f64 = @floatFromInt(idx % 4);
    const row: f64 = @floatFromInt(idx / 4);
    const cy = gy + row_height * row + ring_r + row_top;
    return .{ .cx = gx + pitch * (col + 0.5), .cy = cy, .label_y = cy + ring_r + 6 };
}

/// Whether the pop-up of a click on a push is shown on the encoder `idx`, which takes the place of the value of its knob.
fn noteIsFor(view: *const View, idx: usize) bool {
    const note = view.push_note orelse return false;
    return note.encoder == idx;
}

fn isHeld(view: *const View, idx: usize) bool {
    return (view.held >> @intCast(idx)) & 1 == 1;
}

/// Which of the sixteen knobs the mouse is over, one bit each. Because the pop-up of a value must also stay for a
/// moment after the mouse leaves, the panel asks this before the device is drawn, and keeps the time. `origin` is where
/// the device will be drawn, which is the cursor now. Only the window under the mouse counts, so that a window above
/// this one hides the knobs under it.
pub fn hoveredKnobs(kit: *widgets.Panel, origin: widgets.Point, view: *const View) u16 {
    if (view.collapsed) return 0;
    const ctx = kit.ctx;
    if (!imgui.api.IsWindowHovered(ctx, null)) return 0;
    const gx = origin.x + pad + side_w + side_gap;
    const gy = origin.y + pad + header_h;
    const reach = ring_r + 6;
    var bits: u16 = 0;
    for (0..knob_count) |idx| {
        const cell = cellAt(idx, gx, gy);
        if (imgui.api.IsMouseHoveringRect(ctx, cell.cx - reach, cell.cy - reach, cell.cx + reach, cell.cy + reach, null)) {
            bits |= @as(u16, 1) << @intCast(idx);
        }
    }
    return bits;
}

/// The texts that a mapped knob shows: its name, its value as the plugin writes it (or the percentage), and the value from 0 to 1.
const KnobText = struct {
    name: [:0]const u8,
    value_text: [:0]const u8,
    value: f64,
};

/// Reads the texts of the knob `idx` of a view. The buffers belong to the caller, because the texts that are made here point into them.
fn knobText(info: *const KnobInfo, idx: usize, name_buf: *[16:0]u8, value_buf: *[16:0]u8) KnobText {
    const value = std.math.clamp(info.vals[idx], 0.0, 1.0);
    const name: [:0]const u8 = if (info.has_name[idx]) info.name(idx) else std.mem.printSentinel(name_buf, "K{d}", .{idx + 1}, 0) catch "K";
    // The plugin's own text is shown when the panel has it, and the percentage otherwise.
    const percent: i32 = @intFromFloat(@round(value * 100.0));
    const percent_text = std.mem.printSentinel(value_buf, "{d}%", .{percent}, 0) catch "?";
    return .{ .name = name, .value_text = if (info.has_formatted[idx]) info.formatted(idx) else percent_text, .value = value };
}

/// Shows the value of a knob in a pop-up over it, which lasts while `show` is true.
fn showValue(cell: Cell, text: [:0]const u8, color: c_int, show: bool, bubbles: *Bubbles) void {
    if (!show) return;
    var bubble = Bubble{ .cx = cell.cx, .top = cell.cy - led_ring_r - bubble_gap, .text = undefined, .color = color };
    std.debug.assert(text.len <= formatted_len);
    @memcpy(bubble.text[0 .. text.len + 1], text[0 .. text.len + 1]);
    bubbles.add(bubble);
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
            // The first encoder scrolls the rows, and its ring says where the highlight is; the second adjusts the highlighted row, whose name is on
            // its window, and its push flips a switch; the pushes 7 and 8 save and cancel. The others do nothing.
            const settings = view.settings orelse SettingsView{};
            const value: ?f64 = switch (idx) {
                0 => settings.cursor,
                1 => settings.value,
                else => null,
            };
            drawEncoder(dl, cell.cx, cell.cy, .{ .value = value, .color = mode_color, .pressed = held });
            const turn: ?[:0]const u8 = switch (idx) {
                0 => "Row",
                1 => settings.row_label,
                else => null,
            };
            const press: [:0]const u8 = switch (idx) {
                1 => "Flip",
                6 => "Save",
                7 => "Cancel",
                else => "-",
            };
            if (turn == null and std.mem.eql(u8, press, "-")) {
                drawLedLabel(kit, dl, cell.cx, cell.label_y, null, null, mode_color, 0);
            } else {
                drawDualLabel(kit, dl, cell.cx, cell.label_y, turn, press, mode_color, 1, false, held, theme.text_dim);
            }
        },
        else => {
            const info = &view.knobs;
            const mapped = info.mapped[idx];
            const value = std.math.clamp(info.vals[idx], 0.0, 1.0);
            drawEncoder(dl, cell.cx, cell.cy, .{ .value = if (mapped and !info.is_action[idx]) value else null, .color = mode_color, .pressed = held });
            const push_mapped = idx < push_count and info.push_mapped[idx];
            if (view.push_note) |note| if (note.encoder == idx) {
                var bubble = Bubble{ .cx = cell.cx, .top = cell.cy - led_ring_r - bubble_gap, .text = undefined, .color = mode_color };
                @memcpy(&bubble.text, note.text[0..formatted_len :0]);
                bubbles.add(bubble);
            };
            if (!mapped and !push_mapped) {
                drawLedLabel(kit, dl, cell.cx, cell.label_y, null, null, mode_color, 0);
                return;
            }
            if (!mapped) {
                // A push that has an action while its knob has none: the window has the press line alone.
                drawDualLabel(kit, dl, cell.cx, cell.label_y, null, info.pushName(idx), mode_color, 1, false, held, theme.text_dim);
                return;
            }
            var name_buf: [16:0]u8 = undefined;
            var value_buf: [16:0]u8 = undefined;
            const text = knobText(info, idx, &name_buf, &value_buf);
            // The value is shown over the ring or in a bubble while the knob is held or has just been turned, and in the label otherwise.
            // Holding a knob that has a push does not show its value, because the click that follows shows what the push changed.
            const show = (view.show_value >> @intCast(idx)) & 1 == 1 or (held and !push_mapped);
            showValue(cell, text.value_text, mode_color, show and !noteIsFor(view, idx), bubbles);
            if (push_mapped) {
                // The window says what the turn does on the top line and what a click does under it. The value of the knob is in its ring and
                // its pop-up, since the window has no line left for it.
                drawDualLabel(kit, dl, cell.cx, cell.label_y, text.name, info.pushName(idx), mode_color, 1, false, held, theme.text_dim);
            } else {
                drawLedLabel(kit, dl, cell.cx, cell.label_y, text.name, null, mode_color, 1);
            }
        },
    }
}

/// The page that a bottom-row encoder selects, or null for a cell of the top rows.
pub fn moduleForCell(idx: usize) ?MftActiveModule {
    return pageForEncoder(idx);
}

/// One of the bottom eight encoders. A click selects its page, so its window says the name of the page on the press line, in the color of
/// the page and brighter for the page in use. A turn belongs to the page in use like the turn of the top rows, so the ring shows the
/// parameter that the page maps to it, and the turn line has its name.
fn drawModuleCell(kit: *widgets.Panel, dl: Dl, view: *const View, idx: usize, cell: Cell, bubbles: *Bubbles) void {
    const module = moduleForCell(idx) orelse unreachable;
    const color = view.color(module);
    const active = module == view.active;
    const held = isHeld(view, idx);
    const info = &view.knobs;
    const mapped = info.mapped[idx];
    const value = std.math.clamp(info.vals[idx], 0.0, 1.0);
    drawEncoder(dl, cell.cx, cell.cy, .{ .value = if (mapped) value else null, .color = color, .pressed = held or active });
    // A turn of the transport page can leave a note on its knob, as the Order knob does with the order that the track is in now.
    const has_note = noteIsFor(view, idx);
    if (has_note) {
        var bubble = Bubble{ .cx = cell.cx, .top = cell.cy - led_ring_r - bubble_gap, .text = undefined, .color = view.color(view.active) };
        @memcpy(&bubble.text, view.push_note.?.text[0..formatted_len :0]);
        bubbles.add(bubble);
    }
    var name_buf: [16:0]u8 = undefined;
    var value_buf: [16:0]u8 = undefined;
    // On the transport page the turns of the bottom row have their own functions, which have no ring.
    var turn: ?[:0]const u8 = if (view.active == .TRANSPORT) mft_transport.bottomLabel(idx - 8) else null;
    if (mapped) {
        const text = knobText(info, idx, &name_buf, &value_buf);
        turn = text.name;
        showValue(cell, text.value_text, view.color(view.active), (view.show_value >> @intCast(idx)) & 1 == 1 and !has_note, bubbles);
    }
    // The word under a page button says what a click does, so it is written as a press: with the sign of a press, and lit while the button
    // is held. The page in use is in the color of the page.
    drawDualLabel(kit, dl, cell.cx, cell.label_y, turn, @tagName(module), color, if (active) 1 else 0.4, false, held, if (active) color else theme.text_dim);
}

/// One encoder while the FX SEL mode is open: it has no value, and its window says what a turn and a press do in the mode. The encoder that is
/// chosen (the module, or the entry that the list is on) is sunk, and its window is lit.
fn drawFxSelCell(kit: *widgets.Panel, dl: Dl, view: *const View, idx: usize, cell: Cell, label: mft_fxsel.Label) void {
    // The buttons that choose a module keep the color of their module.
    const color = if (mft_fxsel.moduleForEncoder(idx) != null) view.color(moduleForCell(idx).?) else view.fxsel_color;
    const held = isHeld(view, idx) or (idx < 8 and (view.press_lit >> @intCast(idx)) & 1 == 1);
    drawEncoder(dl, cell.cx, cell.cy, .{ .color = color, .pressed = held or label.chosen });
    const has_function = label.turn != null or !std.mem.eql(u8, label.press, "-");
    drawDualLabel(kit, dl, cell.cx, cell.label_y, label.turn, label.press, color, if (has_function) 1 else 0.4, false, held, if (label.chosen) color else theme.text_dim);
}

/// Draws the sixteen encoders. The LED color of the module in use is the accent of its knobs.
fn drawCells(kit: *widgets.Panel, dl: Dl, view: *const View, gx: f64, gy: f64) void {
    var bubbles = Bubbles{};
    for (0..16) |idx| {
        const cell = cellAt(idx, gx, gy);
        if (view.fxsel_labels) |labels| {
            drawFxSelCell(kit, dl, view, idx, cell, labels[idx]);
        } else if (idx < 8) {
            drawKnobCell(kit, dl, view, idx, cell, &bubbles);
        } else {
            drawModuleCell(kit, dl, view, idx, cell, &bubbles);
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
    inline for (@typeInfo(MftActiveModule).@"enum".field_names) |field_name| {
        widest = @max(widest, widgets.textSize(kit, field_name).w);
    }
    // The name of the FX Selection mode has to fit in the card too.
    const fxsel_name = "FX SELECTION";
    widest = @max(widest, widgets.textSize(kit, fxsel_name).w);
    widgets.popFont(kit, pushed);
    imgui.api.SetCursorScreenPos(ctx, x + pad, y + pad);
    if (view.fxsel_labels != null) {
        widgets.display(kit, fxsel_name, view.fxsel_color, widest + 20);
    } else {
        widgets.display(kit, @tagName(view.active), view.color(view.active), widest + 20);
    }

    const cx = x + body_w / 2;
    const font = kit.fonts.tab;
    if (font != null) imgui.api.PushFont(ctx, font);
    const size = widgets.textSize(kit, title);
    printedText(kit, dl, cx, y + pad + (header_row_h - size.h) / 2, title, theme.text_dim);
    if (font != null) imgui.api.PopFont(ctx);
    const lamp = imgui.api.GetTextLineHeight(ctx);
    imgui.api.SetCursorScreenPos(ctx, cx - size.w / 2 - 8 - lamp, y + pad + (header_row_h - lamp) / 2);
    widgets.lamp(kit, if (view.online) theme.green else theme.amber, true);
    widgets.tooltip(kit, if (view.online) "online, mirroring the controller" else "offline, the controller is not connected");
}

// ---- the whole device ----

/// Draws the device at the cursor: the body, the header, the buttons of the corner and, unless it is folded, the
/// keys and the encoders. A folded device is its header row alone. Returns what the buttons of the corner asked for,
/// and where the device ends.
pub fn draw(kit: *widgets.Panel, view: *const View) Response {
    const ctx = kit.ctx;
    const origin = widgets.cursorScreenPos(kit);
    const row_h = row_height;
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

fn testView(module: MftActiveModule) View {
    var colors: [page_count]c_int = undefined;
    for (&colors, 0..) |*each, i| each.* = rgba(0x4FD68AFF) + @as(c_int, @intCast(i)) * 0x100;
    var view = View{ .active = module, .colors = colors };
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

test "the device leaves the stacks balanced in every module, open and folded" {
    const MockImGui = @import("mock_imgui").MockImGui;
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var kit = widgets.Panel{};
    for ([_]MftActiveModule{ .INPUT, .TRANSPORT, .SETTINGS, .AUTO, .OUTPUT }) |module| {
        var view = testView(module);
        _ = draw(&kit, &view);
        view.collapsed = true;
        const response = draw(&kit, &view);
        try std.testing.expect(response.bottom >= response.left);
    }
    try mock.assertBalanced();
}

test "a folded device is shorter than an open one" {
    const MockImGui = @import("mock_imgui").MockImGui;
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var kit = widgets.Panel{};
    var view = testView(.INPUT);
    const open = draw(&kit, &view);
    view.collapsed = true;
    const folded = draw(&kit, &view);
    try std.testing.expect(folded.bottom < open.bottom);
}

test "every bottom cell selects a page, and the cells of the top rows select none" {
    try std.testing.expectEqual(@as(?MftActiveModule, .INPUT), moduleForCell(8));
    try std.testing.expectEqual(@as(?MftActiveModule, .TRANSPORT), moduleForCell(13));
    try std.testing.expectEqual(@as(?MftActiveModule, .AUTO), moduleForCell(14));
    try std.testing.expectEqual(@as(?MftActiveModule, .OUTPUT), moduleForCell(15));
    try std.testing.expectEqual(@as(?MftActiveModule, null), moduleForCell(0));
}

test "a long name is cut to its width with an ellipsis, and a name that fits is kept as it is" {
    const MockImGui = @import("mock_imgui").MockImGui;
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();
    var kit = widgets.Panel{};
    var buf: [96:0]u8 = undefined;
    const short: [:0]const u8 = "Gain";
    try std.testing.expect(fitText(&kit, short, 1000, &buf).ptr == short.ptr);
    // The mock gives every text the same width, so a width smaller than it leaves only the ellipsis.
    const long: [:0]const u8 = "Automation: Set track automation mode to trim/read";
    try std.testing.expectEqualStrings("...", fitText(&kit, long, 10, &buf));
}
