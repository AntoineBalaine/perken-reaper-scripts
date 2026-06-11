//! Seed of the ported action registry: verified REAPER command ids only.
//! The full ~780-action port from port/actions_inventory.md lands here
//! incrementally (tasks #3/#4); unknown names referenced by bindings simply
//! log as stubs until their entry appears.
const actions = @import("actions.zig");

pub const entries = [_]actions.Entry{
    // track motions
    .{ .name = "NextTrack", .def = .{ .steps = &.{.{ .cmd = 40285 }}, .prefix_repetition_count = true } },
    .{ .name = "PrevTrack", .def = .{ .steps = &.{.{ .cmd = 40286 }}, .prefix_repetition_count = true } },

    // track operators
    .{ .name = "RemoveTracks", .def = .{ .steps = &.{.{ .cmd = 40005 }} } },

    // commands
    .{ .name = "InsertTrack", .def = .{ .steps = &.{.{ .cmd = 40001 }}, .prefix_repetition_count = true } },
    .{ .name = "Undo", .def = .{ .steps = &.{.{ .cmd = 40029 }}, .prefix_repetition_count = true } },
    .{ .name = "Redo", .def = .{ .steps = &.{.{ .cmd = 40030 }}, .prefix_repetition_count = true } },
    .{ .name = "ScrollTrackIntoView", .def = .{ .steps = &.{.{ .cmd = 40913 }} } },

    // timeline motions (cursor moves; ids to verify in REAPER)
    .{ .name = "NextMeasure", .def = .{ .steps = &.{.{ .cmd = 41042 }}, .prefix_repetition_count = true } },
    .{ .name = "PrevMeasure", .def = .{ .steps = &.{.{ .cmd = 41043 }}, .prefix_repetition_count = true } },

    // timeline operators
    .{ .name = "SelectItems", .def = .{ .steps = &.{.{ .cmd = 40717 }}, .set_time_selection = true } },
};
