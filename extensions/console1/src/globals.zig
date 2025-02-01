const std = @import("std");
const State = @import("statemachine.zig").State;
const Preferences = @import("settings.zig").Preferences;
const MapStore = @import("mappings.zig").MapStore;
const logger = @import("logger.zig");
const EventLog = logger.EventLog;
const SettingsPanel = @import("settings_panel.zig");
const MappingsList = @import("mappings_list.zig");
const MappingPanel = @import("mapping_panel.zig").MappingPanel;
const reaper = @import("reaper.zig").reaper;
const fxParser = @import("fx_parser.zig");
const fs_helpers = @import("internals/fs_helpers.zig");
const getControllerPath = fs_helpers.getControllerPath;
const log = std.log.scoped(.globals);
// State machine
pub var state: State = undefined;

// Configuration
pub var preferences: Preferences = undefined;
pub var map_store: MapStore = undefined;
pub var mappings_list: MappingsList = undefined;

// UI
pub var settings_panel: ?SettingsPanel = null;
pub var mapping_panel: ?MappingPanel = null;

// Logging
pub var event_log: EventLog = undefined;
pub var log_file: ?std.fs.File = null; // Store the actual file, not just a pointer

// Resource management
var gpa_int: std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 999, .verbose_log = false }) = undefined;
pub var allocator: std.mem.Allocator = undefined;
pub var resource_path: [:0]const u8 = undefined;

// State flags
pub var modifier_active: bool = false;

// midi
pub var m_midi_in_dev: ?c_int = null;
pub var m_midi_out_dev: ?c_int = null;
pub var m_midi_in: ?*reaper.midi_Input = null;
pub var m_midi_out: ?reaper.midi_Output = null;

pub var playState: bool = false;
pub var pauseState: bool = false;

pub fn init() !void {
    gpa_int = @TypeOf(gpa_int){};
    const gpa = gpa_int.allocator();
    try initLoggerState();
    allocator = gpa;
    const path: [*:0]const u8 = getControllerPath(gpa) catch |err| {
        log.warn("Failed to create controller dir", .{});
        return err;
    };
    resource_path = std.mem.span(path);
    errdefer |err| {
        log.err("C1 init failed: {s}", .{@errorName(err)});
        gpa.free(resource_path);
    }

    // Initialize in dependency order
    preferences = try Preferences.init(gpa, resource_path);

    map_store = try MapStore.init(gpa, resource_path, &preferences.default_fx);
    mappings_list = try MappingsList.init(gpa, resource_path);
    state = State.init(gpa);
    settings_panel = try SettingsPanel.init(&preferences, gpa);
    if (preferences.start_suspended) {
        state.current_mode = .suspended;
    }

    try fxParser.init(allocator);
}

pub fn deinit() void {
    fxParser.deinit(allocator);
    allocator.free(resource_path);
    if (settings_panel) |*panel| {
        panel.deinit();
    }
    map_store.deinit();
    mappings_list.deinit();
    preferences.deinit();
    state.deinit(allocator);
    allocator.free(resource_path);
    const deinit_status = gpa_int.deinit();
    if (deinit_status == .leak) {
        log.err("Memory leak detected\n", .{});
    }
}

pub fn initLoggerState() !void {
    event_log = EventLog.init();
    // Set event log pointer
    logger.event_log = &event_log;
    // Handle file logging

    if (preferences.log_to_file) {
        var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const path = try fs_helpers.joinStrings(&path_buffer, &.{
            resource_path,
            std.fs.path.sep_str,
            "debug.log",
        });

        log_file = try std.fs.createFileAbsolute(path, .{});
        logger.log_file = &log_file.?;
    }
}

pub fn updateLoggerState() !void {
    // Close existing file if any
    if (logger.log_file) |_| {
        logger.log_file = null;
    }

    // Also close our handle if it exists
    if (log_file) |*file| {
        file.close();
    }

    // Open new file if needed
    if (preferences.log_to_file) {
        var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const log_path = try fs_helpers.joinStrings(&path_buffer, &.{
            resource_path,
            std.fs.path.sep_str,
            "debug.log",
        });

        // Store the actual file in our module
        log_file = try std.fs.createFileAbsolute(log_path, .{});
        // Pass pointer to our stored file to logger
        logger.log_file = &log_file.?;
    }
}
