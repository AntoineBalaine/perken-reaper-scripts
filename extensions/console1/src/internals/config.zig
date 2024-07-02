// List of controller modules, containing keys of FX names, and values containing FX mappings.
// Mappings are expected to come from the resources directory.
const std = @import("std");
const ini = @import("ini");

//modulesList.ini
//
//[INPUT]
//JS: Volume/Pan Smoother
//[EQ]
//VST: ReaEQ (Cockos)
//[DEFAULTS]
//EQ = "VST: ReaEQ (Cockos)"
//COMP = "VST: ReaComp (Cockos)"
//GATE = "VST: ReaGate (Cockos)"

const ModulesList = enum {
    INPUT,
    GATE,
    EQ,
    COMP,
    SAT,
};
const Config = @This();

modules: std.EnumArray(ModulesList, std.StringHashMap(void)),
defaults: std.EnumArray(ModulesList, []const u8),

pub fn init(allocator: std.mem.Allocator) Config {
    const mds: Config = .{ .modules = std.EnumArray(ModulesList, std.StringHashMap(void)).init(.{
        .INPUT = std.StringHashMap(void).init(allocator),
        .GATE = std.StringHashMap(void).init(allocator),
        .EQ = std.StringHashMap(void).init(allocator),
        .COMP = std.StringHashMap(void).init(allocator),
        .SAT = std.StringHashMap(void).init(allocator),
    }), .defaults = std.EnumArray(ModulesList, []const u8).init(.{
        .INPUT = undefined,
        .GATE = undefined,
        .EQ = undefined,
        .COMP = undefined,
        .SAT = undefined,
    }) };
    return mds;
}

const Conf = union(enum) {
    modules: std.EnumArray(ModulesList, std.StringHashMap(void)),
    defaults: std.EnumArray(ModulesList, []const u8),
};

pub fn readResourceFiles(self: *Config, allocator: std.mem.Allocator, path: []const u8) !void {
    inline for (std.meta.fields(Conf)) |f| {
        const filePath = std.fs.path.join(allocator, .{ path, f.name });
        const file = try std.fs.openFileAbsolute(filePath, .{});
        defer file.close();

        const parser = ini.parse(allocator, file.reader());
        defer parser.deinit();
        const mod = switch (f.type) {
            .modules => std.EnumArray(ModulesList, std.StringHashMap(void)).init(),
            .defaults => std.EnumArray(ModulesList, []const u8).init(.{
                .INPUT = undefined,
                .GATE = undefined,
                .EQ = undefined,
                .COMP = undefined,
                .SAT = undefined,
            }),
        };
        _ = try ini.readToStruct(mod, parser, allocator);
    }
}

test Config {
    const allocator = std.testing.allocator;
    const modules = Config.init(allocator);
    const path = try std.fs.cwd().realpathAlloc(allocator, "/resources/modules.ini");
    defer allocator.free(path);

    try modules.readResourceFiles(allocator, path);

    defer {
        inline for (std.meta.fields(@TypeOf(modules))) |f| {
            if (f.type == std.StringHashMap(void)) {
                var iterator = f.iterator();
                while (iterator.next()) |item| {
                    allocator.free(item.key_ptr);
                }
            } else if (std.meta.stringToEnum(Config, f.name) == .DEFAULTS) {
                allocator.free(f);
            }
        }
    }

    const expect = std.testing.expect;
    try expect(modules.INPUT.get("JS: Volume/Pan Smoother") != null);
    try expect(modules.GATE.get("VST: ReaGate (Cockos)") != null);
    try expect(modules.EQ.get("VST: ReaEQ (Cockos)") != null);
    try expect(modules.COMP.get("VST: ReaComp (Cockos)") != null);
    try expect(modules.SAT.get("JS: Saturation") != null);
    try expect(std.mem.eql(modules.DEFAULTS.INPUT, "JS: Volume/Pan Smoother"));
    try expect(std.mem.eql(modules.DEFAULTS.GATE, "VST: ReaGate (Cockos)"));
    try expect(std.mem.eql(modules.DEFAULTS.EQ, "VST: ReaEQ (Cockos)"));
    try expect(std.mem.eql(modules.DEFAULTS.COMP, "VST: ReaComp (Cockos)"));
    try expect(std.mem.eql(modules.DEFAULTS.SAT, "JS: Saturation"));
}
