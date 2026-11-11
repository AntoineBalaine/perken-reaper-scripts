//! The user presets of an FX of a track, through REAPER: the names that its preset file has, the loading of one, and
//! the saving of the state of the FX as a new one. See `preset_store.zig` for the file.
const std = @import("std");
const reaper = @import("reaper").reaper;
const pReaper = @import("pReaper.zig");
const preset_store = @import("preset_store.zig");
const log = std.log.scoped(.fx_presets);

pub const SaveError = error{
    /// REAPER gave no preset file for the FX.
    NoPresetFile,
    /// The FX is neither a VST nor a JS, which are the kinds whose state is known.
    UnsupportedFx,
    NoChunk,
    OutOfMemory,
    WriteFailed,
};

fn presetPath(track: reaper.MediaTrack, fx_index: c_int, buffer: *[std.fs.max_path_bytes:0]u8) ?[:0]const u8 {
    buffer[0] = 0;
    reaper.TrackFX_GetUserPresetFilename(track, fx_index, @ptrCast(buffer), @intCast(buffer.len));
    const length = std.mem.indexOfScalar(u8, buffer, 0) orelse return null;
    if (length == 0) return null;
    return buffer[0..length :0];
}

fn readFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !?[]u8 {
    const file = std.Io.Dir.openFileAbsolute(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => return err,
    };
    defer file.close(io);
    var content: std.ArrayList(u8) = .empty;
    errdefer content.deinit(allocator);
    var buffer: [4096]u8 = undefined;
    var reader = file.reader(io, &buffer);
    try reader.interface.appendRemainingUnlimited(allocator, &content);
    return try content.toOwnedSlice(allocator);
}

/// The names of the user presets of the FX, in the order of its preset file. Both the slice and the names are owned by
/// `allocator`, which is meant to be an arena. The list is empty when the FX has no preset file yet.
pub fn listNames(allocator: std.mem.Allocator, io: std.Io, track: reaper.MediaTrack, fx_index: c_int) ![]const [:0]const u8 {
    var path_buffer: [std.fs.max_path_bytes:0]u8 = undefined;
    const path = presetPath(track, fx_index, &path_buffer) orelse return &.{};
    const content = (try readFile(allocator, io, path)) orelse return &.{};
    defer allocator.free(content);
    const names = try preset_store.presetNames(allocator, content);
    defer allocator.free(names);
    const owned = try allocator.alloc([:0]const u8, names.len);
    for (names, 0..) |name, i| owned[i] = try allocator.dupeSentinel(u8, name, 0);
    return owned;
}

/// Loads the preset of that name into the FX.
pub fn load(track: reaper.MediaTrack, fx_index: c_int, name: [:0]const u8) bool {
    return pReaper.TrackFX_SetPreset(.{ track, fx_index, name });
}

/// The name of the preset that the FX shows, or null when it shows none or its state moved away from it.
pub fn currentName(track: reaper.MediaTrack, fx_index: c_int, buffer: *[256:0]u8) ?[:0]const u8 {
    buffer[0] = 0;
    if (!reaper.TrackFX_GetPreset(track, fx_index, buffer, buffer.len)) return null;
    const length = std.mem.indexOfScalar(u8, buffer, 0) orelse return null;
    if (length == 0) return null;
    return buffer[0..length :0];
}

/// The text of the state of a track, as REAPER gives it.
fn trackChunk(allocator: std.mem.Allocator, track: reaper.MediaTrack) ![]u8 {
    var size: usize = 1 << 20;
    const max_size: usize = 1 << 28;
    while (size <= max_size) : (size *= 2) {
        const buffer = try allocator.alloc(u8, size);
        errdefer allocator.free(buffer);
        buffer[0] = 0;
        if (!reaper.GetTrackStateChunk(track, @ptrCast(buffer.ptr), @intCast(size), false)) return error.NoChunk;
        const length = std.mem.indexOfScalar(u8, buffer, 0) orelse size;
        // A chunk that fills the buffer was cut, so it is read again with a bigger one.
        if (length + 1 < size) return allocator.realloc(buffer, length);
        allocator.free(buffer);
    }
    return error.NoChunk;
}

/// Saves the state of the FX as a preset of that name in its preset file, replacing a preset of the same name, and
/// makes REAPER show it.
pub fn save(allocator: std.mem.Allocator, io: std.Io, track: reaper.MediaTrack, fx_index: c_int, name: [:0]const u8) SaveError!void {
    var path_buffer: [std.fs.max_path_bytes:0]u8 = undefined;
    const path = presetPath(track, fx_index, &path_buffer) orelse return error.NoPresetFile;

    const chunk = trackChunk(allocator, track) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.NoChunk,
    };
    defer allocator.free(chunk);
    const block = (preset_store.extractFxBlock(allocator, chunk, @intCast(fx_index)) catch return error.OutOfMemory) orelse
        return error.UnsupportedFx;
    defer allocator.free(block.lines);

    const hex = preset_store.presetHex(allocator, block, name) catch |err| return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.NoChunk,
    };
    defer allocator.free(hex);

    const existing = readFile(allocator, io, path) catch return error.WriteFailed;
    defer if (existing) |content| allocator.free(content);
    const updated = try preset_store.withPreset(allocator, existing, name, hex);
    defer allocator.free(updated);

    if (std.fs.path.dirname(path)) |directory| {
        std.Io.Dir.createDirAbsolute(io, directory, .default_dir) catch |err| {
            if (err != error.PathAlreadyExists) return error.WriteFailed;
        };
    }
    const file = std.Io.Dir.createFileAbsolute(io, path, .{ .truncate = true }) catch return error.WriteFailed;
    defer file.close(io);
    file.writeStreamingAll(io, updated) catch return error.WriteFailed;
    log.info("saved preset '{s}' to {s}", .{ name, path });

    // Because REAPER reads its preset files when it needs them, activating the preset makes it know the new one.
    _ = load(track, fx_index, name);
}
