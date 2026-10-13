//! Builds a Command from an accumulated key sequence, faithful to reavim's
//! command/builder.lua:
//!
//! For each candidate action sequence (grammar order), each action type
//! consumes the longest matching chunk of keys (longest-prefix, no
//! cross-type backtracking); the candidate wins if the whole sequence is
//! consumed. A chunk matches one of three ways, tried in order:
//!   1. plain lookup (register actions excluded unless registerOptional)
//!   2. count prefix: ^[1-9][0-9]* + a chunk whose action has prefixRepetitionCount
//!   3. register postfix: prefix chunk whose action has registerAction + one key
const std = @import("std");
const keymod = @import("key.zig");
const grammar = @import("grammar.zig");
const actions = @import("actions.zig");
const trie_mod = @import("trie.zig");

const Key = keymod.Key;

/// Trie value: a binding resolved at config load.
pub const BindingValue = struct {
    name: []const u8,
    def: *const actions.ActionDef,
};

pub const KeyTrie = trie_mod.Trie(BindingValue);

/// Per-(context, action_type) tries with global already merged underneath.
pub const BindingTables = struct {
    tries: [std.meta.fields(grammar.Context).len][std.meta.fields(grammar.ActionType).len]KeyTrie,
    /// The motion that a doubled track operator ("dd", "MM") composes with.
    /// It is resolved from the registry at config load; when it is null,
    /// doubled operators are not recognized.
    current_track: ?BindingValue = null,

    pub fn get(self: *const BindingTables, ctx: grammar.Context, t: grammar.ActionType) *const KeyTrie {
        return &self.tries[@intFromEnum(ctx)][@intFromEnum(t)];
    }

    pub fn getMut(self: *BindingTables, ctx: grammar.Context, t: grammar.ActionType) *KeyTrie {
        return &self.tries[@intFromEnum(ctx)][@intFromEnum(t)];
    }
};

pub const ActionKey = struct {
    name: []const u8,
    def: *const actions.ActionDef,
    prefixed_repetitions: u32 = 1,
    register: ?Key = null,
};

pub const Command = struct {
    comp: grammar.Composition,
    types: []const grammar.ActionType,
    keys: [2]ActionKey,

    pub fn n(self: *const Command) usize {
        return self.types.len;
    }
};

// ---- trie walking helpers ----

fn walkPath(t: *const KeyTrie, keys: []const Key) ?u32 {
    var node: u32 = 0;
    for (keys) |k| {
        node = t.nodes.items[node].children.get(k.bits()) orelse return null;
    }
    return node;
}

fn valueAt(t: *const KeyTrie, node: u32) ?BindingValue {
    return t.nodes.items[node].value;
}

// ---- chunk matching (getActionKey) ----

fn countPrefixLen(keys: []const Key) usize {
    if (keys.len == 0) return 0;
    if (!isDigit(keys[0], false)) return 0;
    var i: usize = 1;
    while (i < keys.len and isDigit(keys[i], true)) : (i += 1) {}
    return i;
}

fn isDigit(k: Key, allow_zero: bool) bool {
    if (k.ctrl or k.alt or k.shift) return false;
    const lo: u8 = if (allow_zero) '0' else '1';
    return k.vk >= lo and k.vk <= '9';
}

fn digitsValue(keys: []const Key) u32 {
    var v: u32 = 0;
    for (keys) |k| v = v *| 10 +| (k.vk - '0');
    return v;
}

/// Matches one whole chunk against one action type's trie. Returns null if it
/// doesn't match exactly (the caller handles shortening the chunk).
fn getActionKey(t: *const KeyTrie, chunk: []const Key) ?ActionKey {
    // 1. plain lookup
    if (walkPath(t, chunk)) |node| {
        if (valueAt(t, node)) |v| {
            if (!v.def.register_action or v.def.register_optional)
                return .{ .name = v.name, .def = v.def };
        }
    }

    // 2. count prefix
    const nd = countPrefixLen(chunk);
    if (nd > 0 and nd < chunk.len) {
        if (getActionKeyNoCount(t, chunk[nd..])) |ak| {
            if (ak.def.prefix_repetition_count) {
                var out = ak;
                out.prefixed_repetitions = digitsValue(chunk[0..nd]);
                return out;
            }
        }
    }

    // 3. register postfix
    return registerMatch(t, chunk);
}

/// Plain + register matching only (the recursion target of the count branch).
fn getActionKeyNoCount(t: *const KeyTrie, chunk: []const Key) ?ActionKey {
    if (walkPath(t, chunk)) |node| {
        if (valueAt(t, node)) |v| {
            if (!v.def.register_action or v.def.register_optional)
                return .{ .name = v.name, .def = v.def };
        }
    }
    return registerMatch(t, chunk);
}

fn registerMatch(t: *const KeyTrie, chunk: []const Key) ?ActionKey {
    if (chunk.len < 2) return null;
    const node = walkPath(t, chunk[0 .. chunk.len - 1]) orelse return null;
    const v = valueAt(t, node) orelse return null;
    if (!v.def.register_action) return null;
    return .{ .name = v.name, .def = v.def, .register = chunk[chunk.len - 1] };
}

// ---- full-sequence parse ----

pub fn build(
    tables: *const BindingTables,
    ctx: grammar.Context,
    mode: grammar.Mode,
    keys: []const Key,
) ?Command {
    if (keys.len == 0) return null;
    for (grammar.candidatesFor(ctx, mode)) |cand| {
        if (tryCandidate(tables, ctx, cand, keys)) |cmd| return cmd;
    }
    return tryDoubledOperator(tables, ctx, mode, keys);
}

/// Vim applies an operator typed twice ("dd", "yy") to the current line. In
/// the same way, a single-key track operator typed twice ("MM", "SS") applies
/// to the current track only. Because explicit bindings must keep priority
/// (e.g. "zz" or "ss"), this rule is only tried after every grammar candidate
/// has failed to match.
fn tryDoubledOperator(
    tables: *const BindingTables,
    ctx: grammar.Context,
    mode: grammar.Mode,
    keys: []const Key,
) ?Command {
    const motion = tables.current_track orelse return null;
    if (keys.len != 2 or !keys[0].eql(keys[1])) return null;
    const cand = doubledOperatorCandidate(ctx, mode) orelse return null;
    const op = getActionKey(tables.get(ctx, .track_operator), keys[0..1]) orelse return null;
    if (op.register != null) return null;
    var cmd = Command{ .comp = cand.comp, .types = cand.types, .keys = undefined };
    cmd.keys[0] = op;
    cmd.keys[1] = .{ .name = motion.name, .def = motion.def };
    return cmd;
}

/// The operator+motion candidate that doubled operators build into, if the
/// (context, mode) grammar has one.
pub fn doubledOperatorCandidate(ctx: grammar.Context, mode: grammar.Mode) ?grammar.Candidate {
    for (grammar.candidatesFor(ctx, mode)) |cand| {
        if (cand.comp == .track_op_motion) return cand;
    }
    return null;
}

fn tryCandidate(
    tables: *const BindingTables,
    ctx: grammar.Context,
    cand: grammar.Candidate,
    keys: []const Key,
) ?Command {
    var cmd = Command{ .comp = cand.comp, .types = cand.types, .keys = undefined };
    var rest = keys;

    for (cand.types, 0..) |t, ti| {
        const t_trie = tables.get(ctx, t);
        var len = rest.len;
        const matched: ?ActionKey = while (len >= 1) : (len -= 1) {
            if (getActionKey(t_trie, rest[0..len])) |ak| break ak;
        } else null;
        const ak = matched orelse return null;
        cmd.keys[ti] = ak;
        rest = rest[len..];
    }

    if (rest.len != 0) return null;
    return cmd;
}

// ---- completions (possible future entries) ----

pub const Completion = struct {
    key: Key,
    label: ?[]const u8,
    value: ?BindingValue,
};

/// Union of next keys that could extend `keys` toward a buildable command.
/// Greedy per candidate sequence, like the matcher: fully matched chunks
/// advance to the next action type; a remainder that is a valid partial path
/// (after an optional count prefix) contributes that node's children.
pub fn completions(
    tables: *const BindingTables,
    ctx: grammar.Context,
    mode: grammar.Mode,
    keys: []const Key,
    out: []Completion,
) []Completion {
    var n: usize = 0;
    for (grammar.candidatesFor(ctx, mode)) |cand| {
        collectForCandidate(tables, ctx, cand, keys, out, &n);
    }
    addDoubledOperatorCompletion(tables, ctx, mode, keys, out, &n);
    return out[0..n];
}

/// After a lone single-key track operator, the same key again is a valid
/// continuation (see tryDoubledOperator), so the whichkey offers it.
fn addDoubledOperatorCompletion(
    tables: *const BindingTables,
    ctx: grammar.Context,
    mode: grammar.Mode,
    keys: []const Key,
    out: []Completion,
    n: *usize,
) void {
    const motion = tables.current_track orelse return;
    if (keys.len != 1 or n.* >= out.len) return;
    if (doubledOperatorCandidate(ctx, mode) == null) return;
    const op = getActionKey(tables.get(ctx, .track_operator), keys) orelse return;
    if (op.register != null) return;
    for (out[0..n.*]) |e| {
        if (e.key.bits() == keys[0].bits()) return;
    }
    out[n.*] = .{ .key = keys[0], .label = null, .value = motion };
    n.* += 1;
}

fn collectForCandidate(
    tables: *const BindingTables,
    ctx: grammar.Context,
    cand: grammar.Candidate,
    keys: []const Key,
    out: []Completion,
    n: *usize,
) void {
    var rest = keys;
    for (cand.types) |t| {
        const t_trie = tables.get(ctx, t);

        // Children at the partial path of the remainder (count prefix skipped).
        const nd = countPrefixLen(rest);
        if (walkPath(t_trie, rest[nd..])) |node| {
            addChildren(t_trie, node, out, n);
            // A register-action terminal waits for its register key.
            if (valueAt(t_trie, node)) |v| {
                if (v.def.register_action and rest.len > nd and n.* < out.len) {
                    const sentinel = Key{ .vk = 0 };
                    var dup = false;
                    for (out[0..n.*]) |e| {
                        if (e.key.bits() == sentinel.bits()) dup = true;
                    }
                    if (!dup) {
                        out[n.*] = .{ .key = sentinel, .label = "register a-z", .value = v };
                        n.* += 1;
                    }
                }
            }
        }

        // Greedily consume a chunk to advance to the next action type.
        var len = rest.len;
        const matched: ?usize = while (len >= 1) : (len -= 1) {
            if (getActionKey(t_trie, rest[0..len]) != null) break len;
        } else null;
        if (matched) |consumed| {
            rest = rest[consumed..];
        } else return; // chunk can't complete here; partial-path children already added
    }
}

fn addChildren(t: *const KeyTrie, node: u32, out: []Completion, n: *usize) void {
    var it = t.nodes.items[node].children.iterator();
    outer: while (it.next()) |e| {
        if (n.* >= out.len) return;
        const k: Key = @bitCast(e.key_ptr.*);
        // dedupe across sequences/types by key
        for (out[0..n.*]) |existing| {
            if (existing.key.bits() == k.bits()) continue :outer;
        }
        const child = t.nodes.items[e.value_ptr.*];
        out[n.*] = .{ .key = k, .label = child.label, .value = child.value };
        n.* += 1;
    }
}

// ---- tests ----

const TestEnv = struct {
    reg: actions.Registry,
    tables: BindingTables,
    alloc: std.mem.Allocator,

    const defs = [_]actions.Entry{
        .{ .name = "NextTrack", .def = .{ .steps = &.{.{ .cmd = 40285 }}, .prefix_repetition_count = true } },
        .{ .name = "FirstTrack", .def = .{ .steps = &.{.{ .cmd = 40296 }} } },
        .{ .name = "CutTrack", .def = .{ .steps = &.{.{ .cmd = 40337 }} } },
        .{ .name = "SelectItems", .def = .{ .steps = &.{.{ .cmd = 40717 }}, .set_time_selection = true } },
        .{ .name = "Mark", .def = .{ .steps = &.{}, .register_action = true } },
        .{ .name = "RecordMacro", .def = .{ .steps = &.{}, .register_action = true, .register_optional = true } },
        .{ .name = "NextMeasure", .def = .{ .steps = &.{.{ .cmd = 40839 }}, .prefix_repetition_count = true } },
        .{ .name = "CurrentTrack", .def = .{} },
        .{ .name = "ToggleMute", .def = .{ .steps = &.{.{ .cmd = 6 }} } },
        .{ .name = "ScrollToSelectedTracks", .def = .{ .steps = &.{.{ .cmd = 40913 }} } },
    };

    fn init(alloc: std.mem.Allocator) !TestEnv {
        var env = TestEnv{
            .reg = try actions.Registry.init(alloc, &.{&defs}),
            .tables = undefined,
            .alloc = alloc,
        };
        for (&env.tables.tries) |*row| for (row) |*t| {
            t.* = try KeyTrie.init(alloc);
        };
        try env.bind(.main, .track_motion, "j", "NextTrack");
        try env.bind(.main, .track_motion, "gg", "FirstTrack");
        try env.bind(.main, .track_operator, "d", "CutTrack");
        try env.bind(.main, .timeline_motion, "B", "NextMeasure");
        try env.bind(.main, .timeline_operator, "s", "SelectItems");
        try env.bind(.main, .command, "m", "Mark");
        try env.bind(.main, .command, "q", "RecordMacro");
        try env.bind(.main, .track_operator, "M", "ToggleMute");
        try env.bind(.main, .track_operator, "z", "ToggleMute");
        try env.bind(.main, .command, "zz", "ScrollToSelectedTracks");
        env.tables.current_track = .{ .name = "CurrentTrack", .def = env.reg.get("CurrentTrack").? };
        return env;
    }

    fn deinit(env: *TestEnv) void {
        for (&env.tables.tries) |*row| for (row) |*t| t.deinit();
        env.reg.deinit();
    }

    fn bind(env: *TestEnv, ctx: grammar.Context, t: grammar.ActionType, seq: []const u8, name: []const u8) !void {
        var keys = std.ArrayList(Key).init(env.alloc);
        defer keys.deinit();
        try keymod.parseSequence(seq, &keys);
        const def = env.reg.get(name).?;
        try env.tables.getMut(ctx, t).insert(keys.items, .{ .name = name, .def = def });
    }

    fn parse(env: *const TestEnv, seq: []const u8) !?Command {
        var keys = std.ArrayList(Key).init(std.testing.allocator);
        defer keys.deinit();
        try keymod.parseSequence(seq, &keys);
        return build(&env.tables, .main, .normal, keys.items);
    }
};

test "plain motion and command" {
    var env = try TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const j = (try env.parse("j")).?;
    try std.testing.expectEqual(grammar.Composition.plain, j.comp);
    try std.testing.expectEqualStrings("NextTrack", j.keys[0].name);

    const gg = (try env.parse("gg")).?;
    try std.testing.expectEqualStrings("FirstTrack", gg.keys[0].name);
}

test "count prefix on motion: 3j and d3j" {
    var env = try TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const c3j = (try env.parse("3j")).?;
    try std.testing.expectEqual(@as(u32, 3), c3j.keys[0].prefixed_repetitions);

    const d3j = (try env.parse("d3j")).?;
    try std.testing.expectEqual(grammar.Composition.track_op_motion, d3j.comp);
    try std.testing.expectEqualStrings("CutTrack", d3j.keys[0].name);
    try std.testing.expectEqualStrings("NextTrack", d3j.keys[1].name);
    try std.testing.expectEqual(@as(u32, 3), d3j.keys[1].prefixed_repetitions);

    // count on an action without the flag does not match
    try std.testing.expect((try env.parse("2gg")) == null);
}

test "operator + motion composition" {
    var env = try TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const dj = (try env.parse("dj")).?;
    try std.testing.expectEqual(grammar.Composition.track_op_motion, dj.comp);

    const sB = (try env.parse("s12B")).?;
    try std.testing.expectEqual(grammar.Composition.timeline_op_motion, sB.comp);
    try std.testing.expectEqual(@as(u32, 12), sB.keys[1].prefixed_repetitions);
}

test "register actions: bare blocked, postfix matches, optional matches bare" {
    var env = try TestEnv.init(std.testing.allocator);
    defer env.deinit();

    try std.testing.expect((try env.parse("m")) == null);

    const ma = (try env.parse("ma")).?;
    try std.testing.expectEqualStrings("Mark", ma.keys[0].name);
    try std.testing.expectEqual(@as(u8, 'A'), ma.keys[0].register.?.vk);

    const q = (try env.parse("q")).?;
    try std.testing.expectEqualStrings("RecordMacro", q.keys[0].name);
    try std.testing.expect(q.keys[0].register == null);

    const qa = (try env.parse("qa")).?;
    try std.testing.expect(qa.keys[0].register != null);
}

test "completions: pending prefix and next chunk" {
    var env = try TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var buf: [16]Completion = undefined;

    var keys = std.ArrayList(Key).init(std.testing.allocator);
    defer keys.deinit();
    try keymod.parseSequence("g", &keys);
    const after_g = completions(&env.tables, .main, .normal, keys.items, &buf);
    try std.testing.expectEqual(@as(usize, 1), after_g.len); // 'g' -> gg

    keys.clearRetainingCapacity();
    try keymod.parseSequence("d", &keys);
    const after_d = completions(&env.tables, .main, .normal, keys.items, &buf);
    // after the operator chunk 'd', the motion roots are offered: j, g
    try std.testing.expect(after_d.len >= 2);
}

test "doubled track operator applies to the current track" {
    var env = try TestEnv.init(std.testing.allocator);
    defer env.deinit();

    const mm = (try env.parse("MM")).?;
    try std.testing.expectEqual(grammar.Composition.track_op_motion, mm.comp);
    try std.testing.expectEqualStrings("ToggleMute", mm.keys[0].name);
    try std.testing.expectEqualStrings("CurrentTrack", mm.keys[1].name);

    const dd = (try env.parse("dd")).?;
    try std.testing.expectEqualStrings("CutTrack", dd.keys[0].name);

    // An explicit binding keeps priority over the doubled-operator rule.
    const zz = (try env.parse("zz")).?;
    try std.testing.expectEqual(grammar.Composition.plain, zz.comp);
    try std.testing.expectEqualStrings("ScrollToSelectedTracks", zz.keys[0].name);

    // Mismatched keys or a non-operator key do not double.
    try std.testing.expect((try env.parse("Md")) == null);
    try std.testing.expect((try env.parse("jj")) == null);
}

test "completions: a lone operator offers itself again" {
    var env = try TestEnv.init(std.testing.allocator);
    defer env.deinit();

    var buf: [16]Completion = undefined;
    var keys = std.ArrayList(Key).init(std.testing.allocator);
    defer keys.deinit();
    try keymod.parseSequence("M", &keys);
    const after_m = completions(&env.tables, .main, .normal, keys.items, &buf);
    var found = false;
    for (after_m) |c| {
        if (c.key.eql(keys.items[0])) {
            found = true;
            try std.testing.expectEqualStrings("CurrentTrack", c.value.?.name);
        }
    }
    try std.testing.expect(found);
}

test "undefined sequence builds nothing" {
    var env = try TestEnv.init(std.testing.allocator);
    defer env.deinit();
    try std.testing.expect((try env.parse("x")) == null);
}
