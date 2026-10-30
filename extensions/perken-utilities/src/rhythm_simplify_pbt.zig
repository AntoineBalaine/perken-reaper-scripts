//! Property-based test for rhythm_simplify, driven by libhegel (see
//! hegel.zig) rather than hand-picked examples. For each starting meter it
//! generates many random runs of events — libhegel picks
//! how many bars the run covers, whether the meter changes partway and to
//! what, where in the bar grid the run starts, where to cut it into
//! segments, and which segments are notes versus rests — and checks the
//! invariants `simplify` must never violate:
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
//! The multi-bar, arbitrary-start, meter-changing generation matters: an
//! earlier version of this test only ever produced runs that tiled exactly
//! one bar from position zero, and that blind spot hid a bug where any
//! span reaching past the barline was silently truncated — duration
//! vanished and no test noticed. Duration preservation only means
//! something if the generator can produce spans that cross a barline, and
//! the same reasoning applies to meter changes: a note held across a 4/4
//! to 3/4 change is the case most likely to be mangled, so the generator
//! has to be able to build one.
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

/// A duration in sixteenth-note units — the signatures drawn below all
/// divide evenly, which the assert holds us to.
fn unitsOf(dur: rs.Rational) usize {
    const scaled = dur.num * 16;
    std.debug.assert(@rem(scaled, dur.den) == 0);
    return @intCast(@divExact(scaled, dur.den));
}

/// Signatures the generator picks from: simple, compound and irregular, so
/// the hierarchy derivation is exercised rather than just 4/4.
const signatures = [_][2]u32{
    .{ 4, 4 }, .{ 3, 4 }, .{ 2, 4 }, .{ 6, 8 }, .{ 12, 8 }, .{ 9, 8 }, .{ 5, 4 }, .{ 7, 8 },
};

const Run = struct {
    /// Where the first event begins, in whole notes from the bar grid.
    start: rs.Rational,
    events: []rs.Event,
    ctx: rs.Context,
};

/// Draws a random run of events in sixteenth-note units, together with the
/// meter context it sits in: one or two meter sections of one to three bars
/// each (so about half the runs contain a meter change), a start offset
/// anywhere in the first bar, a random cut after each interior unit
/// (p=0.3, so segments average a bit over three units), and a random
/// note/rest kind per segment (p=0.5). Cuts are unconstrained on purpose —
/// a held note or a gap may well span beats, barlines and meter changes as
/// one event, and re-tiling exactly those is the point of the module.
fn drawRun(ctx: hegel.Ctx, tc: *hegel.TestCase, allocator: std.mem.Allocator, first_sig: [2]u32) !Run {
    var sections: [2]rs.meter.Section = undefined;
    var section_count: usize = 1;
    sections[0] = .{ .num = first_sig[0], .denom = first_sig[1], .bars = @intCast(try ctx.drawInt(tc, 1, 3)) };
    if (try ctx.drawBool(tc, 0.5)) {
        const i: usize = @intCast(try ctx.drawInt(tc, 0, signatures.len - 1));
        sections[1] = .{ .num = signatures[i][0], .denom = signatures[i][1], .bars = @intCast(try ctx.drawInt(tc, 1, 3)) };
        section_count = 2;
    }
    const meter_ctx = try rs.meter.fromSections(allocator, rs.Rational.zero(), sections[0..section_count]);
    errdefer rs.meter.freeContext(allocator, meter_ctx);

    const first_bar_units = unitsOf(meter_ctx.bars[0].hierarchy.len);
    const start_unit = try ctx.drawInt(tc, 0, @intCast(first_bar_units - 1));
    // Run to the end of the context, so spans reach every barline and every
    // meter change in it.
    const total_units: usize = unitsOf(meter_ctx.end()) - @as(usize, @intCast(start_unit));

    var cuts = try std.ArrayList(usize).initCapacity(allocator, total_units);
    defer cuts.deinit(allocator);
    var i: usize = 1;
    while (i < total_units) : (i += 1) {
        if (try ctx.drawBool(tc, 0.3)) try cuts.append(allocator, i);
    }
    try cuts.append(allocator, total_units);

    var events = try std.ArrayList(rs.Event).initCapacity(allocator, cuts.items.len);
    var prev: usize = 0;
    for (cuts.items) |cut| {
        const units = cut - prev;
        prev = cut;
        const kind: rs.Kind = if (try ctx.drawBool(tc, 0.5)) .note else .rest;
        try events.append(allocator, .{ .kind = kind, .dur = rs.Rational.of(@intCast(units), 16) });
    }
    return .{
        .start = rs.Rational.of(start_unit, 16),
        .events = try events.toOwnedSlice(allocator),
        .ctx = meter_ctx,
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
    var onsets: std.ArrayList(rs.Rational) = .empty;
    var onset = start;
    var prev_tied = false;
    for (events) |e| {
        if (e.kind == .note and !prev_tied) try onsets.append(allocator, onset);
        prev_tied = e.kind == .note and e.tied_to_next;
        onset = onset.add(e.dur);
    }
    return onsets.toOwnedSlice(allocator);
}

fn checkSignature(allocator: std.mem.Allocator, ctx: hegel.Ctx, first_sig: [2]u32) !void {
    const settings = try ctx.settingsNew(300);
    defer ctx.settingsFree(settings);
    const run = try ctx.runStart(settings);
    defer ctx.runFree(run);

    while (try ctx.nextTestCase(run)) |tc| {
        defer ctx.testCaseFree(tc);
        const drawn = try drawRun(ctx, tc, allocator, first_sig);
        defer allocator.free(drawn.events);
        defer rs.meter.freeContext(allocator, drawn.ctx);
        const start = drawn.start;
        const mctx = drawn.ctx;

        const simplified = try rs.simplify(allocator, mctx, start, drawn.events);
        defer allocator.free(simplified);

        // Nothing may be lost, least of all across a barline.
        try std.testing.expect(totalDur(drawn.events).eq(totalDur(simplified)));

        // Every symbol must be legal where it sits.
        var onset = start;
        for (simplified) |e| {
            try std.testing.expect(rs.isLegalSymbol(mctx, onset, e.dur));
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
        const twice = try rs.simplify(allocator, mctx, start, simplified);
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

test "simplify keeps duration, attacks and legality across barlines and meter changes" {
    const allocator = std.testing.allocator;
    const ctx = hegel.Ctx.init();
    defer ctx.deinit();

    for (signatures) |sig| try checkSignature(allocator, ctx, sig);
}
