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
        // FIXME: This causes a mem leak. I can't figure out why.
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

pub fn readConf(allocator: std.mem.Allocator) !Conf {
    var conf = Conf.init(allocator);
    var mem: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);

    const defaultsPath = try std.fs.path.resolve(allocator, &.{ pth, "./resources/defaults.ini" });
    defer allocator.free(defaultsPath);
    const defaultsFile = try std.fs.openFileAbsolute(defaultsPath, .{});
    defer defaultsFile.close();

    var defaultsParser = ini.parse(allocator, defaultsFile.reader());
    defer defaultsParser.deinit();

    try ini.readToEnumArray(&conf.defaults, ModulesList, &defaultsParser, allocator);

    const modulesPath = try std.fs.path.resolve(allocator, &.{ pth, "./resources/modules.ini" });
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
    var conf = try readConf(allocator);

    defer {

        // FIXME: this code frees fine, but reproducing it in the deinit method causes a memleak
        inline for (std.meta.fields(@TypeOf(conf))) |field| {
            const V = @field(conf, field.name);
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
        // conf.deinit(allocator);
    }

    // test defaults
    // const one = enum_arr.get(.one)
    // try expect(std.mem.eql(u8, conf.defaults.get(.INPUT), "JS: Volume/Pan v5"));
    // try expect(std.mem.eql(u8, conf.defaults.get(.EQ), "VST: ReaEQ (Cockos)"));
    // try expect(std.mem.eql(u8, conf.defaults.get(.COMP), "VST: ReaComp (Cockos)"));
    // try expect(std.mem.eql(u8, conf.defaults.get(.GATE), "VST: ReaGate (Cockos)"));
    // try expect(std.mem.eql(u8, conf.defaults.get(.SAT), "JS: Saturator"));

    try expect(conf.modules.get(.INPUT).get("JS: Volume/Pan Smoother") != null);
}
