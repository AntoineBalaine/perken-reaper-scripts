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
const MidiLearnPhase = statemachine.MidiLearnPhase;
const Mode = statemachine.Mode;
const mapping_actions = @import("../mapping_actions.zig");
const MappingPanelAction = mapping_actions.MappingPanelAction;
const mappings = @import("../mappings.zig");
const c1 = @import("../c1.zig");
const CCs = c1.CCs;
const fs_helpers = @import("../fs_helpers.zig");
const MockFileSystem = fs_helpers.MockFileSystem;

// ============================================================================
// Model
// ============================================================================

const Model = struct {
    phase: MidiLearnPhase = .idle,
    selected_control: ?CCs = null,
    comp_attack: ?u16 = null,
    comp_ratio: ?u16 = null,
    comp_thresh: ?u16 = null,

    pub fn reset(self: *Model) void {
        self.phase = .idle;
        self.selected_control = null;
        self.comp_attack = null;
        self.comp_ratio = null;
        self.comp_thresh = null;
    }
};

// ============================================================================
// System Under Test
// ============================================================================

const System = struct {
    globals: Globals,
    allocator: std.mem.Allocator,
    mock_fs: *MockFileSystem,
    resource_path: [:0]const u8,

    pub fn init(allocator: std.mem.Allocator) !System {
        const mock_fs = try allocator.create(MockFileSystem);
        mock_fs.* = try MockFileSystem.init(allocator);

        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
        const temp_path = try mock_fs.temp_dir.dir.realpath(".", &path_buffer);
        const temp_path_owned = try allocator.dupeZ(u8, temp_path);
        defer allocator.free(temp_path_owned);

        const real_fs = fs_helpers.RealFileSystem.fileSystemOps();
        try fs_helpers.copyEmbeddedFilesToDir(real_fs, temp_path_owned);

        const resource_path = try std.fs.path.joinZ(allocator, &.{
            temp_path_owned, "Data", "Perken", "Console1",
        });

        var g = try Globals.defaults(allocator);
        g.resource_path = resource_path;
        g.fs_ops = mock_fs.fileSystemOps();
        g.state.current_mode = .mapping_panel;
        g.state.fx_ctrl.track_state.module_locations = @TypeOf(g.state.fx_ctrl.track_state.module_locations).initFill(null);

        // Set up a module location so SETFXPARAM scoping works.
        g.state.fx_ctrl.track_state.module_locations.set(.COMP, .{
            .fx_index = 0,
            .mapping = null,
        });

        // Because we need to be in assign submode for MIDI learn to work,
        // we initialize the mapping panel in assign mode for COMP.
        g.state.mapping_panel.deinitCurrentSubMode();
        g.state.mapping_panel.mode = .{
            .assign = statemachine.AssignState.init(
                g.state.mapping_panel.gpa_int.allocator(),
                .{ .COMP = mappings.Comp{} },
            ),
        };

        return System{
            .globals = g,
            .allocator = allocator,
            .mock_fs = mock_fs,
            .resource_path = resource_path,
        };
    }

    pub fn reset(self: *System) void {
        self.globals.state.mapping_panel.deinitCurrentSubMode();
        self.globals.state.mapping_panel.mode = .{
            .assign = statemachine.AssignState.init(
                self.globals.state.mapping_panel.gpa_int.allocator(),
                .{ .COMP = mappings.Comp{} },
            ),
        };
        self.globals.state.current_mode = .mapping_panel;
    }

    pub fn deinit(self: *System) void {
        self.allocator.free(self.resource_path);
        self.mock_fs.deinit();
        self.allocator.destroy(self.mock_fs);
        self.globals.state.mapping_panel.deinit();
        _ = self.globals.arena_int.reset(.free_all);
    }

    pub fn getAssign(self: *System) *statemachine.AssignState {
        return &self.globals.state.mapping_panel.mode.assign;
    }
};

// ============================================================================
// Helper: verify model and system are synchronized
// ============================================================================

fn verifySynced(model: *const Model, sut: *System) bool {
    const assign = sut.getAssign();

    if (assign.midi_learn != model.phase) return false;
    if (assign.selected_control != model.selected_control) return false;

    const comp = assign.current_mappings.COMP;
    if (comp.Comp_Attack != model.comp_attack) return false;
    if (comp.Comp_Ratio != model.comp_ratio) return false;
    if (comp.Comp_Thresh != model.comp_thresh) return false;

    return true;
}

// ============================================================================
// Stateful Test Commands
// ============================================================================

const ToggleMidiLearn = struct {
    pub const name = "toggle_midi_learn";

    pub fn checkPrecondition(_: *@This(), _: *const Model) bool {
        return true;
    }

    pub fn onModelOnly(_: *@This(), model: *Model) void {
        switch (model.phase) {
            .idle, .listening_param => {
                model.phase = .listening_cc;
                model.selected_control = null;
            },
            .listening_cc => {
                model.phase = .idle;
                model.selected_control = null;
            },
        }
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        mapping_actions.mappingPanelActions(&sut.globals, .assign_toggle_midi_learn);
        self.onModelOnly(model);
        return verifySynced(model, sut);
    }
};

const LearnCC = struct {
    cc: CCs,
    pub const name = "learn_cc";

    pub fn checkPrecondition(_: *@This(), model: *const Model) bool {
        return model.phase == .listening_cc;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        std.debug.assert(self.cc.isFxAssignable());
        model.phase = .listening_param;
        model.selected_control = self.cc;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        mapping_actions.mappingPanelActions(&sut.globals, .{ .assign_select_control = self.cc });
        self.onModelOnly(model);
        return verifySynced(model, sut);
    }
};

const LearnParam = struct {
    param_index: u32,
    pub const name = "learn_param";

    pub fn checkPrecondition(_: *@This(), model: *const Model) bool {
        return model.phase == .listening_param and model.selected_control != null;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        if (model.selected_control) |cc| {
            const param: u16 = @intCast(self.param_index);
            switch (cc) {
                .Comp_Attack => model.comp_attack = param,
                .Comp_Ratio => model.comp_ratio = param,
                .Comp_Thresh => model.comp_thresh = param,
                else => {},
            }
        }
        model.phase = .idle;
        model.selected_control = null;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        mapping_actions.mappingPanelActions(&sut.globals, .{ .assign_midi_learned_param = self.param_index });
        self.onModelOnly(model);
        return verifySynced(model, sut);
    }
};

// ============================================================================
// Stateful PBT
// ============================================================================

test "midi_learn - stateful property test" {
    const allocator = std.testing.allocator;
    var model = Model{};
    var sut = try System.init(allocator);
    defer sut.deinit();

    var toggle_cmd = ToggleMidiLearn{};
    var learn_attack = LearnCC{ .cc = .Comp_Attack };
    var learn_ratio = LearnCC{ .cc = .Comp_Ratio };
    var learn_thresh = LearnCC{ .cc = .Comp_Thresh };
    var param_0 = LearnParam{ .param_index = 0 };
    var param_1 = LearnParam{ .param_index = 1 };
    var param_5 = LearnParam{ .param_index = 5 };

    const commands = [_]Command(Model, System){
        Command(Model, System).init(&toggle_cmd),
        Command(Model, System).init(&learn_attack),
        Command(Model, System).init(&learn_ratio),
        Command(Model, System).init(&learn_thresh),
        Command(Model, System).init(&param_0),
        Command(Model, System).init(&param_1),
        Command(Model, System).init(&param_5),
    };

    var bytes: [128 * 1024]u8 = undefined;
    const seed: u64 = @intCast(std.time.milliTimestamp());
    var prng = std.Random.DefaultPrng.init(seed);
    prng.random().bytes(&bytes);
    var finite_prng = FinitePrng.init(&bytes);
    var random = finite_prng.random();

    var cmd_seq = try CommandList(Model, System).init(&commands, &random, 500, allocator);
    defer cmd_seq.deinit(allocator);

    const config = StatefulConfig{ .verbose = false };
    const result = try assertStateful(Model, System, &cmd_seq, &model, &sut, config);

    if (result) |failure_info| {
        std.debug.print("\nMIDI learn stateful test failed at command index: {}\n", .{failure_info});
        return error.StatefulTestFailed;
    }
}

// ============================================================================
// Example-Based Tests
// ============================================================================

test "midi_learn - full learn cycle creates assignment" {
    const allocator = std.testing.allocator;
    var sut = try System.init(allocator);
    defer sut.deinit();

    const assign = sut.getAssign();

    // 1. Toggle learn on
    mapping_actions.mappingPanelActions(&sut.globals, .assign_toggle_midi_learn);
    try std.testing.expect(assign.midi_learn == .listening_cc);

    // 2. Capture CC from Console1
    mapping_actions.mappingPanelActions(&sut.globals, .{ .assign_select_control = .Comp_Attack });
    try std.testing.expect(assign.midi_learn == .listening_param);
    try std.testing.expect(assign.selected_control.? == .Comp_Attack);

    // 3. Capture parameter from VST
    mapping_actions.mappingPanelActions(&sut.globals, .{ .assign_midi_learned_param = 5 });
    try std.testing.expect(assign.midi_learn == .idle);
    try std.testing.expect(assign.selected_control == null);

    // 4. Verify the assignment was created
    try std.testing.expect(assign.current_mappings.COMP.Comp_Attack.? == 5);
}

test "midi_learn - cancel during CC listen clears state" {
    const allocator = std.testing.allocator;
    var sut = try System.init(allocator);
    defer sut.deinit();

    const assign = sut.getAssign();

    mapping_actions.mappingPanelActions(&sut.globals, .assign_toggle_midi_learn);
    try std.testing.expect(assign.midi_learn == .listening_cc);

    mapping_actions.mappingPanelActions(&sut.globals, .assign_toggle_midi_learn);
    try std.testing.expect(assign.midi_learn == .idle);
    try std.testing.expect(assign.selected_control == null);
}

test "midi_learn - restart during param listen goes back to CC listen" {
    const allocator = std.testing.allocator;
    var sut = try System.init(allocator);
    defer sut.deinit();

    const assign = sut.getAssign();

    mapping_actions.mappingPanelActions(&sut.globals, .assign_toggle_midi_learn);
    mapping_actions.mappingPanelActions(&sut.globals, .{ .assign_select_control = .Comp_Ratio });
    try std.testing.expect(assign.midi_learn == .listening_param);

    // Because toggling from listening_param restarts the flow,
    // we expect to go back to listening_cc.
    mapping_actions.mappingPanelActions(&sut.globals, .assign_toggle_midi_learn);
    try std.testing.expect(assign.midi_learn == .listening_cc);
    try std.testing.expect(assign.selected_control == null);
}

test "midi_learn - isFxAssignable correctness" {
    const assignable = [_]CCs{
        .Comp_Attack,       .Comp_DryWet,     .Comp_Ratio,   .Comp_Release,  .Comp_Thresh,    .Comp_comp,
        .Eq_HiFrq,          .Eq_HiGain,       .Eq_HiMidFrq,  .Eq_HiMidGain,  .Eq_HiMidQ,      .Eq_LoFrq,
        .Eq_LoGain,         .Eq_LoMidFrq,     .Eq_LoMidGain, .Eq_LoMidQ,     .Eq_eq,          .Eq_hp_shape,
        .Eq_lp_shape,       .Inpt_Gain,       .Inpt_HiCut,   .Inpt_LoCut,    .Inpt_disp_mode, .Inpt_disp_on,
        .Inpt_filt_to_comp, .Inpt_preset,     .Out_Drive,    .Out_DriveChar, .Out_Pan,        .Out_Vol,
        .Shp_Gate,          .Shp_GateRelease, .Shp_Punch,    .Shp_hard_gate, .Shp_shape,      .Shp_sustain,
    };
    for (assignable) |cc| {
        try std.testing.expect(cc.isFxAssignable());
    }

    const non_assignable = [_]CCs{
        .Out_mute,   .Out_solo,   .Inpt_phase_inv, .Inpt_MtrLft, .Inpt_MtrRgt,
        .Out_MtrLft, .Out_MtrRgt, .Shp_Mtr,        .Comp_Mtr,    .Tr_tr1,
        .Tr_tr2,     .Tr_pg_up,   .Tr_pg_dn,       .Tr_order,    .Tr_ext_sidechain,
        .Tr_tr_copy, .Tr_tr_grp,
    };
    for (non_assignable) |cc| {
        try std.testing.expect(!cc.isFxAssignable());
    }
}

test "midi_learn - multiple consecutive learn cycles" {
    const allocator = std.testing.allocator;
    var sut = try System.init(allocator);
    defer sut.deinit();

    const assign = sut.getAssign();

    // First cycle: Comp_Attack -> param 3
    mapping_actions.mappingPanelActions(&sut.globals, .assign_toggle_midi_learn);
    mapping_actions.mappingPanelActions(&sut.globals, .{ .assign_select_control = .Comp_Attack });
    mapping_actions.mappingPanelActions(&sut.globals, .{ .assign_midi_learned_param = 3 });
    try std.testing.expect(assign.current_mappings.COMP.Comp_Attack.? == 3);

    // Second cycle: Comp_Ratio -> param 7
    mapping_actions.mappingPanelActions(&sut.globals, .assign_toggle_midi_learn);
    mapping_actions.mappingPanelActions(&sut.globals, .{ .assign_select_control = .Comp_Ratio });
    mapping_actions.mappingPanelActions(&sut.globals, .{ .assign_midi_learned_param = 7 });
    try std.testing.expect(assign.current_mappings.COMP.Comp_Ratio.? == 7);

    // Both assignments should persist
    try std.testing.expect(assign.current_mappings.COMP.Comp_Attack.? == 3);
}

test "midi_learn - learned_param ignored when not in listening_param phase" {
    const allocator = std.testing.allocator;
    var sut = try System.init(allocator);
    defer sut.deinit();

    const assign = sut.getAssign();

    // Because we're in idle phase, a stray param event should be ignored.
    mapping_actions.mappingPanelActions(&sut.globals, .{ .assign_midi_learned_param = 42 });
    try std.testing.expect(assign.midi_learn == .idle);
    try std.testing.expect(assign.current_mappings.COMP.Comp_Attack == null);
}

test "midi_learn - param index above 255 is accepted with u16 storage" {
    const allocator = std.testing.allocator;
    var sut = try System.init(allocator);
    defer sut.deinit();

    const assign = sut.getAssign();

    // Because we use u16 for param indices, values above 255 are valid.
    mapping_actions.mappingPanelActions(&sut.globals, .assign_toggle_midi_learn);
    mapping_actions.mappingPanelActions(&sut.globals, .{ .assign_select_control = .Comp_Attack });
    try std.testing.expect(assign.midi_learn == .listening_param);

    mapping_actions.mappingPanelActions(&sut.globals, .{ .assign_midi_learned_param = 300 });
    try std.testing.expect(assign.midi_learn == .idle);
    try std.testing.expect(assign.selected_control == null);
    try std.testing.expect(assign.current_mappings.COMP.Comp_Attack.? == 300);
}
