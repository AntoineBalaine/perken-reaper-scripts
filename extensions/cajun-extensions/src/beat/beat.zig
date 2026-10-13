//! Beat and tempo detection: the Zig side of qm-dsp's bar and beat tracker
//! (qm_bridge.cpp, compiled with REAPER's toolchain).
//!
//! `track` analyses mono audio and returns the beat positions, which beats
//! start a bar, and the tempo between consecutive beats. Because the tempo is
//! reported per beat, material whose tempo drifts gives a tempo curve rather
//! than a single number; `medianTempo` summarises steady material.
const std = @import("std");

pub const Params = extern struct {
    /// Tempo the beat-period estimate is biased towards, in BPM.
    input_tempo: f64 = 120.0,
    /// Keep the beat period near input_tempo (when half or double tempo
    /// would otherwise be picked).
    constrain_tempo: c_int = 0,
    /// Beat tracking smoothness and tightness, qm-dsp's plugin defaults.
    alpha: f64 = 0.9,
    tightness: f64 = 4.0,
    /// Beats per bar for downbeat detection.
    beats_per_bar: c_int = 4,
};

pub const CResult = extern struct {
    beat_times: ?[*]f64,
    beat_count: usize,
    downbeats: ?[*]c_int,
    downbeat_count: usize,
    @"error": [160]u8,
};

pub extern fn cajun_beat_track(mono: [*]const f32, frames: usize, sample_rate: f64, params: *const Params, result: *CResult) c_int;
pub extern fn cajun_beat_result_free(result: *CResult) void;

pub const Beat = struct {
    /// Position in seconds from the start of the analysed audio.
    time: f64,
    /// 1 for the first beat of a bar, then 2, 3, ...; 0 before the first
    /// detected downbeat.
    beat_in_bar: u32,
    /// Tempo in BPM from this beat to the next one; for the last beat, the
    /// tempo from the previous beat.
    tempo: f64,
};

pub const Result = struct {
    beats: []Beat,

    pub fn deinit(self: *Result, alloc: std.mem.Allocator) void {
        alloc.free(self.beats);
    }
};

pub const TrackError = error{ AnalysisFailed, OutOfMemory };

/// Tracks the beats of mono audio. On failure, the bridge's message is
/// logged.
pub fn track(alloc: std.mem.Allocator, mono: []const f32, sample_rate: f64, params: Params) TrackError!Result {
    var c: CResult = undefined;
    defer cajun_beat_result_free(&c);
    if (cajun_beat_track(mono.ptr, mono.len, sample_rate, &params, &c) != 0) {
        std.log.scoped(.beat).warn("beat tracking failed: {s}", .{std.mem.sliceTo(&c.@"error", 0)});
        return error.AnalysisFailed;
    }

    const times: []const f64 = if (c.beat_times) |p| p[0..c.beat_count] else &.{};
    const downbeats: []const c_int = if (c.downbeats) |p| p[0..c.downbeat_count] else &.{};
    const beats = try alloc.alloc(Beat, times.len);
    errdefer alloc.free(beats);

    var next_down: usize = 0;
    var in_bar: u32 = 0;
    for (times, 0..) |t, i| {
        if (next_down < downbeats.len and downbeats[next_down] == @as(c_int, @intCast(i))) {
            in_bar = 1;
            next_down += 1;
        } else if (in_bar > 0) {
            in_bar += 1;
        }
        beats[i] = .{ .time = t, .beat_in_bar = in_bar, .tempo = beatTempo(times, i) };
    }
    return .{ .beats = beats };
}

/// Tempo in BPM between beat i and the next one, or the previous one for the
/// last beat; 0 when there is only one beat.
pub fn beatTempo(times: []const f64, i: usize) f64 {
    if (times.len < 2) return 0;
    const dt = if (i + 1 < times.len) times[i + 1] - times[i] else times[i] - times[i - 1];
    return if (dt > 0) 60.0 / dt else 0;
}

/// The median of the per-beat tempi: the tempo of steady material, robust to
/// a few misplaced beats.
pub fn medianTempo(alloc: std.mem.Allocator, beats: []const Beat) !f64 {
    if (beats.len == 0) return 0;
    const tempi = try alloc.alloc(f64, beats.len);
    defer alloc.free(tempi);
    for (beats, tempi) |b, *t| t.* = b.tempo;
    std.mem.sort(f64, tempi, {}, std.sort.asc(f64));
    return tempi[tempi.len / 2];
}

/// The tempo is reported as steady when the middle 80% of the per-beat
/// tempi lie within this fraction of the median.
pub const steady_spread: f64 = 0.03;

pub const Summary = struct {
    median: f64,
    low: f64,
    high: f64,
    steady: bool,
    beat_count: usize,
};

/// Summarises a result: median tempo and the range of the middle 80% of the
/// per-beat tempi, which ignores a few misplaced beats at either end.
pub fn summarize(alloc: std.mem.Allocator, beats: []const Beat) !Summary {
    if (beats.len == 0) return .{ .median = 0, .low = 0, .high = 0, .steady = false, .beat_count = 0 };
    const tempi = try alloc.alloc(f64, beats.len);
    defer alloc.free(tempi);
    for (beats, tempi) |b, *t| t.* = b.tempo;
    std.mem.sort(f64, tempi, {}, std.sort.asc(f64));
    const median = tempi[tempi.len / 2];
    const low = tempi[tempi.len / 10];
    const high = tempi[tempi.len - 1 - tempi.len / 10];
    return .{
        .median = median,
        .low = low,
        .high = high,
        .steady = median > 0 and (high - low) / median <= steady_spread,
        .beat_count = beats.len,
    };
}

// ---- tests ----

/// A click track at a steady tempo: a 30 ms decaying 1 kHz burst on every
/// beat, twice as loud on the first beat of each bar.
pub fn clickTrack(alloc: std.mem.Allocator, sample_rate: f64, bpm: f64, seconds: f64, beats_per_bar: u32) ![]f32 {
    const n: usize = @intFromFloat(sample_rate * seconds);
    const audio = try alloc.alloc(f32, n);
    @memset(audio, 0);
    const beat_len = sample_rate * 60.0 / bpm;
    const click_len: usize = @intFromFloat(sample_rate * 0.03);
    var beat: u32 = 0;
    while (true) : (beat += 1) {
        const start: usize = @intFromFloat(@as(f64, @floatFromInt(beat)) * beat_len);
        if (start >= n) break;
        const gain: f32 = if (beat % beats_per_bar == 0) 0.9 else 0.45;
        var i: usize = 0;
        while (i < click_len and start + i < n) : (i += 1) {
            const t = @as(f64, @floatFromInt(i)) / sample_rate;
            const env: f32 = @floatCast(@exp(-t * 120.0));
            audio[start + i] = gain * env * @as(f32, @floatCast(@sin(2.0 * std.math.pi * 1000.0 * t)));
        }
    }
    return audio;
}

fn expectSteadyTempo(bpm: f64) !void {
    const alloc = std.testing.allocator;
    const rate = 44100.0;
    const audio = try clickTrack(alloc, rate, bpm, 30.0, 4);
    defer alloc.free(audio);
    var result = try track(alloc, audio, rate, .{});
    defer result.deinit(alloc);

    const tempo = try medianTempo(alloc, result.beats);
    // The analysis step is 512 samples (11.6 ms), so per-beat tempi are
    // quantised; the median lands within 2% of the true tempo.
    try std.testing.expectApproxEqRel(bpm, tempo, 0.02);
    const expected_beats = 30.0 * bpm / 60.0;
    try std.testing.expect(@as(f64, @floatFromInt(result.beats.len)) > expected_beats * 0.8);
}

test "steady click tracks: tempo within 2%" {
    try expectSteadyTempo(120);
    try expectSteadyTempo(96);
    try expectSteadyTempo(140);
}

test "detected beats land on the clicks" {
    const alloc = std.testing.allocator;
    const rate = 44100.0;
    const bpm = 120.0;
    const audio = try clickTrack(alloc, rate, bpm, 20.0, 4);
    defer alloc.free(audio);
    var result = try track(alloc, audio, rate, .{});
    defer result.deinit(alloc);

    // MIREX's tolerance: a detected beat counts when it is within 70 ms of a
    // true one. The first beats are skipped while the tracker settles.
    const period = 60.0 / bpm;
    var on_beat: usize = 0;
    var checked: usize = 0;
    for (result.beats) |b| {
        if (b.time < 2.0) continue;
        checked += 1;
        const nearest = @round(b.time / period) * period;
        if (@abs(b.time - nearest) <= 0.07) on_beat += 1;
    }
    try std.testing.expect(checked > 0);
    try std.testing.expect(@as(f64, @floatFromInt(on_beat)) >= 0.9 * @as(f64, @floatFromInt(checked)));
}

test "audio that is too short reports an error instead of crashing" {
    const alloc = std.testing.allocator;
    const audio = [_]f32{0} ** 100;
    try std.testing.expectError(error.AnalysisFailed, track(alloc, &audio, 44100, .{}));
}

test "beatTempo and medianTempo" {
    const times = [_]f64{ 0, 0.5, 1.0, 1.5 };
    try std.testing.expectApproxEqAbs(@as(f64, 120), beatTempo(&times, 0), 1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, 120), beatTempo(&times, 3), 1e-9);
    const beats = [_]Beat{
        .{ .time = 0, .beat_in_bar = 1, .tempo = 118 },
        .{ .time = 0.5, .beat_in_bar = 2, .tempo = 120 },
        .{ .time = 1, .beat_in_bar = 3, .tempo = 300 },
    };
    try std.testing.expectEqual(@as(f64, 120), try medianTempo(std.testing.allocator, &beats));
}

test "summarize: steady and varying tempi" {
    const alloc = std.testing.allocator;
    var steady: [20]Beat = undefined;
    for (&steady, 0..) |*b, i| b.* = .{ .time = @floatFromInt(i), .beat_in_bar = 1, .tempo = 120 };
    const s = try summarize(alloc, &steady);
    try std.testing.expectEqual(@as(f64, 120), s.median);
    try std.testing.expect(s.steady);

    var ramp: [20]Beat = undefined;
    for (&ramp, 0..) |*b, i| b.* = .{ .time = @floatFromInt(i), .beat_in_bar = 1, .tempo = 100 + @as(f64, @floatFromInt(i)) * 2 };
    const r = try summarize(alloc, &ramp);
    try std.testing.expect(!r.steady);
    try std.testing.expect(r.low >= 100 and r.high <= 138);
}
