// 2. Core Data Structures & State
//    - Define all state structures
//    - Define action unions
//    - Define mode transitions
//    - Add logging points for state changes
//    - Update debug overlay to show new structures

const std = @import("std");
const c1 = @import("c1.zig");
const MapStore = @import("mappings.zig");
const FxControlState = @import("fx_ctrl_state.zig");
const TransportState = @import("transport_actions.zig").TransportState;

pub const ModulesList = enum {
    INPUT,
    GATE,
    EQ,
    COMP,
    OUTPT,

    pub fn toModulePrefixChar(self: ModulesList) u8 {
        return switch (self) {
            .INPUT => 'I',
            .GATE => 'S', // "S" for Shape/Gate
            .EQ => 'E',
            .COMP => 'C',
            .OUTPT => 'O',
        };
    }
    pub fn toModulePrefix(self: ModulesList) [:0]const u8 {
        return switch (self) {
            .INPUT => "I",
            .GATE => "S", // "S" for Shape/Gate
            .EQ => "E",
            .COMP => "C",
            .OUTPT => "O",
        };
    }
};

pub const Mode = enum {
    /// Main operation mode - controlling FX parameters
    fx_ctrl,
    /// transport mode
    transport,
    /// Module selection and FX browser
    fx_sel,
    /// Mapping configuration for unmapped FX
    mapping_panel,
    /// User preferences and global settings
    settings,
    /// Default Fx selection - in settings
    default_fx_sel,
    /// if the user toggles the extension
    suspended,
};

// Helper for valid transitions
pub const valid_transitions = std.EnumMap(Mode, []const Mode).init(.{
    .fx_ctrl = &.{ .settings, .fx_sel, .mapping_panel, .suspended, .transport },
    .fx_sel = &.{ .fx_ctrl, .mapping_panel, .settings, .fx_sel, .suspended },
    .default_fx_sel = &.{ .settings, .default_fx_sel, .suspended },
    .mapping_panel = &.{ .fx_sel, .fx_ctrl, .suspended },
    .settings = &.{ .fx_ctrl, .transport, .suspended, .default_fx_sel },
    .suspended = &.{.fx_ctrl},
    .transport = &.{ .fx_ctrl, .settings, .fx_sel, .suspended },
});

pub const State = struct {
    current_mode: Mode = .fx_ctrl,

    // Mode-specific states
    fx_ctrl: FxControlState,
    fx_sel: FxSelectionState = .{},
    default_fx_sel: FxSelectionState = .{},
    transport: TransportState = .{},
    mapping: MappingState,

    // Shared state
    current_tr_id: ?c_int = null,
    selectedTracks: std.AutoArrayHashMapUnmanaged(c_int, void) = .{},
    fx_ctrl_gui_visible: bool = true,

    pub fn init(gpa: std.mem.Allocator) State {
        return .{
            .fx_ctrl = FxControlState.init(gpa),
            .mapping = .{
                .target_fx = "",
                .current_mappings = undefined, // Will be set when mapping starts
                .midi_learn_active = false,
                .selected_parameter = null,
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
    current_category: ModulesList = .COMP,
    scroll_position_abs: u8 = 0,
    scroll_position_rel: usize = 0,
};

pub const SettingsSelectionState = struct {
    scroll_position_abs: u8 = 0,
    scroll_position_rel: usize = 0,
};

pub const MappingState = struct {
    target_fx: [:0]const u8,
    current_mappings: union(ModulesList) {
        INPUT: MapStore.Inpt,
        GATE: MapStore.Shp,
        EQ: MapStore.Eq,
        COMP: MapStore.Comp,
        OUTPT: MapStore.Outpt,
    },
    target_mapping_filepath: ?[:0]const u8 = null,
    selected_parameter: ?u32 = null,
    selected_control: ?c1.CCs = null,
    midi_learn_active: bool = false,

    pub fn init(gpa: std.mem.Allocator, fx_name: [:0]const u8, module_type: ModulesList, map_store: *MapStore.MapStore) !MappingState {
        const maybe_mapping = map_store.get(fx_name, module_type);
        if (maybe_mapping == null) {
            return error.MappingNotFound;
        }
        const mapping = maybe_mapping.?;

        return .{
            .target_fx = try gpa.dupeZ(u8, fx_name),
            .current_mappings = switch (module_type) {
                .INPUT => .{ .INPUT = mapping.INPUT },
                .GATE => .{ .GATE = mapping.GATE },
                .EQ => .{ .EQ = mapping.EQ },
                .COMP => .{ .COMP = mapping.COMP },
                .OUTPT => .{ .OUTPT = mapping.OUTPT },
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
