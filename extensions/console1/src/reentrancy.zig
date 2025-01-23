const std = @import("std");
const reaper = @import("reaper.zig").reaper;
const log = std.log.scoped(.reentrancy);

pub var current_test: ?*ApiTestResult = null;
pub const ReentrancyMessage = union(enum) {
    api_call: TestApiCall,
    notification: Notification,
};

pub const TestApiCall = enum {
    SetTrackSelected,
    // Track Info
    SetMediaTrackInfo_Value_Phase,
    SetMediaTrackInfo_Value_NChan,

    // FX Management
    TrackFX_AddByName,
    TrackFX_CopyToTrack,
    TrackFX_SetEnabled,
    TrackFX_SetNamedConfigParm_RenamedName,
    TrackFX_SetNamedConfigParm_BandType,
    TrackFX_SetParamNormalized,
    TrackFX_SetPinMappings,

    // CSurf Controls
    CSurf_OnArrow,
    CSurf_OnFwd,
    CSurf_OnFXChange,
    CSurf_OnPlayRateChange,
    CSurf_OnRecord,
    CSurf_OnRecvPanChange,
    CSurf_OnRecvVolumeChange,
    CSurf_OnRew,
    CSurf_OnRewFwd,
    CSurf_OnScroll,
    CSurf_OnSendPanChange,
    CSurf_OnSendVolumeChange,
    CSurf_OnStop,
    CSurf_OnTempoChange,
    CSurf_OnVolumeChangeEx,
    CSurf_OnWidthChange,
    CSurf_OnWidthChangeEx,
    CSurf_OnZoom,

    pub fn toString(self: TestApiCall) []const u8 {
        return switch (self) {
            .SetMediaTrackInfo_Value_Phase => "SetMediaTrackInfo_Value(B_PHASE)",
            .SetMediaTrackInfo_Value_NChan => "SetMediaTrackInfo_Value(I_NCHAN)",
            .TrackFX_AddByName => "TrackFX_AddByName",
            // ... etc
        };
    }
};
pub const NotificationType = enum {
    // Track notifications
    SetTrackListChange,
    SetSurfaceVolume,
    SetSurfacePan,
    SetSurfaceMute,
    SetSurfaceSelected,
    SetSurfaceSolo,
    SetSurfaceRecArm,

    // Playback notifications
    SetPlayState,
    SetRepeatState,

    // FX notifications
    Extended_SetFXParam,
    Extended_SetFXEnabled,
    Extended_SetFocusedFX,
    Extended_SetLastTouchedTrack,

    // Other notifications
    SetAutoMode,
    ResetCachedVolPanStates,
    OnTrackSelection,

    pub fn toString(self: NotificationType) []const u8 {
        return switch (self) {
            .SetTrackListChange => "SetTrackListChange",
            .SetSurfaceVolume => "SetSurfaceVolume",
            else => @tagName(self),
            // ... etc
        };
    }
};
pub const Notification = struct {
    type: NotificationType,
    track_id: ?i32,
    timestamp: i64,
    // Add other relevant fields for specific notifications
    // For example, for SetSurfaceVolume we might want to store the volume value
    data: union(enum) {
        none: void,
        volume: f64,
        pan: f64,
        fx_param: struct {
            fx_index: usize,
            param_index: usize,
            value: f64,
        },
        // ... other specific notification data
    } = .{ .none = {} },
};

pub const ApiTestResult = struct {
    api_call: TestApiCall,
    notifications: std.ArrayList(Notification),
    start_time: i64,
    end_time: i64,
};
pub const ApiTest = struct {
    results: std.ArrayList(ApiTestResult),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ApiTest {
        return .{
            .results = std.ArrayList(ApiTestResult).init(allocator),
            .allocator = allocator,
        };
    }

    fn tearDown(api_call: TestApiCall, test_track: reaper.MediaTrack, witness_track: reaper.MediaTrack) void {
        // Clear current_test to avoid capturing tear down notifications
        current_test = null;

        switch (api_call) {
            .SetTrackSelected => {
                _ = reaper.DeleteTrack(test_track);
                _ = reaper.DeleteTrack(witness_track);
            },
            .SetMediaTrackInfo_Value_Phase => {
                _ = reaper.SetMediaTrackInfo_Value(test_track, "B_PHASE", 0);
            },
            .SetMediaTrackInfo_Value_NChan => {
                _ = reaper.SetMediaTrackInfo_Value(test_track, "I_NCHAN", 2); // Reset to stereo
            },
            .TrackFX_AddByName => {
                const fx_idx = reaper.TrackFX_GetByName(test_track, "Console1", false);
                _ = reaper.TrackFX_Delete(test_track, fx_idx);
            },
            .TrackFX_CopyToTrack => {
                // Remove from both tracks
                const test_fx_idx = reaper.TrackFX_GetByName(test_track, "Console1", false);
                _ = reaper.TrackFX_Delete(test_track, test_fx_idx);

                const wit_fx_idx = reaper.TrackFX_GetByName(witness_track, "Console1", false);
                _ = reaper.TrackFX_Delete(witness_track, wit_fx_idx);
            },
            .TrackFX_SetEnabled => {
                const fx_idx = reaper.TrackFX_GetByName(test_track, "Console1", false);
                reaper.TrackFX_SetEnabled(test_track, fx_idx, true);
                _ = reaper.TrackFX_Delete(test_track, fx_idx);
            },
            .TrackFX_SetNamedConfigParm_RenamedName, .TrackFX_SetNamedConfigParm_BandType, .TrackFX_SetParamNormalized, .TrackFX_SetPinMappings => {
                const fx_idx = reaper.TrackFX_GetByName(test_track, "Console1", false);
                _ = reaper.TrackFX_Delete(test_track, fx_idx);
            },
            .CSurf_OnArrow => {}, // These are momentary actions, no teardown needed
            .CSurf_OnFwd => {},
            .CSurf_OnFXChange => {},
            .CSurf_OnPlayRateChange => reaper.CSurf_OnPlayRateChange(1.0), // Reset to normal rate
            .CSurf_OnRecord => {}, // Momentary
            .CSurf_OnRecvPanChange => _ = reaper.CSurf_OnRecvPanChange(test_track, 0, 0.0, false),
            .CSurf_OnRecvVolumeChange => _ = reaper.CSurf_OnRecvVolumeChange(test_track, 0, 1.0, false),
            .CSurf_OnRew => {},
            .CSurf_OnRewFwd => {},
            .CSurf_OnScroll => {},
            .CSurf_OnSendPanChange => _ = reaper.CSurf_OnSendPanChange(test_track, 0, 0.0, false),
            .CSurf_OnSendVolumeChange => _ = reaper.CSurf_OnSendVolumeChange(test_track, 0, 1.0, false),
            .CSurf_OnStop => {},
            .CSurf_OnTempoChange => reaper.CSurf_OnTempoChange(120.0), // Reset to default
            .CSurf_OnVolumeChangeEx => _ = reaper.CSurf_OnVolumeChangeEx(test_track, 1.0, false, false),
            .CSurf_OnWidthChange => _ = reaper.CSurf_OnWidthChange(test_track, 1.0, false),
            .CSurf_OnWidthChangeEx => _ = reaper.CSurf_OnWidthChangeEx(test_track, 1.0, false, false),
            .CSurf_OnZoom => {},
        }
    }

    pub fn runTest(self: *ApiTest, api_call: TestApiCall, test_track: reaper.MediaTrack, witness_track: reaper.MediaTrack) !void {
        var test_result = ApiTestResult{
            .api_call = api_call,
            .notifications = std.ArrayList(Notification).init(self.allocator),
            .start_time = std.time.milliTimestamp(),
            .end_time = undefined,
        };

        {
            current_test = &test_result;
            // clear current test before teardown
            defer current_test = null;

            // Log that we're starting this API call
            log.debug("{}", .{ReentrancyMessage{ .api_call = api_call }});

            switch (api_call) {
                .SetTrackSelected => reaper.SetTrackSelected(test_track, true),
                .SetMediaTrackInfo_Value_Phase => {
                    _ = reaper.SetMediaTrackInfo_Value(test_track, "B_PHASE", 1);
                },
                .SetMediaTrackInfo_Value_NChan => {
                    _ = reaper.SetMediaTrackInfo_Value(test_track, "I_NCHAN", 4);
                },
                .TrackFX_AddByName => {
                    _ = reaper.TrackFX_AddByName(test_track, "Console1", false, -1);
                },
                .TrackFX_CopyToTrack => {
                    const fx_idx = reaper.TrackFX_AddByName(test_track, "Console1", false, -1);
                    _ = reaper.TrackFX_CopyToTrack(test_track, fx_idx, witness_track, fx_idx, true);
                },
                .TrackFX_SetEnabled => {
                    const fx_idx = reaper.TrackFX_AddByName(test_track, "Console1", false, -1);
                    reaper.TrackFX_SetEnabled(test_track, fx_idx, false);
                },
                .TrackFX_SetNamedConfigParm_RenamedName => {
                    const fx_idx = reaper.TrackFX_AddByName(test_track, "Console1", false, -1);
                    _ = reaper.TrackFX_SetNamedConfigParm(test_track, fx_idx, "renamed_name", "Console1");
                },
                .TrackFX_SetNamedConfigParm_BandType => {
                    const fx_idx = reaper.TrackFX_AddByName(test_track, "Console1", false, -1);
                    _ = reaper.TrackFX_SetNamedConfigParm(test_track, fx_idx, "band_type", "0");
                },
                .TrackFX_SetParamNormalized => {
                    const fx_idx = reaper.TrackFX_AddByName(test_track, "Console1", false, -1);
                    _ = reaper.TrackFX_SetParamNormalized(test_track, fx_idx, 0, 0.5);
                },
                .TrackFX_SetPinMappings => {
                    const fx_idx = reaper.TrackFX_AddByName(test_track, "Console1", false, -1);
                    _ = reaper.TrackFX_SetPinMappings(test_track, fx_idx, 0, 0, 1, 0);
                },
                .CSurf_OnArrow => reaper.CSurf_OnArrow(0, false),
                .CSurf_OnFwd => reaper.CSurf_OnFwd(5),
                .CSurf_OnFXChange => _ = reaper.CSurf_OnFXChange(test_track, 0),
                .CSurf_OnPlayRateChange => reaper.CSurf_OnPlayRateChange(1.5),
                // .CSurf_OnRecord => reaper.CSurf_OnRecord(),
                .CSurf_OnRecvPanChange => _ = reaper.CSurf_OnRecvPanChange(test_track, 0, 0.5, false),
                .CSurf_OnRew => reaper.CSurf_OnRew(5),
                .CSurf_OnRewFwd => reaper.CSurf_OnRewFwd(5, 1),
                .CSurf_OnScroll => reaper.CSurf_OnScroll(1, 0),
                .CSurf_OnSendPanChange => _ = reaper.CSurf_OnSendPanChange(test_track, 0, 0.5, false),
                .CSurf_OnSendVolumeChange => _ = reaper.CSurf_OnSendVolumeChange(test_track, 0, 0.5, false),
                .CSurf_OnStop => reaper.CSurf_OnStop(),
                .CSurf_OnTempoChange => reaper.CSurf_OnTempoChange(120.0),
                .CSurf_OnVolumeChangeEx => _ = reaper.CSurf_OnVolumeChangeEx(test_track, 0.5, false, false),
                .CSurf_OnWidthChange => _ = reaper.CSurf_OnWidthChange(test_track, 0.5, false),
                .CSurf_OnWidthChangeEx => _ = reaper.CSurf_OnWidthChangeEx(test_track, 0.5, false, false),
                .CSurf_OnZoom => reaper.CSurf_OnZoom(0, 0),
                else => {},
            }

            test_result.end_time = std.time.milliTimestamp();
        }

        // Tear down the test
        tearDown(api_call, test_track, witness_track);

        try self.results.append(test_result);
    }
};

pub fn runAllTests(allocator: std.mem.Allocator) !void {
    var test_ = ApiTest.init(allocator);
    defer {
        for (test_.results.items) |*result| {
            result.notifications.deinit();
        }
        test_.results.deinit();
    }

    // Get or create test_ tracks
    const track_count = reaper.CountTracks(null);
    if (track_count < 2) {
        reaper.InsertTrackAtIndex(0, true);
        reaper.InsertTrackAtIndex(1, true);
    }

    const test_track = reaper.GetTrack(0, 0);
    const witness_track = reaper.GetTrack(0, 1);

    // Run test_s for each API call
    inline for (comptime std.meta.fields(TestApiCall)) |field| {
        const api_call = @field(TestApiCall, field.name);
        try test_.runTest(api_call, test_track, witness_track);
    }

    // Generate report
    try generateReport(&test_);
}

fn generateReport(test_: *const ApiTest) !void {
    // Open a file for writing
    const file = try std.fs.cwd().createFile(
        "reentrancy_report.txt",
        .{ .read = true },
    );
    defer file.close();

    const writer = file.writer();

    try writer.writeAll("Reentrancy Test Results\n====================\n\n");

    for (test_.results.items) |result| {
        try writer.print("\nAPI Call: {s}\n", .{@tagName(result.api_call)});
        try writer.print("Time: {}ms\n", .{result.end_time - result.start_time});
        try writer.writeAll("Notifications:\n");

        for (result.notifications.items) |notification| {
            try writer.print("  - {s} (track: {?})\n", .{ notification.type.toString(), notification.track_id });

            // Print notification-specific data
            switch (notification.data) {
                .none => {},
                .volume => |v| try writer.print("    Volume: {d:.2}\n", .{v}),
                .pan => |p| try writer.print("    Pan: {d:.2}\n", .{p}),
                .fx_param => |fx| try writer.print("    FX: {d} Param: {d} Value: {d:.2}\n", .{ fx.fx_index, fx.param_index, fx.value }),
            }
        }
        try writer.writeAll("\n");
    }
}

fn setupTestEnvironment() !struct { test_track: reaper.MediaTrack, witness_track: reaper.MediaTrack } {
    // Clear existing tracks if any
    const count = reaper.CountTracks(0);
    var idx: c_int = 0;
    while (idx < count - 1) : (idx += 1) {
        const track = reaper.GetTrack(0, idx);
        reaper.DeleteTrack(track);
    }

    // Create fresh test tracks
    reaper.InsertTrackAtIndex(0, true);
    reaper.InsertTrackAtIndex(1, true);

    const test_track = reaper.GetTrack(0, 0);
    const witness_track = reaper.GetTrack(0, 1);

    return .{ .test_track = test_track, .witness_track = witness_track };
}

pub fn runInitialTest() !void {
    const tracks = try setupTestEnvironment();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit(); // This will free all allocations

    var test_ = ApiTest.init(arena.allocator());

    // Try just one simple test_ first
    try test_.runTest(.SetTrackSelected, tracks.test_track, tracks.witness_track);

    // Generate and check report
    try generateReport(&test_);
}
