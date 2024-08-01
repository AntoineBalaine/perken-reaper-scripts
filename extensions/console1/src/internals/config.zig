// Init the FX config and load them from the file.
// TODO: make this a little less err-prone:
// - Ini's parser can't check whether the fields in std.EnumArray(ModulesList, []const u8) are undefined.
// This means that having multiple entries in that header would result in a mem leak:
// ```ini
// [INPUT]
// JS: Volume/Pan Smoother
// JS: Volume/Pan Smoother
// [GATE]
// ```
// Would probably need to change the ini file to be K-V pairs instead, though it doesn't fix the mem leaks issue.
// - Init the `Conf` with some defaults, or keep track of uninitialized fields in `ini.readToEnumArray()`
// This could be achieved with a tracker-struct - like a bit map or a hash set.
// - Switch the nested hashmaps to be un-managed? That's a good option to reduce the mem footprint
const std = @import("std");
const ini = @import("ini");
const fs_helpers = @import("fs_helpers.zig");
pub const MapStore = @import("mappings.zig");

pub const Conf = @This();

pub const ModulesList = enum {
    INPUT,
    GATE,
    EQ,
    COMP,
    OUTPT,
};

pub const ModuleSet = std.EnumArray(ModulesList, std.StringHashMap(void));
/// Maps Fx names to modules
pub const Modules = std.StringHashMap(ModulesList);
/// Default FX associated with each module
pub const Defaults = std.EnumArray(ModulesList, [:0]const u8);

// TODO: switch to StringHashMapUnmanaged
// TODO: use modulesList instead of moduleSet
/// Maps modules to FX names
pub var moduleSet: ModuleSet = undefined;
/// Maps Fx names to modules
pub var modulesList: Modules = undefined;
/// Default FX associated with each module
pub var defaults: Defaults = undefined;
pub var mappings: MapStore = undefined;

const FieldEnum = enum {};

pub fn init(allocator: std.mem.Allocator, cntrlrPth: *const []const u8) !void {
    moduleSet = ModuleSet.init(.{
        .INPUT = std.StringHashMap(void).init(allocator),
        .GATE = std.StringHashMap(void).init(allocator),
        .EQ = std.StringHashMap(void).init(allocator),
        .COMP = std.StringHashMap(void).init(allocator),
        .OUTPT = std.StringHashMap(void).init(allocator),
    });
    mappings = undefined;
    modulesList = Modules.init(allocator);
    defaults = Defaults.initUndefined();

    try readConf(allocator, cntrlrPth);

    mappings = MapStore.init(allocator, cntrlrPth, &defaults, &modulesList);
}

const DeinitSelf = struct {
    moduleSet: @TypeOf(moduleSet),
    modulesList: @TypeOf(modulesList),
    defaults: @TypeOf(defaults),
    mappings: @TypeOf(mappings),
};
pub fn deinit(allocator: std.mem.Allocator) void {
    const self = DeinitSelf{
        .moduleSet = moduleSet,
        .modulesList = modulesList,
        .defaults = defaults,
        .mappings = mappings,
    };

    inline for (std.meta.fields(@TypeOf(self))) |field| {
        const V = @field(self, field.name);
        switch (field.type) {
            std.EnumArray(ModulesList, std.StringHashMap(void)) => {
                // free the keys of the set
                inline for (std.meta.fields(ModulesList)) |f| {
                    var map = V.get(std.meta.stringToEnum(ModulesList, f.name).?);
                    var keyIter = map.keyIterator();
                    while (keyIter.next()) |key| {
                        allocator.free(key.*);
                    }
                    map.deinit();
                }
            },
            std.EnumArray(ModulesList, []const u8) => {
                inline for (std.meta.fields(ModulesList)) |f| {
                    const val = V.get(std.meta.stringToEnum(ModulesList, f.name).?);
                    allocator.free(val);
                }
            },
            std.StringHashMap(ModulesList) => {
                var iterator = V.iterator();
                while (iterator.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    // allocator.free(entry.value_ptr.*);
                }
            },
            else => {
                std.debug.print("Unknown type {s}: {s}\n", .{ field.name, @typeName(field.type) });
                unreachable;
            },
        }
    }
}

/// Inits the struct, and reads the  `defaults.ini` and `modules.ini` into it.
fn readConf(allocator: std.mem.Allocator, cntrlrPth: *const []const u8) !void {
    const defaultsPath = try std.fs.path.resolve(allocator, &.{ cntrlrPth.*, "./resources/defaults.ini" });
    defer allocator.free(defaultsPath);
    const defaultsFile = try std.fs.openFileAbsolute(defaultsPath, .{});
    defer defaultsFile.close();

    var defaultsParser = ini.parse(allocator, defaultsFile.reader());
    defer defaultsParser.deinit();

    try readToEnumArray(&defaults, ModulesList, &defaultsParser, allocator);

    const modulesPath = try std.fs.path.resolve(allocator, &.{ cntrlrPth.*, "./resources/modules.ini" });
    defer allocator.free(modulesPath);
    const modulesFile = try std.fs.openFileAbsolute(modulesPath, .{});
    defer modulesFile.close();

    var modulesParser = ini.parse(allocator, modulesFile.reader());
    defer modulesParser.deinit();

    try readToEnumArray(&moduleSet, ModulesList, &modulesParser, allocator);
}

pub fn readToEnumArray(enum_arr: anytype, Or_enum: type, parser: anytype, allocator: std.mem.Allocator) !void {
    const T = @TypeOf(enum_arr.*);
    std.debug.assert(@typeInfo(T) == .Struct);
    std.debug.assert(@typeInfo(Or_enum) == .Enum);

    // replace with parent enum
    var cur_section: ?Or_enum = null;

    while (try parser.*.next()) |record| {
        switch (record) {
            .section => |heading| {
                // fit the enum
                if (std.meta.stringToEnum(Or_enum, heading)) |head_val| {
                    cur_section = head_val;
                }
            },
            .property => {},
            .enumeration => |value| {
                var it = enum_arr.*.iterator();
                while (it.next()) |val| {
                    if (cur_section == null or cur_section.? != val.key) {
                        continue;
                    }

                    const innerArray = enum_arr.get(cur_section.?);
                    const X = @TypeOf(innerArray);
                    if (X == std.ArrayList([]const u8) or X == std.ArrayList([]u8)) {
                        const value_copy = try allocator.dupe(u8, value);
                        var inn = enum_arr.getPtr(cur_section.?);
                        try inn.append(value_copy);
                    } else if (X == std.StringHashMap(void)) {
                        const value_copy = try allocator.dupeZ(u8, value);
                        var inn = enum_arr.getPtr(cur_section.?);
                        try inn.put(value_copy, {});
                        // FIXME: maybe this should have a dedicated match arm
                        try modulesList.put(value_copy, cur_section.?);
                    } else if (X == [:0]const u8) {
                        std.debug.print("val: {s}\n", .{value});
                        const value_copy = try allocator.dupeZ(u8, value);
                        enum_arr.set(cur_section.?, value_copy);
                    } else {
                        std.debug.print("\nfailed\n", .{});
                        return error.NotConvertible;
                    }
                }
                cur_section = null;
            },
        }
    }
}

test readConf {
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;

    var mem: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);

    const path = try std.fs.path.resolve(allocator, &.{ pth, "./" });
    defer allocator.free(path);
    var conf = try init(allocator, path);

    defer conf.deinit(allocator);

    // test defaults
    try expect(std.mem.eql(u8, conf.defaults.get(.INPUT), "JS: Volume/Pan Smoother"));
    try expect(std.mem.eql(u8, conf.defaults.get(.GATE), "VST: ReaGate (Cockos)"));
    try expect(std.mem.eql(u8, conf.defaults.get(.EQ), "VST: ReaEQ (Cockos)"));
    try expect(std.mem.eql(u8, conf.defaults.get(.COMP), "VST: ReaComp (Cockos)"));
    try expect(std.mem.eql(u8, conf.defaults.get(.OUTPT), "JS: Saturation"));

    try expect(conf.moduleSet.get(.INPUT).get("JS: Volume/Pan Smoother") != null);
    try expect(conf.moduleSet.get(.INPUT).get("JS: Other input") != null);
    try expect(conf.moduleSet.get(.GATE).get("VST: ReaGate (Cockos)") != null);
    try expect(conf.moduleSet.get(.GATE).get("VST: SOMEOTHERGATE") != null);
    try expect(conf.moduleSet.get(.EQ).get("VST: ReaEQ (Cockos)") != null);
    try expect(conf.moduleSet.get(.EQ).get("JS: ReEQ") != null);
    try expect(conf.moduleSet.get(.COMP).get("VST: ReaComp (Cockos)") != null);
    try expect(conf.moduleSet.get(.COMP).get("VST: ReaXComp (Cockos)") != null);
    try expect(conf.moduleSet.get(.OUTPT).get("JS: Saturation") != null);
}
