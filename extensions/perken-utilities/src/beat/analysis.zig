//! One tempo analysis of a take.
//!
//! REAPER's audio accessor is used from the main thread only, so the take's
//! audio is read there, one slice per timer tick (`step`), which keeps REAPER
//! and the tempo window responsive and lets the window show progress. Once
//! the audio is read, qm-dsp analyses it on a worker thread, which touches no
//! REAPER API; the window polls `phase` until the worker is done.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const beat = @import("beat.zig");
const grid = @import("grid.zig");

const log = std.log.scoped(.beat);

/// The audio is analysed at 22.05 kHz: onset detection does not need more,
/// and it halves the memory of a long item compared with 44.1 kHz (10 minutes
/// of mono audio is about 53 MB).
pub const analysis_rate: c_int = 22050;
/// Seconds of audio read per timer tick (the timer runs about 30 times a
/// second, so a minute of audio takes well under a second to read).
pub const read_chunk_seconds: f64 = 5.0;
/// Longest item analysed, to bound memory.
pub const max_seconds: f64 = 30.0 * 60.0;

pub const Phase = enum(u8) { reading, analysing, done, failed };

pub const Job = struct {
    alloc: std.mem.Allocator,
    take: *Reaper.MediaItem_Take,
    accessor: ?*Reaper.AudioAccessor,
    channels: c_int,
    /// The accessor's time range; beat times are relative to start_time.
    start_time: f64,
    end_time: f64,
    /// How far reading has got, in accessor time.
    cursor: f64,
    mono: std.ArrayListUnmanaged(f32) = .{},
    params: beat.Params,
    phase: std.atomic.Value(Phase) = std.atomic.Value(Phase).init(.reading),
    thread: ?std.Thread = null,
    result: ?beat.Result = null,
    /// The constant-tempo grid of the result (Mixxx's post-processing), its
    /// beats numbered by bar, and the passages off the grid. Computed by the
    /// worker after the tracker.
    grid: ?grid.Grid = null,
    grid_beats: []grid.GridBeat = &.{},
    passages: []grid.Passage = &.{},
    failure: [160]u8 = @splat(0),

    /// Fraction of the work done, for the progress bar. Reading is shown as
    /// the whole bar; the analysis itself has no progress to report.
    pub fn progress(self: *const Job) f64 {
        const span = self.end_time - self.start_time;
        if (span <= 0) return 1;
        return @min(1.0, (self.cursor - self.start_time) / span);
    }

    pub fn failureText(self: *const Job) []const u8 {
        return std.mem.sliceTo(&self.failure, 0);
    }

    pub fn fail(self: *Job, comptime fmt: []const u8, args: anytype) void {
        _ = std.fmt.bufPrint(self.failure[0 .. self.failure.len - 1], fmt, args) catch {};
        self.phase.store(.failed, .release);
        log.warn("tempo analysis failed: {s}", .{self.failureText()});
    }

    /// Advances the job by one timer tick. Main thread only.
    pub fn step(self: *Job) void {
        if (self.phase.load(.acquire) != .reading) return;
        const accessor = self.accessor orelse return;

        const remaining = self.end_time - self.cursor;
        if (remaining <= 0) {
            self.finishReading();
            return;
        }
        const seconds = @min(read_chunk_seconds, remaining);
        const frames: usize = @intFromFloat(@ceil(seconds * @as(f64, @floatFromInt(analysis_rate))));
        const nch: usize = @intCast(self.channels);

        const buf = self.alloc.alloc(f64, frames * nch) catch return self.fail("out of memory", .{});
        defer self.alloc.free(buf);
        const got = Reaper.GetAudioAccessorSamples(accessor, analysis_rate, self.channels, self.cursor, @intCast(frames), &buf[0]);
        if (got < 0) return self.fail("could not read the item's audio", .{});

        // Mix the channels down to mono.
        self.mono.ensureUnusedCapacity(self.alloc, frames) catch return self.fail("out of memory", .{});
        for (0..frames) |f| {
            var sum: f64 = 0;
            for (0..nch) |c| sum += buf[f * nch + c];
            self.mono.appendAssumeCapacity(@floatCast(sum / @as(f64, @floatFromInt(nch))));
        }
        self.cursor += seconds;
    }

    /// Releases the accessor (main thread) and starts the worker.
    pub fn finishReading(self: *Job) void {
        if (self.accessor) |a| Reaper.DestroyAudioAccessor(a);
        self.accessor = null;
        self.phase.store(.analysing, .release);
        self.thread = std.Thread.spawn(.{}, workerMain, .{self}) catch {
            self.fail("could not start the analysis thread", .{});
            return;
        };
    }

    /// Stops the job and frees everything. Main thread only; waits for the
    /// worker if it is still running.
    pub fn deinit(self: *Job) void {
        if (self.thread) |t| t.join();
        if (self.accessor) |a| Reaper.DestroyAudioAccessor(a);
        if (self.result) |*r| r.deinit(self.alloc);
        if (self.grid) |*g| g.deinit(self.alloc);
        self.alloc.free(self.grid_beats);
        self.alloc.free(self.passages);
        self.mono.deinit(self.alloc);
        self.alloc.destroy(self);
    }
};

/// The worker thread: runs qm-dsp on the audio read so far. It touches no
/// REAPER API.
pub fn workerMain(job: *Job) void {
    const result = beat.track(job.alloc, job.mono.items, @floatFromInt(analysis_rate), job.params) catch |err| {
        job.fail("{s}", .{switch (err) {
            error.AnalysisFailed => "the tracker found no beats (audio too short or silent?)",
            error.OutOfMemory => "out of memory",
        }});
        return;
    };
    job.result = result;
    logBeats(result.beats, job.params);
    computeGrid(job, result) catch {
        job.fail("out of memory", .{});
        return;
    };
    job.phase.store(.done, .release);
}

pub const StartError = error{ MidiTake, TooLong, NoAudio, OutOfMemory };

/// Starts analysing a take: creates the accessor and the job. Main thread.
pub fn start(alloc: std.mem.Allocator, take: *Reaper.MediaItem_Take, params: beat.Params) StartError!*Job {
    if (Reaper.TakeIsMIDI(take)) return error.MidiTake;
    const accessor = Reaper.CreateTakeAudioAccessor(take);
    const start_time = Reaper.GetAudioAccessorStartTime(accessor);
    const end_time = Reaper.GetAudioAccessorEndTime(accessor);
    if (end_time - start_time <= 0) {
        Reaper.DestroyAudioAccessor(accessor);
        return error.NoAudio;
    }
    if (end_time - start_time > max_seconds) {
        Reaper.DestroyAudioAccessor(accessor);
        return error.TooLong;
    }
    const source = Reaper.GetMediaItemTake_Source(take);
    const channels = std.math.clamp(Reaper.GetMediaSourceNumChannels(source), 1, 2);

    const job = alloc.create(Job) catch {
        Reaper.DestroyAudioAccessor(accessor);
        return error.OutOfMemory;
    };
    job.* = .{
        .alloc = alloc,
        .take = take,
        .accessor = accessor,
        .channels = channels,
        .start_time = start_time,
        .end_time = end_time,
        .cursor = start_time,
        .params = params,
    };
    return job;
}

/// Logs every detected beat at debug level (Debug builds print it to the
/// terminal REAPER was started from), to see where the tracker changes tempo
/// or metrical level.
pub fn logBeats(beats: []const beat.Beat, params: beat.Params) void {
    log.debug("{d} beats (input tempo {d:.1}, constrained: {})", .{ beats.len, params.input_tempo, params.constrain_tempo != 0 });
    for (beats, 0..) |b, i| {
        log.debug("beat {d}: {d:.3}s in-bar={d} tempo={d:.1}", .{ i, b.time, b.beat_in_bar, b.tempo });
    }
}

/// Off-grid passages are regions more than this far from the grid's tempo.
pub const passage_tolerance: f64 = 0.05;

/// The constant grid, its numbered beats over the item, and the passages off
/// it. Worker thread; touches no REAPER API.
pub fn computeGrid(job: *Job, result: beat.Result) !void {
    const times = try job.alloc.alloc(f64, result.beats.len);
    defer job.alloc.free(times);
    var downbeats: std.ArrayList(f64) = .empty;
    defer downbeats.deinit(job.alloc);
    for (result.beats, times) |b, *t| {
        t.* = b.time;
        if (b.beat_in_bar == 1) try downbeats.append(job.alloc, b.time);
    }
    var g = try grid.analyze(job.alloc, times);
    errdefer g.deinit(job.alloc);
    if (g.tempo) |tempo| {
        const bpb: u32 = @intCast(@max(1, job.params.beats_per_bar));
        job.grid_beats = try grid.gridBeats(job.alloc, tempo, job.end_time - job.start_time, bpb, downbeats.items);
        job.passages = try grid.offGridPassages(job.alloc, g.regions, tempo.bpm, passage_tolerance);
        log.debug("grid: {d:.3} BPM from {d:.3}s, {d} off-grid passages", .{ tempo.bpm, tempo.first_beat, job.passages.len });
    }
    job.grid = g;
}
