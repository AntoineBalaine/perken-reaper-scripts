//! Committing a tempo analysis to the project, in either direction:
//!
//! - `setProjectTempo`: the grid follows the audio. The project tempo is set
//!   to the detected tempo; the audio is not touched.
//! - `conformToGrid`: the audio follows the grid. Stretch markers are put on
//!   the detected grid's beats and moved onto the project's beats, so that
//!   REAPER stretches the take until bar 1 sits on a bar line and every beat
//!   on a project beat. The project tempo is not touched.
//!
//! Both are refused, with an explanation, where the intent would be
//! ambiguous (existing tempo markers, existing stretch markers), rather than
//! guessing. Main thread only.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const grid = @import("grid.zig");

const log = std.log.scoped(.beat);

pub const CommitError = error{ TakeDeleted, HasTempoMarkers, HasStretchMarkers, NoDownbeat, NoBeats };

/// The message shown in the window for a refused commit.
pub fn errorText(err: CommitError) [:0]const u8 {
    return switch (err) {
        error.TakeDeleted => "The analysed item no longer exists.",
        error.HasTempoMarkers => "The project has tempo markers, so which tempo to change is ambiguous. Remove them or edit them by hand.",
        error.HasStretchMarkers => "The take already has stretch markers. Remove them first, so that none of yours are overwritten.",
        error.NoDownbeat => "No bar 1 was found in the grid.",
        error.NoBeats => "The grid has no beats.",
    };
}

// ---- REAPER calls that take NULL for the current project ----
// reaziglib binds these with a non-optional project pointer; re-typing the
// loaded function pointer keeps the ABI and lets us pass null.

pub fn countTempoMarkers() c_int {
    const f: *const fn (proj: ?*anyopaque) callconv(.C) c_int = @ptrCast(Reaper.CountTempoTimeSigMarkers);
    return f(null);
}

pub fn setCurrentBpm(bpm: f64) void {
    const f: *const fn (proj: ?*anyopaque, bpm: f64, want_undo: bool) callconv(.C) void = @ptrCast(Reaper.SetCurrentBPM);
    f(null, bpm, false);
}

pub fn timeToQn(t: f64) f64 {
    const f: *const fn (proj: ?*anyopaque, tpos: f64) callconv(.C) f64 = @ptrCast(Reaper.TimeMap2_timeToQN);
    return f(null, t);
}

pub fn qnToTime(qn: f64) f64 {
    const f: *const fn (proj: ?*anyopaque, qn: f64) callconv(.C) f64 = @ptrCast(Reaper.TimeMap2_QNToTime);
    return f(null, qn);
}

/// The time of the project's bar line nearest to `t`.
pub fn nearestBarLine(t: f64) f64 {
    const to_beats: *const fn (proj: ?*anyopaque, tpos: f64, measures: ?*c_int, cml: ?*c_int, fullbeats: ?*f64, cdenom: ?*c_int) callconv(.C) f64 = @ptrCast(Reaper.TimeMap2_timeToBeats);
    const to_time: *const fn (proj: ?*anyopaque, tpos: f64, measures: ?*const c_int) callconv(.C) f64 = @ptrCast(Reaper.TimeMap2_beatsToTime);
    var measure: c_int = 0;
    _ = to_beats(null, t, &measure, null, null, null);
    const this_bar = to_time(null, 0, &measure);
    const next_measure = measure + 1;
    const next_bar = to_time(null, 0, &next_measure);
    return if (t - this_bar <= next_bar - t) this_bar else next_bar;
}

/// The project time of an item-relative time of the analysed take.
pub const TakeTiming = struct {
    item: *Reaper.MediaItem,
    position: f64,
    length: f64,
    start_offset: f64,
    rate: f64,
};

pub fn takeTiming(take: *Reaper.MediaItem_Take) TakeTiming {
    const item = Reaper.GetMediaItemTake_Item(take);
    return .{
        .item = item,
        .position = Reaper.GetMediaItemInfo_Value(item, "D_POSITION"),
        .length = Reaper.GetMediaItemInfo_Value(item, "D_LENGTH"),
        .start_offset = Reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS"),
        .rate = Reaper.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE"),
    };
}

/// Sets the project tempo to `bpm` (the grid follows the audio). The
/// analysed item is switched to time-based positioning for the change and
/// restored afterwards, so that its audio neither moves nor stretches even
/// when its timebase is beats.
pub fn setProjectTempo(take: *Reaper.MediaItem_Take, bpm: f64) CommitError!void {
    if (countTempoMarkers() > 0) return error.HasTempoMarkers;
    const item = Reaper.GetMediaItemTake_Item(take);
    Reaper.Undo_BeginBlock();
    const timebase = Reaper.GetMediaItemInfo_Value(item, "C_BEATATTACHMODE");
    _ = Reaper.SetMediaItemInfo_Value(item, "C_BEATATTACHMODE", 0); // time
    setCurrentBpm(bpm);
    _ = Reaper.SetMediaItemInfo_Value(item, "C_BEATATTACHMODE", timebase);
    Reaper.Undo_EndBlock("Cajun: set project tempo to the detected tempo", -1);
    Reaper.UpdateTimeline();
    Reaper.UpdateArrange();
    log.info("project tempo set to {d:.3} BPM", .{bpm});
}

/// Index of the grid's first beat of bar 1.
pub fn firstDownbeat(beats: []const grid.GridBeat) ?usize {
    for (beats, 0..) |b, i| {
        if (b.bar == 1 and b.beat_in_bar == 1) return i;
    }
    return null;
}

/// Stretches the take onto the project's grid (the audio follows the grid).
/// Beat `d` of the detected grid (bar 1) is pinned to the nearest project
/// bar line, and every other grid beat to the project beat (quarter note)
/// the same number of beats away. The item moves so that its first marker
/// lands without stretching the audio before it, and its length changes so
/// that the audio after the last marker is kept whole.
/// `analysis_start` is the time of item-relative 0 in the analysis (the
/// audio accessor's start time).
pub fn conformToGrid(take: *Reaper.MediaItem_Take, analysis_start: f64, beats: []const grid.GridBeat) CommitError!void {
    if (beats.len == 0) return error.NoBeats;
    if (Reaper.GetTakeNumStretchMarkers(take) > 0) return error.HasStretchMarkers;
    const d = firstDownbeat(beats) orelse return error.NoDownbeat;
    const timing = takeTiming(take);

    const downbeat_now = timing.position + analysis_start + beats[d].time;
    const downbeat_qn = timeToQn(nearestBarLine(downbeat_now));

    // Move the item so that the first beat lands on its target exactly:
    // the audio before the first marker then keeps its speed.
    const first_target = qnToTime(downbeat_qn - @as(f64, @floatFromInt(d)));
    const first_now = timing.position + analysis_start + beats[0].time;
    const new_position = timing.position + (first_target - first_now);

    Reaper.Undo_BeginBlock();
    _ = Reaper.SetMediaItemInfo_Value(timing.item, "D_POSITION", new_position);
    var last_pos: f64 = 0;
    var last_src_time: f64 = 0;
    for (beats, 0..) |b, k| {
        const qn = downbeat_qn + @as(f64, @floatFromInt(@as(i64, @intCast(k)) - @as(i64, @intCast(d))));
        const pos = qnToTime(qn) - new_position;
        const item_rel = analysis_start + b.time;
        const srcpos = timing.start_offset + item_rel * timing.rate;
        _ = Reaper.SetTakeStretchMarker(take, -1, pos, &srcpos);
        last_pos = pos;
        last_src_time = item_rel;
    }
    // Keep the audio after the last marker whole: it plays at the item's
    // rate, so its duration in the item is unchanged.
    _ = Reaper.SetMediaItemInfo_Value(timing.item, "D_LENGTH", last_pos + (timing.length - last_src_time));
    Reaper.Undo_EndBlock("Cajun: stretch the audio onto the project grid", -1);
    Reaper.UpdateArrange();
    log.info("{d} stretch markers put on the project grid", .{beats.len});
}

test "firstDownbeat finds bar 1, beat 1" {
    const beats = [_]grid.GridBeat{
        .{ .time = 0, .bar = 0, .beat_in_bar = 3 },
        .{ .time = 0.5, .bar = 0, .beat_in_bar = 4 },
        .{ .time = 1.0, .bar = 1, .beat_in_bar = 1 },
    };
    try std.testing.expectEqual(@as(?usize, 2), firstDownbeat(&beats));
    try std.testing.expectEqual(@as(?usize, null), firstDownbeat(beats[0..2]));
}
