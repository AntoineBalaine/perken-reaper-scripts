const std = @import("std");
const testing = std.testing;
const reaper = @import("reaper").reaper;
const models = @import("../models/models.zig");
const Globals = @import("../globals.zig");
const statemachine = @import("../statemachine.zig");
const ModulesList = statemachine.ModulesList;
const fx_sel_actions = @import("../fx_sel_actions.zig");
const ModulesOrder = @import("../fx_ctrl_state.zig").ModulesOrder;

// Because the module suffix encodes the module type (I=INPUT, S=GATE,
// E=EQ, C=COMP, O=OUTPT), we can read back the module at a given FX
// chain index by inspecting the renamed_name.
fn getModuleAtIndex(track: reaper.MediaTrack, fx_index: c_int) ?ModulesList {
    var buf: [512:0]u8 = undefined;
    if (!reaper.TrackFX_GetNamedConfigParm(track, fx_index, "renamed_name", &buf, buf.len)) return null;
    const name = std.mem.span(@as([*:0]const u8, &buf));
    if (std.mem.indexOf(u8, name, "(C1-I)") != null) return .INPUT;
    if (std.mem.indexOf(u8, name, "(C1-S)") != null) return .GATE;
    if (std.mem.indexOf(u8, name, "(C1-E)") != null) return .EQ;
    if (std.mem.indexOf(u8, name, "(C1-C)") != null) return .COMP;
    if (std.mem.indexOf(u8, name, "(C1-O)") != null) return .OUTPT;
    return null;
}

const FxDef = struct { name: [*:0]const u8, suffix: [*:0]const u8 };

const module_fx = std.EnumArray(ModulesList, FxDef).init(.{
    .INPUT = .{ .name = "JS: Volume/Pan Smoother v5", .suffix = "(C1-I)" },
    .GATE = .{ .name = "VST: ReaGate (Cockos)", .suffix = "(C1-S)" },
    .EQ = .{ .name = "VST: ReaEQ (Cockos)", .suffix = "(C1-E)" },
    .COMP = .{ .name = "VST: ReaComp (Cockos)", .suffix = "(C1-C)" },
    .OUTPT = .{ .name = "JS: Saturation", .suffix = "(C1-O)" },
    .STRIP = .{ .name = "JS: Evolution Channel Strip (chmaha)", .suffix = "(C1-X)" },
});

fn getFullModuleOrder(order: ModulesOrder) [5]ModulesList {
    return switch (order) {
        .@"S-EQ-C" => .{ .INPUT, .GATE, .EQ, .COMP, .OUTPT },
        .@"S-C-EQ" => .{ .INPUT, .GATE, .COMP, .EQ, .OUTPT },
        .@"EQ-S-C" => .{ .INPUT, .EQ, .GATE, .COMP, .OUTPT },
    };
}

// Because we want to test different module orderings, this helper
// inserts FX in the given order and runs validateTrack.
fn setupChainInOrder(globals: *Globals, order: []const ModulesList) reaper.MediaTrack {
    reaper.InsertTrackAtIndex(0, false);
    const track = reaper.CSurf_TrackFromID(1, false).?;
    reaper.SetTrackSelected(track, true);

    for (order, 0..) |module, i| {
        const fx = module_fx.get(module);
        _ = reaper.TrackFX_AddByName(track, fx.name, false, -1);
        var name_buf: [512:0]u8 = undefined;
        const full_name = std.fmt.bufPrintZ(&name_buf, "{s} {s}", .{
            std.mem.span(fx.name),
            std.mem.span(fx.suffix),
        }) catch unreachable;
        _ = reaper.TrackFX_SetNamedConfigParm(track, @intCast(i), "renamed_name", full_name);
    }

    globals.state.current_tr_id = 1;
    _ = globals.state.fx_ctrl.track_state.validateTrack(
        track,
        globals.preferences.default_fx,
        &globals.map_store,
        globals.preferences,
        globals.arena_int.allocator(),
        &globals.mappings_list,
    );

    return track;
}

fn expectChainOrder(track: reaper.MediaTrack, expected: []const ModulesList) !void {
    const count = reaper.TrackFX_GetCount(track);
    try testing.expectEqual(@as(c_int, @intCast(expected.len)), count);
    for (expected, 0..) |expected_module, i| {
        const actual = getModuleAtIndex(track, @intCast(i));
        if (actual) |a| {
            try testing.expectEqual(expected_module, a);
        } else {
            std.debug.print("Expected {s} at index {d}, got non-C1 FX\n", .{ @tagName(expected_module), i });
            return error.TestExpectedEqual;
        }
    }
}

fn swapModule(globals: *Globals, module: ModulesList) void {
    globals.state.fx_sel.current_category = module;
    globals.state.current_mode = .fx_sel;
    fx_sel_actions.fxSelActions(globals, .{ .plugin = .{
        .name = "JS: Replacement Plugin",
        .mapping_name = null,
    } });
}

// Because swapping a module should preserve the preferred module order,
// we test each module swap for each of the three orderings.
fn testSwapPreservesOrder(order: ModulesOrder, swap_module: ModulesList) !void {
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
    globals.preferences.preferred_module_order = order;

    const full_order = getFullModuleOrder(order);
    const track = setupChainInOrder(globals, &full_order);

    try expectChainOrder(track, &full_order);

    swapModule(globals, swap_module);

    try expectChainOrder(track, &full_order);
}

// ============================================================================
// S-EQ-C order: INPUT, GATE, EQ, COMP, OUTPT
// ============================================================================

test "S-EQ-C: swapping GATE preserves order" {
    try testSwapPreservesOrder(.@"S-EQ-C", .GATE);
}

test "S-EQ-C: swapping EQ preserves order" {
    try testSwapPreservesOrder(.@"S-EQ-C", .EQ);
}

test "S-EQ-C: swapping COMP preserves order" {
    try testSwapPreservesOrder(.@"S-EQ-C", .COMP);
}

test "S-EQ-C: swapping INPUT preserves order" {
    try testSwapPreservesOrder(.@"S-EQ-C", .INPUT);
}

test "S-EQ-C: swapping OUTPT preserves order" {
    try testSwapPreservesOrder(.@"S-EQ-C", .OUTPT);
}

// ============================================================================
// S-C-EQ order: INPUT, GATE, COMP, EQ, OUTPT
// ============================================================================

test "S-C-EQ: swapping GATE preserves order" {
    try testSwapPreservesOrder(.@"S-C-EQ", .GATE);
}

test "S-C-EQ: swapping COMP preserves order" {
    try testSwapPreservesOrder(.@"S-C-EQ", .COMP);
}

test "S-C-EQ: swapping EQ preserves order" {
    try testSwapPreservesOrder(.@"S-C-EQ", .EQ);
}

test "S-C-EQ: swapping INPUT preserves order" {
    try testSwapPreservesOrder(.@"S-C-EQ", .INPUT);
}

test "S-C-EQ: swapping OUTPT preserves order" {
    try testSwapPreservesOrder(.@"S-C-EQ", .OUTPT);
}

// ============================================================================
// EQ-S-C order: INPUT, EQ, GATE, COMP, OUTPT
// ============================================================================

test "EQ-S-C: swapping EQ preserves order" {
    try testSwapPreservesOrder(.@"EQ-S-C", .EQ);
}

test "EQ-S-C: swapping GATE preserves order" {
    try testSwapPreservesOrder(.@"EQ-S-C", .GATE);
}

test "EQ-S-C: swapping COMP preserves order" {
    try testSwapPreservesOrder(.@"EQ-S-C", .COMP);
}

test "EQ-S-C: swapping INPUT preserves order" {
    try testSwapPreservesOrder(.@"EQ-S-C", .INPUT);
}

test "EQ-S-C: swapping OUTPT preserves order" {
    try testSwapPreservesOrder(.@"EQ-S-C", .OUTPT);
}

// ============================================================================
// Partial chains
// ============================================================================

test "S-EQ-C: swapping GATE with only GATE and COMP present" {
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
    globals.preferences.preferred_module_order = .@"S-EQ-C";
    globals.preferences.auto_insert_modules = false;
    globals.preferences.auto_reorder_modules = false;

    const partial = [_]ModulesList{ .GATE, .COMP };
    const track = setupChainInOrder(globals, &partial);

    swapModule(globals, .GATE);

    try testing.expectEqual(@as(c_int, 2), reaper.TrackFX_GetCount(track));
    try testing.expectEqual(ModulesList.GATE, getModuleAtIndex(track, 0).?);
    try testing.expectEqual(ModulesList.COMP, getModuleAtIndex(track, 1).?);
}

test "S-EQ-C: swapping COMP with only GATE and COMP present" {
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
    globals.preferences.preferred_module_order = .@"S-EQ-C";
    globals.preferences.auto_insert_modules = false;
    globals.preferences.auto_reorder_modules = false;

    const partial = [_]ModulesList{ .GATE, .COMP };
    const track = setupChainInOrder(globals, &partial);

    swapModule(globals, .COMP);

    try testing.expectEqual(@as(c_int, 2), reaper.TrackFX_GetCount(track));
    try testing.expectEqual(ModulesList.GATE, getModuleAtIndex(track, 0).?);
    try testing.expectEqual(ModulesList.COMP, getModuleAtIndex(track, 1).?);
}

test "EQ-S-C: swapping EQ with only EQ and GATE present" {
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
    globals.preferences.preferred_module_order = .@"EQ-S-C";
    globals.preferences.auto_insert_modules = false;
    globals.preferences.auto_reorder_modules = false;

    const partial = [_]ModulesList{ .EQ, .GATE };
    const track = setupChainInOrder(globals, &partial);

    swapModule(globals, .EQ);

    try testing.expectEqual(@as(c_int, 2), reaper.TrackFX_GetCount(track));
    try testing.expectEqual(ModulesList.EQ, getModuleAtIndex(track, 0).?);
    try testing.expectEqual(ModulesList.GATE, getModuleAtIndex(track, 1).?);
}
