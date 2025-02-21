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

pub const Globals = @This();

// State machine
state: State = undefined,

// Configuration
preferences: Preferences = undefined,
map_store: MapStore = undefined,
mappings_list: MappingsList = undefined,

// UI
settings_panel: ?SettingsPanel = null,
mapping_panel: ?MappingPanel = null,
drwls_splitter: imgui.DrawListSplitterPtr = null,

// Logging
event_log: EventLog = undefined,
log_file: ?std.fs.File = null,

// Resource management
gpa: std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 999, .verbose_log = false }) = undefined,
arena_allocator: std.heap.ArenaAllocator = undefined,
allocator: std.mem.Allocator = undefined,
resource_path: [:0]const u8 = undefined,

// midi
m_midi_in_dev: ?c_int = null,
m_midi_out_dev: ?c_int = null,
m_midi_in: ?*reaper.midi_Input = null,
m_midi_out: ?reaper.midi_Output = null,

playState: bool = false,
pauseState: bool = false,

pub fn init() !Globals {
    var self: Globals = .{};
    self.gpa = @TypeOf(self.gpa){};
    self.arena_allocator = std.heap.ArenaAllocator.init(self.gpa.allocator());
    self.allocator = self.arena_allocator.allocator();

    try self.initLoggerState();
    fs_helpers.ensureConfigPath() catch {};
    self.resource_path = std.mem.span(try fs_helpers.getControllerPath(self.allocator));

    // Initialize in dependency order
    self.preferences = try Preferences.init(self.allocator, self.resource_path);
    self.map_store = try MapStore.init(self.allocator, self.resource_path, &self.preferences.default_fx);
    self.mappings_list = MappingsList.init(self.allocator, self.resource_path);
    self.state = State.init(self.allocator);
    self.settings_panel = try SettingsPanel.init(&self.preferences);
    if (self.preferences.start_suspended) {
        self.state.current_mode = .suspended;
    }

    try fxParser.init(self.gpa.allocator());
    return self;
}

pub fn deinit(self: *Globals) void {
    fxParser.deinit(self.gpa.allocator());
    self.arena_allocator.deinit();

    const deinit_status = self.gpa.deinit();
    if (deinit_status == .leak) {
        log.err("Memory leak detected\n", .{});
    }
}

fn initLoggerState(self: *Globals) !void {
    self.event_log = EventLog.init();
    logger.event_log = &self.event_log;

    if (self.preferences.log_to_file) {
        var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const path = fs_helpers.joinStrings(&path_buffer, &.{
            self.resource_path,
            std.fs.path.sep_str,
            "debug.log",
        });

        self.log_file = try std.fs.createFileAbsolute(path, .{});
        logger.log_file = &self.log_file.?;
    }
}

pub fn updateLoggerState(self: *Globals) !void {
    if (logger.log_file) |_| {
        logger.log_file = null;
    }

    if (self.log_file) |*file| {
        file.close();
    }

    if (self.preferences.log_to_file) {
        var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
        const log_path = fs_helpers.joinStrings(&path_buffer, &.{
            self.resource_path,
            std.fs.path.sep_str,
            "debug.log",
        });

        self.log_file = try std.fs.createFileAbsolute(log_path, .{});
        logger.log_file = &self.log_file.?;
    }
}
