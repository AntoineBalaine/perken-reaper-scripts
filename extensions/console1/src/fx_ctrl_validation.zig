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
const MAX_FX = 5;

const ValidationErr = error{
    NoFx,
    DuplicateModule,
    FxAddFailed,
    GetNameFailed,
    RenameFailed,
    NoInputModule,
};

pub const TrackState = struct {
    // FX tracking for validation
    fx_states: [MAX_FX]struct {
        fx_index: i32,
        // Use bit mask for quick module presence check
        modules: ActiveModules = .{},
    } = undefined,
    fx_count: usize = 0,

    // Quick module -> FX lookup for parameter setting
    module_locations: std.EnumArray(ModulesList, ?struct {
        fx_index: i32,
        mapping: union(ModulesList) {
            INPUT: Inpt,
            GATE: Shp,
            EQ: Eq,
            COMP: Comp,
            OUTPT: Outpt,
        },
    }) = undefined,
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
    original_name: [:0]const u8,
    renamed_name: [:0]const u8,
    active_modules: ?ActiveModules = null,
};

pub fn validateTrack(track_state: *TrackState, mediaTrack: reaper.MediaTrack, allocator: std.mem.Allocator) !void {
    var buf: [512:0]u8 = undefined;

    // Get total FX count
    const fx_count = reaper.TrackFX_GetCount(mediaTrack);
    if (fx_count <= 0) return error.NoFx;

    // Scan FX chain
    var parsed_fx = std.ArrayList(ParsedFx).init(allocator);
    defer parsed_fx.deinit();

    var i: i32 = 0;
    while (i < fx_count) : (i += 1) {
        // Get original name
        if (!reaper.TrackFX_GetFXName(mediaTrack, i, &buf, buf.len)) {
            continue; // Skip if can't get name
        }
        const original_name = std.mem.span(@as([*:0]const u8, &buf));

        // Get renamed name (if any)
        const renamed_name: [:0]const u8 = if (reaper.TrackFX_GetNamedConfigParm(mediaTrack, i, "renamed_name", &buf, buf.len))
            std.mem.span(@as([*:0]const u8, &buf))
        else
            original_name;

        // Parse for C1 modules
        const active_modules = parseC1Suffix(renamed_name);

        try parsed_fx.append(.{
            .index = i,
            .original_name = try allocator.dupeZ(u8, original_name),
            .renamed_name = try allocator.dupeZ(u8, renamed_name),
            .active_modules = active_modules,
        });
    }

    const coverage = try analyzeCoverage(parsed_fx.items);
    try addMissingModules(&parsed_fx, coverage, mediaTrack, allocator);

    try reorderFx(parsed_fx.items, mediaTrack, allocator);

    updateTrackState(track_state, parsed_fx.items);
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
        INPUT: ?i32 = null,
        GATE: ?i32 = null,
        EQ: ?i32 = null,
        COMP: ?i32 = null,
        OUTPT: ?i32 = null,
    } = .{},
};

fn analyzeCoverage(parsed_fx: []const ParsedFx) !ModuleCoverage {
    var coverage = ModuleCoverage{};

    for (parsed_fx) |fx| {
        if (fx.active_modules) |modules| {
            // For each active module in this FX
            inline for (std.meta.fields(@TypeOf(modules))) |field| {
                const is_active = @field(modules, field.name);
                if (is_active) {
                    // Check if module already covered
                    if (@field(coverage.covered, field.name)) {
                        return error.DuplicateModule;
                    }

                    // Mark as covered and record provider
                    @field(coverage.covered, field.name) = true;
                    @field(coverage.providers, field.name) = fx.index;
                }
            }
        }
    }

    return coverage;
}

fn removeDuplicateModule(
    fx_name: [:0]const u8,
    fx_index: i32,
    module_to_remove: ModulesList,
    media_track: MediaTrack,
) void {
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

    const new_name = std.fmt.bufPrintZ(buf[pos..], "){s}", .{
        fx_name[suffix_end + 1 ..],
    }) catch return;

    _ = pReaper.TrackFX_SetNamedConfigParm(.{ media_track, fx_index, "renamed_name", new_name });
}

var last_fx_name: ?[]const u8 = null;

fn mockTrackFX_SetNamedConfigParm(
    track: reaper.MediaTrack,
    fx_index: c_int,
    parm_name: [*:0]const u8,
    parm_value: [*:0]const u8,
) callconv(.C) bool {
    _ = fx_index; // autofix
    _ = track;
    if (std.mem.eql(u8, std.mem.span(parm_name), "renamed_name")) {
        last_fx_name = std.mem.span(parm_value);
    }
    return true;
}

test "removeDuplicateModule" {
    const testing = std.testing;

    // Save original function pointer and replace with mock
    const real_fn = reaper.TrackFX_SetNamedConfigParm;
    @constCast(&reaper.TrackFX_SetNamedConfigParm).* = @constCast(&mockTrackFX_SetNamedConfigParm);
    defer @constCast(&reaper.TrackFX_SetNamedConfigParm).* = real_fn;

    const dummy_track: MediaTrack = @ptrCast(@alignCast(@as(*anyopaque, @constCast(&[_]u8{0}))));

    // Test 1: Remove INPUT module from a multi-module suffix
    {
        const orig_name = "ReaComp (C1-IC)";
        removeDuplicateModule(orig_name, 0, .INPUT, dummy_track);
        try testing.expect(std.mem.eql(u8, last_fx_name.?, "ReaComp (C1-C)"));
    }

    // Test 2: Remove middle module
    {
        const orig_name = "ReaEQ (C1-SEC)";
        removeDuplicateModule(orig_name, 1, .EQ, dummy_track);
        try testing.expect(std.mem.eql(u8, last_fx_name.?, "ReaEQ (C1-SC)"));
    }

    // Test 3: FX name with text after suffix
    {
        const orig_name = "ReaComp (C1-IC) my settings";
        removeDuplicateModule(orig_name, 2, .INPUT, dummy_track);
        try testing.expect(std.mem.eql(u8, last_fx_name.?, "ReaComp (C1-C) my settings"));
    }

    // Test 4: Single module suffix
    {
        const orig_name = "ReaComp (C1-C)";
        removeDuplicateModule(orig_name, 3, .COMP, dummy_track);
        try testing.expect(std.mem.eql(u8, last_fx_name.?, "ReaComp (C1-)"));
    }
}

test "analyzeCoverage" {
    const testing = std.testing;

    // Test case 1: Valid coverage with no duplicates
    {
        const parsed_fx = [_]ParsedFx{
            .{
                .index = 0,
                .original_name = "Test FX 1",
                .renamed_name = "Test FX 1",
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
                .original_name = "Test FX 2",
                .renamed_name = "Test FX 2",
                .active_modules = .{
                    .INPUT = false,
                    .GATE = true,
                    .EQ = false,
                    .COMP = false,
                    .OUTPT = false,
                },
            },
        };

        const coverage = try analyzeCoverage(&parsed_fx);
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
                .original_name = "Test FX 1",
                .renamed_name = "Test FX 1",
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
                .original_name = "Test FX 2",
                .renamed_name = "Test FX 2",
                .active_modules = .{
                    .INPUT = true, // Duplicate INPUT module
                    .GATE = false,
                    .EQ = false,
                    .COMP = false,
                    .OUTPT = false,
                },
            },
        };

        try testing.expectError(error.DuplicateModule, analyzeCoverage(&parsed_fx));
    }
}

fn addMissingModules(
    parsed_fx: *std.ArrayList(ParsedFx),
    coverage: ModuleCoverage,
    mediaTrack: reaper.MediaTrack,
    allocator: std.mem.Allocator,
) !void {
    var buf: [512:0]u8 = undefined;

    // Check each module
    inline for (std.meta.fields(@TypeOf(coverage.covered))) |field| {
        if (!@field(coverage.covered, field.name)) {
            // Get default FX for this module
            const default_fx = globals.preferences.default_fx.get(@field(ModulesList, field.name));

            // Add FX to track
            const fx_index = reaper.TrackFX_AddByName(
                mediaTrack,
                default_fx,
                false,
                -1, // Add to end of chain
            );
            if (fx_index < 0) return error.FxAddFailed;

            // Create C1 suffix for this module
            const suffix = try std.fmt.bufPrintZ(
                &buf,
                "(C1-{c})",
                .{if (comptime std.mem.eql(u8, field.name, "INPUT"))
                    'I'
                else if (comptime std.mem.eql(u8, field.name, "GATE"))
                    'S'
                else if (comptime std.mem.eql(u8, field.name, "EQ"))
                    'E'
                else if (comptime std.mem.eql(u8, field.name, "COMP"))
                    'C'
                else if (comptime std.mem.eql(u8, field.name, "OUTPT"))
                    'O'
                else
                    unreachable},
            );

            // Get original name
            if (!reaper.TrackFX_GetFXName(mediaTrack, fx_index, &buf, buf.len)) {
                return error.GetNameFailed;
            }
            const original_name = std.mem.span(@as([*:0]const u8, &buf));

            // Create new name with suffix
            var new_name_buf: [512:0]u8 = undefined;
            const new_name = try std.fmt.bufPrintZ(
                &new_name_buf,
                "{s} {s}",
                .{ original_name, suffix },
            );

            // Set renamed name
            if (!reaper.TrackFX_SetNamedConfigParm(
                mediaTrack,
                fx_index,
                "renamed_name",
                new_name.ptr,
            )) {
                return error.RenameFailed;
            }

            // Add to parsed_fx list
            try parsed_fx.append(.{
                .index = fx_index,
                .original_name = try allocator.dupeZ(u8, original_name),
                .renamed_name = try allocator.dupeZ(u8, new_name),
                .active_modules = .{
                    .INPUT = std.mem.eql(u8, field.name, "INPUT"),
                    .GATE = std.mem.eql(u8, field.name, "GATE"),
                    .EQ = std.mem.eql(u8, field.name, "EQ"),
                    .COMP = std.mem.eql(u8, field.name, "COMP"),
                    .OUTPT = std.mem.eql(u8, field.name, "OUTPT"),
                },
            });
        }
    }
}

fn reorderFx(
    parsed_fx: []const ParsedFx,
    mediaTrack: reaper.MediaTrack,
    allocator: std.mem.Allocator,
) !void {
    // First, create ordered list of indices
    var ordered_indices = std.ArrayList(i32).init(allocator);
    defer ordered_indices.deinit();

    // 1. Find and move INPUT to front
    for (parsed_fx) |fx| {
        if (fx.active_modules) |modules| {
            if (modules.INPUT) {
                try ordered_indices.append(fx.index);
                break;
            }
        }
    }
    if (ordered_indices.items.len == 0) return error.NoInputModule;

    // 2. Add middle modules in correct order
    // GATE->EQ->COMP or EQ->GATE->COMP etc. based on current order setting
    const module_order = [3][]const u8{ "GATE", "EQ", "COMP" }; // This should come from settings
    for (module_order) |module_name| {
        for (parsed_fx) |fx| {
            if (fx.active_modules) |modules| {
                const is_active = if (std.mem.eql(u8, module_name, "GATE"))
                    modules.GATE
                else if (std.mem.eql(u8, module_name, "EQ"))
                    modules.EQ
                else if (std.mem.eql(u8, module_name, "COMP"))
                    modules.COMP
                else
                    false;

                if (is_active) {
                    try ordered_indices.append(fx.index);
                }
            }
        }
    }

    // 3. Find and move OUTPUT to end
    for (parsed_fx) |fx| {
        if (fx.active_modules) |modules| {
            if (modules.OUTPT) {
                try ordered_indices.append(fx.index);
                break;
            }
        }
    }

    // Now reorder FX chain
    var current_pos: i32 = 0;
    for (ordered_indices.items) |target_idx| {
        // Move FX to current_pos
        _ = reaper.TrackFX_CopyToTrack(mediaTrack, target_idx, mediaTrack, current_pos, true);
        current_pos += 1;
    }
}

pub fn updateTrackState(
    track_state: *TrackState,
    parsed_fx: []const ParsedFx,
) void {
    // Reset current state
    track_state.fx_count = 0;
    for (std.enums.values(ModulesList)) |module| {
        track_state.module_locations.set(module, null);
    }

    // Update FX states and module locations
    for (parsed_fx) |fx| {
        if (fx.active_modules) |modules| {
            // Add to fx_states
            track_state.fx_states[track_state.fx_count] = .{
                .fx_index = fx.index,
                .modules = modules,
            };

            // Update module locations
            inline for (std.meta.fields(@TypeOf(modules))) |field| {
                const is_active = @field(modules, field.name);
                if (is_active) {
                    const module = @field(ModulesList, field.name);
                    track_state.module_locations.set(module, .{
                        .fx_index = fx.index,
                        .mapping = switch (module) {
                            .INPUT => .{ .INPUT = globals.map_store.get(fx.original_name, .INPUT).INPUT.? },
                            .GATE => .{ .GATE = globals.map_store.get(fx.original_name, .GATE).GATE.? },
                            .EQ => .{ .EQ = globals.map_store.get(fx.original_name, .EQ).EQ.? },
                            .COMP => .{ .COMP = globals.map_store.get(fx.original_name, .COMP).COMP.? },
                            .OUTPT => .{ .OUTPT = globals.map_store.get(fx.original_name, .OUTPT).OUTPT.? },
                        },
                    });
                }
            }

            track_state.fx_count += 1;
        }
    }
}
