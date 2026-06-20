const std = @import("std");
const reaper = @import("reaper").reaper;
const pReaper = @import("pReaper.zig");
const log = std.log.scoped(.auto_lane_watcher);

// zRun fires ~30x/sec. Poll every 10 ticks ≈ 3 checks/sec.
const POLL_INTERVAL: u32 = 10;

const ActiveLane = struct {
    track: reaper.MediaTrack,
    env: *reaper.TrackEnvelope,
    fx_index: c_int,
    param_index: c_int,
    // Point count when the lane was first opened. A lane becomes persistent
    // once the user adds at least one new point above this baseline.
    initial_point_count: c_int,
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
        dismissCurrent();
    }
    log.info("auto lane watcher {s}", .{if (watcher_active) "enabled" else "disabled"});
}

/// Called from the SETLASTTOUCHEDFX csurf callback.
/// Shows the envelope for the newly touched parameter and hides the previous
/// temporary lane if the user added no new points to it.
pub fn onLastTouchedFx(track: reaper.MediaTrack, fx_index: c_int, param_index: c_int) void {
    assert(watcher_active);

    // Same lane already shown — nothing to do.
    if (current_lane) |lane| {
        if (lane.track == track and lane.fx_index == fx_index and lane.param_index == param_index)
            return;
    }

    dismissCurrent();
    showLane(track, fx_index, param_index);
}

/// Called when SETFOCUSEDFX fires with all-null params (focus cleared) or when
/// SETFXOPEN fires with the FX window closed. Hides the current temporary lane
/// unless the user has already added points to it (making it persistent).
pub fn onFocusDismissed() void {
    dismissCurrent();
}

/// Called from zRun, throttled to POLL_INTERVAL ticks. Promotes the active
/// lane to persistent once the user adds a new point to it.
pub fn pollRun() void {
    if (!watcher_active) return;
    poll_tick += 1;
    if (poll_tick < POLL_INTERVAL) return;
    poll_tick = 0;

    const lane = current_lane orelse return;

    if (pReaper.CountEnvelopePoints(.{lane.env}) > lane.initial_point_count) {
        log.debug("auto lane: user added a point — lane is now persistent", .{});
        current_lane = null; // stop watching; keep the lane visible
    }
}

fn showLane(track: reaper.MediaTrack, fx_index: c_int, param_index: c_int) void {
    // Get or create the envelope. With create=true this always returns non-null,
    // but the C API does not enforce that at the type level.
    const env_raw = pReaper.GetFXEnvelope(.{ track, fx_index, param_index, true });
    if (@intFromPtr(env_raw) == 0) {
        log.warn("GetFXEnvelope returned null for fx={d} param={d}", .{ fx_index, param_index });
        return;
    }
    const env: *reaper.TrackEnvelope = env_raw;

    const initial_count = pReaper.CountEnvelopePoints(.{env});

    // When Reaper creates a fresh envelope it auto-inserts a point at t=0.
    // We remove it so the lane starts empty and any subsequent point is
    // genuinely from the user.
    if (initial_count == 1) {
        _ = pReaper.DeleteEnvelopePointRange(.{ env, -1.0, 0.001 });
        _ = pReaper.Envelope_SortPoints(.{env});
    }

    setEnvelopeVisible(env, true);
    pReaper.UpdateArrange(.{});

    current_lane = .{
        .track = track,
        .env = env,
        .fx_index = fx_index,
        .param_index = param_index,
        .initial_point_count = if (initial_count == 1) 0 else initial_count,
    };
    poll_tick = 0;
}

fn dismissCurrent() void {
    const lane = current_lane orelse return;

    const has_new_points = pReaper.CountEnvelopePoints(.{lane.env}) > lane.initial_point_count;
    if (!has_new_points) {
        setEnvelopeVisible(lane.env, false);
        pReaper.UpdateArrange(.{});
    }

    current_lane = null;
}

fn setEnvelopeVisible(env: *reaper.TrackEnvelope, visible: bool) void {
    // 64 KB covers all realistic envelope state chunks. The VIS flag lives
    // within the first ~200 bytes but we must write the full chunk back to
    // avoid truncating existing user points.
    var buf: [65536:0]u8 = undefined;
    if (!pReaper.GetEnvelopeStateChunk(.{ env, @as(*i8, @ptrCast(&buf[0])), @as(c_int, @intCast(buf.len)), false })) return;

    const chunk = std.mem.span(@as([*:0]u8, &buf));

    // A well-formed chunk ends with '>'. Truncated data must not be written back.
    if (!std.mem.endsWith(u8, chunk, ">")) {
        log.warn("envelope state chunk appears truncated — skipping VIS toggle", .{});
        return;
    }

    const vis_pos = std.mem.indexOf(u8, chunk, "VIS ") orelse {
        log.warn("VIS flag not found in envelope state chunk", .{});
        return;
    };
    const vis_val_pos = vis_pos + "VIS ".len;
    assert(vis_val_pos < chunk.len);

    buf[vis_val_pos] = if (visible) '1' else '0';

    _ = pReaper.SetEnvelopeStateChunk(.{ env, @as([*:0]const u8, @ptrCast(&buf)), false });
}

const assert = std.debug.assert;
