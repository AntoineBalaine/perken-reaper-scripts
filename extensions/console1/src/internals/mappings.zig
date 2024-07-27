const std = @import("std");
const config = @import("config.zig");
const ModulesList = config.ModulesList;
const ini = @import("ini");

// Trk only carries action buttons, so no need to map them
const Trk = enum {
    Tr_ext_sidechain,
    Tr_order,
    Tr_pg_dn,
    Tr_pg_up,
    Tr_tr1,
    Tr_tr10,
    Tr_tr11,
    Tr_tr12,
    Tr_tr13,
    Tr_tr14,
    Tr_tr15,
    Tr_tr16,
    Tr_tr17,
    Tr_tr18,
    Tr_tr19,
    Tr_tr2,
    Tr_tr20,
    Tr_tr3,
    Tr_tr4,
    Tr_tr5,
    Tr_tr6,
    Tr_tr7,
    Tr_tr8,
    Tr_tr9,
    Tr_tr_copy,
    Tr_tr_grp,
};

const Comp = struct {
    Comp_Attack: u8 = 0,
    Comp_DryWet: u8 = 0,
    Comp_Ratio: u8 = 0,
    Comp_Release: u8 = 0,
    Comp_Thresh: u8 = 0,
    Comp_comp: u8 = 0,
    // Comp_Mtr : u8,
};
const Eq = struct {
    Eq_HiFrq: u8 = 0,
    Eq_HiGain: u8 = 0,
    Eq_HiMidFrq: u8 = 0,
    Eq_HiMidGain: u8 = 0,
    Eq_HiMidQ: u8 = 0,
    Eq_LoFrq: u8 = 0,
    Eq_LoGain: u8 = 0,
    Eq_LoMidFrq: u8 = 0,
    Eq_LoMidGain: u8 = 0,
    Eq_LoMidQ: u8 = 0,
    Eq_eq: u8 = 0,
    Eq_hp_shape: u8 = 0,
    Eq_lp_shape: u8 = 0,
};
const Inpt = struct {
    // Inpt_MtrLft : u8 = 0 ,
    // Inpt_MtrRgt : u8 = 0 ,
    Inpt_Gain: u8 = 0,
    Inpt_HiCut: u8 = 0,
    Inpt_LoCut: u8 = 0,
    Inpt_disp_mode: u8 = 0,
    Inpt_disp_on: u8 = 0,
    Inpt_filt_to_comp: u8 = 0,
    Inpt_phase_inv: u8 = 0,
    Inpt_preset: u8 = 0,
};
const Outpt = struct {
    Out_Drive: u8 = 0,
    Out_DriveChar: u8 = 0,
    // Out_MtrLft : u8 = 0,
    // Out_MtrRgt : u8 = 0,
    Out_Pan: u8 = 0,
    Out_Vol: u8 = 0,
    // Out_mute : u8 = 0,
    // Out_solo : u8 = 0,
};
const Shp = struct {
    Shp_Gate: u8 = 0,
    Shp_GateRelease: u8 = 0,
    Shp_Punch: u8 = 0,
    Shp_hard_gate: u8 = 0,
    Shp_shape: u8 = 0,
    Shp_sustain: u8 = 0,
};

// FIXME: is there anyway the mapping portion of the tuple could be a pointer?
// should it be a pointer?
// upon selecting new track, the mapping is looked-up in the config.
// if found, it ought to be copied.
// else, it ought to be found read from fs, stored in config, and copied as well.
// Is the copy going to be costing a lot?
/// FxMap associates an Fx index with a module map
pub const FxMap = struct {
    COMP: ?std.meta.Tuple(&.{ u8, ?Comp }),
    EQ: ?std.meta.Tuple(&.{ u8, ?Eq }),
    INPUT: ?std.meta.Tuple(&.{ u8, ?Inpt }),
    OUTPT: ?std.meta.Tuple(&.{ u8, ?Outpt }),
    GATE: ?std.meta.Tuple(&.{ u8, ?Shp }),
    // Trk: std.meta.Tuple(&.{ u8, Trk }),
    pub fn init() FxMap {
        return .{
            .COMP = null,
            .EQ = null,
            .INPUT = null,
            .OUTPT = null,
            .GATE = null,
        };
    }
};

const TaggedMapping = union(ModulesList) {
    INPUT: ?Inpt,
    GATE: ?Shp,
    EQ: ?Eq,
    COMP: ?Comp,
    OUTPT: ?Outpt,
};

const MapStore = @This();

COMP: std.StringHashMapUnmanaged(Comp),
EQ: std.StringHashMapUnmanaged(Eq),
INPUT: std.StringHashMapUnmanaged(Inpt),
OUTPT: std.StringHashMapUnmanaged(Outpt),
GATE: std.StringHashMapUnmanaged(Shp),
controller_dir: *const []const u8,
allocator: std.mem.Allocator,
// TRK: std.StringHashMap(Trk),
pub fn init(allocator: std.mem.Allocator, defaults: *std.EnumArray(ModulesList, [:0]const u8), controller_dir: *const []const u8) MapStore {
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
    while (iterator.next()) |module| {
        const fxName = module.value;
        // use self.getMap() only for its side-effect: storing into the map.
        // Its return value is only meant to be used by self.get()
        _ = self.getMap(fxName.*, module.key, controller_dir) catch {
            continue;
        };
    }
    return self;
}

// FIXME: not sure if I need to do any freeing here.
pub fn deinit(self: *MapStore) void {
    _ = self; // autofix
    // don't de-init the allocator here.
    // don't de-init the controller_dir here
    // don't de-init the hashmaps, they're un-managed?
    // for (std.meta.fields(@TypeOf(self))) |field| {
    //     const map = @field(self, field.name);
    //     if (!std.mem.eql(field.name, "controller_dir") and !std.mem.eql(field.name, "allocator")) {
    //         var iterator = map.iterator();
    //         while (iterator.next()) |entry| {
    //             self.allocator.free(entry);
    //         }
    //     }
    // }
}

/// find fx mapping in storage. If unfound, search it from disk. If still unfound, return null.
pub fn get(self: *MapStore, module: ModulesList, fxName: [:0]const u8) TaggedMapping {
    return switch (module) {
        .COMP => if (self.COMP.get(fxName)) |v| TaggedMapping{ .COMP = v } else self.getMap(fxName, module, self.controller_dir) catch TaggedMapping{ .COMP = null },
        .EQ => if (self.EQ.get(fxName)) |v| TaggedMapping{ .EQ = v } else self.getMap(fxName, module, self.controller_dir) catch TaggedMapping{ .EQ = null },
        .INPUT => if (self.INPUT.get(fxName)) |v| TaggedMapping{ .INPUT = v } else self.getMap(fxName, module, self.controller_dir) catch TaggedMapping{ .INPUT = null },
        .OUTPT => if (self.OUTPT.get(fxName)) |v| TaggedMapping{ .OUTPT = v } else self.getMap(fxName, module, self.controller_dir) catch TaggedMapping{ .OUTPT = null },
        .GATE => if (self.GATE.get(fxName)) |v| TaggedMapping{ .GATE = v } else self.getMap(fxName, module, self.controller_dir) catch TaggedMapping{ .GATE = null },
    };
}

/// fetch mapping from disk, parse it, store it, and return it.
fn getMap(self: *MapStore, fxName: [:0]const u8, module: ModulesList, controller_dir: *const []const u8) !TaggedMapping {
    var buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const subdir = @tagName(module);
    const elements = [_][]const u8{ controller_dir.*, subdir, fxName };
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
    std.debug.print("FILEPATH: {s}\n", .{filePath});
    const file = try std.fs.openFileAbsolute(filePath, .{});
    defer file.close();
    var parser = ini.parse(self.allocator, file.reader());
    defer parser.deinit();

    const mapping: TaggedMapping = switch (module) {
        .COMP => {
            const comp = Comp{};
            _ = try readToU8Struct(&comp, &parser);
            self.COMP.put(self.allocator, fxName, comp) catch {}; // side-effect: store in hashmap
            return TaggedMapping{ .COMP = comp };
        },
        .EQ => {
            var eq = Eq{};
            _ = try readToU8Struct(&eq, &parser);
            self.EQ.put(self.allocator, fxName, eq) catch {}; // side-effect: store in hashmap
            return TaggedMapping{ .EQ = eq };
        },
        .INPUT => {
            var inpt: Inpt = Inpt{};
            _ = try readToU8Struct(&inpt, &parser);
            self.INPUT.put(self.allocator, fxName, inpt) catch {}; // side-effect: store in hashmap
            return TaggedMapping{ .INPUT = inpt };
        },
        .OUTPT => {
            var outpt: Outpt = Outpt{};
            _ = try readToU8Struct(&outpt, &parser);
            self.OUTPT.put(self.allocator, fxName, outpt) catch {}; // side-effect: store in hashmap
            return TaggedMapping{ .OUTPT = outpt };
        },
        .GATE => {
            var shp: Shp = Shp{};
            _ = try readToU8Struct(&shp, &parser);
            self.GATE.put(self.allocator, fxName, shp) catch {}; // side-effect: store in hashmap
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
                            var field = &@field(ret_struct, ns_info.name);
                            var parsed = try std.fmt.parseInt(u8, kv.value, 10);
                            field = &parsed;
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
    const allocator = std.testing.allocator;
    const ExampleStruct = struct {
        repositoryformatversion: u8,
    };
    const example =
        \\ 	repositoryformatversion = 0
    ;
    var fbs = std.io.fixedBufferStream(example);
    var parser = ini.parse(std.testing.allocator, fbs.reader());
    defer parser.deinit();

    const ret_str = ExampleStruct{
        .repositoryformatversion = 0,
    };
    const result = try readToU8Struct(&ret_str, &parser, allocator);
    try expect(result.repositoryformatversion == 0);
}
