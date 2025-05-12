/// Global model state
pub var g_session: ?*Session = null;

pub fn setupTestModel(allocator: std.mem.Allocator, trck_count: ?usize, prealloc_tracks: ?usize) struct {
    orig_funcs: Mocks,
    model_ptr: *Session,

    fn teardown(self: @This()) void {
        restoreMockReaperAPI(self.orig_funcs);
        self.model_ptr.deinit();
        self.model_ptr.gpa.destroy(self.model_ptr);
    }
} {
    const model = allocator.create(Session) catch @panic("Failed to initialize model");
    model.* = Session.init(
        allocator,
        if (trck_count) |count| count else 0,
        if (prealloc_tracks) |prealloc| prealloc else 4,
    ) catch @panic("Failed to initialize model");
    const origFuncs = setupMockReaperAPI(model);

    return .{
        .orig_funcs = origFuncs,
        .model_ptr = model,
    };
}

// Helper to set the current model for testing
pub fn setCurrentModel(model: *Session) void {
    g_session = model;
}
const Mocks = struct {
    InsertTrackAtIndex: @TypeOf(reaper.InsertTrackAtIndex),
    DeleteTrack: @TypeOf(reaper.DeleteTrack),
    TrackFX_AddByName: @TypeOf(reaper.TrackFX_AddByName),
    TrackFX_GetCount: @TypeOf(reaper.TrackFX_GetCount),
    TrackFX_GetFXName: @TypeOf(reaper.TrackFX_GetFXName),
    GetNumTracks: @TypeOf(reaper.GetNumTracks),
    CountTracks: @TypeOf(reaper.CountTracks),
    GetTrack: @TypeOf(reaper.GetTrack),
    GetMasterTrack: @TypeOf(reaper.GetMasterTrack),
    GetTrackName: @TypeOf(reaper.GetTrackName),
    SetMediaTrackInfo_Value: @TypeOf(reaper.SetMediaTrackInfo_Value),
    GetMediaTrackInfo_Value: @TypeOf(reaper.GetMediaTrackInfo_Value),
    SetTrackSelected: @TypeOf(reaper.SetTrackSelected),
    GetSelectedTrack: @TypeOf(reaper.GetSelectedTrack),
};

// Helper functions to set up and tear down the mock API
fn setupMockReaperAPI(model: *Session) Mocks {
    setCurrentModel(model);

    // Create a Mocks struct to store original functions
    var origFuncs: Mocks = undefined;

    inline for (std.meta.fields(Mocks)) |field| {
        const name = field.name;
        // Store the original function
        @field(origFuncs, name) = @field(reaper, name);

        if (@hasDecl(@This(), name)) {
            @constCast(&@field(reaper, name)).* = @constCast(&@field(@This(), name));
        } else {
            @compileError("No mock implementation found for " ++ name);
        }
    }

    return origFuncs;
}

fn restoreMockReaperAPI(origFuncs: anytype) void {
    inline for (std.meta.fields(Mocks)) |field| {
        const name = field.name;
        @constCast(&@field(reaper, name)).* = @constCast(&@field(origFuncs, name)).*;
    }

    g_session = null;
}

// Mock REAPER API functions with the same signatures as the real API
fn InsertTrackAtIndex(idx: c_int, wantDefaults: bool) callconv(.C) void {
    _ = wantDefaults;
    const model = g_session.?;
    const gpa = model.gpa;

    // Determine the actual index in our tracks array (accounting for master track at index 0)
    const actual_idx = if (idx < 0) model.tracks.items.len else @as(usize, @intCast(idx)) + 1;

    const track: Track = .default;

    if (actual_idx >= model.tracks.items.len) {
        // Append to the end
        model.tracks.append(gpa, track) catch return;
    } else {
        // Insert at the specified position
        model.tracks.insert(gpa, actual_idx, track) catch return;
    }
}

// Mock FX manipulation functions
// NOTE: there is the case in which we try to add an fx which
// doesn't exist on the user's system, in which case reaper returns -1
// TODO: implement model fx library
fn TrackFX_AddByName(track: reaper.MediaTrack, fxname: [*:0]const u8, recFX: bool, instantiate: c_int) callconv(.C) c_int {
    _ = recFX;
    _ = instantiate;
    const session = g_session.?;

    // Cast to optional pointer and check for null
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return -1;

    const gpa = session.gpa;
    const fx_name = std.mem.span(fxname);

    var guid: Guid = .{ .bytes = undefined };
    std.crypto.random.bytes(&guid.bytes);

    // Create a new FX
    const name = gpa.dupeZ(u8, fx_name) catch return -1;
    const new_fx = FX{
        .guid = guid,
        .enabled = true,
        .params = &[_]Param{},
        .named_configs = .{
            .renamed_name = name,
            .original_name = name,
        },
    };
    var tr: *Track = track_ptr.?;

    // Add the FX to the track
    tr.fx_list.append(gpa, new_fx) catch return -1;

    // Return the index of the newly added FX
    return @intCast(tr.fx_list.items.len - 1);
}

fn TrackFX_GetCount(track: reaper.MediaTrack) callconv(.C) c_int {
    // Cast to optional pointer and check for null
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return -1;

    // Access the track's fx_list directly
    const tr: *const Track = track_ptr.?;
    return @intCast(tr.fx_list.items.len);
}

fn TrackFX_GetFXName(track: reaper.MediaTrack, fx: c_int, bufOut: [*:0]u8, bufOut_sz: c_int) callconv(.C) bool {
    // Cast to optional pointer and check for null
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return false;

    // Access the track's fx_list directly
    const tr: *const Track = track_ptr.?;

    // Check if FX index is valid
    if (fx < 0 or fx >= tr.fx_list.items.len) return false;

    // Copy the FX name to the buffer
    const name = tr.fx_list.items[@intCast(fx)].named_configs.renamed_name;
    const len = @min(@as(usize, @intCast(bufOut_sz)) - 1, name.len);
    @memcpy(bufOut[0..len], name[0..len]);
    bufOut[len] = 0; // Null terminate
    return true;
}

fn DeleteTrack(tr: reaper.MediaTrack) callconv(.C) void {
    const model = g_session.?;

    // Cast to optional pointer and check for null
    const track_ptr: ?*Track = @ptrCast(@alignCast(tr));
    if (track_ptr == null) return;

    // We still need to find the track index for deletion and updating selected tracks
    var track_idx: ?usize = null;
    for (model.tracks.items, 0..) |*t, i| {
        if (t == track_ptr.?) {
            track_idx = i;
            break;
        }
    }

    if (track_idx == null) return;

    // Don't allow deleting the master track
    if (track_idx.? == 0) return;

    // Remove the track
    var removed_track = model.tracks.orderedRemove(track_idx.?);

    // Clean up the track's resources
    removed_track.deinit(model.gpa);

    // Update selected track indices
    var i: usize = 0;
    while (i < model.selected_tracks.items.len) {
        if (model.selected_tracks.items[i] == track_idx.?) {
            _ = model.selected_tracks.orderedRemove(i);
        } else if (model.selected_tracks.items[i] > track_idx.?) {
            model.selected_tracks.items[i] -= 1;
            i += 1;
        } else {
            i += 1;
        }
    }

    // Update last touched track index if needed
    if (model.last_touched_track_index) |*last_touched| {
        if (last_touched.* == track_idx.?) {
            model.last_touched_track_index = null;
        } else if (last_touched.* > track_idx.?) {
            last_touched.* -= 1;
        }
    }
}

// Mock REAPER API functions
fn GetNumTracks() callconv(.C) c_int {
    return @intCast(g_session.?.tracks.items.len - 1); // Don't count master track
}

fn CountTracks(project: ReaProject) callconv(.C) c_int {
    _ = project;
    return @intCast(g_session.?.tracks.items.len); // Count all tracks including master
}

fn GetTrack(project: ReaProject, trackidx: c_int) callconv(.C) MediaTrack {
    _ = project;
    if (trackidx < 0 or trackidx >= g_session.?.tracks.items.len - 1) return null;
    const track = &g_session.?.tracks.items[@as(usize, @intCast(trackidx)) + 1];
    return @ptrCast(track);
}

fn GetMasterTrack(project: ReaProject) callconv(.C) MediaTrack {
    _ = project;
    const track = &g_session.?.tracks.items[0];
    return @ptrCast(track);
}

fn GetTrackName(tr: MediaTrack, buf: [*:0]u8, bufsz: c_int) callconv(.C) bool {
    var track: ?*Track = @alignCast(@ptrCast(tr));
    _ = &track;
    if (track == null or bufsz <= 0) return false;
    const name = g_session.?.getTrackName(track.?.*);
    if (name == null) return false;
    const len = @min(@as(usize, @intCast(bufsz)) - 1, name.?.len);
    @memcpy(buf[0..len], name.?[0..len]);
    buf[len] = 0; // Null terminate
    return true;
}

fn SetMediaTrackInfo_Value(tr: MediaTrack, parmname: [*:0]const u8, newvalue: f64) callconv(.C) bool {
    var track: ?*Track = @alignCast(@ptrCast(tr));
    _ = &track;
    if (track == null) return false;

    const param = std.mem.span(parmname);
    if (std.mem.eql(u8, param, "D_VOL")) {
        track.?.info.volume = newvalue;
        return true;
    } else if (std.mem.eql(u8, param, "D_PAN")) {
        track.?.info.pan = newvalue;
        return true;
    } else if (std.mem.eql(u8, param, "B_MUTE")) {
        track.?.info.mute = newvalue > 0.5;
        return true;
    } else if (std.mem.eql(u8, param, "I_SOLO")) {
        track.?.info.solo = @intFromFloat(newvalue);
        return true;
    }

    return false;
}

fn GetMediaTrackInfo_Value(tr: MediaTrack, parmname: [*:0]const u8) callconv(.C) f64 {
    var track: ?*Track = @alignCast(@ptrCast(tr));
    _ = &track;
    if (track == null) return 0;

    const param = std.mem.span(parmname);
    if (std.mem.eql(u8, param, "D_VOL")) {
        return track.?.info.volume;
    } else if (std.mem.eql(u8, param, "D_PAN")) {
        return track.?.info.pan;
    } else if (std.mem.eql(u8, param, "B_MUTE")) {
        return if (track.?.info.mute) 1.0 else 0.0;
    } else if (std.mem.eql(u8, param, "I_SOLO")) {
        return @floatFromInt(track.?.info.solo);
    }

    return 0;
}

fn SetTrackSelected(tr: MediaTrack, selected: bool) callconv(.C) void {
    var track: ?*Track = @alignCast(@ptrCast(tr));
    _ = &track;
    if (track == null) return;

    // Find track index
    const track_ptr: *const Track = track.?;
    for (g_session.?.tracks.items, 0..) |*t, i| {
        if (t == track_ptr) {
            if (selected) {
                // Check if already selected
                for (g_session.?.selected_tracks.items) |idx| {
                    if (idx == i) return;
                }
                g_session.?.selected_tracks.append(g_session.?.gpa, @intCast(i)) catch return;
            } else {
                // Remove from selection if present
                var j: usize = 0;
                while (j < g_session.?.selected_tracks.items.len) {
                    if (g_session.?.selected_tracks.items[j] == i) {
                        _ = g_session.?.selected_tracks.orderedRemove(j);
                    } else {
                        j += 1;
                    }
                }
            }
            return;
        }
    }
}

fn GetSelectedTrack(proj: ReaProject, seltrackidx: c_int) callconv(.C) MediaTrack {
    _ = proj;
    if (seltrackidx < 0 or seltrackidx >= g_session.?.selected_tracks.items.len) return null;

    const track_idx = g_session.?.selected_tracks.items[@intCast(seltrackidx)];
    const track = &g_session.?.tracks.items[track_idx];
    return @ptrCast(track);
}

test "track creation and deletion with mock API" {
    var test_ctx = setupTestModel(testing.allocator, 3, 4);
    defer test_ctx.teardown();

    // Initial track count
    try testing.expectEqual(@as(c_int, 4), reaper.CountTracks(0)); // 3 regular + master

    // Test track creation
    reaper.InsertTrackAtIndex(1, true);
    try testing.expectEqual(@as(c_int, 5), reaper.CountTracks(0)); // 4 regular + master

    // Get the newly created track
    const new_track = @as(?*Track, @ptrCast(@alignCast(reaper.GetTrack(0, 1))));
    try testing.expect(new_track.?.name == null);

    // Test track deletion
    reaper.DeleteTrack(@ptrCast(new_track.?));
    try testing.expectEqual(@as(c_int, 4), reaper.CountTracks(0)); // Back to 3 regular + master

    // Verify track numbering was updated
    for (0..3) |i| {
        const track = @as(?*Track, @ptrCast(@alignCast(reaper.GetTrack(0, @intCast(i)))));
        try testing.expect(track != null);
    }
}

test "fx operations with mock API" {
    var test_ctx = setupTestModel(testing.allocator, 3, 4);
    defer test_ctx.teardown();

    // Get a track to work with
    const track = @as(?*Track, @ptrCast(@alignCast(GetTrack(0, 0))));
    try testing.expect(track != null);

    // Initially no FX
    try testing.expectEqual(@as(c_int, 0), reaper.TrackFX_GetCount(@ptrCast(track.?)));

    // Add an FX
    const fx_idx = reaper.TrackFX_AddByName(@ptrCast(track.?), "ReaEQ", false, 0);
    try testing.expectEqual(@as(c_int, 0), fx_idx); // First FX should be at index 0
    try testing.expectEqual(@as(c_int, 1), reaper.TrackFX_GetCount(@ptrCast(track.?)));

    // Add another FX
    const fx_idx2 = reaper.TrackFX_AddByName(@ptrCast(track.?), "ReaComp", false, 0);
    try testing.expectEqual(@as(c_int, 1), fx_idx2); // Second FX should be at index 1
    try testing.expectEqual(@as(c_int, 2), reaper.TrackFX_GetCount(@ptrCast(track.?)));

    // Get FX name
    var buf: [128:0]u8 = undefined;
    const got_name = reaper.TrackFX_GetFXName(@ptrCast(track.?), 0, &buf, buf.len);
    try testing.expect(got_name);
    try testing.expectEqualStrings("ReaEQ", std.mem.span(@as([*:0]const u8, &buf)));

    // Get second FX name
    const got_name2 = reaper.TrackFX_GetFXName(@ptrCast(track.?), 1, &buf, buf.len);
    try testing.expect(got_name2);
    try testing.expectEqualStrings("ReaComp", std.mem.span(@as([*:0]const u8, &buf)));

    // Invalid FX index should return false
    const got_name3 = reaper.TrackFX_GetFXName(@ptrCast(track.?), 2, &buf, buf.len);
    try testing.expect(!got_name3);
}

test "mock reaper API track operations" {
    var test_ctx = setupTestModel(testing.allocator, 3, 4);
    defer test_ctx.teardown();

    const model = g_session.?;

    // Test track count via mock API
    const num_tracks = GetNumTracks();
    try testing.expectEqual(@as(c_int, 3), num_tracks); // Regular tracks only
    const total_tracks = CountTracks(0);
    try testing.expectEqual(@as(c_int, 4), total_tracks); // Including master

    // Test track retrieval via mock API
    const track1 = @as(?*Track, @ptrCast(@alignCast(GetTrack(0, 0))));
    try testing.expect(track1 != null);
    try testing.expectEqualStrings("Track 1", model.string_pool.getString(track1.?.name.?));

    const master = @as(?*Track, @ptrCast(@alignCast(GetMasterTrack(0))));
    try testing.expect(master != null);
    try testing.expectEqualStrings("Master", model.string_pool.getString(master.?.name.?));

    // Test track selection via mock API
    SetTrackSelected(@ptrCast(track1), true);
    try testing.expectEqual(@as(usize, 1), model.selected_tracks.items.len);

    const selected = @as(?*Track, @ptrCast(@alignCast(GetSelectedTrack(0, 0))));
    try testing.expect(selected != null);
    try testing.expectEqualStrings("Track 1", model.string_pool.getString(selected.?.name.?));

    // Test track parameters via mock API
    _ = SetMediaTrackInfo_Value(@ptrCast(track1), "D_VOL", 0.5);
    try testing.expectEqual(@as(f64, 0.5), GetMediaTrackInfo_Value(@ptrCast(track1), "D_VOL"));

    _ = SetMediaTrackInfo_Value(@ptrCast(track1), "B_MUTE", 1.0);
    try testing.expectEqual(@as(f64, 1.0), GetMediaTrackInfo_Value(@ptrCast(track1), "B_MUTE"));

    _ = SetMediaTrackInfo_Value(@ptrCast(track1), "I_SOLO", 1.0);
    try testing.expectEqual(@as(f64, 1.0), GetMediaTrackInfo_Value(@ptrCast(track1), "I_SOLO"));

    // Test track deselection via mock API
    SetTrackSelected(@ptrCast(track1), false);
    try testing.expectEqual(@as(usize, 0), model.selected_tracks.items.len);
}

const std = @import("std");
const testing = std.testing;
const reaper = @import("../reaper.zig").reaper;
const Guid = @import("../utils.zig").Guid;
const fx_model = @import("fx_model.zig");
const Param = fx_model.Param;
const FX = fx_model.FX;
const track_model = @import("track_model.zig");
const Track = track_model.Track;
const Session = @import("session.zig");
const ReaProject = reaper.ReaProject;
const MediaTrack = reaper.MediaTrack;
