const std = @import("std");

pub const MftActiveModule = enum { IO, GATE, EQ, COMP, SETTINGS, TRANSPORT };

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
    turned_at: [8]i64 = [_]i64{never} ** 8,
    /// The last press or release of each of the eight top encoders, and which of them are down.
    pressed_at: [8]i64 = [_]i64{never} ** 8,
    encoders_down: u8 = 0,
    /// The same for the six side keys, in the order of their CCs: L1 to L3, then R1 to R3.
    side_at: [6]i64 = [_]i64{never} ** 6,
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

pub const MftState = struct {
    /// What the player did with the controls lately.
    activity: InputActivity = .{},
    active_module: MftActiveModule = .TRANSPORT,
    held_encoders: u16 = 0,
    // The FX index of the most recently tweaked parameter, so the side button
    // can toggle that plugin's floating window.
    last_fx_index: ?c_int = null,
    // The highlighted row in settings mode (0..SETTINGS_ITEM_COUNT-1).
    settings_cursor: u8 = 0,
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
