const std = @import("std");
const reaper = @import("reaper").reaper;
const pReaper = @import("pReaper.zig");
const log = std.log.scoped(.auto_lane_watcher);

const CMD_HIDE_ALL_ENVELOPES: c_int = 40889; // Envelope: Hide all envelopes for tracks
const CMD_SHOW_LAST_TOUCHED_FX_ENV: c_int = 41142; // FX: Show/hide track envelope for last touched FX parameter

const ActiveLane = struct {
    track: reaper.MediaTrack,
    fx_index: c_int,
    param_index: c_int,
    // Point count when the lane was first shown. The seed point REAPER inserts
    // on creation is included here, so "user inserted automation" means the
    // count later exceeds this baseline. Trimming moves the seed without
    // changing the count, so a trimmed-only lane stays at the baseline.
    initial_point_count: c_int,
    env: *reaper.TrackEnvelope,
};

var watcher_active: bool = false;
var current_lane: ?ActiveLane = null;

pub fn isActive() bool {
    return watcher_active;
}

pub fn toggle() void {
    watcher_active = !watcher_active;
    if (!watcher_active) dismissLane();
    log.info("auto lane watcher {s}", .{if (watcher_active) "enabled" else "disabled"});
}

/// Called from SETLASTTOUCHEDFX. Dismisses the previous lane, then shows the
/// lane for the newly touched parameter.
pub fn onLastTouchedFx(track: reaper.MediaTrack, fx_index: c_int, param_index: c_int) void {
    assert(watcher_active);

    if (current_lane) |lane| {
        if (lane.track == track and lane.fx_index == fx_index and lane.param_index == param_index)
            return;
    }

    dismissLane();
    showLane(track, fx_index, param_index);
}

/// Called from the SETFXPARAM csurf callback. When the track is in trim or
/// read mode, REAPER drives the parameter from the envelope and snaps any
/// plugin-UI tweak back to the point. We redirect the tweak instead: we take
/// the value the user set and write it into the envelope point, reproducing
/// what dragging the native trim slider does. This makes a plugin-UI tweak
/// trim the lane, which trim/read mode does not do natively.
pub fn onFxParamChanged(track: reaper.MediaTrack, fx_index: c_int, param_index: c_int) void {
    if (!watcher_active) return;

    // Only redirect in trim/read modes. The global automation override, when
    // set, takes precedence over the track's own mode.
    const override = pReaper.GetGlobalAutomationOverride(.{});
    const effective_mode: c_int = if (override >= 0)
        override
    else
        @intFromFloat(pReaper.GetMediaTrackInfo_Value(.{ track, "I_AUTOMODE" }));
    // 0 = trim/read, 1 = read. Touch/write/latch (2/3/4) write points natively,
    // so we must not interfere there. 5 = bypass.
    if (effective_mode != 0 and effective_mode != 1) return;

    const env_raw = pReaper.GetFXEnvelope(.{ track, fx_index, param_index, false });
    if (@intFromPtr(env_raw) == 0) return;
    const env: *reaper.TrackEnvelope = env_raw;

    // Only the single-point floating lane is handled. A multi-point lane's trim
    // is an offset of every point, which is a different operation.
    if (pReaper.CountEnvelopePoints(.{env}) != 1) return;

    // The point stores the parameter's native value in the envelope's scaling
    // space, not the normalized 0..1 value. We read the native value the user
    // just set (the parameter already sits at it) and convert through the
    // scaling mode: identity for unscaled envelopes, fader curve otherwise.
    var min_val: f64 = 0;
    var max_val: f64 = 0;
    const native_value = pReaper.TrackFX_GetParam(.{ track, fx_index, param_index, &min_val, &max_val });
    const scaling_mode = pReaper.GetEnvelopeScalingMode(.{env});
    var target_value = pReaper.ScaleToEnvelopeMode(.{ scaling_mode, native_value });

    // Preserve the point's time, shape, tension and selection; only the value
    // changes. We read the existing point to fill those fields.
    var time: f64 = 0;
    var old_value: f64 = 0;
    var shape: c_int = 0;
    var tension: f64 = 0;
    var selected: bool = false;
    if (!pReaper.GetEnvelopePoint(.{ env, 0, &time, &old_value, &shape, &tension, &selected })) return;

    // The csurf callback fires every frame while the envelope drives the
    // parameter, so without this guard we would rewrite the same value
    // continuously. Only write when the user actually moved the value.
    if (@abs(old_value - target_value) < 1e-9) return;

    var no_sort = false;
    _ = pReaper.SetEnvelopePoint(.{ env, 0, &time, &target_value, &shape, &tension, &selected, &no_sort });
    pReaper.UpdateArrange(.{});
}

/// Called from SETFOCUSEDFX (all-null) and SETFXOPEN (closed).
pub fn onFocusDismissed() void {
    dismissLane();
}

/// Called from SETLASTTOUCHEDTRACK. Dismisses the lane when the user moves to
/// a different track.
pub fn onTrackChanged(new_track: reaper.MediaTrack) void {
    if (!watcher_active) return;
    const lane = current_lane orelse return;
    if (lane.track != new_track) dismissLane();
}

fn showLane(track: reaper.MediaTrack, fx_index: c_int, param_index: c_int) void {
    // Hide everything on the target track, then show the last-touched envelope.
    pReaper.SetOnlyTrackSelected(.{track});
    pReaper.Main_OnCommand(.{ CMD_HIDE_ALL_ENVELOPES, 0 });
    pReaper.Main_OnCommand(.{ CMD_SHOW_LAST_TOUCHED_FX_ENV, 0 });

    const env_raw = pReaper.GetFXEnvelope(.{ track, fx_index, param_index, false });
    if (@intFromPtr(env_raw) == 0) {
        log.warn("could not get envelope after showing it for fx={d} param={d}", .{ fx_index, param_index });
        return;
    }
    const env: *reaper.TrackEnvelope = env_raw;

    current_lane = .{
        .track = track,
        .fx_index = fx_index,
        .param_index = param_index,
        .initial_point_count = pReaper.CountEnvelopePoints(.{env}),
        .env = env,
    };
}

/// Dismisses the current lane. A lane the user only trimmed (no inserted
/// automation points beyond the seed) is removed entirely; a lane with real
/// automation is kept and merely hidden.
fn dismissLane() void {
    const lane = current_lane orelse return;

    const count = pReaper.CountEnvelopePoints(.{lane.env});
    const should_remove = count <= lane.initial_point_count;
    log.err("dismissLane: count={d} initial={d} -> {s}", .{ count, lane.initial_point_count, if (should_remove) "remove" else "keep" });
    if (should_remove) {
        removeEnvelope(lane.env, lane.track);
    }

    pReaper.SetOnlyTrackSelected(.{lane.track});
    pReaper.Main_OnCommand(.{ CMD_HIDE_ALL_ENVELOPES, 0 });
    pReaper.UpdateArrange(.{});
    current_lane = null;
}

/// Removes an FX parameter envelope entirely. There is no API to delete an
/// envelope and deleting all its points leaves an empty lane behind, so we
/// splice the envelope's PARMENV block out of the parent track's state chunk.
/// We locate the block by its EGUID (indentation-agnostic) rather than by a
/// verbatim chunk match, because the track chunk indents nested blocks while
/// GetEnvelopeStateChunk returns the block un-indented.
fn removeEnvelope(env: *reaper.TrackEnvelope, track: reaper.MediaTrack) void {
    const alloc = std.heap.page_allocator;

    // Read the envelope's own chunk just to extract its EGUID.
    var env_buf: [64 * 1024:0]u8 = undefined;
    const env_ptr: *i8 = @ptrCast(&env_buf[0]);
    const env_cap: c_int = @intCast(env_buf.len);
    if (!pReaper.GetEnvelopeStateChunk(.{ env, env_ptr, env_cap, false })) {
        log.err("removeEnvelope: GetEnvelopeStateChunk failed", .{});
        return;
    }
    const env_chunk = std.mem.span(@as([*:0]u8, &env_buf));

    const eguid = extractEguid(env_chunk) orelse {
        log.err("removeEnvelope: no EGUID in env chunk", .{});
        return;
    };

    // Track chunks can be large because they embed FX (plugin) state.
    const cap: usize = 4 * 1024 * 1024;
    const track_buf = alloc.allocSentinel(u8, cap, 0) catch return;
    defer alloc.free(track_buf);
    const track_ptr: *i8 = @ptrCast(&track_buf[0]);
    const track_cap: c_int = @intCast(cap + 1);
    if (!pReaper.GetTrackStateChunk(.{ track, track_ptr, track_cap, false })) {
        log.err("removeEnvelope: track chunk exceeds {d} bytes", .{cap});
        return;
    }
    const track_chunk = std.mem.span(@as([*:0]u8, track_buf.ptr));

    const gpos = std.mem.indexOf(u8, track_chunk, eguid) orelse {
        log.err("removeEnvelope: EGUID {s} not found in track chunk (len={d})", .{ eguid, track_chunk.len });
        return;
    };

    // Walk backwards to the start of the enclosing <PARMENV line.
    const parmenv_pos = std.mem.lastIndexOf(u8, track_chunk[0..gpos], "<PARMENV") orelse {
        log.err("removeEnvelope: no <PARMENV before EGUID", .{});
        return;
    };
    const block_start = if (std.mem.lastIndexOfScalar(u8, track_chunk[0..parmenv_pos], '\n')) |nl| nl + 1 else 0;

    // Walk forwards line by line, tracking nesting depth, to the matching '>'.
    var block_end: usize = block_start;
    var depth: i32 = 0;
    var i = block_start;
    while (i < track_chunk.len) {
        const line_end = if (std.mem.indexOfScalarPos(u8, track_chunk, i, '\n')) |nl| nl + 1 else track_chunk.len;
        const line = std.mem.trim(u8, track_chunk[i..line_end], " \t\r\n");
        if (std.mem.startsWith(u8, line, "<")) {
            depth += 1;
        } else if (std.mem.startsWith(u8, line, ">")) {
            depth -= 1;
            if (depth == 0) {
                block_end = line_end;
                break;
            }
        }
        i = line_end;
    }
    if (depth != 0) {
        log.err("removeEnvelope: unbalanced PARMENV block", .{});
        return;
    }

    // Splice out [block_start, block_end).
    const tail = track_chunk[block_end..];
    std.mem.copyForwards(u8, track_buf[block_start .. block_start + tail.len], tail);
    track_buf[block_start + tail.len] = 0;

    const new_ptr: [*:0]const u8 = track_buf.ptr;
    const ok = pReaper.SetTrackStateChunk(.{ track, new_ptr, false });
    log.err("removeEnvelope: spliced [{d}..{d}] SetTrackStateChunk={}", .{ block_start, block_end, ok });
}

/// Extracts the EGUID token (e.g. "{...}") from an envelope state chunk.
fn extractEguid(env_chunk: []const u8) ?[]const u8 {
    const key = "EGUID ";
    const kpos = std.mem.indexOf(u8, env_chunk, key) orelse return null;
    const after = env_chunk[kpos + key.len ..];
    const nl = std.mem.indexOfScalar(u8, after, '\n') orelse after.len;
    return std.mem.trim(u8, after[0..nl], " \t\r\n");
}

const assert = std.debug.assert;
