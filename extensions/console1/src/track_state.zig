const std = @import("std");
const reaper = @import("reaper.zig").reaper;
const pReaper = @import("pReaper.zig");
const c1 = @import("c1.zig");
const ChannelStripMapping = MapStore.ChannelStripMapping;
const MediaTrack = reaper.MediaTrack;
const ModulesList = @import("statemachine.zig").ModulesList;
const PhysicalModule = @import("statemachine.zig").PhysicalModule;
const MapStore = @import("mappings.zig");
const ModulesOrder = @import("fx_ctrl_state.zig").ModulesOrder;
const DefaultFx = @import("settings.zig").DefaultFx;
const TaggedMapping = MapStore.TaggedMapping;
const MockReaper = @import("models/reaper_mock.zig");
const Guid = @import("utils.zig").Guid;
const MappingsList = @import("mappings_list.zig");
const log = std.log.scoped(.validation);
const Preferences = @import("settings.zig").Preferences;

pub const MAX_FX = 5;
const MAX_PARSED_FX = MAX_FX * 2;

const Location = struct {
    fx_index: c_int,
    mapping: ?TaggedMapping,
};

pub const ModuleLocations = std.EnumArray(PhysicalModule, ?Location);

const ActiveModules = packed struct {
    INPUT: bool = false,
    GATE: bool = false,
    EQ: bool = false,
    COMP: bool = false,
    OUTPT: bool = false,
};

pub const FxParam = struct {
    fx_index: c_int,
    param_index: u16,
};

pub const ParamKey = packed struct {
    fx_index: u16,
    param_index: u16,
};

pub const ChannelStripState = struct {
    fx_index: c_int,
    mapping: ChannelStripMapping,
    guid: Guid,
};

/// Multi-fx mode assigns one FX per module; channel strip mode routes all
/// CCs to a single FX.
pub const TrackMode = union(enum) {
    multi_fx: ModuleLocations,
    channel_strip: ChannelStripState,
};

pub const ParsedFx = struct {
    index: i32,
    guid: Guid,
    suffix: ?C1Suffix = null,
};

pub const TrackState = @This();

fx_states: [MAX_FX]struct {
    fx_index: i32,
    modules: ActiveModules = .{},
} = undefined,
fx_count: usize = 0,
mode: TrackMode = .{ .multi_fx = ModuleLocations.initFill(null) },
reverse_map: std.AutoArrayHashMapUnmanaged(u32, c1.CCs) = .empty,
forward_map: std.AutoArrayHashMapUnmanaged(c1.CCs, FxParam) = .empty,

pub fn deinitMaps(self: *TrackState, allocator: std.mem.Allocator) void {
    self.reverse_map.deinit(allocator);
    self.forward_map.deinit(allocator);
}

pub fn getModuleLocations(self: *TrackState) ?*ModuleLocations {
    return switch (self.mode) {
        .multi_fx => |*locs| locs,
        .channel_strip => null,
    };
}

pub fn validateTrack(
    track_state: *TrackState,
    mediaTrack: reaper.MediaTrack,
    default_fx: DefaultFx,
    map_store: *MapStore,
    preferences: Preferences,
    allocator: std.mem.Allocator,
    mappings_list: *MappingsList,
) ModuleCoverage {
    track_state.fx_states = undefined;
    track_state.fx_count = 0;
    track_state.mode = .{ .multi_fx = ModuleLocations.initFill(null) };
    track_state.reverse_map.clearRetainingCapacity();
    track_state.forward_map.clearRetainingCapacity();

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

            if (parseC1Suffix(renamed_name)) |suffix| {
                if (parsed_fx.items.len < MAX_PARSED_FX) {
                    parsed_fx.appendAssumeCapacity(.{
                        .index = i,
                        .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(mediaTrack, i)),
                        .suffix = suffix,
                    });
                }
                // Silently ignore if we've reached capacity
            }
        }
    }

    if (parsed_fx.items.len == 0) {
        if (tryInsertDefaultStrip(track_state, mediaTrack, preferences, map_store, allocator, mappings_list)) {
            return ModuleCoverage{};
        }
    }

    // Check for channel strip FX before proceeding with multi-fx path.
    // Because channel strip and multi-fx are mutually exclusive, the first
    // channel strip FX found causes an early return.
    for (parsed_fx.items) |fx| {
        if (fx.suffix) |suffix| {
            switch (suffix) {
                .channel_strip => {
                    // Get original FX name for mapping lookup
                    if (reaper.TrackFX_GetNamedConfigParm(mediaTrack, fx.index, "original_name", &buf, buf.len)) {
                        const fx_name = std.mem.span(@as([*:0]const u8, &buf));
                        const fx_name_z: [:0]const u8 = @ptrCast(fx_name);
                        const mapping = if (map_store.get(fx_name_z, .STRIP, mappings_list)) |tagged|
                            tagged.STRIP
                        else
                            MapStore.ChannelStripMapping{};

                        track_state.mode = .{
                            .channel_strip = .{
                                .fx_index = fx.index,
                                .mapping = mapping,
                                .guid = fx.guid,
                            },
                        };
                        populateMapsFromMapping(&track_state.reverse_map, &track_state.forward_map, allocator, .{ .STRIP = mapping }, fx.index);
                    }
                    return ModuleCoverage{};
                },
                .module => {},
            }
        }
    }

    var coverage = analyzeCoverage(&parsed_fx, mediaTrack);
    coverage = reorderFx2(coverage, mediaTrack, default_fx, preferences);
    updateTrackState(track_state, coverage, mediaTrack, &buf, map_store, allocator, mappings_list);
    return coverage;
}

pub const C1Suffix = union(enum) {
    module: PhysicalModule,
    channel_strip: void,
};

pub fn parseC1Suffix(name: [:0]const u8) ?C1Suffix {
    const suffix_start = if (std.mem.lastIndexOf(u8, name, "(C1-")) |start| start else return null;
    const suffix_end = if (std.mem.indexOfPos(u8, name, suffix_start, ")")) |end| end else return null;
    const modules = name[suffix_start + 4 .. suffix_end];

    for (modules) |c| {
        const m: ?C1Suffix = switch (c) {
            'I' => .{ .module = .INPUT },
            'S' => .{ .module = .GATE },
            'E' => .{ .module = .EQ },
            'C' => .{ .module = .COMP },
            'O' => .{ .module = .OUTPT },
            'X' => .{ .channel_strip = {} },
            else => null,
        };
        if (m) |suffix| return suffix;
    }

    return null;
}

fn tryInsertDefaultStrip(
    track_state: *TrackState,
    mediaTrack: reaper.MediaTrack,
    preferences: Preferences,
    map_store: *MapStore,
    allocator: std.mem.Allocator,
    mappings_list: *MappingsList,
) bool {
    const strip_fx_name = preferences.default_fx.get(.STRIP) orelse return false;
    if (!preferences.auto_insert_modules) return false;

    const new_idx = pReaper.TrackFX_AddByName(.{ mediaTrack, strip_fx_name, false, -1 });
    if (new_idx < 0) return false;

    var name_buf: [512:0]u8 = undefined;
    const new_name = std.fmt.bufPrintZ(&name_buf, "{s} (C1-X)", .{strip_fx_name}) catch return false;
    _ = pReaper.TrackFX_SetNamedConfigParm(.{ mediaTrack, new_idx, "renamed_name", new_name });

    const strip_name_z: [:0]const u8 = strip_fx_name;
    const mapping = if (map_store.get(strip_name_z, .STRIP, mappings_list)) |tagged|
        tagged.STRIP
    else
        MapStore.ChannelStripMapping{};

    track_state.mode = .{
        .channel_strip = .{
            .fx_index = new_idx,
            .mapping = mapping,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(mediaTrack, new_idx)),
        },
    };
    populateMapsFromMapping(
        &track_state.reverse_map,
        &track_state.forward_map,
        allocator,
        .{ .STRIP = mapping },
        new_idx,
    );
    return true;
}

pub fn populateMapsFromMapping(
    reverse_map: *std.AutoArrayHashMapUnmanaged(u32, c1.CCs),
    forward_map: *std.AutoArrayHashMapUnmanaged(c1.CCs, FxParam),
    allocator: std.mem.Allocator,
    tagged_mapping: TaggedMapping,
    fx_index: c_int,
) void {
    switch (tagged_mapping) {
        inline else => |mapping| {
            inline for (std.meta.fields(@TypeOf(mapping))) |field| {
                if (comptime std.mem.eql(u8, field.name, "version")) continue;
                if (comptime !@hasField(c1.CCs, field.name)) continue;
                if (@field(mapping, field.name)) |param_idx| {
                    const key: u32 = @bitCast(ParamKey{
                        .fx_index = @intCast(fx_index),
                        .param_index = param_idx,
                    });
                    const cc = @field(c1.CCs, field.name);
                    reverse_map.put(allocator, key, cc) catch {};
                    forward_map.put(allocator, cc, .{
                        .fx_index = fx_index,
                        .param_index = param_idx,
                    }) catch {};
                }
            }
        },
    }
}

test "parseC1Suffix - basic valid cases" {
    // Valid cases
    const testing = std.testing;
    try testing.expectEqual(C1Suffix{ .module = .INPUT }, parseC1Suffix("Some Plugin (C1-I)").?);

    try testing.expectEqual(C1Suffix{ .module = .COMP }, parseC1Suffix("ReaComp (C1-C)").?);

    // Invalid cases
    try testing.expectEqual(@as(?C1Suffix, null), parseC1Suffix("No Suffix Plugin"));

    try testing.expectEqual(@as(?C1Suffix, null), parseC1Suffix("Invalid (C1"));

    // Ignore invalid characters
    try testing.expectEqual(C1Suffix{ .module = .INPUT }, parseC1Suffix("Plugin (C1-IX)").?);

    // Channel strip suffix
    try testing.expectEqual(C1Suffix{ .channel_strip = {} }, parseC1Suffix("SSL Channel Strip (C1-X)").?);
}

test "parseC1Suffix - multiple suffixes returns last one" {
    const testing = std.testing;
    // Because the function uses lastIndexOf for "(C1-", it will find the last occurrence
    try testing.expectEqual(C1Suffix{ .module = .COMP }, parseC1Suffix("Plugin (C1-I) Extra (C1-C)").?);
    try testing.expectEqual(C1Suffix{ .module = .GATE }, parseC1Suffix("(C1-E) Plugin (C1-S)").?);
    try testing.expectEqual(C1Suffix{ .module = .OUTPT }, parseC1Suffix("(C1-I)(C1-E)(C1-O)").?);
}

test "parseC1Suffix - missing closing parenthesis" {
    const testing = std.testing;
    // Because the function looks for closing paren with indexOfPos, it should return null safely
    try testing.expectEqual(@as(?C1Suffix, null), parseC1Suffix("Plugin (C1-I"));
    try testing.expectEqual(@as(?C1Suffix, null), parseC1Suffix("(C1-C"));
    try testing.expectEqual(@as(?C1Suffix, null), parseC1Suffix("Something (C1-E and more text"));
}

test "parseC1Suffix - empty and very long strings" {
    const testing = std.testing;
    // Empty string
    try testing.expectEqual(@as(?C1Suffix, null), parseC1Suffix(""));

    // Very long string without suffix
    var long_buf: [1000:0]u8 = undefined;
    @memset(&long_buf, 'A');
    long_buf[999] = 0;
    const long_str: [:0]const u8 = long_buf[0..999 :0];
    try testing.expectEqual(@as(?C1Suffix, null), parseC1Suffix(long_str));

    // Very long string with suffix at end
    var long_with_suffix_buf: [1000:0]u8 = undefined;
    @memset(long_with_suffix_buf[0..993], 'A');
    @memcpy(long_with_suffix_buf[993..999], "(C1-S)");
    long_with_suffix_buf[999] = 0;
    const long_with_suffix: [:0]const u8 = long_with_suffix_buf[0..999 :0];
    try testing.expectEqual(C1Suffix{ .module = .GATE }, parseC1Suffix(long_with_suffix).?);
}

test "parseC1Suffix - suffix at boundaries" {
    const testing = std.testing;
    // Suffix at the very start
    try testing.expectEqual(C1Suffix{ .module = .INPUT }, parseC1Suffix("(C1-I)").?);
    try testing.expectEqual(C1Suffix{ .module = .EQ }, parseC1Suffix("(C1-E)").?);

    // Suffix with minimal spacing
    try testing.expectEqual(C1Suffix{ .module = .COMP }, parseC1Suffix("X(C1-C)").?);
    try testing.expectEqual(C1Suffix{ .module = .OUTPT }, parseC1Suffix("AB(C1-O)XY").?);
}

test "parseC1Suffix - empty suffix content" {
    const testing = std.testing;
    // Because the loop looks for valid module chars, empty content should return null
    try testing.expectEqual(@as(?C1Suffix, null), parseC1Suffix("Plugin (C1-)"));
    try testing.expectEqual(@as(?C1Suffix, null), parseC1Suffix("(C1-)"));
}

test "parseC1Suffix - all module types" {
    const testing = std.testing;
    try testing.expectEqual(C1Suffix{ .module = .INPUT }, parseC1Suffix("Test (C1-I)").?);
    try testing.expectEqual(C1Suffix{ .module = .GATE }, parseC1Suffix("Test (C1-S)").?);
    try testing.expectEqual(C1Suffix{ .module = .EQ }, parseC1Suffix("Test (C1-E)").?);
    try testing.expectEqual(C1Suffix{ .module = .COMP }, parseC1Suffix("Test (C1-C)").?);
    try testing.expectEqual(C1Suffix{ .module = .OUTPT }, parseC1Suffix("Test (C1-O)").?);
}

test "parseC1Suffix - invalid characters before valid one" {
    const testing = std.testing;
    // Because the function returns first valid char, invalid chars before should be skipped
    try testing.expectEqual(C1Suffix{ .channel_strip = {} }, parseC1Suffix("Plugin (C1-XXXI)").?);
    try testing.expectEqual(C1Suffix{ .module = .INPUT }, parseC1Suffix("Plugin (C1-###I)").?);
    try testing.expectEqual(C1Suffix{ .module = .COMP }, parseC1Suffix("Plugin (C1-123C)").?);
    try testing.expectEqual(C1Suffix{ .module = .GATE }, parseC1Suffix("Plugin (C1-$#@S)").?);
}

test "analyzeCoverage - empty FX list" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 4);
    defer ctx.teardown();

    const track = reaper.GetTrack(0, 0);

    // Because parsed_fx is empty, coverage should be all null
    var parsed_fx_buf: [MAX_PARSED_FX]ParsedFx = undefined;
    var parsed_fx = std.ArrayListUnmanaged(ParsedFx).initBuffer(&parsed_fx_buf);

    const coverage = analyzeCoverage(&parsed_fx, track);

    try testing.expectEqual(@as(?ModuleLocation, null), coverage.INPUT);
    try testing.expectEqual(@as(?ModuleLocation, null), coverage.GATE);
    try testing.expectEqual(@as(?ModuleLocation, null), coverage.EQ);
    try testing.expectEqual(@as(?ModuleLocation, null), coverage.COMP);
    try testing.expectEqual(@as(?ModuleLocation, null), coverage.OUTPT);
}

test "analyzeCoverage - all duplicates of same module" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 4);
    defer ctx.teardown();

    const track = reaper.GetTrack(0, 0);

    // Add multiple FX with the same module
    _ = reaper.TrackFX_AddByName(track, "ReaComp", false, -1);
    _ = reaper.TrackFX_AddByName(track, "ReaComp", false, -1);
    _ = reaper.TrackFX_AddByName(track, "ReaComp", false, -1);

    // Set all with COMP suffix
    _ = reaper.TrackFX_SetNamedConfigParm(track, 0, "renamed_name", "ReaComp (C1-C)");
    _ = reaper.TrackFX_SetNamedConfigParm(track, 1, "renamed_name", "ReaComp (C1-C)");
    _ = reaper.TrackFX_SetNamedConfigParm(track, 2, "renamed_name", "ReaComp (C1-C)");

    var parsed_fx_buf: [MAX_PARSED_FX]ParsedFx = undefined;
    var parsed_fx = std.ArrayListUnmanaged(ParsedFx).initBuffer(&parsed_fx_buf);

    // Parse all three
    parsed_fx.appendAssumeCapacity(.{
        .index = 0,
        .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 0)),
        .suffix = .{ .module = .COMP },
    });
    parsed_fx.appendAssumeCapacity(.{
        .index = 1,
        .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 1)),
        .suffix = .{ .module = .COMP },
    });
    parsed_fx.appendAssumeCapacity(.{
        .index = 2,
        .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 2)),
        .suffix = .{ .module = .COMP },
    });

    const coverage = analyzeCoverage(&parsed_fx, track);

    // Because only the first should remain marked, coverage.COMP should point to FX 0
    try testing.expect(coverage.COMP != null);
    try testing.expectEqual(@as(c_int, 0), coverage.COMP.?.index);

    // Because analyzeCoverage calls removeDuplicateModule on duplicates,
    // we've tested that the function completes without crashing
}

test "analyzeCoverage - partial coverage" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 4);
    defer ctx.teardown();

    const track = reaper.GetTrack(0, 0);

    // Add only INPUT, EQ, and OUTPT
    _ = reaper.TrackFX_AddByName(track, "JS: Volume Adjustment", false, -1);
    _ = reaper.TrackFX_AddByName(track, "ReaEQ", false, -1);
    _ = reaper.TrackFX_AddByName(track, "JS: Volume Adjustment", false, -1);

    _ = reaper.TrackFX_SetNamedConfigParm(track, 0, "renamed_name", "JS: Volume Adjustment (C1-I)");
    _ = reaper.TrackFX_SetNamedConfigParm(track, 1, "renamed_name", "ReaEQ (C1-E)");
    _ = reaper.TrackFX_SetNamedConfigParm(track, 2, "renamed_name", "JS: Volume Adjustment (C1-O)");

    var parsed_fx_buf: [MAX_PARSED_FX]ParsedFx = undefined;
    var parsed_fx = std.ArrayListUnmanaged(ParsedFx).initBuffer(&parsed_fx_buf);

    parsed_fx.appendAssumeCapacity(.{
        .index = 0,
        .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 0)),
        .suffix = .{ .module = .INPUT },
    });
    parsed_fx.appendAssumeCapacity(.{
        .index = 1,
        .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 1)),
        .suffix = .{ .module = .EQ },
    });
    parsed_fx.appendAssumeCapacity(.{
        .index = 2,
        .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 2)),
        .suffix = .{ .module = .OUTPT },
    });

    const coverage = analyzeCoverage(&parsed_fx, track);

    // Because we have INPUT, EQ, and OUTPT
    try testing.expect(coverage.INPUT != null);
    try testing.expectEqual(@as(c_int, 0), coverage.INPUT.?.index);
    try testing.expect(coverage.EQ != null);
    try testing.expectEqual(@as(c_int, 1), coverage.EQ.?.index);
    try testing.expect(coverage.OUTPT != null);
    try testing.expectEqual(@as(c_int, 2), coverage.OUTPT.?.index);

    // GATE and COMP should be null
    try testing.expectEqual(@as(?ModuleLocation, null), coverage.GATE);
    try testing.expectEqual(@as(?ModuleLocation, null), coverage.COMP);
}

test "analyzeCoverage - multiple items in parsed_fx" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 6);
    defer ctx.teardown();

    const track = reaper.GetTrack(0, 0);

    var parsed_fx_buf: [MAX_PARSED_FX]ParsedFx = undefined;
    var parsed_fx = std.ArrayListUnmanaged(ParsedFx).initBuffer(&parsed_fx_buf);

    // Add 5 items to test handling multiple parsed FX
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        _ = reaper.TrackFX_AddByName(track, "ReaComp", false, -1);
        const fx_index: i32 = @intCast(i);
        _ = reaper.TrackFX_SetNamedConfigParm(track, fx_index, "renamed_name", "ReaComp (C1-C)");

        parsed_fx.appendAssumeCapacity(.{
            .index = fx_index,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, fx_index)),
            .suffix = .{ .module = .COMP },
        });
    }

    const coverage = analyzeCoverage(&parsed_fx, track);

    // Because only first COMP should be covered
    try testing.expect(coverage.COMP != null);
    try testing.expectEqual(@as(c_int, 0), coverage.COMP.?.index);
}

test "analyzeCoverage - null suffix skipped" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 4);
    defer ctx.teardown();

    const track = reaper.GetTrack(0, 0);

    var parsed_fx_buf: [MAX_PARSED_FX]ParsedFx = undefined;
    var parsed_fx = std.ArrayListUnmanaged(ParsedFx).initBuffer(&parsed_fx_buf);

    _ = reaper.TrackFX_AddByName(track, "ReaComp", false, -1);
    _ = reaper.TrackFX_AddByName(track, "ReaGate", false, -1);

    // Add one with null suffix and one with valid module
    parsed_fx.appendAssumeCapacity(.{
        .index = 0,
        .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 0)),
        .suffix = null,
    });
    parsed_fx.appendAssumeCapacity(.{
        .index = 1,
        .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 1)),
        .suffix = .{ .module = .GATE },
    });

    const coverage = analyzeCoverage(&parsed_fx, track);

    // Because only GATE should be in coverage
    try testing.expect(coverage.GATE != null);
    try testing.expectEqual(@as(c_int, 1), coverage.GATE.?.index);
    try testing.expectEqual(@as(?ModuleLocation, null), coverage.COMP);
}

test "removeDuplicateModule - multiple spaces before suffix" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 4);
    defer ctx.teardown();

    const track = reaper.GetTrack(0, 0);

    _ = reaper.TrackFX_AddByName(track, "ReaComp", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(track, 0, "renamed_name", "ReaComp   (C1-C)");

    removeDuplicateModule(0, track);

    var buf: [512:0]u8 = undefined;
    _ = reaper.TrackFX_GetNamedConfigParm(track, 0, "renamed_name", &buf, buf.len);
    const name = std.mem.span(@as([*:0]const u8, &buf));

    // Because trailing spaces should be trimmed
    try testing.expectEqualStrings("ReaComp", name);
}

test "removeDuplicateModule - suffix at start" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 4);
    defer ctx.teardown();

    const track = reaper.GetTrack(0, 0);

    _ = reaper.TrackFX_AddByName(track, "(C1-E)", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(track, 0, "renamed_name", "(C1-E)");

    removeDuplicateModule(0, track);

    var buf: [512:0]u8 = undefined;
    _ = reaper.TrackFX_GetNamedConfigParm(track, 0, "renamed_name", &buf, buf.len);
    const name = std.mem.span(@as([*:0]const u8, &buf));

    // Because prefix is empty, result should be empty
    try testing.expectEqualStrings("", name);
}

test "removeDuplicateModule - suffix at end" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 4);
    defer ctx.teardown();

    const track = reaper.GetTrack(0, 0);

    _ = reaper.TrackFX_AddByName(track, "Plugin (C1-I)", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(track, 0, "renamed_name", "Plugin (C1-I)");

    removeDuplicateModule(0, track);

    var buf: [512:0]u8 = undefined;
    _ = reaper.TrackFX_GetNamedConfigParm(track, 0, "renamed_name", &buf, buf.len);
    const name = std.mem.span(@as([*:0]const u8, &buf));

    // Because suffix is at end
    try testing.expectEqualStrings("Plugin", name);
}

test "removeDuplicateModule - no suffix does not crash" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 4);
    defer ctx.teardown();

    const track = reaper.GetTrack(0, 0);

    _ = reaper.TrackFX_AddByName(track, "Normal Plugin", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(track, 0, "renamed_name", "Normal Plugin");

    // Because there's no suffix, function should return early without crashing
    removeDuplicateModule(0, track);

    var buf: [512:0]u8 = undefined;
    _ = reaper.TrackFX_GetNamedConfigParm(track, 0, "renamed_name", &buf, buf.len);
    const name = std.mem.span(@as([*:0]const u8, &buf));

    // Name should remain unchanged
    try testing.expectEqualStrings("Normal Plugin", name);
}

test "removeDuplicateModule - text after closing paren preserved" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 4);
    defer ctx.teardown();

    const track = reaper.GetTrack(0, 0);

    _ = reaper.TrackFX_AddByName(track, "Plugin (C1-C) Extra", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(track, 0, "renamed_name", "Plugin (C1-C) Extra");

    removeDuplicateModule(0, track);

    var buf: [512:0]u8 = undefined;
    _ = reaper.TrackFX_GetNamedConfigParm(track, 0, "renamed_name", &buf, buf.len);
    const name = std.mem.span(@as([*:0]const u8, &buf));

    // Because text after closing paren should be preserved
    try testing.expectEqualStrings("Plugin Extra", name);
}

test "reorderFx2 - empty track to full chain" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 4);
    defer ctx.teardown();

    const track = reaper.GetTrack(0, 0);

    // Start with completely empty coverage
    const empty_coverage = ModuleCoverage{};

    const settings_mod = @import("settings.zig");
    const fallback_map = settings_mod.fallback_defaults;
    var default_fx = DefaultFx.initFill(null);
    inline for (comptime std.enums.values(PhysicalModule)) |module| {
        default_fx.set(@as(ModulesList, @enumFromInt(@intFromEnum(module))), fallback_map.get(@as(ModulesList, @enumFromInt(@intFromEnum(module)))));
    }

    const result_coverage = reorderFx2(empty_coverage, track, default_fx, .empty);

    // Because all modules should now be present
    try testing.expect(result_coverage.INPUT != null);
    try testing.expect(result_coverage.GATE != null);
    try testing.expect(result_coverage.EQ != null);
    try testing.expect(result_coverage.COMP != null);
    try testing.expect(result_coverage.OUTPT != null);

    // Verify FX count
    const fx_count = reaper.TrackFX_GetCount(track);
    try testing.expectEqual(@as(c_int, 5), fx_count);
}

test "reorderFx2 - partial chain with INPUT and OUTPT" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 4);
    defer ctx.teardown();

    const track = reaper.GetTrack(0, 0);

    // Add only INPUT and OUTPT
    _ = reaper.TrackFX_AddByName(track, "JS: Volume/Pan Smoother v5", false, -1);
    _ = reaper.TrackFX_AddByName(track, "JS: Saturation", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(track, 0, "renamed_name", "JS: Volume/Pan Smoother v5 (C1-I)");
    _ = reaper.TrackFX_SetNamedConfigParm(track, 1, "renamed_name", "JS: Saturation (C1-O)");

    const partial_coverage = ModuleCoverage{
        .INPUT = .{
            .index = 0,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 0)),
        },
        .OUTPT = .{
            .index = 1,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 1)),
        },
    };

    const settings_mod = @import("settings.zig");
    const fallback_map = settings_mod.fallback_defaults;
    var default_fx = DefaultFx.initFill(null);
    inline for (comptime std.enums.values(PhysicalModule)) |module| {
        default_fx.set(@as(ModulesList, @enumFromInt(@intFromEnum(module))), fallback_map.get(@as(ModulesList, @enumFromInt(@intFromEnum(module)))));
    }

    const result_coverage = reorderFx2(partial_coverage, track, default_fx, .empty);

    // Because missing modules should be inserted
    try testing.expect(result_coverage.INPUT != null);
    try testing.expect(result_coverage.GATE != null);
    try testing.expect(result_coverage.EQ != null);
    try testing.expect(result_coverage.COMP != null);
    try testing.expect(result_coverage.OUTPT != null);

    // Verify order: INPUT should be first, OUTPT should be last
    try testing.expect(result_coverage.INPUT.?.index < result_coverage.GATE.?.index);
    try testing.expect(result_coverage.GATE.?.index < result_coverage.COMP.?.index);
    try testing.expect(result_coverage.COMP.?.index < result_coverage.OUTPT.?.index);
}

test "reorderFx2 - chain already in correct order" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 4);
    defer ctx.teardown();

    const track = reaper.GetTrack(0, 0);

    // Add all modules in correct order
    _ = reaper.TrackFX_AddByName(track, "JS: Volume/Pan Smoother v5", false, -1);
    _ = reaper.TrackFX_AddByName(track, "VST: ReaGate (Cockos)", false, -1);
    _ = reaper.TrackFX_AddByName(track, "VST: ReaEQ (Cockos)", false, -1);
    _ = reaper.TrackFX_AddByName(track, "VST: ReaComp (Cockos)", false, -1);
    _ = reaper.TrackFX_AddByName(track, "JS: Saturation", false, -1);

    _ = reaper.TrackFX_SetNamedConfigParm(track, 0, "renamed_name", "JS: Volume/Pan Smoother v5 (C1-I)");
    _ = reaper.TrackFX_SetNamedConfigParm(track, 1, "renamed_name", "VST: ReaGate (Cockos) (C1-S)");
    _ = reaper.TrackFX_SetNamedConfigParm(track, 2, "renamed_name", "VST: ReaEQ (Cockos) (C1-E)");
    _ = reaper.TrackFX_SetNamedConfigParm(track, 3, "renamed_name", "VST: ReaComp (Cockos) (C1-C)");
    _ = reaper.TrackFX_SetNamedConfigParm(track, 4, "renamed_name", "JS: Saturation (C1-O)");

    const correct_coverage = ModuleCoverage{
        .INPUT = .{
            .index = 0,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 0)),
        },
        .GATE = .{
            .index = 1,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 1)),
        },
        .EQ = .{
            .index = 2,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 2)),
        },
        .COMP = .{
            .index = 3,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 3)),
        },
        .OUTPT = .{
            .index = 4,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 4)),
        },
    };

    const settings_mod = @import("settings.zig");
    const fallback_map = settings_mod.fallback_defaults;
    var default_fx = DefaultFx.initFill(null);
    inline for (comptime std.enums.values(PhysicalModule)) |module| {
        default_fx.set(@as(ModulesList, @enumFromInt(@intFromEnum(module))), fallback_map.get(@as(ModulesList, @enumFromInt(@intFromEnum(module)))));
    }

    const result_coverage = reorderFx2(correct_coverage, track, default_fx, .empty);

    // Because chain is already correct, indices should match original
    try testing.expectEqual(@as(c_int, 0), result_coverage.INPUT.?.index);
    try testing.expectEqual(@as(c_int, 1), result_coverage.GATE.?.index);
    try testing.expectEqual(@as(c_int, 2), result_coverage.EQ.?.index);
    try testing.expectEqual(@as(c_int, 3), result_coverage.COMP.?.index);
    try testing.expectEqual(@as(c_int, 4), result_coverage.OUTPT.?.index);
}

test "reorderFx2 - wrong order needs reordering" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 4);
    defer ctx.teardown();

    const track = reaper.GetTrack(0, 0);

    // Add modules in wrong order: OUTPT, COMP, EQ, GATE, INPUT
    _ = reaper.TrackFX_AddByName(track, "JS: Saturation", false, -1);
    _ = reaper.TrackFX_AddByName(track, "VST: ReaComp (Cockos)", false, -1);
    _ = reaper.TrackFX_AddByName(track, "VST: ReaEQ (Cockos)", false, -1);
    _ = reaper.TrackFX_AddByName(track, "VST: ReaGate (Cockos)", false, -1);
    _ = reaper.TrackFX_AddByName(track, "JS: Volume/Pan Smoother v5", false, -1);

    _ = reaper.TrackFX_SetNamedConfigParm(track, 0, "renamed_name", "JS: Saturation (C1-O)");
    _ = reaper.TrackFX_SetNamedConfigParm(track, 1, "renamed_name", "VST: ReaComp (Cockos) (C1-C)");
    _ = reaper.TrackFX_SetNamedConfigParm(track, 2, "renamed_name", "VST: ReaEQ (Cockos) (C1-E)");
    _ = reaper.TrackFX_SetNamedConfigParm(track, 3, "renamed_name", "VST: ReaGate (Cockos) (C1-S)");
    _ = reaper.TrackFX_SetNamedConfigParm(track, 4, "renamed_name", "JS: Volume/Pan Smoother v5 (C1-I)");

    const wrong_coverage = ModuleCoverage{
        .INPUT = .{
            .index = 4,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 4)),
        },
        .GATE = .{
            .index = 3,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 3)),
        },
        .EQ = .{
            .index = 2,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 2)),
        },
        .COMP = .{
            .index = 1,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 1)),
        },
        .OUTPT = .{
            .index = 0,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 0)),
        },
    };

    const settings_mod = @import("settings.zig");
    const fallback_map = settings_mod.fallback_defaults;
    var default_fx = DefaultFx.initFill(null);
    inline for (comptime std.enums.values(PhysicalModule)) |module| {
        default_fx.set(@as(ModulesList, @enumFromInt(@intFromEnum(module))), fallback_map.get(@as(ModulesList, @enumFromInt(@intFromEnum(module)))));
    }

    const result_coverage = reorderFx2(wrong_coverage, track, default_fx, .empty);

    // Because the reorderFx2 function inserts modules but doesn't reorder existing ones,
    // we just verify all modules are present
    try testing.expect(result_coverage.INPUT != null);
    try testing.expect(result_coverage.GATE != null);
    try testing.expect(result_coverage.EQ != null);
    try testing.expect(result_coverage.COMP != null);
    try testing.expect(result_coverage.OUTPT != null);

    try testing.expect(result_coverage.INPUT.?.index == 0);
    try testing.expect(result_coverage.GATE.?.index == 1);
    try testing.expect(result_coverage.EQ.?.index == 2);
    try testing.expect(result_coverage.COMP.?.index == 3);
    try testing.expect(result_coverage.OUTPT.?.index == 4);
}

test "updateTrackState - module_locations populated correctly" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 4);
    defer ctx.teardown();

    const track = reaper.GetTrack(0, 0);

    // Add all modules
    _ = reaper.TrackFX_AddByName(track, "JS: Volume/Pan Smoother v5", false, -1);
    _ = reaper.TrackFX_AddByName(track, "VST: ReaGate (Cockos)", false, -1);
    _ = reaper.TrackFX_AddByName(track, "VST: ReaEQ (Cockos)", false, -1);

    _ = reaper.TrackFX_SetNamedConfigParm(track, 0, "renamed_name", "JS: Volume/Pan Smoother v5 (C1-I)");
    _ = reaper.TrackFX_SetNamedConfigParm(track, 1, "renamed_name", "VST: ReaGate (Cockos) (C1-S)");
    _ = reaper.TrackFX_SetNamedConfigParm(track, 2, "renamed_name", "VST: ReaEQ (Cockos) (C1-E)");

    const coverage = ModuleCoverage{
        .INPUT = .{
            .index = 0,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 0)),
        },
        .GATE = .{
            .index = 1,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 1)),
        },
        .EQ = .{
            .index = 2,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 2)),
        },
    };

    const settings_mod = @import("settings.zig");
    const fallback_map = settings_mod.fallback_defaults;
    var default_fx = DefaultFx.initFill(null);
    inline for (comptime std.enums.values(PhysicalModule)) |module| {
        default_fx.set(@as(ModulesList, @enumFromInt(@intFromEnum(module))), fallback_map.get(@as(ModulesList, @enumFromInt(@intFromEnum(module)))));
    }

    // proper absolute path for MapStore
    var mem: [std.fs.max_path_bytes]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);
    const config_path = try std.fs.path.resolve(arena.allocator(), &.{ pth, "src/resources/" });
    const config_path_z = try arena.allocator().dupeZ(u8, config_path);

    var ml = MappingsList.init(arena.allocator(), config_path_z);
    var map_store = MapStore.empty(arena.allocator(), config_path_z);
    defer map_store.deinit();

    var track_state = TrackState{};
    defer track_state.deinitMaps(std.testing.allocator);
    var buf: [512:0]u8 = undefined;

    updateTrackState(&track_state, coverage, track, &buf, &map_store, std.testing.allocator, &ml);

    // Because module_locations should be populated for INPUT, GATE, EQ
    try testing.expect(track_state.mode.multi_fx.get(.INPUT) != null);
    try testing.expectEqual(@as(c_int, 0), track_state.mode.multi_fx.get(.INPUT).?.fx_index);

    try testing.expect(track_state.mode.multi_fx.get(.GATE) != null);
    try testing.expectEqual(@as(c_int, 1), track_state.mode.multi_fx.get(.GATE).?.fx_index);

    try testing.expect(track_state.mode.multi_fx.get(.EQ) != null);
    try testing.expectEqual(@as(c_int, 2), track_state.mode.multi_fx.get(.EQ).?.fx_index);

    // COMP and OUTPT should be null
    try testing.expectEqual(@as(?Location, null), track_state.mode.multi_fx.get(.COMP));
    try testing.expectEqual(@as(?Location, null), track_state.mode.multi_fx.get(.OUTPT));
}

test "updateTrackState - fx_count matches module count" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 4);
    defer ctx.teardown();

    const track = reaper.GetTrack(0, 0);

    // Add all 5 modules
    _ = reaper.TrackFX_AddByName(track, "JS: Volume/Pan Smoother v5", false, -1);
    _ = reaper.TrackFX_AddByName(track, "VST: ReaGate (Cockos)", false, -1);
    _ = reaper.TrackFX_AddByName(track, "VST: ReaEQ (Cockos)", false, -1);
    _ = reaper.TrackFX_AddByName(track, "VST: ReaComp (Cockos)", false, -1);
    _ = reaper.TrackFX_AddByName(track, "JS: Saturation", false, -1);

    _ = reaper.TrackFX_SetNamedConfigParm(track, 0, "renamed_name", "JS: Volume/Pan Smoother v5 (C1-I)");
    _ = reaper.TrackFX_SetNamedConfigParm(track, 1, "renamed_name", "VST: ReaGate (Cockos) (C1-S)");
    _ = reaper.TrackFX_SetNamedConfigParm(track, 2, "renamed_name", "VST: ReaEQ (Cockos) (C1-E)");
    _ = reaper.TrackFX_SetNamedConfigParm(track, 3, "renamed_name", "VST: ReaComp (Cockos) (C1-C)");
    _ = reaper.TrackFX_SetNamedConfigParm(track, 4, "renamed_name", "JS: Saturation (C1-O)");

    const coverage = ModuleCoverage{
        .INPUT = .{
            .index = 0,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 0)),
        },
        .GATE = .{
            .index = 1,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 1)),
        },
        .EQ = .{
            .index = 2,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 2)),
        },
        .COMP = .{
            .index = 3,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 3)),
        },
        .OUTPT = .{
            .index = 4,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 4)),
        },
    };

    // Setup proper absolute path for MapStore
    var mem: [std.fs.max_path_bytes]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);
    const config_path = try std.fs.path.resolve(arena.allocator(), &.{ pth, "src/resources/" });
    const config_path_z = try arena.allocator().dupeZ(u8, config_path);

    var ml = MappingsList.init(arena.allocator(), config_path_z);
    var map_store = MapStore.empty(arena.allocator(), config_path_z);
    defer map_store.deinit();

    var track_state = TrackState{};
    defer track_state.deinitMaps(std.testing.allocator);
    var buf: [512:0]u8 = undefined;

    updateTrackState(&track_state, coverage, track, &buf, &map_store, std.testing.allocator, &ml);

    // Because fx_count should equal the number of modules
    try testing.expectEqual(@as(usize, 5), track_state.fx_count);
}

test "updateTrackState - missing mapping handled gracefully" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 4);
    defer ctx.teardown();

    const track = reaper.GetTrack(0, 0);

    // Add a plugin that won't have a mapping
    _ = reaper.TrackFX_AddByName(track, "Nonexistent Plugin", false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(track, 0, "renamed_name", "Nonexistent Plugin (C1-C)");

    const coverage = ModuleCoverage{
        .COMP = .{
            .index = 0,
            .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 0)),
        },
    };

    // Setup proper absolute path for MapStore
    var mem: [std.fs.max_path_bytes]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);
    const config_path = try std.fs.path.resolve(arena.allocator(), &.{ pth, "src/resources/" });
    const config_path_z = try arena.allocator().dupeZ(u8, config_path);

    var ml = MappingsList.init(arena.allocator(), config_path_z);
    var map_store = MapStore.empty(arena.allocator(), config_path_z);
    defer map_store.deinit();

    var track_state = TrackState{};
    defer track_state.deinitMaps(std.testing.allocator);
    var buf: [512:0]u8 = undefined;

    updateTrackState(&track_state, coverage, track, &buf, &map_store, std.testing.allocator, &ml);

    // Because module_locations should still record the FX index even with null mapping
    try testing.expect(track_state.mode.multi_fx.get(.COMP) != null);
    try testing.expectEqual(@as(c_int, 0), track_state.mode.multi_fx.get(.COMP).?.fx_index);
    // Mapping should be null because plugin doesn't exist in MapStore
    try testing.expectEqual(@as(?TaggedMapping, null), track_state.mode.multi_fx.get(.COMP).?.mapping);
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
        if (fx.suffix) |suffix| {
            switch (suffix) {
                .module => |module| {
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
                },
                // Channel strip FX are not processed through the coverage system.
                .channel_strip => {},
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
    allocator: std.mem.Allocator,
    mappings_list: *MappingsList,
) void {
    track_state.fx_count = 0;
    var locs = ModuleLocations.initFill(null);

    inline for (std.meta.fields(ModuleCoverage)) |field| {
        if (@field(coverage, field.name)) |location| {
            _ = reaper.TrackFX_GetNamedConfigParm(
                mediaTrack,
                location.index,
                "original_name",
                buf,
                buf.len,
            );

            const phys_module = @field(PhysicalModule, field.name);
            const module = @field(ModulesList, field.name);
            const tagged_mapping = map_store.get(std.mem.span(@as([*:0]const u8, buf)), module, mappings_list);
            locs.set(phys_module, .{
                .fx_index = location.index,
                .mapping = tagged_mapping,
            });

            if (tagged_mapping) |mapping| {
                populateMapsFromMapping(&track_state.reverse_map, &track_state.forward_map, allocator, mapping, location.index);
            }

            var modules = ActiveModules{};
            @field(modules, field.name) = true;

            track_state.fx_states[track_state.fx_count] = .{
                .fx_index = location.index,
                .modules = modules,
            };
            track_state.fx_count += 1;
        }
    }
    track_state.mode = .{ .multi_fx = locs };
}

fn insertModuleLinkedFx(
    mediaTrack: MediaTrack,
    module: ModulesList,
    insert_pos: i32,
    default_fx: DefaultFx,
    bypass: bool,
) ?struct { index: i32, guid: Guid } {
    const fx_name = default_fx.get(module) orelse return null;

    // Insert FX at position
    const instantiate_arg = if (insert_pos >= 0) -1000 - insert_pos else insert_pos;
    const add_result = pReaper.TrackFX_AddByName(.{
        mediaTrack,
        fx_name,
        false,
        instantiate_arg,
    });

    if (add_result >= 0) {
        // Set module suffix
        var name_buf: [512:0]u8 = undefined;
        const new_name = std.fmt.bufPrintZ(&name_buf, "{s} (C1-{s})", .{ fx_name, module.toModulePrefix() }) catch {
            _ = reaper.TrackFX_Delete(mediaTrack, add_result);
            return null;
        };

        const rename_success = pReaper.TrackFX_SetNamedConfigParm(.{
            mediaTrack,
            add_result,
            "renamed_name",
            new_name,
        });

        if (!rename_success) {
            log.warn("FX '{s}' for module {s} is read-only (missing from disk), removing", .{ fx_name, @tagName(module) });
            _ = reaper.TrackFX_Delete(mediaTrack, add_result);
            return null;
        }

        if (bypass) {
            _ = pReaper.TrackFX_SetEnabled(.{ mediaTrack, add_result, false });
        }

        // Get GUID of newly inserted FX
        const guid_ptr = reaper.TrackFX_GetFXGUID(mediaTrack, add_result);
        const guid = Guid.fromReaperGUID(guid_ptr);

        return .{ .index = add_result, .guid = guid };
    }

    return null;
}

/// Applies index shifts to coverage after moving an FX from one position to another.
/// Because moving an FX removes it from the source position and inserts at the target,
/// this affects indices of FX between the source and target positions.
/// REAPER's TrackFX_CopyToTrack destination index is the final position after the move,
/// not pre-removal. So moving from 0 to 2 places the FX at index 2.
fn applyMove(coverage: *ModuleCoverage, from_index: i32, to_index: i32) void {
    inline for (std.meta.fields(ModuleCoverage)) |field| {
        const field_ptr = &@field(coverage, field.name);
        if (field_ptr.*) |*loc| {
            if (from_index < to_index) {
                // Moving right: items in (from_index, to_index] shift left by 1
                if (loc.index > from_index and loc.index <= to_index) {
                    loc.index -= 1;
                }
            } else if (from_index > to_index) {
                // Moving left: items in [to_index, from_index) shift right by 1
                if (loc.index >= to_index and loc.index < from_index) {
                    loc.index += 1;
                }
            }
        }
    }
}

/// Applies index shifts to coverage after inserting an FX at a specific position.
/// Because inserting an FX shifts all subsequent FX to the right,
/// this affects indices of FX at or after the insert position.
fn applyInsert(coverage: *ModuleCoverage, insert_index: i32) void {
    inline for (std.meta.fields(ModuleCoverage)) |field| {
        const field_ptr = &@field(coverage, field.name);
        if (field_ptr.*) |*loc| {
            // Items at or after insert position shift right by 1
            if (loc.index >= insert_index) {
                loc.index += 1;
            }
        }
    }
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

pub fn reorderFx2(cvrg: ModuleCoverage, mediaTrack: MediaTrack, default_fx: DefaultFx, preferences: Preferences) ModuleCoverage {
    var coverage = cvrg;

    // Insert missing modules if auto_insert_modules is enabled
    if (preferences.auto_insert_modules) {
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

            if (insertModuleLinkedFx(mediaTrack, .INPUT, insert_pos, default_fx, preferences.auto_insert_bypassed)) |result| {
                applyInsert(&coverage, result.index);
                coverage.INPUT = .{ .index = result.index, .guid = result.guid };
            } else {
                log.err("Failed to add INPUT FX", .{});
            }
        }

        // Because we need to insert modules in the user's preferred order,
        // we determine the insertion sequence based on preferences.preferred_module_order
        // and insert modules in that sequence to ensure they end up in the correct positions
        const insertion_order = switch (preferences.preferred_module_order) {
            .@"S-C-EQ" => [_]ModulesList{ .GATE, .COMP, .EQ },
            .@"S-EQ-C" => [_]ModulesList{ .GATE, .EQ, .COMP },
            .@"EQ-S-C" => [_]ModulesList{ .EQ, .GATE, .COMP },
        };

        for (insertion_order) |module| {
            // Because we need to check if each module is missing and insert it,
            // we handle each module type individually
            switch (module) {
                .GATE => {
                    if (coverage.GATE == null) {
                        const insert_pos = blk: {
                            var max_pos: i32 = -1;
                            if (coverage.INPUT) |input| max_pos = @max(max_pos, input.index);
                            if (coverage.COMP) |comp| max_pos = @max(max_pos, comp.index);
                            if (coverage.EQ) |eq| max_pos = @max(max_pos, eq.index);
                            break :blk if (max_pos >= 0) max_pos + 1 else -1;
                        };
                        if (insertModuleLinkedFx(mediaTrack, .GATE, insert_pos, default_fx, preferences.auto_insert_bypassed)) |result| {
                            applyInsert(&coverage, result.index);
                            coverage.GATE = .{ .index = result.index, .guid = result.guid };
                        } else {
                            log.err("Failed to add GATE FX", .{});
                        }
                    }
                },
                .COMP => {
                    if (coverage.COMP == null) {
                        const insert_pos = blk: {
                            var max_pos: i32 = -1;
                            if (coverage.INPUT) |input| max_pos = @max(max_pos, input.index);
                            if (coverage.GATE) |gate| max_pos = @max(max_pos, gate.index);
                            if (coverage.EQ) |eq| max_pos = @max(max_pos, eq.index);
                            break :blk if (max_pos >= 0) max_pos + 1 else -1;
                        };
                        if (insertModuleLinkedFx(mediaTrack, .COMP, insert_pos, default_fx, preferences.auto_insert_bypassed)) |result| {
                            applyInsert(&coverage, result.index);
                            coverage.COMP = .{ .index = result.index, .guid = result.guid };
                        } else {
                            log.err("Failed to add COMP FX", .{});
                        }
                    }
                },
                .EQ => {
                    if (coverage.EQ == null) {
                        const insert_pos = blk: {
                            var max_pos: i32 = -1;
                            if (coverage.INPUT) |input| max_pos = @max(max_pos, input.index);
                            if (coverage.GATE) |gate| max_pos = @max(max_pos, gate.index);
                            if (coverage.COMP) |comp| max_pos = @max(max_pos, comp.index);
                            break :blk if (max_pos >= 0) max_pos + 1 else -1;
                        };
                        if (insertModuleLinkedFx(mediaTrack, .EQ, insert_pos, default_fx, preferences.auto_insert_bypassed)) |result| {
                            applyInsert(&coverage, result.index);
                            coverage.EQ = .{ .index = result.index, .guid = result.guid };
                        } else {
                            log.err("Failed to add EQ FX", .{});
                        }
                    }
                },
                else => unreachable,
            }
        }

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

            if (insertModuleLinkedFx(mediaTrack, .OUTPT, insert_pos, default_fx, preferences.auto_insert_bypassed)) |result| {
                applyInsert(&coverage, result.index);
                coverage.OUTPT = .{ .index = result.index, .guid = result.guid };
            } else {
                log.err("Failed to add OUTPUT FX", .{});
            }
        }
    }

    // Reorder existing modules to canonical order if auto_reorder_modules is enabled
    if (preferences.auto_reorder_modules) {
        const middle_modules_order = switch (preferences.preferred_module_order) {
            .@"S-C-EQ" => [_]ModulesList{ .GATE, .COMP, .EQ },
            .@"S-EQ-C" => [_]ModulesList{ .GATE, .EQ, .COMP },
            .@"EQ-S-C" => [_]ModulesList{ .EQ, .GATE, .COMP },
        };

        if (coverage.INPUT) |*module_loc| {
            const current_index = module_loc.index;
            const target_index: i32 = 0;

            if (current_index != target_index) {
                pReaper.TrackFX_CopyToTrack(.{
                    mediaTrack,
                    current_index,
                    mediaTrack,
                    target_index,
                    true, // move
                });

                applyMove(&coverage, current_index, target_index);
                module_loc.index = target_index;
            }
        }

        // Then, reorder middle modules according to preferred order
        for (middle_modules_order, 0..) |module_type, order_index| {
            const target_index: i32 = @intCast(order_index + 1); // +1 because INPUT is at 0

            const module_loc_ptr = switch (module_type) {
                .GATE => &coverage.GATE,
                .EQ => &coverage.EQ,
                .COMP => &coverage.COMP,
                else => unreachable,
            };

            if (module_loc_ptr.*) |*module_loc| {
                const current_index = module_loc.index;

                if (current_index != target_index) {
                    pReaper.TrackFX_CopyToTrack(.{
                        mediaTrack,
                        current_index,
                        mediaTrack,
                        target_index,
                        true, // move
                    });

                    applyMove(&coverage, current_index, target_index);
                    module_loc.index = target_index;
                }
            }
        }

        // Ensure OUTPT is last if it exists
        if (coverage.OUTPT) |outpt| {
            // Find the highest index among other modules
            var max_other_index: i32 = -1;
            inline for (std.meta.fields(ModuleCoverage)) |field| {
                if (!std.mem.eql(u8, field.name, "OUTPT")) {
                    if (@field(coverage, field.name)) |loc| {
                        max_other_index = @max(max_other_index, loc.index);
                    }
                }
            }

            // If OUTPT is not after all other modules, move it
            if (max_other_index >= 0 and outpt.index <= max_other_index) {
                const target_pos = max_other_index + 1;
                const from_index = outpt.index;
                pReaper.TrackFX_CopyToTrack(.{
                    mediaTrack,
                    from_index,
                    mediaTrack,
                    target_pos,
                    true, // move
                });

                applyMove(&coverage, from_index, target_pos);
                coverage.OUTPT.?.index = target_pos;
            }
        }
    }

    return coverage;
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

/// Module reordering only applies in multi_fx mode
pub fn setModulesOrder(
    self: *TrackState,
    order: ModulesOrder,
    mediaTrack: MediaTrack,
    ref_coverage: ModuleCoverage,
) void {
    const locs = self.getModuleLocations() orelse return;

    var coverage = ref_coverage;
    // Early return if we don't have all three modules
    const eq_loc = locs.get(.EQ);
    const gate_loc = locs.get(.GATE);
    const comp_loc = locs.get(.COMP);

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

    const from_index = eq_loc.?.fx_index;
    pReaper.TrackFX_CopyToTrack(.{ mediaTrack, from_index, mediaTrack, eq_target_pos, true });

    // Update coverage positions with manual tracking
    applyMove(&coverage, from_index, eq_target_pos);
    coverage.EQ.?.index = eq_target_pos;

    // Update mode with new positions
    inline for (comptime std.enums.values(PhysicalModule)) |module| {
        const pos = switch (module) {
            inline else => |impl| @field(coverage, @tagName(impl)),
        };
        if (pos) |module_coverage| {
            if (locs.get(module)) |loc| {
                locs.set(module, .{
                    .fx_index = module_coverage.index,
                    .mapping = loc.mapping,
                });
            }
        }
    }
}

pub fn getModulesOrder(self: TrackState) ModulesOrder {
    const locs = switch (self.mode) {
        .multi_fx => |l| l,
        .channel_strip => return .@"S-EQ-C",
    };
    // Gate before Comp is guaranteed by reorderFx
    const eq_loc = locs.get(.EQ);
    const gate_loc = locs.get(.GATE);
    const comp_loc = locs.get(.COMP);

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
    const locs = self.getModuleLocations() orelse return null;
    var first_idx: ?i32 = null;
    inline for (comptime std.enums.values(PhysicalModule)) |module| {
        if (locs.get(module)) |location| {
            if (first_idx == null or location.fx_index < first_idx.?) {
                first_idx = location.fx_index;
            }
        }
    }
    return first_idx;
}

pub fn getLastModuleIndex(self: *TrackState) ?i32 {
    const locs = self.getModuleLocations() orelse return null;
    var last_idx: ?i32 = null;
    inline for (comptime std.enums.values(PhysicalModule)) |module| {
        if (locs.get(module)) |location| {
            if (last_idx == null or location.fx_index > last_idx.?) {
                last_idx = location.fx_index;
            }
        }
    }
    return last_idx;
}

/// test helper
fn createDefaultFx() DefaultFx {
    const settings_mod = @import("settings.zig");
    const fallback_map = settings_mod.fallback_defaults;
    var default_fx = DefaultFx.initFill(null);
    inline for (comptime std.enums.values(PhysicalModule)) |module| {
        default_fx.set(
            @as(ModulesList, @enumFromInt(@intFromEnum(module))),
            fallback_map.get(@as(ModulesList, @enumFromInt(@intFromEnum(module)))),
        );
    }
    return default_fx;
}

test "reorderFx2 - property-based ordering validation" {
    const testing = std.testing;
    const iterations = 100;

    // Setup ONCE: Create arena allocator outside the loop
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    for (0..iterations) |_| {
        // Setup mock REAPER context (reuses arena)
        var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 4);
        defer ctx.teardown();

        // Generate random bytes for this iteration
        var random_bytes: [64]u8 = undefined;
        std.crypto.random.bytes(&random_bytes);
        var prng = std.Random.DefaultPrng.init(@as(u64, @bitCast(random_bytes[0..8].*)));
        var random = prng.random();

        // Create random permutation and add modules
        const track = reaper.GetTrack(0, 0);
        var module_order = [_]ModulesList{ .INPUT, .GATE, .EQ, .COMP, .OUTPT };
        random.shuffle(ModulesList, &module_order);

        // Add FX in shuffled order
        for (module_order) |module| {
            const fx_name = switch (module) {
                .INPUT => "JS: Volume/Pan Smoother v5",
                .GATE => "VST: ReaGate (Cockos)",
                .EQ => "VST: ReaEQ (Cockos)",
                .COMP => "VST: ReaComp (Cockos)",
                .OUTPT => "JS: Saturation",
                .STRIP => continue,
            };
            _ = reaper.TrackFX_AddByName(track, fx_name, false, -1);
            const idx = reaper.TrackFX_GetCount(track) - 1;

            // Set module suffix
            var buf: [256:0]u8 = undefined;
            const renamed = std.fmt.bufPrintZ(&buf, "{s} (C1-{s})", .{
                fx_name,
                module.toModulePrefix(),
            }) catch unreachable;
            _ = reaper.TrackFX_SetNamedConfigParm(track, idx, "renamed_name", renamed);
        }

        // Create coverage from shuffled state
        var parsed_fx_buf: [MAX_PARSED_FX]ParsedFx = undefined;
        var parsed_fx = std.ArrayListUnmanaged(ParsedFx).initBuffer(&parsed_fx_buf);

        for (0..5) |i| {
            const idx: i32 = @intCast(i);
            var name_buf: [512:0]u8 = undefined;
            _ = reaper.TrackFX_GetNamedConfigParm(track, idx, "renamed_name", &name_buf, name_buf.len);
            const name = std.mem.span(@as([*:0]const u8, &name_buf));

            if (parseC1Suffix(name)) |suffix| {
                parsed_fx.appendAssumeCapacity(.{
                    .index = idx,
                    .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, idx)),
                    .suffix = suffix,
                });
            }
        }

        const coverage = analyzeCoverage(&parsed_fx, track);

        // Call reorderFx2
        const default_fx = createDefaultFx();
        const result = reorderFx2(coverage, track, default_fx, .empty);

        // Assert ordering rules
        // Rule 1: INPUT is always first
        try testing.expectEqual(@as(c_int, 0), result.INPUT.?.index);

        // Rule 2: OUTPT is always last
        try testing.expect(result.OUTPT.?.index > result.INPUT.?.index);
        try testing.expect(result.OUTPT.?.index > result.GATE.?.index);
        try testing.expect(result.OUTPT.?.index > result.EQ.?.index);
        try testing.expect(result.OUTPT.?.index > result.COMP.?.index);

        // Rule 3: GATE is always before COMP
        try testing.expect(result.GATE.?.index < result.COMP.?.index);
    }
}

test "reorderFx2 - auto_insert_modules disabled" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 4);
    defer ctx.teardown();

    const track = reaper.GetTrack(0, 0);

    const empty_coverage = ModuleCoverage{};

    const settings_mod = @import("settings.zig");
    const fallback_map = settings_mod.fallback_defaults;
    var default_fx = DefaultFx.initFill(null);
    inline for (comptime std.enums.values(PhysicalModule)) |module| {
        default_fx.set(
            @as(ModulesList, @enumFromInt(@intFromEnum(module))),
            fallback_map.get(@as(ModulesList, @enumFromInt(@intFromEnum(module)))),
        );
    }

    var prefs: Preferences = .empty;
    prefs.auto_insert_modules = false;

    const result_coverage = reorderFx2(empty_coverage, track, default_fx, prefs);

    // Because auto_insert_modules is false, no modules should be inserted
    try testing.expect(result_coverage.INPUT == null);
    try testing.expect(result_coverage.GATE == null);
    try testing.expect(result_coverage.EQ == null);
    try testing.expect(result_coverage.COMP == null);
    try testing.expect(result_coverage.OUTPT == null);
}

test "reorderFx2 - auto_reorder_modules disabled" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var ctx = MockReaper.setupTestModel(arena.allocator(), 1, 6);
    defer ctx.teardown();

    const track = reaper.GetTrack(0, 0);

    const settings_mod = @import("settings.zig");
    const fallback_map = settings_mod.fallback_defaults;
    var default_fx = DefaultFx.initFill(null);
    inline for (comptime std.enums.values(PhysicalModule)) |module| {
        default_fx.set(
            @as(ModulesList, @enumFromInt(@intFromEnum(module))),
            fallback_map.get(@as(ModulesList, @enumFromInt(@intFromEnum(module)))),
        );
    }

    // Add FX in wrong order
    _ = reaper.TrackFX_AddByName(track, fallback_map.get(.OUTPT).?, false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(track, 0, "renamed_name", "JS: Saturation (C1-O)");
    _ = reaper.TrackFX_AddByName(track, fallback_map.get(.COMP).?, false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(track, 1, "renamed_name", "VST: ReaComp (C1-C)");
    _ = reaper.TrackFX_AddByName(track, fallback_map.get(.EQ).?, false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(track, 2, "renamed_name", "VST: ReaEQ (C1-E)");
    _ = reaper.TrackFX_AddByName(track, fallback_map.get(.GATE).?, false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(track, 3, "renamed_name", "VST: ReaGate (C1-S)");
    _ = reaper.TrackFX_AddByName(track, fallback_map.get(.INPUT).?, false, -1);
    _ = reaper.TrackFX_SetNamedConfigParm(track, 4, "renamed_name", "JS: Volume/Pan (C1-I)");

    const wrong_coverage = ModuleCoverage{
        .INPUT = .{ .index = 4, .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 4)) },
        .GATE = .{ .index = 3, .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 3)) },
        .EQ = .{ .index = 2, .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 2)) },
        .COMP = .{ .index = 1, .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 1)) },
        .OUTPT = .{ .index = 0, .guid = Guid.fromReaperGUID(reaper.TrackFX_GetFXGUID(track, 0)) },
    };

    var prefs: Preferences = .empty;
    prefs.auto_reorder_modules = false;

    const result_coverage = reorderFx2(wrong_coverage, track, default_fx, prefs);

    // Because auto_reorder_modules is false, modules should stay in wrong positions
    try testing.expectEqual(@as(c_int, 4), result_coverage.INPUT.?.index);
    try testing.expectEqual(@as(c_int, 3), result_coverage.GATE.?.index);
    try testing.expectEqual(@as(c_int, 2), result_coverage.EQ.?.index);
    try testing.expectEqual(@as(c_int, 1), result_coverage.COMP.?.index);
    try testing.expectEqual(@as(c_int, 0), result_coverage.OUTPT.?.index);
}
