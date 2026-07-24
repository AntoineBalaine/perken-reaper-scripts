const std = @import("std");

pub const MftActiveModule = enum { IO, GATE, EQ, COMP, SETTINGS, TRANSPORT };

// Hue positions on the MFT color wheel, taken from the verified palette in
// perken-reaper-scripts (synth_map_midiFighter.lua): skyBlue 0x0F, pink 0x5A,
// appleGreen 0x3C, red 0x56.
pub const MODULE_COLORS = std.EnumArray(MftActiveModule, u8).init(.{
    .IO = 0x0F,
    .GATE = 0x5A,
    .EQ = 0x3C,
    .COMP = 0x56,
    .SETTINGS = 0,
    .TRANSPORT = 0,
});

// The full MFT color palette (hue values on channel 3), used by the LED test.
pub const LED_TEST_COLORS = [_]u8{ 0x02, 0x0F, 0x19, 0x2E, 0x3C, 0x40, 0x49, 0x56, 0x5A, 0x6B, 0x71 };

pub const MftState = struct {
    active_module: MftActiveModule = .IO,
    held_encoders: u16 = 0,

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
