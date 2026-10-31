const std = @import("std");
const testing = std.testing;
const reaper = @import("reaper").reaper;
const models = @import("../models/models.zig");
const Globals = @import("../globals.zig");
const statemachine = @import("../statemachine.zig");
const c1 = @import("../c1.zig");
const midi_events = @import("../csurf/midi_events.zig");
const Unit = @import("../unit/unit.zig");

const Harness = struct {
    arena: std.heap.ArenaAllocator,
    reaper_teardown: @typeInfo(@TypeOf(models.reaper.setupTestModel)).@"fn".return_type.?,
    midi_teardown: @typeInfo(@TypeOf(models.midi.setupMidiMocks)).@"fn".return_type.?,
    globals: *Globals,

    fn init(track_count: usize) !*Harness {
        const self = try testing.allocator.create(Harness);
        self.arena = std.heap.ArenaAllocator.init(testing.allocator);
        self.reaper_teardown = models.reaper.setupTestModel(self.arena.allocator(), null, null);
        self.midi_teardown = models.midi.setupMidiMocks(reaper);
        Globals.instance = try .defaults(testing.allocator);
        self.globals = &Globals.instance;
        self.globals.m_midi_out = reaper.CreateMIDIOutput(0, false, null);
        self.globals.state.current_mode = .fx_ctrl;
        for (0..track_count) |_| reaper.InsertTrackAtIndex(0, false);
        return self;
    }

    fn deinit(self: *Harness) void {
        self.globals.deinit();
        self.midi_teardown.teardown();
        self.reaper_teardown.teardown();
        self.arena.deinit();
        testing.allocator.destroy(self);
    }

    fn press(self: *Harness, cc: c1.CCs) void {
        midi_events.onUnitEvent(self.globals, .{ .press = cc });
    }

    fn shift(self: *Harness, held: bool) void {
        self.globals.unit.input.shift_held = held;
    }
};

test "shift with Tr1 to Tr6 opens the browser of the strip, shape, EQ, compressor, input and output" {
    const h = try Harness.init(2);
    defer h.deinit();
    const expected = [_]struct { cc: c1.CCs, module: statemachine.ModulesList }{
        .{ .cc = .Tr_tr1, .module = .STRIP },
        .{ .cc = .Tr_tr2, .module = .GATE },
        .{ .cc = .Tr_tr3, .module = .EQ },
        .{ .cc = .Tr_tr4, .module = .COMP },
        .{ .cc = .Tr_tr5, .module = .INPUT },
        .{ .cc = .Tr_tr6, .module = .OUTPT },
    };
    for (expected) |entry| {
        h.globals.state.current_mode = .fx_ctrl;
        h.shift(true);
        h.press(entry.cc);
        try testing.expectEqual(statemachine.Mode.fx_sel, h.globals.state.current_mode);
        try testing.expectEqual(entry.module, h.globals.state.fx_sel.current_category);
    }
}

test "shift with Tr20 opens the settings, and a shifted press does not select a track" {
    const h = try Harness.init(2);
    defer h.deinit();
    h.globals.state.current_tr_id = 1;
    h.shift(true);
    h.press(.Tr_tr20);
    try testing.expectEqual(statemachine.Mode.settings, h.globals.state.current_mode);
    try testing.expectEqual(@as(?c_int, 1), h.globals.state.current_tr_id);
}

test "shift only has these functions in the fx_ctrl mode" {
    const h = try Harness.init(2);
    defer h.deinit();
    h.globals.state.current_mode = .transport;
    h.shift(true);
    // In the transport mode shift does not make Tr1 open a browser: it maps the strip, as it does without shift, and a track
    // with no strip has nothing to map.
    h.press(.Tr_tr1);
    try testing.expectEqual(statemachine.Mode.transport, h.globals.state.current_mode);
}

test "shift with Tr7 creates a mapping: every module that has an FX is open at once, and the first one is focused" {
    const h = try Harness.init(2);
    defer h.deinit();
    h.globals.state.current_tr_id = 1;
    var locations = @import("../track_state.zig").ModuleLocations.initFill(null);
    locations.set(.GATE, .{ .fx_index = 0, .mapping = null });
    locations.set(.COMP, .{ .fx_index = 1, .mapping = null });
    h.globals.state.fx_ctrl.track_state.mode = .{ .multi_fx = locations };
    h.shift(true);
    h.press(.Tr_tr7);
    try testing.expectEqual(statemachine.Mode.mapping_panel, h.globals.state.current_mode);
    try testing.expect(h.globals.state.mapping_panel.mode == .assign);
    const set = &h.globals.state.mapping_panel.mode.assign;
    try testing.expectEqual(statemachine.ModulesList.GATE, set.focus);
    try testing.expect(set.getConst(.GATE) != null);
    try testing.expect(set.getConst(.COMP) != null);
    // A module that has no FX is not open.
    try testing.expect(set.getConst(.EQ) == null);
    try testing.expect(set.getConst(.INPUT) == null);
}

test "a control maps in its own module: the module is focused, and the others keep their mapping" {
    const h = try Harness.init(2);
    defer h.deinit();
    const actions = @import("../actions.zig");
    h.globals.state.current_tr_id = 1;
    var locations = @import("../track_state.zig").ModuleLocations.initFill(null);
    locations.set(.GATE, .{ .fx_index = 0, .mapping = null });
    locations.set(.COMP, .{ .fx_index = 1, .mapping = null });
    h.globals.state.fx_ctrl.track_state.mode = .{ .multi_fx = locations };
    actions.dispatch(h.globals, .{ .mapping_panel = .create_mapping });
    const set = &h.globals.state.mapping_panel.mode.assign;
    try testing.expectEqual(statemachine.ModulesList.GATE, set.focus);

    actions.dispatch(h.globals, .{ .mapping_panel = .{ .assign_add_mapping = .{ .param = 3, .control = .Shp_Gate } } });
    actions.dispatch(h.globals, .{ .mapping_panel = .{ .assign_add_mapping = .{ .param = 5, .control = .Comp_Ratio } } });
    try testing.expectEqual(statemachine.ModulesList.COMP, set.focus);
    try testing.expectEqual(@as(?u16, 5), set.getConst(.COMP).?.current_mappings.COMP.Comp_Ratio);
    try testing.expectEqual(@as(?u16, 3), set.getConst(.GATE).?.current_mappings.GATE.Shp_Gate);

    actions.dispatch(h.globals, .{ .mapping_panel = .{ .assign_remove_mapping = .Shp_Gate } });
    try testing.expectEqual(statemachine.ModulesList.GATE, set.focus);
    try testing.expectEqual(@as(?u16, null), set.getConst(.GATE).?.current_mappings.GATE.Shp_Gate);
    try testing.expectEqual(@as(?u16, 5), set.getConst(.COMP).?.current_mappings.COMP.Comp_Ratio);

    // The learn mode is the same for every module.
    actions.dispatch(h.globals, .{ .mapping_panel = .assign_toggle_midi_learn });
    try testing.expect(set.getConst(.GATE).?.midi_learn_active);
    try testing.expect(set.getConst(.COMP).?.midi_learn_active);

    // A control selected in one module is dropped when a control of another is selected.
    actions.dispatch(h.globals, .{ .mapping_panel = .{ .assign_select_control = .Shp_Gate } });
    actions.dispatch(h.globals, .{ .mapping_panel = .{ .assign_select_control = .Comp_Ratio } });
    try testing.expectEqual(@as(?c1.CCs, null), set.getConst(.GATE).?.selected_control);
    try testing.expectEqual(@as(?c1.CCs, .Comp_Ratio), set.getConst(.COMP).?.selected_control);
}

test "the store key of a plate toggles the preset of its own module" {
    const h = try Harness.init(2);
    defer h.deinit();
    const actions = @import("../actions.zig");
    h.globals.state.current_tr_id = 1;
    var locations = @import("../track_state.zig").ModuleLocations.initFill(null);
    locations.set(.GATE, .{ .fx_index = 0, .mapping = null });
    locations.set(.COMP, .{ .fx_index = 1, .mapping = null });
    h.globals.state.fx_ctrl.track_state.mode = .{ .multi_fx = locations };
    actions.dispatch(h.globals, .{ .mapping_panel = .create_mapping });
    const set = &h.globals.state.mapping_panel.mode.assign;

    actions.dispatch(h.globals, .{ .mapping_panel = .{ .assign_toggle_store_preset = .COMP } });
    try testing.expectEqual(statemachine.ModulesList.COMP, set.focus);
    try testing.expect(set.getConst(.COMP).?.store_preset_data);
    try testing.expect(!set.getConst(.GATE).?.store_preset_data);
}

test "create mapping without any FX on the track still opens the panel, with the first module focused" {
    const h = try Harness.init(2);
    defer h.deinit();
    h.globals.state.current_tr_id = 1;
    h.shift(true);
    h.press(.Tr_tr7);
    try testing.expectEqual(statemachine.Mode.mapping_panel, h.globals.state.current_mode);
    try testing.expect(h.globals.state.mapping_panel.mode == .assign);
    try testing.expectEqual(statemachine.ModulesList.INPUT, h.globals.state.mapping_panel.mode.assign.focus);
}

test "swapping the plugin from the assignment opens the browser of the module, and closing it comes back to the assignment" {
    const h = try Harness.init(2);
    defer h.deinit();
    const actions = @import("../actions.zig");
    h.globals.state.current_tr_id = 1;
    actions.dispatch(h.globals, .{ .mapping_panel = .create_mapping });
    actions.dispatch(h.globals, .{ .mapping_panel = .{ .enter_assign = .INPUT } });
    try testing.expect(h.globals.state.mapping_panel.mode == .assign);

    actions.dispatch(h.globals, .{ .mapping_panel = .{ .assign_swap_fx = .INPUT } });
    try testing.expectEqual(statemachine.Mode.fx_sel, h.globals.state.current_mode);
    try testing.expectEqual(statemachine.ModulesList.INPUT, h.globals.state.fx_sel.current_category);
    try testing.expect(h.globals.state.fx_sel.return_to_mapping);

    actions.dispatch(h.globals, .{ .fx_sel = .close_browser });
    try testing.expectEqual(statemachine.Mode.mapping_panel, h.globals.state.current_mode);
    try testing.expect(h.globals.state.mapping_panel.mode == .assign);
    try testing.expect(!h.globals.state.fx_sel.return_to_mapping);

    // Any other way into the browser forgets where it came from.
    actions.dispatch(h.globals, .{ .mapping_panel = .{ .assign_swap_fx = .GATE } });
    actions.dispatch(h.globals, .{ .fx_sel = .close_browser });
    actions.dispatch(h.globals, .{ .change_mode = .fx_ctrl });
    actions.dispatch(h.globals, .{ .fx_sel = .{ .toggle_module_browser = .COMP } });
    try testing.expect(!h.globals.state.fx_sel.return_to_mapping);
}

test "in the transport mode the first six buttons no longer map a module" {
    const h = try Harness.init(2);
    defer h.deinit();
    h.globals.state.current_mode = .transport;
    h.globals.state.current_tr_id = 1;
    var locations = @import("../track_state.zig").ModuleLocations.initFill(null);
    locations.set(.GATE, .{ .fx_index = 0, .mapping = null });
    h.globals.state.fx_ctrl.track_state.mode = .{ .multi_fx = locations };
    h.press(.Tr_tr2);
    try testing.expectEqual(statemachine.Mode.transport, h.globals.state.current_mode);
}

test "a plain Preset of the sysex unit no longer opens the mapping panel, and the legacy one still does" {
    const h = try Harness.init(2);
    defer h.deinit();
    h.globals.unit.link = .ready;
    h.globals.unit.backend = .sysex;
    h.press(.Inpt_preset);
    try testing.expectEqual(statemachine.Mode.fx_ctrl, h.globals.state.current_mode);

    h.globals.unit.link = .failed;
    h.globals.unit.backend = .legacy_cc;
    h.press(.Inpt_preset);
    try testing.expectEqual(statemachine.Mode.mapping_panel, h.globals.state.current_mode);
}

fn selectedTrackCount(globals: *Globals) usize {
    return globals.state.selectedTracks.count();
}

test "shift with Volume steps to the next and the previous track, and the page follows" {
    const h = try Harness.init(25);
    defer h.deinit();
    h.globals.state.current_tr_id = 19;
    h.shift(true);
    const next: Unit.ControlEvent = .{ .tick = .{ .cc = .Out_Vol, .delta = 1, .fine = true } };
    const previous: Unit.ControlEvent = .{ .tick = .{ .cc = .Out_Vol, .delta = -1, .fine = true } };

    midi_events.onUnitEvent(h.globals, next);
    try testing.expectEqual(@as(u8, 1), h.globals.state.fx_ctrl.current_page);
    try testing.expect(h.globals.state.selectedTracks.contains(20));
    try testing.expectEqual(@as(usize, 1), selectedTrackCount(h.globals));

    // In REAPER the selection comes back through the surface callbacks, which set the current track.
    h.globals.state.current_tr_id = 20;
    midi_events.onUnitEvent(h.globals, previous);
    try testing.expect(h.globals.state.selectedTracks.contains(19));
    try testing.expectEqual(@as(u8, 0), h.globals.state.fx_ctrl.current_page);
}

test "shift with Volume stops at the first and the last track" {
    const h = try Harness.init(3);
    defer h.deinit();
    h.shift(true);
    h.globals.state.current_tr_id = 0;
    midi_events.onUnitEvent(h.globals, .{ .tick = .{ .cc = .Out_Vol, .delta = -1, .fine = true } });
    try testing.expectEqual(@as(?c_int, 0), h.globals.state.current_tr_id);
    h.globals.state.current_tr_id = 3;
    midi_events.onUnitEvent(h.globals, .{ .tick = .{ .cc = .Out_Vol, .delta = 1, .fine = true } });
    try testing.expectEqual(@as(?c_int, 3), h.globals.state.current_tr_id);
}

test "in the transport mode the buttons of the cards do not open a browser of plugins" {
    // Because the harness owns the global state, each button gets a harness of its own, one after the other.
    const without_browser = [_]c1.CCs{ .Inpt_disp_on, .Shp_shape, .Eq_eq, .Tr_order, .Comp_comp, .Eq_lp_shape, .Eq_hp_shape };
    for (without_browser) |cc| {
        const h = try Harness.init(2);
        defer h.deinit();
        h.globals.state.current_mode = .transport;
        h.press(cc);
        try testing.expectEqual(statemachine.Mode.transport, h.globals.state.current_mode);
    }
}

test "in the transport mode the Sidechain button has no use, since the settings are on shift in the fx_ctrl mode" {
    const h = try Harness.init(2);
    defer h.deinit();
    h.globals.state.current_mode = .transport;
    h.press(.Tr_ext_sidechain);
    try testing.expectEqual(statemachine.Mode.transport, h.globals.state.current_mode);
}

test "with shift in the fx_ctrl mode, the last row of the track list opens the settings" {
    const h = try Harness.init(2);
    defer h.deinit();
    h.shift(true);
    h.press(.Tr_tr20);
    try testing.expectEqual(statemachine.Mode.settings, h.globals.state.current_mode);
}

test "when the Mode button is a modifier, the transport mode lasts while the button is held down" {
    const h = try Harness.init(2);
    defer h.deinit();
    h.globals.preferences.mode_is_modifier = true;
    h.press(.Inpt_disp_mode);
    try testing.expectEqual(statemachine.Mode.transport, h.globals.state.current_mode);
    midi_events.onUnitEvent(h.globals, .{ .release = .Inpt_disp_mode });
    try testing.expectEqual(statemachine.Mode.fx_ctrl, h.globals.state.current_mode);
    try testing.expect(!h.globals.mode_held);
}

test "without the preference, the Mode button toggles the transport mode when it is pressed, and its release does nothing" {
    const h = try Harness.init(2);
    defer h.deinit();
    h.press(.Inpt_disp_mode);
    try testing.expectEqual(statemachine.Mode.transport, h.globals.state.current_mode);
    midi_events.onUnitEvent(h.globals, .{ .release = .Inpt_disp_mode });
    try testing.expectEqual(statemachine.Mode.transport, h.globals.state.current_mode);
    h.press(.Inpt_disp_mode);
    try testing.expectEqual(statemachine.Mode.fx_ctrl, h.globals.state.current_mode);
}

test "holding Alt shows the transport mode from the FX controls, and releasing it brings them back, whatever the Mode button is" {
    const h = try Harness.init(2);
    defer h.deinit();
    // The Mode button is not a modifier here, which does not matter to Alt.
    h.globals.preferences.mode_is_modifier = false;

    midi_events.applyAltModifier(h.globals, true);
    try testing.expectEqual(statemachine.Mode.transport, h.globals.state.current_mode);
    // Holding it on keeps the mode, and polls of the same state do nothing.
    midi_events.applyAltModifier(h.globals, true);
    try testing.expectEqual(statemachine.Mode.transport, h.globals.state.current_mode);
    midi_events.applyAltModifier(h.globals, false);
    try testing.expectEqual(statemachine.Mode.fx_ctrl, h.globals.state.current_mode);
}

test "Alt does nothing outside of the FX controls, and its release only leaves the transport mode that it entered" {
    const h = try Harness.init(2);
    defer h.deinit();

    // Held in another mode, it does not enter the transport mode, and its release does not leave that mode.
    h.globals.state.current_mode = .settings;
    midi_events.applyAltModifier(h.globals, true);
    try testing.expectEqual(statemachine.Mode.settings, h.globals.state.current_mode);
    midi_events.applyAltModifier(h.globals, false);
    try testing.expectEqual(statemachine.Mode.settings, h.globals.state.current_mode);

    // The transport mode that the Mode button chose is not left by the release of Alt.
    h.globals.state.current_mode = .transport;
    midi_events.applyAltModifier(h.globals, true);
    midi_events.applyAltModifier(h.globals, false);
    try testing.expectEqual(statemachine.Mode.transport, h.globals.state.current_mode);
}
