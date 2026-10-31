const std = @import("std");
const testing = std.testing;
const imgui = @import("reaper_imgui");
const MockImGui = @import("mock_imgui").MockImGui;
const TestUiStateBuilder = @import("../models/test_ui_state.zig").TestUiStateBuilder;
const fx_sel_panel = @import("../fx_sel_panel.zig");
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
    // A channel strip is one card, which has the keys of the strip, and not the keys of five plates.
    try testing.expect(mock.containsWidget(.invisible_button, "##save_CHANNEL STRIP"));
    try testing.expect(!mock.containsWidget(.invisible_button, "##save_INPUT"));
    try testing.expect(!mock.containsWidget(.invisible_button, "##save_COMPRESSOR"));

    // The state of the plugin is stored without a named preset: there is no dropdown of presets, and the key of the plate is there.
    try testing.expect(!mock.containsWidget(.begin_combo, "##preset_selection"));
    try testing.expect(mock.containsWidget(.invisible_button, "##store_CHANNEL STRIP"));
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

    // No module is disabled: the only disabled things are the four track controls of the output, which are not mapped (the pan,
    // the solo, the mute and the volume).
    try testing.expectEqual(@as(usize, 4), mock.widgetCount(.begin_disabled));
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

test "typing in the search of the browser replaces its cards with the plugins that match" {
    fx_sel_panel.testSearchBuffer()[0] = 0;
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();
    setupGlobals();

    var builder = TestUiStateBuilder.init(testing.allocator);
    defer builder.deinit();
    _ = builder.withMode(.fx_sel);
    builder.preferences.show_track_list = false;
    try builder.fx_plugins_by_type.getPtr(.VST).put(testing.allocator, "VST: ReaComp (Cockos)", {});
    defer builder.fx_plugins_by_type.getPtr(.VST).deinit(testing.allocator);

    // Without a search, the browser has its two cards and the input.
    var ui = builder.build();
    var style_mgr = builder.buildStyleManager();
    _ = try gui_lib.main(null, &ui, 0, &style_mgr);
    try testing.expect(mock.containsWidget(.input_text, "##fx_search"));
    try testing.expect(mock.containsWidget(.begin_child, "##fx_card_menus"));
    try testing.expect(!mock.containsWidget(.begin_child, "##fx_card_search"));

    // With letters in it, the card of the results is there instead.
    mock.resetTrace();
    // The first frame has just opened the browser, so the text is put in once the browser has been drawn.
    @memcpy(fx_sel_panel.testSearchBuffer()[0..4], "comp");
    ui = builder.build();
    _ = try gui_lib.main(null, &ui, 0, &style_mgr);
    try testing.expect(mock.containsWidget(.begin_child, "##fx_card_search"));
    try testing.expect(!mock.containsWidget(.begin_child, "##fx_card_menus"));
    try testing.expect(!mock.containsWidget(.begin_child, "##fx_card_mapped"));
}

test "the keys move through the results of the search, and Enter inserts the one that they are on" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();
    setupGlobals();
    fx_sel_panel.testSearchBuffer()[0] = 0;

    // Because the mock does not give the keys numbers, each one that is used here gets its own, and they are put back after.
    const saved_keys = [_]c_int{ imgui.Key_Enter, imgui.Key_KeypadEnter, imgui.Key_DownArrow, imgui.Key_UpArrow, imgui.Key_PageDown, imgui.Key_PageUp, imgui.Key_Escape };
    imgui.Key_Enter = 101;
    imgui.Key_KeypadEnter = 102;
    imgui.Key_DownArrow = 103;
    imgui.Key_UpArrow = 104;
    imgui.Key_PageDown = 105;
    imgui.Key_PageUp = 106;
    imgui.Key_Escape = 107;
    defer {
        imgui.Key_Enter = saved_keys[0];
        imgui.Key_KeypadEnter = saved_keys[1];
        imgui.Key_DownArrow = saved_keys[2];
        imgui.Key_UpArrow = saved_keys[3];
        imgui.Key_PageDown = saved_keys[4];
        imgui.Key_PageUp = saved_keys[5];
        imgui.Key_Escape = saved_keys[6];
    }

    var builder = TestUiStateBuilder.init(testing.allocator);
    defer builder.deinit();
    _ = builder.withMode(.fx_sel);
    builder.preferences.show_track_list = false;
    try builder.fx_plugins_by_type.getPtr(.VST).put(testing.allocator, "VST: ReaComp (Cockos)", {});
    try builder.fx_plugins_by_type.getPtr(.JS).put(testing.allocator, "JS: Compressor Deluxe", {});
    defer builder.fx_plugins_by_type.getPtr(.VST).deinit(testing.allocator);
    defer builder.fx_plugins_by_type.getPtr(.JS).deinit(testing.allocator);

    var ui = builder.build();
    var style_mgr = builder.buildStyleManager();
    // The first frame opens the browser, and then the text is typed.
    _ = try gui_lib.main(null, &ui, 0, &style_mgr);
    @memcpy(fx_sel_panel.testSearchBuffer()[0..4], "comp");

    mock.pressKey(imgui.Key_Enter);
    ui = builder.build();
    const best = (try gui_lib.main(null, &ui, 0, &style_mgr)).?.fx_sel.plugin.name;

    // Down moves to the next result, and Enter inserts that one.
    mock.pressKey(imgui.Key_DownArrow);
    ui = builder.build();
    const next = (try gui_lib.main(null, &ui, 0, &style_mgr)).?.fx_sel.plugin.name;
    try testing.expect(!std.mem.eql(u8, best, next));

    // Up goes back to the first.
    mock.key_press_targets.clearRetainingCapacity();
    mock.pressKey(imgui.Key_UpArrow);
    mock.pressKey(imgui.Key_Enter);
    ui = builder.build();
    const again = (try gui_lib.main(null, &ui, 0, &style_mgr)).?.fx_sel.plugin.name;
    try testing.expectEqualStrings(best, again);
}

test "Escape closes the browser when the search does not have the keyboard" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();
    setupGlobals();
    fx_sel_panel.testSearchBuffer()[0] = 0;

    const saved_escape = imgui.Key_Escape;
    imgui.Key_Escape = 107;
    defer imgui.Key_Escape = saved_escape;

    var builder = TestUiStateBuilder.init(testing.allocator);
    defer builder.deinit();
    _ = builder.withMode(.fx_sel);
    builder.preferences.show_track_list = false;

    var ui = builder.build();
    var style_mgr = builder.buildStyleManager();
    try testing.expect((try gui_lib.main(null, &ui, 0, &style_mgr)) == null);

    mock.pressKey(imgui.Key_Escape);
    ui = builder.build();
    const action = (try gui_lib.main(null, &ui, 0, &style_mgr)).?;
    try testing.expect(action.fx_sel == .close_browser);

    // Text that was typed does not keep it open when the field has not the keyboard: it is not where the key is for.
    @memcpy(fx_sel_panel.testSearchBuffer()[0..4], "comp");
    ui = builder.build();
    const with_text = (try gui_lib.main(null, &ui, 0, &style_mgr)).?;
    try testing.expect(with_text.fx_sel == .close_browser);
}

test "the FX controls of a channel strip are drawn as one card, and every module is still there" {
    var mock = MockImGui.init(testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();
    setupGlobals();

    var builder = TestUiStateBuilder.init(testing.allocator);
    defer builder.deinit();
    _ = builder.withMode(.fx_ctrl);
    builder.preferences.show_track_list = false;
    builder.state.fx_ctrl.track_state.mode = .{ .channel_strip = .{
        .fx_index = 0,
        .mapping = .{},
        .guid = std.mem.zeroes(@import("utils").Guid),
    } };

    var ui = builder.build();
    var style_mgr = builder.buildStyleManager();
    _ = try gui_lib.main(null, &ui, 0, &style_mgr);
    // The second frame has the card drawn with the size that it had.
    _ = try gui_lib.main(null, &ui, 0, &style_mgr);

    try testing.expect(mock.containsWidget(.invisible_button, "Inpt_Gain"));
    try testing.expect(mock.containsWidget(.invisible_button, "Eq_LoFrq"));
    try testing.expect(mock.containsWidget(.invisible_button, "Out_Vol"));
    // The plates are not bare any more once the card is done.
    try testing.expect(!@import("../components/module_plate.zig").sections_open);
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
