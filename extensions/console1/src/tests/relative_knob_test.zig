const std = @import("std");
const testing = std.testing;
const reaper = @import("reaper").reaper;
const models = @import("../models/models.zig");
const Globals = @import("../globals.zig");
const c1 = @import("../c1.zig");
const midi_events = @import("../csurf/midi_events.zig");
const Unit = @import("../unit/unit.zig");

// A track with one compressor, whose threshold the forward map points the Comp_Thresh knob at.
fn setupTrack(globals: *Globals, session: *@TypeOf(models.reaper.setupTestModel(testing.allocator, null, null).model_ptr.*)) !reaper.MediaTrack {
    reaper.InsertTrackAtIndex(0, false);
    const track = reaper.CSurf_TrackFromID(1, false).?;
    reaper.SetTrackSelected(track, true);
    _ = reaper.TrackFX_AddByName(track, "VST: ReaComp (Cockos)", false, -1);
    try session.setFxParams(1, 0, &.{.{ .name = "Threshold", .normalized_value = 0.5, .formatted_value = "0.5" }});
    globals.state.current_tr_id = 1;
    globals.state.fx_ctrl.track_state.forward_map.put(globals.arena_int.allocator(), .Comp_Thresh, .{ .fx_index = 0, .param_index = 0 }) catch unreachable;
    return track;
}

const Harness = struct {
    arena: std.heap.ArenaAllocator,
    reaper_teardown: @typeInfo(@TypeOf(models.reaper.setupTestModel)).@"fn".return_type.?,
    midi_teardown: @typeInfo(@TypeOf(models.midi.setupMidiMocks)).@"fn".return_type.?,
    globals: *Globals,
    track: reaper.MediaTrack,
    fx_index: c_int,
    param_index: c_int,

    fn init() !*Harness {
        const self = try testing.allocator.create(Harness);
        self.arena = std.heap.ArenaAllocator.init(testing.allocator);
        self.reaper_teardown = models.reaper.setupTestModel(self.arena.allocator(), null, null);
        self.midi_teardown = models.midi.setupMidiMocks(reaper);
        Globals.instance = try .defaults(testing.allocator);
        self.globals = &Globals.instance;
        self.globals.m_midi_out = reaper.CreateMIDIOutput(0, false, null);
        self.globals.state.current_mode = .fx_ctrl;
        self.track = try setupTrack(self.globals, self.reaper_teardown.model_ptr);
        const fxp = self.globals.state.fx_ctrl.track_state.forward_map.get(.Comp_Thresh) orelse return error.NoMapping;
        self.fx_index = fxp.fx_index;
        self.param_index = fxp.param_index;
        return self;
    }

    fn deinit(self: *Harness) void {
        self.globals.deinit();
        self.midi_teardown.teardown();
        self.reaper_teardown.teardown();
        self.arena.deinit();
        testing.allocator.destroy(self);
    }

    fn value(self: *Harness) f64 {
        return reaper.TrackFX_GetParamNormalized(self.track, self.fx_index, self.param_index);
    }

    fn set(self: *Harness, v: f64) void {
        _ = reaper.TrackFX_SetParamNormalized(self.track, self.fx_index, self.param_index, v);
    }

    fn tick(self: *Harness, delta: i8, fine: bool) void {
        midi_events.onUnitEvent(self.globals, .{ .tick = .{ .cc = .Comp_Thresh, .delta = delta, .fine = fine } });
    }
};

test "a tick moves the parameter from the value that REAPER has, by 1/127" {
    const h = try Harness.init();
    defer h.deinit();
    h.set(0.5);
    h.tick(1, false);
    try testing.expectApproxEqAbs(0.5 + 1.0 / 127.0, h.value(), 1e-9);
    h.tick(-1, false);
    h.tick(-1, false);
    try testing.expectApproxEqAbs(0.5 - 1.0 / 127.0, h.value(), 1e-9);
}

test "a parameter that something else moved does not make the knob jump" {
    const h = try Harness.init();
    defer h.deinit();
    h.set(0.2);
    h.tick(1, false);
    h.set(0.8);
    h.tick(1, false);
    try testing.expectApproxEqAbs(0.8 + 1.0 / 127.0, h.value(), 1e-9);
}

test "shift makes the tick a tenth of the step" {
    const h = try Harness.init();
    defer h.deinit();
    h.set(0.5);
    h.tick(1, true);
    try testing.expectApproxEqAbs(0.5 + 0.1 / 127.0, h.value(), 1e-9);
}

test "the sensitivity setting scales the step" {
    const h = try Harness.init();
    defer h.deinit();
    h.globals.preferences.sensitivity = 4.0;
    h.set(0.5);
    h.tick(1, false);
    try testing.expectApproxEqAbs(0.5 + 4.0 / 127.0, h.value(), 1e-9);
}

test "the value stops at 0 and at 1" {
    const h = try Harness.init();
    defer h.deinit();
    h.set(1.0);
    h.tick(1, false);
    try testing.expectEqual(@as(f64, 1.0), h.value());
    h.set(0.0);
    h.tick(-1, false);
    try testing.expectEqual(@as(f64, 0.0), h.value());
}

test "the ring shows the value, and the next legacy tick starts from it" {
    const h = try Harness.init();
    defer h.deinit();
    h.set(0.5);
    h.tick(1, false);
    const expected: u8 = @intFromFloat((0.5 + 1.0 / 127.0) * 127);
    try testing.expectEqual(expected, h.globals.unit.leds.value(.Comp_Thresh));
    try testing.expectEqual(expected, h.globals.unit.input.knob_pos[@backingInt(c1.CCs.Comp_Thresh)]);
}

test "outside the fx_ctrl mode a tick keeps the absolute emulation" {
    const h = try Harness.init();
    defer h.deinit();
    h.set(0.5);
    h.globals.state.current_mode = .transport;
    h.tick(1, false);
    try testing.expectEqual(@as(f64, 0.5), h.value());
}
