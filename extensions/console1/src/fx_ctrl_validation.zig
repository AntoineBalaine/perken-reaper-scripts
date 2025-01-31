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
const MAX_FX = 5;
const MAX_PARSED_FX = MAX_FX * 2; // Allow for reasonable number of duplicates

const ValidationErr = error{
    NoFx,
    DuplicateModule,
    FxAddFailed,
    GetNameFailed,
    RenameFailed,
    NoInputModule,
};

const ModuleLocation = std.EnumArray(ModulesList, ?struct {
    fx_index: c_int,
    mapping: ?TaggedMapping,
});

pub const TrackState = struct {
    // FX tracking for validation
    fx_states: [MAX_FX]struct {
        fx_index: i32,
        // Use bit mask for quick module presence check
        modules: ActiveModules = .{},
    } = undefined,
    fx_count: usize = 0,

    // Quick module -> FX lookup for parameter setting
    module_locations: ModuleLocation = undefined,
};
const ActiveModules = packed struct {
    INPUT: bool = false,
    GATE: bool = false,
    EQ: bool = false,
    COMP: bool = false,
    OUTPT: bool = false,
};

const ParsedFx = struct {
    index: i32,
    active_modules: ?ActiveModules = null,
};

pub fn validateTrack(track_state: *TrackState, mediaTrack: reaper.MediaTrack) !void {
    // Initialize track state
    track_state.* = .{ .fx_states = undefined, .fx_count = 0, .module_locations = ModuleLocation.initFill(null) };

    var buf: [512:0]u8 = undefined;

    // Get total FX count
    const fx_count = reaper.TrackFX_GetCount(mediaTrack);
    if (fx_count <= 0) return error.NoFx;

    // Scan FX chain
    // Use fixed-size array for parsed FX
    var parsed_fx_buf: [MAX_PARSED_FX]ParsedFx = undefined;
    var parsed_fx_count: usize = 0;

    var i: i32 = 0;
    while (i < fx_count) : (i += 1) {
        if (reaper.TrackFX_GetNamedConfigParm(mediaTrack, i, "renamed_name", &buf, buf.len)) {
            const renamed_name = std.mem.span(@as([*:0]const u8, &buf));
            if (renamed_name.len == 0) continue; // Skip if no rename

            if (parseC1Suffix(renamed_name)) |active_modules| {
                if (parsed_fx_count < MAX_PARSED_FX) {
                    parsed_fx_buf[parsed_fx_count] = .{
                        .index = i,
                        .active_modules = active_modules,
                    };
                    parsed_fx_count += 1;
                }
                // Silently ignore if we've reached capacity
            }
        }
    }

    var coverage = analyzeCoverage(parsed_fx_buf[0..parsed_fx_count], mediaTrack);
    coverage = reorderFx2(coverage, mediaTrack, globals.preferences.default_fx);
    updateTrackState(track_state, parsed_fx_buf[0..parsed_fx_count], coverage, mediaTrack, &buf);
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
const ModuleCoverage = struct {
    INPUT: ?c_int = null,
    GATE: ?c_int = null,
    EQ: ?c_int = null,
    COMP: ?c_int = null,
    OUTPT: ?c_int = null,
};

fn analyzeCoverage(
    parsed_fx: []const ParsedFx,
    media_track: MediaTrack,
) ModuleCoverage {
    var coverage = ModuleCoverage{};

    for (parsed_fx) |fx| {
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

fn removeDuplicateModule(
    fx_index: i32,
    module_to_remove: ModulesList,
    media_track: MediaTrack,
) void {
    var name_buf: [512]u8 = undefined;

    // Get current name
    if (!reaper.TrackFX_GetNamedConfigParm(media_track, fx_index, "renamed_name", @ptrCast(&name_buf), name_buf.len)) {
        return;
    }
    const fx_name = std.mem.span(@as([*:0]const u8, @ptrCast(&name_buf)));

    var buf: [512]u8 = undefined;

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

    const Mock = struct {
        var buffer: [512]u8 = undefined;
        var last_fx_name: ?[]const u8 = null;
        var current_test_name: [:0]const u8 = undefined;

        fn mockTrackFX_GetNamedConfigParm(
            track: reaper.MediaTrack,
            fx_index: c_int,
            parm_name: [*:0]const u8,
            parm_value: [*:0]u8,
            parm_value_sz: c_int,
        ) callconv(.C) bool {
            _ = fx_index; // autofix
            _ = track; // autofix
            if (std.mem.eql(u8, std.mem.span(parm_name), "renamed_name")) {
                const value = current_test_name;
                if (value.len >= parm_value_sz) return false;
                @memcpy(@as([*]u8, @ptrCast(parm_value))[0..value.len], value);
                @as([*]u8, @ptrCast(parm_value))[value.len] = 0;
                return true;
            }
            return false;
        }

        fn mockTrackFX_SetNamedConfigParm(
            track: reaper.MediaTrack,
            fx_index: c_int,
            parm_name: [*:0]const u8,
            parm_value: [*:0]const u8,
        ) callconv(.C) bool {
            _ = fx_index; // autofix
            _ = track; // autofix
            if (std.mem.eql(u8, std.mem.span(parm_name), "renamed_name")) {
                const value = std.mem.span(parm_value);
                @memcpy(buffer[0..value.len], value);
                last_fx_name = buffer[0..value.len];
            }
            return true;
        }

        fn reset() void {
            last_fx_name = null;
        }
    };

    // Save original functions and replace with mocks
    const real_get_fn = reaper.TrackFX_GetNamedConfigParm;
    const real_set_fn = reaper.TrackFX_SetNamedConfigParm;

    @constCast(&reaper.TrackFX_GetNamedConfigParm).* = @constCast(&Mock.mockTrackFX_GetNamedConfigParm);
    @constCast(&reaper.TrackFX_SetNamedConfigParm).* = @constCast(&Mock.mockTrackFX_SetNamedConfigParm);
    defer {
        @constCast(&reaper.TrackFX_GetNamedConfigParm).* = real_get_fn;
        @constCast(&reaper.TrackFX_SetNamedConfigParm).* = real_set_fn;
    }

    const dummy_track: MediaTrack = @ptrFromInt(0xdeadbeef);

    // Test 1: Remove INPUT module from a multi-module suffix
    {
        Mock.reset();
        Mock.current_test_name = "ReaComp (C1-IC)";
        removeDuplicateModule(0, .INPUT, dummy_track);
        try testing.expect(std.mem.eql(u8, Mock.last_fx_name.?, "ReaComp (C1-C)"));
    }

    // Test 2: Remove middle module
    {
        Mock.reset();
        Mock.current_test_name = "ReaEQ (C1-SEC)";
        removeDuplicateModule(1, .EQ, dummy_track);
        try testing.expect(std.mem.eql(u8, Mock.last_fx_name.?, "ReaEQ (C1-SC)"));
    }

    // Test 3: FX name with text after suffix
    {
        Mock.reset();
        Mock.current_test_name = "ReaComp (C1-IC) my settings";
        removeDuplicateModule(2, .INPUT, dummy_track);
        try testing.expect(std.mem.eql(u8, Mock.last_fx_name.?, "ReaComp (C1-C) my settings"));
    }

    // Test 4: Single module suffix
    {
        Mock.reset();
        Mock.current_test_name = "ReaComp (C1-C)";
        removeDuplicateModule(3, .COMP, dummy_track);
        try testing.expect(std.mem.eql(u8, Mock.last_fx_name.?, "ReaComp (C1-)"));
    }
}

test "analyzeCoverage" {
    const testing = std.testing;
    const dummy_track: MediaTrack = @ptrCast(@alignCast(@as(*anyopaque, @constCast(&[_]u8{0}))));

    // Test case 1: Valid coverage with no duplicates
    {
        const parsed_fx = [_]ParsedFx{
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

        const coverage = analyzeCoverage(&parsed_fx, dummy_track);
        try testing.expect(coverage.INPUT == 0);
        try testing.expect(coverage.GATE == 1);
    }

    // Test case 2: Duplicate module (should error)
    {
        const parsed_fx = [_]ParsedFx{
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

        const coverage = analyzeCoverage(&parsed_fx, dummy_track);
        try testing.expect(coverage.INPUT == 0);
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
    parsed_fx: []const ParsedFx,
    coverage: ModuleCoverage,
    mediaTrack: MediaTrack,
    buf: *[512]u8,
) void {
    // Reset current state
    track_state.fx_count = 0;
    for (std.enums.values(ModulesList)) |module| {
        track_state.module_locations.set(module, null);
    }

    // Update FX states and module locations
    for (parsed_fx) |fx| {
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
                        .mapping = globals.map_store.get(@ptrCast(buf), module),
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

fn reorderFx2(cvrg: ModuleCoverage, mediaTrack: MediaTrack, default_fx: DefaultFx) ModuleCoverage {
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

    const Mock = struct {
        var buffer: [512]u8 = undefined;
        var fx_at_positions: std.AutoHashMap(i32, [:0]const u8) = undefined;
        var last_deleted_fx: ?i32 = null;
        var fx_chain_changed = false;

        fn mockTrackFX_GetNamedConfigParm(
            track: MediaTrack,
            fx_index: c_int,
            parm_name: [*:0]const u8,
            parm_value: [*:0]u8,
            parm_value_sz: c_int,
        ) callconv(.C) bool {
            _ = track; // autofix
            if (std.mem.eql(u8, std.mem.span(parm_name), "original_name") or
                std.mem.eql(u8, std.mem.span(parm_name), "renamed_name"))
            {
                if (fx_at_positions.get(@intCast(fx_index))) |name| {
                    if (name.len >= parm_value_sz) return false;
                    @memcpy(@as([*]u8, @ptrCast(parm_value))[0..name.len], name);
                    @as([*]u8, @ptrCast(parm_value))[name.len] = 0;
                    return true;
                }
                return false;
            }
            return false;
        }

        fn mockTrackFX_SetNamedConfigParm(
            track: MediaTrack,
            fx_index: c_int,
            parm_name: [*:0]const u8,
            parm_value: [*:0]const u8,
        ) callconv(.C) bool {
            _ = track; // autofix
            if (std.mem.eql(u8, std.mem.span(parm_name), "renamed_name")) {
                const value = std.mem.span(parm_value);
                if (fx_at_positions.get(@intCast(fx_index))) |_| {
                    fx_at_positions.put(@intCast(fx_index), value) catch return false;
                    fx_chain_changed = true;
                }
            }
            return true;
        }

        fn mockTrackFX_Delete(
            track: MediaTrack,
            fx_index: c_int,
        ) callconv(.C) bool {
            _ = track; // autofix
            last_deleted_fx = fx_index;
            _ = fx_at_positions.remove(@intCast(fx_index));
            fx_chain_changed = true;
            return true;
        }

        fn mockTrackFX_AddByName(
            track: MediaTrack,
            fx_name: [*:0]const u8,
            recfx: bool,
            pos: c_int,
        ) callconv(.C) c_int {
            _ = recfx; // autofix
            _ = track; // autofix
            const insert_pos = if (pos < -999) -(pos + 1000) else pos;
            fx_at_positions.put(@intCast(insert_pos), std.mem.span(fx_name)) catch return -1;
            fx_chain_changed = true;
            return insert_pos;
        }

        fn mockTrackFX_CopyToTrack(
            track: MediaTrack,
            src_fx: c_int,
            dest_track: MediaTrack,
            dest_fx: c_int,
            delete: bool,
        ) callconv(.C) void {
            _ = dest_track; // autofix
            _ = track; // autofix
            const src_name = fx_at_positions.get(@intCast(src_fx)) orelse return;
            const dest_pos = if (dest_fx < -999) -(dest_fx + 1000) else dest_fx;

            fx_at_positions.put(@intCast(dest_pos), src_name) catch return;
            if (delete) {
                _ = fx_at_positions.remove(@intCast(src_fx));
            }
            fx_chain_changed = true;
        }

        fn reset(allocator: std.mem.Allocator) !void {
            last_deleted_fx = null;
            fx_chain_changed = false;
            fx_at_positions = std.AutoHashMap(i32, [:0]const u8).init(allocator);
        }

        fn deinit() void {
            fx_at_positions.deinit();
        }

        fn getChainState() ![]const [:0]const u8 {
            var state = std.ArrayList([:0]const u8).init(std.testing.allocator);
            defer state.deinit();

            var i: i32 = 0;
            while (i < 100) : (i += 1) { // reasonable upper limit
                if (fx_at_positions.get(i)) |name| {
                    try state.append(name);
                } else break;
            }
            return state.toOwnedSlice();
        }
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try Mock.reset(arena.allocator());

    // Setup mock functions
    const real_get_fn = reaper.TrackFX_GetNamedConfigParm;
    const real_set_fn = reaper.TrackFX_SetNamedConfigParm;
    const real_del_fn = reaper.TrackFX_Delete;
    const real_add_fn = reaper.TrackFX_AddByName;
    const real_copy_fn = reaper.TrackFX_CopyToTrack;
    @constCast(&reaper.TrackFX_GetNamedConfigParm).* = @constCast(&Mock.mockTrackFX_GetNamedConfigParm);
    @constCast(&reaper.TrackFX_SetNamedConfigParm).* = @constCast(&Mock.mockTrackFX_SetNamedConfigParm);
    @constCast(&reaper.TrackFX_Delete).* = @constCast(&Mock.mockTrackFX_Delete);
    @constCast(&reaper.TrackFX_AddByName).* = @constCast(&Mock.mockTrackFX_AddByName);
    @constCast(&reaper.TrackFX_CopyToTrack).* = @constCast(&Mock.mockTrackFX_CopyToTrack);
    defer {
        @constCast(&reaper.TrackFX_GetNamedConfigParm).* = real_get_fn;
        @constCast(&reaper.TrackFX_SetNamedConfigParm).* = real_set_fn;
        @constCast(&reaper.TrackFX_Delete).* = real_del_fn;
        @constCast(&reaper.TrackFX_AddByName).* = real_add_fn;
        @constCast(&reaper.TrackFX_CopyToTrack).* = real_copy_fn;
    }

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
        try Mock.reset(arena.allocator());
        var coverage = ModuleCoverage{};

        coverage = reorderFx2(coverage, dummy_track, default_fx);

        try testing.expect(coverage.INPUT != null);
        try testing.expect(coverage.GATE != null);
        try testing.expect(coverage.EQ != null);
        try testing.expect(coverage.COMP != null);
        try testing.expect(coverage.OUTPT != null);

        // Verify order
        const chain = try Mock.getChainState();
        defer std.testing.allocator.free(chain);

        try testing.expect(chain.len == 5);
        try testing.expect(std.mem.eql(u8, chain[0], "Standard Input (C1-I)"));
        try testing.expect(std.mem.eql(u8, chain[1], "Standard Gate (C1-S)"));
        try testing.expect(std.mem.eql(u8, chain[2], "Standard EQ (C1-E)"));
        try testing.expect(std.mem.eql(u8, chain[3], "Standard Comp (C1-C)"));
        try testing.expect(std.mem.eql(u8, chain[4], "Standard Output (C1-O)"));
    }

    // Test 2: Incorrect order needing fixes
    {
        try Mock.reset(arena.allocator());

        // Setup initial chain state
        try Mock.fx_at_positions.put(2, "Standard Input (C1-I)");
        try Mock.fx_at_positions.put(0, "Standard Comp (C1-C)");
        try Mock.fx_at_positions.put(3, "Standard Gate (C1-S)");
        try Mock.fx_at_positions.put(1, "Standard Output (C1-O)");
        try Mock.fx_at_positions.put(4, "Standard EQ (C1-E)");

        var coverage = ModuleCoverage{
            .INPUT = 2,
            .GATE = 3,
            .EQ = 4,
            .COMP = 0,
            .OUTPT = 1,
        };

        coverage = reorderFx2(coverage, dummy_track, default_fx);

        // Verify final order
        const chain = try Mock.getChainState();
        defer std.testing.allocator.free(chain);

        try testing.expect(chain.len == 5);
        try testing.expect(std.mem.eql(u8, chain[0], "Standard Input (C1-I)"));
        try testing.expect(std.mem.eql(u8, chain[1], "Standard Gate (C1-S)"));
        try testing.expect(std.mem.eql(u8, chain[2], "Standard EQ (C1-E)"));
        try testing.expect(std.mem.eql(u8, chain[3], "Standard Comp (C1-C)"));
        try testing.expect(std.mem.eql(u8, chain[4], "Standard Output (C1-O)"));
    }

    // Test 3: Correct order with some modules
    {
        try Mock.reset(arena.allocator());

        try Mock.fx_at_positions.put(0, "Standard Input (C1-I)");
        try Mock.fx_at_positions.put(1, "Standard EQ (C1-E)");
        try Mock.fx_at_positions.put(2, "Standard Output (C1-O)");

        var coverage = ModuleCoverage{
            .INPUT = 0,
            .EQ = 1,
            .OUTPT = 2,
        };

        coverage = reorderFx2(coverage, dummy_track, default_fx);

        const chain = try Mock.getChainState();
        defer std.testing.allocator.free(chain);

        try testing.expect(chain.len == 5); // Should add missing GATE and COMP
        try testing.expect(std.mem.eql(u8, chain[0], "Standard Input (C1-I)"));
        try testing.expect(std.mem.eql(u8, chain[1], "Standard Gate (C1-S)"));
        try testing.expect(std.mem.eql(u8, chain[2], "Standard EQ (C1-E)"));
        try testing.expect(std.mem.eql(u8, chain[3], "Standard Comp (C1-C)"));
        try testing.expect(std.mem.eql(u8, chain[4], "Standard Output (C1-O)"));
    }

    // Test 4: Missing middle modules
    {
        try Mock.reset(arena.allocator());

        try Mock.fx_at_positions.put(0, "Standard Input (C1-I)");
        try Mock.fx_at_positions.put(1, "Standard Output (C1-O)");

        var coverage = ModuleCoverage{
            .INPUT = 0,
            .OUTPT = 1,
        };

        coverage = reorderFx2(coverage, dummy_track, default_fx);

        const chain = try Mock.getChainState();
        defer std.testing.allocator.free(chain);

        try testing.expect(chain.len == 5);
        try testing.expect(std.mem.eql(u8, chain[0], "Standard Input (C1-I)"));
        try testing.expect(std.mem.eql(u8, chain[1], "Standard Gate (C1-S)"));
        try testing.expect(std.mem.eql(u8, chain[2], "Standard EQ (C1-E)"));
        try testing.expect(std.mem.eql(u8, chain[3], "Standard Comp (C1-C)"));
        try testing.expect(std.mem.eql(u8, chain[4], "Standard Output (C1-O)"));
    }

    // Test 5: Consolidation during reordering
    {
        try Mock.reset(arena.allocator());
        default_fx = DefaultFx.init(.{
            .INPUT = "Channel Strip",
            .GATE = "Channel Strip",
            .EQ = "Channel Strip",
            .COMP = "Channel Strip",
            .OUTPT = "Different Output",
        });

        try Mock.fx_at_positions.put(1, "Channel Strip (C1-I)");
        try Mock.fx_at_positions.put(0, "Channel Strip (C1-C)");

        var coverage = ModuleCoverage{
            .INPUT = 1,
            .COMP = 0,
        };

        coverage = reorderFx2(coverage, dummy_track, default_fx);

        const chain = try Mock.getChainState();
        defer std.testing.allocator.free(chain);

        // Should consolidate INPUT, GATE, EQ, COMP into one FX
        try testing.expect(chain.len == 2); // Consolidated FX + OUTPUT
        try testing.expect(std.mem.eql(u8, chain[0], "Channel Strip (C1-ISEC)"));
        try testing.expect(std.mem.eql(u8, chain[1], "Different Output (C1-O)"));
    }

    // Test 6: Partial chain with incorrect order
    {
        try Mock.reset(arena.allocator());

        // Setup initial incorrect order: COMP before GATE
        try Mock.fx_at_positions.put(1, "Standard Gate (C1-S)");
        try Mock.fx_at_positions.put(0, "Standard Comp (C1-C)");

        var coverage = ModuleCoverage{
            .GATE = 1,
            .COMP = 0,
        };

        coverage = reorderFx2(coverage, dummy_track, default_fx);

        const chain = try Mock.getChainState();
        defer std.testing.allocator.free(chain);

        try testing.expect(chain.len == 5);
        // Verify final order:
        // 1. INPUT should be added first
        // 2. GATE should be moved before COMP
        // 3. EQ should be added between GATE and COMP
        // 4. OUTPUT should be added last
        try testing.expect(std.mem.eql(u8, chain[0], "Standard Input (C1-I)"));
        try testing.expect(std.mem.eql(u8, chain[1], "Standard Gate (C1-S)"));
        try testing.expect(std.mem.eql(u8, chain[2], "Standard EQ (C1-E)"));
        try testing.expect(std.mem.eql(u8, chain[3], "Standard Comp (C1-C)"));
        try testing.expect(std.mem.eql(u8, chain[4], "Standard Output (C1-O)"));

        // Verify coverage was updated correctly
        try testing.expect(coverage.INPUT.? == 0);
        try testing.expect(coverage.GATE.? == 1);
        try testing.expect(coverage.EQ.? == 2);
        try testing.expect(coverage.COMP.? == 3);
        try testing.expect(coverage.OUTPT.? == 4);
    }

    // Test 7: Edge case with single FX handling multiple modules
    {
        try Mock.reset(arena.allocator());

        // Setup initial state: one FX handling both INPUT and EQ
        try Mock.fx_at_positions.put(0, "Standard Input (C1-IE)");

        var coverage = ModuleCoverage{
            .INPUT = 0,
            .EQ = 0,
        };

        coverage = reorderFx2(coverage, dummy_track, default_fx);

        const chain = try Mock.getChainState();
        defer std.testing.allocator.free(chain);

        // Should split the consolidated FX and add missing modules in correct order
        try testing.expect(chain.len == 5);
        try testing.expect(std.mem.eql(u8, chain[0], "Standard Input (C1-I)"));
        try testing.expect(std.mem.eql(u8, chain[1], "Standard Gate (C1-S)"));
        try testing.expect(std.mem.eql(u8, chain[2], "Standard EQ (C1-E)"));
        try testing.expect(std.mem.eql(u8, chain[3], "Standard Comp (C1-C)"));
        try testing.expect(std.mem.eql(u8, chain[4], "Standard Output (C1-O)"));

        // Verify coverage reflects the split and new positions
        try testing.expect(coverage.INPUT.? == 0);
        try testing.expect(coverage.GATE.? == 1);
        try testing.expect(coverage.EQ.? == 2);
        try testing.expect(coverage.COMP.? == 3);
        try testing.expect(coverage.OUTPT.? == 4);
    }

    // Test 8: Case where default FX for adjacent modules are the same
    {
        try Mock.reset(arena.allocator());

        // Setup where GATE and COMP will use the same default FX
        default_fx = DefaultFx.init(.{
            .INPUT = "Standard Input",
            .GATE = "Dynamics Processor", // Same FX for GATE and COMP
            .EQ = "Standard EQ",
            .COMP = "Dynamics Processor", // Same FX for GATE and COMP
            .OUTPT = "Standard Output",
        });

        // Start with just INPUT and EQ
        try Mock.fx_at_positions.put(0, "Standard Input (C1-I)");
        try Mock.fx_at_positions.put(1, "Standard EQ (C1-E)");

        var coverage = ModuleCoverage{
            .INPUT = 0,
            .EQ = 1,
        };

        coverage = reorderFx2(coverage, dummy_track, default_fx);

        const chain = try Mock.getChainState();
        defer std.testing.allocator.free(chain);

        // Should add GATE and COMP as one consolidated FX
        try testing.expect(chain.len == 4); // INPUT, GATE+COMP(consolidated), EQ, OUTPUT
        try testing.expect(std.mem.eql(u8, chain[0], "Standard Input (C1-I)"));
        try testing.expect(std.mem.eql(u8, chain[1], "Dynamics Processor (C1-SC)")); // Consolidated
        try testing.expect(std.mem.eql(u8, chain[2], "Standard EQ (C1-E)"));
        try testing.expect(std.mem.eql(u8, chain[3], "Standard Output (C1-O)"));

        // Verify coverage reflects consolidated positions
        try testing.expect(coverage.INPUT.? == 0);
        try testing.expect(coverage.GATE.? == 1); // Both GATE and COMP
        try testing.expect(coverage.COMP.? == 1); // point to same position
        try testing.expect(coverage.EQ.? == 2);
        try testing.expect(coverage.OUTPT.? == 3);

        // Verify the consolidation was tracked
        try testing.expect(Mock.fx_chain_changed);
    }
}
const ConsolidationResult = struct {
    did_consolidate: bool,
    position: ?i32,
};

fn handleInsertWithConsolidation(
    mediaTrack: MediaTrack,
    module: ModulesList,
    insert_pos: i32,
    default_fx: DefaultFx,
    coverage: ModuleCoverage,
) ConsolidationResult {
    const fx_name = default_fx.get(module);

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
    const add_result = pReaper.TrackFX_AddByName(.{ mediaTrack, fx_name, false, -1000 - insert_pos });
    return .{
        .did_consolidate = false,
        .position = if (add_result >= 0) insert_pos else null,
    };
}

test "handleInsertWithConsolidation" {
    const testing = std.testing;

    const Mock = struct {
        var buffer: [512]u8 = undefined;
        var last_renamed_name: ?[]const u8 = null;
        var current_fx_name: [:0]const u8 = undefined;
        var fx_at_positions: std.AutoHashMap(i32, [:0]const u8) = undefined;
        var last_deleted_fx: ?i32 = null;

        fn mockTrackFX_GetNamedConfigParm(
            track: reaper.MediaTrack,
            fx_index: c_int,
            parm_name: [*:0]const u8,
            parm_value: [*:0]u8,
            parm_value_sz: c_int,
        ) callconv(.C) bool {
            _ = track; // autofix
            if (std.mem.eql(u8, std.mem.span(parm_name), "original_name")) {
                if (fx_at_positions.get(@intCast(fx_index))) |name| {
                    if (name.len >= parm_value_sz) return false;
                    @memcpy(@as([*]u8, @ptrCast(parm_value))[0..name.len], name);
                    @as([*]u8, @ptrCast(parm_value))[name.len] = 0;
                    return true;
                }
                return false;
            }
            if (std.mem.eql(u8, std.mem.span(parm_name), "renamed_name")) {
                if (fx_at_positions.get(@intCast(fx_index))) |name| {
                    if (name.len >= parm_value_sz) return false;
                    @memcpy(@as([*]u8, @ptrCast(parm_value))[0..name.len], name);
                    @as([*]u8, @ptrCast(parm_value))[name.len] = 0;
                    return true;
                }
                return false;
            }
            return false;
        }

        fn mockTrackFX_SetNamedConfigParm(
            track: reaper.MediaTrack,
            fx_index: c_int,
            parm_name: [*:0]const u8,
            parm_value: [*:0]const u8,
        ) callconv(.C) bool {
            _ = fx_index; // autofix
            _ = track; // autofix
            if (std.mem.eql(u8, std.mem.span(parm_name), "renamed_name")) {
                const value = std.mem.span(parm_value);
                @memcpy(buffer[0..value.len], value);
                last_renamed_name = buffer[0..value.len];
            }
            return true;
        }

        fn mockTrackFX_Delete(
            track: reaper.MediaTrack,
            fx_index: c_int,
        ) callconv(.C) bool {
            _ = track; // autofix
            last_deleted_fx = fx_index;
            _ = fx_at_positions.remove(@intCast(fx_index));
            return true;
        }

        fn mockTrackFX_AddByName(
            track: reaper.MediaTrack,
            fx_name: [*:0]const u8,
            recfx: bool,
            pos: c_int,
        ) callconv(.C) c_int {
            _ = recfx; // autofix
            _ = track; // autofix
            const insert_pos = if (pos < -999) -(pos + 1000) else pos;
            fx_at_positions.put(@intCast(insert_pos), std.mem.span(fx_name)) catch return -1;
            return insert_pos;
        }

        fn reset(allocator: std.mem.Allocator) !void {
            last_renamed_name = null;
            last_deleted_fx = null;
            fx_at_positions = std.AutoHashMap(i32, [:0]const u8).init(allocator);
        }

        fn deinit() void {
            fx_at_positions.deinit();
        }
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try Mock.reset(arena.allocator());

    // Save original functions and replace with mocks
    const real_get_fn = reaper.TrackFX_GetNamedConfigParm;
    const real_set_fn = reaper.TrackFX_SetNamedConfigParm;
    const real_del_fn = reaper.TrackFX_Delete;
    const real_add_fn = reaper.TrackFX_AddByName;
    @constCast(&reaper.TrackFX_GetNamedConfigParm).* = @constCast(&Mock.mockTrackFX_GetNamedConfigParm);
    @constCast(&reaper.TrackFX_SetNamedConfigParm).* = @constCast(&Mock.mockTrackFX_SetNamedConfigParm);
    @constCast(&reaper.TrackFX_Delete).* = @constCast(&Mock.mockTrackFX_Delete);
    @constCast(&reaper.TrackFX_AddByName).* = @constCast(&Mock.mockTrackFX_AddByName);
    defer {
        @constCast(&reaper.TrackFX_GetNamedConfigParm).* = real_get_fn;
        @constCast(&reaper.TrackFX_SetNamedConfigParm).* = real_set_fn;
        @constCast(&reaper.TrackFX_Delete).* = real_del_fn;
        @constCast(&reaper.TrackFX_AddByName).* = real_add_fn;
    }

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
        try Mock.reset(arena.allocator());
        const result = handleInsertWithConsolidation(dummy_track, .EQ, 0, default_fx, .{});
        try testing.expect(!result.did_consolidate);
        try testing.expect(result.position.? == 0);
    }

    // Test 2: Insert for consolidation with previous
    {
        try Mock.reset(arena.allocator());
        try Mock.fx_at_positions.put(0, "Test FX (C1-E)");

        const result = handleInsertWithConsolidation(dummy_track, .GATE, 1, default_fx, .{ .EQ = 0 });
        try testing.expect(result.did_consolidate);
        try testing.expect(result.position.? == 0);
        try testing.expect(std.mem.eql(u8, Mock.last_renamed_name.?, "Test FX (C1-ES)"));
    }

    // Test 3: Insert between for consolidation
    {
        try Mock.reset(arena.allocator());
        try Mock.fx_at_positions.put(0, "Test FX (C1-E)");
        try Mock.fx_at_positions.put(2, "Test FX (C1-O)");

        const result = handleInsertWithConsolidation(dummy_track, .GATE, 1, default_fx, .{
            .EQ = 0,
            .OUTPT = 2,
        });
        try testing.expect(result.did_consolidate);
        try testing.expect(result.position.? == 0);
        try testing.expect(Mock.last_deleted_fx.? == 2);
        try testing.expect(std.mem.eql(u8, Mock.last_renamed_name.?, "Test FX (C1-ESO)"));
    }

    // Test 4: Insert without consolidation
    {
        try Mock.reset(arena.allocator());
        try Mock.fx_at_positions.put(0, "Test FX (C1-E)");

        const result = handleInsertWithConsolidation(dummy_track, .COMP, 1, default_fx, .{ .EQ = 0 });
        try testing.expect(!result.did_consolidate);
        try testing.expect(result.position.? == 1);
    }
}

fn consolidateWithFxSuffix(
    mediaTrack: MediaTrack,
    target_fx: i32,
    module: ModulesList,
) bool {
    var buf: [512:0]u8 = undefined;

    // Get current renamed name
    if (!pReaper.TrackFX_GetNamedConfigParm(.{ mediaTrack, target_fx, "renamed_name", @as([*:0]u8, @constCast(&buf)), buf.len })) {
        log.err("Failed to get renamed name for FX at position {}", .{target_fx});
        return false;
    }

    const current_name = std.mem.span(@as([*:0]const u8, &buf));

    // Find C1 suffix
    const suffix_start = std.mem.lastIndexOf(u8, current_name, "(C1-") orelse {
        log.err("No C1 suffix found in FX name {s}", .{current_name});
        return false;
    };

    const suffix_end = std.mem.indexOfPos(u8, current_name, suffix_start, ")") orelse {
        log.err("Malformed C1 suffix in FX name {s}", .{current_name});
        return false;
    };

    // Add new module to suffix
    const module_char = switch (module) {
        .INPUT => "I",
        .GATE => "S",
        .EQ => "E",
        .COMP => "C",
        .OUTPT => "O",
    };

    // Build new name with updated suffix
    const new_name = std.fmt.bufPrintZ(&buf, "{s}(C1-{s}{s}){s}", .{
        current_name[0..suffix_start],
        current_name[suffix_start + 4 .. suffix_end],
        module_char,
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

    const Mock = struct {
        var buffer: [512]u8 = undefined;
        var last_renamed_name: ?[]const u8 = null;

        fn mockTrackFX_GetNamedConfigParm(
            track: reaper.MediaTrack,
            fx_index: c_int,
            parm_name: [*:0]const u8,
            parm_value: [*:0]u8,
            parm_value_sz: c_int,
        ) callconv(.C) bool {
            _ = fx_index; // autofix
            _ = track; // autofix
            if (std.mem.eql(u8, std.mem.span(parm_name), "renamed_name")) {
                const test_name = "Test FX (C1-EC)";
                if (test_name.len >= parm_value_sz) return false;
                @memcpy(@as([*]u8, @ptrCast(parm_value))[0..test_name.len], test_name);
                @as([*]u8, @ptrCast(parm_value))[test_name.len] = 0;
                return true;
            }
            return false;
        }

        fn mockTrackFX_SetNamedConfigParm(
            track: reaper.MediaTrack,
            fx_index: c_int,
            parm_name: [*:0]const u8,
            parm_value: [*:0]const u8,
        ) callconv(.C) bool {
            _ = fx_index; // autofix
            _ = track; // autofix
            if (std.mem.eql(u8, std.mem.span(parm_name), "renamed_name")) {
                const value = std.mem.span(parm_value);
                @memcpy(buffer[0..value.len], value);
                last_renamed_name = buffer[0..value.len];
                return true;
            }
            return true;
        }

        fn reset() void {
            last_renamed_name = null;
        }
    };

    // Save original functions and replace with mocks
    const real_get_fn = reaper.TrackFX_GetNamedConfigParm;
    const real_set_fn = reaper.TrackFX_SetNamedConfigParm;

    @constCast(&reaper.TrackFX_GetNamedConfigParm).* = @constCast(&Mock.mockTrackFX_GetNamedConfigParm);
    @constCast(&reaper.TrackFX_SetNamedConfigParm).* = @constCast(&Mock.mockTrackFX_SetNamedConfigParm);
    defer {
        @constCast(&reaper.TrackFX_GetNamedConfigParm).* = real_get_fn;
        @constCast(&reaper.TrackFX_SetNamedConfigParm).* = real_set_fn;
    }

    const dummy_track: MediaTrack = @ptrFromInt(0xdeadbeef);

    // Test 1: Add COMP to existing EQ
    {
        Mock.last_renamed_name = null;
        try testing.expect(consolidateWithFxSuffix(dummy_track, 0, .COMP));
        try testing.expect(std.mem.eql(u8, Mock.last_renamed_name.?, "Test FX (C1-EC)"));
    }

    // Test 2: Add INPUT to existing EQ
    {
        Mock.last_renamed_name = null;
        try testing.expect(consolidateWithFxSuffix(dummy_track, 0, .INPUT));
        try testing.expect(std.mem.eql(u8, Mock.last_renamed_name.?, "Test FX (C1-IEC)"));
    }

    // Test 3: Add OUTPUT to existing EQ
    {
        Mock.last_renamed_name = null;
        try testing.expect(consolidateWithFxSuffix(dummy_track, 0, .OUTPT));
        try testing.expect(std.mem.eql(u8, Mock.last_renamed_name.?, "Test FX (C1-ECO)"));
    }
}
