const std = @import("std");
const ModulesList = @import("statemachine.zig").ModulesList;
const logger = @import("logger.zig");

// Store just file names, not actual mappings
list: std.EnumArray(ModulesList, std.StringHashMap(void)),
allocator: std.mem.Allocator,
pub fn init(gpa: std.mem.Allocator, resource_path: [:0]const u8) !@This() {
    var maps = std.EnumArray(ModulesList, std.StringHashMap(void)).initUndefined();

    inline for (comptime std.enums.values(ModulesList)) |module| {
        maps.set(module, std.StringHashMap(void).init(gpa));

        const module_path = try std.fs.path.join(gpa, &.{ resource_path, "maps", @tagName(module) });
        defer gpa.free(module_path);

        var dir = try std.fs.openDirAbsolute(module_path, .{ .iterate = true });
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".ini")) {
                const name = try gpa.dupeZ(u8, std.fs.path.stem(entry.name));
                maps.getPtr(module).put(name, {}) catch {
                    std.log.scoped(.todo).warn("Mappings list: Failed to store fx name {s}\n", .{entry.name});
                    continue;
                };
            }
        }
    }

    return .{
        .list = maps,
        .allocator = gpa,
    };
}

pub fn deinit(self: *@This()) void {
    inline for (comptime std.enums.values(ModulesList)) |module| {
        var map = self.list.get(module);
        var iter = map.keyIterator();
        while (iter.next()) |key| {
            self.allocator.free(@as([:0]const u8, @ptrCast(key.*)));
        }
        map.deinit();
    }
}
