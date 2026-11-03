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
const FxSelActions = fx_sel_actions.FxSelActions;
const reaper = @import("reaper").reaper;
const test_setup = @import("mode_switch_tests.zig").test_setup;

// The model tracks FX selection mode state: the current module category,
// scroll positions, and whether we are in fx_sel or fx_ctrl mode.
const Model = struct {
    current_mode: Mode = .fx_ctrl,
    current_category: ModulesList = .COMP,
    scroll_position_abs: u8 = 0,
    scroll_position_rel: usize = 0,

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

// ToggleModuleBrowserCmd: toggles the FX browser for a specific module.
// If already in fx_sel with the same module, it returns to fx_ctrl.
// Otherwise it enters fx_sel with the new module and resets scroll positions.
const ToggleModuleBrowserCmd = struct {
    module: ModulesList,
    pub const name = "ToggleBrowser";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        // We can toggle the browser from fx_ctrl or fx_sel mode.
        return model.current_mode == .fx_ctrl or model.current_mode == .fx_sel;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        if (model.current_mode == .fx_sel and self.module == model.current_category) {
            // Same module toggled again -> close browser
            model.current_mode = .fx_ctrl;
        } else {
            // Enter or switch to new module
            model.current_mode = .fx_sel;
            model.current_category = self.module;
            model.scroll_position_abs = 0;
            model.scroll_position_rel = 0;
        }
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        fx_sel_actions.fxSelActions(sut.globals, .{ .toggle_module_browser = self.module });
        self.onModelOnly(model);

        // Verify mode and category
        if (model.current_mode == .fx_sel) {
            return sut.globals.state.current_mode == .fx_sel and
                sut.globals.state.fx_sel.current_category == model.current_category and
                sut.globals.state.fx_sel.scroll_position_abs == 0 and
                sut.globals.state.fx_sel.scroll_position_rel == 0;
        } else {
            return sut.globals.state.current_mode == .fx_ctrl;
        }
    }
};

// CloseBrowserCmd: closes the FX browser and returns to fx_ctrl.
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

// ScrollCmd: scrolls through the FX list within the current module category.
// Because the FX list may be empty in tests (no mappings loaded), the scroll
// is often a no-op. We still verify that it does not crash.
const ScrollFxCmd = struct {
    value: u8,
    pub const name = "ScrollFx";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        return model.current_mode == .fx_sel;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        _ = model;
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        fx_sel_actions.fxSelActions(sut.globals, .{ .scroll = self.value });
        // Sync model from system
        model.scroll_position_abs = sut.globals.state.fx_sel.scroll_position_abs;
        model.scroll_position_rel = sut.globals.state.fx_sel.scroll_position_rel;
        // Verify mode is still fx_sel
        return sut.globals.state.current_mode == .fx_sel;
    }
};

// ToggleStripBrowserCmd: toggles the strip browser.
// If already in fx_sel with STRIP category, it returns to fx_ctrl.
// Otherwise it enters fx_sel with STRIP and resets scroll positions.
const ToggleStripBrowserCmd = struct {
    pub const name = "ToggleStripBrowser";

    pub fn checkPrecondition(self: *@This(), model: *const Model) bool {
        _ = self;
        return model.current_mode == .fx_ctrl or model.current_mode == .fx_sel;
    }

    pub fn onModelOnly(self: *@This(), model: *Model) void {
        _ = self;
        if (model.current_mode == .fx_sel and model.current_category == .STRIP) {
            model.current_mode = .fx_ctrl;
        } else {
            model.current_mode = .fx_sel;
            model.current_category = .STRIP;
            model.scroll_position_abs = 0;
            model.scroll_position_rel = 0;
        }
    }

    pub fn onPair(self: *@This(), model: *Model, sut: *System) !bool {
        fx_sel_actions.fxSelActions(sut.globals, .{ .toggle_module_browser = .STRIP });
        self.onModelOnly(model);

        if (model.current_mode == .fx_sel) {
            return sut.globals.state.current_mode == .fx_sel and
                sut.globals.state.fx_sel.current_category == .STRIP and
                sut.globals.state.fx_sel.scroll_position_abs == 0 and
                sut.globals.state.fx_sel.scroll_position_rel == 0;
        } else {
            return sut.globals.state.current_mode == .fx_ctrl;
        }
    }
};

// ============================================================================
// Test Entry Points
// ============================================================================

fn fxSelStatefulTest(_: void, input: []const u8) !void {
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

    // Module browser toggles for all 5 modules
    var browse_input = ToggleModuleBrowserCmd{ .module = .INPUT };
    var browse_gate = ToggleModuleBrowserCmd{ .module = .GATE };
    var browse_eq = ToggleModuleBrowserCmd{ .module = .EQ };
    var browse_comp = ToggleModuleBrowserCmd{ .module = .COMP };
    var browse_outpt = ToggleModuleBrowserCmd{ .module = .OUTPT };

    // Strip browser toggle
    var browse_strip = ToggleStripBrowserCmd{};

    // Close browser
    var close_cmd = CloseBrowserCmd{};

    // Scroll commands
    var scroll_up = ScrollFxCmd{ .value = 70 };
    var scroll_down = ScrollFxCmd{ .value = 58 };

    const commands = [_]Command(Model, System){
        Command(Model, System).init(&browse_input),
        Command(Model, System).init(&browse_gate),
        Command(Model, System).init(&browse_eq),
        Command(Model, System).init(&browse_comp),
        Command(Model, System).init(&browse_outpt),
        Command(Model, System).init(&browse_strip),
        Command(Model, System).init(&close_cmd),
        Command(Model, System).init(&scroll_up),
        Command(Model, System).init(&scroll_down),
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
        std.debug.print("\nfx_sel failure: {any}\n", .{failure});
        return error.TestFailed;
    }

    try testing.expect(rv == null);
}

test "fx_sel stateful - with random bytes" {
    const seeds = [_]u64{ 0xDEAD0001BEEF0002, 0x0123456789ABCDEF, 0xFACEFEED00112233 };
    for (seeds) |seed| {
        var seed_prng = std.Random.DefaultPrng.init(seed);
        var random_bytes: [4096]u8 = undefined;
        seed_prng.random().bytes(&random_bytes);
        try fxSelStatefulTest({}, &random_bytes);
    }
}
