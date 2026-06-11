//! Port of reavim custom_actions/fx.lua — a single HARD action, registered
//! as a logging stub for now.
const std = @import("std");
const actions = @import("../actions.zig");

const log = std.log.scoped(.engine);

// TODO(HARD): fx.insertFXAtSlot prompts for a slot, saves the selection,
// inserts a dummy track, opens the FX browser (40271), then arms a
// reaper.defer polling loop that watches Undo_CanUndo2(0) for a
// locale-dependent "Add FX: ..." undo label before TrackFX_CopyToTrack-ing
// the new FX to every originally-selected track at the slot and deleting the
// dummy track. A native port should poll from a timer/idle hook and watch the
// dummy track's TrackFX_GetCount instead of parsing undo text.
fn insertFXAtSlot(_: *actions.RunCtx) void {
    log.warn("'InsertFxAtSlot' not ported yet", .{});
}

pub const entries = [_]actions.Entry{
    .{ .name = "InsertFxAtSlot", .def = .{ .steps = &.{.{ .func = &insertFXAtSlot }} } },
};
