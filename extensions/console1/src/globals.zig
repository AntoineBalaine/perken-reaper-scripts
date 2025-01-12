const std = @import("std");
const State = @import("statemachine.zig").State;
const Preferences = @import("settings.zig").Preferences;
const MapStore = @import("internals/mappings.zig").MapStore;
const logger = @import("logger.zig");
const EventLog = logger.EventLog;
const SettingsPanel = @import("settings_panel.zig");
const MappingsList = @import("mappings_list.zig");

// State machine
pub var state: State = undefined;

// Configuration
pub var preferences: Preferences = undefined;
pub var map_store: MapStore = undefined;
pub var mappings_list: MappingsList = undefined;

// UI
pub var settings_panel: ?SettingsPanel = null;

// Logging
pub var event_log: EventLog = undefined;
pub var log_file: ?std.fs.File = null; // Store the actual file, not just a pointer

// Resource management
pub var allocator: std.mem.Allocator = undefined;
pub var resource_path: [:0]const u8 = undefined;

pub fn init(gpa: std.mem.Allocator, path: [*:0]const u8) !void {
    allocator = gpa;
    resource_path = try allocator.dupeZ(u8, std.mem.span(path));

    // Initialize in dependency order
    preferences = try Preferences.init(allocator, resource_path);

    map_store = try MapStore.init(allocator, resource_path, &preferences.default_fx);
    mappings_list = try MappingsList.init(allocator, resource_path);
    event_log = EventLog.init();
    state = State.init(gpa);
    settings_panel = try SettingsPanel.init(&preferences, gpa);
    try initLoggerState();
}

pub fn deinit(alloc: std.mem.Allocator) void {
    map_store.deinit();
    mappings_list.deinit();
    preferences.deinit();
    state.deinit(alloc);
    allocator.free(resource_path);
}

pub fn initLoggerState() !void {
    // Set log level pointer
    logger.log_level = &preferences.log_level;

    // Set event log pointer
    logger.event_log = &event_log;

    // Handle file logging
    if (preferences.log_to_file) {
        const log_path = try std.fs.path.join(allocator, &.{ resource_path, "debug.log" });
        defer allocator.free(log_path);

        log_file = try std.fs.createFileAbsolute(log_path, .{});
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
        const log_path = try std.fs.path.join(allocator, &.{ resource_path, "debug.log" });
        defer allocator.free(log_path);

        // Store the actual file in our module
        log_file = try std.fs.createFileAbsolute(log_path, .{});
        // Pass pointer to our stored file to logger
        logger.log_file = &log_file.?;
    }
}
