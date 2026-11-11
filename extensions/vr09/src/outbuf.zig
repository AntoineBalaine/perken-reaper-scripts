//! The events a block sends to the host, gathered first and pushed in time
//! order.
//!
//! The host requires the plugin's output events to be sorted by time. Two
//! sources feed one block: the events the plugin passes through from its
//! input, which arrive sorted, and the events the engine produces, which are
//! sorted too but interleave with the first. Because pushing them as they
//! appear would break the order, each source fills its own list and `merge`
//! walks both.
const std = @import("std");

pub const Kind = enum(u8) {
    midi,
    sysex,
    param_value,
    gesture_begin,
    gesture_end,
};

pub const Event = struct {
    time: u32,
    kind: Kind,
    midi: [3]u8 = .{ 0, 0, 0 },
    param_index: u32 = 0,
    value: f64 = 0,
    /// For a SysEx: where its bytes are. Passed-through messages point into
    /// the host's input buffer, which stays valid for the whole process call;
    /// the engine's own point into the plugin's arena.
    sysex_ptr: ?[*]const u8 = null,
    sysex_len: u32 = 0,
};

pub fn List(comptime capacity: usize) type {
    return struct {
        const Self = @This();

        items: [capacity]Event = undefined,
        len: usize = 0,

        pub fn push(self: *Self, event: Event) bool {
            if (self.len == capacity) return false;
            self.items[self.len] = event;
            self.len += 1;
            return true;
        }

        pub fn clear(self: *Self) void {
            self.len = 0;
        }

        pub fn slice(self: *const Self) []const Event {
            return self.items[0..self.len];
        }
    };
}

/// Walks two sorted lists as one. On equal times the first list comes first,
/// so a passed-through note keeps its place before the engine's message.
pub const Merge = struct {
    a: []const Event,
    b: []const Event,
    i: usize = 0,
    j: usize = 0,

    pub fn next(self: *Merge) ?Event {
        if (self.i < self.a.len and (self.j >= self.b.len or self.a[self.i].time <= self.b[self.j].time)) {
            defer self.i += 1;
            return self.a[self.i];
        }
        if (self.j < self.b.len) {
            defer self.j += 1;
            return self.b[self.j];
        }
        return null;
    }
};

/// A bump allocator for the bytes of the engine's SysEx messages, reset at
/// the start of every block.
pub fn Arena(comptime capacity: usize) type {
    return struct {
        const Self = @This();

        bytes: [capacity]u8 = undefined,
        used: usize = 0,

        pub fn reset(self: *Self) void {
            self.used = 0;
        }

        pub fn copy(self: *Self, data: []const u8) ?[]const u8 {
            if (self.used + data.len > capacity) return null;
            const start = self.used;
            @memcpy(self.bytes[start .. start + data.len], data);
            self.used += data.len;
            return self.bytes[start .. start + data.len];
        }
    };
}

test "merge keeps both lists sorted and prefers the first on ties" {
    const a = [_]Event{
        .{ .time = 0, .kind = .midi },
        .{ .time = 10, .kind = .midi },
        .{ .time = 10, .kind = .midi, .midi = .{ 1, 0, 0 } },
    };
    const b = [_]Event{
        .{ .time = 5, .kind = .sysex },
        .{ .time = 10, .kind = .sysex },
        .{ .time = 20, .kind = .sysex },
    };
    var m = Merge{ .a = &a, .b = &b };
    var times: [6]u32 = undefined;
    var kinds: [6]Kind = undefined;
    var n: usize = 0;
    while (m.next()) |e| : (n += 1) {
        times[n] = e.time;
        kinds[n] = e.kind;
    }
    try std.testing.expectEqual(@as(usize, 6), n);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 0, 5, 10, 10, 10, 20 }, &times);
    try std.testing.expectEqual(Kind.midi, kinds[2]);
    try std.testing.expectEqual(Kind.midi, kinds[3]);
    try std.testing.expectEqual(Kind.sysex, kinds[4]);
}

test "a list refuses more than its capacity and the arena runs out" {
    var l = List(2){};
    try std.testing.expect(l.push(.{ .time = 0, .kind = .midi }));
    try std.testing.expect(l.push(.{ .time = 1, .kind = .midi }));
    try std.testing.expect(!l.push(.{ .time = 2, .kind = .midi }));
    var arena = Arena(4){};
    try std.testing.expect(arena.copy("abc") != null);
    try std.testing.expect(arena.copy("de") == null);
    arena.reset();
    try std.testing.expect(arena.copy("de") != null);
}
