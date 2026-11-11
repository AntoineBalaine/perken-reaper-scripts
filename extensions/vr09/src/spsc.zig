//! A fixed-size single-producer single-consumer queue.
//!
//! Because the plugin's audio thread may never block or allocate, the user
//! interface hands it work through queues like this one: exactly one thread
//! pushes, exactly one thread pops, and neither ever waits.
const std = @import("std");

pub fn Spsc(comptime T: type, comptime capacity: usize) type {
    comptime std.debug.assert(std.math.isPowerOfTwo(capacity));
    return struct {
        const Self = @This();

        items: [capacity]T = undefined,
        /// Written only by the consumer.
        head: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),
        /// Written only by the producer.
        tail: std.atomic.Value(usize) = std.atomic.Value(usize).init(0),

        /// Returns false when the queue is full, and drops the item.
        pub fn push(self: *Self, item: T) bool {
            const tail = self.tail.load(.monotonic);
            const head = self.head.load(.acquire);
            if (tail -% head == capacity) return false;
            self.items[tail & (capacity - 1)] = item;
            self.tail.store(tail +% 1, .release);
            return true;
        }

        pub fn pop(self: *Self) ?T {
            const head = self.head.load(.monotonic);
            const tail = self.tail.load(.acquire);
            if (head == tail) return null;
            const item = self.items[head & (capacity - 1)];
            self.head.store(head +% 1, .release);
            return item;
        }

        pub fn len(self: *const Self) usize {
            return self.tail.load(.acquire) -% self.head.load(.acquire);
        }
    };
}

test "items come out in the order they went in" {
    var q = Spsc(u32, 4){};
    try std.testing.expect(q.pop() == null);
    try std.testing.expect(q.push(1));
    try std.testing.expect(q.push(2));
    try std.testing.expectEqual(@as(u32, 1), q.pop().?);
    try std.testing.expectEqual(@as(u32, 2), q.pop().?);
    try std.testing.expect(q.pop() == null);
}

test "a full queue refuses an item instead of overwriting" {
    var q = Spsc(u32, 2){};
    try std.testing.expect(q.push(1));
    try std.testing.expect(q.push(2));
    try std.testing.expect(!q.push(3));
    try std.testing.expectEqual(@as(u32, 1), q.pop().?);
    try std.testing.expect(q.push(3));
    try std.testing.expectEqual(@as(usize, 2), q.len());
}

test "it keeps working after the indexes wrap around" {
    var q = Spsc(u8, 2){};
    var i: u8 = 0;
    while (i < 50) : (i += 1) {
        try std.testing.expect(q.push(i));
        try std.testing.expectEqual(i, q.pop().?);
    }
}

const ProducerContext = struct {
    q: Spsc(u32, 64) = .{},

    pub fn produce(self: *ProducerContext) void {
        var i: u32 = 0;
        while (i < 20000) {
            if (self.q.push(i)) i += 1;
        }
    }
};

test "two threads move every item once, in order" {
    var ctx = ProducerContext{};
    const t = try std.Thread.spawn(.{}, ProducerContext.produce, .{&ctx});
    var expected: u32 = 0;
    while (expected < 20000) {
        if (ctx.q.pop()) |v| {
            try std.testing.expectEqual(expected, v);
            expected += 1;
        }
    }
    t.join();
}
