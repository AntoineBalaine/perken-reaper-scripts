const std = @import("std");
const testing = std.testing;
const reaper_mock = @import("reaper_mock");
const reaper = @import("reaper").reaper;
const Session = @import("session");
const fx_model = @import("fx_model");

test "setupTestModel creates a session with tracks" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var env = reaper_mock.setupTestModel(arena.allocator(), 3, 8);
    defer env.teardown();

    // The session should have 4 tracks: 1 master + 3 regular.
    try testing.expectEqual(@as(usize, 4), env.model_ptr.tracks.items.len);
}

test "mock REAPER API returns track count" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var env = reaper_mock.setupTestModel(arena.allocator(), 2, 4);
    defer env.teardown();

    // CountTracks includes the master track in the mock implementation.
    // 2 regular tracks + 1 master = 3.
    const count = reaper.CountTracks(0);
    try testing.expectEqual(@as(c_int, 3), count);

    // GetNumTracks excludes the master track.
    const num = reaper.GetNumTracks();
    try testing.expectEqual(@as(c_int, 2), num);
}

test "mock REAPER API can insert and delete tracks" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var env = reaper_mock.setupTestModel(arena.allocator(), 1, 8);
    defer env.teardown();

    // 1 regular + 1 master = 2 total, 1 via GetNumTracks.
    try testing.expectEqual(@as(c_int, 1), reaper.GetNumTracks());

    // Insert a track at index 1 (after the first regular track).
    reaper.InsertTrackAtIndex(1, false);
    try testing.expectEqual(@as(c_int, 2), reaper.GetNumTracks());

    // Get the inserted track and delete it.
    const track = reaper.GetTrack(0, 1);
    try testing.expect(track != null);
    reaper.DeleteTrack(track.?);
    try testing.expectEqual(@as(c_int, 1), reaper.GetNumTracks());
}

test "mock GetTrack returns tracks by index" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var env = reaper_mock.setupTestModel(arena.allocator(), 3, 8);
    defer env.teardown();

    // Track indices are 0-based into regular tracks only.
    const track0 = reaper.GetTrack(0, 0);
    const track1 = reaper.GetTrack(0, 1);
    const track2 = reaper.GetTrack(0, 2);
    const track3 = reaper.GetTrack(0, 3); // out of range

    try testing.expect(track0 != null);
    try testing.expect(track1 != null);
    try testing.expect(track2 != null);
    try testing.expect(track3 == null);
}

test "session track names are accessible via the string pool" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var env = reaper_mock.setupTestModel(arena.allocator(), 2, 4);
    defer env.teardown();

    const model = env.model_ptr;

    // Master track is at index 0.
    const master_name = model.getTrackName(model.tracks.items[0]);
    try testing.expect(master_name != null);
    try testing.expectEqualStrings("Master", master_name.?);

    // First regular track is at index 1.
    const track1_name = model.getTrackName(model.tracks.items[1]);
    try testing.expect(track1_name != null);
    try testing.expectEqualStrings("Track 1", track1_name.?);
}

test "GetMediaTrackInfo_Value returns I_FXEN" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var env = reaper_mock.setupTestModel(arena.allocator(), 1, 4);
    defer env.teardown();

    const track = reaper.GetTrack(0, 0).?;
    try testing.expectEqual(@as(f64, 1.0), reaper.GetMediaTrackInfo_Value(track, "I_FXEN"));

    _ = reaper.SetMediaTrackInfo_Value(track, "I_FXEN", 0.0);
    try testing.expectEqual(@as(f64, 0.0), reaper.GetMediaTrackInfo_Value(track, "I_FXEN"));
}

test "GetMediaTrackInfo_Value returns I_AUTOMODE" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var env = reaper_mock.setupTestModel(arena.allocator(), 1, 4);
    defer env.teardown();

    const track = reaper.GetTrack(0, 0).?;
    try testing.expectEqual(@as(f64, 1.0), reaper.GetMediaTrackInfo_Value(track, "I_AUTOMODE"));

    _ = reaper.SetMediaTrackInfo_Value(track, "I_AUTOMODE", 3.0);
    try testing.expectEqual(@as(f64, 3.0), reaper.GetMediaTrackInfo_Value(track, "I_AUTOMODE"));
}

test "TrackFX_GetNamedConfigParm returns parallel" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var env = reaper_mock.setupTestModel(arena.allocator(), 1, 4);
    defer env.teardown();

    const track = reaper.GetTrack(0, 0).?;
    _ = reaper.TrackFX_AddByName(track, "TestFX", false, -1);

    var buf: [64:0]u8 = undefined;
    const result = reaper.TrackFX_GetNamedConfigParm(track, 0, "parallel", &buf, buf.len);
    try testing.expect(result);
    try testing.expectEqualStrings("0", std.mem.span(@as([*:0]const u8, &buf)));
}

test "TrackFX_GetNamedConfigParm returns fx_type" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var env = reaper_mock.setupTestModel(arena.allocator(), 1, 4);
    defer env.teardown();

    const track = reaper.GetTrack(0, 0).?;
    _ = reaper.TrackFX_AddByName(track, "TestFX", false, -1);

    var buf: [64:0]u8 = undefined;
    const result = reaper.TrackFX_GetNamedConfigParm(track, 0, "fx_type", &buf, buf.len);
    try testing.expect(result);
    try testing.expectEqualStrings("VST", std.mem.span(@as([*:0]const u8, &buf)));
}

test "setFxParams populates FX params" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    var env = reaper_mock.setupTestModel(arena.allocator(), 1, 4);
    defer env.teardown();

    const track = reaper.GetTrack(0, 0).?;
    _ = reaper.TrackFX_AddByName(track, "TestFX", false, -1);

    try testing.expectEqual(@as(c_int, 0), reaper.TrackFX_GetNumParams(track, 0));

    const params = [_]fx_model.Param{
        .{ .name = "Gain", .formatted_value = "0 dB" },
        .{ .name = "Pan", .formatted_value = "C" },
        .{ .name = "Mix", .formatted_value = "100%" },
    };
    try env.model_ptr.setFxParams(1, 0, &params);

    try testing.expectEqual(@as(c_int, 3), reaper.TrackFX_GetNumParams(track, 0));

    var name_buf: [256:0]u8 = undefined;
    _ = reaper.TrackFX_GetParamName(track, 0, 0, &name_buf, name_buf.len);
    try testing.expectEqualStrings("Gain", std.mem.span(@as([*:0]const u8, &name_buf)));
}
