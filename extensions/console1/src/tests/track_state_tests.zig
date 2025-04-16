const std = @import("std");
const models = @import("../models/models.zig");
const extension = @import("../console1_extension.zig");
const TestRunner = @import("../test_runner.zig");
const reaper = @import("../reaper.zig").reaper;
const pReaper = @import("../pReaper.zig");
const TrackState = @import("../track_state.zig");
const RprCmds = @import("../reaper_cmds.zig");
const DefaultFx = @import("../settings.zig").DefaultFx;
const utils = @import("../utils.zig");

const log = std.log.scoped(.track_tests);

pub fn runTrackStateTests() !void {
    var test_runner = TestRunner.init(std.heap.page_allocator);
    defer test_runner.deinit();

    const test_cases = [_]TestRunner.TestCase{
        .{ .name = "fx chain validation", .setup = setupEmptyTrack, .run = testFxChainValidation },
        .{ .name = "remove suffix", .setup = setupEmptyTrack, .run = testRemoveSuffix },
        .{ .name = "analyze coverage - no duplicates", .setup = setupEmptyTrack, .run = testAnalyzeCoverageNoDuplicates },
        .{ .name = "analyze coverage - removes duplicates fx suffix", .setup = setupEmptyTrack, .run = testAnalyzeCoverageDuplicates },
        .{ .name = "insert missing modules", .setup = setupEmptyTrack, .run = testAddMissingModules },
        .{ .name = "default fx chain order", .setup = setupEmptyTrack, .run = testDefaultFxChainOrder },
    };

    for (test_cases) |test_case| {
        try test_runner.runTest(test_case);
        pReaper.Main_OnCommand(.{ RprCmds.IDC_EDIT_UNDO, 0 });
    }

    test_runner.reportResults();
}

// Setup/teardown functions
pub fn setupEmptyTrack() !void {
    _ = pReaper.InsertTrackAtIndex(.{ 0, false });
}

pub fn testDefaultFxChainOrder() !void {
    const track = reaper.GetTrack(0, 0);

    var track_state: TrackState = undefined;
    const globals = extension.getGlobals();
    const coverage = track_state.validateTrack(track, globals.preferences.default_fx, &globals.map_store);

    // Verify all modules were added and positioned correctly
    try std.testing.expectEqual(@as(i32, 0), coverage.INPUT.?.index);
    try std.testing.expectEqual(@as(i32, 1), coverage.GATE.?.index);
    try std.testing.expectEqual(@as(i32, 2), coverage.EQ.?.index);
    try std.testing.expectEqual(@as(i32, 3), coverage.COMP.?.index);
    try std.testing.expectEqual(@as(i32, 4), coverage.OUTPT.?.index);

    // Verify total FX count
    const fx_count = pReaper.TrackFX_GetCount(.{track});
    try std.testing.expectEqual(@as(c_int, 5), fx_count);
}

pub fn testFxChainValidation() !void {
    const track = pReaper.GetTrack(.{ 0, 0 });

    // Setup FX chain without triggering notifications
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaEQ (Cockos)", false, -1 });

    // Manually rename FX for testing
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (C1-C)" });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 1, "renamed_name", "VST: ReaEQ (C1-E)" });

    // Now we can test the validation logic directly
    var track_state: TrackState = undefined;

    const globals = extension.getGlobals();

    _ = track_state.validateTrack(track, globals.preferences.default_fx, &globals.map_store);

    // Verify results
    try std.testing.expectEqual(track_state.fx_count, 5); // assuming default config
    try std.testing.expect(track_state.module_locations.get(.COMP) != null);
    try std.testing.expect(track_state.module_locations.get(.EQ) != null);
}

pub fn testRemoveSuffix() !void {
    const track = pReaper.GetTrack(.{ 0, 0 });

    // Setup
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });

    // Set initial state
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-C)" });

    // Execute test
    TrackState.removeDuplicateModule(0, track);

    // Verify result
    var buf: [512:0]u8 = undefined;
    _ = pReaper.TrackFX_GetNamedConfigParm(.{ track, 0, "renamed_name", &buf, buf.len });
    try std.testing.expectEqualStrings("VST: ReaComp (Cockos)", std.mem.span(@as([*:0]const u8, &buf)));
}

pub fn testAnalyzeCoverageNoDuplicates() !void {
    const track = pReaper.GetTrack(.{ 0, 0 });

    // Add FX without triggering notifications
    // First FX with INPUT module
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-I)" });

    // Second FX with GATE module
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaGate (Cockos)", false, -1 });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 1, "renamed_name", "VST: ReaGate (Cockos) (C1-S)" });

    // Create parsed FX buffer
    var parsed_fx_buf: [TrackState.MAX_PARSED_FX]TrackState.ParsedFx = undefined;
    var parsed_fx = std.ArrayListUnmanaged(TrackState.ParsedFx).initBuffer(&parsed_fx_buf);

    // Add parsed FX info
    parsed_fx.appendSliceAssumeCapacity(&[_]TrackState.ParsedFx{
        .{ .index = 0, .active_modules = .INPUT, .guid = utils.Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 0)) },
        .{ .index = 1, .active_modules = .GATE, .guid = utils.Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 0)) },
    });

    // Test coverage analysis
    const coverage = TrackState.analyzeCoverage(&parsed_fx, track);
    try std.testing.expect(coverage.INPUT.?.index == 0);
    try std.testing.expect(coverage.GATE.?.index == 1);
}

// Test case 2: Duplicate module handling
pub fn testAnalyzeCoverageDuplicates() !void {
    const track = pReaper.GetTrack(.{ 0, 0 });

    // Add two FX with same module (INPUT)
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-I)" });

    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 1, "renamed_name", "VST: ReaComp (Cockos) (C1-I)" });

    // Create parsed FX buffer
    var parsed_fx_buf: [TrackState.MAX_PARSED_FX]TrackState.ParsedFx = undefined;
    var parsed_fx = std.ArrayListUnmanaged(TrackState.ParsedFx).initBuffer(&parsed_fx_buf);

    // Add parsed FX info with duplicate INPUT modules
    parsed_fx.appendSliceAssumeCapacity(&[_]TrackState.ParsedFx{
        .{ .index = 0, .guid = utils.Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 0)), .active_modules = .INPUT },
        .{ .index = 1, .guid = utils.Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 1)), .active_modules = .INPUT },
    });

    // Test coverage analysis
    const coverage = TrackState.analyzeCoverage(&parsed_fx, track);
    try std.testing.expectEqual(@as(c_int, 0), coverage.INPUT.?.index);

    // Verify the duplicate had its suffix removed
    var buf: [512:0]u8 = undefined;
    _ = pReaper.TrackFX_GetNamedConfigParm(.{ track, 1, "renamed_name", &buf, buf.len });
    try std.testing.expectEqualStrings("VST: ReaComp (Cockos)", std.mem.span(@as([*:0]const u8, &buf)));

    // Both FX should still exist
    const fx_count = pReaper.TrackFX_GetCount(.{track});
    try std.testing.expectEqual(@as(c_int, 2), fx_count);
}

pub fn testAddMissingModules() !void {
    const track = reaper.GetTrack(0, 0);

    // Setup initial chain with only INPUT and OUTPUT
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_AddByName(.{ track, "JS: Volume Adjustment", false, -1 });

    // Set their names
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-I)" });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 1, "renamed_name", "JS: Volume Adjustment (C1-O)" });

    var coverage = TrackState.ModuleCoverage{
        .INPUT = .{ .index = 0, .guid = utils.Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 0)) },
        .OUTPT = .{ .index = 1, .guid = utils.Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 1)) },
    };

    const default_fx = DefaultFx.init(.{
        .INPUT = "VST: ReaComp (Cockos)",
        .GATE = "VST: ReaGate (Cockos)",
        .EQ = "VST: ReaEQ (Cockos)",
        .COMP = "VST: ReaComp (Cockos)",
        .OUTPT = "JS: Volume Adjustment",
    });

    coverage = TrackState.reorderFx2(coverage, track, default_fx);

    // Original FX should stay in place, missing modules added between
    var buf: [512:0]u8 = undefined;

    // Check original INPUT still at position 0
    _ = pReaper.TrackFX_GetNamedConfigParm(.{ track, 0, "renamed_name", &buf, buf.len });
    try std.testing.expectEqualStrings("VST: ReaComp (Cockos) (C1-I)", std.mem.span(@as([*:0]const u8, &buf)));

    // Check GATE was added at position 1
    _ = pReaper.TrackFX_GetNamedConfigParm(.{ track, 1, "renamed_name", &buf, buf.len });
    try std.testing.expectEqualStrings("VST: ReaGate (Cockos) (C1-S)", std.mem.span(@as([*:0]const u8, &buf)));

    // Check EQ was added at position 2
    _ = pReaper.TrackFX_GetNamedConfigParm(.{ track, 2, "renamed_name", &buf, buf.len });
    try std.testing.expectEqualStrings("VST: ReaEQ (Cockos) (C1-E)", std.mem.span(@as([*:0]const u8, &buf)));

    // Check COMP was added at position 3
    _ = pReaper.TrackFX_GetNamedConfigParm(.{ track, 3, "renamed_name", &buf, buf.len });
    try std.testing.expectEqualStrings("VST: ReaComp (Cockos) (C1-C)", std.mem.span(@as([*:0]const u8, &buf)));

    // Check original OUTPUT still at the end
    _ = pReaper.TrackFX_GetNamedConfigParm(.{ track, 4, "renamed_name", &buf, buf.len });
    try std.testing.expectEqualStrings("JS: Volume Adjustment (C1-O)", std.mem.span(@as([*:0]const u8, &buf)));

    // Verify coverage was updated correctly
    try std.testing.expectEqual(@as(i32, 0), coverage.INPUT.?.index);
    try std.testing.expectEqual(@as(i32, 1), coverage.GATE.?.index);
    try std.testing.expectEqual(@as(i32, 2), coverage.EQ.?.index);
    try std.testing.expectEqual(@as(i32, 3), coverage.COMP.?.index);
    try std.testing.expectEqual(@as(i32, 4), coverage.OUTPT.?.index);
}
