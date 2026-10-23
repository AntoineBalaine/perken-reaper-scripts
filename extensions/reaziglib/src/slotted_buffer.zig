const std = @import("std");

/// A contiguous backing array divided into fixed-size sentinel-terminated
/// slots. Each slot has an independently configured size, and the offsets
/// are computed at comptime. Slots are accessed by runtime index.
///
/// Usage:
/// ```
/// const Buf = SlottedBuffer(&.{ 128, 256 });
/// var buf: Buf = .{};
/// buf.set(0, "hello");
/// const slice = buf.get(0); // "hello"
/// const ptr = buf.getBuf(1); // mutable [*:0]u8 for ImGui InputText
/// ```
pub fn SlottedBuffer(comptime slot_sizes: []const usize) type {
    comptime {
        for (slot_sizes) |size| {
            if (size == 0) @compileError("slot size must be greater than zero");
        }
    }

    const total_size = comptime blk: {
        var sum: usize = 0;
        for (slot_sizes) |size| sum += size;
        break :blk sum;
    };

    return struct {
        const Self = @This();

        const offsets: [slot_sizes.len]usize = blk: {
            var result: [slot_sizes.len]usize = undefined;
            var offset: usize = 0;
            for (slot_sizes, 0..) |size, i| {
                result[i] = offset;
                offset += size;
            }
            break :blk result;
        };

        const sizes: [slot_sizes.len]usize = slot_sizes[0..slot_sizes.len].*;

        buffer: [total_size]u8 = [_]u8{0} ** total_size,

        /// Returns a sentinel-terminated slice of the slot's content,
        /// spanning from the slot start up to the first zero byte.
        pub fn get(self: *const Self, slot: usize) [:0]const u8 {
            const start = offsets[slot];
            return std.mem.span(@as([*:0]const u8, @ptrCast(&self.buffer[start])));
        }

        /// Returns a mutable sentinel-terminated pointer to the slot,
        /// suitable for passing to ImGui's InputText widgets.
        pub fn getBuf(self: *Self, slot: usize) [*:0]u8 {
            const start = offsets[slot];
            return @ptrCast(&self.buffer[start]);
        }

        /// Copies content into the slot and zero-pads the remainder.
        pub fn set(self: *Self, slot: usize, content: []const u8) void {
            const start = offsets[slot];
            const size = sizes[slot];
            const dest = self.buffer[start..][0..size];
            @memset(dest, 0);
            const len = @min(content.len, size - 1);
            @memcpy(dest[0..len], content[0..len]);
        }

        /// Returns the capacity of the given slot (including the sentinel).
        pub fn slotSize(slot: usize) usize {
            return sizes[slot];
        }

        /// Returns the number of slots.
        pub fn slotCount() usize {
            return slot_sizes.len;
        }
    };
}

test "get returns empty string for zeroed slot" {
    const Buf = SlottedBuffer(&.{ 32, 64 });
    var buf: Buf = .{};
    try std.testing.expectEqualStrings("", buf.get(0));
    try std.testing.expectEqualStrings("", buf.get(1));
}

test "set and get round-trip" {
    const Buf = SlottedBuffer(&.{ 32, 64 });
    var buf: Buf = .{};
    buf.set(0, "hello");
    buf.set(1, "world");
    try std.testing.expectEqualStrings("hello", buf.get(0));
    try std.testing.expectEqualStrings("world", buf.get(1));
}

test "set truncates content that exceeds slot capacity" {
    const Buf = SlottedBuffer(&.{8});
    var buf: Buf = .{};
    buf.set(0, "this is way too long for the slot");
    try std.testing.expectEqualStrings("this is", buf.get(0));
    try std.testing.expectEqual(@as(usize, 7), buf.get(0).len);
}

test "set overwrites previous content cleanly" {
    const Buf = SlottedBuffer(&.{32});
    var buf: Buf = .{};
    buf.set(0, "long initial content");
    buf.set(0, "short");
    try std.testing.expectEqualStrings("short", buf.get(0));
}

test "slots are independent" {
    const Buf = SlottedBuffer(&.{ 16, 16, 16 });
    var buf: Buf = .{};
    buf.set(0, "aaa");
    buf.set(1, "bbb");
    buf.set(2, "ccc");
    try std.testing.expectEqualStrings("aaa", buf.get(0));
    try std.testing.expectEqualStrings("bbb", buf.get(1));
    try std.testing.expectEqualStrings("ccc", buf.get(2));
}

test "getBuf returns mutable pointer that can be written to" {
    const Buf = SlottedBuffer(&.{32});
    var buf: Buf = .{};
    const ptr = buf.getBuf(0);
    ptr[0] = 'z';
    ptr[1] = 'i';
    ptr[2] = 'g';
    ptr[3] = 0;
    try std.testing.expectEqualStrings("zig", buf.get(0));
}

test "slotSize and slotCount" {
    const Buf = SlottedBuffer(&.{ 128, 256, 512 });
    try std.testing.expectEqual(@as(usize, 128), Buf.slotSize(0));
    try std.testing.expectEqual(@as(usize, 256), Buf.slotSize(1));
    try std.testing.expectEqual(@as(usize, 512), Buf.slotSize(2));
    try std.testing.expectEqual(@as(usize, 3), Buf.slotCount());
}
