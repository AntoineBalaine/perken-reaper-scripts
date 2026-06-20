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
