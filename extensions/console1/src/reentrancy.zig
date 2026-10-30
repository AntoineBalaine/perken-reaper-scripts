const std = @import("std");
const pReaper = @import("pReaper.zig");
const reaper = @import("reaper").reaper;
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
    SetTrackTitle,

    // Playback notifications
    SetPlayState,
    SetRepeatState,

    // FX notifications
    Extended_SetFXParam,
    Extended_SetFXEnabled,
    Extended_SetFocusedFX,
    Extended_SetLastTouchedTrack,
    Extended_SetFXOpen,
    Extended_SetFXChange,
    Extended_MidiDeviceRemap,
    Extended_Reset,
    Extended_SetAutoRecArm,
    Extended_SetBPMAndPlayrate,
    Extended_SetMetronome,
    Extended_SetMixerScroll,
    Extended_SetFXParamRecFX,
    Extended_SetInputMonitor,
    Extended_SetLastTouchedFX,
    Extended_SetProjectMarkerChange,
    Extended_SetRecMode,
    Extended_SetRecvPan,
    Extended_SetRecvVolume,
    Extended_SetSendPan,
    Extended_SetSendVolume,
    Extended_SupportsExtendedTouch,
    Extended_TrackFXPresetChanged,

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
    pub fn getDelayFromApiCall(self: @This(), api_start_time: i64) i64 {
        return self.timestamp - api_start_time;
    }
};

pub const ApiTestResult = struct {
    api_call: TestApiCall,
    notifications: std.ArrayList(Notification),
    /// The allocator of `notifications`, which is unmanaged.
    allocator: std.mem.Allocator,
    start_time: i64,
    end_time: i64,
};
pub const ApiTest = struct {
    results: std.ArrayList(ApiTestResult),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ApiTest {
        return .{
            .results = .empty,
            .allocator = allocator,
        };
    }

    fn tearDown(api_call: TestApiCall, test_track: reaper.MediaTrack, witness_track: reaper.MediaTrack) void {
        // Clear current_test to avoid capturing tear down notifications
        current_test = null;

        switch (api_call) {
            .SetTrackSelected => {
                _ = pReaper.DeleteTrack(.{test_track});
                _ = pReaper.DeleteTrack(.{witness_track});
            },
            .SetMediaTrackInfo_Value_Phase => {
                _ = pReaper.SetMediaTrackInfo_Value(.{ test_track, "B_PHASE", 0 });
            },
            .SetMediaTrackInfo_Value_NChan => {
                _ = pReaper.SetMediaTrackInfo_Value(.{ test_track, "I_NCHAN", 2 }); // Reset to stereo
            },
            .TrackFX_AddByName => {
                const fx_idx = reaper.TrackFX_GetByName(test_track, "JS: DC Filter", false);
                _ = pReaper.TrackFX_Delete(.{ test_track, fx_idx });
            },
            .TrackFX_CopyToTrack => {
                // Remove from both tracks
                const test_fx_idx = reaper.TrackFX_GetByName(test_track, "JS: DC Filter", false);
                _ = pReaper.TrackFX_Delete(.{ test_track, test_fx_idx });

                const wit_fx_idx = reaper.TrackFX_GetByName(witness_track, "JS: DC Filter", false);
                _ = pReaper.TrackFX_Delete(.{ witness_track, wit_fx_idx });
            },
            .TrackFX_SetEnabled => {
                const fx_idx = reaper.TrackFX_GetByName(test_track, "JS: DC Filter", false);
                pReaper.TrackFX_SetEnabled(.{ test_track, fx_idx, true });
                _ = pReaper.TrackFX_Delete(.{ test_track, fx_idx });
            },
            .TrackFX_SetNamedConfigParm_RenamedName => {
                const fx_idx = reaper.TrackFX_GetByName(test_track, "JS: DC Filter_perkn", false);
                _ = pReaper.TrackFX_Delete(.{ test_track, fx_idx });
            },
            .TrackFX_SetNamedConfigParm_BandType, .TrackFX_SetParamNormalized, .TrackFX_SetPinMappings => {
                const fx_idx = reaper.TrackFX_GetByName(test_track, "JS: DC Filter", false);
                _ = pReaper.TrackFX_Delete(.{ test_track, fx_idx });
            },
            .CSurf_OnArrow => {}, // These are momentary actions, no teardown needed
            .CSurf_OnFwd => {},
            .CSurf_OnFXChange => {},
            .CSurf_OnPlayRateChange => pReaper.CSurf_OnPlayRateChange(.{1.0}), // Reset to normal rate
            .CSurf_OnRecord => {}, // Momentary
            .CSurf_OnRecvPanChange => _ = pReaper.CSurf_OnRecvPanChange(.{ test_track, 0, 0.0, false }),
            .CSurf_OnRecvVolumeChange => _ = pReaper.CSurf_OnRecvVolumeChange(.{ test_track, 0, 1.0, false }),
            .CSurf_OnRew => {},
            .CSurf_OnRewFwd => {},
            .CSurf_OnScroll => {},
            .CSurf_OnSendPanChange => _ = pReaper.CSurf_OnSendPanChange(.{ test_track, 0, 0.0, false }),
            .CSurf_OnSendVolumeChange => _ = pReaper.CSurf_OnSendVolumeChange(.{ test_track, 0, 1.0, false }),
            .CSurf_OnStop => {},
            .CSurf_OnTempoChange => pReaper.CSurf_OnTempoChange(.{120.0}), // Reset to default
            .CSurf_OnVolumeChangeEx => _ = pReaper.CSurf_OnVolumeChangeEx(.{ test_track, 1.0, false, false }),
            .CSurf_OnWidthChange => _ = pReaper.CSurf_OnWidthChange(.{ test_track, 1.0, false }),
            .CSurf_OnWidthChangeEx => _ = pReaper.CSurf_OnWidthChangeEx(.{ test_track, 1.0, false, false }),
            .CSurf_OnZoom => {},
        }
    }

    pub fn runTest(self: *ApiTest, io: std.Io, api_call: TestApiCall, test_track: reaper.MediaTrack, witness_track: reaper.MediaTrack) !void {
        var test_result = ApiTestResult{
            .api_call = api_call,
            .notifications = .empty,
            .allocator = self.allocator,
            .start_time = std.Io.Timestamp.now(io, .real).toMilliseconds(),
            .end_time = undefined,
        };

        {
            current_test = &test_result;
            // clear current test before teardown
            defer current_test = null;

            // Log that we're starting this API call
            log.debug("{}", .{ReentrancyMessage{ .api_call = api_call }});

            switch (api_call) {
                .SetTrackSelected => pReaper.SetTrackSelected(.{ test_track, true }),
                .SetMediaTrackInfo_Value_Phase => {
                    _ = pReaper.SetMediaTrackInfo_Value(.{ test_track, "B_PHASE", 1 });
                },
                .SetMediaTrackInfo_Value_NChan => {
                    _ = pReaper.SetMediaTrackInfo_Value(.{ test_track, "I_NCHAN", 4 });
                },
                .TrackFX_AddByName => {
                    _ = pReaper.TrackFX_AddByName(.{ test_track, "JS: DC Filter", false, -1 });
                },
                .TrackFX_CopyToTrack => {
                    const fx_idx = pReaper.TrackFX_AddByName(.{ test_track, "JS: DC Filter", false, -1 });
                    _ = pReaper.TrackFX_CopyToTrack(.{ test_track, fx_idx, witness_track, fx_idx, true });
                },
                .TrackFX_SetEnabled => {
                    const fx_idx = pReaper.TrackFX_AddByName(.{ test_track, "JS: DC Filter", false, -1 });
                    pReaper.TrackFX_SetEnabled(.{ test_track, fx_idx, false });
                },
                .TrackFX_SetNamedConfigParm_RenamedName => {
                    const fx_idx = pReaper.TrackFX_AddByName(.{ test_track, "JS: DC Filter", false, -1 });
                    _ = pReaper.TrackFX_SetNamedConfigParm(.{ test_track, fx_idx, "renamed_name", "JS: DC Filter_perkn" });
                },
                .TrackFX_SetNamedConfigParm_BandType => {
                    const fx_idx = pReaper.TrackFX_AddByName(.{ test_track, "JS: DC Filter", false, -1 });
                    _ = pReaper.TrackFX_SetNamedConfigParm(.{ test_track, fx_idx, "band_type", "0" });
                },
                .TrackFX_SetParamNormalized => {
                    const fx_idx = pReaper.TrackFX_AddByName(.{ test_track, "JS: DC Filter", false, -1 });
                    _ = pReaper.TrackFX_SetParamNormalized(.{ test_track, fx_idx, 0, 0 });
                },
                .TrackFX_SetPinMappings => {
                    const fx_idx = pReaper.TrackFX_AddByName(.{ test_track, "JS: DC Filter", false, -1 });
                    _ = pReaper.TrackFX_SetPinMappings(.{ test_track, fx_idx, 0, 0, 1, 0 });
                },
                .CSurf_OnArrow => pReaper.CSurf_OnArrow(.{ 0, false }),
                .CSurf_OnFwd => pReaper.CSurf_OnFwd(.{5}),
                .CSurf_OnFXChange => _ = pReaper.CSurf_OnFXChange(.{ test_track, 0 }),
                .CSurf_OnPlayRateChange => pReaper.CSurf_OnPlayRateChange(.{1.5}),
                // .CSurf_OnRecord => pReaper.CSurf_OnRecord.{ ( }),
                .CSurf_OnRecvPanChange => _ = pReaper.CSurf_OnRecvPanChange(.{ test_track, 0, 0.5, false }),
                .CSurf_OnRew => pReaper.CSurf_OnRew(.{5}),
                .CSurf_OnRewFwd => pReaper.CSurf_OnRewFwd(.{ 5, 1 }),
                .CSurf_OnScroll => pReaper.CSurf_OnScroll(.{ 1, 0 }),
                .CSurf_OnSendPanChange => _ = pReaper.CSurf_OnSendPanChange(.{ test_track, 0, 0.5, false }),
                .CSurf_OnSendVolumeChange => _ = pReaper.CSurf_OnSendVolumeChange(.{ test_track, 0, 0.5, false }),
                .CSurf_OnStop => pReaper.CSurf_OnStop(.{}),
                .CSurf_OnTempoChange => pReaper.CSurf_OnTempoChange(.{120.0}),
                .CSurf_OnVolumeChangeEx => _ = pReaper.CSurf_OnVolumeChangeEx(.{ test_track, 0.5, false, false }),
                .CSurf_OnWidthChange => _ = pReaper.CSurf_OnWidthChange(.{ test_track, 0.5, false }),
                .CSurf_OnWidthChangeEx => _ = pReaper.CSurf_OnWidthChangeEx(.{ test_track, 0.5, false, false }),
                .CSurf_OnZoom => pReaper.CSurf_OnZoom(.{ 0, 0 }),
                else => {},
            }

            test_result.end_time = std.Io.Timestamp.now(io, .real).toMilliseconds();
        }

        // Tear down the test
        tearDown(api_call, test_track, witness_track);

        try self.results.append(self.allocator, test_result);
    }
};

fn isFXRelatedTest(api_call: TestApiCall) bool {
    return switch (api_call) {
        .TrackFX_AddByName, .TrackFX_CopyToTrack, .TrackFX_SetEnabled, .TrackFX_SetNamedConfigParm_RenamedName, .TrackFX_SetNamedConfigParm_BandType, .TrackFX_SetParamNormalized => true,
        else => false,
    };
}

pub fn runAllTests(io: std.Io) !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit(); // This will free all allocations

    var test_ = ApiTest.init(arena.allocator());

    // Get or create test_ tracks
    const track_count = reaper.CountTracks(null);
    if (track_count < 2) {
        reaper.InsertTrackAtIndex(0, true);
        reaper.InsertTrackAtIndex(1, true);
    }

    const tracks = try setupTestEnvironment();

    // Run test_s for each API call
    inline for (@typeInfo(TestApiCall).@"enum".field_names) |field_name| {
        const api_call = @field(TestApiCall, field_name);
        if (!isFXRelatedTest(api_call)) {
            try test_.runTest(io, api_call, tracks.test_track, tracks.witness_track);
            io.sleep(.fromMilliseconds(50), .awake) catch {};
        }
    }

    // Then run FX tests with more delay
    inline for (@typeInfo(TestApiCall).@"enum".field_names) |field_name| {
        const api_call = @field(TestApiCall, field_name);
        if (isFXRelatedTest(api_call)) {
            try test_.runTest(io, api_call, tracks.test_track, tracks.witness_track);
            io.sleep(.fromMilliseconds(100), .awake) catch {};
        }
    }

    // Generate report
    try generateReport(io, &test_, null);
}

fn generateReport(io: std.Io, test_: *const ApiTest, filename: ?[]const u8) !void {
    const path = if (filename) |name| name else "reentrancy_report.txt";

    // Try to open existing file, create if doesn't exist
    var file = std.Io.Dir.cwd().openFile(io, path, .{ .mode = .read_write }) catch std.Io.Dir.cwd().createFile(io, path, .{}) catch return;
    defer file.close(io);

    // Because file writers are buffered since Zig 0.15, the writer is flushed before the file closes.
    var writer_buffer: [4096]u8 = undefined;
    var writer_file_writer = file.writer(io, &writer_buffer);
    const writer = &writer_file_writer.interface;

    // Seek to end of file. Because the position belongs to the writer since Zig 0.16, the writer seeks.
    const stat = try file.stat(io);
    try writer_file_writer.seekTo(stat.size);

    // Add separator between test runs
    try writer.writeAll("\n=================================\n");

    for (test_.results.items) |result| {
        try writer.print("\nAPI Call: {s}\n", .{@tagName(result.api_call)});
        try writer.print("Time: {}ms\n", .{result.end_time - result.start_time});
        try writer.writeAll("Notifications:\n");

        for (result.notifications.items) |notification| {
            const delay = notification.getDelayFromApiCall(result.start_time);
            try writer.print("  - {s} (track: {?}, delay: {}ms)\n", .{ notification.type.toString(), notification.track_id, delay });

            switch (notification.data) {
                .none => {},
                .volume => |v| try writer.print("    Volume: {d:.2}\n", .{v}),
                .pan => |p| try writer.print("    Pan: {d:.2}\n", .{p}),
                .fx_param => |fx| try writer.print("    FX: {d} Param: {d} Value: {d:.2}\n", .{ fx.fx_index, fx.param_index, fx.value }),
            }
        }

        if (result.notifications.items.len > 0) {
            const last_notification = result.notifications.items[result.notifications.items.len - 1];
            const max_delay = last_notification.getDelayFromApiCall(result.start_time);
            try writer.print("\nMax notification delay: {}ms\n", .{max_delay});
        }

        try writer.writeAll("\n");
    }
    try writer.flush();
}

fn setupTestEnvironment() !struct { test_track: reaper.MediaTrack, witness_track: reaper.MediaTrack } {
    // Clear existing tracks if any
    const count = reaper.CountTracks(null);
    var idx: c_int = 0;
    while (idx < count - 1) : (idx += 1) {
        const track = reaper.GetTrack(null, idx);
        reaper.DeleteTrack(track);
    }

    // Create fresh test tracks
    reaper.InsertTrackAtIndex(0, true);
    reaper.InsertTrackAtIndex(1, true);

    const test_track = reaper.GetTrack(null, 0);
    const witness_track = reaper.GetTrack(null, 1);

    return .{ .test_track = test_track, .witness_track = witness_track };
}

pub fn runInitialTest() !void {
    const tracks = try setupTestEnvironment();

    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit(); // This will free all allocations

    var test_ = ApiTest.init(arena.allocator());

    // Try just one simple test_ first
    try test_.runTest(.TrackFX_AddByName, tracks.test_track, tracks.witness_track);

    // Generate and check report
    try generateReport(&test_, null);
}

pub fn runSingleTest(io: std.Io, api_call: TestApiCall) !void {
    const tracks = try setupTestEnvironment();

    var test_ = ApiTest.init(std.heap.page_allocator);
    defer {
        for (test_.results.items) |*result| {
            result.notifications.deinit(result.allocator);
        }
        test_.results.deinit(test_.allocator);
    }

    try test_.runTest(io, api_call, tracks.test_track, tracks.witness_track);

    // Generate report with specific name for this test
    // var buf: [256]u8 = undefined;
    // const report_name = try std.fmt.bufPrint(&buf, "reentrancy_report_{s}.txt", .{@tagName(api_call)});
    try generateReport(io, &test_, null);
}
