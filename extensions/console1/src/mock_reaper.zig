const std = @import("std");
const reaper = @import("reaper.zig").reaper;
const MediaTrack = reaper.MediaTrack;

const FxInfo = struct {
    original_name: [:0]const u8,
    renamed_name: [:0]const u8,
};

const ReaperFunctions = struct {
    TrackFX_GetNamedConfigParm: @TypeOf(reaper.TrackFX_GetNamedConfigParm),
    TrackFX_SetNamedConfigParm: @TypeOf(reaper.TrackFX_SetNamedConfigParm),
    TrackFX_Delete: @TypeOf(reaper.TrackFX_Delete),
    TrackFX_AddByName: @TypeOf(reaper.TrackFX_AddByName),
    TrackFX_CopyToTrack: @TypeOf(reaper.TrackFX_CopyToTrack),
};

var arena: std.heap.ArenaAllocator = undefined;
pub var fx_chain: std.ArrayList(FxInfo) = undefined;
pub var last_deleted_fx: ?i32 = null;
pub var fx_chain_changed = false;
var original_fns: ?ReaperFunctions = null;

pub fn init(allocator: std.mem.Allocator) void {
    arena = std.heap.ArenaAllocator.init(allocator);
    fx_chain = std.ArrayList(FxInfo).init(arena.allocator());

    // Store original functions and set up mocks
    original_fns = ReaperFunctions{
        .TrackFX_GetNamedConfigParm = reaper.TrackFX_GetNamedConfigParm,
        .TrackFX_SetNamedConfigParm = reaper.TrackFX_SetNamedConfigParm,
        .TrackFX_Delete = reaper.TrackFX_Delete,
        .TrackFX_AddByName = reaper.TrackFX_AddByName,
        .TrackFX_CopyToTrack = reaper.TrackFX_CopyToTrack,
    };

    @constCast(&reaper.TrackFX_GetNamedConfigParm).* = @constCast(&mockTrackFX_GetNamedConfigParm);
    @constCast(&reaper.TrackFX_SetNamedConfigParm).* = @constCast(&mockTrackFX_SetNamedConfigParm);
    @constCast(&reaper.TrackFX_Delete).* = @constCast(&mockTrackFX_Delete);
    @constCast(&reaper.TrackFX_AddByName).* = @constCast(&mockTrackFX_AddByName);
    @constCast(&reaper.TrackFX_CopyToTrack).* = @constCast(&mockTrackFX_CopyToTrack);
}

pub fn reset(allocator: std.mem.Allocator) !void {
    last_deleted_fx = null;
    fx_chain_changed = false;

    arena.deinit();
    arena = std.heap.ArenaAllocator.init(allocator);
    fx_chain = std.ArrayList(FxInfo).init(arena.allocator());
}

pub fn deinit() void {
    // Restore original functions
    if (original_fns) |fns| {
        @constCast(&reaper.TrackFX_GetNamedConfigParm).* = fns.TrackFX_GetNamedConfigParm;
        @constCast(&reaper.TrackFX_SetNamedConfigParm).* = fns.TrackFX_SetNamedConfigParm;
        @constCast(&reaper.TrackFX_Delete).* = fns.TrackFX_Delete;
        @constCast(&reaper.TrackFX_AddByName).* = fns.TrackFX_AddByName;
        @constCast(&reaper.TrackFX_CopyToTrack).* = fns.TrackFX_CopyToTrack;
        original_fns = null;
    }

    arena.deinit();
}

pub fn mockTrackFX_GetNamedConfigParm(
    track: MediaTrack,
    fx_index: c_int,
    parm_name: [*:0]const u8,
    parm_value: [*:0]u8,
    parm_value_sz: c_int,
) callconv(.C) bool {
    _ = track;
    const idx = @as(usize, @intCast(fx_index));
    if (idx >= fx_chain.items.len) return false;

    const fx_info = fx_chain.items[idx];
    const value = if (std.mem.eql(u8, std.mem.span(parm_name), "original_name"))
        fx_info.original_name
    else if (std.mem.eql(u8, std.mem.span(parm_name), "renamed_name"))
        fx_info.renamed_name
    else
        return false;

    if (value.len >= parm_value_sz) return false;
    @memcpy(@as([*]u8, @ptrCast(parm_value))[0..value.len], value);
    @as([*]u8, @ptrCast(parm_value))[value.len] = 0;
    return true;
}

pub fn mockTrackFX_SetNamedConfigParm(
    track: MediaTrack,
    fx_index: c_int,
    parm_name: [*:0]const u8,
    parm_value: [*:0]const u8,
) callconv(.C) bool {
    _ = track;
    const idx = @as(usize, @intCast(fx_index));
    if (idx >= fx_chain.items.len) return false;

    if (std.mem.eql(u8, std.mem.span(parm_name), "renamed_name")) {
        const new_renamed = arena.allocator().dupeZ(u8, std.mem.span(parm_value)) catch return false;
        fx_chain.items[idx].renamed_name = new_renamed;
        fx_chain_changed = true;
        return true;
    }
    return false;
}

pub fn mockTrackFX_Delete(
    track: MediaTrack,
    fx_index: c_int,
) callconv(.C) bool {
    _ = track;
    const idx = @as(usize, @intCast(fx_index));
    if (idx >= fx_chain.items.len) return false;

    last_deleted_fx = fx_index;
    _ = fx_chain.orderedRemove(idx);
    fx_chain_changed = true;
    return true;
}

pub fn mockTrackFX_CopyToTrack(
    track: MediaTrack,
    src_fx: c_int,
    dest_track: MediaTrack,
    dest_fx: c_int,
    delete: bool,
) callconv(.C) void {
    _ = track;
    _ = dest_track;
    const src_idx = @as(usize, @intCast(src_fx));
    if (src_idx >= fx_chain.items.len) return;

    const dest_pos = if (dest_fx < -999) -(dest_fx + 1000) else dest_fx;
    const fx_info = fx_chain.items[src_idx];

    // Insert at destination, which will shift other FX up
    fx_chain.insert(@intCast(dest_pos), fx_info) catch return;

    if (delete) {
        // If we inserted before the source, source index has moved up by 1
        _ = fx_chain.orderedRemove(if (dest_pos <= src_idx) src_idx + 1 else src_idx);
    }
    fx_chain_changed = true;
}

pub fn mockTrackFX_AddByName(
    track: MediaTrack,
    fx_name: [*:0]const u8,
    recfx: bool,
    pos: c_int,
) callconv(.C) c_int {
    _ = track;
    _ = recfx;

    const insert_pos = if (pos == -1) @as(i32, @intCast(fx_chain.items.len)) else if (pos < -999) -(pos + 1000) else pos;

    const name = std.mem.span(fx_name);
    const original_name = arena.allocator().dupeZ(u8, name) catch return -1;

    // Insert at position, shifting other FX up
    fx_chain.insert(@intCast(insert_pos), .{
        .original_name = original_name,
        .renamed_name = original_name,
    }) catch return -1;

    return insert_pos;
}

pub fn getChainState() ![]const FxInfo {
    var state = std.ArrayList(FxInfo).init(std.testing.allocator);
    defer state.deinit();
    try state.appendSlice(fx_chain.items);
    return state.toOwnedSlice();
}
