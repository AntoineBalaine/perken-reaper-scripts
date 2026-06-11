//! INI binding config → per-(context, mode) tries, built once at startup.
//!
//! Format (sections are context.mode; keys are vim-notation sequences):
//!
//!   [main.normal]
//!   j  = 40285                 ; numeric command id (section chosen by context)
//!   gg = _SWS_SOMETHING        ; named command, resolved via NamedCommandLookup
//!   i  = @insert               ; engine builtin
//!   dd = CutTrack              ; bare name -> stub until ported / mapped
//!
//!   [main.labels]
//!   c = change/fit             ; folder label shown in completion hints
const std = @import("std");
const ini = @import("ini");
const keymod = @import("key.zig");
const trie = @import("trie.zig");

const log = std.log.scoped(.config);

pub const Builtin = enum { insert, normal, off, clear };

pub const Action = union(enum) {
    /// Numeric command id; dispatched per context (Main_OnCommand / MIDIEditor_*).
    cmd: c_int,
    /// Named command ("_SWS_...", "_RS..."), resolved lazily via NamedCommandLookup.
    named: [:0]const u8,
    builtin: Builtin,
    /// Unported/unknown action name; logs when triggered.
    stub: []const u8,

    pub fn describe(self: Action, buf: []u8) []const u8 {
        return switch (self) {
            .cmd => |id| std.fmt.bufPrint(buf, "cmd:{d}", .{id}) catch buf[0..0],
            .named => |n| n,
            .builtin => |b| std.fmt.bufPrint(buf, "@{s}", .{@tagName(b)}) catch buf[0..0],
            .stub => |n| std.fmt.bufPrint(buf, "{s} (stub)", .{n}) catch buf[0..0],
        };
    }
};

pub const KeyTrie = trie.Trie(Action);
pub const Context = enum { main, midi };
pub const BindMode = enum { normal }; // visual modes arrive in a later milestone

pub const Bindings = struct {
    arena: std.heap.ArenaAllocator,
    tries: [std.meta.fields(Context).len][std.meta.fields(BindMode).len]KeyTrie,

    pub fn get(self: *const Bindings, ctx: Context, mode: BindMode) *const KeyTrie {
        return &self.tries[@intFromEnum(ctx)][@intFromEnum(mode)];
    }

    fn getMut(self: *Bindings, ctx: Context, mode: BindMode) *KeyTrie {
        return &self.tries[@intFromEnum(ctx)][@intFromEnum(mode)];
    }

    pub fn deinit(self: *Bindings) void {
        for (&self.tries) |*row| for (row) |*t| t.deinit();
        self.arena.deinit();
    }
};

const SectionTarget = union(enum) {
    bindings: struct { ctx: Context, mode: BindMode },
    labels: Context,
    unknown,
};

fn parseSectionName(name: []const u8) SectionTarget {
    const dot = std.mem.indexOfScalar(u8, name, '.') orelse return .unknown;
    const ctx = std.meta.stringToEnum(Context, name[0..dot]) orelse return .unknown;
    const rest = name[dot + 1 ..];
    if (std.mem.eql(u8, rest, "labels")) return .{ .labels = ctx };
    const mode = std.meta.stringToEnum(BindMode, rest) orelse return .unknown;
    return .{ .bindings = .{ .ctx = ctx, .mode = mode } };
}

fn parseActionValue(value: []const u8, arena: std.mem.Allocator) !Action {
    if (value.len == 0) return error.EmptyValue;
    if (value[0] == '@') {
        const b = std.meta.stringToEnum(Builtin, value[1..]) orelse return error.UnknownBuiltin;
        return .{ .builtin = b };
    }
    if (std.fmt.parseInt(c_int, value, 10)) |id| {
        return .{ .cmd = id };
    } else |_| {}
    if (value[0] == '_') {
        return .{ .named = try arena.dupeZ(u8, value) };
    }
    return .{ .stub = try arena.dupe(u8, value) };
}

/// Parses bindings from any reader. Bad entries are logged and skipped — one
/// typo must not take the whole vim mode down.
pub fn parse(gpa: std.mem.Allocator, reader: anytype) !Bindings {
    var b = Bindings{
        .arena = std.heap.ArenaAllocator.init(gpa),
        .tries = undefined,
    };
    errdefer b.arena.deinit();
    for (&b.tries) |*row| for (row) |*t| {
        t.* = try KeyTrie.init(gpa);
    };

    var parser = ini.parse(gpa, reader);
    defer parser.deinit();

    var target: SectionTarget = .unknown;
    var keys = std.ArrayList(keymod.Key).init(gpa);
    defer keys.deinit();

    while (try parser.next()) |record| {
        switch (record) {
            .section => |name| {
                target = parseSectionName(name);
                if (target == .unknown)
                    log.warn("unknown section [{s}] — skipped", .{name});
            },
            .property => |kv| switch (target) {
                .unknown => {},
                .bindings => |t| {
                    keys.clearRetainingCapacity();
                    keymod.parseSequence(kv.key, &keys) catch |err| {
                        log.warn("bad key sequence '{s}': {s} — skipped", .{ kv.key, @errorName(err) });
                        continue;
                    };
                    if (keys.items.len == 0) continue;
                    const action = parseActionValue(std.mem.trim(u8, kv.value, " \t"), b.arena.allocator()) catch |err| {
                        log.warn("bad action value '{s}' for '{s}': {s} — skipped", .{ kv.value, kv.key, @errorName(err) });
                        continue;
                    };
                    b.getMut(t.ctx, t.mode).insert(keys.items, action) catch |err| switch (err) {
                        error.DuplicateBinding => log.warn("duplicate binding '{s}' — first one wins", .{kv.key}),
                        else => |e| return e,
                    };
                },
                .labels => |ctx| {
                    keys.clearRetainingCapacity();
                    keymod.parseSequence(kv.key, &keys) catch continue;
                    if (keys.items.len == 0) continue;
                    const label = try b.arena.allocator().dupe(u8, std.mem.trim(u8, kv.value, " \t"));
                    // Labels apply to normal mode (the only mode with folders today).
                    try b.getMut(ctx, .normal).setLabel(keys.items, label);
                },
            },
            .enumeration => {},
        }
    }

    return b;
}

pub fn parseString(gpa: std.mem.Allocator, text: []const u8) !Bindings {
    var fbs = std.io.fixedBufferStream(text);
    return parse(gpa, fbs.reader());
}

test "parse bindings from string" {
    const text =
        \\; comment
        \\[main.normal]
        \\j = 40285
        \\k = 40286
        \\gg = _SWS_FIRST
        \\i = @insert
        \\dd = CutTrack
        \\
        \\[main.labels]
        \\d = delete
        \\
        \\[midi.normal]
        \\i = @insert
        \\
        \\[bogus]
        \\x = 1
    ;
    var b = try parseString(std.testing.allocator, text);
    defer b.deinit();

    var c = b.get(.main, .normal).cursor();
    switch (c.step((try keymod.parseToken("j")).key)) {
        .exact => |a| try std.testing.expectEqual(@as(c_int, 40285), a.cmd),
        else => return error.TestUnexpectedResult,
    }

    c.reset();
    switch (c.step((try keymod.parseToken("g")).key)) {
        .pending => {},
        else => return error.TestUnexpectedResult,
    }
    switch (c.step((try keymod.parseToken("g")).key)) {
        .exact => |a| try std.testing.expectEqualStrings("_SWS_FIRST", a.named),
        else => return error.TestUnexpectedResult,
    }

    c.reset();
    switch (c.step((try keymod.parseToken("d")).key)) {
        .pending => {},
        else => return error.TestUnexpectedResult,
    }
    switch (c.step((try keymod.parseToken("d")).key)) {
        .exact => |a| try std.testing.expectEqualStrings("CutTrack", a.stub),
        else => return error.TestUnexpectedResult,
    }

    var mc = b.get(.midi, .normal).cursor();
    switch (mc.step((try keymod.parseToken("i")).key)) {
        .exact => |a| try std.testing.expectEqual(Builtin.insert, a.builtin),
        else => return error.TestUnexpectedResult,
    }
}

test "bad entries are skipped, good ones survive" {
    const text =
        \\[main.normal]
        \\<oops = 40285
        \\j = @nosuchbuiltin
        \\k = 40286
    ;
    var b = try parseString(std.testing.allocator, text);
    defer b.deinit();

    var c = b.get(.main, .normal).cursor();
    switch (c.step((try keymod.parseToken("k")).key)) {
        .exact => |a| try std.testing.expectEqual(@as(c_int, 40286), a.cmd),
        else => return error.TestUnexpectedResult,
    }
    c.reset();
    switch (c.step((try keymod.parseToken("j")).key)) {
        .nomatch => {},
        else => return error.TestUnexpectedResult,
    }
}
