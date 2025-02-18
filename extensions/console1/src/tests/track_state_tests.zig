const std = @import("std");
const TestRunner = @import("../test_runner.zig");
const reaper = @import("../reaper.zig").reaper;
const pReaper = @import("../pReaper.zig");
const TrackState = @import("../track_state.zig");
const RprCmds = @import("../reaper_cmds.zig");
const DefaultFx = @import("../settings.zig").DefaultFx;
const log = std.log.scoped(.track_tests);

pub fn runTrackStateTests() !void {
    var test_runner = TestRunner.init(std.heap.page_allocator);
    defer test_runner.deinit();

    const test_cases = [_]TestRunner.TestCase{
        .{ .name = "validate empty track", .setup = setupEmptyTrack, .run = testEmptyTrack },
        .{ .name = "fx chain validation", .setup = setupEmptyTrack, .run = testFxChainValidation },
        .{ .name = "remove duplicate module: input from multi-module", .setup = setupEmptyTrack, .run = testRemoveInputFromMultiModule },
        .{ .name = "remove duplicate module: middle module", .setup = setupEmptyTrack, .run = testRemoveMiddleModule },
        .{ .name = "remove duplicate module: module with extra text", .setup = setupEmptyTrack, .run = testRemoveModuleWithExtraText },
        .{ .name = "remove duplicate module: single module", .setup = setupEmptyTrack, .run = testRemoveSingleModule },
        .{ .name = "analyze coverage - no duplicates", .setup = setupEmptyTrack, .run = testAnalyzeCoverageNoDuplicates },
        .{ .name = "analyze coverage - with duplicates", .setup = setupEmptyTrack, .run = testAnalyzeCoverageDuplicates },
        .{ .name = "reorder - empty coverage", .setup = setupEmptyTrack, .run = testReorderEmptyCoverage },
        .{ .name = "reorder - incorrect order", .setup = setupEmptyTrack, .run = testReorderIncorrectOrder },
        .{ .name = "reorder - partial correct order", .setup = setupEmptyTrack, .run = testReorderPartialCorrectOrder },
        .{ .name = "reorder - missing middle modules", .setup = setupEmptyTrack, .run = testReorderMissingMiddleModules },
        .{ .name = "reorder - consolidation", .setup = setupEmptyTrack, .run = testReorderWithConsolidation },
        .{ .name = "reorder - partial chain incorrect order", .setup = setupEmptyTrack, .run = testPartialChainIncorrectOrder },
        .{ .name = "reorder - single fx multiple modules", .setup = setupEmptyTrack, .run = testSingleFxMultipleModules },
        .{ .name = "reorder - adjacent modules same fx", .setup = setupEmptyTrack, .run = testAdjacentModulesSameFx },
        .{ .name = "insert - no existing fx", .setup = setupEmptyTrack, .run = testInsertWithNoExistingFx },
        .{ .name = "insert - consolidate with previous", .setup = setupEmptyTrack, .run = testInsertForConsolidationWithPrevious },
        .{ .name = "insert - consolidate between", .setup = setupEmptyTrack, .run = testInsertBetweenForConsolidation },
        .{ .name = "insert - without consolidation", .setup = setupEmptyTrack, .run = testInsertWithoutConsolidation },
        .{ .name = "consolidate - two consecutive fx", .setup = setupEmptyTrack, .run = testFxConsolidation },
        .{ .name = "consolidate - comp with eq", .setup = setupEmptyTrack, .run = testConsolidateCompWithEq },
        .{ .name = "consolidate - input with eq", .setup = setupEmptyTrack, .run = testConsolidateInputWithEq },
        .{ .name = "consolidate - output with eq", .setup = setupEmptyTrack, .run = testConsolidateOutputWithEq },
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

// Test cases
pub fn testEmptyTrack() !void {
    const track = pReaper.GetTrack(.{ 0, 0 });

    var track_state: TrackState = undefined;
    track_state.validateTrack(track);

    try std.testing.expectEqual(
        track_state.fx_count,
        @as(usize, 0),
    );
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
    track_state.validateTrack(track);

    // Verify results
    try std.testing.expectEqual(track_state.fx_count, 2);
    try std.testing.expect(track_state.module_locations.get(.COMP) != null);
    try std.testing.expect(track_state.module_locations.get(.EQ) != null);
}

pub fn testFxConsolidation() !void {
    const track = pReaper.GetTrack(.{ 0, 0 });

    // Add FX without triggering notifications
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });

    // Set up test scenario manually
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-S)" });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 1, "renamed_name", "VST: ReaComp (Cockos) (C1-C)" });

    // Test validation logic
    var track_state: TrackState = undefined;
    track_state.validateTrack(track);

    // Verify consolidation happened
    try std.testing.expectEqual(track_state.fx_count, @as(usize, 1));

    var buf: [512:0]u8 = undefined;
    _ = pReaper.TrackFX_GetNamedConfigParm(.{ track, 0, "renamed_name", &buf, buf.len });
    try std.testing.expectEqualStrings("VST: ReaComp (Cockos) (C1-SC)", std.mem.span(@as([*:0]const u8, &buf)));
}

// Test 1: Remove INPUT module from a multi-module suffix
pub fn testRemoveInputFromMultiModule() !void {
    const track = pReaper.GetTrack(.{ 0, 0 });

    // Setup
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });

    // Set initial state
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-IC)" });

    // Execute test
    TrackState.removeDuplicateModule(0, .INPUT, track, true);

    // Verify result
    var buf: [512:0]u8 = undefined;
    _ = pReaper.TrackFX_GetNamedConfigParm(.{ track, 0, "renamed_name", &buf, buf.len });
    try std.testing.expectEqualStrings("VST: ReaComp (Cockos) (C1-C)", std.mem.span(@as([*:0]const u8, &buf)));
}

// Test 2: Remove middle module
pub fn testRemoveMiddleModule() !void {
    const track = pReaper.GetTrack(.{ 0, 0 });

    // Setup
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaEQ (Cockos)", false, -1 });

    // Set initial state
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaEQ (Cockos) (C1-SEC)" });

    // Execute test
    TrackState.removeDuplicateModule(0, .EQ, track, true);

    // Verify result
    var buf: [512:0]u8 = undefined;
    _ = pReaper.TrackFX_GetNamedConfigParm(.{ track, 0, "renamed_name", &buf, buf.len });
    try std.testing.expectEqualStrings("VST: ReaEQ (Cockos) (C1-SC)", std.mem.span(@as([*:0]const u8, &buf)));
}

// Test 3: FX name with text after suffix
pub fn testRemoveModuleWithExtraText() !void {
    const track = pReaper.GetTrack(.{ 0, 0 });

    // Setup
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });

    // Set initial state
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-IC) my settings" });

    // Execute test
    TrackState.removeDuplicateModule(0, .INPUT, track, true);

    // Verify result
    var buf: [512:0]u8 = undefined;
    _ = pReaper.TrackFX_GetNamedConfigParm(.{ track, 0, "renamed_name", &buf, buf.len });
    try std.testing.expectEqualStrings("VST: ReaComp (Cockos) (C1-C) my settings", std.mem.span(@as([*:0]const u8, &buf)));
}

// Test 4: Single module suffix
pub fn testRemoveSingleModule() !void {
    const track = pReaper.GetTrack(.{ 0, 0 });

    // Setup
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });

    // Set initial state
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-C)" });

    // Execute test
    TrackState.removeDuplicateModule(0, .COMP, track, false);

    // Verify result
    var buf: [512:0]u8 = undefined;
    _ = pReaper.TrackFX_GetNamedConfigParm(.{ track, 0, "renamed_name", &buf, buf.len });
    try std.testing.expectEqualStrings("VST: ReaComp (Cockos) ", std.mem.span(@as([*:0]const u8, &buf)));
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
        .{ .index = 0, .active_modules = .{ .INPUT = true, .GATE = false, .EQ = false, .COMP = false, .OUTPT = false } },
        .{ .index = 1, .active_modules = .{ .INPUT = false, .GATE = true, .EQ = false, .COMP = false, .OUTPT = false } },
    });

    // Test coverage analysis
    const coverage = TrackState.analyzeCoverage(&parsed_fx, track);
    try std.testing.expect(coverage.INPUT == 0);
    try std.testing.expect(coverage.GATE == 1);
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
        .{ .index = 0, .active_modules = .{ .INPUT = true, .GATE = false, .EQ = false, .COMP = false, .OUTPT = false } },
        .{ .index = 1, .active_modules = .{ .INPUT = true, .GATE = false, .EQ = false, .COMP = false, .OUTPT = false } },
    });

    // Test coverage analysis
    const coverage = TrackState.analyzeCoverage(&parsed_fx, track);
    try std.testing.expectEqual(@as(c_int, 0), coverage.INPUT);

    // Verify the duplicate was removed (check FX chain length)
    var buf: [512:0]u8 = undefined;
    _ = pReaper.TrackFX_GetNamedConfigParm(.{ track, 0, "renamed_name", &buf, buf.len });

    // The second FX should have been removed
    const fx_count = pReaper.TrackFX_GetCount(.{track});
    try std.testing.expectEqual(@as(c_int, 2), fx_count);
}

// Test 1: Empty coverage - adds all modules in correct order
pub fn testReorderEmptyCoverage() !void {
    const track = reaper.GetTrack(0, 0);
    var coverage = TrackState.ModuleCoverage{};

    const default_fx = DefaultFx.init(.{
        .INPUT = "VST: ReaComp (Cockos)",
        .GATE = "VST: ReaGate (Cockos)",
        .EQ = "VST: ReaEQ (Cockos)",
        .COMP = "VST: ReaComp (Cockos)",
        .OUTPT = "JS: Volume Adjustment",
    });

    coverage = TrackState.reorderFx2(coverage, track, default_fx);

    // Verify all modules were added
    try std.testing.expect(coverage.INPUT != null);
    try std.testing.expect(coverage.GATE != null);
    try std.testing.expect(coverage.EQ != null);
    try std.testing.expect(coverage.COMP != null);
    try std.testing.expect(coverage.OUTPT != null);

    // Verify final chain state
    try verifyFxChain(track, &[_][]const u8{
        "VST: ReaComp (Cockos) (C1-I)",
        "VST: ReaGate (Cockos) (C1-S)",
        "VST: ReaEQ (Cockos) (C1-E)",
        "VST: ReaComp (Cockos) (C1-C)",
        "JS: Volume Adjustment (C1-O)",
    });
}

// Test 2: Incorrect order needing fixes
pub fn testReorderIncorrectOrder() !void {
    const track = pReaper.GetTrack(.{ 0, 0 });

    // Setup initial incorrect order
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_AddByName(.{ track, "JS: Volume Adjustment", false, -1 });
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaGate (Cockos)", false, -1 });
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaEQ (Cockos)", false, -1 });

    // Set initial names
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-C)" });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 1, "renamed_name", "JS: Volume Adjustment (C1-O)" });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 2, "renamed_name", "VST: ReaComp (Cockos) (C1-I)" });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 3, "renamed_name", "VST: ReaGate (Cockos) (C1-S)" });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 4, "renamed_name", "VST: ReaEQ (Cockos) (C1-E)" });

    var coverage = TrackState.ModuleCoverage{
        .INPUT = 2,
        .GATE = 3,
        .EQ = 4,
        .COMP = 0,
        .OUTPT = 1,
    };

    const default_fx = DefaultFx.init(.{
        .INPUT = "VST: ReaComp (Cockos)",
        .GATE = "VST: ReaGate (Cockos)",
        .EQ = "VST: ReaEQ (Cockos)",
        .COMP = "VST: ReaComp (Cockos)",
        .OUTPT = "JS: Volume Adjustment",
    });

    coverage = TrackState.reorderFx2(coverage, track, default_fx);

    // Verify final order
    try verifyFxChain(track, &[_][]const u8{
        "VST: ReaComp (Cockos) (C1-I)",
        "VST: ReaGate (Cockos) (C1-S)",
        "VST: ReaEQ (Cockos) (C1-E)",
        "VST: ReaComp (Cockos) (C1-C)",
        "JS: Volume Adjustment (C1-O)",
    });

    // Verify coverage was updated correctly
    try std.testing.expectEqual(@as(i32, 0), coverage.INPUT.?);
    try std.testing.expectEqual(@as(i32, 1), coverage.GATE.?);
    try std.testing.expectEqual(@as(i32, 2), coverage.EQ.?);
    try std.testing.expectEqual(@as(i32, 3), coverage.COMP.?);
    try std.testing.expectEqual(@as(i32, 4), coverage.OUTPT.?);
}

// Helper function to verify FX chain state
fn verifyFxChain(track: reaper.MediaTrack, expected_names: []const []const u8) !void {
    const fx_count = reaper.TrackFX_GetCount(track);
    try std.testing.expectEqual(expected_names.len, @as(usize, @intCast(fx_count)));

    var buf: [512:0]u8 = undefined;
    for (expected_names, 0..) |expected, i| {
        _ = pReaper.TrackFX_GetNamedConfigParm(.{ track, @as(c_int, @intCast(i)), "renamed_name", &buf, buf.len });
        try std.testing.expectEqualStrings(expected, std.mem.span(@as([*:0]const u8, &buf)));
    }
}

// Test 3: Correct order with some modules (missing modules should be added)
pub fn testReorderPartialCorrectOrder() !void {
    const track = reaper.GetTrack(0, 0);

    // Setup initial chain with INPUT, EQ, OUTPUT in correct order
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaEQ (Cockos)", false, -1 });
    _ = pReaper.TrackFX_AddByName(.{ track, "JS: Volume Adjustment", false, -1 });

    // Set their names
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-I)" });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 1, "renamed_name", "VST: ReaEQ (Cockos) (C1-E)" });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 2, "renamed_name", "JS: Volume Adjustment (C1-O)" });

    var coverage = TrackState.ModuleCoverage{
        .INPUT = 0,
        .EQ = 1,
        .OUTPT = 2,
    };

    const default_fx = DefaultFx.init(.{
        .INPUT = "VST: ReaComp (Cockos)",
        .GATE = "VST: ReaGate (Cockos)",
        .EQ = "VST: ReaEQ (Cockos)",
        .COMP = "VST: ReaComp (Cockos)",
        .OUTPT = "JS: Volume Adjustment",
    });

    coverage = TrackState.reorderFx2(coverage, track, default_fx);

    // Should add missing GATE and COMP in correct positions
    try verifyFxChain(track, &[_][]const u8{
        "VST: ReaComp (Cockos) (C1-I)",
        "VST: ReaGate (Cockos) (C1-S)",
        "VST: ReaEQ (Cockos) (C1-E)",
        "VST: ReaComp (Cockos) (C1-C)",
        "JS: Volume Adjustment (C1-O)",
    });
}

// Test 4: Missing middle modules (should add all missing modules)
pub fn testReorderMissingMiddleModules() !void {
    const track = reaper.GetTrack(0, 0);

    // Setup initial chain with only INPUT and OUTPUT
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_AddByName(.{ track, "JS: Volume Adjustment", false, -1 });

    // Set their names
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-I)" });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 1, "renamed_name", "JS: Volume Adjustment (C1-O)" });

    var coverage = TrackState.ModuleCoverage{
        .INPUT = 0,
        .OUTPT = 1,
    };

    const default_fx = DefaultFx.init(.{
        .INPUT = "VST: ReaComp (Cockos)",
        .GATE = "VST: ReaGate (Cockos)",
        .EQ = "VST: ReaEQ (Cockos)",
        .COMP = "VST: ReaComp (Cockos)",
        .OUTPT = "JS: Volume Adjustment",
    });

    coverage = TrackState.reorderFx2(coverage, track, default_fx);

    // Should add all missing modules in correct order
    try verifyFxChain(track, &[_][]const u8{
        "VST: ReaComp (Cockos) (C1-I)",
        "VST: ReaGate (Cockos) (C1-S)",
        "VST: ReaEQ (Cockos) (C1-E)",
        "VST: ReaComp (Cockos) (C1-C)",
        "JS: Volume Adjustment (C1-O)",
    });

    // Verify coverage was updated correctly
    try std.testing.expectEqual(@as(i32, 0), coverage.INPUT.?);
    try std.testing.expectEqual(@as(i32, 1), coverage.GATE.?);
    try std.testing.expectEqual(@as(i32, 2), coverage.EQ.?);
    try std.testing.expectEqual(@as(i32, 3), coverage.COMP.?);
    try std.testing.expectEqual(@as(i32, 4), coverage.OUTPT.?);
}

// Test 5: Consolidation during reordering
pub fn testReorderWithConsolidation() !void {
    const track = reaper.GetTrack(0, 0);

    // Setup initial chain with COMP and INPUT using same plugin
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });

    // Set their names
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-C)" });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 1, "renamed_name", "VST: ReaComp (Cockos) (C1-I)" });

    var coverage = TrackState.ModuleCoverage{
        .INPUT = 1,
        .COMP = 0,
    };

    // Use same FX for multiple modules
    const default_fx = DefaultFx.init(.{
        .INPUT = "VST: ReaComp (Cockos)",
        .GATE = "VST: ReaComp (Cockos)",
        .EQ = "VST: ReaComp (Cockos)",
        .COMP = "VST: ReaComp (Cockos)",
        .OUTPT = "JS: Volume Adjustment", // Different for OUTPUT
    });

    coverage = TrackState.reorderFx2(coverage, track, default_fx);

    // Should consolidate INPUT, GATE, EQ, COMP into one FX
    try verifyFxChain(track, &[_][]const u8{
        "VST: ReaComp (Cockos) (C1-ISEC)",
        "JS: Volume Adjustment (C1-O)",
    });
}

// Test 6: Partial chain with incorrect order
pub fn testPartialChainIncorrectOrder() !void {
    const track = reaper.GetTrack(0, 0);

    // Setup initial incorrect order: COMP before GATE
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaGate (Cockos)", false, -1 });

    // Set their names
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-C)" });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 1, "renamed_name", "VST: ReaGate (Cockos) (C1-S)" });

    var coverage = TrackState.ModuleCoverage{
        .GATE = 1,
        .COMP = 0,
    };

    const default_fx = DefaultFx.init(.{
        .INPUT = "VST: ReaComp (Cockos)",
        .GATE = "VST: ReaGate (Cockos)",
        .EQ = "VST: ReaEQ (Cockos)",
        .COMP = "VST: ReaComp (Cockos)",
        .OUTPT = "JS: Volume Adjustment",
    });

    coverage = TrackState.reorderFx2(coverage, track, default_fx);

    // Verify final order and missing modules
    try verifyFxChain(track, &[_][]const u8{
        "VST: ReaComp (Cockos) (C1-I)",
        "VST: ReaGate (Cockos) (C1-S)",
        "VST: ReaEQ (Cockos) (C1-E)",
        "VST: ReaComp (Cockos) (C1-C)",
        "JS: Volume Adjustment (C1-O)",
    });

    // Verify coverage was updated correctly
    try std.testing.expectEqual(@as(i32, 0), coverage.INPUT.?);
    try std.testing.expectEqual(@as(i32, 1), coverage.GATE.?);
    try std.testing.expectEqual(@as(i32, 2), coverage.EQ.?);
    try std.testing.expectEqual(@as(i32, 3), coverage.COMP.?);
    try std.testing.expectEqual(@as(i32, 4), coverage.OUTPT.?);
}

// Test 7: Edge case with single FX handling multiple modules
pub fn testSingleFxMultipleModules() !void {
    const track = reaper.GetTrack(0, 0);

    // Setup initial state: one FX handling both INPUT and EQ
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });

    // Set initial name with multiple modules
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-IE)" });

    var coverage = TrackState.ModuleCoverage{
        .INPUT = 0,
        .EQ = 0,
    };

    const default_fx = DefaultFx.init(.{
        .INPUT = "VST: ReaComp (Cockos)",
        .GATE = "VST: ReaGate (Cockos)",
        .EQ = "VST: ReaEQ (Cockos)",
        .COMP = "VST: ReaComp (Cockos)",
        .OUTPT = "JS: Volume Adjustment",
    });

    coverage = TrackState.reorderFx2(coverage, track, default_fx);

    // Should split and add missing modules
    try verifyFxChain(track, &[_][]const u8{
        "VST: ReaComp (Cockos) (C1-I)",
        "VST: ReaGate (Cockos) (C1-S)",
        "VST: ReaEQ (Cockos) (C1-E)",
        "VST: ReaComp (Cockos) (C1-C)",
        "JS: Volume Adjustment (C1-O)",
    });

    // Verify coverage
    try std.testing.expectEqual(@as(i32, 0), coverage.INPUT.?);
    try std.testing.expectEqual(@as(i32, 1), coverage.GATE.?);
    try std.testing.expectEqual(@as(i32, 2), coverage.EQ.?);
    try std.testing.expectEqual(@as(i32, 3), coverage.COMP.?);
    try std.testing.expectEqual(@as(i32, 4), coverage.OUTPT.?);
}

// Test 8: Adjacent modules using same default FX
pub fn testAdjacentModulesSameFx() !void {
    const track = reaper.GetTrack(0, 0);

    // Start with INPUT and EQ
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaEQ (Cockos)", false, -1 });

    // Set their names
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-I)" });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 1, "renamed_name", "VST: ReaEQ (Cockos) (C1-E)" });

    var coverage = TrackState.ModuleCoverage{
        .INPUT = 0,
        .EQ = 1,
    };

    // Use same FX for GATE and COMP
    const default_fx = DefaultFx.init(.{
        .INPUT = "VST: ReaComp (Cockos)",
        .GATE = "VST: ReaComp (Cockos)", // Same FX
        .EQ = "VST: ReaEQ (Cockos)",
        .COMP = "VST: ReaComp (Cockos)", // Same FX
        .OUTPT = "JS: Volume Adjustment",
    });

    coverage = TrackState.reorderFx2(coverage, track, default_fx);

    // Should add GATE and COMP as consolidated FX
    try verifyFxChain(track, &[_][]const u8{
        "VST: ReaComp (Cockos) (C1-I)",
        "VST: ReaComp (Cockos) (C1-SC)", // Consolidated GATE+COMP
        "VST: ReaEQ (Cockos) (C1-E)",
        "JS: Volume Adjustment (C1-O)",
    });

    // Verify coverage reflects consolidated positions
    try std.testing.expectEqual(@as(i32, 0), coverage.INPUT.?);
    try std.testing.expectEqual(@as(i32, 1), coverage.GATE.?);
    try std.testing.expectEqual(@as(i32, 1), coverage.COMP.?); // Same position as GATE
    try std.testing.expectEqual(@as(i32, 2), coverage.EQ.?);
    try std.testing.expectEqual(@as(i32, 3), coverage.OUTPT.?);
}

// Test handleInsertWithConsolidation
pub fn testInsertWithNoExistingFx() !void {
    const track = reaper.GetTrack(0, 0);

    const default_fx = DefaultFx.init(.{
        .INPUT = "VST: ReaComp (Cockos)",
        .GATE = "VST: ReaComp (Cockos)",
        .EQ = "VST: ReaComp (Cockos)",
        .COMP = "VST: ReaGate (Cockos)", // Different FX
        .OUTPT = "VST: ReaComp (Cockos)",
    });

    const result = TrackState.handleInsertWithConsolidation(track, .EQ, 0, default_fx, .{});

    try std.testing.expectEqual(false, result.did_consolidate);
    try std.testing.expectEqual(@as(i32, 0), result.position.?);

    // Verify FX was added
    try verifyFxChain(track, &[_][]const u8{
        "VST: ReaComp (Cockos) (C1-E)",
    });
}

pub fn testInsertForConsolidationWithPrevious() !void {
    const track = reaper.GetTrack(0, 0);

    // Add initial FX
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-E)" });

    const default_fx = DefaultFx.init(.{
        .INPUT = "VST: ReaComp (Cockos)",
        .GATE = "VST: ReaComp (Cockos)",
        .EQ = "VST: ReaComp (Cockos)",
        .COMP = "VST: ReaGate (Cockos)", // Different FX
        .OUTPT = "VST: ReaComp (Cockos)",
    });

    const result = TrackState.handleInsertWithConsolidation(track, .GATE, 1, default_fx, .{ .EQ = 0 });

    try std.testing.expectEqual(true, result.did_consolidate);
    try std.testing.expectEqual(@as(i32, 0), result.position.?);

    // Verify consolidation happened
    try verifyFxChain(track, &[_][]const u8{
        "VST: ReaComp (Cockos) (C1-SE)",
    });
}

pub fn testInsertBetweenForConsolidation() !void {
    const track = reaper.GetTrack(0, 0);

    // Add initial FX chain
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-E)" });

    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 1, "renamed_name", "VST: ReaComp (Cockos) (C1-O)" });

    const default_fx = DefaultFx.init(.{
        .INPUT = "VST: ReaComp (Cockos)",
        .GATE = "VST: ReaComp (Cockos)",
        .EQ = "VST: ReaComp (Cockos)",
        .COMP = "VST: ReaGate (Cockos)", // Different FX
        .OUTPT = "VST: ReaComp (Cockos)",
    });

    const result = TrackState.handleInsertWithConsolidation(track, .GATE, 1, default_fx, .{
        .EQ = 0,
        .OUTPT = 1,
    });

    try std.testing.expectEqual(true, result.did_consolidate);
    try std.testing.expectEqual(@as(i32, 0), result.position.?);

    // Verify consolidation of all three modules
    try verifyFxChain(track, &[_][]const u8{
        "VST: ReaComp (Cockos) (C1-SEO)",
    });
}

pub fn testInsertWithoutConsolidation() !void {
    const track = reaper.GetTrack(0, 0);

    // Add initial FX
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-E)" });

    const default_fx = DefaultFx.init(.{
        .INPUT = "VST: ReaComp (Cockos)",
        .GATE = "VST: ReaComp (Cockos)",
        .EQ = "VST: ReaComp (Cockos)",
        .COMP = "VST: ReaGate (Cockos)", // Different FX
        .OUTPT = "VST: ReaComp (Cockos)",
    });

    const result = TrackState.handleInsertWithConsolidation(track, .COMP, 1, default_fx, .{ .EQ = 0 });

    try std.testing.expectEqual(false, result.did_consolidate);
    try std.testing.expectEqual(@as(i32, 1), result.position.?);

    // Verify both FX remain separate
    try verifyFxChain(track, &[_][]const u8{
        "VST: ReaComp (Cockos) (C1-E)",
        "VST: ReaGate (Cockos) (C1-C)",
    });
}

pub fn testConsolidateCompWithEq() !void {
    const track = reaper.GetTrack(0, 0);

    // Add initial EQ
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-E)" });

    // Try to consolidate with COMP
    try std.testing.expect(TrackState.consolidateWithFxSuffix(track, 0, .COMP));

    // Verify consolidation
    var buf: [512:0]u8 = undefined;
    _ = pReaper.TrackFX_GetNamedConfigParm(.{ track, 0, "renamed_name", &buf, buf.len });
    try std.testing.expectEqualStrings("VST: ReaComp (Cockos) (C1-EC)", std.mem.span(@as([*:0]const u8, &buf)));
}

pub fn testConsolidateInputWithEq() !void {
    const track = pReaper.GetTrack(.{ 0, 0 });

    // Add initial EQ
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-E)" });

    // Try to consolidate with INPUT
    try std.testing.expect(TrackState.consolidateWithFxSuffix(track, 0, .INPUT));

    // Verify consolidation
    var buf: [512:0]u8 = undefined;
    _ = pReaper.TrackFX_GetNamedConfigParm(.{ track, 0, "renamed_name", &buf, buf.len });
    try std.testing.expectEqualStrings("VST: ReaComp (Cockos) (C1-IE)", std.mem.span(@as([*:0]const u8, &buf)));
}

pub fn testConsolidateOutputWithEq() !void {
    const track = reaper.GetTrack(0, 0);

    // Add initial EQ
    _ = pReaper.TrackFX_AddByName(.{ track, "VST: ReaComp (Cockos)", false, -1 });
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ track, 0, "renamed_name", "VST: ReaComp (Cockos) (C1-E)" });

    // Try to consolidate with OUTPUT
    try std.testing.expect(TrackState.consolidateWithFxSuffix(track, 0, .OUTPT));

    // Verify consolidation
    var buf: [512:0]u8 = undefined;
    _ = pReaper.TrackFX_GetNamedConfigParm(.{ track, 0, "renamed_name", &buf, buf.len });
    try std.testing.expectEqualStrings("VST: ReaComp (Cockos) (C1-EO)", std.mem.span(@as([*:0]const u8, &buf)));
}
