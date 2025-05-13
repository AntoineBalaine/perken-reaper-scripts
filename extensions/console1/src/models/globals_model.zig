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

    // Initialize default preferences with fallback values
    globals.preferences = Preferences{
        .default_fx = DefaultFx.initFill(null),
    };

    // Copy fallback defaults for preferences
    inline for (comptime std.enums.values(ModulesList)) |module| {
        const fallback = Preferences.fallback_defaults.get(module).?;
        const owned_copy = try globals.arena.dupeZ(u8, fallback);
        globals.preferences.default_fx.set(module, owned_copy);
    }

    // Initialize event log (needed by called functions)
    globals.event_log = EventLog.init();
    logger.event_log = &globals.event_log;

    // Initialize empty map_store
    globals.map_store = MapStore{
        .COMP = std.StringArrayHashMapUnmanaged(MapStore.Comp){},
        .EQ = std.StringArrayHashMapUnmanaged(MapStore.Eq){},
        .INPUT = std.StringArrayHashMapUnmanaged(MapStore.Inpt){},
        .OUTPT = std.StringArrayHashMapUnmanaged(MapStore.Outpt){},
        .GATE = std.StringArrayHashMapUnmanaged(MapStore.Shp){},
        .controller_dir = try globals.arena.dupeZ(u8, ""),
        .allocator = globals.arena,
    };

    // Initialize empty mappings_list
    globals.mappings_list = .{
        .list = std.EnumArray(ModulesList, std.StringArrayHashMap(void)).init(.{
            .INPUT = std.StringArrayHashMap(void).init(globals.arena),
            .GATE = std.StringArrayHashMap(void).init(globals.arena),
            .EQ = std.StringArrayHashMap(void).init(globals.arena),
            .COMP = std.StringArrayHashMap(void).init(globals.arena),
            .OUTPT = std.StringArrayHashMap(void).init(globals.arena),
        }),
        .arena = globals.arena,
    };

    // Initialize translations with default values
    globals.translations = .{
        .store = Translations.StringStore.init(),
        .current_language = "en",
        .available_languages = &[_]Translations.LanguageInfo{},
    };
    try globals.translations.store.loadDefaults(globals.arena);

    // Initialize state machine
    globals.state = statemachine.State.init(globals.arena);

    // Set suspended mode initially
    globals.state.current_mode = .suspended;

    return globals;
}
