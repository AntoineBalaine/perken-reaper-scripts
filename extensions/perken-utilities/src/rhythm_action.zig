//! REAPER side of the notation simplifier: reads the notes of the MIDI
//! editor's take, builds the musical context they sit in, runs
//! rhythm_simplify over them, and writes the resulting note lengths back.
//!
//! What actually changes in the MIDI data is narrower than what the
//! simplifier computes, and worth being clear about. Of its three rules,
//! only one has any MIDI effect:
//!
//! - re-tiling a run of rests changes nothing: a rest is not a MIDI
//!   object, only the gap between notes;
//! - splitting one long note into tied noteheads changes nothing either:
//!   a tie is notation, and the note keeps one start and one end;
//! - collapsing a note plus an equal rest into one staccato value *does*
//!   change the note: its end moves out to fill the value.
//!
//! So this action's visible effect is that note ends move out to the
//! simplest value the position allows. The other two rules pay off when
//! the same simplifier output drives notation (the ABC export), not here.
//!
//! Positions go through project QN, never raw PPQ: a take's PPQ-to-QN
//! mapping accounts for playrate and time stretching, and bars are defined
//! in beats so tempo changes do not enter the arithmetic.

const std = @import("std");
const Reaper = @import("reaper").reaper;
const helpers = @import("reaper_helpers");
const actions = @import("actions.zig");
const timemap = @import("timemap.zig");
const meter = @import("meter.zig");
const rs = @import("rhythm_simplify.zig");

const Rational = rs.Rational;

const log = std.log.scoped(.rhythm);

/// Positions are snapped to 96ths of a whole note, which is exact for
/// everything this handles: the binary values down to a 32nd (a 32nd is
/// 3/96) and the triplets of each (a triplet eighth is 8/96, a triplet
/// sixteenth 4/96). REAPER hands back floats, and a recorded note sits a
/// tick or two off even after quantising, so snapping is what lets the rest
/// of the pipeline use exact rationals and compare positions for equality
/// at all. Finer grids (64ths, quintuplets) land on the nearest 96th.
pub const snap_den: i64 = 96;

/// Quarter notes to an exact rational in whole notes.
pub fn qnToRational(qn: f64) Rational {
    // whole notes = qn / 4, so n/96 with n = round(qn/4 * 96) = round(qn * 24).
    const n: i64 = @intFromFloat(@round(qn * @as(f64, @floatFromInt(@divExact(snap_den, 4)))));
    return Rational.of(n, snap_den);
}

/// An exact rational in whole notes back to quarter notes.
pub fn rationalToQn(r: Rational) f64 {
    return 4.0 * @as(f64, @floatFromInt(r.num)) / @as(f64, @floatFromInt(r.den));
}

// ---- building the musical context -------------------------------------------

/// Builds the context covering [from_qn, to_qn), one bar at a time as the
/// source reports them, so a meter change or a partial bar inside the span
/// is described rather than assumed away.
pub fn contextForSpan(allocator: std.mem.Allocator, src: timemap.BarSource, from_qn: f64, to_qn: f64) !meter.Context {
    var bars = std.ArrayList(meter.Bar).init(allocator);
    errdefer bars.deinit();

    var it = timemap.walkBars(src, from_qn, to_qn);
    while (it.next()) |bar| {
        try bars.append(.{
            .start = qnToRational(bar.start_qn),
            .end = qnToRational(bar.end_qn),
            .hierarchy = meter.hierarchyFor(bar.sig.num, bar.sig.denom),
        });
    }
    return .{ .bars = try bars.toOwnedSlice() };
}

pub fn freeContext(allocator: std.mem.Allocator, ctx: meter.Context) void {
    meter.freeContext(allocator, ctx);
}

// ---- notes to events and back ------------------------------------------------

/// One attack: a chord's worth of notes sharing a start, with the span it
/// reads as. `count` notes starting at `first` in the chord-ordered slice
/// it came from.
pub const Attack = struct {
    first: usize,
    count: usize,
    start: Rational,
    /// The end this attack reads as, which is its own end clipped to the
    /// next attack — a note overlapping the next one is notated as ending
    /// where the next begins, since the sequence has to read as one voice.
    end: Rational,
};

/// Groups chord-ordered notes (see helpers.sortChordOrder) into attacks,
/// snapping positions to exact rationals and clipping each attack's notated
/// end to the next attack's start.
///
/// Chords collapse to one attack because the simplifier reasons about one
/// voice: every note of a chord gets the same notated length, which is what
/// a chord is. Independent polyphony in one take would need a voice split
/// first, and is not handled.
pub fn attacksOf(allocator: std.mem.Allocator, notes: []const helpers.QnNote) ![]Attack {
    var out = std.ArrayList(Attack).init(allocator);
    errdefer out.deinit();

    var i: usize = 0;
    while (i < notes.len) {
        const start_qn = notes[i].start_qn;
        const first = i;
        var end_qn = notes[i].end_qn;
        while (i < notes.len and notes[i].start_qn == start_qn) {
            end_qn = @max(end_qn, notes[i].end_qn);
            i += 1;
        }
        try out.append(.{
            .first = first,
            .count = i - first,
            .start = qnToRational(start_qn),
            .end = qnToRational(end_qn),
        });
    }

    // Clip each attack to the next, and drop any left with no length (two
    // attacks snapping onto the same position), since a zero-length symbol
    // is not notatable and would break the tiling's advance.
    var kept = std.ArrayList(Attack).init(allocator);
    errdefer kept.deinit();
    for (out.items, 0..) |attack, k| {
        var a = attack;
        if (k + 1 < out.items.len) a.end = Rational.min(a.end, out.items[k + 1].start);
        if (a.start.lt(a.end)) try kept.append(a);
    }
    out.deinit();
    return kept.toOwnedSlice();
}

/// The note/rest sequence a list of attacks reads as: each attack's span as
/// a note, each gap between attacks as a rest.
///
/// `until` bounds the last note's room — the end of the item, normally.
/// Without it the final note could never be lengthened, so two notes with
/// the same silence after them would come out different lengths purely
/// because one happened to be last.
pub fn eventsOf(allocator: std.mem.Allocator, attacks: []const Attack, until: ?Rational) ![]rs.Event {
    var out = std.ArrayList(rs.Event).init(allocator);
    errdefer out.deinit();
    for (attacks, 0..) |a, i| {
        try out.append(.{ .kind = .note, .dur = a.end.sub(a.start) });
        const next_start = if (i + 1 < attacks.len) attacks[i + 1].start else until orelse continue;
        const gap = next_start.sub(a.end);
        if (Rational.zero().lt(gap)) try out.append(.{ .kind = .rest, .dur = gap });
    }
    return out.toOwnedSlice();
}

/// The notated duration of each attack in a simplified event list: a tied
/// run is one attack, so its pieces sum. Returns an error if the list does
/// not hold exactly `expected` attacks, which would mean the simplifier
/// added or lost one — writing lengths back from a mismatched list could
/// put them on the wrong notes, so it is refused rather than guessed.
pub fn attackDurations(allocator: std.mem.Allocator, events: []const rs.Event, expected: usize) ![]Rational {
    var out = std.ArrayList(Rational).init(allocator);
    errdefer out.deinit();

    var i: usize = 0;
    while (i < events.len) {
        if (events[i].kind != .note) {
            i += 1;
            continue;
        }
        var total = Rational.zero();
        // Walk the tied run: every piece but the last carries the tie.
        while (i < events.len and events[i].kind == .note) {
            total = total.add(events[i].dur);
            const tied = events[i].tied_to_next;
            i += 1;
            if (!tied) break;
        }
        try out.append(total);
    }

    if (out.items.len != expected) return error.AttackCountMismatch;
    return out.toOwnedSlice();
}

// ---- the action ---------------------------------------------------------------

/// The take's item end, in whole notes, which bounds how far the last note
/// may be lengthened. Null when the item cannot be read, in which case the
/// last note is simply left alone.
fn itemEndRational(take: *Reaper.MediaItem_Take) ?Rational {
    const item = Reaper.GetMediaItemTake_Item(take);
    const pos = Reaper.GetMediaItemInfo_Value(item, "D_POSITION");
    const len = Reaper.GetMediaItemInfo_Value(item, "D_LENGTH");
    if (len <= 0) return null;
    return qnToRational(timemap.timeToQn(pos + len));
}

/// Collects the take's notes in QN, keeping the selected ones when any are
/// selected, in chord order.
fn collectTargetNotes(allocator: std.mem.Allocator, take: *Reaper.MediaItem_Take) ?[]helpers.QnNote {
    var n_notes: c_int = 0;
    var n_cc: c_int = 0;
    var n_sysex: c_int = 0;
    _ = Reaper.MIDI_CountEvts(take, &n_notes, &n_cc, &n_sysex);

    var list = std.ArrayList(helpers.QnNote).init(allocator);
    defer list.deinit();
    var any_selected = false;
    var i: c_int = 0;
    while (i < n_notes) : (i += 1) {
        var selected = false;
        var muted = false;
        var start_ppq: f64 = 0;
        var end_ppq: f64 = 0;
        var chan: c_int = 0;
        var pitch: c_int = 0;
        var vel: c_int = 0;
        if (!Reaper.MIDI_GetNote(take, i, &selected, &muted, &start_ppq, &end_ppq, &chan, &pitch, &vel)) continue;
        if (selected) any_selected = true;
        list.append(.{
            .idx = i,
            .selected = selected,
            .muted = muted,
            .start_qn = Reaper.MIDI_GetProjQNFromPPQPos(take, start_ppq),
            .end_qn = Reaper.MIDI_GetProjQNFromPPQPos(take, end_ppq),
            .chan = chan,
            .pitch = pitch,
            .vel = vel,
        }) catch return null;
    }

    if (any_selected) {
        var w: usize = 0;
        for (list.items) |n| {
            if (n.selected) {
                list.items[w] = n;
                w += 1;
            }
        }
        list.shrinkRetainingCapacity(w);
    }

    const notes = list.toOwnedSlice() catch return null;
    helpers.sortChordOrder(notes);
    return notes;
}

fn simplifyNoteLengths(_: *actions.RunCtx) void {
    const alloc = helpers.allocator;
    const editor = helpers.midiEditorActive() orelse return;
    const take = helpers.midiEditorTake(editor) orelse return;

    const notes = collectTargetNotes(alloc, take) orelse return;
    defer alloc.free(notes);
    if (notes.len == 0) return;

    const attacks = attacksOf(alloc, notes) catch return;
    defer alloc.free(attacks);
    if (attacks.len == 0) return;

    const item_end = itemEndRational(take);
    const events = eventsOf(alloc, attacks, item_end) catch return;
    defer alloc.free(events);

    const from_qn = rationalToQn(attacks[0].start);
    const to_qn = rationalToQn(attacks[attacks.len - 1].end);
    const ctx = contextForSpan(alloc, timemap.reaperBarSource(), from_qn, to_qn) catch return;
    defer freeContext(alloc, ctx);
    if (ctx.bars.len == 0) return;

    const simplified = rs.simplify(alloc, ctx, attacks[0].start, events) catch return;
    defer alloc.free(simplified);

    const durations = attackDurations(alloc, simplified, attacks.len) catch |err| {
        log.err("not writing note lengths: {s}", .{@errorName(err)});
        return;
    };
    defer alloc.free(durations);

    Reaper.Undo_BeginBlock();
    for (attacks, durations) |attack, dur| {
        const new_end_qn = rationalToQn(attack.start.add(dur));
        const new_end_ppq = Reaper.MIDI_GetPPQPosFromProjQN(take, new_end_qn);
        for (notes[attack.first .. attack.first + attack.count]) |n| {
            const start_ppq = Reaper.MIDI_GetPPQPosFromProjQN(take, n.start_qn);
            // Every write passes noSort, with one MIDI_Sort afterwards: a
            // sorting write can reorder the take mid-loop and leave the
            // cached note indices stale (see kawa.zig's header).
            const no_sort = true;
            var selected = n.selected;
            var muted = n.muted;
            var chan = n.chan;
            var pitch = n.pitch;
            var vel = n.vel;
            var start_mut = start_ppq;
            var end_mut = new_end_ppq;
            _ = Reaper.MIDI_SetNote(take, n.idx, &selected, &muted, &start_mut, &end_mut, &chan, &pitch, &vel, &no_sort);
        }
    }
    Reaper.MIDI_Sort(take);
    Reaper.Undo_EndBlock("Perken: simplify note lengths", -1);
    Reaper.UpdateArrange();
}

pub const entries = [_]actions.Entry{
    .{
        .name = "SimplifyNoteLengths",
        .def = .{
            .steps = &.{.{ .func = &simplifyNoteLengths }},
            .midi_command = true,
            .desc = "Simplify note lengths to the simplest value each position allows",
        },
    },
};

// ---- tests -------------------------------------------------------------------

test "quarter notes convert to exact rationals and back" {
    try std.testing.expect(qnToRational(1.0).eq(Rational.of(1, 4))); // a quarter
    try std.testing.expect(qnToRational(0.5).eq(Rational.of(1, 8))); // an eighth
    try std.testing.expect(qnToRational(4.0).eq(Rational.of(1, 1))); // a whole
    try std.testing.expect(qnToRational(6.0).eq(Rational.of(3, 2))); // a dotted whole
    try std.testing.expect(qnToRational(1.0 / 3.0).eq(Rational.of(1, 12))); // triplet eighth
    try std.testing.expectApproxEqAbs(@as(f64, 1.5), rationalToQn(Rational.of(3, 8)), 1e-12);
}

test "a position a tick off the grid snaps to the value it means" {
    // What REAPER hands back after quantising is close, not exact.
    try std.testing.expect(qnToRational(0.9997).eq(Rational.of(1, 4)));
    try std.testing.expect(qnToRational(1.0004).eq(Rational.of(1, 4)));
}

test "a context is built from the grid's own barlines, meter change and all" {
    const allocator = std.testing.allocator;
    // 4/4 at QN 0, then 3/4 at QN 4, two bars of it.
    const grid = timemap.FakeGrid{
        .starts = &.{ 0, 4, 7, 10 },
        .sigs = &.{ .{ .num = 4, .denom = 4 }, .{ .num = 3, .denom = 4 }, .{ .num = 3, .denom = 4 } },
    };
    const ctx = try contextForSpan(allocator, grid.source(), 0, 10);
    defer freeContext(allocator, ctx);

    try std.testing.expectEqual(@as(usize, 3), ctx.bars.len);
    try std.testing.expect(ctx.bars[0].hierarchy.len.eq(Rational.of(1, 1)));
    try std.testing.expect(ctx.bars[1].hierarchy.len.eq(Rational.of(3, 4)));
    // Boundaries come from the grid, in whole notes: QN 4 is 1 whole note.
    try std.testing.expect(ctx.bars[1].start.eq(Rational.of(1, 1)));
    try std.testing.expect(ctx.bars[2].end.eq(Rational.of(10, 4)));
}

test "a short bar keeps the length the grid gives it, not the signature's" {
    const allocator = std.testing.allocator;
    // A 4/4 bar cut short at QN 3 by a marker placed off the barline.
    const grid = timemap.FakeGrid{
        .starts = &.{ 0, 3, 7 },
        .sigs = &.{ .{ .num = 4, .denom = 4 }, .{ .num = 4, .denom = 4 } },
    };
    const ctx = try contextForSpan(allocator, grid.source(), 0, 5);
    defer freeContext(allocator, ctx);

    try std.testing.expect(ctx.bars[0].end.eq(Rational.of(3, 4)));
    // The hierarchy is still 4/4's; the bar is simply shorter than it.
    try std.testing.expect(ctx.bars[0].hierarchy.len.eq(Rational.of(1, 1)));
}

test "chords become one attack and overlaps are clipped to the next" {
    const allocator = std.testing.allocator;
    const notes = [_]helpers.QnNote{
        // A three-note chord at QN 0, lasting 2 QN.
        .{ .idx = 0, .selected = false, .muted = false, .start_qn = 0, .end_qn = 2, .chan = 0, .pitch = 72, .vel = 96 },
        .{ .idx = 1, .selected = false, .muted = false, .start_qn = 0, .end_qn = 2, .chan = 0, .pitch = 67, .vel = 96 },
        .{ .idx = 2, .selected = false, .muted = false, .start_qn = 0, .end_qn = 2, .chan = 0, .pitch = 64, .vel = 96 },
        // A note at QN 1 — the chord above overlaps it and must be clipped.
        .{ .idx = 3, .selected = false, .muted = false, .start_qn = 1, .end_qn = 2, .chan = 0, .pitch = 60, .vel = 96 },
    };
    const attacks = try attacksOf(allocator, &notes);
    defer allocator.free(attacks);

    try std.testing.expectEqual(@as(usize, 2), attacks.len);
    try std.testing.expectEqual(@as(usize, 3), attacks[0].count);
    // Clipped from QN 2 to QN 1, which is 1/4 of a whole note.
    try std.testing.expect(attacks[0].end.eq(Rational.of(1, 4)));
    try std.testing.expectEqual(@as(usize, 1), attacks[1].count);
}

test "events are the attacks with the gaps between them as rests" {
    const allocator = std.testing.allocator;
    const attacks = [_]Attack{
        .{ .first = 0, .count = 1, .start = Rational.zero(), .end = Rational.of(1, 8) },
        // A gap of an eighth, then another eighth-long note.
        .{ .first = 1, .count = 1, .start = Rational.of(1, 4), .end = Rational.of(3, 8) },
    };
    const events = try eventsOf(allocator, &attacks, null);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 3), events.len);
    try std.testing.expectEqual(rs.Kind.note, events[0].kind);
    try std.testing.expectEqual(rs.Kind.rest, events[1].kind);
    try std.testing.expect(events[1].dur.eq(Rational.of(1, 8)));
    try std.testing.expectEqual(rs.Kind.note, events[2].kind);
}

test "a tied run counts as the one attack it is" {
    const allocator = std.testing.allocator;
    const events = [_]rs.Event{
        .{ .kind = .note, .dur = Rational.of(1, 8), .tied_to_next = true },
        .{ .kind = .note, .dur = Rational.of(1, 8) },
        .{ .kind = .rest, .dur = Rational.of(1, 4) },
        .{ .kind = .note, .dur = Rational.of(1, 4) },
    };
    const durs = try attackDurations(allocator, &events, 2);
    defer allocator.free(durs);

    try std.testing.expectEqual(@as(usize, 2), durs.len);
    // The tied pair is one attack of a quarter.
    try std.testing.expect(durs[0].eq(Rational.of(1, 4)));
    try std.testing.expect(durs[1].eq(Rational.of(1, 4)));
}

test "a mismatched attack count is refused rather than written to wrong notes" {
    const allocator = std.testing.allocator;
    const events = [_]rs.Event{.{ .kind = .note, .dur = Rational.of(1, 4) }};
    try std.testing.expectError(error.AttackCountMismatch, attackDurations(allocator, &events, 2));
}

test "the note+rest collapse is what reaches the MIDI data" {
    const allocator = std.testing.allocator;
    // The motivating case: eighth note, eighth rest, eighth note, eighth
    // rest. The notation is two staccato quarters, so each note's length
    // goes from an eighth to a quarter.
    const attacks = [_]Attack{
        .{ .first = 0, .count = 1, .start = Rational.zero(), .end = Rational.of(1, 8) },
        .{ .first = 1, .count = 1, .start = Rational.of(1, 4), .end = Rational.of(3, 8) },
    };
    // The item runs to the half bar, so the second note has silence after
    // it too — without that bound it could never be lengthened.
    const events = try eventsOf(allocator, &attacks, Rational.of(1, 2));
    defer allocator.free(events);

    const ctx = try meter.uniform(allocator, Rational.zero(), 4, 4, 2);
    defer meter.freeContext(allocator, ctx);
    const simplified = try rs.simplify(allocator, ctx, attacks[0].start, events);
    defer allocator.free(simplified);

    const durs = try attackDurations(allocator, simplified, attacks.len);
    defer allocator.free(durs);
    try std.testing.expect(durs[0].eq(Rational.of(1, 4)));
    try std.testing.expect(durs[1].eq(Rational.of(1, 4)));
}
