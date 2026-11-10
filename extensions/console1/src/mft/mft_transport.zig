const std = @import("std");
const reaper = @import("reaper").reaper;

// Transport control for TRANSPORT mode. The eight top encoders each have a
// continuous function on rotation and a momentary function on press, mirroring
// the Console One transport controls within the MFT's smaller surface.
//
// Rotations: jog, scrub, zoom H, zoom V, playrate, grid, track select, marker jog.
// Presses:   play and stop, play and pause, fit horizontally, fit vertically, reset the rate, snap, record, marker.
// The bottom row selects the pages, and its turns are the loop start and end, the loop, and the volume and pan of the track.

// REAPER main-action command IDs.
const CMD_SNAP = 1157;
const CMD_MARKER_PREV = 40172;
const CMD_MARKER_NEXT = 40173;
const CMD_GRID_DIVIDE = 40783;
const CMD_GRID_MULTIPLY = 40786;
const CMD_NEXT_TRACK = 40285;
const CMD_PREV_TRACK = 40286;
const CMD_NEXT_ITEM = 40417; // Item navigation: select and move to next item
const CMD_PREV_ITEM = 40416; // Item navigation: select and move to previous item
const CMD_PLAY_STOP = 40044;
const CMD_PLAY_PAUSE = 40073;

const CMD_INSERT_MARKER = 40157;
const CMD_DELETE_MARKER_NEAR_CURSOR = 40613;
const CMD_RECORD = 1013;
// The two zoom-fit command IDs are best guesses and need confirming against the
// REAPER action list on hardware (right-click the action, copy command ID).
const CMD_ZOOM_FIT_PROJECT_H = 40295; // View: fit whole project horizontally (VERIFY)
const CMD_ZOOM_FIT_TRACKS_V = 40110; // View: minimize/fit all tracks vertically (VERIFY)

pub fn rotationLabel(idx: usize) [:0]const u8 {
    return switch (idx) {
        0 => "Jog",
        1 => "Item",
        2 => "Zoom H",
        3 => "Zoom V",
        4 => "Rate",
        5 => "Grid",
        6 => "Trk",
        7 => "Mkr",
        else => "-",
    };
}

// Presses reset or toggle the function of their own knob. Only the knobs with a
// meaningful momentary action are assigned.
pub fn pressLabel(idx: usize) [:0]const u8 {
    return switch (idx) {
        0 => "Play/Stop",
        1 => "Play/Pause",
        2 => "FitH",
        3 => "FitV",
        4 => "Rate=1",
        5 => "Snap",
        6 => "Rec",
        7 => "Marker",
        else => "-",
    };
}

fn adjustRate(delta: i8) void {
    const cur = reaper.Master_GetPlayRate(null);
    const step = 0.01 * @as(f64, @floatFromInt(delta));
    const new_rate = std.math.clamp(cur + step, 0.25, 4.0);
    reaper.CSurf_OnPlayRateChange(new_rate);
}

// Vertical zoom step, used by knob 4's rotation and by knob 3 when pressed.
pub fn zoomVertical(delta: i8) void {
    reaper.CSurf_OnZoom(0, delta);
}

pub fn onRotate(idx: u3, delta: i8) void {
    switch (idx) {
        0 => reaper.CSurf_OnRewFwd(0, delta),
        1 => reaper.Main_OnCommand(if (delta > 0) CMD_NEXT_ITEM else CMD_PREV_ITEM, 0),
        2 => reaper.CSurf_OnZoom(delta, 0),
        3 => zoomVertical(delta),
        4 => adjustRate(delta),
        5 => reaper.Main_OnCommand(if (delta > 0) CMD_GRID_MULTIPLY else CMD_GRID_DIVIDE, 0),
        6 => reaper.Main_OnCommand(if (delta > 0) CMD_NEXT_TRACK else CMD_PREV_TRACK, 0),
        7 => reaper.Main_OnCommand(if (delta > 0) CMD_MARKER_NEXT else CMD_MARKER_PREV, 0),
    }
}

pub fn onPress(idx: u3) void {
    switch (idx) {
        0 => reaper.Main_OnCommand(CMD_PLAY_STOP, 0),
        1 => reaper.Main_OnCommand(CMD_PLAY_PAUSE, 0),
        2 => reaper.Main_OnCommand(CMD_ZOOM_FIT_PROJECT_H, 0), // fit project horizontally
        3 => reaper.Main_OnCommand(CMD_ZOOM_FIT_TRACKS_V, 0), // fit/minimize tracks vertically
        4 => reaper.CSurf_OnPlayRateChange(1.0), // reset playrate
        5 => reaper.Main_OnCommand(CMD_SNAP, 0), // toggle grid snap
        6 => reaper.Main_OnCommand(CMD_RECORD, 0), // record
        7 => toggleMarker(),
    }
}

/// The knob of the bottom row that puts the modules of the track in another order, which the MIDI handler turns.
pub const order_knob = 2;

/// The words of the turns of the bottom row, whose pushes select the pages. The last two are free.
pub fn bottomLabel(idx: usize) [:0]const u8 {
    return switch (idx) {
        0 => "Loop In",
        1 => "Loop Out",
        order_knob => "Order",
        3 => "Loop",
        4 => "Trk Vol",
        5 => "Trk Pan",
        else => "-",
    };
}

/// How far a turn nudges a loop edge: a sixteenth of a quarter note per click, which depends on the tempo.
pub fn nudgeSeconds(tempo: f64, delta: i8) f64 {
    std.debug.assert(tempo > 0);
    return @as(f64, @floatFromInt(delta)) * 60.0 / tempo / 16.0;
}

/// The volume (a linear factor) after a turn: a quarter of a decibel per click, held between silence and about +12 dB.
pub fn stepVolume(current: f64, delta: i8) f64 {
    const db = 20.0 * @log10(@max(current, 1e-6)) + 0.25 * @as(f64, @floatFromInt(delta));
    return std.math.clamp(std.math.pow(f64, 10.0, db / 20.0), 0.0, 4.0);
}

/// The pan, from -1 to 1, after a turn: a hundredth per click.
pub fn stepPan(current: f64, delta: i8) f64 {
    return std.math.clamp(current + 0.01 * @as(f64, @floatFromInt(delta)), -1.0, 1.0);
}

/// A turn of the bottom row in TRANSPORT. `track` is the one that the volume and the pan are for.
pub fn onBottomRotate(idx: usize, delta: i8, track: ?reaper.MediaTrack) void {
    switch (idx) {
        0, 1 => {
            var start: f64 = 0;
            var end: f64 = 0;
            reaper.GetSet_LoopTimeRange(false, true, &start, &end, false);
            const nudge = nudgeSeconds(reaper.Master_GetTempo(), delta);
            if (idx == 0) start = @max(0.0, start + nudge) else end = @max(0.0, end + nudge);
            // An edge cannot pass the other one.
            if (end < start) return;
            reaper.GetSet_LoopTimeRange(true, true, &start, &end, false);
        },
        3 => _ = reaper.GetSetRepeat(if (delta > 0) 1 else 0),
        4 => if (track) |t| {
            const current = reaper.GetMediaTrackInfo_Value(t, "D_VOL");
            _ = reaper.CSurf_OnVolumeChange(t, stepVolume(current, delta), false);
        },
        5 => if (track) |t| {
            const current = reaper.GetMediaTrackInfo_Value(t, "D_PAN");
            _ = reaper.CSurf_OnPanChange(t, stepPan(current, delta), false);
        },
        else => {},
    }
}

// The project marker whose position is at the edit cursor (within a small
// tolerance), or null.
fn markerAtCursor(cursor: f64) ?c_int {
    var idx: c_int = 0;
    var is_rgn: bool = undefined;
    var pos: f64 = undefined;
    var rgn_end: f64 = undefined;
    var name_ptr: [*:0]const u8 = undefined;
    var markrgn_idx: c_int = undefined;
    while (reaper.EnumProjectMarkers(idx, &is_rgn, &pos, &rgn_end, @ptrCast(&name_ptr), &markrgn_idx) != 0) : (idx += 1) {
        if (!is_rgn and @abs(pos - cursor) < 0.02) return markrgn_idx;
    }
    return null;
}

// Insert a marker at the cursor, or remove the one already there. The native
// actions are used so no project pointer is needed.
fn toggleMarker() void {
    const cursor = reaper.GetCursorPosition();
    if (markerAtCursor(cursor) != null) {
        reaper.Main_OnCommand(CMD_DELETE_MARKER_NEAR_CURSOR, 0);
    } else {
        reaper.Main_OnCommand(CMD_INSERT_MARKER, 0);
    }
}

test "transport labels" {
    try std.testing.expectEqualStrings("Jog", rotationLabel(0));
    try std.testing.expectEqualStrings("Item", rotationLabel(1));
    try std.testing.expectEqualStrings("Mkr", rotationLabel(7));
    try std.testing.expectEqualStrings("Rec", pressLabel(6));
    try std.testing.expectEqualStrings("Rate=1", pressLabel(4));
    try std.testing.expectEqualStrings("Snap", pressLabel(5));
    try std.testing.expectEqualStrings("Marker", pressLabel(7));
    try std.testing.expectEqualStrings("Play/Stop", pressLabel(0));
    try std.testing.expectEqualStrings("-", pressLabel(8));
}

test "the bottom row has the loop, the volume and the pan, and a dash where nothing is done" {
    const t = std.testing;
    try t.expectEqualStrings("Loop In", bottomLabel(0));
    try t.expectEqualStrings("Loop", bottomLabel(3));
    try t.expectEqualStrings("Trk Pan", bottomLabel(5));
    try t.expectEqualStrings("Order", bottomLabel(2));
    try t.expectEqualStrings("-", bottomLabel(7));
}

test "the steps of the volume, the pan and the loop edges follow the turn and stay inside their ranges" {
    const t = std.testing;
    // A quarter of a decibel up from 0 dB, and back.
    try t.expectApproxEqAbs(std.math.pow(f64, 10.0, 0.25 / 20.0), stepVolume(1.0, 1), 1e-9);
    try t.expectApproxEqAbs(@as(f64, 1.0), stepVolume(stepVolume(1.0, 4), -4), 1e-9);
    try t.expectEqual(@as(f64, 4.0), stepVolume(4.0, 20));
    try t.expect(stepVolume(0.0, -1) >= 0.0);
    try t.expectApproxEqAbs(@as(f64, 0.05), stepPan(0.0, 5), 1e-9);
    try t.expectEqual(@as(f64, 1.0), stepPan(0.995, 5));
    try t.expectEqual(@as(f64, -1.0), stepPan(-1.0, -1));
    // At 120 bpm a quarter note lasts half a second, so a sixteenth of it lasts 1/32 s.
    try t.expectApproxEqAbs(@as(f64, 1.0 / 32.0), nudgeSeconds(120, 1), 1e-9);
    try t.expectApproxEqAbs(@as(f64, -2.0 / 32.0), nudgeSeconds(120, -2), 1e-9);
}
