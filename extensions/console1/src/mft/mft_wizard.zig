const std = @import("std");
const mft = @import("mft.zig");
const mft_state = @import("mft_state.zig");
const log = std.log.scoped(.mft_wizard);

// A guided calibration pass. Because the CC numbers, the relative encoding
// direction, and the channels were taken from a ReaLearn config rather than
// tested on hardware, the wizard walks the user through each control, listens
// to the incoming MIDI, and records whether it matched what the code expects.
// The side-button CCs are not firmly known, so those steps just capture and
// report whatever arrives.

pub const StepKind = enum { rotate, press, side };

pub const Step = struct {
    kind: StepKind,
    index: u8,
};

pub const Status = enum { pending, pass, fail, skipped };

pub const Result = struct {
    status: Status = .pending,
    captured: bool = false,
    obs_channel: u8 = 0,
    obs_cc: u8 = 0,
    obs_val: u8 = 0,
};

pub const STEP_COUNT = 16 + 16 + 6;

pub const steps: [STEP_COUNT]Step = blk: {
    var s: [STEP_COUNT]Step = undefined;
    var n: usize = 0;
    for (0..16) |i| {
        s[n] = .{ .kind = .rotate, .index = @intCast(i) };
        n += 1;
    }
    for (0..16) |i| {
        s[n] = .{ .kind = .press, .index = @intCast(i) };
        n += 1;
    }
    for (0..6) |i| {
        s[n] = .{ .kind = .side, .index = @intCast(i) };
        n += 1;
    }
    break :blk s;
};

fn evaluate(step: Step, channel: u8, cc: u8, val: u8) Status {
    return switch (step.kind) {
        .rotate => if (channel == mft.ENCODER_ROT_CHANNEL and cc == step.index and mft.decodeRelative(val) > 0)
            .pass
        else
            .fail,
        .press => if (channel == mft.ENCODER_BTN_CHANNEL and cc == step.index and val == 127)
            .pass
        else
            .fail,
        // The side-button CCs are unknown, so arriving on the side-button
        // channel is enough to pass; the report records the observed CC.
        .side => if (channel == mft.SIDE_BTN_CHANNEL) .pass else .fail,
    };
}

pub const WizardState = struct {
    active: bool = false,
    current: usize = 0,
    results: [STEP_COUNT]Result = [_]Result{.{}} ** STEP_COUNT,
    // LED test: cycles colours and sweeps the rings so the feedback path can be
    // eyeballed. `led_frame` advances once per panel frame.
    led_test_active: bool = false,
    led_frame: u32 = 0,

    pub fn start(self: *WizardState) void {
        self.active = true;
        self.current = 0;
        self.results = [_]Result{.{}} ** STEP_COUNT;
        log.info("calibration started", .{});
    }

    pub fn stop(self: *WizardState) void {
        self.active = false;
    }

    // Capture the first event seen for the current step and evaluate it. Later
    // events for the same step are ignored until the user advances, so the user
    // can read the result.
    pub fn onMidi(self: *WizardState, channel: u8, cc: u8, val: u8) void {
        if (!self.active) return;
        const r = &self.results[self.current];
        if (r.captured) return;
        r.captured = true;
        r.obs_channel = channel;
        r.obs_cc = cc;
        r.obs_val = val;
        r.status = evaluate(steps[self.current], channel, cc, val);
        log.info("step {d}: expected {s}, observed ch{d} cc{d} val{d} -> {s}", .{
            self.current + 1, @tagName(steps[self.current].kind), channel, cc, val, @tagName(r.status),
        });
    }

    pub fn next(self: *WizardState) void {
        if (self.current + 1 < STEP_COUNT) self.current += 1;
    }

    pub fn retry(self: *WizardState) void {
        self.results[self.current] = .{};
    }

    pub fn skip(self: *WizardState) void {
        self.results[self.current].status = .skipped;
        self.next();
    }

    pub fn isLast(self: *const WizardState) bool {
        return self.current + 1 == STEP_COUNT;
    }

    // Advance the LED test one frame and return the hue and ring position to
    // send to every knob. The colour steps through the palette every 20 frames;
    // the ring sweeps 0..127 each frame.
    pub fn ledTestAdvance(self: *WizardState) struct { hue: u8, ring: u8 } {
        const colors = mft_state.LED_TEST_COLORS;
        const hue = colors[(self.led_frame / 20) % colors.len];
        const ring: u8 = @intCast(self.led_frame % 128);
        self.led_frame +%= 1;
        return .{ .hue = hue, .ring = ring };
    }
};

// Format the instruction for a step into buf. Returns a null-terminated slice.
pub fn describe(step: Step, buf: [:0]u8) [:0]const u8 {
    return switch (step.kind) {
        .rotate => std.fmt.bufPrintZ(buf, "Turn encoder {d} one click clockwise", .{step.index + 1}) catch buf[0..0 :0],
        .press => std.fmt.bufPrintZ(buf, "Press encoder {d}", .{step.index + 1}) catch buf[0..0 :0],
        .side => std.fmt.bufPrintZ(buf, "Press side button {d} of 6", .{step.index + 1}) catch buf[0..0 :0],
    };
}

pub fn expectedText(step: Step, buf: [:0]u8) [:0]const u8 {
    return switch (step.kind) {
        .rotate => std.fmt.bufPrintZ(buf, "expect ch{d} cc{d}, positive delta", .{ mft.ENCODER_ROT_CHANNEL, step.index }) catch buf[0..0 :0],
        .press => std.fmt.bufPrintZ(buf, "expect ch{d} cc{d}, value 127", .{ mft.ENCODER_BTN_CHANNEL, step.index }) catch buf[0..0 :0],
        .side => std.fmt.bufPrintZ(buf, "expect ch{d}, cc unknown (capturing)", .{mft.SIDE_BTN_CHANNEL}) catch buf[0..0 :0],
    };
}

pub fn observedText(r: Result, buf: [:0]u8) [:0]const u8 {
    if (!r.captured) return std.fmt.bufPrintZ(buf, "waiting...", .{}) catch buf[0..0 :0];
    return std.fmt.bufPrintZ(buf, "ch{d} cc{d} val{d}", .{ r.obs_channel, r.obs_cc, r.obs_val }) catch buf[0..0 :0];
}

// Write a markdown report of the run to <dir>/wizard_report.md.
pub fn writeReport(self: *const WizardState, dir: [:0]const u8) !void {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "{s}{s}wizard_report.md", .{ dir, std.fs.path.sep_str });

    const file = try std.fs.createFileAbsolute(path, .{ .truncate = true });
    defer file.close();
    var w = file.writer();

    try w.writeAll("# MFT calibration report\n\n");
    try w.writeAll("| step | instruction | expected | observed | result |\n");
    try w.writeAll("| --- | --- | --- | --- | --- |\n");

    var instr_buf: [128:0]u8 = undefined;
    var exp_buf: [128:0]u8 = undefined;
    var obs_buf: [128:0]u8 = undefined;
    for (steps, self.results, 1..) |step, r, n| {
        try w.print("| {d} | {s} | {s} | {s} | {s} |\n", .{
            n,
            describe(step, &instr_buf),
            expectedText(step, &exp_buf),
            observedText(r, &obs_buf),
            @tagName(r.status),
        });
    }
    log.info("calibration report written to {s}", .{path});
}

test "wizard: steps cover all controls" {
    try std.testing.expectEqual(@as(usize, 38), STEP_COUNT);
    try std.testing.expectEqual(StepKind.rotate, steps[0].kind);
    try std.testing.expectEqual(StepKind.press, steps[16].kind);
    try std.testing.expectEqual(StepKind.side, steps[32].kind);
}

test "wizard: evaluate rotate direction and channel" {
    // Clockwise on the right encoder (65 = +1) passes.
    try std.testing.expectEqual(Status.pass, evaluate(.{ .kind = .rotate, .index = 0 }, mft.ENCODER_ROT_CHANNEL, 0, 65));
    // Counter-clockwise (63 = -1) fails, flagging an inverted direction.
    try std.testing.expectEqual(Status.fail, evaluate(.{ .kind = .rotate, .index = 0 }, mft.ENCODER_ROT_CHANNEL, 0, 63));
    // Wrong CC fails.
    try std.testing.expectEqual(Status.fail, evaluate(.{ .kind = .rotate, .index = 0 }, mft.ENCODER_ROT_CHANNEL, 5, 65));
}

test "wizard: onMidi captures once and holds" {
    var s = WizardState{};
    s.start();
    s.onMidi(mft.ENCODER_ROT_CHANNEL, 0, 65);
    try std.testing.expectEqual(Status.pass, s.results[0].status);
    // A second event for the same step is ignored.
    s.onMidi(mft.ENCODER_ROT_CHANNEL, 0, 63);
    try std.testing.expectEqual(Status.pass, s.results[0].status);
    try std.testing.expectEqual(@as(u8, 65), s.results[0].obs_val);
}
