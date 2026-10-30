//! Auto lane watcher: while it is on, touching an FX parameter shows that
//! parameter's envelope lane (and hides the track's others); moving to
//! another track, or closing or unfocusing the FX, dismisses the lane, and a
//! lane that received no automation is removed again. In trim/read mode, a
//! tweak in the plugin UI trims the lane's single point instead of snapping
//! back. Moved here from reaperConsole1, where Console1's control surface fed
//! it; perken-utilities' own hidden control surface (surface.zig) now
//! delivers the same notifications, and is only registered while the watcher
//! is on.
const std = @import("std");
const reaper = @import("reaper").reaper;
const sws = @import("sws.zig");
const surface = @import("surface.zig");
const actions = @import("actions.zig");
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
    if (!watcher_active) {
        // SWS loads after this extension (plugin files load in name order),
        // so its functions are resolved when the watcher starts, not at load.
        if (!sws.available) sws.init();
        if (!surface.acquire()) {
            log.err("auto lane watcher: could not register the control surface", .{});
            return;
        }
        watcher_active = true;
    } else {
        watcher_active = false;
        dismissLane();
        surface.release();
    }
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
    const override = reaper.GetGlobalAutomationOverride();
    const effective_mode: c_int = if (override >= 0)
        override
    else
        @intFromFloat(reaper.GetMediaTrackInfo_Value(track, "I_AUTOMODE"));
    // 0 = trim/read, 1 = read. Touch/write/latch (2/3/4) write points natively,
    // so we must not interfere there. 5 = bypass.
    if (effective_mode != 0 and effective_mode != 1) return;

    const env_raw = reaper.GetFXEnvelope(track, fx_index, param_index, false);
    if (@intFromPtr(env_raw) == 0) return;
    const env: *reaper.TrackEnvelope = env_raw;

    // Only the single-point floating lane is handled. A multi-point lane's trim
    // is an offset of every point, which is a different operation.
    if (reaper.CountEnvelopePoints(env) != 1) return;

    // The point stores the parameter's native value in the envelope's scaling
    // space, not the normalized 0..1 value. We read the native value the user
    // just set (the parameter already sits at it) and convert through the
    // scaling mode: identity for unscaled envelopes, fader curve otherwise.
    var min_val: f64 = 0;
    var max_val: f64 = 0;
    const native_value = reaper.TrackFX_GetParam(track, fx_index, param_index, &min_val, &max_val);
    const scaling_mode = reaper.GetEnvelopeScalingMode(env);
    var target_value = reaper.ScaleToEnvelopeMode(scaling_mode, native_value);

    // Preserve the point's time, shape, tension and selection; only the value
    // changes. We read the existing point to fill those fields.
    var time: f64 = 0;
    var old_value: f64 = 0;
    var shape: c_int = 0;
    var tension: f64 = 0;
    var selected: bool = false;
    if (!reaper.GetEnvelopePoint(env, 0, &time, &old_value, &shape, &tension, &selected)) return;

    // The csurf callback fires every frame while the envelope drives the
    // parameter, so without this guard we would rewrite the same value
    // continuously. Only write when the user actually moved the value.
    if (@abs(old_value - target_value) < 1e-9) return;

    var no_sort = false;
    _ = reaper.SetEnvelopePoint(env, 0, &time, &target_value, &shape, &tension, &selected, &no_sort);
    reaper.UpdateArrange();
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
    reaper.SetOnlyTrackSelected(track);
    reaper.Main_OnCommand(CMD_HIDE_ALL_ENVELOPES, 0);
    reaper.Main_OnCommand(CMD_SHOW_LAST_TOUCHED_FX_ENV, 0);

    const env_raw = reaper.GetFXEnvelope(track, fx_index, param_index, false);
    if (@intFromPtr(env_raw) == 0) {
        log.warn("could not get envelope after showing it for fx={d} param={d}", .{ fx_index, param_index });
        return;
    }
    const env: *reaper.TrackEnvelope = env_raw;

    current_lane = .{
        .track = track,
        .fx_index = fx_index,
        .param_index = param_index,
        .initial_point_count = reaper.CountEnvelopePoints(env),
        .env = env,
    };
}

/// Dismisses the current lane. A lane the user only trimmed (no inserted
/// automation points beyond the seed) is removed entirely; a lane with real
/// automation is kept and merely hidden.
fn dismissLane() void {
    const lane = current_lane orelse return;

    const count = reaper.CountEnvelopePoints(lane.env);
    const should_remove = count <= lane.initial_point_count;
    log.debug("dismissLane: count={d} initial={d} -> {s}", .{ count, lane.initial_point_count, if (should_remove) "remove" else "keep" });
    if (should_remove) {
        removeEnvelope(lane.track, lane.fx_index, lane.param_index);
    }

    reaper.SetOnlyTrackSelected(lane.track);
    reaper.Main_OnCommand(CMD_HIDE_ALL_ENVELOPES, 0);
    reaper.UpdateArrange();
    current_lane = null;
}

/// Removes an FX parameter envelope entirely. There is no API to delete an
/// envelope and deleting all its points leaves an empty lane behind, so we
/// reproduce the me2beats "Delete envelope for last touched parameter" script:
/// read the track chunk through the SWS fast-string API, splice out the target
/// <PARMENV ...> block, and write the chunk back.
fn removeEnvelope(track: reaper.MediaTrack, fx_index: c_int, param_index: c_int) void {
    if (!sws.available) {
        log.err("removeEnvelope: SWS extension not available", .{});
        return;
    }

    // Find the ordinal of the target envelope among the track's FX-parameter
    // envelopes. This matches the order PARMENV blocks appear in the chunk
    // (built-in vol/pan envelopes serialize as VOLENV/PANENV, not PARMENV).
    const env_count = reaper.CountTrackEnvelopes(track);
    var ordinal: c_int = -1;
    var target: ?c_int = null;
    var i: c_int = 0;
    while (i < env_count) : (i += 1) {
        const tr_env = reaper.GetTrackEnvelope(track, i);
        if (@intFromPtr(tr_env) == 0) continue;
        var e_fx: c_int = -1;
        var e_prm: c_int = -1;
        _ = reaper.Envelope_GetParentTrack(tr_env, &e_fx, &e_prm);
        if (e_fx < 0) continue; // skip built-in (vol/pan/etc.) envelopes
        ordinal += 1;
        if (e_fx == fx_index and e_prm == param_index) {
            target = ordinal;
            break;
        }
    }
    const target_ordinal = target orelse {
        log.err("removeEnvelope: no matching FX-param envelope (fx={d} prm={d})", .{ fx_index, param_index });
        return;
    };

    // Read the track chunk via the SWS fast-string API (handles any size).
    const fs = sws.SNM_CreateFastString("");
    defer sws.SNM_DeleteFastString(fs);
    if (!sws.SNM_GetSetObjectState(@ptrCast(track), fs, false, false)) {
        log.err("removeEnvelope: SNM get chunk failed", .{});
        return;
    }
    const chunk = std.mem.span(sws.SNM_GetFastString(fs));

    // Find the target-th <PARMENV ... > block. Non-greedy like the script's
    // '<PARMENV.->' pattern: from "<PARMENV" to the first '>'.
    var x: c_int = -1;
    var search: usize = 0;
    var blk_start: usize = 0;
    var blk_end: usize = 0;
    var found = false;
    while (std.mem.indexOfPos(u8, chunk, search, "<PARMENV")) |p| {
        const gt = std.mem.indexOfScalarPos(u8, chunk, p, '>') orelse break;
        x += 1;
        if (x == target_ordinal) {
            blk_start = p;
            blk_end = gt + 1;
            if (blk_end < chunk.len and chunk[blk_end] == '\n') blk_end += 1; // drop trailing newline
            found = true;
            break;
        }
        search = gt + 1;
    }
    if (!found) {
        log.err("removeEnvelope: PARMENV block #{d} not found", .{target_ordinal});
        return;
    }

    // Build the chunk without the block.
    const alloc = std.heap.page_allocator;
    const new_len = chunk.len - (blk_end - blk_start);
    const new_buf = alloc.allocSentinel(u8, new_len, 0) catch return;
    defer alloc.free(new_buf);
    @memcpy(new_buf[0..blk_start], chunk[0..blk_start]);
    @memcpy(new_buf[blk_start..new_len], chunk[blk_end..]);

    // Write the chunk back, guarding against reentrant csurf notifications.
    const prev_ignore = surface.ignore_notifications;
    surface.ignore_notifications = true;
    defer surface.ignore_notifications = prev_ignore;

    const fs2 = sws.SNM_CreateFastString("");
    defer sws.SNM_DeleteFastString(fs2);
    _ = sws.SNM_SetFastString(fs2, new_buf.ptr);
    const ok = sws.SNM_GetSetObjectState(@ptrCast(track), fs2, true, false);
    log.debug("removeEnvelope: ord={d} spliced [{d}..{d}] set={}", .{ target_ordinal, blk_start, blk_end, ok });
}

fn toggleAction(_: *actions.RunCtx) void {
    toggle();
}

pub const entries = [_]actions.Entry{
    .{ .name = "AutoLaneWatcher", .def = .{
        .steps = &.{.{ .func = &toggleAction }},
        .desc = "Toggle auto lane watcher (show the last-touched FX parameter's envelope)",
        .toggle_state = &isActive,
    } },
};

const assert = std.debug.assert;
