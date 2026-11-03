//! Native port of reavim custom_actions/items.lua (all 8 functions / 9 actions).
//! Action names and flags mirror definitions/extended_defaults/actions.lua.
//! paste_before is pure command choreography, so it stays a steps-only entry.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const actions = @import("actions.zig");
const timemap = @import("timemap.zig");
const helpers = @import("reaper_helpers");

// ---- ABI shims (reaziglib types these returns as non-optional) ---------------

const getActiveTake = helpers.getActiveTake;

fn getTake(item: *Reaper.MediaItem, takeidx: c_int) ?*Reaper.MediaItem_Take {
    const f: *const fn (item: *Reaper.MediaItem, takeidx: c_int) callconv(.c) ?*Reaper.MediaItem_Take = @ptrCast(Reaper.GetTake);
    return f(item, takeidx);
}

fn splitMediaItem(item: *Reaper.MediaItem, position: f64) ?*Reaper.MediaItem {
    const f: *const fn (item: *Reaper.MediaItem, position: f64) callconv(.c) ?*Reaper.MediaItem = @ptrCast(Reaper.SplitMediaItem);
    return f(item, position);
}

fn getTakeSource(take: *Reaper.MediaItem_Take) ?*Reaper.PCM_source {
    const f: *const fn (take: *Reaper.MediaItem_Take) callconv(.c) ?*Reaper.PCM_source = @ptrCast(Reaper.GetMediaItemTake_Source);
    return f(take);
}

/// Because the real ABI of EnumProjectMarkers takes a `const char **` for the
/// name, and reaziglib types it as a plain string pointer, we re-type it here
/// so that the unused outputs can be null.
fn enumProjectMarkers(idx: c_int, is_region: *bool, pos: *f64, number: *c_int) bool {
    const f: *const fn (idx: c_int, isrgnOut: ?*bool, posOut: ?*f64, rgnendOut: ?*f64, nameOut: ?*[*:0]const u8, markrgnindexnumberOut: ?*c_int) callconv(.c) c_int = @ptrCast(Reaper.EnumProjectMarkers);
    return f(idx, is_region, pos, null, null, number) != 0;
}

// ---- 2 ms fades on selected items in selected tracks --------------------------

fn set2msFades(_: *actions.RunCtx) void {
    const n_tracks = Reaper.CountSelectedTracks(null);
    var i: c_int = 0;
    while (i < n_tracks) : (i += 1) {
        const track = Reaper.GetSelectedTrack(null, i) orelse continue;
        const tp = helpers.trackPtr(track) orelse continue;
        const n_items = Reaper.GetTrackNumMediaItems(tp);
        var j: c_int = 0;
        while (j < n_items) : (j += 1) {
            const item = Reaper.GetTrackMediaItem(tp, j);
            if (@intFromPtr(item) == 0) continue;
            if (!Reaper.IsMediaItemSelected(item)) continue;
            _ = Reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", 0.002);
            _ = Reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", 0.002);
        }
    }
}

// ---- fade/trim the item under the mouse ----------------------------------------

const EditKind = enum { fade, trim };
const Edge = enum { left, right };

fn editItemFromMouse(kind: EditKind, edge: Edge) void {
    helpers.runNamedCommand("_XENAKIOS_DOSTORECURPOS"); // store edit cursor pos
    Reaper.Main_OnCommand(40514, 0); // move edit cursor to mouse cursor
    if (Reaper.GetToggleCommandStateEx(0, 1157) == 1) { // snap enabled?
        const snapped = Reaper.SnapToGrid(null, Reaper.GetCursorPosition());
        Reaper.MoveEditCursor(snapped - Reaper.GetCursorPosition(), false);
    }
    Reaper.Main_OnCommand(40528, 0); // select item under mouse cursor
    const cmd: c_int = switch (kind) {
        .fade => switch (edge) {
            .left => 40509, // fade item in to cursor
            .right => 40510, // fade item out from cursor
        },
        .trim => switch (edge) {
            .left => 41300, // trim left edge of item to edit cursor
            .right => 41310, // trim right edge of item to edit cursor
        },
    };
    Reaper.Main_OnCommand(cmd, 0);
    Reaper.Main_OnCommand(40289, 0); // unselect all items
    helpers.runNamedCommand("_XENAKIOS_DORECALLCURPOS"); // restore edit cursor pos
}

fn fadeItemInFromMouse(_: *actions.RunCtx) void {
    editItemFromMouse(.fade, .left);
}

fn fadeItemOutFromMouse(_: *actions.RunCtx) void {
    editItemFromMouse(.fade, .right);
}

fn trimRightEdgeFromMouse(_: *actions.RunCtx) void {
    editItemFromMouse(.trim, .right);
}

fn trimLeftEdgeFromMouse(_: *actions.RunCtx) void {
    editItemFromMouse(.trim, .left);
}

// ---- split selected items at every MIDI note start -----------------------------

fn splitItemsAtNoteStart(_: *actions.RunCtx) void {
    Reaper.Main_OnCommand(40153, 0); // Item: Open in built-in MIDI editor
    const editor = helpers.midiEditorActive() orelse return;
    _ = Reaper.MIDIEditor_OnCommand(editor, 40006); // Edit: Select all events

    const n_sel = Reaper.CountSelectedMediaItems(null);
    if (n_sel == 0) return; // Lua bailed here too, leaving the editor open

    var i: c_int = n_sel - 1;
    while (i >= 0) : (i -= 1) {
        const sel_item = Reaper.GetSelectedMediaItem(null, i) orelse continue;
        const take = getActiveTake(sel_item) orelse continue;
        if (!Reaper.TakeIsMIDI(take)) continue;

        var notes: c_int = 0;
        var ccs: c_int = 0;
        var sysex: c_int = 0;
        _ = Reaper.MIDI_CountEvts(take, &notes, &ccs, &sysex);

        // deduped note-start times in project seconds (notes come back in
        // ppq order, so the list stays sorted)
        var times: std.ArrayList(f64) = .empty;
        defer times.deinit(helpers.allocator);
        var ni: c_int = 0;
        while (ni < notes) : (ni += 1) {
            var selected = false;
            var muted = false;
            var startppq: f64 = 0;
            var endppq: f64 = 0;
            var chan: c_int = 0;
            var pitch: c_int = 0;
            var vel: c_int = 0;
            if (!Reaper.MIDI_GetNote(take, ni, &selected, &muted, &startppq, &endppq, &chan, &pitch, &vel))
                continue;
            const t = Reaper.MIDI_GetProjTimeFromPPQPos(take, startppq);
            if (std.mem.indexOfScalar(f64, times.items, t) == null)
                times.append(helpers.allocator, t) catch return;
        }

        // split at every note start except the first (the item already starts there)
        if (times.items.len > 1) {
            var item = sel_item;
            for (times.items[1..]) |t| {
                // FIXED vs lua: SplitMediaItem returns nil when the position
                // is outside the item — Lua then crashed on the next split;
                // keep splitting the current piece instead.
                if (splitMediaItem(item, t)) |right| item = right;
            }
        }
    }
    _ = Reaper.MIDIEditor_OnCommand(editor, 40477); // File: Close window
}

// ---- time-stretch selected items to the edit cursor -----------------------------

fn stretchItem(edge: Edge) void {
    const n = Reaper.CountSelectedMediaItems(null);
    const cur = Reaper.GetCursorPosition();
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        const item = Reaper.GetSelectedMediaItem(null, i) orelse continue;
        const pos = Reaper.GetMediaItemInfo_Value(item, "D_POSITION");
        const must_stretch = switch (edge) {
            .left => cur < pos,
            .right => cur > pos,
        };
        if (!must_stretch) continue;

        const old_len = Reaper.GetMediaItemInfo_Value(item, "D_LENGTH");
        const new_len = switch (edge) {
            .left => (pos + old_len) - cur,
            .right => cur - pos,
        };

        const takes = Reaper.CountTakes(item);
        var t: c_int = 0;
        while (t < takes) : (t += 1) {
            const take = getTake(item, t) orelse continue;
            const rate = Reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE");
            _ = Reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", old_len * rate / new_len);
        }
        if (edge == .left)
            Reaper.Main_OnCommand(41205, 0); // move position of item to edit cursor
        _ = Reaper.SetMediaItemInfo_Value(item, "D_LENGTH", new_len);
        Reaper.UpdateItemInProject(item);
    }
}

fn stretchItemStartToCursor(_: *actions.RunCtx) void {
    stretchItem(.left);
}

fn stretchItemEndToCursor(_: *actions.RunCtx) void {
    stretchItem(.right);
}

// ---- conform items recorded at another tempo to the session tempo ----------------

const ConformCtx = struct {
    /// Start of the earliest selected item; the stretch scales around it.
    anchor: f64,
    /// Session tempo divided by the original tempo of the recording.
    factor: f64,
};

fn conformItem(ctx: *const ConformCtx, item: *Reaper.MediaItem) void {
    const pos = Reaper.GetMediaItemInfo_Value(item, "D_POSITION");
    const len = Reaper.GetMediaItemInfo_Value(item, "D_LENGTH");

    // Because the item timebase would otherwise react to the new play rate, we pin it to time.
    _ = Reaper.SetMediaItemInfo_Value(item, "C_BEATATTACHMODE", 0);

    const takes = Reaper.CountTakes(item);
    var t: c_int = 0;
    while (t < takes) : (t += 1) {
        const take = getTake(item, t) orelse continue;
        const rate = Reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE");
        _ = Reaper.SetMediaItemTakeInfo_Value(take, "D_PLAYRATE", rate * ctx.factor);
    }
    _ = Reaper.SetMediaItemInfo_Value(item, "D_LENGTH", len / ctx.factor);
    _ = Reaper.SetMediaItemInfo_Value(item, "D_POSITION", ctx.anchor + (pos - ctx.anchor) / ctx.factor);
    Reaper.UpdateItemInProject(item);
}

/// Because the selected items were played in real time against an external
/// metronome, their notes only sit on the grid at the original tempo. We ask
/// for that tempo, and we stretch the items by session tempo / original tempo,
/// so that the notes land on the grid of the session. The session tempo is
/// read at the start of the earliest selected item, and the item positions
/// are scaled around that start, so that the gaps between the items stay
/// proportional.
fn conformItemsToSessionTempo(_: *actions.RunCtx) void {
    const title = "Perken: conform items to session tempo";
    const n = Reaper.CountSelectedMediaItems(null);
    if (n == 0) {
        _ = Reaper.ShowMessageBox("Because no item is selected, there is nothing to conform.", title, 0);
        return;
    }

    var buf: [64]u8 = undefined;
    const reply = helpers.getUserInput(title, "Original BPM of the recording", &buf) orelse return;
    const original = std.fmt.parseFloat(f64, reply) catch 0;
    if (!(original > 0)) {
        _ = Reaper.ShowMessageBox("Because the original BPM is not a positive number, nothing was changed.", title, 0);
        return;
    }

    var anchor = std.math.inf(f64);
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        const item = Reaper.GetSelectedMediaItem(null, i) orelse continue;
        anchor = @min(anchor, Reaper.GetMediaItemInfo_Value(item, "D_POSITION"));
    }

    const ctx = ConformCtx{ .anchor = anchor, .factor = timemap.dividedBpmAtTime(anchor) / original };
    i = 0;
    while (i < n) : (i += 1) {
        const item = Reaper.GetSelectedMediaItem(null, i) orelse continue;
        conformItem(&ctx, item);
    }
}

// ---- one region per selected item on the first selected track ---------------------

/// Because a region name should be the bare file name, we drop the folders
/// (separated by either "/" or "\\") and the last extension from `path`, and
/// we write the remaining name in upper case into `out`. Because an
/// extension is only an extension when something precedes the dot, a name
/// such as ".wav" stays whole. When no name remains, we return null.
fn regionNameFromPath(path: []const u8, out: []u8) ?[]const u8 {
    const sep = std.mem.lastIndexOfAny(u8, path, "/\\");
    const file = if (sep) |i| path[i + 1 ..] else path;
    const dot = std.mem.lastIndexOfScalar(u8, file, '.');
    const stem = if (dot) |i| (if (i > 0) file[0..i] else file) else file;
    const n = @min(stem.len, out.len);
    if (n == 0) return null;
    return std.ascii.upperString(out[0..n], stem[0..n]);
}

/// Because REAPER numbers a region differently from how it enumerates it, we
/// return the number that SetProjectMarker expects for the region starting at
/// `start`, or null when no region starts there.
fn findRegionStartingAt(start: f64) ?c_int {
    var idx: c_int = 0;
    var is_region = false;
    var pos: f64 = 0;
    var number: c_int = 0;
    while (enumProjectMarkers(idx, &is_region, &pos, &number)) : (idx += 1) {
        if (is_region and pos == start) return number;
    }
    return null;
}

/// Because the file name of an item is a good label for the region that
/// covers it, we give every selected item on the first selected track a
/// region that spans the item and carries its source file name. When a region
/// already starts where the item starts, we resize and rename that one
/// instead of stacking a second region on top of it. Because an item without
/// a source file has no name to give, we skip it.
fn itemNamesToRegions(_: *actions.RunCtx) void {
    const track = Reaper.GetSelectedTrack(null, 0) orelse return;
    const tp = helpers.trackPtr(track) orelse return;
    const n_items = Reaper.GetTrackNumMediaItems(tp);
    var i: c_int = 0;
    while (i < n_items) : (i += 1) {
        const item = Reaper.GetTrackMediaItem(tp, i);
        if (@intFromPtr(item) == 0) continue;
        if (!Reaper.IsMediaItemSelected(item)) continue;
        const take = getTake(item, 0) orelse continue;
        const source = getTakeSource(take) orelse continue;

        var path_buf: [1024]u8 = undefined;
        path_buf[0] = 0;
        Reaper.GetMediaSourceFileName(source, @ptrCast(&path_buf), path_buf.len);
        const path = std.mem.sliceTo(&path_buf, 0);

        // Because REAPER wants a null-terminated name, the buffer keeps one spare byte.
        var name_buf: [513]u8 = undefined;
        const name = regionNameFromPath(path, name_buf[0..512]) orelse continue;
        name_buf[name.len] = 0;
        const name_z: [*:0]const u8 = @ptrCast(&name_buf);

        const start = Reaper.GetMediaItemInfo_Value(item, "D_POSITION");
        const end_ = start + Reaper.GetMediaItemInfo_Value(item, "D_LENGTH");
        if (findRegionStartingAt(start)) |number| {
            _ = Reaper.SetProjectMarker(number, true, start, end_, name_z);
        } else {
            _ = Reaper.AddProjectMarker2(null, true, start, end_, name_z, -1, 0);
        }
    }
}

// ---- registry entries -------------------------------------------------------------

pub const entries = [_]actions.Entry{
    // paste_before is a branch-free command sequence; expressed as steps.
    .{
        .name = "PasteItemBeforeCursor",
        .def = .{
            .steps = &.{
                .{ .named = "_XENAKIOS_DOSTORECURPOS" }, // store edit cursor pos
                .{ .named = "_SWS_SAVESEL" }, // store track selection
                .{ .cmd = 40001 }, // insert track
                .{ .cmd = 40058 }, // paste item
                .{ .named = "_XENAKIOS_DORECALLCURPOS" }, // recall edit cursor pos
                .{ .cmd = 41307 }, // trim right edge of item to cursor
                .{ .cmd = 40318 }, // move cursor to right edge of item
                .{ .cmd = 40699 }, // cut items
                .{ .cmd = 40005 }, // remove track
                .{ .named = "_SWS_RESTORESEL" }, // restore track selection
                .{ .cmd = 40058 }, // paste item
            },
        },
    },
    .{ .name = "Set2msFades", .def = .{ .steps = &.{.{ .func = &set2msFades }} } },
    .{ .name = "FadeItemInFromMouse", .def = .{ .steps = &.{.{ .func = &fadeItemInFromMouse }} } },
    .{ .name = "FadeItemOutFromMouse", .def = .{ .steps = &.{.{ .func = &fadeItemOutFromMouse }} } },
    .{ .name = "TrimRightEdgeFromMouse", .def = .{ .steps = &.{.{ .func = &trimRightEdgeFromMouse }} } },
    .{ .name = "TrimLeftEdgeFromMouse", .def = .{ .steps = &.{.{ .func = &trimLeftEdgeFromMouse }} } },
    .{ .name = "SplitItemsAtNoteStart", .def = .{ .steps = &.{.{ .func = &splitItemsAtNoteStart }} } },
    .{ .name = "StretchItemStartToCursor", .def = .{ .steps = &.{.{ .func = &stretchItemStartToCursor }} } },
    .{ .name = "StretchItemEndToCursor", .def = .{ .steps = &.{.{ .func = &stretchItemEndToCursor }} } },
    .{
        .name = "ItemNamesToRegions",
        .def = .{ .desc = "item names to regions", .steps = &.{.{ .func = &itemNamesToRegions }} },
    },
    .{
        .name = "ConformItemsToSessionTempo",
        .def = .{ .desc = "conform items to session tempo", .steps = &.{.{ .func = &conformItemsToSessionTempo }} },
    },
};

test {
    _ = helpers;
}

test "regionNameFromPath keeps the bare upper-case file name" {
    var buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings("KICK_01", regionNameFromPath("/samples/drums/kick_01.wav", &buf).?);
    try std.testing.expectEqualStrings("SNARE", regionNameFromPath("C:\\samples\\snare.flac", &buf).?);
    try std.testing.expectEqualStrings("LOOP.V2", regionNameFromPath("loop.v2.wav", &buf).?);
    try std.testing.expectEqualStrings("NOEXT", regionNameFromPath("/a/noext", &buf).?);
    try std.testing.expectEqualStrings(".WAV", regionNameFromPath("/a/.wav", &buf).?);
    try std.testing.expect(regionNameFromPath("", &buf) == null);
    try std.testing.expect(regionNameFromPath("/a/", &buf) == null);
}
