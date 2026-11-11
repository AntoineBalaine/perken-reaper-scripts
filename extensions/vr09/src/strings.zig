//! The plugin's strings: the names of the patches, the tones and the groups, the file names of the library, and
//! the names that the player types. Each distinct text is stored once, in the pool of reaziglib's `string_pool`,
//! and the panel, the rows of the patch table and the actions refer to it by a small ID.
//!
//! The pool is made when the plugin is made, grows when a string is first seen, and is freed with the plugin.
//! Nothing is taken out of it, because the strings are few and most of them are the keyboard's own tones and
//! registrations. A new name that the player types adds one string.
//!
//! The first string is the empty one, so the ID 0 is always the empty text.
//!
//! The texts are null-terminated slices from end to end, the way the pool and the REAPER API want them. Because
//! the pool grows in one block of memory that may move, the slice that `get` returns is only good until the next
//! `intern`. A caller that reads a string and then interns another copies the first one out.
const std = @import("std");
const string_pool = @import("string_pool");

pub const Ref = string_pool.StringPool.StringRef;

/// The ID of the empty text.
pub const empty: Ref = @fromBackingInt(@intCast(0));

/// The room of the buffers that format a text before it is stored. Names and file names are far shorter.
pub const max_text = 255;

/// The room taken at the start, so that the pool rarely has to move: the tones, the registrations and the
/// strings of the panel take about 10 KB.
const reserve = 32 * 1024;

pub const Strings = struct {
    pool: string_pool.StringPool = .empty,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Strings {
        var strings = Strings{ .allocator = allocator };
        strings.pool.bytes.ensureTotalCapacity(allocator, reserve) catch {};
        _ = strings.intern("");
        return strings;
    }

    pub fn deinit(self: *Strings) void {
        self.pool.deinit(self.allocator);
    }

    /// The ID of a text, which is stored when it is new. Because the plugin keeps its texts null-terminated, as
    /// the pool does, nothing is copied before the lookup. Returns the ID of the empty text when there is no
    /// memory for it.
    pub fn intern(self: *Strings, text: [:0]const u8) Ref {
        return self.pool.intern(self.allocator, text) catch empty;
    }

    /// The ID of a text that is not null-terminated: a piece of a file's contents, or a field of a command. Because
    /// the pool wants a terminated text, the text is copied first, and it is cut at `max_text` bytes and at a
    /// zero byte. Texts that the plugin makes itself are terminated, and go through `intern`.
    pub fn internSlice(self: *Strings, text: []const u8) Ref {
        const cut = std.mem.sliceTo(text, 0);
        var buf: [max_text:0]u8 = undefined;
        const n = @min(cut.len, max_text);
        @memcpy(buf[0..n], cut[0..n]);
        buf[n] = 0;
        return self.intern(buf[0..n :0]);
    }

    /// The text of an ID, until the next `intern`.
    pub fn get(self: *const Strings, ref: Ref) [:0]const u8 {
        return self.pool.get(ref);
    }
};

test "a text is stored once, and the first string is the empty one" {
    var strings = Strings.init(std.testing.allocator);
    defer strings.deinit();
    try std.testing.expectEqualStrings("", strings.get(empty));
    const a = strings.intern("Warm Pad");
    const b = strings.intern("Warm Pad");
    try std.testing.expectEqual(a, b);
    try std.testing.expect(a != strings.intern("Warm Pad 2"));
    try std.testing.expectEqualStrings("Warm Pad", strings.get(a));
    try std.testing.expectEqual(empty, strings.intern(""));
}

test "a text that is not terminated is copied, cut at the limit and at a zero byte" {
    var strings = Strings.init(std.testing.allocator);
    defer strings.deinit();
    const long: [400]u8 = @splat('x');
    try std.testing.expectEqual(@as(usize, max_text), strings.get(strings.internSlice(&long)).len);
    try std.testing.expectEqualStrings("ab", strings.get(strings.internSlice("ab\x00cd")));
    try std.testing.expectEqual(strings.intern("Pad"), strings.internSlice("Pad 2"[0..3]));
}

test "every declaration compiles" {
    std.testing.refAllDecls(@This());
}
