//! The order of the modules on a track: where the gate (the shape), the EQ and the compressor are, one after the other, between the input and the output.
//! The orders are those of the Console 1: EQ before the shape and the compressor, the shape and the compressor before the EQ, or the shape, the EQ and the
//! compressor.
//!
//! The three modules change places among the places they have in the chain, and every other FX of the chain keeps its place, so that a plugin that the
//! user put between two modules stays there. Because this is a reordering of indices, it is here, with no call into REAPER, where the unit tests reach it;
//! `mft_fx.applyOrder` moves the FX.
const std = @import("std");

/// The modules whose order changes.
pub const Dyn = enum { gate, eq, comp };

pub const Order = enum {
    eq_s_c,
    s_c_eq,
    s_eq_c,

    pub fn label(self: Order) [:0]const u8 {
        return switch (self) {
            .eq_s_c => "EQ-S-C",
            .s_c_eq => "S-C-EQ",
            .s_eq_c => "S-EQ-C",
        };
    }

    /// The modules in the order, the first one first.
    pub fn sequence(self: Order) [3]Dyn {
        return switch (self) {
            .eq_s_c => .{ .eq, .gate, .comp },
            .s_c_eq => .{ .gate, .comp, .eq },
            .s_eq_c => .{ .gate, .eq, .comp },
        };
    }

    /// The place of a module in the order.
    pub fn rank(self: Order, dyn: Dyn) usize {
        for (self.sequence(), 0..) |d, i| {
            if (d == dyn) return i;
        }
        unreachable;
    }

    /// The order `delta` steps after this one, going round.
    pub fn step(self: Order, delta: i32) Order {
        const n: i32 = @typeInfo(Order).@"enum".field_names.len;
        return @fromBackingInt(@intCast(@as(u8, @intCast(@mod(@as(i32, @backingInt(self)) + delta, n)))));
    }

    /// The order that a label names ("S-EQ-C"), or null for a label that is not one.
    pub fn parse(text: []const u8) ?Order {
        inline for (@typeInfo(Order).@"enum".field_names) |name| {
            const order = @field(Order, name);
            if (std.mem.eql(u8, text, order.label())) return order;
        }
        return null;
    }
};

/// How many FX of a chain the reordering handles. A track has far fewer.
pub const max_fx = 128;

/// Where every FX of a chain goes for the order: `out[i]` is the index, in the chain as it is, of the FX that ends at the place `i`. `kinds` has the module
/// of each FX of the chain, and null for the FX that are not modules. The modules fill the places that the modules have now, in the order, two of a kind
/// keeping theirs; the other FX stay where they are.
pub fn targetChain(kinds: []const ?Dyn, order: Order, out: []usize) void {
    std.debug.assert(kinds.len <= max_fx and out.len >= kinds.len);
    var places: [max_fx]usize = undefined;
    var wanted: [max_fx]usize = undefined;
    var count: usize = 0;
    for (kinds, 0..) |kind, i| {
        out[i] = i;
        if (kind == null) continue;
        places[count] = i;
        wanted[count] = i;
        count += 1;
    }
    // The modules in the order: by their rank in it, and by where they are now for two of the same kind.
    std.mem.sort(usize, wanted[0..count], LessThan{ .kinds = kinds, .order = order }, LessThan.lessThan);
    for (places[0..count], wanted[0..count]) |place, fx| out[place] = fx;
}

const LessThan = struct {
    kinds: []const ?Dyn,
    order: Order,

    fn lessThan(self: LessThan, a: usize, b: usize) bool {
        const ra = self.order.rank(self.kinds[a].?);
        const rb = self.order.rank(self.kinds[b].?);
        if (ra != rb) return ra < rb;
        return a < b;
    }
};

/// The order that the modules of a chain are in, or null when fewer than two different modules are there (any order fits), or when they are in no
/// order of the list. When two orders fit (two modules only), the first of the list is the one.
pub fn orderOf(kinds: []const ?Dyn) ?Order {
    var seen: [3]Dyn = undefined;
    var count: usize = 0;
    for (kinds) |maybe| {
        const kind = maybe orelse continue;
        if (std.mem.indexOfScalar(Dyn, seen[0..count], kind) != null) continue;
        seen[count] = kind;
        count += 1;
    }
    if (count < 2) return null;
    inline for (@typeInfo(Order).@"enum".field_names) |name| {
        const order = @field(Order, name);
        var at: usize = 0;
        var fits = true;
        for (order.sequence()) |d| {
            if (std.mem.indexOfScalar(Dyn, seen[0..count], d) == null) continue;
            if (seen[at] != d) {
                fits = false;
                break;
            }
            at += 1;
        }
        if (fits) return order;
    }
    return null;
}

test "the orders have their labels, their modules in order, go round, and are read back from their labels" {
    const t = std.testing;
    try t.expectEqualStrings("S-EQ-C", Order.s_eq_c.label());
    try t.expectEqual([3]Dyn{ .eq, .gate, .comp }, Order.eq_s_c.sequence());
    try t.expectEqual(Order.eq_s_c, Order.s_eq_c.step(1));
    try t.expectEqual(Order.s_c_eq, Order.s_eq_c.step(-1));
    try t.expectEqual(@as(?Order, .s_c_eq), Order.parse("S-C-EQ"));
    try t.expectEqual(@as(?Order, null), Order.parse("EQ"));
}

test "targetChain: the modules swap among their places, and a plugin between them keeps its place" {
    const t = std.testing;
    // input, EQ, a plugin of the user, gate, comp, output
    const kinds = [_]?Dyn{ null, .eq, null, .gate, .comp, null };
    var out: [6]usize = undefined;
    targetChain(&kinds, .s_eq_c, &out);
    // The places 1, 3 and 4 get the gate, the EQ and the comp; the input, the plugin and the output stay.
    try t.expectEqual([6]usize{ 0, 3, 2, 1, 4, 5 }, out);
    targetChain(&kinds, .eq_s_c, &out);
    try t.expectEqual([6]usize{ 0, 1, 2, 3, 4, 5 }, out);
    targetChain(&kinds, .s_c_eq, &out);
    try t.expectEqual([6]usize{ 0, 3, 2, 4, 1, 5 }, out);
}

test "targetChain: a chain with no module, or with a module missing, is reordered with what it has" {
    const t = std.testing;
    var out: [4]usize = undefined;
    const none = [_]?Dyn{ null, null, null, null };
    targetChain(&none, .s_eq_c, &out);
    try t.expectEqual([4]usize{ 0, 1, 2, 3 }, out);
    const two = [_]?Dyn{ .comp, null, .gate, null };
    targetChain(&two, .s_eq_c, &out);
    try t.expectEqual([4]usize{ 2, 1, 0, 3 }, out);
}

test "orderOf: the order that a chain is in, none for fewer than two modules, and none for a chain in no order" {
    const t = std.testing;
    try t.expectEqual(@as(?Order, .s_eq_c), orderOf(&[_]?Dyn{ null, .gate, null, .eq, .comp }));
    try t.expectEqual(@as(?Order, .eq_s_c), orderOf(&[_]?Dyn{ .eq, .gate, .comp }));
    try t.expectEqual(@as(?Order, .s_c_eq), orderOf(&[_]?Dyn{ .gate, .comp, .eq }));
    try t.expectEqual(@as(?Order, null), orderOf(&[_]?Dyn{ .eq, null }));
    // The comp before the shape is in none of the orders.
    try t.expectEqual(@as(?Order, null), orderOf(&[_]?Dyn{ .comp, .eq, .gate }));
    // Two modules: the first order of the list that fits, which is EQ-S-C for the shape before the compressor.
    try t.expectEqual(@as(?Order, .eq_s_c), orderOf(&[_]?Dyn{ .gate, .comp }));
    try t.expectEqual(@as(?Order, .s_c_eq), orderOf(&[_]?Dyn{ .comp, .eq }));
}
