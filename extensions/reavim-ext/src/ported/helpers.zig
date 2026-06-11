//! Shared helpers for the ported custom_actions modules — the Zig port of the
//! parts of reavim's custom_actions/utils.lua (plus utils/reaper_state.lua)
//! that movement.zig and selection.zig need. MIDI/envelope/chunk helpers come
//! with later batches.
const std = @import("std");
const Reaper = @import("reaper").reaper;

const log = std.log.scoped(.engine);

/// Allocator for the short-lived per-action scratch lists.
pub const allocator = std.heap.c_allocator;

// ---- pointer-shape shims over the reaziglib bindings -----------------------
// reaziglib binds some ReaProject* parameters as non-optional *c_int, but
// REAPER expects NULL for "the current project". Re-typing the loaded function
// pointer with an optional project argument keeps the ABI identical (one
// pointer either way) while letting us pass null.

pub fn getProjectLength() f64 {
    const f: *const fn (proj: ?*Reaper.ReaProject) callconv(.C) f64 = @ptrCast(Reaper.GetProjectLength);
    return f(null);
}

pub fn countSelectedMediaItems() c_int {
    const f: *const fn (proj: ?*Reaper.ReaProject) callconv(.C) c_int = @ptrCast(Reaper.CountSelectedMediaItems);
    return f(null);
}

pub fn getSelectedMediaItem(i: c_int) ?*Reaper.MediaItem {
    const f: *const fn (proj: ?*Reaper.ReaProject, selitem: c_int) callconv(.C) ?*Reaper.MediaItem = @ptrCast(Reaper.GetSelectedMediaItem);
    return f(null, i);
}

pub const MarkerRegion = struct { marker: c_int, region: c_int };

pub fn getLastMarkerAndCurRegion(time: f64) MarkerRegion {
    const f: *const fn (proj: ?*Reaper.ReaProject, time: f64, markeridxOut: ?*c_int, regionidxOut: ?*c_int) callconv(.C) void = @ptrCast(Reaper.GetLastMarkerAndCurRegion);
    var marker: c_int = -1;
    var region: c_int = -1;
    f(null, time, &marker, &region);
    return .{ .marker = marker, .region = region };
}

pub fn timeMap2BeatsToTime(tpos: f64, measures: c_int) f64 {
    const f: *const fn (proj: ?*Reaper.ReaProject, tpos: f64, measuresIn: ?*const c_int) callconv(.C) f64 = @ptrCast(Reaper.TimeMap2_beatsToTime);
    return f(null, tpos, &measures);
}

/// MIDIEditor_GetActive returns NULL when no editor is open; the binding's
/// return type is non-optional, so re-type it.
pub fn midiEditorActive() ?Reaper.HWND {
    const f: *const fn () callconv(.C) ?Reaper.HWND = @ptrCast(Reaper.MIDIEditor_GetActive);
    return f();
}

pub fn midiEditorTake(editor: Reaper.HWND) ?*Reaper.MediaItem_Take {
    const f: *const fn (midieditor: Reaper.HWND) callconv(.C) ?*Reaper.MediaItem_Take = @ptrCast(Reaper.MIDIEditor_GetTake);
    return f(editor);
}

// reaziglib types some C MediaTrack* values as *MediaTrack (a pointer to the
// ?*opaque alias) and others as MediaTrack. The bits are the same single
// REAPER handle either way, so convert by re-typing the pointer — never by
// dereferencing it.

pub fn trackPtr(track: Reaper.MediaTrack) ?*Reaper.MediaTrack {
    return @ptrCast(@alignCast(track orelse return null));
}

pub fn trackHandle(ptr: *Reaper.MediaTrack) Reaper.MediaTrack {
    return @ptrCast(ptr);
}

// ---- commands ---------------------------------------------------------------

/// NamedCommandLookup + Main_OnCommand with a warning when the extension
/// providing the command (SWS, Xenakios, ...) is not installed.
pub fn runNamedCommand(name: [*:0]const u8) void {
    const id = Reaper.NamedCommandLookup(name);
    if (id == 0) {
        log.warn("named command not found: {s}", .{name});
        return;
    }
    Reaper.Main_OnCommand(id, 0);
}

// ---- track string properties (GetSetMediaTrackInfo_String) -------------------

/// Read a track string property ("P_NAME", "GUID", ...) into `buf`; returns
/// the slice into `buf`, or null on failure. `buf` must be large enough for
/// the property (REAPER's API carries no size — 512 covers names, 64 GUIDs).
pub fn getTrackString(track: Reaper.MediaTrack, parm: [*:0]const u8, buf: []u8) ?[]const u8 {
    const tp = trackPtr(track) orelse return null;
    buf[0] = 0;
    if (!Reaper.GetSetMediaTrackInfo_String(tp, parm, @ptrCast(buf.ptr), false))
        return null;
    return std.mem.sliceTo(buf, 0);
}

/// Write a track string property; values longer than 511 bytes are truncated.
pub fn setTrackString(track: Reaper.MediaTrack, parm: [*:0]const u8, value: []const u8) bool {
    const tp = trackPtr(track) orelse return false;
    var buf: [512]u8 = undefined;
    const n = @min(value.len, buf.len - 1);
    @memcpy(buf[0..n], value[0..n]);
    buf[n] = 0;
    return Reaper.GetSetMediaTrackInfo_String(tp, parm, @ptrCast(&buf), true);
}

// ---- time selection ---------------------------------------------------------

pub fn setTimeSelection(start: f64, end_: f64) void {
    var s = start;
    var e = end_;
    Reaper.GetSet_LoopTimeRange(true, false, &s, &e, false);
}

// ---- item position lists (utils.getItemPositionsOnSelectedTracks etc.) -----

pub const ItemPosition = struct { left: f64, right: f64 };

fn leftLessThan(_: void, a: ItemPosition, b: ItemPosition) bool {
    if (a.left == b.left) return a.right < b.right;
    return a.left < b.left;
}

/// All item spans on the selected tracks, sorted by left edge. Same result as
/// utils.lua's k-way mergeItemPositionsLists over per-track lists (per-track
/// item order is positional, so sorting the concatenation is equivalent).
/// FIXED vs lua: the selected-track loop in getItemPositionsOnSelectedTracks
/// ran 0..count writing GetSelectedTrack(0, i-1) — off by one that only
/// worked through Lua's 1-based `#`; indexed cleanly here.
pub fn getItemPositionsOnSelectedTracks(alloc: std.mem.Allocator) ![]ItemPosition {
    var list = std.ArrayList(ItemPosition).init(alloc);
    errdefer list.deinit();

    const n_tracks = Reaper.CountSelectedTracks(0);
    var i: c_int = 0;
    while (i < n_tracks) : (i += 1) {
        const track = Reaper.GetSelectedTrack(0, i) orelse continue;
        const tp = trackPtr(track) orelse continue;
        const n_items = Reaper.GetTrackNumMediaItems(tp);
        var j: c_int = 0;
        while (j < n_items) : (j += 1) {
            const item = Reaper.GetTrackMediaItem(tp, j);
            if (@intFromPtr(item) == 0) continue;
            const start = Reaper.GetMediaItemInfo_Value(item, "D_POSITION");
            const length = Reaper.GetMediaItemInfo_Value(item, "D_LENGTH");
            try list.append(.{ .left = start, .right = start + length });
        }
    }

    const slice = try list.toOwnedSlice();
    std.mem.sort(ItemPosition, slice, {}, leftLessThan);
    return slice;
}

/// Merge overlapping/contiguous spans into "big items" — the single pass from
/// utils.getBigItemPositionsOnSelectedTracks, split out so it is testable.
pub fn mergeBigItems(alloc: std.mem.Allocator, items: []const ItemPosition) ![]ItemPosition {
    var big = std.ArrayList(ItemPosition).init(alloc);
    errdefer big.deinit();
    if (items.len > 0) {
        try big.append(items[0]);
        for (items) |next| {
            const cur = &big.items[big.items.len - 1];
            if (next.left <= cur.right and next.right > cur.right)
                cur.right = next.right;
            if (next.left > cur.right)
                try big.append(next);
        }
    }
    return big.toOwnedSlice();
}

pub fn getBigItemPositionsOnSelectedTracks(alloc: std.mem.Allocator) ![]ItemPosition {
    const items = try getItemPositionsOnSelectedTracks(alloc);
    defer alloc.free(items);
    return mergeBigItems(alloc, items);
}

// ---- tracks -----------------------------------------------------------------

/// 0-based track index from an IP_TRACKNUMBER value (1-based; 0 = not found,
/// -1 = master). utils.getTrackIndex scanned every track comparing the float
/// (and its getTrackIdx twin skipped track 0 — off by one). FIXED vs lua:
/// the number minus one IS the index; no scan, and invalid numbers map to
/// null instead of selecting a wrong track.
pub fn getTrackIndex(tracknumber: f64) ?c_int {
    if (!std.math.isFinite(tracknumber) or tracknumber < 1) return null;
    return @as(c_int, @intFromFloat(tracknumber)) - 1;
}

// ---- regions ----------------------------------------------------------------

/// utils.selectRegion: set the time selection to region `id`'s bounds.
pub fn selectRegion(id: c_int) bool {
    // Real ABI of EnumProjectMarkers: nameOut is const char** (reaziglib types
    // it as a plain string ptr); re-type so we can pass null for unused outs.
    const f: *const fn (idx: c_int, isrgnOut: ?*bool, posOut: ?*f64, rgnendOut: ?*f64, nameOut: ?*[*:0]const u8, markrgnindexnumberOut: ?*c_int) callconv(.C) c_int = @ptrCast(Reaper.EnumProjectMarkers);
    var is_region = false;
    var start: f64 = 0;
    var end_: f64 = 0;
    _ = f(id, &is_region, &start, &end_, null, null);
    // Lua gated on `ok and is_region`, but ok (a number) is always truthy in
    // Lua — only is_region decides; mirrored here.
    if (is_region) {
        setTimeSelection(start, end_);
        return true;
    }
    return false;
}

// ---- cursor position stack (movement.store/restoreCursorPosition) ----------
// reaper_state.lua persisted a serpent-dumped Lua table in ExtState; we use a
// comma-separated f64 list under the same namespace/key. Store and restore
// are both ported, so the format change is invisible.

const ext_section = "reaper_keys";
const cursor_stack_key = "cursorPositionStack";
const stack_buf_len = 4096;

fn cursorStackString() []const u8 {
    const raw = Reaper.GetExtState(ext_section, cursor_stack_key);
    if (@intFromPtr(raw) == 0) return "";
    return std.mem.span(raw);
}

pub fn pushCursorPosition(pos: f64) void {
    var buf: [stack_buf_len:0]u8 = undefined;
    const old = cursorStackString();
    const printed = if (old.len == 0)
        std.fmt.bufPrintZ(&buf, "{d}", .{pos})
    else
        std.fmt.bufPrintZ(&buf, "{s},{d}", .{ old, pos });
    const new = printed catch {
        log.warn("cursorPositionStack full — position not stored", .{});
        return;
    };
    Reaper.SetExtState(ext_section, cursor_stack_key, new.ptr, true);
}

pub fn popCursorPosition() ?f64 {
    const cur = cursorStackString();
    if (cur.len == 0 or cur.len > stack_buf_len) return null;

    // Copy before writing back: SetExtState may invalidate GetExtState's buffer.
    var buf: [stack_buf_len:0]u8 = undefined;
    @memcpy(buf[0..cur.len], cur);
    const stack = buf[0..cur.len];

    const split = std.mem.lastIndexOfScalar(u8, stack, ',');
    const last = if (split) |s| stack[s + 1 ..] else stack;
    const pos = std.fmt.parseFloat(f64, last) catch {
        log.warn("cursorPositionStack: unparsable entry '{s}'", .{last});
        return null;
    };

    const rest_len = if (split) |s| s else 0;
    buf[rest_len] = 0;
    Reaper.SetExtState(ext_section, cursor_stack_key, buf[0..rest_len :0].ptr, true);
    return pos;
}

// ---- user input -------------------------------------------------------------

/// GetUserInputs with a single field; returns the trimmed reply, or null on
/// cancel. The returned slice points into `buf`.
pub fn getUserInput(title: [*:0]const u8, caption: [*:0]const u8, buf: []u8) ?[]const u8 {
    buf[0] = 0;
    if (!Reaper.GetUserInputs(title, 1, caption, @ptrCast(buf.ptr), @intCast(buf.len)))
        return null;
    return std.mem.trim(u8, std.mem.sliceTo(buf, 0), " \t\r\n");
}

// ---- tests ------------------------------------------------------------------

test "mergeBigItems merges overlapping and contained spans" {
    const items = [_]ItemPosition{
        .{ .left = 0, .right = 2 },
        .{ .left = 1, .right = 3 },
        .{ .left = 5, .right = 6 },
        .{ .left = 5.5, .right = 5.8 },
        .{ .left = 7, .right = 8 },
    };
    const big = try mergeBigItems(std.testing.allocator, &items);
    defer std.testing.allocator.free(big);
    try std.testing.expectEqualSlices(ItemPosition, &.{
        .{ .left = 0, .right = 3 },
        .{ .left = 5, .right = 6 },
        .{ .left = 7, .right = 8 },
    }, big);
}

test "mergeBigItems empty input" {
    const big = try mergeBigItems(std.testing.allocator, &.{});
    defer std.testing.allocator.free(big);
    try std.testing.expectEqual(@as(usize, 0), big.len);
}

test "getTrackIndex is the 1-based number minus one" {
    try std.testing.expectEqual(@as(?c_int, 4), getTrackIndex(5));
    try std.testing.expectEqual(@as(?c_int, 0), getTrackIndex(1));
    try std.testing.expectEqual(@as(?c_int, null), getTrackIndex(0)); // not found
    try std.testing.expectEqual(@as(?c_int, null), getTrackIndex(-1)); // master
}
