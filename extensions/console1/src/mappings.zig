const std = @import("std");
const ini = @import("ini");
const settings = @import("settings.zig");
const statemachine = @import("statemachine.zig");
const c1 = @import("c1.zig");
const ModulesList = statemachine.ModulesList;
const PhysicalModule = statemachine.PhysicalModule;
const fs_helpers = @import("fs_helpers.zig");
const StringPool = @import("string_pool.zig").StringPool;
const preset_file_reader = @import("preset_file_reader.zig");
const log = std.log.scoped(.mappings);

pub const MAPPING_FORMAT_VERSION = 1;

pub const Comp = struct {
    version: u8 = MAPPING_FORMAT_VERSION,
    fx_preset: ?StringPool.StringRef = null,
    Comp_Attack: ?u16 = null,
    Comp_DryWet: ?u16 = null,
    Comp_Ratio: ?u16 = null,
    Comp_Release: ?u16 = null,
    Comp_Thresh: ?u16 = null,
    Comp_comp: ?u16 = null,
    Comp_HiCut: ?u16 = null,
    Comp_LoCut: ?u16 = null,
    // Comp_Mtr : u8,
};

pub const Eq = struct {
    version: u8 = MAPPING_FORMAT_VERSION,
    fx_preset: ?StringPool.StringRef = null,
    Eq_HiFrq: ?u16 = null,
    Eq_HiGain: ?u16 = null,
    Eq_HiMidFrq: ?u16 = null,
    Eq_HiMidGain: ?u16 = null,
    Eq_HiMidQ: ?u16 = null,
    Eq_LoFrq: ?u16 = null,
    Eq_LoGain: ?u16 = null,
    Eq_LoMidFrq: ?u16 = null,
    Eq_LoMidGain: ?u16 = null,
    Eq_LoMidQ: ?u16 = null,
    Eq_eq: ?u16 = null,
    Eq_hp_shape: ?u16 = null,
    Eq_lp_shape: ?u16 = null,
};

pub const Inpt = struct {
    version: u8 = MAPPING_FORMAT_VERSION,
    fx_preset: ?StringPool.StringRef = null,
    // Inpt_MtrLft : u8 = 0 ,
    // Inpt_MtrRgt : u8 = 0 ,
    Inpt_Gain: ?u16 = null,
    Inpt_HiCut: ?u16 = null,
    Inpt_LoCut: ?u16 = null,
    Inpt_disp_mode: ?u16 = null,
    Inpt_disp_on: ?u16 = null,
    Inpt_filt_to_comp: ?u16 = null,
    // Inpt_phase_inv: ?u16 = null,  // Track parameter only, not mappable to FX
    Inpt_preset: ?u16 = null,
};

pub const Outpt = struct {
    version: u8 = MAPPING_FORMAT_VERSION,
    fx_preset: ?StringPool.StringRef = null,
    Out_Drive: ?u16 = null,
    Out_DriveChar: ?u16 = null,
    // Out_MtrLft : u8 = null,
    // Out_MtrRgt : u8 = null,
    Out_Pan: ?u16 = null,
    Out_Vol: ?u16 = null,
    // Out_mute : u8 = null,
    // Out_solo : u8 = null,
};

pub const Shp = struct {
    version: u8 = MAPPING_FORMAT_VERSION,
    fx_preset: ?StringPool.StringRef = null,
    Shp_Gate: ?u16 = null,
    Shp_GateRelease: ?u16 = null,
    Shp_Punch: ?u16 = null,
    Shp_hard_gate: ?u16 = null,
    Shp_shape: ?u16 = null,
    Shp_sustain: ?u16 = null,
};

/// A flattened mapping for channel strip FX that contain all Console1 sections
/// in a single plugin. Each field is an optional parameter index within the FX.
/// Because channel strip mode repurposes Tr_ext_sidechain and Tr_order as freely
/// assignable parameters, they are included here.
pub const ChannelStripMapping = struct {
    version: u8 = MAPPING_FORMAT_VERSION,
    fx_preset: ?StringPool.StringRef = null,

    // Input section
    Inpt_Gain: ?u16 = null,
    Inpt_HiCut: ?u16 = null,
    Inpt_LoCut: ?u16 = null,
    Inpt_disp_mode: ?u16 = null,
    Inpt_disp_on: ?u16 = null,
    Inpt_filt_to_comp: ?u16 = null,
    Inpt_preset: ?u16 = null,

    // Gate/Shape section
    Shp_Gate: ?u16 = null,
    Shp_GateRelease: ?u16 = null,
    Shp_Punch: ?u16 = null,
    Shp_hard_gate: ?u16 = null,
    Shp_shape: ?u16 = null,
    Shp_sustain: ?u16 = null,

    // EQ section
    Eq_HiFrq: ?u16 = null,
    Eq_HiGain: ?u16 = null,
    Eq_HiMidFrq: ?u16 = null,
    Eq_HiMidGain: ?u16 = null,
    Eq_HiMidQ: ?u16 = null,
    Eq_LoFrq: ?u16 = null,
    Eq_LoGain: ?u16 = null,
    Eq_LoMidFrq: ?u16 = null,
    Eq_LoMidGain: ?u16 = null,
    Eq_LoMidQ: ?u16 = null,
    Eq_eq: ?u16 = null,
    Eq_hp_shape: ?u16 = null,
    Eq_lp_shape: ?u16 = null,

    // Compressor section
    Comp_Attack: ?u16 = null,
    Comp_DryWet: ?u16 = null,
    Comp_Ratio: ?u16 = null,
    Comp_Release: ?u16 = null,
    Comp_Thresh: ?u16 = null,
    Comp_comp: ?u16 = null,

    // Output section
    Out_Drive: ?u16 = null,
    Out_DriveChar: ?u16 = null,
    Out_Pan: ?u16 = null,
    Out_Vol: ?u16 = null,

    // Reassignable controls (no fixed meaning in channel strip mode)
    Tr_ext_sidechain: ?u16 = null,
    Tr_order: ?u16 = null,
};

/// Tagged union representing a loaded mapping for any module type.
/// null indicates no mapping was found or loading failed - or was never set.
pub const TaggedMapping = union(ModulesList) {
    INPUT: Inpt,
    GATE: Shp,
    EQ: Eq,
    COMP: Comp,
    OUTPT: Outpt,
    STRIP: ChannelStripMapping,
    pub fn empty(mode: ModulesList) TaggedMapping {
        return switch (mode) {
            .INPUT => .{ .INPUT = Inpt{} },
            .GATE => .{ .GATE = Shp{} },
            .EQ => .{ .EQ = Eq{} },
            .COMP => .{ .COMP = Comp{} },
            .OUTPT => .{ .OUTPT = Outpt{} },
            .STRIP => .{ .STRIP = ChannelStripMapping{} },
        };
    }
};

/// FxMaps stores multiple mappings for a single FX.
/// Because we need to support multiple mappings per FX, we key on file paths instead of just FX names.
pub fn FxMaps(comptime T: type) type {
    return struct {
        mappings: std.StringArrayHashMapUnmanaged(?T),
        preferred_mapping: [:0]const u8,

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            // Because MapStore uses an arena allocator in both production and tests,
            // we don't need to free individual keys - they'll be freed when the arena is deinitialized.
            // The keys are file path strings allocated with allocator.dupeZ.
            // preferred_mapping points to one of the keys in the hashmap.
            self.mappings.deinit(allocator);
        }
    };
}

/// MapStore manages FX parameter mappings with lazy loading.
/// Mappings are loaded from disk only when requested and cached for future use.
pub const MapStore = @This();

COMP: std.StringArrayHashMapUnmanaged(FxMaps(Comp)),
EQ: std.StringArrayHashMapUnmanaged(FxMaps(Eq)),
INPUT: std.StringArrayHashMapUnmanaged(FxMaps(Inpt)),
OUTPT: std.StringArrayHashMapUnmanaged(FxMaps(Outpt)),
GATE: std.StringArrayHashMapUnmanaged(FxMaps(Shp)),
STRIP: std.StringArrayHashMapUnmanaged(FxMaps(ChannelStripMapping)),
controller_dir: [*:0]const u8,
allocator: std.mem.Allocator,
preset_strings: StringPool,
pub fn empty(allocator: std.mem.Allocator, controller_dir: [*:0]const u8) @This() {
    const self: MapStore = .{
        .INPUT = std.StringArrayHashMapUnmanaged(FxMaps(Inpt)){},
        .GATE = std.StringArrayHashMapUnmanaged(FxMaps(Shp)){},
        .EQ = std.StringArrayHashMapUnmanaged(FxMaps(Eq)){},
        .COMP = std.StringArrayHashMapUnmanaged(FxMaps(Comp)){},
        .OUTPT = std.StringArrayHashMapUnmanaged(FxMaps(Outpt)){},
        .STRIP = std.StringArrayHashMapUnmanaged(FxMaps(ChannelStripMapping)){},
        .controller_dir = controller_dir,
        .allocator = allocator,
        .preset_strings = .empty,
    };
    return self;
}

pub fn init(allocator: std.mem.Allocator, controller_dir: [*:0]const u8, ml: *MappingsList, defaults: *settings.DefaultFx) !MapStore {
    var self: MapStore = .empty(allocator, controller_dir);
    // find the mappings for the defaults
    var iterator = defaults.iterator();
    while (iterator.next()) |defaultsEntry| {
        const fxName = defaultsEntry.value.*;

        if (fxName) |fx_name| {
            // use self.getMap() only for its side-effect: storing into the map.
            // Its return value is only meant to be used by self.get()
            _ = self.getMap(fx_name, defaultsEntry.key, "default", ml) catch {
                continue;
            };
        }
    }
    return self;
}

pub fn deinit(self: *MapStore) void {
    log.debug("Cleaning up MapStore", .{});

    self.preset_strings.deinit(self.allocator);

    // Clean up nested FxMaps structures
    var comp_iter = self.COMP.iterator();
    while (comp_iter.next()) |entry| {
        entry.value_ptr.deinit(self.allocator);
    }
    self.COMP.deinit(self.allocator);

    var eq_iter = self.EQ.iterator();
    while (eq_iter.next()) |entry| {
        entry.value_ptr.deinit(self.allocator);
    }
    self.EQ.deinit(self.allocator);

    var input_iter = self.INPUT.iterator();
    while (input_iter.next()) |entry| {
        entry.value_ptr.deinit(self.allocator);
    }
    self.INPUT.deinit(self.allocator);

    var outpt_iter = self.OUTPT.iterator();
    while (outpt_iter.next()) |entry| {
        entry.value_ptr.deinit(self.allocator);
    }
    self.OUTPT.deinit(self.allocator);

    var gate_iter = self.GATE.iterator();
    while (gate_iter.next()) |entry| {
        entry.value_ptr.deinit(self.allocator);
    }
    self.GATE.deinit(self.allocator);

    var strip_iter = self.STRIP.iterator();
    while (strip_iter.next()) |entry| {
        entry.value_ptr.deinit(self.allocator);
    }
    self.STRIP.deinit(self.allocator);
}

pub fn getModuleByName(self: *MapStore, fx_name: [:0]const u8) ?ModulesList {
    inline for (comptime std.enums.values(ModulesList)) |module| {
        const field_name = @tagName(module);
        const map = &@field(self, field_name);
        if (map.contains(fx_name)) {
            return module;
        }
    }
    return null;
}

/// Retrieves a channel strip mapping for the given FX name.
/// If the mapping is not in the cache, we attempt to load it from disk.
/// Saves a channel strip mapping to disk at `maps/STRIP/<fx_name>/<mapping_name>.ini`
pub fn saveStripToFile(
    self: *MapStore,
    fs_ops: fs_helpers.FileSystemOps,
    fx_name: [:0]const u8,
    mapping: ChannelStripMapping,
    mapping_name: [:0]const u8,
    embedded_preset: ?preset_file_reader.EmbeddedPreset,
) !void {
    var name_buf: [512:0]u8 = undefined;
    const sanitized_name = try fs_helpers.sanitizeFxName(&name_buf, fx_name);

    var dir_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = fs_helpers.joinStrings(&dir_path_buf, &.{
        std.mem.span(self.controller_dir),
        std.fs.path.sep_str,
        "maps",
        std.fs.path.sep_str,
        "STRIP",
        std.fs.path.sep_str,
        sanitized_name,
    });

    fs_ops.makeDirAbsolute(dir_path) catch |err| {
        if (err != error.PathAlreadyExists) {
            log.err("Failed to create strip directory: {s}", .{@errorName(err)});
            return err;
        }
    };

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = fs_helpers.joinStrings(&path_buf, &.{
        std.mem.span(self.controller_dir),
        std.fs.path.sep_str,
        "maps",
        std.fs.path.sep_str,
        "STRIP",
        std.fs.path.sep_str,
        sanitized_name,
        std.fs.path.sep_str,
        mapping_name,
        ".ini",
    });

    const file = try fs_ops.createFileAbsolute(path, .{
        .read = true,
        .truncate = true,
    });
    defer file.close();

    var writer = file.writer();

    // Because fx_preset is a StringPool offset (not a raw integer),
    // we write it as a string before the generic field loop
    if (mapping.fx_preset) |offset| {
        try writer.print("fx_preset={s}\n", .{self.preset_strings.get(offset)});
    }

    inline for (std.meta.fields(ChannelStripMapping)) |field| {
        if (comptime std.mem.eql(u8, field.name, "fx_preset")) continue;
        try writer.print("{s} = ", .{field.name});
        try formatOptionalU8(@field(mapping, field.name), writer);
        try writer.writeByte('\n');
    }

    // Because preset data fields are not stored in the mapping structs,
    // we write them from the caller-provided parameters
    if (embedded_preset) |ep| {
        try writer.print("fx_preset_file={s}\n", .{ep.file});
        try writer.print("fx_preset_data={s}\n", .{ep.data});
        try writer.print("fx_preset_len={d}\n", .{ep.len});
    }
}

/// find fx mapping in storage. If unfound, search it from disk. If still unfound, return null.
/// Because we now store multiple mappings per FX, we return the preferred mapping.
pub fn get(self: *MapStore, fxName: [:0]const u8, module: ModulesList, ml: *MappingsList) ?TaggedMapping {
    switch (module) {
        .COMP => {
            if (self.COMP.get(fxName)) |mappings_list| {
                // Get the preferred mapping from the list
                if (mappings_list.mappings.get(mappings_list.preferred_mapping)) |maybe_comp| {
                    if (maybe_comp) |comp| {
                        return TaggedMapping{ .COMP = comp };
                    }
                }
                return null;
            } else {
                log.debug("mapping {s} unfound", .{fxName});
                return self.getMap(fxName, module, "default", ml) catch null;
            }
        },
        .EQ => {
            if (self.EQ.get(fxName)) |mappings_list| {
                if (mappings_list.mappings.get(mappings_list.preferred_mapping)) |maybe_eq| {
                    if (maybe_eq) |eq| {
                        return TaggedMapping{ .EQ = eq };
                    }
                }
                return null;
            } else {
                log.debug("mapping {s} unfound", .{fxName});
                return self.getMap(fxName, module, "default", ml) catch null;
            }
        },
        .INPUT => {
            if (self.INPUT.get(fxName)) |mappings_list| {
                if (mappings_list.mappings.get(mappings_list.preferred_mapping)) |maybe_inpt| {
                    if (maybe_inpt) |inpt| {
                        return TaggedMapping{ .INPUT = inpt };
                    }
                }
                return null;
            } else {
                log.debug("mapping {s} unfound", .{fxName});
                return self.getMap(fxName, module, "default", ml) catch null;
            }
        },
        .OUTPT => {
            if (self.OUTPT.get(fxName)) |mappings_list| {
                if (mappings_list.mappings.get(mappings_list.preferred_mapping)) |maybe_outpt| {
                    if (maybe_outpt) |outpt| {
                        return TaggedMapping{ .OUTPT = outpt };
                    }
                }
                return null;
            } else {
                log.debug("mapping {s} unfound", .{fxName});
                return self.getMap(fxName, module, "default", ml) catch null;
            }
        },
        .GATE => {
            if (self.GATE.get(fxName)) |mappings_list| {
                if (mappings_list.mappings.get(mappings_list.preferred_mapping)) |maybe_shp| {
                    if (maybe_shp) |shp| {
                        return TaggedMapping{ .GATE = shp };
                    }
                }
                return null;
            } else {
                log.debug("mapping {s} unfound", .{fxName});
                return self.getMap(fxName, module, "default", ml) catch null;
            }
        },
        .STRIP => {
            if (self.STRIP.get(fxName)) |mappings_list| {
                if (mappings_list.mappings.get(mappings_list.preferred_mapping)) |maybe_strip| {
                    if (maybe_strip) |strip| {
                        return TaggedMapping{ .STRIP = strip };
                    }
                }
                return null;
            } else {
                log.debug("mapping {s} unfound", .{fxName});
                return self.getMap(fxName, module, "default", ml) catch null;
            }
        },
    }
}

/// Set the preferred mapping for an FX.
/// Because the preferred mapping determines which mapping is returned by get(), we update the FxMaps.
/// Avoid silent failures by validating filepath
pub fn setPreferredMapping(self: *MapStore, fx_name: [:0]const u8, module: ModulesList, filepath: [:0]const u8) !void {
    switch (module) {
        .COMP => {
            if (self.COMP.getPtr(fx_name)) |mappings_list| {
                if (!mappings_list.mappings.contains(filepath)) {
                    return error.MappingNotFound;
                }
                mappings_list.preferred_mapping = filepath;
            } else {
                return error.FxNotFound;
            }
        },
        .EQ => {
            if (self.EQ.getPtr(fx_name)) |mappings_list| {
                if (!mappings_list.mappings.contains(filepath)) {
                    return error.MappingNotFound;
                }
                mappings_list.preferred_mapping = filepath;
            } else {
                return error.FxNotFound;
            }
        },
        .INPUT => {
            if (self.INPUT.getPtr(fx_name)) |mappings_list| {
                if (!mappings_list.mappings.contains(filepath)) {
                    return error.MappingNotFound;
                }
                mappings_list.preferred_mapping = filepath;
            } else {
                return error.FxNotFound;
            }
        },
        .OUTPT => {
            if (self.OUTPT.getPtr(fx_name)) |mappings_list| {
                if (!mappings_list.mappings.contains(filepath)) {
                    return error.MappingNotFound;
                }
                mappings_list.preferred_mapping = filepath;
            } else {
                return error.FxNotFound;
            }
        },
        .GATE => {
            if (self.GATE.getPtr(fx_name)) |mappings_list| {
                if (!mappings_list.mappings.contains(filepath)) {
                    return error.MappingNotFound;
                }
                mappings_list.preferred_mapping = filepath;
            } else {
                return error.FxNotFound;
            }
        },
        .STRIP => {
            if (self.STRIP.getPtr(fx_name)) |mappings_list| {
                if (!mappings_list.mappings.contains(filepath)) {
                    return error.MappingNotFound;
                }
                mappings_list.preferred_mapping = filepath;
            } else {
                return error.FxNotFound;
            }
        },
    }
}

/// Get the preferred mapping filepath for an FX.
pub fn getPreferredMapping(self: *MapStore, fx_name: [:0]const u8, module: ModulesList) ?[:0]const u8 {
    switch (module) {
        .COMP => {
            if (self.COMP.get(fx_name)) |mappings_list| {
                return mappings_list.preferred_mapping;
            }
            return null;
        },
        .EQ => {
            if (self.EQ.get(fx_name)) |mappings_list| {
                return mappings_list.preferred_mapping;
            }
            return null;
        },
        .INPUT => {
            if (self.INPUT.get(fx_name)) |mappings_list| {
                return mappings_list.preferred_mapping;
            }
            return null;
        },
        .OUTPT => {
            if (self.OUTPT.get(fx_name)) |mappings_list| {
                return mappings_list.preferred_mapping;
            }
            return null;
        },
        .GATE => {
            if (self.GATE.get(fx_name)) |mappings_list| {
                return mappings_list.preferred_mapping;
            }
            return null;
        },
        .STRIP => {
            if (self.STRIP.get(fx_name)) |mappings_list| {
                return mappings_list.preferred_mapping;
            }
            return null;
        },
    }
}

/// Returns the preset name associated with the preferred mapping for the given FX,
/// or null if no preset is set. This only looks at already-cached mappings and
/// does not trigger lazy loading from disk.
pub fn getPresetName(self: *MapStore, fxName: [:0]const u8, module: ModulesList) ?[:0]const u8 {
    switch (module) {
        inline else => |tag| {
            const map = &@field(self, @tagName(tag));
            const ml = map.get(fxName) orelse return null;
            const m = ml.mappings.get(ml.preferred_mapping) orelse return null;
            const mapping = m orelse return null;
            return if (mapping.fx_preset) |o| self.preset_strings.get(o) else null;
        },
    }
}

/// fetch mapping from disk, parse it, store it, and return it.
/// Because the mappings_list index knows the absolute path for each mapping,
/// we look up the path there instead of constructing it ourselves.
pub fn getMap(self: *MapStore, fxName: [:0]const u8, module: ModulesList, mapping_name: [:0]const u8, ml: *MappingsList) !TaggedMapping {
    const filePath_z = ml.lookupPath(module, fxName, mapping_name) orelse return error.FileNotFound;
    const filePath: []const u8 = filePath_z;

    log.debug("Loading mapping from {s}", .{filePath});

    if (!std.fs.path.isAbsolute(filePath)) {
        const config = @import("config");
        if (@hasDecl(config, "test") and @field(config, "test")) {
            log.debug("Mapping path is not absolute: {s}", .{filePath});
        } else {
            log.err("Mapping path is not absolute: {s}", .{filePath});
        }
        return error.InvalidPath;
    }

    const file = try std.fs.openFileAbsolute(filePath, .{});
    defer file.close();

    var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer temp_arena.deinit();
    var parser = ini.parse(temp_arena.allocator(), file.reader());
    defer parser.deinit(); // doesn’t actually do anything because of arena

    var found_module: ?ModulesList = null;

    const mapping: TaggedMapping = switch (module) {
        .COMP => {
            var comp = Comp{};
            _ = try readToU8Struct(&comp, &parser, &found_module, &self.preset_strings, self.allocator);

            if (found_module) |m| {
                if (m != module) return error.ModuleMismatch;
            }

            var gop = try self.COMP.getOrPut(self.allocator, fxName);
            if (!gop.found_existing) {
                gop.value_ptr.* = FxMaps(Comp){
                    .mappings = std.StringArrayHashMapUnmanaged(?Comp){},
                    .preferred_mapping = filePath_z,
                };
            }

            try gop.value_ptr.mappings.put(self.allocator, filePath_z, comp);

            return TaggedMapping{ .COMP = comp };
        },
        .EQ => {
            var eq = Eq{};
            _ = try readToU8Struct(&eq, &parser, &found_module, &self.preset_strings, self.allocator);

            if (found_module) |m| {
                if (m != module) return error.ModuleMismatch;
            }

            var gop = try self.EQ.getOrPut(self.allocator, fxName);
            if (!gop.found_existing) {
                gop.value_ptr.* = FxMaps(Eq){
                    .mappings = std.StringArrayHashMapUnmanaged(?Eq){},
                    .preferred_mapping = filePath_z,
                };
            }

            try gop.value_ptr.mappings.put(self.allocator, filePath_z, eq);

            return TaggedMapping{ .EQ = eq };
        },
        .INPUT => {
            var inpt: Inpt = Inpt{};
            _ = try readToU8Struct(&inpt, &parser, &found_module, &self.preset_strings, self.allocator);

            if (found_module) |m| {
                if (m != module) return error.ModuleMismatch;
            }

            var gop = try self.INPUT.getOrPut(self.allocator, fxName);
            if (!gop.found_existing) {
                gop.value_ptr.* = FxMaps(Inpt){
                    .mappings = std.StringArrayHashMapUnmanaged(?Inpt){},
                    .preferred_mapping = filePath_z,
                };
            }

            try gop.value_ptr.mappings.put(self.allocator, filePath_z, inpt);

            return TaggedMapping{ .INPUT = inpt };
        },
        .OUTPT => {
            var outpt: Outpt = Outpt{};
            _ = try readToU8Struct(&outpt, &parser, &found_module, &self.preset_strings, self.allocator);

            if (found_module) |m| {
                if (m != module) return error.ModuleMismatch;
            }

            var gop = try self.OUTPT.getOrPut(self.allocator, fxName);
            if (!gop.found_existing) {
                gop.value_ptr.* = FxMaps(Outpt){
                    .mappings = std.StringArrayHashMapUnmanaged(?Outpt){},
                    .preferred_mapping = filePath_z,
                };
            }

            try gop.value_ptr.mappings.put(self.allocator, filePath_z, outpt);

            return TaggedMapping{ .OUTPT = outpt };
        },
        .GATE => {
            var shp: Shp = Shp{};
            _ = try readToU8Struct(&shp, &parser, &found_module, &self.preset_strings, self.allocator);

            if (found_module) |m| {
                if (m != module) return error.ModuleMismatch;
            }

            var gop = try self.GATE.getOrPut(self.allocator, fxName);
            if (!gop.found_existing) {
                gop.value_ptr.* = FxMaps(Shp){
                    .mappings = std.StringArrayHashMapUnmanaged(?Shp){},
                    .preferred_mapping = filePath_z,
                };
            }

            try gop.value_ptr.mappings.put(self.allocator, filePath_z, shp);

            return TaggedMapping{ .GATE = shp };
        },
        .STRIP => {
            var strip = ChannelStripMapping{};
            _ = try readToU8Struct(&strip, &parser, &found_module, &self.preset_strings, self.allocator);

            if (found_module) |m| {
                if (m != module) return error.ModuleMismatch;
            }

            var gop = try self.STRIP.getOrPut(self.allocator, fxName);
            if (!gop.found_existing) {
                gop.value_ptr.* = FxMaps(ChannelStripMapping){
                    .mappings = std.StringArrayHashMapUnmanaged(?ChannelStripMapping){},
                    .preferred_mapping = filePath_z,
                };
            }

            try gop.value_ptr.mappings.put(self.allocator, filePath_z, strip);

            return TaggedMapping{ .STRIP = strip };
        },
    };

    return mapping;
}

/// parse comp/eq/gate/input/output structs, and extract the module field if present.
/// Because fx_preset is a string field stored as a StringPool offset, we handle it
/// as a special case before the generic integer-parsing field loop.
fn readToU8Struct(ret_struct: anytype, parser: anytype, found_module: *?ModulesList, preset_strings: ?*StringPool, allocator: std.mem.Allocator) !@TypeOf(ret_struct) {
    const T = @TypeOf(ret_struct.*);
    std.debug.assert(@typeInfo(T) == .@"struct");

    var version_found = false;

    while (try parser.*.next()) |record| {
        switch (record) {
            .property => |kv| {
                // Because the module field is not part of the mapping structs,
                // we check for it separately before the struct field matching
                if (std.mem.eql(u8, kv.key, "module")) {
                    inline for (comptime std.enums.values(ModulesList)) |module_val| {
                        if (std.mem.eql(u8, kv.value, @tagName(module_val))) {
                            found_module.* = module_val;
                        }
                    }
                    continue;
                }

                // Because fx_preset is a string value (not an integer), we handle it
                // before the generic field loop to avoid it being misinterpreted
                if (comptime @hasField(T, "fx_preset")) {
                    if (std.mem.eql(u8, kv.key, "fx_preset")) {
                        if (kv.value.len > 0) {
                            if (preset_strings) |ps| {
                                @field(ret_struct, "fx_preset") = try ps.intern(allocator, kv.value);
                            }
                        }
                        continue;
                    }
                }

                inline for (std.meta.fields(T)) |ns_info| {
                    // Because fx_preset is handled above, we skip it here
                    if (comptime std.mem.eql(u8, ns_info.name, "fx_preset")) continue;

                    if (std.mem.eql(u8, ns_info.name, kv.key)) {
                        const field_type = @TypeOf(@field(ret_struct, ns_info.name));
                        if (field_type == ?u16 or field_type == u16 or field_type == ?u8 or field_type == u8) {
                            const ParsedInt = if (field_type == ?u16 or field_type == u16) u16 else u8;
                            const parsed = std.fmt.parseInt(ParsedInt, kv.value, 10) catch null;
                            if (parsed) |val| {
                                @field(ret_struct, ns_info.name) = val;
                                if (std.mem.eql(u8, ns_info.name, "version")) {
                                    version_found = true;
                                    if (val != MAPPING_FORMAT_VERSION) {
                                        log.warn("Mapping file has version {d}, expected {d}", .{ val, MAPPING_FORMAT_VERSION });
                                    }
                                }
                            }
                        }
                    }
                }
            },
            .section => {},
            .enumeration => {},
        }
    }

    if (!version_found) {
        const config = @import("config");
        const is_test = @hasDecl(config, "test") and @field(config, "test");
        if (!is_test) {
            log.warn("Mapping file missing version field, assuming version 0 (old format)", .{});
        }
    }

    return ret_struct;
}

fn formatOptionalU8(value: anytype, writer: anytype) !void {
    const T = @TypeOf(value);
    const info = @typeInfo(T);
    comptime {
        if (info == .optional) {
            if (@typeInfo(info.optional.child) != .int and @typeInfo(info.optional.child) != .Float) {
                @compileError("Expected optional number type, got optional " ++ @typeName(info.optional.child));
            }
        } else if (info == .int or info == .Float) {
            // Allow non-optional numeric types as well
        } else {
            @compileError("Expected optional or non-optional number type, got " ++ @typeName(T));
        }
    }

    if (info == .optional) {
        if (value) |v| {
            try writer.print("{d}", .{v});
        } else {
            // Print nothing for null
            try writer.writeAll("");
        }
    } else {
        // Non-optional value, just print it
        try writer.print("{d}", .{value});
    }
}

/// Save a mapping to disk at the given absolute file path.
/// The caller is responsible for determining the path (existing map location
/// for overwrites, or a default location for new maps).
pub fn saveToFile(
    self: *MapStore,
    fs_ops: fs_helpers.FileSystemOps,
    module: ModulesList,
    fx_name: [:0]const u8,
    mapping: TaggedMapping,
    file_path: [:0]const u8,
    embedded_preset: ?preset_file_reader.EmbeddedPreset,
) !void {
    // Create the parent directory if it does not exist
    if (std.fs.path.dirname(file_path)) |dir_path| {
        fs_ops.makeDirAbsolute(dir_path) catch |err| {
            if (err != error.PathAlreadyExists) {
                log.err("Failed to create directory: {s}", .{@errorName(err)});
                return err;
            }
        };
    }

    // Create or truncate file
    const file = try fs_ops.createFileAbsolute(file_path, .{
        .read = true,
        .truncate = true,
    });
    defer file.close();

    // Write mappings
    var writer = file.writer();

    // Write header fields that are not part of the mapping structs
    try writer.print("module={s}\n", .{@tagName(module)});
    try writer.print("fx_name={s}\n", .{fx_name});

    // Write different fields based on module type
    switch (mapping) {
        inline else => |m| {
            // Because fx_preset is a StringPool offset (not a raw integer),
            // we write it as a string before the generic field loop
            if (m.fx_preset) |offset| {
                try writer.print("fx_preset={s}\n", .{self.preset_strings.get(offset)});
            }

            inline for (std.meta.fields(@TypeOf(m))) |field| {
                if (comptime std.mem.eql(u8, field.name, "fx_preset")) continue;
                try writer.print("{s} = ", .{field.name});
                try formatOptionalU8(@field(m, field.name), writer);
                try writer.writeByte('\n');
            }
        },
    }

    // Because preset data fields are not stored in the mapping structs,
    // we write them from the caller-provided parameters
    if (embedded_preset) |ep| {
        try writer.print("fx_preset_file={s}\n", .{ep.file});
        try writer.print("fx_preset_data={s}\n", .{ep.data});
        try writer.print("fx_preset_len={d}\n", .{ep.len});
    }
}

test readToU8Struct {
    const expect = std.testing.expect;
    const ExampleStruct = struct {
        repositoryformatversion: u8,
    };
    const example =
        \\ repositoryformatversion=8
    ;
    var fbs = std.io.fixedBufferStream(example);
    var parser = ini.parse(std.testing.allocator, fbs.reader());
    defer parser.deinit();

    var found_module: ?ModulesList = null;
    var ret_str: ExampleStruct = .{
        .repositoryformatversion = 0,
    };
    _ = try readToU8Struct(&ret_str, &parser, &found_module, null, std.testing.allocator);
    try expect(ret_str.repositoryformatversion == 8);
    // Because the example INI has no module field, found_module should remain null
    try expect(found_module == null);
}

test "readToU8Struct: module field is parsed correctly" {
    const testing = std.testing;
    const example =
        \\ version=1
        \\ module=COMP
        \\ Comp_Thresh=0
        \\ Comp_Ratio=1
    ;
    var fbs = std.io.fixedBufferStream(example);
    var parser = ini.parse(testing.allocator, fbs.reader());
    defer parser.deinit();

    var found_module: ?ModulesList = null;
    var comp = Comp{};
    _ = try readToU8Struct(&comp, &parser, &found_module, null, testing.allocator);

    try testing.expect(found_module != null);
    try testing.expectEqual(ModulesList.COMP, found_module.?);
    try testing.expectEqual(@as(?u16, 0), comp.Comp_Thresh);
    try testing.expectEqual(@as(?u16, 1), comp.Comp_Ratio);
}

test init {
    var ctx = try TestContext.init();
    defer ctx.deinit();

    // Verify initialization with default mappings loaded
    try std.testing.expect(ctx.store.COMP.count() == 1);
    try std.testing.expect(ctx.store.EQ.count() == 1);
    try std.testing.expect(ctx.store.INPUT.count() == 1);
    try std.testing.expect(ctx.store.OUTPT.count() == 1);
    try std.testing.expect(ctx.store.GATE.count() == 1);
}

test "MapStore - get: lazy loading and caching" {
    var ctx = try TestContext.init();
    defer ctx.deinit();

    const test_fx = "VST: ReaComp (Cockos)";

    // First access should load from disk
    const first_result = ctx.store.get(test_fx, .COMP, ctx.mappings_list);
    try std.testing.expect(first_result != null);
    try std.testing.expect(ctx.store.COMP.count() == 1);

    // Second access should use cache
    const second_result = ctx.store.get(test_fx, .COMP, ctx.mappings_list);
    try std.testing.expect(second_result != null);
    try std.testing.expect(ctx.store.COMP.count() == 1);

    // Verify cached values match
    if (first_result) |comp_first| {
        const first = comp_first.COMP;
        if (second_result) |comp_second| {
            const second = comp_second.COMP;
            try std.testing.expect(first.Comp_Attack == second.Comp_Attack);
            try std.testing.expect(first.Comp_Release == second.Comp_Release);
            // ... test other fields
        } else {
            try std.testing.expect(false); // Should not happen
        }
    }
}

test "MapStore - invalid fx name" {
    var ctx = try TestContext.init();
    defer ctx.deinit();

    const nonexistent_fx = "VST: NonexistentPlugin";

    try std.testing.expect(ctx.store.COMP.count() == 1);
    const result = ctx.store.get(nonexistent_fx, .COMP, ctx.mappings_list);
    try std.testing.expect(result == null);
    try std.testing.expect(ctx.store.COMP.count() == 1); // Should not cache failed attempts
}

test "MapStore - all values are within MIDI range (0-127)" {
    var ctx = try TestContext.init();
    defer ctx.deinit();

    const test_fx = "VST: ReaComp (Cockos)";

    const result = ctx.store.get(test_fx, .COMP, ctx.mappings_list);
    if (result) |COMP| {
        const comp = COMP.COMP;
        // Test that all values are within MIDI range (0-127)
        try std.testing.expect(comp.Comp_Attack.? <= 127);
        try std.testing.expect(comp.Comp_Release.? <= 127);
        try std.testing.expect(comp.Comp_Thresh.? <= 127);
    } else {
        try std.testing.expect(false);
    }
}

const MappingsList = @import("mappings_list.zig");

const TestContext = struct {
    arena: std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,
    config: settings.Preferences,
    mappings_list: *MappingsList,
    store: MapStore,

    pub fn init() !TestContext {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        errdefer arena.deinit();
        const allocator = arena.allocator();

        var mem: [std.fs.max_path_bytes]u8 = undefined;
        const pth = try std.fs.cwd().realpath(".", &mem);
        const config_path = try std.fs.path.resolve(allocator, &.{ pth, "src/resources/" });
        const config_path_z = try allocator.dupeZ(u8, config_path);

        var config = try settings.init(allocator, config_path_z);

        // Because the MapStore stores a pointer to the MappingsList, we need to
        // heap-allocate it so that the pointer remains stable when TestContext is
        // returned by value (returning by value moves the struct, which would
        // invalidate any internal pointer).
        const ml = try allocator.create(MappingsList);
        ml.* = MappingsList.init(allocator, config_path_z);

        const store = try MapStore.init(allocator, config_path_z, ml, &config.default_fx);

        return TestContext{
            .arena = arena,
            .allocator = allocator,
            .config = config,
            .mappings_list = ml,
            .store = store,
        };
    }

    pub fn deinit(self: *TestContext) void {
        self.arena.deinit();
    }
};

test getPreferredMapping {
    var ctx = try TestContext.init();
    defer ctx.deinit();

    const test_fx = "VST: ReaComp (Cockos)";

    const result = ctx.store.get(test_fx, .COMP, ctx.mappings_list);
    try std.testing.expect(result != null);

    // Verify that the preferred mapping is set
    const preferred = ctx.store.getPreferredMapping(test_fx, .COMP);
    try std.testing.expect(preferred != null);
    try std.testing.expect(std.mem.endsWith(u8, preferred.?, "default.ini"));
}

test "MapStore: get - returns null for missing maps" {
    var ctx = try TestContext.init();
    defer ctx.deinit();

    const nonexistent_fx = "VST: BogusPlugin";

    const result = ctx.store.get(nonexistent_fx, .COMP, ctx.mappings_list);
    try std.testing.expect(result == null);
}

test "MapStore - get: basic" {
    var ctx = try TestContext.init();
    defer ctx.deinit();

    const test_fx = "VST: ReaComp (Cockos)";

    // First access loads default mapping
    const first_result = ctx.store.get(test_fx, .COMP, ctx.mappings_list);
    try std.testing.expect(first_result != null);

    // Verify FxMaps exists for this FX
    const fx_maps = ctx.store.COMP.get(test_fx);
    try std.testing.expect(fx_maps != null);

    // Because we loaded the default mapping, the mappings hashmap should have one entry
    try std.testing.expectEqual(@as(usize, 1), fx_maps.?.mappings.count());

    // Second access uses cache
    const second_result = ctx.store.get(test_fx, .COMP, ctx.mappings_list);
    try std.testing.expect(second_result != null);
}

test "MapStore - get: handling FX with zero mappings" {
    var ctx = try TestContext.init();
    defer ctx.deinit();

    const nonexistent_fx = "VST: BrandNewPlugin";

    // Because no mappings exist for this FX, get should return null
    const result = ctx.store.get(nonexistent_fx, .EQ, ctx.mappings_list);
    try std.testing.expect(result == null);
}

// test "MapStore: setPreferredMapping - validates filepath exists" {
//     var ctx = try TestContext.init();
//     defer ctx.deinit();

//     const test_fx = "VST: ReaComp (Cockos)";

//     // Load the default mapping first
//     _ = ctx.store.get(test_fx, .COMP, ctx.mappings_list);

//     // Because we try to set a non-existent mapping as preferred, we should get an error
//     const bogus_path = "/nonexistent/path/to/mapping.ini";
//     const bogus_path_z = try ctx.allocator.dupeZ(u8, bogus_path);
//     const result = ctx.store.setPreferredMapping(test_fx, .COMP, bogus_path_z);

//     try std.testing.expectError(error.MappingNotFound, result);
// }

test "MapStore: setPreferredMapping - returns error for unfound FX" {
    var ctx = try TestContext.init();
    defer ctx.deinit();

    const nonexistent_fx = "VST: NonexistentPlugin";
    const some_path = "/some/path.ini";

    // Because the FX is not in the store, we should get FxNotFound error
    const result = ctx.store.setPreferredMapping(nonexistent_fx, .COMP, some_path);

    try std.testing.expectError(error.FxNotFound, result);
}

test "readToU8Struct: fx_preset field is parsed correctly" {
    const testing = std.testing;
    const example =
        \\ version=1
        \\ module=COMP
        \\ Comp_Thresh=0
        \\ fx_preset=My Custom Preset
    ;
    var fbs = std.io.fixedBufferStream(example);
    var parser = ini.parse(testing.allocator, fbs.reader());
    defer parser.deinit();

    var preset_strings: StringPool = .empty;
    defer preset_strings.deinit(testing.allocator);

    var found_module: ?ModulesList = null;
    var comp = Comp{};
    _ = try readToU8Struct(&comp, &parser, &found_module, &preset_strings, testing.allocator);

    // Because the INI contains fx_preset=My Custom Preset, the field should be set
    try testing.expect(comp.fx_preset != null);
    const preset_name = preset_strings.get(comp.fx_preset.?);
    try testing.expectEqualStrings("My Custom Preset", preset_name);
    try testing.expectEqual(@as(?u16, 0), comp.Comp_Thresh);
}

test "readToU8Struct: missing fx_preset remains null" {
    const testing = std.testing;
    const example =
        \\ version=1
        \\ module=COMP
        \\ Comp_Thresh=0
    ;
    var fbs = std.io.fixedBufferStream(example);
    var parser = ini.parse(testing.allocator, fbs.reader());
    defer parser.deinit();

    var preset_strings: StringPool = .empty;
    defer preset_strings.deinit(testing.allocator);

    var found_module: ?ModulesList = null;
    var comp = Comp{};
    _ = try readToU8Struct(&comp, &parser, &found_module, &preset_strings, testing.allocator);

    // Because the INI has no fx_preset line, the field should remain null
    try testing.expect(comp.fx_preset == null);
}

test "readToU8Struct: fx_preset with null preset_strings parameter is ignored" {
    const testing = std.testing;
    const example =
        \\ version=1
        \\ fx_preset=Some Preset
        \\ Comp_Thresh=5
    ;
    var fbs = std.io.fixedBufferStream(example);
    var parser = ini.parse(testing.allocator, fbs.reader());
    defer parser.deinit();

    var found_module: ?ModulesList = null;
    var comp = Comp{};
    _ = try readToU8Struct(&comp, &parser, &found_module, null, testing.allocator);

    // Because preset_strings is null, the fx_preset field should remain null
    // even though the INI contains the field
    try testing.expect(comp.fx_preset == null);
    try testing.expectEqual(@as(?u16, 5), comp.Comp_Thresh);
}

test "MapStore: getPresetName returns null when no preset is set" {
    var ctx = try TestContext.init();
    defer ctx.deinit();

    const test_fx = "VST: ReaComp (Cockos)";

    // Load the mapping first
    _ = ctx.store.get(test_fx, .COMP, ctx.mappings_list);

    // Because the default mapping files have no fx_preset field,
    // getPresetName should return null
    const preset = ctx.store.getPresetName(test_fx, .COMP);
    try std.testing.expect(preset == null);
}

test "MapStore: getPresetName returns null for unknown FX" {
    var ctx = try TestContext.init();
    defer ctx.deinit();

    const preset = ctx.store.getPresetName("VST: NonexistentPlugin", .COMP);
    try std.testing.expect(preset == null);
}
