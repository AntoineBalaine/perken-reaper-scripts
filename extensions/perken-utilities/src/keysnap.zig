//! Port of reavim custom_actions/midi.lua's toggleKeySnap, which toggles the
//! MIDI editor's key-snap checkbox. It stays a logging stub for now.
const std = @import("std");
const actions = @import("actions.zig");

const log = std.log.scoped(.extension);

// TODO: the Lua drives the checkbox through js_ReaScriptAPI:
// JS_Window_FindChildByID(editor, 0x4EC) for the key-snap checkbox, then
// JS_WindowMessage_Send (BM_GETCHECK / BM_SETCHECK / WM_COMMAND 1260). A
// compiled extension can send those window messages itself through SWELL /
// Win32, so it does not need js_ReaScriptAPI.
fn toggleKeySnap(_: *actions.RunCtx) void {
    log.warn("'toggleKeySnap' not ported yet", .{});
}

pub const entries = [_]actions.Entry{
    .{ .name = "toggleKeySnap", .def = .{ .steps = &.{.{ .func = &toggleKeySnap }}, .midi_command = true } },
};
