const std = @import("std");
const ini = @import("ini");
const settings = @import("settings.zig");
const statemachine = @import("statemachine.zig");
const MappingState = statemachine.MappingState;
const ModulesList = statemachine.ModulesList;
const fs_helpers = @import("fs_helpers.zig");
const log = std.log.scoped(.mappings);

pub const Comp = struct {
    Comp_Attack: ?u8 = null,
    Comp_DryWet: ?u8 = null,
    Comp_Ratio: ?u8 = null,
    Comp_Release: ?u8 = null,
    Comp_Thresh: ?u8 = null,
    Comp_comp: ?u8 = null,
    // Comp_Mtr : u8,
};

pub const Eq = struct {
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
    Shp_Gate: ?u8 = null,
    Shp_GateRelease: ?u8 = null,
    Shp_Punch: ?u8 = null,
    Shp_hard_gate: ?u8 = null,
    Shp_shape: ?u8 = null,
    Shp_sustain: ?u8 = null,
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
pub const TaggedMapping = union(ModulesList) {
    INPUT: Inpt,
    GATE: Shp,
    EQ: Eq,
    COMP: Comp,
    OUTPT: Outpt,
};

/// MapStore manages FX parameter mappings with lazy loading.
/// Mappings are loaded from disk only when requested and cached for future use.
pub const MapStore = @This();

COMP: std.StringArrayHashMapUnmanaged(Comp),
EQ: std.StringArrayHashMapUnmanaged(Eq),
INPUT: std.StringArrayHashMapUnmanaged(Inpt),
OUTPT: std.StringArrayHashMapUnmanaged(Outpt),
GATE: std.StringArrayHashMapUnmanaged(Shp),
controller_dir: [*:0]const u8,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, controller_dir: [*:0]const u8, defaults: *settings.DefaultFx) !MapStore {
    var self: MapStore = .{
        .INPUT = std.StringArrayHashMapUnmanaged(Inpt){},
        .GATE = std.StringArrayHashMapUnmanaged(Shp){},
        .EQ = std.StringArrayHashMapUnmanaged(Eq){},
        .COMP = std.StringArrayHashMapUnmanaged(Comp){},
        .OUTPT = std.StringArrayHashMapUnmanaged(Outpt){},
        .controller_dir = try allocator.dupeZ(u8, std.mem.span(controller_dir)),
        .allocator = allocator,
    };
    // find the mappings for the defaults
    var iterator = defaults.iterator();
    while (iterator.next()) |defaultsEntry| {
        const fxName = defaultsEntry.value.*;

        if (fxName) |fx_name| {
            // use self.getMap() only for its side-effect: storing into the map.
            // Its return value is only meant to be used by self.get()
            _ = self.getMap(fx_name, defaultsEntry.key) catch {
                continue;
            };
        }
    }
    return self;
}

pub fn deinit(self: *MapStore) void {
    log.debug("Cleaning up MapStore", .{});
    self.allocator.free(std.mem.span(self.controller_dir)); // Free our copy
    self.COMP.deinit(self.allocator);
    self.EQ.deinit(self.allocator);
    self.INPUT.deinit(self.allocator);
    self.OUTPT.deinit(self.allocator);
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
pub fn get(self: *MapStore, fxName: [:0]const u8, module: ModulesList) ?TaggedMapping {
    switch (module) {
        .COMP => {
            if (self.COMP.get(fxName)) |v| {
                return TaggedMapping{ .COMP = v };
            } else {
                log.warn("mapping {s} unfound", .{fxName});
                return self.getMap(fxName, module) catch null;
            }
        },
        .EQ => {
            if (self.EQ.get(fxName)) |v| {
                return TaggedMapping{ .EQ = v };
            } else {
                log.warn("mapping {s} unfound", .{fxName});
                return self.getMap(fxName, module) catch null;
            }
        },
        .INPUT => {
            return if (self.INPUT.get(fxName)) |v| {
                return TaggedMapping{ .INPUT = v };
            } else {
                log.warn("mapping {s} unfound", .{fxName});
                return self.getMap(fxName, module) catch null;
            };
        },
        .OUTPT => {
            if (self.OUTPT.get(fxName)) |v| {
                return TaggedMapping{ .OUTPT = v };
            } else {
                log.warn("mapping {s} unfound", .{fxName});
                return self.getMap(fxName, module) catch null;
            }
        },
        .GATE => {
            if (self.GATE.get(fxName)) |v| {
                return TaggedMapping{ .GATE = v };
            } else {
                log.warn("mapping {s} unfound", .{fxName});
                return self.getMap(fxName, module) catch null;
            }
        },
    }
}

fn sanitizeFxName(buf: *[512:0]u8, fx_name: []const u8) ![:0]const u8 {
    const base_name = try std.fmt.bufPrintZ(buf, "{s}", .{fx_name});
    _ = std.mem.replace(u8, base_name, "/", "_", buf);
    return base_name;
}

/// fetch mapping from disk, parse it, store it, and return it.
fn getMap(self: *MapStore, fxName: [:0]const u8, module: ModulesList) !TaggedMapping {
    var name_buf: [512:0]u8 = undefined;
    const sanitized_name = try sanitizeFxName(&name_buf, fxName);

    var path_buffer: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const filePath = fs_helpers.joinStrings(&path_buffer, &.{
        std.mem.span(self.controller_dir),
        std.fs.path.sep_str,
        "maps",
        std.fs.path.sep_str,
        @tagName(module),
        std.fs.path.sep_str,
        sanitized_name,
        ".ini",
    });

    log.debug("Loading mapping from {s}", .{filePath});

    const file = try std.fs.openFileAbsolute(filePath, .{});
    defer file.close();

    var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer temp_arena.deinit();
    var parser = ini.parse(temp_arena.allocator(), file.reader());
    defer parser.deinit(); // doesn’t actually do anything because of arena

    const mapping: TaggedMapping = switch (module) {
        .COMP => {
            var comp = Comp{};
            _ = try readToU8Struct(&comp, &parser);
            // side-effect: store in hashmap
            self.COMP.put(self.allocator, fxName, comp) catch |err| blk: {
                log.err("Failed to store mapping: {s}", .{@errorName(err)});
                break :blk;
            };
            return TaggedMapping{ .COMP = comp };
        },
        .EQ => {
            var eq = Eq{};
            _ = try readToU8Struct(&eq, &parser);
            self.EQ.put(self.allocator, fxName, eq) catch |err| {
                log.err("Failed to store mapping: {s}", .{@errorName(err)});
            }; // side-effect: store in hashmap
            return TaggedMapping{ .EQ = eq };
        },
        .INPUT => {
            var inpt: Inpt = Inpt{};
            _ = try readToU8Struct(&inpt, &parser);
            self.INPUT.put(self.allocator, fxName, inpt) catch |err| {
                log.err("Failed to store mapping: {s}", .{@errorName(err)});
            }; // side-effect: store in hashmap
            return TaggedMapping{ .INPUT = inpt };
        },
        .OUTPT => {
            var outpt: Outpt = Outpt{};
            _ = try readToU8Struct(&outpt, &parser);
            self.OUTPT.put(self.allocator, fxName, outpt) catch |err| {
                log.err("Failed to store mapping: {s}", .{@errorName(err)});
            }; // side-effect: store in hashmap
            return TaggedMapping{ .OUTPT = outpt };
        },
        .GATE => {
            var shp: Shp = Shp{};
            _ = try readToU8Struct(&shp, &parser);
            self.GATE.put(self.allocator, fxName, shp) catch |err| {
                log.err("Failed to store mapping: {s}", .{@errorName(err)});
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
                        if (@TypeOf(@field(ret_struct, ns_info.name)) == ?u8) {
                            // const field = &@field(ret_struct, ns_info.name);
                            // field.* = parsed;
                            const parsed = std.fmt.parseInt(u8, kv.value, 10) catch null;
                            if (parsed) |val| {
                                @field(ret_struct, ns_info.name) = val;
                            }
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

fn formatOptionalU8(value: anytype, writer: anytype) !void {
    const T = @TypeOf(value);
    const info = @typeInfo(T);
    comptime {
        if (info != .Optional) @compileError("Expected optional type, got " ++ @typeName(T));
        if (@typeInfo(info.Optional.child) != .Int and @typeInfo(info.Optional.child) != .Float) @compileError("Expected optional number type, got optional " ++ @typeName(info.Optional.child));
    }
    if (value) |v| {
        try writer.print("{d}", .{v});
    } else {
        // Print nothing for null
        try writer.writeAll("");
    }
}

pub fn saveToFile(self: *MapStore, mapping_state: MappingState) !void {
    // Build path: resourcePath/maps/<MODULE>/<target_fx>.ini
    var name_buf: [512:0]u8 = undefined;
    const sanitized_name = try sanitizeFxName(&name_buf, mapping_state.target_fx);
    // Create path buffers and join components
    var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;

    const path = fs_helpers.joinStrings(&path_buf, &.{
        std.mem.span(self.controller_dir),
        std.fs.path.sep_str,
        "maps",
        std.fs.path.sep_str,
        @tagName(mapping_state.current_mappings),
        std.fs.path.sep_str,
        sanitized_name,
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
    switch (mapping_state.current_mappings) {
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
    const config_path = try std.fs.path.resolve(allocator, &.{ pth, "src/resources/" });
    const config_path_z = try allocator.dupeZ(u8, config_path);
    defer allocator.free(config_path);
    defer allocator.free(config_path_z);

    var cur_config = try settings.init(allocator, config_path_z);
    defer cur_config.test_deinit(allocator);

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
    const config_path = try std.fs.path.resolve(allocator, &.{ pth, "src/resources/" });
    const config_path_z = try allocator.dupeZ(u8, config_path);
    defer allocator.free(config_path);
    defer allocator.free(config_path_z);

    var cur_config = try settings.init(allocator, config_path_z);
    defer cur_config.test_deinit(allocator);

    var store = try MapStore.init(
        allocator,
        config_path_z,
        &cur_config.default_fx, // Use cur_config's initialized defaults
    );
    defer store.deinit();

    const test_fx = "VST: ReaComp (Cockos)";

    // First access should load from disk
    const first_result = store.get(test_fx, .COMP);
    try expect(first_result != null);
    try expect(store.COMP.count() == 1);

    // Second access should use cache
    const second_result = store.get(test_fx, .COMP);
    try expect(second_result != null);
    try expect(store.COMP.count() == 1);

    // Verify cached values match
    if (first_result) |comp_first| {
        const first = comp_first.COMP;
        if (second_result) |comp_second| {
            const second = comp_second.COMP;
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
    const config_path = try std.fs.path.resolve(allocator, &.{ pth, "src/resources/" });
    const config_path_z = try allocator.dupeZ(u8, config_path);
    defer allocator.free(config_path);
    defer allocator.free(config_path_z);
    var cur_config = try settings.init(allocator, config_path_z);
    defer cur_config.test_deinit(allocator);
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
    try expect(result == null);
    try expect(store.COMP.count() == 1); // Should not cache failed attempts
}

test "MapStore - mapping validation" {
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;
    // Setup config first
    var mem: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);
    const config_path = try std.fs.path.resolve(allocator, &.{ pth, "src/resources/" });
    const config_path_z = try allocator.dupeZ(u8, config_path);
    defer allocator.free(config_path);
    defer allocator.free(config_path_z);

    var cur_config = try settings.init(allocator, config_path_z);
    defer cur_config.test_deinit(allocator);
    var store = try MapStore.init(
        allocator,
        config_path_z,
        &cur_config.default_fx, // Use cur_config's initialized defaults
    );
    defer store.deinit();

    const test_fx = "VST: ReaComp (Cockos)";

    const result = store.get(test_fx, .COMP);
    if (result) |COMP| {
        const comp = COMP.COMP;
        // Test that all values are within MIDI range (0-127)
        try expect(comp.Comp_Attack.? <= 127);
        try expect(comp.Comp_Release.? <= 127);
        try expect(comp.Comp_Thresh.? <= 127);
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
    const config_path = try std.fs.path.resolve(allocator, &.{ pth, "src/resources/" });
    const config_path_z = try allocator.dupeZ(u8, config_path);
    defer allocator.free(config_path);
    defer allocator.free(config_path_z);

    var cur_config = try settings.init(allocator, config_path_z);
    defer cur_config.test_deinit(allocator);
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
    try expect(wrong_module == null);
}
