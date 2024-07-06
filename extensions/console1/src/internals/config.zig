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

pub const ModulesList = enum {
    INPUT,
    GATE,
    EQ,
    COMP,
    SAT,
};

const Conf = struct {
    // TODO: switch to StringHashMapUnmanaged
    modules: std.EnumArray(ModulesList, std.StringHashMap(void)),
    defaults: std.EnumArray(ModulesList, []const u8),
    pub fn init(allocator: std.mem.Allocator) Conf {
        const self: Conf = .{
            .modules = std.EnumArray(ModulesList, std.StringHashMap(void)).init(.{
                .INPUT = std.StringHashMap(void).init(allocator),
                .GATE = std.StringHashMap(void).init(allocator),
                .EQ = std.StringHashMap(void).init(allocator),
                .COMP = std.StringHashMap(void).init(allocator),
                .SAT = std.StringHashMap(void).init(allocator),
            }),
            .defaults = std.EnumArray(ModulesList, []const u8).initUndefined(),
        };
        return self;
    }

    pub fn deinit(self: *Conf, allocator: std.mem.Allocator) void {
        inline for (std.meta.fields(@TypeOf(self.*))) |field| {
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
                else => unreachable,
            }
        }
    }
};

/// Inits the struct, and reads the  `defaults.ini` and `modules.ini` into it.
pub fn readConf(allocator: std.mem.Allocator, configPath: []const u8) !Conf {
    var conf = Conf.init(allocator);

    const defaultsPath = try std.fs.path.resolve(allocator, &.{ configPath, "./defaults.ini" });
    defer allocator.free(defaultsPath);
    const defaultsFile = try std.fs.openFileAbsolute(defaultsPath, .{});
    defer defaultsFile.close();

    var defaultsParser = ini.parse(allocator, defaultsFile.reader());
    defer defaultsParser.deinit();

    try ini.readToEnumArray(&conf.defaults, ModulesList, &defaultsParser, allocator);

    const modulesPath = try std.fs.path.resolve(allocator, &.{ configPath, "./modules.ini" });
    defer allocator.free(modulesPath);
    const modulesFile = try std.fs.openFileAbsolute(modulesPath, .{});
    defer modulesFile.close();

    var modulesParser = ini.parse(allocator, modulesFile.reader());
    defer modulesParser.deinit();

    try ini.readToEnumArray(&conf.modules, ModulesList, &modulesParser, allocator);

    return conf;
}

test readConf {
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;

    var mem: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);

    const path = try std.fs.path.resolve(allocator, &.{ pth, "./resources" });
    defer allocator.free(path);
    var conf = try readConf(allocator, path);

    defer conf.deinit(allocator);

    // test defaults
    try expect(std.mem.eql(u8, conf.defaults.get(.INPUT), "JS: Volume/Pan Smoother"));
    try expect(std.mem.eql(u8, conf.defaults.get(.GATE), "VST: ReaGate (Cockos)"));
    try expect(std.mem.eql(u8, conf.defaults.get(.EQ), "VST: ReaEQ (Cockos)"));
    try expect(std.mem.eql(u8, conf.defaults.get(.COMP), "VST: ReaComp (Cockos)"));
    try expect(std.mem.eql(u8, conf.defaults.get(.SAT), "JS: Saturation"));

    try expect(conf.modules.get(.INPUT).get("JS: Volume/Pan Smoother") != null);
    try expect(conf.modules.get(.INPUT).get("JS: Other input") != null);
    try expect(conf.modules.get(.GATE).get("VST: ReaGate (Cockos)") != null);
    try expect(conf.modules.get(.GATE).get("VST: SOMEOTHERGATE") != null);
    try expect(conf.modules.get(.EQ).get("VST: ReaEQ (Cockos)") != null);
    try expect(conf.modules.get(.EQ).get("JS: ReEQ") != null);
    try expect(conf.modules.get(.COMP).get("VST: ReaComp (Cockos)") != null);
    try expect(conf.modules.get(.COMP).get("VST: ReaXComp (Cockos)") != null);
    try expect(conf.modules.get(.SAT).get("JS: Saturation") != null);
}
