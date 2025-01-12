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
const FxControlState = @import("fx_ctrl_state.zig");
const globals = @import("globals.zig");

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
    current_mode: Mode = .fx_ctrl,

    // Mode-specific states
    fx_ctrl: FxControlState,
    fx_sel: FxSelectionState,
    mapping: MappingState,
    settings: SettingsState,

    // Shared state
    last_touched_tr_id: ?c_int = null,
    selectedTracks: std.AutoArrayHashMapUnmanaged(c_int, void) = .{},
    gui_visible: bool = true,

    pub fn init(gpa: std.mem.Allocator) State {
        return .{
            .fx_ctrl = FxControlState.init(gpa),
            .fx_sel = .{
                .current_category = .COMP, // Default category
                .selected_fx = null,
                .scroll_position = 0,
            },
            .mapping = .{
                .target_fx = "",
                .current_mappings = undefined, // Will be set when mapping starts
                .midi_learn_active = false,
                .selected_parameter = null,
            },
            .settings = .{
                .show_startup_message = false,
                .show_feedback_window = true,
                .manual_routing = false,
                .default_channel_strip = .{},
            },
            // Shared state uses default values
        };
    }

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        self.fx_ctrl.deinit();
        self.selectedTracks.deinit(allocator);
        // Any other cleanup needed...
    }
};

pub const FxSelectionState = struct {
    current_category: Conf.ModulesList,
    selected_fx: ?[]const u8,
    scroll_position: usize = 0,
};

pub const MappingState = struct {
    target_fx: [:0]const u8,
    current_mappings: union(Conf.ModulesList) {
        INPUT: MapStore.Inpt,
        GATE: MapStore.Shp,
        EQ: MapStore.Eq,
        COMP: MapStore.Comp,
        OUTPT: MapStore.Outpt,
    },
    selected_parameter: ?u32 = null,
    selected_control: ?c1.CCs = null,
    midi_learn_active: bool = false,

    pub fn init(gpa: std.mem.Allocator, fx_name: [:0]const u8, module_type: Conf.ModulesList) !MappingState {
        return .{
            .target_fx = try gpa.dupeZ(u8, fx_name),
            .current_mappings = switch (module_type) {
                .COMP => globals.map_store.COMP.get(fx_name).?,
                .EQ => globals.map_store.EQ.get(fx_name).?,
                .INPUT => globals.map_store.INPUT.get(fx_name).?,
                .OUTPT => globals.map_store.OUTPT.get(fx_name).?,
                .GATE => globals.map_store.GATE.get(fx_name).?,
            },
            .selected_parameter = null,
            .selected_control = null,
            .midi_learn_active = false,
        };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        allocator.free(self.target_fx);
    }
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
