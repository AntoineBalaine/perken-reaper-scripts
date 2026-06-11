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
const actions = @import("../actions.zig");
const helpers = @import("helpers.zig");

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

    var list = std.ArrayList(helpers.QnNote).init(helpers.allocator);
    defer list.deinit();
    var any_selected = false;
    var i: c_int = 0;
    while (i < n_notes) : (i += 1) {
        var selected = false;
        var muted = false;
        var start_ppq: f64 = 0;
        var end_ppq: f64 = 0;
        var chan: c_int = 0;
        var pitch: c_int = 0;
        var vel: c_int = 0;
        if (!Reaper.MIDI_GetNote(take, i, &selected, &muted, &start_ppq, &end_ppq, &chan, &pitch, &vel))
            continue;
        if (selected) any_selected = true;
        list.append(.{
            .idx = i,
            .selected = selected,
            .muted = muted,
            .start_qn = Reaper.MIDI_GetProjQNFromPPQPos(take, start_ppq),
            .end_qn = Reaper.MIDI_GetProjQNFromPPQPos(take, end_ppq),
            .chan = chan,
            .pitch = pitch,
            .vel = vel,
        }) catch return null;
    }

    if (any_selected) {
        var w: usize = 0;
        for (list.items) |n| {
            if (n.selected) {
                list.items[w] = n;
                w += 1;
            }
        }
        list.shrinkRetainingCapacity(w);
    }

    const notes = list.toOwnedSlice() catch return null;
    helpers.sortChordOrder(notes);
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

// ---- registry entries -------------------------------------------------------------

pub const entries = [_]actions.Entry{
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
