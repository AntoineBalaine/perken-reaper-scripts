const std = @import("std");
const ini = @import("ini");
const logger = @import("logger.zig");
const settings = @import("settings.zig");
const statemachine = @import("statemachine.zig");
const MappingState = statemachine.MappingState;
const ModulesList = statemachine.ModulesList;
pub const UNMAPPED_PARAM: u8 = std.math.maxInt(u8); // or -1, or another sentinel value

/// values are set to std.math.maxInt(u8) for unset mappings
pub const Comp = struct {
    Comp_Attack: u8 = UNMAPPED_PARAM,
    Comp_DryWet: u8 = UNMAPPED_PARAM,
    Comp_Ratio: u8 = UNMAPPED_PARAM,
    Comp_Release: u8 = UNMAPPED_PARAM,
    Comp_Thresh: u8 = UNMAPPED_PARAM,
    Comp_comp: u8 = UNMAPPED_PARAM,
    // Comp_Mtr : u8,
};

/// values are set to UNMAPPED_PARAM for unset mappings
pub const Eq = struct {
    Eq_HiFrq: u8 = UNMAPPED_PARAM,
    Eq_HiGain: u8 = UNMAPPED_PARAM,
    Eq_HiMidFrq: u8 = UNMAPPED_PARAM,
    Eq_HiMidGain: u8 = UNMAPPED_PARAM,
    Eq_HiMidQ: u8 = UNMAPPED_PARAM,
    Eq_LoFrq: u8 = UNMAPPED_PARAM,
    Eq_LoGain: u8 = UNMAPPED_PARAM,
    Eq_LoMidFrq: u8 = UNMAPPED_PARAM,
    Eq_LoMidGain: u8 = UNMAPPED_PARAM,
    Eq_LoMidQ: u8 = UNMAPPED_PARAM,
    Eq_eq: u8 = UNMAPPED_PARAM,
    Eq_hp_shape: u8 = UNMAPPED_PARAM,
    Eq_lp_shape: u8 = UNMAPPED_PARAM,
};

/// values are set to UNMAPPED_PARAM for unset mappings
pub const Inpt = struct {
    // Inpt_MtrLft : u8 = 0 ,
    // Inpt_MtrRgt : u8 = 0 ,
    Inpt_Gain: u8 = UNMAPPED_PARAM,
    Inpt_HiCut: u8 = UNMAPPED_PARAM,
    Inpt_LoCut: u8 = UNMAPPED_PARAM,
    Inpt_disp_mode: u8 = UNMAPPED_PARAM,
    Inpt_disp_on: u8 = UNMAPPED_PARAM,
    Inpt_filt_to_comp: u8 = UNMAPPED_PARAM,
    Inpt_phase_inv: u8 = UNMAPPED_PARAM,
    Inpt_preset: u8 = UNMAPPED_PARAM,
};

/// values are set to UNMAPPED_PARAM for unset mappings
pub const Outpt = struct {
    Out_Drive: u8 = UNMAPPED_PARAM,
    Out_DriveChar: u8 = UNMAPPED_PARAM,
    // Out_MtrLft : u8 = UNMAPPED_PARAM,
    // Out_MtrRgt : u8 = UNMAPPED_PARAM,
    Out_Pan: u8 = UNMAPPED_PARAM,
    Out_Vol: u8 = UNMAPPED_PARAM,
    // Out_mute : u8 = UNMAPPED_PARAM,
    // Out_solo : u8 = UNMAPPED_PARAM,
};

/// values are set to UNMAPPED_PARAM for unset mappings
pub const Shp = struct {
    Shp_Gate: u8 = UNMAPPED_PARAM,
    Shp_GateRelease: u8 = UNMAPPED_PARAM,
    Shp_Punch: u8 = UNMAPPED_PARAM,
    Shp_hard_gate: u8 = UNMAPPED_PARAM,
    Shp_shape: u8 = UNMAPPED_PARAM,
    Shp_sustain: u8 = UNMAPPED_PARAM,
};

/// FxMap associates an Fx index with a module map
pub const FxMap = struct {
    COMP: ?std.meta.Tuple(&.{ u8, ?Comp }) = null,
    EQ: ?std.meta.Tuple(&.{ u8, ?Eq }) = null,
    INPUT: ?std.meta.Tuple(&.{ u8, ?Inpt }) = null,
    OUTPT: ?std.meta.Tuple(&.{ u8, ?Outpt }) = null,
    GATE: ?std.meta.Tuple(&.{ u8, ?Shp }) = null,
};

/// Tagged union representing a loaded mapping for any module type.
/// null indicates no mapping was found or loading failed - or was never set.
const TaggedMapping = union(ModulesList) {
    INPUT: ?Inpt,
    GATE: ?Shp,
    EQ: ?Eq,
    COMP: ?Comp,
    OUTPT: ?Outpt,
};

/// MapStore manages FX parameter mappings with lazy loading.
/// Mappings are loaded from disk only when requested and cached for future use.
pub const MapStore = @This();

COMP: std.StringHashMapUnmanaged(Comp),
EQ: std.StringHashMapUnmanaged(Eq),
INPUT: std.StringHashMapUnmanaged(Inpt),
OUTPT: std.StringHashMapUnmanaged(Outpt),
GATE: std.StringHashMapUnmanaged(Shp),
controller_dir: [*:0]const u8,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, controller_dir: [*:0]const u8, defaults: *settings.DefaultFx) !MapStore {
    var self: MapStore = .{
        .COMP = std.StringHashMapUnmanaged(Comp){},
        .EQ = std.StringHashMapUnmanaged(Eq){},
        .INPUT = std.StringHashMapUnmanaged(Inpt){},
        .OUTPT = std.StringHashMapUnmanaged(Outpt){},
        .GATE = std.StringHashMapUnmanaged(Shp){},
        .controller_dir = try allocator.dupeZ(u8, std.mem.span(controller_dir)),
        .allocator = allocator,
    };
    // find the mappings for the defaults
    var iterator = defaults.iterator();
    while (iterator.next()) |defaultsEntry| {
        const fxName = defaultsEntry.value;
        // use self.getMap() only for its side-effect: storing into the map.
        // Its return value is only meant to be used by self.get()
        _ = self.getMap(fxName.*, defaultsEntry.key) catch {
            continue;
        };
    }
    return self;
}

pub fn deinit(self: *MapStore) void {
    logger.log(.debug, "Cleaning up MapStore", .{}, null, self.allocator);
    self.allocator.free(std.mem.span(self.controller_dir)); // Free our copy
    self.COMP.deinit(self.allocator);
    self.EQ.deinit(self.allocator);
    self.INPUT.deinit(self.allocator);
    self.OUTPT.deinit(self.allocator);
    self.GATE.deinit(self.allocator);
}

/// find fx mapping in storage. If unfound, search it from disk. If still unfound, return null.
pub fn get(self: *MapStore, fxName: [:0]const u8, module: ModulesList) TaggedMapping {
    switch (module) {
        .COMP => {
            if (self.COMP.get(fxName)) |v| {
                return TaggedMapping{ .COMP = v };
            } else {
                logger.log(.err, "mapping {s} unfound\n", .{fxName}, null, self.allocator);
                return self.getMap(fxName, module) catch TaggedMapping{ .COMP = null };
            }
        },
        .EQ => {
            if (self.EQ.get(fxName)) |v| {
                return TaggedMapping{ .EQ = v };
            } else {
                logger.log(.err, "mapping {s} unfound\n", .{fxName}, null, self.allocator);
                return self.getMap(fxName, module) catch TaggedMapping{ .EQ = null };
            }
        },
        .INPUT => {
            return if (self.INPUT.get(fxName)) |v| {
                return TaggedMapping{ .INPUT = v };
            } else {
                logger.log(.err, "mapping {s} unfound\n", .{fxName}, null, self.allocator);
                return self.getMap(fxName, module) catch TaggedMapping{ .INPUT = null };
            };
        },
        .OUTPT => {
            if (self.OUTPT.get(fxName)) |v| {
                return TaggedMapping{ .OUTPT = v };
            } else {
                logger.log(.err, "mapping {s} unfound\n", .{fxName}, null, self.allocator);
                return self.getMap(fxName, module) catch TaggedMapping{ .OUTPT = null };
            }
        },
        .GATE => {
            if (self.GATE.get(fxName)) |v| {
                return TaggedMapping{ .GATE = v };
            } else {
                logger.log(.err, "mapping {s} unfound\n", .{fxName}, null, self.allocator);
                return self.getMap(fxName, module) catch TaggedMapping{ .GATE = null };
            }
        },
    }
}

/// fetch mapping from disk, parse it, store it, and return it.
fn getMap(self: *MapStore, fxName: [:0]const u8, module: ModulesList) !TaggedMapping {
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const subdir = @tagName(module);

    // NOTE: should this really by 4096 bytes? Is there a cost to having a larger buffer?
    var nameBuf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    var sanitizedFxName: []const u8 = undefined;
    const extension = ".ini";
    if (std.mem.indexOfScalar(u8, fxName, '/') != null) {
        _ = std.mem.replace(u8, fxName, "/", "_", &nameBuf);
        @memcpy(nameBuf[fxName.len .. fxName.len + extension.len], extension);
    } else {
        @memcpy(nameBuf[0..fxName.len], fxName);
        @memcpy(nameBuf[fxName.len .. fxName.len + extension.len], extension);
    }
    sanitizedFxName = nameBuf[0 .. fxName.len + extension.len];

    const elements = [_][]const u8{ std.mem.span(self.controller_dir), "maps", subdir, sanitizedFxName };

    var pos: usize = 0;
    for (elements, 0..) |element, idx| {
        @memcpy(buf[pos .. pos + element.len], element);
        pos += element.len;
        if (idx != elements.len - 1) { // not last in list
            @memcpy(buf[pos .. pos + 1], &[_]u8{@as(u8, @intCast(std.fs.path.sep))});
            pos += 1;
        }
    }
    const filePath = buf[0..pos];
    const file = try std.fs.openFileAbsolute(filePath, .{});
    defer file.close();
    var parser = ini.parse(self.allocator, file.reader());
    defer parser.deinit();

    const mapping: TaggedMapping = switch (module) {
        .COMP => {
            var comp = Comp{};
            _ = try readToU8Struct(&comp, &parser);
            // side-effect: store in hashmap
            self.COMP.put(self.allocator, fxName, comp) catch |err| blk: {
                logger.log(.err, "Failed to store mapping: {s}", .{@errorName(err)}, null, self.allocator);
                break :blk;
            };
            return TaggedMapping{ .COMP = comp };
        },
        .EQ => {
            var eq = Eq{};
            _ = try readToU8Struct(&eq, &parser);
            self.EQ.put(self.allocator, fxName, eq) catch |err| {
                logger.log(.err, "Failed to store mapping: {s}", .{@errorName(err)}, null, self.allocator);
            }; // side-effect: store in hashmap
            return TaggedMapping{ .EQ = eq };
        },
        .INPUT => {
            var inpt: Inpt = Inpt{};
            _ = try readToU8Struct(&inpt, &parser);
            self.INPUT.put(self.allocator, fxName, inpt) catch |err| {
                logger.log(.err, "Failed to store mapping: {s}", .{@errorName(err)}, null, self.allocator);
            }; // side-effect: store in hashmap
            return TaggedMapping{ .INPUT = inpt };
        },
        .OUTPT => {
            var outpt: Outpt = Outpt{};
            _ = try readToU8Struct(&outpt, &parser);
            self.OUTPT.put(self.allocator, fxName, outpt) catch |err| {
                logger.log(.err, "Failed to store mapping: {s}", .{@errorName(err)}, null, self.allocator);
            }; // side-effect: store in hashmap
            return TaggedMapping{ .OUTPT = outpt };
        },
        .GATE => {
            var shp: Shp = Shp{};
            _ = try readToU8Struct(&shp, &parser);
            self.GATE.put(self.allocator, fxName, shp) catch |err| {
                logger.log(.err, "Failed to store mapping: {s}", .{@errorName(err)}, null, self.allocator);
            }; // side-effect: store in hashmap
            return TaggedMapping{ .GATE = shp };
        },
    };

    return mapping;
}

/// parse comp/eq/gate/input/output structs
fn readToU8Struct(ret_struct: anytype, parser: anytype) !@TypeOf(ret_struct) {
    const T = @TypeOf(ret_struct.*);
    std.debug.assert(@typeInfo(T) == .Struct);

    while (try parser.*.next()) |record| {
        switch (record) {
            .property => |kv| {
                inline for (std.meta.fields(T)) |ns_info| {
                    if (std.mem.eql(u8, ns_info.name, kv.key)) {
                        if (@TypeOf(@field(ret_struct, ns_info.name)) == u8) {
                            // const field = &@field(ret_struct, ns_info.name);
                            // field.* = parsed;
                            const parsed = std.fmt.parseInt(u8, kv.value, 10) catch std.math.maxInt(u8);
                            @field(ret_struct, ns_info.name) = parsed;
                        }
                    }
                }
            },
            .section => {},
            .enumeration => {},
        }
    }
    return ret_struct;
}

pub fn saveToFile(self: *MapStore, mapping_state: MappingState) !void {
    // Build path: resourcePath/maps/<MODULE>/<target_fx>.ini

    // Create path buffers and join components
    var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const path = try std.fmt.bufPrint(
        &path_buf,
        "{s}/maps/{s}/{s}.ini",
        .{
            self.controller_dir,
            @tagName(mapping_state.current_mappings),
            mapping_state.target_fx,
        },
    );

    // Create or truncate file
    const file = try std.fs.createFileAbsolute(path, .{
        .read = true,
        .truncate = true,
    });
    defer file.close();

    // Write mappings
    var writer = file.writer();

    // Write different fields based on module type
    switch (mapping_state.current_mappings) {
        .COMP => |comp| inline for (std.meta.fields(@TypeOf(comp))) |field| {
            try writer.print("{s} = {d}\n", .{
                field.name,
                @field(comp, field.name),
            });
        },
        .EQ => |eq| inline for (std.meta.fields(@TypeOf(eq))) |field| {
            try writer.print("{s} = {d}\n", .{
                field.name,
                @field(eq, field.name),
            });
        },
        .INPUT => |input| inline for (std.meta.fields(@TypeOf(input))) |field| {
            try writer.print("{s} = {d}\n", .{
                field.name,
                @field(input, field.name),
            });
        },
        .OUTPT => |outpt| inline for (std.meta.fields(@TypeOf(outpt))) |field| {
            try writer.print("{s} = {d}\n", .{
                field.name,
                @field(outpt, field.name),
            });
        },
        .GATE => |gate| inline for (std.meta.fields(@TypeOf(gate))) |field| {
            try writer.print("{s} = {d}\n", .{
                field.name,
                @field(gate, field.name),
            });
        },
    }
}

test readToU8Struct {
    const expect = std.testing.expect;
    const ExampleStruct = struct {
        repositoryformatversion: u8,
    };
    const example =
        \\ 	repositoryformatversion = 8
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

test "MapStore - initialization and caching" {
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;

    // Setup test directory path
    var mem: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);

    // Initialize config manager first
    const config_path = try std.fs.path.resolve(allocator, &.{ pth, "./resources/" });
    const config_path_z = try allocator.dupeZ(u8, config_path);
    defer allocator.free(config_path);
    defer allocator.free(config_path_z);

    var cur_config = try settings.init(allocator, config_path);
    defer cur_config.deinit();

    // Now setup MapStore with initialized config
    var store = try MapStore.init(
        allocator,
        config_path_z,
        &cur_config.default_fx, // Use cur_config's initialized defaults
    );
    defer store.deinit();

    // Verify empty initialization
    try expect(store.COMP.count() == 1);
    try expect(store.EQ.count() == 1);
    try expect(store.INPUT.count() == 1);
    try expect(store.OUTPT.count() == 1);
    try expect(store.GATE.count() == 1);
}

test "MapStore - lazy loading and caching" {
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;

    // Setup config first
    var mem: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);
    const config_path = try std.fs.path.resolve(allocator, &.{ pth, "./resources/" });
    const config_path_z = try allocator.dupeZ(u8, config_path);
    defer allocator.free(config_path);
    defer allocator.free(config_path_z);

    var cur_config = try settings.init(allocator, config_path);
    defer cur_config.deinit();

    var store = try MapStore.init(
        allocator,
        config_path_z,
        &cur_config.default_fx, // Use cur_config's initialized defaults
    );
    defer store.deinit();

    const test_fx = "VST: ReaComp (Cockos)";

    // First access should load from disk
    const first_result = store.get(test_fx, .COMP);
    try expect(first_result.COMP != null);
    try expect(store.COMP.count() == 1);

    // Second access should use cache
    const second_result = store.get(test_fx, .COMP);
    try expect(second_result.COMP != null);
    try expect(store.COMP.count() == 1);

    // Verify cached values match
    if (first_result.COMP) |first| {
        if (second_result.COMP) |second| {
            try expect(first.Comp_Attack == second.Comp_Attack);
            try expect(first.Comp_Release == second.Comp_Release);
            // ... test other fields
        } else {
            try expect(false); // Should not happen
        }
    }
}

test "MapStore - invalid fx name" {
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;

    // Setup config first
    var mem: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);
    const config_path = try std.fs.path.resolve(allocator, &.{ pth, "./resources/" });
    const config_path_z = try allocator.dupeZ(u8, config_path);
    defer allocator.free(config_path);
    defer allocator.free(config_path_z);
    var cur_config = try settings.init(allocator, config_path);
    defer cur_config.deinit();
    var store = try MapStore.init(
        allocator,
        config_path_z,
        &cur_config.default_fx, // Use cur_config's initialized defaults
    );
    defer store.deinit();

    const nonexistent_fx = "VST: NonexistentPlugin";

    // Should return null mapping for unknown FX
    try expect(store.COMP.count() == 1);
    const result = store.get(nonexistent_fx, .COMP);
    try expect(result.COMP == null);
    try expect(store.COMP.count() == 1); // Should not cache failed attempts
}

test "MapStore - mapping validation" {
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;
    // Setup config first
    var mem: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);
    const config_path = try std.fs.path.resolve(allocator, &.{ pth, "./resources/" });
    const config_path_z = try allocator.dupeZ(u8, config_path);
    defer allocator.free(config_path);
    defer allocator.free(config_path_z);

    var cur_config = try settings.init(allocator, config_path);
    defer cur_config.deinit();
    var store = try MapStore.init(
        allocator,
        config_path_z,
        &cur_config.default_fx, // Use cur_config's initialized defaults
    );
    defer store.deinit();

    const test_fx = "VST: ReaComp (Cockos)";

    const result = store.get(test_fx, .COMP);
    if (result.COMP) |comp| {
        // Test that all values are within MIDI range (0-127)
        try expect(comp.Comp_Attack <= 127);
        try expect(comp.Comp_Release <= 127);
        try expect(comp.Comp_Thresh <= 127);
        // ... test other fields
    } else {
        try expect(false); // Should not happen for known FX
    }
}

test "MapStore - cross-module access" {
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;
    // Setup config first
    var mem: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);
    const config_path = try std.fs.path.resolve(allocator, &.{ pth, "./resources/" });
    const config_path_z = try allocator.dupeZ(u8, config_path);
    defer allocator.free(config_path);
    defer allocator.free(config_path_z);

    var cur_config = try settings.init(allocator, config_path);
    defer cur_config.deinit();
    var store = try MapStore.init(
        allocator,
        config_path_z,
        &cur_config.default_fx, // Use cur_config's initialized defaults
    );
    defer store.deinit();

    const comp_fx = "VST: ReaComp (Cockos)";
    const eq_fx = "VST: ReaEQ (Cockos)";

    // Load both types of mappings
    _ = store.get(comp_fx, .COMP);
    _ = store.get(eq_fx, .EQ);

    // Verify separate caching
    try expect(store.COMP.count() == 1);
    try expect(store.EQ.count() == 1);

    // Try loading comp FX as EQ (should fail gracefully)
    const wrong_module = store.get(comp_fx, .EQ);
    try expect(wrong_module.EQ == null);
}
