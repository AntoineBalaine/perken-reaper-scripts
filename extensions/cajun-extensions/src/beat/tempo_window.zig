//! The tempo detection window and its action.
//!
//! "Cajun: Detect tempo of selected item" opens the window and starts an
//! analysis of the selected item's active take (analysis.zig). The window
//! shows the progress while the audio is read and "Analysing…" while qm-dsp
//! runs on its worker thread; then the result: the median tempo, the tempo
//! range, whether the tempo is steady, and the number of beats. The beats are
//! previewed as take markers named bar.beat ("♩3.2"), which can be dragged to
//! correct them. "Lock to this tempo" re-runs the analysis constrained around
//! the median tempo, for when the tracker switches metrical level in places
//! (e.g. marking eighth notes in busy sections); "×2" and "÷2" re-run it
//! constrained around double or half the tempo, for when it locked onto the
//! wrong level everywhere.
//!
//! The window is a ReaImGui window, drawn from a timer that only runs while
//! the window is open or an analysis is still running. ReaImGui's API is
//! resolved on the first tick, because ReaImGui may load after this
//! extension (plugin files load in name order).
const std = @import("std");
const Reaper = @import("reaper").reaper;
const imgui = @import("reaper_imgui");
const helpers = @import("reaper_helpers");
const actions = @import("../actions.zig");
const analysis = @import("analysis.zig");
const beat = @import("beat.zig");

const log = std.log.scoped(.tempo_window);

/// Take markers created by the preview start with this prefix, so that they
/// can be told apart from the user's own markers and removed again.
pub const marker_prefix = "\u{2669}"; // ♩

pub const ImguiState = enum { unchecked, present, missing };

pub const State = struct {
    imgui_state: ImguiState = .unchecked,
    ctx: imgui.ContextPtr = null,
    /// The window is shown.
    open: bool = false,
    timer_registered: bool = false,
    job: ?*analysis.Job = null,
    /// Preview markers were added for the current job's result.
    previewed: bool = false,
    beats_per_bar: c_int = 4,
};

pub var state: State = .{};

// ---- the action ----

fn detectTempoAction(_: *actions.RunCtx) void {
    if (state.imgui_state == .missing) {
        _ = Reaper.ShowMessageBox("Tempo detection needs ReaImGui (install it with ReaPack).", "Cajun: tempo detection", 0);
        return;
    }
    const item = helpers.getSelectedMediaItem(0) orelse {
        _ = Reaper.ShowMessageBox("Select an audio item first.", "Cajun: tempo detection", 0);
        return;
    };
    const take = helpers.getActiveTake(item) orelse {
        _ = Reaper.ShowMessageBox("The selected item has no take.", "Cajun: tempo detection", 0);
        return;
    };
    startAnalysis(take, .{ .beats_per_bar = state.beats_per_bar });
    state.open = true;
    ensureTimer();
}

/// Starts (or restarts) an analysis of `take`, dropping the previous job and
/// its preview markers.
pub fn startAnalysis(take: *Reaper.MediaItem_Take, params: beat.Params) void {
    discardJob();
    state.job = analysis.start(std.heap.c_allocator, take, params) catch |err| {
        const msg: [:0]const u8 = switch (err) {
            error.MidiTake => "The selected take is MIDI; tempo detection needs audio.",
            error.TooLong => "The item is longer than 30 minutes, the longest this analyses.",
            error.NoAudio => "The selected take has no audio to analyse.",
            error.OutOfMemory => "Out of memory.",
        };
        _ = Reaper.ShowMessageBox(msg, "Cajun: tempo detection", 0);
        return;
    };
    state.previewed = false;
}

/// Frees the current job and removes its preview markers.
pub fn discardJob() void {
    const job = state.job orelse return;
    if (state.previewed and takeIsValid(job.take)) removePreviewMarkers(job.take);
    job.deinit();
    state.job = null;
    state.previewed = false;
}

// ---- timer and window ----

pub fn ensureTimer() void {
    if (state.timer_registered) return;
    _ = Reaper.plugin_register("timer", @constCast(@ptrCast(&onTimer)));
    state.timer_registered = true;
}

pub fn stopTimer() void {
    if (!state.timer_registered) return;
    _ = Reaper.plugin_register("-timer", @constCast(@ptrCast(&onTimer)));
    state.timer_registered = false;
}

pub fn ensureImgui() void {
    if (state.imgui_state != .unchecked) return;
    imgui.init(Reaper.plugin_getapi) catch {
        state.imgui_state = .missing;
        log.warn("ReaImGui not available — the tempo window needs it (install via ReaPack)", .{});
        return;
    };
    state.imgui_state = .present;
}

pub fn onTimer() callconv(.C) void {
    ensureImgui();
    if (state.imgui_state == .missing) {
        if (state.open) {
            state.open = false;
            _ = Reaper.ShowMessageBox("Tempo detection needs ReaImGui (install it with ReaPack).", "Cajun: tempo detection", 0);
        }
        discardJob();
        stopTimer();
        return;
    }

    if (state.job) |job| {
        job.step();
        if (job.phase.load(.acquire) == .done and !state.previewed) {
            if (takeIsValid(job.take)) {
                if (job.result) |r| addPreviewMarkers(job, r.beats);
            }
            state.previewed = true;
        }
    }

    if (state.open) drawWindow();

    // Once the window is closed, the timer stops; a job still analysing is
    // kept until its worker finishes, so that closing never waits on it.
    if (!state.open) {
        if (state.job) |job| {
            if (job.phase.load(.acquire) == .analysing) return;
        }
        stopTimer();
    }
}

pub fn drawWindow() void {
    if (state.ctx == null) {
        var cfg_flags: c_int = 0;
        state.ctx = imgui.api.CreateContext("Cajun tempo detection", &cfg_flags);
        if (state.ctx == null) return;
    }
    const ctx = state.ctx;
    imgui.api.SetNextWindowSize(ctx, 380, 230, &imgui.Cond_FirstUseEver);
    var is_open: bool = true;
    var flags: c_int = imgui.WindowFlags_NoSavedSettings;
    if (imgui.api.Begin(ctx, "Cajun: tempo detection", &is_open, &flags)) drawContent(ctx);
    imgui.api.End(ctx);
    if (!is_open) state.open = false;
}

pub fn drawContent(ctx: imgui.ContextPtr) void {
    var line: [256:0]u8 = undefined;

    var bpb = state.beats_per_bar;
    if (imgui.api.InputInt(ctx, "Beats per bar", &bpb, null, null, null)) {
        state.beats_per_bar = std.math.clamp(bpb, 1, 16);
    }
    imgui.api.Separator(ctx);

    const job = state.job orelse {
        imgui.api.TextWrapped(ctx, "Select an audio item and run \"Cajun: Detect tempo of selected item\".");
        return;
    };
    imgui.api.Text(ctx, fmtZ(&line, "Item: {s}", .{if (takeIsValid(job.take)) std.mem.span(Reaper.GetTakeName(job.take)) else "(deleted)"}));

    switch (job.phase.load(.acquire)) {
        .reading => imgui.api.ProgressBar(ctx, job.progress(), null, null, "Reading audio"),
        .analysing => imgui.api.Text(ctx, "Analysing\u{2026}"),
        .failed => {
            imgui.api.TextWrapped(ctx, fmtZ(&line, "Analysis failed: {s}", .{job.failureText()}));
            if (imgui.api.Button(ctx, "Close", null, null)) closeAndDiscard();
        },
        .done => drawResult(ctx, job),
    }
}

pub fn drawResult(ctx: imgui.ContextPtr, job: *analysis.Job) void {
    var line: [256:0]u8 = undefined;
    const result = job.result orelse return;
    const s = beat.summarize(std.heap.c_allocator, result.beats) catch return;

    imgui.api.Text(ctx, fmtZ(&line, "Tempo: {d:.1} BPM", .{s.median}));
    if (s.steady) {
        imgui.api.Text(ctx, "Steady tempo");
    } else {
        imgui.api.Text(ctx, fmtZ(&line, "Varies between {d:.1} and {d:.1} BPM", .{ s.low, s.high }));
    }
    imgui.api.Text(ctx, fmtZ(&line, "{d} beats, shown as take markers", .{s.beat_count}));
    imgui.api.Separator(ctx);

    // Re-run constrained around the median, so that the tracker stays at
    // that metrical level everywhere instead of switching in busy sections.
    if (imgui.api.Button(ctx, "Lock to this tempo", null, null)) rerun(job.take, s.median);
    imgui.api.SameLine(ctx, null, null);
    // Re-run constrained around double or half the tempo, for when the
    // tracker locked onto the wrong level everywhere.
    if (imgui.api.Button(ctx, "\u{00d7}2", null, null)) rerun(job.take, s.median * 2);
    imgui.api.SameLine(ctx, null, null);
    if (imgui.api.Button(ctx, "\u{00f7}2", null, null)) rerun(job.take, s.median / 2);
    imgui.api.SameLine(ctx, null, null);
    if (imgui.api.Button(ctx, "Discard", null, null)) closeAndDiscard();
}

pub fn rerun(take: *Reaper.MediaItem_Take, tempo: f64) void {
    if (!takeIsValid(take)) return;
    startAnalysis(take, .{
        .input_tempo = tempo,
        .constrain_tempo = 1,
        .beats_per_bar = state.beats_per_bar,
    });
}

pub fn closeAndDiscard() void {
    discardJob();
    state.open = false;
}

pub fn fmtZ(buf: *[256:0]u8, comptime fmt: []const u8, args: anytype) [:0]const u8 {
    return std.fmt.bufPrintZ(buf, fmt, args) catch "…";
}

// ---- take markers ----

/// True while `take` still exists in the current project (the user may
/// delete the item during the analysis).
pub fn takeIsValid(take: *Reaper.MediaItem_Take) bool {
    const f: *const fn (proj: ?*anyopaque, pointer: ?*anyopaque, ctypename: [*:0]const u8) callconv(.C) bool = @ptrCast(Reaper.ValidatePtr2);
    return f(null, @ptrCast(take), "MediaItem_Take*");
}

/// Adds one take marker per detected beat, named bar.beat with the preview
/// prefix. Beat times are relative to the accessor's start; take markers are
/// positioned in source time, which also depends on the take's start offset
/// and playback rate.
pub fn addPreviewMarkers(job: *analysis.Job, beats: []const beat.Beat) void {
    const offset = Reaper.GetMediaItemTakeInfo_Value(job.take, "D_STARTOFFS");
    const rate = Reaper.GetMediaItemTakeInfo_Value(job.take, "D_PLAYRATE");
    Reaper.Undo_BeginBlock();
    var bar: u32 = 0;
    for (beats) |b| {
        if (b.beat_in_bar == 1) bar += 1;
        var name_buf: [32:0]u8 = undefined;
        const name = if (b.beat_in_bar == 0)
            std.fmt.bufPrintZ(&name_buf, marker_prefix, .{}) catch continue
        else
            std.fmt.bufPrintZ(&name_buf, marker_prefix ++ "{d}.{d}", .{ bar, b.beat_in_bar }) catch continue;
        var srcpos = offset + (job.start_time + b.time) * rate;
        var color: c_int = 0; // REAPER's default marker color
        _ = Reaper.SetTakeMarker(job.take, -1, name, &srcpos, &color);
    }
    Reaper.Undo_EndBlock("Cajun: preview detected beats", -1);
    Reaper.UpdateArrange();
}

/// Removes the take markers whose name starts with the preview prefix.
pub fn removePreviewMarkers(take: *Reaper.MediaItem_Take) void {
    Reaper.Undo_BeginBlock();
    var i = Reaper.GetNumTakeMarkers(take) - 1;
    while (i >= 0) : (i -= 1) {
        var name_buf: [64]u8 = [_]u8{0} ** 64;
        var color: c_int = 0;
        _ = Reaper.GetTakeMarker(take, i, @ptrCast(&name_buf), name_buf.len, &color);
        if (std.mem.startsWith(u8, std.mem.sliceTo(&name_buf, 0), marker_prefix)) {
            _ = Reaper.DeleteTakeMarker(take, i);
        }
    }
    Reaper.Undo_EndBlock("Cajun: remove beat preview", -1);
    Reaper.UpdateArrange();
}

pub const entries = [_]actions.Entry{
    .{ .name = "DetectTempo", .def = .{ .steps = &.{.{ .func = &detectTempoAction }}, .desc = "Detect tempo of selected item" } },
};

// ---- tests ----

/// An 89 BPM click track with loud eighth-note hi-hats between 10 and 20
/// seconds: the busy middle section that can make the tracker switch to
/// marking eighth notes.
pub fn busyMiddleTrack(alloc: std.mem.Allocator, rate: f64) ![]f32 {
    const audio = try beat.clickTrack(alloc, rate, 89, 30, 4);
    const eighth = rate * 60.0 / 89.0 / 2.0;
    const hat_len: usize = @intFromFloat(rate * 0.02);
    var k: usize = 0;
    while (true) : (k += 1) {
        const start: usize = @intFromFloat(@as(f64, @floatFromInt(k)) * eighth);
        const t0 = @as(f64, @floatFromInt(start)) / rate;
        if (t0 >= 20.0 or start >= audio.len) break;
        if (t0 < 10.0) continue;
        var prng = std.Random.DefaultPrng.init(k);
        var i: usize = 0;
        while (i < hat_len and start + i < audio.len) : (i += 1) {
            const env: f32 = @floatCast(@exp(-@as(f64, @floatFromInt(i)) / rate * 200.0));
            audio[start + i] += 0.8 * env * (prng.random().float(f32) * 2 - 1);
        }
    }
    return audio;
}

test "busy eighth notes in the middle do not throw a click track off its tempo" {
    const alloc = std.testing.allocator;
    const rate = 22050.0;
    const audio = try busyMiddleTrack(alloc, rate);
    defer alloc.free(audio);

    // Free tracking, then locked around the tempo it found ("Lock to this
    // tempo"): both stay at 89 BPM. Real recordings that do switch levels
    // need more than loud hi-hats; this guards the synthetic case.
    var free_run = try beat.track(alloc, audio, rate, .{});
    defer free_run.deinit(alloc);
    const f = try beat.summarize(alloc, free_run.beats);
    try std.testing.expectApproxEqRel(@as(f64, 89), f.median, 0.02);
    try std.testing.expect(f.steady);

    var locked = try beat.track(alloc, audio, rate, .{ .input_tempo = f.median, .constrain_tempo = 1 });
    defer locked.deinit(alloc);
    const l = try beat.summarize(alloc, locked.beats);
    try std.testing.expectApproxEqRel(@as(f64, 89), l.median, 0.02);
    try std.testing.expect(l.steady);
}
