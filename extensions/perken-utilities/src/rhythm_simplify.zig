//! Simplifies quantized note/rest sequences within a bar into the fewest,
//! most readable symbols a reader expects at each position.
//!
//! The governing rule is metric hierarchy, not a flat "a symbol may never
//! cross a beat": a bar subdivides into halves (or thirds), those into
//! beats, beats into their own divisions, and so on, and one notated symbol
//! may only span an exact node of that tree. That is what makes a whole
//! rest right for a full 4/4 bar and a half rest right on beat 1, while a
//! half rest starting on beat 2 is wrong — all three span a beat boundary,
//! but only the first two line up with the hierarchy. A span matching no
//! single node becomes several symbols: consecutive rests, or tied
//! noteheads for one note, since a sustained note that outgrows its node is
//! notated as tied pieces rather than moved.
//!
//! What this never does is merge two adjacent note events. Each note event
//! is one performed attack; collapsing two of them into one tie would
//! delete an attack, which changes the music rather than its notation. A
//! single note's own span may still be split into tied pieces — there is
//! only ever one attack there, and the tie is how notation writes it.
//! Consecutive rests have no such constraint: silence is silence, so a run
//! of them is one span to re-tile.
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

    pub fn sub(a: Rational, b: Rational) Rational {
        return a.add(.{ .num = -b.num, .den = b.den });
    }

    pub fn divInt(a: Rational, n: i64) Rational {
        return of(a.num, a.den * n);
    }

    pub fn mulInt(a: Rational, n: i64) Rational {
        return of(a.num * n, a.den);
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

    pub fn min(a: Rational, b: Rational) Rational {
        return if (a.lt(b)) a else b;
    }

    pub fn max(a: Rational, b: Rational) Rational {
        return if (a.lt(b)) b else a;
    }

    pub fn zero() Rational {
        return .{ .num = 0, .den = 1 };
    }

    /// True if `a` is an exact whole multiple of `unit` — the alignment
    /// test for whether a dotted value may sit at a given onset.
    pub fn isMultipleOf(a: Rational, unit: Rational) bool {
        // a / unit = (a.num * unit.den) / (a.den * unit.num)
        const n = a.num * unit.den;
        const d = a.den * unit.num;
        return @rem(n, d) == 0;
    }
};

/// A time signature as its metric hierarchy: `bar_len` subdivided by each
/// factor in `divisions` in turn, so 4/4 is a bar halved into two half
/// bars, each halved into beats, and so on, while 6/8 is a bar halved into
/// two dotted-quarter beats, each split into three eighths. Only the common
/// meters for now, and no mid-bar meter changes or tuplets.
pub const TimeSig = struct {
    bar_len: Rational,
    /// One primary beat — reported for callers; the hierarchy below is what
    /// actually decides which symbols are legal where.
    beat: Rational,
    /// Subdivision factors from the bar down to a thirty-second.
    divisions: []const u8,

    pub const four_four = TimeSig{
        .bar_len = Rational{ .num = 1, .den = 1 },
        .beat = Rational{ .num = 1, .den = 4 },
        .divisions = &.{ 2, 2, 2, 2, 2 }, // 1 → 1/2 → 1/4 → 1/8 → 1/16 → 1/32
    };
    pub const three_four = TimeSig{
        .bar_len = Rational{ .num = 3, .den = 4 },
        .beat = Rational{ .num = 1, .den = 4 },
        .divisions = &.{ 3, 2, 2, 2 }, // 3/4 → 1/4 → 1/8 → 1/16 → 1/32
    };
    pub const two_four = TimeSig{
        .bar_len = Rational{ .num = 1, .den = 2 },
        .beat = Rational{ .num = 1, .den = 4 },
        .divisions = &.{ 2, 2, 2, 2 }, // 1/2 → 1/4 → 1/8 → 1/16 → 1/32
    };
    pub const six_eight = TimeSig{
        .bar_len = Rational{ .num = 3, .den = 4 },
        .beat = Rational{ .num = 3, .den = 8 },
        .divisions = &.{ 2, 3, 2, 2 }, // 3/4 → 3/8 → 1/8 → 1/16 → 1/32
    };
    pub const twelve_eight = TimeSig{
        .bar_len = Rational{ .num = 3, .den = 2 },
        .beat = Rational{ .num = 3, .den = 8 },
        .divisions = &.{ 2, 2, 3, 2, 2 }, // 3/2 → 3/4 → 3/8 → 1/8 → 1/16 → 1/32
    };

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
    /// note: both noteheads are one continuous sound, written as several
    /// because no single symbol spans that position. Always false on a
    /// rest — there is no such thing as a tied rest.
    tied_to_next: bool = false,
};

/// Single-symbol durations: plain values and their dotted (3/2) forms. A
/// dotted value is always exactly three of the next value down.
const standard_values = [_]Rational{
    .{ .num = 3, .den = 2 }, // dotted whole
    .{ .num = 1, .den = 1 }, // whole
    .{ .num = 3, .den = 4 }, // dotted half
    .{ .num = 1, .den = 2 }, // half
    .{ .num = 3, .den = 8 }, // dotted quarter
    .{ .num = 1, .den = 4 }, // quarter
    .{ .num = 3, .den = 16 }, // dotted eighth
    .{ .num = 1, .den = 8 }, // eighth
    .{ .num = 3, .den = 32 }, // dotted sixteenth
    .{ .num = 1, .den = 16 }, // sixteenth
    .{ .num = 1, .den = 32 }, // thirty-second
};

fn isStandardValue(d: Rational) bool {
    for (standard_values) |v| {
        if (v.eq(d)) return true;
    }
    return false;
}

/// Enough room for the pieces any one span in these meters can need.
pub const max_pieces = 64;

/// Recursive hierarchy tiling: covers [span_start, span_end) using only
/// spans that are exact nodes of the meter's subdivision tree, descending
/// a level whenever the span doesn't fill the current node exactly.
fn tileInto(
    ts: TimeSig,
    node_start: Rational,
    node_len: Rational,
    depth: usize,
    span_start: Rational,
    span_end: Rational,
    kind: Kind,
    out: []Event,
    n: *usize,
) void {
    if (!span_start.lt(span_end)) return;
    if (n.* >= out.len) return;

    const node_end = node_start.add(node_len);
    if (span_start.eq(node_start) and span_end.eq(node_end)) {
        out[n.*] = .{ .kind = kind, .dur = node_len };
        n.* += 1;
        return;
    }
    if (depth >= ts.divisions.len) {
        // Finer than the hierarchy goes: emit the remainder as it is.
        out[n.*] = .{ .kind = kind, .dur = span_end.sub(span_start) };
        n.* += 1;
        return;
    }

    const count = ts.divisions[depth];
    const child_len = node_len.divInt(count);
    var child_start = node_start;
    var i: usize = 0;
    while (i < count) : (i += 1) {
        const child_end = child_start.add(child_len);
        const s = Rational.max(span_start, child_start);
        const e = Rational.min(span_end, child_end);
        if (s.lt(e)) tileInto(ts, child_start, child_len, depth + 1, s, e, kind, out, n);
        child_start = child_end;
    }
}

/// Merges an adjacent (symbol, half-as-long symbol) pair into one dotted
/// symbol wherever that is legal here — "a dotted value is preferred over
/// two tied values within a beat". Only that order merges: short-then-long
/// is a syncopation, which convention writes as a tie rather than moving
/// the value, and the longer piece must sit on its own value's grid.
fn dottedMergeInPlace(onset: Rational, buf: []Event, n: *usize) void {
    var pos = onset;
    var i: usize = 0;
    while (i + 1 < n.*) {
        const a = buf[i];
        const b = buf[i + 1];
        const merged = a.dur.add(b.dur);
        if (a.dur.eq(b.dur.mulInt(2)) and
            isStandardValue(merged) and
            pos.isMultipleOf(a.dur))
        {
            buf[i].dur = merged;
            // tied_to_next of the pair is whatever the second piece had.
            buf[i].tied_to_next = b.tied_to_next;
            var j = i + 1;
            while (j + 1 < n.*) : (j += 1) buf[j] = buf[j + 1];
            n.* -= 1;
            pos = pos.add(merged);
            i += 1;
            continue;
        }
        pos = pos.add(a.dur);
        i += 1;
    }
}

/// Tiles one span into the fewest legal symbols, writing into `buf` and
/// returning the slice used. `kind` notes get tied together, since a note
/// span split by the hierarchy is still one attack; rests do not.
pub fn tileSpan(ts: TimeSig, onset: Rational, dur: Rational, kind: Kind, buf: []Event) []Event {
    var n: usize = 0;
    tileInto(ts, Rational.zero(), ts.bar_len, 0, onset, onset.add(dur), kind, buf, &n);
    dottedMergeInPlace(onset, buf, &n);
    if (kind == .note and n > 0) {
        for (buf[0 .. n - 1]) |*e| e.tied_to_next = true;
    }
    return buf[0..n];
}

/// True if [onset, onset+dur) is writable as exactly one symbol here.
pub fn isLegalSymbol(ts: TimeSig, onset: Rational, dur: Rational) bool {
    var buf: [max_pieces]Event = undefined;
    return tileSpan(ts, onset, dur, .rest, &buf).len == 1;
}

/// One fixed-point pass: re-tiles each span into the fewest legal symbols.
/// Consecutive rests are gathered into one span first — silence is one
/// continuous thing however many events it arrived as. Notes are re-tiled
/// one event at a time and never merged with a neighbour, so no attack is
/// ever added or removed; a single note too long for one symbol here comes
/// back as tied pieces. Staccato notes pass through untouched, since
/// collapsePass shortened them deliberately.
fn retilePass(allocator: std.mem.Allocator, time_sig: TimeSig, events: []const Event) !struct { out: []Event, changed: bool } {
    var out = std.ArrayList(Event).init(allocator);
    errdefer out.deinit();
    var buf: [max_pieces]Event = undefined;
    var onset = Rational.zero();
    var changed = false;
    var i: usize = 0;
    while (i < events.len) {
        if (events[i].kind == .rest) {
            const start = i;
            const run_onset = onset;
            var run_len = Rational.zero();
            while (i < events.len and events[i].kind == .rest) {
                run_len = run_len.add(events[i].dur);
                onset = onset.add(events[i].dur);
                i += 1;
            }
            const pieces = tileSpan(time_sig, run_onset, run_len, .rest, &buf);
            if (differs(pieces, events[start..i])) changed = true;
            try out.appendSlice(pieces);
            continue;
        }

        const e = events[i];
        if (e.staccato) {
            try out.append(e);
            onset = onset.add(e.dur);
            i += 1;
            continue;
        }
        const pieces = tileSpan(time_sig, onset, e.dur, .note, &buf);
        // The run's last piece inherits whatever this note was tied to.
        pieces[pieces.len - 1].tied_to_next = e.tied_to_next;
        if (differs(pieces, events[i .. i + 1])) changed = true;
        try out.appendSlice(pieces);
        onset = onset.add(e.dur);
        i += 1;
    }
    return .{ .out = try out.toOwnedSlice(), .changed = changed };
}

fn differs(a: []const Event, b: []const Event) bool {
    if (a.len != b.len) return true;
    for (a, b) |x, y| {
        if (!x.dur.eq(y.dur) or x.kind != y.kind) return true;
    }
    return false;
}

/// One fixed-point pass: collapses every adjacent (note, rest) pair of
/// equal duration into a single staccato note of double the duration,
/// provided that merged span is writable as one legal symbol here, and
/// that it is no longer than one beat. The beat limit is a deliberate
/// narrowing of the rule as originally stated: staccato reads as
/// "shortened" only at shortish values, so an eighth plus an eighth rest
/// becoming a staccato quarter is idiomatic, while a quarter plus a
/// quarter rest becoming a staccato half note is not — nobody writes
/// that, and it would be read as a held note rather than a short one.
/// Events must already tile the bar exactly (each one starts where the
/// previous one ends) — that invariant is never changed by this function.
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
            if (a.kind == .note and !a.tied_to_next and b.kind == .rest and a.dur.eq(b.dur)) {
                const merged_dur = a.dur.add(b.dur);
                if (merged_dur.lte(time_sig.beat) and isLegalSymbol(time_sig, onset, merged_dur)) {
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

/// Simplifies a bar's worth of events to a fixed point: re-tile every span
/// into the fewest legal symbols (`retilePass`), then collapse equal-length
/// note+rest pairs into staccato notes (`collapsePass`), until a full round
/// changes nothing. Total duration and every attack position are preserved
/// exactly; only the symbols representing them change.
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

test "a full 4/4 bar of silence is one whole rest" {
    const allocator = std.testing.allocator;
    const events = [_]Event{.{ .kind = .rest, .dur = Rational.of(1, 1) }};
    const out = try simplifyBar(allocator, TimeSig.four_four, &events);
    defer allocator.free(out);
    try std.testing.expectEqual(@as(usize, 1), out.len);
    try std.testing.expect(out[0].dur.eq(Rational.of(1, 1)));
}

test "a half-length span is one symbol on beat 1 of 4/4 but not on beat 2" {
    // The distinction the hierarchy exists for: both spans are 1/2 long
    // and both cross a beat boundary, but only the one starting at 0
    // lines up with the half-bar node.
    try std.testing.expect(isLegalSymbol(TimeSig.four_four, Rational.zero(), Rational.of(1, 2)));
    try std.testing.expect(isLegalSymbol(TimeSig.four_four, Rational.of(1, 2), Rational.of(1, 2)));
    try std.testing.expect(!isLegalSymbol(TimeSig.four_four, Rational.of(1, 4), Rational.of(1, 2)));
}

test "silence across beats 2-3 of 4/4 becomes two quarter rests" {
    const allocator = std.testing.allocator;
    const events = [_]Event{
        .{ .kind = .note, .dur = Rational.of(1, 4) },
        .{ .kind = .rest, .dur = Rational.of(1, 2) },
        .{ .kind = .note, .dur = Rational.of(1, 4) },
    };
    const out = try simplifyBar(allocator, TimeSig.four_four, &events);
    defer allocator.free(out);

    var rests: usize = 0;
    for (out) |e| {
        if (e.kind == .rest) {
            rests += 1;
            try std.testing.expect(e.dur.eq(Rational.of(1, 4)));
        }
    }
    try std.testing.expectEqual(@as(usize, 2), rests);
    try std.testing.expect(totalDur(&events).eq(totalDur(out)));
}

test "a quarter note plus a quarter rest is not a staccato half note" {
    const allocator = std.testing.allocator;
    const events = [_]Event{
        .{ .kind = .note, .dur = Rational.of(1, 4) },
        .{ .kind = .rest, .dur = Rational.of(1, 4) },
        .{ .kind = .note, .dur = Rational.of(1, 2) },
    };
    const out = try simplifyBar(allocator, TimeSig.four_four, &events);
    defer allocator.free(out);
    // The merged span [0, 1/2) *is* a legal half note, so only the beat
    // limit stops this; without it the rest would vanish into a staccato.
    try std.testing.expectEqual(@as(usize, 3), out.len);
    try std.testing.expectEqual(Kind.rest, out[1].kind);
    for (out) |e| try std.testing.expect(!e.staccato);
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

test "one note too long for its position comes back as tied pieces" {
    const allocator = std.testing.allocator;
    // A single quarter-long note starting on the second eighth of 4/4:
    // [1/8, 3/8) fits no single node, so it is written as two tied
    // eighths — one attack, two noteheads.
    const events = [_]Event{
        .{ .kind = .rest, .dur = Rational.of(1, 8) },
        .{ .kind = .note, .dur = Rational.of(1, 4) },
        .{ .kind = .rest, .dur = Rational.of(5, 8) },
    };
    const out = try simplifyBar(allocator, TimeSig.four_four, &events);
    defer allocator.free(out);

    var notes: usize = 0;
    var ties: usize = 0;
    for (out) |e| {
        if (e.kind == .note) {
            notes += 1;
            if (e.tied_to_next) ties += 1;
        }
    }
    try std.testing.expectEqual(@as(usize, 2), notes);
    try std.testing.expectEqual(@as(usize, 1), ties);
    try std.testing.expect(totalDur(&events).eq(totalDur(out)));
}

test "two adjacent note events are never merged — each is its own attack" {
    const allocator = std.testing.allocator;
    const s16 = Rational.of(1, 16);
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

test "a note+rest pair that would land on no single symbol is left alone" {
    const allocator = std.testing.allocator;
    // Eighth note at [1/8, 1/4) plus eighth rest at [1/4, 3/8): each is
    // fine alone, but the merged [1/8, 3/8) matches no node, so the pair
    // must not collapse.
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

test "6/8 beat 2 takes a dotted-quarter rest, which 4/4 beat 2 would not" {
    const allocator = std.testing.allocator;
    // [3/8, 3/4) is exactly 6/8's second beat node.
    try std.testing.expect(isLegalSymbol(TimeSig.six_eight, Rational.of(3, 8), Rational.of(3, 8)));
    // The same span in 4/4 straddles the half-bar boundary at 1/2.
    try std.testing.expect(!isLegalSymbol(TimeSig.four_four, Rational.of(3, 8), Rational.of(3, 8)));

    const events = [_]Event{
        .{ .kind = .note, .dur = Rational.of(3, 8) },
        .{ .kind = .rest, .dur = Rational.of(1, 8) },
        .{ .kind = .rest, .dur = Rational.of(1, 8) },
        .{ .kind = .rest, .dur = Rational.of(1, 8) },
    };
    const out = try simplifyBar(allocator, TimeSig.six_eight, &events);
    defer allocator.free(out);
    try std.testing.expectEqual(@as(usize, 2), out.len);
    try std.testing.expect(out[1].dur.eq(Rational.of(3, 8)));
}

test "a dotted quarter is preferred over a quarter plus an eighth on the beat" {
    // [0, 3/8) in 4/4: a quarter node plus the eighth after it, which the
    // dotted merge should turn into a single dotted quarter.
    try std.testing.expect(isLegalSymbol(TimeSig.four_four, Rational.zero(), Rational.of(3, 8)));
}

test "6/8 beat boundaries are the dotted-quarter grouping, not every eighth" {
    var buf: [8]Rational = undefined;
    const b = TimeSig.six_eight.beatBoundaries(&buf);
    try std.testing.expectEqual(@as(usize, 2), b.len);
    try std.testing.expect(b[0].eq(Rational.zero()));
    try std.testing.expect(b[1].eq(Rational.of(3, 8)));
}
