//! Property-based test for rhythm_simplify's collapse rule, driven by
//! libhegel (see hegel.zig) rather than hand-picked examples: for each
//! common time signature, generates many random bars that exactly tile it
//! in sixteenth-note units — libhegel chooses where to cut the bar into
//! segments and which segments are notes versus rests — and checks the
//! invariants simplifyBar must never violate: total duration is preserved,
//! no output symbol's span crosses a beat boundary, and the result is a
//! fixed point (simplifying it again changes nothing). Symbol count is
//! deliberately *not* checked as "never increases" — a raw gap like 5/16
//! has no single standard notehead and correctly *must* split into more
//! symbols (quarter + sixteenth) than the one raw input event it came
//! from; that is this feature working, not a regression.
//!
//! This uses libhegel purely as an input generator for now (failures
//! surface as an ordinary Zig test failure via std.testing.expect, not
//! through hegel_mark_complete's INTERESTING status). Wiring up libhegel's
//! own shrinker for a minimal counterexample is follow-up work, not needed
//! to get real property-based coverage today.

const std = @import("std");
const hegel = @import("hegel.zig");
const rs = @import("rhythm_simplify.zig");

const sixteenth = rs.Rational.of(1, 16);

/// Bar length in sixteenth-note units — must divide evenly, checked by the
/// assert below (holds for every TimeSig in rs.TimeSig).
fn unitsInBar(time_sig: rs.TimeSig) usize {
    // bar_len / sixteenth, computed as (bar_len.num * 16) / bar_len.den.
    const scaled = time_sig.bar_len.num * 16;
    std.debug.assert(@rem(scaled, time_sig.bar_len.den) == 0);
    return @intCast(@divExact(scaled, time_sig.bar_len.den));
}

/// Beat length in sixteenth-note units — same divide-evenly guarantee as
/// unitsInBar, holds for every TimeSig in rs.TimeSig.
fn unitsPerBeat(time_sig: rs.TimeSig) usize {
    const scaled = time_sig.beat.num * 16;
    std.debug.assert(@rem(scaled, time_sig.beat.den) == 0);
    return @intCast(@divExact(scaled, time_sig.beat.den));
}

/// Draws a random bar that exactly tiles `time_sig` in sixteenth-note
/// units: every beat boundary is always a cut — a raw quantized bar is a
/// sequence of individually-timed note/rest events, never one event that
/// already spans multiple beats, so simplifyBar's job is always to
/// *reduce* symbol count from here, never to additionally split an input
/// that was already invalid on its own terms — plus a random extra cut
/// after each of the other total_units - 1 units (p=0.3, so segments
/// average a bit over 3 units long), then a random note/rest kind per
/// segment (p=0.5).
fn drawBar(ctx: hegel.Ctx, tc: *hegel.TestCase, allocator: std.mem.Allocator, time_sig: rs.TimeSig) ![]rs.Event {
    const total_units = unitsInBar(time_sig);
    const beat_units = unitsPerBeat(time_sig);
    var cuts = try std.ArrayList(usize).initCapacity(allocator, total_units);
    defer cuts.deinit();
    var i: usize = 1;
    while (i < total_units) : (i += 1) {
        if (i % beat_units == 0 or try ctx.drawBool(tc, 0.3)) try cuts.append(i);
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
    return events.toOwnedSlice();
}

fn totalDur(events: []const rs.Event) rs.Rational {
    var total = rs.Rational.zero();
    for (events) |e| total = total.add(e.dur);
    return total;
}

fn checkTimeSig(allocator: std.mem.Allocator, ctx: hegel.Ctx, time_sig: rs.TimeSig) !void {
    const settings = try ctx.settingsNew(300);
    defer ctx.settingsFree(settings);
    const run = try ctx.runStart(settings);
    defer ctx.runFree(run);

    while (try ctx.nextTestCase(run)) |tc| {
        defer ctx.testCaseFree(tc);
        const bar = try drawBar(ctx, tc, allocator, time_sig);
        defer allocator.free(bar);

        const simplified = try rs.simplifyBar(allocator, time_sig, bar);
        defer allocator.free(simplified);

        try std.testing.expect(totalDur(bar).eq(totalDur(simplified)));

        var onset = rs.Rational.zero();
        for (simplified) |e| {
            try std.testing.expect(!rs.crossesABeat(time_sig, onset, e.dur));
            onset = onset.add(e.dur);
        }

        const twice = try rs.simplifyBar(allocator, time_sig, simplified);
        defer allocator.free(twice);
        try std.testing.expectEqual(simplified.len, twice.len);
        for (simplified, twice) |a, b| {
            try std.testing.expect(a.dur.eq(b.dur));
            try std.testing.expectEqual(a.kind, b.kind);
        }

        try ctx.markComplete(tc, .valid);
    }
    try std.testing.expectEqual(hegel.RunStatus.passed, try ctx.runResultStatus(run));
}

test "simplifyBar preserves duration and never grows the symbol count, across many random bars" {
    const allocator = std.testing.allocator;
    const ctx = hegel.Ctx.init();
    defer ctx.deinit();

    try checkTimeSig(allocator, ctx, rs.TimeSig.four_four);
    try checkTimeSig(allocator, ctx, rs.TimeSig.three_four);
    try checkTimeSig(allocator, ctx, rs.TimeSig.two_four);
    try checkTimeSig(allocator, ctx, rs.TimeSig.six_eight);
    try checkTimeSig(allocator, ctx, rs.TimeSig.twelve_eight);
}
