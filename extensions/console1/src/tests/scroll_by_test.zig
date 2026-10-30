const std = @import("std");
const testing = std.testing;
const models = @import("../models/models.zig");
const Globals = @import("../globals.zig");
const SettingsPanel = @import("../settings_panel.zig");
const statemachine = @import("../statemachine.zig");
const midi_events = @import("../csurf/midi_events.zig");

fn volumeTick(globals: *Globals, delta: i8) void {
    midi_events.onUnitEvent(globals, .{ .tick = .{ .cc = .Out_Vol, .delta = delta, .fine = false } });
}

test "Volume ticks scroll the settings one row at a time and wrap" {
    Globals.instance = try .defaults(testing.allocator);
    defer Globals.instance.deinit();
    const globals = &Globals.instance;
    globals.settings_panel = try SettingsPanel.init(&globals.preferences);
    globals.state.current_mode = .settings;

    volumeTick(globals, 1);
    volumeTick(globals, 1);
    try testing.expectEqual(@as(u8, 2), globals.settings_panel.?.scroll_position_rel);
    volumeTick(globals, -1);
    try testing.expectEqual(@as(u8, 1), globals.settings_panel.?.scroll_position_rel);
    volumeTick(globals, -1);
    volumeTick(globals, -1);
    // From the first row up, the list wraps to the last one.
    try testing.expect(globals.settings_panel.?.scroll_position_rel > 1);
}

test "Volume ticks move the module of the mapping browser" {
    Globals.instance = try .defaults(testing.allocator);
    defer Globals.instance.deinit();
    const globals = &Globals.instance;
    globals.state.current_mode = .mapping_panel;
    globals.state.mapping_panel.mode = .{ .browse = .init(testing.allocator) };
    defer globals.state.mapping_panel.mode.browse.arena.deinit();

    volumeTick(globals, 1);
    try testing.expectEqual(statemachine.ModulesList.GATE, globals.state.mapping_panel.mode.browse.selected_module);
    volumeTick(globals, -1);
    volumeTick(globals, -1);
    try testing.expectEqual(statemachine.ModulesList.STRIP, globals.state.mapping_panel.mode.browse.selected_module);
}

test "the controller scrolls through the plugins of the browser and then through its menus, enters one and leaves it" {
    const fxp = @import("fx_parser");
    const fx_browser = @import("../fx_browser.zig");
    Globals.instance = try .defaults(testing.allocator);
    defer Globals.instance.deinit();
    const globals = &Globals.instance;
    fxp.fx_chains = .{ .path = "/chains", .name = "chains", .subdirs = null, .files = null };
    fxp.track_templates = .{ .path = "/templates", .name = "templates", .subdirs = null, .files = null };
    fxp.pluginsByType = fxp.FxByType.initFill(.{});
    fxp.fx_tags = .{ .category = .{}, .developer = .{} };
    globals.state.current_mode = .fx_sel;
    globals.state.fx_sel.current_category = .COMP;
    const mapped = globals.mappings_list.list.get(.COMP).count();

    // Because the first level has the plugins with a mapping and then the menus, a tick down from the last plugin lands on
    // the first menu, and the cursor goes on to the menu of all the plugins.
    const all_plugins_row = mapped + @backingInt(fx_browser.RootMenu.all_plugins);
    for (0..all_plugins_row) |_| volumeTick(globals, 1);
    try testing.expectEqual(all_plugins_row, globals.state.fx_sel.scroll_position_rel);

    // Confirming a menu enters it, with the cursor on its first entry.
    fxSelConfirm(globals);
    try testing.expectEqual(@as(u8, 1), globals.state.fx_sel.menu_depth);
    try testing.expectEqual(@as(usize, 0), globals.state.fx_sel.cursorPtr().*);
    volumeTick(globals, 1);
    try testing.expectEqual(@as(usize, 1), globals.state.fx_sel.cursorPtr().*);

    // Cancel leaves it, and the cursor of the first level is on the menu that was open.
    fxSelBack(globals);
    try testing.expectEqual(@as(u8, 0), globals.state.fx_sel.menu_depth);
    try testing.expectEqual(all_plugins_row, globals.state.fx_sel.scroll_position_rel);
}

fn fxSelConfirm(globals: *Globals) void {
    @import("../fx_sel_actions.zig").fxSelActions(globals, .confirm);
}

fn fxSelBack(globals: *Globals) void {
    @import("../fx_sel_actions.zig").fxSelActions(globals, .back);
}
