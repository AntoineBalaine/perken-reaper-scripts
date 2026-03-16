const std = @import("std");
const testing = std.testing;
const reaper_mock = @import("../models/reaper_mock.zig");
const ParamStore = @import("../statemachine.zig").ParamStore;
const FX = @import("../models/models.zig").FX;
const Param = @import("../models/models.zig").Param;
const reaper = @import("../reaper.zig").reaper;

fn createTestFX(allocator: std.mem.Allocator, param_names: []const [:0]const u8) !FX {
    var params = try allocator.alloc(Param, param_names.len);
    for (param_names, 0..) |name, i| {
        params[i] = .{
            .name = name,
            .normalized_value = 0.5,
            .formatted_value = "50%",
        };
    }

    return .{
        .guid = .{ .bytes = [_]u8{0} ** 16 },
        .enabled = true,
        .params = params,
        .named_configs = .{
            .original_name = "TestFX",
            .renamed_name = "TestFX",
        },
    };
}

test "ParamStore - load parameters from FX in assignment mode" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Set up model with track and FX
    var test_env = reaper_mock.setupTestModel(allocator, 1, 4);
    defer test_env.teardown();

    const model = test_env.model_ptr;
    const track = &model.tracks.items[1]; // first regular track

    // Add FX with parameters
    const param_names = [_][:0]const u8{
        "Gain",
        "Frequency",
        "Resonance",
        "Mix",
    };
    const test_fx = try createTestFX(allocator, &param_names);
    try track.fx_list.append(allocator, test_fx);

    // Create ParamStore and load parameters
    var param_store = ParamStore.init(allocator);
    defer param_store.deinit();

    // Simulate what mapping_actions.zig does
    const fx_idx = 0;
    const params_length = reaper.TrackFX_GetNumParams(@ptrCast(track), fx_idx);

    var prm_name_buf: [256:0]u8 = undefined;
    for (0..@intCast(params_length)) |i| {
        const prm_idx: i32 = @intCast(i);
        if (reaper.TrackFX_GetParamName(@ptrCast(track), fx_idx, prm_idx, &prm_name_buf, prm_name_buf.len)) {
            const param_name = std.mem.span(@as([*:0]const u8, &prm_name_buf));
            try param_store.addParam(prm_idx, param_name);
        }
    }

    // Verify parameters loaded correctly
    try testing.expectEqual(@as(usize, 4), param_store.len());
    try testing.expectEqualStrings("Gain", param_store.getName(0));
    try testing.expectEqualStrings("Frequency", param_store.getName(1));
    try testing.expectEqualStrings("Resonance", param_store.getName(2));
    try testing.expectEqualStrings("Mix", param_store.getName(3));

    try testing.expectEqual(@as(i32, 0), param_store.getIndex(0));
    try testing.expectEqual(@as(i32, 1), param_store.getIndex(1));
    try testing.expectEqual(@as(i32, 2), param_store.getIndex(2));
    try testing.expectEqual(@as(i32, 3), param_store.getIndex(3));
}

test "ParamStore - clear and reload when switching modules" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Set up model with track and two FX
    var test_env = reaper_mock.setupTestModel(allocator, 1, 4);
    defer test_env.teardown();

    const model = test_env.model_ptr;
    const track = &model.tracks.items[1];

    // Add first FX with EQ parameters
    const eq_param_names = [_][:0]const u8{
        "Low Gain",
        "Mid Gain",
        "High Gain",
    };
    const eq_fx = try createTestFX(allocator, &eq_param_names);
    try track.fx_list.append(allocator, eq_fx);

    // Add second FX with compressor parameters
    const comp_param_names = [_][:0]const u8{
        "Threshold",
        "Ratio",
        "Attack",
        "Release",
    };
    const comp_fx = try createTestFX(allocator, &comp_param_names);
    try track.fx_list.append(allocator, comp_fx);

    var param_store = ParamStore.init(allocator);
    defer param_store.deinit();

    // Load parameters from first FX
    {
        const fx_idx = 0;
        const params_length = reaper.TrackFX_GetNumParams(@ptrCast(track), fx_idx);

        var prm_name_buf: [256:0]u8 = undefined;
        for (0..@intCast(params_length)) |i| {
            const prm_idx: i32 = @intCast(i);
            if (reaper.TrackFX_GetParamName(@ptrCast(track), fx_idx, prm_idx, &prm_name_buf, prm_name_buf.len)) {
                const param_name = std.mem.span(@as([*:0]const u8, &prm_name_buf));
                try param_store.addParam(prm_idx, param_name);
            }
        }

        try testing.expectEqual(@as(usize, 3), param_store.len());
        try testing.expectEqualStrings("Low Gain", param_store.getName(0));
    }

    // Clear and load parameters from second FX (simulating module switch)
    {
        param_store.clear();
        const fx_idx = 1;
        const params_length = reaper.TrackFX_GetNumParams(@ptrCast(track), fx_idx);

        var prm_name_buf: [256:0]u8 = undefined;
        for (0..@intCast(params_length)) |i| {
            const prm_idx: i32 = @intCast(i);
            if (reaper.TrackFX_GetParamName(@ptrCast(track), fx_idx, prm_idx, &prm_name_buf, prm_name_buf.len)) {
                const param_name = std.mem.span(@as([*:0]const u8, &prm_name_buf));
                try param_store.addParam(prm_idx, param_name);
            }
        }

        // Verify new parameters loaded correctly and old ones are gone
        try testing.expectEqual(@as(usize, 4), param_store.len());
        try testing.expectEqualStrings("Threshold", param_store.getName(0));
        try testing.expectEqualStrings("Ratio", param_store.getName(1));
        try testing.expectEqualStrings("Attack", param_store.getName(2));
        try testing.expectEqualStrings("Release", param_store.getName(3));
    }
}

test "ParamStore - memory efficiency across multiple loads" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var test_env = reaper_mock.setupTestModel(allocator, 1, 4);
    defer test_env.teardown();

    const model = test_env.model_ptr;
    const track = &model.tracks.items[1];

    // Create an FX with many parameters
    const param_names = [_][:0]const u8{
        "P1",  "P2",  "P3",  "P4",  "P5",
        "P6",  "P7",  "P8",  "P9",  "P10",
        "P11", "P12", "P13", "P14", "P15",
        "P16", "P17", "P18", "P19", "P20",
    };
    const test_fx = try createTestFX(allocator, &param_names);
    try track.fx_list.append(allocator, test_fx);

    var param_store = ParamStore.init(allocator);
    defer param_store.deinit();

    // Load params multiple times with clear() in between
    for (0..10) |_| {
        param_store.clear();

        const fx_idx = 0;
        const params_length = reaper.TrackFX_GetNumParams(@ptrCast(track), fx_idx);

        var prm_name_buf: [256:0]u8 = undefined;
        for (0..@intCast(params_length)) |i| {
            const prm_idx: i32 = @intCast(i);
            if (reaper.TrackFX_GetParamName(@ptrCast(track), fx_idx, prm_idx, &prm_name_buf, prm_name_buf.len)) {
                const param_name = std.mem.span(@as([*:0]const u8, &prm_name_buf));
                try param_store.addParam(prm_idx, param_name);
            }
        }
    }

    // Verify final load is correct
    try testing.expectEqual(@as(usize, 20), param_store.len());
    try testing.expectEqualStrings("P1", param_store.getName(0));
    try testing.expectEqualStrings("P20", param_store.getName(19));

    // Capacity should have stabilized (not growing unbounded)
    // We verify this by checking the buffer isn't excessively large
    try testing.expect(param_store.strings.buffer.capacity < 10000);
}

test "ParamStore - handles FX with no parameters" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var test_env = reaper_mock.setupTestModel(allocator, 1, 4);
    defer test_env.teardown();

    const model = test_env.model_ptr;
    const track = &model.tracks.items[1];

    // Add FX with no parameters
    const param_names = [_][:0]const u8{};
    const test_fx = try createTestFX(allocator, &param_names);
    try track.fx_list.append(allocator, test_fx);

    var param_store = ParamStore.init(allocator);
    defer param_store.deinit();

    const fx_idx = 0;
    const params_length = reaper.TrackFX_GetNumParams(@ptrCast(track), fx_idx);

    try testing.expectEqual(@as(c_int, 0), params_length);
    try testing.expectEqual(@as(usize, 0), param_store.len());
}
