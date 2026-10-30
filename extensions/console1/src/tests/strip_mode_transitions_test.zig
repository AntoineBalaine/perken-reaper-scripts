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
const Mode = statemachine.Mode;
const fx_sel_actions = @import("../fx_sel_actions.zig");
const actions = @import("../actions.zig");
const reaper = @import("reaper").reaper;
const test_setup = @import("mode_switch_tests.zig").test_setup;

// The model tracks only the current mode. The property under test is that
// no invalid mode transition ever occurs (i.e. the SUT does not panic).
const Model = struct {
    current_mode: Mode = .fx_ctrl,

    pub fn init() Model {
        return .{};
    }

    pub fn deinit(self: *Model) void {
        _ = self;
    }

    pub fn reset(self: *Model) void {
        self.* = .{};
    }
};

const System = struct {
    globals: *Globals,

    pub fn init(globals: *Globals) System {
        return .{ .globals = globals };
    }

    pub fn deinit(self: *System) void {
        _ = self;
    }

    pub fn reset(self: *System) void {
        self.globals.state.current_mode = .fx_ctrl;
        self.globals.state.fx_sel = .{};
    }
};

// ============================================================================
// Commands
// ============================================================================

const EnterTransportCmd = struct {
    pub const name = "EnterTransport";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        return model.current_mode == .fx_ctrl;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.current_mode = .transport;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        actions.dispatch(sut.globals, .{ .change_mode = .transport });
        self.onModelOnly(model);
        return sut.globals.state.current_mode == .transport;
    }
};

const EnterFxCtrlCmd = struct {
    pub const name = "EnterFxCtrl";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        // Because fx_ctrl is reachable from fx_sel, transport, and mapping_panel
        return model.current_mode == .fx_sel or
            model.current_mode == .transport or
            model.current_mode == .mapping_panel;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.current_mode = .fx_ctrl;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        actions.dispatch(sut.globals, .{ .change_mode = .fx_ctrl });
        self.onModelOnly(model);
        return sut.globals.state.current_mode == .fx_ctrl;
    }
};

const ToggleStripBrowserCmd = struct {
    pub const name = "ToggleStripBrowser";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        return model.current_mode == .fx_ctrl or
            model.current_mode == .fx_sel or
            model.current_mode == .transport;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        if (model.current_mode == .fx_sel and model.current_mode == .fx_sel) {
            // Because toggle_strip_browser checks current_category == .STRIP,
            // we can't model that here without tracking the category. So we
            // always model it as entering fx_sel with STRIP.
            model.current_mode = .fx_sel;
        } else {
            model.current_mode = .fx_sel;
        }
    }

    pub fn onPair(_: *@This(), model: *Model, sut: *System) !bool {
        fx_sel_actions.fxSelActions(sut.globals, .{ .toggle_module_browser = .STRIP });
        // Because toggle_strip_browser either enters or stays in fx_sel,
        // we sync the model from the SUT.
        model.current_mode = sut.globals.state.current_mode;
        return sut.globals.state.current_mode == .fx_sel or
            sut.globals.state.current_mode == .fx_ctrl;
    }
};

const ToggleModuleBrowserCmd = struct {
    module: ModulesList,
    pub const name = "ToggleModuleBrowser";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        return model.current_mode == .fx_ctrl or
            model.current_mode == .fx_sel or
            model.current_mode == .transport;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.current_mode = .fx_sel;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        fx_sel_actions.fxSelActions(sut.globals, .{ .toggle_module_browser = self.module });
        model.current_mode = sut.globals.state.current_mode;
        return sut.globals.state.current_mode == .fx_sel or
            sut.globals.state.current_mode == .fx_ctrl;
    }
};

const CloseBrowserCmd = struct {
    pub const name = "CloseBrowser";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        return model.current_mode == .fx_sel;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.current_mode = .fx_ctrl;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        fx_sel_actions.fxSelActions(sut.globals, .close_browser);
        self.onModelOnly(model);
        return sut.globals.state.current_mode == .fx_ctrl;
    }
};

const OpenSettingsCmd = struct {
    pub const name = "OpenSettings";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        return model.current_mode == .fx_ctrl or model.current_mode == .transport;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.current_mode = .settings;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        actions.dispatch(sut.globals, .{ .change_mode = .settings });
        self.onModelOnly(model);
        return sut.globals.state.current_mode == .settings;
    }
};

const CloseSettingsCmd = struct {
    pub const name = "CloseSettings";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        return model.current_mode == .settings;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        model.current_mode = .fx_ctrl;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        actions.dispatch(sut.globals, .{ .change_mode = .fx_ctrl });
        self.onModelOnly(model);
        return sut.globals.state.current_mode == .fx_ctrl;
    }
};

// ============================================================================
// Test Entry Points
// ============================================================================

fn modeTransitionStatefulTest(_: void, input: []const u8) !void {
    var g_teardown = try test_setup(testing.allocator);
    defer g_teardown.teardown();

    const globals = g_teardown.globals;
    globals.m_midi_out = reaper.CreateMIDIOutput(0, false, null);
    _ = @import("../csurf/control_surface.zig").init(0, 0, null);
    globals.state.current_mode = .fx_ctrl;

    const fuzz_data = testing.allocator.alloc(u8, input.len) catch return error.SkipZigTest;
    defer testing.allocator.free(fuzz_data);
    @memcpy(fuzz_data, input);

    var prng = FinitePrng.init(fuzz_data);
    var random = prng.random();

    var enter_transport = EnterTransportCmd{};
    var enter_fx_ctrl = EnterFxCtrlCmd{};
    var toggle_strip = ToggleStripBrowserCmd{};
    var toggle_input = ToggleModuleBrowserCmd{ .module = .INPUT };
    var toggle_comp = ToggleModuleBrowserCmd{ .module = .COMP };
    var toggle_strip_mod = ToggleModuleBrowserCmd{ .module = .STRIP };
    var close_browser = CloseBrowserCmd{};
    var open_settings = OpenSettingsCmd{};
    var close_settings = CloseSettingsCmd{};

    const commands = [_]Command(Model, System){
        Command(Model, System).init(&enter_transport),
        Command(Model, System).init(&enter_fx_ctrl),
        Command(Model, System).init(&toggle_strip),
        Command(Model, System).init(&toggle_input),
        Command(Model, System).init(&toggle_comp),
        Command(Model, System).init(&toggle_strip_mod),
        Command(Model, System).init(&close_browser),
        Command(Model, System).init(&open_settings),
        Command(Model, System).init(&close_settings),
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

    var model = Model.init();
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
        std.debug.print("\nmode transition failure: {any}\n", .{failure});
        return error.TestFailed;
    }

    try testing.expect(rv == null);
}

test "strip mode transitions - no invalid transitions" {
    const seeds = [_]u64{ 0x5721F001BEEF0002, 0x0123456789ABCDEF, 0xFACEFEED00112233 };
    for (seeds) |seed| {
        var seed_prng = std.Random.DefaultPrng.init(seed);
        var random_bytes: [4096]u8 = undefined;
        seed_prng.random().bytes(&random_bytes);
        try modeTransitionStatefulTest({}, &random_bytes);
    }
}
