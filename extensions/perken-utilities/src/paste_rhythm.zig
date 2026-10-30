//! Port of reavim custom_actions/pasteRhythm.lua (pasteRhythmToPitches), itself
//! a mod of Pandabot's Paste Rhythm that needs no special copy action.
//!
//! The clipboard holds a MIDI item whose notes are the rhythm. The action
//! pastes it as a new take of the selected item, reads the rhythm from that
//! take, then rewrites the active take: each rhythm position gets the pitches
//! (and channels) of the chord that was playing there, with the rhythm's
//! velocities. The pasted take is deleted afterwards.
//!
//! FIXED vs lua: the Lua inserted its notes one by one with sorting on, and
//! deleted the pasted take without an undo block; here the writes pass
//! noSort and one MIDI_Sort runs at the end, inside one undo point.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const actions = @import("actions.zig");
const helpers = @import("reaper_helpers");

const log = std.log.scoped(.extension);

const Note = helpers.Note;

const cmd_paste_as_takes: c_int = 40603; // Take: Paste as takes in items
const cmd_delete_active_take: c_int = 40129; // Take: Delete active take from items

/// pasteRhythm.lua's getCurrentVelocity default, used when a rhythm position
/// has fewer notes than the chord it lands on and no earlier velocity exists.
const default_velocity: c_int = 96;

/// The clipboard's notes sharing a start and an end, with their velocities
/// in note order (pasteRhythm.lua's rhythmNote).
const RhythmSlot = struct {
    start: f64,
    end: f64,
    vels: std.ArrayList(c_int) = .empty,
};

/// The existing notes sharing a start: the chord the rhythm lands on
/// (pasteRhythm.lua's existingNote).
const Chord = struct {
    start: f64,
    chans: std.ArrayList(c_int) = .empty,
    pitches: std.ArrayList(c_int) = .empty,
};

/// The chord that was playing at `start`: the latest one starting at or
/// before it, else the closest one after it. Null only when there is none.
fn chordAt(chords: []const Chord, start: f64) ?*const Chord {
    var best: ?*const Chord = null;
    var best_delta = std.math.inf(f64);
    for (chords) |*c| {
        const delta = start - c.start;
        if (delta >= 0 and delta <= best_delta) {
            best = c;
            best_delta = delta;
        }
    }
    if (best != null) return best;
    for (chords) |*c| {
        const delta = @abs(start - c.start);
        if (delta <= best_delta) {
            best = c;
            best_delta = delta;
        }
    }
    return best;
}

/// The notes that replace `existing` once `rhythm` is pasted onto it. Every
/// rhythm position gets the pitches and channels of the chord playing there;
/// velocities come from the rhythm, note for note, and the last one read
/// fills the rest of a bigger chord. Empty when `existing` has no notes.
pub fn pasteRhythm(alloc: std.mem.Allocator, rhythm: []const Note, existing: []const Note) ![]Note {
    var arena_state = std.heap.ArenaAllocator.init(alloc);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    var slots: std.ArrayList(RhythmSlot) = .empty;
    for (rhythm) |n| {
        // The Lua skipped a note at 0..0, the placeholder REAPER leaves in an empty take.
        if (n.start_ppq == 0 and n.end_ppq == 0) continue;
        const slot = for (slots.items) |*s| {
            if (s.start == n.start_ppq and s.end == n.end_ppq) break s;
        } else blk: {
            try slots.append(arena, .{ .start = n.start_ppq, .end = n.end_ppq });
            break :blk &slots.items[slots.items.len - 1];
        };
        try slot.vels.append(arena, n.vel);
    }

    var chords: std.ArrayList(Chord) = .empty;
    for (existing) |n| {
        const chord = for (chords.items) |*c| {
            if (c.start == n.start_ppq) break c;
        } else blk: {
            try chords.append(arena, .{ .start = n.start_ppq });
            break :blk &chords.items[chords.items.len - 1];
        };
        try chord.chans.append(arena, n.chan);
        try chord.pitches.append(arena, n.pitch);
    }

    var out: std.ArrayList(Note) = .empty;
    errdefer out.deinit(alloc);
    var previous_vel = default_velocity;
    for (slots.items) |s| {
        const chord = chordAt(chords.items, s.start) orelse break;
        for (chord.pitches.items, chord.chans.items, 0..) |pitch, chan, j| {
            const vel = if (j < s.vels.items.len) s.vels.items[j] else previous_vel;
            previous_vel = vel;
            try out.append(alloc, .{
                .selected = false,
                .muted = false,
                .start_ppq = s.start,
                .end_ppq = s.end,
                .chan = chan,
                .pitch = pitch,
                .vel = vel,
            });
        }
    }
    return out.toOwnedSlice(alloc);
}

fn takesOf(alloc: std.mem.Allocator, item: *Reaper.MediaItem) ![]*Reaper.MediaItem_Take {
    const n: usize = @intCast(Reaper.GetMediaItemNumTakes(item));
    const takes = try alloc.alloc(*Reaper.MediaItem_Take, n);
    for (takes, 0..) |*t, i| t.* = Reaper.GetMediaItemTake(item, @intCast(i));
    return takes;
}

fn deleteAllNotes(take: *Reaper.MediaItem_Take) void {
    var n_notes: c_int = 0;
    var n_cc: c_int = 0;
    var n_sysex: c_int = 0;
    _ = Reaper.MIDI_CountEvts(take, &n_notes, &n_cc, &n_sysex);
    var i = n_notes;
    while (i > 0) : (i -= 1) _ = Reaper.MIDI_DeleteNote(take, i - 1);
}

/// Rewrites `target` with the rhythm of `rhythm_take`; a target without notes
/// is left alone, like the Lua did.
fn applyRhythm(alloc: std.mem.Allocator, target: *Reaper.MediaItem_Take, rhythm_take: *Reaper.MediaItem_Take) !void {
    const rhythm = try helpers.collectNotes(alloc, rhythm_take);
    defer alloc.free(rhythm);
    const existing = try helpers.collectNotes(alloc, target);
    defer alloc.free(existing);
    if (existing.len == 0) return;

    const new_notes = try pasteRhythm(alloc, rhythm, existing);
    defer alloc.free(new_notes);

    deleteAllNotes(target);
    const no_sort = true;
    for (new_notes) |n| {
        _ = Reaper.MIDI_InsertNote(target, false, false, n.start_ppq, n.end_ppq, n.chan, n.pitch, n.vel, &no_sort);
    }
    Reaper.MIDI_Sort(target);
}

fn pasteRhythmToPitches(_: *actions.RunCtx) void {
    const alloc = helpers.allocator;
    if (Reaper.CountSelectedMediaItems(null) == 0) return;
    const item = Reaper.GetSelectedMediaItem(null, 0) orelse return;
    const active = helpers.getActiveTake(item) orelse return;

    const before = takesOf(alloc, item) catch return;
    defer alloc.free(before);

    Reaper.Undo_BeginBlock();
    defer Reaper.Undo_EndBlock("Paste rhythm to pitches", -1);

    Reaper.Main_OnCommand(cmd_paste_as_takes, 0);

    const after = takesOf(alloc, item) catch return;
    defer alloc.free(after);

    // The pasted takes are the ones that were not there before; the first
    // holds the rhythm. Nothing pasted means the clipboard held no item.
    var rhythm_take: ?*Reaper.MediaItem_Take = null;
    for (after) |t| {
        if (std.mem.indexOfScalar(*Reaper.MediaItem_Take, before, t) == null) {
            rhythm_take = t;
            break;
        }
    }
    const rhythm = rhythm_take orelse return;

    Reaper.SetActiveTake(active);
    applyRhythm(alloc, active, rhythm) catch |err| log.warn("paste rhythm: {s}", .{@errorName(err)});

    for (after) |t| {
        if (std.mem.indexOfScalar(*Reaper.MediaItem_Take, before, t) != null) continue;
        Reaper.SetActiveTake(t);
        Reaper.Main_OnCommand(cmd_delete_active_take, 0);
    }
    Reaper.SetActiveTake(active);
}

pub const entries = [_]actions.Entry{
    .{ .name = "PasteRhythmToPitches", .def = .{
        .steps = &.{.{ .func = &pasteRhythmToPitches }},
        .desc = "Paste rhythm to pitches: the clipboard item's rhythm onto the selected item's notes",
    } },
};

// ---- tests ---------------------------------------------------------------------

fn note(start: f64, end: f64, chan: c_int, pitch: c_int, vel: c_int) Note {
    return .{ .selected = false, .muted = false, .start_ppq = start, .end_ppq = end, .chan = chan, .pitch = pitch, .vel = vel };
}

test "each rhythm position takes the chord playing there, with the rhythm's velocity" {
    const rhythm = [_]Note{ note(0, 240, 0, 60, 100), note(240, 480, 0, 60, 80), note(480, 960, 0, 60, 90) };
    // a chord at 0 and a different one at 480
    const existing = [_]Note{ note(0, 480, 0, 60, 70), note(0, 480, 1, 64, 70), note(480, 960, 0, 67, 70) };
    const out = try pasteRhythm(std.testing.allocator, &rhythm, &existing);
    defer std.testing.allocator.free(out);
    const want = [_]Note{
        note(0, 240, 0, 60, 100),   note(0, 240, 1, 64, 100),
        note(240, 480, 0, 60, 80),  note(240, 480, 1, 64, 80),
        note(480, 960, 0, 67, 90),
    };
    try std.testing.expectEqualSlices(Note, &want, out);
}

test "a chord bigger than the rhythm's note count reuses the last velocity read" {
    const rhythm = [_]Note{ note(0, 240, 0, 60, 100), note(0, 240, 0, 64, 50) };
    const existing = [_]Note{ note(0, 480, 0, 48, 1), note(0, 480, 0, 52, 1), note(0, 480, 0, 55, 1) };
    const out = try pasteRhythm(std.testing.allocator, &rhythm, &existing);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqual(@as(usize, 3), out.len);
    try std.testing.expectEqual(@as(c_int, 100), out[0].vel);
    try std.testing.expectEqual(@as(c_int, 50), out[1].vel);
    try std.testing.expectEqual(@as(c_int, 50), out[2].vel);
}

test "a rhythm position before every chord takes the closest chord after it" {
    const rhythm = [_]Note{note(100, 200, 0, 60, 100)};
    const existing = [_]Note{ note(400, 800, 0, 60, 1), note(1000, 1200, 0, 72, 1) };
    const out = try pasteRhythm(std.testing.allocator, &rhythm, &existing);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualSlices(Note, &.{note(100, 200, 0, 60, 100)}, out);
}

test "the first velocity falls back to the default, and the empty-take placeholder is skipped" {
    const rhythm = [_]Note{ note(0, 0, 0, 60, 100), note(0, 240, 0, 60, 100) };
    const existing = [_]Note{ note(0, 480, 2, 60, 1), note(0, 480, 2, 64, 1) };
    const out = try pasteRhythm(std.testing.allocator, &rhythm, &existing);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqualSlices(Note, &.{ note(0, 240, 2, 60, 100), note(0, 240, 2, 64, 100) }, out);
}

test "nothing to play on gives nothing" {
    const rhythm = [_]Note{note(0, 240, 0, 60, 100)};
    const out = try pasteRhythm(std.testing.allocator, &rhythm, &.{});
    defer std.testing.allocator.free(out);
    try std.testing.expectEqual(@as(usize, 0), out.len);
}
