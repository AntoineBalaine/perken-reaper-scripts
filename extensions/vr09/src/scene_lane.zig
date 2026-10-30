//! The automation lane of the Scene parameter, as the panel needs it: moving or removing a scene leaves the
//! song playing the same scenes, because the lane's points follow, and a point can be put at the edit cursor.
//!
//! This is a port of the design lab's `scene_link.lua` (`remap_lane` and `insert_point`), which does the same
//! through the ReaScript API.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const plugin = @import("plugin.zig");
const scenes = @import("scenes.zig");
const actions = @import("actions.zig");
const glue = @import("reaper_glue.zig");

const Plugin = plugin.Plugin;

/// The plugin's track, its place in the track's FX chain, and the index of its Scene parameter.
pub const Target = struct { track: Reaper.MediaTrack, fx: c_int, param: c_int };

/// The envelope point shape that holds its value until the next point, so that no scene is selected on the
/// way between two.
const square_shape: c_int = 1;

/// Where the plugin is, or null when REAPER has not said yet.
pub fn target(p: *Plugin) ?Target {
    if (p.track == null) p.track = glue.trackOf(p.host);
    if (p.track == null) return null;
    const fx = glue.fxIndexOf(p.host) orelse return null;
    return .{ .track = p.track, .fx = @intCast(fx), .param = @intCast(plugin.sceneParamIndex()) };
}

/// The position that a lane point's value selects, in the units that REAPER reports for the parameter.
pub fn positionOf(value: f64, min: f64, max: f64) i64 {
    if (max == min) return 0;
    return @intFromFloat(@floor((value - min) / (max - min) * @as(f64, scenes.max_scenes) + 0.5));
}

const Range = struct { min: f64, max: f64 };

fn rangeOf(t: Target) Range {
    var min: f64 = 0;
    var max: f64 = 0;
    var mid: f64 = 0;
    _ = Reaper.TrackFX_GetParamEx(t.track, t.fx, t.param, &min, &max, &mid);
    return .{ .min = min, .max = max };
}

/// Gives every point of the Scene lane (and of its automation items) its new position, so that moving or
/// removing a scene leaves the song playing the same scenes. Each point is read once and written once, so
/// none is mapped twice. `count` is how many scenes the list had before the change. Returns how many points
/// changed.
pub fn remapLane(t: Target, count: usize, map: *const scenes.Mapping) usize {
    const env_raw = Reaper.GetFXEnvelope(t.track, t.fx, t.param, false);
    if (@intFromPtr(env_raw) == 0) return 0;
    const env: *Reaper.TrackEnvelope = env_raw;
    const range = rangeOf(t);
    var changed: usize = 0;
    Reaper.Undo_BeginBlock();
    var item: c_int = -1;
    const items = Reaper.CountAutomationItems(env);
    while (item < items) : (item += 1) {
        const points = Reaper.CountEnvelopePointsEx(env, item);
        var index: c_int = 0;
        while (index < points) : (index += 1) {
            var time: f64 = 0;
            var value: f64 = 0;
            var shape: c_int = 0;
            var tension: f64 = 0;
            var selected: bool = false;
            if (!Reaper.GetEnvelopePointEx(env, item, index, &time, &value, &shape, &tension, &selected)) continue;
            const position = positionOf(value, range.min, range.max);
            if (position < 1 or position > count) continue;
            const new: i64 = map[@intCast(position - 1)];
            if (new == position) continue;
            var new_value = actions.laneValue(@intCast(new), range.min, range.max);
            var no_sort = true;
            _ = Reaper.SetEnvelopePointEx(env, item, index, &time, &new_value, &shape, &tension, &selected, &no_sort);
            changed += 1;
        }
        _ = Reaper.Envelope_SortPointsEx(env, item);
    }
    Reaper.Undo_EndBlock("Move the points of the VR-09 scene lane", -1);
    Reaper.UpdateArrange();
    return changed;
}

/// Puts a square point at the edit cursor on the Scene lane, set to `position`. GetFXEnvelope creates the lane
/// when the track does not have one. Returns the time, or null when REAPER could not make the lane.
pub fn insertPoint(t: Target, position: u8) ?f64 {
    const env_raw = Reaper.GetFXEnvelope(t.track, t.fx, t.param, true);
    if (@intFromPtr(env_raw) == 0) return null;
    const env: *Reaper.TrackEnvelope = env_raw;
    const range = rangeOf(t);
    const time = Reaper.GetCursorPosition();
    var no_sort = false;
    Reaper.Undo_BeginBlock();
    _ = Reaper.InsertEnvelopePoint(env, time, actions.laneValue(position, range.min, range.max), square_shape, 0, false, &no_sort);
    _ = Reaper.Envelope_SortPoints(env);
    Reaper.Undo_EndBlock("Insert a VR-09 scene point", -1);
    Reaper.UpdateArrange();
    return time;
}

test "a lane value gives back its position" {
    const value = actions.laneValue(42, 0, 1);
    try std.testing.expectEqual(@as(i64, 42), positionOf(value, 0, 1));
    try std.testing.expectEqual(@as(i64, 7), positionOf(actions.laneValue(7, 0, 127), 0, 127));
}

test "every declaration compiles" {
    std.testing.refAllDecls(@This());
}
