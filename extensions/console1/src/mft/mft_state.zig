const std = @import("std");

pub const MftActiveModule = enum { IO, GATE, EQ, COMP, SETTINGS, TRANSPORT };

// The full MFT color palette (hue values on channel 3), used by the LED test.
pub const LED_TEST_COLORS = [_]u8{ 0x02, 0x0F, 0x19, 0x2E, 0x3C, 0x40, 0x49, 0x56, 0x5A, 0x6B, 0x71 };

pub const MftState = struct {
    active_module: MftActiveModule = .IO,
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
