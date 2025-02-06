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
const fs_helpers = @import("fs_helpers.zig");
const log = std.log.scoped(.globals);
const imgui = @import("reaper_imgui.zig");
// State machine
pub var state: State = undefined;

// Configuration
pub var preferences: Preferences = undefined;
pub var map_store: MapStore = undefined;
pub var mappings_list: MappingsList = undefined;

// UI
pub var settings_panel: ?SettingsPanel = null;
pub var mapping_panel: ?MappingPanel = null;
pub var drwls_splitter: imgui.DrawListSplitterPtr = null;
// Logging
pub var event_log: EventLog = undefined;
pub var log_file: ?std.fs.File = null; // Store the actual file, not just a pointer

// Resource management
var gpa_int: std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 999, .verbose_log = false }) = undefined;
var arena_int: std.heap.ArenaAllocator = undefined;
pub var arena: std.mem.Allocator = undefined;
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
    arena_int = std.heap.ArenaAllocator.init(gpa_int.allocator());
    arena = arena_int.allocator();

    try initLoggerState();
    fs_helpers.ensureConfigPath() catch {};
    resource_path = std.mem.span(try fs_helpers.getControllerPath(arena));

    // Initialize in dependency order
    preferences = try Preferences.init(arena, resource_path);

    map_store = try MapStore.init(arena, resource_path, &preferences.default_fx);
    mappings_list = MappingsList.init(arena, resource_path);
    state = State.init(arena);
    settings_panel = try SettingsPanel.init(&preferences, arena);
    if (preferences.start_suspended) {
        state.current_mode = .suspended;
    }

    try fxParser.init(gpa_int.allocator());
}

pub fn deinit() void {
    fxParser.deinit(gpa_int.allocator());

    arena_int.deinit();

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
        const path = fs_helpers.joinStrings(&path_buffer, &.{
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
        const log_path = fs_helpers.joinStrings(&path_buffer, &.{
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
