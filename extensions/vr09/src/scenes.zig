//! The session's scenes: an ordered list of named patches, kept in the plugin's saved state.
//!
//! A scene holds its own copy of a patch (a dump), so that editing or deleting the library afterwards
//! cannot change what a session plays. The Scene parameter holds a position in this list: 0 means no
//! scene, and positions count from 1, which is how the user sees the list.
//!
//! Only the main thread reads or changes the list. The audio thread only stores the position that an
//! automation lane asked for, and the main thread loads it at its next tick.
const std = @import("std");
const dump = @import("dump.zig");

/// The Scene parameter has a fixed range, so that adding a scene never rescales the points of a
/// lane that already refers to the scenes by position.
pub const max_scenes = 127;
pub const max_name = 48;

pub const Scene = struct {
    name_buf: [max_name:0]u8 = [_:0]u8{0} ** max_name,
    /// Which patch of the library the scene was made from, and a short text for the panel to show. They
    /// let a panel list the scenes, and save them as a template, without reading the dump. A scene made
    /// from the plugin's own state has no patch ID (0).
    patch_id: u16 = 0,
    label_buf: [max_name:0]u8 = [_:0]u8{0} ** max_name,
    patch: dump.Dump = .{},

    pub fn name(self: *const Scene) [:0]const u8 {
        return std.mem.sliceTo(&self.name_buf, 0);
    }

    pub fn label(self: *const Scene) [:0]const u8 {
        return std.mem.sliceTo(&self.label_buf, 0);
    }

    /// Longer names are cut, because the list stores a fixed number of bytes for each.
    pub fn setName(self: *Scene, text: []const u8) void {
        const n = @min(text.len, max_name);
        @memcpy(self.name_buf[0..n], text[0..n]);
        self.name_buf[n] = 0;
    }

    pub fn setLabel(self: *Scene, text: []const u8) void {
        const n = @min(text.len, max_name);
        @memcpy(self.label_buf[0..n], text[0..n]);
        self.label_buf[n] = 0;
    }
};

pub const Error = error{ Full, Truncated, BadCount };

/// The parts that take a tone from the piano and synth lists. The drum kits are left out: the unit's
/// drum block is not a plain tone triple (docs/midi-capabilities.md in the roland-vr09 project).
pub const tone_parts = [_][:0]const u8{ "upper_piano", "upper_piano_dual2", "lower_piano", "upper_synth", "upper_synth_dual2", "lower_synth" };

/// Fills `out` with a patch that holds one part's tone and nothing else: the tone number, the bank MSB
/// and the bank LSB, at offset 1 of the part's block. Because a recall writes only the bytes that its
/// patch knows, selecting such a scene sends one three-byte message. This relies on a tone replacing
/// the whole sound of the keyboard, which has not been tried on the unit. Returns false for a part
/// that is not in `tone_parts`.
pub fn toneDump(out: *dump.Dump, part: []const u8, number: u8, msb: u8, lsb: u8) bool {
    for (tone_parts) |name| {
        if (!std.mem.eql(u8, name, part)) continue;
        const block = dump.blockByName(name) orelse return false;
        const base = dump.block_offsets[block] + 1;
        const bytes = [3]u8{ number, msb, lsb };
        for (bytes, 0..) |value, i| {
            out.values[base + i] = value;
            out.known[base + i] = true;
        }
        return true;
    }
    return false;
}

/// Where every position goes when a scene moves or is removed: `map[i - 1]` is the new position of the
/// position `i`, and 0 stands for "no scene". An automation lane holds positions, so it needs the same
/// change for its points, to keep playing the same scenes.
pub const Mapping = [max_scenes]u8;

/// The mapping for moving the scene at `from` to `to`, in a list of `count` scenes.
pub fn moveMapping(count: usize, from: usize, to: usize, map: *Mapping) void {
    for (0..count) |k| {
        const i = k + 1;
        const new: usize = if (i == from)
            to
        else if (from < to and i > from and i <= to)
            i - 1
        else if (from > to and i >= to and i < from)
            i + 1
        else
            i;
        map[k] = @intCast(new);
    }
}

/// The mapping for removing the scene at `at`: its own points fall to 0 and the later scenes move up.
pub fn removeMapping(count: usize, at: usize, map: *Mapping) void {
    for (0..count) |k| {
        const i = k + 1;
        map[k] = @intCast(if (i == at) 0 else if (i > at) i - 1 else i);
    }
}

/// A list takes about half a megabyte, so it is allocated, not copied around.
pub const List = struct {
    count: u8 = 0,
    items: [max_scenes]Scene = undefined,

    /// The scene at a position (from 1), or null when there is none.
    pub fn get(self: *const List, position: usize) ?*const Scene {
        if (position < 1 or position > self.count) return null;
        return &self.items[position - 1];
    }

    /// Appends a copy of a patch. Gives the new scene's position.
    pub fn add(self: *List, scene_name: []const u8, patch: *const dump.Dump) Error!u8 {
        return self.addFrom(scene_name, patch, 0, "");
    }

    /// Appends a copy of a patch of the library, with its ID and label.
    pub fn addFrom(self: *List, scene_name: []const u8, patch: *const dump.Dump, patch_id: u16, patch_label: []const u8) Error!u8 {
        if (self.count >= max_scenes) return error.Full;
        const item = &self.items[self.count];
        item.* = .{};
        item.setName(scene_name);
        item.setLabel(patch_label);
        item.patch_id = patch_id;
        item.patch = patch.*;
        self.count += 1;
        return self.count;
    }

    /// Removes a scene; the scenes after it move up by one.
    pub fn remove(self: *List, position: usize) bool {
        if (position < 1 or position > self.count) return false;
        var i = position - 1;
        while (i + 1 < self.count) : (i += 1) self.items[i] = self.items[i + 1];
        self.count -= 1;
        return true;
    }

    /// Moves a scene to another position; the scenes in between shift by one.
    pub fn move(self: *List, from: usize, to: usize) bool {
        if (from < 1 or from > self.count or to < 1 or to > self.count) return false;
        if (from == to) return true;
        const moved = self.items[from - 1];
        if (from < to) {
            var i = from - 1;
            while (i < to - 1) : (i += 1) self.items[i] = self.items[i + 1];
        } else {
            var i = from - 1;
            while (i > to - 1) : (i -= 1) self.items[i] = self.items[i - 1];
        }
        self.items[to - 1] = moved;
        return true;
    }

    pub fn rename(self: *List, position: usize, scene_name: []const u8) bool {
        if (position < 1 or position > self.count) return false;
        self.items[position - 1].setName(scene_name);
        return true;
    }

    pub fn clear(self: *List) void {
        self.count = 0;
    }

    // ---- the saved state ----

    const bitmap_bytes = (dump.total_bytes + 7) / 8;

    /// Writes the count, then each scene: its name, which bytes of its patch are known, and the values.
    pub fn write(self: *const List, writer: anytype) !void {
        try writer.writeByte(self.count);
        for (self.items[0..self.count]) |*scene| {
            // The saved state keeps the length of each text, so that a state saved before the texts were
            // null-terminated is still read.
            try writer.writeByte(@intCast(scene.name().len));
            try writer.writeAll(scene.name());
            try writer.writeInt(u16, scene.patch_id, .little);
            try writer.writeByte(@intCast(scene.label().len));
            try writer.writeAll(scene.label());
            var bits: [bitmap_bytes]u8 = [_]u8{0} ** bitmap_bytes;
            for (scene.patch.known, 0..) |k, i| {
                if (k) bits[i / 8] |= @as(u8, 1) << @intCast(i % 8);
            }
            try writer.writeAll(&bits);
            try writer.writeAll(&scene.patch.values);
        }
    }

    /// Reads what `write` wrote. A state saved before scenes existed ends where the count would be, and
    /// gives an empty list. A state that ends in the middle of a scene keeps the scenes read before it.
    pub fn read(self: *List, reader: anytype) Error!void {
        self.count = 0;
        const count = reader.readByte() catch return;
        if (count > max_scenes) return error.BadCount;
        var i: usize = 0;
        while (i < count) : (i += 1) {
            const item = &self.items[i];
            item.* = .{};
            const name_len = reader.readByte() catch return error.Truncated;
            if (name_len > max_name) return error.Truncated;
            reader.readNoEof(item.name_buf[0..name_len]) catch return error.Truncated;
            item.name_buf[name_len] = 0;
            item.patch_id = reader.readInt(u16, .little) catch return error.Truncated;
            const label_len = reader.readByte() catch return error.Truncated;
            if (label_len > max_name) return error.Truncated;
            reader.readNoEof(item.label_buf[0..label_len]) catch return error.Truncated;
            item.label_buf[label_len] = 0;
            var bits: [bitmap_bytes]u8 = undefined;
            reader.readNoEof(&bits) catch return error.Truncated;
            reader.readNoEof(&item.patch.values) catch return error.Truncated;
            for (&item.patch.known, 0..) |*k, b| k.* = bits[b / 8] & (@as(u8, 1) << @intCast(b % 8)) != 0;
            self.count = @intCast(i + 1);
        }
    }
};

fn testPatch(value: u8) dump.Dump {
    var d = dump.Dump{};
    d.values[0] = value;
    d.known[0] = true;
    d.values[dump.total_bytes - 1] = value +% 1;
    d.known[dump.total_bytes - 1] = true;
    return d;
}

fn testList() !*List {
    const list = try std.testing.allocator.create(List);
    list.* = .{};
    return list;
}

test "scenes are added at the end and counted from 1" {
    const list = try testList();
    defer std.testing.allocator.destroy(list);
    const a = testPatch(1);
    const b = testPatch(2);
    try std.testing.expectEqual(@as(u8, 1), try list.add("Verse", &a));
    try std.testing.expectEqual(@as(u8, 2), try list.add("Chorus", &b));
    try std.testing.expectEqualStrings("Chorus", list.get(2).?.name());
    try std.testing.expect(list.get(0) == null);
    try std.testing.expect(list.get(3) == null);
    try std.testing.expectEqual(@as(u8, 2), list.get(2).?.patch.values[0]);
}

test "a scene keeps a copy of its patch" {
    const list = try testList();
    defer std.testing.allocator.destroy(list);
    var a = testPatch(7);
    _ = try list.add("A", &a);
    a.values[0] = 99;
    try std.testing.expectEqual(@as(u8, 7), list.get(1).?.patch.values[0]);
}

test "removing a scene moves the next ones up" {
    const list = try testList();
    defer std.testing.allocator.destroy(list);
    for ([_][]const u8{ "A", "B", "C" }, 0..) |n, i| {
        const p = testPatch(@intCast(i));
        _ = try list.add(n, &p);
    }
    try std.testing.expect(list.remove(2));
    try std.testing.expectEqual(@as(u8, 2), list.count);
    try std.testing.expectEqualStrings("C", list.get(2).?.name());
    try std.testing.expectEqual(@as(u8, 2), list.get(2).?.patch.values[0]);
    try std.testing.expect(!list.remove(3));
}

test "moving a scene shifts the ones in between" {
    const list = try testList();
    defer std.testing.allocator.destroy(list);
    for ([_][]const u8{ "A", "B", "C", "D" }) |n| {
        const p = testPatch(n[0]);
        _ = try list.add(n, &p);
    }
    try std.testing.expect(list.move(2, 4));
    var order: [4]u8 = undefined;
    for (&order, 1..) |*o, i| o.* = list.get(i).?.name()[0];
    try std.testing.expectEqualStrings("ACDB", &order);
    try std.testing.expect(list.move(4, 1));
    for (&order, 1..) |*o, i| o.* = list.get(i).?.name()[0];
    try std.testing.expectEqualStrings("BACD", &order);
    // the patch travels with its name
    try std.testing.expectEqual(@as(u8, 'B'), list.get(1).?.patch.values[0]);
    try std.testing.expect(!list.move(1, 9));
    try std.testing.expect(!list.move(0, 1));
}

test "the list refuses more scenes than the parameter can hold" {
    const list = try testList();
    defer std.testing.allocator.destroy(list);
    const p = testPatch(0);
    var i: usize = 0;
    while (i < max_scenes) : (i += 1) _ = try list.add("x", &p);
    try std.testing.expectError(error.Full, list.add("one more", &p));
}

test "long names are cut, and renaming works" {
    const list = try testList();
    defer std.testing.allocator.destroy(list);
    const p = testPatch(0);
    _ = try list.add("a" ** 100, &p);
    try std.testing.expectEqual(@as(usize, max_name), list.get(1).?.name().len);
    try std.testing.expect(list.rename(1, "Solo"));
    try std.testing.expectEqualStrings("Solo", list.get(1).?.name());
    try std.testing.expect(!list.rename(2, "nope"));
}

test "the list survives the saved state, and an old state gives none" {
    const list = try testList();
    defer std.testing.allocator.destroy(list);
    const a = testPatch(5);
    const b = testPatch(6);
    _ = try list.addFrom("Verse", &a, 12, "Registration 1-2");
    _ = try list.add("Chorus", &b);
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    try list.write(buf.writer());

    const back = try testList();
    defer std.testing.allocator.destroy(back);
    var stream = std.io.fixedBufferStream(buf.items);
    try back.read(stream.reader());
    try std.testing.expectEqual(@as(u8, 2), back.count);
    try std.testing.expectEqualStrings("Chorus", back.get(2).?.name());
    try std.testing.expectEqual(@as(u16, 12), back.get(1).?.patch_id);
    try std.testing.expectEqualStrings("Registration 1-2", back.get(1).?.label());
    try std.testing.expectEqual(@as(u16, 0), back.get(2).?.patch_id);
    try std.testing.expectEqual(@as(u8, 6), back.get(2).?.patch.values[0]);
    try std.testing.expect(back.get(2).?.patch.known[0]);
    try std.testing.expect(!back.get(2).?.patch.known[1]);

    // A state from before the scenes ends where the count would be.
    var empty = std.io.fixedBufferStream(buf.items[0..0]);
    try back.read(empty.reader());
    try std.testing.expectEqual(@as(u8, 0), back.count);

    // A state cut in the middle of a scene is refused.
    var cut = std.io.fixedBufferStream(buf.items[0 .. buf.items.len - 10]);
    try std.testing.expectError(error.Truncated, back.read(cut.reader()));
}

test "the mappings say where every position goes" {
    var map: Mapping = undefined;
    moveMapping(4, 2, 4, &map);
    try std.testing.expectEqualSlices(u8, &.{ 1, 4, 2, 3 }, map[0..4]);
    moveMapping(4, 4, 1, &map);
    try std.testing.expectEqualSlices(u8, &.{ 2, 3, 4, 1 }, map[0..4]);
    removeMapping(4, 2, &map);
    try std.testing.expectEqualSlices(u8, &.{ 1, 0, 2, 3 }, map[0..4]);
}

test "a tone patch writes one three-byte message and nothing else" {
    var d = dump.Dump{};
    try std.testing.expect(toneDump(&d, "upper_synth", 12, 3, 1));
    try std.testing.expectEqual(@as(usize, 3), d.knownCount());
    var ops: [8]dump.WriteOp = undefined;
    const n = dump.diff(&d, null, .mapped_only, &ops);
    try std.testing.expectEqual(@as(usize, 1), n);
    try std.testing.expectEqual(@as(usize, 3), ops[0].bytes().len);
    try std.testing.expectEqualSlices(u8, &.{ 12, 3, 1 }, ops[0].bytes());
    // Offset 1 of the upper synth block (01 03 00).
    try std.testing.expectEqual(@as(u32, 1 << 14 | 3 << 7 | 1), ops[0].address);
    // A part without a tone list, and a drum kit, are refused.
    try std.testing.expect(!toneDump(&d, "drum", 1, 1, 0));
    try std.testing.expect(!toneDump(&d, "nonsense", 1, 1, 0));
}
