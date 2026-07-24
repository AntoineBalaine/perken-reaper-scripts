const std = @import("std");

pub const MftActiveModule = enum { IO, GATE, EQ, COMP, SETTINGS, TRANSPORT };

pub const MODULE_COLORS = std.EnumArray(MftActiveModule, u8).init(.{
    .IO = 26,
    .GATE = 112,
    .EQ = 60,
    .COMP = 80,
    .SETTINGS = 0,
    .TRANSPORT = 0,
});

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
