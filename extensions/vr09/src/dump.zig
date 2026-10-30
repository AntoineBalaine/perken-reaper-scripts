//! The VR-09's memory blocks, a dump of them, and the writes that bring the
//! keyboard from one dump to another.
//!
//! A dump is a snapshot of the keyboard's parameter values, taken after the
//! panel recalled a Registration. The keyboard's own Registrations cannot be
//! selected over MIDI, so recalling means writing the dump's values back, one
//! parameter per message. The block table, the write grouping and the JSON
//! format come from `vr09.py` and `docs/midi-capabilities.md` of the
//! roland-vr09 project, so that the plugin reads the dumps that project made.
const std = @import("std");
const roland = @import("roland.zig");

pub const Block = struct {
    name: []const u8,
    kind: roland.Kind,
    /// The packed address of the first byte of the block.
    start: u32,
    size: u32,
};

fn kb(a1: u32, a2: u32, a3: u32) u32 {
    return a1 << 14 | a2 << 7 | a3;
}

fn synth(a1: u32, a2: u32, a3: u32, a4: u32) u32 {
    return a1 << 21 | a2 << 14 | a3 << 7 | a4;
}

/// Everything that changed between Registrations. The `part_` slots are not in
/// Roland's map; the scan found part data there.
pub const blocks = [_]Block{
    .{ .name = "system", .kind = .kb, .start = kb(0x00, 0x00, 0x00), .size = 0x69 },
    .{ .name = "upper_piano", .kind = .kb, .start = kb(0x01, 0x01, 0x00), .size = 0x65 },
    .{ .name = "upper_synth_dual2", .kind = .kb, .start = kb(0x01, 0x02, 0x00), .size = 0x65 },
    .{ .name = "upper_synth", .kind = .kb, .start = kb(0x01, 0x03, 0x00), .size = 0x65 },
    .{ .name = "lower_piano", .kind = .kb, .start = kb(0x01, 0x11, 0x00), .size = 0x65 },
    .{ .name = "lower_synth", .kind = .kb, .start = kb(0x01, 0x13, 0x00), .size = 0x65 },
    .{ .name = "upper_piano_dual2", .kind = .kb, .start = kb(0x01, 0x31, 0x00), .size = 0x65 },
    .{ .name = "drum", .kind = .kb, .start = kb(0x01, 0x41, 0x00), .size = 0x65 },
    .{ .name = "part_01_00", .kind = .kb, .start = kb(0x01, 0x00, 0x00), .size = 0x65 },
    .{ .name = "part_01_10", .kind = .kb, .start = kb(0x01, 0x10, 0x00), .size = 0x65 },
    .{ .name = "part_01_12", .kind = .kb, .start = kb(0x01, 0x12, 0x00), .size = 0x65 },
    .{ .name = "part_01_20", .kind = .kb, .start = kb(0x01, 0x20, 0x00), .size = 0x65 },
    .{ .name = "part_01_21", .kind = .kb, .start = kb(0x01, 0x21, 0x00), .size = 0x65 },
    .{ .name = "part_01_22", .kind = .kb, .start = kb(0x01, 0x22, 0x00), .size = 0x65 },
    .{ .name = "part_01_30", .kind = .kb, .start = kb(0x01, 0x30, 0x00), .size = 0x65 },
    .{ .name = "part_01_51", .kind = .kb, .start = kb(0x01, 0x51, 0x00), .size = 0x65 },
    .{ .name = "organ_upper", .kind = .kb, .start = kb(0x02, 0x00, 0x00), .size = 0x3A },
    .{ .name = "organ_lower", .kind = .kb, .start = kb(0x02, 0x01, 0x00), .size = 0x3A },
    .{ .name = "organ_pedal", .kind = .kb, .start = kb(0x02, 0x02, 0x00), .size = 0x3A },
    .{ .name = "synth_set_upper2", .kind = .synth, .start = synth(0x18, 0x00, 0x21, 0x00), .size = 0x09 },
    .{ .name = "synth_set_upper1", .kind = .synth, .start = synth(0x18, 0x00, 0x22, 0x00), .size = 0x09 },
    .{ .name = "synth_set_lower", .kind = .synth, .start = synth(0x18, 0x00, 0x25, 0x00), .size = 0x09 },
};

pub const block_count = blocks.len;

/// The index in `values` of the first byte of each block, and the total.
pub const block_offsets = blk: {
    var offsets: [block_count + 1]usize = undefined;
    var sum: usize = 0;
    for (blocks, 0..) |b, i| {
        offsets[i] = sum;
        sum += b.size;
    }
    offsets[block_count] = sum;
    break :blk offsets;
};

pub const total_bytes = block_offsets[block_count];

/// Where an address falls in the block table.
pub const Slot = struct {
    block: usize,
    offset: usize,

    pub fn index(self: Slot) usize {
        return block_offsets[self.block] + self.offset;
    }
};

pub fn locate(kind: roland.Kind, address: u32) ?Slot {
    for (blocks, 0..) |b, i| {
        if (b.kind != kind) continue;
        if (address >= b.start and address < b.start + b.size) {
            return .{ .block = i, .offset = address - b.start };
        }
    }
    return null;
}

/// The block and offset of a flat index into `values`.
pub fn slotOfIndex(index: usize) Slot {
    var i: usize = block_count;
    while (i > 0) {
        i -= 1;
        if (index >= block_offsets[i]) return .{ .block = i, .offset = index - block_offsets[i] };
    }
    unreachable;
}

pub fn blockByName(name: []const u8) ?usize {
    for (blocks, 0..) |b, i| {
        if (std.mem.eql(u8, b.name, name)) return i;
    }
    return null;
}

pub fn isUnmappedSlot(block: usize) bool {
    return std.mem.startsWith(u8, blocks[block].name, "part_");
}

/// The values of every block, with a flag per byte that says whether the value
/// was read (or loaded), because a keyboard that never answered leaves gaps.
pub const Dump = struct {
    values: [total_bytes]u8 = @splat(0),
    known: [total_bytes]bool = @splat(false),

    pub fn set(self: *Dump, kind: roland.Kind, address: u32, value: u8) bool {
        const slot = locate(kind, address) orelse return false;
        self.values[slot.index()] = value;
        self.known[slot.index()] = true;
        return true;
    }

    pub fn get(self: *const Dump, kind: roland.Kind, address: u32) ?u8 {
        const slot = locate(kind, address) orelse return null;
        if (!self.known[slot.index()]) return null;
        return self.values[slot.index()];
    }

    pub fn knownCount(self: *const Dump) usize {
        var n: usize = 0;
        for (self.known) |k| {
            if (k) n += 1;
        }
        return n;
    }

    pub fn isComplete(self: *const Dump) bool {
        return self.knownCount() == total_bytes;
    }

    /// True when the dump holds at least the bytes of the block `index`.
    pub fn blockKnown(self: *const Dump, index: usize) bool {
        for (self.known[block_offsets[index]..block_offsets[index + 1]]) |k| {
            if (!k) return false;
        }
        return true;
    }
};

/// One message to send: a run of up to three bytes at an address.
pub const WriteOp = struct {
    kind: roland.Kind,
    address: u32,
    len: u8,
    data: [3]u8,

    pub fn bytes(self: *const WriteOp) []const u8 {
        return self.data[0..self.len];
    }
};

/// The size of the group that a write at `offset` of `block` belongs to, and
/// the offset where the group starts. A DT1 must start at a parameter's own
/// address and some parameters only exist together:
///
/// - the reverb type and level, at the start of the system block (two bytes);
/// - the tone number, bank MSB and bank LSB, at offset 1 of every part block
///   and part slot (three bytes);
/// - the bank MSB, LSB and program of a synth set part, at offset 6 (three
///   bytes).
pub fn groupOf(block: usize, offset: usize) struct { start: usize, len: usize } {
    const name = blocks[block].name;
    if (std.mem.eql(u8, name, "system") and offset <= 1) return .{ .start = 0, .len = 2 };
    const is_part = std.mem.startsWith(u8, name, "upper_") or std.mem.startsWith(u8, name, "lower_") or
        std.mem.startsWith(u8, name, "drum") or std.mem.startsWith(u8, name, "part_");
    if (is_part and offset >= 1 and offset <= 3) return .{ .start = 1, .len = 3 };
    if (std.mem.startsWith(u8, name, "synth_set") and offset >= 6 and offset <= 8) return .{ .start = 6, .len = 3 };
    return .{ .start = offset, .len = 1 };
}

pub const Scope = enum {
    /// Every block.
    everything,
    /// Only the blocks of Roland's map. The `part_` slots are left out because
    /// writing them has never been tried.
    mapped_only,
};

/// Fills `out` with the writes that turn `current` into `target` and returns
/// how many it wrote. Without a `current` dump every known byte of `target`
/// is written. A byte counts as different when `current` does not know it.
/// The writes come in block order, grouped as the unit requires, and a group
/// whose bytes are not all known in `target` is skipped, because writing part
/// of it would be wrong.
pub fn diff(target: *const Dump, current: ?*const Dump, scope: Scope, out: []WriteOp) usize {
    var count: usize = 0;
    for (blocks, 0..) |b, bi| {
        if (scope == .mapped_only and isUnmappedSlot(bi)) continue;
        var offset: usize = 0;
        while (offset < b.size) {
            const group = groupOf(bi, offset);
            const group_end = group.start + group.len;
            if (offset > group.start) {
                // The group began earlier and was handled there.
                offset = group_end;
                continue;
            }
            var all_known = true;
            var changed = false;
            var i: usize = 0;
            while (i < group.len) : (i += 1) {
                const idx = block_offsets[bi] + group.start + i;
                if (!target.known[idx]) {
                    all_known = false;
                    break;
                }
                if (current) |cur| {
                    if (!cur.known[idx] or cur.values[idx] != target.values[idx]) changed = true;
                } else {
                    changed = true;
                }
            }
            if (all_known and changed and count < out.len) {
                var op = WriteOp{ .kind = b.kind, .address = b.start + @as(u32, @intCast(group.start)), .len = @intCast(group.len), .data = .{ 0, 0, 0 } };
                i = 0;
                while (i < group.len) : (i += 1) {
                    op.data[i] = target.values[block_offsets[bi] + group.start + i];
                }
                out[count] = op;
                count += 1;
            }
            offset = group_end;
        }
    }
    return count;
}

/// Upper bound of the writes `diff` can produce.
pub const max_writes = total_bytes;

pub const JsonError = error{ NotADump, OutOfMemory, InvalidJson };

/// Reads the JSON format of `vr09.py`: an object whose keys are
/// `block:XXXXXXXX` (the block name and the packed address in eight hex
/// digits) and whose values are the bytes. Keys of blocks we do not know are
/// ignored, so a dump from a newer version still loads.
pub fn parseJson(allocator: std.mem.Allocator, text: []const u8, dump: *Dump) JsonError!void {
    var parsed = std.json.parseFromSlice(std.json.Value, allocator, text, .{}) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        else => return error.InvalidJson,
    };
    defer parsed.deinit();
    if (parsed.value != .object) return error.NotADump;
    dump.* = .{};
    var seen: usize = 0;
    var it = parsed.value.object.iterator();
    while (it.next()) |entry| {
        const colon = std.mem.indexOfScalar(u8, entry.key_ptr.*, ':') orelse return error.NotADump;
        const name = entry.key_ptr.*[0..colon];
        const address = std.fmt.parseInt(u32, entry.key_ptr.*[colon + 1 ..], 16) catch return error.NotADump;
        const bi = blockByName(name) orelse continue;
        const value: i64 = switch (entry.value_ptr.*) {
            .integer => |v| v,
            else => return error.NotADump,
        };
        if (value < 0 or value > 127) return error.NotADump;
        if (dump.set(blocks[bi].kind, address, @intCast(value))) seen += 1;
    }
    if (seen == 0) return error.NotADump;
}

/// Writes the same format, one entry per known byte, sorted like Python's
/// `sort_keys` so that a dump written here diffs cleanly against one from
/// `vr09.py`.
const JsonEntry = struct { key: []u8, value: u8 };

fn lessJsonEntry(_: void, a: JsonEntry, b: JsonEntry) bool {
    return std.mem.lessThan(u8, a.key, b.key);
}

pub fn writeJson(allocator: std.mem.Allocator, dump: *const Dump, writer: anytype) !void {
    var entries: std.ArrayList(JsonEntry) = .empty;
    defer {
        for (entries.items) |e| allocator.free(e.key);
        entries.deinit(allocator);
    }
    for (blocks, 0..) |b, bi| {
        var i: usize = 0;
        while (i < b.size) : (i += 1) {
            const idx = block_offsets[bi] + i;
            if (!dump.known[idx]) continue;
            const key = try std.fmt.allocPrint(allocator, "{s}:{X:0>8}", .{ b.name, b.start + @as(u32, @intCast(i)) });
            try entries.append(allocator, .{ .key = key, .value = dump.values[idx] });
        }
    }
    std.mem.sort(JsonEntry, entries.items, {}, lessJsonEntry);
    try writer.writeAll("{\n");
    for (entries.items, 0..) |e, i| {
        try writer.print("\"{s}\": {d}", .{ e.key, e.value });
        try writer.writeAll(if (i + 1 < entries.items.len) ",\n" else "\n");
    }
    try writer.writeAll("}");
}

fn fillDump(dump: *Dump, seed: u8) void {
    for (blocks, 0..) |b, bi| {
        var i: usize = 0;
        while (i < b.size) : (i += 1) {
            dump.known[block_offsets[bi] + i] = true;
            dump.values[block_offsets[bi] + i] = @intCast((seed + i) % 100);
        }
    }
}

test "the block table has no overlapping blocks" {
    for (blocks, 0..) |a, i| {
        for (blocks[i + 1 ..]) |b| {
            if (a.kind != b.kind) continue;
            try std.testing.expect(a.start + a.size <= b.start or b.start + b.size <= a.start);
        }
    }
    try std.testing.expectEqual(@as(usize, 1821), total_bytes);
}

test "locate finds the block of an address" {
    const slot = locate(.kb, kb(0x02, 0x00, 0x05)).?;
    try std.testing.expectEqualStrings("organ_upper", blocks[slot.block].name);
    try std.testing.expectEqual(@as(usize, 5), slot.offset);
    try std.testing.expect(locate(.kb, kb(0x03, 0x00, 0x00)) == null);
    const synth_slot = locate(.synth, synth(0x18, 0x00, 0x22, 0x06)).?;
    try std.testing.expectEqualStrings("synth_set_upper1", blocks[synth_slot.block].name);
    try std.testing.expectEqual(@as(usize, synth_slot.block), slotOfIndex(synth_slot.index()).block);
}

test "diff against nothing writes everything in groups" {
    var target = Dump{};
    fillDump(&target, 1);
    var ops: [max_writes]WriteOp = undefined;
    const n = diff(&target, null, .everything, &ops);
    // The system block saves one message for its reverb pair, and every part
    // block and slot (15 of them) and every synth set part (3) saves two.
    try std.testing.expectEqual(total_bytes - 1 - 2 * 15 - 2 * 3, n);
}

test "diff writes only the changed groups" {
    var current = Dump{};
    fillDump(&current, 1);
    var target = current;
    // A drawbar of the upper organ, the reverb level and one tone byte change.
    _ = target.set(.kb, kb(0x02, 0x00, 0x05), 3);
    _ = target.set(.kb, kb(0x00, 0x00, 0x01), 99);
    _ = target.set(.kb, kb(0x01, 0x03, 0x02), 77);
    var ops: [max_writes]WriteOp = undefined;
    const n = diff(&target, &current, .everything, &ops);
    try std.testing.expectEqual(@as(usize, 3), n);
    // Blocks come in table order: system, upper_synth, organ_upper.
    try std.testing.expectEqual(kb(0x00, 0x00, 0x00), ops[0].address);
    try std.testing.expectEqual(@as(u8, 2), ops[0].len);
    try std.testing.expectEqual(@as(u8, 99), ops[0].data[1]);
    try std.testing.expectEqual(kb(0x01, 0x03, 0x01), ops[1].address);
    try std.testing.expectEqual(@as(u8, 3), ops[1].len);
    try std.testing.expectEqual(@as(u8, 77), ops[1].data[1]);
    try std.testing.expectEqual(kb(0x02, 0x00, 0x05), ops[2].address);
    try std.testing.expectEqual(@as(u8, 1), ops[2].len);
}

test "diff with the mapped scope leaves the part slots out" {
    var target = Dump{};
    fillDump(&target, 1);
    var all: [max_writes]WriteOp = undefined;
    var mapped: [max_writes]WriteOp = undefined;
    const n_all = diff(&target, null, .everything, &all);
    const n_mapped = diff(&target, null, .mapped_only, &mapped);
    // Eight slots of 0x65 bytes, minus the two bytes each saves by grouping.
    try std.testing.expectEqual(n_all - 8 * (0x65 - 2), n_mapped);
}

test "diff skips a group that is not fully known" {
    var target = Dump{};
    fillDump(&target, 1);
    target.known[block_offsets[3] + 2] = false; // the middle of upper_synth's tone triple
    var ops: [max_writes]WriteOp = undefined;
    const n = diff(&target, null, .everything, &ops);
    for (ops[0..n]) |op| try std.testing.expect(op.address != kb(0x01, 0x03, 0x01));
}

test "json round trip keeps every byte and the python key format" {
    var dump = Dump{};
    fillDump(&dump, 5);
    var buf: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer buf.deinit();
    try writeJson(std.testing.allocator, &dump, &buf.writer);
    try std.testing.expect(std.mem.indexOf(u8, buf.written(), "\"organ_upper:00008000\": 5") != null);
    var loaded = Dump{};
    try parseJson(std.testing.allocator, buf.written(), &loaded);
    try std.testing.expect(loaded.isComplete());
    try std.testing.expectEqualSlices(u8, &dump.values, &loaded.values);
}

test "json refuses something that is not a dump" {
    var dump = Dump{};
    try std.testing.expectError(error.NotADump, parseJson(std.testing.allocator, "[1,2]", &dump));
    try std.testing.expectError(error.NotADump, parseJson(std.testing.allocator, "{\"nothing\": 1}", &dump));
    try std.testing.expectError(error.InvalidJson, parseJson(std.testing.allocator, "{", &dump));
}
