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
const StringPool = @import("string_pool").StringPool;
const TranslationKey = @import("translations.zig").TranslationKey;

pub const PhysicalModule = enum {
    INPUT,
    GATE,
    EQ,
    COMP,
    OUTPT,
};

pub const ModulesList = enum {
    INPUT,
    GATE,
    EQ,
    COMP,
    OUTPT,
    STRIP,

    pub fn toModulePrefixChar(self: ModulesList) u8 {
        return switch (self) {
            .INPUT => 'I',
            .GATE => 'S', // "S" for Shape/Gate
            .EQ => 'E',
            .COMP => 'C',
            .OUTPT => 'O',
            .STRIP => 'X',
        };
    }
    pub fn toModulePrefix(self: ModulesList) [:0]const u8 {
        return switch (self) {
            .INPUT => "I",
            .GATE => "S", // "S" for Shape/Gate
            .EQ => "E",
            .COMP => "C",
            .OUTPT => "O",
            .STRIP => "X",
        };
    }
};

pub const MappingPanelMode = enum {
    BROWSE,
    ASSIGN,
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
    /// Loading and saving the presets of the FX of the modules
    presets,
    /// if the user toggles the extension
    suspended,
};

// Helper for valid transitions
pub const valid_transitions = std.EnumMap(Mode, []const Mode).init(.{
    .fx_ctrl = &.{ .settings, .fx_sel, .mapping_panel, .suspended, .transport, .presets },
    .presets = &.{ .fx_ctrl, .suspended },
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
    presets: PresetsState,

    // Shared state
    current_tr_id: ?c_int = null,
    selectedTracks: std.AutoArrayHashMapUnmanaged(c_int, void) = .{},
    fx_ctrl_gui_visible: bool = true,

    pub fn init(gpa: std.mem.Allocator) State {
        return .{
            .fx_ctrl = FxControlState.init(gpa),
            .mapping_panel = MappingPanelState.init(),
            .presets = PresetsState.init(gpa),
            // Shared state uses default values
        };
    }

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        self.fx_ctrl.deinit();
        self.mapping_panel.deinit();
        self.presets.deinit();
        self.selectedTracks.deinit(allocator);
        // Any other cleanup needed...
    }
};

pub const PresetsPurpose = enum { load, save };

pub const PresetsStage = enum {
    /// The modules, each with the FX that it has
    modules,
    /// The presets of the FX of the module that was chosen, to load one
    presets,
    /// The name to save the preset under
    name,
    /// The name is the one of a preset that exists
    overwrite,
};

pub const PresetsMessage = enum { none, no_presets, unsupported_fx, save_failed };

pub const PresetsRow = struct {
    module: ModulesList,
    /// Null when the module has no FX on the track
    fx_index: ?c_int,
    fx_name: [:0]const u8,
};

/// The screen that loads or saves the presets of the FX of the modules.
pub const PresetsState = struct {
    /// Holds the rows, the names and everything else that the screen shows, until it is entered again.
    arena: std.heap.ArenaAllocator,
    purpose: PresetsPurpose = .load,
    stage: PresetsStage = .modules,
    rows: []const PresetsRow = &.{},
    module_cursor: usize = 0,
    /// The FX of the module that was chosen
    fx_index: c_int = 0,
    names: []const [:0]const u8 = &.{},
    preset_cursor: usize = 0,
    name_buffer: [256:0]u8 = @splat(0),
    message: PresetsMessage = .none,
    /// Set when the cursor moved, so that the list scrolls to it
    scroll_changed: bool = false,
    /// The position that the legacy knob had when it last scrolled the list
    scroll_position_abs: u8 = 0,

    pub fn init(gpa: std.mem.Allocator) PresetsState {
        return .{ .arena = std.heap.ArenaAllocator.init(gpa) };
    }

    /// Forgets what the screen showed, for a new visit
    pub fn reset(self: *PresetsState, purpose: PresetsPurpose) void {
        _ = self.arena.reset(.retain_capacity);
        self.* = .{ .arena = self.arena, .purpose = purpose };
    }

    pub fn deinit(self: *PresetsState) void {
        self.arena.deinit();
    }

    pub fn nameSlice(self: *const PresetsState) []const u8 {
        return std.mem.sliceTo(&self.name_buffer, 0);
    }
};

pub const FxSelSubMode = union(enum) {
    browse_fx,
    select_mapping: struct {
        /// The display name of the FX whose mappings we are browsing.
        fx_name: [:0]const u8,
        /// The StringPool offset for this FX. We use this to look up the
        /// mapping list in mappings_list, because the StringPool stores
        /// both FX names and mapping names by offset.
        fx_string_pool_offset: StringPool.StringRef,
        scroll_position_abs: u8 = 0,
        scroll_position_rel: usize = 0,
    },
};

pub const FxSelectionState = struct {
    current_category: ModulesList = .COMP,
    scroll_position_abs: u8 = 0,
    scroll_position_rel: usize = 0,
    sub_mode: FxSelSubMode = .browse_fx,
    scroll_changed: bool = false,
};

pub const SettingsSelectionState = struct {
    scroll_position_abs: u8 = 0,
    scroll_position_rel: usize = 0,
};

pub const BrowseState = struct {
    selected_module: ModulesList = .INPUT,
    scroll_position_abs: u8 = 0,
    scroll_position_rel: usize = 0,
    available_modules: [std.enums.values(ModulesList).len]?[:0]const u8 = @splat(null),
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

pub const ParamStore = struct {
    strings: StringPool,
    params: std.ArrayListUnmanaged(ParamEntry),
    allocator: std.mem.Allocator,

    pub const ParamEntry = struct {
        index: i32,
        name_offset: StringPool.StringRef,
    };

    pub fn init(gpa: std.mem.Allocator) ParamStore {
        return .{
            .strings = .empty,
            .params = .empty,
            .allocator = gpa,
        };
    }

    pub fn deinit(self: *ParamStore) void {
        self.strings.deinit(self.allocator);
        self.params.deinit(self.allocator);
        self.strings = .empty;
        self.params = .empty;
    }

    pub fn clear(self: *ParamStore) void {
        self.strings.clear();
        self.params.clearRetainingCapacity();
    }

    pub fn addParam(self: *ParamStore, index: i32, name: [:0]const u8) !void {
        const name_offset = try self.strings.intern(self.allocator, name);
        try self.params.append(self.allocator, .{
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

pub const AssignState = struct {
    target_fx: [:0]const u8,
    current_mappings: MapStore.TaggedMapping,
    selected_parameter: ?u32,
    selected_control: ?c1.CCs,
    learned_param: ?u32,
    midi_learn_active: bool,
    /// The FX chain index of the plugin being assigned, so that MIDI learn
    /// capture can verify that a touched parameter belongs to the correct FX.
    assign_fx_index: ?c_int,
    param_store: ParamStore,
    arena: std.heap.ArenaAllocator,
    knob_values: [128]f32,
    /// Because the UI needs to display FX names per module without calling
    /// REAPER APIs, we cache them here when entering assign mode.
    module_fx_names: std.EnumArray(PhysicalModule, ?[:0]const u8),
    /// translation key for the save mapping’s error message
    save_error: ?TranslationKey,
    /// Contiguous storage for preset name strings, used by the preset dropdown.
    /// The caller must call initPresetStrings() after placement to set the allocator.
    /// This field is undefined until then.
    preset_strings: StringPool,
    /// Refs into preset_strings for each available preset name
    preset_name_offsets: []const StringPool.StringRef,
    /// Currently selected preset (ref into preset_strings), or null for no preset
    selected_preset: ?StringPool.StringRef,
    /// Whether to embed preset data in the map file when saving
    store_preset_data: bool,

    const defaults: AssignState = .{
        .target_fx = "",
        .current_mappings = undefined,
        .selected_parameter = null,
        .selected_control = null,
        .learned_param = null,
        .midi_learn_active = false,
        .assign_fx_index = null,
        .param_store = undefined,
        .arena = undefined,
        .knob_values = @splat(0.5),
        .module_fx_names = std.EnumArray(PhysicalModule, ?[:0]const u8).initFill(null),
        .save_error = null,
        .preset_strings = .empty,
        .preset_name_offsets = &.{},
        .selected_preset = null,
        .store_preset_data = false,
    };

    pub const FxParameter = struct {
        index: u32,
        name: [:0]const u8,
    };

    pub fn init(gpa: std.mem.Allocator, mappings: MapStore.TaggedMapping) AssignState {
        var state: AssignState = .defaults;
        state.current_mappings = mappings;
        state.param_store = ParamStore.init(gpa);
        state.arena = std.heap.ArenaAllocator.init(gpa);
        return state;
    }

    pub fn initPresetStrings(self: *AssignState, gpa: std.mem.Allocator) void {
        _ = gpa;
        self.preset_strings = .empty;
    }

    pub fn deinit(self: *AssignState) void {
        self.param_store.deinit();
        self.preset_strings.deinit(self.arena.allocator());
        self.arena.deinit();
    }
};

pub const MapSubMode = union(enum) {
    browse: BrowseState,
    assign: AssignState,
};

pub const MappingPanelState = struct {
    mode: MapSubMode,
    gpa_int: std.heap.DebugAllocator(.{}),

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
