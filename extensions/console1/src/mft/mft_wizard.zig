const std = @import("std");
const mft = @import("mft.zig");
const mft_state = @import("mft_state.zig");
const log = std.log.scoped(.mft_wizard);

// A guided calibration pass. The wizard walks the user through each control of the layout, listens to the incoming MIDI, and records whether it matched
// what the code expects: the sixteen encoders turned to the right, the first one turned to the left (which checks the relative encoding), the sixteen
// pushes, and the six side keys with their CCs. Then it shows what the controller can only be looked at for, and the user says whether it looks right:
// the colors of the pages on the bottom row, the nine hues of the settings, and the sweep of the rings. The MFT action "MFT: Calibration wizard" opens
// it, and it writes its report to wizard_report.md in the resource folder of REAPER.

pub const StepKind = enum { rotate, rotate_back, press, side, look };

/// What a step that is looked at shows on the controller.
pub const Look = enum {
    /// The bottom row has the color of each page, and the top rows the color of the page in use.
    page_colors,
    /// The first nine encoders have the nine hues of the settings, in the order of the settings.
    hues,
    /// Every ring sweeps from empty to full.
    ring_sweep,
};

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

pub const look_count = @typeInfo(Look).@"enum".field_names.len;
pub const STEP_COUNT = 16 + 1 + 16 + 6 + look_count;

pub const steps: [STEP_COUNT]Step = blk: {
    var s: [STEP_COUNT]Step = undefined;
    var n: usize = 0;
    for (0..16) |i| {
        s[n] = .{ .kind = .rotate, .index = @intCast(i) };
        n += 1;
    }
    s[n] = .{ .kind = .rotate_back, .index = 0 };
    n += 1;
    for (0..16) |i| {
        s[n] = .{ .kind = .press, .index = @intCast(i) };
        n += 1;
    }
    for (0..6) |i| {
        s[n] = .{ .kind = .side, .index = @intCast(i) };
        n += 1;
    }
    for (0..look_count) |i| {
        s[n] = .{ .kind = .look, .index = @intCast(i) };
        n += 1;
    }
    std.debug.assert(n == STEP_COUNT);
    break :blk s;
};

fn evaluate(step: Step, channel: u8, cc: u8, val: u8) Status {
    return switch (step.kind) {
        .rotate => if (channel == mft.ENCODER_ROT_CHANNEL and cc == step.index and mft.decodeRelative(val) > 0)
            .pass
        else
            .fail,
        .rotate_back => if (channel == mft.ENCODER_ROT_CHANNEL and cc == step.index and mft.decodeRelative(val) < 0)
            .pass
        else
            .fail,
        .press => if (channel == mft.ENCODER_BTN_CHANNEL and cc == step.index and val == 127)
            .pass
        else
            .fail,
        .side => if (channel == mft.SIDE_BTN_CHANNEL and cc == mft.SIDE_BUTTON_CCS[step.index] and val == 127) .pass else .fail,
        // A step that is looked at hears nothing: the user says whether it looks right.
        .look => .pending,
    };
}

pub const WizardState = struct {
    active: bool = false,
    current: usize = 0,
    results: [STEP_COUNT]Result = @splat(.{}),
    // LED test: cycles colours and sweeps the rings so the feedback path can be
    // eyeballed. `led_frame` advances once per panel frame.
    led_test_active: bool = false,
    led_frame: u32 = 0,

    pub fn start(self: *WizardState) void {
        self.active = true;
        self.current = 0;
        self.results = @splat(.{});
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
        if (steps[self.current].kind == .look) return;
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

    /// What the controller shows for the step that is looked at, or null when the step listens.
    pub fn look(self: *const WizardState) ?Look {
        if (!self.active) return null;
        const step = steps[self.current];
        if (step.kind != .look) return null;
        return @fromBackingInt(@intCast(step.index));
    }

    /// The user's answer for a step that is looked at.
    pub fn mark(self: *WizardState, status: Status) void {
        std.debug.assert(steps[self.current].kind == .look);
        self.results[self.current] = .{ .status = status, .captured = true };
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
        .rotate => std.mem.printSentinel(buf, "Turn encoder {d} one click clockwise", .{step.index + 1}, 0) catch buf[0..0 :0],
        .rotate_back => std.mem.printSentinel(buf, "Turn encoder {d} one click counter-clockwise", .{step.index + 1}, 0) catch buf[0..0 :0],
        .press => std.mem.printSentinel(buf, "Press encoder {d}", .{step.index + 1}, 0) catch buf[0..0 :0],
        .side => std.mem.printSentinel(buf, "Press side button {s}", .{side_names[step.index]}, 0) catch buf[0..0 :0],
        .look => std.mem.printSentinel(buf, "{s}", .{switch (@as(Look, @fromBackingInt(@intCast(step.index)))) {
            .page_colors => "Look at the bottom row: each encoder has the color of its page, and the top rows the color of TRANSPORT",
            .hues => "Look at the first nine encoders: Input, Shape, EQ, Comp, Output, Settings, Transport, Auto and FX Selection, in their colors",
            .ring_sweep => "Look at the rings: every ring sweeps from empty to full",
        }}, 0) catch buf[0..0 :0],
    };
}

/// The names of the side keys, in the order of their CCs.
const side_names = [6][]const u8{ "L1 (FX chain)", "L2 (bypass)", "L3", "R1 (mute)", "R2 (solo)", "R3 (phase)" };

pub fn expectedText(step: Step, buf: [:0]u8) [:0]const u8 {
    return switch (step.kind) {
        .rotate => std.mem.printSentinel(buf, "expect ch{d} cc{d}, positive delta", .{ mft.ENCODER_ROT_CHANNEL, step.index }, 0) catch buf[0..0 :0],
        .rotate_back => std.mem.printSentinel(buf, "expect ch{d} cc{d}, negative delta", .{ mft.ENCODER_ROT_CHANNEL, step.index }, 0) catch buf[0..0 :0],
        .press => std.mem.printSentinel(buf, "expect ch{d} cc{d}, value 127", .{ mft.ENCODER_BTN_CHANNEL, step.index }, 0) catch buf[0..0 :0],
        .side => std.mem.printSentinel(buf, "expect ch{d} cc{d}, value 127", .{ mft.SIDE_BTN_CHANNEL, mft.SIDE_BUTTON_CCS[step.index] }, 0) catch buf[0..0 :0],
        .look => std.mem.printSentinel(buf, "answer with Looks right or Looks wrong", .{}, 0) catch buf[0..0 :0],
    };
}

pub fn observedText(r: Result, buf: [:0]u8) [:0]const u8 {
    if (r.captured and r.obs_channel == 0 and r.obs_cc == 0 and r.obs_val == 0 and r.status != .pending) return std.mem.printSentinel(buf, "answered", .{}, 0) catch buf[0..0 :0];
    if (!r.captured) return std.mem.printSentinel(buf, "waiting...", .{}, 0) catch buf[0..0 :0];
    return std.mem.printSentinel(buf, "ch{d} cc{d} val{d}", .{ r.obs_channel, r.obs_cc, r.obs_val }, 0) catch buf[0..0 :0];
}

// Write a markdown report of the run to <dir>/wizard_report.md.
pub fn writeReport(self: *const WizardState, io: std.Io, dir: [:0]const u8) !void {
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "{s}{s}wizard_report.md", .{ dir, std.fs.path.sep_str });

    const file = try std.Io.Dir.createFileAbsolute(io, path, .{ .truncate = true });
    defer file.close(io);
    // Because file writers are buffered since Zig 0.15, the writer is flushed before the file closes.
    var w_buffer: [4096]u8 = undefined;
    var w_file_writer = file.writer(io, &w_buffer);
    const w = &w_file_writer.interface;

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
    try w.flush();
}

test "wizard: steps cover all controls, then what is looked at" {
    try std.testing.expectEqual(@as(usize, 42), STEP_COUNT);
    try std.testing.expectEqual(StepKind.rotate, steps[0].kind);
    try std.testing.expectEqual(StepKind.rotate_back, steps[16].kind);
    try std.testing.expectEqual(StepKind.press, steps[17].kind);
    try std.testing.expectEqual(StepKind.side, steps[33].kind);
    try std.testing.expectEqual(StepKind.look, steps[39].kind);
}

test "wizard: a side key passes with its CC, a turn to the left passes the step that asks for it, and a step that is looked at is answered" {
    const t = std.testing;
    try t.expectEqual(Status.pass, evaluate(.{ .kind = .side, .index = 3 }, mft.SIDE_BTN_CHANNEL, mft.SIDE_BUTTON_CCS[3], 127));
    try t.expectEqual(Status.fail, evaluate(.{ .kind = .side, .index = 3 }, mft.SIDE_BTN_CHANNEL, mft.SIDE_BUTTON_CCS[2], 127));
    try t.expectEqual(Status.pass, evaluate(.{ .kind = .rotate_back, .index = 0 }, mft.ENCODER_ROT_CHANNEL, 0, 63));
    var s = WizardState{};
    s.start();
    try t.expectEqual(@as(?Look, null), s.look());
    s.current = 39;
    try t.expectEqual(@as(?Look, .page_colors), s.look());
    s.onMidi(mft.ENCODER_ROT_CHANNEL, 0, 65);
    try t.expectEqual(Status.pending, s.results[39].status);
    s.mark(.pass);
    try t.expectEqual(Status.pass, s.results[39].status);
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
