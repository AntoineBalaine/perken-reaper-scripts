//! Null-safe wrappers over REAPER's time map.
//!
//! The generated bindings type `proj` and the optional out-parameters of
//! these functions as non-null pointers, while the C API takes NULL for the
//! active project and for every output a caller does not want. Each wrapper
//! below re-types its function through the signature the C API actually
//! has, which is the same trick abc_export.zig already uses for
//! `TimeMap_GetTimeSigAtTime` — gathered here so there is one copy.
//!
//! Positions are project quarter notes (QN) or project time in seconds, as
//! named. QN is the domain to prefer: bars are defined in beats, so tempo
//! changes do not affect QN-to-bar arithmetic at all, and a take's
//! PPQ-to-QN mapping accounts for playrate and time stretching, which raw
//! PPQ does not.

const std = @import("std");
const Reaper = @import("reaper").reaper;

pub fn qnToTime(qn: f64) f64 {
    const f: *const fn (proj: ?*anyopaque, qn: f64) callconv(.C) f64 = @ptrCast(Reaper.TimeMap2_QNToTime);
    return f(null, qn);
}

pub fn timeToQn(time: f64) f64 {
    const f: *const fn (proj: ?*anyopaque, time: f64) callconv(.C) f64 = @ptrCast(Reaper.TimeMap2_timeToQN);
    return f(null, time);
}

pub const Signature = struct { num: u32, denom: u32 };

/// The time signature in force at `time`.
pub fn sigAtTime(time: f64) Signature {
    const f: *const fn (proj: ?*anyopaque, time: f64, num: *c_int, denom: *c_int, tempo: *f64) callconv(.C) void =
        @ptrCast(Reaper.TimeMap_GetTimeSigAtTime);
    var num: c_int = 4;
    var denom: c_int = 4;
    var tempo: f64 = 120;
    f(null, time, &num, &denom, &tempo);
    // A project always has a signature; clamp anyway so a surprising reply
    // cannot produce a zero-length bar and hang a caller walking bars.
    return .{
        .num = if (num > 0) @intCast(num) else 4,
        .denom = if (denom > 0) @intCast(denom) else 4,
    };
}

/// The measure index containing `time`, as REAPER counts them.
pub fn measureAtTime(time: f64) c_int {
    const f: *const fn (
        proj: ?*anyopaque,
        tpos: f64,
        measures: ?*c_int,
        cml: ?*c_int,
        fullbeats: ?*f64,
        cdenom: ?*c_int,
    ) callconv(.C) f64 = @ptrCast(Reaper.TimeMap2_timeToBeats);
    var measure: c_int = 0;
    _ = f(null, time, &measure, null, null, null);
    return measure;
}

/// The time at which measure `measure` begins. Asking REAPER for the
/// measure's own start, rather than adding up nominal bar lengths, is what
/// keeps partial bars (a time-signature marker placed off a barline)
/// honest: REAPER's grid is what the user sees.
pub fn measureStartTime(measure: c_int) f64 {
    const f: *const fn (proj: ?*anyopaque, tpos: f64, measures: ?*const c_int) callconv(.C) f64 =
        @ptrCast(Reaper.TimeMap2_beatsToTime);
    var m = measure;
    return f(null, 0.0, &m);
}

/// The QN position where the measure containing `qn` begins.
pub fn barStartQn(qn: f64) f64 {
    const time = qnToTime(qn);
    return timeToQn(measureStartTime(measureAtTime(time)));
}

/// The QN position where the measure after the one containing `qn` begins.
pub fn nextBarStartQn(qn: f64) f64 {
    const time = qnToTime(qn);
    return timeToQn(measureStartTime(measureAtTime(time) + 1));
}

/// The time signature in force at a QN position.
pub fn sigAtQn(qn: f64) Signature {
    return sigAtTime(qnToTime(qn));
}

// ---- walking the bar grid -----------------------------------------------------

/// Where bars and signatures come from. `reaperBarSource` is the real one;
/// the seam exists so everything built on the walk below can be tested
/// against a synthetic grid — meter changes, short bars, a grid that stops
/// reporting — without a REAPER host.
pub const BarSource = struct {
    ctx: ?*anyopaque = null,
    /// QN where the bar containing `qn` begins.
    barStartQn: *const fn (?*anyopaque, f64) f64,
    /// QN where the bar after the one containing `qn` begins.
    nextBarStartQn: *const fn (?*anyopaque, f64) f64,
    /// The signature in force at `qn`.
    sigAtQn: *const fn (?*anyopaque, f64) Signature,
};

fn reaperBarStart(_: ?*anyopaque, qn: f64) f64 {
    return barStartQn(qn);
}
fn reaperNextBarStart(_: ?*anyopaque, qn: f64) f64 {
    return nextBarStartQn(qn);
}
fn reaperSigAt(_: ?*anyopaque, qn: f64) Signature {
    return sigAtQn(qn);
}

pub fn reaperBarSource() BarSource {
    return .{
        .barStartQn = &reaperBarStart,
        .nextBarStartQn = &reaperNextBarStart,
        .sigAtQn = &reaperSigAt,
    };
}

pub const Bar = struct {
    start_qn: f64,
    end_qn: f64,
    sig: Signature,
};

/// Guards against a source that never advances. A selection of a few hours
/// is well under this.
pub const max_bars = 100_000;

/// Walks the bars overlapping [from_qn, to_qn), one at a time as the source
/// reports them, so a meter change or a short bar inside the span is
/// described rather than assumed away.
///
/// A source that stops advancing ends the walk instead of spinning: an
/// infinite loop here would hang REAPER, which is worse than a short answer
/// for every caller.
pub const BarWalker = struct {
    src: BarSource,
    to_qn: f64,
    at_qn: f64,
    seen: usize = 0,
    done: bool = false,

    pub fn next(self: *BarWalker) ?Bar {
        if (self.done or self.seen >= max_bars) return null;
        const sig = self.src.sigAtQn(self.src.ctx, self.at_qn);
        const next_qn = self.src.nextBarStartQn(self.src.ctx, self.at_qn);
        const bar = Bar{
            .start_qn = self.at_qn,
            // A stalled source leaves no end to report, so fall back to the
            // signature's own bar length: num/denom quarter notes.
            .end_qn = if (next_qn > self.at_qn)
                next_qn
            else
                self.at_qn + 4.0 * @as(f64, @floatFromInt(sig.num)) / @as(f64, @floatFromInt(sig.denom)),
            .sig = sig,
        };
        self.seen += 1;
        if (!(next_qn > self.at_qn) or !(next_qn < self.to_qn)) {
            self.done = true;
        } else {
            self.at_qn = next_qn;
        }
        return bar;
    }
};

pub fn walkBars(src: BarSource, from_qn: f64, to_qn: f64) BarWalker {
    return .{ .src = src, .to_qn = to_qn, .at_qn = src.barStartQn(src.ctx, from_qn) };
}

// ---- tests -------------------------------------------------------------------

/// A synthetic bar grid, so the walk can be tested without REAPER.
pub const FakeGrid = struct {
    /// Bar starts in QN, ascending, with one more entry than there are bars
    /// so the last bar has an end.
    starts: []const f64,
    sigs: []const Signature,

    fn barIndex(self: *const FakeGrid, qn: f64) usize {
        var i: usize = 0;
        while (i + 1 < self.starts.len and self.starts[i + 1] <= qn) i += 1;
        // Past the last described bar there is no signature to report, so
        // hold at the last one — that is the stalling case the walk has to
        // survive.
        return @min(i, self.sigs.len - 1);
    }

    fn fakeBarStart(ptr: ?*anyopaque, qn: f64) f64 {
        const self: *const FakeGrid = @ptrCast(@alignCast(ptr.?));
        return self.starts[self.barIndex(qn)];
    }
    fn fakeNextBarStart(ptr: ?*anyopaque, qn: f64) f64 {
        const self: *const FakeGrid = @ptrCast(@alignCast(ptr.?));
        const i = self.barIndex(qn);
        return if (i + 1 < self.starts.len) self.starts[i + 1] else self.starts[self.starts.len - 1];
    }
    fn fakeSigAt(ptr: ?*anyopaque, qn: f64) Signature {
        const self: *const FakeGrid = @ptrCast(@alignCast(ptr.?));
        return self.sigs[self.barIndex(qn)];
    }

    pub fn source(self: *const FakeGrid) BarSource {
        return .{
            .ctx = @constCast(@ptrCast(self)),
            .barStartQn = &fakeBarStart,
            .nextBarStartQn = &fakeNextBarStart,
            .sigAtQn = &fakeSigAt,
        };
    }
};

test "the walk reports each bar with the signature in force there" {
    // 4/4 at QN 0, then 3/4 from QN 4.
    const grid = FakeGrid{
        .starts = &.{ 0, 4, 7, 10 },
        .sigs = &.{ .{ .num = 4, .denom = 4 }, .{ .num = 3, .denom = 4 }, .{ .num = 3, .denom = 4 } },
    };
    var it = walkBars(grid.source(), 0, 10);

    const a = it.next().?;
    try std.testing.expectEqual(@as(f64, 0), a.start_qn);
    try std.testing.expectEqual(@as(f64, 4), a.end_qn);
    try std.testing.expectEqual(@as(u32, 4), a.sig.num);

    const b = it.next().?;
    try std.testing.expectEqual(@as(f64, 4), b.start_qn);
    try std.testing.expectEqual(@as(u32, 3), b.sig.num);

    const c = it.next().?;
    try std.testing.expectEqual(@as(f64, 7), c.start_qn);
    try std.testing.expectEqual(@as(f64, 10), c.end_qn);
    try std.testing.expect(it.next() == null);
}

test "the walk starts at the bar containing the span, not at the span" {
    const grid = FakeGrid{
        .starts = &.{ 0, 4, 8 },
        .sigs = &.{ .{ .num = 4, .denom = 4 }, .{ .num = 4, .denom = 4 } },
    };
    // Asking from the middle of the second bar starts at its barline.
    var it = walkBars(grid.source(), 5.5, 7);
    const bar = it.next().?;
    try std.testing.expectEqual(@as(f64, 4), bar.start_qn);
}

test "a short bar keeps the length the grid gives it" {
    const grid = FakeGrid{
        .starts = &.{ 0, 3, 7 },
        .sigs = &.{ .{ .num = 4, .denom = 4 }, .{ .num = 4, .denom = 4 } },
    };
    var it = walkBars(grid.source(), 0, 5);
    const bar = it.next().?;
    try std.testing.expectEqual(@as(f64, 3), bar.end_qn);
}

test "a grid that stops advancing ends the walk instead of hanging" {
    const grid = FakeGrid{ .starts = &.{ 0, 4 }, .sigs = &.{.{ .num = 4, .denom = 4 }} };
    var it = walkBars(grid.source(), 0, 1000);
    var count: usize = 0;
    while (it.next()) |_| {
        count += 1;
        if (count > max_bars) break;
    }
    try std.testing.expect(count > 0);
    try std.testing.expect(count < max_bars);
}
