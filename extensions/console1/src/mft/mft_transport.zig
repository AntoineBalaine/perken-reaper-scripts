const std = @import("std");
const reaper = @import("reaper").reaper;

// Transport control for TRANSPORT mode. The eight top encoders each have a
// continuous function on rotation and a momentary function on press, mirroring
// the Console One transport controls within the MFT's smaller surface.
//
// Rotations: jog, scrub, zoom H, zoom V, playrate, grid, track select, marker jog.
// Presses:   loop toggle, loop start, loop end, snap, then the automation modes
//            trim, read, latch, write.

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
const CMD_INSERT_TRACK = 40001;
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
        6 => "NewTrk",
        7 => "Marker",
        else => "-",
    };
}

fn adjustRate(delta: i8) void {
    const cur = reaper.Master_GetPlayRate(0);
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
        6 => reaper.Main_OnCommand(CMD_INSERT_TRACK, 0), // insert new track
        7 => toggleMarker(),
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
    try std.testing.expectEqualStrings("Rate=1", pressLabel(4));
    try std.testing.expectEqualStrings("Snap", pressLabel(5));
    try std.testing.expectEqualStrings("Marker", pressLabel(7));
    try std.testing.expectEqualStrings("-", pressLabel(0));
}
