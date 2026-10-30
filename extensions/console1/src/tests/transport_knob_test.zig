const std = @import("std");
const testing = std.testing;
const reaper = @import("reaper").reaper;
const models = @import("../models/models.zig");
const Globals = @import("../globals.zig");
const c1 = @import("../c1.zig");
const midi_events = @import("../csurf/midi_events.zig");

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
        self.globals.state.current_mode = .transport;
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

    fn tick(self: *Harness, cc: c1.CCs, delta: i8) void {
        midi_events.onUnitEvent(self.globals, .{ .tick = .{ .cc = cc, .delta = delta, .fine = false } });
    }
};

test "Volume in the transport mode steps through the tracks and wraps around" {
    const h = try Harness.init(3); // the master and 3 tracks
    defer h.deinit();
    h.globals.state.current_tr_id = 3;
    h.tick(.Out_Vol, 1);
    try testing.expectEqual(@as(?c_int, 0), h.globals.state.current_tr_id);
    h.tick(.Out_Vol, -1);
    try testing.expectEqual(@as(?c_int, 3), h.globals.state.current_tr_id);
    h.tick(.Out_Vol, -1);
    try testing.expectEqual(@as(?c_int, 2), h.globals.state.current_tr_id);
    try testing.expect(h.globals.state.selectedTracks.contains(2));
}

test "every knob of the transport mode takes a tick without moving the emulated position" {
    const h = try Harness.init(2);
    defer h.deinit();
    h.globals.state.current_tr_id = 1;
    const knobs = [_]c1.CCs{ .Inpt_HiCut, .Eq_LoGain, .Eq_LoMidGain, .Comp_Attack, .Eq_HiGain, .Out_Drive, .Out_DriveChar, .Out_Pan, .Out_Vol, .Comp_Thresh };
    for (knobs) |cc| {
        h.globals.unit.input.setKnobPosition(cc, 40);
        h.tick(cc, 1);
        h.tick(cc, -1);
        try testing.expectEqual(@as(u8, 40), h.globals.unit.input.knob_pos[@backingInt(cc)]);
    }
    try testing.expectEqual(@import("../statemachine.zig").Mode.transport, h.globals.state.current_mode);
}
