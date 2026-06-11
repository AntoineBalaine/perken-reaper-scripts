//! INI binding config → per-(context, action_type) tries, built once at startup.
//!
//! Sections are context.action_type, where context is main, midi, or global
//! (global is merged underneath both real contexts; context entries shadow it):
//!
//!   [main.track_motion]
//!   j = NextTrack              ; action name in the registry
//!   [main.command]
//!   o = 40001                  ; raw command id
//!   gg = _SWS_SOMETHING        ; named command
//!   i = @insert                ; engine builtin (insert/normal/off/clear)
//!   d = +delete                ; folder label for completion hints
const std = @import("std");
const ini = @import("ini");
const keymod = @import("key.zig");
const grammar = @import("grammar.zig");
const actions = @import("actions.zig");
const builder = @import("builder.zig");
const lib_state = @import("lib_state.zig");

const log = std.log.scoped(.config);

pub const Bindings = struct {
    arena: std.heap.ArenaAllocator,
    tables: builder.BindingTables,

    pub fn deinit(self: *Bindings) void {
        for (&self.tables.tries) |*row| for (row) |*t| t.deinit();
        self.arena.deinit();
    }
};

const IniContext = enum { main, midi, global };

const Section = struct {
    ctx: IniContext,
    action_type: grammar.ActionType,
};

fn parseSectionName(name: []const u8) ?Section {
    const dot = std.mem.indexOfScalar(u8, name, '.') orelse return null;
    const ctx = std.meta.stringToEnum(IniContext, name[0..dot]) orelse return null;
    const t = std.meta.stringToEnum(grammar.ActionType, name[dot + 1 ..]) orelse return null;
    return .{ .ctx = ctx, .action_type = t };
}

const Value = union(enum) {
    name: []const u8,
    cmd: c_int,
    named: [:0]const u8,
    builtin: *const actions.ActionDef,
    label: []const u8,
};

fn parseValue(raw: []const u8, arena: std.mem.Allocator) !Value {
    const v = std.mem.trim(u8, raw, " \t");
    if (v.len == 0) return error.EmptyValue;
    if (v[0] == '+') return .{ .label = try arena.dupe(u8, v[1..]) };
    if (v[0] == '@') {
        inline for (@typeInfo(lib_state.builtin_defs).@"struct".decls) |d| {
            if (std.mem.eql(u8, v[1..], d.name))
                return .{ .builtin = &@field(lib_state.builtin_defs, d.name) };
        }
        return error.UnknownBuiltin;
    }
    if (std.fmt.parseInt(c_int, v, 10)) |id| return .{ .cmd = id } else |_| {}
    if (v[0] == '_') return .{ .named = try arena.dupeZ(u8, v) };
    return .{ .name = try arena.dupe(u8, v) };
}

const RawEntry = struct {
    section: Section,
    keys: []keymod.Key,
    value: Value,
};

/// Turns a parsed Value into a BindingValue, resolving registry names and
/// allocating inline defs for raw ids / named commands. `midi` selects the
/// MIDIEditor dispatch variant for raw ids.
fn toBindingValue(
    value: Value,
    registry: *const actions.Registry,
    arena: std.mem.Allocator,
    midi: bool,
    stub_def: *const actions.ActionDef,
) !?builder.BindingValue {
    switch (value) {
        .label => unreachable, // handled by caller
        .name => |n| {
            if (registry.get(n)) |def| return .{ .name = n, .def = def };
            return .{ .name = n, .def = stub_def };
        },
        .cmd => |id| {
            const def = try arena.create(actions.ActionDef);
            const steps = try arena.alloc(actions.Step, 1);
            steps[0] = .{ .cmd = id };
            def.* = .{ .steps = steps, .prefix_repetition_count = true, .midi_command = midi };
            const name = try std.fmt.allocPrint(arena, "cmd:{d}", .{id});
            return .{ .name = name, .def = def };
        },
        .named => |n| {
            const def = try arena.create(actions.ActionDef);
            const steps = try arena.alloc(actions.Step, 1);
            steps[0] = .{ .named = n };
            def.* = .{ .steps = steps, .prefix_repetition_count = true };
            return .{ .name = n, .def = def };
        },
        .builtin => |def| {
            return .{ .name = def.desc orelse "builtin", .def = def };
        },
    }
}

pub fn parse(
    gpa: std.mem.Allocator,
    registry: *const actions.Registry,
    reader: anytype,
) !Bindings {
    var b = Bindings{
        .arena = std.heap.ArenaAllocator.init(gpa),
        .tables = undefined,
    };
    errdefer b.arena.deinit();
    for (&b.tables.tries) |*row| for (row) |*t| {
        t.* = try builder.KeyTrie.init(gpa);
    };
    const arena = b.arena.allocator();

    const stub_def = try arena.create(actions.ActionDef);
    stub_def.* = .{ .steps = &.{}, .desc = "(stub)" };

    // Pass 1: read all entries, keeping global separate.
    var entries = std.ArrayList(RawEntry).init(gpa);
    defer entries.deinit();

    var parser = ini.parse(gpa, reader);
    defer parser.deinit();

    var section: ?Section = null;
    var keybuf = std.ArrayList(keymod.Key).init(gpa);
    defer keybuf.deinit();

    while (try parser.next()) |record| {
        switch (record) {
            .section => |name| {
                section = parseSectionName(name);
                if (section == null)
                    log.warn("unknown section [{s}] — skipped", .{name});
            },
            .property => |kv| {
                const sec = section orelse continue;
                keybuf.clearRetainingCapacity();
                keymod.parseSequence(kv.key, &keybuf) catch |err| {
                    log.warn("bad key sequence '{s}': {s} — skipped", .{ kv.key, @errorName(err) });
                    continue;
                };
                if (keybuf.items.len == 0) continue;
                const value = parseValue(kv.value, arena) catch |err| {
                    log.warn("bad value '{s}' for '{s}': {s} — skipped", .{ kv.value, kv.key, @errorName(err) });
                    continue;
                };
                try entries.append(.{
                    .section = sec,
                    .keys = try arena.dupe(keymod.Key, keybuf.items),
                    .value = value,
                });
            },
            .enumeration => {},
        }
    }

    // Pass 2: global first, then context entries shadowing.
    for ([_]bool{ true, false }) |global_pass| {
        for (entries.items) |e| {
            if ((e.section.ctx == .global) != global_pass) continue;
            const targets: []const grammar.Context = switch (e.section.ctx) {
                .global => &.{ .main, .midi },
                .main => &.{.main},
                .midi => &.{.midi},
            };
            for (targets) |ctx| {
                const t = b.tables.getMut(ctx, e.section.action_type);
                if (e.value == .label) {
                    try t.setLabel(e.keys, e.value.label);
                    continue;
                }
                const bv = (try toBindingValue(e.value, registry, arena, ctx == .midi, stub_def)) orelse continue;
                try t.insertReplace(e.keys, bv);
            }
        }
    }

    return b;
}

pub fn parseString(gpa: std.mem.Allocator, registry: *const actions.Registry, text: []const u8) !Bindings {
    var fbs = std.io.fixedBufferStream(text);
    return parse(gpa, registry, fbs.reader());
}

// ---- tests ----

const test_defs = [_]actions.Entry{
    .{ .name = "NextTrack", .def = .{ .steps = &.{.{ .cmd = 40285 }}, .prefix_repetition_count = true } },
    .{ .name = "RemoveTracks", .def = .{ .steps = &.{.{ .cmd = 40005 }} } },
};

test "quoted keys with comment chars bind" {
    const text =
        \\[main.command]
        \\";" = 40912
        \\"x#1" = 40913
        \\"\"#" = "+recall #"
    ;
    var reg = try actions.Registry.init(std.testing.allocator, &.{});
    defer reg.deinit();
    var b = try parseString(std.testing.allocator, &reg, text);
    defer b.deinit();

    var keys = std.ArrayList(keymod.Key).init(std.testing.allocator);
    defer keys.deinit();

    try keymod.parseSequence(";", &keys);
    const semi = builder.build(&b.tables, .main, .normal, keys.items).?;
    try std.testing.expectEqual(@as(c_int, 40912), semi.keys[0].def.steps[0].cmd);

    keys.clearRetainingCapacity();
    try keymod.parseSequence("x#1", &keys);
    const hash = builder.build(&b.tables, .main, .normal, keys.items).?;
    try std.testing.expectEqual(@as(c_int, 40913), hash.keys[0].def.steps[0].cmd);
}

test "parse new format with registry names, raw ids, global merge and shadowing" {
    const text =
        \\[main.track_motion]
        \\j = NextTrack
        \\
        \\[main.track_operator]
        \\d = RemoveTracks
        \\
        \\[global.command]
        \\u = 40029
        \\x = 40001
        \\
        \\[midi.command]
        \\x = 40002
        \\
        \\[main.command]
        \\zz = +view
        \\i = @insert
    ;
    var reg = try actions.Registry.init(std.testing.allocator, &.{&test_defs});
    defer reg.deinit();
    var b = try parseString(std.testing.allocator, &reg, text);
    defer b.deinit();

    var keys = std.ArrayList(keymod.Key).init(std.testing.allocator);
    defer keys.deinit();

    // dj builds as track_op_motion through the grammar
    try keymod.parseSequence("dj", &keys);
    const cmd = builder.build(&b.tables, .main, .normal, keys.items).?;
    try std.testing.expectEqual(grammar.Composition.track_op_motion, cmd.comp);
    try std.testing.expectEqualStrings("RemoveTracks", cmd.keys[0].name);

    // global u reaches both contexts
    keys.clearRetainingCapacity();
    try keymod.parseSequence("u", &keys);
    try std.testing.expect(builder.build(&b.tables, .main, .normal, keys.items) != null);
    try std.testing.expect(builder.build(&b.tables, .midi, .normal, keys.items) != null);

    // midi x shadows global x
    keys.clearRetainingCapacity();
    try keymod.parseSequence("x", &keys);
    const mx = builder.build(&b.tables, .midi, .normal, keys.items).?;
    try std.testing.expectEqual(@as(c_int, 40002), mx.keys[0].def.steps[0].cmd);
    try std.testing.expect(mx.keys[0].def.midi_command);
    const gx = builder.build(&b.tables, .main, .normal, keys.items).?;
    try std.testing.expectEqual(@as(c_int, 40001), gx.keys[0].def.steps[0].cmd);

    // builtin
    keys.clearRetainingCapacity();
    try keymod.parseSequence("i", &keys);
    const bi = builder.build(&b.tables, .main, .normal, keys.items).?;
    try std.testing.expectEqualStrings("Enter insert mode", bi.keys[0].name);
}
