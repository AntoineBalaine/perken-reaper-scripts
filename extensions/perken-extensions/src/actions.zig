//! The action model of perken-extensions.
//!
//! Each module exports `entries`, a table of named actions. main.zig
//! registers every entry as a REAPER action whose command id is
//! `_PERKEN_<name>`, so that reavim-ext (or any keymap) can bind it. Actions
//! flagged `midi_command` are registered in the MIDI editor section, and their
//! numeric steps are dispatched to the last focused MIDI editor.
//!
//! This is a deliberately small subset of reavim-ext's action model: there is
//! no grammar here, so counts, registers and operator flags do not exist.
//! reavim-ext repeats a counted binding by running the command several times.
const std = @import("std");
const Reaper = @import("reaper").reaper;

const log = std.log.scoped(.extension);

/// Execution context handed to native action functions.
pub const RunCtx = struct {
    /// The section the action was triggered from.
    context: Context,

    pub const Context = enum { main, midi };
};

pub const NativeFn = *const fn (ctx: *RunCtx) void;

/// One step of an action, run in order.
pub const Step = union(enum) {
    /// Numeric REAPER command id.
    cmd: c_int,
    /// Named command ("_SWS_...", "_RS..."), resolved via NamedCommandLookup.
    named: [:0]const u8,
    /// Native Zig implementation.
    func: NativeFn,
};

pub const ActionDef = struct {
    steps: []const Step = &.{},
    /// Register in the MIDI editor section, and dispatch numeric steps through
    /// MIDIEditor_LastFocused_OnCommand.
    midi_command: bool = false,
    /// Human-readable name for REAPER's action list; falls back to the
    /// action's name.
    desc: ?[]const u8 = null,
    /// For on/off actions: reports the current state to REAPER (toolbar
    /// buttons and menu check marks).
    toggle_state: ?*const fn () bool = null,
};

pub const Entry = struct {
    name: []const u8,
    def: ActionDef,
};

pub fn run(def: *const ActionDef) void {
    var ctx = RunCtx{ .context = if (def.midi_command) .midi else .main };
    for (def.steps) |step| {
        switch (step) {
            .cmd => |id| dispatch(id, def.midi_command),
            .named => |name| {
                const id = Reaper.NamedCommandLookup(name.ptr);
                if (id == 0) {
                    log.warn("named command not found: {s}", .{name});
                    continue;
                }
                dispatch(id, def.midi_command);
            },
            .func => |f| f(&ctx),
        }
    }
}

pub fn dispatch(id: c_int, midi: bool) void {
    if (midi) {
        _ = Reaper.MIDIEditor_LastFocused_OnCommand(id, false);
    } else {
        Reaper.Main_OnCommand(id, 0);
    }
}
