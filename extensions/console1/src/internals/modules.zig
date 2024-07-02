const std = @import("std");
const ini = @import("ini");

const Module = struct { mappings: std.AutoHashMap([]const u8, void), default: []const u8 };

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

const ModulesList = struct {
    //
    INPUT: std.ArrayList([]const u8),
    GATE: std.ArrayList([]const u8),
    EQ: std.ArrayList([]const u8),
    COMP: std.ArrayList([]const u8),
    SAT: std.ArrayList([]const u8),
    DEFAUTS: struct {
        INPUT: []const u8,
        GATE: []const u8,
        EQ: []const u8,
        COMP: []const u8,
        SAT: []const u8,
    },
};

pub fn readResourceFile(self: *Modules, allocator: std.mem.Allocator, path: []const u8) void {
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    const parser = ini.parse(allocator, file.reader());
    defer parser.deinit();

    _ = try ini.readToStruct(&self, parser, allocator);
}

/// List of controller modules, containing keys of FX names, and values containing FX mappings.
/// Mappings are expected to come from the resources directory.
pub const Modules = struct {
    INPUT: std.StringHashMap(void),
    GATE: std.StringHashMap(void),
    EQ: std.StringHashMap(void),
    COMP: std.StringHashMap(void),
    SAT: std.StringHashMap(void),
    pub fn init(allocator: std.mem.Allocator) Modules {
        const modules: Modules = .{
            .INPUT = std.StringHashMap(void).init(allocator),
            .GATE = std.StringHashMap(void).init(allocator),
            .EQ = std.StringHashMap(void).init(allocator),
            .COMP = std.StringHashMap(void).init(allocator),
            .SAT = std.StringHashMap(void).init(allocator),
        };
        return modules;
    }
};

test Modules {
    const allocator = std.testing.allocator;
    const modules = Modules.init(allocator);
    const path = try std.fs.cwd().realpathAlloc(allocator, "/resources/modules.ini");
    defer allocator.free(path);

    modules.readResourceFile(allocator, path);

    const expect = std.testing.expect;
    expect(modules.INPUT.get("JS: Volume/Pan Smoother") != null);
    expect(modules.GATE.get("VST: ReaGate (Cockos)") != null);
    expect(modules.EQ.get("VST: ReaEQ (Cockos)") != null);
    expect(modules.COMP.get("VST: ReaComp (Cockos)") != null);
    expect(modules.SAT.get("JS: Saturation") != null);
    expect(std.mem.eql(modules.DEFAULTS.INPUT, "JS: Volume/Pan Smoother"));
    expect(std.mem.eql(modules.DEFAULTS.GATE, "VST: ReaGate (Cockos)"));
    expect(std.mem.eql(modules.DEFAULTS.EQ, "VST: ReaEQ (Cockos)"));
    expect(std.mem.eql(modules.DEFAULTS.COMP, "VST: ReaComp (Cockos)"));
    expect(std.mem.eql(modules.DEFAULTS.SAT, "JS: Saturation"));
}
