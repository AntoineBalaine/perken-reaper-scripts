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

pub const MappingPanelMode = enum {
    BROWSE,
    ASSIGN,
    SAVE,
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
    mapping_panel: MappingPanelState,

    // Shared state
    current_tr_id: ?c_int = null,
    selectedTracks: std.AutoArrayHashMapUnmanaged(c_int, void) = .{},
    fx_ctrl_gui_visible: bool = true,

    pub fn init(gpa: std.mem.Allocator) State {
        return .{
            .fx_ctrl = FxControlState.init(gpa),
            .mapping_panel = MappingPanelState.init(),
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

pub const BrowseState = struct {
    selected_module: ModulesList = .INPUT,
    scroll_position_abs: u8 = 0,
    scroll_position_rel: usize = 0,
    available_modules: [5]?[:0]const u8 = [_]?[:0]const u8{null} ** 5,
};

pub const ModuleMappings = union(ModulesList) {
    INPUT: MapStore.Inpt,
    GATE: MapStore.Shp,
    EQ: MapStore.Eq,
    COMP: MapStore.Comp,
    OUTPT: MapStore.Outpt,
};

pub const AssignState = struct {
    target_fx: [:0]const u8 = "",
    current_mappings: ModuleMappings,
    selected_parameter: ?u32 = null,
    selected_control: ?c1.CCs = null,
    midi_learn_active: bool = false,
};

pub const SaveState = struct {
    name_buffer: [512]u8 = [_]u8{0} ** 512,
    existing_presets: std.ArrayListUnmanaged([:0]const u8) = .{},
    show_overwrite_confirm: bool = false,
    pending_name: [:0]const u8 = "",
    // Because we need access to assign data when saving, we preserve it here
    target_fx: [:0]const u8 = "",
    current_mappings: ModuleMappings,

    pub fn init(allocator: std.mem.Allocator) SaveState {
        return SaveState{
            .existing_presets = std.ArrayList([]const u8).init(allocator),
            .current_mappings = .{ .INPUT = MapStore.Inpt{} },
        };
    }
};

pub const MapSubMode = union(enum) {
    browse: BrowseState,
    assign: AssignState,
    save: SaveState,
};

pub const MappingPanelState = struct {
    mode: MapSubMode,

    pub fn init() MappingPanelState {
        return MappingPanelState{
            .mode = .{
                .browse = BrowseState{},
            },
        };
    }
};
