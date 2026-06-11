//! Native port of reavim custom_actions/items.lua (all 8 functions / 9 actions).
//! Action names and flags mirror definitions/extended_defaults/actions.lua.
//! paste_before is pure command choreography, so it stays a steps-only entry.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const actions = @import("../actions.zig");
const helpers = @import("helpers.zig");

// ---- ABI shims (reaziglib types these returns as non-optional) ---------------

const getActiveTake = helpers.getActiveTake;

fn getTake(item: *Reaper.MediaItem, takeidx: c_int) ?*Reaper.MediaItem_Take {
    const f: *const fn (item: *Reaper.MediaItem, takeidx: c_int) callconv(.C) ?*Reaper.MediaItem_Take = @ptrCast(Reaper.GetTake);
    return f(item, takeidx);
}

fn splitMediaItem(item: *Reaper.MediaItem, position: f64) ?*Reaper.MediaItem {
    const f: *const fn (item: *Reaper.MediaItem, position: f64) callconv(.C) ?*Reaper.MediaItem = @ptrCast(Reaper.SplitMediaItem);
    return f(item, position);
}

// ---- 2 ms fades on selected items in selected tracks --------------------------

fn set2msFades(_: *actions.RunCtx) void {
    const n_tracks = Reaper.CountSelectedTracks(0);
    var i: c_int = 0;
    while (i < n_tracks) : (i += 1) {
        const track = Reaper.GetSelectedTrack(0, i) orelse continue;
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
        const snapped = Reaper.SnapToGrid(0, Reaper.GetCursorPosition());
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

    const n_sel = helpers.countSelectedMediaItems();
    if (n_sel == 0) return; // Lua bailed here too, leaving the editor open

    var i: c_int = n_sel - 1;
    while (i >= 0) : (i -= 1) {
        const sel_item = helpers.getSelectedMediaItem(i) orelse continue;
        const take = getActiveTake(sel_item) orelse continue;
        if (!Reaper.TakeIsMIDI(take)) continue;

        var notes: c_int = 0;
        var ccs: c_int = 0;
        var sysex: c_int = 0;
        _ = Reaper.MIDI_CountEvts(take, &notes, &ccs, &sysex);

        // deduped note-start times in project seconds (notes come back in
        // ppq order, so the list stays sorted)
        var times = std.ArrayList(f64).init(helpers.allocator);
        defer times.deinit();
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
                times.append(t) catch return;
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
    const n = helpers.countSelectedMediaItems();
    const cur = Reaper.GetCursorPosition();
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        const item = helpers.getSelectedMediaItem(i) orelse continue;
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
            .prefix_repetition_count = true,
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
};

test {
    _ = helpers;
}
