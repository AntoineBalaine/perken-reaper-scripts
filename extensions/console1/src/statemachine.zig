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
const TransportState = @import("action_types.zig").TransportState;
const StringPool = @import("string_pool.zig").StringPool;

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
        self.mapping_panel.deinit();
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
    arena: std.heap.ArenaAllocator,

    pub fn init(gpa: std.mem.Allocator) BrowseState {
        return BrowseState{
            .arena = std.heap.ArenaAllocator.init(gpa),
        };
    }

    pub fn deinit(self: *BrowseState) void {
        self.arena.deinit();
    }
};

pub const ModuleMappings = union(ModulesList) {
    INPUT: MapStore.Inpt,
    GATE: MapStore.Shp,
    EQ: MapStore.Eq,
    COMP: MapStore.Comp,
    OUTPT: MapStore.Outpt,
};

pub const ParamStore = struct {
    strings: StringPool,
    params: std.ArrayListUnmanaged(ParamEntry),

    pub const ParamEntry = struct {
        index: i32,
        name_offset: u32,
    };

    pub fn init(gpa: std.mem.Allocator) ParamStore {
        return .{
            .strings = StringPool.init(gpa),
            .params = .{},
        };
    }

    pub fn deinit(self: *ParamStore) void {
        self.strings.deinit();
    }

    pub fn clear(self: *ParamStore) void {
        self.strings.clear();
        self.params.clearRetainingCapacity();
    }

    pub fn addParam(self: *ParamStore, index: i32, name: [:0]const u8) !void {
        const name_offset = try self.strings.intern(name);
        const allocator = self.strings.arena.allocator();
        try self.params.append(allocator, .{
            .index = index,
            .name_offset = name_offset,
        });
    }

    pub fn len(self: *const ParamStore) usize {
        return self.params.items.len;
    }

    pub fn getName(self: *const ParamStore, param_idx: usize) [:0]const u8 {
        const entry = self.params.items[param_idx];
        return self.strings.get(entry.name_offset);
    }

    pub fn getIndex(self: *const ParamStore, param_idx: usize) i32 {
        return self.params.items[param_idx].index;
    }
};

pub const MidiLearnPhase = enum {
    idle,
    listening_cc,
    listening_param,
};

pub const AssignState = struct {
    target_fx: [:0]const u8 = "",
    current_mappings: ModuleMappings,
    selected_parameter: ?u32 = null,
    selected_control: ?c1.CCs = null,
    midi_learn: MidiLearnPhase = .idle,
    param_store: ParamStore,
    arena: std.heap.ArenaAllocator,
    // Because the UI needs to display FX names per module without calling
    // REAPER APIs, we cache them here when entering assign mode.
    module_fx_names: std.EnumArray(ModulesList, ?[:0]const u8) = std.EnumArray(ModulesList, ?[:0]const u8).initFill(null),

    pub const FxParameter = struct {
        index: u32,
        name: [:0]const u8,
    };

    pub fn init(gpa: std.mem.Allocator, mappings: ModuleMappings) AssignState {
        return AssignState{
            .current_mappings = mappings,
            .param_store = ParamStore.init(gpa),
            .arena = std.heap.ArenaAllocator.init(gpa),
        };
    }

    pub fn deinit(self: *AssignState) void {
        self.param_store.deinit();
        self.arena.deinit();
    }
};

pub const SaveState = struct {
    name_buffer: [512]u8 = [_]u8{0} ** 512,
    existing_presets: std.ArrayListUnmanaged([:0]const u8) = .{},
    show_overwrite_confirm: bool = false,
    pending_name: [:0]const u8 = "",
    // Because we need access to assign data when saving, we preserve it here
    target_fx: [:0]const u8 = "",
    current_mappings: ModuleMappings,
    arena: std.heap.ArenaAllocator,

    pub fn init(gpa: std.mem.Allocator, mappings: ModuleMappings) SaveState {
        return SaveState{
            .current_mappings = mappings,
            .arena = std.heap.ArenaAllocator.init(gpa),
        };
    }

    pub fn deinit(self: *SaveState) void {
        self.arena.deinit();
    }
};

pub const MapSubMode = union(enum) {
    browse: BrowseState,
    assign: AssignState,
    save: SaveState,
};

pub const MappingPanelState = struct {
    mode: MapSubMode,
    gpa_int: std.heap.GeneralPurposeAllocator(.{}),

    pub fn init() MappingPanelState {
        var self = MappingPanelState{
            .gpa_int = .{},
            .mode = undefined,
        };
        self.mode = .{
            .browse = BrowseState.init(self.gpa_int.allocator()),
        };
        return self;
    }

    pub fn deinitCurrentSubMode(self: *MappingPanelState) void {
        switch (self.mode) {
            .browse => |*browse| browse.deinit(),
            .assign => |*assign| assign.deinit(),
            .save => |*save| save.deinit(),
        }
    }

    pub fn deinit(self: *MappingPanelState) void {
        self.deinitCurrentSubMode();

        const deinit_status = self.gpa_int.deinit();
        if (deinit_status == .leak) {
            std.log.err("Memory leak detected in mapping panel sub-states", .{});
        }
    }
};
