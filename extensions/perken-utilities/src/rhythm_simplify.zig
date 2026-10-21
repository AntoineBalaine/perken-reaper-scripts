//! Simplifies quantized note/rest sequences within a bar into fewer, more
//! readable symbols, following two engraving principles: a note's notated
//! span must never cross a primary beat boundary without a tie, and among
//! notations that preserve the same onsets and total duration without
//! crossing a beat, the one with the fewest noteheads/rests is preferred.
//!
//! Durations are rationals in units of whole notes (a quarter note is
//! 1/4), matching this codebase's existing rational time-map convention —
//! independent of any particular PPQ grid resolution. Callers convert
//! to/from PPQ at the boundary (see kawa.zig's QN-based note snapshots).

const std = @import("std");

pub const Rational = struct {
    num: i64,
    den: i64, // always > 0; fraction kept in lowest terms.

    pub fn of(num: i64, den: i64) Rational {
        std.debug.assert(den != 0);
        var n = num;
        var d = den;
        if (d < 0) {
            n = -n;
            d = -d;
        }
        const g = gcd(if (n < 0) -n else n, d);
        if (g != 0) {
            n = @divExact(n, g);
            d = @divExact(d, g);
        }
        return .{ .num = n, .den = d };
    }

    fn gcd(a: i64, b: i64) i64 {
        var x = a;
        var y = b;
        while (y != 0) {
            const t = y;
            y = @mod(x, y);
            x = t;
        }
        return x;
    }

    pub fn add(a: Rational, b: Rational) Rational {
        return of(a.num * b.den + b.num * a.den, a.den * b.den);
    }

    pub fn eq(a: Rational, b: Rational) bool {
        return a.num == b.num and a.den == b.den;
    }

    pub fn lt(a: Rational, b: Rational) bool {
        return a.num * b.den < b.num * a.den;
    }

    pub fn lte(a: Rational, b: Rational) bool {
        return a.lt(b) or a.eq(b);
    }

    pub fn zero() Rational {
        return .{ .num = 0, .den = 1 };
    }
};

/// Common time signatures only (see module decisions): no mid-bar meter
/// changes, no tuplets yet. `beat` is the duration, in whole notes, of one
/// primary beat for the purpose of the beat-boundary guard — a quarter for
/// simple meters, a dotted quarter (3/8) for compound ones.
pub const TimeSig = struct {
    bar_len: Rational,
    beat: Rational,

    pub const four_four = TimeSig{ .bar_len = Rational.of(1, 1), .beat = Rational.of(1, 4) };
    pub const three_four = TimeSig{ .bar_len = Rational.of(3, 4), .beat = Rational.of(1, 4) };
    pub const two_four = TimeSig{ .bar_len = Rational.of(1, 2), .beat = Rational.of(1, 4) };
    pub const six_eight = TimeSig{ .bar_len = Rational.of(3, 4), .beat = Rational.of(3, 8) };
    pub const twelve_eight = TimeSig{ .bar_len = Rational.of(3, 2), .beat = Rational.of(3, 8) };

    /// Beat-boundary positions within the bar, from 0 up to (excluding)
    /// bar_len, as absolute offsets in whole notes.
    pub fn beatBoundaries(self: TimeSig, buf: []Rational) []Rational {
        var pos = Rational.zero();
        var i: usize = 0;
        while (pos.lt(self.bar_len)) {
            buf[i] = pos;
            i += 1;
            pos = pos.add(self.beat);
        }
        return buf[0..i];
    }
};

pub const Kind = enum { note, rest };

pub const Event = struct {
    kind: Kind,
    dur: Rational,
    /// Set on a note produced by collapsing a note+rest pair, so the
    /// caller can render it as a staccato notehead to preserve the
    /// original short articulation.
    staccato: bool = false,
};

/// True if a span starting at `onset` with length `dur` crosses any beat
/// boundary strictly inside it (touching a boundary at either end is fine —
/// that is what makes the span valid in the first place).
fn crossesABeat(time_sig: TimeSig, onset: Rational, dur: Rational) bool {
    var buf: [64]Rational = undefined;
    const boundaries = time_sig.beatBoundaries(&buf);
    const end = onset.add(dur);
    for (boundaries) |b| {
        if (onset.lt(b) and b.lt(end)) return true;
    }
    return false;
}

/// One fixed-point pass: collapses every adjacent (note, rest) pair of
/// equal duration into a single staccato note of double the duration,
/// provided the merged note's span does not cross a beat boundary. Events
/// must already tile the bar exactly (each one starts where the previous
/// one ends) — that invariant is never changed by this function.
fn collapsePass(allocator: std.mem.Allocator, time_sig: TimeSig, events: []const Event) !struct { out: []Event, changed: bool } {
    var out = try std.ArrayList(Event).initCapacity(allocator, events.len);
    errdefer out.deinit();
    var onset = Rational.zero();
    var changed = false;
    var i: usize = 0;
    while (i < events.len) {
        const a = events[i];
        if (i + 1 < events.len) {
            const b = events[i + 1];
            if (a.kind == .note and b.kind == .rest and a.dur.eq(b.dur)) {
                const merged_dur = a.dur.add(b.dur);
                if (!crossesABeat(time_sig, onset, merged_dur)) {
                    try out.append(.{ .kind = .note, .dur = merged_dur, .staccato = true });
                    onset = onset.add(merged_dur);
                    i += 2;
                    changed = true;
                    continue;
                }
            }
        }
        try out.append(a);
        onset = onset.add(a.dur);
        i += 1;
    }
    return .{ .out = try out.toOwnedSlice(), .changed = changed };
}

/// Simplifies a bar's worth of events to a fixed point: repeatedly applies
/// `collapsePass` until a full pass makes no further change. Total
/// duration and every onset position are preserved exactly — only the
/// number of symbols used to represent them can shrink.
pub fn simplifyBar(allocator: std.mem.Allocator, time_sig: TimeSig, events: []const Event) ![]Event {
    var current = try allocator.dupe(Event, events);
    while (true) {
        const pass = try collapsePass(allocator, time_sig, current);
        allocator.free(current);
        current = pass.out;
        if (!pass.changed) break;
    }
    return current;
}

fn totalDur(events: []const Event) Rational {
    var total = Rational.zero();
    for (events) |e| total = total.add(e.dur);
    return total;
}

test "eighth note + eighth rest, twice, collapses to two staccato quarters" {
    const allocator = std.testing.allocator;
    const e8 = Rational.of(1, 8);
    const events = [_]Event{
        .{ .kind = .note, .dur = e8 },
        .{ .kind = .rest, .dur = e8 },
        .{ .kind = .note, .dur = e8 },
        .{ .kind = .rest, .dur = e8 },
    };
    const out = try simplifyBar(allocator, TimeSig.four_four, &events);
    defer allocator.free(out);

    try std.testing.expectEqual(@as(usize, 2), out.len);
    for (out) |e| {
        try std.testing.expectEqual(Kind.note, e.kind);
        try std.testing.expect(e.dur.eq(Rational.of(1, 4)));
        try std.testing.expect(e.staccato);
    }
    try std.testing.expect(totalDur(&events).eq(totalDur(out)));
}

test "a pair that would cross a beat boundary is left alone" {
    const allocator = std.testing.allocator;
    // In 4/4, a dotted-eighth note followed by a dotted-eighth rest starting
    // on beat 1 (offset 1/4) would end at 1/4 + 3/16 + 3/16 = 5/8, crossing
    // the beat-3 boundary at 1/2 — must not be collapsed.
    const d8 = Rational.of(3, 16);
    const events = [_]Event{
        .{ .kind = .note, .dur = Rational.of(1, 4) }, // fills beat 1
        .{ .kind = .note, .dur = d8 },
        .{ .kind = .rest, .dur = d8 },
    };
    const out = try simplifyBar(allocator, TimeSig.four_four, &events);
    defer allocator.free(out);

    try std.testing.expectEqual(@as(usize, 3), out.len);
    try std.testing.expect(totalDur(&events).eq(totalDur(out)));
}

test "nothing to collapse leaves the bar untouched" {
    const allocator = std.testing.allocator;
    const events = [_]Event{
        .{ .kind = .note, .dur = Rational.of(1, 4) },
        .{ .kind = .note, .dur = Rational.of(1, 4) },
        .{ .kind = .note, .dur = Rational.of(1, 4) },
        .{ .kind = .note, .dur = Rational.of(1, 4) },
    };
    const out = try simplifyBar(allocator, TimeSig.four_four, &events);
    defer allocator.free(out);
    try std.testing.expectEqual(@as(usize, 4), out.len);
}

test "6/8 beat boundaries are the dotted-quarter grouping, not every eighth" {
    var buf: [8]Rational = undefined;
    const b = TimeSig.six_eight.beatBoundaries(&buf);
    try std.testing.expectEqual(@as(usize, 2), b.len);
    try std.testing.expect(b[0].eq(Rational.zero()));
    try std.testing.expect(b[1].eq(Rational.of(3, 8)));
}
