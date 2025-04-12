// reaper_model_test.zig - REAPER Model Testing Playground

const std = @import("std");
const testing = std.testing;
const reaper = @import("../reaper.zig").reaper;
const AutomationMode = @import("../transport_actions.zig").AutomationMode;
const utils = @import("../utils.zig");

const TrackInfo = struct {
    phase: bool = false,
    num_channels: i32 = 2,
    volume: f64 = 1.0,
    pan: f64 = 0.0,
    mute: bool = false,
    solo: i32 = 0,
};

const PeakInfo = struct {
    left: f64 = 0.0,
    right: f64 = 0.0,
};

const Param = struct {
    name: [:0]const u8,
    normalized_value: f64 = 0.0,
    formatted_value: [:0]const u8,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.formatted_value);
    }
};

const FX = struct {
    name: [:0]const u8,
    guid: utils.Guid,
    enabled: bool = true,
    params: std.ArrayList(Param),

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        for (self.params.items) |*param| {
            param.deinit(allocator);
        }
        self.params.deinit();
    }
};

const Track = struct {
    name: [:0]const u8,
    fx_list: std.ArrayList(FX),
    automation_mode: AutomationMode = .read,
    info: TrackInfo = .{},
    peak_info: ?PeakInfo = null,

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        for (self.fx_list.items) |*fx| {
            fx.deinit(allocator);
        }
        self.fx_list.deinit();
    }
};

// REAPER Model
const RprModel = struct {
    tracks: std.ArrayList(Track),
    selected_tracks: std.ArrayList(usize),
    last_touched_track_index: ?usize = null,
    cursor_position: f64 = 0.0,
    global_automation_mode: AutomationMode = .read,

    pub fn deinit(self: *@This()) void {
        const allocator = self.tracks.allocator;
        for (self.tracks.items) |*track| {
            track.deinit(allocator);
        }
        self.tracks.deinit();
        self.selected_tracks.deinit();
    }
};

// Global model state
var g_rpr_model: ?*RprModel = null;

// Helper to set the current model for testing
pub fn setCurrentModel(model: *RprModel) void {
    g_rpr_model = model;
}

// Mock REAPER API functions with the same signatures as the real API
fn mockInsertTrackAtIndex(idx: c_int, wantDefaults: bool) callconv(.C) void {
    _ = wantDefaults;
    const model = g_rpr_model.?;
    const allocator = model.tracks.allocator;

    // Determine the actual index in our tracks array (accounting for master track at index 0)
    const actual_idx = if (idx < 0) model.tracks.items.len else @as(usize, @intCast(idx)) + 1;

    const track = Track{
        .name = allocator.dupeZ(u8, "") catch return,
        .fx_list = std.ArrayList(FX).init(allocator),
        .info = .{},
    };

    if (actual_idx >= model.tracks.items.len) {
        // Append to the end
        model.tracks.append(track) catch return;
    } else {
        // Insert at the specified position
        model.tracks.insert(actual_idx, track) catch return;
    }
}

// Mock FX manipulation functions
// NOTE: there is the case in which we try to add an fx which
// doesn't exist on the user's system, in which case reaper returns -1
fn mockTrackFX_AddByName(track: reaper.MediaTrack, fxname: [*:0]const u8, recFX: bool, instantiate: c_int) callconv(.C) c_int {
    _ = recFX;
    _ = instantiate;
    const model = g_rpr_model.?;

    // Cast to optional pointer and check for null
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return -1;

    const allocator = model.tracks.allocator;
    const fx_name = std.mem.span(fxname);

    var guid_bytes: [16]u8 = undefined;
    std.crypto.random.bytes(&guid_bytes);
    const guid = utils.Guid{ .bytes = guid_bytes };

    // Create a new FX
    const new_fx = FX{
        .name = allocator.dupeZ(u8, fx_name) catch return -1,
        .guid = guid,
        .enabled = true,
        .params = std.ArrayList(Param).init(allocator),
    };
    var tr: *Track = track_ptr.?;

    // Add the FX to the track
    tr.fx_list.append(new_fx) catch return -1;

    // Return the index of the newly added FX
    return @intCast(tr.fx_list.items.len - 1);
}

fn mockTrackFX_GetCount(track: reaper.MediaTrack) callconv(.C) c_int {
    // Cast to optional pointer and check for null
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return -1;

    // Access the track's fx_list directly
    const tr: *const Track = track_ptr.?;
    return @intCast(tr.fx_list.items.len);
}

fn mockTrackFX_GetFXName(track: reaper.MediaTrack, fx: c_int, bufOut: [*:0]u8, bufOut_sz: c_int) callconv(.C) bool {
    // Cast to optional pointer and check for null
    const track_ptr: ?*Track = @ptrCast(@alignCast(track));
    if (track_ptr == null) return false;

    // Access the track's fx_list directly
    const tr: *const Track = track_ptr.?;

    // Check if FX index is valid
    if (fx < 0 or fx >= tr.fx_list.items.len) return false;

    // Copy the FX name to the buffer
    const name = tr.fx_list.items[@intCast(fx)].name;
    const len = @min(@as(usize, @intCast(bufOut_sz)) - 1, name.len);
    @memcpy(bufOut[0..len], name[0..len]);
    bufOut[len] = 0; // Null terminate
    return true;
}

fn mockDeleteTrack(tr: reaper.MediaTrack) callconv(.C) void {
    const model = g_rpr_model.?;

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
    removed_track.deinit(model.tracks.allocator);

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

// Helper functions to set up and tear down the mock API
pub fn setupMockReaperAPI(model: *RprModel) struct {
    origInsertTrackAtIndex: @TypeOf(reaper.InsertTrackAtIndex),
    origDeleteTrack: @TypeOf(reaper.DeleteTrack),
    origTrackFX_AddByName: @TypeOf(reaper.TrackFX_AddByName),
    origTrackFX_GetCount: @TypeOf(reaper.TrackFX_GetCount),
    origTrackFX_GetFXName: @TypeOf(reaper.TrackFX_GetFXName),
} {
    setCurrentModel(model);

    const origFuncs = .{
        .origInsertTrackAtIndex = reaper.InsertTrackAtIndex,
        .origDeleteTrack = reaper.DeleteTrack,
        .origTrackFX_AddByName = reaper.TrackFX_AddByName,
        .origTrackFX_GetCount = reaper.TrackFX_GetCount,
        .origTrackFX_GetFXName = reaper.TrackFX_GetFXName,
    };

    @constCast(&reaper.InsertTrackAtIndex).* = @constCast(&mockInsertTrackAtIndex);
    @constCast(&reaper.DeleteTrack).* = @constCast(&mockDeleteTrack);
    @constCast(&reaper.TrackFX_AddByName).* = @constCast(&mockTrackFX_AddByName);
    @constCast(&reaper.TrackFX_GetCount).* = @constCast(&mockTrackFX_GetCount);
    @constCast(&reaper.TrackFX_GetFXName).* = @constCast(&mockTrackFX_GetFXName);

    return origFuncs;
}

pub fn restoreMockReaperAPI(origFuncs: anytype) void {
    @constCast(&reaper.InsertTrackAtIndex).* = origFuncs.origInsertTrackAtIndex;
    @constCast(&reaper.DeleteTrack).* = origFuncs.origDeleteTrack;
    @constCast(&reaper.TrackFX_AddByName).* = origFuncs.origTrackFX_AddByName;
    @constCast(&reaper.TrackFX_GetCount).* = origFuncs.origTrackFX_GetCount;
    @constCast(&reaper.TrackFX_GetFXName).* = origFuncs.origTrackFX_GetFXName;

    g_rpr_model = null;
}

// Mock REAPER API functions
fn GetNumTracks(project: ?*anyopaque, state: *RprModel) i32 {
    _ = project;
    return @intCast(state.tracks.items.len - 1); // Don't count master track
}

fn CountTracks(project: ?*anyopaque, state: *RprModel) i32 {
    _ = project;
    return @intCast(state.tracks.items.len); // Count all tracks including master
}

fn GetTrack(project: ?*anyopaque, trackidx: i32, state: *RprModel) ?*Track {
    _ = project;
    if (trackidx < 0 or trackidx >= state.tracks.items.len - 1) return null;
    return &state.tracks.items[@as(usize, @intCast(trackidx)) + 1]; // Skip master track
}

fn GetMasterTrack(project: ?*anyopaque, state: *RprModel) ?*Track {
    _ = project;
    return &state.tracks.items[0];
}

fn GetTrackName(track: ?*Track, buf: ?[*]u8, bufsz: i32) bool {
    if (track == null or buf == null or bufsz <= 0) return false;

    const name = track.?.name;
    const len = @min(@as(usize, @intCast(bufsz)) - 1, name.len);
    @memcpy(buf.?[0..len], name[0..len]);
    buf.?[len] = 0; // Null terminate
    return true;
}

fn SetMediaTrackInfo_Value(track: ?*Track, parmname: [*:0]const u8, newvalue: f64) bool {
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

fn GetMediaTrackInfo_Value(track: ?*Track, parmname: [*:0]const u8) f64 {
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

fn SetTrackSelected(track: ?*Track, selected: bool, state: *RprModel) void {
    if (track == null) return;

    // Find track index
    const track_ptr: *const Track = track.?;
    for (state.tracks.items, 0..) |*t, i| {
        if (t == track_ptr) {
            if (selected) {
                // Check if already selected
                for (state.selected_tracks.items) |idx| {
                    if (idx == i) return;
                }
                state.selected_tracks.append(i) catch return;
            } else {
                // Remove from selection if present
                var j: usize = 0;
                while (j < state.selected_tracks.items.len) {
                    if (state.selected_tracks.items[j] == i) {
                        _ = state.selected_tracks.orderedRemove(j);
                    } else {
                        j += 1;
                    }
                }
            }
            return;
        }
    }
}

fn GetSelectedTrack(project: ?*anyopaque, seltrackidx: i32, state: *RprModel) ?*Track {
    _ = project;
    if (seltrackidx < 0 or seltrackidx >= state.selected_tracks.items.len) return null;

    const track_idx = state.selected_tracks.items[@intCast(seltrackidx)];
    return &state.tracks.items[track_idx];
}

// Test initialization helper
fn initializeTestState(allocator: std.mem.Allocator) !RprModel {
    var state = RprModel{
        .tracks = std.ArrayList(Track).init(allocator),
        .selected_tracks = std.ArrayList(usize).init(allocator),
    };

    // Create a master track
    try state.tracks.append(.{
        .name = try allocator.dupeZ(u8, "Master"),
        .fx_list = std.ArrayList(FX).init(allocator),
    });

    // Create a few regular tracks
    for (0..3) |i| {
        const track_name = try std.fmt.allocPrintZ(allocator, "Track {d}", .{i + 1});
        try state.tracks.append(.{
            .name = track_name,
            .fx_list = std.ArrayList(FX).init(allocator),
            .info = .{},
        });
    }

    return state;
}

// Tests
test "track creation and deletion with mock API" {
    var allocator = testing.allocator;
    _ = &allocator;
    var model = try initializeTestState(allocator);
    defer model.deinit();

    // Set up the mock API
    const origFuncs = setupMockReaperAPI(&model);
    defer restoreMockReaperAPI(origFuncs);

    // Initial track count
    try testing.expectEqual(@as(i32, 4), CountTracks(null, &model)); // 3 regular + master

    // Test track creation
    reaper.InsertTrackAtIndex(1, true);
    try testing.expectEqual(@as(i32, 5), CountTracks(null, &model)); // 4 regular + master

    // Get the newly created track
    const new_track = GetTrack(null, 1, &model);
    try testing.expect(new_track != null);
    try testing.expectEqualStrings("", new_track.?.name);

    // Test track deletion
    reaper.DeleteTrack(@ptrCast(new_track.?));
    try testing.expectEqual(@as(i32, 4), CountTracks(null, &model)); // Back to 3 regular + master

    // Verify track numbering was updated
    for (1..4) |i| {
        const track = GetTrack(null, @intCast(i - 1), &model);
        try testing.expect(track != null);
    }
}

test "fx operations with mock API" {
    var allocator = testing.allocator;
    _ = &allocator;
    var model = try initializeTestState(allocator);
    defer model.deinit();

    // Set up the mock API
    const origFuncs = setupMockReaperAPI(&model);
    defer restoreMockReaperAPI(origFuncs);

    // Get a track to work with
    const track = GetTrack(null, 0, &model);
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

test "basic track operations" {
    var allocator = testing.allocator;
    _ = &allocator;
    var model = try initializeTestState(allocator);
    defer model.deinit();

    // Test track count
    const num_tracks = GetNumTracks(null, &model);
    try testing.expectEqual(@as(i32, 3), num_tracks);

    const total_tracks = CountTracks(null, &model);
    try testing.expectEqual(@as(i32, 4), total_tracks); // 3 regular + master

    // Test track retrieval
    const track1 = GetTrack(null, 0, &model);
    try testing.expect(track1 != null);
    try testing.expectEqualStrings("Track 1", track1.?.name);

    const master = GetMasterTrack(null, &model);
    try testing.expect(master != null);
    try testing.expectEqualStrings("Master", master.?.name);

    // Test track selection
    SetTrackSelected(track1, true, &model);
    try testing.expectEqual(@as(usize, 1), model.selected_tracks.items.len);

    const selected = GetSelectedTrack(null, 0, &model);
    try testing.expect(selected != null);
    try testing.expectEqualStrings("Track 1", selected.?.name);

    // Test volume
    const initial_vol = GetMediaTrackInfo_Value(track1, "D_VOL");
    try testing.expectEqual(@as(f64, 1.0), initial_vol);

    _ = SetMediaTrackInfo_Value(track1, "D_VOL", 0.5);
    const new_vol = GetMediaTrackInfo_Value(track1, "D_VOL");
    try testing.expectEqual(@as(f64, 0.5), new_vol);

    // Test mute and solo
    _ = SetMediaTrackInfo_Value(track1, "B_MUTE", 1.0);
    const mute = GetMediaTrackInfo_Value(track1, "B_MUTE");
    try testing.expectEqual(@as(f64, 1.0), mute);

    _ = SetMediaTrackInfo_Value(track1, "I_SOLO", 1.0);
    const solo = GetMediaTrackInfo_Value(track1, "I_SOLO");
    try testing.expectEqual(@as(f64, 1.0), solo);

    // Test track deselection
    SetTrackSelected(track1, false, &model);
    try testing.expectEqual(@as(usize, 0), model.selected_tracks.items.len);
}
