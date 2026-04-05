tracks: std.ArrayListUnmanaged(Track.Track) = .empty,
/// data storage for track names
string_pool: StringPool = .empty,
selected_tracks: std.ArrayListUnmanaged(u32) = .empty,
last_touched_track_index: ?usize = null,
cursor_position: f64 = 0.0,
global_automation_mode: AutomationMode = .read,
arena_alloc: std.mem.Allocator = undefined,

pub fn ensureTotalCapacity(self: *@This(), gpa: std.mem.Allocator, new_capacity: usize) !void {
    try self.tracks.ensureTotalCapacity(gpa, new_capacity + 1);
    try self.selected_tracks.ensureTotalCapacity(gpa, new_capacity + 1);
}

/// Creates a master track and three tracks
/// will init tracks list with a capacity of `track_capacity` + 1 for master track.
pub fn init(gpa: std.mem.Allocator, track_count: usize, max_tracks: usize) !@This() {
    std.debug.assert(track_count <= max_tracks);
    var self: @This() = .{};
    self.arena_alloc = gpa;
    try self.ensureTotalCapacity(gpa, max_tracks);
    // Create a master track

    var master_tr: Track.Track = .default;
    master_tr.name = try self.string_pool.add(gpa, "Master");
    try self.tracks.append(gpa, master_tr);

    // Create a few regular tracks
    for (0..track_count) |i| {
        var track: Track.Track = .default;
        var buf: [1024]u8 = undefined;
        const track_name = std.fmt.bufPrint(&buf, "Track {d}", .{i + 1}) catch unreachable;
        track.name = try self.string_pool.add(gpa, track_name);
        try self.tracks.append(gpa, track);
    }

    return self;
}

pub fn getTrackName(self: @This(), track: Track.Track) ?[:0]const u8 {
    if (track.name) |name| {
        return self.string_pool.getString(name);
    }
    return null;
}

pub fn setTrackName(self: *@This(), track_index: usize, name: []const u8) !void {
    if (track_index >= self.tracks.items.len) return error.InvalidTrackIndex;
    const interned_name = try self.string_pool.add(self.arena_alloc, name);
    self.tracks.items[track_index].name = interned_name;
}

const std = @import("std");
const AutomationMode = @import("automation_mode.zig").AutomationMode;
const Track = @import("track_model.zig");
const StringPool = @import("utils").StringPool;
