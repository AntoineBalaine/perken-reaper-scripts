const std = @import("std");

const ModulesList = enum {
    INPUT,
    GATE,
    EQ,
    COMP,
    SAT,
};

const StrType = struct {
    modules: std.meta.TagPayload(Conf, .modules),
    defaults: std.meta.TagPayload(Conf, .defaults),
};

const Conf = struct {
    modules: ModulesToValue,
    another_file: ModulesToValue,

    const ModulesToValue = std.EnumArray(ModulesList, std.StringHashMap(void));
};

pub fn doSmth(alloc: std.mem.Allocator) !Conf {
    const defaults: std.EnumMap(ModulesList, []const u8) = getValuesFromFile("defaults.ini");
    var conf: Conf = undefined;

    inline for (std.meta.fields(Conf)) |field| {
        const values: std.EnumMap(ModulesList, []const u8) = getValuesFromFile(field.name ++ ".ini");

        var conf_field = std.EnumArray(ModulesList, std.StringHashMapUnmanaged(void)).initFill(.{});

        for (std.enums.values(ModulesList)) |mod| {
            // parse file for value
            try conf_field.getPtr(mod).put(alloc, values.get(mod) orelse
                defaults.get(mod) orelse
                std.debug.panic("defaults file missing {s}", .{@tagName(mod)}), {});
        }

        @field(conf, field.name) = conf_field;
    }

    return conf;
}

fn getValuesFromFile(file_name: []const u8) std.EnumMap(ModulesList, []const u8) {
    _ = file_name;
    // TODO: read ini file into EnumMap
}
