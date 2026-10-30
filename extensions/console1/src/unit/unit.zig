//! The Console 1 as the extension talks to it: the backend that is in use (the sysex mode after the handshake, or the
//! legacy CC mode when the handshake failed), the handshake itself, and the LEDs that the unit has to be told about.
const std = @import("std");
const c = @import("c");
const c1 = @import("../c1.zig");
const ids = @import("ids.zig");
const protocol = @import("protocol.zig");
const LedState = @import("led_state.zig");
const Input = @import("input.zig");
pub const ControlEvent = Input.ControlEvent;
const log = std.log.scoped(.unit);

const Unit = @This();

pub const Backend = enum { legacy_cc, sysex };

pub const Link = union(enum) {
    /// Nothing was started: no MIDI output, or the unit was replugged and the handshake has to start again.
    idle,
    handshaking: struct { step: u8, tries: u8, deadline_ms: u64 },
    ready,
    /// The handshake got no answer three times, so the backend is the legacy one for good.
    failed,
};

/// How the unit sends bytes. The real one goes through REAPER's MIDI output, and the tests use their own.
pub const Sender = struct {
    context: ?*anyopaque,
    sendCc: *const fn (context: ?*anyopaque, status: u8, d1: u8, d2: u8) void,
    sendSysex: *const fn (context: ?*anyopaque, bytes: []const u8) void,

    pub fn reaper(midi_out: anytype) Sender {
        return .{ .context = @ptrCast(midi_out), .sendCc = reaperSendCc, .sendSysex = reaperSendSysex };
    }
};

fn reaperSendCc(context: ?*anyopaque, status: u8, d1: u8, d2: u8) void {
    c.MidiOut_Send(@ptrCast(context), status, d1, d2, -1);
}

fn reaperSendSysex(context: ?*anyopaque, bytes: []const u8) void {
    c.MidiOut_SendSysex(@ptrCast(context), bytes.ptr, @intCast(bytes.len));
}

/// The time that the unit gets to answer one request. The answer to the challenge alone takes about half a second.
const answer_timeout_ms = 2000;
const max_tries = 3;
/// The application sends a frame about every 30 ms while something changes.
const flush_interval_ms = 30;
/// The first state frame after the handshake push, which has the counter 1.
const first_counter: u7 = 2;

const Request = struct { frame: []const u8, answer: u8 };
const handshake = [_]Request{
    .{ .frame = &protocol.hello_frame, .answer = protocol.Kind.hello_answer },
    .{ .frame = &protocol.hello_frame, .answer = protocol.Kind.hello_answer },
    .{ .frame = &protocol.challenge_frame, .answer = protocol.Kind.challenge_answer },
    .{ .frame = &protocol.version_request_frame, .answer = protocol.Kind.version_answer },
    .{ .frame = &protocol.handshake_state_frame, .answer = protocol.Kind.ack },
};

const queue_capacity = 128;

backend: Backend = .legacy_cc,
link: Link = .idle,
leds: LedState = .off,
input: Input = .{},
sender: ?Sender = null,
counter: u7 = first_counter,
last_acked: ?u7 = null,
last_flush_ms: u64 = 0,
events: [queue_capacity]ControlEvent = undefined,
event_count: usize = 0,
event_head: usize = 0,
/// How many sysex events were logged with their size, to show whether REAPER delivers them whole.
logged_sizes: u8 = 0,

pub fn shiftHeld(self: *const Unit) bool {
    return self.input.shift_held;
}

pub fn isReady(self: *const Unit) bool {
    return self.link == .ready;
}

/// True when the handshake failed and the unit runs in the legacy mode, which the UI has to say.
pub fn isLegacyMode(self: *const Unit) bool {
    return self.link == .failed;
}

/// Starts the handshake. The unit is in the legacy mode until it answers.
pub fn start(self: *Unit, sender: Sender, now_ms: u64) void {
    self.sender = sender;
    self.backend = .legacy_cc;
    self.beginHandshake(0, now_ms);
}

fn beginHandshake(self: *Unit, tries: u8, now_ms: u64) void {
    self.link = .{ .handshaking = .{ .step = 0, .tries = tries, .deadline_ms = now_ms + answer_timeout_ms } };
    self.sendStep(0);
}

fn sendStep(self: *Unit, step: u8) void {
    const sender = self.sender orelse return;
    log.info("handshake: step {d} of {d}", .{ step + 1, handshake.len });
    sender.sendSysex(sender.context, handshake[step].frame);
}

fn advance(self: *Unit, now_ms: u64) void {
    const state = &self.link.handshaking;
    state.step += 1;
    if (state.step == handshake.len) {
        log.info("handshake done: the unit is in sysex mode", .{});
        self.link = .ready;
        self.backend = .sysex;
        self.counter = first_counter;
        // The unit now shows the quiet frame of the handshake, so what the shadow holds has to follow.
        self.leds.dirty = true;
        self.last_flush_ms = 0;
        return;
    }
    state.deadline_ms = now_ms + answer_timeout_ms;
    self.sendStep(state.step);
}

/// A sysex that arrived from the unit. Whether the input list delivers whole sysex events is logged for the first few.
pub fn onSysex(self: *Unit, bytes: []const u8, now_ms: u64) void {
    if (self.logged_sizes < 20) {
        self.logged_sizes += 1;
        log.info("sysex event of {d} bytes, first byte {x}", .{ bytes.len, if (bytes.len > 0) bytes[0] else 0 });
    }
    const message = protocol.parse(bytes) orelse return;
    switch (message.kind) {
        protocol.Kind.control => {
            const control = protocol.parseControl(message) orelse return;
            if (self.link != .ready) return;
            if (self.input.handle(control)) |event| self.push(event);
        },
        protocol.Kind.ack => {
            if (message.payload.len == 1) self.last_acked = @intCast(message.payload[0] & 0x7F);
            self.answer(message.kind, now_ms);
        },
        else => {
            if (message.kind == protocol.Kind.version_answer) log.info("unit firmware: {s}", .{message.payload});
            self.answer(message.kind, now_ms);
        },
    }
}

fn answer(self: *Unit, kind: u8, now_ms: u64) void {
    switch (self.link) {
        .handshaking => |state| if (handshake[state.step].answer == kind) self.advance(now_ms),
        else => {},
    }
}

/// A CC arrived. It returns whether the legacy code should handle it: after the handshake the unit does not send CCs,
/// so one means that the unit was unplugged and plugged in again, and that the handshake has to be made again.
pub fn onCc(self: *Unit, now_ms: u64) bool {
    if (self.link != .ready) return true;
    log.warn("a CC arrived in sysex mode: the unit was replugged, the handshake starts again", .{});
    self.backend = .legacy_cc;
    self.beginHandshake(0, now_ms);
    return false;
}

/// The timeouts of the handshake, and the state frame when something changed.
pub fn tick(self: *Unit, now_ms: u64) void {
    switch (self.link) {
        .handshaking => |state| if (now_ms >= state.deadline_ms) {
            if (state.tries + 1 >= max_tries) {
                log.warn("handshake: no answer to step {d} after {d} tries, using the legacy CC mode", .{ state.step + 1, max_tries });
                self.link = .failed;
                self.backend = .legacy_cc;
            } else {
                self.beginHandshake(state.tries + 1, now_ms);
            }
        },
        .ready => self.flush(now_ms, false),
        else => {},
    }
}

fn flush(self: *Unit, now_ms: u64, force: bool) void {
    if (!self.leds.dirty) return;
    if (!force and now_ms - self.last_flush_ms < flush_interval_ms) return;
    const sender = self.sender orelse return;
    const frame = self.leds.frame(self.counter);
    sender.sendSysex(sender.context, &frame);
    self.counter +%= 1;
    self.leds.dirty = false;
    self.last_flush_ms = now_ms;
}

/// Sets what a control shows. Because the unit keeps no LED by itself in sysex mode, the value goes into the state
/// frame; in the legacy mode and while the handshake runs it is a CC, as it always was. A knob moves the emulated
/// position in both cases, so that the next tick starts from what the ring shows.
pub fn setLed(self: *Unit, cc: c1.CCs, value: u8) void {
    self.leds.setValue(cc, value);
    self.input.setKnobPosition(cc, value);
    if (self.link != .ready) self.sendCc(cc, value);
}

/// Every LED off, and the meters at rest.
pub fn clearAll(self: *Unit) void {
    self.leds.clearAll();
    if (self.link == .ready) return;
    for (std.enums.values(c1.CCs)) |cc| {
        self.sendCc(cc, if (cc == .Comp_Mtr or cc == .Shp_Mtr) 0x7F else 0);
    }
}

fn sendCc(self: *Unit, cc: c1.CCs, value: u8) void {
    const sender = self.sender orelse return;
    sender.sendCc(sender.context, 0xB0, @backingInt(cc), value);
}

/// The unit is going away: everything dark, including the meters, sent at once.
pub fn shutdown(self: *Unit) void {
    if (self.link == .ready) {
        self.leds = .off;
        self.flush(0, true);
    } else {
        self.clearAll();
    }
}

fn push(self: *Unit, event: ControlEvent) void {
    if (self.event_count == queue_capacity) {
        log.warn("the event queue of the unit is full, an event is dropped", .{});
        return;
    }
    self.events[(self.event_head + self.event_count) % queue_capacity] = event;
    self.event_count += 1;
}

pub fn popEvent(self: *Unit) ?ControlEvent {
    if (self.event_count == 0) return null;
    const event = self.events[self.event_head];
    self.event_head = (self.event_head + 1) % queue_capacity;
    self.event_count -= 1;
    return event;
}

// Tests -------------------------------------------------------------------------------------------------------------

const Fake = struct {
    sysex: std.ArrayList([]const u8) = .empty,
    ccs: usize = 0,
    last_cc: [3]u8 = .{ 0, 0, 0 },

    fn sender(self: *Fake) Sender {
        return .{ .context = self, .sendCc = fakeCc, .sendSysex = fakeSysex };
    }
    fn fakeCc(context: ?*anyopaque, status: u8, d1: u8, d2: u8) void {
        const self: *Fake = @ptrCast(@alignCast(context));
        self.ccs += 1;
        self.last_cc = .{ status, d1, d2 };
    }
    fn fakeSysex(context: ?*anyopaque, bytes: []const u8) void {
        const self: *Fake = @ptrCast(@alignCast(context));
        self.sysex.append(std.testing.allocator, std.testing.allocator.dupe(u8, bytes) catch unreachable) catch unreachable;
    }
    fn deinit(self: *Fake) void {
        for (self.sysex.items) |item| std.testing.allocator.free(item);
        self.sysex.deinit(std.testing.allocator);
    }
    fn kindOfLast(self: *Fake) u8 {
        return self.sysex.items[self.sysex.items.len - 1][2];
    }
};

fn answerOf(kind: u8, payload: []const u8) [20]u8 {
    var bytes: [20]u8 = @splat(0);
    bytes[0] = 0xF0;
    bytes[1] = 0x7D;
    bytes[2] = kind;
    bytes[6] = @intCast(payload.len);
    @memcpy(bytes[8 .. 8 + payload.len], payload);
    return bytes;
}

fn feed(unit: *Unit, kind: u8, payload: []const u8, now_ms: u64) void {
    const bytes = answerOf(kind, payload);
    unit.onSysex(bytes[0 .. 8 + payload.len], now_ms);
}

fn completeHandshake(unit: *Unit, fake: *Fake) void {
    unit.start(fake.sender(), 0);
    feed(unit, protocol.Kind.hello_answer, &.{0x7F}, 10);
    feed(unit, protocol.Kind.hello_answer, &.{0x7F}, 20);
    feed(unit, protocol.Kind.challenge_answer, &.{0x01}, 30);
    feed(unit, protocol.Kind.version_answer, "1.19", 40);
    feed(unit, protocol.Kind.ack, &.{0x01}, 50);
}

test "the handshake sends its requests in order, each after the answer to the one before" {
    var fake: Fake = .{};
    defer fake.deinit();
    var unit: Unit = .{};
    unit.start(fake.sender(), 0);
    try std.testing.expectEqual(@as(usize, 1), fake.sysex.items.len);
    try std.testing.expectEqual(protocol.Kind.hello, fake.kindOfLast());

    // An answer that is not the expected one changes nothing.
    feed(&unit, protocol.Kind.version_answer, "1.19", 5);
    try std.testing.expectEqual(@as(usize, 1), fake.sysex.items.len);

    feed(&unit, protocol.Kind.hello_answer, &.{0x7F}, 10);
    try std.testing.expectEqual(protocol.Kind.hello, fake.kindOfLast());
    feed(&unit, protocol.Kind.hello_answer, &.{0x7F}, 20);
    try std.testing.expectEqual(protocol.Kind.challenge, fake.kindOfLast());
    feed(&unit, protocol.Kind.challenge_answer, &.{0x01}, 30);
    try std.testing.expectEqual(protocol.Kind.version_request, fake.kindOfLast());
    feed(&unit, protocol.Kind.version_answer, "1.19", 40);
    try std.testing.expectEqual(protocol.Kind.state, fake.kindOfLast());
    try std.testing.expect(!unit.isReady());
    feed(&unit, protocol.Kind.ack, &.{0x01}, 50);
    try std.testing.expect(unit.isReady());
    try std.testing.expectEqual(Backend.sysex, unit.backend);
    try std.testing.expect(!unit.isLegacyMode());
}

test "a handshake that gets no answer is tried three times and ends in the legacy mode" {
    var fake: Fake = .{};
    defer fake.deinit();
    var unit: Unit = .{};
    unit.start(fake.sender(), 0);
    unit.tick(1000);
    try std.testing.expectEqual(@as(usize, 1), fake.sysex.items.len);
    unit.tick(2000);
    try std.testing.expectEqual(@as(usize, 2), fake.sysex.items.len);
    try std.testing.expect(!unit.isLegacyMode());
    unit.tick(4000);
    try std.testing.expectEqual(@as(usize, 3), fake.sysex.items.len);
    unit.tick(6000);
    try std.testing.expect(unit.isLegacyMode());
    try std.testing.expectEqual(Backend.legacy_cc, unit.backend);
    // The legacy mode sends CCs.
    unit.setLed(.Out_Vol, 99);
    try std.testing.expectEqual([3]u8{ 0xB0, @backingInt(c1.CCs.Out_Vol), 99 }, fake.last_cc);
    // Nothing more is sent as sysex, and the CCs go to the legacy code.
    unit.tick(10000);
    try std.testing.expectEqual(@as(usize, 3), fake.sysex.items.len);
    try std.testing.expect(unit.onCc(10001));
}

test "in sysex mode an LED goes into one state frame, at most one every 30 ms" {
    var fake: Fake = .{};
    defer fake.deinit();
    var unit: Unit = .{};
    completeHandshake(&unit, &fake);
    const sent_by_handshake = fake.sysex.items.len;
    fake.ccs = 0;

    unit.setLed(.Tr_tr1, 0x7F);
    unit.setLed(.Out_Vol, 0x40);
    try std.testing.expectEqual(@as(usize, 0), fake.ccs);
    unit.tick(60);
    try std.testing.expectEqual(sent_by_handshake + 1, fake.sysex.items.len);
    try std.testing.expectEqual(@as(usize, protocol.state_frame_length), fake.sysex.items[sent_by_handshake].len);

    unit.setLed(.Tr_tr2, 0x7F);
    unit.tick(70);
    try std.testing.expectEqual(sent_by_handshake + 1, fake.sysex.items.len);
    unit.tick(95);
    try std.testing.expectEqual(sent_by_handshake + 2, fake.sysex.items.len);
    // Nothing changed: nothing is sent.
    unit.tick(500);
    try std.testing.expectEqual(sent_by_handshake + 2, fake.sysex.items.len);
    // The counter goes up by one per frame.
    try std.testing.expectEqual(fake.sysex.items[sent_by_handshake][8] +% 1, fake.sysex.items[sent_by_handshake + 1][8]);
}

test "a frame carries the whole shadow, which the handshake could not have" {
    var fake: Fake = .{};
    defer fake.deinit();
    var unit: Unit = .{};
    unit.start(fake.sender(), 0);
    // LEDs set while the handshake runs are sent as CCs and also kept for the first frame.
    unit.setLed(.Tr_tr3, 0x7F);
    try std.testing.expectEqual(@as(usize, 1), fake.ccs);
    feed(&unit, protocol.Kind.hello_answer, &.{0x7F}, 10);
    feed(&unit, protocol.Kind.hello_answer, &.{0x7F}, 20);
    feed(&unit, protocol.Kind.challenge_answer, &.{0x01}, 30);
    feed(&unit, protocol.Kind.version_answer, "1.19", 40);
    feed(&unit, protocol.Kind.ack, &.{0x01}, 50);
    unit.tick(100);
    const frame = fake.sysex.items[fake.sysex.items.len - 1];
    try std.testing.expectEqual(@as(u8, 0x7F), frame[8 + 1 + ids.idOf(.Tr_tr3).?]);
}

test "a control event is queued, shift is kept, and nothing is queued before the handshake is done" {
    var fake: Fake = .{};
    defer fake.deinit();
    var unit: Unit = .{};
    unit.start(fake.sender(), 0);
    feed(&unit, protocol.Kind.control, &.{ ids.idOf(.Tr_tr1).?, 0x7F }, 1);
    try std.testing.expectEqual(@as(?ControlEvent, null), unit.popEvent());

    completeHandshake(&unit, &fake);
    feed(&unit, protocol.Kind.control, &.{ protocol.shift_id, 0x7F }, 100);
    try std.testing.expect(unit.shiftHeld());
    feed(&unit, protocol.Kind.control, &.{ ids.idOf(.Tr_tr1).?, 0x7F }, 101);
    feed(&unit, protocol.Kind.control, &.{ ids.idOf(.Tr_tr1).?, 0x00 }, 102);
    try std.testing.expectEqual(c1.CCs.Tr_tr1, unit.popEvent().?.press);
    try std.testing.expectEqual(c1.CCs.Tr_tr1, unit.popEvent().?.release);
    try std.testing.expectEqual(@as(?ControlEvent, null), unit.popEvent());
}

test "a CC in sysex mode restarts the handshake" {
    var fake: Fake = .{};
    defer fake.deinit();
    var unit: Unit = .{};
    completeHandshake(&unit, &fake);
    const before = fake.sysex.items.len;
    try std.testing.expect(!unit.onCc(1000));
    try std.testing.expect(!unit.isReady());
    try std.testing.expectEqual(before + 1, fake.sysex.items.len);
    try std.testing.expectEqual(protocol.Kind.hello, fake.kindOfLast());
    try std.testing.expectEqual(Backend.legacy_cc, unit.backend);
}

test "shutdown sends one frame with every LED dark" {
    var fake: Fake = .{};
    defer fake.deinit();
    var unit: Unit = .{};
    completeHandshake(&unit, &fake);
    unit.setLed(.Tr_tr1, 0x7F);
    unit.tick(200);
    unit.shutdown();
    const frame = fake.sysex.items[fake.sysex.items.len - 1];
    try std.testing.expectEqual(@as(usize, protocol.state_frame_length), frame.len);
    for (frame[8 + 73 .. 8 + 84]) |byte| try std.testing.expectEqual(@as(u8, 0), byte);
}
