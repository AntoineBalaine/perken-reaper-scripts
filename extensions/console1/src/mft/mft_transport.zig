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
const CMD_REPEAT = 1068;
const CMD_LOOP_START = 40222;
const CMD_LOOP_END = 40223;
const CMD_SNAP = 1157;
const CMD_MARKER_PREV = 40172;
const CMD_MARKER_NEXT = 40173;
const CMD_GRID_DIVIDE = 40783;
const CMD_GRID_MULTIPLY = 40786;
const CMD_NEXT_TRACK = 40285;
const CMD_PREV_TRACK = 40286;

// Automation mode ids (SetAutomationMode).
const AUTO_TRIM = 0;
const AUTO_READ = 1;
const AUTO_LATCH = 3;
const AUTO_WRITE = 5;

pub fn rotationLabel(idx: usize) [:0]const u8 {
    return switch (idx) {
        0 => "Jog",
        1 => "Scrub",
        2 => "Zoom H",
        3 => "Zoom V",
        4 => "Rate",
        5 => "Grid",
        6 => "Trk",
        7 => "Mkr",
        else => "-",
    };
}

pub fn pressLabel(idx: usize) [:0]const u8 {
    return switch (idx) {
        0 => "Loop",
        1 => "LpStart",
        2 => "LpEnd",
        3 => "Snap",
        4 => "Trim",
        5 => "Read",
        6 => "Latch",
        7 => "Write",
        else => "-",
    };
}

fn adjustRate(delta: i8) void {
    const cur = reaper.Master_GetPlayRate(0);
    const step = 0.01 * @as(f64, @floatFromInt(delta));
    const new_rate = std.math.clamp(cur + step, 0.25, 4.0);
    reaper.CSurf_OnPlayRateChange(new_rate);
}

pub fn onRotate(idx: u3, delta: i8) void {
    switch (idx) {
        0 => reaper.CSurf_OnRewFwd(0, delta),
        1 => reaper.CSurf_ScrubAmt((1.0 / 128.0) * @as(f64, @floatFromInt(delta))),
        2 => reaper.CSurf_OnZoom(delta, 0),
        3 => reaper.CSurf_OnZoom(0, delta),
        4 => adjustRate(delta),
        5 => reaper.Main_OnCommand(if (delta > 0) CMD_GRID_MULTIPLY else CMD_GRID_DIVIDE, 0),
        6 => reaper.Main_OnCommand(if (delta > 0) CMD_NEXT_TRACK else CMD_PREV_TRACK, 0),
        7 => reaper.Main_OnCommand(if (delta > 0) CMD_MARKER_NEXT else CMD_MARKER_PREV, 0),
    }
}

pub fn onPress(idx: u3) void {
    switch (idx) {
        0 => reaper.Main_OnCommand(CMD_REPEAT, 0),
        1 => reaper.Main_OnCommand(CMD_LOOP_START, 0),
        2 => reaper.Main_OnCommand(CMD_LOOP_END, 0),
        3 => reaper.Main_OnCommand(CMD_SNAP, 0),
        4 => reaper.SetAutomationMode(AUTO_TRIM, false),
        5 => reaper.SetAutomationMode(AUTO_READ, false),
        6 => reaper.SetAutomationMode(AUTO_LATCH, false),
        7 => reaper.SetAutomationMode(AUTO_WRITE, false),
    }
}

test "transport labels" {
    try std.testing.expectEqualStrings("Jog", rotationLabel(0));
    try std.testing.expectEqualStrings("Mkr", rotationLabel(7));
    try std.testing.expectEqualStrings("Loop", pressLabel(0));
    try std.testing.expectEqualStrings("Write", pressLabel(7));
}
