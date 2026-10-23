const std = @import("std");
const models = @import("../models/models.zig");
const c1 = @import("../c1.zig");
const Globals = @import("../globals.zig");
const reaper = @import("reaper").reaper;

/// convenience function that lumps together the setup/teardown
/// utilities of the reaper mocks, midi mocks, and minimal globals.
pub fn test_setup(allocator: std.mem.Allocator) !struct {
    reaper_teardown: @typeInfo(@TypeOf(models.reaper.setupTestModel)).@"fn".return_type.?,
    midi_teardown: @typeInfo(@TypeOf(models.midi.setupMidiMocks)).@"fn".return_type.?,
    globals: *Globals,
    pub fn teardown(self: *@This()) void {
        models.midi.clearEventQueue();
        self.reaper_teardown.teardown();
        self.midi_teardown.teardown();
        self.globals.deinit();
    }
} {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const reaper_teardown = models.reaper.setupTestModel(arena.allocator(), null, null);
    const midi_teardown = models.midi.setupMidiMocks(reaper);
    Globals.instance = try .defaults(allocator);

    return .{
        .reaper_teardown = reaper_teardown,
        .midi_teardown = midi_teardown,
        .globals = &Globals.instance,
    };
}

test "control surface init switches from suspended to fx_ctrl" {
    var g_teardown = try test_setup(std.testing.allocator);
    defer g_teardown.teardown();

    const midi_out_inst = models.midi.getModelInstance();
    for (std.enums.values(c1.CCs)) |cc| {
        midi_out_inst.updateValue(cc, 0x7f); // set all values to max
    }

    Globals.instance.state.current_mode = .suspended;

    // Call control_surface.init with valid device IDs (0 and 0)
    // This should trigger the mode switch
    _ = @import("../csurf/control_surface.zig").init(0, 0, null);

    // Verify state machine switched to fx_ctrl
    try std.testing.expectEqual(@import("../statemachine.zig").Mode.fx_ctrl, Globals.instance.state.current_mode);
    for (std.enums.values(c1.CCs)) |cc| {
        if (cc == c1.CCs.Comp_Mtr or cc == c1.CCs.Shp_Mtr) {
            try std.testing.expectEqual(midi_out_inst.getValue(cc), 0x7f);
        } else {
            try std.testing.expectEqual(midi_out_inst.getValue(cc), 0x0);
        }
    }
}
