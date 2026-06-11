//! Native port of reavim custom_actions/drums.lua — flam/ras/crescendo
//! native; quantizeTool stays a logging stub (SKIP per the port inventory:
//! it launches a user-local quantize ReaScript by its registered _RS command
//! id, which only exists on the original install).
const std = @import("std");
const Reaper = @import("reaper").reaper;
const actions = @import("../actions.zig");
const helpers = @import("helpers.zig");

const log = std.log.scoped(.engine);

// ---- ABI shims ---------------------------------------------------------------

/// AddMediaItemToTrack can return NULL; the binding types it non-optional.
fn addMediaItemToTrack(tp: *Reaper.MediaTrack) ?*Reaper.MediaItem {
    const f: *const fn (tr: *Reaper.MediaTrack) callconv(.C) ?*Reaper.MediaItem = @ptrCast(Reaper.AddMediaItemToTrack);
    return f(tp);
}

// ---- selected items per track (utils.getSelectedItemsInTrack) -----------------

/// Snapshot of the selected items on a track — a snapshot so the mutations
/// below (flam adds items to the track) cannot disturb the iteration, exactly
/// like the Lua's pre-collected list.
fn selectedItemsInTrack(alloc: std.mem.Allocator, tp: *Reaper.MediaTrack) ![]*Reaper.MediaItem {
    var list = std.ArrayList(*Reaper.MediaItem).init(alloc);
    errdefer list.deinit();
    const n = Reaper.GetTrackNumMediaItems(tp);
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        const item = Reaper.GetTrackMediaItem(tp, i);
        if (@intFromPtr(item) == 0) continue;
        if (!Reaper.IsMediaItemSelected(item)) continue;
        try list.append(item);
    }
    return list.toOwnedSlice();
}

// ---- chunk-based item copy (utils.CopyMediaItemToTrack) -----------------------

/// Remove every "{...}" group in place (Lua gsub("{.-}", "")) so REAPER
/// regenerates all GUIDs on SetItemStateChunk; returns the compacted slice.
/// An unmatched '{' is kept, like the non-greedy Lua pattern.
fn stripBracedGroups(s: []u8) []u8 {
    var w: usize = 0;
    var r: usize = 0;
    while (r < s.len) {
        if (s[r] == '{') {
            if (std.mem.indexOfScalarPos(u8, s, r, '}')) |close| {
                r = close + 1;
                continue;
            }
        }
        s[w] = s[r];
        w += 1;
        r += 1;
    }
    return s[0..w];
}

/// Item state chunks have no size-query API; this covers even chunky MIDI items.
const chunk_buf_len = 1 << 20;

/// utils.CopyMediaItemToTrack: clone `item` onto `track` at `position` via its
/// state chunk, GUIDs stripped so REAPER auto-generates fresh ones.
fn copyMediaItemToTrack(item: *Reaper.MediaItem, tp: *Reaper.MediaTrack, position: f64) ?*Reaper.MediaItem {
    const buf = helpers.allocator.alloc(u8, chunk_buf_len) catch return null;
    defer helpers.allocator.free(buf);
    buf[0] = 0;
    if (!Reaper.GetItemStateChunk(item, @ptrCast(buf.ptr), @intCast(buf.len), false)) return null;
    const stripped = stripBracedGroups(std.mem.sliceTo(buf, 0));
    buf[stripped.len] = 0; // safe: stripped.len < buf.len (terminator excluded)

    const new_item = addMediaItemToTrack(tp) orelse return null;
    Reaper.PreventUIRefresh(1);
    _ = Reaper.SetItemStateChunk(new_item, @ptrCast(buf.ptr), false);
    _ = Reaper.SetMediaItemInfo_Value(new_item, "D_POSITION", position);
    Reaper.PreventUIRefresh(-1);
    return new_item;
}

/// utils.nudgeItemVolume: scale D_VOL by `db` decibels.
fn nudgeItemVolume(item: *Reaper.MediaItem, db: f64) void {
    const vol = Reaper.GetMediaItemInfo_Value(item, "D_VOL");
    _ = Reaper.SetMediaItemInfo_Value(item, "D_VOL", vol * std.math.pow(f64, 10.0, 0.05 * db));
    Reaper.UpdateItemInProject(item);
}

// ---- flams / ruffs --------------------------------------------------------------

/// drums.lua CreateFlams: temporarily shorten the item to the flam length,
/// copy it `reps` times before the downbeat with decreasing volume/pitch and
/// short fades, then restore the original length.
fn createFlams(item: *Reaper.MediaItem, tp: *Reaper.MediaTrack, reps: u32) void {
    var flam_length: f64 = 0.04; // 40 ms
    var fade_in: f64 = 0.01;
    if (reps > 1) { // tighter spacing/fades for ruffs
        flam_length = 0.035;
        fade_in = 0.006;
    }
    var nudge_db: f64 = -16;
    var pitch: f64 = -0.5;

    const item_pos = Reaper.GetMediaItemInfo_Value(item, "D_POSITION");
    const item_len = Reaper.GetMediaItemInfo_Value(item, "D_LENGTH");
    _ = Reaper.SetMediaItemInfo_Value(item, "D_LENGTH", flam_length);

    var flam_pos = item_pos - flam_length;
    var r: u32 = 0;
    while (r < reps) : (r += 1) {
        const new_item = copyMediaItemToTrack(item, tp, flam_pos) orelse break;
        nudgeItemVolume(new_item, nudge_db);
        _ = Reaper.SetMediaItemInfo_Value(new_item, "D_FADEINLEN", fade_in);
        _ = Reaper.SetMediaItemInfo_Value(new_item, "D_FADEOUTLEN", 0.001);
        // FIXED vs lua: guard the take — an item without takes crashed there.
        if (helpers.getActiveTake(new_item)) |take|
            _ = Reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH", pitch);
        flam_pos -= flam_length;
        pitch -= 0.15;
        nudge_db -= 3;
    }

    _ = Reaper.SetMediaItemInfo_Value(item, "D_LENGTH", item_len);
}

/// utils.cycleSelectedItemsInSelectedTracks(CreateFlams ...).
fn flamSelectedItems(reps: u32) void {
    const n_tracks = Reaper.CountSelectedTracks(0);
    var i: c_int = 0;
    while (i < n_tracks) : (i += 1) {
        const track = Reaper.GetSelectedTrack(0, i) orelse continue;
        const tp = helpers.trackPtr(track) orelse continue;
        const items = selectedItemsInTrack(helpers.allocator, tp) catch return;
        defer helpers.allocator.free(items);
        for (items) |item| createFlams(item, tp, reps);
    }
}

fn flam(_: *actions.RunCtx) void {
    flamSelectedItems(1);
}

fn ras3(_: *actions.RunCtx) void {
    flamSelectedItems(2);
}

fn ras5(_: *actions.RunCtx) void {
    flamSelectedItems(4);
}

// ---- crescendo / decrescendo ------------------------------------------------------

const Ramp = enum { crescendo, decrescendo };

/// CrescendoTrackSelectedItems / DecrescendoTrackSelectedItems: ramp item
/// volumes and take pitches across the selected items of one track, anchored
/// at the last (crescendo) or first (decrescendo) item's volume.
fn rampTrackItems(tp: *Reaper.MediaTrack, ramp: Ramp) void {
    const items = selectedItemsInTrack(helpers.allocator, tp) catch return;
    defer helpers.allocator.free(items);
    // FIXED vs lua: no selected items indexed a nil item there.
    if (items.len == 0) return;

    const count: f64 = @floatFromInt(items.len);
    const anchor_item = switch (ramp) {
        .crescendo => items[items.len - 1],
        .decrescendo => items[0],
    };
    const anchor_vol = Reaper.GetMediaItemInfo_Value(anchor_item, "D_VOL");

    var diminution: f64 = 0.1;
    const increment = (anchor_vol - diminution) / count;
    var pitch: f64 = switch (ramp) {
        .crescendo => -0.15 * count,
        .decrescendo => -0.01 * count,
    };
    const pitch_step: f64 = switch (ramp) {
        .crescendo => 0.15,
        .decrescendo => 0.05,
    };

    var k: usize = 0;
    while (k < items.len) : (k += 1) {
        // crescendo walks the items back-to-front, decrescendo front-to-back.
        const item = switch (ramp) {
            .crescendo => items[items.len - 1 - k],
            .decrescendo => items[k],
        };
        _ = Reaper.SetMediaItemInfo_Value(item, "D_VOL", anchor_vol - diminution);
        // FIXED vs lua: take guarded, as in createFlams.
        if (helpers.getActiveTake(item)) |take|
            _ = Reaper.SetMediaItemTakeInfo_Value(take, "D_PITCH", pitch);
        diminution += increment;
        pitch -= pitch_step;
    }
}

fn rampSelectedTracks(ramp: Ramp) void {
    const n_tracks = Reaper.CountSelectedTracks(0);
    var i: c_int = 0;
    while (i < n_tracks) : (i += 1) {
        const track = Reaper.GetSelectedTrack(0, i) orelse continue;
        const tp = helpers.trackPtr(track) orelse continue;
        rampTrackItems(tp, ramp);
    }
}

fn crescendo(_: *actions.RunCtx) void {
    rampSelectedTracks(.crescendo);
}

fn decrescendo(_: *actions.RunCtx) void {
    rampSelectedTracks(.decrescendo);
}

// ---- quantize tool (stub) -----------------------------------------------------

// SKIP: launches a user-local quantize ReaScript via its hardcoded _RS
// command id (_RS61423f4f1224e18018576b5e3e1af80ebbd67f7e) which is not
// registered outside the original install.
fn quantizeTool(_: *actions.RunCtx) void {
    log.warn("'QuantizeTool' not ported — it launches a user-local quantize ReaScript by a hardcoded _RS command id", .{});
}

// ---- registry entries -------------------------------------------------------------

pub const entries = [_]actions.Entry{
    .{ .name = "Flam", .def = .{ .steps = &.{.{ .func = &flam }} } },
    .{ .name = "Ras3", .def = .{ .steps = &.{.{ .func = &ras3 }} } },
    .{ .name = "Ras5", .def = .{ .steps = &.{.{ .func = &ras5 }} } },
    .{ .name = "Crescendo", .def = .{ .steps = &.{.{ .func = &crescendo }} } },
    .{ .name = "Decrescendo", .def = .{ .steps = &.{.{ .func = &decrescendo }} } },
    .{ .name = "QuantizeTool", .def = .{ .steps = &.{.{ .func = &quantizeTool }} } },
};

// ---- tests ------------------------------------------------------------------

test "stripBracedGroups removes GUID groups, keeps unmatched braces" {
    var buf1 = "IGUID {1234-ABCD}\nGUID {X}\nNAME hat".*;
    try std.testing.expectEqualStrings("IGUID \nGUID \nNAME hat", stripBracedGroups(&buf1));

    var buf2 = "no braces at all".*;
    try std.testing.expectEqualStrings("no braces at all", stripBracedGroups(&buf2));

    var buf3 = "dangling {open brace".*;
    try std.testing.expectEqualStrings("dangling {open brace", stripBracedGroups(&buf3));

    var buf4 = "a{1}{2}b".*;
    try std.testing.expectEqualStrings("ab", stripBracedGroups(&buf4));
}

test {
    _ = helpers;
}
