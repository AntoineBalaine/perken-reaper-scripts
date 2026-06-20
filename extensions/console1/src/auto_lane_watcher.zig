const std = @import("std");
const reaper = @import("reaper").reaper;
const pReaper = @import("pReaper.zig");
const log = std.log.scoped(.auto_lane_watcher);

const POLL_INTERVAL: u32 = 10;

const CMD_HIDE_ALL_ENVELOPES: c_int = 40889; // Envelope: Hide all envelopes for tracks
const CMD_SHOW_LAST_TOUCHED_FX_ENV: c_int = 41142; // FX: Show/hide track envelope for last touched FX parameter

const ActiveLane = struct {
    track: reaper.MediaTrack,
    fx_index: c_int,
    param_index: c_int,
    initial_point_count: c_int,
    env: *reaper.TrackEnvelope,
};

var watcher_active: bool = false;
var current_lane: ?ActiveLane = null;
var poll_tick: u32 = 0;

pub fn isActive() bool {
    return watcher_active;
}

pub fn toggle() void {
    watcher_active = !watcher_active;
    if (!watcher_active) {
        hideAllOnTrack(current_lane);
        current_lane = null;
    }
    log.info("auto lane watcher {s}", .{if (watcher_active) "enabled" else "disabled"});
}

/// Called from SETLASTTOUCHEDFX. Hides all envelopes on the track then shows
/// the lane for the newly touched parameter.
pub fn onLastTouchedFx(track: reaper.MediaTrack, fx_index: c_int, param_index: c_int) void {
    assert(watcher_active);

    if (current_lane) |lane| {
        if (lane.track == track and lane.fx_index == fx_index and lane.param_index == param_index)
            return;
        if (lane.track != track)
            hideAllOnTrack(current_lane);
    }

    current_lane = null;

    // Hide all envelopes on the track, then show the last-touched one.
    // The track is already selected because the user just interacted with its FX.
    pReaper.Main_OnCommand(.{ CMD_HIDE_ALL_ENVELOPES, 0 });
    pReaper.Main_OnCommand(.{ CMD_SHOW_LAST_TOUCHED_FX_ENV, 0 });

    // Grab the envelope handle so we can watch its point count.
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
    poll_tick = 0;
}

/// Called from the SETFXPARAM csurf callback. When the track is in trim or
/// read mode, REAPER drives the parameter from the envelope and snaps any
/// plugin-UI tweak back to the point. We redirect the tweak instead: we take
/// the value the user set and write it into the envelope point, reproducing
/// what dragging the native trim slider does. This makes a plugin-UI tweak
/// trim the lane, which trim/read mode does not do natively.
///
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
    hideAllOnTrack(current_lane);
    current_lane = null;
}

/// Called from SETLASTTOUCHEDTRACK. Hides envelopes on the old track when
/// the user moves to a different one.
pub fn onTrackChanged(new_track: reaper.MediaTrack) void {
    if (!watcher_active) return;
    const lane = current_lane orelse return;
    if (lane.track != new_track) {
        hideAllOnTrack(current_lane);
        current_lane = null;
    }
}

/// Called from zRun, throttled. Stops watching once the user adds a point
/// (the lane becomes persistent and no longer needs to be auto-hidden).
pub fn pollRun() void {
    if (!watcher_active) return;
    poll_tick += 1;
    if (poll_tick < POLL_INTERVAL) return;
    poll_tick = 0;

    const lane = current_lane orelse return;
    if (pReaper.CountEnvelopePoints(.{lane.env}) > lane.initial_point_count) {
        log.debug("auto lane: user added a point — lane is now persistent", .{});
        current_lane = null;
    }
}

fn hideAllOnTrack(lane: ?ActiveLane) void {
    const l = lane orelse return;
    pReaper.SetOnlyTrackSelected(.{l.track});
    pReaper.Main_OnCommand(.{ CMD_HIDE_ALL_ENVELOPES, 0 });
}

const assert = std.debug.assert;
