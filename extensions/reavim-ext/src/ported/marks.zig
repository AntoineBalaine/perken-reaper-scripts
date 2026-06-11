//! Native port of reavim library/marks.lua — the five register actions
//! Mark, DeleteMark, MarkedTracks, MarkedRegion, MarkedTimelinePosition.
//!
//! Storage: reavim kept marks as serpent-serialized Lua tables in project
//! ext state (section per project_state namespace). We keep project ext
//! state (marks are project data: positions and track GUIDs) but use a flat
//! format we control:
//!
//!   section "reavim_marks", key = register character ("a".."z" / "0".."9"),
//!   value = one pipe-separated record:
//!
//!     <type>|<marker_index>|<left>|<right>|<position>|<last_guid>|<guid,...>
//!
//!   type         r = region mark, p = timeline-position mark,
//!                t = track-selection mark (which fields matter on recall
//!                mirrors the Lua: recall functions read any mark type)
//!   marker_index project marker/region id of the visual indication added by
//!                Mark (-1 = none); deleted on overwrite/DeleteMark
//!   left/right   time selection when the mark was set (seconds)
//!   position     edit cursor when the mark was set (seconds)
//!   last_guid    GUID of the last-touched track ("" = none) — replaces the
//!                Lua's track_position index, robust against reordering
//!   guid,...     selected-track GUIDs, comma-separated ("" = none) —
//!                replaces the Lua's track_selection index list
const std = @import("std");
const Reaper = @import("reaper").reaper;
const actions = @import("../actions.zig");
const helpers = @import("helpers.zig");
const state = @import("../state.zig");

const log = std.log.scoped(.engine);

const ext_section = "reavim_marks";
const payload_max = 8192;

// ---- ABI shims (project-pointer params take NULL for "current project") -------

fn addProjectMarker(isrgn: bool, pos: f64, rgnend: f64, name: [*:0]const u8) c_int {
    const f: *const fn (proj: ?*Reaper.ReaProject, isrgn: bool, pos: f64, rgnend: f64, name: [*:0]const u8, wantidx: c_int) callconv(.C) c_int = @ptrCast(Reaper.AddProjectMarker);
    return f(null, isrgn, pos, rgnend, name, -1);
}

fn deleteProjectMarker(idx: c_int, isrgn: bool) void {
    const f: *const fn (proj: ?*Reaper.ReaProject, markrgnindexnumber: c_int, isrgn: bool) callconv(.C) bool = @ptrCast(Reaper.DeleteProjectMarker);
    _ = f(null, idx, isrgn);
}

/// value == null deletes the key.
fn setMarkPayload(register: u8, value: ?[*:0]const u8) void {
    const f: *const fn (proj: ?*Reaper.ReaProject, extname: [*:0]const u8, key: [*:0]const u8, value: ?[*:0]const u8) callconv(.C) c_int = @ptrCast(Reaper.SetProjExtState);
    var key = [_:0]u8{register};
    _ = f(null, ext_section, &key, value);
}

fn getMarkPayload(register: u8, buf: []u8) ?[]const u8 {
    const f: *const fn (proj: ?*Reaper.ReaProject, extname: [*:0]const u8, key: [*:0]const u8, valOut: [*]u8, valOut_sz: c_int) callconv(.C) c_int = @ptrCast(Reaper.GetProjExtState);
    var key = [_:0]u8{register};
    buf[0] = 0;
    if (f(null, ext_section, &key, buf.ptr, @intCast(buf.len)) == 0) return null;
    return std.mem.sliceTo(buf, 0);
}

// ---- mark payload ---------------------------------------------------------------

const MarkType = enum(u8) { region = 'r', position = 'p', tracks = 't' };

const Mark = struct {
    typ: MarkType,
    /// Project marker/region id of the indication, -1 = none.
    index: c_int,
    left: f64,
    right: f64,
    position: f64,
    /// Slices into the caller's load buffer.
    last_guid: []const u8,
    guids: []const u8,
};

fn parseMark(payload: []const u8) ?Mark {
    if (payload.len == 0) return null;
    var it = std.mem.splitScalar(u8, payload, '|');
    const typ_s = it.next() orelse return null;
    const index_s = it.next() orelse return null;
    const left_s = it.next() orelse return null;
    const right_s = it.next() orelse return null;
    const position_s = it.next() orelse return null;
    const last_guid = it.next() orelse return null;
    const guids = it.next() orelse return null;
    if (typ_s.len != 1) return null;
    return .{
        .typ = switch (typ_s[0]) {
            'r' => .region,
            'p' => .position,
            't' => .tracks,
            else => return null,
        },
        .index = std.fmt.parseInt(c_int, index_s, 10) catch return null,
        .left = std.fmt.parseFloat(f64, left_s) catch return null,
        .right = std.fmt.parseFloat(f64, right_s) catch return null,
        .position = std.fmt.parseFloat(f64, position_s) catch return null,
        .last_guid = last_guid,
        .guids = guids,
    };
}

fn writePayload(writer: anytype, m: Mark) !void {
    try writer.print("{c}|{d}|{d}|{d}|{d}|{s}|{s}", .{
        @intFromEnum(m.typ), m.index, m.left, m.right, m.position, m.last_guid, m.guids,
    });
}

fn loadMark(register: u8, buf: []u8) ?Mark {
    const payload = getMarkPayload(register, buf) orelse return null;
    return parseMark(payload);
}

/// Register key -> mark key character. Letters arrive as uppercase VK codes;
/// registers are a-z and 0-9 (modifiers ignored, like reavim).
fn registerChar(ctx: *actions.RunCtx) ?u8 {
    const vk = ctx.register.vk;
    if (vk >= 'A' and vk <= 'Z') return vk + ('a' - 'A');
    if (vk >= '0' and vk <= '9') return vk;
    log.warn("marks: unsupported register key (vk=0x{x:0>2}) — use a-z or 0-9", .{vk});
    return null;
}

// ---- track lookup ----------------------------------------------------------------

fn findTrackIndexByGuid(guid: []const u8) ?c_int {
    if (guid.len == 0) return null;
    const n = Reaper.CountTracks(0);
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        const track = Reaper.GetTrack(0, i) orelse continue;
        var buf: [64]u8 = undefined;
        const g = helpers.getTrackString(track, "GUID", &buf) orelse continue;
        if (std.mem.eql(u8, g, guid)) return i;
    }
    return null;
}

fn unselectAllTracks() void {
    const n = Reaper.CountTracks(0);
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        if (Reaper.GetTrack(0, i)) |track| Reaper.SetTrackSelected(track, false);
    }
}

// ---- actions ----------------------------------------------------------------------

/// marks.save: snapshot time selection, cursor, last-touched track and track
/// selection; add a marker/region indication depending on the current mode;
/// overwrite the register and drop back to normal mode.
fn mark(ctx: *actions.RunCtx) void {
    const register = registerChar(ctx) orelse return;

    var left: f64 = 0;
    var right: f64 = 0;
    Reaper.GetSet_LoopTimeRange(false, false, &left, &right, false);
    const position = Reaper.GetCursorPosition();

    var last_buf: [64]u8 = undefined;
    const last_guid: []const u8 = if (Reaper.GetLastTouchedTrack()) |track|
        helpers.getTrackString(track, "GUID", &last_buf) orelse ""
    else
        "";

    var guids = std.ArrayList(u8).init(helpers.allocator);
    defer guids.deinit();
    const n_sel = Reaper.CountSelectedTracks(0);
    var i: c_int = 0;
    while (i < n_sel) : (i += 1) {
        const track = Reaper.GetSelectedTrack(0, i) orelse continue;
        var guid_buf: [64]u8 = undefined;
        const g = helpers.getTrackString(track, "GUID", &guid_buf) orelse continue;
        if (guids.items.len > 0) guids.append(',') catch return;
        guids.appendSlice(g) catch return;
    }

    var marker_name = [_:0]u8{register};
    var new_mark = Mark{
        .typ = .position,
        .index = -1,
        .left = left,
        .right = right,
        .position = position,
        .last_guid = last_guid,
        .guids = guids.items,
    };
    switch (state.mode) {
        .visual_timeline => {
            new_mark.typ = .region;
            new_mark.index = addProjectMarker(true, left, right, &marker_name);
        },
        .visual_track => new_mark.typ = .tracks,
        else => {
            new_mark.typ = .position;
            new_mark.index = addProjectMarker(false, position, position, &marker_name);
        },
    }

    // Drop the previous mark's marker/region indication before overwriting.
    var old_buf: [payload_max]u8 = undefined;
    if (loadMark(register, &old_buf)) |old| deleteMarkIndication(old);

    var payload = std.ArrayList(u8).init(helpers.allocator);
    defer payload.deinit();
    writePayload(payload.writer(), new_mark) catch return;
    const z = payload.toOwnedSliceSentinel(0) catch return;
    defer helpers.allocator.free(z);
    setMarkPayload(register, z.ptr);

    state.setModeToNormal();
}

fn deleteMarkIndication(m: Mark) void {
    if (m.index < 0) return;
    switch (m.typ) {
        .region => deleteProjectMarker(m.index, true),
        .position => deleteProjectMarker(m.index, false),
        .tracks => {},
    }
}

/// marks.delete: remove the indication and clear the register.
fn deleteMark(ctx: *actions.RunCtx) void {
    const register = registerChar(ctx) orelse return;
    var buf: [payload_max]u8 = undefined;
    if (loadMark(register, &buf)) |m| deleteMarkIndication(m);
    setMarkPayload(register, null);
}

/// marks.recallMarkedTimelinePosition: cursor to the stored position (region
/// marks jump to their left edge).
fn markedTimelinePosition(ctx: *actions.RunCtx) void {
    const register = registerChar(ctx) orelse return;
    var buf: [payload_max]u8 = undefined;
    const m = loadMark(register, &buf) orelse return;
    const target = if (m.typ == .region) m.left else m.position;
    Reaper.SetEditCurPos(target, true, false);
}

/// marks.recallMarkedRegion: time selection to the stored range, scroll the
/// view there without moving the cursor (utils.scrollToPosition).
fn markedRegion(ctx: *actions.RunCtx) void {
    const register = registerChar(ctx) orelse return;
    var buf: [payload_max]u8 = undefined;
    const m = loadMark(register, &buf) orelse return;
    helpers.setTimeSelection(m.left, m.right);
    const cursor = Reaper.GetCursorPosition();
    Reaper.SetEditCurPos(m.left, true, false);
    Reaper.SetEditCurPos(cursor, false, false);
}

/// marks.recallMarkedTracks: restore last-touched track and track selection.
/// Net effect of the Lua's setCurrentTrack + setTrackSelection dance: the
/// marked current track becomes last-touched, the stored set becomes the
/// selection, and the view scrolls to it.
fn markedTracks(ctx: *actions.RunCtx) void {
    const register = registerChar(ctx) orelse return;
    var buf: [payload_max]u8 = undefined;
    const m = loadMark(register, &buf) orelse return;

    if (findTrackIndexByGuid(m.last_guid)) |idx| {
        if (Reaper.GetTrack(0, idx)) |track| {
            Reaper.SetOnlyTrackSelected(track);
            Reaper.Main_OnCommand(40914, 0); // set first selected track as last touched
        }
    }

    unselectAllTracks();
    var it = std.mem.splitScalar(u8, m.guids, ',');
    while (it.next()) |guid| {
        if (findTrackIndexByGuid(guid)) |idx| {
            if (Reaper.GetTrack(0, idx)) |track| Reaper.SetTrackSelected(track, true);
        }
    }
    Reaper.Main_OnCommand(40913, 0); // scroll to selected tracks
}

// ---- registry entries -------------------------------------------------------------
// All five carry registerAction = true in definitions/*/actions.lua; the
// selector/operator composition flags live on operators, not on these.

pub const entries = [_]actions.Entry{
    .{ .name = "Mark", .def = .{ .steps = &.{.{ .func = &mark }}, .register_action = true } },
    .{ .name = "DeleteMark", .def = .{ .steps = &.{.{ .func = &deleteMark }}, .register_action = true } },
    .{ .name = "MarkedTracks", .def = .{ .steps = &.{.{ .func = &markedTracks }}, .register_action = true } },
    .{ .name = "MarkedRegion", .def = .{ .steps = &.{.{ .func = &markedRegion }}, .register_action = true } },
    .{ .name = "MarkedTimelinePosition", .def = .{ .steps = &.{.{ .func = &markedTimelinePosition }}, .register_action = true } },
};

// ---- tests ------------------------------------------------------------------

test "mark payload round-trips" {
    const original = Mark{
        .typ = .region,
        .index = 42,
        .left = 1.25,
        .right = 17.333333333333332,
        .position = 3.5,
        .last_guid = "{01234567-89AB-CDEF-0123-456789ABCDEF}",
        .guids = "{A},{B},{C}",
    };
    var list = std.ArrayList(u8).init(std.testing.allocator);
    defer list.deinit();
    try writePayload(list.writer(), original);

    const parsed = parseMark(list.items).?;
    try std.testing.expectEqual(original.typ, parsed.typ);
    try std.testing.expectEqual(original.index, parsed.index);
    try std.testing.expectEqual(original.left, parsed.left);
    try std.testing.expectEqual(original.right, parsed.right);
    try std.testing.expectEqual(original.position, parsed.position);
    try std.testing.expectEqualStrings(original.last_guid, parsed.last_guid);
    try std.testing.expectEqualStrings(original.guids, parsed.guids);
}

test "parseMark rejects garbage" {
    try std.testing.expect(parseMark("") == null);
    try std.testing.expect(parseMark("x|1|0|0|0||") == null);
    try std.testing.expect(parseMark("r|nope|0|0|0||") == null);
    try std.testing.expect(parseMark("r|1|0|0") == null);
    // empty guid fields are fine
    const m = parseMark("p|-1|0|0|12.5||").?;
    try std.testing.expectEqual(MarkType.position, m.typ);
    try std.testing.expectEqual(@as(f64, 12.5), m.position);
    try std.testing.expectEqual(@as(usize, 0), m.last_guid.len);
    try std.testing.expectEqual(@as(usize, 0), m.guids.len);
}

test {
    _ = helpers;
}
