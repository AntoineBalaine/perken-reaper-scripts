//! Native port of reavim custom_actions/kawa.lua (all 23 bound actions).
//! Action names and flags mirror definitions/extended_defaults/actions.lua —
//! every entry carries midiCommand = true in the Lua defs.
//!
//! The Lua's re-minified kawa engine (createMIDIFunc3) collapses to one
//! collectTarget(): pre-clean the take via MIDI-editor commands, snapshot all
//! notes in QN domain, pick selected-else-all, and sort into chord order
//! (helpers.sortChordOrder + helpers.chords replace get_chords/sort_chords).
//!
//! FIXED vs lua (two index-staleness hazards, both noted inline):
//! - drop* rewrote pitches with sorting MIDI_SetNote calls, so REAPER could
//!   reorder notes mid-loop and the remaining cached note indices went stale;
//!   here every write passes noSort=true and one MIDI_Sort runs at the end.
//! - double* inserted copies with noSort=true and never sorted the take;
//!   here MIDI_Sort runs after the inserts as the API requires.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const actions = @import("actions.zig");
const helpers = @import("reaper_helpers");
const commit = @import("beat/commit.zig");
const timemap = @import("timemap.zig");

// MIDI-editor command ids used by kawa's createMIDIFunc3.
const cmd_delete_tiny_notes: c_int = 40815; // delete all notes < 1/256 in length
const cmd_correct_overlapping: c_int = 40659; // correct overlapping notes
const cmd_unselect_all: c_int = 40214; // unselect all events

/// kawa capped reads at 1000 notes and aborted with a message box.
const note_limit: c_int = 1000;

const Target = struct {
    editor: Reaper.HWND,
    take: *Reaper.MediaItem_Take,
    /// Target notes (selected if any, else all) in chord order.
    notes: []helpers.QnNote,

    fn deinit(self: Target) void {
        helpers.allocator.free(self.notes);
    }
};

/// createMIDIFunc3's _init + getMidiNotes + detectTargetNote: pre-clean the
/// active editor's take (delete tiny notes, correct overlaps — both under
/// PreventUIRefresh like the Lua), snapshot every note converting PPQ→QN, and
/// keep the selected notes — or all of them when none is selected. Null when
/// no editor/take is open or the note-count safety cap trips.
fn collectTarget() ?Target {
    const editor = helpers.midiEditorActive() orelse return null;
    const take = helpers.midiEditorTake(editor) orelse return null;

    Reaper.PreventUIRefresh(2);
    _ = Reaper.MIDIEditor_OnCommand(editor, cmd_delete_tiny_notes);
    _ = Reaper.MIDIEditor_OnCommand(editor, cmd_correct_overlapping);
    Reaper.PreventUIRefresh(-1);

    var n_notes: c_int = 0;
    var n_cc: c_int = 0;
    var n_sysex: c_int = 0;
    _ = Reaper.MIDI_CountEvts(take, &n_notes, &n_cc, &n_sysex);
    if (n_notes > note_limit) {
        _ = Reaper.ShowMessageBox("over 1000 clip num .\nstop process", "stop.", 0);
        return null;
    }

    const collected = helpers.collectQnNotes(helpers.allocator, take) catch return null;
    const notes = helpers.keepSelected(helpers.QnNote, collected.notes, collected.any_selected);
    return .{ .editor = editor, .take = take, .notes = notes };
}

// ---- note writes ------------------------------------------------------------

/// MIDI_SetNote from a QnNote with QN→PPQ conversion (kawa's select_notes /
/// transpose_notes). Always noSort=true — see the module header.
fn writeNote(take: *Reaper.MediaItem_Take, n: helpers.QnNote, selected: bool, pitch: c_int) void {
    const start_ppq = Reaper.MIDI_GetPPQPosFromProjQN(take, n.start_qn);
    const end_ppq = Reaper.MIDI_GetPPQPosFromProjQN(take, n.end_qn);
    const no_sort = true;
    _ = Reaper.MIDI_SetNote(take, n.idx, &selected, &n.muted, &start_ppq, &end_ppq, &n.chan, &pitch, &n.vel, &no_sort);
}

/// MIDI_InsertNote of a transposed copy (kawa's double* family).
fn insertTransposedCopy(take: *Reaper.MediaItem_Take, n: helpers.QnNote, semitones: c_int) void {
    const start_ppq = Reaper.MIDI_GetPPQPosFromProjQN(take, n.start_qn);
    const end_ppq = Reaper.MIDI_GetPPQPosFromProjQN(take, n.end_qn);
    const no_sort = true;
    _ = Reaper.MIDI_InsertNote(take, n.selected, n.muted, start_ppq, end_ppq, n.chan, n.pitch + semitones, n.vel, &no_sort);
}

// ---- chord-position selection (select_bottom_note .. select_all_but_middle) --

const Part = enum { bottom, top, middle, all_but_top, all_but_bottom, all_but_middle };

/// The chord sub-slice a Part keeps; the chord is pitch-descending ([0] = top).
/// all_but_middle is not contiguous (top + bottom) and is handled by the
/// caller. Mirrors the Lua's table.remove choreography, including the empty
/// results for 1- and 2-note chords.
fn partOfChord(part: Part, chord: []const helpers.QnNote) []const helpers.QnNote {
    return switch (part) {
        .top => chord[0..1],
        .bottom => chord[chord.len - 1 ..],
        .middle => if (chord.len > 2) chord[1 .. chord.len - 1] else chord[0..0],
        .all_but_top => chord[1..],
        .all_but_bottom => chord[0 .. chord.len - 1],
        .all_but_middle => unreachable,
    };
}

fn selectPart(part: Part) void {
    const tgt = collectTarget() orelse return;
    defer tgt.deinit();
    if (tgt.notes.len == 0) return;
    _ = Reaper.MIDIEditor_OnCommand(tgt.editor, cmd_unselect_all);
    var it = helpers.chords(tgt.notes);
    while (it.next()) |chord| {
        if (part == .all_but_middle) {
            // Lua deep-copied top and bottom; a 1-note chord selects the same
            // note twice there and here — harmless either way.
            writeNote(tgt.take, chord[0], true, chord[0].pitch);
            writeNote(tgt.take, chord[chord.len - 1], true, chord[chord.len - 1].pitch);
        } else {
            for (partOfChord(part, chord)) |n| writeNote(tgt.take, n, true, n.pitch);
        }
    }
}

// ---- drop voicings (drop_2 / drop_3 / drop2_4) --------------------------------

/// Transpose the chord notes at the given 1-based-from-top positions down an
/// octave (get_chords_only_notes_at_idx + transpose_notes).
fn dropVoices(comptime keep: []const usize) void {
    const tgt = collectTarget() orelse return;
    defer tgt.deinit();
    if (tgt.notes.len == 0) return;
    var it = helpers.chords(tgt.notes);
    while (it.next()) |chord| {
        inline for (keep) |k| {
            if (k <= chord.len) {
                const n = chord[k - 1];
                writeNote(tgt.take, n, n.selected, n.pitch - 12);
            }
        }
    }
    Reaper.MIDI_Sort(tgt.take);
}

// ---- doubled voices ------------------------------------------------------------

const Voice = enum { top, bottom };

/// doubleTopNotesUp / doubleBottomNotesDown: copy one voice of every chord.
fn doubleVoice(voice: Voice, semitones: c_int) void {
    const tgt = collectTarget() orelse return;
    defer tgt.deinit();
    if (tgt.notes.len == 0) return;
    var it = helpers.chords(tgt.notes);
    while (it.next()) |chord| {
        const n = switch (voice) {
            .top => chord[0],
            .bottom => chord[chord.len - 1],
        };
        insertTransposedCopy(tgt.take, n, semitones);
    }
    Reaper.MIDI_Sort(tgt.take);
}

/// double_notes: copy every target note, transposed.
fn doubleNotes(semitones: c_int) void {
    const tgt = collectTarget() orelse return;
    defer tgt.deinit();
    if (tgt.notes.len == 0) return;
    for (tgt.notes) |n| insertTransposedCopy(tgt.take, n, semitones);
    Reaper.MIDI_Sort(tgt.take);
}

// ---- action wrappers -------------------------------------------------------------

fn selectBottomNotes(_: *actions.RunCtx) void {
    selectPart(.bottom);
}

fn selectTopNotes(_: *actions.RunCtx) void {
    selectPart(.top);
}

fn selectMiddleNotes(_: *actions.RunCtx) void {
    selectPart(.middle);
}

fn selectAllButTop(_: *actions.RunCtx) void {
    selectPart(.all_but_top);
}

fn selectAllButBottom(_: *actions.RunCtx) void {
    selectPart(.all_but_bottom);
}

fn selectAllButMiddle(_: *actions.RunCtx) void {
    selectPart(.all_but_middle);
}

fn drop2(_: *actions.RunCtx) void {
    dropVoices(&.{2});
}

fn drop3(_: *actions.RunCtx) void {
    dropVoices(&.{3});
}

fn drop24(_: *actions.RunCtx) void {
    dropVoices(&.{ 2, 4 });
}

fn doubleTopOctUp(_: *actions.RunCtx) void {
    doubleVoice(.top, 12);
}

fn doubleBottomOctDown(_: *actions.RunCtx) void {
    doubleVoice(.bottom, -12);
}

fn doubleOctUp(_: *actions.RunCtx) void {
    doubleNotes(12);
}

fn doubleOctDown(_: *actions.RunCtx) void {
    doubleNotes(-12);
}

fn doubleSeventhUp(_: *actions.RunCtx) void {
    doubleNotes(10);
}

fn doubleSeventhDown(_: *actions.RunCtx) void {
    doubleNotes(-10);
}

fn doubleSixthUp(_: *actions.RunCtx) void {
    doubleNotes(9);
}

fn doubleSixthDown(_: *actions.RunCtx) void {
    doubleNotes(-9);
}

fn doubleFifthUp(_: *actions.RunCtx) void {
    doubleNotes(7);
}

fn doubleFifthDown(_: *actions.RunCtx) void {
    doubleNotes(-7);
}

fn doubleFourthUp(_: *actions.RunCtx) void {
    doubleNotes(5);
}

fn doubleFourthDown(_: *actions.RunCtx) void {
    doubleNotes(-5);
}

fn doubleThirdUp(_: *actions.RunCtx) void {
    doubleNotes(4);
}

fn doubleThirdDown(_: *actions.RunCtx) void {
    doubleNotes(-4);
}

// ---- legato ----------------------------------------------------------------------
// Replaces the user's old REAPER custom action "AB - Custom Legato", which ran
// kawa_MIDI_NoteLengthToEndOfTakeItem and then kawa_MIDI_ResolveOverLap: every
// target note ended one tick before the next chord, and the last chord ran to
// the end of the item.

/// A target note as the legato logic sees it: its index in the take, and its
/// start and end in PPQ ticks.
pub const Span = struct { idx: c_int, start: f64, end: f64 };

fn spanStartLessThan(spans: []const Span, a: usize, b: usize) bool {
    return spans[a].start < spans[b].start;
}

/// The nearest start in `starts` that is later than `after`, if any.
fn nextStartAfter(starts: []const f64, after: f64) ?f64 {
    var nearest: ?f64 = null;
    for (starts) |st| {
        if (st > after and (nearest == null or st < nearest.?)) nearest = st;
    }
    return nearest;
}

/// Computes the legato end of every note in `spans`, into `out` (same order).
/// A chord is the notes sharing one start; pitch plays no part. Every chord
/// but the last ends one tick before the start of the next chord (the nearest
/// later start among `spans`, so a selected voice stays legato across the
/// notes in between that are not selected). The last chord ends one tick
/// before the nearest later start among `other_starts`, the starts of the
/// notes that are not in `spans`, because nothing selected follows it and its
/// tail must not run into the next note; with no such note, it ends at
/// `item_end`. Notes are both lengthened and shortened to that point. A note
/// keeps its end when the point would leave it with no length: when the next
/// start is under two ticks away, or the item ends at or before the note's
/// start.
pub fn legatoEnds(alloc: std.mem.Allocator, spans: []const Span, other_starts: []const f64, item_end: f64, out: []f64) !void {
    std.debug.assert(out.len == spans.len);
    const tick: f64 = 1;
    for (spans, out) |sp, *o| o.* = sp.end;

    const order = try alloc.alloc(usize, spans.len);
    defer alloc.free(order);
    for (order, 0..) |*o, i| o.* = i;
    std.mem.sort(usize, order, spans, spanStartLessThan);

    var g: usize = 0;
    while (g < order.len) {
        const start = spans[order[g]].start;
        var h = g;
        while (h < order.len and spans[order[h]].start == start) h += 1;
        const limit = if (h < order.len)
            spans[order[h]].start - tick
        else if (nextStartAfter(other_starts, start)) |next|
            next - tick
        else
            item_end;
        if (limit > start) {
            for (order[g..h]) |i| out[i] = limit;
        }
        g = h;
    }
}

/// The end of the take's item in PPQ ticks.
fn itemEndPpq(take: *Reaper.MediaItem_Take) ?f64 {
    const item = Reaper.GetMediaItemTake_Item(take);
    if (@intFromPtr(item) == 0) return null;
    const pos = Reaper.GetMediaItemInfo_Value(item, "D_POSITION");
    const len = Reaper.GetMediaItemInfo_Value(item, "D_LENGTH");
    return Reaper.MIDI_GetPPQPosFromProjQN(take, timemap.timeToQn(pos + len));
}

/// Legato on the selected notes of the active MIDI editor's take, or on every
/// note when none is selected: each chord ends before the next selected one,
/// and the last chord before the next note of any kind, or at the item end.
/// Nothing else in the take is touched: unlike
/// kawa's scripts it does not delete short notes first, and it has no cap on
/// the number of notes.
fn legato(_: *actions.RunCtx) void {
    const editor = helpers.midiEditorActive() orelse return;
    const take = helpers.midiEditorTake(editor) orelse return;
    const item_end = itemEndPpq(take) orelse return;

    const collected = helpers.collectPpqNotes(helpers.allocator, take) catch return;
    defer helpers.allocator.free(collected.notes);
    const all = collected.notes;
    const any_selected = collected.any_selected;

    var targets = std.ArrayList(helpers.PpqNote).init(helpers.allocator);
    defer targets.deinit();
    for (all) |r| {
        if (!any_selected or r.selected) targets.append(r) catch return;
    }
    if (targets.items.len == 0) return;

    // The starts of the notes that are not targets: the last chord stops
    // before the next of them.
    var others = std.ArrayList(f64).init(helpers.allocator);
    defer others.deinit();
    for (all) |r| {
        if (any_selected and !r.selected) others.append(r.start) catch return;
    }

    const spans = helpers.allocator.alloc(Span, targets.items.len) catch return;
    defer helpers.allocator.free(spans);
    const ends = helpers.allocator.alloc(f64, targets.items.len) catch return;
    defer helpers.allocator.free(ends);
    for (targets.items, spans) |r, *sp| sp.* = .{ .idx = r.idx, .start = r.start, .end = r.end };
    legatoEnds(helpers.allocator, spans, others.items, item_end, ends) catch return;

    Reaper.Undo_BeginBlock();
    for (targets.items, ends) |r, new_end| {
        if (new_end == r.end) continue;
        const no_sort = true;
        _ = Reaper.MIDI_SetNote(take, r.idx, &r.selected, &r.muted, &r.start, &new_end, &r.chan, &r.pitch, &r.vel, &no_sort);
    }
    Reaper.MIDI_Sort(take);
    Reaper.Undo_EndBlock("Perken: legato", -1);
    Reaper.UpdateArrange();
}

// ---- quantize note ends -----------------------------------------------------------

/// The end, in quarter notes, that a note starting at `start_qn` and ending at
/// `end_qn` gets when its end is snapped to a grid of `grid_qn` quarter notes.
/// Because a note needs some length, an end that would land on or before the
/// start moves to the first grid line after the start instead.
pub fn quantizedEndQn(start_qn: f64, end_qn: f64, grid_qn: f64) f64 {
    const snapped = @round(end_qn / grid_qn) * grid_qn;
    if (snapped > start_qn) return snapped;
    return (@floor(start_qn / grid_qn) + 1) * grid_qn;
}

/// Snaps the end of every selected note of the active MIDI editor's take (or
/// of every note when none is selected) to the editor's grid, and leaves the
/// starts alone. Because the grid is read from the editor, the action follows
/// whatever grid division the user has chosen there.
fn quantizeNoteEnds(_: *actions.RunCtx) void {
    const editor = helpers.midiEditorActive() orelse return;
    const take = helpers.midiEditorTake(editor) orelse return;

    var swing: f64 = 0;
    var note_len: f64 = 0;
    var grid_qn = Reaper.MIDI_GetGrid(take, &swing, &note_len);
    if (grid_qn <= 0) grid_qn = 1;

    const collected = helpers.collectPpqNotes(helpers.allocator, take) catch return;
    defer helpers.allocator.free(collected.notes);
    const all = collected.notes;
    const any_selected = collected.any_selected;

    Reaper.Undo_BeginBlock();
    for (all) |r| {
        if (any_selected and !r.selected) continue;
        const start_qn = Reaper.MIDI_GetProjQNFromPPQPos(take, r.start);
        const end_qn = Reaper.MIDI_GetProjQNFromPPQPos(take, r.end);
        const new_end = Reaper.MIDI_GetPPQPosFromProjQN(take, quantizedEndQn(start_qn, end_qn, grid_qn));
        if (@abs(new_end - r.end) < 0.5) continue;
        const no_sort = true;
        _ = Reaper.MIDI_SetNote(take, r.idx, &r.selected, &r.muted, &r.start, &new_end, &r.chan, &r.pitch, &r.vel, &no_sort);
    }
    Reaper.MIDI_Sort(take);
    Reaper.Undo_EndBlock("Perken: quantize note ends", -1);
    Reaper.UpdateArrange();
}

// ---- registry entries -------------------------------------------------------------

pub const entries = [_]actions.Entry{
    .{ .name = "QuantizeNoteEnds", .def = .{ .steps = &.{.{ .func = &quantizeNoteEnds }}, .midi_command = true, .desc = "Quantize note ends to the grid, leaving the starts alone" } },
    .{ .name = "Legato", .def = .{ .steps = &.{.{ .func = &legato }}, .midi_command = true, .desc = "Legato: notes end at the next chord, the last at the item end" } },
    .{ .name = "SelectBottomNotes", .def = .{ .steps = &.{.{ .func = &selectBottomNotes }}, .midi_command = true } },
    .{ .name = "SelectTopNotes", .def = .{ .steps = &.{.{ .func = &selectTopNotes }}, .midi_command = true } },
    .{ .name = "SelectMiddleNotes", .def = .{ .steps = &.{.{ .func = &selectMiddleNotes }}, .midi_command = true } },
    .{ .name = "SelectAllButTop", .def = .{ .steps = &.{.{ .func = &selectAllButTop }}, .midi_command = true } },
    .{ .name = "SelectAllButBottom", .def = .{ .steps = &.{.{ .func = &selectAllButBottom }}, .midi_command = true } },
    .{ .name = "SelectAllButMiddle", .def = .{ .steps = &.{.{ .func = &selectAllButMiddle }}, .midi_command = true } },
    .{ .name = "drop2", .def = .{ .steps = &.{.{ .func = &drop2 }}, .midi_command = true } },
    .{ .name = "drop3", .def = .{ .steps = &.{.{ .func = &drop3 }}, .midi_command = true } },
    .{ .name = "drop24", .def = .{ .steps = &.{.{ .func = &drop24 }}, .midi_command = true } },
    .{ .name = "doubleTopOctUp", .def = .{ .steps = &.{.{ .func = &doubleTopOctUp }}, .midi_command = true } },
    .{ .name = "doubleBottomOctDown", .def = .{ .steps = &.{.{ .func = &doubleBottomOctDown }}, .midi_command = true } },
    .{ .name = "doubleOctUp", .def = .{ .steps = &.{.{ .func = &doubleOctUp }}, .midi_command = true } },
    .{ .name = "doubleOctDown", .def = .{ .steps = &.{.{ .func = &doubleOctDown }}, .midi_command = true } },
    .{ .name = "doubleSeventhUp", .def = .{ .steps = &.{.{ .func = &doubleSeventhUp }}, .midi_command = true } },
    .{ .name = "doubleSeventhDown", .def = .{ .steps = &.{.{ .func = &doubleSeventhDown }}, .midi_command = true } },
    .{ .name = "doubleSixthUp", .def = .{ .steps = &.{.{ .func = &doubleSixthUp }}, .midi_command = true } },
    .{ .name = "doubleSixthDown", .def = .{ .steps = &.{.{ .func = &doubleSixthDown }}, .midi_command = true } },
    .{ .name = "doubleFifthUp", .def = .{ .steps = &.{.{ .func = &doubleFifthUp }}, .midi_command = true } },
    .{ .name = "doubleFifthDown", .def = .{ .steps = &.{.{ .func = &doubleFifthDown }}, .midi_command = true } },
    .{ .name = "doubleFourthUp", .def = .{ .steps = &.{.{ .func = &doubleFourthUp }}, .midi_command = true } },
    .{ .name = "doubleFourthDown", .def = .{ .steps = &.{.{ .func = &doubleFourthDown }}, .midi_command = true } },
    .{ .name = "doubleThirdUp", .def = .{ .steps = &.{.{ .func = &doubleThirdUp }}, .midi_command = true } },
    .{ .name = "doubleThirdDown", .def = .{ .steps = &.{.{ .func = &doubleThirdDown }}, .midi_command = true } },
};

// ---- tests ------------------------------------------------------------------

fn testChord(comptime pitches: []const c_int) [pitches.len]helpers.QnNote {
    var out: [pitches.len]helpers.QnNote = undefined;
    inline for (pitches, 0..) |p, i| {
        out[i] = .{ .idx = @intCast(i), .selected = false, .muted = false, .start_qn = 1.0, .end_qn = 2.0, .chan = 0, .pitch = p, .vel = 90 };
    }
    return out;
}

test "partOfChord on a 4-note chord" {
    const chord = testChord(&.{ 72, 67, 64, 60 }); // pitch-descending
    try std.testing.expectEqual(@as(c_int, 72), partOfChord(.top, &chord)[0].pitch);
    try std.testing.expectEqual(@as(c_int, 60), partOfChord(.bottom, &chord)[0].pitch);

    const middle = partOfChord(.middle, &chord);
    try std.testing.expectEqual(@as(usize, 2), middle.len);
    try std.testing.expectEqual(@as(c_int, 67), middle[0].pitch);
    try std.testing.expectEqual(@as(c_int, 64), middle[1].pitch);

    const no_top = partOfChord(.all_but_top, &chord);
    try std.testing.expectEqual(@as(usize, 3), no_top.len);
    try std.testing.expectEqual(@as(c_int, 67), no_top[0].pitch);

    const no_bottom = partOfChord(.all_but_bottom, &chord);
    try std.testing.expectEqual(@as(usize, 3), no_bottom.len);
    try std.testing.expectEqual(@as(c_int, 64), no_bottom[2].pitch);
}

test "partOfChord edge sizes match the Lua's table.remove behavior" {
    const single = testChord(&.{60});
    try std.testing.expectEqual(@as(usize, 0), partOfChord(.middle, &single).len);
    try std.testing.expectEqual(@as(usize, 0), partOfChord(.all_but_top, &single).len);
    try std.testing.expectEqual(@as(usize, 0), partOfChord(.all_but_bottom, &single).len);
    try std.testing.expectEqual(@as(usize, 1), partOfChord(.top, &single).len);
    try std.testing.expectEqual(@as(usize, 1), partOfChord(.bottom, &single).len);

    const pair = testChord(&.{ 67, 60 });
    try std.testing.expectEqual(@as(usize, 0), partOfChord(.middle, &pair).len);
    try std.testing.expectEqual(@as(usize, 1), partOfChord(.all_but_top, &pair).len);
    try std.testing.expectEqual(@as(c_int, 60), partOfChord(.all_but_top, &pair)[0].pitch);
}

test {
    _ = helpers;
}

test "legato: each chord ends a tick before the next, the last at the item end" {
    const spans = [_]Span{
        .{ .idx = 0, .start = 0, .end = 100 },
        .{ .idx = 1, .start = 0, .end = 400 }, // same chord, and longer than the gap
        .{ .idx = 2, .start = 960, .end = 1000 },
        .{ .idx = 3, .start = 1920, .end = 1930 },
    };
    var out: [4]f64 = undefined;
    try legatoEnds(std.testing.allocator, &spans, &.{}, 2880, &out);
    try std.testing.expectEqualSlices(f64, &.{ 959, 959, 1919, 2880 }, &out);
}

test "legato: the order of the notes does not matter" {
    const spans = [_]Span{
        .{ .idx = 5, .start = 1920, .end = 1930 },
        .{ .idx = 3, .start = 0, .end = 100 },
        .{ .idx = 4, .start = 960, .end = 1000 },
    };
    var out: [3]f64 = undefined;
    try legatoEnds(std.testing.allocator, &spans, &.{}, 2880, &out);
    try std.testing.expectEqualSlices(f64, &.{ 2880, 959, 1919 }, &out);
}

test "legato: a single note runs to the item end" {
    const spans = [_]Span{.{ .idx = 0, .start = 480, .end = 600 }};
    var out: [1]f64 = undefined;
    try legatoEnds(std.testing.allocator, &spans, &.{}, 1920, &out);
    try std.testing.expectEqualSlices(f64, &.{1920}, &out);
}

test "legato: a note keeps its end when it would be left without length" {
    // The next chord is one tick away, so the point one tick before it is the
    // note's own start.
    const close = [_]Span{ .{ .idx = 0, .start = 0, .end = 50 }, .{ .idx = 1, .start = 1, .end = 80 } };
    var out2: [2]f64 = undefined;
    try legatoEnds(std.testing.allocator, &close, &.{}, 960, &out2);
    try std.testing.expectEqualSlices(f64, &.{ 50, 960 }, &out2);

    // The last chord starts at the item end.
    const at_end = [_]Span{.{ .idx = 0, .start = 960, .end = 1000 }};
    var out1: [1]f64 = undefined;
    try legatoEnds(std.testing.allocator, &at_end, &.{}, 960, &out1);
    try std.testing.expectEqualSlices(f64, &.{1000}, &out1);
}

test "legato: no notes" {
    var out: [0]f64 = undefined;
    try legatoEnds(std.testing.allocator, &.{}, &.{}, 960, &out);
}

test "legato: the last chord stops before the next note that is not selected" {
    // Selected notes at 0 and 960; unselected notes start at 480 (between them),
    // 1440 and 1920 (after the last selected chord).
    const spans = [_]Span{
        .{ .idx = 0, .start = 0, .end = 100 },
        .{ .idx = 1, .start = 960, .end = 1000 },
    };
    var out: [2]f64 = undefined;
    try legatoEnds(std.testing.allocator, &spans, &.{ 1920, 480, 1440 }, 2880, &out);
    // The first chord ignores the unselected note at 480; the last stops
    // before the nearest later one, at 1440.
    try std.testing.expectEqualSlices(f64, &.{ 959, 1439 }, &out);
}

test "legato: unselected notes before the last chord do not limit it" {
    const spans = [_]Span{.{ .idx = 2, .start = 960, .end = 1000 }};
    var out: [1]f64 = undefined;
    try legatoEnds(std.testing.allocator, &spans, &.{ 0, 480, 960 }, 2880, &out);
    // Nothing starts after 960, and a note starting together with the chord is
    // not later than it, so the chord runs to the item end.
    try std.testing.expectEqualSlices(f64, &.{2880}, &out);
}

test "legato: a next note too close leaves the last chord as it was" {
    const spans = [_]Span{.{ .idx = 0, .start = 0, .end = 50 }};
    var out: [1]f64 = undefined;
    try legatoEnds(std.testing.allocator, &spans, &.{1}, 960, &out);
    try std.testing.expectEqualSlices(f64, &.{50}, &out);
}

test "quantize ends: an end snaps to the nearest grid line" {
    try std.testing.expectEqual(@as(f64, 1.0), quantizedEndQn(0, 0.9, 0.25));
    try std.testing.expectEqual(@as(f64, 1.0), quantizedEndQn(0, 1.1, 0.25));
    try std.testing.expectEqual(@as(f64, 1.25), quantizedEndQn(0, 1.2, 0.25));
}

test "quantize ends: an end that would not follow the start moves to the next grid line" {
    try std.testing.expectEqual(@as(f64, 0.5), quantizedEndQn(0.3, 0.35, 0.5));
    try std.testing.expectEqual(@as(f64, 1.0), quantizedEndQn(0.5, 0.6, 0.5));
}
