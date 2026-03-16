const std = @import("std");
const State = @import("statemachine.zig").State;
const Preferences = @import("settings.zig").Preferences;
const MapStore = @import("mappings.zig").MapStore;
const logger = @import("logger.zig");
const SettingsPanel = @import("settings_panel.zig");
const FxMaps = @import("mappings_list.zig");
const reaper = @import("reaper.zig").reaper;
const fxParser = @import("fx_parser.zig");
const fs_helpers = @import("fs_helpers.zig");
const log = std.log.scoped(.globals);
const imgui = @import("reaper_imgui");
const TranslationStore = @import("translations.zig").TranslationStore;

pub const Globals = @This();
pub var instance: Globals = undefined;

// State machine
state: State = undefined,

// Configuration
preferences: Preferences = undefined,
map_store: MapStore = undefined,
mappings_list: FxMaps = undefined,

// UI
settings_panel: ?SettingsPanel = null,
drwls_splitter: imgui.DrawListSplitterPtr = null,

// Logging
log_file: ?std.fs.File = null,

// Resource management
gpa_int: std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 999, .verbose_log = false }) = undefined,
arena_int: std.heap.ArenaAllocator = undefined,
arena: std.mem.Allocator = undefined,
resource_path: [:0]const u8 = undefined,
fs_ops: fs_helpers.FileSystemOps = undefined,
translations: TranslationStore = undefined,

// midi
m_midi_in_dev: ?c_int = null,
m_midi_out_dev: ?c_int = null,
m_midi_in: ?*reaper.midi_Input = null,
m_midi_out: ?reaper.midi_Output = null,

playState: bool = false,
pauseState: bool = false,

pub fn defaults(debug_allocator: std.mem.Allocator) !Globals {
    // Create a basic instance
    var globals = Globals{};

    globals.arena_int = std.heap.ArenaAllocator.init(debug_allocator);
    globals.arena = globals.arena_int.allocator();
    globals.fs_ops = fs_helpers.RealFileSystem.fileSystemOps();
    globals.resource_path = "";
    globals.preferences = try .defaults(globals.arena);
    globals.map_store = .empty(globals.arena, globals.resource_path);
    globals.mappings_list = .empty(globals.arena);
    globals.translations = try .defaults(globals.arena);
    globals.state = .init(globals.arena);
    globals.state.current_mode = .suspended;

    return globals;
}

pub fn reset(self: *Globals) void {
    @import("actions.zig").dispatch(self, .{ .change_mode = if (self.m_midi_in != null) .fx_ctrl else .suspended });
}

pub fn init() !void {
    instance = .{};
    instance.gpa_int = .{};
    instance.arena_int = .init(instance.gpa_int.allocator());
    instance.arena = instance.arena_int.allocator();
    instance.fs_ops = fs_helpers.RealFileSystem.fileSystemOps();

    fs_helpers.ensureConfigPath(instance.fs_ops) catch {};
    instance.resource_path = std.mem.span(try fs_helpers.getControllerPath(instance.arena));

    // Initialize in dependency order
    instance.preferences = try .init(instance.arena, instance.resource_path);
    instance.translations = try .init(
        instance.arena,
        instance.resource_path,
        instance.preferences.language, // We'll need to add this to preferences
    );
    instance.map_store = try .init(
        instance.arena,
        instance.resource_path,
        &instance.preferences.default_fx,
    );
    instance.mappings_list = .init(instance.arena, instance.resource_path);
    instance.state = .init(instance.arena);
    instance.settings_panel = try .init(&instance.preferences);

    if (instance.preferences.start_suspended) {
        instance.state.current_mode = .suspended;
    }

    try fxParser.init(instance.arena);
}

pub fn deinit(self: *Globals) void {
    self.arena_int.deinit();

    const deinit_status = self.gpa_int.deinit();
    if (deinit_status == .leak) {
        log.err("Memory leak detected\n", .{});
    }
}

pub fn initLoggerState(self: *Globals) !void {
    if (self.preferences.log_to_file) {
        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
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

    // Open new file if needed
    if (self.preferences.log_to_file) {
        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
        const log_path = fs_helpers.joinStrings(&path_buffer, &.{
            self.resource_path,
            std.fs.path.sep_str,
            "debug.log",
        });

        self.log_file = try std.fs.createFileAbsolute(log_path, .{});
        logger.log_file = &self.log_file.?;
    }
}
