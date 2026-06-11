//! Native mode/state actions (port of reavim internal/library/state.lua) and
//! the engine builtins reachable from bindings as @insert/@normal/@off/@clear.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const actions = @import("actions.zig");
const state = @import("state.zig");

const log = std.log.scoped(.engine);

fn setModeNormal(_: *actions.RunCtx) void {
    state.setModeToNormal();
    log.info("mode: normal", .{});
}

fn setModeVisualTrack(_: *actions.RunCtx) void {
    const tr = Reaper.GetLastTouchedTrack() orelse return;
    Reaper.SetOnlyTrackSelected(tr);
    const num = Reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER");
    state.visual_track_pivot = if (num > 0) @as(c_int, @intFromFloat(num)) - 1 else 0;
    state.mode = .visual_track;
    log.info("mode: visual_track (pivot {d})", .{state.visual_track_pivot});
}

fn setModeVisualTimeline(_: *actions.RunCtx) void {
    state.mode = .visual_timeline;
    Reaper.Main_OnCommand(40625, 0); // Time selection: set start point
    log.info("mode: visual_timeline", .{});
}

fn switchTimelineSelectionSide(_: *actions.RunCtx) void {
    switch (state.timeline_side) {
        .right => {
            Reaper.Main_OnCommand(40630, 0); // go to start of time selection
            state.timeline_side = .left;
        },
        .left => {
            Reaper.Main_OnCommand(40631, 0); // go to end of time selection
            state.timeline_side = .right;
        },
    }
}

fn enterInsert(_: *actions.RunCtx) void {
    state.mode = .insert;
    log.info("mode: insert (native bindings active)", .{});
}

fn vimOff(_: *actions.RunCtx) void {
    state.mode = .off;
    log.info("vim mode: off", .{});
}

fn noOp(_: *actions.RunCtx) void {}

/// Static defs for the @builtin binding values.
pub const builtin_defs = struct {
    pub const insert = actions.ActionDef{ .steps = &.{.{ .func = &enterInsert }}, .desc = "Enter insert mode" };
    pub const normal = actions.ActionDef{ .steps = &.{.{ .func = &setModeNormal }}, .desc = "Enter normal mode" };
    pub const off = actions.ActionDef{ .steps = &.{.{ .func = &vimOff }}, .desc = "Turn vim mode off" };
    pub const clear = actions.ActionDef{ .steps = &.{.{ .func = &noOp }}, .desc = "Clear pending keys" };
};

pub const entries = [_]actions.Entry{
    .{ .name = "SetModeNormal", .def = builtin_defs.normal },
    .{ .name = "SetModeVisualTrack", .def = .{ .steps = &.{.{ .func = &setModeVisualTrack }}, .desc = "Visual track mode" } },
    .{ .name = "SetModeVisualTimeline", .def = .{ .steps = &.{.{ .func = &setModeVisualTimeline }}, .desc = "Visual timeline mode" } },
    .{ .name = "SwitchTimelineSelectionSide", .def = .{ .steps = &.{.{ .func = &switchTimelineSelectionSide }}, .desc = "Switch selection side" } },
    .{ .name = "EnterInsertMode", .def = builtin_defs.insert },
    .{ .name = "VimOff", .def = builtin_defs.off },
};
