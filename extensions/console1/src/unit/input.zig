//! What the unit says in sysex mode, turned into events, and the emulated positions of the knobs for the code that was
//! written for the absolute values of the legacy mode.
const std = @import("std");
const c1 = @import("../c1.zig");
const ids = @import("ids.zig");
const protocol = @import("protocol.zig");

const Input = @This();

pub const ControlEvent = union(enum) {
    press: c1.CCs,
    release: c1.CCs,
    /// One tick of a knob. The delta is signed and its size is meant to grow with the speed, which is not
    /// implemented: it is always 1 or -1. Fine is true while shift is held.
    tick: struct { cc: c1.CCs, delta: i8, fine: bool },
};

/// The step of a tick, in the 0 to 127 scale of the legacy mode: 3 of 127, and 1 of 127 with shift.
const coarse_step: i16 = 3;
const fine_step: i16 = 1;

shift_held: bool = false,
/// The position that the legacy unit would report for each knob. The host sets it with its feedback, and ticks move it.
knob_pos: [256]u8 = @splat(0),
/// The last value that a three-state button (Order and Sidechain) reported, for its cycle of 00, 3F, 7F.
button_state: [256]u8 = @splat(0),

/// Reads one control message of the unit. Shift is kept here and is not an event. A tick does not move the emulated
/// position: `legacyValue` does, for the consumers that still want an absolute value. A release of a button is an event,
/// and a message of an id that no control has is dropped.
pub fn handle(self: *Input, message: protocol.ControlMessage) ?ControlEvent {
    if (message.id == protocol.shift_id) {
        self.shift_held = message.value != 0;
        return null;
    }
    const cc = ids.ccOf(message.id) orelse return null;
    if (ids.isMeter(cc)) return null;
    if (cc.isBtn()) {
        return if (message.value != 0) .{ .press = cc } else .{ .release = cc };
    }
    const delta: i8 = if (message.value != 0) 1 else -1;
    return .{ .tick = .{ .cc = cc, .delta = delta, .fine = self.shift_held } };
}

/// The value that the legacy unit would have sent for this event: the emulated position of a knob, 7F for a button.
/// A press of Order or Sidechain cycles through 00, 3F and 7F, as the legacy unit's value did.
pub fn legacyValue(self: *Input, event: ControlEvent) ?struct { cc: c1.CCs, value: u8 } {
    switch (event) {
        .tick => |tick| {
            // Because a tick that something else consumed (shift and Volume selects a track) must not move the
            // position that the next tick of the knob starts from, the position only moves here.
            const step = if (tick.fine) fine_step else coarse_step;
            const moved = std.math.clamp(@as(i16, self.knob_pos[@backingInt(tick.cc)]) + tick.delta * step, 0, 127);
            self.knob_pos[@backingInt(tick.cc)] = @intCast(moved);
            return .{ .cc = tick.cc, .value = @intCast(moved) };
        },
        .press => |cc| {
            if (cc == .Tr_order or cc == .Tr_ext_sidechain) {
                const next: u8 = switch (self.button_state[@backingInt(cc)]) {
                    0x00 => 0x3F,
                    0x3F => 0x7F,
                    else => 0x00,
                };
                self.button_state[@backingInt(cc)] = next;
                return .{ .cc = cc, .value = next };
            }
            return .{ .cc = cc, .value = 0x7F };
        },
        .release => return null,
    }
}

/// The host moved a knob: the next tick starts from there, as the ring of the legacy unit did.
pub fn setKnobPosition(self: *Input, cc: c1.CCs, value: u8) void {
    if (ids.isKnob(cc)) self.knob_pos[@backingInt(cc)] = @min(value, 127);
}

fn control(id: u8, value: u8) protocol.ControlMessage {
    return .{ .id = id, .value = value };
}

/// A message of a knob, read and then given to a consumer that wants the absolute value.
fn tickValue(input: *Input, id: u8, value: u8) u8 {
    return input.legacyValue(input.handle(control(id, value)).?).?.value;
}

test "a tick that nobody takes does not move the emulated position" {
    var input: Input = .{};
    input.setKnobPosition(.Out_Vol, 50);
    _ = input.handle(control(ids.idOf(.Out_Vol).?, 0x7F));
    try std.testing.expectEqual(@as(u8, 50), input.knob_pos[@backingInt(c1.CCs.Out_Vol)]);
}

test "a tick moves the emulated position by 3, and by 1 while shift is held" {
    var input: Input = .{};
    const gain = ids.idOf(.Inpt_Gain).?;
    try std.testing.expectEqual(@as(u8, 3), tickValue(&input, gain, 0x7F));
    try std.testing.expectEqual(@as(?ControlEvent, null), input.handle(control(protocol.shift_id, 0x7F)));
    try std.testing.expect(input.shift_held);
    try std.testing.expect(input.handle(control(gain, 0x7F)).?.tick.fine);
    try std.testing.expectEqual(@as(u8, 4), tickValue(&input, gain, 0x7F));
    try std.testing.expectEqual(@as(u8, 3), tickValue(&input, gain, 0x00));
    _ = input.handle(control(protocol.shift_id, 0));
    try std.testing.expect(!input.shift_held);
}

test "the emulated position is clamped to 0 and 127" {
    var input: Input = .{};
    const vol = ids.idOf(.Out_Vol).?;
    try std.testing.expectEqual(@as(u8, 0), tickValue(&input, vol, 0x00));
    input.setKnobPosition(.Out_Vol, 126);
    try std.testing.expectEqual(@as(u8, 127), tickValue(&input, vol, 0x7F));
}

test "feedback sets the position that the next tick starts from" {
    var input: Input = .{};
    input.setKnobPosition(.Eq_HiGain, 60);
    try std.testing.expectEqual(@as(u8, 63), tickValue(&input, ids.idOf(.Eq_HiGain).?, 0x7F));
}

test "a press and a release of a button are two events, and a press has the value 7F" {
    var input: Input = .{};
    const tr1 = ids.idOf(.Tr_tr1).?;
    const press = input.handle(control(tr1, 0x7F)).?;
    try std.testing.expectEqual(c1.CCs.Tr_tr1, press.press);
    const legacy = input.legacyValue(press).?;
    try std.testing.expectEqual(@as(u8, 0x7F), legacy.value);
    const release = input.handle(control(tr1, 0x00)).?;
    try std.testing.expectEqual(c1.CCs.Tr_tr1, release.release);
    try std.testing.expectEqual(@as(?@TypeOf(legacy), null), input.legacyValue(release));
}

test "Order cycles 00, 3F, 7F, 00 on each press" {
    var input: Input = .{};
    const order: ControlEvent = .{ .press = .Tr_order };
    const expected = [_]u8{ 0x3F, 0x7F, 0x00, 0x3F };
    for (expected) |value| try std.testing.expectEqual(value, input.legacyValue(order).?.value);
}

test "meters and unknown ids are dropped" {
    var input: Input = .{};
    try std.testing.expectEqual(@as(?ControlEvent, null), input.handle(control(ids.idOf(.Out_MtrLft).?, 0x7F)));
    try std.testing.expectEqual(@as(?ControlEvent, null), input.handle(control(0x7E, 0x7F)));
}

test "any sequence of ticks and feedback keeps every position in range" {
    var prng = std.Random.DefaultPrng.init(0x5EED);
    const random = prng.random();
    var input: Input = .{};
    const knobs = [_]c1.CCs{ .Inpt_Gain, .Out_Vol, .Eq_LoFrq, .Comp_Thresh };
    for (0..2000) |_| {
        const cc = knobs[random.uintLessThan(usize, knobs.len)];
        switch (random.uintLessThan(u8, 4)) {
            0 => {
                const fed = random.uintLessThan(u8, 128);
                input.setKnobPosition(cc, fed);
                try std.testing.expectEqual(fed, input.knob_pos[@backingInt(cc)]);
            },
            1 => _ = input.handle(control(protocol.shift_id, if (random.boolean()) 0x7F else 0)),
            else => _ = tickValue(&input, ids.idOf(cc).?, if (random.boolean()) 0x7F else 0),
        }
        for (knobs) |knob| try std.testing.expect(input.knob_pos[@backingInt(knob)] <= 127);
    }
}
