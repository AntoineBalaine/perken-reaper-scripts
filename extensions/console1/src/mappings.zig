const std = @import("std");
const ini = @import("ini");
const settings = @import("settings.zig");
const statemachine = @import("statemachine.zig");
const c1 = @import("c1.zig");
const ModulesList = statemachine.ModulesList;
const fs_helpers = @import("fs_helpers.zig");
const log = std.log.scoped(.mappings);

pub const MAPPING_FORMAT_VERSION = 1;

pub const Comp = struct {
    version: u8 = MAPPING_FORMAT_VERSION,
    Comp_Attack: ?u8 = null,
    Comp_DryWet: ?u8 = null,
    Comp_Ratio: ?u8 = null,
    Comp_Release: ?u8 = null,
    Comp_Thresh: ?u8 = null,
    Comp_comp: ?u8 = null,
    // Comp_Mtr : u8,
};

pub const Eq = struct {
    version: u8 = MAPPING_FORMAT_VERSION,
    Eq_HiFrq: ?u8 = null,
    Eq_HiGain: ?u8 = null,
    Eq_HiMidFrq: ?u8 = null,
    Eq_HiMidGain: ?u8 = null,
    Eq_HiMidQ: ?u8 = null,
    Eq_LoFrq: ?u8 = null,
    Eq_LoGain: ?u8 = null,
    Eq_LoMidFrq: ?u8 = null,
    Eq_LoMidGain: ?u8 = null,
    Eq_LoMidQ: ?u8 = null,
    Eq_eq: ?u8 = null,
    Eq_hp_shape: ?u8 = null,
    Eq_lp_shape: ?u8 = null,
};

pub const Inpt = struct {
    version: u8 = MAPPING_FORMAT_VERSION,
    // Inpt_MtrLft : u8 = 0 ,
    // Inpt_MtrRgt : u8 = 0 ,
    Inpt_Gain: ?u8 = null,
    Inpt_HiCut: ?u8 = null,
    Inpt_LoCut: ?u8 = null,
    Inpt_disp_mode: ?u8 = null,
    Inpt_disp_on: ?u8 = null,
    Inpt_filt_to_comp: ?u8 = null,
    Inpt_phase_inv: ?u8 = null,
    Inpt_preset: ?u8 = null,
};

pub const Outpt = struct {
    version: u8 = MAPPING_FORMAT_VERSION,
    Out_Drive: ?u8 = null,
    Out_DriveChar: ?u8 = null,
    // Out_MtrLft : u8 = null,
    // Out_MtrRgt : u8 = null,
    Out_Pan: ?u8 = null,
    Out_Vol: ?u8 = null,
    // Out_mute : u8 = null,
    // Out_solo : u8 = null,
};

pub const Shp = struct {
    version: u8 = MAPPING_FORMAT_VERSION,
    Shp_Gate: ?u8 = null,
    Shp_GateRelease: ?u8 = null,
    Shp_Punch: ?u8 = null,
    Shp_hard_gate: ?u8 = null,
    Shp_shape: ?u8 = null,
    Shp_sustain: ?u8 = null,
};

/// Tagged union representing a loaded mapping for any module type.
/// null indicates no mapping was found or loading failed - or was never set.
pub const TaggedMapping = union(ModulesList) {
    INPUT: Inpt,
    GATE: Shp,
    EQ: Eq,
    COMP: Comp,
    OUTPT: Outpt,
    pub fn empty(mode: ModulesList) TaggedMapping {
        switch (mode) {
            .INPUT => Inpt{},
            .GATE => Shp{},
            .EQ => Eq{},
            .COMP => Comp{},
            .OUTPT => Outpt{},
        }
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
controller_dir: [*:0]const u8,
allocator: std.mem.Allocator,

pub fn empty(allocator: std.mem.Allocator, controller_dir: [*:0]const u8) @This() {
    const self: MapStore = .{
        .INPUT = std.StringArrayHashMapUnmanaged(FxMaps(Inpt)){},
        .GATE = std.StringArrayHashMapUnmanaged(FxMaps(Shp)){},
        .EQ = std.StringArrayHashMapUnmanaged(FxMaps(Eq)){},
        .COMP = std.StringArrayHashMapUnmanaged(FxMaps(Comp)){},
        .OUTPT = std.StringArrayHashMapUnmanaged(FxMaps(Outpt)){},
        .controller_dir = controller_dir,
        .allocator = allocator,
    };
    return self;
}

pub fn init(allocator: std.mem.Allocator, controller_dir: [*:0]const u8, defaults: *settings.DefaultFx) !MapStore {
    var self: MapStore = .empty(allocator, controller_dir);
    // find the mappings for the defaults
    var iterator = defaults.iterator();
    while (iterator.next()) |defaultsEntry| {
        const fxName = defaultsEntry.value.*;

        if (fxName) |fx_name| {
            // use self.getMap() only for its side-effect: storing into the map.
            // Its return value is only meant to be used by self.get()
            _ = self.getMap(fx_name, defaultsEntry.key, "default") catch {
                continue;
            };
        }
    }
    return self;
}

pub fn deinit(self: *MapStore) void {
    log.debug("Cleaning up MapStore", .{});

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

/// find fx mapping in storage. If unfound, search it from disk. If still unfound, return null.
/// Because we now store multiple mappings per FX, we return the preferred mapping.
pub fn get(self: *MapStore, fxName: [:0]const u8, module: ModulesList) ?TaggedMapping {
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
                return self.getMap(fxName, module, "default") catch null;
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
                return self.getMap(fxName, module, "default") catch null;
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
                return self.getMap(fxName, module, "default") catch null;
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
                return self.getMap(fxName, module, "default") catch null;
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
                return self.getMap(fxName, module, "default") catch null;
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
    }
}

/// fetch mapping from disk, parse it, store it, and return it.
/// Because we now support multiple mappings per FX, we use directory-based paths: maps/<MODULE>/<fx_name>/<mapping_name>.ini
pub fn getMap(self: *MapStore, fxName: [:0]const u8, module: ModulesList, mapping_name: [:0]const u8) !TaggedMapping {
    var name_buf: [512:0]u8 = undefined;
    const sanitized_name = try fs_helpers.sanitizeFxName(&name_buf, fxName);

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const filePath = fs_helpers.joinStrings(&path_buffer, &.{
        std.mem.span(self.controller_dir),
        std.fs.path.sep_str,
        "maps",
        std.fs.path.sep_str,
        @tagName(module),
        std.fs.path.sep_str,
        sanitized_name,
        std.fs.path.sep_str,
        mapping_name,
        ".ini",
    });

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

    // Because filePath is []const u8, we need to duplicate it with a sentinel for storage
    const filePath_z = try self.allocator.dupeZ(u8, filePath);

    const mapping: TaggedMapping = switch (module) {
        .COMP => {
            var comp = Comp{};
            _ = try readToU8Struct(&comp, &parser);

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
            _ = try readToU8Struct(&eq, &parser);

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
            _ = try readToU8Struct(&inpt, &parser);

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
            _ = try readToU8Struct(&outpt, &parser);

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
            _ = try readToU8Struct(&shp, &parser);

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
    };

    return mapping;
}

/// parse comp/eq/gate/input/output structs
fn readToU8Struct(ret_struct: anytype, parser: anytype) !@TypeOf(ret_struct) {
    const T = @TypeOf(ret_struct.*);
    std.debug.assert(@typeInfo(T) == .@"struct");

    var version_found = false;

    while (try parser.*.next()) |record| {
        switch (record) {
            .property => |kv| {
                inline for (std.meta.fields(T)) |ns_info| {
                    if (std.mem.eql(u8, ns_info.name, kv.key)) {
                        const field_type = @TypeOf(@field(ret_struct, ns_info.name));
                        if (field_type == ?u8 or field_type == u8) {
                            const parsed = std.fmt.parseInt(u8, kv.value, 10) catch null;
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

/// Because this function now takes pure parameters, it is more testable and has clearer dependencies.
pub fn saveToFile(self: *MapStore, module: ModulesList, fx_name: [:0]const u8, mapping: TaggedMapping, mapping_name: [:0]const u8) !void {
    // Build path: resourcePath/maps/<MODULE>/<fx_name>/<mapping_name>.ini
    var name_buf: [512:0]u8 = undefined;
    const sanitized_name = try fs_helpers.sanitizeFxName(&name_buf, fx_name);

    // Create the directory structure first
    var dir_path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir_path = fs_helpers.joinStrings(&dir_path_buf, &.{
        std.mem.span(self.controller_dir),
        std.fs.path.sep_str,
        "maps",
        std.fs.path.sep_str,
        @tagName(module),
        std.fs.path.sep_str,
        sanitized_name,
    });

    // Because we need to create the directory before saving the file, we make it recursively
    std.fs.makeDirAbsolute(dir_path) catch |err| {
        if (err != error.PathAlreadyExists) {
            log.err("Failed to create directory: {s}", .{@errorName(err)});
            return err;
        }
    };

    // Create path buffers and join components
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = fs_helpers.joinStrings(&path_buf, &.{
        std.mem.span(self.controller_dir),
        std.fs.path.sep_str,
        "maps",
        std.fs.path.sep_str,
        @tagName(module),
        std.fs.path.sep_str,
        sanitized_name,
        std.fs.path.sep_str,
        mapping_name,
        ".ini",
    });

    // Create or truncate file
    const file = try std.fs.createFileAbsolute(path, .{
        .read = true,
        .truncate = true,
    });
    defer file.close();

    // Write mappings
    var writer = file.writer();

    // Write different fields based on module type
    switch (mapping) {
        .COMP => |comp| inline for (std.meta.fields(@TypeOf(comp))) |field| {
            try writer.print("{s} = ", .{field.name});
            try formatOptionalU8(@field(comp, field.name), writer);
            try writer.writeByte('\n');
        },
        .EQ => |eq| inline for (std.meta.fields(@TypeOf(eq))) |field| {
            try writer.print("{s} = ", .{field.name});
            try formatOptionalU8(@field(eq, field.name), writer);
            try writer.writeByte('\n');
        },
        .INPUT => |input| inline for (std.meta.fields(@TypeOf(input))) |field| {
            try writer.print("{s} = ", .{field.name});
            try formatOptionalU8(@field(input, field.name), writer);
            try writer.writeByte('\n');
        },
        .OUTPT => |outpt| inline for (std.meta.fields(@TypeOf(outpt))) |field| {
            try writer.print("{s} = ", .{field.name});
            try formatOptionalU8(@field(outpt, field.name), writer);
            try writer.writeByte('\n');
        },
        .GATE => |gate| inline for (std.meta.fields(@TypeOf(gate))) |field| {
            try writer.print("{s} = ", .{field.name});
            try formatOptionalU8(@field(gate, field.name), writer);
            try writer.writeByte('\n');
        },
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

    var ret_str: ExampleStruct = .{
        .repositoryformatversion = 0,
    };
    _ = try readToU8Struct(&ret_str, &parser);
    try expect(ret_str.repositoryformatversion == 8);
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
    const first_result = ctx.store.get(test_fx, .COMP);
    try std.testing.expect(first_result != null);
    try std.testing.expect(ctx.store.COMP.count() == 1);

    // Second access should use cache
    const second_result = ctx.store.get(test_fx, .COMP);
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
    const result = ctx.store.get(nonexistent_fx, .COMP);
    try std.testing.expect(result == null);
    try std.testing.expect(ctx.store.COMP.count() == 1); // Should not cache failed attempts
}

test "MapStore - all values are within MIDI range (0-127)" {
    var ctx = try TestContext.init();
    defer ctx.deinit();

    const test_fx = "VST: ReaComp (Cockos)";

    const result = ctx.store.get(test_fx, .COMP);
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

/// Helper function to get the parameter index for a given CC from a mapping
pub fn getParamForCC(cc: c1.CCs, mapping: TaggedMapping) ?u8 {
    // Get the module for this CC using the existing toModule method
    const module = cc.toModule();

    // Check if the mapping is for the correct module
    if (@as(ModulesList, @enumFromInt(@intFromEnum(mapping))) != module) {
        return null;
    }

    // Hard-coded correspondences for each CC
    return switch (cc) {
        // COMP module parameters
        .Comp_Attack => mapping.COMP.Comp_Attack,
        .Comp_DryWet => mapping.COMP.Comp_DryWet,
        .Comp_Ratio => mapping.COMP.Comp_Ratio,
        .Comp_Release => mapping.COMP.Comp_Release,
        .Comp_Thresh => mapping.COMP.Comp_Thresh,
        .Comp_comp => mapping.COMP.Comp_comp,

        // EQ module parameters
        .Eq_HiFrq => mapping.EQ.Eq_HiFrq,
        .Eq_HiGain => mapping.EQ.Eq_HiGain,
        .Eq_HiMidFrq => mapping.EQ.Eq_HiMidFrq,
        .Eq_HiMidGain => mapping.EQ.Eq_HiMidGain,
        .Eq_HiMidQ => mapping.EQ.Eq_HiMidQ,
        .Eq_LoFrq => mapping.EQ.Eq_LoFrq,
        .Eq_LoGain => mapping.EQ.Eq_LoGain,
        .Eq_LoMidFrq => mapping.EQ.Eq_LoMidFrq,
        .Eq_LoMidGain => mapping.EQ.Eq_LoMidGain,
        .Eq_LoMidQ => mapping.EQ.Eq_LoMidQ,
        .Eq_eq => mapping.EQ.Eq_eq,
        .Eq_hp_shape => mapping.EQ.Eq_hp_shape,
        .Eq_lp_shape => mapping.EQ.Eq_lp_shape,

        // INPUT module parameters
        .Inpt_Gain => mapping.INPUT.Inpt_Gain,
        .Inpt_HiCut => mapping.INPUT.Inpt_HiCut,
        .Inpt_LoCut => mapping.INPUT.Inpt_LoCut,
        .Inpt_disp_mode => mapping.INPUT.Inpt_disp_mode,
        .Inpt_disp_on => mapping.INPUT.Inpt_disp_on,
        .Inpt_filt_to_comp => mapping.INPUT.Inpt_filt_to_comp,
        .Inpt_phase_inv => mapping.INPUT.Inpt_phase_inv,
        .Inpt_preset => mapping.INPUT.Inpt_preset,

        // OUTPT module parameters
        .Out_Drive => mapping.OUTPT.Out_Drive,
        .Out_DriveChar => mapping.OUTPT.Out_DriveChar,
        .Out_Pan => mapping.OUTPT.Out_Pan,
        .Out_Vol => mapping.OUTPT.Out_Vol,

        // GATE module parameters
        .Shp_Gate => mapping.GATE.Shp_Gate,
        .Shp_GateRelease => mapping.GATE.Shp_GateRelease,
        .Shp_Punch => mapping.GATE.Shp_Punch,
        .Shp_hard_gate => mapping.GATE.Shp_hard_gate,
        .Shp_shape => mapping.GATE.Shp_shape,
        .Shp_sustain => mapping.GATE.Shp_sustain,

        // Other CCs that don't map to parameters
        else => unreachable,
    };
}

const TestContext = struct {
    arena: std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,
    config: settings.Preferences,
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
        const store = try MapStore.init(allocator, config_path_z, &config.default_fx);

        return TestContext{
            .arena = arena,
            .allocator = allocator,
            .config = config,
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

    const result = ctx.store.get(test_fx, .COMP);
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

    const result = ctx.store.get(nonexistent_fx, .COMP);
    try std.testing.expect(result == null);
}

test "MapStore - get: basic" {
    var ctx = try TestContext.init();
    defer ctx.deinit();

    const test_fx = "VST: ReaComp (Cockos)";

    // First access loads default mapping
    const first_result = ctx.store.get(test_fx, .COMP);
    try std.testing.expect(first_result != null);

    // Verify FxMaps exists for this FX
    const fx_maps = ctx.store.COMP.get(test_fx);
    try std.testing.expect(fx_maps != null);

    // Because we loaded the default mapping, the mappings hashmap should have one entry
    try std.testing.expectEqual(@as(usize, 1), fx_maps.?.mappings.count());

    // Second access uses cache
    const second_result = ctx.store.get(test_fx, .COMP);
    try std.testing.expect(second_result != null);
}

test "MapStore - get: handling FX with zero mappings" {
    var ctx = try TestContext.init();
    defer ctx.deinit();

    const nonexistent_fx = "VST: BrandNewPlugin";

    // Because no mappings exist for this FX, get should return null
    const result = ctx.store.get(nonexistent_fx, .EQ);
    try std.testing.expect(result == null);
}

// test "MapStore: setPreferredMapping - validates filepath exists" {
//     var ctx = try TestContext.init();
//     defer ctx.deinit();

//     const test_fx = "VST: ReaComp (Cockos)";

//     // Load the default mapping first
//     _ = ctx.store.get(test_fx, .COMP);

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
