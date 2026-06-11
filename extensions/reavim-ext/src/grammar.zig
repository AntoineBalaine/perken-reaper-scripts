//! The reavim grammar: action types, legal action sequences per (context,
//! mode) in match priority order, and the composition semantics id that tells
//! the runner how to execute a matched sequence.
//! Faithful to port/bindings_inventory.md Part 2.
const std = @import("std");

pub const Context = enum { main, midi };
pub const Mode = enum { normal, visual_track, visual_timeline };

pub const ActionType = enum {
    command,
    track_motion,
    track_operator,
    track_selector,
    visual_track_command,
    timeline_motion,
    timeline_operator,
    timeline_selector,
    visual_timeline_command,
};

/// How the runner wraps execution of a matched sequence.
pub const Composition = enum {
    /// Just run it (commands, plain motions, selectors in visual modes).
    plain,
    /// Save time selection; selector sets it; run operator; restore unless setTimeSelection.
    timeline_op_selector,
    /// Save time selection; span it via motion (cursor restored); run operator; restore.
    timeline_op_motion,
    /// Save track selection; selector sets it; run operator; restore unless setTrackSelection.
    track_op_selector,
    /// Save track selection; span range via motion; run operator; restore.
    track_op_motion,
    /// Run operator on live visual timeline selection; back to normal; maybe clear.
    visual_timeline_operator,
    /// Extend the visual timeline selection with a motion (side-flipping).
    visual_timeline_motion_extend,
    /// Run operator on live visual track selection; back to normal; maybe unselect.
    visual_track_operator,
    /// Extend the visual track selection with a motion (pivot-anchored).
    visual_track_motion_extend,
    /// Timeline motion inside visual_track (gated by config).
    visual_track_timeline_motion,
};

pub const Candidate = struct {
    types: []const ActionType,
    comp: Composition,
};

// ---- Sequence tables (match order matters) ----

const main_normal = [_]Candidate{
    .{ .types = &.{ .track_operator, .track_motion }, .comp = .track_op_motion },
    .{ .types = &.{ .track_operator, .track_selector }, .comp = .track_op_selector },
    .{ .types = &.{ .timeline_operator, .timeline_selector }, .comp = .timeline_op_selector },
    .{ .types = &.{ .timeline_operator, .timeline_motion }, .comp = .timeline_op_motion },
    .{ .types = &.{.timeline_motion}, .comp = .plain },
    .{ .types = &.{.track_motion}, .comp = .plain },
    .{ .types = &.{.command}, .comp = .plain },
};

const main_visual_track = [_]Candidate{
    .{ .types = &.{.visual_track_command}, .comp = .plain },
    .{ .types = &.{.track_operator}, .comp = .visual_track_operator },
    .{ .types = &.{.track_selector}, .comp = .plain },
    .{ .types = &.{.track_motion}, .comp = .visual_track_motion_extend },
    .{ .types = &.{.timeline_motion}, .comp = .visual_track_timeline_motion },
    .{ .types = &.{.command}, .comp = .plain },
};

const main_visual_timeline = [_]Candidate{
    .{ .types = &.{.visual_timeline_command}, .comp = .plain },
    .{ .types = &.{.timeline_operator}, .comp = .visual_timeline_operator },
    .{ .types = &.{.timeline_selector}, .comp = .plain },
    .{ .types = &.{.timeline_motion}, .comp = .visual_timeline_motion_extend },
    .{ .types = &.{.track_motion}, .comp = .plain },
    .{ .types = &.{.command}, .comp = .plain },
};

const midi_normal = [_]Candidate{
    .{ .types = &.{ .timeline_operator, .timeline_selector }, .comp = .timeline_op_selector },
    .{ .types = &.{ .timeline_operator, .timeline_motion }, .comp = .timeline_op_motion },
    .{ .types = &.{.timeline_motion}, .comp = .plain },
    .{ .types = &.{.command}, .comp = .plain },
};

const midi_visual_timeline = [_]Candidate{
    .{ .types = &.{.visual_timeline_command}, .comp = .plain },
    .{ .types = &.{.timeline_operator}, .comp = .visual_timeline_operator },
    .{ .types = &.{.timeline_selector}, .comp = .plain },
    .{ .types = &.{.timeline_motion}, .comp = .visual_timeline_motion_extend },
    .{ .types = &.{.command}, .comp = .plain },
};

const midi_visual_track = [_]Candidate{
    .{ .types = &.{.command}, .comp = .plain },
};

pub fn candidatesFor(ctx: Context, mode: Mode) []const Candidate {
    return switch (ctx) {
        .main => switch (mode) {
            .normal => &main_normal,
            .visual_track => &main_visual_track,
            .visual_timeline => &main_visual_timeline,
        },
        .midi => switch (mode) {
            .normal => &midi_normal,
            .visual_track => &midi_visual_track,
            .visual_timeline => &midi_visual_timeline,
        },
    };
}

/// Config knobs (reavim definitions/config.lua values, hardcoded for now).
pub const cfg = struct {
    pub const persist_visual_timeline_selection = true;
    pub const persist_visual_track_selection = false;
    pub const allow_visual_track_timeline_movement = true;
};

test "sequence tables are wired" {
    try std.testing.expectEqual(@as(usize, 7), candidatesFor(.main, .normal).len);
    try std.testing.expectEqual(@as(usize, 4), candidatesFor(.midi, .normal).len);
    try std.testing.expectEqual(Composition.track_op_motion, candidatesFor(.main, .normal)[0].comp);
}
