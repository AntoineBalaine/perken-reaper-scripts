//! Meta commands (reavim handler.lua + meta_command.lua): macros, repeat,
//! binding list. Meta commands are detected by the name of a [command]-type
//! action key and handled here instead of going through the runner.
//!
//! Macros work like vim's: a register holds the keys typed between q{reg}
//! and q, and @{reg} feeds them back through the engine as if typed, so
//! counts, operators, visual modes, "." and nested @ all replay naturally.
//! q{REG} (an uppercase letter) appends to the register instead of replacing
//! it, @@ plays the register played last, and [count]@{reg} repeats. The
//! registers persist in Data/Perken/macros.ini, one line per register.
//!
//! Two things differ from vim because REAPER has no failing motion to end a
//! recursive macro on: playback stops after `max_depth` nested @ calls or
//! `max_keys_per_play` replayed keys. And keys typed in insert mode pass
//! through to REAPER, so only the <esc> that leaves insert mode is recorded.
const std = @import("std");
const builder = @import("builder.zig");
const grammar = @import("grammar.zig");
const keymod = @import("key.zig");
const runner = @import("runner.zig");
const vim = @import("vim.zig");
const perken_file = @import("perken_file.zig");

const Key = keymod.Key;
const log = std.log.scoped(.engine);

pub const macros_file = "macros.ini";
/// How deep @ calls may nest before playback gives up.
pub const max_depth: u32 = 100;
/// How many keys one top-level @ call may replay before playback gives up.
pub const max_keys_per_play: usize = 100_000;
/// The register name that @@ uses: play the register played last.
pub const last_played_name: u8 = '@';

pub var recording: bool = false;
/// The register being recorded into, as a folded name ('a', '3', '"').
pub var record_register: u8 = 0;
var last_played: ?u8 = null;
var last_command: ?builder.Command = null;

var play_depth: u32 = 0;
var play_budget: usize = 0;
var play_exhausted: bool = false;
/// Where played keys go. A test swaps it for a counter.
pub var feed_fn: *const fn (Key) void = &vim.feedKey;

var gpa: std.mem.Allocator = std.heap.c_allocator;
var macros: std.AutoHashMapUnmanaged(u8, std.ArrayList(Key)) = .{};

pub const MetaKind = enum { play_macro, record_macro, stop_record_macro, repeat_last, show_binding_list };

pub fn metaKind(cmd: *const builder.Command) ?MetaKind {
    // Meta commands are single [command]-type sequences.
    if (cmd.types.len != 1 or cmd.types[0] != .command) return null;
    const name = cmd.keys[0].name;
    if (std.mem.eql(u8, name, "PlayMacro")) return .play_macro;
    if (std.mem.eql(u8, name, "RecordMacro")) return .record_macro;
    if (std.mem.eql(u8, name, "StopRecordMacro")) return .stop_record_macro;
    if (std.mem.eql(u8, name, "RepeatLastCommand")) return .repeat_last;
    if (std.mem.eql(u8, name, "ShowBindingList")) return .show_binding_list;
    return null;
}

/// reavim repeatable_commands_action_type_match = {command, operator,
/// meta_command}: substring match over the action type names.
fn isRepeatable(cmd: *const builder.Command) bool {
    for (cmd.types) |t| {
        const name = @tagName(t);
        if (std.mem.indexOf(u8, name, "command") != null) return true;
        if (std.mem.indexOf(u8, name, "operator") != null) return true;
    }
    return false;
}

/// Called by vim.zig for every successfully built non-meta command, after
/// execution: remembers it for ".".
pub fn afterExecute(cmd: builder.Command) void {
    if (isRepeatable(&cmd)) last_command = cmd;
}

// ---- registers ----

/// The register a key names, folded the way vim does: letters a-z (an
/// uppercase letter names the same register, see isAppendKey), digits, and
/// the plain punctuation keys. Modified and named keys name no register.
pub fn registerOf(k: Key) ?u8 {
    if (k.ctrl or k.alt) return null;
    if (k.is_char) return if (k.vk > ' ' and k.vk < 0x7f) k.vk else null;
    if (k.vk >= 'A' and k.vk <= 'Z') return std.ascii.toLower(k.vk);
    if (k.vk >= '0' and k.vk <= '9') return k.vk;
    return null;
}

/// q{REG}: an uppercase letter appends to the register.
pub fn isAppendKey(k: Key) bool {
    return !k.is_char and k.shift and k.vk >= 'A' and k.vk <= 'Z';
}

pub fn playing() bool {
    return play_depth > 0;
}

/// The keys of a register, for the UI and the tests.
pub fn macro(reg: u8) ?[]const Key {
    const list = macros.getPtr(reg) orelse return null;
    return list.items;
}

/// Called by vim.zig with the keys of each sequence the engine consumed.
/// Keys replayed by @ are not recorded again: the @{reg} keys are.
pub fn recordKeys(keys: []const Key) void {
    if (!recording or playing()) return;
    const gop = macros.getOrPut(gpa, record_register) catch return;
    if (!gop.found_existing) gop.value_ptr.* = .empty;
    gop.value_ptr.appendSlice(gpa, keys) catch {};
}

pub fn recordKey(k: Key) void {
    recordKeys(&.{k});
}

fn startRecording(reg_key: Key) void {
    const reg = registerOf(reg_key) orelse {
        var kb: [16]u8 = undefined;
        log.info("RecordMacro: {s} names no register", .{keymod.format(reg_key, &kb)});
        return;
    };
    if (reg == last_played_name) {
        log.info("RecordMacro: @ is not a register", .{});
        return;
    }
    const append = isAppendKey(reg_key);
    if (!append) {
        if (macros.getPtr(reg)) |list| list.clearRetainingCapacity();
    }
    record_register = reg;
    recording = true;
    log.info("recording macro @{c}{s}", .{ reg, if (append) " (appending)" else "" });
}

fn stopRecording() void {
    if (!recording) return;
    recording = false;
    const count = if (macros.getPtr(record_register)) |l| l.items.len else 0;
    log.info("stopped recording @{c} ({d} keys)", .{ record_register, count });
    save();
}

fn play(reg: u8, times: u32) void {
    const list = macros.getPtr(reg) orelse {
        log.info("no macro in register {c}", .{reg});
        return;
    };
    if (play_depth >= max_depth) {
        play_exhausted = true;
        return;
    }
    if (play_depth == 0) {
        play_budget = max_keys_per_play;
        play_exhausted = false;
    }
    play_depth += 1;
    defer play_depth -= 1;

    // A copy, so that nothing a replayed key does to the table moves the
    // keys under the loop.
    const keys = gpa.dupe(Key, list.items) catch return;
    defer gpa.free(keys);

    var i: u32 = 0;
    outer: while (i < times) : (i += 1) {
        for (keys) |k| {
            if (play_exhausted) break :outer;
            if (play_budget == 0) {
                play_exhausted = true;
                break :outer;
            }
            play_budget -= 1;
            feed_fn(k);
        }
    }

    if (play_depth == 1) {
        if (play_exhausted) {
            log.warn("macro @{c} stopped: deeper than {d} nested calls or more than {d} keys (recursive macro?)", .{ reg, max_depth, max_keys_per_play });
        } else {
            log.info("played macro @{c} x{d} ({d} keys)", .{ reg, times, keys.len });
        }
    }
}

pub fn handle(cmd: builder.Command, ctx: grammar.Context) void {
    switch (metaKind(&cmd).?) {
        .record_macro => {
            // Like vim, q does nothing while a register is executing.
            if (playing()) return;
            if (recording) {
                stopRecording();
            } else if (cmd.keys[0].register) |reg| {
                startRecording(reg);
            } else {
                log.info("RecordMacro: no register given", .{});
            }
        },
        .stop_record_macro => {
            if (playing()) return;
            stopRecording();
        },
        .play_macro => {
            const reg_key = cmd.keys[0].register orelse return;
            const named = registerOf(reg_key) orelse {
                var kb: [16]u8 = undefined;
                log.info("PlayMacro: {s} names no register", .{keymod.format(reg_key, &kb)});
                return;
            };
            const reg = if (named == last_played_name) last_played orelse {
                log.info("@@: no macro played yet", .{});
                return;
            } else named;
            last_played = reg;
            last_command = cmd; // "." repeats the last @{reg} call
            play(reg, @max(cmd.keys[0].prefixed_repetitions, 1));
        },
        .repeat_last => {
            const last = last_command orelse return;
            const times = @max(cmd.keys[0].prefixed_repetitions, 1);
            var i: u32 = 0;
            while (i < times) : (i += 1) {
                if (metaKind(&last) != null) {
                    handle(last, ctx);
                } else {
                    runner.execute(last, ctx);
                }
            }
        },
        .show_binding_list => @import("ui.zig").openSearch(),
    }
}

// ---- persistence ----

/// Writes the registers as `<name>=<keys>` lines, sorted by name.
pub fn dump(w: *std.Io.Writer) !void {
    var names: [256]u8 = undefined;
    var n: usize = 0;
    var it = macros.iterator();
    while (it.next()) |e| {
        if (e.value_ptr.items.len == 0) continue;
        names[n] = e.key_ptr.*;
        n += 1;
    }
    std.mem.sort(u8, names[0..n], {}, std.sort.asc(u8));
    for (names[0..n]) |name| {
        try w.print("{c}=", .{name});
        for (macros.get(name).?.items) |k| {
            var kb: [16]u8 = undefined;
            try w.writeAll(keymod.format(k, &kb));
        }
        try w.writeByte('\n');
    }
}

/// Reads `<name>=<keys>` lines into the registers, replacing the ones named.
pub fn loadText(text: []const u8) void {
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw| {
        const line = std.mem.trimEnd(u8, raw, "\r");
        if (line.len < 2 or line[1] != '=') continue;
        var keys: std.ArrayList(Key) = .empty;
        keymod.parseSequence(gpa, line[2..], &keys) catch |err| {
            keys.deinit(gpa);
            log.warn("macros.ini: register {c} skipped: {s}", .{ line[0], @errorName(err) });
            continue;
        };
        const gop = macros.getOrPut(gpa, line[0]) catch {
            keys.deinit(gpa);
            continue;
        };
        if (gop.found_existing) gop.value_ptr.deinit(gpa);
        gop.value_ptr.* = keys;
    }
}

const file_buf_size = 64 * 1024;

fn save() void {
    var buf: [file_buf_size]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    dump(&w) catch {
        log.warn("macros.ini not written: the registers exceed {d} bytes", .{file_buf_size});
        return;
    };
    perken_file.write(macros_file, w.buffered());
}

/// Restores the registers persisted by a previous session. Call once at load.
pub fn load() void {
    var buf: [file_buf_size]u8 = undefined;
    const text = perken_file.readInto(macros_file, &buf) orelse return;
    loadText(text);
    log.info("macros restored ({d} registers)", .{macros.count()});
}

// ---- tests ----

fn clearAll() void {
    var it = macros.valueIterator();
    while (it.next()) |list| list.deinit(gpa);
    macros.clearRetainingCapacity();
    recording = false;
    last_played = null;
    last_command = null;
}

fn parse(text: []const u8) !std.ArrayList(Key) {
    var keys: std.ArrayList(Key) = .empty;
    try keymod.parseSequence(gpa, text, &keys);
    return keys;
}

fn metaCommand(name: []const u8, def: *const @import("actions.zig").ActionDef, register: ?Key, count: u32) builder.Command {
    var cmd = builder.Command{ .comp = .plain, .types = &.{.command}, .keys = undefined };
    cmd.keys[0] = .{ .name = name, .def = def, .register = register, .prefixed_repetitions = count };
    return cmd;
}

test "meta kind detection and repeatability" {
    const actions = @import("actions.zig");
    const def = actions.ActionDef{};
    const cmd = metaCommand("PlayMacro", &def, null, 1);
    try std.testing.expectEqual(MetaKind.play_macro, metaKind(&cmd).?);
    try std.testing.expect(isRepeatable(&cmd));

    var motion = builder.Command{
        .comp = .plain,
        .types = &.{.track_motion},
        .keys = undefined,
    };
    motion.keys[0] = .{ .name = "NextTrack", .def = &def };
    try std.testing.expect(metaKind(&motion) == null);
    try std.testing.expect(!isRepeatable(&motion));

    var op = builder.Command{
        .comp = .track_op_motion,
        .types = &.{ .track_operator, .track_motion },
        .keys = undefined,
    };
    op.keys[0] = .{ .name = "CutTrack", .def = &def };
    op.keys[1] = .{ .name = "NextTrack", .def = &def };
    try std.testing.expect(isRepeatable(&op));
}

test "register names fold like vim's" {
    try std.testing.expectEqual(@as(?u8, 'a'), registerOf(.{ .vk = 'A' }));
    try std.testing.expectEqual(@as(?u8, 'a'), registerOf(.{ .vk = 'A', .shift = true }));
    try std.testing.expectEqual(@as(?u8, '3'), registerOf(.{ .vk = '3' }));
    try std.testing.expectEqual(@as(?u8, '"'), registerOf(.{ .vk = '"', .is_char = true }));
    try std.testing.expectEqual(@as(?u8, '@'), registerOf(.{ .vk = '@', .is_char = true }));
    try std.testing.expectEqual(@as(?u8, null), registerOf(.{ .vk = 'A', .ctrl = true }));
    try std.testing.expectEqual(@as(?u8, null), registerOf(.{ .vk = keymod.VK.ESCAPE }));
    try std.testing.expect(isAppendKey(.{ .vk = 'A', .shift = true }));
    try std.testing.expect(!isAppendKey(.{ .vk = 'A' }));
}

test "recording: q{reg} replaces, q{REG} appends, replayed keys are not recorded" {
    const actions = @import("actions.zig");
    const def = actions.ActionDef{ .register_action = true, .register_optional = true };
    clearAll();
    defer clearAll();

    var jj = try parse("jj");
    defer jj.deinit(gpa);
    var dd = try parse("dd");
    defer dd.deinit(gpa);

    handle(metaCommand("RecordMacro", &def, .{ .vk = 'A' }, 1), .main);
    try std.testing.expect(recording);
    try std.testing.expectEqual(@as(u8, 'a'), record_register);
    recordKeys(jj.items);
    handle(metaCommand("RecordMacro", &def, null, 1), .main);
    try std.testing.expect(!recording);
    try std.testing.expectEqual(@as(usize, 2), macro('a').?.len);

    // qA appends.
    handle(metaCommand("RecordMacro", &def, .{ .vk = 'A', .shift = true }, 1), .main);
    recordKeys(dd.items);
    handle(metaCommand("RecordMacro", &def, null, 1), .main);
    try std.testing.expectEqual(@as(usize, 4), macro('a').?.len);
    try std.testing.expectEqual(@as(u8, 'D'), macro('a').?[2].vk);

    // qa replaces.
    handle(metaCommand("RecordMacro", &def, .{ .vk = 'A' }, 1), .main);
    recordKeys(dd.items);
    handle(metaCommand("RecordMacro", &def, null, 1), .main);
    try std.testing.expectEqual(@as(usize, 2), macro('a').?.len);

    // Keys fed while a register plays are not recorded.
    handle(metaCommand("RecordMacro", &def, .{ .vk = 'B' }, 1), .main);
    play_depth = 1;
    recordKeys(jj.items);
    play_depth = 0;
    try std.testing.expect(macro('b') == null);
    handle(metaCommand("RecordMacro", &def, null, 1), .main);
}

const Counter = struct {
    var fed: usize = 0;
    var last: Key = .{ .vk = 0 };
    fn feed(k: Key) void {
        fed += 1;
        last = k;
    }
};

test "playback: count, @@, and the recursion guard" {
    const actions = @import("actions.zig");
    const def = actions.ActionDef{ .register_action = true, .prefix_repetition_count = true };
    clearAll();
    defer clearAll();
    const saved_feed = feed_fn;
    feed_fn = &Counter.feed;
    defer feed_fn = saved_feed;

    loadText("a=jjd<C-x>\n");
    try std.testing.expectEqual(@as(usize, 4), macro('a').?.len);

    Counter.fed = 0;
    handle(metaCommand("PlayMacro", &def, .{ .vk = 'A' }, 3), .main);
    try std.testing.expectEqual(@as(usize, 12), Counter.fed);
    try std.testing.expect(Counter.last.ctrl);

    // @@ replays the register played last.
    Counter.fed = 0;
    handle(metaCommand("PlayMacro", &def, .{ .vk = '@', .is_char = true }, 1), .main);
    try std.testing.expectEqual(@as(usize, 4), Counter.fed);

    // An unknown register plays nothing.
    Counter.fed = 0;
    handle(metaCommand("PlayMacro", &def, .{ .vk = 'Z' }, 1), .main);
    try std.testing.expectEqual(@as(usize, 0), Counter.fed);

    // A register that calls itself stops at the depth guard instead of
    // running forever: the feed stands in for the engine and re-enters play.
    const Recursive = struct {
        fn feed(k: Key) void {
            _ = k;
            Counter.fed += 1;
            play('r', 1);
        }
    };
    loadText("r=j\n");
    feed_fn = &Recursive.feed;
    Counter.fed = 0;
    handle(metaCommand("PlayMacro", &def, .{ .vk = 'R' }, 1), .main);
    try std.testing.expectEqual(@as(usize, max_depth), Counter.fed);
    try std.testing.expect(play_exhausted);
    try std.testing.expectEqual(@as(u32, 0), play_depth);
}

test "macros.ini round trip" {
    clearAll();
    defer clearAll();
    loadText("b=<esc>3@a\r\na=jjG\nnot a line\nx=<bogus>\n");
    try std.testing.expect(macro('x') == null);
    try std.testing.expectEqual(@as(usize, 3), macro('a').?.len);

    var buf: [256]u8 = undefined;
    var w: std.Io.Writer = .fixed(&buf);
    try dump(&w);
    try std.testing.expectEqualStrings("a=jjG\nb=<esc>3@a\n", w.buffered());

    // Reading the dump back yields the same registers.
    clearAll();
    loadText(w.buffered());
    var w2: std.Io.Writer = .fixed(&buf);
    try dump(&w2);
    try std.testing.expectEqualStrings("a=jjG\nb=<esc>3@a\n", w2.buffered());
}
