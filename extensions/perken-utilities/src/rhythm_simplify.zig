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
    /// Set on a note that is tied into the next event, which is also a
    /// note — the two noteheads represent one continuous sound split only
    /// because a single notehead cannot cross a beat boundary. Rests are
    /// never tied (there is no such thing as a tied rest), so this is
    /// always false on a rest.
    tied_to_next: bool = false,
};

/// Standard note/rest values, in units of whole notes, descending. Dotted
/// values included — a dot is "half again," always itself one borderline
/// bigger than the next plain value down — so greedily taking the largest
/// value that fits is always optimal (never leaves a remainder that needs
/// more symbols than picking a smaller value first would have). Binary
/// subdivision only for now, matching the common-meters-only scope — no
/// tuplets.
const standard_values = [_]Rational{
    Rational{ .num = 1, .den = 1 }, // whole
    Rational{ .num = 3, .den = 4 }, // dotted half
    Rational{ .num = 1, .den = 2 }, // half
    Rational{ .num = 3, .den = 8 }, // dotted quarter (a compound beat)
    Rational{ .num = 1, .den = 4 }, // quarter
    Rational{ .num = 3, .den = 16 }, // dotted eighth
    Rational{ .num = 1, .den = 8 }, // eighth
    Rational{ .num = 3, .den = 32 }, // dotted sixteenth
    Rational{ .num = 1, .den = 16 }, // sixteenth
    Rational{ .num = 3, .den = 64 }, // dotted thirty-second
    Rational{ .num = 1, .den = 32 }, // thirty-second
};

/// True if a span starting at `onset` with length `dur` crosses any beat
/// boundary strictly inside it (touching a boundary at either end is fine —
/// that is what makes the span valid in the first place). Exported for
/// callers (tests included) that want to verify this externally rather
/// than trust it was applied correctly inside this module.
pub fn crossesABeat(time_sig: TimeSig, onset: Rational, dur: Rational) bool {
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

/// Re-tiles one maximal same-kind run — total length `len` starting at
/// `onset`, all of kind `kind` — into standard values: mandatory splits at
/// every beat boundary inside it (a single symbol never crosses one), then
/// within each boundary-respecting stretch, greedily take the largest
/// standard value that fits, repeatedly, which this candidate set makes
/// optimal (see `standard_values`). Adjacent note pieces coming from the
/// same original run are tied together, since they are one continuous
/// sound notated as several noteheads only because of the beat-boundary
/// rule; adjacent rest pieces are not tied (rests cannot be).
fn retileRun(allocator: std.mem.Allocator, time_sig: TimeSig, onset: Rational, len: Rational, kind: Kind) ![]Event {
    var out = std.ArrayList(Event).init(allocator);
    errdefer out.deinit();

    var buf: [64]Rational = undefined;
    const boundaries = time_sig.beatBoundaries(&buf);
    const run_end = onset.add(len);

    // Index of the first beat boundary strictly after onset — boundaries
    // at or before onset don't split anything, they're where we start.
    var bi: usize = 0;
    while (bi < boundaries.len and boundaries[bi].lte(onset)) : (bi += 1) {}

    var seg_start = onset;
    while (true) {
        const seg_end = if (bi < boundaries.len and boundaries[bi].lt(run_end)) boundaries[bi] else run_end;

        // Fill [seg_start, seg_end), the next beat-boundary-respecting
        // stretch, greedily with the largest standard value that fits.
        var p = seg_start;
        while (p.lt(seg_end)) {
            const left = seg_end.add(negate(p));
            var step = left; // if nothing standard fits (shouldn't happen for dyadic inputs), take the whole remainder as one odd symbol.
            for (standard_values) |v| {
                if (v.lte(left)) {
                    step = v;
                    break;
                }
            }
            try out.append(.{ .kind = kind, .dur = step });
            p = p.add(step);
        }
        if (!seg_end.lt(run_end)) break;
        seg_start = seg_end;
        bi += 1;
    }

    // Tie every note piece to the next, except the last — adjacent pieces
    // from the same run are one continuous sound split only by the beat
    // boundary rule. Rests have no such concept.
    if (kind == .note) {
        for (out.items[0 .. out.items.len -| 1]) |*e| e.tied_to_next = true;
    }
    return out.toOwnedSlice();
}

fn negate(a: Rational) Rational {
    return Rational.of(-a.num, a.den);
}

/// One fixed-point pass: re-tiles every maximal run of consecutive rests
/// into the fewest standard-value symbols (see `retileRun`). Notes are
/// left alone here — unlike rests, two adjacent note events are not
/// safely mergeable without knowing they are the same pitch (one
/// sustained sound quantization-split into pieces, versus two
/// deliberately separate notes played back to back), and `Event` carries
/// no pitch. Silence has no such ambiguity, so rest runs are always safe
/// to re-tile.
fn retilePass(allocator: std.mem.Allocator, time_sig: TimeSig, events: []const Event) !struct { out: []Event, changed: bool } {
    var out = std.ArrayList(Event).init(allocator);
    errdefer out.deinit();
    var onset = Rational.zero();
    var changed = false;
    var i: usize = 0;
    while (i < events.len) {
        const start = i;
        const kind = events[i].kind;
        const run_onset = onset;
        var run_len = Rational.zero();
        while (i < events.len and events[i].kind == kind and kind == .rest) {
            run_len = run_len.add(events[i].dur);
            onset = onset.add(events[i].dur);
            i += 1;
        }
        if (i == start) {
            // A note (not retiled here, see the doc comment above) passes
            // through untouched, as its own run of one.
            try out.append(events[i]);
            onset = onset.add(events[i].dur);
            i += 1;
            continue;
        }
        const retiled = try retileRun(allocator, time_sig, run_onset, run_len, kind);
        defer allocator.free(retiled);
        if (retiled.len != i - start) changed = true else {
            for (retiled, events[start..i]) |r, orig| {
                if (!r.dur.eq(orig.dur)) {
                    changed = true;
                    break;
                }
            }
        }
        try out.appendSlice(retiled);
    }
    return .{ .out = try out.toOwnedSlice(), .changed = changed };
}

/// Simplifies a bar's worth of events to a fixed point: repeatedly re-tiles
/// same-kind runs into the fewest standard values (`retilePass`), then
/// collapses equal-length note+rest pairs into a staccato note
/// (`collapsePass`), until a full round makes no further change. Total
/// duration and every onset position are preserved exactly — only the
/// number and shape of the symbols representing them can change.
pub fn simplifyBar(allocator: std.mem.Allocator, time_sig: TimeSig, events: []const Event) ![]Event {
    var current = try allocator.dupe(Event, events);
    while (true) {
        const retiled = try retilePass(allocator, time_sig, current);
        allocator.free(current);
        current = retiled.out;

        const collapsed = try collapsePass(allocator, time_sig, current);
        allocator.free(current);
        current = collapsed.out;

        if (!retiled.changed and !collapsed.changed) break;
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
    // In 4/4: an eighth note at [0, 1/8), another at [1/8, 1/4) (so it ends
    // exactly on the beat-2 boundary — fine on its own), then an eighth
    // rest at [1/4, 3/8) (starts exactly on that boundary — also fine on
    // its own). Merging the second note with the rest would span
    // [1/8, 3/8), which strictly contains the 1/4 boundary — must not be
    // collapsed, even though neither piece crosses it alone.
    const e8 = Rational.of(1, 8);
    const events = [_]Event{
        .{ .kind = .note, .dur = e8 },
        .{ .kind = .note, .dur = e8 },
        .{ .kind = .rest, .dur = e8 },
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

test "four sixteenth rests on the beat collapse to one quarter rest" {
    const allocator = std.testing.allocator;
    const s16 = Rational.of(1, 16);
    const events = [_]Event{
        .{ .kind = .rest, .dur = s16 },
        .{ .kind = .rest, .dur = s16 },
        .{ .kind = .rest, .dur = s16 },
        .{ .kind = .rest, .dur = s16 },
    };
    const out = try simplifyBar(allocator, TimeSig.four_four, &events);
    defer allocator.free(out);

    try std.testing.expectEqual(@as(usize, 1), out.len);
    try std.testing.expectEqual(Kind.rest, out[0].kind);
    try std.testing.expect(out[0].dur.eq(Rational.of(1, 4)));
}

test "a rest run spanning a beat boundary retiles into two pieces, not one" {
    const allocator = std.testing.allocator;
    const s16 = Rational.of(1, 16);
    // Six sixteenth rests starting at offset 3/16 (the fourth sixteenth of
    // beat 1) span beats 1 and 2: 1/16 left in beat 1, then 5/16 of beat
    // 2. A single rest symbol can't cross the beat-2 boundary at 1/4, so
    // this must retile to (at least) two rests, never one.
    var six: [6]Event = undefined;
    for (&six) |*e| e.* = .{ .kind = .rest, .dur = s16 };
    const lead_in = Event{ .kind = .note, .dur = Rational.of(3, 16) };
    var full = [_]Event{lead_in} ++ six ++ [_]Event{Event{ .kind = .note, .dur = Rational.of(7, 16) }};
    const out = try simplifyBar(allocator, TimeSig.four_four, &full);
    defer allocator.free(out);

    var rest_pieces: usize = 0;
    for (out) |e| {
        if (e.kind == .rest) rest_pieces += 1;
    }
    try std.testing.expect(rest_pieces >= 2);
    try std.testing.expect(rest_pieces < 6);
    try std.testing.expect(totalDur(&full).eq(totalDur(out)));
}

test "two adjacent note events are never merged — pitch is unknown" {
    const allocator = std.testing.allocator;
    const s16 = Rational.of(1, 16);
    // Four consecutive sixteenth notes, same shape as the rest-merging
    // test above, but as notes: must come out exactly as given, since
    // nothing here says they are one sustained pitch rather than four
    // separate ones.
    const events = [_]Event{
        .{ .kind = .note, .dur = s16 },
        .{ .kind = .note, .dur = s16 },
        .{ .kind = .note, .dur = s16 },
        .{ .kind = .note, .dur = s16 },
    };
    const out = try simplifyBar(allocator, TimeSig.four_four, &events);
    defer allocator.free(out);
    try std.testing.expectEqual(@as(usize, 4), out.len);
    for (out) |e| try std.testing.expect(e.dur.eq(s16));
}

test "6/8 beat boundaries are the dotted-quarter grouping, not every eighth" {
    var buf: [8]Rational = undefined;
    const b = TimeSig.six_eight.beatBoundaries(&buf);
    try std.testing.expectEqual(@as(usize, 2), b.len);
    try std.testing.expect(b[0].eq(Rational.zero()));
    try std.testing.expect(b[1].eq(Rational.of(3, 8)));
}
