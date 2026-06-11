//! Shared helpers for the ported custom_actions modules — the Zig port of the
//! parts of reavim's custom_actions/utils.lua (plus utils/reaper_state.lua)
//! that the ported action modules need, plus the envelope value-range helper
//! (envelope.lua's getEnvelopeRange/getEnvelopeMinMaxValues) and the MIDI
//! notes snapshot (midi.listNotes + the MIDI_GetNote loops).
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

pub const TimeRange = struct { start: f64, end_: f64 };

/// Read the current time selection (GetSet_LoopTimeRange2 with isSet=false in
/// the Lua; the project-less variant is the same call for the current project).
pub fn getTimeSelection() TimeRange {
    var s: f64 = 0;
    var e: f64 = 0;
    Reaper.GetSet_LoopTimeRange(false, false, &s, &e, false);
    return .{ .start = s, .end_ = e };
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

// ---- envelopes ----------------------------------------------------------------

/// GetSelectedEnvelope returns NULL when no envelope is selected and takes
/// NULL for "current project"; the binding types both as non-optional.
pub fn getSelectedEnvelope() ?*Reaper.TrackEnvelope {
    const f: *const fn (proj: ?*Reaper.ReaProject) callconv(.C) ?*Reaper.TrackEnvelope = @ptrCast(Reaper.GetSelectedEnvelope);
    return f(null);
}

/// Native replacement for SWS SNM_GetIntConfigVar: read an int-sized config
/// variable via the raw get_config_var API (which Lua cannot dereference —
/// the only reason the original needed SWS).
pub fn getIntConfigVar(name: [*:0]const u8, fallback: c_int) c_int {
    const f: *const fn (name: [*:0]const u8, szOut: *c_int) callconv(.C) ?*anyopaque = @ptrCast(Reaper.get_config_var);
    var sz: c_int = 0;
    const p = f(name, &sz) orelse return fallback;
    if (sz != @sizeOf(c_int)) return fallback;
    const ip: *align(1) const c_int = @ptrCast(p);
    return ip.*;
}

pub const EnvelopeRange = struct { min: f64, max: f64, center: f64 };

const ChunkEnvKind = union(enum) {
    fixed: EnvelopeRange,
    volenv,
    pitchenv,
    tempoenv,
};

/// Sniff the envelope type from the first state-chunk line and resolve the
/// per-type value range (envelope.lua getEnvelopeRange, by Cfillion). PARMENV
/// carries min/max/center inline; vol/pitch/tempo need config vars (resolved
/// by the caller so this stays pure/testable).
fn classifyEnvelopeChunk(chunk: []const u8) ?ChunkEnvKind {
    if (chunk.len < 2 or chunk[0] != '<') return null;
    const line_end = std.mem.indexOfScalar(u8, chunk, '\n') orelse chunk.len;
    var tokens = std.mem.tokenizeAny(u8, chunk[0..line_end], " \t\r");
    const tag = tokens.next() orelse return null;
    const env_type = tag[1..];

    if (std.mem.indexOf(u8, env_type, "PARMENV") != null) {
        _ = tokens.next() orelse return null; // param ident
        const min = std.fmt.parseFloat(f64, tokens.next() orelse return null) catch return null;
        const max = std.fmt.parseFloat(f64, tokens.next() orelse return null) catch return null;
        const center = std.fmt.parseFloat(f64, tokens.next() orelse return null) catch return null;
        return .{ .fixed = .{ .min = min, .max = max, .center = center } };
    }
    // Substring match like the Lua (VOLENV also catches AUXVOLENV/VOLENV2).
    if (std.mem.indexOf(u8, env_type, "VOLENV") != null) return .volenv;
    if (std.mem.indexOf(u8, env_type, "PANENV") != null) return .{ .fixed = .{ .min = -1, .max = 1, .center = 0 } };
    if (std.mem.indexOf(u8, env_type, "WIDTHENV") != null) return .{ .fixed = .{ .min = -1, .max = 1, .center = 0 } };
    if (std.mem.indexOf(u8, env_type, "MUTEENV") != null) return .{ .fixed = .{ .min = 0, .max = 1, .center = 0.5 } };
    if (std.mem.indexOf(u8, env_type, "SPEEDENV") != null) return .{ .fixed = .{ .min = 0.1, .max = 4, .center = 1 } };
    if (std.mem.indexOf(u8, env_type, "PITCHENV") != null) return .pitchenv;
    if (std.mem.indexOf(u8, env_type, "TEMPOENV") != null) return .tempoenv;
    return null;
}

/// Min/max/center of an envelope in raw envelope units, with fader scaling
/// applied (envelope.lua getEnvelopeMinMaxValues). Null on unknown envelope
/// types (where the Lua error()'d). Only the chunk header is needed, so a
/// truncating read into a fixed buffer is fine.
pub fn envelopeRange(env: *Reaper.TrackEnvelope) ?EnvelopeRange {
    var buf: [4096]u8 = undefined;
    buf[0] = 0;
    if (!Reaper.GetEnvelopeStateChunk(env, @ptrCast(&buf), buf.len, false)) return null;
    const kind = classifyEnvelopeChunk(std.mem.sliceTo(&buf, 0)) orelse {
        log.warn("unknown envelope type — cannot determine value range", .{});
        return null;
    };
    var range: EnvelopeRange = switch (kind) {
        .fixed => |r| r,
        .volenv => blk: {
            const max: f64 = switch (getIntConfigVar("volenvrange", 0)) {
                1, 3 => 1,
                0, 2 => 2,
                4, 6 => 4,
                5, 7 => 16,
                else => 2,
            };
            break :blk .{ .min = 0, .max = max, .center = if (max == 1) 0.5 else 1 };
        },
        .pitchenv => blk: {
            const semis: f64 = @floatFromInt(getIntConfigVar("pitchenvrange", 0) & 0x0F);
            break :blk .{ .min = -semis, .max = semis, .center = 0 };
        },
        .tempoenv => blk: {
            const min: f64 = @floatFromInt(getIntConfigVar("tempoenvmin", 0));
            const max: f64 = @floatFromInt(getIntConfigVar("tempoenvmax", 0));
            break :blk .{ .min = min, .max = max, .center = (max + min) / 2 };
        },
    };
    if (Reaper.GetEnvelopeScalingMode(env) == 1) {
        range = .{
            .min = Reaper.ScaleToEnvelopeMode(1, range.min),
            .max = Reaper.ScaleToEnvelopeMode(1, range.max),
            .center = Reaper.ScaleToEnvelopeMode(1, range.center),
        };
    }
    return range;
}

// ---- MIDI notes snapshot ------------------------------------------------------

pub const Note = struct {
    selected: bool,
    muted: bool,
    start_ppq: f64,
    end_ppq: f64,
    chan: c_int,
    pitch: c_int,
    vel: c_int,
};

/// Snapshot every note of a take — midi.listNotes plus the per-action
/// MIDI_GetNote loops of midi.lua (and later kawa.lua/pasteRhythm.lua),
/// ported once.
pub fn collectNotes(alloc: std.mem.Allocator, take: *Reaper.MediaItem_Take) ![]Note {
    var n_notes: c_int = 0;
    var n_cc: c_int = 0;
    var n_sysex: c_int = 0;
    _ = Reaper.MIDI_CountEvts(take, &n_notes, &n_cc, &n_sysex);

    var list = std.ArrayList(Note).init(alloc);
    errdefer list.deinit();
    var i: c_int = 0;
    while (i < n_notes) : (i += 1) {
        var n: Note = undefined;
        if (!Reaper.MIDI_GetNote(take, i, &n.selected, &n.muted, &n.start_ppq, &n.end_ppq, &n.chan, &n.pitch, &n.vel))
            continue;
        try list.append(n);
    }
    return list.toOwnedSlice();
}

/// GetActiveTake returns NULL for items without takes; the binding's return
/// type is non-optional, so re-type it.
pub fn getActiveTake(item: *Reaper.MediaItem) ?*Reaper.MediaItem_Take {
    const f: *const fn (item: *Reaper.MediaItem) callconv(.C) ?*Reaper.MediaItem_Take = @ptrCast(Reaper.GetActiveTake);
    return f(item);
}

// ---- chord grouping (kawa.lua get_chords/sort_chords) -------------------------

/// Note in project-QN domain carrying its REAPER note index — kawa.lua's
/// KawaNote (minus the redundant take/length fields).
pub const QnNote = struct {
    idx: c_int,
    selected: bool,
    muted: bool,
    start_qn: f64,
    end_qn: f64,
    chan: c_int,
    pitch: c_int,
    vel: c_int,
};

fn chordLessThan(_: void, a: QnNote, b: QnNote) bool {
    if (a.start_qn == b.start_qn) return a.pitch > b.pitch;
    return a.start_qn < b.start_qn;
}

/// Sort notes into chord order: start QN ascending, pitch descending within a
/// chord. Replaces kawa's get_chords (which keyed a Lua table by the exact
/// startQn float — so exact == grouping is faithful) plus sort_chords.
pub fn sortChordOrder(notes: []QnNote) void {
    std.mem.sort(QnNote, notes, {}, chordLessThan);
}

/// Iterator over the chords (runs of equal start QN) of a chord-ordered
/// slice. Each yielded chord is pitch-descending: [0] is the top note,
/// [len-1] the bottom; yielded slices are never empty.
pub const ChordIterator = struct {
    notes: []const QnNote,
    i: usize = 0,

    pub fn next(self: *ChordIterator) ?[]const QnNote {
        if (self.i >= self.notes.len) return null;
        const start = self.i;
        while (self.i < self.notes.len and self.notes[self.i].start_qn == self.notes[start].start_qn)
            self.i += 1;
        return self.notes[start..self.i];
    }
};

pub fn chords(notes: []const QnNote) ChordIterator {
    return .{ .notes = notes };
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

test "classifyEnvelopeChunk parses PARMENV header ranges" {
    const chunk = "<PARMENV 0:wet 0 1 0.25\nACT 1 -1\nVIS 1 1 1\n>";
    const kind = classifyEnvelopeChunk(chunk).?;
    try std.testing.expectEqual(EnvelopeRange{ .min = 0, .max = 1, .center = 0.25 }, kind.fixed);
}

test "classifyEnvelopeChunk maps built-in envelope types" {
    try std.testing.expectEqual(ChunkEnvKind.volenv, classifyEnvelopeChunk("<VOLENV2\nACT 1\n>").?);
    try std.testing.expectEqual(ChunkEnvKind.volenv, classifyEnvelopeChunk("<AUXVOLENV\n>").?);
    try std.testing.expectEqual(ChunkEnvKind.pitchenv, classifyEnvelopeChunk("<PITCHENV\n>").?);
    try std.testing.expectEqual(ChunkEnvKind.tempoenv, classifyEnvelopeChunk("<TEMPOENVEX\n>").?);
    try std.testing.expectEqual(
        EnvelopeRange{ .min = -1, .max = 1, .center = 0 },
        classifyEnvelopeChunk("<PANENV2\n>").?.fixed,
    );
    try std.testing.expectEqual(
        EnvelopeRange{ .min = 0, .max = 1, .center = 0.5 },
        classifyEnvelopeChunk("<MUTEENV\n>").?.fixed,
    );
}

test "classifyEnvelopeChunk rejects garbage" {
    try std.testing.expect(classifyEnvelopeChunk("") == null);
    try std.testing.expect(classifyEnvelopeChunk("TRACK 1") == null);
    try std.testing.expect(classifyEnvelopeChunk("<WHATENV\n>") == null);
    // PARMENV with a malformed header must not leak tokens from later lines
    try std.testing.expect(classifyEnvelopeChunk("<PARMENV 0:wet\n0 1 0.5\n>") == null);
}

test "sortChordOrder + chords groups by exact startQn, pitch descending" {
    const mk = struct {
        fn n(idx: c_int, start: f64, pitch: c_int) QnNote {
            return .{ .idx = idx, .selected = false, .muted = false, .start_qn = start, .end_qn = start + 1, .chan = 0, .pitch = pitch, .vel = 100 };
        }
    };
    // Two chords plus a lone note, deliberately shuffled.
    var notes = [_]QnNote{
        mk.n(0, 2.0, 64),
        mk.n(1, 0.5, 60),
        mk.n(2, 0.5, 72),
        mk.n(3, 2.0, 67),
        mk.n(4, 4.25, 48),
        mk.n(5, 0.5, 67),
    };
    sortChordOrder(&notes);

    var it = chords(&notes);
    const c1 = it.next().?;
    try std.testing.expectEqual(@as(usize, 3), c1.len);
    try std.testing.expectEqual(@as(c_int, 72), c1[0].pitch); // top
    try std.testing.expectEqual(@as(c_int, 67), c1[1].pitch);
    try std.testing.expectEqual(@as(c_int, 60), c1[2].pitch); // bottom
    const c2 = it.next().?;
    try std.testing.expectEqual(@as(usize, 2), c2.len);
    try std.testing.expectEqual(@as(c_int, 67), c2[0].pitch);
    const c3 = it.next().?;
    try std.testing.expectEqual(@as(usize, 1), c3.len);
    try std.testing.expectEqual(@as(c_int, 4), c3[0].idx);
    try std.testing.expectEqual(@as(?[]const QnNote, null), it.next());
}

test "chords iterator on empty slice" {
    var it = chords(&.{});
    try std.testing.expectEqual(@as(?[]const QnNote, null), it.next());
}

test "getTrackIndex is the 1-based number minus one" {
    try std.testing.expectEqual(@as(?c_int, 4), getTrackIndex(5));
    try std.testing.expectEqual(@as(?c_int, 0), getTrackIndex(1));
    try std.testing.expectEqual(@as(?c_int, null), getTrackIndex(0)); // not found
    try std.testing.expectEqual(@as(?c_int, null), getTrackIndex(-1)); // master
}
