const std = @import("std");
const testing = std.testing;
const zlowcheck = @import("zlowcheck");
const Command = zlowcheck.Command;
const CommandList = zlowcheck.CommandList;
const FinitePrng = zlowcheck.FinitePrng;
const assertStateful = zlowcheck.assertStateful;

const Globals = @import("../globals.zig").Globals;
const statemachine = @import("../statemachine.zig");
const ModulesList = statemachine.ModulesList;
const fx_ctrl_actions = @import("../fx_ctrl_actions.zig");
const c1 = @import("../c1.zig");
const reaper = @import("../reaper.zig").reaper;
const utils = @import("../utils.zig");
const models = @import("../models/models.zig");

// The model tracks the expected state for FX control three-way synchronization:
// UI/controller input -> application state (fx_ctrl.values) -> REAPER FX parameters.
const Model = struct {
    // Whether a track is selected and its ID
    current_track_id: ?c_int = null,

    // Track phase inversion state (mirrors REAPER's B_PHASE property)
    track_phase_inverted: bool = false,

    // Expected FX parameter values keyed by CC.
    // Because we only test CCs that go through the panel_input "else" branch,
    // we store the expected normalized value for each CC.
    param_values: std.AutoHashMap(c1.CCs, f64),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Model {
        return .{
            .param_values = std.AutoHashMap(c1.CCs, f64).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Model) void {
        self.param_values.deinit();
    }

    pub fn reset(self: *Model) void {
        self.current_track_id = null;
        self.track_phase_inverted = false;
        self.param_values.clearRetainingCapacity();
    }
};

// The system wraps Globals with mock REAPER infrastructure.
const System = struct {
    globals: *Globals,

    pub fn init(globals: *Globals) System {
        return .{ .globals = globals };
    }

    pub fn reset(self: *System) void {
        self.globals.state.current_mode = .fx_ctrl;
        self.globals.state.current_tr_id = null;
    }

    pub fn deinit(self: *System) void {
        _ = self;
    }
};

// ============================================================================
// Commands
// ============================================================================

// SetTrackCmd: simulates selecting a track by setting current_tr_id.
// We do NOT call on_track_entry because it requires full track validation
// (already tested in track_validation_pbt.zig). Instead, we manually set up the
// state that on_track_entry would produce: a track with known module_locations and
// initial parameter values.
const SetTrackCmd = struct {
    track_id: c_int,

    pub const name = "SetTrack";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        _ = model;
        return true;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        model.current_track_id = self.track_id;
        model.track_phase_inverted = false;
        // Initialize all testable CCs to 0.5
        for (testable_param_ccs) |cc| {
            model.param_values.put(cc, 0.5) catch unreachable;
        }
        for (testable_button_ccs) |cc| {
            model.param_values.put(cc, 0.0) catch unreachable;
        }
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        // Set up the system state to simulate what on_track_entry would produce.
        sut.globals.state.current_tr_id = self.track_id;
        sut.globals.state.current_mode = .fx_ctrl;

        // Set up module_locations for all modules.
        // Each module gets fx_index = module ordinal, and a mapping where each CC
        // maps to param index 0 (all params share index 0 for simplicity).
        inline for (comptime std.enums.values(ModulesList)) |module| {
            const module_idx: c_int = @intCast(@intFromEnum(module));
            sut.globals.state.fx_ctrl.track_state.module_locations.set(module, .{
                .fx_index = module_idx,
                .mapping = switch (module) {
                    .INPUT => .{ .INPUT = .{ .Inpt_Gain = 0, .Inpt_HiCut = 1, .Inpt_LoCut = 2 } },
                    .GATE => .{ .GATE = .{ .Shp_Gate = 0, .Shp_GateRelease = 1, .Shp_Punch = 2, .Shp_sustain = 3, .Shp_shape = 4, .Shp_hard_gate = 5 } },
                    .EQ => .{ .EQ = .{ .Eq_HiFrq = 0, .Eq_HiGain = 1, .Eq_LoFrq = 2, .Eq_LoGain = 3, .Eq_eq = 4 } },
                    .COMP => .{ .COMP = .{ .Comp_Attack = 0, .Comp_Ratio = 1, .Comp_Thresh = 2, .Comp_Release = 3, .Comp_DryWet = 4, .Comp_comp = 5 } },
                    .OUTPT => .{ .OUTPT = .{ .Out_Drive = 0, .Out_DriveChar = 1 } },
                },
            });
        }

        // Set initial parameter values in the REAPER mock (all 0.5 for param CCs, 0.0 for buttons).
        const media_track = reaper.CSurf_TrackFromID(self.track_id, false);
        if (media_track == null) return false;

        // Reset B_PHASE to 0 so that the phase model stays in sync
        _ = reaper.SetMediaTrackInfo_Value(media_track, "B_PHASE", 0.0);

        for (testable_param_ccs) |cc| {
            const param_idx = getParamIdx(cc) orelse continue;
            const fx_idx = getFxIdx(cc) orelse continue;
            _ = reaper.TrackFX_SetParamNormalized(media_track, fx_idx, param_idx, 0.5);
        }
        for (testable_button_ccs) |cc| {
            const param_idx = getParamIdx(cc) orelse continue;
            const fx_idx = getFxIdx(cc) orelse continue;
            _ = reaper.TrackFX_SetParamNormalized(media_track, fx_idx, param_idx, 0.0);
        }

        // Initialize fx_ctrl.values for these CCs
        for (testable_param_ccs) |cc| {
            sut.globals.state.fx_ctrl.values.put(cc, .{ .param = .{ .normalized = 0.5 } }) catch unreachable;
        }
        for (testable_button_ccs) |cc| {
            sut.globals.state.fx_ctrl.values.put(cc, .{ .button = false }) catch unreachable;
        }

        self.onModelOnly(model);
        return true;
    }
};

// ClearTrackCmd: deselects the current track.
const ClearTrackCmd = struct {
    pub const name = "ClearTrack";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        return model.current_track_id != null;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.current_track_id = null;
        model.track_phase_inverted = false;
        model.param_values.clearRetainingCapacity();
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        sut.globals.state.current_tr_id = null;
        self.onModelOnly(model);
        return true;
    }
};

// PanelInputParamCmd: simulates panel_input for a parameter-type CC.
// Verifies three-way synchronization: state + REAPER mock both get updated.
const PanelInputParamCmd = struct {
    cc: c1.CCs,
    value: f64,

    pub const name = "PanelParam";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        return model.current_track_id != null and model.param_values.contains(self.cc);
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        model.param_values.put(self.cc, self.value) catch unreachable;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        fx_ctrl_actions.fxCtrlActions(sut.globals, .{ .panel_input = .{ .cc = self.cc, .value = self.value } });
        self.onModelOnly(model);

        // Verify application state
        const state_val = sut.globals.state.fx_ctrl.values.get(self.cc) orelse return false;
        const state_norm = switch (state_val) {
            .param => |p| p.normalized,
            else => return false,
        };
        if (@abs(state_norm - self.value) > 0.001) return false;

        // Verify REAPER mock parameter was updated
        const media_track = reaper.CSurf_TrackFromID(model.current_track_id.?, false);
        const fx_idx = getFxIdx(self.cc) orelse return false;
        const param_idx = getParamIdx(self.cc) orelse return false;
        const reaper_val = reaper.TrackFX_GetParamNormalized(media_track, fx_idx, param_idx);
        if (@abs(reaper_val - self.value) > 0.001) return false;

        return true;
    }
};

// PanelInputButtonCmd: simulates panel_input for a button-type CC.
const PanelInputButtonCmd = struct {
    cc: c1.CCs,
    value: f64,

    pub const name = "PanelButton";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        return model.current_track_id != null and model.param_values.contains(self.cc);
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        // Buttons store normalized value in the model (converted to bool in the system)
        model.param_values.put(self.cc, self.value) catch unreachable;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        fx_ctrl_actions.fxCtrlActions(sut.globals, .{ .panel_input = .{ .cc = self.cc, .value = self.value } });
        self.onModelOnly(model);

        // Verify application state (button stores bool)
        const state_val = sut.globals.state.fx_ctrl.values.get(self.cc) orelse return false;
        const state_bool = switch (state_val) {
            .button => |b| b,
            else => return false,
        };
        const expected_bool = self.value > 0.5;
        if (state_bool != expected_bool) return false;

        // Verify REAPER mock parameter was updated
        const media_track = reaper.CSurf_TrackFromID(model.current_track_id.?, false);
        const fx_idx = getFxIdx(self.cc) orelse return false;
        const param_idx = getParamIdx(self.cc) orelse return false;
        const reaper_val = reaper.TrackFX_GetParamNormalized(media_track, fx_idx, param_idx);
        if (@abs(reaper_val - self.value) > 0.001) return false;

        return true;
    }
};

// TogglePhaseCmd: toggles track phase inversion.
const TogglePhaseCmd = struct {
    pub const name = "TogglePhase";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        return model.current_track_id != null;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.track_phase_inverted = !model.track_phase_inverted;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        const media_track = reaper.CSurf_TrackFromID(model.current_track_id.?, false);

        fx_ctrl_actions.fxCtrlActions(sut.globals, .{ .toggle_phase_inv = media_track });
        self.onModelOnly(model);

        // Verify B_PHASE in the REAPER mock
        const reaper_phase = reaper.GetMediaTrackInfo_Value(media_track, "B_PHASE");
        const expected: f64 = if (model.track_phase_inverted) 1.0 else 0.0;
        return @abs(reaper_phase - expected) < 0.001;
    }
};

// SetVolumeCmd: sets track volume via set_volume action.
const SetVolumeCmd = struct {
    value: f64,

    pub const name = "SetVolume";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        return model.current_track_id != null;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        _ = model;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        fx_ctrl_actions.fxCtrlActions(sut.globals, .{ .set_volume = self.value });
        _ = model;

        // Verify the state was updated (set_volume calls MidiEvts.setUIVal)
        if (sut.globals.state.fx_ctrl.values.get(.Out_Vol)) |val| {
            return switch (val) {
                .param => |p| @abs(p.normalized - self.value) < 0.001,
                else => false,
            };
        }
        return false;
    }
};

// SetPanCmd: sets track pan via set_pan action.
const SetPanCmd = struct {
    value: f64,

    pub const name = "SetPan";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        return model.current_track_id != null;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        _ = model;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        fx_ctrl_actions.fxCtrlActions(sut.globals, .{ .set_pan = self.value });
        _ = model;

        // set_pan converts pan_value to normalized using panToNormalized,
        // so the stored value in state is the normalized version.
        const expected_norm = utils.panToNormalized(self.value);
        if (sut.globals.state.fx_ctrl.values.get(.Out_Pan)) |val| {
            return switch (val) {
                .param => |p| @abs(p.normalized - expected_norm) < 0.001,
                else => false,
            };
        }
        return false;
    }
};

// ============================================================================
// Helpers
// ============================================================================

// Parameter CCs that go through the panel_input "else" branch
const testable_param_ccs = [_]c1.CCs{
    .Inpt_Gain, .Comp_Attack, .Comp_Thresh, .Eq_HiGain, .Eq_LoGain, .Shp_Gate, .Out_Drive,
};

// Button CCs that go through the panel_input "else" branch
const testable_button_ccs = [_]c1.CCs{
    .Comp_comp, .Eq_eq, .Shp_shape, .Shp_hard_gate,
};

// Returns the fx_index for a given CC based on its module.
// Must match the module -> fx_index mapping set up in SetTrackCmd.
fn getFxIdx(cc: c1.CCs) ?c_int {
    const module = cc.toModule();
    return @intCast(@intFromEnum(module));
}

// Returns the param_index for a given CC based on the mapping set up in SetTrackCmd.
fn getParamIdx(cc: c1.CCs) ?c_int {
    return switch (cc) {
        .Inpt_Gain => 0,
        .Inpt_HiCut => 1,
        .Inpt_LoCut => 2,
        .Shp_Gate => 0,
        .Shp_GateRelease => 1,
        .Shp_Punch => 2,
        .Shp_sustain => 3,
        .Shp_shape => 4,
        .Shp_hard_gate => 5,
        .Eq_HiFrq => 0,
        .Eq_HiGain => 1,
        .Eq_LoFrq => 2,
        .Eq_LoGain => 3,
        .Eq_eq => 4,
        .Comp_Attack => 0,
        .Comp_Ratio => 1,
        .Comp_Thresh => 2,
        .Comp_Release => 3,
        .Comp_DryWet => 4,
        .Comp_comp => 5,
        .Out_Drive => 0,
        .Out_DriveChar => 1,
        else => null,
    };
}

// ============================================================================
// Test Entry Points
// ============================================================================

fn fxCtrlStatefulTest(_: void, input: []const u8) !void {
    // We set up the mock infrastructure manually (instead of test_setup) because we need
    // tracks with FX in the session, and test_setup creates 0 tracks with an arena that
    // gets freed before we can add to it.
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const gpa = arena.allocator();

    var reaper_teardown = models.reaper.setupTestModel(gpa, 1, 4);
    defer reaper_teardown.teardown();
    const midi_teardown = models.midi.setupMidiMocks(reaper);
    defer midi_teardown.teardown();

    Globals.instance = try .defaults(testing.allocator);
    defer Globals.instance.deinit();
    const globals = &Globals.instance;

    globals.m_midi_out = reaper.CreateMIDIOutput(0, false, null);
    _ = @import("../csurf/control_surface.zig").init(0, 0, null);
    globals.state.current_mode = .fx_ctrl;

    const session = reaper_teardown.model_ptr;

    // Add 5 FX (one per module) to track 1 (index 1, since index 0 is master).
    const track_ptr = &session.tracks.items[1];
    for (0..5) |_| {
        const params = try gpa.alloc(models.Param, 6);
        for (params) |*p| {
            p.* = .{ .name = "param", .normalized_value = 0.5, .formatted_value = "0.5" };
        }
        try track_ptr.fx_list.append(gpa, .{
            .guid = std.mem.zeroes(@import("../utils.zig").Guid),
            .enabled = true,
            .params = params,
            .named_configs = .{ .original_name = "Test FX", .renamed_name = "Test FX" },
        });
    }

    const fuzz_data = testing.allocator.alloc(u8, input.len) catch return error.SkipZigTest;
    defer testing.allocator.free(fuzz_data);
    @memcpy(fuzz_data, input);

    var prng = FinitePrng.init(fuzz_data);
    var random = prng.random();

    // Create command instances.
    // Track ID 1 corresponds to the first regular track (index 0 is master).
    var set_track = SetTrackCmd{ .track_id = 1 };
    var clear_track = ClearTrackCmd{};

    // Parameter CCs at different values
    var param_inpt_low = PanelInputParamCmd{ .cc = .Inpt_Gain, .value = 0.1 };
    var param_inpt_high = PanelInputParamCmd{ .cc = .Inpt_Gain, .value = 0.9 };
    var param_comp_mid = PanelInputParamCmd{ .cc = .Comp_Attack, .value = 0.5 };
    var param_eq_low = PanelInputParamCmd{ .cc = .Eq_HiGain, .value = 0.2 };
    var param_shp = PanelInputParamCmd{ .cc = .Shp_Gate, .value = 0.7 };
    var param_out = PanelInputParamCmd{ .cc = .Out_Drive, .value = 0.6 };

    // Button CCs
    var btn_comp_on = PanelInputButtonCmd{ .cc = .Comp_comp, .value = 0.8 };
    var btn_comp_off = PanelInputButtonCmd{ .cc = .Comp_comp, .value = 0.2 };
    var btn_eq = PanelInputButtonCmd{ .cc = .Eq_eq, .value = 0.9 };
    var btn_shp = PanelInputButtonCmd{ .cc = .Shp_shape, .value = 0.7 };

    // Phase toggle
    var toggle_phase = TogglePhaseCmd{};

    // Volume / Pan
    var set_vol_low = SetVolumeCmd{ .value = 0.2 };
    var set_vol_high = SetVolumeCmd{ .value = 0.8 };
    var set_pan_left = SetPanCmd{ .value = -0.5 };
    var set_pan_right = SetPanCmd{ .value = 0.5 };

    const commands = [_]Command(Model, System){
        Command(Model, System).init(&set_track),
        Command(Model, System).init(&clear_track),
        Command(Model, System).init(&param_inpt_low),
        Command(Model, System).init(&param_inpt_high),
        Command(Model, System).init(&param_comp_mid),
        Command(Model, System).init(&param_eq_low),
        Command(Model, System).init(&param_shp),
        Command(Model, System).init(&param_out),
        Command(Model, System).init(&btn_comp_on),
        Command(Model, System).init(&btn_comp_off),
        Command(Model, System).init(&btn_eq),
        Command(Model, System).init(&btn_shp),
        Command(Model, System).init(&toggle_phase),
        Command(Model, System).init(&set_vol_low),
        Command(Model, System).init(&set_vol_high),
        Command(Model, System).init(&set_pan_left),
        Command(Model, System).init(&set_pan_right),
    };

    var cmd_seq = CommandList(Model, System).init(
        &commands,
        &random,
        500,
        testing.allocator,
    ) catch |err| {
        if (err == FinitePrng.FinitePrngErr.OutOfEntropy) return;
        return err;
    };
    defer cmd_seq.deinit(testing.allocator);

    var model = Model.init(testing.allocator);
    defer model.deinit();
    var system = System.init(globals);

    const rv = assertStateful(
        Model,
        System,
        &cmd_seq,
        &model,
        &system,
        .{ .verbose = true },
    ) catch |err| {
        if (err == FinitePrng.FinitePrngErr.OutOfEntropy) return;
        return err;
    };

    if (rv) |failure| {
        std.debug.print("\nfx_ctrl failure: {any}\n", .{failure});
        // Print model and system state for debugging
        std.debug.print("model track_id={?}, phase={}\n", .{ model.current_track_id, model.track_phase_inverted });
        std.debug.print("system track_id={?}, mode={s}\n", .{ system.globals.state.current_tr_id, @tagName(system.globals.state.current_mode) });
        return error.TestFailed;
    }

    try testing.expect(rv == null);
}

test "fx_ctrl stateful - with random bytes" {
    const seeds = [_]u64{ 0xABCD1234EF005678, 0x1111222233334444, 0xFEDCBA9876543210 };
    for (seeds) |seed| {
        var seed_prng = std.Random.DefaultPrng.init(seed);
        var random_bytes: [4096]u8 = undefined;
        seed_prng.random().bytes(&random_bytes);
        try fxCtrlStatefulTest({}, &random_bytes);
    }
}

test fxCtrlStatefulTest {
    try std.testing.fuzz({}, fxCtrlStatefulTest, .{});
}
