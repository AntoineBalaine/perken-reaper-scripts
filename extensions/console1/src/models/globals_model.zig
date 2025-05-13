const DefaultFx = @import("../settings.zig").DefaultFx;
const EventLog = logger.EventLog;
const Globals = @import("../globals.zig");
const MapStore = @import("../mappings.zig").MapStore;
const ModulesList = statemachine.ModulesList;
const Preferences = @import("../settings.zig").Preferences;
const Translations = @import("../translations.zig");
const logger = @import("../logger.zig");
const statemachine = @import("../statemachine.zig");
const std = @import("std");

/// Function to initialize a minimal Globals instance for testing
pub fn initMinimalGlobals() !Globals {
    // Create a basic instance
    var globals = Globals{};

    // Set up memory allocators
    const gpa = std.heap.GeneralPurposeAllocator(.{ .stack_trace_frames = 999, .verbose_log = false }){};
    globals.gpa_int = gpa;
    globals.arena_int = std.heap.ArenaAllocator.init(globals.gpa_int.allocator());
    globals.arena = globals.arena_int.allocator();

    globals.resource_path = "";
    // other option for storing to disk
    // const tmp = std.testing.tmpDir(.{});
    // globals.tmp_dir = tmp;
    // globals.resource_path = try globals.arena.dupeZ(u8, tmp.dir.path);

    globals.preferences = try .defaults(globals.arena);

    globals.event_log = .init();
    logger.event_log = &globals.event_log;
    globals.map_store = .empty(globals.arena, globals.resource_path);

    globals.mappings_list = .empty(globals.arena);

    globals.translations = try .defaults(globals.arena);

    globals.state = .init(globals.arena);

    globals.state.current_mode = .suspended;

    return globals;
}
