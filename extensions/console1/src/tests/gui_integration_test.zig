const std = @import("std");
const testing = std.testing;
const imgui = @import("reaper_imgui");
const zlowcheck = @import("zlowcheck");
const MockImGui = @import("mock_imgui").MockImGui;
const gui_lib = @import("../gui_lib.zig");
const actions_mod = @import("../actions.zig");
const action_types = @import("../action_types.zig");
const ModeAction = action_types.ModeAction;
const Globals = @import("../globals.zig").Globals;
const statemachine = @import("../statemachine.zig");
const Mode = statemachine.Mode;
const Theme = @import("../theme/c1_theme.zig");
const styles = @import("../styles.zig");
const UiState = @import("../ui_state.zig").UiState;
const SettingsPanel = @import("../settings_panel.zig");
const fx_types = @import("fx_parser_types");
const fx_parser = @import("fx_parser");

// -- Test harness --

const GuiTestHarness = struct {
    mock_imgui: *MockImGui,
    globals: *Globals,
    allocator: std.mem.Allocator,

    // Owned style data for StyleManager construction
    main_style: styles.StyleStruct,
    config_style: styles.StyleStruct,
    main_style_open: bool,
    config_style_open: bool,

    // FX parser globals that UiState references must be valid.
    // Because fx_parser module-level vars are undefined by default and
    // fx_parser.init() requires REAPER API calls, we provide our own empty data.
    fx_plugins_by_type: fx_types.FxByType,
    fx_chains: fx_types.Directory,
    track_templates: fx_types.Directory,
    fx_tags: fx_types.FxTags,

    fn init(allocator: std.mem.Allocator) !GuiTestHarness {
        var mock = try allocator.create(MockImGui);
        mock.* = MockImGui.init(allocator);
        mock.install();

        Theme.fonts.MAIN = null;
        Theme.fonts.ICON_FONT_SMALL = null;

        // We initialize Globals in-place on the heap rather than using
        // Globals.defaults() because ArenaAllocator stores self-referential
        // pointers. Copying a Globals value (which contains an ArenaAllocator)
        // after initialization corrupts those internal references, causing
        // panics during deinit.
        const globals = try allocator.create(Globals);
        globals.* = .{};
        globals.arena_int = std.heap.ArenaAllocator.init(allocator);
        const arena = globals.arena_int.allocator();
        globals.fs_ops = @import("fs_helpers").RealFileSystem.fileSystemOps();
        globals.resource_path = "";
        globals.preferences = try .defaults(arena);
        globals.mappings_list = .empty(arena);
        globals.map_store = .empty(arena, globals.resource_path);
        globals.translations = try .defaults(arena);
        globals.state = .init(arena);
        globals.state.current_mode = .fx_ctrl;

        return .{
            .mock_imgui = mock,
            .globals = globals,
            .allocator = allocator,
            .main_style = std.mem.zeroes(styles.StyleStruct),
            .config_style = std.mem.zeroes(styles.StyleStruct),
            .main_style_open = false,
            .config_style_open = false,
            .fx_plugins_by_type = fx_types.FxByType.initFill(.{}),
            .fx_chains = .{ .path = "", .name = "", .subdirs = null, .files = null },
            .track_templates = .{ .path = "", .name = "", .subdirs = null, .files = null },
            .fx_tags = .{ .category = .{}, .developer = .{} },
        };
    }

    fn deinit(self: *GuiTestHarness) void {
        self.mock_imgui.restore();
        self.mock_imgui.deinit();
        self.allocator.destroy(self.mock_imgui);

        self.globals.state.deinit(self.allocator);
        self.globals.arena_int.deinit();
        self.allocator.destroy(self.globals);
    }

    fn buildStyleManager(self: *GuiTestHarness) styles.StyleManager {
        return .{
            .MainStyle = &self.main_style,
            .ConfigStyle = &self.config_style,
            .main_style_open = &self.main_style_open,
            .config_style_open = &self.config_style_open,
        };
    }

    fn buildUiState(self: *GuiTestHarness) UiState {
        const g = self.globals;
        return .{
            .state = &g.state,
            .translations = &g.translations,
            .drwls_splitter = &g.drwls_splitter,
            .mappings_list = &g.mappings_list,
            .settings_panel = if (g.settings_panel) |*panel| panel else null,
            .preferences = &g.preferences,
            .midi_connected = g.m_midi_in != null,
            .main_font = Theme.fonts.MAIN,
            .icon_font = Theme.fonts.ICON_FONT_SMALL,
            .fx_plugins_by_type = &self.fx_plugins_by_type,
            .fx_chains = &self.fx_chains,
            .track_templates = &self.track_templates,
            .fx_tags = &self.fx_tags,
            .editing_cc = &g.state.fx_ctrl.editing_cc,
            .edit_buf = &g.state.fx_ctrl.edit_buf,
        };
    }

    /// Render one frame and return any ModeAction the GUI produced.
    fn renderFrame(self: *GuiTestHarness) !?ModeAction {
        var ui = self.buildUiState();
        var style_mgr = self.buildStyleManager();
        self.globals.preferences.show_track_list = false;

        const result = gui_lib.main(null, &ui, 0, &style_mgr) catch |err| {
            if (err == error.WindowClosed) return null;
            return err;
        };
        return result;
    }

    /// Render one frame and, if the GUI produced a ModeAction, dispatch it.
    fn step(self: *GuiTestHarness) !void {
        if (try self.renderFrame()) |action| {
            actions_mod.dispatch(self.globals, action);
        }
        self.mock_imgui.resetTrace();
    }

    fn currentMode(self: *const GuiTestHarness) Mode {
        return self.globals.state.current_mode;
    }
};

// -- Example-based integration tests --

test "integration: fx_ctrl mode renders and stays in fx_ctrl" {
    var harness = try GuiTestHarness.init(testing.allocator);
    defer harness.deinit();

    try harness.step();

    try testing.expectEqual(Mode.fx_ctrl, harness.currentMode());
}

test "integration: clicking settings button transitions to settings mode" {
    var harness = try GuiTestHarness.init(testing.allocator);
    defer harness.deinit();

    // The settings button in ButtonsBar has the "wrench" icon label "k"
    harness.mock_imgui.click("k");
    try harness.step();

    // The dispatch should have opened settings: settingsActions(.open) creates
    // a settings panel and transitions to .settings mode.
    try testing.expectEqual(Mode.settings, harness.currentMode());
    try testing.expect(harness.globals.settings_panel != null);
}

test "integration: settings save returns to fx_ctrl" {
    var harness = try GuiTestHarness.init(testing.allocator);
    defer harness.deinit();

    // Enter settings mode
    harness.mock_imgui.click("k");
    try harness.step();
    try testing.expectEqual(Mode.settings, harness.currentMode());

    // Click save button (label is "Save##stngs_sv")
    harness.mock_imgui.click("Save##stngs_sv");
    try harness.step();

    try testing.expectEqual(Mode.fx_ctrl, harness.currentMode());
    // Settings panel should be closed after save
    try testing.expect(harness.globals.settings_panel == null);
}

test "integration: settings cancel returns to fx_ctrl" {
    var harness = try GuiTestHarness.init(testing.allocator);
    defer harness.deinit();

    // Enter settings mode
    harness.mock_imgui.click("k");
    try harness.step();
    try testing.expectEqual(Mode.settings, harness.currentMode());

    // Click cancel button (label is "Cancel##stngs_x")
    harness.mock_imgui.click("Cancel##stngs_x");
    try harness.step();

    try testing.expectEqual(Mode.fx_ctrl, harness.currentMode());
    try testing.expect(harness.globals.settings_panel == null);
}

test "integration: clicking mapping panel button from fx_ctrl" {
    var harness = try GuiTestHarness.init(testing.allocator);
    defer harness.deinit();

    // The mapping panel button in ButtonsBar has the "plus" icon label "B"
    harness.mock_imgui.click("B");
    try harness.step();

    try testing.expectEqual(Mode.mapping_panel, harness.currentMode());
}

test "integration: mode transition validity across multiple frames" {
    var harness = try GuiTestHarness.init(testing.allocator);
    defer harness.deinit();

    // Frame 1: fx_ctrl -> settings (via button click)
    harness.mock_imgui.click("k");
    try harness.step();
    try testing.expectEqual(Mode.settings, harness.currentMode());

    // Frame 2: settings -> fx_ctrl (via cancel)
    harness.mock_imgui.click("Cancel##stngs_x");
    try harness.step();
    try testing.expectEqual(Mode.fx_ctrl, harness.currentMode());

    // Frame 3: fx_ctrl -> mapping_panel
    harness.mock_imgui.click("B");
    try harness.step();
    try testing.expectEqual(Mode.mapping_panel, harness.currentMode());
}

test "integration: rendering multiple frames without interaction stays in mode" {
    var harness = try GuiTestHarness.init(testing.allocator);
    defer harness.deinit();

    // Render 5 frames with no interactions
    for (0..5) |_| {
        try harness.step();
    }

    // Should still be in fx_ctrl
    try testing.expectEqual(Mode.fx_ctrl, harness.currentMode());
}

// -- Zlowcheck stateful tests: mode transition invariants --

// The model tracks the expected mode after each GUI interaction.
const GuiModel = struct {
    expected_mode: Mode,

    pub fn init() GuiModel {
        return .{ .expected_mode = .fx_ctrl };
    }

    pub fn reset(self: *GuiModel) void {
        self.expected_mode = .fx_ctrl;
    }
};

// The system wraps the GuiTestHarness.
const GuiSystem = struct {
    harness: *GuiTestHarness,

    pub fn init(harness: *GuiTestHarness) GuiSystem {
        return .{ .harness = harness };
    }

    pub fn reset(self: *GuiSystem) void {
        self.harness.globals.state.current_mode = .fx_ctrl;
        self.harness.globals.settings_panel = null;
        self.harness.mock_imgui.resetInteractions();
        self.harness.mock_imgui.resetTrace();
    }
};

const Command = zlowcheck.Command(GuiModel, GuiSystem);

// Command: render a frame with no interaction (noop)
const NoopCmd = struct {
    pub const name = "noop";

    pub fn checkPrecondition(_: *@This(), _: *GuiModel) bool {
        return true;
    }

    pub fn onModelOnly(_: *@This(), _: *GuiModel) void {}

    pub fn onPair(_: *@This(), model: *GuiModel, sut: *GuiSystem) !bool {
        sut.harness.step() catch return false;
        return model.expected_mode == sut.harness.currentMode();
    }
};

// Command: click the settings button (icon "k") in ButtonsBar.
// Because the settingsActions(.open) handler creates a SettingsPanel and
// transitions to .settings, this only applies from modes where the
// ButtonsBar is rendered and the transition to settings is valid.
const ClickSettingsCmd = struct {
    pub const name = "click_settings";

    pub fn checkPrecondition(_: *@This(), model: *GuiModel) bool {
        return switch (model.expected_mode) {
            .fx_ctrl, .transport => true,
            else => false,
        };
    }

    pub fn onModelOnly(_: *@This(), model: *GuiModel) void {
        model.expected_mode = .settings;
    }

    pub fn onPair(self: *@This(), model: *GuiModel, sut: *GuiSystem) !bool {
        sut.harness.mock_imgui.click("k");
        sut.harness.step() catch return false;
        self.onModelOnly(model);
        return model.expected_mode == sut.harness.currentMode();
    }
};

// Command: click the save button in the settings panel.
const ClickSettingsSaveCmd = struct {
    pub const name = "click_settings_save";

    pub fn checkPrecondition(_: *@This(), model: *GuiModel) bool {
        return model.expected_mode == .settings;
    }

    pub fn onModelOnly(_: *@This(), model: *GuiModel) void {
        model.expected_mode = .fx_ctrl;
    }

    pub fn onPair(self: *@This(), model: *GuiModel, sut: *GuiSystem) !bool {
        sut.harness.mock_imgui.click("Save##stngs_sv");
        sut.harness.step() catch return false;
        self.onModelOnly(model);
        return model.expected_mode == sut.harness.currentMode();
    }
};

// Command: click the cancel button in the settings panel.
const ClickSettingsCancelCmd = struct {
    pub const name = "click_settings_cancel";

    pub fn checkPrecondition(_: *@This(), model: *GuiModel) bool {
        return model.expected_mode == .settings;
    }

    pub fn onModelOnly(_: *@This(), model: *GuiModel) void {
        model.expected_mode = .fx_ctrl;
    }

    pub fn onPair(self: *@This(), model: *GuiModel, sut: *GuiSystem) !bool {
        sut.harness.mock_imgui.click("Cancel##stngs_x");
        sut.harness.step() catch return false;
        self.onModelOnly(model);
        return model.expected_mode == sut.harness.currentMode();
    }
};

// Command: click the mapping panel button (icon "B") in ButtonsBar.
const ClickMappingPanelCmd = struct {
    pub const name = "click_mapping_panel";

    pub fn checkPrecondition(_: *@This(), model: *GuiModel) bool {
        return model.expected_mode == .fx_ctrl;
    }

    pub fn onModelOnly(_: *@This(), model: *GuiModel) void {
        model.expected_mode = .mapping_panel;
    }

    pub fn onPair(self: *@This(), model: *GuiModel, sut: *GuiSystem) !bool {
        sut.harness.mock_imgui.click("B");
        sut.harness.step() catch return false;
        self.onModelOnly(model);
        return model.expected_mode == sut.harness.currentMode();
    }
};

test "integration: mode transitions stateful property test" {
    var harness = try GuiTestHarness.init(testing.allocator);
    defer harness.deinit();

    var noop_cmd = NoopCmd{};
    var click_settings_cmd = ClickSettingsCmd{};
    var click_save_cmd = ClickSettingsSaveCmd{};
    var click_cancel_cmd = ClickSettingsCancelCmd{};
    var click_mapping_cmd = ClickMappingPanelCmd{};

    const commands = [_]Command{
        Command.init(&noop_cmd),
        Command.init(&click_settings_cmd),
        Command.init(&click_save_cmd),
        Command.init(&click_cancel_cmd),
        Command.init(&click_mapping_cmd),
    };

    var model = GuiModel.init();
    var sut = GuiSystem.init(&harness);

    var bytes: [4096]u8 = undefined;
    std.crypto.random.bytes(&bytes);
    var prng = zlowcheck.FinitePrng.init(&bytes);
    var random = prng.random();

    var cmd_seq = zlowcheck.CommandList(GuiModel, GuiSystem).init(
        &commands,
        &random,
        30,
        testing.allocator,
    ) catch return;
    defer cmd_seq.deinit(testing.allocator);

    const config = zlowcheck.StatefulConfig{ .verbose = false };
    const result = try zlowcheck.assertStateful(
        GuiModel,
        GuiSystem,
        &cmd_seq,
        &model,
        &sut,
        config,
    );

    if (result) |_| {
        return error.TestUnexpectedResult;
    }
}
