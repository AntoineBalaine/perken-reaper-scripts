//! Native mode/state actions (port of reavim internal/library/state.lua) and
//! the engine builtins reachable from bindings as @insert/@normal/@off/@clear.
const std = @import("std");
const builtin = @import("builtin");
const Reaper = @import("reaper").reaper;
const actions = @import("actions.zig");
const state = @import("state.zig");

const log = std.log.scoped(.engine);

/// The built-in default bindings, also written out the first time the user
/// opens the bindings file for editing.
pub const default_bindings = @embedFile("default_bindings.ini");

/// Open the user bindings file in the OS default editor, creating it from the
/// embedded defaults first if it does not exist yet. Reachable both as the
/// "EditBindings" binding action and the REAPER "ReaVim: Edit bindings" action.
pub fn editBindings() void {
    const resource = std.mem.span(Reaper.GetResourcePath());
    var dbuf: [std.fs.max_path_bytes]u8 = undefined;
    const dir = std.fmt.bufPrint(&dbuf, "{s}/Data/Perken", .{resource}) catch return;
    std.fs.makeDirAbsolute(dir) catch {};
    var pbuf: [std.fs.max_path_bytes]u8 = undefined;
    const path = std.fmt.bufPrint(&pbuf, "{s}/Data/Perken/bindings.ini", .{resource}) catch return;
    std.fs.accessAbsolute(path, .{}) catch {
        const f = std.fs.createFileAbsolute(path, .{}) catch return;
        defer f.close();
        f.writeAll(default_bindings) catch {};
    };
    const argv: []const []const u8 = switch (builtin.os.tag) {
        .macos => &.{ "open", path },
        .windows => &.{ "cmd", "/c", "start", "", path },
        else => &.{ "xdg-open", path },
    };
    var child = std.process.Child.init(argv, std.heap.c_allocator);
    child.spawn() catch |err| {
        log.warn("could not open bindings editor: {s}", .{@errorName(err)});
        return;
    };
    _ = child.wait() catch {};
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
    .{ .name = "EditBindings", .def = .{ .steps = &.{.{ .func = &editBindingsAction }}, .desc = "Edit reavim bindings" } },
};
