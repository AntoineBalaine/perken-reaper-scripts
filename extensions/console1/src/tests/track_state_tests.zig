const std = @import("std");
const TestRunner = @import("../test_runner.zig");
const reaper = @import("../reaper.zig").reaper;
const TrackState = @import("../track_state.zig").TrackState;
const RprCmds = @import("../reaper_cmds.zig");
const log = std.log.scoped(.track_tests);

pub fn runTrackStateTests() !void {
    var test_runner = TestRunner.init(std.heap.page_allocator);
    defer test_runner.deinit();

    const test_cases = [_]TestRunner.TestCase{
        .{
            .name = "validate empty track",
            .setup = setupEmptyTrack,
            .run = testEmptyTrack,
        },
        // ... more test cases
    };

    for (test_cases) |test_case| {
        try test_runner.runTest(test_case);
        reaper.Main_OnCommand(RprCmds.IDC_EDIT_UNDO, 0);
    }

    test_runner.reportResults();
}

// Setup/teardown functions
pub fn setupEmptyTrack() !void {
    _ = reaper.InsertTrackAtIndex(0, false);
}

pub fn setupFxChain() !void {
    _ = reaper.InsertTrackAtIndex(0, true);
    const track = reaper.GetTrack(null, 0) orelse
        return error.TrackNotFound;

    // Add test FX chain
    _ = reaper.TrackFX_AddByName(track, "ReaComp", false, -1);
    // ... setup other FX
}

// Test cases
pub fn testEmptyTrack() !void {
    const track = reaper.GetTrack(0, 0);

    var track_state: TrackState = undefined;
    track_state.validateTrack(track);

    try std.testing.expectEqual(
        track_state.fx_count,
        @as(usize, 0),
    );
}
