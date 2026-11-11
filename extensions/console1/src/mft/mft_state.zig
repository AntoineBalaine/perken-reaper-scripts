const std = @import("std");

/// The pages of the controller, in the order of the eight encoders of its bottom row: the encoder 9 is the first page, and the encoder 16
/// the last. Because the order is the order of the encoders, the page of an encoder is its position minus 8.
pub const MftActiveModule = enum { INPUT, GATE, EQ, COMP, SETTINGS, TRANSPORT, AUTO, OUTPUT };

/// How many pages the controller has, which is how many encoders its bottom row has.
pub const page_count = @typeInfo(MftActiveModule).@"enum".field_names.len;

/// The page that a bottom-row encoder (the position 8 to 15 of the grid) selects, or null for a position of the top rows.
pub fn pageForEncoder(position: usize) ?MftActiveModule {
    if (position < 8 or position >= 8 + page_count) return null;
    return @fromBackingInt(@intCast(position - 8));
}

test "pageForEncoder: the bottom row selects the pages in order, and the top rows select none" {
    const t = std.testing;
    try t.expectEqual(@as(?MftActiveModule, .INPUT), pageForEncoder(8));
    try t.expectEqual(@as(?MftActiveModule, .TRANSPORT), pageForEncoder(13));
    try t.expectEqual(@as(?MftActiveModule, .AUTO), pageForEncoder(14));
    try t.expectEqual(@as(?MftActiveModule, .OUTPUT), pageForEncoder(15));
    try t.expectEqual(@as(?MftActiveModule, null), pageForEncoder(7));
    try t.expectEqual(@as(?MftActiveModule, null), pageForEncoder(16));
}

// The full MFT color palette (hue values on channel 3), used by the LED test.
pub const LED_TEST_COLORS = [_]u8{ 0x02, 0x0F, 0x19, 0x2E, 0x3C, 0x40, 0x49, 0x56, 0x5A, 0x6B, 0x71 };

/// How long a control of the panel stays lit after the controller stopped using it, in milliseconds. Because the
/// controller gives no state for a turn, and a press can be shorter than a frame, the light lingers so that it can be
/// seen. The pop-up of a value uses the same duration.
pub const linger_ms: i64 = 500;

/// When each control of the controller was last used, which the panel lights. A time is written by the MIDI handler
/// when a message arrives, and read by the panel when it draws.
pub const InputActivity = struct {
    /// The time of a control that has never been used.
    pub const never: i64 = std.math.minInt(i64) / 2;

    /// The last turn of each of the eight top encoders.
    turned_at: [8]i64 = @splat(never),
    /// The last press or release of each of the eight top encoders, and which of them are down.
    pressed_at: [8]i64 = @splat(never),
    encoders_down: u8 = 0,
    /// The same for the six side keys, in the order of their CCs: L1 to L3, then R1 to R3.
    side_at: [6]i64 = @splat(never),
    sides_down: u8 = 0,

    pub fn markTurn(self: *InputActivity, encoder: usize, now_ms: i64) void {
        self.turned_at[encoder] = now_ms;
    }

    pub fn markPress(self: *InputActivity, encoder: usize, down: bool, now_ms: i64) void {
        const bit = @as(u8, 1) << @intCast(encoder);
        if (down) self.encoders_down |= bit else self.encoders_down &= ~bit;
        self.pressed_at[encoder] = now_ms;
    }

    pub fn markSide(self: *InputActivity, key: usize, down: bool, now_ms: i64) void {
        const bit = @as(u8, 1) << @intCast(key);
        if (down) self.sides_down |= bit else self.sides_down &= ~bit;
        self.side_at[key] = now_ms;
    }

    /// Whether a turn is lit: it was less than `linger_ms` ago.
    pub fn turnLit(self: *const InputActivity, encoder: usize, now_ms: i64) bool {
        return now_ms - self.turned_at[encoder] < linger_ms;
    }

    /// Whether a press is lit: the encoder is down, or was pressed or released less than `linger_ms` ago.
    pub fn pressLit(self: *const InputActivity, encoder: usize, now_ms: i64) bool {
        return (self.encoders_down >> @intCast(encoder)) & 1 == 1 or now_ms - self.pressed_at[encoder] < linger_ms;
    }

    pub fn sideLit(self: *const InputActivity, key: usize, now_ms: i64) bool {
        return (self.sides_down >> @intCast(key)) & 1 == 1 or now_ms - self.side_at[key] < linger_ms;
    }
};

/// What the last click on a push changed, which the panel shows in a pop-up on the encoder for a moment: the new shape of an EQ band, or the new
/// value of a parameter as the plugin writes it.
pub const PushNote = struct {
    encoder: u8 = 0,
    text: [32:0]u8 = @splat(0),
    at_ms: i64 = std.math.minInt(i64) / 2,

    pub fn set(self: *PushNote, encoder: u8, text: []const u8, now_ms: i64) void {
        const n = @min(text.len, self.text.len);
        @memcpy(self.text[0..n], text[0..n]);
        self.text[n] = 0;
        self.encoder = encoder;
        self.at_ms = now_ms;
    }

    /// Whether the note is still shown at `now_ms`.
    pub fn lit(self: *const PushNote, now_ms: i64) bool {
        return now_ms - self.at_ms < linger_ms;
    }
};

pub const MftState = struct {
    /// The FX SEL mode, which takes over the controller while it is not null.
    fxsel: ?@import("mft_fxsel.zig").FxSelState = null,
    /// What the last click on a push changed.
    push_note: PushNote = .{},
    /// What the player did with the controls lately.
    activity: InputActivity = .{},
    active_module: MftActiveModule = .TRANSPORT,
    held_encoders: u16 = 0,
    /// The held encoders that were turned while they were held, one bit each. Because a turn with the push down is a fine adjustment, the
    /// release of such an encoder is not a click.
    turned_while_held: u16 = 0,
    // The FX index of the most recently tweaked parameter, so the side button
    // can toggle that plugin's floating window.
    last_fx_index: ?c_int = null,
    // The highlighted row of the settings (see mft_settings_rows.rows).
    settings_cursor: u8 = 0,
    /// The ticks of the first encoder of the SETTINGS page that have not moved the highlight yet, which keep the sign of the turn.
    settings_ticks: i16 = 0,
    /// The page that the controller was on before the SETTINGS page, which Save and Cancel go back to, and whether they asked for it: the panel draws in the
    /// timer of the window, so the run of the surface does the going back.
    settings_return: MftActiveModule = .TRANSPORT,
    settings_leave: bool = false,
    /// The ticks of the Order knob of the transport page that have not changed the order yet, which keep the sign of the turn.
    order_ticks: i16 = 0,
    /// The ticks of each knob that turns a stepped parameter, which have not made a step yet.
    step_ticks: [16]i16 = @splat(0),
    // Whether the on-screen panel is shown (toggled by side button L2).
    panel_visible: bool = true,
    // Whether an encoder was turned while held in transport mode, so a press was
    // a press-and-turn gesture rather than a click. Used by the knob-3 vertical
    // zoom experiment.
    transport_turned: bool = false,

    pub fn setHeld(self: *MftState, encoder_idx: u8) void {
        std.debug.assert(encoder_idx < 16);
        self.held_encoders |= (@as(u16, 1) << @intCast(encoder_idx));
    }

    pub fn clearHeld(self: *MftState, encoder_idx: u8) void {
        std.debug.assert(encoder_idx < 16);
        self.held_encoders &= ~(@as(u16, 1) << @intCast(encoder_idx));
    }

    /// Notes that an encoder was turned. When it is held, the turn is a fine adjustment, which takes away the click of its release.
    pub fn markTurnedIfHeld(self: *MftState, encoder_idx: u8) void {
        std.debug.assert(encoder_idx < 16);
        if (self.isHeld(encoder_idx)) self.turned_while_held |= (@as(u16, 1) << @intCast(encoder_idx));
    }

    /// Releases an encoder, and says whether the release is a click: the encoder was held and was not turned meanwhile.
    pub fn releaseIsClick(self: *MftState, encoder_idx: u8) bool {
        std.debug.assert(encoder_idx < 16);
        const bit = @as(u16, 1) << @intCast(encoder_idx);
        const click = self.isHeld(encoder_idx) and self.turned_while_held & bit == 0;
        self.clearHeld(encoder_idx);
        self.turned_while_held &= ~bit;
        return click;
    }

    pub fn isHeld(self: *const MftState, encoder_idx: u8) bool {
        std.debug.assert(encoder_idx < 16);
        return (self.held_encoders >> @intCast(encoder_idx)) & 1 == 1;
    }
};

test "MftState: held encoder bitfield" {
    const t = std.testing;
    var s = MftState{};

    s.setHeld(0);
    try t.expect(s.isHeld(0));
    try t.expect(!s.isHeld(1));

    s.setHeld(15);
    try t.expect(s.isHeld(15));

    s.clearHeld(0);
    try t.expect(!s.isHeld(0));
    try t.expect(s.isHeld(15));
}

test "a push note keeps its text cut to its size, and is lit for the linger time" {
    const t = std.testing;
    var note = PushNote{};
    try t.expect(!note.lit(0));
    note.set(1, "Low Shelf", 1000);
    try t.expectEqualStrings("Low Shelf", std.mem.sliceTo(&note.text, 0));
    try t.expect(note.lit(1000 + linger_ms - 1));
    try t.expect(!note.lit(1000 + linger_ms));
    const long: [40]u8 = @splat('x');
    note.set(2, &long, 5000);
    try t.expectEqual(@as(usize, 32), std.mem.sliceTo(&note.text, 0).len);
}

test "a release is a click unless the encoder was turned while it was held" {
    const t = std.testing;
    var s = MftState{};
    s.setHeld(3);
    try t.expect(s.releaseIsClick(3));
    try t.expect(!s.isHeld(3));
    // A release of an encoder that was not held is not a click.
    try t.expect(!s.releaseIsClick(3));
    s.setHeld(3);
    s.markTurnedIfHeld(3);
    try t.expect(!s.releaseIsClick(3));
    // The next press starts again, and a turn without the push down marks nothing.
    s.setHeld(3);
    try t.expect(s.releaseIsClick(3));
    s.markTurnedIfHeld(4);
    s.setHeld(4);
    try t.expect(s.releaseIsClick(4));
}

test "a turn and a press stay lit for the linger time, and a held press stays lit as long as it is held" {
    const t = std.testing;
    var a = InputActivity{};
    try t.expect(!a.turnLit(0, 1000));
    a.markTurn(0, 1000);
    try t.expect(a.turnLit(0, 1000 + linger_ms - 1));
    try t.expect(!a.turnLit(0, 1000 + linger_ms));
    try t.expect(!a.turnLit(1, 1000));

    a.markPress(2, true, 5000);
    try t.expect(a.pressLit(2, 5000 + 10 * linger_ms));
    a.markPress(2, false, 9000);
    try t.expect(a.pressLit(2, 9000 + linger_ms - 1));
    try t.expect(!a.pressLit(2, 9000 + linger_ms));

    a.markSide(0, true, 100);
    try t.expect(a.sideLit(0, 100 + 10 * linger_ms));
    a.markSide(0, false, 200);
    try t.expect(!a.sideLit(0, 200 + linger_ms));
    try t.expect(!a.sideLit(3, 200));
}
