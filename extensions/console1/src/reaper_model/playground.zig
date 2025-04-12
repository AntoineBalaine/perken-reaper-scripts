// reaper_model_test.zig - REAPER Model Testing Playground

const std = @import("std");
const testing = std.testing;

// Basic data structures
const AutomationMode = enum {
    trim_read,
    read,
    touch,
    write,
    latch,
};

const TrackInfo = struct {
    phase: bool = false,
    num_channels: i32 = 2,
    volume: f64 = 1.0,
    pan: f64 = 0.0,
    mute: bool = false,
    solo: i32 = 0,
    track_number: i32 = 0,
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
    guid: [:0]const u8,
    enabled: bool = true,
    params: std.ArrayList(Param),

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.guid);
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

// REAPER State
const ReaperState = struct {
    tracks: std.ArrayList(Track),
    selected_track_indices: std.ArrayList(usize),
    last_touched_track_index: ?usize = null,
    cursor_position: f64 = 0.0,
    global_automation_mode: AutomationMode = .read,

    pub fn deinit(self: *@This()) void {
        const allocator = self.tracks.allocator;
        for (self.tracks.items) |*track| {
            track.deinit(allocator);
        }
        self.tracks.deinit();
        self.selected_track_indices.deinit();
    }
};

// Mock REAPER API functions
fn GetNumTracks(project: ?*anyopaque, state: *ReaperState) i32 {
    _ = project;
    return @intCast(state.tracks.items.len - 1); // Don't count master track
}

fn CountTracks(project: ?*anyopaque, state: *ReaperState) i32 {
    _ = project;
    return @intCast(state.tracks.items.len); // Count all tracks including master
}

fn GetTrack(project: ?*anyopaque, trackidx: i32, state: *ReaperState) ?*Track {
    _ = project;
    if (trackidx < 0 or trackidx >= state.tracks.items.len - 1) return null;
    return &state.tracks.items[@as(usize, @intCast(trackidx)) + 1]; // Skip master track
}

fn GetMasterTrack(project: ?*anyopaque, state: *ReaperState) ?*Track {
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

fn SetTrackSelected(track: ?*Track, selected: bool, state: *ReaperState) void {
    if (track == null) return;

    // Find track index
    const track_ptr: *const Track = @ptrCast(track.?);
    for (state.tracks.items, 0..) |*t, i| {
        if (@as(*const Track, @ptrCast(t)) == track_ptr) {
            if (selected) {
                // Check if already selected
                for (state.selected_track_indices.items) |idx| {
                    if (idx == i) return;
                }
                state.selected_track_indices.append(i) catch return;
            } else {
                // Remove from selection if present
                var j: usize = 0;
                while (j < state.selected_track_indices.items.len) {
                    if (state.selected_track_indices.items[j] == i) {
                        _ = state.selected_track_indices.orderedRemove(j);
                    } else {
                        j += 1;
                    }
                }
            }
            return;
        }
    }
}

fn GetSelectedTrack(project: ?*anyopaque, seltrackidx: i32, state: *ReaperState) ?*Track {
    _ = project;
    if (seltrackidx < 0 or seltrackidx >= state.selected_track_indices.items.len) return null;

    const track_idx = state.selected_track_indices.items[@intCast(seltrackidx)];
    return &state.tracks.items[track_idx];
}

// Test initialization helper
fn initializeTestState(allocator: std.mem.Allocator) !ReaperState {
    var state = ReaperState{
        .tracks = std.ArrayList(Track).init(allocator),
        .selected_track_indices = std.ArrayList(usize).init(allocator),
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
            .info = .{ .track_number = @intCast(i + 1) },
        });
    }

    return state;
}

// Tests
test "basic track operations" {
    var allocator = testing.allocator;
    _ = &allocator;
    var state = try initializeTestState(allocator);
    defer state.deinit();

    // Test track count
    const num_tracks = GetNumTracks(null, &state);
    try testing.expectEqual(@as(i32, 3), num_tracks);

    const total_tracks = CountTracks(null, &state);
    try testing.expectEqual(@as(i32, 4), total_tracks); // 3 regular + master

    // Test track retrieval
    const track1 = GetTrack(null, 0, &state);
    try testing.expect(track1 != null);
    try testing.expectEqualStrings("Track 1", track1.?.name);

    const master = GetMasterTrack(null, &state);
    try testing.expect(master != null);
    try testing.expectEqualStrings("Master", master.?.name);

    // Test track selection
    SetTrackSelected(track1, true, &state);
    try testing.expectEqual(@as(usize, 1), state.selected_track_indices.items.len);

    const selected = GetSelectedTrack(null, 0, &state);
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
    SetTrackSelected(track1, false, &state);
    try testing.expectEqual(@as(usize, 0), state.selected_track_indices.items.len);
}
