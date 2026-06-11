//! Binding trie: built once at config load, walked one node per keystroke.
//! Nodes may carry both a value and children (e.g. "g" bound while "gg" also
//! exists); the engine decides the disambiguation policy. Completions for the
//! feedback window are the children of the cursor's node.
const std = @import("std");
const keymod = @import("key.zig");
const Key = keymod.Key;

pub fn Trie(comptime V: type) type {
    return struct {
        const Self = @This();

        pub const Node = struct {
            children: std.AutoArrayHashMapUnmanaged(u16, u32) = .{},
            value: ?V = null,
            /// Folder label ("+change/fit") shown in completion hints.
            label: ?[]const u8 = null,
        };

        nodes: std.ArrayListUnmanaged(Node) = .{},
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) !Self {
            var self = Self{ .allocator = allocator };
            try self.nodes.append(allocator, .{}); // root at index 0
            return self;
        }

        pub fn deinit(self: *Self) void {
            for (self.nodes.items) |*n| n.children.deinit(self.allocator);
            self.nodes.deinit(self.allocator);
        }

        pub const InsertError = error{ DuplicateBinding, OutOfMemory };

        pub fn insert(self: *Self, seq: []const Key, value: V) InsertError!void {
            std.debug.assert(seq.len > 0);
            const idx = try self.walkOrCreate(seq);
            const node = &self.nodes.items[idx];
            if (node.value != null) return error.DuplicateBinding;
            node.value = value;
        }

        /// Attaches a folder label to a prefix (creating it if needed).
        pub fn setLabel(self: *Self, seq: []const Key, label: []const u8) !void {
            const idx = try self.walkOrCreate(seq);
            self.nodes.items[idx].label = label;
        }

        fn walkOrCreate(self: *Self, seq: []const Key) !u32 {
            var idx: u32 = 0;
            for (seq) |k| {
                const gop = try self.nodes.items[idx].children.getOrPut(self.allocator, k.bits());
                if (!gop.found_existing) {
                    gop.value_ptr.* = @intCast(self.nodes.items.len);
                    try self.nodes.append(self.allocator, .{});
                }
                idx = gop.value_ptr.*;
            }
            return idx;
        }

        pub const StepResult = union(enum) {
            /// Key matches no child of the current node.
            nomatch,
            /// Moved to a node with children and no value — more keys needed.
            pending: u32,
            /// Moved to a leaf with a value — unambiguous match.
            exact: V,
            /// Moved to a node with both a value and children.
            ambiguous: struct { node: u32, value: V },
        };

        pub const Cursor = struct {
            trie: *const Self,
            node: u32 = 0,

            pub fn reset(self: *Cursor) void {
                self.node = 0;
            }

            pub fn step(self: *Cursor, k: Key) StepResult {
                const child = self.trie.nodes.items[self.node].children.get(k.bits()) orelse
                    return .nomatch;
                self.node = child;
                const n = self.trie.nodes.items[child];
                if (n.value) |v| {
                    if (n.children.count() > 0) return .{ .ambiguous = .{ .node = child, .value = v } };
                    return .{ .exact = v };
                }
                return .{ .pending = child };
            }

            pub const Completion = struct { key: Key, label: ?[]const u8, value: ?V };

            /// Iterates the children of the current node, for the feedback UI.
            pub fn completions(self: *const Cursor, buf: []Completion) []Completion {
                const node = self.trie.nodes.items[self.node];
                var i: usize = 0;
                var it = node.children.iterator();
                while (it.next()) |e| {
                    if (i >= buf.len) break;
                    const child = self.trie.nodes.items[e.value_ptr.*];
                    buf[i] = .{
                        .key = @bitCast(e.key_ptr.*),
                        .label = child.label,
                        .value = child.value,
                    };
                    i += 1;
                }
                return buf[0..i];
            }
        };

        pub fn cursor(self: *const Self) Cursor {
            return .{ .trie = self };
        }
    };
}

const TestTrie = Trie([]const u8);

fn kseq(comptime s: []const u8) []const Key {
    const arr = comptime blk: {
        var keys: [16]Key = undefined;
        var n: usize = 0;
        var rest: []const u8 = s;
        while (rest.len > 0) {
            const tok = keymod.parseToken(rest) catch unreachable;
            keys[n] = tok.key;
            n += 1;
            rest = rest[tok.len..];
        }
        const out: [n]Key = keys[0..n].*;
        break :blk out;
    };
    return &arr;
}

test "insert and walk exact match" {
    var t = try TestTrie.init(std.testing.allocator);
    defer t.deinit();

    try t.insert(kseq("gg"), "FirstTrack");
    try t.insert(kseq("G"), "LastTrack");
    try t.insert(kseq("j"), "NextTrack");

    var c = t.cursor();
    switch (c.step((try keymod.parseToken("g")).key)) {
        .pending => {},
        else => return error.TestUnexpectedResult,
    }
    switch (c.step((try keymod.parseToken("g")).key)) {
        .exact => |v| try std.testing.expectEqualStrings("FirstTrack", v),
        else => return error.TestUnexpectedResult,
    }

    c.reset();
    switch (c.step((try keymod.parseToken("G")).key)) {
        .exact => |v| try std.testing.expectEqualStrings("LastTrack", v),
        else => return error.TestUnexpectedResult,
    }
}

test "nomatch leaves cursor in place; ambiguous prefix" {
    var t = try TestTrie.init(std.testing.allocator);
    defer t.deinit();

    try t.insert(kseq("g"), "GoSomewhere");
    try t.insert(kseq("gg"), "FirstTrack");

    var c = t.cursor();
    switch (c.step((try keymod.parseToken("g")).key)) {
        .ambiguous => |a| try std.testing.expectEqualStrings("GoSomewhere", a.value),
        else => return error.TestUnexpectedResult,
    }
    switch (c.step((try keymod.parseToken("x")).key)) {
        .nomatch => {},
        else => return error.TestUnexpectedResult,
    }
}

test "duplicate insert rejected" {
    var t = try TestTrie.init(std.testing.allocator);
    defer t.deinit();
    try t.insert(kseq("j"), "NextTrack");
    try std.testing.expectError(error.DuplicateBinding, t.insert(kseq("j"), "Other"));
}

test "completions list children with labels" {
    var t = try TestTrie.init(std.testing.allocator);
    defer t.deinit();

    try t.setLabel(kseq("c"), "change/fit");
    try t.insert(kseq("ca"), "InsertOrExtendMidiItem");
    try t.insert(kseq("cf"), "FitByLooping");
    try t.insert(kseq("j"), "NextTrack");

    var c = t.cursor();
    var buf: [8]TestTrie.Cursor.Completion = undefined;
    const root_comps = c.completions(&buf);
    try std.testing.expectEqual(@as(usize, 2), root_comps.len);

    switch (c.step((try keymod.parseToken("c")).key)) {
        .pending => {},
        else => return error.TestUnexpectedResult,
    }
    const comps = c.completions(&buf);
    try std.testing.expectEqual(@as(usize, 2), comps.len);
}
