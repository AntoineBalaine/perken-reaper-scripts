const std = @import("std");
const zlowcheck = @import("zlowcheck");
const Command = zlowcheck.Command;
const CommandList = zlowcheck.CommandList;
const StatefulConfig = zlowcheck.StatefulConfig;
const FinitePrng = zlowcheck.FinitePrng;
const assertStateful = zlowcheck.assertStateful;

const Globals = @import("../globals.zig");
const statemachine = @import("../statemachine.zig");
const ModulesList = statemachine.ModulesList;
const MappingPanelMode = statemachine.MappingPanelMode;
const Mode = statemachine.Mode;
const mapping_actions = @import("../mapping_actions.zig");
const MappingPanelAction = mapping_actions.MappingPanelAction;
const mappings = @import("../mappings.zig");
const TaggedMapping = mappings.TaggedMapping;
const c1 = @import("../c1.zig");
const fs_helpers = @import("../fs_helpers.zig");

const MockFileSystem = fs_helpers.MockFileSystem;

// Simplified Model representing the hierarchical state machine
const Model = struct {
    // Mode state
    current_mode: Mode = .fx_ctrl,
    sub_mode: ?MappingPanelMode = null,

    // Track state - simplified FX information
    modules: std.EnumArray(ModulesList, ?FxInfo) = std.EnumArray(ModulesList, ?FxInfo).initFill(null),

    // Browser state (BROWSE sub-mode)
    selected_module: ModulesList = .INPUT,

    // Edit state (ASSIGN sub-mode)
    current_mappings: ?TaggedMapping = null,

    pub fn init() Model {
        var model = Model{};
        // Initialize some modules with FX
        model.modules.set(.INPUT, FxInfo{ .name = "VST: Input", .param_count = 5 });
        model.modules.set(.COMP, FxInfo{ .name = "VST: ReaComp", .param_count = 8 });
        model.modules.set(.EQ, FxInfo{ .name = "VST: ReaEQ", .param_count = 10 });
        return model;
    }

    pub fn reset(self: *Model) void {
        self.current_mode = .fx_ctrl;
        self.sub_mode = null;
        self.selected_module = .INPUT;
        self.current_mappings = null;
    }
};

const FxInfo = struct {
    name: []const u8,
    param_count: u8,
};

// System Under Test - wraps real Globals
const System = struct {
    globals: Globals,
    allocator: std.mem.Allocator,
    mock_fs: *MockFileSystem,
    resource_path: [:0]const u8,

    pub fn init(allocator: std.mem.Allocator) !System {
        const mock_fs = try allocator.create(MockFileSystem);
        mock_fs.* = try MockFileSystem.init(allocator);

        // Get temp directory absolute path
        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
        const temp_path = try mock_fs.temp_dir.dir.realpath(".", &path_buffer);
        const temp_path_owned = try allocator.dupeZ(u8, temp_path);
        defer allocator.free(temp_path_owned);

        // Use real filesystem to copy embedded files to temp dir
        const real_fs = fs_helpers.RealFileSystem.fileSystemOps();
        try fs_helpers.copyEmbeddedFilesToDir(real_fs, temp_path_owned);

        // Build resource_path pointing to temp Console1 directory
        const resource_path = try std.fs.path.joinZ(allocator, &.{
            temp_path_owned, "Data", "Perken", "Console1",
        });

        // Create test Globals
        var g = try Globals.defaults(allocator);
        g.resource_path = resource_path;
        g.fs_ops = mock_fs.fileSystemOps();
        g.state.current_mode = .fx_ctrl;
        // Initialize module_locations with null values since TrackState doesn't initialize it by default
        g.state.fx_ctrl.track_state.module_locations = @TypeOf(g.state.fx_ctrl.track_state.module_locations).initFill(null);

        return System{
            .globals = g,
            .allocator = allocator,
            .mock_fs = mock_fs,
            .resource_path = resource_path,
        };
    }

    pub fn reset(self: *System) void {
        // Because we need to reset the system to initial state, we reset to fx_ctrl mode
        self.globals.state.current_mode = .fx_ctrl;
        self.globals.state.mapping_panel.deinitCurrentSubMode();
        self.globals.state.mapping_panel.mode = .{ .browse = statemachine.BrowseState.init(self.globals.state.mapping_panel.gpa_int.allocator()) };
    }

    pub fn deinit(self: *System) void {
        self.allocator.free(self.resource_path);
        self.mock_fs.deinit();
        self.allocator.destroy(self.mock_fs);

        self.globals.state.mapping_panel.deinit();
        _ = self.globals.arena_int.reset(.free_all);
    }

    /// Sets up a module location entry for testing. This simulates the state where
    /// a track has an FX assigned to a module slot but no custom mapping exists yet.
    pub fn setupModuleLocation(self: *System, module: ModulesList, fx_index: c_int) void {
        self.globals.state.fx_ctrl.track_state.module_locations.set(module, .{
            .fx_index = fx_index,
            .mapping = null,
        });
    }
};

// ============================================================================
// Sub-mode Transition Commands
// ============================================================================

const EnterBrowse = struct {
    pub const name = "enter_browse";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        return model.current_mode == .fx_ctrl;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.current_mode = .mapping_panel;
        model.sub_mode = .BROWSE;
        model.selected_module = .INPUT;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Because enter_browse doesn't change the mode (only sub_mode), we need to change it manually
        // Execute mode change first
        sut.globals.state.current_mode = .mapping_panel;
        // Then execute action on SUT
        mapping_actions.mappingPanelActions(&sut.globals, .enter_browse);

        // Update model
        self.onModelOnly(model);

        // Verify synchronization
        return sut.globals.state.current_mode == .mapping_panel and
            sut.globals.state.mapping_panel.mode == .browse;
    }
};

const EnterAssign = struct {
    module: ModulesList,
    pub const name = "enter_assign";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        // Because we can only enter ASSIGN from BROWSE sub-mode, we verify the precondition
        return model.current_mode == .mapping_panel and
            model.sub_mode == .BROWSE and
            model.modules.get(self.module) != null;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        model.sub_mode = .ASSIGN;
        // Initialize empty mapping
        model.current_mappings = switch (self.module) {
            .INPUT => .{ .INPUT = mappings.Inpt{} },
            .GATE => .{ .GATE = mappings.Shp{} },
            .EQ => .{ .EQ = mappings.Eq{} },
            .COMP => .{ .COMP = mappings.Comp{} },
            .OUTPT => .{ .OUTPT = mappings.Outpt{} },
        };
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Execute action on SUT
        mapping_actions.mappingPanelActions(&sut.globals, .{ .enter_assign = self.module });

        // Update model
        self.onModelOnly(model);

        // Verify synchronization
        return switch (sut.globals.state.mapping_panel.mode) {
            .assign => |s| std.meta.activeTag(s.current_mappings) == self.module,
            else => false,
        };
    }
};

const EnterSave = struct {
    pub const name = "enter_save";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        // Because we can only enter SAVE from ASSIGN sub-mode, we verify the precondition
        return model.current_mode == .mapping_panel and model.sub_mode == .ASSIGN;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.sub_mode = .SAVE;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Execute action on SUT
        mapping_actions.mappingPanelActions(&sut.globals, .enter_save);

        // Update model
        self.onModelOnly(model);

        // Verify synchronization
        return sut.globals.state.mapping_panel.mode == .save;
    }
};

const ExitToFxCtrl = struct {
    pub const name = "exit_to_fx_ctrl";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        // Because we can exit from any sub-mode, we only check we're in mapping_panel mode
        return model.current_mode == .mapping_panel;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.current_mode = .fx_ctrl;
        model.sub_mode = null;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Execute action on SUT
        mapping_actions.mappingPanelActions(&sut.globals, .exit_to_fx_ctrl);

        // Update model
        self.onModelOnly(model);

        // Verify synchronization
        return sut.globals.state.current_mode == .fx_ctrl;
    }
};

// ============================================================================
// BROWSE Sub-mode Commands
// ============================================================================

const ScrollBrowse = struct {
    target_module: ModulesList,
    pub const name = "scroll_browse";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        // Because we can only scroll in BROWSE sub-mode, we verify the precondition
        return model.current_mode == .mapping_panel and model.sub_mode == .BROWSE;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        model.selected_module = self.target_module;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Execute action on SUT
        mapping_actions.mappingPanelActions(&sut.globals, .{ .browse_select_module = self.target_module });

        // Update model
        self.onModelOnly(model);

        // Verify synchronization
        return switch (sut.globals.state.mapping_panel.mode) {
            .browse => |s| s.selected_module == self.target_module,
            else => false,
        };
    }
};

const ConfirmBrowse = struct {
    pub const name = "confirm_browse";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        // Because ConfirmBrowse transitions to ASSIGN with selected module, we verify the precondition
        return model.current_mode == .mapping_panel and
            model.sub_mode == .BROWSE and
            model.modules.get(model.selected_module) != null;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.sub_mode = .ASSIGN;
        // Initialize empty mapping
        model.current_mappings = switch (model.selected_module) {
            .INPUT => .{ .INPUT = mappings.Inpt{} },
            .GATE => .{ .GATE = mappings.Shp{} },
            .EQ => .{ .EQ = mappings.Eq{} },
            .COMP => .{ .COMP = mappings.Comp{} },
            .OUTPT => .{ .OUTPT = mappings.Outpt{} },
        };
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Execute action on SUT
        mapping_actions.mappingPanelActions(&sut.globals, .browse_confirm);

        // Update model
        self.onModelOnly(model);

        // Verify synchronization
        return switch (sut.globals.state.mapping_panel.mode) {
            .assign => |s| std.meta.activeTag(s.current_mappings) == model.selected_module,
            else => false,
        };
    }
};

const CancelBrowse = struct {
    pub const name = "cancel_browse";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        // Because CancelBrowse exits to fx_ctrl, we verify we're in BROWSE sub-mode
        return model.current_mode == .mapping_panel and model.sub_mode == .BROWSE;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.current_mode = .fx_ctrl;
        model.sub_mode = null;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Execute action on SUT
        mapping_actions.mappingPanelActions(&sut.globals, .browse_cancel);

        // Update model
        self.onModelOnly(model);

        // Verify synchronization
        return sut.globals.state.current_mode == .fx_ctrl;
    }
};

// ============================================================================
// ASSIGN Sub-mode Commands
// ============================================================================

const AddMapping = struct {
    control: c1.CCs,
    param: u8,
    pub const name = "add_mapping";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        // Because we can only add mappings in ASSIGN sub-mode, we verify the precondition
        return model.current_mode == .mapping_panel and
            model.sub_mode == .ASSIGN and
            model.current_mappings != null;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        // Because we need to update the mapping in the model, we switch on the module type
        if (model.current_mappings) |*mapping| {
            switch (mapping.*) {
                .COMP => |*comp| switch (self.control) {
                    .Comp_Attack => comp.Comp_Attack = self.param,
                    .Comp_DryWet => comp.Comp_DryWet = self.param,
                    .Comp_Ratio => comp.Comp_Ratio = self.param,
                    .Comp_Release => comp.Comp_Release = self.param,
                    .Comp_Thresh => comp.Comp_Thresh = self.param,
                    .Comp_comp => comp.Comp_comp = self.param,
                    else => {},
                },
                .EQ => |*eq| switch (self.control) {
                    .Eq_HiFrq => eq.Eq_HiFrq = self.param,
                    .Eq_HiGain => eq.Eq_HiGain = self.param,
                    .Eq_HiMidFrq => eq.Eq_HiMidFrq = self.param,
                    .Eq_HiMidGain => eq.Eq_HiMidGain = self.param,
                    .Eq_HiMidQ => eq.Eq_HiMidQ = self.param,
                    .Eq_LoFrq => eq.Eq_LoFrq = self.param,
                    .Eq_LoGain => eq.Eq_LoGain = self.param,
                    .Eq_LoMidFrq => eq.Eq_LoMidFrq = self.param,
                    .Eq_LoMidGain => eq.Eq_LoMidGain = self.param,
                    .Eq_LoMidQ => eq.Eq_LoMidQ = self.param,
                    .Eq_eq => eq.Eq_eq = self.param,
                    .Eq_hp_shape => eq.Eq_hp_shape = self.param,
                    .Eq_lp_shape => eq.Eq_lp_shape = self.param,
                    else => {},
                },
                .INPUT => |*input| switch (self.control) {
                    .Inpt_Gain => input.Inpt_Gain = self.param,
                    .Inpt_HiCut => input.Inpt_HiCut = self.param,
                    .Inpt_LoCut => input.Inpt_LoCut = self.param,
                    .Inpt_disp_mode => input.Inpt_disp_mode = self.param,
                    .Inpt_disp_on => input.Inpt_disp_on = self.param,
                    .Inpt_filt_to_comp => input.Inpt_filt_to_comp = self.param,
                    // .Inpt_phase_inv => input.Inpt_phase_inv = self.param,
                    .Inpt_preset => input.Inpt_preset = self.param,
                    else => {},
                },
                .OUTPT => |*output| switch (self.control) {
                    .Out_Drive => output.Out_Drive = self.param,
                    .Out_DriveChar => output.Out_DriveChar = self.param,
                    .Out_Pan => output.Out_Pan = self.param,
                    .Out_Vol => output.Out_Vol = self.param,
                    else => {},
                },
                .GATE => |*gate| switch (self.control) {
                    .Shp_Gate => gate.Shp_Gate = self.param,
                    .Shp_GateRelease => gate.Shp_GateRelease = self.param,
                    .Shp_Punch => gate.Shp_Punch = self.param,
                    .Shp_hard_gate => gate.Shp_hard_gate = self.param,
                    .Shp_shape => gate.Shp_shape = self.param,
                    .Shp_sustain => gate.Shp_sustain = self.param,
                    else => {},
                },
            }
        }
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Execute action on SUT
        mapping_actions.mappingPanelActions(&sut.globals, .{ .assign_add_mapping = .{ .param = self.param, .control = self.control } });

        // Update model
        self.onModelOnly(model);

        // Verify synchronization - check that the mapping was added
        const sut_mappings = switch (sut.globals.state.mapping_panel.mode) {
            .assign => |s| s.current_mappings,
            else => return false,
        };
        const model_mappings = model.current_mappings orelse return false;

        // Because we need to verify the specific control was mapped, we switch on module type
        return switch (sut_mappings) {
            .COMP => |comp| switch (self.control) {
                .Comp_Attack => comp.Comp_Attack == self.param,
                .Comp_DryWet => comp.Comp_DryWet == self.param,
                .Comp_Ratio => comp.Comp_Ratio == self.param,
                .Comp_Release => comp.Comp_Release == self.param,
                .Comp_Thresh => comp.Comp_Thresh == self.param,
                .Comp_comp => comp.Comp_comp == self.param,
                else => true,
            },
            .EQ => |eq| switch (self.control) {
                .Eq_HiFrq => eq.Eq_HiFrq == self.param,
                .Eq_HiGain => eq.Eq_HiGain == self.param,
                else => true,
            },
            .INPUT => |input| switch (self.control) {
                .Inpt_Gain => input.Inpt_Gain == self.param,
                .Inpt_HiCut => input.Inpt_HiCut == self.param,
                else => true,
            },
            .OUTPT => |output| switch (self.control) {
                .Out_Drive => output.Out_Drive == self.param,
                .Out_Vol => output.Out_Vol == self.param,
                else => true,
            },
            .GATE => |gate| switch (self.control) {
                .Shp_Gate => gate.Shp_Gate == self.param,
                .Shp_shape => gate.Shp_shape == self.param,
                else => true,
            },
        } and std.meta.activeTag(model_mappings) == std.meta.activeTag(sut_mappings);
    }
};

const RemoveMapping = struct {
    control: c1.CCs,
    pub const name = "remove_mapping";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        // Because we can only remove mappings in ASSIGN sub-mode, we verify the precondition
        return model.current_mode == .mapping_panel and
            model.sub_mode == .ASSIGN and
            model.current_mappings != null;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        // Because we need to remove the mapping from the model, we switch on the module type
        if (model.current_mappings) |*mapping| {
            switch (mapping.*) {
                .COMP => |*comp| switch (self.control) {
                    .Comp_Attack => comp.Comp_Attack = null,
                    .Comp_DryWet => comp.Comp_DryWet = null,
                    .Comp_Ratio => comp.Comp_Ratio = null,
                    .Comp_Release => comp.Comp_Release = null,
                    .Comp_Thresh => comp.Comp_Thresh = null,
                    .Comp_comp => comp.Comp_comp = null,
                    else => {},
                },
                .EQ => |*eq| switch (self.control) {
                    .Eq_HiFrq => eq.Eq_HiFrq = null,
                    .Eq_HiGain => eq.Eq_HiGain = null,
                    .Eq_HiMidFrq => eq.Eq_HiMidFrq = null,
                    .Eq_HiMidGain => eq.Eq_HiMidGain = null,
                    .Eq_HiMidQ => eq.Eq_HiMidQ = null,
                    .Eq_LoFrq => eq.Eq_LoFrq = null,
                    .Eq_LoGain => eq.Eq_LoGain = null,
                    .Eq_LoMidFrq => eq.Eq_LoMidFrq = null,
                    .Eq_LoMidGain => eq.Eq_LoMidGain = null,
                    .Eq_LoMidQ => eq.Eq_LoMidQ = null,
                    .Eq_eq => eq.Eq_eq = null,
                    .Eq_hp_shape => eq.Eq_hp_shape = null,
                    .Eq_lp_shape => eq.Eq_lp_shape = null,
                    else => {},
                },
                .INPUT => |*input| switch (self.control) {
                    .Inpt_Gain => input.Inpt_Gain = null,
                    .Inpt_HiCut => input.Inpt_HiCut = null,
                    .Inpt_LoCut => input.Inpt_LoCut = null,
                    .Inpt_disp_mode => input.Inpt_disp_mode = null,
                    .Inpt_disp_on => input.Inpt_disp_on = null,
                    .Inpt_filt_to_comp => input.Inpt_filt_to_comp = null,
                    // .Inpt_phase_inv => input.Inpt_phase_inv = null,
                    .Inpt_preset => input.Inpt_preset = null,
                    else => {},
                },
                .OUTPT => |*output| switch (self.control) {
                    .Out_Drive => output.Out_Drive = null,
                    .Out_DriveChar => output.Out_DriveChar = null,
                    .Out_Pan => output.Out_Pan = null,
                    .Out_Vol => output.Out_Vol = null,
                    else => {},
                },
                .GATE => |*gate| switch (self.control) {
                    .Shp_Gate => gate.Shp_Gate = null,
                    .Shp_GateRelease => gate.Shp_GateRelease = null,
                    .Shp_Punch => gate.Shp_Punch = null,
                    .Shp_hard_gate => gate.Shp_hard_gate = null,
                    .Shp_shape => gate.Shp_shape = null,
                    .Shp_sustain => gate.Shp_sustain = null,
                    else => {},
                },
            }
        }
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Execute action on SUT
        mapping_actions.mappingPanelActions(&sut.globals, .{ .assign_remove_mapping = self.control });

        // Update model
        self.onModelOnly(model);

        // Verify synchronization - check that the mapping was removed
        const sut_mappings = switch (sut.globals.state.mapping_panel.mode) {
            .assign => |s| s.current_mappings,
            else => return false,
        };

        // Because we need to verify the specific control was unmapped, we switch on module type
        return switch (sut_mappings) {
            .COMP => |comp| switch (self.control) {
                .Comp_Attack => comp.Comp_Attack == null,
                .Comp_DryWet => comp.Comp_DryWet == null,
                .Comp_Ratio => comp.Comp_Ratio == null,
                .Comp_Release => comp.Comp_Release == null,
                .Comp_Thresh => comp.Comp_Thresh == null,
                .Comp_comp => comp.Comp_comp == null,
                else => true,
            },
            .EQ => |eq| switch (self.control) {
                .Eq_HiFrq => eq.Eq_HiFrq == null,
                .Eq_HiGain => eq.Eq_HiGain == null,
                else => true,
            },
            .INPUT => |input| switch (self.control) {
                .Inpt_Gain => input.Inpt_Gain == null,
                .Inpt_HiCut => input.Inpt_HiCut == null,
                else => true,
            },
            .OUTPT => |output| switch (self.control) {
                .Out_Drive => output.Out_Drive == null,
                .Out_Vol => output.Out_Vol == null,
                else => true,
            },
            .GATE => |gate| switch (self.control) {
                .Shp_Gate => gate.Shp_Gate == null,
                .Shp_shape => gate.Shp_shape == null,
                else => true,
            },
        };
    }
};

const RequestSave = struct {
    pub const name = "request_save";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        // Because RequestSave transitions to SAVE sub-mode, we verify we're in ASSIGN sub-mode
        return model.current_mode == .mapping_panel and model.sub_mode == .ASSIGN;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.sub_mode = .SAVE;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Execute action on SUT
        mapping_actions.mappingPanelActions(&sut.globals, .assign_request_save);

        // Update model
        self.onModelOnly(model);

        // Verify synchronization
        return sut.globals.state.mapping_panel.mode == .save;
    }
};

const CancelAssign = struct {
    pub const name = "cancel_assign";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        // Because CancelAssign exits to fx_ctrl, we verify we're in ASSIGN sub-mode
        return model.current_mode == .mapping_panel and model.sub_mode == .ASSIGN;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.current_mode = .fx_ctrl;
        model.sub_mode = null;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Execute action on SUT
        mapping_actions.mappingPanelActions(&sut.globals, .assign_cancel);

        // Update model
        self.onModelOnly(model);

        // Verify synchronization
        return sut.globals.state.current_mode == .fx_ctrl;
    }
};

// ============================================================================
// SAVE Sub-mode Commands
// ============================================================================

const SavePreset = struct {
    pub const name = "save_preset";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        // Because SavePreset completes the workflow and exits to fx_ctrl, we verify we're in SAVE sub-mode
        return model.current_mode == .mapping_panel and model.sub_mode == .SAVE;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.current_mode = .fx_ctrl;
        model.sub_mode = null;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Set target_fx to a test value since REAPER isn't available in tests
        sut.globals.state.mapping_panel.mode.save.target_fx = "VST: Test Plugin";

        // Execute action on SUT
        const preset_name = "test_preset";
        mapping_actions.mappingPanelActions(&sut.globals, .{ .save_confirm = preset_name });

        // Update model
        self.onModelOnly(model);

        // Verify: mode transitioned to fx_ctrl
        // Note: We don't verify module_locations here because in the stateful test,
        // module_locations is not populated (no REAPER track). The save_confirm
        // update only happens when there's an existing module_location entry.
        // The dedicated unit test verifies this behavior.
        return sut.globals.state.current_mode == .fx_ctrl;
    }
};

const CancelSave = struct {
    pub const name = "cancel_save";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        // Because CancelSave returns to ASSIGN sub-mode, we verify we're in SAVE sub-mode
        return model.current_mode == .mapping_panel and model.sub_mode == .SAVE;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.sub_mode = .ASSIGN;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Execute action on SUT
        mapping_actions.mappingPanelActions(&sut.globals, .save_cancel);

        // Update model
        self.onModelOnly(model);

        // Verify synchronization
        return sut.globals.state.mapping_panel.mode == .assign;
    }
};

// ============================================================================
// Test Entry Point
// ============================================================================

test "mapping panel hierarchical state machine" {
    const allocator = std.testing.allocator;

    // Initialize model and system
    var model = Model.init();
    var sut = try System.init(allocator);
    defer sut.deinit();

    // Create command instances
    var enter_browse_cmd = EnterBrowse{};
    var enter_assign_comp = EnterAssign{ .module = .COMP };
    var enter_assign_eq = EnterAssign{ .module = .EQ };
    var enter_assign_input = EnterAssign{ .module = .INPUT };
    var enter_save_cmd = EnterSave{};
    var exit_cmd = ExitToFxCtrl{};

    var scroll_comp = ScrollBrowse{ .target_module = .COMP };
    var scroll_eq = ScrollBrowse{ .target_module = .EQ };
    var scroll_input = ScrollBrowse{ .target_module = .INPUT };
    var confirm_browse_cmd = ConfirmBrowse{};
    var cancel_browse_cmd = CancelBrowse{};

    var add_comp_attack = AddMapping{ .control = .Comp_Attack, .param = 0 };
    var add_comp_thresh = AddMapping{ .control = .Comp_Thresh, .param = 1 };
    var add_eq_higain = AddMapping{ .control = .Eq_HiGain, .param = 2 };
    var add_input_gain = AddMapping{ .control = .Inpt_Gain, .param = 3 };
    var remove_comp_attack = RemoveMapping{ .control = .Comp_Attack };
    var remove_eq_higain = RemoveMapping{ .control = .Eq_HiGain };
    var request_save_cmd = RequestSave{};
    var cancel_assign_cmd = CancelAssign{};

    var save_preset_cmd = SavePreset{};
    var cancel_save_cmd = CancelSave{};

    // Register commands
    const commands = [_]Command(Model, System){
        // Sub-mode transitions
        Command(Model, System).init(&enter_browse_cmd),
        Command(Model, System).init(&enter_assign_comp),
        Command(Model, System).init(&enter_assign_eq),
        Command(Model, System).init(&enter_assign_input),
        Command(Model, System).init(&enter_save_cmd),
        Command(Model, System).init(&exit_cmd),

        // BROWSE actions
        Command(Model, System).init(&scroll_comp),
        Command(Model, System).init(&scroll_eq),
        Command(Model, System).init(&scroll_input),
        Command(Model, System).init(&confirm_browse_cmd),
        Command(Model, System).init(&cancel_browse_cmd),

        // ASSIGN actions
        Command(Model, System).init(&add_comp_attack),
        Command(Model, System).init(&add_comp_thresh),
        Command(Model, System).init(&add_eq_higain),
        Command(Model, System).init(&add_input_gain),
        Command(Model, System).init(&remove_comp_attack),
        Command(Model, System).init(&remove_eq_higain),
        Command(Model, System).init(&request_save_cmd),
        Command(Model, System).init(&cancel_assign_cmd),

        // SAVE actions
        Command(Model, System).init(&save_preset_cmd),
        Command(Model, System).init(&cancel_save_cmd),
    };

    var bytes: [128 * 1024]u8 = undefined;
    const seed: u64 = @intCast(std.time.milliTimestamp());
    var prng = std.Random.DefaultPrng.init(seed);
    prng.random().bytes(&bytes);
    var finite_prng = FinitePrng.init(&bytes);
    var random = finite_prng.random();

    var cmd_seq = try CommandList(Model, System).init(&commands, &random, 500, allocator);
    defer cmd_seq.deinit(allocator);

    // Run stateful test
    const config = StatefulConfig{ .verbose = false };
    const result = try assertStateful(Model, System, &cmd_seq, &model, &sut, config);

    // Because the test should pass, we expect no failure
    if (result) |failure_info| {
        std.debug.print("\nTest failed at command index: {}\n", .{failure_info});
        return error.StatefulTestFailed;
    }
}

test "save_confirm updates module_locations for immediate FX control use" {
    const allocator = std.testing.allocator;
    var sut = try System.init(allocator);
    defer sut.deinit();

    // Step 1: Enter mapping panel in browse mode
    sut.globals.state.current_mode = .mapping_panel;
    mapping_actions.mappingPanelActions(&sut.globals, .enter_browse);

    // Step 2: Select COMP module and enter assign mode
    mapping_actions.mappingPanelActions(&sut.globals, .{ .browse_select_module = .COMP });
    mapping_actions.mappingPanelActions(&sut.globals, .{ .enter_assign = .COMP });

    // Step 3: Manually set target_fx
    // In production, this is queried from REAPER via TrackFX_GetFXName when module_locations has an entry.
    // In tests, module_locations is empty so that path is skipped and target_fx remains "".
    // We set it manually so save operations have an FX name to use.
    sut.globals.state.mapping_panel.mode.assign.target_fx = "VST: Test Compressor";

    // Step 4: Add a NEW mapping - this is the value we'll verify later
    mapping_actions.mappingPanelActions(&sut.globals, .{
        .assign_add_mapping = .{ .param = 5, .control = .Comp_Attack },
    });

    // Step 5: Enter save mode
    mapping_actions.mappingPanelActions(&sut.globals, .enter_save);

    // Step 6: Setup module_location so save_confirm has an entry to update
    sut.setupModuleLocation(.COMP, 0);

    // Step 7: Execute save_confirm
    mapping_actions.mappingPanelActions(&sut.globals, .{ .save_confirm = "test_mapping" });

    // Verification 1: Mode returned to fx_ctrl
    try std.testing.expectEqual(Mode.fx_ctrl, sut.globals.state.current_mode);

    // Verification 2: module_locations[COMP] exists and has a mapping
    const loc = sut.globals.state.fx_ctrl.track_state.module_locations.get(.COMP);
    try std.testing.expect(loc != null);
    try std.testing.expect(loc.?.mapping != null);

    // Verification 3: Mapping is for COMP module
    const mapping = loc.?.mapping.?;
    try std.testing.expectEqual(ModulesList.COMP, std.meta.activeTag(mapping));

    // Verification 4: The specific parameter value we set is present
    try std.testing.expectEqual(@as(?u8, 5), mapping.COMP.Comp_Attack);
}
