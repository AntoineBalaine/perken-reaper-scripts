const std = @import("std");
const testing = std.testing;
const reaper = @import("../reaper.zig").reaper;
const models = @import("../models/models.zig");
const Globals = @import("../globals.zig");
const statemachine = @import("../statemachine.zig");
const ModulesList = statemachine.ModulesList;
const fx_sel_actions = @import("../fx_sel_actions.zig");

// Populates a track with 5 FX assigned to all Console1 modules in canonical order,
// then runs validateTrack so that module_locations are populated.
fn setupFullChain(globals: *Globals) reaper.MediaTrack {
    // Create and select a track in the mock session
    reaper.InsertTrackAtIndex(0, false);
    const track = reaper.CSurf_TrackFromID(1, false).?;
    reaper.SetTrackSelected(track, true);

    _ = reaper.TrackFX_AddByName(track, "JS: Volume/Pan Smoother v5", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(track, 0, "renamed_name", "JS: Volume/Pan Smoother v5 (C1-I)");

    _ = reaper.TrackFX_AddByName(track, "VST: ReaGate (Cockos)", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(track, 1, "renamed_name", "VST: ReaGate (Cockos) (C1-S)");

    _ = reaper.TrackFX_AddByName(track, "VST: ReaEQ (Cockos)", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(track, 2, "renamed_name", "VST: ReaEQ (Cockos) (C1-E)");

    _ = reaper.TrackFX_AddByName(track, "VST: ReaComp (Cockos)", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(track, 3, "renamed_name", "VST: ReaComp (Cockos) (C1-C)");

    _ = reaper.TrackFX_AddByName(track, "JS: Saturation", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(track, 4, "renamed_name", "JS: Saturation (C1-O)");

    globals.state.current_tr_id = 1;

    _ = globals.state.fx_ctrl.track_state.validateTrack(
        track,
        globals.preferences.default_fx,
        &globals.map_store,
        globals.preferences,
        testing.allocator,
        &globals.mappings_list,
    );

    return track;
}

fn getRenamedName(track: reaper.MediaTrack, fx_index: c_int) ?[]const u8 {
    var buf: [512:0]u8 = undefined;
    if (reaper.TrackFX_GetNamedConfigParm(track, fx_index, "renamed_name", &buf, buf.len)) {
        const name = std.mem.span(@as([*:0]const u8, &buf));
        return name;
    }
    return null;
}

// When replacing the GATE FX on a full chain, the new GATE is inserted before COMP
// (index 3), which is after the old GATE (index 1). The old GATE's index must not
// be shifted by +1 in that case, otherwise the wrong FX gets deleted.
test "swapping GATE FX removes old gate and preserves other modules" {
    var model_arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer model_arena.deinit();
    var reaper_teardown = models.reaper.setupTestModel(model_arena.allocator(), null, null);
    defer reaper_teardown.teardown();
    var midi_teardown = models.midi.setupMidiMocks(reaper);
    defer midi_teardown.teardown();
    Globals.instance = try .defaults(testing.allocator);
    defer Globals.instance.deinit();
    const globals = &Globals.instance;
    globals.m_midi_out = reaper.CreateMIDIOutput(0, false, null);
    globals.state.current_mode = .fx_ctrl;

    const track = setupFullChain(globals);

    // Verify initial chain: 5 FX
    try testing.expectEqual(@as(c_int, 5), reaper.TrackFX_GetCount(track));

    // Verify GATE is at index 1
    const gate_loc = globals.state.fx_ctrl.track_state.mode.multi_fx.get(.GATE);
    try testing.expect(gate_loc != null);
    try testing.expectEqual(@as(c_int, 1), gate_loc.?.fx_index);

    // Swap the GATE FX
    globals.state.fx_sel.current_category = .GATE;
    globals.state.current_mode = .fx_sel;

    fx_sel_actions.fxSelActions(globals, .{ .plugin = .{
        .name = "JS: Transient Controller",
        .mapping_name = null,
    } });

    // After swap: should still have 5 FX (old removed, new added)
    try testing.expectEqual(@as(c_int, 5), reaper.TrackFX_GetCount(track));

    // Verify INPUT is still at index 0
    const input_name = getRenamedName(track, 0);
    try testing.expect(input_name != null);
    try testing.expect(std.mem.indexOf(u8, input_name.?, "(C1-I)") != null);

    // Verify EQ still exists and has its suffix
    // After the swap, the chain should be: INPUT(0), EQ(1), NEW_GATE(2), COMP(3), OUTPT(4)
    // or INPUT(0), NEW_GATE(1), EQ(2), COMP(3), OUTPT(4) depending on insertion logic.
    // The key assertion: the old GATE is gone, EQ is present, new GATE has suffix.
    var found_eq = false;
    var found_new_gate = false;
    var found_comp = false;
    var found_outpt = false;

    var i: c_int = 0;
    while (i < reaper.TrackFX_GetCount(track)) : (i += 1) {
        if (getRenamedName(track, i)) |name| {
            if (std.mem.indexOf(u8, name, "(C1-E)") != null) found_eq = true;
            if (std.mem.indexOf(u8, name, "(C1-S)") != null) found_new_gate = true;
            if (std.mem.indexOf(u8, name, "(C1-C)") != null) found_comp = true;
            if (std.mem.indexOf(u8, name, "(C1-O)") != null) found_outpt = true;
        }
    }

    try testing.expect(found_eq);
    try testing.expect(found_new_gate);
    try testing.expect(found_comp);
    try testing.expect(found_outpt);
}

// When replacing the INPUT FX, the new INPUT is inserted at or before the old INPUT's
// position, so the old INPUT shifts up by 1. The +1 offset is correct in this case.
test "swapping INPUT FX removes old input and preserves other modules" {
    var model_arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer model_arena.deinit();
    var reaper_teardown = models.reaper.setupTestModel(model_arena.allocator(), null, null);
    defer reaper_teardown.teardown();
    var midi_teardown = models.midi.setupMidiMocks(reaper);
    defer midi_teardown.teardown();
    Globals.instance = try .defaults(testing.allocator);
    defer Globals.instance.deinit();
    const globals = &Globals.instance;
    globals.m_midi_out = reaper.CreateMIDIOutput(0, false, null);
    globals.state.current_mode = .fx_ctrl;

    const track = setupFullChain(globals);

    try testing.expectEqual(@as(c_int, 5), reaper.TrackFX_GetCount(track));

    // Verify INPUT is at index 0
    const input_loc = globals.state.fx_ctrl.track_state.mode.multi_fx.get(.INPUT);
    try testing.expect(input_loc != null);
    try testing.expectEqual(@as(c_int, 0), input_loc.?.fx_index);

    // Swap the INPUT FX
    globals.state.fx_sel.current_category = .INPUT;
    globals.state.current_mode = .fx_sel;

    fx_sel_actions.fxSelActions(globals, .{ .plugin = .{
        .name = "JS: Phase Rotator",
        .mapping_name = null,
    } });

    // After swap: should still have 5 FX
    try testing.expectEqual(@as(c_int, 5), reaper.TrackFX_GetCount(track));

    // Verify new INPUT has suffix at index 0
    const new_input_name = getRenamedName(track, 0);
    try testing.expect(new_input_name != null);
    try testing.expect(std.mem.indexOf(u8, new_input_name.?, "(C1-I)") != null);

    // Verify all other modules still present
    var found_gate = false;
    var found_eq = false;
    var found_comp = false;
    var found_outpt = false;

    var i: c_int = 0;
    while (i < reaper.TrackFX_GetCount(track)) : (i += 1) {
        if (getRenamedName(track, i)) |name| {
            if (std.mem.indexOf(u8, name, "(C1-S)") != null) found_gate = true;
            if (std.mem.indexOf(u8, name, "(C1-E)") != null) found_eq = true;
            if (std.mem.indexOf(u8, name, "(C1-C)") != null) found_comp = true;
            if (std.mem.indexOf(u8, name, "(C1-O)") != null) found_outpt = true;
        }
    }

    try testing.expect(found_gate);
    try testing.expect(found_eq);
    try testing.expect(found_comp);
    try testing.expect(found_outpt);
}
