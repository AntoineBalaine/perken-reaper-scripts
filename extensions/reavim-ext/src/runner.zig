//! Executes built Commands: the port of reavim's runner.lua + the
//! action_sequence_functions composition wrappers.
//! Counts multiply in exactly one place: the runActionKey loop.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const keymod = @import("key.zig");
const grammar = @import("grammar.zig");
const actions = @import("actions.zig");
const builder = @import("builder.zig");
const state = @import("state.zig");

const log = std.log.scoped(.engine);

pub var registry: ?*const actions.Registry = null;

const MAX_RECURSION = 16;

// ---- track selection snapshot (native replacement for SWS save/restore) ----

const MAX_SAVED_TRACKS = 512;
var saved_guids: [MAX_SAVED_TRACKS][64]u8 = undefined;
var saved_count: usize = 0;

fn saveTrackSelection() void {
    saved_count = 0;
    const n = Reaper.CountSelectedTracks(0);
    var i: c_int = 0;
    while (i < n and saved_count < MAX_SAVED_TRACKS) : (i += 1) {
        var tr: Reaper.MediaTrack = Reaper.GetSelectedTrack(0, i);
        if (tr == null) continue;
        _ = Reaper.GetSetMediaTrackInfo_String(&tr, "GUID", @ptrCast(&saved_guids[saved_count]), false);
        saved_count += 1;
    }
}

fn restoreTrackSelection() void {
    unselectAllTracks();
    const total = Reaper.CountTracks(0);
    var i: c_int = 0;
    while (i < total) : (i += 1) {
        var tr: Reaper.MediaTrack = Reaper.GetTrack(0, i);
        if (tr == null) continue;
        var guid: [64]u8 = undefined;
        _ = Reaper.GetSetMediaTrackInfo_String(&tr, "GUID", @ptrCast(&guid), false);
        for (saved_guids[0..saved_count]) |*g| {
            if (std.mem.eql(u8, std.mem.sliceTo(g, 0), std.mem.sliceTo(&guid, 0))) {
                Reaper.SetTrackSelected(tr.?, true);
                break;
            }
        }
    }
}

fn unselectAllTracks() void {
    const n = Reaper.CountTracks(0);
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        if (Reaper.GetTrack(0, i)) |tr| Reaper.SetTrackSelected(tr, false);
    }
}

/// Index of the last-touched track (reavim reaper_utils.getTrackPosition).
fn getTrackPosition() c_int {
    const tr = Reaper.GetLastTouchedTrack() orelse return 0;
    const num = Reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER");
    if (num <= 0) return 0;
    return @as(c_int, @intFromFloat(num)) - 1;
}

fn unselectAllButLastTouchedTrack() void {
    unselectAllTracks();
    if (Reaper.GetLastTouchedTrack()) |tr| Reaper.SetTrackSelected(tr, true);
}

// ---- time selection helpers ----

const TimeSel = struct { start: f64, end_: f64 };

fn getTimeSelection() TimeSel {
    var s: f64 = 0;
    var e: f64 = 0;
    _ = Reaper.GetSet_LoopTimeRange(false, false, &s, &e, false);
    return .{ .start = s, .end_ = e };
}

fn setTimeSelection(s: f64, e: f64) void {
    var sv = s;
    var ev = e;
    _ = Reaper.GetSet_LoopTimeRange(true, false, &sv, &ev, false);
}

// ---- action execution (runner.runAction) ----

pub fn runActionKey(ak: builder.ActionKey, ctx: grammar.Context) void {
    runDef(ak.def, ak.prefixed_repetitions, ak.register, ctx, 0);
}

fn runByName(name: []const u8, ctx: grammar.Context, depth: usize) void {
    const reg = registry orelse return;
    const def = reg.get(name) orelse {
        log.warn("action '{s}' not in registry (stub)", .{name});
        return;
    };
    runDef(def, 1, null, ctx, depth);
}

fn runDef(def: *const actions.ActionDef, prefixed: u32, register: ?keymod.Key, ctx: grammar.Context, depth: usize) void {
    if (depth > MAX_RECURSION) {
        log.err("action recursion too deep — composite cycle?", .{});
        return;
    }

    var rctx = actions.RunCtx{
        .context = switch (ctx) {
            .main => .main,
            .midi => .midi,
        },
        .register = register orelse .{ .vk = 0 },
    };

    // Register actions: call the function step with the register; no loop.
    if (def.register_action) {
        for (def.steps) |step| {
            if (step == .func) {
                step.func(&rctx);
                return;
            }
        }
        log.warn("register action without native function step", .{});
        return;
    }

    if (def.pre_action) |p| runByName(p, ctx, depth + 1);

    const total: u64 = @as(u64, def.repetitions) * @as(u64, @max(prefixed, 1));
    var i: u64 = 0;
    while (i < total) : (i += 1) {
        for (def.steps) |step| runStep(step, def, &rctx, ctx, depth);
    }

    if (def.post_action) |p| runByName(p, ctx, depth + 1);
}

fn runStep(step: actions.Step, def: *const actions.ActionDef, rctx: *actions.RunCtx, ctx: grammar.Context, depth: usize) void {
    switch (step) {
        .cmd => |id| dispatchCmd(id, def.midi_command),
        .named => |name| {
            const id = Reaper.NamedCommandLookup(name.ptr);
            if (id == 0) {
                log.warn("named command not found: {s}", .{name});
                return;
            }
            dispatchCmd(id, def.midi_command);
        },
        .action => |name| runByName(name, ctx, depth + 1),
        .func => |f| f(rctx),
    }
}

fn dispatchCmd(id: c_int, midi: bool) void {
    if (midi) {
        _ = Reaper.MIDIEditor_LastFocused_OnCommand(id, false);
    } else {
        Reaper.Main_OnCommand(id, 0);
    }
}

// ---- composition wrappers (action_sequence_functions) ----

pub fn execute(cmd: builder.Command, ctx: grammar.Context) void {
    switch (cmd.comp) {
        .plain => runActionKey(cmd.keys[0], ctx),

        .timeline_op_selector => {
            const saved = getTimeSelection();
            runActionKey(cmd.keys[1], ctx); // selector
            runActionKey(cmd.keys[0], ctx); // operator
            if (!cmd.keys[0].def.set_time_selection)
                setTimeSelection(saved.start, saved.end_);
        },

        .timeline_op_motion => {
            const saved = getTimeSelection();
            makeSelectionFromTimelineMotion(cmd.keys[1], ctx);
            runActionKey(cmd.keys[0], ctx);
            if (!cmd.keys[0].def.set_time_selection)
                setTimeSelection(saved.start, saved.end_);
        },

        .track_op_selector => {
            saveTrackSelection();
            runActionKey(cmd.keys[1], ctx);
            runActionKey(cmd.keys[0], ctx);
            if (!cmd.keys[0].def.set_track_selection)
                restoreTrackSelection();
        },

        .track_op_motion => {
            saveTrackSelection();
            if (!makeSelectionFromTrackMotion(cmd.keys[1], ctx)) return;
            runActionKey(cmd.keys[0], ctx);
            if (!cmd.keys[0].def.set_track_selection)
                restoreTrackSelection();
        },

        .visual_track_motion_extend => {
            if (!makeSelectionFromTrackMotion(cmd.keys[0], ctx)) return;
            const end_pos = getTrackPosition();
            const pivot = state.visual_track_pivot;
            unselectAllTracks();
            var i = end_pos;
            const step: c_int = if (pivot > end_pos) 1 else -1;
            while (i != pivot) : (i += step) {
                if (Reaper.GetTrack(0, i)) |tr| Reaper.SetTrackSelected(tr, true);
            }
            if (Reaper.GetTrack(0, pivot)) |tr| Reaper.SetTrackSelected(tr, true);
        },

        .visual_timeline_operator => {
            runActionKey(cmd.keys[0], ctx);
            state.setModeToNormal();
            if (!grammar.cfg.persist_visual_timeline_selection)
                setTimeSelection(0, 0);
        },

        .visual_timeline_motion_extend => extendTimelineSelection(cmd.keys[0], ctx),

        .visual_track_operator => {
            runActionKey(cmd.keys[0], ctx);
            state.setModeToNormal();
            if (!grammar.cfg.persist_visual_track_selection and
                !cmd.keys[0].def.set_track_selection)
            {
                unselectAllButLastTouchedTrack();
            }
        },

        .visual_track_timeline_motion => {
            if (grammar.cfg.allow_visual_track_timeline_movement)
                runActionKey(cmd.keys[0], ctx);
        },
    }
}

/// Span the time selection over a timeline motion; cursor is put back.
fn makeSelectionFromTimelineMotion(motion: builder.ActionKey, ctx: grammar.Context) void {
    const sel_start = Reaper.GetCursorPosition();
    runActionKey(motion, ctx);
    const sel_end = Reaper.GetCursorPosition();
    Reaper.SetEditCurPos(sel_start, false, false);
    setTimeSelection(sel_start, sel_end);
}

/// Select the track range spanned by a track motion. Returns false if no
/// selected track exists after the motion (reavim bails out).
fn makeSelectionFromTrackMotion(motion: builder.ActionKey, ctx: grammar.Context) bool {
    const first_index = getTrackPosition();
    runActionKey(motion, ctx);
    const end_track = Reaper.GetSelectedTrack(0, 0) orelse return false;
    const second_index = @as(c_int, @intFromFloat(Reaper.GetMediaTrackInfo_Value(end_track, "IP_TRACKNUMBER"))) - 1;

    var lo = first_index;
    var hi = second_index;
    if (lo > hi) std.mem.swap(c_int, &lo, &hi);
    var i = lo;
    while (i <= hi) : (i += 1) {
        if (Reaper.GetTrack(0, i)) |tr| Reaper.SetTrackSelected(tr, true);
    }
    return true;
}

/// Extend the visual timeline selection with a motion, flipping sides at the
/// edges (faithful to runner.extendTimelineSelection, minus its dead fallback).
fn extendTimelineSelection(motion: builder.ActionKey, ctx: grammar.Context) void {
    const sel = getTimeSelection();
    runActionKey(motion, ctx);
    const end_pos_i = Reaper.GetCursorPosition();
    const end_pos: f64 = end_pos_i;

    switch (state.timeline_side) {
        .right => {
            if (end_pos <= sel.start) {
                state.timeline_side = .left;
                setTimeSelection(end_pos, sel.start);
            } else {
                setTimeSelection(sel.start, end_pos);
            }
        },
        .left => {
            if (end_pos >= sel.end_) {
                state.timeline_side = .right;
                setTimeSelection(sel.end_, end_pos);
            } else {
                setTimeSelection(end_pos, sel.end_);
            }
        },
    }
}
