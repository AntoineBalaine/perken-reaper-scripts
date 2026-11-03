//! The shadow of the state frame: the value and the flag bits of every control. The unit lights nothing by itself in
//! sysex mode, so this is what it shows, and it is sent whenever something changed.
const std = @import("std");
const c1 = @import("../c1.zig");
const ids = @import("ids.zig");
const protocol = @import("protocol.zig");

const LedState = @This();

const bank_a_start = 73;

payload: [protocol.payload_length]u8,
/// True when the payload differs from the last frame that was sent.
dirty: bool,

pub const off: LedState = blk: {
    var state: LedState = .{ .payload = @splat(0), .dirty = true };
    state.payload[protocol.switch_byte] = protocol.switch_value;
    state.payload[protocol.unknown_byte] = protocol.unknown_value;
    break :blk state;
};

/// The byte of a bank that has the flag of an id, and the bit in it. The bits of a byte are in reverse order.
fn flagPosition(bank_start: usize, id: u8) struct { byte: usize, mask: u8 } {
    return .{ .byte = bank_start + id / 7, .mask = @as(u8, 1) << @intCast(6 - id % 7) };
}

fn setFlag(self: *LedState, bank_start: usize, id: u8, on: bool) void {
    const position = flagPosition(bank_start, id);
    const before = self.payload[position.byte];
    self.payload[position.byte] = if (on) before | position.mask else before & ~position.mask;
    if (before != self.payload[position.byte]) self.dirty = true;
}

fn hasFlag(self: *const LedState, bank_start: usize, id: u8) bool {
    const position = flagPosition(bank_start, id);
    return self.payload[position.byte] & position.mask != 0;
}

/// What the unit shows when nothing is lit: the controls are dark and the values are zero, except for the meters.
/// Because the meters should always be visible, they keep their flags, and the shape and the compressor meter rest
/// at 7F, as they did in the legacy mode.
pub fn clearAll(self: *LedState) void {
    const before = self.payload;
    @memset(self.payload[1 .. 1 + ids.id_count], 0);
    @memset(self.payload[bank_a_start..protocol.switch_byte], 0);
    for (std.enums.values(c1.CCs)) |cc| {
        if (ids.isMeter(cc)) self.setValue(cc, if (cc == .Comp_Mtr or cc == .Shp_Mtr) 0x7F else 0);
    }
    if (!std.mem.eql(u8, &before, &self.payload)) self.dirty = true;
}

/// Sets the value of a control and lights it with its flag in bank A. Bank B stays clear: it only matters when the
/// global switch (byte 95) is low, and the extension keeps that byte at the value of the application. The value of a button is lit when it is not zero, and the value of a knob is a position of its ring.
pub fn setValue(self: *LedState, cc: c1.CCs, new_value: u8) void {
    const id = ids.idOf(cc) orelse return;
    const clamped = new_value & 0x7F;
    if (self.payload[1 + id] != clamped) {
        self.payload[1 + id] = clamped;
        self.dirty = true;
    }
    self.setFlag(bank_a_start, id, true);
}

pub fn value(self: *const LedState, cc: c1.CCs) u8 {
    const id = ids.idOf(cc) orelse return 0;
    return self.payload[1 + id];
}

pub fn isLit(self: *const LedState, cc: c1.CCs) bool {
    const id = ids.idOf(cc) orelse return false;
    return self.hasFlag(bank_a_start, id);
}

/// The frame to send, with the counter of the frame in the first byte of the payload.
pub fn frame(self: *const LedState, counter: u7) [protocol.state_frame_length]u8 {
    var payload = self.payload;
    payload[0] = counter;
    return protocol.buildStateFrame(&payload);
}

test "setValue sets the value byte and the flag in the reversed order of its group" {
    var state = LedState.off;
    state.dirty = false;
    // Id 0x2A (Eq_LoGain) is the fourth of its group of seven: payload byte 73 + 6 = 79, bit 6 - 0 = 6 for 0x2A mod 7 = 0.
    state.setValue(.Eq_LoGain, 0x40);
    try std.testing.expectEqual(@as(u8, 0x40), state.payload[1 + 0x2A]);
    try std.testing.expectEqual(@as(u8, 1 << 6), state.payload[79] & (1 << 6));
    try std.testing.expect(state.dirty);
    // The next id of the same group is the next bit down.
    state.setValue(.Eq_LoMidFrq, 1);
    try std.testing.expectEqual(@as(u8, 1 << 5), state.payload[79] & (1 << 5));
}

test "bank B stays clear" {
    var state = LedState.off;
    state.setValue(.Inpt_Gain, 0x3F);
    state.setValue(.Comp_Ratio, 0x20);
    try std.testing.expect(state.isLit(.Inpt_Gain));
    for (84..95) |byte| try std.testing.expectEqual(@as(u8, 0), state.payload[byte]);
}

test "setValue only marks the state dirty when something changed" {
    var state = LedState.off;
    state.setValue(.Out_Vol, 10);
    state.dirty = false;
    state.setValue(.Out_Vol, 10);
    try std.testing.expect(!state.dirty);
    state.setValue(.Out_Vol, 11);
    try std.testing.expect(state.dirty);
}

test "clearAll darkens the controls and keeps the meters visible, at rest" {
    var state = LedState.off;
    state.setValue(.Tr_tr1, 0x7F);
    state.setValue(.Eq_HiFrq, 0x50);
    state.clearAll();
    try std.testing.expect(!state.isLit(.Tr_tr1));
    try std.testing.expectEqual(@as(u8, 0), state.value(.Eq_HiFrq));
    try std.testing.expect(state.isLit(.Out_MtrLft));
    try std.testing.expectEqual(@as(u8, 0x7F), state.value(.Comp_Mtr));
    try std.testing.expectEqual(@as(u8, 0x7F), state.value(.Shp_Mtr));
    try std.testing.expectEqual(@as(u8, 0), state.value(.Inpt_MtrLft));
    try std.testing.expectEqual(protocol.switch_value, state.payload[protocol.switch_byte]);
    try std.testing.expectEqual(protocol.unknown_value, state.payload[protocol.unknown_byte]);
}

test "a control that was never set is dark" {
    const state = LedState.off;
    try std.testing.expect(!state.isLit(.Tr_tr1));
    try std.testing.expect(!state.isLit(.Comp_Mtr));
}

test "the frame has the counter, the markers and 7-bit bytes" {
    var state = LedState.off;
    state.setValue(.Out_Vol, 0x7F);
    const frame_bytes = state.frame(0x55);
    try std.testing.expectEqual(@as(usize, 111), frame_bytes.len);
    try std.testing.expectEqual(@as(u8, 0xF0), frame_bytes[0]);
    try std.testing.expectEqual(@as(u8, 0xF7), frame_bytes[110]);
    try std.testing.expectEqual(@as(u8, 0x55), frame_bytes[8]);
    for (frame_bytes[1..110]) |byte| try std.testing.expect(byte < 0x80);
}
