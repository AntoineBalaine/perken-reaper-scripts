//! Native port of reavim custom_actions/midi.lua (the 9 bound actions).
//! Action names and flags mirror definitions/extended_defaults/actions.lua —
//! every entry here carries midiCommand = true in the Lua defs.
//!
//! toggleKeySnap stays a logging stub: the Lua drives the MIDI editor's
//! key-snap checkbox over js_ReaScriptAPI window messages, and reaziglib has
//! no JS_* bindings.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const actions = @import("../actions.zig");
const helpers = @import("helpers.zig");

const log = std.log.scoped(.engine);

/// midi.listNotes' take lookup: the take open in the active MIDI editor.
fn activeEditorTake() ?*Reaper.MediaItem_Take {
    const editor = helpers.midiEditorActive() orelse return null;
    return helpers.midiEditorTake(editor);
}

// ---- pitch cursor ---------------------------------------------------------------

fn pitchCursorToSelectedNote(_: *actions.RunCtx) void {
    const editor = helpers.midiEditorActive() orelse return;
    const take = helpers.midiEditorTake(editor) orelse return;
    const notes = helpers.collectNotes(helpers.allocator, take) catch return;
    defer helpers.allocator.free(notes);
    for (notes) |n| {
        if (n.selected) {
            _ = Reaper.MIDIEditor_SetSetting_int(editor, "active_note_row", n.pitch);
            return;
        }
    }
}

// ---- jump the edit cursor between note starts --------------------------------------

fn jumpToNextNote(_: *actions.RunCtx) void {
    const take = activeEditorTake() orelse return;
    const notes = helpers.collectNotes(helpers.allocator, take) catch return;
    defer helpers.allocator.free(notes);
    const cur = Reaper.GetCursorPosition();
    for (notes) |n| {
        const pos = Reaper.MIDI_GetProjTimeFromPPQPos(take, n.start_ppq);
        if (pos > cur) {
            Reaper.SetEditCurPos(pos, true, false);
            return;
        }
    }
}

fn jumpToPrevNote(_: *actions.RunCtx) void {
    const take = activeEditorTake() orelse return;
    const notes = helpers.collectNotes(helpers.allocator, take) catch return;
    defer helpers.allocator.free(notes);
    const cur = Reaper.GetCursorPosition();
    var i = notes.len;
    while (i > 0) {
        i -= 1;
        const pos = Reaper.MIDI_GetProjTimeFromPPQPos(take, notes[i].start_ppq);
        if (pos < cur) {
            Reaper.SetEditCurPos(pos, true, false);
            return;
        }
    }
}

// ---- big notes (overlapping/contiguous note runs merged into one PPQ span) ----------

fn spanLessThan(_: void, a: helpers.ItemPosition, b: helpers.ItemPosition) bool {
    if (a.left == b.left) return a.right < b.right;
    return a.left < b.left;
}

/// midi.getNotePositionsInEditor: every note as a {start,end} PPQ span. The
/// Lua trusted MIDI_GetNote's order; sorted here so the merge is correct even
/// on unsorted takes.
fn noteSpans(alloc: std.mem.Allocator, notes: []const helpers.Note) ![]helpers.ItemPosition {
    const spans = try alloc.alloc(helpers.ItemPosition, notes.len);
    for (notes, spans) |n, *s| s.* = .{ .left = n.start_ppq, .right = n.end_ppq };
    std.mem.sort(helpers.ItemPosition, spans, {}, spanLessThan);
    return spans;
}

/// midi.getBigNotePositions — same merge as the big-item helper, in PPQ.
fn bigNoteSpans(take: *Reaper.MediaItem_Take) ?[]helpers.ItemPosition {
    const notes = helpers.collectNotes(helpers.allocator, take) catch return null;
    defer helpers.allocator.free(notes);
    const spans = noteSpans(helpers.allocator, notes) catch return null;
    defer helpers.allocator.free(spans);
    return helpers.mergeBigItems(helpers.allocator, spans) catch null;
}

const Edge = enum { start, end };

fn moveToNextBigNote(edge: Edge) void {
    const take = activeEditorTake() orelse return;
    const spans = bigNoteSpans(take) orelse return;
    defer helpers.allocator.free(spans);
    const cur = Reaper.GetCursorPosition();
    for (spans) |s| {
        const ppq = switch (edge) {
            .start => s.left,
            .end => s.right,
        };
        const pos = Reaper.MIDI_GetProjTimeFromPPQPos(take, ppq);
        if (pos > cur) {
            Reaper.SetEditCurPos(pos, true, false);
            return;
        }
    }
}

fn moveToPrevBigNote(edge: Edge) void {
    const take = activeEditorTake() orelse return;
    const spans = bigNoteSpans(take) orelse return;
    defer helpers.allocator.free(spans);
    const cur = Reaper.GetCursorPosition();
    var i = spans.len;
    while (i > 0) {
        i -= 1;
        const ppq = switch (edge) {
            .start => spans[i].left,
            .end => spans[i].right,
        };
        const pos = Reaper.MIDI_GetProjTimeFromPPQPos(take, ppq);
        if (pos < cur) {
            Reaper.SetEditCurPos(pos, true, false);
            return;
        }
    }
}

fn nextBigNoteEnd(_: *actions.RunCtx) void {
    moveToNextBigNote(.end);
}

fn nextBigNoteStart(_: *actions.RunCtx) void {
    moveToNextBigNote(.start);
}

fn prevBigNoteEnd(_: *actions.RunCtx) void {
    moveToPrevBigNote(.end);
}

fn prevBigNoteStart(_: *actions.RunCtx) void {
    moveToPrevBigNote(.start);
}

// ---- key snap (stub) -----------------------------------------------------------------

// TODO: needs js_ReaScriptAPI bindings missing from reaziglib:
// JS_Window_FindChildByID(editor, 0x4EC) for the key-snap checkbox plus
// JS_WindowMessage_Send (BM_GETCHECK / BM_SETCHECK / WM_COMMAND 1260).
fn toggleKeySnap(_: *actions.RunCtx) void {
    log.warn("'toggleKeySnap' not ported yet — js_ReaScriptAPI window-message bindings missing from reaziglib", .{});
}

// ---- screenset on editor close ---------------------------------------------------------

fn loadScreenSetWhenClosingEditor(_: *actions.RunCtx) void {
    Reaper.Main_OnCommand(40444, 0); // Screenset: Load window set #04 (same id as LoadTrkScreenSet1)
}

// ---- registry entries -------------------------------------------------------------

pub const entries = [_]actions.Entry{
    .{ .name = "PitchCursorToSelectedNote", .def = .{ .steps = &.{.{ .func = &pitchCursorToSelectedNote }}, .midi_command = true } },
    .{ .name = "JumpToNextNote", .def = .{ .steps = &.{.{ .func = &jumpToNextNote }}, .midi_command = true, .prefix_repetition_count = true } },
    .{ .name = "JumpToPrevNote", .def = .{ .steps = &.{.{ .func = &jumpToPrevNote }}, .midi_command = true, .prefix_repetition_count = true } },
    .{ .name = "NextBigNoteEnd", .def = .{ .steps = &.{ .{ .action = "UnselectAllEvents" }, .{ .func = &nextBigNoteEnd } }, .midi_command = true, .prefix_repetition_count = true } },
    .{ .name = "NextBigNoteStart", .def = .{ .steps = &.{ .{ .action = "UnselectAllEvents" }, .{ .func = &nextBigNoteStart } }, .midi_command = true, .prefix_repetition_count = true } },
    .{ .name = "PrevBigNoteEnd", .def = .{ .steps = &.{ .{ .action = "UnselectAllEvents" }, .{ .func = &prevBigNoteEnd } }, .midi_command = true, .prefix_repetition_count = true } },
    .{ .name = "PrevBigNoteStart", .def = .{ .steps = &.{ .{ .action = "UnselectAllEvents" }, .{ .func = &prevBigNoteStart } }, .midi_command = true, .prefix_repetition_count = true } },
    .{ .name = "toggleKeySnap", .def = .{ .steps = &.{.{ .func = &toggleKeySnap }}, .midi_command = true } },
    .{ .name = "CloseUndockedMidiEditorOrPassToMainWindow", .def = .{ .steps = &.{ .{ .cmd = 40477 }, .{ .func = &loadScreenSetWhenClosingEditor } }, .midi_command = true } },
};

// ---- tests ------------------------------------------------------------------

test "noteSpans sorts and big-note merge collapses legato runs" {
    const mk = struct {
        fn note(start: f64, end_: f64) helpers.Note {
            return .{ .selected = false, .muted = false, .start_ppq = start, .end_ppq = end_, .chan = 0, .pitch = 60, .vel = 100 };
        }
    };
    // Deliberately unsorted, with an overlap and a gap.
    const notes = [_]helpers.Note{
        mk.note(480, 960),
        mk.note(0, 500),
        mk.note(1200, 1400),
    };
    const spans = try noteSpans(std.testing.allocator, &notes);
    defer std.testing.allocator.free(spans);
    try std.testing.expectEqual(@as(f64, 0), spans[0].left);

    const big = try helpers.mergeBigItems(std.testing.allocator, spans);
    defer std.testing.allocator.free(big);
    try std.testing.expectEqualSlices(helpers.ItemPosition, &.{
        .{ .left = 0, .right = 960 },
        .{ .left = 1200, .right = 1400 },
    }, big);
}

test {
    _ = helpers;
}
