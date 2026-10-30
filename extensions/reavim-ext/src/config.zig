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
//!   l = @unbind                ; drops a binding that the global section gave this context
//!   d = +delete                ; folder label for completion hints
//!
//! Two more sections configure the whichkey window instead of binding keys:
//!
//!   [whichkey]
//!   page_next = <pagedown>     ; pagination keys of the list view
//!   view = keyboard            ; keyboard | list
//!   layout = bepo              ; qwerty | bepo (where each character sits)
//!   board = ortho              ; staggered | ortho
//!   dock = 1                   ; REAPER docker number (1-16) the window opens in | none (also: empty or missing) = remembers its last placement
//!   [labels]
//!   AddNextNoteToSelection = Extend → | extend   ; short cap label | category
const std = @import("std");
const ini = @import("ini");
const keymod = @import("key.zig");
const grammar = @import("grammar.zig");
const actions = @import("actions.zig");
const builder = @import("builder.zig");
const lib_state = @import("lib_state.zig");
const keyboard = @import("keyboard.zig");

const log = std.log.scoped(.config);

pub const Bindings = struct {
    arena: std.heap.ArenaAllocator,
    tables: builder.BindingTables,
    /// Whichkey pagination keys (the [whichkey] config section). Special-cased
    /// in the engine — they are not regular bindings, so they work mid-sequence.
    page_next: keymod.Key = .{ .vk = keymod.VK.NEXT }, // PageDown
    page_prev: keymod.Key = .{ .vk = keymod.VK.PRIOR }, // PageUp
    /// How the whichkey window shows the next keys, and on which keyboard.
    view: keyboard.View = .keyboard,
    layout: keyboard.Layout = .qwerty,
    board: keyboard.Board = .staggered,
    /// The REAPER docker (1-16) that the whichkey window opens in, or null to
    /// let it keep the placement of the last session. Because a docker number
    /// turns the saving of the placement off, that setting decides where the
    /// window lands at every start. Because a missing or empty setting counts
    /// as "none", the default is null.
    dock: ?u8 = null,
    /// Short cap labels and categories by action name (the [labels] section).
    /// The strings live in the arena.
    labels: std.StringHashMapUnmanaged(keyboard.Label) = .{},

    pub fn deinit(self: *Bindings) void {
        for (&self.tables.tries) |*row| for (row) |*t| t.deinit();
        self.arena.deinit();
    }
};

const CurSection = union(enum) {
    binding: Section,
    whichkey,
    labels,
    unknown,
};

/// Parses a single-key value like "<pagedown>" or "<C-n>" for [whichkey].
fn parseSingleKey(raw: []const u8) ?keymod.Key {
    const tok = keymod.parseToken(std.mem.trim(u8, raw, " \t")) catch return null;
    if (tok.len != std.mem.trim(u8, raw, " \t").len) return null; // must be exactly one key
    return tok.key;
}

/// Parses the value of the [whichkey] dock option: a docker number from 1 to
/// 16, or "none" (or an empty value) for a window that keeps its last
/// placement. Returns error.InvalidDock otherwise.
fn parseDock(value: []const u8) error{InvalidDock}!?u8 {
    if (value.len == 0 or std.mem.eql(u8, value, "none")) return null;
    const n = std.fmt.parseInt(u8, value, 10) catch return error.InvalidDock;
    if (n < 1 or n > 16) return error.InvalidDock;
    return n;
}

/// Applies a [whichkey] option that is not a key (view, layout, board, dock).
/// Returns false when the name is not one of them, so that the caller parses
/// the value as a pagination key instead.
fn parseWhichkeyOption(b: *Bindings, name: []const u8, raw: []const u8) !bool {
    const value = std.mem.trim(u8, raw, " \t");
    if (std.mem.eql(u8, name, "dock")) {
        if (parseDock(value)) |dock| {
            b.dock = dock;
        } else |_| {
            log.warn("unknown [whichkey] dock '{s}' (expected 1-16 or none) — skipped", .{value});
        }
        return true;
    }
    inline for (.{ .{ "view", keyboard.View }, .{ "layout", keyboard.Layout }, .{ "board", keyboard.Board } }) |opt| {
        if (std.mem.eql(u8, name, opt[0])) {
            if (std.meta.stringToEnum(opt[1], value)) |v| {
                @field(b, opt[0]) = v;
            } else {
                log.warn("unknown [whichkey] {s} '{s}' — skipped", .{ opt[0], value });
            }
            return true;
        }
    }
    return false;
}

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
    unbind,
};

fn parseValue(raw: []const u8, arena: std.mem.Allocator) !Value {
    const v = std.mem.trim(u8, raw, " \t");
    if (v.len == 0) return error.EmptyValue;
    if (v[0] == '+') return .{ .label = try arena.dupe(u8, v[1..]) };
    if (std.mem.eql(u8, v, "@unbind")) return .unbind;
    if (v[0] == '@') {
        inline for (@typeInfo(lib_state.builtin_defs).@"struct".decl_names) |d_name| {
            if (std.mem.eql(u8, v[1..], d_name))
                return .{ .builtin = &@field(lib_state.builtin_defs, d_name) };
        }
        return error.UnknownBuiltin;
    }
    if (std.fmt.parseInt(c_int, v, 10)) |id| return .{ .cmd = id } else |_| {}
    if (v[0] == '_') return .{ .named = try arena.dupeSentinel(u8, v, 0) };
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
        .label, .unbind => unreachable, // handled by caller
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
            // Like a numeric id, a named command bound in the MIDI context is
            // dispatched to the MIDI editor; perken-utilities registers its
            // MIDI actions in the MIDI editor section for that reason.
            def.* = .{ .steps = steps, .prefix_repetition_count = true, .midi_command = midi };
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
    reader: *std.Io.Reader,
) !Bindings {
    var b = Bindings{
        .arena = std.heap.ArenaAllocator.init(gpa),
        .tables = .{ .tries = undefined },
    };
    errdefer b.arena.deinit();
    for (&b.tables.tries) |*row| for (row) |*t| {
        t.* = try builder.KeyTrie.init(gpa);
    };
    const arena = b.arena.allocator();

    const stub_def = try arena.create(actions.ActionDef);
    stub_def.* = .{ .steps = &.{}, .desc = "(stub)" };

    // Pass 1: read all entries, keeping global separate.
    var entries: std.ArrayList(RawEntry) = .empty;
    defer entries.deinit(gpa);

    var parser = ini.parse(gpa, reader, ";#");
    defer parser.deinit();

    var section: CurSection = .unknown;
    var keybuf: std.ArrayList(keymod.Key) = .empty;
    defer keybuf.deinit(gpa);

    while (try parser.next()) |record| {
        switch (record) {
            .section => |name| {
                if (std.mem.eql(u8, name, "whichkey")) {
                    section = .whichkey;
                } else if (std.mem.eql(u8, name, "labels")) {
                    section = .labels;
                } else if (parseSectionName(name)) |sec| {
                    section = .{ .binding = sec };
                } else {
                    section = .unknown;
                    log.warn("unknown section [{s}] — skipped", .{name});
                }
            },
            .property => |kv| switch (section) {
                .unknown => {},
                .labels => {
                    const label = keyboard.parseLabel(kv.value) catch |err| {
                        log.warn("bad label '{s}' for '{s}': {s} — skipped", .{ kv.value, kv.key, @errorName(err) });
                        continue;
                    };
                    const name = try arena.dupe(u8, std.mem.trim(u8, kv.key, " \t"));
                    try b.labels.put(arena, name, .{
                        .text = try arena.dupe(u8, label.text),
                        .category = label.category,
                    });
                },
                .whichkey => {
                    if (try parseWhichkeyOption(&b, kv.key, kv.value)) continue;
                    const key = parseSingleKey(kv.value) orelse {
                        log.warn("bad whichkey key '{s}' for '{s}' — skipped", .{ kv.value, kv.key });
                        continue;
                    };
                    if (std.mem.eql(u8, kv.key, "page_next")) {
                        b.page_next = key;
                    } else if (std.mem.eql(u8, kv.key, "page_prev")) {
                        b.page_prev = key;
                    } else {
                        log.warn("unknown [whichkey] key '{s}' — skipped", .{kv.key});
                    }
                },
                .binding => |sec| {
                    keybuf.clearRetainingCapacity();
                    keymod.parseSequence(gpa, kv.key, &keybuf) catch |err| {
                        log.warn("bad key sequence '{s}': {s} — skipped", .{ kv.key, @errorName(err) });
                        continue;
                    };
                    if (keybuf.items.len == 0) continue;
                    const value = parseValue(kv.value, arena) catch |err| {
                        log.warn("bad value '{s}' for '{s}': {s} — skipped", .{ kv.value, kv.key, @errorName(err) });
                        continue;
                    };
                    try entries.append(gpa, .{
                        .section = sec,
                        .keys = try arena.dupe(keymod.Key, keybuf.items),
                        .value = value,
                    });
                },
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
                if (e.value == .unbind) {
                    t.remove(e.keys);
                    continue;
                }
                const bv = (try toBindingValue(e.value, registry, arena, ctx == .midi, stub_def)) orelse continue;
                try t.insertReplace(e.keys, bv);
            }
        }
    }

    if (registry.get("CurrentTrack")) |def| {
        b.tables.current_track = .{ .name = "CurrentTrack", .def = def };
    }
    return b;
}

pub fn parseString(gpa: std.mem.Allocator, registry: *const actions.Registry, text: []const u8) !Bindings {
    var fbs: std.Io.Reader = .fixed(text);
    return parse(gpa, registry, &fbs);
}

// ---- tests ----

const test_defs = [_]actions.Entry{
    .{ .name = "NextTrack", .def = .{ .steps = &.{.{ .cmd = 40285 }}, .prefix_repetition_count = true } },
    .{ .name = "RemoveTracks", .def = .{ .steps = &.{.{ .cmd = 40005 }} } },
};

test "whichkey view options and labels" {
    var reg = try actions.Registry.init(std.testing.allocator, &.{});
    defer reg.deinit();
    var b = try parseString(std.testing.allocator, &reg,
        \\[whichkey]
        \\view = list
        \\layout = bepo
        \\board = ortho
        \\[labels]
        \\AddNextNoteToSelection = Extend → | extend
        \\Quantize = Quantize
        \\Broken = X | nope
    );
    defer b.deinit();
    try std.testing.expectEqual(keyboard.View.list, b.view);
    try std.testing.expectEqual(keyboard.Layout.bepo, b.layout);
    try std.testing.expectEqual(keyboard.Board.ortho, b.board);
    const ext = b.labels.get("AddNextNoteToSelection").?;
    try std.testing.expectEqualStrings("Extend →", ext.text);
    try std.testing.expectEqual(keyboard.Category.extend, ext.category.?);
    try std.testing.expect(b.labels.get("Quantize").?.category == null);
    try std.testing.expect(b.labels.get("Broken") == null);
}

test "whichkey dock option" {
    var reg = try actions.Registry.init(std.testing.allocator, &.{});
    defer reg.deinit();

    // a missing setting counts as "none"
    var d = try parseString(std.testing.allocator, &reg, "[main.command]\nj = 40285\n");
    defer d.deinit();
    try std.testing.expectEqual(@as(?u8, null), d.dock);

    // an empty setting counts as "none" too
    var empty = try parseString(std.testing.allocator, &reg, "[whichkey]\ndock =\n");
    defer empty.deinit();
    try std.testing.expectEqual(@as(?u8, null), empty.dock);

    var seven = try parseString(std.testing.allocator, &reg, "[whichkey]\ndock = 7\n");
    defer seven.deinit();
    try std.testing.expectEqual(@as(?u8, 7), seven.dock);

    var floating = try parseString(std.testing.allocator, &reg, "[whichkey]\ndock = none\n");
    defer floating.deinit();
    try std.testing.expectEqual(@as(?u8, null), floating.dock);

    // an out-of-range or unreadable value keeps the default
    var bad = try parseString(std.testing.allocator, &reg, "[whichkey]\ndock = 17\n");
    defer bad.deinit();
    try std.testing.expectEqual(@as(?u8, null), bad.dock);
}

test "whichkey pagination keys default and override" {
    var reg = try actions.Registry.init(std.testing.allocator, &.{});
    defer reg.deinit();

    // defaults when no [whichkey] section
    var d = try parseString(std.testing.allocator, &reg, "[main.command]\nj = 40285\n");
    defer d.deinit();
    try std.testing.expectEqual(keymod.VK.NEXT, d.page_next.vk);
    try std.testing.expectEqual(keymod.VK.PRIOR, d.page_prev.vk);

    // override via config
    var o = try parseString(std.testing.allocator, &reg,
        \\[whichkey]
        \\page_next = <C-n>
        \\page_prev = <C-p>
    );
    defer o.deinit();
    try std.testing.expectEqual(@as(u8, 'N'), o.page_next.vk);
    try std.testing.expect(o.page_next.ctrl);
    try std.testing.expectEqual(@as(u8, 'P'), o.page_prev.vk);
    try std.testing.expect(o.page_prev.ctrl);
}

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

    var keys: std.ArrayList(keymod.Key) = .empty;
    defer keys.deinit(std.testing.allocator);

    try keymod.parseSequence(std.testing.allocator, ";", &keys);
    const semi = builder.build(&b.tables, .main, .normal, keys.items).?;
    try std.testing.expectEqual(@as(c_int, 40912), semi.keys[0].def.steps[0].cmd);

    keys.clearRetainingCapacity();
    try keymod.parseSequence(std.testing.allocator, "x#1", &keys);
    const hash = builder.build(&b.tables, .main, .normal, keys.items).?;
    try std.testing.expectEqual(@as(c_int, 40913), hash.keys[0].def.steps[0].cmd);
}

test "unbind drops a global binding in one context only" {
    const text =
        \\[global.timeline_motion]
        \\j = NextTrack
        \\
        \\[midi.timeline_motion]
        \\j = @unbind
    ;
    var reg = try actions.Registry.init(std.testing.allocator, &.{&test_defs});
    defer reg.deinit();
    var b = try parseString(std.testing.allocator, &reg, text);
    defer b.deinit();
    var keys: std.ArrayList(keymod.Key) = .empty;
    defer keys.deinit(std.testing.allocator);
    try keymod.parseSequence(std.testing.allocator, "j", &keys);
    try std.testing.expect(builder.build(&b.tables, .main, .normal, keys.items) != null);
    try std.testing.expect(builder.build(&b.tables, .midi, .normal, keys.items) == null);
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

    var keys: std.ArrayList(keymod.Key) = .empty;
    defer keys.deinit(std.testing.allocator);

    // dj builds as track_op_motion through the grammar
    try keymod.parseSequence(std.testing.allocator, "dj", &keys);
    const cmd = builder.build(&b.tables, .main, .normal, keys.items).?;
    try std.testing.expectEqual(grammar.Composition.track_op_motion, cmd.comp);
    try std.testing.expectEqualStrings("RemoveTracks", cmd.keys[0].name);

    // global u reaches both contexts
    keys.clearRetainingCapacity();
    try keymod.parseSequence(std.testing.allocator, "u", &keys);
    try std.testing.expect(builder.build(&b.tables, .main, .normal, keys.items) != null);
    try std.testing.expect(builder.build(&b.tables, .midi, .normal, keys.items) != null);

    // midi x shadows global x
    keys.clearRetainingCapacity();
    try keymod.parseSequence(std.testing.allocator, "x", &keys);
    const mx = builder.build(&b.tables, .midi, .normal, keys.items).?;
    try std.testing.expectEqual(@as(c_int, 40002), mx.keys[0].def.steps[0].cmd);
    try std.testing.expect(mx.keys[0].def.midi_command);
    const gx = builder.build(&b.tables, .main, .normal, keys.items).?;
    try std.testing.expectEqual(@as(c_int, 40001), gx.keys[0].def.steps[0].cmd);

    // builtin
    keys.clearRetainingCapacity();
    try keymod.parseSequence(std.testing.allocator, "i", &keys);
    const bi = builder.build(&b.tables, .main, .normal, keys.items).?;
    try std.testing.expectEqualStrings("Enter insert mode", bi.keys[0].name);
}
