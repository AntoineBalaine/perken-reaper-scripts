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
    modules: std.EnumArray(ModulesList, std.StringHashMap(void)),
    defaults: std.EnumArray(ModulesList, []const u8),
};

pub fn readConf(allocator: std.mem.Allocator) !Conf {
    var mem: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);

    const full_path = try std.fs.path.resolve(allocator, &.{ pth, "./resource/defaults.ini" });
    const file = try std.fs.openFileAbsolute(full_path, .{});
    defer file.close();

    var parser = ini.parse(allocator, file.reader());
    defer parser.deinit();

    var defaults = std.EnumArray(ModulesList, []const u8).initUndefined();
    try ini.readToEnumArray(&defaults, ModulesList, &parser, allocator);

    // TODO: switch to StringHashMapUnmanaged
    var modules = std.EnumArray(ModulesList, std.StringHashMap(void)).initUndefined();

    try ini.readToEnumArray(&modules, ModulesList, &parser, allocator);

    return Conf{ .defaults = defaults, .modules = modules };
}

test readConf {
    const allocator = std.testing.allocator;
    const expect = std.testing.expect;
    const conf = try readConf(allocator);

    defer {
        inline for (std.meta.fields(@TypeOf(conf))) |field| {
            const V = @field(conf, field.name);
            switch (field.type) {
                std.EnumArray(ModulesList, std.StringHashMap(void)) => {
                    // free the keys of the set
                    inline for (std.meta.fields(ModulesList)) |f| {
                        const hashmap = V.get(std.meta.stringToEnum(ModulesList, f.name).?);
                        var it = hashmap.iterator();
                        while (it.next()) |entry| {
                            allocator.free(entry.key_ptr.*);
                        }
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

    // test defaults
    // const one = enum_arr.get(.one)
    try expect(std.mem.eql(u8, conf.defaults.get(.INPUT), "JS: Volume/Pan v5"));
    try expect(std.mem.eql(u8, conf.defaults.get(.EQ), "VST: ReaEQ (Cockos)"));
    try expect(std.mem.eql(u8, conf.defaults.get(.COMP), "VST: ReaComp (Cockos)"));
    try expect(std.mem.eql(u8, conf.defaults.get(.GATE), "VST: ReaGate (Cockos)"));
    try expect(std.mem.eql(u8, conf.defaults.get(.SAT), "JS: Saturator"));
}
