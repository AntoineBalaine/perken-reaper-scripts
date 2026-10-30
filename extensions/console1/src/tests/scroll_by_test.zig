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
