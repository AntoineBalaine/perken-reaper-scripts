//! Property-based test for rhythm_simplify, driven by libhegel (see
//! hegel.zig) rather than hand-picked examples. For each common time
//! signature it generates many random runs of events — libhegel picks how
//! many bars the run covers, where in the bar grid it starts, where to cut
//! it into segments, and which segments are notes versus rests — and
//! checks the invariants `simplify` must never violate:
//!
//! - total duration is preserved;
//! - every output symbol is one the meter's hierarchy actually allows at
//!   the position it sits (the real correctness property, checked here
//!   against isLegalSymbol rather than taken on trust);
//! - every attack is preserved: the output has exactly as many note
//!   onsets as the input, at the same positions, since tying splits a
//!   note without adding an attack and nothing may ever merge two;
//! - the result is a fixed point — simplifying it again changes nothing.
//!
//! The multi-bar, arbitrary-start generation matters: an earlier version
//! of this test only ever produced runs that tiled exactly one bar from
//! position zero, and that blind spot hid a bug where any span reaching
//! past the barline was silently truncated — duration vanished and no
//! test noticed. Duration preservation only means something if the
//! generator can produce spans that cross a barline.
//!
//! Symbol count is deliberately *not* checked as "never increases". A raw
//! gap of 5/16 has no single notehead and correctly becomes two symbols;
//! that is the feature working, not a regression.
//!
//! This uses libhegel purely as an input generator for now (failures
//! surface as an ordinary Zig test failure via std.testing.expect, not
//! through hegel_mark_complete's INTERESTING status). Wiring up libhegel's
//! own shrinker for a minimal counterexample is follow-up work, not needed
//! to get real property-based coverage today.

const std = @import("std");
const hegel = @import("hegel.zig");
const rs = @import("rhythm_simplify.zig");

/// Bar length in sixteenth-note units — must divide evenly, checked by the
/// assert (holds for every TimeSig in rs.TimeSig).
fn unitsInBar(time_sig: rs.TimeSig) usize {
    // bar_len / (1/16), computed as (bar_len.num * 16) / bar_len.den.
    const scaled = time_sig.bar_len.num * 16;
    std.debug.assert(@rem(scaled, time_sig.bar_len.den) == 0);
    return @intCast(@divExact(scaled, time_sig.bar_len.den));
}

const Run = struct {
    /// Where the first event begins, in whole notes from the bar grid.
    start: rs.Rational,
    events: []rs.Event,
};

/// Draws a random run of events in sixteenth-note units: a start offset
/// anywhere in the first bar, a length of one to three bars' worth, a
/// random cut after each interior unit (p=0.3, so segments average a bit
/// over three units), and a random note/rest kind per segment (p=0.5).
/// Cuts are unconstrained on purpose — a held note or a gap may well span
/// beats and barlines as one event, and re-tiling exactly those is the
/// point of the module.
fn drawRun(ctx: hegel.Ctx, tc: *hegel.TestCase, allocator: std.mem.Allocator, time_sig: rs.TimeSig) !Run {
    const bar_units = unitsInBar(time_sig);
    const start_unit = try ctx.drawInt(tc, 0, @intCast(bar_units - 1));
    const bars = try ctx.drawInt(tc, 1, 3);
    const total_units: usize = @intCast(@as(i64, @intCast(bar_units)) * bars);

    var cuts = try std.ArrayList(usize).initCapacity(allocator, total_units);
    defer cuts.deinit();
    var i: usize = 1;
    while (i < total_units) : (i += 1) {
        if (try ctx.drawBool(tc, 0.3)) try cuts.append(i);
    }
    try cuts.append(total_units);

    var events = try std.ArrayList(rs.Event).initCapacity(allocator, cuts.items.len);
    var prev: usize = 0;
    for (cuts.items) |cut| {
        const units = cut - prev;
        prev = cut;
        const kind: rs.Kind = if (try ctx.drawBool(tc, 0.5)) .note else .rest;
        try events.append(.{ .kind = kind, .dur = rs.Rational.of(@intCast(units), 16) });
    }
    return .{
        .start = rs.Rational.of(start_unit, 16),
        .events = try events.toOwnedSlice(),
    };
}

fn totalDur(events: []const rs.Event) rs.Rational {
    var total = rs.Rational.zero();
    for (events) |e| total = total.add(e.dur);
    return total;
}

/// Onsets at which a new note actually starts — a tied-into piece is a
/// continuation of the previous attack, not a new one, so it doesn't
/// count. This is what has to match between input and output.
fn attackOnsets(allocator: std.mem.Allocator, start: rs.Rational, events: []const rs.Event) ![]rs.Rational {
    var onsets = std.ArrayList(rs.Rational).init(allocator);
    var onset = start;
    var prev_tied = false;
    for (events) |e| {
        if (e.kind == .note and !prev_tied) try onsets.append(onset);
        prev_tied = e.kind == .note and e.tied_to_next;
        onset = onset.add(e.dur);
    }
    return onsets.toOwnedSlice();
}

fn checkTimeSig(allocator: std.mem.Allocator, ctx: hegel.Ctx, time_sig: rs.TimeSig) !void {
    const settings = try ctx.settingsNew(300);
    defer ctx.settingsFree(settings);
    const run = try ctx.runStart(settings);
    defer ctx.runFree(run);

    while (try ctx.nextTestCase(run)) |tc| {
        defer ctx.testCaseFree(tc);
        const drawn = try drawRun(ctx, tc, allocator, time_sig);
        defer allocator.free(drawn.events);
        const start = drawn.start;

        const simplified = try rs.simplify(allocator, time_sig, start, drawn.events);
        defer allocator.free(simplified);

        // Nothing may be lost, least of all across a barline.
        try std.testing.expect(totalDur(drawn.events).eq(totalDur(simplified)));

        // Every symbol must be legal where it sits.
        var onset = start;
        for (simplified) |e| {
            try std.testing.expect(rs.isLegalSymbol(time_sig, onset, e.dur));
            onset = onset.add(e.dur);
        }

        // No attack added, removed, or moved.
        const before = try attackOnsets(allocator, start, drawn.events);
        defer allocator.free(before);
        const after = try attackOnsets(allocator, start, simplified);
        defer allocator.free(after);
        try std.testing.expectEqual(before.len, after.len);
        for (before, after) |x, y| try std.testing.expect(x.eq(y));

        // Already simplified: simplifying again changes nothing.
        const twice = try rs.simplify(allocator, time_sig, start, simplified);
        defer allocator.free(twice);
        try std.testing.expectEqual(simplified.len, twice.len);
        for (simplified, twice) |a, b| {
            try std.testing.expect(a.dur.eq(b.dur));
            try std.testing.expectEqual(a.kind, b.kind);
            try std.testing.expectEqual(a.tied_to_next, b.tied_to_next);
        }

        try ctx.markComplete(tc, .valid);
    }
    try std.testing.expectEqual(hegel.RunStatus.passed, try ctx.runResultStatus(run));
}

test "simplify keeps duration, attacks and legality across barlines, and is a fixed point" {
    const allocator = std.testing.allocator;
    const ctx = hegel.Ctx.init();
    defer ctx.deinit();

    try checkTimeSig(allocator, ctx, rs.TimeSig.four_four);
    try checkTimeSig(allocator, ctx, rs.TimeSig.three_four);
    try checkTimeSig(allocator, ctx, rs.TimeSig.two_four);
    try checkTimeSig(allocator, ctx, rs.TimeSig.six_eight);
    try checkTimeSig(allocator, ctx, rs.TimeSig.twelve_eight);
}
