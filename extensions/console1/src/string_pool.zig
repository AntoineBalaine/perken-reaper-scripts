const std = @import("std");

pub const StringPool = struct {
    buffer: std.ArrayListUnmanaged(u8),
    arena: std.heap.ArenaAllocator,

    pub fn init(gpa: std.mem.Allocator) StringPool {
        return .{
            .buffer = .{},
            .arena = std.heap.ArenaAllocator.init(gpa),
        };
    }

    pub fn deinit(self: *StringPool) void {
        self.arena.deinit();
    }

    pub fn clear(self: *StringPool) void {
        self.buffer.clearRetainingCapacity();
    }

    pub fn intern(self: *StringPool, str: [:0]const u8) !u32 {
        const allocator = self.arena.allocator();
        const offset = self.buffer.items.len;
        try self.buffer.appendSlice(allocator, str);
        try self.buffer.append(allocator, '\x00');
        return @intCast(offset);
    }

    pub fn get(self: *const StringPool, offset: u32) [:0]const u8 {
        const start_slice = self.buffer.items[offset..];
        return start_slice[0..std.mem.indexOfScalar(u8, start_slice, 0).? :0];
    }
};
