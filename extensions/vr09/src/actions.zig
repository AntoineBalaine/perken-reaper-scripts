//! The plugin's REAPER actions: step to the next or previous scene (for a footswitch or a page-turner
//! pedal), and put a point on the Scene lane at each marker that is named like a scene.
//!
//! The actions belong to the plugin, so they exist wherever the plugin is installed. They are
//! registered once, when the first instance loads (as `VR09_Command` is), and act on an instance of the
//! plugin directly: the one on a selected track, or else the first one found. REAPER runs actions on
//! its main thread, which is the thread that owns each instance's scene list.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const glue = @import("reaper_glue.zig");
const plugin = @import("plugin.zig");
const scenes = @import("scenes.zig");

const log = std.log.scoped(.actions);

const title = "VR-09 scene points";
/// The envelope point shape that holds its value until the next point, so that no scene is selected
/// on the way between two.
const square_shape: c_int = 1;
const max_markers = 512;

// ---- the pure rules --------------------------------------------------------------------

/// The scene a step lands on. The scenes are not a loop: a page-turner pressed by mistake at the last
/// scene must not jump back to the first one in the middle of a song. With no scene selected, either
/// direction goes to the first.
pub fn stepPosition(current: u8, count: u8, delta: i32) u8 {
    if (count == 0) return 0;
    if (current == 0) return 1;
    const moved = @as(i32, current) + delta;
    return @intCast(std.math.clamp(moved, 1, @as(i32, count)));
}

/// The scene that a marker's name stands for: the scene of that name (ignoring case), or else a scene
/// position written as a number. Gives the position, or null.
pub fn matchScene(list: *const scenes.List, marker_name: []const u8) ?u8 {
    const name = std.mem.trim(u8, marker_name, " \t");
    if (name.len == 0) return null;
    var position: usize = 1;
    while (position <= list.count) : (position += 1) {
        if (std.ascii.eqlIgnoreCase(list.get(position).?.name(), name)) return @intCast(position);
    }
    const number = std.fmt.parseInt(u8, name, 10) catch return null;
    if (number < 1 or number > list.count) return null;
    return number;
}

/// The value of a lane point that selects `position`, for a parameter whose reported range is `min`
/// to `max`. A lane point holds the parameter's value in the units REAPER reports for it, so the
/// position is scaled across that range, whatever it is.
pub fn laneValue(position: u8, min: f64, max: f64) f64 {
    return min + @as(f64, @floatFromInt(position)) / @as(f64, scenes.max_scenes) * (max - min);
}

// ---- finding the instance ----------------------------------------------------------

/// The instance on a selected track, or else the first one.
fn pickInstance() ?*plugin.Plugin {
    var first: ?*plugin.Plugin = null;
    for (plugin.instances) |maybe| {
        const p = maybe orelse continue;
        if (first == null) first = p;
        if (p.track == null) p.track = glue.trackOf(p.host);
        if (p.track != null and Reaper.GetMediaTrackInfo_Value(p.track, "I_SELECTED") != 0) return p;
    }
    return first;
}

// ---- stepping between scenes -----------------------------------------------------------

pub fn step(io: std.Io, delta: i32) void {
    const p = pickInstance() orelse {
        log.warn("scene step: there is no VR-09 plugin", .{});
        return;
    };
    const next = stepPosition(p.scene.load(.monotonic), p.scene_list.count, delta);
    if (next == 0 or next == p.scene.load(.monotonic)) return;
    p.selectScene(io, next) catch |err| log.warn("scene {d} could not be selected: {s}", .{ next, @errorName(err) });
}

fn nextScene() void {
    const io = plugin.hostIo();
    step(io, 1);
}

fn previousScene() void {
    const io = plugin.hostIo();
    step(io, -1);
}

// ---- scene points from the project's markers ------------------------------------------

/// Because the real ABI of EnumProjectMarkers takes a `const char **` for the name, and reaziglib
/// types it as a plain string pointer, it is re-typed here.
fn enumProjectMarkers(idx: c_int, pos: *f64, name: *[*:0]const u8) c_int {
    const f: *const fn (idx: c_int, isrgnOut: ?*bool, posOut: ?*f64, rgnendOut: ?*f64, nameOut: ?*[*:0]const u8, markrgnindexnumberOut: ?*c_int) callconv(.c) c_int = @ptrCast(Reaper.EnumProjectMarkers);
    return f(idx, null, pos, null, name, null);
}

const Placement = struct { time: f64, position: u8 };

fn orderByTime(_: void, a: Placement, b: Placement) bool {
    return a.time < b.time;
}

/// Puts a square point on the Scene lane at `time`, or moves the point that is already there, so
/// that running the action again does not stack points.
fn setPoint(env: *Reaper.TrackEnvelope, time: f64, value: f64) void {
    var no_sort = true;
    const count = Reaper.CountEnvelopePoints(env);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        var t: f64 = 0;
        var v: f64 = 0;
        var shape: c_int = 0;
        var tension: f64 = 0;
        var selected: bool = false;
        if (!Reaper.GetEnvelopePoint(env, i, &t, &v, &shape, &tension, &selected)) continue;
        if (@abs(t - time) > 0.0005) continue;
        var new_value = value;
        var new_shape = square_shape;
        _ = Reaper.SetEnvelopePoint(env, i, &t, &new_value, &new_shape, &tension, &selected, &no_sort);
        return;
    }
    _ = Reaper.InsertEnvelopePoint(env, time, value, square_shape, 0, false, &no_sort);
}

fn tell(message: [:0]const u8) void {
    _ = Reaper.ShowMessageBox(message.ptr, title, 0);
}

fn scenePointsFromMarkers() void {
    const p = pickInstance() orelse return tell("There is no VR-09 plugin.");
    if (p.track == null) return tell("The plugin has not found its track yet.");
    const fx = glue.fxIndexOf(p.host) orelse return tell("REAPER did not say where the plugin is on its track.");
    const param: c_int = @intCast(plugin.sceneParamIndex());

    // The markers and region starts whose name stands for a scene, in time order.
    var placements: [max_markers]Placement = undefined;
    var placed: usize = 0;
    var skipped: usize = 0;
    var idx: c_int = 0;
    while (placed < max_markers) {
        var pos: f64 = 0;
        var name: [*:0]const u8 = "";
        const next = enumProjectMarkers(idx, &pos, &name);
        if (next == 0) break;
        idx = next;
        if (matchScene(p.scene_list, std.mem.span(name))) |position| {
            placements[placed] = .{ .time = pos, .position = position };
            placed += 1;
        } else {
            skipped += 1;
        }
    }
    if (placed == 0) return tell("No marker or region is named like a scene, or numbered like one.");
    std.mem.sort(Placement, placements[0..placed], {}, orderByTime);

    const env_raw = Reaper.GetFXEnvelope(p.track, @intCast(fx), param, true);
    if (@intFromPtr(env_raw) == 0) return tell("REAPER could not create the Scene lane.");
    const env: *Reaper.TrackEnvelope = env_raw;
    var min: f64 = 0;
    var max: f64 = 0;
    var mid: f64 = 0;
    _ = Reaper.TrackFX_GetParamEx(p.track, @intCast(fx), param, &min, &max, &mid);
    Reaper.Undo_BeginBlock();
    for (placements[0..placed]) |placement| setPoint(env, placement.time, laneValue(placement.position, min, max));
    _ = Reaper.Envelope_SortPoints(env);
    Reaper.Undo_EndBlock("Put VR-09 scene points at the markers", -1);
    Reaper.UpdateArrange();

    // Because a message box would stop REAPER until someone closed it, the unmatched markers are reported
    // on the console, which does not wait for anyone. Only a failure that stops the action has a box.
    var msg: [160:0]u8 = undefined;
    const text = std.mem.printSentinel(&msg, "VR-09: put {d} scene points on the lane; {d} markers did not match a scene.\n", .{ placed, skipped }, 0) catch return;
    log.info("put {d} scene points, {d} markers did not match a scene", .{ placed, skipped });
    if (skipped > 0) Reaper.ShowConsoleMsg(text.ptr);
}

// ---- registering the actions -----------------------------------------------------

const Definition = struct {
    /// The command id is `_VR09_<id>`; keymaps and toolbars refer to it.
    id: [:0]const u8,
    name: [:0]const u8,
    run: *const fn () void,
};

const definitions = [_]Definition{
    .{ .id = "VR09_NEXT_SCENE", .name = "VR-09: next scene", .run = &nextScene },
    .{ .id = "VR09_PREVIOUS_SCENE", .name = "VR-09: previous scene", .run = &previousScene },
    .{ .id = "VR09_SCENE_POINTS_FROM_MARKERS", .name = "VR-09: put a scene point at each marker named like a scene", .run = &scenePointsFromMarkers },
};

/// The registrations REAPER keeps pointers to, so they are built at compile time and live for the whole
/// session.
const registrations = blk: {
    var regs: [definitions.len]Reaper.custom_action_register_t = undefined;
    for (definitions, 0..) |d, i| regs[i] = .{ .section = 0, .id_str = d.id.ptr, .name = d.name.ptr };
    break :blk regs;
};

var command_ids: [definitions.len]c_int = @splat(0);
var registered = false;

fn onCommand(sec: ?Reaper.KbdSectionInfo, command: c_int, val: c_int, val2hw: c_int, relmode: c_int, hwnd: Reaper.HWND) callconv(.c) c_char {
    _ = .{ sec, val, val2hw, relmode, hwnd };
    if (command == 0) return 0;
    for (command_ids, 0..) |id, i| {
        if (id != command) continue;
        definitions[i].run();
        return 1;
    }
    return 0;
}

/// Registers the actions, once. Called when the first instance loads.
pub fn register() void {
    if (registered or !glue.ready) return;
    registered = true;
    for (&registrations, 0..) |*reg, i| {
        command_ids[i] = Reaper.plugin_register("custom_action", @ptrCast(@constCast(reg)));
        if (command_ids[i] == 0) log.warn("the action {s} could not be registered", .{reg.id_str});
    }
    _ = Reaper.plugin_register("hookcommand2", @ptrCast(@constCast(&onCommand)));
}

/// Stops handling the actions. REAPER cannot remove an action it was given, but it must not call a
/// function of a library that is gone.
pub fn unregister() void {
    if (!registered) return;
    registered = false;
    _ = Reaper.plugin_register("-hookcommand2", @ptrCast(@constCast(&onCommand)));
}

// ---- tests ------------------------------------------------------------------

test "stepping stays between the first and the last scene" {
    try std.testing.expectEqual(@as(u8, 3), stepPosition(2, 5, 1));
    try std.testing.expectEqual(@as(u8, 1), stepPosition(2, 5, -1));
    // No wrap-around at the ends.
    try std.testing.expectEqual(@as(u8, 5), stepPosition(5, 5, 1));
    try std.testing.expectEqual(@as(u8, 1), stepPosition(1, 5, -1));
    // With none selected, both directions go to the first; with no scenes there is nowhere to go.
    try std.testing.expectEqual(@as(u8, 1), stepPosition(0, 5, 1));
    try std.testing.expectEqual(@as(u8, 1), stepPosition(0, 5, -1));
    try std.testing.expectEqual(@as(u8, 0), stepPosition(0, 0, 1));
}

test "a marker stands for the scene of its name, or for its number" {
    const list = try std.testing.allocator.create(scenes.List);
    defer std.testing.allocator.destroy(list);
    list.* = .{};
    const patch = @import("dump.zig").Dump{};
    _ = try list.add("Verse", &patch);
    _ = try list.add("Big Chorus", &patch);
    _ = try list.add("Solo", &patch);
    try std.testing.expectEqual(@as(?u8, 2), matchScene(list, "big chorus"));
    try std.testing.expectEqual(@as(?u8, 1), matchScene(list, "  VERSE "));
    try std.testing.expectEqual(@as(?u8, 3), matchScene(list, "3"));
    try std.testing.expectEqual(@as(?u8, null), matchScene(list, "4"));
    try std.testing.expectEqual(@as(?u8, null), matchScene(list, "0"));
    try std.testing.expectEqual(@as(?u8, null), matchScene(list, "Bridge"));
    try std.testing.expectEqual(@as(?u8, null), matchScene(list, ""));
}

test "a lane value scales across the range that REAPER reports" {
    try std.testing.expectEqual(@as(f64, 2), laneValue(2, 0, 127));
    try std.testing.expectApproxEqAbs(@as(f64, 2.0 / 127.0), laneValue(2, 0, 1), 1e-12);
}
