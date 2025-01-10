const std = @import("std");
const config = @import("config.zig");
const ini = @import("ini");
const logger = @import("../logger.zig");

/// values are set to std.math.maxInt(u8) for unset mappings
pub const Comp = struct {
    Comp_Attack: u8 = std.math.maxInt(u8),
    Comp_DryWet: u8 = std.math.maxInt(u8),
    Comp_Ratio: u8 = std.math.maxInt(u8),
    Comp_Release: u8 = std.math.maxInt(u8),
    Comp_Thresh: u8 = std.math.maxInt(u8),
    Comp_comp: u8 = std.math.maxInt(u8),
    // Comp_Mtr : u8,
};

/// values are set to std.math.maxInt(u8) for unset mappings
pub const Eq = struct {
    Eq_HiFrq: u8 = std.math.maxInt(u8),
    Eq_HiGain: u8 = std.math.maxInt(u8),
    Eq_HiMidFrq: u8 = std.math.maxInt(u8),
    Eq_HiMidGain: u8 = std.math.maxInt(u8),
    Eq_HiMidQ: u8 = std.math.maxInt(u8),
    Eq_LoFrq: u8 = std.math.maxInt(u8),
    Eq_LoGain: u8 = std.math.maxInt(u8),
    Eq_LoMidFrq: u8 = std.math.maxInt(u8),
    Eq_LoMidGain: u8 = std.math.maxInt(u8),
    Eq_LoMidQ: u8 = std.math.maxInt(u8),
    Eq_eq: u8 = std.math.maxInt(u8),
    Eq_hp_shape: u8 = std.math.maxInt(u8),
    Eq_lp_shape: u8 = std.math.maxInt(u8),
};

/// values are set to std.math.maxInt(u8) for unset mappings
pub const Inpt = struct {
    // Inpt_MtrLft : u8 = 0 ,
    // Inpt_MtrRgt : u8 = 0 ,
    Inpt_Gain: u8 = std.math.maxInt(u8),
    Inpt_HiCut: u8 = std.math.maxInt(u8),
    Inpt_LoCut: u8 = std.math.maxInt(u8),
    Inpt_disp_mode: u8 = std.math.maxInt(u8),
    Inpt_disp_on: u8 = std.math.maxInt(u8),
    Inpt_filt_to_comp: u8 = std.math.maxInt(u8),
    Inpt_phase_inv: u8 = std.math.maxInt(u8),
    Inpt_preset: u8 = std.math.maxInt(u8),
};

/// values are set to std.math.maxInt(u8) for unset mappings
pub const Outpt = struct {
    Out_Drive: u8 = std.math.maxInt(u8),
    Out_DriveChar: u8 = std.math.maxInt(u8),
    // Out_MtrLft : u8 = std.math.maxInt(u8),
    // Out_MtrRgt : u8 = std.math.maxInt(u8),
    Out_Pan: u8 = std.math.maxInt(u8),
    Out_Vol: u8 = std.math.maxInt(u8),
    // Out_mute : u8 = std.math.maxInt(u8),
    // Out_solo : u8 = std.math.maxInt(u8),
};

/// values are set to std.math.maxInt(u8) for unset mappings
pub const Shp = struct {
    Shp_Gate: u8 = std.math.maxInt(u8),
    Shp_GateRelease: u8 = std.math.maxInt(u8),
    Shp_Punch: u8 = std.math.maxInt(u8),
    Shp_hard_gate: u8 = std.math.maxInt(u8),
    Shp_shape: u8 = std.math.maxInt(u8),
    Shp_sustain: u8 = std.math.maxInt(u8),
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
const TaggedMapping = union(config.ModulesList) {
    INPUT: ?Inpt,
    GATE: ?Shp,
    EQ: ?Eq,
    COMP: ?Comp,
    OUTPT: ?Outpt,
};

/// MapStore manages FX parameter mappings with lazy loading.
/// Mappings are loaded from disk only when requested and cached for future use.
const MapStore = @This();

COMP: std.StringHashMapUnmanaged(Comp),
EQ: std.StringHashMapUnmanaged(Eq),
INPUT: std.StringHashMapUnmanaged(Inpt),
OUTPT: std.StringHashMapUnmanaged(Outpt),
GATE: std.StringHashMapUnmanaged(Shp),
controller_dir: [*:0]const u8,
allocator: std.mem.Allocator,
pub fn init(allocator: std.mem.Allocator, controller_dir: [*:0]const u8, defaults: *config.Defaults, modules: *config.Modules) MapStore {
    var self: MapStore = .{
        .COMP = std.StringHashMapUnmanaged(Comp){},
        .EQ = std.StringHashMapUnmanaged(Eq){},
        .INPUT = std.StringHashMapUnmanaged(Inpt){},
        .OUTPT = std.StringHashMapUnmanaged(Outpt){},
        .GATE = std.StringHashMapUnmanaged(Shp){},
        .controller_dir = controller_dir,
        .allocator = allocator,
    };
    // find the mappings for the defaults
    var iterator = defaults.iterator();
    while (iterator.next()) |defaultsEntry| {
        const fxName = defaultsEntry.value;
        // use self.getMap() only for its side-effect: storing into the map.
        // Its return value is only meant to be used by self.get()
        if (modules.get(fxName.*) != null) {
            _ = self.getMap(fxName.*, defaultsEntry.key) catch {
                continue;
            };
        } else continue;
    }
    return self;
}

pub fn deinit(self: *MapStore) void {
    logger.log(.debug, "Cleaning up MapStore", .{}, null, self.allocator);
    self.COMP.deinit(self.allocator);
    self.EQ.deinit(self.allocator);
    self.INPUT.deinit(self.allocator);
    self.OUTPT.deinit(self.allocator);
    self.GATE.deinit(self.allocator);
}

/// find fx mapping in storage. If unfound, search it from disk. If still unfound, return null.
pub fn get(self: *MapStore, fxName: [:0]const u8, module: config.ModulesList, modules: config.Modules) TaggedMapping {
    switch (module) {
        .COMP => {
            if (modules.get(fxName) == null) {
                return TaggedMapping{ .COMP = null };
            } else if (self.COMP.get(fxName)) |v| {
                return TaggedMapping{ .COMP = v };
            } else {
                return self.getMap(fxName, module) catch TaggedMapping{ .COMP = null };
            }
        },
        .EQ => {
            if (modules.get(fxName) == null) {
                return TaggedMapping{ .EQ = null };
            } else if (self.EQ.get(fxName)) |v| {
                return TaggedMapping{ .EQ = v };
            } else {
                return self.getMap(fxName, module) catch TaggedMapping{ .EQ = null };
            }
        },
        .INPUT => {
            return if (modules.get(fxName) == null) {
                return TaggedMapping{ .INPUT = null };
            } else if (self.INPUT.get(fxName)) |v| {
                return TaggedMapping{ .INPUT = v };
            } else {
                return self.getMap(fxName, module) catch TaggedMapping{ .INPUT = null };
            };
        },
        .OUTPT => {
            if (modules.get(fxName) == null) {
                return TaggedMapping{ .OUTPT = null };
            } else if (self.OUTPT.get(fxName)) |v| {
                return TaggedMapping{ .OUTPT = v };
            } else {
                return self.getMap(fxName, module) catch TaggedMapping{ .OUTPT = null };
            }
        },
        .GATE => {
            if (modules.get(fxName) == null) {
                return TaggedMapping{ .GATE = null };
            } else if (self.GATE.get(fxName)) |v| {
                return TaggedMapping{ .GATE = v };
            } else {
                return self.getMap(fxName, module) catch TaggedMapping{ .GATE = null };
            }
        },
    }
}

/// fetch mapping from disk, parse it, store it, and return it.
fn getMap(self: *MapStore, fxName: [:0]const u8, module: config.ModulesList) !TaggedMapping {
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

    const elements = [_][]const u8{ std.mem.span(self.controller_dir), "resources", "maps", subdir, sanitizedFxName };

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
