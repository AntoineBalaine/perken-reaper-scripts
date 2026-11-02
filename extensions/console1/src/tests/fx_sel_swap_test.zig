const std = @import("std");
const testing = std.testing;
const reaper = @import("reaper").reaper;
const models = @import("../models/models.zig");
const Globals = @import("../globals.zig");
const statemachine = @import("../statemachine.zig");
const ModulesList = statemachine.ModulesList;
const fx_sel_actions = @import("../fx_sel_actions.zig");

// Populates a track with 5 FX assigned to all Console1 modules in canonical order,
// then runs validateTrack so that module_locations are populated.
fn setupFullChain(globals: *Globals) reaper.MediaTrack {
    const io = Globals.hostIo();
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
        globals.arena_int.allocator(),
        io,
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

test "swapping a plugin from the mapping panel comes back to the mapping panel, on the new plugin" {
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
    const actions = @import("../actions.zig");

    _ = setupFullChain(globals);
    actions.dispatch(globals, .{ .mapping_panel = .create_mapping });
    try testing.expectEqual(statemachine.Mode.mapping_panel, globals.state.current_mode);

    actions.dispatch(globals, .{ .mapping_panel = .{ .assign_swap_fx = .GATE } });
    try testing.expectEqual(statemachine.Mode.fx_sel, globals.state.current_mode);
    try testing.expect(globals.state.fx_sel.return_to_mapping);

    actions.dispatch(globals, .{ .fx_sel = .{ .plugin = .{ .name = "JS: Transient Controller", .mapping_name = null } } });
    try testing.expectEqual(statemachine.Mode.mapping_panel, globals.state.current_mode);
    try testing.expect(globals.state.mapping_panel.mode == .assign);
    try testing.expectEqual(ModulesList.GATE, globals.state.mapping_panel.mode.assign.focus);
}

test "swapping to a plugin that has a mapping from the mapping panel also comes back to the mapping panel" {
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
    const actions = @import("../actions.zig");

    _ = setupFullChain(globals);
    actions.dispatch(globals, .{ .mapping_panel = .create_mapping });
    actions.dispatch(globals, .{ .mapping_panel = .{ .assign_swap_fx = .COMP } });
    actions.dispatch(globals, .{ .fx_sel = .{ .plugin = .{ .name = "VST: ReaComp (Cockos)", .mapping_name = null } } });
    try testing.expectEqual(statemachine.Mode.mapping_panel, globals.state.current_mode);
    try testing.expect(globals.state.mapping_panel.mode == .assign);
}

test "the plugins that were chosen are remembered, the latest first and without repeats" {
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

    _ = setupFullChain(globals);
    globals.state.fx_sel.current_category = .GATE;
    globals.state.current_mode = .fx_sel;
    fx_sel_actions.fxSelActions(globals, .{ .plugin = .{ .name = "JS: Transient Controller", .mapping_name = null } });
    globals.state.fx_sel.current_category = .COMP;
    globals.state.current_mode = .fx_sel;
    fx_sel_actions.fxSelActions(globals, .{ .plugin = .{ .name = "VST: ReaComp (Cockos)", .mapping_name = null } });
    globals.state.fx_sel.current_category = .GATE;
    globals.state.current_mode = .fx_sel;
    fx_sel_actions.fxSelActions(globals, .{ .plugin = .{ .name = "JS: Transient Controller", .mapping_name = null } });

    const recent = globals.recent_plugins.keys();
    try testing.expectEqual(@as(usize, 2), recent.len);
    try testing.expectEqualStrings("JS: Transient Controller", recent[0]);
    try testing.expectEqualStrings("VST: ReaComp (Cockos)", recent[1]);
}

test "the single plugin mode is chosen from the mapping panel, which comes back on the channel strip" {
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
    const actions = @import("../actions.zig");

    _ = setupFullChain(globals);
    actions.dispatch(globals, .{ .mapping_panel = .create_mapping });
    try testing.expect(globals.state.mapping_panel.mode.assign.getConst(.STRIP) == null);

    actions.dispatch(globals, .{ .mapping_panel = .{ .assign_swap_fx = .STRIP } });
    try testing.expectEqual(ModulesList.STRIP, globals.state.fx_sel.current_category);
    actions.dispatch(globals, .{ .fx_sel = .{ .plugin = .{ .name = "VST: ReaComp (Cockos)", .mapping_name = null } } });
    try testing.expectEqual(statemachine.Mode.mapping_panel, globals.state.current_mode);
    try testing.expect(globals.state.mapping_panel.mode.assign.getConst(.STRIP) != null);
    try testing.expectEqual(ModulesList.STRIP, globals.state.mapping_panel.mode.assign.focus);
}

test "the key of the single plugin mode leaves the channel strip, and the track has a plugin for each module again" {
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
    const actions = @import("../actions.zig");

    _ = setupFullChain(globals);
    actions.dispatch(globals, .{ .mapping_panel = .create_mapping });
    actions.dispatch(globals, .{ .mapping_panel = .{ .assign_swap_fx = .STRIP } });
    actions.dispatch(globals, .{ .fx_sel = .{ .plugin = .{ .name = "VST: ReaComp (Cockos)", .mapping_name = null } } });
    try testing.expect(globals.state.fx_ctrl.track_state.mode == .channel_strip);
    try testing.expect(globals.state.mapping_panel.mode.assign.getConst(.STRIP) != null);

    actions.dispatch(globals, .{ .mapping_panel = .assign_toggle_single_fx });
    try testing.expectEqual(statemachine.Mode.mapping_panel, globals.state.current_mode);
    try testing.expect(globals.state.fx_ctrl.track_state.mode == .multi_fx);
    try testing.expect(globals.state.mapping_panel.mode.assign.getConst(.STRIP) == null);
}

test "closing the browser of the strip without a strip validates the track again, and the assignment shows the modules" {
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
    const actions = @import("../actions.zig");

    const track = setupFullChain(globals);
    actions.dispatch(globals, .{ .mapping_panel = .create_mapping });

    // The key opens the browser of the strip, and pressed again it closes it, with the modules as they were.
    actions.dispatch(globals, .{ .mapping_panel = .assign_toggle_single_fx });
    try testing.expectEqual(statemachine.Mode.fx_sel, globals.state.current_mode);
    actions.dispatch(globals, .{ .mapping_panel = .assign_toggle_single_fx });
    try testing.expectEqual(statemachine.Mode.mapping_panel, globals.state.current_mode);
    try testing.expect(globals.state.fx_ctrl.track_state.mode == .multi_fx);
    try testing.expect(globals.state.mapping_panel.mode.assign.getConst(.STRIP) == null);
    try testing.expectEqual(@as(c_int, 5), reaper.TrackFX_GetCount(track));
}

test "the compressor of a channel strip has a meter that rests at zero when the plugin reports no reduction" {
    var model_arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer model_arena.deinit();
    var reaper_teardown = models.reaper.setupTestModel(model_arena.allocator(), null, null);
    defer reaper_teardown.teardown();
    var midi_teardown = models.midi.setupMidiMocks(reaper);
    defer midi_teardown.teardown();
    Globals.instance = try .defaults(testing.allocator);
    defer Globals.instance.deinit();
    const globals = &Globals.instance;

    // Because no track is selected, the plugin cannot report anything, which is what a plugin that has no reduction does.
    globals.state.current_tr_id = null;
    globals.state.fx_ctrl.track_state.mode = .{ .channel_strip = .{
        .fx_index = 0,
        .mapping = .{},
        .guid = std.mem.zeroes(@import("utils").Guid),
    } };
    globals.state.fx_ctrl.comp_reduction_db = null;

    @import("../csurf/midi_events_fxctrl.zig").readMeters(globals);

    try testing.expectEqual(@as(?f64, 0), globals.state.fx_ctrl.comp_reduction_db);
    try testing.expectEqual(@as(?f64, null), globals.state.fx_ctrl.gate_reduction_db);
}

test "the volume and the pan knobs drive the track unless a parameter is assigned to them, and then only while shift is held" {
    var model_arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer model_arena.deinit();
    var reaper_teardown = models.reaper.setupTestModel(model_arena.allocator(), null, null);
    defer reaper_teardown.teardown();
    var midi_teardown = models.midi.setupMidiMocks(reaper);
    defer midi_teardown.teardown();
    Globals.instance = try .defaults(testing.allocator);
    defer Globals.instance.deinit();
    const fx_ctrl = &Globals.instance.state.fx_ctrl;

    try testing.expect(!fx_ctrl.isKnobMapped(.Out_Vol));
    try testing.expect(fx_ctrl.knobDrivesTrack(.Out_Vol, false));
    try testing.expect(fx_ctrl.knobDrivesTrack(.Out_Pan, true));

    try fx_ctrl.track_state.forward_map.put(testing.allocator, .Out_Vol, .{ .fx_index = 0, .param_index = 3 });
    defer fx_ctrl.track_state.forward_map.clearAndFree(testing.allocator);
    try testing.expect(fx_ctrl.isKnobMapped(.Out_Vol));
    try testing.expect(!fx_ctrl.knobDrivesTrack(.Out_Vol, false));
    try testing.expect(fx_ctrl.knobDrivesTrack(.Out_Vol, true));
    // The knob that has no parameter assigned stays the track's, whatever shift does.
    try testing.expect(!fx_ctrl.isKnobMapped(.Out_Pan));
    try testing.expect(fx_ctrl.knobDrivesTrack(.Out_Pan, false));

    // Because shift makes the volume the track's when a parameter is assigned to it, it does not also step the track list.
    const handled = @import("../csurf/midi_events_fxctrl.zig").shiftFunction(&Globals.instance, .{ .tick = .{ .cc = .Out_Vol, .delta = 1, .fine = true } });
    try testing.expect(!handled);
}

test "the surface keeps the knob of the volume at the volume that REAPER has, even for a move smaller than a step of the unit" {
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
    const csurf = @import("../csurf/control_surface.zig");
    const utils = @import("utils");
    const fx_ctrl = &globals.state.fx_ctrl;

    // Because the knob is at noon for 0 dB, a track at unity gain has the knob at 0.5.
    csurf.zSetSurfaceVolume(track, 1.0);
    try testing.expectApproxEqAbs(@as(f64, 0.5), fx_ctrl.track_volume, 1e-9);
    try testing.expectApproxEqAbs(@as(f64, 0), utils.normalizedToDb(fx_ctrl.track_volume), 1e-9);

    // Because the volume of a track is a gain, half of the gain is 6 dB under.
    csurf.zSetSurfaceVolume(track, 0.5);
    try testing.expectApproxEqAbs(@as(f64, -6.0206), utils.normalizedToDb(fx_ctrl.track_volume), 0.001);

    // A move that is smaller than a step of the unit still moves the knob, and so the dB that the panel says.
    const before = fx_ctrl.track_volume;
    csurf.zSetSurfaceVolume(track, 0.5003);
    try testing.expect(fx_ctrl.track_volume > before);
}

test "a plugin that has several maps opens the selector of maps when it is chosen without one, and goes back to the list" {
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
    const actions = @import("../actions.zig");

    const track = setupFullChain(globals);
    const fx_name = "VST: ReaComp (Cockos)";
    try globals.mappings_list.registerPath(.COMP, fx_name, "default", "/maps/COMP/reacomp/default.ini");
    try globals.mappings_list.registerPath(.COMP, fx_name, "punchy", "/maps/COMP/reacomp/punchy.ini");

    globals.state.fx_sel.current_category = .COMP;
    actions.dispatch(globals, .{ .change_mode = .fx_sel });
    const count_before = reaper.TrackFX_GetCount(track);

    // Because the plugin comes with no map, and has two, the selector opens and nothing is inserted.
    actions.dispatch(globals, .{ .fx_sel = .{ .plugin = .{ .name = fx_name, .mapping_name = null } } });
    try testing.expectEqual(statemachine.Mode.fx_sel, globals.state.current_mode);
    try testing.expect(globals.state.fx_sel.sub_mode == .select_mapping);
    try testing.expectEqualStrings(fx_name, globals.state.fx_sel.sub_mode.select_mapping.fx_name);
    try testing.expectEqual(count_before, reaper.TrackFX_GetCount(track));

    // Because a step back leaves the maps of the plugin, the list is shown again.
    actions.dispatch(globals, .{ .fx_sel = .back });
    try testing.expect(globals.state.fx_sel.sub_mode == .browse_fx);
}

test "the default button makes a map the default of the plugin and writes it to the disk, and shift with confirm does the same, with the selector open" {
    const default_maps = @import("../default_maps.zig");
    const MappingsList = @import("../mappings_list.zig");
    const io = Globals.hostIo();
    var model_arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer model_arena.deinit();
    const arena = model_arena.allocator();
    var reaper_teardown = models.reaper.setupTestModel(arena, null, null);
    defer reaper_teardown.teardown();
    var midi_teardown = models.midi.setupMidiMocks(reaper);
    defer midi_teardown.teardown();
    Globals.instance = try .defaults(testing.allocator);
    defer Globals.instance.deinit();
    const globals = &Globals.instance;
    globals.m_midi_out = reaper.CreateMIDIOutput(0, false, null);
    globals.state.current_mode = .fx_ctrl;
    const actions = @import("../actions.zig");

    // Because the choice is written to the folder of the store, and the maps are read from files, both are in a folder of the test.
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    try tmp_dir.dir.createDirPath(io, "maps/COMP/reacomp");
    inline for (.{ .{ "default", "1" }, .{ "punchy", "2" } }) |map| {
        const file = try tmp_dir.dir.createFile(io, "maps/COMP/reacomp/" ++ map[0] ++ ".ini", .{});
        defer file.close(io);
        try file.writeStreamingAll(io, "version=1\nmodule=COMP\nfx_name=VST: ReaComp (Cockos)\nComp_Attack=" ++ map[1] ++ "\n");
    }
    var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir = dir_buf[0..try tmp_dir.dir.realPathFile(io, ".", &dir_buf)];
    globals.map_store.controller_dir = try arena.dupeSentinel(u8, dir, 0);

    const fx_name = "VST: ReaComp (Cockos)";
    inline for (.{ "default", "punchy" }) |map_name| {
        var path_buf: [std.fs.max_path_bytes:0]u8 = undefined;
        const path = try std.mem.printSentinel(&path_buf, "{s}/maps/COMP/reacomp/{s}.ini", .{ dir, map_name }, 0);
        try globals.mappings_list.registerPath(.COMP, fx_name, map_name, path);
    }

    const track = setupFullChain(globals);
    globals.state.fx_sel.current_category = .COMP;
    actions.dispatch(globals, .{ .change_mode = .fx_sel });
    actions.dispatch(globals, .{ .fx_sel = .{ .plugin = .{ .name = fx_name, .mapping_name = null } } });
    try testing.expect(globals.state.fx_sel.sub_mode == .select_mapping);
    try testing.expectEqual(@as(?[:0]const u8, null), globals.mappings_list.defaultMapName(.COMP, fx_name));
    const count_before = reaper.TrackFX_GetCount(track);

    // The button of a row makes its map the default: the selector stays open, the check moves, and the choice is on the disk.
    actions.dispatch(globals, .{ .fx_sel = .{ .set_default_map = .{ .name = fx_name, .mapping_name = "punchy" } } });
    try testing.expectEqual(statemachine.Mode.fx_sel, globals.state.current_mode);
    try testing.expect(globals.state.fx_sel.sub_mode == .select_mapping);
    try testing.expectEqualStrings("punchy", globals.mappings_list.defaultMapName(.COMP, fx_name).?);
    try testing.expect(std.mem.endsWith(u8, globals.map_store.getPreferredMapping(fx_name, .COMP).?, "punchy.ini"));
    // Because the file is read into the flags of a list that has the maps, a list that was just indexed has the choice back.
    var reloaded = MappingsList.empty(arena);
    try reloaded.registerPath(.COMP, fx_name, "default", "/maps/default.ini");
    try reloaded.registerPath(.COMP, fx_name, "punchy", "/maps/punchy.ini");
    default_maps.load(&reloaded, io, dir);
    try testing.expectEqualStrings("punchy", reloaded.defaultMapName(.COMP, fx_name).?);

    // Because the controller reaches the button with shift, confirming the first row with shift held makes it the default, and
    // nothing is inserted.
    globals.state.fx_ctrl.shift_held = true;
    globals.state.fx_sel.sub_mode.select_mapping.scroll_position_rel = 0;
    actions.dispatch(globals, .{ .fx_sel = .confirm });
    try testing.expectEqual(statemachine.Mode.fx_sel, globals.state.current_mode);
    try testing.expect(globals.state.fx_sel.sub_mode == .select_mapping);
    try testing.expectEqualStrings("default", globals.mappings_list.defaultMapName(.COMP, fx_name).?);
    try testing.expectEqual(count_before, reaper.TrackFX_GetCount(track));
    var reloaded_again = MappingsList.empty(arena);
    try reloaded_again.registerPath(.COMP, fx_name, "default", "/maps/default.ini");
    try reloaded_again.registerPath(.COMP, fx_name, "punchy", "/maps/punchy.ini");
    default_maps.load(&reloaded_again, io, dir);
    try testing.expectEqualStrings("default", reloaded_again.defaultMapName(.COMP, fx_name).?);
}

test "set_default_plugin makes the plugin the default of the module that the browser is on" {
    Globals.instance = try .defaults(testing.allocator);
    defer Globals.instance.deinit();
    const globals = &Globals.instance;
    const actions = @import("../actions.zig");

    globals.state.current_mode = .fx_sel;
    globals.state.fx_sel.current_category = .STRIP;
    try testing.expect(globals.preferences.default_fx.get(.STRIP) == null);
    const comp_before = globals.preferences.default_fx.get(.COMP);
    actions.dispatch(globals, .{ .fx_sel = .{ .set_default_plugin = "JS: Lumina Channel Strip (port) by chmaha" } });
    try testing.expectEqualStrings("JS: Lumina Channel Strip (port) by chmaha", globals.preferences.default_fx.get(.STRIP).?);
    try testing.expectEqualStrings(comp_before.?, globals.preferences.default_fx.get(.COMP).?);
}
