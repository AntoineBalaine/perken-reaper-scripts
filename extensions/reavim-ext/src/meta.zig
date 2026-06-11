//! Meta commands (reavim handler.lua + meta_command.lua): macros, repeat,
//! binding list. Meta commands are detected by the name of a [command]-type
//! action key and handled here instead of going through the runner.
//!
//! Macro storage is in-memory for the session (the Lua persisted to ExtState
//! via serpent; persistence can come later — commands reference the bindings
//! arena, which lives for the session).
const std = @import("std");
const builder = @import("builder.zig");
const grammar = @import("grammar.zig");
const keymod = @import("key.zig");
const runner = @import("runner.zig");

const log = std.log.scoped(.engine);

pub var recording: bool = false;
pub var record_register: u16 = 0;
var last_command: ?builder.Command = null;

var gpa: std.mem.Allocator = std.heap.c_allocator;
var macros: std.AutoHashMapUnmanaged(u16, std.ArrayListUnmanaged(builder.Command)) = .{};

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
/// execution: records into the active macro and remembers it for ".".
pub fn afterExecute(cmd: builder.Command) void {
    if (isRepeatable(&cmd)) last_command = cmd;
    if (recording) appendToMacro(record_register, cmd);
}

fn appendToMacro(register: u16, cmd: builder.Command) void {
    const gop = macros.getOrPut(gpa, register) catch return;
    if (!gop.found_existing) gop.value_ptr.* = .{};
    gop.value_ptr.append(gpa, cmd) catch {};
}

fn registerName(bits: u16) u8 {
    const k: keymod.Key = @bitCast(bits);
    return if (k.vk >= 'A' and k.vk <= 'Z') std.ascii.toLower(k.vk) else k.vk;
}

pub fn handle(cmd: builder.Command, ctx: grammar.Context) void {
    switch (metaKind(&cmd).?) {
        .record_macro => {
            if (recording) {
                stopRecording();
            } else if (cmd.keys[0].register) |reg| {
                record_register = reg.bits();
                recording = true;
                if (macros.getPtr(record_register)) |list| list.clearRetainingCapacity();
                log.info("recording macro @{c}", .{registerName(record_register)});
            } else {
                log.info("RecordMacro: no register given", .{});
            }
        },
        .stop_record_macro => stopRecording(),
        .play_macro => {
            const reg = cmd.keys[0].register orelse return;
            const list = macros.getPtr(reg.bits()) orelse {
                log.info("no macro in register {c}", .{registerName(reg.bits())});
                return;
            };
            const times = @max(cmd.keys[0].prefixed_repetitions, 1);
            var i: u32 = 0;
            while (i < times) : (i += 1) {
                for (list.items) |stored| {
                    if (metaKind(&stored) != null) {
                        handle(stored, ctx);
                    } else {
                        runner.execute(stored, ctx);
                    }
                }
            }
            log.info("played macro @{c} x{d} ({d} commands)", .{
                registerName(reg.bits()), times, list.items.len,
            });
        },
        .repeat_last => {
            const last = last_command orelse return;
            const times = @max(cmd.keys[0].prefixed_repetitions, 1);
            var i: u32 = 0;
            while (i < times) : (i += 1) runner.execute(last, ctx);
            if (recording) appendToMacro(record_register, last);
        },
        .show_binding_list => {
            // The feedback window's completion grid is the binding list today;
            // a searchable list is future UI work.
            log.info("binding list: see the ReaVim feedback window", .{});
        },
    }
}

fn stopRecording() void {
    if (!recording) return;
    recording = false;
    const count = if (macros.getPtr(record_register)) |l| l.items.len else 0;
    log.info("stopped recording @{c} ({d} commands)", .{ registerName(record_register), count });
}

test "meta kind detection and repeatability" {
    const actions = @import("actions.zig");
    const def = actions.ActionDef{};
    var cmd = builder.Command{
        .comp = .plain,
        .types = &.{.command},
        .keys = undefined,
    };
    cmd.keys[0] = .{ .name = "PlayMacro", .def = &def };
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
