//! Development tool: runs the beat tracker on a WAV file, outside REAPER.
//!
//!     zig build analyze -- path/to/file.wav
//!
//! The file must be 16-bit PCM (mono or stereo; stereo is mixed to mono, as
//! the extension does). Convert other formats first, e.g. on macOS:
//!
//!     afconvert -f WAVE -d LEI16@22050 -c 1 in.mp3 out.wav
//!
//! It prints the same summary as the tempo window for a free run and for a
//! run locked around the free run's median ("Lock to this tempo"), then
//! every beat whose tempo strays more than 10% from the median, to see where
//! the tracker changes level.
const std = @import("std");
const beat = @import("beat");
const grid = @import("grid");

pub const Wav = struct {
    rate: u32,
    mono: []f32,
};

pub const WavError = error{ NotWav, Unsupported, Truncated };

/// Reads a 16-bit PCM WAV file into mono floats.
pub fn readWav(alloc: std.mem.Allocator, bytes: []const u8) (WavError || error{OutOfMemory})!Wav {
    if (bytes.len < 12 or !std.mem.eql(u8, bytes[0..4], "RIFF") or !std.mem.eql(u8, bytes[8..12], "WAVE")) return error.NotWav;
    var channels: u16 = 0;
    var rate: u32 = 0;
    var bits: u16 = 0;
    var pos: usize = 12;
    while (pos + 8 <= bytes.len) {
        const id = bytes[pos .. pos + 4];
        const size = std.mem.readInt(u32, bytes[pos + 4 ..][0..4], .little);
        const body_start = pos + 8;
        if (body_start + size > bytes.len) return error.Truncated;
        const body = bytes[body_start .. body_start + size];
        if (std.mem.eql(u8, id, "fmt ")) {
            if (std.mem.readInt(u16, body[0..2], .little) != 1) return error.Unsupported; // PCM only
            channels = std.mem.readInt(u16, body[2..4], .little);
            rate = std.mem.readInt(u32, body[4..8], .little);
            bits = std.mem.readInt(u16, body[14..16], .little);
        } else if (std.mem.eql(u8, id, "data")) {
            if (bits != 16 or channels == 0) return error.Unsupported;
            const frames = body.len / (2 * @as(usize, channels));
            const mono = try alloc.alloc(f32, frames);
            for (0..frames) |f| {
                var sum: f32 = 0;
                for (0..channels) |c| {
                    const off = (f * channels + c) * 2;
                    const v = std.mem.readInt(i16, body[off..][0..2], .little);
                    sum += @as(f32, @floatFromInt(v)) / 32768.0;
                }
                mono[f] = sum / @as(f32, @floatFromInt(channels));
            }
            return .{ .rate = rate, .mono = mono };
        }
        pos = body_start + size + (size & 1); // chunks are word aligned
    }
    return error.Truncated;
}

pub fn printRun(out: anytype, label: []const u8, result: beat.Result, summary: beat.Summary) !void {
    try out.print("{s}: median {d:.1} BPM, middle 80% {d:.1}-{d:.1} BPM, {s}, {d} beats\n", .{
        label,                                       summary.median,     summary.low, summary.high,
        if (summary.steady) "steady" else "varying", summary.beat_count,
    });
    _ = result;
}

/// The constant-tempo grid (Mixxx's post-processing) and its regions.
pub fn printGrid(out: anytype, alloc: std.mem.Allocator, result: beat.Result) !void {
    const times = try alloc.alloc(f64, result.beats.len);
    defer alloc.free(times);
    for (result.beats, times) |b, *t| t.* = b.time;
    var g = try grid.analyze(alloc, times);
    defer g.deinit(alloc);
    if (g.tempo) |t| {
        try out.print("  constant tempo {d:.3} BPM, grid anchored at {d:.3}s\n", .{ t.bpm, t.first_beat });
    } else {
        try out.print("  no constant tempo could be inferred\n", .{});
    }
    try out.print("  {d} constant regions:\n", .{g.regions.len - 1});
    for (g.regions[0 .. g.regions.len - 1], 0..) |r, i| {
        const end = g.regions[i + 1].first_beat;
        try out.print("    {d:>7.2}s - {d:>7.2}s  {d:>7.2} BPM  ({d} beats)\n", .{ r.first_beat, end, r.bpm(), grid.regionBeatCount(end - r.first_beat, r.beat_length) });
    }
}

pub fn printOutliers(out: anytype, result: beat.Result, median: f64) !void {
    var count: usize = 0;
    for (result.beats, 0..) |b, i| {
        if (median <= 0 or @abs(b.tempo - median) / median <= 0.10) continue;
        count += 1;
        try out.print("  beat {d:>4} at {d:>7.2}s  in-bar {d}  tempo {d:>6.1}  ({d:.2}x)\n", .{ i, b.time, b.beat_in_bar, b.tempo, b.tempo / median });
    }
    try out.print("  {d} of {d} beats stray more than 10% from the median\n", .{ count, result.beats.len });
    // Exploratory: one tempo fitted across all beats (least squares of beat
    // time against beat index), and the range of per-bar tempi.
    const n = result.beats.len;
    if (n > 8) {
        var sx: f64 = 0;
        var sy: f64 = 0;
        var sxx: f64 = 0;
        var sxy: f64 = 0;
        for (result.beats, 0..) |b, i| {
            const x: f64 = @floatFromInt(i);
            sx += x;
            sy += b.time;
            sxx += x * x;
            sxy += x * b.time;
        }
        const nf: f64 = @floatFromInt(n);
        const slope = (nf * sxy - sx * sy) / (nf * sxx - sx * sx);
        var lo: f64 = 1e9;
        var hi: f64 = 0;
        var i: usize = 0;
        while (i + 4 < n) : (i += 4) {
            const t = 240.0 / (result.beats[i + 4].time - result.beats[i].time);
            lo = @min(lo, t);
            hi = @max(hi, t);
        }
        try out.print("  fitted tempo {d:.2} BPM; per-bar (4-beat) tempo {d:.1}-{d:.1}\n", .{ 60.0 / slope, lo, hi });
        const intercept = (sy - slope * sx) / nf;
        var worst: f64 = 0;
        var sq: f64 = 0;
        var over40: usize = 0;
        for (result.beats, 0..) |b, k| {
            const r = b.time - (intercept + slope * @as(f64, @floatFromInt(k)));
            worst = @max(worst, @abs(r));
            sq += r * r;
            if (@abs(r) > 0.04) over40 += 1;
        }
        try out.print("  distance from the fitted line: rms {d:.1} ms, worst {d:.1} ms, {d} beats beyond 40 ms\n", .{ @sqrt(sq / nf) * 1000, worst * 1000, over40 });
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);
    const out = std.io.getStdOut().writer();
    if (args.len < 2) {
        try out.print("usage: analyze <file.wav>\n", .{});
        return;
    }

    const bytes = try std.fs.cwd().readFileAlloc(alloc, args[1], 1 << 30);
    defer alloc.free(bytes);
    const wav = try readWav(alloc, bytes);
    defer alloc.free(wav.mono);
    const rate: f64 = @floatFromInt(wav.rate);
    try out.print("{s}: {d:.1}s at {d} Hz\n", .{ args[1], @as(f64, @floatFromInt(wav.mono.len)) / rate, wav.rate });

    var free_run = try beat.track(alloc, wav.mono, rate, .{});
    defer free_run.deinit(alloc);
    const f = try beat.summarize(alloc, free_run.beats);
    try printRun(out, "free  ", free_run, f);
    try printOutliers(out, free_run, f.median);
    try printGrid(out, alloc, free_run);

    var locked = try beat.track(alloc, wav.mono, rate, .{ .input_tempo = f.median, .constrain_tempo = 1 });
    defer locked.deinit(alloc);
    const l = try beat.summarize(alloc, locked.beats);
    try printRun(out, "locked", locked, l);
    try printOutliers(out, locked, l.median);
    try printGrid(out, alloc, locked);
}
