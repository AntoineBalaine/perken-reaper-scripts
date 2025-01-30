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

    var coverage = try analyzeCoverage(parsed_fx_buf[0..parsed_fx_count], mediaTrack);
    try reorderFx(&coverage, mediaTrack, globals.preferences.default_fx);

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

const ModuleCoverage = struct {
    // Which modules are covered
    covered: ActiveModules = .{},

    // Track which FX provides each module
    providers: struct {
        INPUT: ?c_int = null,
        GATE: ?c_int = null,
        EQ: ?c_int = null,
        COMP: ?c_int = null,
        OUTPT: ?c_int = null,
    } = .{},
};

fn analyzeCoverage(
    parsed_fx: []const ParsedFx,
    media_track: MediaTrack,
) !ModuleCoverage {
    var coverage = ModuleCoverage{};

    for (parsed_fx) |fx| {
        if (fx.active_modules) |modules| {
            // For each active module in this FX
            inline for (std.meta.fields(@TypeOf(modules))) |field| {
                const is_active = @field(modules, field.name);
                if (is_active) {
                    // Check if module already covered
                    if (@field(coverage.covered, field.name)) {
                        const module = @field(ModulesList, field.name);
                        removeDuplicateModule(fx.index, module, media_track);
                    } else {
                        // Mark as covered and record provider
                        @field(coverage.covered, field.name) = true;
                        @field(coverage.providers, field.name) = fx.index;
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

/// test-related
var mock_buffer: [512]u8 = undefined;
/// test-related
var last_fx_name: ?[]const u8 = null;
/// test-related
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
        @memcpy(mock_buffer[0..value.len], value);
        last_fx_name = mock_buffer[0..value.len];
    }
    return true;
}

test "removeDuplicateModule" {
    const testing = std.testing;

    // Save original functions and replace with mocks
    const real_get_fn = reaper.TrackFX_GetNamedConfigParm;
    const real_set_fn = reaper.TrackFX_SetNamedConfigParm;
    @constCast(&reaper.TrackFX_GetNamedConfigParm).* = @constCast(&mockTrackFX_GetNamedConfigParm);
    @constCast(&reaper.TrackFX_SetNamedConfigParm).* = @constCast(&mockTrackFX_SetNamedConfigParm);
    defer {
        @constCast(&reaper.TrackFX_GetNamedConfigParm).* = real_get_fn;
        @constCast(&reaper.TrackFX_SetNamedConfigParm).* = real_set_fn;
    }

    const dummy_track: MediaTrack = @ptrFromInt(0xdeadbeef);

    // Test 1: Remove INPUT module from a multi-module suffix
    {
        current_test_name = "ReaComp (C1-IC)";
        removeDuplicateModule(0, .INPUT, dummy_track);
        try testing.expect(std.mem.eql(u8, last_fx_name.?, "ReaComp (C1-C)"));
    }

    // Test 2: Remove middle module
    {
        current_test_name = "ReaEQ (C1-SEC)";
        removeDuplicateModule(1, .EQ, dummy_track);
        try testing.expect(std.mem.eql(u8, last_fx_name.?, "ReaEQ (C1-SC)"));
    }

    // Test 3: FX name with text after suffix
    {
        current_test_name = "ReaComp (C1-IC) my settings";
        removeDuplicateModule(2, .INPUT, dummy_track);
        try testing.expect(std.mem.eql(u8, last_fx_name.?, "ReaComp (C1-C) my settings"));
    }

    // Test 4: Single module suffix
    {
        current_test_name = "ReaComp (C1-C)";
        removeDuplicateModule(3, .COMP, dummy_track);
        try testing.expect(std.mem.eql(u8, last_fx_name.?, "ReaComp (C1-)"));
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

        const coverage = try analyzeCoverage(&parsed_fx, dummy_track);
        try testing.expect(coverage.covered.INPUT == true);
        try testing.expect(coverage.covered.GATE == true);
        try testing.expect(coverage.covered.EQ == false);
        try testing.expect(coverage.providers.INPUT == 0);
        try testing.expect(coverage.providers.GATE == 1);
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

        try testing.expectError(error.DuplicateModule, analyzeCoverage(&parsed_fx, dummy_track));
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
                        .fx_index = @field(coverage.providers, field.name).?,
                        .mapping = globals.map_store.get(@ptrCast(buf), module),
                    });
                }
            }

            track_state.fx_count += 1;
        }
    }
}

fn reorderFx(
    coverage: *ModuleCoverage,
    mediaTrack: MediaTrack,
    default_fx: DefaultFx,
) !void {
    // 1. Handle INPUT
    if (coverage.providers.INPUT) |INPUT| {
        var lowest_idx = INPUT;
        inline for (std.meta.fields(@TypeOf(coverage.providers))) |field| {
            if (@field(coverage.providers, field.name)) |field_idx| {
                lowest_idx = @min(lowest_idx, field_idx);
            }
        }
        if (lowest_idx < INPUT) {
            _ = pReaper.TrackFX_CopyToTrack(.{ mediaTrack, INPUT, mediaTrack, 1000 - lowest_idx, true });
            coverage.providers.INPUT = lowest_idx;
        }
    } else {
        // Find the lowest position among module-linked FX
        const insert_pos = blk: {
            var min_pos: i32 = std.math.maxInt(i32);
            var found_any = false;
            inline for (std.meta.fields(@TypeOf(coverage.providers))) |field| {
                if (@field(coverage.providers, field.name)) |field_idx| {
                    min_pos = @min(min_pos, field_idx);
                    found_any = true;
                }
            }
            // Convert to TrackFX_AddByName position format (-1000 based)
            break :blk if (found_any) -1000 - min_pos else -1; // use -1 to add at end of chain.
        };

        _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.INPUT), false, insert_pos });
        coverage.covered.INPUT = true;
        // Convert back from -1000 based to actual position
        coverage.providers.INPUT = -(insert_pos + 1000);

        // Shift other positions up
        inline for (std.meta.fields(@TypeOf(coverage.providers))) |field| {
            if (!std.mem.eql(u8, field.name, "INPUT")) {
                if (@field(coverage.providers, field.name)) |field_idx| {
                    @field(coverage.providers, field.name) = field_idx + 1;
                }
            }
        }
    }

    // 2. Handle OUTPUT
    if (coverage.providers.OUTPT) |OUTPT| {
        var highest_idx = OUTPT;
        inline for (std.meta.fields(@TypeOf(coverage.providers))) |field| {
            if (@field(coverage.providers, field.name)) |field_idx| {
                highest_idx = @max(highest_idx, field_idx);
            }
        }
        if (highest_idx > OUTPT) {
            _ = pReaper.TrackFX_CopyToTrack(.{ mediaTrack, OUTPT, mediaTrack, -1000 - highest_idx, true });
            coverage.providers.OUTPT = highest_idx;
        }
    } else {
        // For OUTPUT not found, add at the end and update coverage
        const last_position = blk: {
            var max_pos: i32 = -1; // Default to end of chain
            var found_any = false;
            inline for (std.meta.fields(@TypeOf(coverage.providers))) |field| {
                if (@field(coverage.providers, field.name)) |field_idx| {
                    max_pos = @max(max_pos, field_idx);
                    found_any = true;
                }
            }
            // If we found module-linked FX, insert after the last one, else at chain end
            break :blk if (found_any) -1000 - (max_pos + 1) else -1;
        };

        _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.OUTPT), false, last_position });
        coverage.covered.OUTPT = true;
        coverage.providers.OUTPT = if (last_position != -1)
            -(last_position + 1000)
        else
            last_position;
    }

    // 3. Handle GATE and COMP
    if (coverage.providers.GATE) |GATE| {
        if (coverage.providers.COMP) |COMP| {
            // Both exist, ensure GATE is before COMP
            if (GATE > COMP) {
                _ = pReaper.TrackFX_CopyToTrack(.{ mediaTrack, GATE, mediaTrack, -1000 - COMP, true });
                coverage.providers.GATE = COMP;
                coverage.providers.COMP = COMP + 1;
            }
        } else {
            // Add COMP after GATE
            const insert_pos = -1000 - (GATE + 1);
            _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.COMP), false, insert_pos });
            coverage.covered.COMP = true;
            coverage.providers.COMP = GATE + 1;
        }
    } else {
        if (coverage.providers.COMP) |COMP| {
            // Add GATE before COMP
            const insert_pos = -1000 - COMP;
            _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.GATE), false, insert_pos });
            coverage.covered.GATE = true;
            coverage.providers.GATE = COMP;
            coverage.providers.COMP.? += 1;
        } else {
            if (coverage.providers.EQ) |EQ| {
                // Add after EQ
                const insert_pos = -1000 - (EQ + 1);
                _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.GATE), false, insert_pos });
                _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.COMP), false, insert_pos - 1 });
                coverage.covered.GATE = true;
                coverage.covered.COMP = true;
                coverage.providers.GATE = EQ + 1;
                coverage.providers.COMP = EQ + 2;
            } else {
                // Add gate, eq, comp in sequence after INPUT
                const base_pos = coverage.providers.INPUT.? + 1;
                _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.GATE), false, -1000 - base_pos });
                _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.EQ), false, -1000 - (base_pos + 1) });
                _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.COMP), false, -1000 - (base_pos + 2) });
                coverage.covered.GATE = true;
                coverage.covered.EQ = true;
                coverage.covered.COMP = true;
                coverage.providers.GATE = base_pos;
                coverage.providers.EQ = base_pos + 1;
                coverage.providers.COMP = base_pos + 2;
            }
        }
    }

    // 4. Handle missing EQ
    if (coverage.providers.EQ == null) {
        const insert_pos = -1000 - coverage.providers.OUTPT.?; // Insert before OUTPUT
        _ = pReaper.TrackFX_AddByName(.{ mediaTrack, default_fx.get(.EQ), false, insert_pos });
        coverage.covered.EQ = true;
        coverage.providers.EQ = coverage.providers.OUTPT;
        coverage.providers.OUTPT.? += 1;
    }
}
