const std = @import("std");
const testing = std.testing;
const reaper = @import("reaper").reaper;
const models = @import("../models/models.zig");
const Globals = @import("../globals.zig");
const control_surface = @import("../csurf/control_surface.zig");

test "the surface that REAPER deletes after it made the next one leaves the devices of the next, and closing a surface without reset does not release its place" {
    var model_arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer model_arena.deinit();
    var reaper_teardown = models.reaper.setupTestModel(model_arena.allocator(), null, null);
    defer reaper_teardown.teardown();
    var midi_teardown = models.midi.setupMidiMocks(reaper);
    defer midi_teardown.teardown();
    Globals.instance = try .defaults(testing.allocator);
    defer Globals.instance.deinit();

    // When the settings change, REAPER makes the surface of the new ones before it deletes the old one.
    const first = control_surface.init(-1, -1, null);
    const second = control_surface.init(-1, -1, null);
    try testing.expect(control_surface.testMidiOwner() == second);

    // Deleting the old one runs its destructor, which the mock of the surface does not, and the new one keeps what it holds.
    control_surface.zSurfaceDestroyed(first);
    try testing.expect(control_surface.testMidiOwner() == second);
    try testing.expect(control_surface.my_csurf == second);

    // A surface that is closed without reset is not deleted by that: REAPER deletes it afterwards.
    control_surface.zCloseNoReset(second);
    try testing.expect(control_surface.testMidiOwner() == second);
    control_surface.zSurfaceDestroyed(second);
    try testing.expect(control_surface.testMidiOwner() == null);
    try testing.expect(control_surface.my_csurf == null);
}
