//! The tempo detection window and its action.
//!
//! "Cajun: Detect tempo of selected item" opens the window and starts an
//! analysis of the selected item's active take (analysis.zig). The window
//! shows the progress while the audio is read and "Analysing…" while qm-dsp
//! runs on its worker thread; then the result: the median tempo, the tempo
//! range, whether the tempo is steady, and the number of beats. The beats are
//! previewed as take markers named bar.beat ("♩3.2"), which can be dragged to
//! correct them. "×2" and "÷2" re-run the analysis biased towards double or
//! half the tempo, for when the tracker locked onto the wrong one.
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

/// The tempo is reported as steady when the middle 80% of the per-beat
/// tempi lie within this fraction of the median.
pub const steady_spread: f64 = 0.03;

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

pub const Summary = struct {
    median: f64,
    low: f64,
    high: f64,
    steady: bool,
    beat_count: usize,
};

/// Summarises a result: median tempo and the range of the middle 80% of the
/// per-beat tempi, which ignores a few misplaced beats at either end.
pub fn summarize(alloc: std.mem.Allocator, beats: []const beat.Beat) !Summary {
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
    const s = summarize(std.heap.c_allocator, result.beats) catch return;

    imgui.api.Text(ctx, fmtZ(&line, "Tempo: {d:.1} BPM", .{s.median}));
    if (s.steady) {
        imgui.api.Text(ctx, "Steady tempo");
    } else {
        imgui.api.Text(ctx, fmtZ(&line, "Varies between {d:.1} and {d:.1} BPM", .{ s.low, s.high }));
    }
    imgui.api.Text(ctx, fmtZ(&line, "{d} beats, shown as take markers", .{s.beat_count}));
    imgui.api.Separator(ctx);

    // Re-run biased towards double or half the tempo, for when the tracker
    // locked onto the wrong one.
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

test "summarize: steady and varying tempi" {
    const alloc = std.testing.allocator;
    var steady: [20]beat.Beat = undefined;
    for (&steady, 0..) |*b, i| b.* = .{ .time = @floatFromInt(i), .beat_in_bar = 1, .tempo = 120 };
    const s = try summarize(alloc, &steady);
    try std.testing.expectEqual(@as(f64, 120), s.median);
    try std.testing.expect(s.steady);

    var ramp: [20]beat.Beat = undefined;
    for (&ramp, 0..) |*b, i| b.* = .{ .time = @floatFromInt(i), .beat_in_bar = 1, .tempo = 100 + @as(f64, @floatFromInt(i)) * 2 };
    const r = try summarize(alloc, &ramp);
    try std.testing.expect(!r.steady);
    try std.testing.expect(r.low >= 100 and r.high <= 138);
}
