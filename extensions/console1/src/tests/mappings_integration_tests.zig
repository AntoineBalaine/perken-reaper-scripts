const std = @import("std");
const testing = std.testing;
const MapStore = @import("../mappings.zig");
const MappingsList = @import("../mappings_list.zig");
const settings = @import("../settings.zig");
const TaggedMapping = MapStore.TaggedMapping;
const ModulesList = @import("../statemachine.zig").ModulesList;
const mapping_browser = @import("../mapping_browser.zig");
const fs_helpers = @import("../fs_helpers.zig");
const getTestConfigPath = @import("track_validation_pbt.zig").getTestConfigPath;

test "Integration - loading default mapping for new FX" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config_path_z = try getTestConfigPath(allocator);

    var cur_config = try settings.init(allocator, config_path_z);

    var ml = MappingsList.init(allocator, config_path_z);

    var store = try MapStore.init(
        allocator,
        config_path_z,
        &ml,
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

    var ml = MappingsList.init(allocator, config_path_z);

    var store = try MapStore.init(
        allocator,
        config_path_z,
        &ml,
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

    const fs_ops = fs_helpers.RealFileSystem.fileSystemOps();

    // Construct save path
    var save_path_buf: [std.fs.max_path_bytes:0]u8 = undefined;
    const save_path = try std.fmt.bufPrintZ(&save_path_buf, "{s}/maps/test_plugin/{s}.ini", .{ std.mem.span(config_path_z), test_mapping_name });

    // Save the mapping to disk
    try store.saveToFile(fs_ops, .COMP, test_fx, test_mapping, save_path);

    // Register the saved path in the mappings_list so getMap can look it up
    try ml.registerPath(.COMP, test_fx, test_mapping_name, save_path);

    // Create a fresh store instance to simulate a restart
    var store2 = MapStore.empty(allocator, config_path_z, &ml);
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

    // Clean up
    std.fs.deleteFileAbsolute(save_path) catch {};
    var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = try std.fmt.bufPrint(&dir_buf, "{s}/maps/test_plugin", .{std.mem.span(config_path_z)});
    std.fs.deleteDirAbsolute(dir_path) catch {};
}

test "Integration - the preferred mapping is used when loading an FX" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config_path_z = try getTestConfigPath(allocator);

    var cur_config = try settings.init(allocator, config_path_z);

    var ml = MappingsList.init(allocator, config_path_z);

    var store = try MapStore.init(
        allocator,
        config_path_z,
        &ml,
        &cur_config.default_fx,
    );
    defer store.deinit();

    const test_fx = "VST: TestPlugin2";

    const fs_ops = fs_helpers.RealFileSystem.fileSystemOps();

    // Construct save paths
    var default_path_buf: [std.fs.max_path_bytes:0]u8 = undefined;
    const default_path = try std.fmt.bufPrintZ(&default_path_buf, "{s}/maps/test_plugin2/default.ini", .{std.mem.span(config_path_z)});

    var custom_path_buf: [std.fs.max_path_bytes:0]u8 = undefined;
    const custom_path = try std.fmt.bufPrintZ(&custom_path_buf, "{s}/maps/test_plugin2/custom.ini", .{std.mem.span(config_path_z)});

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

    // Save both mappings
    try store.saveToFile(fs_ops, .COMP, test_fx, TaggedMapping{ .COMP = default_comp }, default_path);
    try store.saveToFile(fs_ops, .COMP, test_fx, TaggedMapping{ .COMP = custom_comp }, custom_path);

    // Register paths
    try ml.registerPath(.COMP, test_fx, "default", default_path);
    try ml.registerPath(.COMP, test_fx, "custom", custom_path);

    // Create a fresh store instance
    var store2 = MapStore.empty(allocator, config_path_z, &ml);
    defer store2.deinit();

    // Load the default mapping first (this sets it as preferred)
    const loaded_default = try store2.getMap(test_fx, .COMP, "default");
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
    _ = try store2.getMap(test_fx, .COMP, "custom");

    // Verify preferred is still default
    const preferred_after = store2.getPreferredMapping(test_fx, .COMP);
    try testing.expect(preferred_after != null);
    try testing.expect(std.mem.endsWith(u8, preferred_after.?, "default.ini"));

    // Now explicitly set custom as preferred
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
    std.fs.deleteFileAbsolute(default_path) catch {};
    std.fs.deleteFileAbsolute(custom_path) catch {};
    var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = try std.fmt.bufPrint(&dir_buf, "{s}/maps/test_plugin2", .{std.mem.span(config_path_z)});
    std.fs.deleteDirAbsolute(dir_path) catch {};
}

test "Integration - multiple mappings per FX workflow" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config_path_z = try getTestConfigPath(allocator);

    var cur_config = try settings.init(allocator, config_path_z);

    var ml = MappingsList.init(allocator, config_path_z);

    var store = try MapStore.init(
        allocator,
        config_path_z,
        &ml,
        &cur_config.default_fx,
    );
    defer store.deinit();

    const test_fx = "VST: MultiMappingTest";

    const mapping_names = [_][:0]const u8{ "gentle", "aggressive", "extreme" };

    const comp1 = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Ratio = 20,
        .Comp_Attack = 30,
    };

    const comp2 = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Ratio = 60,
        .Comp_Attack = 10,
    };

    const comp3 = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Ratio = 100,
        .Comp_Attack = 1,
    };

    const comps = [_]MapStore.Comp{ comp1, comp2, comp3 };

    const fs_ops = fs_helpers.RealFileSystem.fileSystemOps();

    // Save all three mappings and register paths
    var path_bufs: [3][std.fs.max_path_bytes:0]u8 = undefined;
    var save_paths: [3][:0]const u8 = undefined;

    for (mapping_names, 0..) |mname, i| {
        save_paths[i] = try std.fmt.bufPrintZ(&path_bufs[i], "{s}/maps/multi_test/{s}.ini", .{ std.mem.span(config_path_z), mname });
        try store.saveToFile(fs_ops, .COMP, test_fx, TaggedMapping{ .COMP = comps[i] }, save_paths[i]);
        try ml.registerPath(.COMP, test_fx, mname, save_paths[i]);
    }

    // Create a fresh store
    var store2 = MapStore.empty(allocator, config_path_z, &ml);
    defer store2.deinit();

    // Get the list of available mappings
    const names = try mapping_browser.getMappingNames(allocator, &ml, test_fx, .COMP);
    defer {
        for (names) |name| {
            allocator.free(name);
        }
        allocator.free(names);
    }

    try testing.expectEqual(@as(usize, 3), names.len);

    // Load each mapping and verify correct data
    const loaded1 = try store2.getMap(test_fx, .COMP, "gentle");
    try testing.expectEqual(comp1.Comp_Ratio, loaded1.COMP.Comp_Ratio);
    try testing.expectEqual(comp1.Comp_Attack, loaded1.COMP.Comp_Attack);

    const loaded2 = try store2.getMap(test_fx, .COMP, "aggressive");
    try testing.expectEqual(comp2.Comp_Ratio, loaded2.COMP.Comp_Ratio);
    try testing.expectEqual(comp2.Comp_Attack, loaded2.COMP.Comp_Attack);

    const loaded3 = try store2.getMap(test_fx, .COMP, "extreme");
    try testing.expectEqual(comp3.Comp_Ratio, loaded3.COMP.Comp_Ratio);
    try testing.expectEqual(comp3.Comp_Attack, loaded3.COMP.Comp_Attack);

    // Clean up
    for (save_paths) |p| {
        std.fs.deleteFileAbsolute(p) catch {};
    }
    var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = try std.fmt.bufPrint(&dir_buf, "{s}/maps/multi_test", .{std.mem.span(config_path_z)});
    std.fs.deleteDirAbsolute(dir_path) catch {};
}
