//! The musical context a stretch of music sits in: where its barlines fall
//! and what metric hierarchy each bar has. Everything that needs to reason
//! about bars reads it from here — the notation simplifier
//! (rhythm_simplify.zig) and, when it is migrated, the ABC export.
//!
//! Why a map rather than one time signature: a selection can contain meter
//! changes, and the alternative — splitting the selection at each change
//! and processing the pieces separately — would mangle anything spanning a
//! change, exactly as truncating at the barline once dropped notes. A note
//! held across a 4/4-to-3/4 change is still one note, so the context has to
//! describe the whole span and let the simplifier walk it bar by bar.
//!
//! Bars are stored as explicit boundaries rather than derived by dividing,
//! because REAPER's bar grid is the authority: a time-signature marker
//! placed off a barline produces a genuinely short bar, and computing
//! boundaries arithmetically would disagree with what the user sees.

const std = @import("std");
pub const Rational = @import("rational.zig").Rational;

/// The metric hierarchy of one bar: `len` subdivided by each factor in
/// `divisions` in turn. 4/4 is a bar halved into two half bars, each halved
/// into beats, and so on; 6/8 is a bar halved into two dotted-quarter
/// beats, each split into three eighths. A notated symbol may only span an
/// exact node of this tree, which is what makes a whole rest right for a
/// full bar and a half rest starting on beat 2 of 4/4 wrong.
pub const Hierarchy = struct {
    len: Rational,
    /// One primary beat, reported for callers that want it (the staccato
    /// collapse bounds itself by this); the tree decides legality.
    beat: Rational,
    /// Subdivision factors, stored inline so a Hierarchy is a plain value
    /// with no borrowed storage to outlive.
    division_buf: [max_divisions]u8 = undefined,
    division_count: u8 = 0,

    pub fn divisions(self: *const Hierarchy) []const u8 {
        return self.division_buf[0..self.division_count];
    }
};

/// How deep to subdivide below the beat. Six binary levels below a quarter
/// reaches a 256th, past any quantisation anyone records against.
const sub_beat_levels = 6;

/// Buffer for a derived divisions list: the beat grouping plus the binary
/// levels under it.
const max_divisions = 2 + sub_beat_levels;

/// Derives the hierarchy of a `num`/`denom` time signature as REAPER
/// reports it.
///
/// Beat grouping follows the usual conventions: a compound meter (an eighth
/// or sixteenth denominator whose numerator is a multiple of 3, above 3
/// itself) groups in threes, so 6/8 is two dotted-quarter beats and 12/8 is
/// four; anything else takes `num` beats of one `denom` note. Below the
/// beat it is binary all the way down.
///
/// Irregular meters (5/8, 7/8) have no single correct grouping — 5 can be
/// 3+2 or 2+3, and only the composer's beaming settles it. Rather than
/// invent an asymmetric tree, those take a flat `num` beats, which is
/// always *safe* (every symbol stays within one beat, nothing is dropped)
/// if sometimes more conservative than an engraver would be.
pub fn hierarchyFor(num: u32, denom: u32) Hierarchy {
    std.debug.assert(num > 0 and denom > 0);
    var buf: [max_divisions]u8 = undefined;
    const unit = Rational.of(1, @intCast(denom)); // one denominator note
    const bar_len = unit.mulInt(@intCast(num));

    var n: usize = 0;
    var beat = unit;

    const compound = (denom == 8 or denom == 16) and num % 3 == 0 and num > 3;
    if (compound) {
        const groups = num / 3;
        beat = unit.mulInt(3);
        // Split the bar into its groups, halving first where the group
        // count is even so that 12/8 reads as two halves of two beats
        // rather than four flat beats.
        if (groups % 2 == 0 and groups > 2) {
            buf[n] = 2;
            n += 1;
            buf[n] = @intCast(groups / 2);
            n += 1;
        } else if (groups > 1) {
            buf[n] = @intCast(groups);
            n += 1;
        }
        buf[n] = 3; // each beat into its three denominator notes
        n += 1;
    } else {
        // Simple meter: halve first when the beat count is even, so 4/4
        // gets its half-bar level and a half note on beat 1 stays legal.
        if (num % 2 == 0 and num > 2) {
            buf[n] = 2;
            n += 1;
            buf[n] = @intCast(num / 2);
            n += 1;
        } else if (num > 1) {
            buf[n] = @intCast(num);
            n += 1;
        }
    }

    var i: usize = 0;
    while (i < sub_beat_levels and n < buf.len) : (i += 1) {
        buf[n] = 2;
        n += 1;
    }

    return .{
        .len = bar_len,
        .beat = beat,
        .division_buf = buf,
        .division_count = @intCast(n),
    };
}

/// One bar of the context.
pub const Bar = struct {
    start: Rational,
    end: Rational,
    hierarchy: Hierarchy,
};

/// The barlines and hierarchies covering a stretch of music. Build one with
/// `fromSignatures` for a synthetic context, or from REAPER's bar grid.
/// `bars` must be contiguous and ordered: each bar starts where the
/// previous one ended, with no gaps, so no position inside the span can
/// fail to resolve.
pub const Context = struct {
    bars: []const Bar,

    pub fn start(self: Context) Rational {
        return self.bars[0].start;
    }

    pub fn end(self: Context) Rational {
        return self.bars[self.bars.len - 1].end;
    }

    /// The bar containing `pos`.
    ///
    /// Past the end, the last signature simply continues, which is what
    /// REAPER does too — the final time-signature marker applies for the
    /// rest of the project — so the returned bar is the next one of that
    /// meter rather than a clamp onto the last stored bar. Clamping would
    /// hand back a bar that does not contain `pos`, and tiling against a
    /// bar the span is not in is how spans get mangled. Before the start,
    /// the first signature extends backwards on the same reasoning.
    pub fn barAt(self: Context, pos: Rational) Bar {
        for (self.bars) |bar| {
            if (pos.lt(bar.end) and !pos.lt(bar.start)) return bar;
        }
        const anchor = if (pos.lt(self.start())) self.bars[0] else self.bars[self.bars.len - 1];
        return extend(anchor, pos);
    }
};

/// The bar of `anchor`'s meter that contains `pos`, stepping whole bars
/// from `anchor` in whichever direction is needed.
fn extend(anchor: Bar, pos: Rational) Bar {
    const len = anchor.hierarchy.len;
    // How many whole bars from anchor.start to pos, floored, so the result
    // is the bar containing pos rather than the one after it.
    const offset = pos.sub(anchor.start);
    const n = @divFloor(offset.num * len.den, offset.den * len.num);
    const start = anchor.start.add(len.mulInt(n));
    return .{ .start = start, .end = start.add(len), .hierarchy = anchor.hierarchy };
}

/// A meter change: the signature taking effect, and for how many bars.
pub const Section = struct {
    num: u32,
    denom: u32,
    bars: u32,
};

/// Builds a context from consecutive sections, each contributing whole bars
/// of its signature starting at `from`. For tests and for callers that know
/// the meter layout; the REAPER-backed builder lives in the integration
/// layer, which reads the real barlines.
pub fn fromSections(
    allocator: std.mem.Allocator,
    from: Rational,
    sections: []const Section,
) !Context {
    var bars: std.ArrayList(Bar) = .empty;
    errdefer bars.deinit(allocator);
    var pos = from;
    for (sections) |section| {
        const hierarchy = hierarchyFor(section.num, section.denom);
        var b: u32 = 0;
        while (b < section.bars) : (b += 1) {
            const next = pos.add(hierarchy.len);
            try bars.append(allocator, .{ .start = pos, .end = next, .hierarchy = hierarchy });
            pos = next;
        }
    }
    return .{ .bars = try bars.toOwnedSlice(allocator) };
}

/// Frees a context built by `fromSections`.
pub fn freeContext(allocator: std.mem.Allocator, ctx: Context) void {
    allocator.free(ctx.bars);
}

/// A context of `bars` bars of one signature, the common case.
pub fn uniform(
    allocator: std.mem.Allocator,
    from: Rational,
    num: u32,
    denom: u32,
    bars: u32,
) !Context {
    return fromSections(allocator, from, &.{.{ .num = num, .denom = denom, .bars = bars }});
}

test "4/4 halves the bar before reaching the beat" {
    const h = hierarchyFor(4, 4);
    try std.testing.expect(h.len.eq(Rational.of(1, 1)));
    try std.testing.expect(h.beat.eq(Rational.of(1, 4)));
    try std.testing.expectEqual(@as(u8, 2), h.divisions()[0]);
    try std.testing.expectEqual(@as(u8, 2), h.divisions()[1]);
}

test "3/4 is three beats with no half-bar level" {
    const h = hierarchyFor(3, 4);
    try std.testing.expect(h.len.eq(Rational.of(3, 4)));
    try std.testing.expect(h.beat.eq(Rational.of(1, 4)));
    try std.testing.expectEqual(@as(u8, 3), h.divisions()[0]);
}

test "6/8 is two dotted-quarter beats of three eighths" {
    const h = hierarchyFor(6, 8);
    try std.testing.expect(h.len.eq(Rational.of(3, 4)));
    try std.testing.expect(h.beat.eq(Rational.of(3, 8)));
    try std.testing.expectEqual(@as(u8, 2), h.divisions()[0]);
    try std.testing.expectEqual(@as(u8, 3), h.divisions()[1]);
}

test "12/8 is two halves of two dotted-quarter beats" {
    const h = hierarchyFor(12, 8);
    try std.testing.expect(h.len.eq(Rational.of(3, 2)));
    try std.testing.expect(h.beat.eq(Rational.of(3, 8)));
    try std.testing.expectEqual(@as(u8, 2), h.divisions()[0]);
    try std.testing.expectEqual(@as(u8, 2), h.divisions()[1]);
    try std.testing.expectEqual(@as(u8, 3), h.divisions()[2]);
}

test "3/8 is simple, not compound — three eighths, not one beat" {
    const h = hierarchyFor(3, 8);
    try std.testing.expect(h.len.eq(Rational.of(3, 8)));
    try std.testing.expect(h.beat.eq(Rational.of(1, 8)));
    try std.testing.expectEqual(@as(u8, 3), h.divisions()[0]);
}

test "an irregular meter takes flat beats rather than a guessed grouping" {
    const h = hierarchyFor(7, 8);
    try std.testing.expect(h.len.eq(Rational.of(7, 8)));
    try std.testing.expect(h.beat.eq(Rational.of(1, 8)));
    try std.testing.expectEqual(@as(u8, 7), h.divisions()[0]);
}

test "every derived hierarchy's divisions multiply back to the bar" {
    // The tree has to partition the bar exactly, or tiling could place a
    // node outside it.
    const cases = [_][2]u32{
        .{ 4, 4 },  .{ 3, 4 },  .{ 2, 4 }, .{ 5, 4 }, .{ 6, 8 },
        .{ 9, 8 },  .{ 12, 8 }, .{ 7, 8 }, .{ 3, 8 }, .{ 2, 2 },
        .{ 6, 16 }, .{ 1, 4 },
    };
    for (cases) |c| {
        const h = hierarchyFor(c[0], c[1]);
        var smallest = h.len;
        for (h.divisions()) |d| smallest = smallest.divInt(d);
        // Walking the tree down and multiplying back must return the bar.
        var back = smallest;
        var i = h.divisions().len;
        while (i > 0) : (i -= 1) back = back.mulInt(h.divisions()[i - 1]);
        try std.testing.expect(back.eq(h.len));
    }
}

test "a context resolves every position in its span to the right bar" {
    const allocator = std.testing.allocator;
    // Two bars of 4/4 then two of 3/4, from position 0.
    const ctx = try fromSections(allocator, Rational.zero(), &.{
        .{ .num = 4, .denom = 4, .bars = 2 },
        .{ .num = 3, .denom = 4, .bars = 2 },
    });
    defer freeContext(allocator, ctx);

    try std.testing.expectEqual(@as(usize, 4), ctx.bars.len);
    try std.testing.expect(ctx.end().eq(Rational.of(7, 2))); // 1+1+3/4+3/4

    // Inside bar 1 (4/4).
    try std.testing.expect(ctx.barAt(Rational.of(1, 2)).hierarchy.len.eq(Rational.of(1, 1)));
    // Inside bar 3, the first 3/4 bar, which starts at 2.
    try std.testing.expect(ctx.barAt(Rational.of(2, 1)).hierarchy.len.eq(Rational.of(3, 4)));
    try std.testing.expect(ctx.barAt(Rational.of(2, 1)).start.eq(Rational.of(2, 1)));
    // The boundary itself belongs to the bar starting there, not the one ending.
    try std.testing.expect(ctx.barAt(Rational.of(1, 1)).start.eq(Rational.of(1, 1)));
}

test "past the end the last meter continues, giving a bar that really contains the position" {
    const allocator = std.testing.allocator;
    const ctx = try uniform(allocator, Rational.zero(), 4, 4, 2);
    defer freeContext(allocator, ctx);

    // The context describes [0, 2). Ask well past it.
    const bar = ctx.barAt(Rational.of(9, 2)); // 4.5
    try std.testing.expect(bar.start.eq(Rational.of(4, 1)));
    try std.testing.expect(bar.end.eq(Rational.of(5, 1)));
    // The point of extending rather than clamping: the bar contains the
    // position asked about.
    try std.testing.expect(!Rational.of(9, 2).lt(bar.start));
    try std.testing.expect(Rational.of(9, 2).lt(bar.end));
}

test "before the start the first meter extends backwards" {
    const allocator = std.testing.allocator;
    const ctx = try uniform(allocator, Rational.of(2, 1), 4, 4, 2);
    defer freeContext(allocator, ctx);

    const bar = ctx.barAt(Rational.of(1, 2));
    try std.testing.expect(bar.start.eq(Rational.zero()));
    try std.testing.expect(bar.end.eq(Rational.of(1, 1)));
}

test "a meter change lands on the bar it belongs to, both sides" {
    const allocator = std.testing.allocator;
    const ctx = try fromSections(allocator, Rational.zero(), &.{
        .{ .num = 4, .denom = 4, .bars = 1 },
        .{ .num = 6, .denom = 8, .bars = 2 },
    });
    defer freeContext(allocator, ctx);

    // Last moment of the 4/4 bar.
    try std.testing.expect(ctx.barAt(Rational.of(15, 16)).hierarchy.len.eq(Rational.of(1, 1)));
    // First moment of the first 6/8 bar, and its compound beat.
    const six = ctx.barAt(Rational.of(1, 1));
    try std.testing.expect(six.hierarchy.len.eq(Rational.of(3, 4)));
    try std.testing.expect(six.hierarchy.beat.eq(Rational.of(3, 8)));
}
