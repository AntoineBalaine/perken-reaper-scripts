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

pub fn validateTrack(track_state: *TrackState, mediaTrack: reaper.MediaTrack, default_fx: DefaultFx, map_store: *MapStore) ModuleCoverage {
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
    coverage = reorderFx2(coverage, mediaTrack, default_fx);
    updateTrackState(track_state, coverage, mediaTrack, &buf, map_store);
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
    try testing.expectEqual(.INPUT, parseC1Suffix("Some Plugin (C1-I)").?);

    try testing.expectEqual(.COMP, parseC1Suffix("ReaComp (C1-C)").?);

    // Invalid cases
    try testing.expectEqual(@as(?ModulesList, null), parseC1Suffix("No Suffix Plugin"));

    try testing.expectEqual(@as(?ModulesList, null), parseC1Suffix("Invalid (C1"));

    // Ignore invalid characters
    try testing.expectEqual(.INPUT, parseC1Suffix("Plugin (C1-IX)").?);
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
