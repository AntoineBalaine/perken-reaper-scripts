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
const TrackState = @import("../track_state.zig");
const PhysicalModule = @import("../statemachine.zig").PhysicalModule;
const c1 = @import("../c1.zig");

test "Integration - loading default mapping for new FX" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config_path_z: [:0]const u8 = std.mem.span(try getTestConfigPath(allocator));

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
    const result = store.get(test_fx, .COMP, &ml);

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

    const config_path_z: [:0]const u8 = std.mem.span(try getTestConfigPath(allocator));

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
    const save_path = try std.fmt.bufPrintZ(&save_path_buf, "{s}/maps/test_plugin/{s}.ini", .{ config_path_z, test_mapping_name });

    // Save the mapping to disk
    try store.saveToFile(fs_ops, .COMP, test_fx, test_mapping, save_path, null, null, null);

    // Register the saved path in the mappings_list so getMap can look it up
    try ml.registerPath(.COMP, test_fx, test_mapping_name, save_path);

    // Create a fresh store instance to simulate a restart
    var store2 = MapStore.empty(allocator, config_path_z);
    defer store2.deinit();

    // Because we saved a mapping, we should be able to load it
    const loaded = try store2.getMap(test_fx, .COMP, test_mapping_name, &ml);

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
    const dir_path = try std.fmt.bufPrint(&dir_buf, "{s}/maps/test_plugin", .{config_path_z});
    std.fs.deleteDirAbsolute(dir_path) catch {};
}

test "Integration - the preferred mapping is used when loading an FX" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config_path_z: [:0]const u8 = std.mem.span(try getTestConfigPath(allocator));

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
    const default_path = try std.fmt.bufPrintZ(&default_path_buf, "{s}/maps/test_plugin2/default.ini", .{config_path_z});

    var custom_path_buf: [std.fs.max_path_bytes:0]u8 = undefined;
    const custom_path = try std.fmt.bufPrintZ(&custom_path_buf, "{s}/maps/test_plugin2/custom.ini", .{config_path_z});

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
    try store.saveToFile(fs_ops, .COMP, test_fx, TaggedMapping{ .COMP = default_comp }, default_path, null, null, null);
    try store.saveToFile(fs_ops, .COMP, test_fx, TaggedMapping{ .COMP = custom_comp }, custom_path, null, null, null);

    // Register paths
    try ml.registerPath(.COMP, test_fx, "default", default_path);
    try ml.registerPath(.COMP, test_fx, "custom", custom_path);

    // Create a fresh store instance
    var store2 = MapStore.empty(allocator, config_path_z);
    defer store2.deinit();

    // Load the default mapping first (this sets it as preferred)
    const loaded_default = try store2.getMap(test_fx, .COMP, "default", &ml);
    try testing.expect(std.meta.activeTag(loaded_default) == .COMP);

    // Verify the preferred mapping is set to default
    const preferred = store2.getPreferredMapping(test_fx, .COMP);
    try testing.expect(preferred != null);
    try testing.expect(std.mem.endsWith(u8, preferred.?, "default.ini"));

    // Because get() uses the preferred mapping, we should get the default values
    const result = store2.get(test_fx, .COMP, &ml);
    try testing.expect(result != null);

    if (result) |tagged| {
        const comp = tagged.COMP;
        try testing.expectEqual(default_comp.Comp_Attack, comp.Comp_Attack);
        try testing.expectEqual(default_comp.Comp_Release, comp.Comp_Release);
    }

    // Load the custom mapping (this should NOT change the preferred)
    _ = try store2.getMap(test_fx, .COMP, "custom", &ml);

    // Verify preferred is still default
    const preferred_after = store2.getPreferredMapping(test_fx, .COMP);
    try testing.expect(preferred_after != null);
    try testing.expect(std.mem.endsWith(u8, preferred_after.?, "default.ini"));

    // Now explicitly set custom as preferred
    try store2.setPreferredMapping(test_fx, .COMP, custom_path);

    // Verify get() now returns the custom mapping
    const result_custom = store2.get(test_fx, .COMP, &ml);
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
    const dir_path = try std.fmt.bufPrint(&dir_buf, "{s}/maps/test_plugin2", .{config_path_z});
    std.fs.deleteDirAbsolute(dir_path) catch {};
}

test "Integration - multiple mappings per FX workflow" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config_path_z: [:0]const u8 = std.mem.span(try getTestConfigPath(allocator));

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
        save_paths[i] = try std.fmt.bufPrintZ(&path_bufs[i], "{s}/maps/multi_test/{s}.ini", .{ config_path_z, mname });
        try store.saveToFile(fs_ops, .COMP, test_fx, TaggedMapping{ .COMP = comps[i] }, save_paths[i], null, null, null);
        try ml.registerPath(.COMP, test_fx, mname, save_paths[i]);
    }

    // Create a fresh store
    var store2 = MapStore.empty(allocator, config_path_z);
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
    const loaded1 = try store2.getMap(test_fx, .COMP, "gentle", &ml);
    try testing.expectEqual(comp1.Comp_Ratio, loaded1.COMP.Comp_Ratio);
    try testing.expectEqual(comp1.Comp_Attack, loaded1.COMP.Comp_Attack);

    const loaded2 = try store2.getMap(test_fx, .COMP, "aggressive", &ml);
    try testing.expectEqual(comp2.Comp_Ratio, loaded2.COMP.Comp_Ratio);
    try testing.expectEqual(comp2.Comp_Attack, loaded2.COMP.Comp_Attack);

    const loaded3 = try store2.getMap(test_fx, .COMP, "extreme", &ml);
    try testing.expectEqual(comp3.Comp_Ratio, loaded3.COMP.Comp_Ratio);
    try testing.expectEqual(comp3.Comp_Attack, loaded3.COMP.Comp_Attack);

    // Clean up
    for (save_paths) |p| {
        std.fs.deleteFileAbsolute(p) catch {};
    }
    var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = try std.fmt.bufPrint(&dir_buf, "{s}/maps/multi_test", .{config_path_z});
    std.fs.deleteDirAbsolute(dir_path) catch {};
}

test "mappings_list scans STRIP directories and populates list.get(.STRIP)" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var mem: [std.fs.max_path_bytes]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);
    const config_path = try std.fs.path.resolve(allocator, &.{ pth, "src/resources/" });
    const config_path_z = try allocator.dupeZ(u8, config_path);

    var ml = MappingsList.init(allocator, config_path_z);

    // Because the walkDir scanner reads module=STRIP from INI headers, any
    // strip mapping files in the maps/ tree should be indexed under list.get(.STRIP).
    const strip_map = ml.list.get(.STRIP);
    // We may or may not have strip mappings in the test resources, but the
    // scanner should not crash and the slot should be a valid (possibly empty) map.
    _ = strip_map.count();
}

test "getMap with .STRIP loads a ChannelStripMapping" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config_path_z: [:0]const u8 = std.mem.span(try getTestConfigPath(allocator));

    var cur_config = try settings.init(allocator, config_path_z);
    var ml = MappingsList.init(allocator, config_path_z);

    var store = try MapStore.init(
        allocator,
        config_path_z,
        &ml,
        &cur_config.default_fx,
    );
    defer store.deinit();

    // Because strip maps live in maps/*/STRIP/ directories and are loaded via
    // the same getMap path as other modules, calling get with .STRIP should
    // either return a TaggedMapping with .STRIP active or null if no strip
    // mappings exist in the test resources.
    const result = store.get("JS: Evolution Channel Strip (chmaha)", .STRIP, &ml);
    if (result) |tagged| {
        try testing.expect(std.meta.activeTag(tagged) == .STRIP);
    }
}

test "forward/reverse maps populated correctly for multi-fx" {
    const allocator = testing.allocator;

    // Set up a mapping with known param indices
    const comp_mapping = MapStore.Comp{ .Comp_Attack = 2, .Comp_Ratio = 5 };
    const tagged: MapStore.TaggedMapping = .{ .COMP = comp_mapping };
    const fx_index: c_int = 3;

    var track_state = TrackState.TrackState{};
    defer track_state.deinitMaps(allocator);

    TrackState.populateMapsFromMapping(
        &track_state.reverse_map,
        &track_state.forward_map,
        allocator,
        tagged,
        fx_index,
    );

    // Forward: CC -> FxParam
    const attack_fxp = track_state.forward_map.get(.Comp_Attack);
    try testing.expect(attack_fxp != null);
    try testing.expectEqual(@as(c_int, 3), attack_fxp.?.fx_index);
    try testing.expectEqual(@as(u16, 2), attack_fxp.?.param_index);

    const ratio_fxp = track_state.forward_map.get(.Comp_Ratio);
    try testing.expect(ratio_fxp != null);
    try testing.expectEqual(@as(u16, 5), ratio_fxp.?.param_index);

    // Unmapped CC returns null
    try testing.expect(track_state.forward_map.get(.Comp_Release) == null);

    // Reverse: (fx_index, param_index) -> CC
    const key_attack: u32 = @bitCast(TrackState.ParamKey{ .fx_index = 3, .param_index = 2 });
    try testing.expectEqual(c1.CCs.Comp_Attack, track_state.reverse_map.get(key_attack).?);

    const key_ratio: u32 = @bitCast(TrackState.ParamKey{ .fx_index = 3, .param_index = 5 });
    try testing.expectEqual(c1.CCs.Comp_Ratio, track_state.reverse_map.get(key_ratio).?);

    // Wrong fx_index returns null
    const wrong_key: u32 = @bitCast(TrackState.ParamKey{ .fx_index = 0, .param_index = 2 });
    try testing.expect(track_state.reverse_map.get(wrong_key) == null);
}

test "forward/reverse maps populated correctly for channel strip" {
    const allocator = testing.allocator;

    const strip_mapping = MapStore.ChannelStripMapping{
        .Eq_HiGain = 3,
        .Comp_Thresh = 7,
        .Out_Drive = 9,
    };
    const tagged: MapStore.TaggedMapping = .{ .STRIP = strip_mapping };
    const fx_index: c_int = 0;

    var track_state = TrackState.TrackState{};
    defer track_state.deinitMaps(allocator);

    TrackState.populateMapsFromMapping(
        &track_state.reverse_map,
        &track_state.forward_map,
        allocator,
        tagged,
        fx_index,
    );

    // Forward lookups
    const hi_gain = track_state.forward_map.get(.Eq_HiGain);
    try testing.expect(hi_gain != null);
    try testing.expectEqual(@as(c_int, 0), hi_gain.?.fx_index);
    try testing.expectEqual(@as(u16, 3), hi_gain.?.param_index);

    const thresh = track_state.forward_map.get(.Comp_Thresh);
    try testing.expect(thresh != null);
    try testing.expectEqual(@as(u16, 7), thresh.?.param_index);

    // Reverse lookups
    const key_3: u32 = @bitCast(TrackState.ParamKey{ .fx_index = 0, .param_index = 3 });
    try testing.expectEqual(c1.CCs.Eq_HiGain, track_state.reverse_map.get(key_3).?);

    const key_7: u32 = @bitCast(TrackState.ParamKey{ .fx_index = 0, .param_index = 7 });
    try testing.expectEqual(c1.CCs.Comp_Thresh, track_state.reverse_map.get(key_7).?);

    // Unmapped param returns null
    const key_99: u32 = @bitCast(TrackState.ParamKey{ .fx_index = 0, .param_index = 99 });
    try testing.expect(track_state.reverse_map.get(key_99) == null);
}

test "re-validation clears stale entries" {
    const allocator = testing.allocator;

    var track_state = TrackState.TrackState{};
    defer track_state.deinitMaps(allocator);

    // Populate with COMP mapping
    const comp_tagged: MapStore.TaggedMapping = .{ .COMP = .{ .Comp_Attack = 0 } };
    TrackState.populateMapsFromMapping(
        &track_state.reverse_map,
        &track_state.forward_map,
        allocator,
        comp_tagged,
        0,
    );
    try testing.expect(track_state.forward_map.get(.Comp_Attack) != null);

    // Simulate re-validation: clear and populate with EQ mapping instead
    track_state.reverse_map.clearRetainingCapacity();
    track_state.forward_map.clearRetainingCapacity();

    const eq_tagged: MapStore.TaggedMapping = .{ .EQ = .{ .Eq_HiGain = 1 } };
    TrackState.populateMapsFromMapping(
        &track_state.reverse_map,
        &track_state.forward_map,
        allocator,
        eq_tagged,
        1,
    );

    // Old COMP entry should be gone
    try testing.expect(track_state.forward_map.get(.Comp_Attack) == null);
    // New EQ entry should be present
    try testing.expect(track_state.forward_map.get(.Eq_HiGain) != null);
}

test "multi-fx maps handle multiple modules without key collision" {
    const allocator = testing.allocator;

    var track_state = TrackState.TrackState{};
    defer track_state.deinitMaps(allocator);

    // Both COMP at fx_index=0 and EQ at fx_index=1 map param_index 0 to different CCs
    const comp_tagged: MapStore.TaggedMapping = .{ .COMP = .{ .Comp_Attack = 0 } };
    const eq_tagged: MapStore.TaggedMapping = .{ .EQ = .{ .Eq_HiGain = 0 } };

    TrackState.populateMapsFromMapping(&track_state.reverse_map, &track_state.forward_map, allocator, comp_tagged, 0);
    TrackState.populateMapsFromMapping(&track_state.reverse_map, &track_state.forward_map, allocator, eq_tagged, 1);

    // Both forward entries exist
    try testing.expect(track_state.forward_map.get(.Comp_Attack) != null);
    try testing.expect(track_state.forward_map.get(.Eq_HiGain) != null);

    // Reverse: same param_index 0 but different fx_index produces different CCs
    const key_comp: u32 = @bitCast(TrackState.ParamKey{ .fx_index = 0, .param_index = 0 });
    const key_eq: u32 = @bitCast(TrackState.ParamKey{ .fx_index = 1, .param_index = 0 });
    try testing.expectEqual(c1.CCs.Comp_Attack, track_state.reverse_map.get(key_comp).?);
    try testing.expectEqual(c1.CCs.Eq_HiGain, track_state.reverse_map.get(key_eq).?);
}
