//! Native port of the module-level actions of reavim
//! custom_actions/custom_actions.lua (the aggregator file's own 5 functions).
//! Action names and flags mirror definitions/extended_defaults/actions.lua.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const actions = @import("../actions.zig");
const helpers = @import("helpers.zig");

const log = std.log.scoped(.engine);

// ---- ABI shims (project argument typed non-optional in reaziglib) ---------------

fn setMidiEditorGrid(division: f64) void {
    const f: *const fn (project: ?*Reaper.ReaProject, division: f64) callconv(.C) void = @ptrCast(Reaper.SetMIDIEditorGrid);
    f(null, division);
}

fn setProjectGrid(division: f64) void {
    const f: *const fn (project: ?*Reaper.ReaProject, division: f64) callconv(.C) void = @ptrCast(Reaper.SetProjectGrid);
    f(null, division);
}

// ---- grid division input ---------------------------------------------------------

fn numberRunAt(s: []const u8, start: usize) ?[]const u8 {
    var end = start;
    while (end < s.len and (std.ascii.isDigit(s[end]) or s[end] == '.')) end += 1;
    if (end == start) return null;
    return s[start..end];
}

/// getUserGridDivisionInput's parse. Lua matched first_num = "[0-9.]+" and
/// divider = "/([0-9.]+)" — the first number run, divided by the number run
/// after the first '/' that is directly followed by one ("1/8" → 0.125,
/// "0.25" → 0.25). Null when nothing parses (the Lua error()'d or crashed on
/// arithmetic over a malformed match like "1.2.3").
fn parseGridDivision(s: []const u8) ?f64 {
    var first: ?[]const u8 = null;
    for (0..s.len) |i| {
        if (numberRunAt(s, i)) |run| {
            first = run;
            break;
        }
    }
    const num = std.fmt.parseFloat(f64, first orelse return null) catch return null;

    var i: usize = 0;
    while (std.mem.indexOfScalarPos(u8, s, i, '/')) |slash| {
        if (numberRunAt(s, slash + 1)) |den_str| {
            const den = std.fmt.parseFloat(f64, den_str) catch return null;
            return num / den;
        }
        i = slash + 1;
    }
    return num;
}

fn promptGridDivision() ?f64 {
    var buf: [128]u8 = undefined;
    const input = helpers.getUserInput("Set Grid Division", "Fraction/Number", &buf) orelse return null;
    return parseGridDivision(input) orelse {
        log.warn("could not parse specified grid division '{s}'", .{input});
        return null;
    };
}

fn setMidiGridDivision(_: *actions.RunCtx) void {
    const division = promptGridDivision() orelse return;
    setMidiEditorGrid(division);
    helpers.runNamedCommand("_SN_FOCUS_MIDI_EDITOR");
}

fn setGridDivision(_: *actions.RunCtx) void {
    const division = promptGridDivision() orelse return;
    setProjectGrid(division);
}

// ---- time selection ---------------------------------------------------------------

/// clearTimeSelection and clearSelectedTimeline have identical bodies in the
/// Lua — ported once, registered under both names.
fn clearTimeSelection(_: *actions.RunCtx) void {
    const pos = Reaper.GetCursorPosition();
    helpers.setTimeSelection(pos, pos);
}

// ---- split at time selection ---------------------------------------------------

/// The selected-items guard keeps REAPER from splitting every track when
/// nothing is selected.
fn splitItemsAtTimeSelection(_: *actions.RunCtx) void {
    if (helpers.countSelectedMediaItems() == 0) return;
    Reaper.Main_OnCommand(40061, 0); // Item: Split items at time selection
}

// ---- registry entries -------------------------------------------------------------

pub const entries = [_]actions.Entry{
    .{ .name = "ClearTimeSelection", .def = .{ .steps = &.{.{ .func = &clearTimeSelection }} } },
    .{ .name = "ClearSelectedTimeline", .def = .{ .steps = &.{.{ .func = &clearTimeSelection }} } },
    .{ .name = "SetMidiGridDivision", .def = .{ .steps = &.{.{ .func = &setMidiGridDivision }} } },
    .{ .name = "SetGridDivision", .def = .{ .steps = &.{.{ .func = &setGridDivision }} } },
    .{ .name = "SplitItemsAtTimeSelection", .def = .{ .steps = &.{.{ .func = &splitItemsAtTimeSelection }} } },
};

// ---- tests ------------------------------------------------------------------

test "parseGridDivision fractions and plain numbers" {
    try std.testing.expectEqual(@as(?f64, 0.125), parseGridDivision("1/8"));
    try std.testing.expectEqual(@as(?f64, 0.75), parseGridDivision("3/4"));
    try std.testing.expectEqual(@as(?f64, 0.25), parseGridDivision("0.25"));
    try std.testing.expectEqual(@as(?f64, 0.5), parseGridDivision(".5"));
    try std.testing.expectEqual(@as(?f64, 2), parseGridDivision("2"));
    // number run after the slash is required; a bare slash falls back
    try std.testing.expectEqual(@as(?f64, 4), parseGridDivision("4/"));
    // the first '/' directly followed by a number wins (the "/ " is skipped)
    try std.testing.expectEqual(@as(?f64, 0.25), parseGridDivision("1 / 2/4"));
}

test "parseGridDivision rejects garbage" {
    try std.testing.expectEqual(@as(?f64, null), parseGridDivision(""));
    try std.testing.expectEqual(@as(?f64, null), parseGridDivision("abc"));
    try std.testing.expectEqual(@as(?f64, null), parseGridDivision("1.2.3")); // Lua raised here
    try std.testing.expectEqual(@as(?f64, null), parseGridDivision("1/..")); // unparsable divider
}

test {
    _ = helpers;
}
