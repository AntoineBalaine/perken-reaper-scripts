//! Native mode/state actions (port of reavim internal/library/state.lua) and
//! the engine builtins reachable from bindings as @insert/@normal/@off/@clear.
const std = @import("std");
const builtin = @import("builtin");
const Reaper = @import("reaper").reaper;
const actions = @import("actions.zig");
const state = @import("state.zig");
const win_file = @import("win_file.zig");

const log = std.log.scoped(.engine);

/// The built-in default bindings, also written out the first time the user
/// opens the bindings file for editing.
pub const default_bindings = @embedFile("default_bindings.ini");

/// Open the user bindings file in the OS default editor, creating it from the
/// embedded defaults first if it does not exist yet. Reachable both as the
/// "EditBindings" binding action and the REAPER "ReaVim: Edit bindings" action.
pub fn editBindings() void {
    const io = state.io();
    const resource = std.mem.span(Reaper.GetResourcePath());
    var dbuf: [std.fs.max_path_bytes]u8 = undefined;
    const dir = std.fmt.bufPrint(&dbuf, "{s}/Data/Perken", .{resource}) catch return;
    var pbuf: [std.fs.max_path_bytes]u8 = undefined;
    const path = std.fmt.bufPrint(&pbuf, "{s}/Data/Perken/bindings.ini", .{resource}) catch return;

    // See main.zig's loadBindings for why std.fs's *Absolute calls are
    // avoided on Windows (stack overflow at REAPER's call depth).
    if (builtin.os.tag == .windows) {
        _ = win_file.makeDir(dir);
        if (!win_file.exists(path)) {
            _ = win_file.writeFile(path, default_bindings);
        }
    } else {
        std.Io.Dir.createDirAbsolute(io, dir, .default_dir) catch {};
        std.Io.Dir.accessAbsolute(io, path, .{}) catch {
            const f = std.Io.Dir.createFileAbsolute(io, path, .{}) catch return;
            defer f.close(io);
            f.writeStreamingAll(io, default_bindings) catch {};
        };
    }
    const argv: []const []const u8 = switch (builtin.os.tag) {
        .macos => &.{ "open", path },
        .windows => &.{ "cmd", "/c", "start", "", path },
        else => &.{ "xdg-open", path },
    };
    var child = std.process.spawn(io, .{ .argv = argv }) catch |err| {
        log.warn("could not open bindings editor: {s}", .{@errorName(err)});
        return;
    };
    _ = child.wait(io) catch {};
}

fn editBindingsAction(_: *actions.RunCtx) void {
    editBindings();
}

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

/// Index of the last-touched track: the active end of a track selection.
fn lastTouchedIndex() ?c_int {
    const tr = Reaper.GetLastTouchedTrack() orelse return null;
    const num = Reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER");
    if (num <= 0) return null;
    return @as(c_int, @intFromFloat(num)) - 1;
}

/// Whether exactly the tracks between `anchor` and `active` (inclusive, in
/// either order) are selected.
fn selectionIsRange(anchor: c_int, active: c_int) bool {
    const lo = @min(anchor, active);
    const hi = @max(anchor, active);
    if (Reaper.CountSelectedTracks(null) != hi - lo + 1) return false;
    var i = lo;
    while (i <= hi) : (i += 1) {
        const tr = Reaper.GetTrack(null, i) orelse return false;
        if (Reaper.GetMediaTrackInfo_Value(tr, "I_SELECTED") == 0) return false;
    }
    return true;
}

/// The track one step from `active` in `direction`, or null at either end of
/// the project.
fn stepTarget(active: c_int, direction: c_int, track_count: c_int) ?c_int {
    const target = active + direction;
    if (target < 0 or target >= track_count) return null;
    return target;
}

/// Moves the active end of the track selection one track in `direction`,
/// keeping the anchor where it is: moving away from the anchor adds a track
/// and moving back toward it removes one, as Shift+arrow does in a text
/// selection. Because the anchor is only trusted while the selection is
/// exactly the range between it and the active end, any other way of
/// selecting tracks (j, k, a click) starts a new selection at the active
/// track. Inside visual track mode the mode's pivot is the anchor.
fn extendTrackSelection(direction: c_int) void {
    const active = lastTouchedIndex() orelse return;
    var anchor = if (state.mode == .visual_track)
        state.visual_track_pivot
    else
        state.track_anchor orelse active;
    if (!selectionIsRange(anchor, active)) anchor = active;
    state.track_anchor = anchor;

    _ = stepTarget(active, direction, Reaper.CountTracks(null)) orelse return;

    // Because REAPER's own "go to next/previous track" is what moves the
    // last-touched track (the active end) everywhere else in this extension,
    // we use it here too, then rebuild the range around it.
    Reaper.Main_OnCommand(if (direction > 0) 40285 else 40286, 0);
    const new_active = lastTouchedIndex() orelse return;

    const count = Reaper.CountTracks(null);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        const tr = Reaper.GetTrack(null, i) orelse continue;
        const inside = i >= @min(anchor, new_active) and i <= @max(anchor, new_active);
        Reaper.SetTrackSelected(tr, inside);
    }
}

fn extendTrackSelectionUp(rctx: *actions.RunCtx) void {
    _ = rctx;
    extendTrackSelection(-1);
}

fn extendTrackSelectionDown(rctx: *actions.RunCtx) void {
    _ = rctx;
    extendTrackSelection(1);
}

test "stepTarget stops at both ends of the project" {
    try std.testing.expectEqual(@as(?c_int, 3), stepTarget(2, 1, 5));
    try std.testing.expectEqual(@as(?c_int, 1), stepTarget(2, -1, 5));
    try std.testing.expectEqual(@as(?c_int, null), stepTarget(4, 1, 5));
    try std.testing.expectEqual(@as(?c_int, null), stepTarget(0, -1, 5));
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
    .{ .name = "ExtendTrackSelectionUp", .def = .{ .steps = &.{.{ .func = &extendTrackSelectionUp }}, .prefix_repetition_count = true, .desc = "Extend track selection up" } },
    .{ .name = "ExtendTrackSelectionDown", .def = .{ .steps = &.{.{ .func = &extendTrackSelectionDown }}, .prefix_repetition_count = true, .desc = "Extend track selection down" } },
    .{ .name = "SwitchTimelineSelectionSide", .def = .{ .steps = &.{.{ .func = &switchTimelineSelectionSide }}, .desc = "Switch selection side" } },
    .{ .name = "EnterInsertMode", .def = builtin_defs.insert },
    .{ .name = "VimOff", .def = builtin_defs.off },
    .{ .name = "EditBindings", .def = .{ .steps = &.{.{ .func = &editBindingsAction }}, .desc = "Edit reavim bindings" } },
};
