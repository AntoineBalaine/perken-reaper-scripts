//! Action definitions registry — the Zig port of reavim's actions.lua.
//!
//! An action definition carries execution steps plus the flags the grammar
//! needs at parse time (prefixRepetitionCount, registerAction, ...) and at
//! run time (repetitions, midiCommand, setTimeSelection, pre/post actions).
//! Bindings (INI) reference actions by name; the registry resolves names.
const std = @import("std");
const keymod = @import("key.zig");

const log = std.log.scoped(.engine);

/// Execution context handed to native action functions.
pub const RunCtx = struct {
    /// Context of the keypress (main window or MIDI editor).
    context: Context,
    /// Register key for register actions (e.g. the 'a' of "ma), 0 vk = none.
    register: keymod.Key = .{ .vk = 0 },

    pub const Context = enum { main, midi };
};

pub const NativeFn = *const fn (ctx: *RunCtx) void;

/// One positional step of an action.
pub const Step = union(enum) {
    /// Numeric REAPER command id.
    cmd: c_int,
    /// Named command ("_SWS_...", "_RS..."), resolved via NamedCommandLookup.
    named: [:0]const u8,
    /// Reference to another action in the registry (composite actions).
    action: []const u8,
    /// Native Zig implementation.
    func: NativeFn,
};

pub const ActionDef = struct {
    steps: []const Step = &.{},
    /// Static multiplier baked into the definition (e.g. Next4Measures).
    repetitions: u32 = 1,
    /// Whether a typed count prefix (e.g. the 3 of "3j") applies to this action.
    prefix_repetition_count: bool = false,
    /// Register actions take a trailing register key ("ma, @q). Their first
    /// step must be .func and receives the register via RunCtx.
    register_action: bool = false,
    /// Register actions that also match bare (e.g. RecordMacro stop).
    register_optional: bool = false,
    /// Dispatch numeric ids via MIDIEditor_LastFocused_OnCommand.
    midi_command: bool = false,
    /// Operator flags: "this operator's purpose IS the selection — don't restore".
    set_time_selection: bool = false,
    set_track_selection: bool = false,
    pre_action: ?[]const u8 = null,
    post_action: ?[]const u8 = null,
    /// Human-readable description for the feedback window; falls back to
    /// kbd_getTextFromCmd for single-cmd actions.
    desc: ?[]const u8 = null,
};

pub const Entry = struct {
    name: []const u8,
    def: ActionDef,
};

/// The registry: name -> definition. Seeded from the comptime table(s) of
/// ported defaults; INI bindings may also reference raw ids / named commands
/// directly without going through the registry.
pub const Registry = struct {
    map: std.StringHashMapUnmanaged(ActionDef) = .{},
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, tables: []const []const Entry) !Registry {
        var self = Registry{ .allocator = allocator };
        errdefer self.map.deinit(allocator);
        for (tables) |table| {
            for (table) |entry| {
                const gop = try self.map.getOrPut(allocator, entry.name);
                if (gop.found_existing)
                    log.warn("duplicate action definition '{s}' — last one wins", .{entry.name});
                gop.value_ptr.* = entry.def;
            }
        }
        return self;
    }

    pub fn deinit(self: *Registry) void {
        self.map.deinit(self.allocator);
    }

    pub fn get(self: *const Registry, name: []const u8) ?*const ActionDef {
        return self.map.getPtr(name);
    }
};

test "registry init and lookup" {
    const table = [_]Entry{
        .{ .name = "NextTrack", .def = .{ .steps = &.{.{ .cmd = 40285 }}, .prefix_repetition_count = true } },
        .{ .name = "Reset", .def = .{ .steps = &.{ .{ .action = "Stop" }, .{ .action = "SetModeNormal" } } } },
    };
    var reg = try Registry.init(std.testing.allocator, &.{&table});
    defer reg.deinit();

    const nt = reg.get("NextTrack").?;
    try std.testing.expect(nt.prefix_repetition_count);
    try std.testing.expectEqual(@as(c_int, 40285), nt.steps[0].cmd);
    try std.testing.expect(reg.get("Nope") == null);
}
