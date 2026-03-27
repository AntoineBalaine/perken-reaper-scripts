const std = @import("std");
const testing = std.testing;
const imgui = @import("reaper_imgui");
const MockImGui = @import("../models/mock_imgui.zig").MockImGui;
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
