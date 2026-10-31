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

test "mapping panel in strip assign mode renders the store key and param list" {
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

    builder.state.mapping_panel.mode = .{ .assign = statemachine.AssignSet.single(assign_state) };

    var ui = builder.build();
    var style_mgr = builder.buildStyleManager();

    _ = try gui_lib.main(null, &ui, 0, &style_mgr);

    // The module selection dropdown should be rendered
    // Every module is open at once: there is no combo to choose one, and each plate has its key that saves its mapping.
    try testing.expect(!mock.containsWidget(.begin_combo, "##module_selection"));
    try testing.expect(mock.containsWidget(.invisible_button, "##save_INPUT"));

    // The state of the plugin is stored without a named preset: there is no dropdown of presets, and the key of the plate is there.
    try testing.expect(!mock.containsWidget(.begin_combo, "##preset_selection"));
    try testing.expect(mock.containsWidget(.invisible_button, "##store_INPUT"));
    // The keys without a label are in the bar at the left.
    try testing.expect(mock.containsWidget(.invisible_button, "##midi_learn"));
    try testing.expect(mock.containsWidget(.invisible_button, "##map_close"));

    // In strip assign mode, all 5 module panels should be active (not disabled),
    // because ChannelStripMapping shares the same CC field names.
    try testing.expect(mock.containsWidget(.begin_combo, "##combo_Inpt_Gain"));
    try testing.expect(mock.containsWidget(.begin_combo, "##combo_Comp_Attack"));
    try testing.expect(mock.containsWidget(.begin_combo, "##combo_Eq_HiGain"));
    try testing.expect(mock.containsWidget(.begin_combo, "##combo_Out_Vol"));

    // The two reassignable strip-only controls should be rendered
    try testing.expect(mock.containsWidget(.begin_combo, "##combo_Tr_ext_sidechain"));
    try testing.expect(mock.containsWidget(.begin_combo, "##combo_Tr_order"));

    // No module panels should be disabled: the store key does not wait for a preset, and the knob panels are all enabled.
    try testing.expect(mock.widgetCount(.begin_disabled) == 0);
}

test "the store key of a plate does not need a preset to be loaded" {
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

    builder.state.mapping_panel.mode = .{ .assign = statemachine.AssignSet.single(assign_state) };

    var ui = builder.build();
    var style_mgr = builder.buildStyleManager();

    _ = try gui_lib.main(null, &ui, 0, &style_mgr);

    // The key that stores the state of the plugin is there, and it is enabled although no preset is loaded: it only needs a plugin.
    try testing.expect(mock.containsWidget(.invisible_button, "##store_COMPRESSOR"));
    // The plugin has a key that opens its window, and MIDI learn is in the bar at the left.
    try testing.expect(mock.containsWidget(.invisible_button, "##openfx_COMP"));
    try testing.expect(mock.containsWidget(.invisible_button, "##midi_learn"));
}

test "while the browser is open from the assignment, the window still shows the mapping panel" {
    const statemachine = @import("../statemachine.zig");
    const mappings = @import("../mappings.zig");

    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();
    setupGlobals();

    var builder = TestUiStateBuilder.init(testing.allocator);
    defer builder.deinit();
    _ = builder.withMode(.fx_sel);
    builder.preferences.show_track_list = false;
    builder.state.fx_sel.return_to_mapping = true;

    builder.state.mapping_panel.deinitCurrentSubMode();
    var assign_state = statemachine.AssignState.init(
        builder.state.mapping_panel.gpa_int.allocator(),
        .{ .COMP = mappings.Comp{} },
    );
    assign_state.assign_fx_index = 0;
    builder.state.mapping_panel.mode = .{ .assign = statemachine.AssignSet.single(assign_state) };

    var ui = builder.build();
    var style_mgr = builder.buildStyleManager();

    _ = try gui_lib.main(null, &ui, 0, &style_mgr);

    // The save keys of the plates are the ones of the mapping panel, and the keys of the panel of the FX controls are not there.
    try testing.expect(mock.containsWidget(.invisible_button, "##save_COMPRESSOR"));
    try testing.expect(!mock.containsWidget(.invisible_button, "##Out_mute"));
}

test "roundButton component renders with mock imgui" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();
    setupGlobals();

    const button = @import("../components/button.zig");
    const clicked = try button.roundButton(null, "test", "##test", null, null, null, null, null, null, null, null, null);

    try testing.expect(!clicked);
    // roundButton should record draw operations in the trace
    try testing.expect(mock.trace_list.items.len > 0);
}
