const State = struct {
    clowns: AutoHashMap(String, Clown) = .empty,
    string_bytes: ArrayList(u8) = .empty,
    string_table: String.Table = .empty,
    const Clown = struct {
        scariness: f32,
        funniness: f32,
    };
    fn deinit(state: *State, gpa: Allocator) void {
        state.string_bytes.deinit(gpa);
        state.string_table.deinit(gpa);
        state.clowns.deinit(gpa);
    }

    pub const String = enum(u32) {
        _,
        const Table = HashMap(String, void, TableContext, max_load_percent);
        const TableContext = struct {
            bytes: []const u8,
            pub fn eql(_: @This(), a: String, b: String) bool {
                return a == b;
            }
            pub fn hash(ctx: @This(), key: String) u64 {
                return std.hash_map.hashString(mem.sliceTo(ctx.bytes[@intFromEnum(key)..], 0));
            }
        };

        const TableIndexAdapter = struct {
            bytes: []const u8,
            pub fn eql(ctx: @This(), a: []const u8, b: String) bool {
                return mem.eql(u8, a, mem.sliceTo(ctx.bytes[@intFromEnum(b)..], 0));
            }
            pub fn hash(_: @This(), adapted_key: []const u8) u64 {
                assert(mem.indexOfScalar(u8, adapted_key, 0) == null);
                return std.hash_map.hashString(adapted_key);
            }
        };

        pub fn slice(index: String, state: *const State) [:0]const u8 {
            const start_slice = state.string_bytes.items[@intFromEnum(index)..];
            return start_slice[0..mem.indexOfScalar(u8, start_slice, 0).? :0];
        }
    };

    pub fn internString(state: *State, gpa: Allocator, bytes: []const u8) !String {
        const gop = try state.string_table.getOrPutContextAdapted(
            gpa,
            @as([]const u8, bytes),
            @as(String.TableIndexAdapter, .{ .bytes = state.string_bytes.items }),
            @as(String.TableContext, .{ .bytes = state.string_bytes.items }),
        );
        if (gop.found_existing) return gop.key_ptr.*;
        try state.string_bytes.ensureUnusedCapacity(gpa, bytes.len + 1);

        const new_off: String = @enumFromInt(state.string_bytes.items.len);

        state.string_bytes.appendSliceAssumeCapacity(bytes);
        state.string_bytes.appendAssumeCapacity(0);

        gop.key_ptr.* = new_off;
        return new_off;
    }
};

test {
    const gpa = std.testing.allocator;
    var state: State = .{};
    defer state.deinit(gpa);
    try state.clowns.put(gpa, try state.internString(gpa, "Dimples"), .{
        .scariness = 0.50,
        .funniness = 0.10,
    });
    try state.clowns.put(gpa, try state.internString(gpa, "Humpty"), .{
        .scariness = 0.99,
        .funniness = 0.99,
    });
}

const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const ArrayList = std.ArrayListUnmanaged;
const Allocator = std.mem.Allocator;
const HashMap = std.HashMapUnmanaged;
const AutoHashMap = std.AutoHashMapUnmanaged;
const max_load_percent = std.hash_map.default_max_load_percent;
