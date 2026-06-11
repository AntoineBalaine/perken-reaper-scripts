//! Native port of reavim custom_actions/movement.lua (all 22 functions).
//! Action names and flags mirror definitions/extended_defaults/actions.lua.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const actions = @import("../actions.zig");
const helpers = @import("helpers.zig");

// ---- project edges ----------------------------------------------------------

fn projectStart(_: *actions.RunCtx) void {
    Reaper.SetEditCurPos(0, true, false);
}

fn projectEnd(_: *actions.RunCtx) void {
    Reaper.SetEditCurPos(helpers.getProjectLength(), true, false);
}

// ---- first/last item on selected tracks --------------------------------------

fn lastItemEnd(_: *actions.RunCtx) void {
    const items = helpers.getBigItemPositionsOnSelectedTracks(helpers.allocator) catch return;
    defer helpers.allocator.free(items);
    if (items.len > 0)
        Reaper.SetEditCurPos(items[items.len - 1].right, true, false);
}

fn firstItemStart(_: *actions.RunCtx) void {
    const items = helpers.getBigItemPositionsOnSelectedTracks(helpers.allocator) catch return;
    defer helpers.allocator.free(items);
    if (items.len > 0)
        Reaper.SetEditCurPos(items[0].left, true, false);
}

// ---- MIDI take bounds (movement.midi.takeStart/takeEnd) ----------------------

fn midiTakeItem() ?*Reaper.MediaItem {
    const editor = helpers.midiEditorActive() orelse return null;
    const take = helpers.midiEditorTake(editor) orelse return null;
    const item = Reaper.GetMediaItemTake_Item(take);
    if (@intFromPtr(item) == 0) return null;
    return item;
}

fn midiTakeStart(_: *actions.RunCtx) void {
    const item = midiTakeItem() orelse return;
    Reaper.SetEditCurPos(Reaper.GetMediaItemInfo_Value(item, "D_POSITION"), true, false);
}

fn midiTakeEnd(_: *actions.RunCtx) void {
    const item = midiTakeItem() orelse return;
    const pos = Reaper.GetMediaItemInfo_Value(item, "D_POSITION");
    const len = Reaper.GetMediaItemInfo_Value(item, "D_LENGTH");
    Reaper.SetEditCurPos(pos + len, true, false);
}

// ---- item-edge jumps ----------------------------------------------------------

const Span = enum { all, big };

fn itemPositions(span: Span) ?[]helpers.ItemPosition {
    const res = switch (span) {
        .all => helpers.getItemPositionsOnSelectedTracks(helpers.allocator),
        .big => helpers.getBigItemPositionsOnSelectedTracks(helpers.allocator),
    };
    return res catch null;
}

fn moveToPrevItemStart(items: []const helpers.ItemPosition) void {
    const cur = Reaper.GetCursorPosition();
    var next: ?f64 = null;
    for (items, 0..) |item, i| {
        if (next == null and item.left < cur and item.right >= cur)
            next = item.left;
        if (next != null and item.left > next.? and item.right >= next.?)
            next = item.left;
        if (i + 1 >= items.len or items[i + 1].left >= cur) {
            next = item.left;
            break;
        }
    }
    if (next) |pos| Reaper.SetEditCurPos(pos, true, false);
}

fn prevBigItemStart(_: *actions.RunCtx) void {
    const items = itemPositions(.big) orelse return;
    defer helpers.allocator.free(items);
    moveToPrevItemStart(items);
}

fn prevItemStart(_: *actions.RunCtx) void {
    const items = itemPositions(.all) orelse return;
    defer helpers.allocator.free(items);
    moveToPrevItemStart(items);
}

fn moveToNextItemStart(items: []const helpers.ItemPosition) void {
    const cur = Reaper.GetCursorPosition();
    var next: ?f64 = null;
    for (items) |item| {
        if (next == null and cur < item.left)
            next = item.left;
        if (next != null and item.left < next.?)
            next = item.left;
    }
    if (next) |pos| Reaper.SetEditCurPos(pos, true, false);
}

fn nextBigItemStart(_: *actions.RunCtx) void {
    const items = itemPositions(.big) orelse return;
    defer helpers.allocator.free(items);
    moveToNextItemStart(items);
}

fn nextItemStart(_: *actions.RunCtx) void {
    const items = itemPositions(.all) orelse return;
    defer helpers.allocator.free(items);
    moveToNextItemStart(items);
}

fn moveToNextItemEnd(items: []const helpers.ItemPosition) void {
    const cur = Reaper.GetCursorPosition();
    const tolerance = 0.002;
    var next: ?f64 = null;
    for (items) |item| {
        if (next == null and item.right - tolerance > cur) {
            next = item.right;
        } else if (next != null and item.right < next.? and item.right > cur) {
            next = item.right;
        }
    }
    if (next) |pos| Reaper.SetEditCurPos(pos, true, false);
}

fn nextBigItemEnd(_: *actions.RunCtx) void {
    const items = itemPositions(.big) orelse return;
    defer helpers.allocator.free(items);
    moveToNextItemEnd(items);
}

fn nextItemEnd(_: *actions.RunCtx) void {
    const items = itemPositions(.all) orelse return;
    defer helpers.allocator.free(items);
    moveToNextItemEnd(items);
}

// ---- track selection moves ----------------------------------------------------

fn firstTrack(_: *actions.RunCtx) void {
    const track = Reaper.GetTrack(0, 0) orelse return;
    Reaper.SetOnlyTrackSelected(track);
}

fn lastTrack(_: *actions.RunCtx) void {
    const track = Reaper.GetTrack(0, Reaper.GetNumTracks() - 1) orelse return;
    Reaper.SetOnlyTrackSelected(track);
}

fn trackWithNumber(_: *actions.RunCtx) void {
    var buf: [64]u8 = undefined;
    const reply = helpers.getUserInput("Match Forward", "Track Number", &buf) orelse return;
    const number = std.fmt.parseFloat(f64, reply) catch return;
    if (!std.math.isFinite(number) or number < 1 or number > 1e9) return;
    const track = Reaper.GetTrack(0, @as(c_int, @intFromFloat(number)) - 1) orelse return;
    Reaper.SetOnlyTrackSelected(track);
}

fn firstTrackWithItem(_: *actions.RunCtx) void {
    const n = Reaper.GetNumTracks();
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        const track = Reaper.GetTrack(0, i) orelse continue;
        const tp = helpers.trackPtr(track) orelse continue;
        if (Reaper.GetTrackNumMediaItems(tp) > 0) {
            Reaper.SetOnlyTrackSelected(track);
            return;
        }
    }
}

// ---- cursor utilities -----------------------------------------------------------

fn snap(_: *actions.RunCtx) void {
    const pos = Reaper.GetCursorPosition();
    Reaper.SetEditCurPos(Reaper.SnapToGrid(0, pos), false, false);
}

fn storeCursorPosition(_: *actions.RunCtx) void {
    helpers.pushCursorPosition(Reaper.GetCursorPosition());
}

fn restoreCursorPosition(_: *actions.RunCtx) void {
    if (helpers.popCursorPosition()) |pos|
        Reaper.SetEditCurPos(pos, true, false);
}

fn jumpToBarNumber(_: *actions.RunCtx) void {
    var buf: [64]u8 = undefined;
    const reply = helpers.getUserInput("Jump to bar number", "Bar number", &buf) orelse return;
    // Lua tonumber'd without a nil check and errored on garbage; bail instead.
    const bar = std.fmt.parseFloat(f64, reply) catch return;
    if (!std.math.isFinite(bar) or bar < -1e9 or bar > 1e9) return;
    const target = helpers.timeMap2BeatsToTime(0, @as(c_int, @intFromFloat(bar)) - 1);
    Reaper.MoveEditCursor(target - Reaper.GetCursorPosition(), false);
}

// ---- move selected items across tracks ------------------------------------------

const Direction = enum { up, down };

fn moveItem(direction: Direction) void {
    const n = helpers.countSelectedMediaItems();
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        const item = helpers.getSelectedMediaItem(i) orelse continue;
        const track_ptr = Reaper.GetMediaItem_Track(item);
        if (@intFromPtr(track_ptr) == 0) continue;
        const tracknumber = Reaper.GetMediaTrackInfo_Value(helpers.trackHandle(track_ptr), "IP_TRACKNUMBER");
        const index = helpers.getTrackIndex(tracknumber) orelse continue;
        const dest_index = switch (direction) {
            .up => index - 1,
            .down => index + 1,
        };
        // FIXED vs lua: no bounds check at the first/last track — GetTrack
        // returned nil and MoveMediaItemToTrack(item, nil) errored at runtime.
        const dest = Reaper.GetTrack(0, dest_index) orelse continue;
        _ = Reaper.MoveMediaItemToTrack(item, helpers.trackPtr(dest).?);
        Reaper.SetOnlyTrackSelected(dest);
    }
}

fn moveItemUp(_: *actions.RunCtx) void {
    moveItem(.up);
}

fn moveItemDown(_: *actions.RunCtx) void {
    moveItem(.down);
}

// ---- registry entries -------------------------------------------------------------
// FirstTrack/LastTrack are the multi-actions from extended_defaults/actions.lua
// ({ func, "ScrollToSelectedTracks" }) that were skipped because they reference
// these funcs.

pub const entries = [_]actions.Entry{
    .{ .name = "ProjectStart", .def = .{ .steps = &.{.{ .func = &projectStart }} } },
    .{ .name = "ProjectEnd", .def = .{ .steps = &.{.{ .func = &projectEnd }} } },
    .{ .name = "LastItemEnd", .def = .{ .steps = &.{.{ .func = &lastItemEnd }} } },
    .{ .name = "FirstItemStart", .def = .{ .steps = &.{.{ .func = &firstItemStart }} } },
    .{ .name = "MidiItemStart", .def = .{ .steps = &.{.{ .func = &midiTakeStart }}, .midi_command = true } },
    .{ .name = "MidiItemEnd", .def = .{ .steps = &.{.{ .func = &midiTakeEnd }}, .midi_command = true } },
    .{ .name = "PrevBigItemStart", .def = .{ .steps = &.{.{ .func = &prevBigItemStart }}, .prefix_repetition_count = true } },
    .{ .name = "PrevItemStart", .def = .{ .steps = &.{.{ .func = &prevItemStart }}, .prefix_repetition_count = true } },
    .{ .name = "NextBigItemStart", .def = .{ .steps = &.{.{ .func = &nextBigItemStart }}, .prefix_repetition_count = true } },
    .{ .name = "NextItemStart", .def = .{ .steps = &.{.{ .func = &nextItemStart }}, .prefix_repetition_count = true } },
    .{ .name = "NextBigItemEnd", .def = .{ .steps = &.{.{ .func = &nextBigItemEnd }}, .prefix_repetition_count = true } },
    .{ .name = "NextItemEnd", .def = .{ .steps = &.{.{ .func = &nextItemEnd }}, .prefix_repetition_count = true } },
    .{ .name = "FirstTrack", .def = .{ .steps = &.{ .{ .func = &firstTrack }, .{ .action = "ScrollToSelectedTracks" } } } },
    .{ .name = "LastTrack", .def = .{ .steps = &.{ .{ .func = &lastTrack }, .{ .action = "ScrollToSelectedTracks" } } } },
    .{ .name = "TrackWithNumber", .def = .{ .steps = &.{.{ .func = &trackWithNumber }} } },
    .{ .name = "FirstTrackWithItem", .def = .{ .steps = &.{.{ .func = &firstTrackWithItem }} } },
    .{ .name = "SnappedPosition", .def = .{ .steps = &.{.{ .func = &snap }} } },
    .{ .name = "StoreCursorPosition", .def = .{ .steps = &.{.{ .func = &storeCursorPosition }}, .prefix_repetition_count = true } },
    .{ .name = "RestoreCursorPosition", .def = .{ .steps = &.{.{ .func = &restoreCursorPosition }}, .prefix_repetition_count = true } },
    .{ .name = "jumpToBar", .def = .{ .steps = &.{.{ .func = &jumpToBarNumber }}, .midi_command = true } },
    .{ .name = "MoveItemUp", .def = .{ .steps = &.{.{ .func = &moveItemUp }}, .prefix_repetition_count = true } },
    .{ .name = "MoveItemDown", .def = .{ .steps = &.{.{ .func = &moveItemDown }}, .prefix_repetition_count = true } },
};

test {
    _ = helpers;
}
