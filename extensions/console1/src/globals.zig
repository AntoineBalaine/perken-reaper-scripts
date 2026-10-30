const std = @import("std");
const State = @import("statemachine.zig").State;
const Preferences = @import("settings.zig").Preferences;
const MapStore = @import("mappings.zig").MapStore;
const logger = @import("logger.zig");
const SettingsPanel = @import("settings_panel.zig");
const FxMaps = @import("mappings_list.zig");
const reaper = @import("reaper").reaper;
const fxParser = @import("fx_parser");
const fs_helpers = @import("fs_helpers");
const host_io = @import("host_io");
const actions = @import("actions.zig");
const log = std.log.scoped(.globals);
const imgui = @import("reaper_imgui");
const TranslationStore = @import("translations.zig").TranslationStore;

pub const Globals = @This();
pub var instance: Globals = undefined;

/// The std.Io that the extension does its file and process work with. Because REAPER loads the extension as
/// a library, there is no main() to receive one from, so the extension owns it here. `init` replaces this
/// single-threaded default with host_io.create(), and `deinit` frees it; tests keep the default.
pub var io_threaded: std.Io.Threaded = .init_single_threaded;

pub fn hostIo() std.Io {
    return io_threaded.io();
}

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
log_file: ?std.Io.File = null,

// Resource management
gpa_int: std.heap.DebugAllocator(.{ .stack_trace_frames = 999, .verbose_log = false }) = undefined,
arena_int: std.heap.ArenaAllocator = undefined,
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
    var globals = Globals{};
    // Because deinit always checks this allocator for leaks, it must be a valid empty one when the caller owns the memory.
    globals.gpa_int = .{};

    globals.arena_int = std.heap.ArenaAllocator.init(debug_allocator);
    const alloc = globals.arena_int.allocator();
    globals.fs_ops = fs_helpers.RealFileSystem.fileSystemOps(hostIo());
    globals.resource_path = "";
    globals.preferences = try .defaults(alloc);
    globals.mappings_list = .empty(alloc);
    globals.map_store = .empty(alloc, globals.resource_path);
    globals.translations = try .defaults(alloc);
    globals.state = .init(alloc);
    globals.state.current_mode = .suspended;

    return globals;
}

pub fn reset(self: *Globals) void {
    actions.dispatch(self, .{ .change_mode = if (self.m_midi_in != null) .fx_ctrl else .suspended });
}

pub fn init() !void {
    io_threaded = host_io.create();
    const io = hostIo();
    instance = .{};
    instance.gpa_int = .{};
    instance.arena_int = .init(instance.gpa_int.allocator());
    const alloc = instance.arena_int.allocator();
    instance.fs_ops = fs_helpers.RealFileSystem.fileSystemOps(hostIo());

    @import("defaults.zig").ensureConfigPath(instance.fs_ops) catch {};
    instance.resource_path = std.mem.span(try fs_helpers.getControllerPath(alloc));

    // Initialize in dependency order
    instance.preferences = try .init(alloc, io, instance.resource_path);
    instance.translations = try .init(
        alloc,
        io,
        instance.resource_path,
        instance.preferences.language, // We'll need to add this to preferences
    );
    instance.mappings_list = .init(alloc, io, instance.resource_path);
    instance.map_store = try .init(
        alloc,
        io,
        instance.resource_path,
        &instance.mappings_list,
        &instance.preferences.default_fx,
    );
    instance.state = .init(alloc);
    instance.settings_panel = try .init(&instance.preferences);

    if (instance.preferences.start_suspended) {
        instance.state.current_mode = .suspended;
    }

    try fxParser.init(alloc, io);
}

pub fn deinit(self: *Globals) void {
    self.state.fx_ctrl.track_state.deinitMaps(self.arena_int.allocator());
    self.arena_int.deinit();

    const deinit_status = self.gpa_int.deinit();
    if (deinit_status == .leak) {
        log.err("Memory leak detected\n", .{});
    }
    io_threaded.deinit();
    // Because a freed instance must not be used again, the single-threaded default takes its place.
    io_threaded = .init_single_threaded;
}

pub fn initLoggerState(self: *Globals) !void {
    const io = hostIo();
    if (self.preferences.log_to_file) {
        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
        const path = fs_helpers.joinStrings(&path_buffer, &.{
            self.resource_path,
            std.fs.path.sep_str,
            "debug.log",
        });

        self.log_file = try std.Io.Dir.createFileAbsolute(io, path, .{});
        logger.log_file = &self.log_file.?;
    }
}

pub fn updateLoggerState(self: *Globals) !void {
    const io = hostIo();
    if (logger.log_file) |_| {
        logger.log_file = null;
    }

    if (self.log_file) |*file| {
        file.close(io);
    }

    // Open new file if needed
    if (self.preferences.log_to_file) {
        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
        const log_path = fs_helpers.joinStrings(&path_buffer, &.{
            self.resource_path,
            std.fs.path.sep_str,
            "debug.log",
        });

        self.log_file = try std.Io.Dir.createFileAbsolute(io, log_path, .{});
        logger.log_file = &self.log_file.?;
    }
}
