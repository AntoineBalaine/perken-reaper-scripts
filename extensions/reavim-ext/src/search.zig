//! Binding search: the data side of the whichkey search box.
//!
//! The index lists every binding that can start a command in the current
//! (context, mode), each with its key sequence and a searchable text made of
//! the keys, the action name and its description. A query matches an entry
//! when every whitespace-separated word of the query appears in that text,
//! ignoring case. Running an entry feeds its key sequence to the vim engine,
//! so an operator entry leaves the engine pending for a motion, exactly as if
//! the keys had been typed.
const std = @import("std");
const keymod = @import("key.zig");
const grammar = @import("grammar.zig");
const builder = @import("builder.zig");

const Key = keymod.Key;

pub const Entry = struct {
    keys: []const Key,
    /// The key sequence in vim notation, for display.
    keys_text: []const u8,
    value: builder.BindingValue,
    /// The description shown next to the keys.
    desc: []const u8,
    /// Lowercased "keys name desc", which queries are matched against.
    haystack: []const u8,
    action_type: grammar.ActionType,
};

/// Resolves the description of a binding (the ui uses REAPER's action names;
/// tests use a plain stand-in). The result is copied into the index.
pub const DescFn = *const fn (value: builder.BindingValue, ctx: grammar.Context, buf: [:0]u8) []const u8;

pub const MAX_DEPTH = 16;

pub const Index = struct {
    arena: std.heap.ArenaAllocator,
    entries: std.ArrayListUnmanaged(Entry) = .{},
    ctx: grammar.Context = .main,
    mode: grammar.Mode = .normal,

    pub fn init(gpa: std.mem.Allocator) Index {
        return .{ .arena = std.heap.ArenaAllocator.init(gpa) };
    }

    pub fn deinit(self: *Index) void {
        self.arena.deinit();
    }
};

/// The state shared by the recursive trie walk, grouped so that the walk
/// function can stay a plain top-level function.
pub const WalkCtx = struct {
    index: *Index,
    trie: *const builder.KeyTrie,
    action_type: grammar.ActionType,
    desc_fn: DescFn,
    path: [MAX_DEPTH]Key = undefined,
};

/// Rebuilds the index for (ctx, mode). Because the grammar tries candidates
/// in priority order, the first action type that binds a given key sequence
/// is the one that runs, so later duplicates are skipped.
pub fn rebuild(
    index: *Index,
    tables: *const builder.BindingTables,
    ctx: grammar.Context,
    mode: grammar.Mode,
    desc_fn: DescFn,
) !void {
    _ = index.arena.reset(.retain_capacity);
    index.entries = .{};
    index.ctx = ctx;
    index.mode = mode;

    var seen = [_]bool{false} ** std.meta.fields(grammar.ActionType).len;
    for (grammar.candidatesFor(ctx, mode)) |cand| {
        const t = cand.types[0];
        if (seen[@intFromEnum(t)]) continue;
        seen[@intFromEnum(t)] = true;
        var wctx = WalkCtx{
            .index = index,
            .trie = tables.get(ctx, t),
            .action_type = t,
            .desc_fn = desc_fn,
        };
        try walk(&wctx, 0, 0);
    }
    try addDoubledOperators(index, tables, desc_fn);
}

/// Doubled track operators ("MM", "dd") are a grammar rule, not trie entries,
/// so the walk above cannot find them. Because users search for them like any
/// other binding, each single-key track operator is listed a second time as
/// its doubled form, unless that sequence is already bound explicitly.
pub fn addDoubledOperators(index: *Index, tables: *const builder.BindingTables, desc_fn: DescFn) !void {
    if (tables.current_track == null) return;
    if (builder.doubledOperatorCandidate(index.ctx, index.mode) == null) return;
    const ops = tables.get(index.ctx, .track_operator);
    var wctx = WalkCtx{
        .index = index,
        .trie = ops,
        .action_type = .track_operator,
        .desc_fn = desc_fn,
    };
    var it = ops.nodes.items[0].children.iterator();
    while (it.next()) |e| {
        const value = ops.nodes.items[e.value_ptr.*].value orelse continue;
        if (value.def.register_action) continue;
        const k: Key = @bitCast(e.key_ptr.*);
        const before = index.entries.items.len;
        try addEntry(&wctx, &.{ k, k }, value);
        if (index.entries.items.len == before) continue; // explicitly bound already
        try markCurrentTrack(index, &index.entries.items[before]);
    }
}

/// Appends "(current track)" to a doubled operator's description and
/// searchable text, so that "mute current" finds "MM".
pub fn markCurrentTrack(index: *Index, entry: *Entry) !void {
    const a = index.arena.allocator();
    entry.desc = try std.fmt.allocPrint(a, "{s} (current track)", .{entry.desc});
    entry.haystack = try std.fmt.allocPrint(a, "{s} (current track)", .{entry.haystack});
}

pub fn walk(wctx: *WalkCtx, node: u32, depth: usize) !void {
    const n = wctx.trie.nodes.items[node];
    if (n.value) |v| {
        if (depth > 0) try addEntry(wctx, wctx.path[0..depth], v);
    }
    if (depth >= MAX_DEPTH) return;
    var it = n.children.iterator();
    while (it.next()) |e| {
        wctx.path[depth] = @bitCast(e.key_ptr.*);
        try walk(wctx, e.value_ptr.*, depth + 1);
    }
}

pub fn addEntry(wctx: *WalkCtx, path: []const Key, value: builder.BindingValue) !void {
    const index = wctx.index;
    for (index.entries.items) |existing| {
        if (std.mem.eql(Key, existing.keys, path)) return;
    }
    const a = index.arena.allocator();

    var text = std.ArrayList(u8).init(a);
    for (path) |k| {
        var kb: [16]u8 = undefined;
        try text.appendSlice(keymod.format(k, &kb));
    }
    const keys_text = try text.toOwnedSlice();

    var dbuf: [256:0]u8 = undefined;
    const desc = try a.dupe(u8, wctx.desc_fn(value, index.ctx, &dbuf));

    const hay = try std.fmt.allocPrint(a, "{s} {s} {s}", .{ keys_text, value.name, desc });
    for (hay) |*c| c.* = std.ascii.toLower(c.*);

    try index.entries.append(a, .{
        .keys = try a.dupe(Key, path),
        .keys_text = keys_text,
        .value = value,
        .desc = desc,
        .haystack = hay,
        .action_type = wctx.action_type,
    });
}

/// True when every whitespace-separated word of `query` occurs in the
/// (already lowercased) haystack, ignoring case.
pub fn matches(query: []const u8, haystack: []const u8) bool {
    var it = std.mem.tokenizeAny(u8, query, " \t");
    while (it.next()) |word| {
        var lower: [128]u8 = undefined;
        if (word.len > lower.len) return false;
        for (word, 0..) |c, i| lower[i] = std.ascii.toLower(c);
        if (std.mem.indexOf(u8, haystack, lower[0..word.len]) == null) return false;
    }
    return true;
}

/// Writes the indices of the matching entries into `out` and returns them.
pub fn filter(index: *const Index, query: []const u8, out: []usize) []usize {
    var n: usize = 0;
    for (index.entries.items, 0..) |e, i| {
        if (n >= out.len) break;
        if (matches(query, e.haystack)) {
            out[n] = i;
            n += 1;
        }
    }
    return out[0..n];
}

/// The character a key types into the search query, or null when the key is
/// not text (a modifier combo or a named key such as an arrow).
pub fn keyChar(k: Key) ?u8 {
    if (k.ctrl or k.alt) return null;
    if (k.is_char) return if (k.vk >= 0x20 and k.vk < 0x7f) k.vk else null;
    if (k.vk == keymod.VK.SPACE) return ' ';
    if (k.vk >= 'A' and k.vk <= 'Z') return if (k.shift) k.vk else k.vk + 32;
    if (k.vk >= '0' and k.vk <= '9') return k.vk;
    return null;
}

// ---- tests ----

const actions = @import("actions.zig");

fn testDesc(value: builder.BindingValue, _: grammar.Context, _: [:0]u8) []const u8 {
    return value.def.desc orelse value.name;
}

const test_defs = [_]actions.Entry{
    .{ .name = "ToggleMute", .def = .{ .desc = "Track: Toggle mute" } },
    .{ .name = "NextTrack", .def = .{ .desc = "Track: Go to next track" } },
    .{ .name = "SaveProject", .def = .{ .desc = "File: Save project" } },
};

fn bindTest(reg: *const actions.Registry, tables: *builder.BindingTables, t: grammar.ActionType, seq: []const u8, name: []const u8) !void {
    var keys = std.ArrayList(Key).init(std.testing.allocator);
    defer keys.deinit();
    try keymod.parseSequence(seq, &keys);
    try tables.getMut(.main, t).insert(keys.items, .{ .name = name, .def = reg.get(name).? });
}

test "index lists bindings and filters by words" {
    var reg = try actions.Registry.init(std.testing.allocator, &.{&test_defs});
    defer reg.deinit();
    var tables: builder.BindingTables = .{ .tries = undefined };
    for (&tables.tries) |*row| for (row) |*t| {
        t.* = try builder.KeyTrie.init(std.testing.allocator);
    };
    defer for (&tables.tries) |*row| for (row) |*t| t.deinit();

    try bindTest(&reg, &tables, .track_operator, "M", "ToggleMute");
    try bindTest(&reg, &tables, .track_motion, "j", "NextTrack");
    try bindTest(&reg, &tables, .command, "<space>ps", "SaveProject");
    tables.current_track = .{ .name = "CurrentTrack", .def = reg.get("NextTrack").? };

    var index = Index.init(std.testing.allocator);
    defer index.deinit();
    try rebuild(&index, &tables, .main, .normal, &testDesc);
    // M, j, <space>ps, plus the doubled operator MM.
    try std.testing.expectEqual(@as(usize, 4), index.entries.items.len);

    var out: [8]usize = undefined;
    const mute = filter(&index, "MUTE", &out);
    try std.testing.expectEqual(@as(usize, 2), mute.len);
    try std.testing.expectEqualStrings("M", index.entries.items[mute[0]].keys_text);
    try std.testing.expectEqualStrings("MM", index.entries.items[mute[1]].keys_text);

    const current = filter(&index, "mute current", &out);
    try std.testing.expectEqual(@as(usize, 1), current.len);
    try std.testing.expectEqualStrings("Track: Toggle mute (current track)", index.entries.items[current[0]].desc);

    const track = filter(&index, "track", &out);
    try std.testing.expectEqual(@as(usize, 3), track.len);

    const save = filter(&index, "save proj", &out);
    try std.testing.expectEqual(@as(usize, 1), save.len);
    try std.testing.expectEqualStrings("<space>ps", index.entries.items[save[0]].keys_text);

    try std.testing.expectEqual(@as(usize, 0), filter(&index, "mute next", &out).len);
}

test "keyChar maps text keys only" {
    try std.testing.expectEqual(@as(?u8, 'a'), keyChar(.{ .vk = 'A' }));
    try std.testing.expectEqual(@as(?u8, 'A'), keyChar(.{ .vk = 'A', .shift = true }));
    try std.testing.expectEqual(@as(?u8, '?'), keyChar(.{ .vk = '?', .is_char = true }));
    try std.testing.expectEqual(@as(?u8, ' '), keyChar(.{ .vk = keymod.VK.SPACE }));
    try std.testing.expectEqual(@as(?u8, null), keyChar(.{ .vk = 'A', .ctrl = true }));
    try std.testing.expectEqual(@as(?u8, null), keyChar(.{ .vk = keymod.VK.UP }));
}
