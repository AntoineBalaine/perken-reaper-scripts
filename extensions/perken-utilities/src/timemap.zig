//! The one home for the extension's time-map queries, all asked of the
//! active project (the bindings take NULL for that).
//!
//! Positions are project quarter notes (QN) or project time in seconds, as
//! named. QN is the domain to prefer: bars are defined in beats, so tempo
//! changes do not affect QN-to-bar arithmetic at all, and a take's
//! PPQ-to-QN mapping accounts for playrate and time stretching, which raw
//! PPQ does not.

const std = @import("std");
const Reaper = @import("reaper").reaper;
const helpers = @import("reaper_helpers");

pub fn qnToTime(qn: f64) f64 {
    return Reaper.TimeMap2_QNToTime(null, qn);
}

pub fn timeToQn(time: f64) f64 {
    return Reaper.TimeMap2_timeToQN(null, time);
}

pub const Signature = struct { num: u32, denom: u32 };

/// The time signature in force at `time`.
pub fn sigAtTime(time: f64) Signature {
    var num: c_int = 4;
    var denom: c_int = 4;
    var tempo: f64 = 120;
    Reaper.TimeMap_GetTimeSigAtTime(null, time, &num, &denom, &tempo);
    // A project always has a signature; clamp anyway so a surprising reply
    // cannot produce a zero-length bar and hang a caller walking bars.
    return .{
        .num = if (num > 0) @intCast(num) else 4,
        .denom = if (denom > 0) @intCast(denom) else 4,
    };
}

/// What one `TimeMap2_timeToBeats` call reports about a position: the
/// measure it falls in and that measure's time-signature denominator.
/// Both come back together because they come from the same call.
pub const BeatsInfo = struct {
    measure: c_int,
    /// The denominator REAPER reports for this measure, never zero.
    denominator: c_int,
};

pub fn beatsInfoAtTime(time: f64) BeatsInfo {
    var measure: c_int = 0;
    var denominator: c_int = 4;
    _ = Reaper.TimeMap2_timeToBeats(null, time, &measure, null, null, &denominator);
    return .{ .measure = measure, .denominator = if (denominator > 0) denominator else 4 };
}

/// The measure index containing `time`, as REAPER counts them.
pub fn measureAtTime(time: f64) c_int {
    return beatsInfoAtTime(time).measure;
}

/// The time at which measure `measure` begins. Asking REAPER for the
/// measure's own start, rather than adding up nominal bar lengths, is what
/// keeps partial bars (a time-signature marker placed off a barline)
/// honest: REAPER's grid is what the user sees.
///
pub fn measureStartTime(measure: c_int) f64 {
    return helpers.timeMap2BeatsToTime(0.0, measure);
}

/// REAPER's "divided" BPM at `time`: the tempo marker's value scaled by the
/// time signature (doubled in /8 signatures, for instance). `tempoAt`
/// converts it back; callers wanting the raw scaled figure use this.
pub fn dividedBpmAtTime(time: f64) f64 {
    return Reaper.TimeMap2_GetDividedBpmAtTime(null, time);
}

/// The tempo marker value in effect at `time`, undoing the division above
/// with the measure's own denominator.
pub fn tempoAt(time: f64) f64 {
    const denominator = beatsInfoAtTime(time).denominator;
    return dividedBpmAtTime(time) * 4.0 / @as(f64, @floatFromInt(denominator));
}

/// The take-PPQ position where the measure containing `ppq` begins.
///
/// A separate REAPER call from the measure walk above, and the right one
/// when the answer is wanted in a take's own PPQ domain; kept here so every
/// bar-line lookup in the extension goes through one module.
pub fn barStartPpq(take: *Reaper.MediaItem_Take, ppq: f64) f64 {
    return Reaper.MIDI_GetPPQPos_StartOfMeasure(take, ppq);
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
