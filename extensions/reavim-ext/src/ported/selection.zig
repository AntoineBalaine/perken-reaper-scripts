//! Native port of reavim custom_actions/selection.lua (all 5 functions).
//! Action names mirror definitions/extended_defaults/actions.lua.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const actions = @import("../actions.zig");
const helpers = @import("helpers.zig");

fn innerProjectTimeline(_: *actions.RunCtx) void {
    helpers.setTimeSelection(0, helpers.getProjectLength());
}

/// Backwards scan shared by innerItem/innerBigItem: select the last span in
/// list order that contains the edit cursor.
fn selectSpanUnderCursor(items: []const helpers.ItemPosition) void {
    const cur = Reaper.GetCursorPosition();
    var i = items.len;
    while (i > 0) {
        i -= 1;
        const item = items[i];
        if (item.left <= cur and item.right >= cur) {
            helpers.setTimeSelection(item.left, item.right);
            break;
        }
    }
}

fn innerItem(_: *actions.RunCtx) void {
    const items = helpers.getItemPositionsOnSelectedTracks(helpers.allocator) catch return;
    defer helpers.allocator.free(items);
    selectSpanUnderCursor(items);
}

fn innerBigItem(_: *actions.RunCtx) void {
    const items = helpers.getBigItemPositionsOnSelectedTracks(helpers.allocator) catch return;
    defer helpers.allocator.free(items);
    selectSpanUnderCursor(items);
}

fn onlyCurrentTrack(_: *actions.RunCtx) void {
    const track = Reaper.GetSelectedTrack(0, 0) orelse return;
    Reaper.SetOnlyTrackSelected(track);
}

fn innerRegion(_: *actions.RunCtx) void {
    const ids = helpers.getLastMarkerAndCurRegion(Reaper.GetCursorPosition());
    _ = helpers.selectRegion(ids.region);
}

pub const entries = [_]actions.Entry{
    .{ .name = "ProjectTimeline", .def = .{ .steps = &.{.{ .func = &innerProjectTimeline }} } },
    .{ .name = "Item", .def = .{ .steps = &.{.{ .func = &innerItem }} } },
    .{ .name = "BigItem", .def = .{ .steps = &.{.{ .func = &innerBigItem }} } },
    .{ .name = "SelectOnlyCurrentTrack", .def = .{ .steps = &.{.{ .func = &onlyCurrentTrack }} } },
    .{ .name = "Region", .def = .{ .steps = &.{.{ .func = &innerRegion }} } },
};

test {
    _ = helpers;
    _ = std;
}
