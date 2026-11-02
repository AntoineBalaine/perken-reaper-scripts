const std = @import("std");
const ini = @import("ini");
const settings = @import("settings.zig");
const statemachine = @import("statemachine.zig");
const c1 = @import("c1.zig");
const ModulesList = statemachine.ModulesList;
const PhysicalModule = statemachine.PhysicalModule;
const fs_helpers = @import("fs_helpers");
const StringPool = @import("string_pool").StringPool;
const preset_file_reader = @import("preset_file_reader");
const default_maps = @import("default_maps.zig");
const log = std.log.scoped(.mappings);

pub const MAPPING_FORMAT_VERSION = 1;

/// The longest name that a map can give a control: the label pool keeps 31 bytes of a label.
pub const max_label_len = 31;

/// A name that a map gives a control, in place of the one that the plugin gives its parameter. It is empty when the map gives none.
pub const Label = struct {
    buf: [max_label_len]u8 = undefined,
    len: u8 = 0,

    pub fn get(self: *const Label) ?[]const u8 {
        return if (self.len == 0) null else self.buf[0..self.len];
    }

    /// Keeps the name, cut at the longest that a label can be.
    pub fn set(self: *Label, text: []const u8) void {
        const length = @min(text.len, max_label_len);
        @memcpy(self.buf[0..length], text[0..length]);
        self.len = @intCast(length);
    }
};

/// The most controls that one map can name.
pub const max_labels = 16;

/// The names that a map gives its controls. They are written in the section `[labels]` of the map file, one line for each control,
/// as `Inpt_LoCut=HPF`. Because a map names a few controls at most, the names are a short list that is searched in order.
pub const Labels = struct {
    entries: [max_labels]Entry = undefined,
    count: u8 = 0,

    const Entry = struct { cc: c1.CCs, label: Label };

    pub fn get(self: *const Labels, cc: c1.CCs) ?[]const u8 {
        for (self.entries[0..self.count]) |*entry| {
            if (entry.cc == cc) return entry.label.get();
        }
        return null;
    }

    /// Names the control, or renames it. A map that names more controls than the list holds loses the last ones.
    pub fn set(self: *Labels, cc: c1.CCs, text: []const u8) void {
        for (self.entries[0..self.count]) |*entry| {
            if (entry.cc == cc) {
                entry.label.set(text);
                return;
            }
        }
        if (self.count == max_labels) {
            log.warn("A map names more than {d} controls, so the name of {s} is dropped", .{ max_labels, @tagName(cc) });
            return;
        }
        self.entries[self.count] = .{ .cc = cc, .label = .{} };
        self.entries[self.count].label.set(text);
        self.count += 1;
    }

    /// Takes the name of the control away, so that it has the one of the plugin again. A control that has no name is left alone.
    pub fn clear(self: *Labels, cc: c1.CCs) void {
        for (self.entries[0..self.count], 0..) |entry, index| {
            if (entry.cc != cc) continue;
            std.mem.copyForwards(Entry, self.entries[index .. self.count - 1], self.entries[index + 1 .. self.count]);
            self.count -= 1;
            return;
        }
    }

    pub fn any(self: *const Labels) bool {
        return self.count > 0;
    }

    /// Writes the section `[labels]`, or nothing when the map gives no name.
    pub fn write(self: *const Labels, writer: anytype) !void {
        if (!self.any()) return;
        try writer.writeAll("\n[labels]\n");
        for (self.entries[0..self.count]) |*entry| {
            if (entry.label.get()) |text| try writer.print("{s}={s}\n", .{ @tagName(entry.cc), text });
        }
    }
};

pub const Comp = struct {
    version: u8 = MAPPING_FORMAT_VERSION,
    fx_preset: ?StringPool.StringRef = null,
    labels: Labels = .{},
    Comp_Attack: ?u16 = null,
    Comp_DryWet: ?u16 = null,
    Comp_Ratio: ?u16 = null,
    Comp_Release: ?u16 = null,
    Comp_Thresh: ?u16 = null,
    Comp_comp: ?u16 = null,
    Comp_HiCut: ?u16 = null,
    Comp_LoCut: ?u16 = null,
    // Comp_Mtr : u8,
    /// The parameter in which the plugin keeps its gain reduction, in dB. It is no control: when a map has it, the meter reads
    /// the parameter, and when it has not, it asks the plugin for "GainReduction_dB".
    Comp_GR: ?u16 = null,
};

pub const Eq = struct {
    version: u8 = MAPPING_FORMAT_VERSION,
    fx_preset: ?StringPool.StringRef = null,
    labels: Labels = .{},
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
    labels: Labels = .{},
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
    labels: Labels = .{},
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
    labels: Labels = .{},
    Shp_Gate: ?u16 = null,
    Shp_GateRelease: ?u16 = null,
    Shp_Punch: ?u16 = null,
    Shp_hard_gate: ?u16 = null,
    Shp_shape: ?u16 = null,
    Shp_sustain: ?u16 = null,
    /// The parameter in which the plugin keeps its gain reduction, in dB. It is no control: see `Comp.Comp_GR`.
    Shp_GR: ?u16 = null,
};

/// A flattened mapping for channel strip FX that contain all Console1 sections
/// in a single plugin. Each field is an optional parameter index within the FX.
/// Because channel strip mode repurposes Tr_ext_sidechain and Tr_order as freely
/// assignable parameters, they are included here.
pub const ChannelStripMapping = struct {
    version: u8 = MAPPING_FORMAT_VERSION,
    fx_preset: ?StringPool.StringRef = null,
    labels: Labels = .{},

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
    /// The parameter in which the plugin keeps the gain reduction of its compressor, in dB. It is no control: see `Comp.Comp_GR`.
    Comp_GR: ?u16 = null,

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

pub fn init(allocator: std.mem.Allocator, io: std.Io, controller_dir: [*:0]const u8, ml: *MappingsList, defaults: *settings.DefaultFx) !MapStore {
    var self: MapStore = .empty(allocator, controller_dir);
    // Because the maps that the user picked decide which map each FX loads first, they are flagged in the list before the defaults
    // are loaded.
    default_maps.load(ml, io, std.mem.span(controller_dir));
    // find the mappings for the defaults
    var iterator = defaults.iterator();
    while (iterator.next()) |defaultsEntry| {
        const fxName = defaultsEntry.value.*;

        if (fxName) |fx_name| {
            // use self.getDefaultMap() only for its side-effect: storing into the map.
            // Its return value is only meant to be used by self.get()
            _ = self.getDefaultMap(io, fx_name, defaultsEntry.key, ml);
        }
    }
    return self;
}

/// Loads the map that an FX starts from: the one that the user picked, or the map that is named `default` when none was picked,
/// or when the picked one is not on the disk anymore.
pub fn getDefaultMap(self: *MapStore, io: std.Io, fx_name: [:0]const u8, module: ModulesList, ml: *MappingsList) ?TaggedMapping {
    if (ml.defaultMapName(module, fx_name)) |picked| {
        if (self.getMap(io, fx_name, module, picked, ml)) |mapping| return mapping else |_| {}
    }
    return self.getMap(io, fx_name, module, "default", ml) catch null;
}

/// Makes a map the default of an FX, which is also the map that the FX uses from now on, and writes the choice to the disk at
/// once. Because the flag of the map is set before the file is written, a failure to write returns its error and the session
/// keeps the choice. Because the file has one `FX = map` line for each FX, a name that holds an equal sign is refused.
pub fn setDefaultMap(self: *MapStore, io: std.Io, module: ModulesList, fx_name: [:0]const u8, map_name: [:0]const u8, ml: *MappingsList) !void {
    if (std.mem.indexOfScalar(u8, fx_name, '=') != null) return error.UnsupportedName;
    const path = ml.lookupPath(module, fx_name, map_name) orelse return error.FileNotFound;
    try ml.setDefault(module, fx_name, map_name);
    _ = try self.getMap(io, fx_name, module, map_name, ml);
    try self.setPreferredMapping(fx_name, module, path);
    try default_maps.save(ml, io, std.mem.span(self.controller_dir));
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
    io: std.Io,
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
    defer file.close(io);

    // Because file writers are buffered since Zig 0.15, the writer is flushed before the file closes.
    var writer_buffer: [4096]u8 = undefined;
    var writer_file_writer = file.writer(io, &writer_buffer);
    const writer = &writer_file_writer.interface;

    // Because fx_preset is a StringPool offset (not a raw integer),
    // we write it as a string before the generic field loop
    if (mapping.fx_preset) |offset| {
        try writer.print("fx_preset={s}\n", .{self.preset_strings.get(offset)});
    }

    inline for (@typeInfo(ChannelStripMapping).@"struct".field_names) |field_name| {
        if (comptime std.mem.eql(u8, field_name, "fx_preset")) continue;
        if (comptime std.mem.eql(u8, field_name, "labels")) continue;
        try writer.print("{s} = ", .{field_name});
        try formatOptionalU8(@field(mapping, field_name), writer);
        try writer.writeByte('\n');
    }

    // Because preset data fields are not stored in the mapping structs,
    // we write them from the caller-provided parameters
    if (embedded_preset) |ep| {
        try writer.print("fx_preset_file={s}\n", .{ep.file});
        try writer.print("fx_preset_data={s}\n", .{ep.data});
        try writer.print("fx_preset_len={d}\n", .{ep.len});
    }
    // Because a section lasts until the next one, the names come last.
    try mapping.labels.write(writer);
    try writer.flush();
}

/// find fx mapping in storage. If unfound, search it from disk. If still unfound, return null.
/// Because we now store multiple mappings per FX, we return the preferred mapping.
pub fn get(self: *MapStore, io: std.Io, fxName: [:0]const u8, module: ModulesList, ml: *MappingsList) ?TaggedMapping {
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
                return self.getDefaultMap(io, fxName, module, ml);
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
                return self.getDefaultMap(io, fxName, module, ml);
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
                return self.getDefaultMap(io, fxName, module, ml);
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
                return self.getDefaultMap(io, fxName, module, ml);
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
                return self.getDefaultMap(io, fxName, module, ml);
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
                return self.getDefaultMap(io, fxName, module, ml);
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
pub fn getMap(self: *MapStore, io: std.Io, fxName: [:0]const u8, module: ModulesList, mapping_name: [:0]const u8, ml: *MappingsList) !TaggedMapping {
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

    const file = try std.Io.Dir.openFileAbsolute(io, filePath, .{});
    defer file.close(io);

    var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer temp_arena.deinit();
    var file_buffer: [4096]u8 = undefined;
    var file_reader = file.reader(io, &file_buffer);
    var parser = ini.parse(temp_arena.allocator(), &file_reader.interface, ";#");
    defer parser.deinit(); // doesn’t actually do anything because of arena

    var found_module: ?ModulesList = null;

    const mapping: TaggedMapping = switch (module) {
        .COMP => {
            var comp = Comp{};
            _ = try readToU8Struct(&comp, &parser, &found_module, &self.preset_strings, self.allocator);

            if (found_module) |m| {
                if (m != module) return error.ModuleMismatch;
            }

            const entry = self.COMP.getPtr(fxName) orelse blk: {
                const owned_key = try self.allocator.dupeSentinel(u8, fxName, 0);
                try self.COMP.put(self.allocator, owned_key, FxMaps(Comp){
                    .mappings = std.StringArrayHashMapUnmanaged(?Comp){},
                    .preferred_mapping = filePath_z,
                });
                break :blk self.COMP.getPtr(owned_key).?;
            };

            try entry.mappings.put(self.allocator, filePath_z, comp);

            return TaggedMapping{ .COMP = comp };
        },
        .EQ => {
            var eq = Eq{};
            _ = try readToU8Struct(&eq, &parser, &found_module, &self.preset_strings, self.allocator);

            if (found_module) |m| {
                if (m != module) return error.ModuleMismatch;
            }

            const entry = self.EQ.getPtr(fxName) orelse blk: {
                const owned_key = try self.allocator.dupeSentinel(u8, fxName, 0);
                try self.EQ.put(self.allocator, owned_key, FxMaps(Eq){
                    .mappings = std.StringArrayHashMapUnmanaged(?Eq){},
                    .preferred_mapping = filePath_z,
                });
                break :blk self.EQ.getPtr(owned_key).?;
            };

            try entry.mappings.put(self.allocator, filePath_z, eq);

            return TaggedMapping{ .EQ = eq };
        },
        .INPUT => {
            var inpt: Inpt = Inpt{};
            _ = try readToU8Struct(&inpt, &parser, &found_module, &self.preset_strings, self.allocator);

            if (found_module) |m| {
                if (m != module) return error.ModuleMismatch;
            }

            const entry = self.INPUT.getPtr(fxName) orelse blk: {
                const owned_key = try self.allocator.dupeSentinel(u8, fxName, 0);
                try self.INPUT.put(self.allocator, owned_key, FxMaps(Inpt){
                    .mappings = std.StringArrayHashMapUnmanaged(?Inpt){},
                    .preferred_mapping = filePath_z,
                });
                break :blk self.INPUT.getPtr(owned_key).?;
            };

            try entry.mappings.put(self.allocator, filePath_z, inpt);

            return TaggedMapping{ .INPUT = inpt };
        },
        .OUTPT => {
            var outpt: Outpt = Outpt{};
            _ = try readToU8Struct(&outpt, &parser, &found_module, &self.preset_strings, self.allocator);

            if (found_module) |m| {
                if (m != module) return error.ModuleMismatch;
            }

            const entry = self.OUTPT.getPtr(fxName) orelse blk: {
                const owned_key = try self.allocator.dupeSentinel(u8, fxName, 0);
                try self.OUTPT.put(self.allocator, owned_key, FxMaps(Outpt){
                    .mappings = std.StringArrayHashMapUnmanaged(?Outpt){},
                    .preferred_mapping = filePath_z,
                });
                break :blk self.OUTPT.getPtr(owned_key).?;
            };

            try entry.mappings.put(self.allocator, filePath_z, outpt);

            return TaggedMapping{ .OUTPT = outpt };
        },
        .GATE => {
            var shp: Shp = Shp{};
            _ = try readToU8Struct(&shp, &parser, &found_module, &self.preset_strings, self.allocator);

            if (found_module) |m| {
                if (m != module) return error.ModuleMismatch;
            }

            const entry = self.GATE.getPtr(fxName) orelse blk: {
                const owned_key = try self.allocator.dupeSentinel(u8, fxName, 0);
                try self.GATE.put(self.allocator, owned_key, FxMaps(Shp){
                    .mappings = std.StringArrayHashMapUnmanaged(?Shp){},
                    .preferred_mapping = filePath_z,
                });
                break :blk self.GATE.getPtr(owned_key).?;
            };

            try entry.mappings.put(self.allocator, filePath_z, shp);

            return TaggedMapping{ .GATE = shp };
        },
        .STRIP => {
            var strip = ChannelStripMapping{};
            _ = try readToU8Struct(&strip, &parser, &found_module, &self.preset_strings, self.allocator);

            if (found_module) |m| {
                if (m != module) return error.ModuleMismatch;
            }

            const entry = self.STRIP.getPtr(fxName) orelse blk: {
                const owned_key = try self.allocator.dupeSentinel(u8, fxName, 0);
                try self.STRIP.put(self.allocator, owned_key, FxMaps(ChannelStripMapping){
                    .mappings = std.StringArrayHashMapUnmanaged(?ChannelStripMapping){},
                    .preferred_mapping = filePath_z,
                });
                break :blk self.STRIP.getPtr(owned_key).?;
            };

            try entry.mappings.put(self.allocator, filePath_z, strip);

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
    // Because a section lasts until the next one, the lines of `[labels]` are names of controls, and no parameter.
    var in_labels = false;

    while (try parser.*.next()) |record| {
        switch (record) {
            .property => |kv| {
                if (in_labels) {
                    if (comptime @hasField(T, "labels")) {
                        if (std.meta.stringToEnum(c1.CCs, kv.key)) |cc| {
                            if (kv.value.len > 0) ret_struct.labels.set(cc, kv.value);
                        }
                    }
                    continue;
                }

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

                inline for (@typeInfo(T).@"struct".field_names) |ns_info_name| {
                    // Because fx_preset is handled above, we skip it here, and the names of `[labels]` too
                    if (comptime std.mem.eql(u8, ns_info_name, "fx_preset")) continue;
                    if (comptime std.mem.eql(u8, ns_info_name, "labels")) continue;

                    if (std.mem.eql(u8, ns_info_name, kv.key)) {
                        const field_type = @TypeOf(@field(ret_struct, ns_info_name));
                        if (field_type == ?u16 or field_type == u16 or field_type == ?u8 or field_type == u8) {
                            const ParsedInt = if (field_type == ?u16 or field_type == u16) u16 else u8;
                            const parsed = std.fmt.parseInt(ParsedInt, kv.value, 10) catch null;
                            if (parsed) |val| {
                                @field(ret_struct, ns_info_name) = val;
                                if (std.mem.eql(u8, ns_info_name, "version")) {
                                    version_found = true;
                                    // A mapping file from a newer build is a problem with the
                                    // user's input, not an internal failure, so it is logged as
                                    // a warning; the caller still receives the error.
                                    if (val > MAPPING_FORMAT_VERSION) {
                                        log.warn("Mapping file has version {d}, but this build only supports up to version {d}", .{ val, MAPPING_FORMAT_VERSION });
                                        return error.UnsupportedMapVersion;
                                    }
                                }
                            }
                        }
                    }
                }
            },
            .section => |name| in_labels = std.mem.eql(u8, name, "labels"),
            .enumeration => {},
        }
    }

    // Only enforce the version requirement on structs that have a version field
    // (i.e., the actual mapping types, not arbitrary test structs).
    if (comptime @hasField(T, "version")) {
        if (!version_found) {
            // As above, a malformed user file is logged as a warning rather
            // than an error; the caller still receives the error.
            log.warn("Mapping file is missing the required version field", .{});
            return error.MissingVersion;
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
    io: std.Io,
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
    defer file.close(io);

    // Write mappings
    // Because file writers are buffered since Zig 0.15, the writer is flushed before the file closes.
    var writer_buffer: [4096]u8 = undefined;
    var writer_file_writer = file.writer(io, &writer_buffer);
    const writer = &writer_file_writer.interface;

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

            inline for (@typeInfo(@TypeOf(m)).@"struct".field_names) |field_name| {
                if (comptime std.mem.eql(u8, field_name, "fx_preset")) continue;
                if (comptime std.mem.eql(u8, field_name, "labels")) continue;
                try writer.print("{s} = ", .{field_name});
                try formatOptionalU8(@field(m, field_name), writer);
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
    // Because a section lasts until the next one, the names come last.
    switch (mapping) {
        inline else => |m| try m.labels.write(writer),
    }
    try writer.flush();
}

test "a [labels] section names controls, and its lines are no parameter" {
    const example =
        \\version = 1
        \\module=STRIP
        \\Inpt_LoCut=35
        \\
        \\[labels]
        \\Inpt_LoCut=HPF
        \\Inpt_HiCut=LPF
        \\Inpt_Gain=
    ;
    var fbs: std.Io.Reader = .fixed(example);
    var parser = ini.parse(std.testing.allocator, &fbs, ";#");
    defer parser.deinit();

    var found_module: ?ModulesList = null;
    var strip = ChannelStripMapping{};
    _ = try readToU8Struct(&strip, &parser, &found_module, null, std.testing.allocator);
    try std.testing.expectEqual(@as(?u16, 35), strip.Inpt_LoCut);
    // Because the lines of the section are names, the name of a control does not become its parameter.
    try std.testing.expectEqual(@as(?u16, null), strip.Inpt_HiCut);
    try std.testing.expectEqualStrings("HPF", strip.labels.get(.Inpt_LoCut).?);
    try std.testing.expectEqualStrings("LPF", strip.labels.get(.Inpt_HiCut).?);
    // Because a line without a name gives none, the plugin's own name stays.
    try std.testing.expect(strip.labels.get(.Inpt_Gain) == null);
    try std.testing.expectEqual(ModulesList.STRIP, found_module.?);
}

test "Comp_GR is read from a map as a parameter, and no control gets it" {
    const example =
        \\version = 1
        \\module=STRIP
        \\Comp_comp=12
        \\Comp_GR=47
    ;
    var fbs: std.Io.Reader = .fixed(example);
    var parser = ini.parse(std.testing.allocator, &fbs, ";#");
    defer parser.deinit();
    var found_module: ?ModulesList = null;
    var strip = ChannelStripMapping{};
    _ = try readToU8Struct(&strip, &parser, &found_module, null, std.testing.allocator);
    try std.testing.expectEqual(@as(?u16, 47), strip.Comp_GR);
    try std.testing.expectEqual(@as(?u16, 12), strip.Comp_comp);
    try std.testing.expect(!@hasField(c1.CCs, "Comp_GR"));
    try std.testing.expect(!@hasField(c1.CCs, "Shp_GR"));
}

test "the names of a map are written as a [labels] section that reads back, and a map with none writes nothing" {
    var labels: Labels = .{};
    var nothing: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer nothing.deinit();
    try labels.write(&nothing.writer);
    try std.testing.expectEqualStrings("", nothing.written());

    labels.set(.Inpt_LoCut, "HPF");
    labels.set(.Inpt_HiCut, "LPF");
    var out: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer out.deinit();
    try labels.write(&out.writer);
    try std.testing.expectEqualStrings("\n[labels]\nInpt_LoCut=HPF\nInpt_HiCut=LPF\n", out.written());

    const text = try std.fmt.allocPrint(std.testing.allocator, "version = 1\nmodule=STRIP\n{s}", .{out.written()});
    defer std.testing.allocator.free(text);
    var fbs: std.Io.Reader = .fixed(text);
    var parser = ini.parse(std.testing.allocator, &fbs, ";#");
    defer parser.deinit();
    var found_module: ?ModulesList = null;
    var strip = ChannelStripMapping{};
    _ = try readToU8Struct(&strip, &parser, &found_module, null, std.testing.allocator);
    try std.testing.expectEqualStrings("HPF", strip.labels.get(.Inpt_LoCut).?);
    try std.testing.expectEqualStrings("LPF", strip.labels.get(.Inpt_HiCut).?);
}

test "a name is taken away by clear, the others stay in order, and clearing a control without a name does nothing" {
    var labels: Labels = .{};
    labels.set(.Inpt_LoCut, "HPF");
    labels.set(.Inpt_HiCut, "LPF");
    labels.set(.Comp_Ratio, "Ratio");
    labels.clear(.Inpt_HiCut);
    try std.testing.expectEqual(@as(u8, 2), labels.count);
    try std.testing.expect(labels.get(.Inpt_HiCut) == null);
    try std.testing.expectEqualStrings("HPF", labels.get(.Inpt_LoCut).?);
    try std.testing.expectEqualStrings("Ratio", labels.get(.Comp_Ratio).?);
    labels.clear(.Out_Vol);
    try std.testing.expectEqual(@as(u8, 2), labels.count);
    labels.clear(.Inpt_LoCut);
    labels.clear(.Comp_Ratio);
    try std.testing.expect(!labels.any());
    // Because a list that was emptied is free again, a new name goes in.
    labels.set(.Out_Vol, "Vol");
    try std.testing.expectEqualStrings("Vol", labels.get(.Out_Vol).?);
}

test "a name is replaced by naming the control again, cut at the longest label, and the list has a limit" {
    var labels: Labels = .{};
    labels.set(.Inpt_LoCut, "HPF");
    labels.set(.Inpt_LoCut, "High pass");
    try std.testing.expectEqualStrings("High pass", labels.get(.Inpt_LoCut).?);
    try std.testing.expectEqual(@as(u8, 1), labels.count);

    var long: [max_label_len + 9]u8 = undefined;
    @memset(&long, 'x');
    labels.set(.Inpt_HiCut, &long);
    try std.testing.expectEqual(@as(usize, max_label_len), labels.get(.Inpt_HiCut).?.len);

    // Because the list holds `max_labels` names, the names after them are dropped and the others stay.
    var count: u8 = labels.count;
    for (std.enums.values(c1.CCs)) |cc| {
        if (count == max_labels) break;
        if (labels.get(cc) != null) continue;
        labels.set(cc, "name");
        count += 1;
    }
    try std.testing.expectEqual(@as(u8, max_labels), labels.count);
    for (std.enums.values(c1.CCs)) |cc| {
        if (labels.get(cc) == null) {
            labels.set(cc, "one too many");
            try std.testing.expect(labels.get(cc) == null);
            break;
        }
    }
    try std.testing.expectEqualStrings("High pass", labels.get(.Inpt_LoCut).?);
}

test readToU8Struct {
    const expect = std.testing.expect;
    const ExampleStruct = struct {
        repositoryformatversion: u8,
    };
    const example =
        \\ repositoryformatversion=8
    ;
    var fbs: std.Io.Reader = .fixed(example);
    var parser = ini.parse(std.testing.allocator, &fbs, ";#");
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
    var fbs: std.Io.Reader = .fixed(example);
    var parser = ini.parse(testing.allocator, &fbs, ";#");
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
    const io = std.testing.io;
    var ctx = try TestContext.init(io);
    defer ctx.deinit();

    // Verify initialization with default mappings loaded
    try std.testing.expect(ctx.store.COMP.count() == 1);
    try std.testing.expect(ctx.store.EQ.count() == 1);
    try std.testing.expect(ctx.store.INPUT.count() == 1);
    try std.testing.expect(ctx.store.OUTPT.count() == 1);
    try std.testing.expect(ctx.store.GATE.count() == 1);
}

test "MapStore - get: lazy loading and caching" {
    const io = std.testing.io;
    var ctx = try TestContext.init(io);
    defer ctx.deinit();

    const test_fx = "VST: ReaComp (Cockos)";

    // First access should load from disk
    const first_result = ctx.store.get(io, test_fx, .COMP, ctx.mappings_list);
    try std.testing.expect(first_result != null);
    try std.testing.expect(ctx.store.COMP.count() == 1);

    // Second access should use cache
    const second_result = ctx.store.get(io, test_fx, .COMP, ctx.mappings_list);
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
    const io = std.testing.io;
    var ctx = try TestContext.init(io);
    defer ctx.deinit();

    const nonexistent_fx = "VST: NonexistentPlugin";

    try std.testing.expect(ctx.store.COMP.count() == 1);
    const result = ctx.store.get(io, nonexistent_fx, .COMP, ctx.mappings_list);
    try std.testing.expect(result == null);
    try std.testing.expect(ctx.store.COMP.count() == 1); // Should not cache failed attempts
}

test "MapStore - all values are within MIDI range (0-127)" {
    const io = std.testing.io;
    var ctx = try TestContext.init(io);
    defer ctx.deinit();

    const test_fx = "VST: ReaComp (Cockos)";

    const result = ctx.store.get(io, test_fx, .COMP, ctx.mappings_list);
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

    pub fn init(io: std.Io) !TestContext {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        errdefer arena.deinit();
        const allocator = arena.allocator();

        var mem: [std.fs.max_path_bytes]u8 = undefined;
        const pth = mem[0..try std.Io.Dir.cwd().realPathFile(io, ".", &mem)];
        const config_path = try std.fs.path.resolve(allocator, &.{ pth, "src/resources/" });
        const config_path_z = try allocator.dupeSentinel(u8, config_path, 0);

        var config = try settings.init(allocator, io, config_path_z);

        // Because the MapStore stores a pointer to the MappingsList, we need to
        // heap-allocate it so that the pointer remains stable when TestContext is
        // returned by value (returning by value moves the struct, which would
        // invalidate any internal pointer).
        const ml = try allocator.create(MappingsList);
        ml.* = MappingsList.init(allocator, io, config_path_z);

        const store = try MapStore.init(allocator, io, config_path_z, ml, &config.default_fx);

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
    const io = std.testing.io;
    var ctx = try TestContext.init(io);
    defer ctx.deinit();

    const test_fx = "VST: ReaComp (Cockos)";

    const result = ctx.store.get(io, test_fx, .COMP, ctx.mappings_list);
    try std.testing.expect(result != null);

    // Verify that the preferred mapping is set
    const preferred = ctx.store.getPreferredMapping(test_fx, .COMP);
    try std.testing.expect(preferred != null);
    try std.testing.expect(std.mem.endsWith(u8, preferred.?, "default.ini"));
}

test "MapStore: get - returns null for missing maps" {
    const io = std.testing.io;
    var ctx = try TestContext.init(io);
    defer ctx.deinit();

    const nonexistent_fx = "VST: BogusPlugin";

    const result = ctx.store.get(io, nonexistent_fx, .COMP, ctx.mappings_list);
    try std.testing.expect(result == null);
}

test "MapStore - get: basic" {
    const io = std.testing.io;
    var ctx = try TestContext.init(io);
    defer ctx.deinit();

    const test_fx = "VST: ReaComp (Cockos)";

    // First access loads default mapping
    const first_result = ctx.store.get(io, test_fx, .COMP, ctx.mappings_list);
    try std.testing.expect(first_result != null);

    // Verify FxMaps exists for this FX
    const fx_maps = ctx.store.COMP.get(test_fx);
    try std.testing.expect(fx_maps != null);

    // Because we loaded the default mapping, the mappings hashmap should have one entry
    try std.testing.expectEqual(@as(usize, 1), fx_maps.?.mappings.count());

    // Second access uses cache
    const second_result = ctx.store.get(io, test_fx, .COMP, ctx.mappings_list);
    try std.testing.expect(second_result != null);
}

test "MapStore - get: handling FX with zero mappings" {
    const io = std.testing.io;
    var ctx = try TestContext.init(io);
    defer ctx.deinit();

    const nonexistent_fx = "VST: BrandNewPlugin";

    // Because no mappings exist for this FX, get should return null
    const result = ctx.store.get(io, nonexistent_fx, .EQ, ctx.mappings_list);
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
//     const bogus_path_z = try ctx.allocator.dupeSentinel(u8, bogus_path, 0);
//     const result = ctx.store.setPreferredMapping(test_fx, .COMP, bogus_path_z);

//     try std.testing.expectError(error.MappingNotFound, result);
// }

test "MapStore: setPreferredMapping - returns error for unfound FX" {
    const io = std.testing.io;
    var ctx = try TestContext.init(io);
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
    var fbs: std.Io.Reader = .fixed(example);
    var parser = ini.parse(testing.allocator, &fbs, ";#");
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
    var fbs: std.Io.Reader = .fixed(example);
    var parser = ini.parse(testing.allocator, &fbs, ";#");
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
    var fbs: std.Io.Reader = .fixed(example);
    var parser = ini.parse(testing.allocator, &fbs, ";#");
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
    const io = std.testing.io;
    var ctx = try TestContext.init(io);
    defer ctx.deinit();

    const test_fx = "VST: ReaComp (Cockos)";

    // Load the mapping first
    _ = ctx.store.get(io, test_fx, .COMP, ctx.mappings_list);

    // Because the default mapping files have no fx_preset field,
    // getPresetName should return null
    const preset = ctx.store.getPresetName(test_fx, .COMP);
    try std.testing.expect(preset == null);
}

test "MapStore: getPresetName returns null for unknown FX" {
    const io = std.testing.io;
    var ctx = try TestContext.init(io);
    defer ctx.deinit();

    const preset = ctx.store.getPresetName("VST: NonexistentPlugin", .COMP);
    try std.testing.expect(preset == null);
}

test "readToU8Struct: version 1 parses successfully" {
    const example =
        \\ version=1
        \\ module=COMP
        \\ Comp_Thresh=10
    ;
    var fbs: std.Io.Reader = .fixed(example);
    var parser = ini.parse(std.testing.allocator, &fbs, ";#");
    defer parser.deinit();

    var found_module: ?ModulesList = null;
    var comp = Comp{};
    _ = try readToU8Struct(&comp, &parser, &found_module, null, std.testing.allocator);
    try std.testing.expectEqual(@as(?u16, 10), comp.Comp_Thresh);
}

test "readToU8Struct: missing version field returns error.MissingVersion" {
    const example =
        \\ module=COMP
        \\ Comp_Thresh=10
    ;
    var fbs: std.Io.Reader = .fixed(example);
    var parser = ini.parse(std.testing.allocator, &fbs, ";#");
    defer parser.deinit();

    var found_module: ?ModulesList = null;
    var comp = Comp{};
    const result = readToU8Struct(&comp, &parser, &found_module, null, std.testing.allocator);
    try std.testing.expectError(error.MissingVersion, result);
}

test "readToU8Struct: version 2 returns error.UnsupportedMapVersion" {
    const example =
        \\ version=2
        \\ module=COMP
        \\ Comp_Thresh=10
    ;
    var fbs: std.Io.Reader = .fixed(example);
    var parser = ini.parse(std.testing.allocator, &fbs, ";#");
    defer parser.deinit();

    var found_module: ?ModulesList = null;
    var comp = Comp{};
    const result = readToU8Struct(&comp, &parser, &found_module, null, std.testing.allocator);
    try std.testing.expectError(error.UnsupportedMapVersion, result);
}
