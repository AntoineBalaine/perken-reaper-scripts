//! Native port of reavim custom_actions/envelope.lua (the 9 bound actions).
//! Action names and flags mirror definitions/extended_defaults/actions.lua.
//!
//! envelope.autoMode ("show only the last-touched FX param's envelope") is
//! NOT ported and NOT registered: no action in the reavim definitions binds
//! it (only a commented-out call in dev.lua references it), and it depends on
//! SWS BR_EnvAlloc/BR_EnvGetProperties/BR_EnvFree, which have no reaziglib
//! bindings.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const actions = @import("../actions.zig");
const helpers = @import("helpers.zig");

// ---- ABI shim: SetEnvelopePoint's In parameters take NULL for "keep" ----------

fn setEnvelopePoint(env: *Reaper.TrackEnvelope, ptidx: c_int, time: ?*f64, value: ?*f64, shape: ?*c_int, tension: ?*f64, selected: ?*bool, no_sort: ?*bool) bool {
    const f: *const fn (envelope: *Reaper.TrackEnvelope, ptidx: c_int, timeInOptional: ?*f64, valueInOptional: ?*f64, shapeInOptional: ?*c_int, tensionInOptional: ?*f64, selectedInOptional: ?*bool, noSortInOptional: ?*bool) callconv(.C) bool = @ptrCast(Reaper.SetEnvelopePoint);
    return f(env, ptidx, time, value, shape, tension, selected, no_sort);
}

// ---- point access ---------------------------------------------------------------

const Point = struct {
    time: f64,
    value: f64,
    shape: c_int,
    tension: f64,
    selected: bool,
};

fn getPoint(env: *Reaper.TrackEnvelope, i: c_int) ?Point {
    var p: Point = undefined;
    if (!Reaper.GetEnvelopePoint(env, i, &p.time, &p.value, &p.shape, &p.tension, &p.selected))
        return null;
    return p;
}

// ---- time selection from selected points ------------------------------------------

fn setTimeSelectionToSelectedEnvelopePoints(_: *actions.RunCtx) void {
    const ts = helpers.getTimeSelection();
    if (ts.start != 0 and ts.end_ != 0) return;

    const env = helpers.getSelectedEnvelope() orelse return;
    const count = Reaper.CountEnvelopePoints(env);
    var first: ?f64 = null;
    var last: f64 = 0;
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        const p = getPoint(env, i) orelse continue;
        if (p.selected) {
            if (first == null) first = p.time;
            last = p.time;
        }
    }
    // FIXED vs lua: with no selected points the Lua passed nil times to
    // GetSet_LoopTimeRange and errored at runtime; bail instead.
    if (first) |f| helpers.setTimeSelection(f, last);
}

// ---- select points inside the time selection ---------------------------------------

fn selectPointsCrossingTimeSelection(_: *actions.RunCtx) void {
    const ts = helpers.getTimeSelection();
    if (ts.start == 0 and ts.end_ == 0) return;

    const env = helpers.getSelectedEnvelope() orelse return;
    const count = Reaper.CountEnvelopePoints(env);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        const p = getPoint(env, i) orelse continue;
        if (p.time >= ts.start and p.time <= ts.end_) {
            var time = p.time;
            var selected = true;
            var no_sort = true;
            _ = setEnvelopePoint(env, i, &time, null, null, null, &selected, &no_sort);
        }
    }
}

// ---- peg selected points to min/max/center or nudge by ±3 ---------------------------

const Peg = enum { min, max, center, down, up };

fn pegValue(peg: Peg, value: f64, range: helpers.EnvelopeRange) f64 {
    return switch (peg) {
        .min => range.min,
        .max => range.max,
        .center => range.center,
        .down => value - 3, // ±3 in raw envelope units, like the Lua
        .up => value + 3,
    };
}

fn pegPoint(peg: Peg) void {
    const env = helpers.getSelectedEnvelope() orelse return;
    // The Lua error()'d on unknown envelope types (even for up/down); we
    // just bail (envelopeRange already logged a warning).
    const range = helpers.envelopeRange(env) orelse return;

    const count = Reaper.CountEnvelopePoints(env);
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        var p = getPoint(env, i) orelse continue;
        if (!p.selected) continue;
        p.value = pegValue(peg, p.value, range);
        var selected = true;
        var no_sort = true;
        _ = setEnvelopePoint(env, i, &p.time, &p.value, &p.shape, &p.tension, &selected, &no_sort);
    }
}

fn moveEnvelopePointDown(_: *actions.RunCtx) void {
    pegPoint(.down);
}

fn moveEnvelopePointUp(_: *actions.RunCtx) void {
    pegPoint(.up);
}

fn setPointMin(_: *actions.RunCtx) void {
    pegPoint(.min);
}

fn setPointMax(_: *actions.RunCtx) void {
    pegPoint(.max);
}

fn setPointCenter(_: *actions.RunCtx) void {
    pegPoint(.center);
}

// ---- square on/off toggle across the time selection ---------------------------------

fn insertToggleAtTimeSelection(_: *actions.RunCtx) void {
    const ts = helpers.getTimeSelection();
    if (ts.start == ts.end_) return;

    const env = helpers.getSelectedEnvelope() orelse return;
    const range = helpers.envelopeRange(env);
    const min: f64 = if (range) |r| r.min else 0; // Lua: minValue or 0
    const max: f64 = if (range) |r| r.max else 100; // Lua: maxValue or 100
    var no_sort = true;
    _ = Reaper.InsertEnvelopePoint(env, ts.start, min, 1, 0, true, &no_sort); // shape 1 = square
    _ = Reaper.InsertEnvelopePoint(env, ts.end_, max, 1, 0, true, &no_sort);
}

// ---- delete points -------------------------------------------------------------------

fn deletePoints(_: *actions.RunCtx) void {
    const env = helpers.getSelectedEnvelope() orelse return;
    const ts = helpers.getTimeSelection();
    const has_time_selection = ts.start != ts.end_;
    const count = Reaper.CountEnvelopePoints(env);

    Reaper.Main_OnCommand(40335, 0); // Envelope: Copy points

    if (count > 0 and has_time_selection) {
        // FIXED vs lua: the per-point loop called the local helper
        // DeleteAtTimeSelection() with zero arguments and errored at runtime;
        // the intent — delete the selected envelope's points inside the time
        // selection — is a single range delete.
        _ = Reaper.DeleteEnvelopePointRange(env, ts.start, ts.end_);
    } else {
        var has_selected_points = false;
        var i: c_int = 0;
        while (i < count) : (i += 1) {
            const p = getPoint(env, i) orelse continue;
            if (p.selected) {
                has_selected_points = true;
                break;
            }
        }
        if (has_selected_points) {
            Reaper.Main_OnCommand(40333, 0); // Envelope: Delete all selected points
        } else {
            Reaper.Main_OnCommand(40325, 0); // Envelope: Cut points within time selection / all
        }
    }
}

// ---- registry entries -------------------------------------------------------------

pub const entries = [_]actions.Entry{
    .{ .name = "DeleteEnvelopePoints", .def = .{ .steps = &.{.{ .func = &deletePoints }} } },
    .{ .name = "SelectEnvelopePoints", .def = .{ .steps = &.{.{ .func = &selectPointsCrossingTimeSelection }} } },
    .{ .name = "SelectedPoints", .def = .{ .steps = &.{ .{ .action = "RemoveTimeSelection" }, .{ .func = &setTimeSelectionToSelectedEnvelopePoints } } } },
    .{ .name = "SetPointMin", .def = .{ .steps = &.{.{ .func = &setPointMin }} } },
    .{ .name = "SetPointMax", .def = .{ .steps = &.{.{ .func = &setPointMax }} } },
    .{ .name = "SetPointCenter", .def = .{ .steps = &.{.{ .func = &setPointCenter }} } },
    .{ .name = "MoveEnvelopePointDown", .def = .{ .steps = &.{.{ .func = &moveEnvelopePointDown }}, .prefix_repetition_count = true } },
    .{ .name = "MoveEnvelopePointUp", .def = .{ .steps = &.{.{ .func = &moveEnvelopePointUp }}, .prefix_repetition_count = true } },
    .{ .name = "InsertToggleAtTimeSelection", .def = .{ .steps = &.{.{ .func = &insertToggleAtTimeSelection }} } },
};

// ---- tests ------------------------------------------------------------------

test "pegValue resolves range pegs and raw-unit nudges" {
    const range = helpers.EnvelopeRange{ .min = -1, .max = 1, .center = 0 };
    try std.testing.expectEqual(@as(f64, -1), pegValue(.min, 0.4, range));
    try std.testing.expectEqual(@as(f64, 1), pegValue(.max, 0.4, range));
    try std.testing.expectEqual(@as(f64, 0), pegValue(.center, 0.4, range));
    try std.testing.expectEqual(@as(f64, -2.6), pegValue(.down, 0.4, range));
    try std.testing.expectEqual(@as(f64, 3.4), pegValue(.up, 0.4, range));
}

test {
    _ = helpers;
}
