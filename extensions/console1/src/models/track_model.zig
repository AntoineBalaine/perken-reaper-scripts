const std = @import("std");
const AutomationMode = @import("../transport_actions.zig").AutomationMode;
const utils = @import("../utils.zig");
const fx_model = @import("fx_model.zig");
const Param = fx_model.Param;
const FX = fx_model.FX;

pub const TrackInfo = struct {
    phase: bool = false,
    num_channels: i32 = 2,
    volume: f64 = 1.0,
    pan: f64 = 0.0,
    mute: bool = false,
    solo: i32 = 0,
};

pub const PeakInfo = struct {
    left: f64 = 0.0,
    right: f64 = 0.0,
};

pub const Track = struct {
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

/// create a master track and three tracks
pub fn initializeTestState(allocator: std.mem.Allocator) !Session {
    var state = Session{
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

// REAPER Model
pub const Session = struct {
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

test "basic track operations" {
    var allocator = std.testing.allocator;
    _ = &allocator;
    var model = try initializeTestState(allocator);
    defer model.deinit();

    // Test track count
    try std.testing.expectEqual(@as(usize, 3), model.tracks.items.len - 1); // Excluding master track
    try std.testing.expectEqual(@as(usize, 4), model.tracks.items.len); // Including master track

    // Test track names
    try std.testing.expectEqualStrings("Master", model.tracks.items[0].name);
    try std.testing.expectEqualStrings("Track 1", model.tracks.items[1].name);
    try std.testing.expectEqualStrings("Track 2", model.tracks.items[2].name);
    try std.testing.expectEqualStrings("Track 3", model.tracks.items[3].name);

    // Test track info defaults
    const track1 = &model.tracks.items[1];
    try std.testing.expectEqual(@as(f64, 1.0), track1.info.volume);
    try std.testing.expectEqual(@as(f64, 0.0), track1.info.pan);
    try std.testing.expect(!track1.info.mute);
    try std.testing.expectEqual(@as(i32, 0), track1.info.solo);
}

test "basic track state initialization" {
    const testing = std.testing;
    var allocator = testing.allocator;
    _ = &allocator;
    var state = try initializeTestState(allocator);
    defer state.deinit();

    // Test track count
    try testing.expectEqual(@as(usize, 4), state.tracks.items.len); // 3 regular + master
    try testing.expectEqual(@as(usize, 0), state.selected_tracks.items.len);

    // Test track names
    try testing.expectEqualStrings("Master", state.tracks.items[0].name);
    try testing.expectEqualStrings("Track 1", state.tracks.items[1].name);
    try testing.expectEqualStrings("Track 2", state.tracks.items[2].name);
    try testing.expectEqualStrings("Track 3", state.tracks.items[3].name);

    // Test default track info values
    for (state.tracks.items) |track| {
        try testing.expectEqual(@as(f64, 1.0), track.info.volume);
        try testing.expectEqual(@as(f64, 0.0), track.info.pan);
        try testing.expect(!track.info.mute);
        try testing.expectEqual(@as(i32, 0), track.info.solo);
    }
}
