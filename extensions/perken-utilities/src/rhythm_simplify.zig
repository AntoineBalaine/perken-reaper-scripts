//! Simplifies quantized note/rest sequences into the fewest, most readable
//! symbols a reader expects at each position.
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

pub const Rational = @import("rational.zig").Rational;
pub const meter = @import("meter.zig");
pub const Context = meter.Context;


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
    /// rest — there is no such thing as a tied rest, so a silence
    /// crossing a barline is simply one rest per bar.
    tied_to_next: bool = false,
    /// Set on a rest that fills its whole bar. `dur` stays the bar's true
    /// length for all arithmetic; this only tells a renderer to draw the
    /// whole-rest glyph, which by convention stands for an empty bar in
    /// any meter (so a 3/4 bar of silence is a whole rest, not a dotted
    /// half rest).
    bar_rest: bool = false,
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

/// Recursive hierarchy tiling within one bar: covers [span_start,
/// span_end) using only spans that are exact nodes of the meter's
/// subdivision tree, descending a level whenever the span doesn't fill the
/// current node exactly. Appends rather than writing into a fixed buffer,
/// so a span can never be silently truncated for want of room.
fn tileInto(
    h: meter.Hierarchy,
    node_start: Rational,
    node_len: Rational,
    depth: usize,
    span_start: Rational,
    span_end: Rational,
    kind: Kind,
    out: *std.ArrayList(Event),
) !void {
    if (!span_start.lt(span_end)) return;

    const node_end = node_start.add(node_len);
    if (span_start.eq(node_start) and span_end.eq(node_end)) {
        try out.append(.{
            .kind = kind,
            .dur = node_len,
            // depth 0 is the bar itself: a rest filling it is an empty bar.
            .bar_rest = depth == 0 and kind == .rest,
        });
        return;
    }
    if (depth >= h.divisions().len) {
        // Finer than the hierarchy goes: emit the remainder as it is.
        try out.append(.{ .kind = kind, .dur = span_end.sub(span_start) });
        return;
    }

    const count = h.divisions()[depth];
    const child_len = node_len.divInt(count);
    var child_start = node_start;
    var i: usize = 0;
    while (i < count) : (i += 1) {
        const child_end = child_start.add(child_len);
        const s = Rational.max(span_start, child_start);
        const e = Rational.min(span_end, child_end);
        if (s.lt(e)) try tileInto(h, child_start, child_len, depth + 1, s, e, kind, out);
        child_start = child_end;
    }
}

/// Merges an adjacent (symbol, half-as-long symbol) pair into one dotted
/// symbol wherever that is legal here — "a dotted value is preferred over
/// two tied values within a beat". Only that order merges: short-then-long
/// is a syncopation, which convention writes as a tie rather than moving
/// the value, and the longer piece must sit on its own value's grid.
/// Runs over the pieces appended from index `from` on, which tileSpan only
/// ever fills from a single bar, so a merged value cannot reach across a
/// barline. `onset` is where that bar's portion starts.
fn dottedMergeInPlace(onset: Rational, items: *std.ArrayList(Event), from: usize) void {
    var pos = onset;
    var i: usize = from;
    while (i + 1 < items.items.len) {
        const a = items.items[i];
        const b = items.items[i + 1];
        const merged = a.dur.add(b.dur);
        if (a.dur.eq(b.dur.mulInt(2)) and
            isStandardValue(merged) and
            pos.isMultipleOf(a.dur))
        {
            items.items[i].dur = merged;
            // tied_to_next of the pair is whatever the second piece had.
            items.items[i].tied_to_next = b.tied_to_next;
            _ = items.orderedRemove(i + 1);
            pos = pos.add(merged);
            i += 1;
            continue;
        }
        pos = pos.add(a.dur);
        i += 1;
    }
}

/// Tiles one span into the fewest legal symbols, appending them to `out`.
/// Splits at every barline first — no symbol may cross one — then tiles
/// each bar's portion against that bar's hierarchy. Note pieces are tied
/// to each other, including across a barline, since a sustained note is
/// still one attack; rests are not, because a tied rest does not exist.
pub fn tileSpan(ctx: Context, onset: Rational, dur: Rational, kind: Kind, out: *std.ArrayList(Event)) !void {
    const first = out.items.len;
    const span_end = onset.add(dur);
    var pos = onset;
    while (pos.lt(span_end)) {
        // Each step asks the context which bar `pos` is in, so a meter
        // change inside the span is picked up as it is reached rather than
        // the span being cut at the change and the pieces handled apart.
        const bar = ctx.barAt(pos);
        const e = Rational.min(span_end, bar.end);
        if (!pos.lt(e)) {
            // The bar handed back does not contain `pos`, so this loop
            // cannot advance. A Context is supposed to make that
            // impossible, but a hang inside REAPER would take the whole
            // DAW with it, so the rest of the span goes out as one symbol
            // rather than spinning: wrong-looking beats unresponsive, and
            // nothing is dropped either way.
            std.debug.assert(false);
            try out.append(.{ .kind = kind, .dur = span_end.sub(pos) });
            break;
        }
        const bar_first = out.items.len;
        try tileInto(bar.hierarchy, bar.start, bar.hierarchy.len, 0, pos, e, kind, out);
        // Dotted values are a within-bar nicety; merge per bar so one can
        // never reach across the barline.
        dottedMergeInPlace(pos, out, bar_first);
        pos = e;
    }
    if (kind == .note and out.items.len > first) {
        for (out.items[first .. out.items.len - 1]) |*e| e.tied_to_next = true;
    }
}

/// True if [onset, onset+dur) is writable as exactly one symbol here.
pub fn isLegalSymbol(ctx: Context, onset: Rational, dur: Rational) bool {
    var backing: [64]Event = undefined;
    var fba = std.heap.FixedBufferAllocator.init(std.mem.asBytes(&backing));
    var list = std.ArrayList(Event).initCapacity(fba.allocator(), 32) catch return false;
    // Needing more than the buffer holds means it is certainly not one
    // symbol, so a failure here answers the question too.
    tileSpan(ctx, onset, dur, .rest, &list) catch return false;
    return list.items.len == 1;
}

/// One fixed-point pass: re-tiles each span into the fewest legal symbols.
/// Consecutive rests are gathered into one span first — silence is one
/// continuous thing however many events it arrived as. Notes are re-tiled
/// one event at a time and never merged with a neighbour, so no attack is
/// ever added or removed; a single note too long for one symbol here comes
/// back as tied pieces. Staccato notes pass through untouched, since
/// collapsePass shortened them deliberately.
fn retilePass(allocator: std.mem.Allocator, ctx: Context, start: Rational, events: []const Event) !struct { out: []Event, changed: bool } {
    var out = std.ArrayList(Event).init(allocator);
    errdefer out.deinit();
    var onset = start;
    var changed = false;
    var i: usize = 0;
    while (i < events.len) {
        const first = out.items.len;
        if (events[i].kind == .rest) {
            const run_start = i;
            const run_onset = onset;
            var run_len = Rational.zero();
            while (i < events.len and events[i].kind == .rest) {
                run_len = run_len.add(events[i].dur);
                onset = onset.add(events[i].dur);
                i += 1;
            }
            try tileSpan(ctx, run_onset, run_len, .rest, &out);
            if (differs(out.items[first..], events[run_start..i])) changed = true;
            continue;
        }

        const e = events[i];
        if (e.staccato) {
            try out.append(e);
            onset = onset.add(e.dur);
            i += 1;
            continue;
        }
        try tileSpan(ctx, onset, e.dur, .note, &out);
        // The last piece inherits whatever this note was tied to.
        out.items[out.items.len - 1].tied_to_next = e.tied_to_next;
        if (differs(out.items[first..], events[i .. i + 1])) changed = true;
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
/// Events must tile their span exactly (each one starts where the previous
/// one ends) — that invariant is never changed by this function.
fn collapsePass(allocator: std.mem.Allocator, ctx: Context, start: Rational, events: []const Event) !struct { out: []Event, changed: bool } {
    var out = try std.ArrayList(Event).initCapacity(allocator, events.len);
    errdefer out.deinit();
    var onset = start;
    var changed = false;
    var i: usize = 0;
    while (i < events.len) {
        const a = events[i];
        if (i + 1 < events.len) {
            const b = events[i + 1];
            if (a.kind == .note and !a.tied_to_next and b.kind == .rest and a.dur.eq(b.dur)) {
                const merged_dur = a.dur.add(b.dur);
                if (merged_dur.lte(ctx.barAt(onset).hierarchy.beat) and isLegalSymbol(ctx, onset, merged_dur)) {
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

/// Simplifies a run of events to a fixed point: re-tile every span into the
/// fewest legal symbols (`retilePass`), then collapse equal-length note+rest
/// pairs into staccato notes (`collapsePass`), until a full round changes
/// nothing. Total duration and every attack position are preserved exactly;
/// only the symbols representing them change.
///
/// `start` is where the first event begins, measured in whole notes from
/// the start of the bar grid, so the run may begin anywhere and may span
/// any number of bars — spans crossing a barline are split there, notes
/// tied across it and silence written as one rest per bar.
pub fn simplify(allocator: std.mem.Allocator, ctx: Context, start: Rational, events: []const Event) ![]Event {
    var current = try allocator.dupe(Event, events);
    while (true) {
        const retiled = try retilePass(allocator, ctx, start, current);
        allocator.free(current);
        current = retiled.out;

        const collapsed = try collapsePass(allocator, ctx, start, current);
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

// ---- tests -----------------------------------------------------------------

/// A context of `bars` bars of one signature from position zero, enough for
/// the hand-written cases below. Generous bar counts cost nothing: past its
/// end the context continues the same meter anyway.
fn testCtx(allocator: std.mem.Allocator, num: u32, denom: u32) !Context {
    return meter.uniform(allocator, Rational.zero(), num, denom, 8);
}

test "a full 4/4 bar of silence is one whole rest" {
    const allocator = std.testing.allocator;
    const ctx = try testCtx(allocator, 4, 4);
    defer meter.freeContext(allocator, ctx);
    const events = [_]Event{.{ .kind = .rest, .dur = Rational.of(1, 1) }};
    const out = try simplify(allocator, ctx, Rational.zero(), &events);
    defer allocator.free(out);
    try std.testing.expectEqual(@as(usize, 1), out.len);
    try std.testing.expect(out[0].dur.eq(Rational.of(1, 1)));
}

test "a half-length span is one symbol on beat 1 of 4/4 but not on beat 2" {
    const allocator = std.testing.allocator;
    const ctx44 = try testCtx(allocator, 4, 4);
    defer meter.freeContext(allocator, ctx44);
    // The distinction the hierarchy exists for: both spans are 1/2 long
    // and both cross a beat boundary, but only the one starting at 0
    // lines up with the half-bar node.
    try std.testing.expect(isLegalSymbol(ctx44, Rational.zero(), Rational.of(1, 2)));
    try std.testing.expect(isLegalSymbol(ctx44, Rational.of(1, 2), Rational.of(1, 2)));
    try std.testing.expect(!isLegalSymbol(ctx44, Rational.of(1, 4), Rational.of(1, 2)));
}

test "silence across beats 2-3 of 4/4 becomes two quarter rests" {
    const allocator = std.testing.allocator;
    const ctx = try testCtx(allocator, 4, 4);
    defer meter.freeContext(allocator, ctx);
    const events = [_]Event{
        .{ .kind = .note, .dur = Rational.of(1, 4) },
        .{ .kind = .rest, .dur = Rational.of(1, 2) },
        .{ .kind = .note, .dur = Rational.of(1, 4) },
    };
    const out = try simplify(allocator, ctx, Rational.zero(), &events);
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
    const ctx = try testCtx(allocator, 4, 4);
    defer meter.freeContext(allocator, ctx);
    const events = [_]Event{
        .{ .kind = .note, .dur = Rational.of(1, 4) },
        .{ .kind = .rest, .dur = Rational.of(1, 4) },
        .{ .kind = .note, .dur = Rational.of(1, 2) },
    };
    const out = try simplify(allocator, ctx, Rational.zero(), &events);
    defer allocator.free(out);
    // The merged span [0, 1/2) *is* a legal half note, so only the beat
    // limit stops this; without it the rest would vanish into a staccato.
    try std.testing.expectEqual(@as(usize, 3), out.len);
    try std.testing.expectEqual(Kind.rest, out[1].kind);
    for (out) |e| try std.testing.expect(!e.staccato);
}

test "four sixteenth rests on the beat collapse to one quarter rest" {
    const allocator = std.testing.allocator;
    const ctx = try testCtx(allocator, 4, 4);
    defer meter.freeContext(allocator, ctx);
    const s16 = Rational.of(1, 16);
    const events = [_]Event{
        .{ .kind = .rest, .dur = s16 },
        .{ .kind = .rest, .dur = s16 },
        .{ .kind = .rest, .dur = s16 },
        .{ .kind = .rest, .dur = s16 },
    };
    const out = try simplify(allocator, ctx, Rational.zero(), &events);
    defer allocator.free(out);

    try std.testing.expectEqual(@as(usize, 1), out.len);
    try std.testing.expectEqual(Kind.rest, out[0].kind);
    try std.testing.expect(out[0].dur.eq(Rational.of(1, 4)));
}

test "one note too long for its position comes back as tied pieces" {
    const allocator = std.testing.allocator;
    const ctx = try testCtx(allocator, 4, 4);
    defer meter.freeContext(allocator, ctx);
    // A single quarter-long note starting on the second eighth of 4/4:
    // [1/8, 3/8) fits no single node, so it is written as two tied
    // eighths — one attack, two noteheads.
    const events = [_]Event{
        .{ .kind = .rest, .dur = Rational.of(1, 8) },
        .{ .kind = .note, .dur = Rational.of(1, 4) },
        .{ .kind = .rest, .dur = Rational.of(5, 8) },
    };
    const out = try simplify(allocator, ctx, Rational.zero(), &events);
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
    const ctx = try testCtx(allocator, 4, 4);
    defer meter.freeContext(allocator, ctx);
    const s16 = Rational.of(1, 16);
    const events = [_]Event{
        .{ .kind = .note, .dur = s16 },
        .{ .kind = .note, .dur = s16 },
        .{ .kind = .note, .dur = s16 },
        .{ .kind = .note, .dur = s16 },
    };
    const out = try simplify(allocator, ctx, Rational.zero(), &events);
    defer allocator.free(out);
    try std.testing.expectEqual(@as(usize, 4), out.len);
    for (out) |e| try std.testing.expect(e.dur.eq(s16));
}

test "eighth note + eighth rest, twice, collapses to two staccato quarters" {
    const allocator = std.testing.allocator;
    const ctx = try testCtx(allocator, 4, 4);
    defer meter.freeContext(allocator, ctx);
    const e8 = Rational.of(1, 8);
    const events = [_]Event{
        .{ .kind = .note, .dur = e8 },
        .{ .kind = .rest, .dur = e8 },
        .{ .kind = .note, .dur = e8 },
        .{ .kind = .rest, .dur = e8 },
    };
    const out = try simplify(allocator, ctx, Rational.zero(), &events);
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
    const ctx = try testCtx(allocator, 4, 4);
    defer meter.freeContext(allocator, ctx);
    // Eighth note at [1/8, 1/4) plus eighth rest at [1/4, 3/8): each is
    // fine alone, but the merged [1/8, 3/8) matches no node, so the pair
    // must not collapse.
    const e8 = Rational.of(1, 8);
    const events = [_]Event{
        .{ .kind = .note, .dur = e8 },
        .{ .kind = .note, .dur = e8 },
        .{ .kind = .rest, .dur = e8 },
    };
    const out = try simplify(allocator, ctx, Rational.zero(), &events);
    defer allocator.free(out);

    try std.testing.expectEqual(@as(usize, 3), out.len);
    try std.testing.expect(totalDur(&events).eq(totalDur(out)));
}

test "6/8 beat 2 takes a dotted-quarter rest, which 4/4 beat 2 would not" {
    const allocator = std.testing.allocator;
    const ctx = try testCtx(allocator, 6, 8);
    defer meter.freeContext(allocator, ctx);
    const ctx44 = try testCtx(allocator, 4, 4);
    defer meter.freeContext(allocator, ctx44);
    const ctx68 = ctx;
    // [3/8, 3/4) is exactly 6/8's second beat node.
    try std.testing.expect(isLegalSymbol(ctx68, Rational.of(3, 8), Rational.of(3, 8)));
    // The same span in 4/4 straddles the half-bar boundary at 1/2.
    try std.testing.expect(!isLegalSymbol(ctx44, Rational.of(3, 8), Rational.of(3, 8)));

    const events = [_]Event{
        .{ .kind = .note, .dur = Rational.of(3, 8) },
        .{ .kind = .rest, .dur = Rational.of(1, 8) },
        .{ .kind = .rest, .dur = Rational.of(1, 8) },
        .{ .kind = .rest, .dur = Rational.of(1, 8) },
    };
    const out = try simplify(allocator, ctx, Rational.zero(), &events);
    defer allocator.free(out);
    try std.testing.expectEqual(@as(usize, 2), out.len);
    try std.testing.expect(out[1].dur.eq(Rational.of(3, 8)));
}

test "a dotted quarter is preferred over a quarter plus an eighth on the beat" {
    const allocator = std.testing.allocator;
    const ctx44 = try testCtx(allocator, 4, 4);
    defer meter.freeContext(allocator, ctx44);
    // [0, 3/8) in 4/4: a quarter node plus the eighth after it, which the
    // dotted merge should turn into a single dotted quarter.
    try std.testing.expect(isLegalSymbol(ctx44, Rational.zero(), Rational.of(3, 8)));
}

test "a note running past the barline is tied across it, losing nothing" {
    const allocator = std.testing.allocator;
    const ctx = try testCtx(allocator, 4, 4);
    defer meter.freeContext(allocator, ctx);
    // Three quarters of rest, then a half note that reaches 1/4 into the
    // next bar. The note must come back as tied pieces totalling 1/2, and
    // the whole run must still total 5/4.
    const events = [_]Event{
        .{ .kind = .rest, .dur = Rational.of(3, 4) },
        .{ .kind = .note, .dur = Rational.of(1, 2) },
    };
    const out = try simplify(allocator, ctx, Rational.zero(), &events);
    defer allocator.free(out);

    try std.testing.expect(totalDur(&events).eq(totalDur(out)));
    try std.testing.expect(totalDur(out).eq(Rational.of(5, 4)));

    var note_dur = Rational.zero();
    var ties: usize = 0;
    for (out) |e| {
        if (e.kind == .note) {
            note_dur = note_dur.add(e.dur);
            if (e.tied_to_next) ties += 1;
        }
    }
    try std.testing.expect(note_dur.eq(Rational.of(1, 2)));
    // Split at the barline at 1/1: two pieces, so exactly one tie.
    try std.testing.expectEqual(@as(usize, 1), ties);
}

test "silence running past the barline becomes one rest per bar, never tied" {
    const allocator = std.testing.allocator;
    const ctx = try testCtx(allocator, 4, 4);
    defer meter.freeContext(allocator, ctx);
    const events = [_]Event{
        .{ .kind = .note, .dur = Rational.of(3, 4) },
        .{ .kind = .rest, .dur = Rational.of(1, 2) },
    };
    const out = try simplify(allocator, ctx, Rational.zero(), &events);
    defer allocator.free(out);

    try std.testing.expect(totalDur(&events).eq(totalDur(out)));
    var rest_dur = Rational.zero();
    for (out) |e| {
        if (e.kind == .rest) {
            rest_dur = rest_dur.add(e.dur);
            try std.testing.expect(!e.tied_to_next);
        }
    }
    try std.testing.expect(rest_dur.eq(Rational.of(1, 2)));
}

test "a run starting mid-bar is placed against the real grid, not from zero" {
    const allocator = std.testing.allocator;
    // A half-length silence starting on beat 2 of 4/4 is two quarter
    // rests, exactly as when it is reached by preceding events — the
    // start offset has to be honoured, not assumed to be zero.
    const ctx = try testCtx(allocator, 4, 4);
    defer meter.freeContext(allocator, ctx);
    const events = [_]Event{.{ .kind = .rest, .dur = Rational.of(1, 2) }};
    const out = try simplify(allocator, ctx, Rational.of(1, 4), &events);
    defer allocator.free(out);
    try std.testing.expectEqual(@as(usize, 2), out.len);
    for (out) |e| try std.testing.expect(e.dur.eq(Rational.of(1, 4)));
}

test "an empty bar is flagged as a whole-bar rest in every meter" {
    const allocator = std.testing.allocator;
    inline for (.{ .{ 4, 4 }, .{ 3, 4 }, .{ 2, 4 }, .{ 6, 8 }, .{ 7, 8 } }) |sig| {
        const ctx = try testCtx(allocator, sig[0], sig[1]);
        defer meter.freeContext(allocator, ctx);
        const bar_len = ctx.bars[0].hierarchy.len;
        const events = [_]Event{.{ .kind = .rest, .dur = bar_len }};
        const out = try simplify(allocator, ctx, Rational.zero(), &events);
        defer allocator.free(out);
        try std.testing.expectEqual(@as(usize, 1), out.len);
        // dur stays the bar's true length; only the glyph differs.
        try std.testing.expect(out[0].dur.eq(bar_len));
        try std.testing.expect(out[0].bar_rest);
    }
}

test "a rest that merely fills a beat is not flagged as a whole-bar rest" {
    const allocator = std.testing.allocator;
    const ctx = try testCtx(allocator, 4, 4);
    defer meter.freeContext(allocator, ctx);
    const events = [_]Event{
        .{ .kind = .rest, .dur = Rational.of(1, 4) },
        .{ .kind = .note, .dur = Rational.of(3, 4) },
    };
    const out = try simplify(allocator, ctx, Rational.zero(), &events);
    defer allocator.free(out);
    try std.testing.expect(!out[0].bar_rest);
}

test "6/8 groups as dotted-quarter beats, so beat 2 starts at 3/8" {
    const allocator = std.testing.allocator;
    const ctx = try testCtx(allocator, 6, 8);
    defer meter.freeContext(allocator, ctx);
    const h = ctx.bars[0].hierarchy;
    try std.testing.expect(h.beat.eq(Rational.of(3, 8)));
    // Beat 2 is a node, so a symbol may fill it; the eighth-level
    // boundaries inside it are not where the beat falls.
    try std.testing.expect(isLegalSymbol(ctx, Rational.of(3, 8), Rational.of(3, 8)));
}
