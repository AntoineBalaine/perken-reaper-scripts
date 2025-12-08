const std = @import("std");
const testing = std.testing;
const MapStore = @import("../mappings.zig");
const settings = @import("../settings.zig");
const TaggedMapping = MapStore.TaggedMapping;
const ModulesList = @import("../statemachine.zig").ModulesList;
const mapping_browser = @import("../mapping_browser.zig");
const getTestConfigPath = @import("track_validation_pbt.zig").getTestConfigPath;

test "Integration - loading default mapping for new FX" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config_path_z = try getTestConfigPath(allocator);

    var cur_config = try settings.init(allocator, config_path_z);

    var store = try MapStore.init(
        allocator,
        config_path_z,
        &cur_config.default_fx,
    );
    defer store.deinit();

    const test_fx = "VST: ReaComp (Cockos)";

    // Because this is a new FX (first access), we should load the default mapping from disk
    const result = store.get(test_fx, .COMP);

    // Verify the mapping was loaded
    try testing.expect(result != null);

    // Verify it's the COMP type
    if (result) |tagged| {
        try testing.expect(std.meta.activeTag(tagged) == .COMP);

        // Verify some expected values from the default ReaComp mapping
        const comp = tagged.COMP;
        try testing.expect(comp.version == MapStore.MAPPING_FORMAT_VERSION);

        // Verify the mapping is cached
        const fx_maps = store.COMP.get(test_fx);
        try testing.expect(fx_maps != null);
        try testing.expectEqual(@as(usize, 1), fx_maps.?.mappings.count());
    }
}

test "Integration - loading a saved mapping reads the correct data" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config_path_z = try getTestConfigPath(allocator);

    var cur_config = try settings.init(allocator, config_path_z);

    var store = try MapStore.init(
        allocator,
        config_path_z,
        &cur_config.default_fx,
    );
    defer store.deinit();

    const test_fx = "VST: TestPlugin";
    const test_mapping_name = "test_mapping";

    // Create a test mapping
    const test_comp = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Attack = 10,
        .Comp_Release = 20,
        .Comp_Thresh = 30,
        .Comp_Ratio = 40,
        .Comp_DryWet = 50,
        .Comp_comp = 60,
    };

    const test_mapping = TaggedMapping{ .COMP = test_comp };

    // Save the mapping to disk
    try store.saveToFile(.COMP, test_fx, test_mapping, test_mapping_name);

    // Create a fresh store instance to simulate a restart
    var store2 = MapStore.empty(allocator, config_path_z);
    defer store2.deinit();

    // Because we saved a mapping, we should be able to load it
    const loaded = try store2.getMap(test_fx, .COMP, test_mapping_name);

    try testing.expect(std.meta.activeTag(loaded) == .COMP);

    const loaded_comp = loaded.COMP;
    try testing.expectEqual(test_comp.version, loaded_comp.version);
    try testing.expectEqual(test_comp.Comp_Attack, loaded_comp.Comp_Attack);
    try testing.expectEqual(test_comp.Comp_Release, loaded_comp.Comp_Release);
    try testing.expectEqual(test_comp.Comp_Thresh, loaded_comp.Comp_Thresh);
    try testing.expectEqual(test_comp.Comp_Ratio, loaded_comp.Comp_Ratio);
    try testing.expectEqual(test_comp.Comp_DryWet, loaded_comp.Comp_DryWet);
    try testing.expectEqual(test_comp.Comp_comp, loaded_comp.Comp_comp);

    // Clean up the test file
    var name_buf: [512:0]u8 = undefined;
    const sanitized_name = try std.fmt.bufPrintZ(&name_buf, "{s}", .{test_fx});
    _ = std.mem.replace(u8, sanitized_name, "/", "_", &name_buf);

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const test_file_path = try std.fmt.bufPrint(&path_buffer, "{s}/maps/COMP/{s}/{s}.ini", .{ std.mem.span(config_path_z), sanitized_name, test_mapping_name });
    std.fs.deleteFileAbsolute(test_file_path) catch {};

    // Also delete the directory if it's now empty
    var dir_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = try std.fmt.bufPrint(&dir_path_buf, "{s}/maps/COMP/{s}", .{ std.mem.span(config_path_z), sanitized_name });
    std.fs.deleteDirAbsolute(dir_path) catch {};
}

test "Integration - the preferred mapping is used when loading an FX" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config_path_z = try getTestConfigPath(allocator);

    var cur_config = try settings.init(allocator, config_path_z);

    var store = try MapStore.init(
        allocator,
        config_path_z,
        &cur_config.default_fx,
    );
    defer store.deinit();

    const test_fx = "VST: TestPlugin2";
    const default_mapping_name = "default";
    const custom_mapping_name = "custom";

    // Create two different mappings
    const default_comp = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Attack = 10,
        .Comp_Release = 20,
        .Comp_Thresh = 30,
        .Comp_Ratio = 40,
        .Comp_DryWet = 50,
        .Comp_comp = 60,
    };

    const custom_comp = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Attack = 15,
        .Comp_Release = 25,
        .Comp_Thresh = 35,
        .Comp_Ratio = 45,
        .Comp_DryWet = 55,
        .Comp_comp = 65,
    };

    const default_mapping = TaggedMapping{ .COMP = default_comp };
    const custom_mapping = TaggedMapping{ .COMP = custom_comp };

    // Save both mappings
    try store.saveToFile(.COMP, test_fx, default_mapping, default_mapping_name);
    try store.saveToFile(.COMP, test_fx, custom_mapping, custom_mapping_name);

    // Create a fresh store instance
    var store2 = MapStore.empty(allocator, config_path_z);
    defer store2.deinit();

    // Load the default mapping first (this sets it as preferred)
    const loaded_default = try store2.getMap(test_fx, .COMP, default_mapping_name);
    try testing.expect(std.meta.activeTag(loaded_default) == .COMP);

    // Verify the preferred mapping is set to default
    const preferred = store2.getPreferredMapping(test_fx, .COMP);
    try testing.expect(preferred != null);
    try testing.expect(std.mem.endsWith(u8, preferred.?, "default.ini"));

    // Because get() uses the preferred mapping, we should get the default values
    const result = store2.get(test_fx, .COMP);
    try testing.expect(result != null);

    if (result) |tagged| {
        const comp = tagged.COMP;
        try testing.expectEqual(default_comp.Comp_Attack, comp.Comp_Attack);
        try testing.expectEqual(default_comp.Comp_Release, comp.Comp_Release);
    }

    // Load the custom mapping (this should NOT change the preferred)
    _ = try store2.getMap(test_fx, .COMP, custom_mapping_name);

    // Verify preferred is still default
    const preferred_after = store2.getPreferredMapping(test_fx, .COMP);
    try testing.expect(preferred_after != null);
    try testing.expect(std.mem.endsWith(u8, preferred_after.?, "default.ini"));

    // Now explicitly set custom as preferred
    var custom_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const custom_path = try std.fmt.bufPrintZ(&custom_path_buf, "{s}/maps/COMP/{s}/{s}.ini", .{ std.mem.span(config_path_z), test_fx, custom_mapping_name });
    try store2.setPreferredMapping(test_fx, .COMP, custom_path);

    // Verify get() now returns the custom mapping
    const result_custom = store2.get(test_fx, .COMP);
    try testing.expect(result_custom != null);

    if (result_custom) |tagged| {
        const comp = tagged.COMP;
        try testing.expectEqual(custom_comp.Comp_Attack, comp.Comp_Attack);
        try testing.expectEqual(custom_comp.Comp_Release, comp.Comp_Release);
    }

    // Clean up test files
    var name_buf: [512:0]u8 = undefined;
    const sanitized_name = try std.fmt.bufPrintZ(&name_buf, "{s}", .{test_fx});
    _ = std.mem.replace(u8, sanitized_name, "/", "_", &name_buf);

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const default_file_path = try std.fmt.bufPrint(&path_buffer, "{s}/maps/COMP/{s}/{s}.ini", .{ std.mem.span(config_path_z), sanitized_name, default_mapping_name });
    std.fs.deleteFileAbsolute(default_file_path) catch {};

    var custom_path_buf2: [std.fs.max_path_bytes]u8 = undefined;
    const custom_file_path = try std.fmt.bufPrint(&custom_path_buf2, "{s}/maps/COMP/{s}/{s}.ini", .{ std.mem.span(config_path_z), sanitized_name, custom_mapping_name });
    std.fs.deleteFileAbsolute(custom_file_path) catch {};

    // Delete the directory
    var dir_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = try std.fmt.bufPrint(&dir_path_buf, "{s}/maps/COMP/{s}", .{ std.mem.span(config_path_z), sanitized_name });
    std.fs.deleteDirAbsolute(dir_path) catch {};
}

test "Integration - multiple mappings per FX workflow" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config_path_z = try getTestConfigPath(allocator);

    var cur_config = try settings.init(allocator, config_path_z);

    var store = try MapStore.init(
        allocator,
        config_path_z,
        &cur_config.default_fx,
    );
    defer store.deinit();

    const test_fx = "VST: MultiMappingTest";

    // Create three different mappings
    const mapping1_name = "gentle";
    const mapping2_name = "aggressive";
    const mapping3_name = "extreme";

    const comp1 = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Ratio = 20,
        .Comp_Attack = 30,
        .Comp_Release = null,
        .Comp_Thresh = null,
        .Comp_DryWet = null,
        .Comp_comp = null,
    };

    const comp2 = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Ratio = 60,
        .Comp_Attack = 10,
        .Comp_Release = null,
        .Comp_Thresh = null,
        .Comp_DryWet = null,
        .Comp_comp = null,
    };

    const comp3 = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Ratio = 100,
        .Comp_Attack = 1,
        .Comp_Release = null,
        .Comp_Thresh = null,
        .Comp_DryWet = null,
        .Comp_comp = null,
    };

    // Save all three mappings
    try store.saveToFile(.COMP, test_fx, TaggedMapping{ .COMP = comp1 }, mapping1_name);
    try store.saveToFile(.COMP, test_fx, TaggedMapping{ .COMP = comp2 }, mapping2_name);
    try store.saveToFile(.COMP, test_fx, TaggedMapping{ .COMP = comp3 }, mapping3_name);

    // Create a fresh store
    var store2 = MapStore.empty(allocator, config_path_z);
    defer store2.deinit();

    // Get the list of available mappings
    const mapping_names = try mapping_browser.getMappingNames(allocator, config_path_z, test_fx, .COMP);
    defer {
        for (mapping_names) |name| {
            allocator.free(name);
        }
        allocator.free(mapping_names);
    }

    // Because we saved three mappings, we should have three names
    try testing.expectEqual(@as(usize, 3), mapping_names.len);

    // Verify all names are present
    var found_gentle = false;
    var found_aggressive = false;
    var found_extreme = false;

    for (mapping_names) |name| {
        if (std.mem.eql(u8, name, "gentle")) found_gentle = true;
        if (std.mem.eql(u8, name, "aggressive")) found_aggressive = true;
        if (std.mem.eql(u8, name, "extreme")) found_extreme = true;
    }

    try testing.expect(found_gentle);
    try testing.expect(found_aggressive);
    try testing.expect(found_extreme);

    // Load each mapping and verify correct data
    const loaded1 = try store2.getMap(test_fx, .COMP, mapping1_name);
    try testing.expectEqual(comp1.Comp_Ratio, loaded1.COMP.Comp_Ratio);
    try testing.expectEqual(comp1.Comp_Attack, loaded1.COMP.Comp_Attack);

    const loaded2 = try store2.getMap(test_fx, .COMP, mapping2_name);
    try testing.expectEqual(comp2.Comp_Ratio, loaded2.COMP.Comp_Ratio);
    try testing.expectEqual(comp2.Comp_Attack, loaded2.COMP.Comp_Attack);

    const loaded3 = try store2.getMap(test_fx, .COMP, mapping3_name);
    try testing.expectEqual(comp3.Comp_Ratio, loaded3.COMP.Comp_Ratio);
    try testing.expectEqual(comp3.Comp_Attack, loaded3.COMP.Comp_Attack);

    // Clean up
    var name_buf: [512:0]u8 = undefined;
    const sanitized_name = try std.fmt.bufPrintZ(&name_buf, "{s}", .{test_fx});
    _ = std.mem.replace(u8, sanitized_name, "/", "_", &name_buf);

    inline for ([_][:0]const u8{ mapping1_name, mapping2_name, mapping3_name }) |mapping_name| {
        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
        const file_path = try std.fmt.bufPrint(&path_buffer, "{s}/maps/COMP/{s}/{s}.ini", .{ std.mem.span(config_path_z), sanitized_name, mapping_name });
        std.fs.deleteFileAbsolute(file_path) catch {};
    }

    var dir_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = try std.fmt.bufPrint(&dir_path_buf, "{s}/maps/COMP/{s}", .{ std.mem.span(config_path_z), sanitized_name });
    std.fs.deleteDirAbsolute(dir_path) catch {};
}
