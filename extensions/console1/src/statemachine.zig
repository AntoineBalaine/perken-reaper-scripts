// 2. Core Data Structures & State
//    - Define all state structures
//    - Define action unions
//    - Define mode transitions
//    - Add logging points for state changes
//    - Update debug overlay to show new structures

const std = @import("std");
const c1 = @import("internals/c1.zig");
const Conf = @import("internals/config.zig");
const MapStore = @import("internals/mappings.zig");
const FxMap = MapStore.FxMap;
const track = @import("internals/track.zig");
pub const Mode = enum {

    // Main operation mode - controlling FX parameters
    fx_ctrl,

    // Module selection and FX browser
    fx_sel,

    // Mapping configuration for unmapped FX
    mapping_panel,

    // User preferences and global settings
    settings,

    // Special sub-mode of settings for configuring default channel strip
    // Could alternatively be handled as a settings panel state
    settings_default_channel_strip,

    // Optional: Additional modes you might want to consider
    startup, // Initial mode when plugin loads
    midi_learn, // Specific mode for MIDI learning (if implemented separately)
    error_state, // For handling error conditions that need user intervention
};

// Helper for valid transitions
pub const valid_transitions = std.EnumMap(Mode, []const Mode).init(.{
    .startup = &.{ .fx_ctrl, .settings },
    .fx_ctrl = &.{ .fx_sel, .settings, .mapping_panel },
    .fx_sel = &.{ .fx_ctrl, .mapping_panel },
    .mapping_panel = &.{ .fx_sel, .fx_ctrl },
    .settings = &.{ .fx_ctrl, .settings_default_channel_strip },
    .settings_default_channel_strip = &.{.settings},
    .midi_learn = &.{.mapping_panel},
    .error_state = &.{ .fx_ctrl, .settings },
});

pub const State = struct {
    current_mode: Mode,

    // Mode-specific states
    fx_ctrl: FxControlState,
    fx_sel: FxSelectionState,
    mapping: MappingState,
    settings: SettingsState,

    // Shared state that might be needed across modes
    last_touched_tr_id: ?c_int = null,
    selectedTracks: std.AutoArrayHashMapUnmanaged(c_int, void),
    gui_visible: bool,
    mappings: MapStore,
};

// Mode-specific state structures
pub const FxControlState = struct {
    // Current values of all CC controls
    CCs: c1.CCs,
    // Current parameter mappings
    fxMap: FxMap = *FxMap{},
    order: track.ModulesOrder = .@"S-EQ-C",
    scRouting: track.SCRouting = .off,
    // Display settings
    show_plugin_ui: bool,
};

pub const FxSelectionState = struct {
    current_category: Conf.ModulesList,
    selected_fx: ?[]const u8,
    scroll_position: usize,
};

pub const MappingState = struct {
    target_fx: []const u8,
    current_mappings: union {
        COMP: MapStore.Comp,
        EQ: MapStore.Eq,
        INPUT: MapStore.Inpt,
        OUTPT: MapStore.Outpt,
        GATE: MapStore.Shp,
    },
    midi_learn_active: bool,
    selected_parameter: ?u32,
};

pub const SettingsState = struct {
    show_startup_message: bool,
    show_feedback_window: bool,
    manual_routing: bool,
    default_channel_strip: DefaultsMap,
};

pub const DefaultsMap = struct {
    COMP: ?std.meta.Tuple(&.{ [*:0]const u8, MapStore.Comp }) = null,
    EQ: ?std.meta.Tuple(&.{ [*:0]const u8, MapStore.Eq }) = null,
    INPUT: ?std.meta.Tuple(&.{ [*:0]const u8, MapStore.Inpt }) = null,
    OUTPT: ?std.meta.Tuple(&.{ [*:0]const u8, MapStore.Outpt }) = null,
    GATE: ?std.meta.Tuple(&.{ [*:0]const u8, MapStore.Shp }) = null,
};
