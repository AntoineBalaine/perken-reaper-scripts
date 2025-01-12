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

/// Maps Fx names to modules
pub const Modules = std.StringHashMapUnmanaged(ModulesList);
/// Default FX associated with each module
pub const Defaults = std.EnumArray(ModulesList, [:0]const u8);

/// Maps Fx names to modules
pub var modulesList: Modules = undefined;
/// Default FX associated with each module
pub var defaults: Defaults = undefined;
pub var mappings: MapStore = undefined;

const FieldEnum = enum {};

pub fn init(allocator: std.mem.Allocator, cntrlrPth: [*:0]const u8) !void {
    mappings = undefined;

    modulesList = Modules{};
    defaults = Defaults.initUndefined();

    try readConf(allocator, cntrlrPth);

    mappings = try MapStore.init(allocator, cntrlrPth, &defaults);
}

const DeinitSelf = struct {
    modulesList: Modules,
    defaults: Defaults,
    mappings: MapStore,
};
pub fn deinit(allocator: std.mem.Allocator) void {
    const self = DeinitSelf{
        .modulesList = modulesList,
        .defaults = defaults,
        .mappings = mappings,
    };

    inline for (std.meta.fields(@TypeOf(self))) |field| {
        var V = @field(self, field.name);
        switch (field.type) {
            Defaults => {
                inline for (std.meta.fields(ModulesList)) |f| {
                    const val = V.get(std.meta.stringToEnum(ModulesList, f.name).?);
                    allocator.free(val);
                }
            },
            Modules => {
                var iterator = V.iterator();
                while (iterator.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                }
                V.deinit(allocator);
            },
            MapStore => {
                V.deinit();
            },
            else => {
                std.debug.print("Unknown type {s}: {s}\n", .{ field.name, @typeName(field.type) });
                unreachable;
            },
        }
    }
}

/// Inits the struct, and reads the  `defaults.ini` and `modules.ini` into it.
fn readConf(allocator: std.mem.Allocator, cntrlrPth: [*:0]const u8) !void {
    const ctrl_pth = std.mem.span(cntrlrPth);
    const defaultsPath = try std.fs.path.resolve(allocator, &.{ ctrl_pth, "./defaults.ini" });
    defer allocator.free(defaultsPath);
    const defaultsFile = try std.fs.openFileAbsolute(defaultsPath, .{});
    defer defaultsFile.close();

    var defaultsParser = ini.parse(allocator, defaultsFile.reader());
    defer defaultsParser.deinit();

    try readToEnumArray(&defaults, ModulesList, &defaultsParser, allocator);

    const modulesPath = try std.fs.path.resolve(allocator, &.{ ctrl_pth, "./modules.ini" });
    defer allocator.free(modulesPath);
    const modulesFile = try std.fs.openFileAbsolute(modulesPath, .{});
    defer modulesFile.close();

    var modulesParser = ini.parse(allocator, modulesFile.reader());
    defer modulesParser.deinit();

    try readToHashMap(&modulesList, ModulesList, &modulesParser, allocator);
}

pub fn readToHashMap(hashmap: anytype, OriginEnum: type, parser: anytype, allocator: std.mem.Allocator) !void {
    std.debug.assert(@typeInfo(OriginEnum) == .Enum);

    // replace with parent enum
    var cur_section: ?OriginEnum = null;

    while (try parser.*.next()) |record| {
        switch (record) {
            .section => |heading| {
                // heading is an enum key
                if (std.meta.stringToEnum(OriginEnum, heading)) |head_val| {
                    cur_section = head_val;
                }
            },
            .property => {},
            .enumeration => |value| {
                // pub const Modules = std.StringHashMapUnmanaged(ModulesList);
                // value is the name of an FX
                // var it = hashmap.*.iterator();
                if (cur_section) |section| {
                    const value_copy = try allocator.dupe(u8, value);
                    try hashmap.put(allocator, value_copy, section);
                }
            },
        }
    }
}
pub fn readToEnumArray(enum_arr: anytype, OriginEnum: type, parser: anytype, allocator: std.mem.Allocator) !void {
    // defaults: std.EnumArray(ModulesList, [:0]const u8);
    std.debug.assert(@typeInfo(OriginEnum) == .Enum);
    // replace with parent enum
    var cur_section: ?OriginEnum = null;

    while (try parser.*.next()) |record| {
        switch (record) {
            .section => |heading| {
                // fit the enum
                if (std.meta.stringToEnum(OriginEnum, heading)) |head_val| {
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
                    if (X == [:0]const u8) {
                        const value_copy = try allocator.dupeZ(u8, value);
                        enum_arr.set(cur_section.?, value_copy);
                    } else {
                        return error.NotConvertible;
                    }
                }
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
    const path_z = try allocator.dupeZ(u8, path);
    defer allocator.free(path);
    defer allocator.free(path_z);
    try init(allocator, path_z);

    defer deinit(allocator);

    // test defaults
    try expect(std.mem.eql(u8, defaults.get(.INPUT), "JS: Volume/Pan Smoother"));
    try expect(std.mem.eql(u8, defaults.get(.GATE), "VST: ReaGate (Cockos)"));
    try expect(std.mem.eql(u8, defaults.get(.EQ), "VST: ReaEQ (Cockos)"));
    try expect(std.mem.eql(u8, defaults.get(.COMP), "VST: ReaComp (Cockos)"));
    try expect(std.mem.eql(u8, defaults.get(.OUTPT), "JS: Saturation"));
}
