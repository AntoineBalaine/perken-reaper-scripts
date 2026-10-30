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
    // In the transport mode Tr1 loads the input, as it does without shift.
    h.press(.Tr_tr1);
    try testing.expectEqual(statemachine.Mode.fx_sel, h.globals.state.current_mode);
    try testing.expectEqual(statemachine.ModulesList.INPUT, h.globals.state.fx_sel.current_category);
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
