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

/// List of controller modules, containing keys of FX names, and values containing FX mappings.
/// Mappings are expected to come from the resources directory.
pub const Modules = struct {
    INPUT: std.AutoHashMap([]const u8, void),
    GATE: std.AutoHashMap([]const u8, void),
    EQ: std.AutoHashMap([]const u8, void),
    COMP: std.AutoHashMap([]const u8, void),
    SAT: std.AutoHashMap([]const u8, void),
    pub fn init(allocator: std.mem.Allocator) Modules {
        const modules: Modules = .{
            .INPUT = std.AutoHashMap([]const u8, void).init(allocator),
            .GATE = std.AutoHashMap([]const u8, void).init(allocator),
            .EQ = std.AutoHashMap([]const u8, void).init(allocator),
            .COMP = std.AutoHashMap([]const u8, void).init(allocator),
            .SAT = std.AutoHashMap([]const u8, void).init(allocator),
        };
        return modules;
    }
    pub fn readResourceFile(self: *Modules, allocator: std.mem.Allocator, path: []const u8) void {
        const file = try std.fs.openFileAbsolute(path, .{});
        defer file.close();

        const parser = ini.parse(allocator, file.reader());
        ini.readToStruct(&self, parser, allocator);
    }
};
