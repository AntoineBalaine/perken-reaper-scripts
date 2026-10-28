//! Constant-tempo grid from tracked beats: a port of Mixxx's beat
//! post-processing (src/track/beatutils.cpp: retrieveConstRegions,
//! makeConstBpm, roundBpmWithinRange, trySnap, adjustPhase).
//!
//! Mixxx — Copyright (C) Mixxx Development Team, GPL-2.0-or-later
//! (https://github.com/mixxxdj/mixxx). This port works in seconds where
//! Mixxx works in sample frames; the arithmetic is otherwise the same.
//!
//! Why it is needed: qm-dsp's tracker places beats on a grid of analysis
//! steps (about 11.6 ms), so the tempo between two beats jumps between
//! neighbouring values (e.g. 86.1 / 87.6 / 89.1 BPM), and in some passages
//! the tracker may hook onto a beat that is a fraction of the real one (a
//! 4/3 grid in a three-against-four passage). Following Mixxx, the beats
//! are split into the longest regions that fit a constant beat length within
//! an inaudible 25 ms, the longest region near the middle of the track sets
//! the tempo, regions at the same tempo and phase extend it, and the result
//! is rounded to a whole (or simple fractional) BPM when the regions allow.
//! The assumption, in Mixxx's words, is that the track "was recorded with an
//! unhear-able static metronome".
const std = @import("std");

/// The tolerance for ironing a beat onto a constant grid. 25 ms is
/// inaudible, and more than twice the tracker's 12 ms step.
pub const max_phase_error: f64 = 0.025;
/// A region whose errors add up past this in one direction drifts: its mean
/// beat length is wrong (e.g. the beat-giving instrument changed).
pub const max_phase_error_sum: f64 = 0.1;
pub const max_outliers: usize = 1;
/// Regions shorter than this are too unstable to extend the tempo with.
pub const min_region_beats: usize = 16;

pub const ConstRegion = struct {
    /// Time of the region's first beat, in seconds.
    first_beat: f64,
    /// Constant beat length over the region, in seconds; 0 for the final
    /// marker region.
    beat_length: f64,

    pub fn bpm(self: ConstRegion) f64 {
        return if (self.beat_length > 0) 60.0 / self.beat_length else 0;
    }
};

/// Splits beats into regions of constant tempo (Mixxx's
/// retrieveConstRegions). The last region has a zero beat length and marks
/// the end, so region i spans [regions[i].first_beat, regions[i+1].first_beat).
pub fn constRegions(alloc: std.mem.Allocator, beats: []const f64) ![]ConstRegion {
    var regions: std.ArrayList(ConstRegion) = .empty;
    errdefer regions.deinit(alloc);
    if (beats.len < 2) return regions.toOwnedSlice(alloc);

    var left: usize = 0;
    var right: usize = beats.len - 1;
    while (left < beats.len - 1) {
        std.debug.assert(right > left);
        const mean_beat_length = (beats[right] - beats[left]) / @as(f64, @floatFromInt(right - left));
        var outliers: usize = 0;
        var ironed_beat = beats[left];
        var error_sum: f64 = 0;
        var i = left + 1;
        while (i <= right) : (i += 1) {
            ironed_beat += mean_beat_length;
            const phase_error = ironed_beat - beats[i];
            error_sum += phase_error;
            if (@abs(phase_error) > max_phase_error) {
                outliers += 1;
                // The first beat must not be an outlier.
                if (outliers > max_outliers or i == left + 1) break;
            }
            // Drifting away in one direction: the mean beat length is wrong.
            if (@abs(error_sum) > max_phase_error_sum) break;
        }
        if (i > right) {
            // The first and last beats must not both be corrections in the
            // same direction, which would bend the mean beat length.
            var border_error: f64 = 0;
            if (right > left + 2) {
                const first_len = beats[left + 1] - beats[left];
                const last_len = beats[right] - beats[right - 1];
                border_error = @abs(first_len + last_len - 2 * mean_beat_length);
            }
            if (border_error < max_phase_error / 2) {
                try regions.append(alloc, .{ .first_beat = beats[left], .beat_length = mean_beat_length });
                left = right;
                right = beats.len - 1;
                continue;
            }
        }
        // Try a region shorter by one beat.
        right -= 1;
    }
    try regions.append(alloc, .{ .first_beat = beats[beats.len - 1], .beat_length = 0 });
    return regions.toOwnedSlice(alloc);
}

pub const ConstTempo = struct {
    bpm: f64,
    /// A beat of the grid, as close to the start of the audio as possible
    /// (Mixxx's anchor): the grid is first_beat + k * 60 / bpm.
    first_beat: f64,
};

/// Beats per region, rounded as Mixxx does.
pub fn regionBeatCount(length: f64, beat_length: f64) usize {
    return @intFromFloat(length / beat_length + 0.5);
}

/// The constant tempo of the track (Mixxx's makeConstBpm): the longest
/// region sets the tempo, and the earliest and latest regions with a
/// matching tempo and phase extend it, which refines the beat length.
/// Returns null when no tempo can be inferred.
pub fn constTempo(regions: []const ConstRegion) ?ConstTempo {
    if (regions.len < 2) return null;

    var mid: usize = 0;
    var longest_length: f64 = 0;
    var longest_beat_length: f64 = 0;
    for (0..regions.len - 1) |i| {
        const length = regions[i + 1].first_beat - regions[i].first_beat;
        if (length > longest_length) {
            longest_length = length;
            longest_beat_length = regions[i].beat_length;
            mid = i;
        }
    }
    if (longest_length == 0 or longest_beat_length == 0) return null;

    var longest_beats = regionBeatCount(longest_length, longest_beat_length);
    var len_min = longest_beat_length - max_phase_error / @as(f64, @floatFromInt(longest_beats));
    var len_max = longest_beat_length + max_phase_error / @as(f64, @floatFromInt(longest_beats));
    var start: usize = mid;

    // Extend towards the start with a region of similar tempo and phase.
    for (0..mid) |i| {
        if (extendWith(regions, i, regions[mid + 1].first_beat - regions[i].first_beat, longest_beat_length, len_min, len_max)) |ext| {
            longest_beat_length = ext.beat_length;
            longest_beats = ext.beats;
            len_min = longest_beat_length - max_phase_error / @as(f64, @floatFromInt(longest_beats));
            len_max = longest_beat_length + max_phase_error / @as(f64, @floatFromInt(longest_beats));
            start = i;
            break;
        }
    }

    // Extend towards the end the same way.
    var i: usize = regions.len - 2;
    while (i > mid) : (i -= 1) {
        if (extendWith(regions, i, regions[i + 1].first_beat - regions[start].first_beat, longest_beat_length, len_min, len_max)) |ext| {
            longest_beat_length = ext.beat_length;
            longest_beats = ext.beats;
            break;
        }
    }

    len_min = longest_beat_length - max_phase_error / @as(f64, @floatFromInt(longest_beats));
    len_max = longest_beat_length + max_phase_error / @as(f64, @floatFromInt(longest_beats));
    const bpm = roundBpmWithinRange(60.0 / len_max, 60.0 / longest_beat_length, 60.0 / len_min);
    if (!(bpm > 0)) return null;

    // Move the anchor beat as close to the start as possible.
    const rounded_len = 60.0 / bpm;
    return .{ .bpm = bpm, .first_beat = @mod(regions[start].first_beat, rounded_len) };
}

pub const Extension = struct { beat_length: f64, beats: usize };

/// Whether region `i` has the longest region's tempo (within its rounding
/// range) and the same phase over `new_length`; if so, the refined beat
/// length over the combined span.
pub fn extendWith(regions: []const ConstRegion, i: usize, new_length: f64, longest_beat_length: f64, len_min: f64, len_max: f64) ?Extension {
    const length = regions[i + 1].first_beat - regions[i].first_beat;
    if (regions[i].beat_length <= 0) return null;
    const beats = regionBeatCount(length, regions[i].beat_length);
    if (beats < min_region_beats) return null; // too unstable
    const this_min = regions[i].beat_length - max_phase_error / @as(f64, @floatFromInt(beats));
    const this_max = regions[i].beat_length + max_phase_error / @as(f64, @floatFromInt(beats));
    if (!(longest_beat_length > this_min and longest_beat_length < this_max)) return null;

    // Same phase: the combined span must hold an unambiguous whole number of
    // beats.
    const beat_min = @max(len_min, this_min);
    const beat_max = @min(len_max, this_max);
    const max_beats: i64 = @intFromFloat(@round(new_length / beat_min));
    const min_beats: i64 = @intFromFloat(@round(new_length / beat_max));
    if (min_beats != max_beats or min_beats <= 0) return null;
    const new_beat_length = new_length / @as(f64, @floatFromInt(min_beats));
    if (!(new_beat_length > len_min and new_beat_length < len_max)) return null;
    return .{ .beat_length = new_beat_length, .beats = @intCast(min_beats) };
}

/// `center` snapped to a multiple of 1/fraction BPM, when that stays
/// strictly within (min, max) (Mixxx's trySnap).
pub fn trySnap(min: f64, center: f64, max: f64, fraction: f64) ?f64 {
    const snap = @round(center * fraction) / fraction;
    if (snap > min and snap < max) return snap;
    return null;
}

/// Rounds a tempo to the simplest value the measurement allows (Mixxx's
/// roundBpmWithinRange): a whole BPM, then half BPM below 85, then 2/3 above
/// 127, then thirds, then twelfths; otherwise the measured value.
pub fn roundBpmWithinRange(min: f64, center: f64, max: f64) f64 {
    if (!(min > 0 and center > 0 and max > 0)) return center;
    if (trySnap(min, center, max, 1.0)) |s| return s;
    if (center < 85.0) {
        if (trySnap(min, center, max, 2.0)) |s| return s;
    }
    if (center > 127.0) {
        if (trySnap(min, center, max, 2.0 / 3.0)) |s| return s;
    }
    if (trySnap(min, center, max, 3.0)) |s| return s;
    if (trySnap(min, center, max, 12.0)) |s| return s;
    return center;
}

/// Shifts the grid's anchor by the average offset of the beats that lie
/// within 25 ms of the grid (Mixxx's adjustPhase).
pub fn adjustPhase(first_beat: f64, bpm: f64, beats: []const f64) f64 {
    if (!(bpm > 0)) return first_beat;
    const beat_length = 60.0 / bpm;
    const start_offset = @mod(first_beat, beat_length);
    var adjust: f64 = 0;
    var count: f64 = 0;
    for (beats) |b| {
        var offset = @mod(b - start_offset, beat_length);
        if (offset > beat_length / 2) offset -= beat_length;
        if (@abs(offset) < max_phase_error) {
            adjust += offset;
            count += 1;
        }
    }
    if (count == 0) return first_beat;
    return first_beat + adjust / count;
}

pub const Grid = struct {
    /// The constant tempo and its phase, when one could be inferred.
    tempo: ?ConstTempo,
    /// The regions of constant tempo, for variable-tempo material (the last
    /// one marks the end).
    regions: []ConstRegion,

    pub fn deinit(self: *Grid, alloc: std.mem.Allocator) void {
        alloc.free(self.regions);
    }
};

/// The full post-processing: regions, then the constant tempo and its
/// phase-adjusted anchor. With fewer beats than a region needs, the tempo is
/// the average over all beats (Mixxx's calculateBpm).
pub fn analyze(alloc: std.mem.Allocator, beats: []const f64) !Grid {
    const regions = try constRegions(alloc, beats);
    errdefer alloc.free(regions);
    var tempo: ?ConstTempo = null;
    if (beats.len >= 2 and beats.len < min_region_beats) {
        const span = beats[beats.len - 1] - beats[0];
        if (span > 0) tempo = .{ .bpm = 60.0 * @as(f64, @floatFromInt(beats.len - 1)) / span, .first_beat = beats[0] };
    } else if (constTempo(regions)) |t| {
        tempo = .{ .bpm = t.bpm, .first_beat = adjustPhase(t.first_beat, t.bpm, beats) };
    }
    return .{ .tempo = tempo, .regions = regions };
}

/// A beat of the constant grid, numbered by bar and beat.
pub const GridBeat = struct {
    time: f64,
    /// 0 for a pickup before the first full bar.
    bar: u32,
    /// 1 for the first beat of a bar.
    beat_in_bar: u32,
};

/// The grid's beats from the anchor to `duration`, numbered so that bar 1
/// starts on the grid beat most of the tracker's downbeats agree with: each
/// downbeat within 25 ms of a grid beat votes for that beat's position
/// modulo the bar length.
pub fn gridBeats(alloc: std.mem.Allocator, tempo: ConstTempo, duration: f64, beats_per_bar: u32, downbeats: []const f64) ![]GridBeat {
    const period = 60.0 / tempo.bpm;
    const bpb: usize = @max(1, beats_per_bar);
    const votes = try alloc.alloc(u32, bpb);
    defer alloc.free(votes);
    @memset(votes, 0);
    for (downbeats) |d| {
        const k = @round((d - tempo.first_beat) / period);
        if (k < 0) continue;
        if (@abs(d - (tempo.first_beat + k * period)) > max_phase_error) continue;
        votes[@as(usize, @intFromFloat(k)) % bpb] += 1;
    }
    var downbeat_slot: usize = 0;
    for (votes, 0..) |v, i| {
        if (v > votes[downbeat_slot]) downbeat_slot = i;
    }

    var list: std.ArrayList(GridBeat) = .empty;
    errdefer list.deinit(alloc);
    var k: usize = 0;
    while (true) : (k += 1) {
        const t = tempo.first_beat + @as(f64, @floatFromInt(k)) * period;
        if (t > duration) break;
        if (k < downbeat_slot) {
            try list.append(alloc, .{ .time = t, .bar = 0, .beat_in_bar = @intCast(bpb - downbeat_slot + k + 1) });
        } else {
            const n = k - downbeat_slot;
            try list.append(alloc, .{ .time = t, .bar = @intCast(n / bpb + 1), .beat_in_bar = @intCast(n % bpb + 1) });
        }
    }
    return list.toOwnedSlice(alloc);
}

/// A stretch where the tracker's beats do not follow the constant grid.
pub const Passage = struct { start: f64, end: f64, bpm: f64 };

/// Consecutive regions whose tempo is more than `tolerance` away from the
/// grid's, merged into passages, with their duration-weighted tempo.
pub fn offGridPassages(alloc: std.mem.Allocator, regions: []const ConstRegion, grid_bpm: f64, tolerance: f64) ![]Passage {
    var list: std.ArrayList(Passage) = .empty;
    errdefer list.deinit(alloc);
    if (regions.len < 2 or !(grid_bpm > 0)) return list.toOwnedSlice(alloc);
    var open: ?Passage = null;
    var weighted: f64 = 0;
    for (0..regions.len - 1) |i| {
        const r = regions[i];
        const end = regions[i + 1].first_beat;
        const off = r.beat_length > 0 and @abs(r.bpm() - grid_bpm) / grid_bpm > tolerance;
        if (off) {
            if (open) |*o| {
                o.end = end;
            } else {
                open = .{ .start = r.first_beat, .end = end, .bpm = 0 };
                weighted = 0;
            }
            weighted += r.bpm() * (end - r.first_beat);
        } else if (open) |o| {
            try list.append(alloc, .{ .start = o.start, .end = o.end, .bpm = weighted / (o.end - o.start) });
            open = null;
        }
    }
    if (open) |o| try list.append(alloc, .{ .start = o.start, .end = o.end, .bpm = weighted / (o.end - o.start) });
    return list.toOwnedSlice(alloc);
}

// ---- tests ----

/// Beats of a steady tempo as the tracker reports them: each one rounded to
/// its ~11.6 ms analysis step, which makes neighbouring intervals differ.
pub fn quantizedBeats(alloc: std.mem.Allocator, bpm: f64, count: usize, offset: f64) ![]f64 {
    const step = 256.0 / 22050.0;
    const beats = try alloc.alloc(f64, count);
    for (beats, 0..) |*b, i| {
        const t = offset + @as(f64, @floatFromInt(i)) * 60.0 / bpm;
        b.* = @floor(t / step) * step;
    }
    return beats;
}

test "quantized beats of a whole-BPM tempo are ironed back to that tempo" {
    const alloc = std.testing.allocator;
    for ([_]f64{ 88, 120, 128, 96 }) |bpm| {
        const beats = try quantizedBeats(alloc, bpm, 300, 0.3);
        defer alloc.free(beats);
        var g = try analyze(alloc, beats);
        defer g.deinit(alloc);
        try std.testing.expectEqual(bpm, g.tempo.?.bpm);
        // The anchor lies on the grid of the real beats (within 25 ms).
        const period = 60.0 / bpm;
        const off = @mod(g.tempo.?.first_beat - 0.3, period);
        try std.testing.expect(@min(off, period - off) < 0.025);
    }
}

test "a section on a 4/3 grid does not change the tempo" {
    const alloc = std.testing.allocator;
    var list: std.ArrayList(f64) = .empty;
    defer list.deinit(alloc);
    const step = 256.0 / 22050.0;
    var t: f64 = 0.3;
    // 120 beats at 88 BPM, 40 beats at 4/3 of that, then 120 at 88 again.
    for (0..120) |_| {
        try list.append(alloc, @floor(t / step) * step);
        t += 60.0 / 88.0;
    }
    for (0..40) |_| {
        try list.append(alloc, @floor(t / step) * step);
        t += 60.0 / (88.0 * 4.0 / 3.0);
    }
    for (0..120) |_| {
        try list.append(alloc, @floor(t / step) * step);
        t += 60.0 / 88.0;
    }
    var g = try analyze(alloc, list.items);
    defer g.deinit(alloc);
    try std.testing.expectEqual(@as(f64, 88), g.tempo.?.bpm);
    // The regions show the 4/3 section separately.
    var saw_fast = false;
    for (g.regions) |r| {
        if (r.beat_length > 0 and @abs(r.bpm() - 88.0 * 4.0 / 3.0) < 2) saw_fast = true;
    }
    try std.testing.expect(saw_fast);
}

test "roundBpmWithinRange prefers whole, then half, then thirds" {
    try std.testing.expectEqual(@as(f64, 120), roundBpmWithinRange(119.8, 120.1, 120.3));
    try std.testing.expectEqual(@as(f64, 83.5), roundBpmWithinRange(83.4, 83.48, 83.6));
    try std.testing.expectApproxEqAbs(@as(f64, 100.0 + 1.0 / 3.0), roundBpmWithinRange(100.3, 100.33, 100.36), 1e-9);
    try std.testing.expectEqual(@as(f64, 101.2345), roundBpmWithinRange(101.2340, 101.2345, 101.2350));
}

test "few beats: the average tempo" {
    const alloc = std.testing.allocator;
    const beats = [_]f64{ 0, 0.5, 1.0, 1.5, 2.0 };
    var g = try analyze(alloc, &beats);
    defer g.deinit(alloc);
    try std.testing.expectApproxEqAbs(@as(f64, 120), g.tempo.?.bpm, 1e-9);
}

test "gridBeats numbers bars from the downbeats' majority" {
    const alloc = std.testing.allocator;
    const tempo = ConstTempo{ .bpm = 120, .first_beat = 0.1 };
    // Downbeats on grid beats 2, 6, 10 (and one stray vote on 3).
    const downbeats = [_]f64{ 0.1 + 2 * 0.5, 0.1 + 6 * 0.5 + 0.01, 0.1 + 10 * 0.5, 0.1 + 3 * 0.5 };
    const beats = try gridBeats(alloc, tempo, 6.0, 4, &downbeats);
    defer alloc.free(beats);
    try std.testing.expectEqual(@as(u32, 0), beats[0].bar); // pickup
    try std.testing.expectEqual(@as(u32, 3), beats[0].beat_in_bar);
    try std.testing.expectEqual(@as(u32, 1), beats[2].bar);
    try std.testing.expectEqual(@as(u32, 1), beats[2].beat_in_bar);
    try std.testing.expectEqual(@as(u32, 2), beats[6].bar);
    try std.testing.expectEqual(@as(u32, 1), beats[6].beat_in_bar);
}

test "offGridPassages merges neighbouring off-tempo regions" {
    const alloc = std.testing.allocator;
    const regions = [_]ConstRegion{
        .{ .first_beat = 0, .beat_length = 60.0 / 88.0 },
        .{ .first_beat = 100, .beat_length = 60.0 / 122.0 },
        .{ .first_beat = 110, .beat_length = 60.0 / 118.0 },
        .{ .first_beat = 130, .beat_length = 60.0 / 88.0 },
        .{ .first_beat = 200, .beat_length = 0 },
    };
    const p = try offGridPassages(alloc, &regions, 88, 0.05);
    defer alloc.free(p);
    try std.testing.expectEqual(@as(usize, 1), p.len);
    try std.testing.expectEqual(@as(f64, 100), p[0].start);
    try std.testing.expectEqual(@as(f64, 130), p[0].end);
    try std.testing.expect(p[0].bpm > 118 and p[0].bpm < 122);
}
