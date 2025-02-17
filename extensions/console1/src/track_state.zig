const std = @import("std");
const reaper = @import("reaper.zig").reaper;
const pReaper = @import("pReaper.zig");
const MediaTrack = reaper.MediaTrack;
const ModulesList = @import("statemachine.zig").ModulesList;
const globals = @import("globals.zig");
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

pub const MAX_FX = 5;
pub const MAX_PARSED_FX = MAX_FX * 2; // Allow for reasonable number of duplicates

const Location = struct {
    fx_index: c_int,
    mapping: ?TaggedMapping,
};

const ModuleLocation = std.EnumArray(ModulesList, ?Location);

pub const TrackState = @This();
// FX tracking for validation
fx_states: [MAX_FX]struct {
    fx_index: i32,
    // Use bit mask for quick module presence check
    modules: ActiveModules = .{},
} = undefined,
fx_count: usize = 0,

// Quick module -> FX lookup for parameter setting
module_locations: ModuleLocation = undefined,
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
    active_modules: ?ActiveModules = null,
};

pub fn validateTrack(track_state: *TrackState, mediaTrack: reaper.MediaTrack) void {
    // Initialize track state
    track_state.* = .{ .fx_states = undefined, .fx_count = 0, .module_locations = ModuleLocation.initFill(null) };

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
                        .active_modules = active_modules,
                    });
                }
                // Silently ignore if we've reached capacity
            }
        }
    }

    var coverage = analyzeCoverage(&parsed_fx, mediaTrack);
    coverage = reorderFx2(coverage, mediaTrack, globals.preferences.default_fx);
    updateTrackState(track_state, &parsed_fx, coverage, mediaTrack, &buf);
}

fn parseC1Suffix(name: [:0]const u8) ?ActiveModules {
    // Look for last "(C1-" occurrence
    const suffix_start = if (std.mem.lastIndexOf(u8, name, "(C1-")) |start| start else return null;

    // Find closing parenthesis
    const suffix_end = if (std.mem.indexOfPos(u8, name, suffix_start, ")")) |end| end else return null;

    // Extract module identifiers
    const modules = name[suffix_start + 4 .. suffix_end];

    var result: ActiveModules = .{};
    for (modules) |c| {
        switch (c) {
            'I' => result.INPUT = true,
            'S' => result.GATE = true,
            'E' => result.EQ = true,
            'C' => result.COMP = true,
            'O' => result.OUTPT = true,
            else => {}, // ignore invalid characters
        }
    }

    return result;
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
pub const ModuleCoverage = struct {
    INPUT: ?c_int = null,
    GATE: ?c_int = null,
    EQ: ?c_int = null,
    COMP: ?c_int = null,
    OUTPT: ?c_int = null,
};

pub fn analyzeCoverage(
    parsed_fx: *std.ArrayListUnmanaged(ParsedFx),
    media_track: MediaTrack,
) ModuleCoverage {
    var coverage = ModuleCoverage{};

    var i: usize = 0;
    while (i < parsed_fx.items.len) : (i += 1) {
        const fx = parsed_fx.items[i];
        if (fx.active_modules) |modules| {
            // For each active module in this FX
            inline for (std.meta.fields(@TypeOf(modules))) |field| {
                const is_active = @field(modules, field.name);
                if (is_active) {
                    // Check if module already covered
                    if (@field(coverage, field.name) != null) {
                        const module = @field(ModulesList, field.name);
                        removeDuplicateModule(fx.index, module, media_track);
                    } else {
                        // Mark as covered and record provider
                        @field(coverage, field.name) = fx.index;
                    }
                }
            }
        }
    }

    return coverage;
}

pub fn removeDuplicateModule(
    fx_index: i32,
    module_to_remove: ModulesList,
    media_track: MediaTrack,
) void {
    var name_buf: [512:0]u8 = undefined;

    // Get current name
    if (!reaper.TrackFX_GetNamedConfigParm(media_track, fx_index, "renamed_name", @ptrCast(&name_buf), name_buf.len)) {
        return;
    }
    const fx_name = std.mem.span(@as([*:0]const u8, @ptrCast(&name_buf)));

    var buf: [512:0]u8 = undefined;

    const suffix_start = std.mem.lastIndexOf(u8, fx_name, "(C1-").?;
    const suffix_end = std.mem.indexOfPos(u8, fx_name, suffix_start, ")").?;

    _ = std.fmt.bufPrintZ(&buf, "{s}(C1-", .{
        fx_name[0..suffix_start],
    }) catch return;

    var pos = suffix_start + 4;
    for (fx_name[suffix_start + 4 .. suffix_end]) |c| {
        if (pos >= buf.len - 1) break; // Ensure room for null terminator

        switch (module_to_remove) {
            .INPUT => if (c == 'I') continue,
            .GATE => if (c == 'S') continue,
            .EQ => if (c == 'E') continue,
            .COMP => if (c == 'C') continue,
            .OUTPT => if (c == 'O') continue,
        }
        buf[pos] = c;
        pos += 1;
    }

    _ = std.fmt.bufPrintZ(buf[pos..], "){s}", .{
        fx_name[suffix_end + 1 ..],
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
    parsed_fx: *std.ArrayListUnmanaged(ParsedFx),
    coverage: ModuleCoverage,
    mediaTrack: MediaTrack,
    buf: *[512:0]u8,
) void {
    // Reset current state
    track_state.fx_count = 0;
    for (std.enums.values(ModulesList)) |module| {
        track_state.module_locations.set(module, null);
    }

    // Update FX states and module locations
    var i: usize = 0;
    while (i < parsed_fx.items.len and i < MAX_FX) : (i += 1) {
        const fx = parsed_fx.items[i];
        if (fx.active_modules) |modules| {
            // Add to fx_states using positions from coverage
            track_state.fx_states[track_state.fx_count] = .{
                .fx_index = fx.index,
                .modules = modules,
            };

            // Update module locations using coverage positions
            inline for (std.meta.fields(@TypeOf(modules))) |field| {
                const is_active = @field(modules, field.name);
                if (is_active) {
                    const module = @field(ModulesList, field.name);
                    _ = reaper.TrackFX_GetNamedConfigParm(
                        mediaTrack,
                        fx.index,
                        "original_name",
                        @ptrCast(buf),
                        buf.len,
                    );
                    track_state.module_locations.set(module, .{
                        .fx_index = @field(coverage, field.name).?,
                        .mapping = globals.map_store.get(std.mem.span(@as([*:0]const u8, buf)), module),
                    });
                }
            }

            track_state.fx_count += 1;
        }
    }
}

fn reorderFx(cvrg: ModuleCoverage, mediaTrack: MediaTrack, default_fx: DefaultFx) ModuleCoverage {
    var coverage = cvrg;
    // 1. Handle INPUT
    if (coverage.INPUT) |INPUT| {
        var lowest_idx = INPUT;
        inline for (std.meta.fields(@TypeOf(coverage))) |field| {
            if (@field(coverage, field.name)) |field_idx| {
                lowest_idx = @min(lowest_idx, field_idx);
            }
        }
        if (lowest_idx < INPUT) {
            _ = pReaper.TrackFX_CopyToTrack(.{ mediaTrack, INPUT, mediaTrack, 1000 - lowest_idx, true });
            coverage.INPUT = lowest_idx;
        }
    } else {
        // Find the lowest position among module-linked FX
        const insert_pos = blk: {
            var min_pos: i32 = std.math.maxInt(i32);
            var found_any = false;
            inline for (std.meta.fields(@TypeOf(coverage))) |field| {
                if (@field(coverage, field.name)) |field_idx| {
                    min_pos = @min(min_pos, field_idx);
                    found_any = true;
                }
            }
            // Convert to TrackFX_AddByName position format (-1000 based)
            break :blk if (found_any) -1000 - min_pos else -1; // use -1 to add at end of chain.
        };

        _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.INPUT), false, insert_pos });
        // Convert back from -1000 based to actual position
        coverage.INPUT = -(insert_pos + 1000);

        // Shift other positions up
        inline for (std.meta.fields(@TypeOf(coverage))) |field| {
            if (!std.mem.eql(u8, field.name, "INPUT")) {
                if (@field(coverage, field.name)) |field_idx| {
                    @field(coverage, field.name) = field_idx + 1;
                }
            }
        }
    }

    // 2. Handle OUTPUT
    if (coverage.OUTPT) |OUTPT| {
        var highest_idx = OUTPT;
        inline for (std.meta.fields(@TypeOf(coverage))) |field| {
            if (@field(coverage, field.name)) |field_idx| {
                highest_idx = @max(highest_idx, field_idx);
            }
        }
        if (highest_idx > OUTPT) {
            _ = pReaper.TrackFX_CopyToTrack(.{ mediaTrack, OUTPT, mediaTrack, -1000 - highest_idx, true });
            coverage.OUTPT = highest_idx;
        }
    } else {
        // For OUTPUT not found, add at the end and update coverage
        const last_position = blk: {
            var max_pos: i32 = -1; // Default to end of chain
            var found_any = false;
            inline for (std.meta.fields(@TypeOf(coverage))) |field| {
                if (@field(coverage, field.name)) |field_idx| {
                    max_pos = @max(max_pos, field_idx);
                    found_any = true;
                }
            }
            // If we found module-linked FX, insert after the last one, else at chain end
            break :blk if (found_any) -1000 - (max_pos + 1) else -1;
        };

        _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.OUTPT), false, last_position });
        coverage.OUTPT = if (last_position != -1)
            -(last_position + 1000)
        else
            last_position;
    }

    // 3. Handle GATE and COMP
    if (coverage.GATE) |GATE| {
        if (coverage.COMP) |COMP| {
            // Both exist, ensure GATE is before COMP
            if (GATE > COMP) {
                _ = pReaper.TrackFX_CopyToTrack(.{ mediaTrack, GATE, mediaTrack, -1000 - COMP, true });
                coverage.GATE = COMP;
                coverage.COMP = COMP + 1;
            }
        } else {
            // Add COMP after GATE
            const insert_pos = -1000 - (GATE + 1);
            _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.COMP), false, insert_pos });
            coverage.COMP = GATE + 1;
        }
    } else {
        if (coverage.COMP) |COMP| {
            // Add GATE before COMP
            const insert_pos = -1000 - COMP;
            _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.GATE), false, insert_pos });
            coverage.GATE = COMP;
            coverage.COMP.? += 1;
        } else {
            if (coverage.EQ) |EQ| {
                // Add after EQ
                const insert_pos = -1000 - (EQ + 1);
                _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.GATE), false, insert_pos });
                _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.COMP), false, insert_pos - 1 });
                coverage.GATE = EQ + 1;
                coverage.COMP = EQ + 2;
            } else {
                // Add gate, eq, comp in sequence after INPUT
                const base_pos = coverage.INPUT.? + 1;
                _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.GATE), false, -1000 - base_pos });
                _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.EQ), false, -1000 - (base_pos + 1) });
                _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.COMP), false, -1000 - (base_pos + 2) });
                coverage.GATE = base_pos;
                coverage.EQ = base_pos + 1;
                coverage.COMP = base_pos + 2;
            }
        }
    }

    // 4. Handle missing EQ
    if (coverage.EQ == null) {
        const insert_pos = -1000 - coverage.OUTPT.?; // Insert before OUTPUT
        _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.EQ), false, insert_pos });
        coverage.EQ = coverage.OUTPT;
        coverage.OUTPT.? += 1;
    }
    return coverage;
}

const log = std.log.scoped(.validation);

pub fn reorderFx2(cvrg: ModuleCoverage, mediaTrack: MediaTrack, default_fx: DefaultFx) ModuleCoverage {
    var coverage = cvrg;

    // Handle INPUT first
    if (coverage.INPUT) |input_pos| {
        var lowest_idx = input_pos;
        inline for (std.meta.fields(ModuleCoverage)) |field| {
            if (@field(coverage, field.name)) |pos| {
                lowest_idx = @min(lowest_idx, pos);
            }
        }

        if (lowest_idx < input_pos) {
            const result = handleInsertWithConsolidation(mediaTrack, .INPUT, lowest_idx, default_fx, coverage);
            if (result.position) |pos| {
                coverage.INPUT = pos;
            } else {
                log.err("Failed to move INPUT FX to front position", .{});
            }
        }
    } else {
        // Find lowest position among module-linked FX
        const insert_pos = blk: {
            var min_pos: i32 = std.math.maxInt(i32);
            var found_any = false;
            inline for (std.meta.fields(ModuleCoverage)) |field| {
                if (@field(coverage, field.name)) |pos| {
                    min_pos = @min(min_pos, pos);
                    found_any = true;
                }
            }
            break :blk if (found_any) min_pos else -1;
        };

        const result = handleInsertWithConsolidation(mediaTrack, .INPUT, if (insert_pos == -1) 0 else insert_pos, default_fx, coverage);
        if (result.position) |pos| {
            coverage.INPUT = pos;
        } else {
            log.err("Failed to add INPUT FX", .{});
        }
    }

    // Handle GATE and COMP together due to their ordering dependency
    if (coverage.GATE) |gate_pos| {
        if (coverage.COMP) |comp_pos| {
            // Both exist, ensure GATE is before COMP
            if (gate_pos > comp_pos) {
                const result = handleInsertWithConsolidation(mediaTrack, .GATE, comp_pos, default_fx, coverage);
                if (result.position) |pos| {
                    coverage.GATE = pos;
                    if (!result.did_consolidate) {
                        coverage.COMP = pos + 1;
                    }
                } else {
                    log.err("Failed to move GATE FX before COMP", .{});
                }
            }
        } else {
            // Add COMP after GATE
            const result = handleInsertWithConsolidation(mediaTrack, .COMP, gate_pos + 1, default_fx, coverage);
            if (result.position) |pos| {
                coverage.COMP = pos;
            } else {
                log.err("Failed to add COMP FX after GATE", .{});
            }
        }
    } else if (coverage.COMP) |comp_pos| {
        // Add GATE before COMP
        const result = handleInsertWithConsolidation(mediaTrack, .GATE, comp_pos, default_fx, coverage);
        if (result.position) |pos| {
            coverage.GATE = pos;
            if (!result.did_consolidate) {
                coverage.COMP = pos + 1;
            }
        } else {
            log.err("Failed to add GATE FX before COMP", .{});
        }
    } else {
        // Neither exists, check EQ position or add after INPUT
        const insert_pos = if (coverage.EQ) |eq_pos|
            eq_pos + 1
        else if (coverage.INPUT) |input_pos|
            input_pos + 1
        else
            0;

        // Add GATE first
        const gate_result = handleInsertWithConsolidation(mediaTrack, .GATE, insert_pos, default_fx, coverage);
        if (gate_result.position) |gate_pos| {
            coverage.GATE = gate_pos;

            // Then add COMP
            const comp_result = handleInsertWithConsolidation(mediaTrack, .COMP, gate_pos + 1, default_fx, coverage);
            if (comp_result.position) |comp_pos| {
                coverage.COMP = comp_pos;
            } else {
                log.err("Failed to add COMP FX after newly added GATE", .{});
            }
        } else {
            log.err("Failed to add GATE FX", .{});
        }
    }

    // Handle EQ
    if (coverage.EQ == null) {
        const insert_pos = if (coverage.GATE) |gate_pos|
            gate_pos + 1
        else if (coverage.INPUT) |input_pos|
            input_pos + 1
        else
            0;

        const result = handleInsertWithConsolidation(mediaTrack, .EQ, insert_pos, default_fx, coverage);
        if (result.position) |pos| {
            coverage.EQ = pos;
        } else {
            log.err("Failed to add EQ FX", .{});
        }
    }

    // Handle OUTPUT last
    if (coverage.OUTPT) |output_pos| {
        var highest_idx = output_pos;
        inline for (std.meta.fields(ModuleCoverage)) |field| {
            if (@field(coverage, field.name)) |pos| {
                highest_idx = @max(highest_idx, pos);
            }
        }

        if (highest_idx > output_pos) {
            const result = handleInsertWithConsolidation(mediaTrack, .OUTPT, highest_idx, default_fx, coverage);
            if (result.position) |pos| {
                coverage.OUTPT = pos;
            } else {
                log.err("Failed to move OUTPUT FX to last position", .{});
            }
        }
    } else {
        const result = handleInsertWithConsolidation(mediaTrack, .OUTPT, if (coverage.INPUT == null) 0 else -1, // -1 for end of chain
            default_fx, coverage);
        if (result.position) |pos| {
            coverage.OUTPT = pos;
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

pub fn handleInsertWithConsolidation(
    mediaTrack: MediaTrack,
    module: ModulesList,
    insert_pos: i32,
    default_fx: DefaultFx,
    coverage: ModuleCoverage,
) ConsolidationResult {
    const fx_name: [:0]const u8 = default_fx.get(module) orelse return .{ .did_consolidate = false, .position = null };
    // Find preceding and following module-linked FX
    var prev_fx: ?i32 = null;
    var next_fx: ?i32 = null;
    var prev_name: ?[:0]const u8 = null;
    var next_name: ?[:0]const u8 = null;

    inline for (std.meta.fields(ModuleCoverage)) |field| {
        if (@field(coverage, field.name)) |pos| {
            if (pos == insert_pos - 1) {
                prev_fx = pos;
                var buf: [512:0]u8 = undefined;
                if (pReaper.TrackFX_GetNamedConfigParm(.{ mediaTrack, pos, "original_name", @as([*:0]u8, &buf), buf.len })) {
                    prev_name = std.mem.span(@as([*:0]const u8, &buf));
                }
            } else if (pos == insert_pos + 1) {
                next_fx = pos;
                var buf: [512:0]u8 = undefined;
                if (pReaper.TrackFX_GetNamedConfigParm(.{ mediaTrack, pos, "original_name", @as([*:0]u8, &buf), buf.len })) {
                    next_name = std.mem.span(@as([*:0]const u8, &buf));
                }
            }
        }
    }

    // Case 1: Can consolidate with both prev and next
    // Skip if INPUT (no preceding) or OUTPUT (no following)
    if (module != .INPUT and module != .OUTPT and
        prev_fx != null and next_fx != null and
        prev_name != null and next_name != null and
        std.mem.eql(u8, prev_name.?, fx_name) and
        std.mem.eql(u8, next_name.?, fx_name))
    {
        // Update prev FX suffix to include all three
        if (consolidateWithFxSuffix(mediaTrack, prev_fx.?, module)) {
            // Remove next FX as it's now consolidated
            _ = pReaper.TrackFX_Delete(.{ mediaTrack, next_fx.? });
            return .{ .did_consolidate = true, .position = prev_fx };
        }
    }

    // Case 2: Can consolidate with prev only
    // Skip if INPUT (no preceding)
    if (module != .INPUT and
        prev_fx != null and prev_name != null and
        std.mem.eql(u8, prev_name.?, fx_name))
    {
        if (consolidateWithFxSuffix(mediaTrack, prev_fx.?, module)) {
            return .{ .did_consolidate = true, .position = prev_fx };
        }
    }

    // Case 3: Can consolidate with next only
    // Skip if OUTPUT (no following)
    if (module != .OUTPT and
        next_fx != null and next_name != null and
        std.mem.eql(u8, next_name.?, fx_name))
    {
        if (consolidateWithFxSuffix(mediaTrack, next_fx.?, module)) {
            return .{ .did_consolidate = true, .position = next_fx };
        }
    }

    // Case 4: No consolidation possible, perform normal insertion
    const add_result = pReaper.TrackFX_AddByName(.{ mediaTrack, fx_name, false, if (insert_pos >= 0) -1000 - insert_pos else insert_pos });
    if (add_result >= 0) {
        const module_char = module.toModulePrefix();
        var name_buf: [512:0]u8 = undefined;
        const new_name = std.fmt.bufPrintZ(&name_buf, "{s} (C1-{s})", .{ fx_name, module_char }) catch return .{ .did_consolidate = false, .position = null };

        _ = pReaper.TrackFX_SetNamedConfigParm(.{ mediaTrack, add_result, "renamed_name", new_name });
        return .{ .did_consolidate = false, .position = insert_pos };
    }
    return .{ .did_consolidate = false, .position = null };
}

test "handleInsertWithConsolidation" {
    const testing = std.testing;

    const allocator = std.testing.allocator;

    // Save original functions and replace with mocks
    MockReaper.init(testing.allocator);
    defer MockReaper.deinit();

    const dummy_track: MediaTrack = @ptrFromInt(0xdeadbeef);
    const default_fx = DefaultFx.init(.{
        .INPUT = "Test FX",
        .GATE = "Test FX",
        .EQ = "Test FX",
        .COMP = "Different FX",
        .OUTPT = "Test FX",
    });

    // Test 1: Insert with no pre-existing FX
    {
        try MockReaper.reset(allocator);
        const result = handleInsertWithConsolidation(dummy_track, .EQ, 0, default_fx, .{});
        try testing.expectEqual(false, result.did_consolidate);
        try testing.expectEqual(@as(i32, 0), result.position.?);
    }

    // Test 2: Insert for consolidation with previous
    {
        try MockReaper.reset(allocator);
        try MockReaper.fx_chain.append(.{
            .original_name = "Test FX",
            .renamed_name = "Test FX (C1-E)",
        });

        const result = handleInsertWithConsolidation(dummy_track, .GATE, 1, default_fx, .{ .EQ = 0 });
        try testing.expectEqual(true, result.did_consolidate);
        try testing.expectEqual(@as(i32, 0), result.position.?);
        try testing.expectEqualStrings("Test FX (C1-SE)", MockReaper.fx_chain.items[0].renamed_name);
    }

    // Test 3: Insert between for consolidation
    {
        try MockReaper.reset(allocator);
        try MockReaper.fx_chain.append(.{
            .original_name = "Test FX",
            .renamed_name = "Test FX (C1-E)",
        });
        try MockReaper.fx_chain.append(.{
            .original_name = "Test FX",
            .renamed_name = "Test FX (C1-O)",
        });

        const result = handleInsertWithConsolidation(dummy_track, .GATE, 1, default_fx, .{
            .EQ = 0,
            .OUTPT = 1,
        });
        try testing.expectEqual(true, result.did_consolidate);
        try testing.expectEqual(@as(i32, 0), result.position.?);
        const chain = try MockReaper.getChainState();
        defer testing.allocator.free(chain);
        try testing.expectEqual(@as(usize, 1), chain.len);
        try testing.expectEqualStrings("Test FX (C1-SEO)", MockReaper.fx_chain.items[0].renamed_name);
    }

    // Test 4: Insert without consolidation
    {
        try MockReaper.reset(allocator);
        try MockReaper.fx_chain.append(.{
            .original_name = "Test FX",
            .renamed_name = "Test FX (C1-E)",
        });

        const result = handleInsertWithConsolidation(dummy_track, .COMP, 1, default_fx, .{ .EQ = 0 });
        try testing.expectEqual(false, result.did_consolidate);
        try testing.expectEqual(@as(i32, 1), result.position.?);
    }
}

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

pub fn consolidateWithFxSuffix(
    mediaTrack: MediaTrack,
    target_fx: i32,
    module: ModulesList,
) bool {
    var name_buf: [512:0]u8 = undefined;
    var buf: [512:0]u8 = undefined;
    var suffix_buf: [5:0]u8 = undefined;

    // Get current renamed name
    if (!pReaper.TrackFX_GetNamedConfigParm(.{ mediaTrack, target_fx, "renamed_name", @as([*:0]u8, &name_buf), name_buf.len })) {
        log.err("Failed to get renamed name for FX at position {}", .{target_fx});
        return false;
    }

    const current_name = std.mem.span(@as([*:0]const u8, &name_buf));

    // Parse current modules using existing function
    const current_modules = parseC1Suffix(current_name) orelse {
        log.err("Failed to parse C1 suffix from name {s}", .{current_name});
        return false;
    };

    // Find C1 suffix
    const suffix_start = std.mem.lastIndexOf(u8, current_name, "(C1-") orelse {
        log.err("No C1 suffix found in FX name {s}", .{current_name});
        return false;
    };

    const suffix_end = std.mem.indexOfPos(u8, current_name, suffix_start, ")") orelse {
        log.err("Malformed C1 suffix in FX name {s}", .{current_name});
        return false;
    };

    // Build ordered suffix
    const ordered_suffix = toOrderedSuffix(current_modules, module, &suffix_buf);

    // Build new name with ordered suffix
    const new_name = std.fmt.bufPrintZ(&buf, "{s}(C1-{s}){s}", .{
        current_name[0..suffix_start],
        ordered_suffix,
        current_name[suffix_end + 1 ..],
    }) catch |err| {
        log.err("Failed to build new name: {}", .{err});
        return false;
    };

    // Update FX name
    if (!pReaper.TrackFX_SetNamedConfigParm(.{ mediaTrack, target_fx, "renamed_name", new_name.ptr })) {
        log.err("Failed to set new name for FX at position {}", .{target_fx});
        return false;
    }

    return true;
}

test "consolidateWithFx" {
    const testing = std.testing;

    const allocator = testing.allocator;

    MockReaper.init(allocator);
    defer MockReaper.deinit();

    const dummy_track: MediaTrack = @ptrFromInt(0xdeadbeef);

    // Test 1: Add COMP to existing EQ
    {
        try MockReaper.reset(allocator);
        try MockReaper.fx_chain.append(.{
            .original_name = "Test FX",
            .renamed_name = "Test FX (C1-E)",
        });
        try testing.expect(consolidateWithFxSuffix(dummy_track, 0, .COMP));
        try testing.expect(std.mem.eql(u8, MockReaper.fx_chain.items[0].renamed_name, "Test FX (C1-EC)"));
    }

    // Test 2: Add INPUT to existing EQ
    {
        try MockReaper.reset(allocator);
        try MockReaper.fx_chain.append(.{
            .original_name = "Test FX",
            .renamed_name = "Test FX (C1-E)",
        });
        try testing.expect(consolidateWithFxSuffix(dummy_track, 0, .INPUT));
        try testing.expect(std.mem.eql(u8, MockReaper.fx_chain.items[0].renamed_name, "Test FX (C1-IE)"));
    }

    // Test 3: Add OUTPUT to existing EQ
    {
        try MockReaper.reset(allocator);
        try MockReaper.fx_chain.append(.{
            .original_name = "Test FX",
            .renamed_name = "Test FX (C1-E)",
        });
        try testing.expect(consolidateWithFxSuffix(dummy_track, 0, .OUTPT));
        try testing.expect(std.mem.eql(u8, MockReaper.fx_chain.items[0].renamed_name, "Test FX (C1-EO)"));
    }
}

pub fn setModulesOrder(self: *TrackState, order: ModulesOrder, mediaTrack: MediaTrack) void {
    // Early return if we don't have all three modules
    const eq_loc = self.module_locations.get(.EQ);
    const gate_loc = self.module_locations.get(.GATE);
    const comp_loc = self.module_locations.get(.COMP);

    if (eq_loc == null or gate_loc == null or comp_loc == null) return;

    var coverage = ModuleCoverage{
        .INPUT = if (self.module_locations.get(.INPUT)) |loc| loc.fx_index else null,
        .GATE = gate_loc.?.fx_index,
        .EQ = eq_loc.?.fx_index,
        .COMP = comp_loc.?.fx_index,
        .OUTPT = if (self.module_locations.get(.OUTPT)) |loc| loc.fx_index else null,
    };

    // Calculate target position for EQ based on desired order
    const eq_target_pos = switch (order) {
        .@"EQ-S-C" => gate_loc.?.fx_index, // EQ should go before GATE
        .@"S-C-EQ" => comp_loc.?.fx_index + 1, // EQ should go after COMP
        .@"S-EQ-C" => gate_loc.?.fx_index + 1, // EQ should go between GATE and COMP
    };

    // Only move if needed
    if (eq_loc.?.fx_index == eq_target_pos) return;

    _ = pReaper.TrackFX_CopyToTrack(.{
        mediaTrack,
        eq_loc.?.fx_index,
        mediaTrack,
        -1000 - eq_target_pos,
        true,
    });

    // Update coverage with new position
    coverage.EQ = eq_target_pos;

    // Adjust other positions if needed
    if (eq_target_pos < eq_loc.?.fx_index) {
        // Moving earlier in chain, shift others up
        if (coverage.GATE) |pos| {
            if (pos > eq_target_pos) {
                coverage.GATE = pos + 1;
            }
        }
        if (coverage.COMP) |pos| {
            if (pos > eq_target_pos) {
                coverage.COMP = pos + 1;
            }
        }
    } else {
        // Moving later in chain, shift others down
        if (coverage.GATE) |pos| {
            if (pos < eq_target_pos) {
                coverage.GATE = pos - 1;
            }
        }
        if (coverage.COMP) |pos| {
            if (pos < eq_target_pos) {
                coverage.COMP = pos - 1;
            }
        }
    }

    // Update module_locations with new positions
    inline for (comptime std.enums.values(ModulesList)) |module| {
        const pos = switch (module) {
            .INPUT => coverage.INPUT,
            .GATE => coverage.GATE,
            .EQ => coverage.EQ,
            .COMP => coverage.COMP,
            .OUTPT => coverage.OUTPT,
        };
        if (pos) |fx_index| {
            if (self.module_locations.get(module)) |loc| {
                self.module_locations.set(module, .{
                    .fx_index = fx_index,
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
