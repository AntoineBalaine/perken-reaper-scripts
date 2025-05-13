const std = @import("std");
const models = @import("../models/models.zig");
const c1 = @import("../c1.zig");
const Globals = @import("../globals.zig");
const reaper = @import("../reaper.zig").reaper;

test "control surface init switches from suspended to fx_ctrl" {
    const teardown = models.reaper.setupTestModel(std.testing.allocator, null, null);
    defer teardown.teardown();

    // Set up the mock API
    _ = models.midi.setupMidiMocks(reaper);
    const midi_out_inst = models.midi.getModelInstance();
    for (std.enums.values(c1.CCs)) |cc| {
        midi_out_inst.updateValue(cc, 0x7f); // set all values to max
    }

    Globals.instance = try models.initMinimalGlobals();
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
