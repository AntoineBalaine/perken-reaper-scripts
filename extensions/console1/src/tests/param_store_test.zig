const std = @import("std");
const testing = std.testing;
const StringPool = @import("string_pool").StringPool;
const ParamStore = @import("../statemachine.zig").ParamStore;

test "StringPool - basic operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var pool: StringPool = .empty;
    defer pool.deinit(allocator);

    // Test intern returns correct offsets
    const offset1 = try pool.intern(allocator, "Hello");
    const offset2 = try pool.intern(allocator, "World");
    const offset3 = try pool.intern(allocator, "Test");

    try testing.expect(@intFromEnum(offset2) > @intFromEnum(offset1));
    try testing.expect(@intFromEnum(offset3) > @intFromEnum(offset2));

    // Test get retrieves correct strings
    try testing.expectEqualStrings("Hello", pool.get(offset1));
    try testing.expectEqualStrings("World", pool.get(offset2));
    try testing.expectEqualStrings("Test", pool.get(offset3));
}

test "StringPool - clear retains capacity" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var pool: StringPool = .empty;
    defer pool.deinit(allocator);

    // Add strings
    _ = try pool.intern(allocator, "First");
    _ = try pool.intern(allocator, "Second");
    _ = try pool.intern(allocator, "Third");

    const capacity_before = pool.bytes.capacity;
    try testing.expect(capacity_before > 0);

    // Clear and check capacity is retained
    pool.clear();
    try testing.expectEqual(@as(usize, 0), pool.bytes.items.len);
    try testing.expectEqual(capacity_before, pool.bytes.capacity);

    // Verify we can add new strings after clear
    const offset = try pool.intern(allocator, "After Clear");
    try testing.expectEqualStrings("After Clear", pool.get(offset));
}

test "ParamStore - basic operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var store = ParamStore.init(allocator);
    defer store.deinit();

    // Test addParam correctly stores index and name
    try store.addParam(0, "Gain");
    try store.addParam(1, "Frequency");
    try store.addParam(2, "Resonance");

    // Test len returns correct count
    try testing.expectEqual(@as(usize, 3), store.len());

    // Test getName and getIndex retrieve correct values
    try testing.expectEqualStrings("Gain", store.getName(0));
    try testing.expectEqualStrings("Frequency", store.getName(1));
    try testing.expectEqualStrings("Resonance", store.getName(2));

    try testing.expectEqual(@as(i32, 0), store.getIndex(0));
    try testing.expectEqual(@as(i32, 1), store.getIndex(1));
    try testing.expectEqual(@as(i32, 2), store.getIndex(2));
}

test "ParamStore - clear resets both strings and params" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var store = ParamStore.init(allocator);
    defer store.deinit();

    // Add params
    try store.addParam(0, "Param1");
    try store.addParam(1, "Param2");
    try store.addParam(2, "Param3");

    try testing.expectEqual(@as(usize, 3), store.len());

    const string_capacity_before = store.strings.bytes.capacity;
    const params_capacity_before = store.params.capacity;

    // Clear
    store.clear();

    // Verify both are reset but capacity retained
    try testing.expectEqual(@as(usize, 0), store.len());
    try testing.expectEqual(@as(usize, 0), store.strings.bytes.items.len);
    try testing.expectEqual(string_capacity_before, store.strings.bytes.capacity);
    try testing.expectEqual(params_capacity_before, store.params.capacity);

    // Verify we can add new params after clear
    try store.addParam(10, "NewParam");
    try testing.expectEqual(@as(usize, 1), store.len());
    try testing.expectEqualStrings("NewParam", store.getName(0));
    try testing.expectEqual(@as(i32, 10), store.getIndex(0));
}

test "ParamStore - memory efficiency with multiple loads" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var store = ParamStore.init(allocator);
    defer store.deinit();

    // Simulate loading params multiple times with clear() in between
    for (0..5) |iteration| {
        store.clear();

        for (0..10) |i| {
            const param_name = try std.fmt.allocPrintZ(allocator, "Param{d}_{d}", .{ iteration, i });
            defer allocator.free(param_name);
            try store.addParam(@intCast(i), param_name);
        }

        try testing.expectEqual(@as(usize, 10), store.len());
    }

    // After multiple load cycles, capacity should have stabilized (not growing unbounded)
    // We can't test exact capacity, but we can verify the last load worked correctly
    try testing.expectEqual(@as(usize, 10), store.len());
    const last_param = store.getName(9);
    try testing.expect(std.mem.startsWith(u8, last_param, "Param4_9"));
}

test "StringPool - handles empty strings" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var pool: StringPool = .empty;
    defer pool.deinit(allocator);

    const offset = try pool.intern(allocator, "");
    try testing.expectEqualStrings("", pool.get(offset));
}

test "ParamStore - handles parameters with long names" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var store = ParamStore.init(allocator);
    defer store.deinit();

    const long_name = "VeryLongParameterNameThatExceedsTypicalLength_WithNumbers_12345";
    try store.addParam(42, long_name);

    try testing.expectEqual(@as(usize, 1), store.len());
    try testing.expectEqualStrings(long_name, store.getName(0));
    try testing.expectEqual(@as(i32, 42), store.getIndex(0));
}
