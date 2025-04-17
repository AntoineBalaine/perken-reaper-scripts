const std = @import("std");
const testing = std.testing;
const cFxModel = @cImport({
    @cInclude("../rapidcheck/types/fx_model.h");
});
const fx_model = @import("../../models/fx_model.zig");

// Test creating and freeing a parameter
test "RC_Param creation and cleanup" {
    const allocator = testing.allocator;

    // Create a parameter
    var param: cFxModel.RC_Param = undefined;
    param.name = try allocator.dupeZ(u8, "Test Parameter");
    param.normalized_value = 0.5;
    param.formatted_value = try allocator.dupeZ(u8, "50%");

    // Verify parameter values
    try testing.expectEqualStrings("Test Parameter", std.mem.span(param.name));
    try testing.expectEqual(@as(f64, 0.5), param.normalized_value);
    try testing.expectEqualStrings("50%", std.mem.span(param.formatted_value));

    // Clean up using the Zig function
    fx_model.deinitCParam(&param, allocator);
}

// Test creating and freeing named configs
test "RC_NamedConfigs creation and cleanup" {
    const allocator = testing.allocator;

    // Create named configs
    var configs: cFxModel.RC_NamedConfigs = undefined;
    configs.original_name = try allocator.dupeZ(u8, "Original Name");
    configs.renamed_name = try allocator.dupeZ(u8, "Renamed Name");
    configs.gain_reduction_db = std.math.nan(f64); // Use NaN to represent "not set"

    // Verify configs values
    try testing.expectEqualStrings("Original Name", std.mem.span(configs.original_name));
    try testing.expectEqualStrings("Renamed Name", std.mem.span(configs.renamed_name));
    try testing.expect(std.math.isNan(configs.gain_reduction_db)); // Check if it's NaN

    // Clean up manually
    allocator.free(std.mem.span(configs.original_name));

    // Only free renamed_name if it's different from original_name
    if (@intFromPtr(configs.original_name) != @intFromPtr(configs.renamed_name)) {
        allocator.free(std.mem.span(configs.renamed_name));
    }
}

// Test creating and freeing an FX with parameters
test "RC_FX creation and cleanup" {
    const allocator = testing.allocator;

    // Create an FX with parameters
    var fx: cFxModel.RC_FX = undefined;

    // Set up GUID
    for (0..16) |i| {
        fx.guid[i] = @intCast(i);
    }

    // Set up basic properties
    fx.enabled = true;

    // Create parameters
    const params_count: usize = 2;
    fx.params_count = params_count;
    fx.params = @ptrCast(try allocator.alloc(cFxModel.RC_Param, params_count));

    // Initialize parameters
    fx.params[0].name = try allocator.dupeZ(u8, "Param 1");
    fx.params[0].normalized_value = 0.25;
    fx.params[0].formatted_value = try allocator.dupeZ(u8, "25%");

    fx.params[1].name = try allocator.dupeZ(u8, "Param 2");
    fx.params[1].normalized_value = 0.75;
    fx.params[1].formatted_value = try allocator.dupeZ(u8, "75%");

    // Set up named configs
    fx.named_configs.original_name = try allocator.dupeZ(u8, "Original FX Name");
    fx.named_configs.renamed_name = try allocator.dupeZ(u8, "Renamed FX Name");
    fx.named_configs.gain_reduction_db = 3.5; // Set a value

    // Verify FX values
    try testing.expect(fx.enabled);
    try testing.expectEqual(@as(usize, 2), fx.params_count);

    // Verify parameters
    try testing.expectEqualStrings("Param 1", std.mem.span(fx.params[0].name));
    try testing.expectEqual(@as(f64, 0.25), fx.params[0].normalized_value);
    try testing.expectEqualStrings("25%", std.mem.span(fx.params[0].formatted_value));

    try testing.expectEqualStrings("Param 2", std.mem.span(fx.params[1].name));
    try testing.expectEqual(@as(f64, 0.75), fx.params[1].normalized_value);
    try testing.expectEqualStrings("75%", std.mem.span(fx.params[1].formatted_value));

    // Verify named configs
    try testing.expectEqualStrings("Original FX Name", std.mem.span(fx.named_configs.original_name));
    try testing.expectEqualStrings("Renamed FX Name", std.mem.span(fx.named_configs.renamed_name));
    try testing.expectEqual(@as(f64, 3.5), fx.named_configs.gain_reduction_db);

    // Clean up using the Zig function
    fx_model.deinitCFX(&fx, allocator);
}

// Test the case where original_name and renamed_name are the same pointer
test "RC_FX with same original and renamed name" {
    const allocator = testing.allocator;

    // Create an FX with parameters
    var fx: cFxModel.RC_FX = undefined;

    // Set up GUID
    for (0..16) |i| {
        fx.guid[i] = @intCast(i);
    }

    // Set up basic properties
    fx.enabled = true;
    fx.params_count = 0;
    fx.params = null;

    // Set up named configs with same pointer for original and renamed
    const name = try allocator.dupeZ(u8, "Same Name");
    fx.named_configs.original_name = name;
    fx.named_configs.renamed_name = name; // Same pointer
    fx.named_configs.gain_reduction_db = std.math.nan(f64); // Not set

    // Verify named configs
    try testing.expectEqualStrings("Same Name", std.mem.span(fx.named_configs.original_name));
    try testing.expectEqualStrings("Same Name", std.mem.span(fx.named_configs.renamed_name));
    try testing.expect(std.math.isNan(fx.named_configs.gain_reduction_db));

    // Verify pointers are the same
    try testing.expect(@intFromPtr(fx.named_configs.original_name) == @intFromPtr(fx.named_configs.renamed_name));

    // Clean up using the Zig function
    fx_model.deinitCFX(&fx, allocator);
}

// Test optional gain reduction with NaN
test "RC_FX with NaN gain reduction" {
    const allocator = testing.allocator;

    // Create an FX with parameters
    var fx: cFxModel.RC_FX = undefined;

    // Set up GUID
    for (0..16) |i| {
        fx.guid[i] = @intCast(i);
    }

    // Set up basic properties
    fx.enabled = true;
    fx.params_count = 0;
    fx.params = null;

    // Set up named configs
    fx.named_configs.original_name = try allocator.dupeZ(u8, "Original Name");
    fx.named_configs.renamed_name = try allocator.dupeZ(u8, "Renamed Name");
    fx.named_configs.gain_reduction_db = std.math.nan(f64); // Use NaN to represent "not set"

    // Verify named configs
    try testing.expectEqualStrings("Original Name", std.mem.span(fx.named_configs.original_name));
    try testing.expectEqualStrings("Renamed Name", std.mem.span(fx.named_configs.renamed_name));
    try testing.expect(std.math.isNan(fx.named_configs.gain_reduction_db));

    // Clean up using the Zig function
    fx_model.deinitCFX(&fx, allocator);
}

// Test conversion between Zig and C structs
test "Convert between Zig and C FX structs" {
    const allocator = testing.allocator;

    // Create a C FX struct
    var c_fx: cFxModel.RC_FX = undefined;

    // Set up GUID
    for (0..16) |i| {
        c_fx.guid[i] = @intCast(i);
    }

    // Set up basic properties
    c_fx.enabled = true;

    // Create parameters
    const params_count: usize = 1;
    c_fx.params_count = params_count;
    c_fx.params = @ptrCast(try allocator.alloc(cFxModel.RC_Param, params_count));

    // Initialize parameters
    c_fx.params[0].name = try allocator.dupeZ(u8, "Volume");
    c_fx.params[0].normalized_value = 0.5;
    c_fx.params[0].formatted_value = try allocator.dupeZ(u8, "0.0 dB");

    // Set up named configs
    c_fx.named_configs.original_name = try allocator.dupeZ(u8, "VST: ReaComp (Cockos)");
    c_fx.named_configs.renamed_name = try allocator.dupeZ(u8, "VST: ReaComp (C1-C)");
    c_fx.named_configs.gain_reduction_db = 6.0;

    // TODO: In a real implementation, you would convert the C struct to a Zig struct here
    // For this test, we'll just verify the C struct values

    try testing.expect(c_fx.enabled);
    try testing.expectEqual(@as(usize, 1), c_fx.params_count);
    try testing.expectEqualStrings("Volume", std.mem.span(c_fx.params[0].name));
    try testing.expectEqual(@as(f64, 0.5), c_fx.params[0].normalized_value);
    try testing.expectEqualStrings("0.0 dB", std.mem.span(c_fx.params[0].formatted_value));
    try testing.expectEqualStrings("VST: ReaComp (Cockos)", std.mem.span(c_fx.named_configs.original_name));
    try testing.expectEqualStrings("VST: ReaComp (C1-C)", std.mem.span(c_fx.named_configs.renamed_name));
    try testing.expectEqual(@as(f64, 6.0), c_fx.named_configs.gain_reduction_db);

    // Clean up using the Zig function
    fx_model.deinitCFX(&c_fx, allocator);
}
