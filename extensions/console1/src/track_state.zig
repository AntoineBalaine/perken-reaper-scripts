const std = @import("std");
const reaper = @import("reaper.zig").reaper;
const pReaper = @import("pReaper.zig");
const MediaTrack = reaper.MediaTrack;
const ModulesList = @import("statemachine.zig").ModulesList;
const MapStore = @import("mappings.zig");
const Inpt = MapStore.Inpt;
const Shp = MapStore.Shp;
const Eq = MapStore.Eq;
const Comp = MapStore.Comp;
const Outpt = MapStore.Outpt;
const ModulesOrder = @import("fx_ctrl_state.zig").ModulesOrder;
const DefaultFx = @import("settings.zig").DefaultFx;
const TaggedMapping = MapStore.TaggedMapping;
const MockReaper = @import("mock_reaper.zig");
const Guid = @import("utils.zig").Guid;
const log = std.log.scoped(.validation);
const Preferences = @import("settings.zig").Preferences;

pub const MAX_FX = 5;
pub const MAX_PARSED_FX = MAX_FX * 2; // Allow for reasonable number of duplicates

const Location = struct {
    fx_index: c_int,
    mapping: ?TaggedMapping,
};

const ModuleLocations = std.EnumArray(ModulesList, ?Location);

pub const TrackState = @This();
// FX tracking for validation
fx_states: [MAX_FX]struct {
    fx_index: i32,
    // Use bit mask for quick module presence check
    modules: ActiveModules = .{},
} = undefined,
fx_count: usize = 0,

// Quick module -> FX lookup for parameter setting
module_locations: ModuleLocations = undefined,
// const array = std.enums.directEnumArrayDefault(
//     ModulesList,
//     ?Location,
//     @as(?Location, null),
//     0,
//     .{ .INPUT = null, .GATE = null, .EQ = null, .COMP = null, .OUTPT = null },
// );

const ActiveModules = packed struct {
    INPUT: bool = false,
    GATE: bool = false,
    EQ: bool = false,
    COMP: bool = false,
    OUTPT: bool = false,
};

pub const ParsedFx = struct {
    index: i32,
    guid: Guid,
    active_modules: ?ModulesList = null,
};

pub fn validateTrack(track_state: *TrackState, mediaTrack: reaper.MediaTrack, preferences: *Preferences, mapStore: *MapStore) ModuleCoverage {
    // Initialize track state
    track_state.* = .{ .fx_states = undefined, .fx_count = 0, .module_locations = ModuleLocations.initFill(null) };

    var buf: [512:0]u8 = undefined;

    // Get total FX count
    const fx_count = reaper.TrackFX_GetCount(mediaTrack);

    // Scan FX chain
    // Use fixed-size array for parsed FX
    var parsed_fx_buf: [MAX_PARSED_FX]ParsedFx = undefined;
    var parsed_fx = std.ArrayListUnmanaged(ParsedFx).initBuffer(&parsed_fx_buf);

    var i: i32 = 0;
    while (i < fx_count) : (i += 1) {
        if (reaper.TrackFX_GetNamedConfigParm(mediaTrack, i, "renamed_name", &buf, buf.len)) {
            const renamed_name = std.mem.span(@as([*:0]const u8, &buf));
            if (renamed_name.len == 0) continue; // Skip if no rename

            if (parseC1Suffix(renamed_name)) |active_modules| {
                if (parsed_fx.items.len < MAX_PARSED_FX) {
                    parsed_fx.appendAssumeCapacity(.{
                        .index = i,
                        .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(mediaTrack, i)),
                        .active_modules = active_modules,
                    });
                }
                // Silently ignore if we've reached capacity
            }
        }
    }

    var coverage = analyzeCoverage(&parsed_fx, mediaTrack);
    coverage = reorderFx2(coverage, mediaTrack, preferences.default_fx);
    updateTrackState(track_state, coverage, mediaTrack, &buf, mapStore);
    return coverage;
}

fn parseC1Suffix(name: [:0]const u8) ?ModulesList {
    // Look for last "(C1-" occurrence
    const suffix_start = if (std.mem.lastIndexOf(u8, name, "(C1-")) |start| start else return null;

    // Find closing parenthesis
    const suffix_end = if (std.mem.indexOfPos(u8, name, suffix_start, ")")) |end| end else return null;

    // Extract module identifiers
    const modules = name[suffix_start + 4 .. suffix_end];

    // Return first found valid module
    for (modules) |c| {
        return switch (c) {
            'I' => .INPUT,
            'S' => .GATE,
            'E' => .EQ,
            'C' => .COMP,
            'O' => .OUTPT,
            else => continue,
        };
    }

    return null;
}

test "parseC1Suffix" {
    // Valid cases
    const testing = std.testing;
    try testing.expectEqual(ActiveModules{ .INPUT = true, .GATE = false, .EQ = false, .COMP = false, .OUTPT = false }, parseC1Suffix("Some Plugin (C1-I)").?);

    try testing.expectEqual(ActiveModules{ .INPUT = true, .GATE = true, .EQ = true, .COMP = true, .OUTPT = true }, parseC1Suffix("Complex Plugin (C1-ISECO)").?);

    try testing.expectEqual(ActiveModules{ .INPUT = false, .GATE = false, .EQ = false, .COMP = true, .OUTPT = false }, parseC1Suffix("ReaComp (C1-C)").?);

    // Invalid cases
    try testing.expectEqual(@as(?ActiveModules, null), parseC1Suffix("No Suffix Plugin"));

    try testing.expectEqual(@as(?ActiveModules, null), parseC1Suffix("Invalid (C1"));

    // Ignore invalid characters
    try testing.expectEqual(ActiveModules{ .INPUT = true, .GATE = false, .EQ = false, .COMP = false, .OUTPT = false }, parseC1Suffix("Plugin (C1-IX)").?);
}

/// Tracks which FX provides each module
const ModuleLocation = struct {
    index: c_int,
    guid: Guid,
};

pub const ModuleCoverage = struct {
    INPUT: ?ModuleLocation = null,
    GATE: ?ModuleLocation = null,
    EQ: ?ModuleLocation = null,
    COMP: ?ModuleLocation = null,
    OUTPT: ?ModuleLocation = null,
};

pub fn analyzeCoverage(
    parsed_fx: *std.ArrayListUnmanaged(ParsedFx),
    media_track: MediaTrack,
) ModuleCoverage {
    var coverage = ModuleCoverage{};

    var i: usize = 0;
    while (i < parsed_fx.items.len) : (i += 1) {
        const fx = &parsed_fx.items[i];
        if (fx.active_modules) |module| {
            // Check if module already covered
            switch (module) {
                inline else => |impl| {
                    if (@field(coverage, @tagName(impl)) != null) {
                        // Found duplicate, remove suffix only
                        removeDuplicateModule(fx.index, media_track);
                    } else {
                        // Mark as covered and record provider
                        @field(coverage, @tagName(impl)) = .{
                            .index = fx.index,
                            .guid = fx.guid,
                        };
                    }
                },
            }
        }
    }

    return coverage;
}

pub fn removeDuplicateModule(fx_index: i32, media_track: MediaTrack) void {
    var name_buf: [512:0]u8 = undefined;
    var buf: [512:0]u8 = undefined;

    // Get current name
    if (!reaper.TrackFX_GetNamedConfigParm(media_track, fx_index, "renamed_name", @ptrCast(&name_buf), name_buf.len)) {
        return;
    }
    const fx_name = std.mem.span(@as([*:0]const u8, @ptrCast(&name_buf)));

    const suffix_start = std.mem.lastIndexOf(u8, fx_name, "(C1-") orelse return;
    const suffix_end = std.mem.indexOfPos(u8, fx_name, suffix_start, ")") orelse return;

    // Trim any trailing spaces before the suffix
    var prefix_end = suffix_start;
    while (prefix_end > 0 and fx_name[prefix_end - 1] == ' ') {
        prefix_end -= 1;
    }

    // Remove suffix and maintain proper spacing
    _ = std.fmt.bufPrintZ(&buf, "{s}{s}", .{
        fx_name[0..prefix_end],
        if (suffix_end + 1 < fx_name.len) fx_name[suffix_end + 1 ..] else "",
    }) catch return;

    _ = pReaper.TrackFX_SetNamedConfigParm(.{ media_track, fx_index, "renamed_name", @as([:0]const u8, @ptrCast(&buf)) });
}

test "removeDuplicateModule" {
    const testing = std.testing;

    const allocator = testing.allocator;

    // Setup mock functions
    MockReaper.init(allocator);
    defer MockReaper.deinit();

    const dummy_track: MediaTrack = @ptrFromInt(0xdeadbeef);

    // Test 1: Remove INPUT module from a multi-module suffix
    {
        try MockReaper.reset(allocator);
        try MockReaper.fx_chain.append(.{
            .original_name = "ReaComp",
            .renamed_name = "ReaComp (C1-IC)",
        });
        removeDuplicateModule(0, .INPUT, dummy_track);
        try testing.expectEqualStrings("ReaComp (C1-C)", MockReaper.fx_chain.items[0].renamed_name);
    }

    // Test 2: Remove middle module
    {
        try MockReaper.reset(allocator);
        try MockReaper.fx_chain.append(.{
            .original_name = "ReaEQ",
            .renamed_name = "ReaEQ (C1-SEC)",
        });
        removeDuplicateModule(1, .EQ, dummy_track);
        try testing.expectEqualStrings("ReaEQ (C1-SC)", MockReaper.fx_chain.items[0].renamed_name);
    }

    // Test 3: FX name with text after suffix
    {
        try MockReaper.reset(allocator);
        try MockReaper.fx_chain.append(.{
            .original_name = "ReaComp",
            .renamed_name = "ReaComp (C1-IC) my settings",
        });
        removeDuplicateModule(2, .INPUT, dummy_track);
        try testing.expectEqualStrings("ReaComp (C1-C) my settings", MockReaper.fx_chain.items[0].renamed_name);
    }

    // Test 4: Single module suffix
    {
        try MockReaper.reset(allocator);
        try MockReaper.fx_chain.append(.{
            .original_name = "ReaComp",
            .renamed_name = "ReaComp (C1-C)",
        });
        removeDuplicateModule(3, .COMP, dummy_track);
        try testing.expectEqualStrings("ReaComp (C1-)", MockReaper.fx_chain.items[0].renamed_name);
    }
}

test "analyzeCoverage" {
    const testing = std.testing;

    const allocator = testing.allocator;

    // Setup mock functions
    MockReaper.init(testing.allocator);
    defer MockReaper.deinit();

    const dummy_track: MediaTrack = @ptrFromInt(0xdeadbeef);

    var parsed_fx_buf: [MAX_PARSED_FX]ParsedFx = undefined;
    var parsed_fx = std.ArrayListUnmanaged(ParsedFx).initBuffer(&parsed_fx_buf);

    // Test case 1: Valid coverage with no duplicates
    {
        try MockReaper.reset(allocator);
        parsed_fx.clearRetainingCapacity();
        const items = [_]ParsedFx{
            .{
                .index = 0,
                .active_modules = .{
                    .INPUT = true,
                    .GATE = false,
                    .EQ = false,
                    .COMP = false,
                    .OUTPT = false,
                },
            },
            .{
                .index = 1,
                .active_modules = .{
                    .INPUT = false,
                    .GATE = true,
                    .EQ = false,
                    .COMP = false,
                    .OUTPT = false,
                },
            },
        };
        parsed_fx.appendSliceAssumeCapacity(&items);

        const coverage = analyzeCoverage(&parsed_fx, dummy_track);
        try testing.expect(coverage.INPUT == 0);
        try testing.expect(coverage.GATE == 1);
    }

    // Test case 2: Duplicate module (should error)
    {
        try MockReaper.reset(allocator);
        try MockReaper.fx_chain.append(.{
            .original_name = "Test FX",
            .renamed_name = "Test FX (C1-I)",
        });
        try MockReaper.fx_chain.append(.{
            .original_name = "Test FX",
            .renamed_name = "Test FX (C1-I)", // Second FX with duplicate INPUT module
        });
        parsed_fx.clearRetainingCapacity();
        const items = [_]ParsedFx{
            .{
                .index = 0,
                .active_modules = .{
                    .INPUT = true,
                    .GATE = false,
                    .EQ = false,
                    .COMP = false,
                    .OUTPT = false,
                },
            },
            .{
                .index = 1,
                .active_modules = .{
                    .INPUT = true, // Duplicate INPUT module
                    .GATE = false,
                    .EQ = false,
                    .COMP = false,
                    .OUTPT = false,
                },
            },
        };
        parsed_fx.appendSliceAssumeCapacity(&items);

        const coverage = analyzeCoverage(&parsed_fx, dummy_track);
        try testing.expectEqual(0, coverage.INPUT);
        try testing.expect(MockReaper.fx_chain_changed);
    }
}

fn moduleToSuffix(buf: *[64:0]u8, comptime field_name: []const u8) ![:0]const u8 {
    return std.fmt.bufPrintZ(
        buf,
        "(C1-{c})",
        .{if (comptime std.mem.eql(u8, field_name, "INPUT"))
            'I'
        else if (comptime std.mem.eql(u8, field_name, "GATE"))
            'S'
        else if (comptime std.mem.eql(u8, field_name, "EQ"))
            'E'
        else if (comptime std.mem.eql(u8, field_name, "COMP"))
            'C'
        else if (comptime std.mem.eql(u8, field_name, "OUTPT"))
            'O'
        else
            unreachable},
    );
}

/// For now, assume that missing modules are always going to be one fx per module
pub fn updateTrackState(
    track_state: *TrackState,
    coverage: ModuleCoverage,
    mediaTrack: MediaTrack,
    buf: *[512:0]u8,
    map_store: *MapStore,
) void {
    // Reset current state
    track_state.fx_count = 0;
    inline for (std.meta.fields(ModulesList)) |field| {
        track_state.module_locations.set(@field(ModulesList, field.name), null);
    }

    // Iterate through coverage to update module locations
    inline for (std.meta.fields(ModuleCoverage)) |field| {
        if (@field(coverage, field.name)) |location| {
            // Get original FX name for mapping lookup
            _ = reaper.TrackFX_GetNamedConfigParm(
                mediaTrack,
                location.index,
                "original_name",
                buf,
                buf.len,
            );

            const module = @field(ModulesList, field.name);
            track_state.module_locations.set(module, .{
                .fx_index = location.index,
                .mapping = map_store.get(std.mem.span(@as([*:0]const u8, buf)), module),
            });

            // Create ActiveModules with single module
            var modules = ActiveModules{};
            @field(modules, field.name) = true;

            // Update fx_states
            track_state.fx_states[track_state.fx_count] = .{
                .fx_index = location.index,
                .modules = modules,
            };
            track_state.fx_count += 1;
        }
    }
}

fn insertModuleLinkedFx(
    mediaTrack: MediaTrack,
    module: ModulesList,
    insert_pos: i32,
    default_fx: DefaultFx,
) ?struct { index: i32, guid: Guid } {
    const fx_name = default_fx.get(module) orelse return null;

    // Insert FX at position
    const add_result = pReaper.TrackFX_AddByName(.{
        mediaTrack,
        fx_name,
        false,
        if (insert_pos >= 0) -1000 - insert_pos else insert_pos,
    });

    if (add_result >= 0) {
        // Set module suffix
        var name_buf: [512:0]u8 = undefined;
        const new_name = std.fmt.bufPrintZ(&name_buf, "{s} (C1-{s})", .{ fx_name, module.toModulePrefix() }) catch return null;

        _ = pReaper.TrackFX_SetNamedConfigParm(.{
            mediaTrack,
            add_result,
            "renamed_name",
            new_name,
        });

        // Get GUID of newly inserted FX
        const guid_ptr = reaper.TrackFX_GetFXGUID(mediaTrack, add_result);
        const guid = Guid.fromReaperGUID(guid_ptr);

        return .{ .index = add_result, .guid = guid };
    }

    return null;
}

fn updateCoveragePositions(coverage: *ModuleCoverage, mediaTrack: MediaTrack) void {
    const fx_count = reaper.TrackFX_GetCount(mediaTrack);

    var i: i32 = 0;
    while (i < fx_count) : (i += 1) {
        const guid_ptr = reaper.TrackFX_GetFXGUID(mediaTrack, i);
        const guid = Guid.fromReaperGUID(guid_ptr);

        // Check if this FX matches any of our covered modules
        blk: {
            inline for (std.meta.fields(ModuleCoverage)) |field| {
                if (@field(coverage, field.name)) |*location| {
                    if (std.mem.eql(u8, &guid.bytes, &location.guid.bytes)) {
                        location.index = i;
                        break :blk; // Break out of the comparison block once we find a match
                    }
                }
            }
        }
    }
}

pub fn reorderFx2(cvrg: ModuleCoverage, mediaTrack: MediaTrack, default_fx: DefaultFx) ModuleCoverage {
    var coverage = cvrg;

    // Handle INPUT first
    if (coverage.INPUT == null) {
        // Find lowest position among module-linked FX
        const insert_pos = blk: {
            var min_pos: i32 = std.math.maxInt(i32);
            var found_any = false;
            inline for (std.meta.fields(ModuleCoverage)) |field| {
                if (@field(coverage, field.name)) |pos| {
                    min_pos = @min(min_pos, pos.index);
                    found_any = true;
                }
            }
            break :blk if (found_any) min_pos else -1;
        };

        if (insertModuleLinkedFx(mediaTrack, .INPUT, insert_pos, default_fx)) |result| {
            coverage.INPUT = .{ .index = result.index, .guid = result.guid };
            updateCoveragePositions(&coverage, mediaTrack);
        } else {
            log.err("Failed to add INPUT FX", .{});
        }
    }

    // Handle missing GATE
    if (coverage.GATE == null) {
        if (coverage.COMP) |comp_pos| {
            const insert_pos = comp_pos.index;
            // Add GATE before COMP
            if (insertModuleLinkedFx(mediaTrack, .GATE, insert_pos, default_fx)) |result| {
                coverage.GATE = .{ .index = result.index, .guid = result.guid };
                updateCoveragePositions(&coverage, mediaTrack);
            } else {
                log.err("Failed to add GATE FX before COMP", .{});
            }
        } else {
            // Neither exists, check EQ position or add after INPUT
            const insert_pos = if (coverage.EQ) |eq_pos|
                eq_pos.index + 1
            else if (coverage.INPUT) |input_pos|
                input_pos.index + 1
            else
                -1;

            // Add GATE first
            if (insertModuleLinkedFx(mediaTrack, .GATE, insert_pos, default_fx)) |result| {
                coverage.GATE = .{ .index = result.index, .guid = result.guid };
                updateCoveragePositions(&coverage, mediaTrack);
            } else {
                log.err("Failed to add GATE FX", .{});
            }
        }
    }

    // Handle missing COMP
    if (coverage.COMP == null) {
        const insert_pos = if (coverage.GATE) |gate|
            gate.index + 1
        else if (coverage.EQ) |eq|
            eq.index + 1
        else if (coverage.INPUT) |input|
            input.index + 1
        else
            -1;

        if (insertModuleLinkedFx(mediaTrack, .COMP, insert_pos, default_fx)) |result| {
            coverage.COMP = .{ .index = result.index, .guid = result.guid };
            updateCoveragePositions(&coverage, mediaTrack);
        } else {
            log.err("Failed to add COMP FX", .{});
        }
    }

    // Handle EQ
    if (coverage.EQ == null) {
        const insert_pos = if (coverage.GATE) |gate_pos|
            gate_pos.index + 1
        else if (coverage.INPUT) |input_pos|
            input_pos.index + 1
        else
            -1;

        if (insertModuleLinkedFx(mediaTrack, .EQ, insert_pos, default_fx)) |result| {
            coverage.EQ = .{ .index = result.index, .guid = result.guid };
            updateCoveragePositions(&coverage, mediaTrack);
        } else {
            log.err("Failed to add EQ FX", .{});
        }
    }

    // Handle OUTPUT last
    if (coverage.OUTPT == null) {
        const insert_pos = blk: {
            var high_pos: i32 = -1;
            inline for (std.meta.fields(ModuleCoverage)) |field| {
                if (@field(coverage, field.name)) |pos| {
                    high_pos = @max(high_pos, pos.index);
                }
            }
            break :blk if (high_pos == -1) high_pos else high_pos + 1;
        };

        if (insertModuleLinkedFx(mediaTrack, .OUTPT, insert_pos, default_fx)) |result| {
            coverage.OUTPT = .{ .index = result.index, .guid = result.guid };
            updateCoveragePositions(&coverage, mediaTrack);
        } else {
            log.err("Failed to add OUTPUT FX", .{});
        }
    }

    return coverage;
}

test "reorderFx2" {
    const testing = std.testing;

    const allocator = testing.allocator;

    MockReaper.init(allocator);
    defer MockReaper.deinit();

    const dummy_track: MediaTrack = @ptrFromInt(0xdeadbeef);
    var default_fx = DefaultFx.init(.{
        .INPUT = "Standard Input",
        .GATE = "Standard Gate",
        .EQ = "Standard EQ",
        .COMP = "Standard Comp",
        .OUTPT = "Standard Output",
    });

    // Test 1: Empty coverage
    {
        try MockReaper.reset(allocator);
        var coverage = ModuleCoverage{};

        coverage = reorderFx2(coverage, dummy_track, default_fx);

        try testing.expect(coverage.INPUT != null);
        try testing.expect(coverage.GATE != null);
        try testing.expect(coverage.EQ != null);
        try testing.expect(coverage.COMP != null);
        try testing.expect(coverage.OUTPT != null);

        // Verify order
        const chain = try MockReaper.getChainState();
        defer std.testing.allocator.free(chain);

        try testing.expectEqual(@as(usize, 5), chain.len);
        try testing.expectEqualStrings("Standard Input (C1-I)", chain[0].renamed_name);
        try testing.expectEqualStrings("Standard Gate (C1-S)", chain[1].renamed_name);
        try testing.expectEqualStrings("Standard EQ (C1-E)", chain[2].renamed_name);
        try testing.expectEqualStrings("Standard Comp (C1-C)", chain[3].renamed_name);
        try testing.expectEqualStrings("Standard Output (C1-O)", chain[4].renamed_name);
    }

    // Test 2: Incorrect order needing fixes
    {
        try MockReaper.reset(allocator);

        // Setup initial chain state
        try MockReaper.fx_chain.append(.{
            .original_name = "Standard Comp",
            .renamed_name = "Standard Comp (C1-C)",
        });
        try MockReaper.fx_chain.append(.{
            .original_name = "Standard Output",
            .renamed_name = "Standard Output (C1-O)",
        });
        try MockReaper.fx_chain.append(.{
            .original_name = "Standard Input",
            .renamed_name = "Standard Input (C1-I)",
        });
        try MockReaper.fx_chain.append(.{
            .original_name = "Standard Gate",
            .renamed_name = "Standard Gate (C1-S)",
        });
        try MockReaper.fx_chain.append(.{
            .original_name = "Standard EQ",
            .renamed_name = "Standard EQ (C1-E)",
        });

        var coverage = ModuleCoverage{
            .INPUT = 2,
            .GATE = 3,
            .EQ = 4,
            .COMP = 0,
            .OUTPT = 1,
        };

        coverage = reorderFx2(coverage, dummy_track, default_fx);

        // Verify final order
        const chain = try MockReaper.getChainState();
        defer std.testing.allocator.free(chain);

        try testing.expectEqual(5, chain.len);
        try testing.expectEqualStrings("Standard Input (C1-I)", chain[0].renamed_name);
        try testing.expectEqualStrings("Standard Gate (C1-S)", chain[1].renamed_name);
        try testing.expectEqualStrings("Standard EQ (C1-E)", chain[2].renamed_name);
        try testing.expectEqualStrings("Standard Comp (C1-C)", chain[3].renamed_name);
        try testing.expectEqualStrings("Standard Output (C1-O)", chain[4].renamed_name);
    }

    // Test 3: Correct order with some modules
    {
        try MockReaper.reset(allocator);

        try MockReaper.fx_chain.append(.{
            .original_name = "Standard Input",
            .renamed_name = "Standard Input (C1-I)",
        });
        try MockReaper.fx_chain.append(.{
            .original_name = "Standard EQ",
            .renamed_name = "Standard EQ (C1-E)",
        });
        try MockReaper.fx_chain.append(.{
            .original_name = "Standard Output",
            .renamed_name = "Standard Output (C1-O)",
        });

        var coverage = ModuleCoverage{
            .INPUT = 0,
            .EQ = 1,
            .OUTPT = 2,
        };

        coverage = reorderFx2(coverage, dummy_track, default_fx);

        const chain = try MockReaper.getChainState();
        defer std.testing.allocator.free(chain);

        try testing.expect(chain.len == 5); // Should add missing GATE and COMP
        try testing.expectEqualStrings("Standard Input (C1-I)", chain[0].renamed_name);
        try testing.expectEqualStrings("Standard Gate (C1-S)", chain[1].renamed_name);
        try testing.expectEqualStrings("Standard EQ (C1-E)", chain[2].renamed_name);
        try testing.expectEqualStrings("Standard Comp (C1-C)", chain[3].renamed_name);
        try testing.expectEqualStrings("Standard Output (C1-O)", chain[4].renamed_name);
    }

    // Test 4: Missing middle modules
    {
        try MockReaper.reset(allocator);

        try MockReaper.fx_chain.append(.{
            .original_name = "Standard Input",
            .renamed_name = "Standard Input (C1-I)",
        });
        try MockReaper.fx_chain.append(.{
            .original_name = "Standard Output",
            .renamed_name = "Standard Output (C1-O)",
        });

        var coverage = ModuleCoverage{
            .INPUT = 0,
            .OUTPT = 1,
        };

        coverage = reorderFx2(coverage, dummy_track, default_fx);

        const chain = try MockReaper.getChainState();
        defer std.testing.allocator.free(chain);

        try testing.expect(chain.len == 5);
        try testing.expectEqualStrings("Standard Input (C1-I)", chain[0].renamed_name);
        try testing.expectEqualStrings("Standard Gate (C1-S)", chain[1].renamed_name);
        try testing.expectEqualStrings("Standard EQ (C1-E)", chain[2].renamed_name);
        try testing.expectEqualStrings("Standard Comp (C1-C)", chain[3].renamed_name);
        try testing.expectEqualStrings("Standard Output (C1-O)", chain[4].renamed_name);
    }

    // Test 5: Consolidation during reordering
    {
        try MockReaper.reset(allocator);
        default_fx = DefaultFx.init(.{
            .INPUT = "Channel Strip",
            .GATE = "Channel Strip",
            .EQ = "Channel Strip",
            .COMP = "Channel Strip",
            .OUTPT = "Different Output",
        });

        try MockReaper.fx_chain.append(.{
            .original_name = "Channel Strip",
            .renamed_name = "Channel Strip (C1-C)",
        });
        try MockReaper.fx_chain.append(.{
            .original_name = "Channel Strip",
            .renamed_name = "Channel Strip (C1-I)",
        });

        var coverage = ModuleCoverage{
            .INPUT = 1,
            .COMP = 0,
        };

        coverage = reorderFx2(coverage, dummy_track, default_fx);

        const chain = try MockReaper.getChainState();
        defer std.testing.allocator.free(chain);

        // Should consolidate INPUT, GATE, EQ, COMP into one FX
        try testing.expect(chain.len == 2); // Consolidated FX + OUTPUT
        try testing.expectEqualStrings("Channel Strip (C1-ISEC)", chain[0].renamed_name);
        try testing.expectEqualStrings("Different Output (C1-O)", chain[1].renamed_name);
    }

    // Test 6: Partial chain with incorrect order
    {
        try MockReaper.reset(allocator);

        // Setup initial incorrect order: COMP before GATE
        try MockReaper.fx_chain.append(.{
            .original_name = "Standard Comp",
            .renamed_name = "Standard Comp (C1-C)",
        });
        try MockReaper.fx_chain.append(.{
            .original_name = "Standard Gate",
            .renamed_name = "Standard Gate (C1-S)",
        });

        var coverage = ModuleCoverage{
            .GATE = 1,
            .COMP = 0,
        };

        coverage = reorderFx2(coverage, dummy_track, default_fx);

        const chain = try MockReaper.getChainState();
        defer std.testing.allocator.free(chain);

        try testing.expect(chain.len == 5);
        // Verify final order:
        // 1. INPUT should be added first
        // 2. GATE should be moved before COMP
        // 3. EQ should be added between GATE and COMP
        // 4. OUTPUT should be added last
        try testing.expectEqualStrings("Standard Input (C1-I)", chain[0].renamed_name);
        try testing.expectEqualStrings("Standard Gate (C1-S)", chain[1].renamed_name);
        try testing.expectEqualStrings("Standard EQ (C1-E)", chain[2].renamed_name);
        try testing.expectEqualStrings("Standard Comp (C1-C)", chain[3].renamed_name);
        try testing.expectEqualStrings("Standard Output (C1-O)", chain[4].renamed_name);

        // Verify coverage was updated correctly
        try testing.expectEqual(@as(i32, 0), coverage.INPUT.?);
        try testing.expectEqual(@as(i32, 1), coverage.GATE.?);
        try testing.expectEqual(@as(i32, 2), coverage.EQ.?);
        try testing.expectEqual(@as(i32, 3), coverage.COMP.?);
        try testing.expectEqual(@as(i32, 4), coverage.OUTPT.?);
    }

    // Test 7: Edge case with single FX handling multiple modules
    {
        try MockReaper.reset(allocator);

        // Setup initial state: one FX handling both INPUT and EQ
        try MockReaper.fx_chain.append(.{
            .original_name = "Standard Input",
            .renamed_name = "Standard Input (C1-IE)",
        });

        var coverage = ModuleCoverage{
            .INPUT = 0,
            .EQ = 0,
        };

        coverage = reorderFx2(coverage, dummy_track, default_fx);

        const chain = try MockReaper.getChainState();
        defer std.testing.allocator.free(chain);

        // Should split the consolidated FX and add missing modules in correct order
        try testing.expectEqual(@as(usize, 5), chain.len);
        try testing.expectEqualStrings("Standard Input (C1-I)", chain[0].renamed_name);
        try testing.expectEqualStrings("Standard Gate (C1-S)", chain[1].renamed_name);
        try testing.expectEqualStrings("Standard EQ (C1-E)", chain[2].renamed_name);
        try testing.expectEqualStrings("Standard Comp (C1-C)", chain[3].renamed_name);
        try testing.expectEqualStrings("Standard Output (C1-O)", chain[4].renamed_name);

        // Verify coverage reflects the split and new positions
        try testing.expectEqual(@as(i32, 0), coverage.INPUT.?);
        try testing.expectEqual(@as(i32, 1), coverage.GATE.?);
        try testing.expectEqual(@as(i32, 2), coverage.EQ.?);
        try testing.expectEqual(@as(i32, 3), coverage.COMP.?);
        try testing.expectEqual(@as(i32, 4), coverage.OUTPT.?);
    }

    // Test 8: Case where default FX for adjacent modules are the same
    {
        try MockReaper.reset(allocator);

        // Setup where GATE and COMP will use the same default FX
        default_fx = DefaultFx.init(.{
            .INPUT = "Standard Input",
            .GATE = "Dynamics Processor", // Same FX for GATE and COMP
            .EQ = "Standard EQ",
            .COMP = "Dynamics Processor", // Same FX for GATE and COMP
            .OUTPT = "Standard Output",
        });

        // Start with just INPUT and EQ
        try MockReaper.fx_chain.append(.{
            .original_name = "Standard Input",
            .renamed_name = "Standard Input (C1-I)",
        });
        try MockReaper.fx_chain.append(.{
            .original_name = "Standard EQ",
            .renamed_name = "Standard EQ (C1-E)",
        });

        var coverage = ModuleCoverage{
            .INPUT = 0,
            .EQ = 1,
        };

        coverage = reorderFx2(coverage, dummy_track, default_fx);

        const chain = try MockReaper.getChainState();
        defer std.testing.allocator.free(chain);

        // Should add GATE and COMP as one consolidated FX
        try testing.expectEqual(@as(usize, 4), chain.len); // INPUT, GATE+COMP(consolidated), EQ, OUTPUT
        try testing.expectEqualStrings("Standard Input (C1-I)", chain[0].renamed_name);
        try testing.expectEqualStrings("Dynamics Processor (C1-SC)", chain[1].renamed_name); // Consolidated
        try testing.expectEqualStrings("Standard EQ (C1-E)", chain[2].renamed_name);
        try testing.expectEqualStrings("Standard Output (C1-O)", chain[3].renamed_name);

        // Verify coverage reflects consolidated positions
        try testing.expectEqual(@as(i32, 0), coverage.INPUT.?);
        try testing.expectEqual(@as(i32, 1), coverage.GATE.?); // Both GATE and COMP
        try testing.expectEqual(@as(i32, 1), coverage.COMP.?); // point to same position
        try testing.expectEqual(@as(i32, 2), coverage.EQ.?);
        try testing.expectEqual(@as(i32, 3), coverage.OUTPT.?);

        // Verify the consolidation was tracked
        try testing.expect(MockReaper.fx_chain_changed);
    }
}
const ConsolidationResult = struct {
    did_consolidate: bool,
    position: ?i32,
};

fn toOrderedSuffix(current_modules: ActiveModules, new_module: ModulesList, buf: *[5:0]u8) [:0]const u8 {
    var active_modules = current_modules;

    switch (new_module) {
        inline else => |impl| @field(active_modules, @tagName(impl)) = true,
    }

    var len: usize = 0;
    // Fields are already defined in the desired order: INPUT, GATE, EQ, COMP, OUTPT
    inline for (std.meta.fields(ActiveModules)) |field| {
        if (@field(active_modules, field.name)) {
            const module = @field(ModulesList, field.name);
            buf[len] = module.toModulePrefixChar();
            len += 1;
        }
    }

    buf[len] = 0;
    return buf[0..len :0];
}

pub fn setModulesOrder(
    self: *TrackState,
    order: ModulesOrder,
    mediaTrack: MediaTrack,
    ref_coverage: ModuleCoverage,
) void {
    var coverage = ref_coverage;
    // Early return if we don't have all three modules
    const eq_loc = self.module_locations.get(.EQ);
    const gate_loc = self.module_locations.get(.GATE);
    const comp_loc = self.module_locations.get(.COMP);

    if (eq_loc == null or gate_loc == null or comp_loc == null) return;
    const eq = eq_loc.?.fx_index;
    const gate = gate_loc.?.fx_index;
    const comp = comp_loc.?.fx_index;

    const eq_target_pos: c_int = switch (order) {
        .@"EQ-S-C" => if (eq > gate) gate else gate - 1,
        .@"S-C-EQ" => if (eq > comp) eq else comp,
        .@"S-EQ-C" => if (eq > comp) comp else comp - 1,
    };

    // Only move if needed
    if (eq_loc.?.fx_index == eq_target_pos) return;

    pReaper.TrackFX_CopyToTrack(.{ mediaTrack, eq_loc.?.fx_index, mediaTrack, eq_target_pos, true });

    // Update coverage with new positions
    updateCoveragePositions(&coverage, mediaTrack);

    // Update module_locations with new positions
    inline for (comptime std.enums.values(ModulesList)) |module| {
        const pos = switch (module) {
            inline else => |impl| @field(coverage, @tagName(impl)),
        };
        if (pos) |module_coverage| {
            if (self.module_locations.get(module)) |loc| {
                self.module_locations.set(module, .{
                    .fx_index = module_coverage.index,
                    .mapping = loc.mapping,
                });
            }
        }
    }
}

pub fn getModulesOrder(self: TrackState) ModulesOrder {
    // Gate before Comp is guaranteed by reorderFx
    const eq_loc = self.module_locations.get(.EQ);
    const gate_loc = self.module_locations.get(.GATE);
    const comp_loc = self.module_locations.get(.COMP);

    if (eq_loc) |eq| {
        if (gate_loc) |gate| {
            if (eq.fx_index < gate.fx_index) {
                return .@"EQ-S-C";
            } else if (comp_loc) |comp| {
                return if (comp.fx_index < eq.fx_index)
                    .@"S-C-EQ"
                else
                    .@"S-EQ-C";
            }
        }
    }
    return .@"S-EQ-C"; // default if can't determine
}

pub fn getFirstModuleIndex(self: *const TrackState) ?i32 {
    var first_idx: ?i32 = null;
    inline for (comptime std.enums.values(ModulesList)) |module| {
        if (self.module_locations.get(module)) |location| {
            if (first_idx == null or location.fx_index < first_idx.?) {
                first_idx = location.fx_index;
            }
        }
    }
    return first_idx;
}

pub fn getLastModuleIndex(self: *const TrackState) ?i32 {
    var last_idx: ?i32 = null;
    inline for (comptime std.enums.values(ModulesList)) |module| {
        if (self.module_locations.get(module)) |location| {
            if (last_idx == null or location.fx_index > last_idx.?) {
                last_idx = location.fx_index;
            }
        }
    }
    return last_idx;
}
