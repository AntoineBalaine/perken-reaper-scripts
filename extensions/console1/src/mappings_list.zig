const std = @import("std");
const ModulesList = @import("statemachine.zig").ModulesList;
const log = std.log.scoped(.mapping_list);
const ini = @import("ini");
const fs_helpers = @import("fs_helpers.zig");

// Store just file names, not actual mappings
list: std.EnumArray(ModulesList, std.StringArrayHashMapUnmanaged(void)),
arena: std.mem.Allocator,

pub fn empty(arena: std.mem.Allocator) @This() {
    return .{
        .list = std.EnumArray(ModulesList, std.StringArrayHashMapUnmanaged(void)).init(.{
            .INPUT = .empty,
            .GATE = .empty,
            .EQ = .empty,
            .COMP = .empty,
            .OUTPT = .empty,
        }),
        .arena = arena,
    };
}

pub fn init(arena: std.mem.Allocator, resource_path: [:0]const u8) @This() {
    var list = std.EnumArray(ModulesList, std.StringArrayHashMapUnmanaged(void)).initUndefined();

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    inline for (comptime std.enums.values(ModulesList)) |module| {
        inline_blk: {
            list.set(module, .empty);

            const module_path = fs_helpers.joinStrings(&path_buffer, &.{
                resource_path,
                std.fs.path.sep_str,
                "maps",
                std.fs.path.sep_str,
                @tagName(module),
            });

            var dir = std.fs.openDirAbsolute(module_path, .{ .iterate = true }) catch {
                break :inline_blk;
            };

            defer dir.close();

            var iter = dir.iterate();
            while (iter.next() catch break :inline_blk) |entry| {
                if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".ini")) {
                    // Get full file path
                    const file_path = fs_helpers.joinStrings(&path_buffer, &.{
                        resource_path,
                        std.fs.path.sep_str,
                        "maps",
                        std.fs.path.sep_str,
                        @tagName(module),
                        std.fs.path.sep_str,
                        entry.name,
                    });

                    const file = std.fs.openFileAbsolute(file_path, .{}) catch continue;
                    defer file.close();

                    if (parseFxName(arena, file) catch continue) |actual_name| {
                        list.getPtr(module).put(arena, actual_name, {}) catch {
                            log.warn("Mappings list: Failed to store fx name {s}", .{actual_name});
                            continue;
                        };
                    } else {
                        log.warn("Mappings list: No fx_name found in {s}", .{entry.name});
                    }
                }
            }
        }
    }

    return .{
        .list = list,
        .arena = arena,
    };
}

pub fn deinit(self: *@This()) void {
    self.arena.deinit();
}

fn parseFxName(arena: std.mem.Allocator, file: std.fs.File) !?[:0]const u8 {
    var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer temp_arena.deinit();
    var parser = ini.parse(temp_arena.allocator(), file.reader());
    defer parser.deinit();

    while (try parser.next()) |record| {
        switch (record) {
            .property => |kv| {
                if (std.mem.eql(u8, kv.key, "fx_name")) {
                    return try arena.dupeZ(u8, kv.value);
                }
            },
            .section, .enumeration => continue,
        }
    }
    return null;
}
