const std = @import("std");
const testing = std.testing;
const c1 = @import("../c1.zig");
const CCs = c1.CCs;
const TrackState = @import("../track_state.zig");
const LabelPool = TrackState.LabelPool;
const FxParam = TrackState.FxParam;
const reaper = @import("../reaper.zig").reaper;
const models = @import("../models/models.zig");
const statemachine = @import("../statemachine.zig");
const PhysicalModule = statemachine.PhysicalModule;
const FxCtrlState = @import("../fx_ctrl_state.zig").FxControlState;
const ControlValue = @import("../fx_ctrl_state.zig").ControlValue;

// --------------------------------------------------------------------------
// is_toggle population tests
// --------------------------------------------------------------------------

test "getLabels populates is_toggle from TrackFX_GetParameterStepSizes" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var reaper_teardown = models.reaper.setupTestModel(alloc, 1, 4);
    defer reaper_teardown.teardown();

    const track_ptr = &reaper_teardown.model_ptr.tracks.items[1];

    // FX 0 (COMP): param 0 is a toggle, param 1 is not
    const comp_params = try alloc.alloc(models.Param, 6);
    for (comp_params) |*p| {
        p.* = .{ .name = "param", .normalized_value = 0.5, .formatted_value = "0.5" };
    }
    comp_params[0].name = "Bypass";
    comp_params[0].is_toggle = true;
    comp_params[0].step_size = 1.0;
    comp_params[1].name = "Attack (ms)";

    try track_ptr.fx_list.append(alloc, .{
        .guid = std.mem.zeroes(@import("../utils.zig").Guid),
        .enabled = true,
        .params = comp_params,
        .named_configs = .{ .original_name = "Test Comp", .renamed_name = "Test Comp" },
    });

    // FX 1 (OUTPT): param 0 is not a toggle
    const out_params = try alloc.alloc(models.Param, 2);
    for (out_params) |*p| {
        p.* = .{ .name = "param", .normalized_value = 0.5, .formatted_value = "0.5" };
    }
    out_params[0].name = "Drive Amount";

    try track_ptr.fx_list.append(alloc, .{
        .guid = std.mem.zeroes(@import("../utils.zig").Guid),
        .enabled = true,
        .params = out_params,
        .named_configs = .{ .original_name = "Test Out", .renamed_name = "Test Out" },
    });

    var track_state = TrackState{};
    // Manually set up forward map: Comp_comp -> FX 0 param 0, Comp_Attack -> FX 0 param 1, Out_Drive -> FX 1 param 0
    track_state.forward_map.put(alloc, .Comp_comp, .{ .fx_index = 0, .param_index = 0 }) catch unreachable;
    track_state.forward_map.put(alloc, .Comp_Attack, .{ .fx_index = 0, .param_index = 1 }) catch unreachable;
    track_state.forward_map.put(alloc, .Out_Drive, .{ .fx_index = 1, .param_index = 0 }) catch unreachable;

    const media_track = reaper.CSurf_TrackFromID(1, false);
    track_state.getLabels(media_track);

    try testing.expect(track_state.forward_map.get(.Comp_comp).?.is_toggle == true);
    try testing.expect(track_state.forward_map.get(.Comp_Attack).?.is_toggle == false);
    try testing.expect(track_state.forward_map.get(.Out_Drive).?.is_toggle == false);
}

// --------------------------------------------------------------------------
// Cycling logic tests
// --------------------------------------------------------------------------

test "cycleDiscreteParam: toggle param flips between 0 and 1" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var reaper_teardown = models.reaper.setupTestModel(alloc, 1, 4);
    defer reaper_teardown.teardown();

    const track_ptr = &reaper_teardown.model_ptr.tracks.items[1];
    const params = try alloc.alloc(models.Param, 1);
    params[0] = .{
        .name = "Bypass",
        .normalized_value = 0.0,
        .formatted_value = "Off",
        .step_size = 1.0,
        .is_toggle = true,
        .min_val = 0.0,
        .max_val = 1.0,
    };
    try track_ptr.fx_list.append(alloc, .{
        .guid = std.mem.zeroes(@import("../utils.zig").Guid),
        .enabled = true,
        .params = params,
        .named_configs = .{ .original_name = "FX", .renamed_name = "FX" },
    });

    const media_track = reaper.CSurf_TrackFromID(1, false);

    // 0 -> 1
    var norm = TrackState.cycleDiscreteParam(media_track, 0, 0, true);
    try testing.expectApproxEqAbs(1.0, norm, 0.001);
    try testing.expectApproxEqAbs(1.0, reaper.TrackFX_GetParamNormalized(media_track, 0, 0), 0.001);

    // 1 -> 0
    norm = TrackState.cycleDiscreteParam(media_track, 0, 0, true);
    try testing.expectApproxEqAbs(0.0, norm, 0.001);
    try testing.expectApproxEqAbs(0.0, reaper.TrackFX_GetParamNormalized(media_track, 0, 0), 0.001);
}

test "cycleDiscreteParam: 6-step param cycles and wraps" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var reaper_teardown = models.reaper.setupTestModel(alloc, 1, 4);
    defer reaper_teardown.teardown();

    const track_ptr = &reaper_teardown.model_ptr.tracks.items[1];
    const params = try alloc.alloc(models.Param, 1);
    params[0] = .{
        .name = "Module Order",
        .normalized_value = 0.0,
        .formatted_value = "Order 1",
        .step_size = 1.0,
        .is_toggle = false,
        .min_val = 0.0,
        .max_val = 5.0,
    };
    try track_ptr.fx_list.append(alloc, .{
        .guid = std.mem.zeroes(@import("../utils.zig").Guid),
        .enabled = true,
        .params = params,
        .named_configs = .{ .original_name = "FX", .renamed_name = "FX" },
    });

    const media_track = reaper.CSurf_TrackFromID(1, false);

    // Cycle through all 6 values
    const expected = [_]f64{ 0.2, 0.4, 0.6, 0.8, 1.0, 0.0 };
    for (expected) |exp| {
        const norm = TrackState.cycleDiscreteParam(media_track, 0, 0, false);
        try testing.expectApproxEqAbs(exp, norm, 0.001);
    }
}

test "cycleDiscreteParam: 3-step param at max wraps to min" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var reaper_teardown = models.reaper.setupTestModel(alloc, 1, 4);
    defer reaper_teardown.teardown();

    const track_ptr = &reaper_teardown.model_ptr.tracks.items[1];
    const params = try alloc.alloc(models.Param, 1);
    params[0] = .{
        .name = "Type",
        .normalized_value = 1.0, // at max (native value 2.0)
        .formatted_value = "Type 3",
        .step_size = 1.0,
        .is_toggle = false,
        .min_val = 0.0,
        .max_val = 2.0,
    };
    try track_ptr.fx_list.append(alloc, .{
        .guid = std.mem.zeroes(@import("../utils.zig").Guid),
        .enabled = true,
        .params = params,
        .named_configs = .{ .original_name = "FX", .renamed_name = "FX" },
    });

    const media_track = reaper.CSurf_TrackFromID(1, false);
    const norm = TrackState.cycleDiscreteParam(media_track, 0, 0, false);
    try testing.expectApproxEqAbs(0.0, norm, 0.001);
}

test "cycleDiscreteParam: continuous param on button toggles around midpoint" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var reaper_teardown = models.reaper.setupTestModel(alloc, 1, 4);
    defer reaper_teardown.teardown();

    const track_ptr = &reaper_teardown.model_ptr.tracks.items[1];
    const params = try alloc.alloc(models.Param, 1);
    params[0] = .{
        .name = "Threshold",
        .normalized_value = 0.3, // below midpoint
        .formatted_value = "-20 dB",
        .step_size = 0.01,
        .is_toggle = false,
        .min_val = 0.0,
        .max_val = 1.0,
    };
    try track_ptr.fx_list.append(alloc, .{
        .guid = std.mem.zeroes(@import("../utils.zig").Guid),
        .enabled = true,
        .params = params,
        .named_configs = .{ .original_name = "FX", .renamed_name = "FX" },
    });

    const media_track = reaper.CSurf_TrackFromID(1, false);

    // Current 0.3 < mid 0.5 -> jumps to max 1.0
    var norm = TrackState.cycleDiscreteParam(media_track, 0, 0, false);
    try testing.expectApproxEqAbs(1.0, norm, 0.001);

    // Current 1.0 > mid 0.5 -> jumps to min 0.0
    norm = TrackState.cycleDiscreteParam(media_track, 0, 0, false);
    try testing.expectApproxEqAbs(0.0, norm, 0.001);
}

// --------------------------------------------------------------------------
// Value storage tests
// --------------------------------------------------------------------------

test "mappable button CCs are stored as .param, hardcoded buttons as .button" {
    var state = FxCtrlState.init(testing.allocator);
    defer state.values.deinit();

    // Mappable buttons should be .param
    try testing.expect(state.values.get(.Comp_comp).? == .param);
    try testing.expect(state.values.get(.Eq_eq).? == .param);
    try testing.expect(state.values.get(.Shp_shape).? == .param);
    try testing.expect(state.values.get(.Shp_hard_gate).? == .param);
    try testing.expect(state.values.get(.Eq_hp_shape).? == .param);
    try testing.expect(state.values.get(.Eq_lp_shape).? == .param);

    // Strip-assignable controls should be .param so they can hold FX param values
    try testing.expect(state.values.get(.Tr_order).? == .param);
    try testing.expect(state.values.get(.Tr_ext_sidechain).? == .param);

    // Hardcoded buttons should still be .button
    try testing.expect(state.values.get(.Out_mute).? == .button);
    try testing.expect(state.values.get(.Out_solo).? == .button);
}

test "Tr_ext_sidechain has a label pool slot" {
    try testing.expectEqual(@as(?u8, 40), LabelPool.indexOf(.Tr_ext_sidechain));

    var pool = LabelPool{};
    pool.setPrmLabel(.Tr_ext_sidechain, "Sidechain");
    try testing.expectEqualStrings("Sidechain", pool.getPrmLabel(.Tr_ext_sidechain));

    pool.setFmtValue(.Tr_ext_sidechain, "Self");
    try testing.expectEqualStrings("Self", pool.getFmtValue(.Tr_ext_sidechain));
}

// --------------------------------------------------------------------------
// Knob discrete stepping tests
// --------------------------------------------------------------------------

test "stepDiscreteParam: accumulates deltas and steps at boundary" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var reaper_teardown = models.reaper.setupTestModel(alloc, 1, 4);
    defer reaper_teardown.teardown();

    const track_ptr = &reaper_teardown.model_ptr.tracks.items[1];
    const params = try alloc.alloc(models.Param, 1);
    params[0] = .{
        .name = "Ratio",
        .normalized_value = 0.0,
        .formatted_value = "1",
        .step_size = 1.0,
        .is_toggle = false,
        .min_val = 0.0,
        .max_val = 5.0,
    };
    try track_ptr.fx_list.append(alloc, .{
        .guid = std.mem.zeroes(@import("../utils.zig").Guid),
        .enabled = true,
        .params = params,
        .named_configs = .{ .original_name = "FX", .renamed_name = "FX" },
    });

    const media_track = reaper.CSurf_TrackFromID(1, false);
    // Norm step = 1/5 = 0.2. We use Comp_Attack (index 0 in pool) as CC.
    var track_state = TrackState{};
    track_state.forward_map.put(alloc, .Comp_Attack, .{ .fx_index = 0, .param_index = 0 }) catch unreachable;

    // Small delta below threshold — should not step
    const result = track_state.stepDiscreteParam(.Comp_Attack, media_track, 0, 0, 0.1);
    try testing.expect(result == null);

    // Another small delta crossing the threshold — should step once
    var norm = track_state.stepDiscreteParam(.Comp_Attack, media_track, 0, 0, 0.15).?;
    try testing.expectApproxEqAbs(0.2, norm, 0.001);

    // Large delta crossing two steps at once
    norm = track_state.stepDiscreteParam(.Comp_Attack, media_track, 0, 0, 0.45).?;
    try testing.expectApproxEqAbs(0.6, norm, 0.001);

    // Step backward
    norm = track_state.stepDiscreteParam(.Comp_Attack, media_track, 0, 0, -0.25).?;
    try testing.expectApproxEqAbs(0.4, norm, 0.001);

    // Clamp at max: current is native 2 (norm 0.4), send large forward delta
    norm = track_state.stepDiscreteParam(.Comp_Attack, media_track, 0, 0, 0.9).?;
    try testing.expectApproxEqAbs(1.0, norm, 0.001);

    // Large backward delta: -0.99 / 0.2 = 4 steps, from 5 to 1 (norm 0.2)
    norm = track_state.stepDiscreteParam(.Comp_Attack, media_track, 0, 0, -0.99).?;
    try testing.expectApproxEqAbs(0.2, norm, 0.001);

    // Another backward delta to reach 0
    norm = track_state.stepDiscreteParam(.Comp_Attack, media_track, 0, 0, -0.25).?;
    try testing.expectApproxEqAbs(0.0, norm, 0.001);
}

test "stepDiscreteParam: returns null for continuous params" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var reaper_teardown = models.reaper.setupTestModel(alloc, 1, 4);
    defer reaper_teardown.teardown();

    const track_ptr = &reaper_teardown.model_ptr.tracks.items[1];
    const params = try alloc.alloc(models.Param, 1);
    params[0] = .{
        .name = "Threshold",
        .normalized_value = 0.5,
        .formatted_value = "-18 dB",
        .step_size = 0.01,
        .is_toggle = false,
        .min_val = 0.0,
        .max_val = 1.0,
    };
    try track_ptr.fx_list.append(alloc, .{
        .guid = std.mem.zeroes(@import("../utils.zig").Guid),
        .enabled = true,
        .params = params,
        .named_configs = .{ .original_name = "FX", .renamed_name = "FX" },
    });

    const media_track = reaper.CSurf_TrackFromID(1, false);
    var track_state = TrackState{};
    const result = track_state.stepDiscreteParam(.Comp_Attack, media_track, 0, 0, 0.5);
    try testing.expect(result == null);
}
