const std = @import("std");
const testing = std.testing;
const imgui = @import("reaper_imgui");
const MockImGui = @import("mock_imgui").MockImGui;
const TestUiStateBuilder = @import("../models/test_ui_state.zig").TestUiStateBuilder;
const gui_lib = @import("../gui_lib.zig");
const Theme = @import("../theme/c1_theme.zig");

/// Set up module-level globals that panel code accesses directly so that they
/// are not left as undefined (which triggers safety panics in debug builds).
fn setupGlobals() void {
    Theme.fonts.MAIN = null;
    Theme.fonts.ICON_FONT_SMALL = null;
}

test "gui_lib.main renders without error in fx_ctrl mode" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();
    setupGlobals();

    var builder = TestUiStateBuilder.init(testing.allocator);
    defer builder.deinit();
    builder.preferences.show_track_list = false;
    var ui = builder.build();
    var style_mgr = builder.buildStyleManager();

    const result = try gui_lib.main(null, &ui, 0, &style_mgr);

    try testing.expect(mock.widgetCount(.begin_window) > 0);
    // In fx_ctrl mode with no track selected and no interactions, there should be
    // no mode action returned.
    try testing.expect(result == null);
}

test "gui_lib.main renders without error in settings mode" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();
    setupGlobals();

    var builder = TestUiStateBuilder.init(testing.allocator);
    defer builder.deinit();
    _ = builder.withMode(.settings);
    var ui = builder.build();
    var style_mgr = builder.buildStyleManager();

    // settings mode requires a SettingsPanel instance; we set it on the ui
    const SettingsPanel = @import("../settings_panel.zig");
    var sp = try SettingsPanel.init(&builder.preferences);
    ui.settings_panel = &sp;

    const result = try gui_lib.main(null, &ui, 0, &style_mgr);

    try testing.expect(mock.widgetCount(.begin_window) > 0);
    _ = result;
}

test "gui_lib.main renders without error in transport mode" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();
    setupGlobals();

    var builder = TestUiStateBuilder.init(testing.allocator);
    defer builder.deinit();
    _ = builder.withMode(.transport);
    builder.preferences.show_track_list = false;
    var ui = builder.build();
    var style_mgr = builder.buildStyleManager();

    const result = try gui_lib.main(null, &ui, 0, &style_mgr);

    try testing.expect(mock.widgetCount(.begin_window) > 0);
    _ = result;
}

test "fx_ctrl panel shows disconnected text when midi not connected" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();
    setupGlobals();

    var builder = TestUiStateBuilder.init(testing.allocator);
    defer builder.deinit();
    _ = builder.withMidiConnected(false);
    builder.preferences.show_track_list = false;
    var ui = builder.build();
    var style_mgr = builder.buildStyleManager();

    _ = try gui_lib.main(null, &ui, 0, &style_mgr);

    // When midi is not connected, the fx_ctrl panel renders a disconnected message
    try testing.expect(mock.containsText("Console disconnected") or mock.containsWidget(.text_colored, "Console disconnected"));
}

test "mapping panel in strip assign mode renders preset checkbox and param list" {
    const statemachine = @import("../statemachine.zig");
    const mappings = @import("../mappings.zig");
    const StringPool = @import("string_pool").StringPool;

    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();
    setupGlobals();

    var builder = TestUiStateBuilder.init(testing.allocator);
    defer builder.deinit();
    _ = builder.withMode(.mapping_panel);
    builder.preferences.show_track_list = false;

    // Set up assign mode for STRIP with some parameters in the param store
    builder.state.mapping_panel.deinitCurrentSubMode();
    var assign_state = statemachine.AssignState.init(
        builder.state.mapping_panel.gpa_int.allocator(),
        .{ .STRIP = mappings.ChannelStripMapping{} },
    );
    assign_state.assign_fx_index = 0;

    // Add some fake parameters to the param store
    assign_state.param_store.addParam(0, "Gain") catch unreachable;
    assign_state.param_store.addParam(1, "Threshold") catch unreachable;
    assign_state.param_store.addParam(2, "Ratio") catch unreachable;

    // Add a fake preset to make the preset section visible
    assign_state.initPresetStrings(builder.state.mapping_panel.gpa_int.allocator());
    const arena_alloc = assign_state.arena.allocator();
    const ref = assign_state.preset_strings.intern(arena_alloc, "My Preset") catch unreachable;
    const offsets = arena_alloc.alloc(StringPool.StringRef, 1) catch unreachable;
    offsets[0] = ref;
    assign_state.preset_name_offsets = offsets;

    builder.state.mapping_panel.mode = .{ .assign = assign_state };

    var ui = builder.build();
    var style_mgr = builder.buildStyleManager();

    _ = try gui_lib.main(null, &ui, 0, &style_mgr);

    // The module selection dropdown should be rendered
    try testing.expect(mock.containsWidget(.begin_combo, "##module_selection"));

    // When preset data is populated, the preset section should be visible
    try testing.expect(mock.containsWidget(.begin_combo, "##preset_selection"));
    try testing.expect(mock.containsWidget(.checkbox, "Store preset in map file"));

    // In strip assign mode, all 5 module panels should be active (not disabled),
    // because ChannelStripMapping shares the same CC field names.
    try testing.expect(mock.containsWidget(.begin_combo, "##combo_Inpt_Gain"));
    try testing.expect(mock.containsWidget(.begin_combo, "##combo_Comp_Attack"));
    try testing.expect(mock.containsWidget(.begin_combo, "##combo_Eq_HiGain"));
    try testing.expect(mock.containsWidget(.begin_combo, "##combo_Out_Vol"));

    // The two reassignable strip-only controls should be rendered
    try testing.expect(mock.containsWidget(.begin_combo, "##combo_Tr_ext_sidechain"));
    try testing.expect(mock.containsWidget(.begin_combo, "##combo_Tr_order"));

    // No module panels should be disabled (the checkbox disabled region is expected
    // when no preset is selected, but the knob panels should all be enabled).
    // The only begin_disabled should be from the preset checkbox.
    try testing.expect(mock.widgetCount(.begin_disabled) <= 1);
}

test "mapping panel shows preset checkbox even without presets on disk" {
    const statemachine = @import("../statemachine.zig");
    const mappings = @import("../mappings.zig");

    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();
    setupGlobals();

    var builder = TestUiStateBuilder.init(testing.allocator);
    defer builder.deinit();
    _ = builder.withMode(.mapping_panel);
    builder.preferences.show_track_list = false;

    builder.state.mapping_panel.deinitCurrentSubMode();
    var assign_state = statemachine.AssignState.init(
        builder.state.mapping_panel.gpa_int.allocator(),
        .{ .COMP = mappings.Comp{} },
    );
    assign_state.assign_fx_index = 0;
    // No presets populated -- preset_name_offsets stays empty

    builder.state.mapping_panel.mode = .{ .assign = assign_state };

    var ui = builder.build();
    var style_mgr = builder.buildStyleManager();

    _ = try gui_lib.main(null, &ui, 0, &style_mgr);

    // Both the preset dropdown and checkbox should be rendered (disabled,
    // since there are no presets on disk).
    try testing.expect(mock.containsWidget(.begin_combo, "##preset_selection"));
    try testing.expect(mock.containsWidget(.checkbox, "Store preset in map file"));

    // The disabled region should wrap both the dropdown and checkbox
    try testing.expect(mock.widgetCount(.begin_disabled) >= 1);
}

test "roundButton component renders with mock imgui" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();
    setupGlobals();

    const button = @import("../components/button.zig");
    const clicked = try button.roundButton(null, "test", "##test", null, null, null, null, null);

    try testing.expect(!clicked);
    // roundButton should record draw operations in the trace
    try testing.expect(mock.trace_list.items.len > 0);
}
