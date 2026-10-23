const std = @import("std");

pub const StringPool = struct {
    bytes: std.ArrayListUnmanaged(u8),
    table: std.HashMapUnmanaged(StringRef, void, TableContext, std.hash_map.default_max_load_percentage),

    pub const empty: StringPool = .{ .bytes = .empty, .table = .empty };

    pub const StringRef = enum(u32) {
        _,
    };

    const TableContext = struct {
        bytes: []const u8,

        pub fn eql(_: @This(), a: StringRef, b: StringRef) bool {
            return a == b;
        }

        pub fn hash(ctx: @This(), key: StringRef) u64 {
            return std.hash_map.hashString(std.mem.sliceTo(ctx.bytes[@intFromEnum(key)..], 0));
        }
    };

    const TableIndexAdapter = struct {
        bytes: []const u8,

        pub fn eql(ctx: @This(), a: []const u8, b: StringRef) bool {
            return std.mem.eql(u8, a, std.mem.sliceTo(ctx.bytes[@intFromEnum(b)..], 0));
        }

        pub fn hash(_: @This(), adapted_key: []const u8) u64 {
            std.debug.assert(std.mem.indexOfScalar(u8, adapted_key, 0) == null);
            return std.hash_map.hashString(adapted_key);
        }
    };

    pub fn deinit(self: *StringPool, allocator: std.mem.Allocator) void {
        self.bytes.deinit(allocator);
        self.table.deinit(allocator);
        self.* = .empty;
    }

    pub fn intern(self: *StringPool, allocator: std.mem.Allocator, str: [:0]const u8) !StringRef {
        const gop = try self.table.getOrPutContextAdapted(
            allocator,
            @as([]const u8, str),
            @as(TableIndexAdapter, .{ .bytes = self.bytes.items }),
            @as(TableContext, .{ .bytes = self.bytes.items }),
        );
        if (gop.found_existing) return gop.key_ptr.*;
        try self.bytes.ensureUnusedCapacity(allocator, str.len + 1);

        const new_ref: StringRef = @enumFromInt(self.bytes.items.len);

        self.bytes.appendSliceAssumeCapacity(str);
        self.bytes.appendAssumeCapacity(0);

        gop.key_ptr.* = new_ref;
        return new_ref;
    }

    pub fn get(self: *const StringPool, ref: StringRef) [:0]const u8 {
        const start_slice = self.bytes.items[@intFromEnum(ref)..];
        return start_slice[0..std.mem.indexOfScalar(u8, start_slice, 0).? :0];
    }

    pub fn clear(self: *StringPool) void {
        self.bytes.clearRetainingCapacity();
        self.table.clearRetainingCapacity();
    }
};
