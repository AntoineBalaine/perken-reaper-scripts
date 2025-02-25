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
const TranslationStore = @import("translations.zig").TranslationStore;

pub const Globals = @This();
pub var instance: Globals = undefined;

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
gpa_int: std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 999, .verbose_log = false }) = undefined,
arena_int: std.heap.ArenaAllocator = undefined,
arena: std.mem.Allocator = undefined,
resource_path: [:0]const u8 = undefined,
translations: TranslationStore = undefined,

// midi
m_midi_in_dev: ?c_int = null,
m_midi_out_dev: ?c_int = null,
m_midi_in: ?*reaper.midi_Input = null,
m_midi_out: ?reaper.midi_Output = null,

playState: bool = false,
pauseState: bool = false,

pub fn init() !void {
    instance = .{};
    const gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 999, .verbose_log = false }){};
    instance.gpa_int = gpa;
    instance.arena_int = std.heap.ArenaAllocator.init(instance.gpa_int.allocator());
    instance.arena = instance.arena_int.allocator();

    fs_helpers.ensureConfigPath() catch {};
    instance.resource_path = std.mem.span(try fs_helpers.getControllerPath(instance.arena));

    // Initialize in dependency order
    instance.preferences = try Preferences.init(instance.arena, instance.resource_path);
    instance.translations = try TranslationStore.init(
        instance.arena,
        instance.resource_path,
        instance.preferences.language, // We'll need to add this to preferences
    );
    instance.map_store = try MapStore.init(instance.arena, instance.resource_path, &instance.preferences.default_fx);
    instance.mappings_list = MappingsList.init(instance.arena, instance.resource_path);
    instance.state = State.init(instance.arena);
    instance.settings_panel = try SettingsPanel.init(&instance.preferences);
    if (instance.preferences.start_suspended) {
        instance.state.current_mode = .suspended;
    }

    try fxParser.init(instance.gpa_int.allocator());
}

pub fn deinit(self: *Globals) void {
    fxParser.deinit(self.gpa_int.allocator());
    self.arena_int.deinit();

    const deinit_status = self.gpa_int.deinit();
    if (deinit_status == .leak) {
        log.err("Memory leak detected\n", .{});
    }
}

pub fn initLoggerState(self: *Globals) !void {
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
