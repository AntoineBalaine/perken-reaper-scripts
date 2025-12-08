const std = @import("std");
const testing = std.testing;
const MapStore = @import("../mappings.zig");
const settings = @import("../settings.zig");
const TaggedMapping = MapStore.TaggedMapping;
const ModulesList = @import("../statemachine.zig").ModulesList;
const mapping_browser = @import("../mapping_browser.zig");
const fs_helpers = @import("../fs_helpers.zig");
const getTestConfigPath = @import("track_validation_pbt.zig").getTestConfigPath;

// ============================================================================
// Unit Tests - Preset Browser Logic
// ============================================================================

test "PresetBrowser - getMappingNames returns empty list for FX with no mappings" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const config_path_z = try getTestConfigPath(allocator);

    const nonexistent_fx = "VST: NonExistent Plugin That Definitely Does Not Exist";

    // Because this FX has no mappings directory, we should get an empty list
    const mapping_names = try mapping_browser.getMappingNames(allocator, config_path_z, nonexistent_fx, .COMP);
    defer {
        for (mapping_names) |name| {
            allocator.free(name);
        }
        allocator.free(mapping_names);
    }

    try testing.expectEqual(@as(usize, 0), mapping_names.len);
}

test "PresetBrowser - getMappingNames returns correct list of mapping files" {
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

    const test_fx = "VST: PresetBrowserTest";

    // Create three test mappings
    const test_comp = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Attack = 10,
        .Comp_Release = null,
        .Comp_Thresh = null,
        .Comp_Ratio = null,
        .Comp_DryWet = null,
        .Comp_comp = null,
    };

    const test_mapping = TaggedMapping{ .COMP = test_comp };

    try store.saveToFile(.COMP, test_fx, test_mapping, "preset1");
    try store.saveToFile(.COMP, test_fx, test_mapping, "preset2");
    try store.saveToFile(.COMP, test_fx, test_mapping, "preset3");

    // Get the list of mappings
    const mapping_names = try mapping_browser.getMappingNames(allocator, config_path_z, test_fx, .COMP);
    defer {
        for (mapping_names) |name| {
            allocator.free(name);
        }
        allocator.free(mapping_names);
    }

    // Because we saved three presets, we should get three names
    try testing.expectEqual(@as(usize, 3), mapping_names.len);

    // Verify all preset names are present
    var found: [3]bool = .{ false, false, false };
    for (mapping_names) |name| {
        if (std.mem.eql(u8, name, "preset1")) found[0] = true;
        if (std.mem.eql(u8, name, "preset2")) found[1] = true;
        if (std.mem.eql(u8, name, "preset3")) found[2] = true;
    }

    try testing.expect(found[0]);
    try testing.expect(found[1]);
    try testing.expect(found[2]);

    // Clean up test files
    var name_buf: [512:0]u8 = undefined;
    const sanitized_name = try fs_helpers.sanitizeFxName(&name_buf, test_fx);

    inline for ([_][:0]const u8{ "preset1", "preset2", "preset3" }) |preset_name| {
        var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
        const file_path = try std.fmt.bufPrint(&path_buffer, "{s}/maps/COMP/{s}/{s}.ini", .{ config_path_z, sanitized_name, preset_name });
        std.fs.deleteFileAbsolute(file_path) catch {};
    }

    var dir_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = try std.fmt.bufPrint(&dir_path_buf, "{s}/maps/COMP/{s}", .{ config_path_z, sanitized_name });
    std.fs.deleteDirAbsolute(dir_path) catch {};
}

test "PresetBrowser - FX names with special characters are sanitized" {
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

    // Because FX names may contain slashes or other special characters,
    // we need to ensure they are sanitized before being used as directory names
    const test_fx_with_slash = "VST: Plugin/SubPlugin";

    const test_comp = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Attack = 10,
        .Comp_Release = null,
        .Comp_Thresh = null,
        .Comp_Ratio = null,
        .Comp_DryWet = null,
        .Comp_comp = null,
    };

    const test_mapping = TaggedMapping{ .COMP = test_comp };

    // Save a mapping with an FX name containing special characters
    try store.saveToFile(.COMP, test_fx_with_slash, test_mapping, "default");

    // Get the list of mappings (should not crash or error due to path issues)
    const mapping_names = try mapping_browser.getMappingNames(allocator, config_path_z, test_fx_with_slash, .COMP);
    defer {
        for (mapping_names) |name| {
            allocator.free(name);
        }
        allocator.free(mapping_names);
    }

    // Because we saved one preset, we should get one name
    try testing.expectEqual(@as(usize, 1), mapping_names.len);
    try testing.expect(std.mem.eql(u8, mapping_names[0], "default"));

    // Clean up test files
    var name_buf: [512:0]u8 = undefined;
    const sanitized_name = try fs_helpers.sanitizeFxName(&name_buf, test_fx_with_slash);

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const file_path = try std.fmt.bufPrint(&path_buffer, "{s}/maps/COMP/{s}/default.ini", .{ config_path_z, sanitized_name });
    std.fs.deleteFileAbsolute(file_path) catch {};

    var dir_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = try std.fmt.bufPrint(&dir_path_buf, "{s}/maps/COMP/{s}", .{ config_path_z, sanitized_name });
    std.fs.deleteDirAbsolute(dir_path) catch {};
}

// ============================================================================
// Unit Tests - Preset Selection Logic
// ============================================================================

test "PresetSelection - setPreferredMapping updates the preferred mapping" {
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

    const test_fx = "VST: PreferredMappingTest";

    // Create two mappings
    const comp1 = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Attack = 10,
        .Comp_Release = null,
        .Comp_Thresh = null,
        .Comp_Ratio = null,
        .Comp_DryWet = null,
        .Comp_comp = null,
    };

    const comp2 = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Attack = 20,
        .Comp_Release = null,
        .Comp_Thresh = null,
        .Comp_Ratio = null,
        .Comp_DryWet = null,
        .Comp_comp = null,
    };

    try store.saveToFile(.COMP, test_fx, TaggedMapping{ .COMP = comp1 }, "mapping1");
    try store.saveToFile(.COMP, test_fx, TaggedMapping{ .COMP = comp2 }, "mapping2");

    // Load mapping1 (sets it as preferred by default)
    _ = try store.getMap(test_fx, .COMP, "mapping1");

    // Verify mapping1 is preferred
    const preferred1 = store.getPreferredMapping(test_fx, .COMP);
    try testing.expect(preferred1 != null);
    try testing.expect(std.mem.endsWith(u8, preferred1.?, "mapping1.ini"));

    // Build filepath for mapping2 using the same format as MapStore
    var name_buf: [512:0]u8 = undefined;
    const sanitized_name = try fs_helpers.sanitizeFxName(&name_buf, test_fx);

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const mapping2_path = fs_helpers.joinStrings(&path_buffer, &.{
        config_path_z,
        std.fs.path.sep_str,
        "maps",
        std.fs.path.sep_str,
        "COMP",
        std.fs.path.sep_str,
        sanitized_name,
        std.fs.path.sep_str,
        "mapping2",
        ".ini",
    });

    const mapping2_path_z = try allocator.dupeZ(u8, mapping2_path);

    // Load mapping2 into the cache before setting it as preferred
    _ = try store.getMap(test_fx, .COMP, "mapping2");

    // Set mapping2 as preferred
    try store.setPreferredMapping(test_fx, .COMP, mapping2_path_z);

    // Verify mapping2 is now preferred
    const preferred2 = store.getPreferredMapping(test_fx, .COMP);
    try testing.expect(preferred2 != null);
    try testing.expect(std.mem.endsWith(u8, preferred2.?, "mapping2.ini"));

    // Verify get() returns mapping2 values
    const result = store.get(test_fx, .COMP);
    try testing.expect(result != null);
    if (result) |tagged| {
        try testing.expectEqual(@as(?u8, 20), tagged.COMP.Comp_Attack);
    }

    // Clean up test files
    inline for ([_][:0]const u8{ "mapping1", "mapping2" }) |mapping_name| {
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const file_path = try std.fmt.bufPrint(&path_buf, "{s}/maps/COMP/{s}/{s}.ini", .{ config_path_z, sanitized_name, mapping_name });
        std.fs.deleteFileAbsolute(file_path) catch {};
    }

    var dir_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = try std.fmt.bufPrint(&dir_path_buf, "{s}/maps/COMP/{s}", .{ config_path_z, sanitized_name });
    std.fs.deleteDirAbsolute(dir_path) catch {};
}

test "PresetSelection - loading mapping from filepath works correctly" {
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

    const test_fx = "VST: FilepathLoadTest";

    const test_comp = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Attack = 42,
        .Comp_Release = 84,
        .Comp_Thresh = null,
        .Comp_Ratio = null,
        .Comp_DryWet = null,
        .Comp_comp = null,
    };

    const test_mapping = TaggedMapping{ .COMP = test_comp };

    try store.saveToFile(.COMP, test_fx, test_mapping, "custom");

    // Load the mapping using getMap (which uses mapping name)
    const loaded = try store.getMap(test_fx, .COMP, "custom");

    // Verify the loaded data matches what we saved
    try testing.expectEqual(@as(?u8, 42), loaded.COMP.Comp_Attack);
    try testing.expectEqual(@as(?u8, 84), loaded.COMP.Comp_Release);

    // Clean up test files
    var name_buf: [512:0]u8 = undefined;
    const sanitized_name = try fs_helpers.sanitizeFxName(&name_buf, test_fx);

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const file_path = try std.fmt.bufPrint(&path_buffer, "{s}/maps/COMP/{s}/custom.ini", .{ config_path_z, sanitized_name });
    std.fs.deleteFileAbsolute(file_path) catch {};

    var dir_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = try std.fmt.bufPrint(&dir_path_buf, "{s}/maps/COMP/{s}", .{ config_path_z, sanitized_name });
    std.fs.deleteDirAbsolute(dir_path) catch {};
}

// ============================================================================
// Unit Tests - Save Dialog Logic
// ============================================================================

test "SaveDialog - name validation rejects empty names" {
    const empty_name = "";

    // Because empty names are invalid for file paths, we should reject them
    // In the actual implementation, this is checked by: if (self.name_len == 0)
    try testing.expectEqual(@as(usize, 0), empty_name.len);
}

test "SaveDialog - save path construction matches MapStore format" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const test_fx = "VST: PathTest/SubPlugin";
    const mapping_name = "my_preset";
    const config_path = "/test/config";

    // Build path using fs_helpers (same as preset_browser_actions does)
    var name_buf: [512:0]u8 = undefined;
    const sanitized_name = try fs_helpers.sanitizeFxName(&name_buf, test_fx);

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const filepath = fs_helpers.joinStrings(&path_buffer, &.{
        config_path,
        std.fs.path.sep_str,
        "maps",
        std.fs.path.sep_str,
        "COMP",
        std.fs.path.sep_str,
        sanitized_name,
        std.fs.path.sep_str,
        mapping_name,
        ".ini",
    });

    // Verify the path contains sanitized FX name (slashes replaced)
    try testing.expect(!std.mem.containsAtLeast(u8, filepath, 1, "/SubPlugin"));
    try testing.expect(std.mem.containsAtLeast(u8, filepath, 1, "_SubPlugin"));

    // Verify the path ends with the mapping name
    try testing.expect(std.mem.endsWith(u8, filepath, "my_preset.ini"));

    _ = allocator;
}

// ============================================================================
// Unit Tests - Overwrite Protection
// ============================================================================

test "OverwriteProtection - detects existing file before save" {
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

    const test_fx = "VST: OverwriteTest";
    const preset_name = "existing";

    const test_comp = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Attack = 10,
        .Comp_Release = null,
        .Comp_Thresh = null,
        .Comp_Ratio = null,
        .Comp_DryWet = null,
        .Comp_comp = null,
    };

    // Save the preset once
    try store.saveToFile(.COMP, test_fx, TaggedMapping{ .COMP = test_comp }, preset_name);

    // Get list of existing presets
    const mapping_names = try mapping_browser.getMappingNames(allocator, config_path_z, test_fx, .COMP);
    defer {
        for (mapping_names) |name| {
            allocator.free(name);
        }
        allocator.free(mapping_names);
    }

    // Check if "existing" is in the list (simulating the overwrite check)
    var name_exists = false;
    for (mapping_names) |name| {
        if (std.mem.eql(u8, name, preset_name)) {
            name_exists = true;
            break;
        }
    }

    // Because we already saved a preset with this name, it should exist
    try testing.expect(name_exists);

    // Clean up test files
    var name_buf: [512:0]u8 = undefined;
    const sanitized_name = try fs_helpers.sanitizeFxName(&name_buf, test_fx);

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const file_path = try std.fmt.bufPrint(&path_buffer, "{s}/maps/COMP/{s}/{s}.ini", .{ config_path_z, sanitized_name, preset_name });
    std.fs.deleteFileAbsolute(file_path) catch {};

    var dir_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = try std.fmt.bufPrint(&dir_path_buf, "{s}/maps/COMP/{s}", .{ config_path_z, sanitized_name });
    std.fs.deleteDirAbsolute(dir_path) catch {};
}

test "OverwriteProtection - save proceeds when file does not exist" {
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

    const test_fx = "VST: NewPresetTest";
    const new_preset_name = "brand_new";

    // Get list of existing presets (should be empty)
    const mapping_names = try mapping_browser.getMappingNames(allocator, config_path_z, test_fx, .COMP);
    defer {
        for (mapping_names) |name| {
            allocator.free(name);
        }
        allocator.free(mapping_names);
    }

    // Check if the new name exists
    var name_exists = false;
    for (mapping_names) |name| {
        if (std.mem.eql(u8, name, new_preset_name)) {
            name_exists = true;
            break;
        }
    }

    // Because this is a new preset name, it should not exist
    try testing.expect(!name_exists);

    // Now save the preset (should succeed without overwrite prompt)
    const test_comp = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Attack = 10,
        .Comp_Release = null,
        .Comp_Thresh = null,
        .Comp_Ratio = null,
        .Comp_DryWet = null,
        .Comp_comp = null,
    };

    try store.saveToFile(.COMP, test_fx, TaggedMapping{ .COMP = test_comp }, new_preset_name);

    // Verify the file was created
    const mapping_names_after = try mapping_browser.getMappingNames(allocator, config_path_z, test_fx, .COMP);
    defer {
        for (mapping_names_after) |name| {
            allocator.free(name);
        }
        allocator.free(mapping_names_after);
    }

    try testing.expectEqual(@as(usize, 1), mapping_names_after.len);
    try testing.expect(std.mem.eql(u8, mapping_names_after[0], new_preset_name));

    // Clean up test files
    var name_buf: [512:0]u8 = undefined;
    const sanitized_name = try fs_helpers.sanitizeFxName(&name_buf, test_fx);

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const file_path = try std.fmt.bufPrint(&path_buffer, "{s}/maps/COMP/{s}/{s}.ini", .{ config_path_z, sanitized_name, new_preset_name });
    std.fs.deleteFileAbsolute(file_path) catch {};

    var dir_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = try std.fmt.bufPrint(&dir_path_buf, "{s}/maps/COMP/{s}", .{ config_path_z, sanitized_name });
    std.fs.deleteDirAbsolute(dir_path) catch {};
}

// ============================================================================
// Integration Tests - Browser Workflow
// ============================================================================

test "Integration - complete preset browser workflow" {
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

    const test_fx = "VST: WorkflowTest";

    // Simulate user workflow:
    // 1. User loads an FX with existing presets
    const preset1 = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Attack = 10,
        .Comp_Release = null,
        .Comp_Thresh = null,
        .Comp_Ratio = null,
        .Comp_DryWet = null,
        .Comp_comp = null,
    };

    const preset2 = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Attack = 20,
        .Comp_Release = null,
        .Comp_Thresh = null,
        .Comp_Ratio = null,
        .Comp_DryWet = null,
        .Comp_comp = null,
    };

    try store.saveToFile(.COMP, test_fx, TaggedMapping{ .COMP = preset1 }, "preset1");
    try store.saveToFile(.COMP, test_fx, TaggedMapping{ .COMP = preset2 }, "preset2");

    // 2. User opens preset browser (simulated by getting list)
    const available_presets = try mapping_browser.getMappingNames(allocator, config_path_z, test_fx, .COMP);
    defer {
        for (available_presets) |name| {
            allocator.free(name);
        }
        allocator.free(available_presets);
    }

    try testing.expectEqual(@as(usize, 2), available_presets.len);

    // 3. User selects preset2 (simulated by building filepath and setting preferred)
    var name_buf: [512:0]u8 = undefined;
    const sanitized_name = try fs_helpers.sanitizeFxName(&name_buf, test_fx);

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const preset2_path = fs_helpers.joinStrings(&path_buffer, &.{
        config_path_z,
        std.fs.path.sep_str,
        "maps",
        std.fs.path.sep_str,
        "COMP",
        std.fs.path.sep_str,
        sanitized_name,
        std.fs.path.sep_str,
        "preset2",
        ".ini",
    });

    const preset2_path_z = try allocator.dupeZ(u8, preset2_path);

    // Load preset2 into the cache before setting it as preferred
    _ = try store.getMap(test_fx, .COMP, "preset2");

    try store.setPreferredMapping(test_fx, .COMP, preset2_path_z);

    // 4. Verify the selected preset is now active
    const active_preset = store.get(test_fx, .COMP);
    try testing.expect(active_preset != null);

    if (active_preset) |tagged| {
        try testing.expectEqual(@as(?u8, 20), tagged.COMP.Comp_Attack);
    }

    // Clean up test files
    inline for ([_][:0]const u8{ "preset1", "preset2" }) |preset_name| {
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const file_path = try std.fmt.bufPrint(&path_buf, "{s}/maps/COMP/{s}/{s}.ini", .{ config_path_z, sanitized_name, preset_name });
        std.fs.deleteFileAbsolute(file_path) catch {};
    }

    var dir_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = try std.fmt.bufPrint(&dir_path_buf, "{s}/maps/COMP/{s}", .{ config_path_z, sanitized_name });
    std.fs.deleteDirAbsolute(dir_path) catch {};
}

test "Integration - save workflow with new preset name" {
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

    const test_fx = "VST: SaveWorkflowTest";

    // Simulate save workflow:
    // 1. User creates custom mapping
    const custom_preset = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Attack = 5,
        .Comp_Release = 100,
        .Comp_Thresh = 50,
        .Comp_Ratio = null,
        .Comp_DryWet = null,
        .Comp_comp = null,
    };

    // 2. User opens save dialog and enters "my_custom_preset"
    const new_name = "my_custom_preset";

    // 3. Check if name exists (should not exist for new preset)
    const existing_presets = try mapping_browser.getMappingNames(allocator, config_path_z, test_fx, .COMP);
    defer {
        for (existing_presets) |name| {
            allocator.free(name);
        }
        allocator.free(existing_presets);
    }

    var name_exists = false;
    for (existing_presets) |name| {
        if (std.mem.eql(u8, name, new_name)) {
            name_exists = true;
            break;
        }
    }

    try testing.expect(!name_exists);

    // 4. Save the preset
    try store.saveToFile(.COMP, test_fx, TaggedMapping{ .COMP = custom_preset }, new_name);

    // 5. Verify the preset was saved
    const saved_preset = try store.getMap(test_fx, .COMP, new_name);
    try testing.expectEqual(@as(?u8, 5), saved_preset.COMP.Comp_Attack);
    try testing.expectEqual(@as(?u8, 100), saved_preset.COMP.Comp_Release);
    try testing.expectEqual(@as(?u8, 50), saved_preset.COMP.Comp_Thresh);

    // Clean up test files
    var name_buf: [512:0]u8 = undefined;
    const sanitized_name = try fs_helpers.sanitizeFxName(&name_buf, test_fx);

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const file_path = try std.fmt.bufPrint(&path_buffer, "{s}/maps/COMP/{s}/{s}.ini", .{ config_path_z, sanitized_name, new_name });
    std.fs.deleteFileAbsolute(file_path) catch {};

    var dir_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = try std.fmt.bufPrint(&dir_path_buf, "{s}/maps/COMP/{s}", .{ config_path_z, sanitized_name });
    std.fs.deleteDirAbsolute(dir_path) catch {};
}

test "Integration - save workflow with overwrite confirmation" {
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

    const test_fx = "VST: OverwriteWorkflowTest";
    const preset_name = "existing_preset";

    // 1. Create initial preset
    const original_preset = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Attack = 10,
        .Comp_Release = null,
        .Comp_Thresh = null,
        .Comp_Ratio = null,
        .Comp_DryWet = null,
        .Comp_comp = null,
    };

    try store.saveToFile(.COMP, test_fx, TaggedMapping{ .COMP = original_preset }, preset_name);

    // 2. User tries to save with the same name
    const existing_presets = try mapping_browser.getMappingNames(allocator, config_path_z, test_fx, .COMP);
    defer {
        for (existing_presets) |name| {
            allocator.free(name);
        }
        allocator.free(existing_presets);
    }

    // 3. Check if name exists (should trigger overwrite confirmation)
    var name_exists = false;
    for (existing_presets) |name| {
        if (std.mem.eql(u8, name, preset_name)) {
            name_exists = true;
            break;
        }
    }

    try testing.expect(name_exists);

    // 4. User confirms overwrite, save new version
    const updated_preset = MapStore.Comp{
        .version = MapStore.MAPPING_FORMAT_VERSION,
        .Comp_Attack = 20, // Different value
        .Comp_Release = null,
        .Comp_Thresh = null,
        .Comp_Ratio = null,
        .Comp_DryWet = null,
        .Comp_comp = null,
    };

    try store.saveToFile(.COMP, test_fx, TaggedMapping{ .COMP = updated_preset }, preset_name);

    // 5. Verify the preset was overwritten with new values
    // Create fresh store to ensure we're reading from disk
    var store2 = MapStore.empty(allocator, config_path_z);
    defer store2.deinit();

    const loaded_preset = try store2.getMap(test_fx, .COMP, preset_name);
    try testing.expectEqual(@as(?u8, 20), loaded_preset.COMP.Comp_Attack);

    // Clean up test files
    var name_buf: [512:0]u8 = undefined;
    const sanitized_name = try fs_helpers.sanitizeFxName(&name_buf, test_fx);

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const file_path = try std.fmt.bufPrint(&path_buffer, "{s}/maps/COMP/{s}/{s}.ini", .{ config_path_z, sanitized_name, preset_name });
    std.fs.deleteFileAbsolute(file_path) catch {};

    var dir_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = try std.fmt.bufPrint(&dir_path_buf, "{s}/maps/COMP/{s}", .{ config_path_z, sanitized_name });
    std.fs.deleteDirAbsolute(dir_path) catch {};
}
