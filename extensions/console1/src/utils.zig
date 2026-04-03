const std = @import("std");
const reaper = @import("reaper").reaper;
pub fn volToU8(vol: f64) u8 {
    var d: f64 = (reaper.DB2SLIDER(VAL2DB(vol)) * 127.0 / 1000.0);
    d = if (d < 0.0) 0.0 else if (d > 127.0) 127.0 else d;
    const t: u8 = @intFromFloat(d + 0.5);
    return t;
}

pub fn normalizedToVol(norm: f64) f64 {
    const slider_pos = norm * 1000.0; // 0-1 → 0-1000
    const db = reaper.SLIDER2DB(slider_pos);
    return DB2VAL(db);
}

pub fn volToNormalized(vol: f64) f64 {
    const db = VAL2DB(vol);
    const slider_pos = reaper.DB2SLIDER(db);
    return slider_pos / 1000.0;
}

pub fn panToNormalized(pan: f64) f64 {
    return (pan + 1.0) / 2.0;
}

pub fn normalizedToPan(norm: f64) f64 {
    return norm * 2.0 - 1.0;
}

pub inline fn DB2VAL(x: f64) f64 {
    return std.math.exp((x) * LN10_OVER_TWENTY);
}
const TWENTY_OVER_LN10 = 8.6858896380650365530225783783321;
const LN10_OVER_TWENTY = 0.11512925464970228420089957273422;
pub inline fn VAL2DB(x: f64) f64 {
    if (x < 0.0000000298023223876953125) return -150.0;
    const v: f64 = std.math.log(@TypeOf(x), 10, x) * TWENTY_OVER_LN10;
    return if (v < -150.0) -150.0 else v;
}

pub fn getTrackIndex(track: reaper.MediaTrack) ?usize {
    const track_number = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER");
    if (track_number <= 0) return null; // Master track or invalid
    return @intFromFloat(track_number - 1); // Convert 1-based to 0-based
}

pub fn calculateDelta(comptime T: type, old_pos_abs: u8, new_pos: u8) T {
    if ((old_pos_abs == 127 or old_pos_abs == 0) and new_pos == old_pos_abs) {
        return if (old_pos_abs == 127) 1 else -1;
    }
    return @as(T, @intCast(new_pos)) - @as(T, @intCast(old_pos_abs));
}

pub fn calculateNewScrollPosition(
    comptime T: type,
    pos_abs: *u8,
    pos_rel: anytype,
    new_pos: u8,
    wrap_count: T,
    max_increment: ?T,
) ?T {
    if (wrap_count == 0) return null;

    const PosRelType = @typeInfo(@TypeOf(pos_rel));
    if (PosRelType != .pointer) {
        @compileError("pos_rel must be a pointer");
    }
    if (@typeInfo(PosRelType.pointer.child) != .int) {
        @compileError("pos_rel must point to an integer type");
    }

    const old_pos_abs = pos_abs.*;
    pos_abs.* = new_pos;

    var delta = calculateDelta(T, old_pos_abs, new_pos);

    if (max_increment) |max_inc| {
        if (@abs(delta) > max_inc) {
            delta = if (delta > 0) max_inc else -max_inc;
        }
    }

    const new_pos_rel = @as(T, @intCast(pos_rel.*)) + @as(T, @intCast(delta));

    if (new_pos_rel >= wrap_count) {
        pos_rel.* = @intCast(@rem(new_pos_rel, wrap_count));
    } else if (new_pos_rel < 0) {
        const wrapped = wrap_count - @rem(@as(T, @intCast(@abs(new_pos_rel))), wrap_count);
        pos_rel.* = @intCast(if (wrapped == wrap_count) 0 else wrapped);
    } else {
        pos_rel.* = @intCast(new_pos_rel);
    }
    return delta;
}

/// Computes a delta from absolute CC values and clamps the resulting position
/// to [0, max-1] instead of wrapping. Returns the effective delta (which may
/// be reduced if clamping occurred), or null if the position did not change.
pub fn calculateClampedDelta(
    comptime T: type,
    pos_abs: *u8,
    pos_rel: *u8,
    new_pos: u8,
    max: T,
    max_increment: ?T,
) ?T {
    if (max <= 0) return null;

    const old_pos_abs = pos_abs.*;
    pos_abs.* = new_pos;

    var delta = calculateDelta(T, old_pos_abs, new_pos);

    if (max_increment) |max_inc| {
        if (@abs(delta) > max_inc) {
            delta = if (delta > 0) max_inc else -max_inc;
        }
    }

    const current: T = @intCast(pos_rel.*);
    const new_pos_rel = current + delta;

    if (new_pos_rel >= max) {
        const old = pos_rel.*;
        pos_rel.* = @intCast(max - 1);
        if (pos_rel.* == old) return null;
        return @as(T, @intCast(pos_rel.*)) - current;
    } else if (new_pos_rel < 0) {
        const old = pos_rel.*;
        pos_rel.* = 0;
        if (pos_rel.* == old) return null;
        return -current;
    } else {
        pos_rel.* = @intCast(new_pos_rel);
        return delta;
    }
}

test "calculateClampedDelta" {
    const testing = std.testing;

    // Normal case: delta fits within range
    {
        var pos_abs: u8 = 64;
        var pos_rel: u8 = 64;
        const result = calculateClampedDelta(c_int, &pos_abs, &pos_rel, 65, 127, null);
        try testing.expectEqual(@as(?c_int, 1), result);
        try testing.expectEqual(@as(u8, 65), pos_rel);
    }

    // Upper clamp: pos_rel hits max-1
    {
        var pos_abs: u8 = 126;
        var pos_rel: u8 = 126;
        _ = calculateClampedDelta(c_int, &pos_abs, &pos_rel, 127, 127, null);
        try testing.expectEqual(@as(u8, 126), pos_rel);
    }

    // At upper clamp, repeated: returns null because position cannot change
    {
        var pos_abs: u8 = 127;
        var pos_rel: u8 = 126;
        const result = calculateClampedDelta(c_int, &pos_abs, &pos_rel, 127, 127, null);
        try testing.expectEqual(@as(?c_int, null), result);
        try testing.expectEqual(@as(u8, 126), pos_rel);
    }

    // Lower clamp: pos_rel hits 0
    {
        var pos_abs: u8 = 1;
        var pos_rel: u8 = 0;
        const result = calculateClampedDelta(c_int, &pos_abs, &pos_rel, 0, 127, null);
        try testing.expectEqual(@as(?c_int, null), result);
        try testing.expectEqual(@as(u8, 0), pos_rel);
    }

    // At lower clamp, repeated: returns null
    {
        var pos_abs: u8 = 0;
        var pos_rel: u8 = 0;
        const result = calculateClampedDelta(c_int, &pos_abs, &pos_rel, 0, 127, null);
        try testing.expectEqual(@as(?c_int, null), result);
        try testing.expectEqual(@as(u8, 0), pos_rel);
    }

    // Large delta clamped by max_increment
    {
        var pos_abs: u8 = 50;
        var pos_rel: u8 = 50;
        const result = calculateClampedDelta(c_int, &pos_abs, &pos_rel, 60, 127, 5);
        try testing.expectEqual(@as(?c_int, 5), result);
        try testing.expectEqual(@as(u8, 55), pos_rel);
    }

    // Property: pos_rel always stays within [0, max-1]
    {
        var pos_abs: u8 = 64;
        var pos_rel: u8 = 64;
        const inputs = [_]u8{ 0, 127, 0, 127, 50, 100, 0, 0, 127, 127 };
        for (inputs) |input| {
            _ = calculateClampedDelta(c_int, &pos_abs, &pos_rel, input, 127, null);
            try testing.expect(pos_rel < 127);
        }
    }
}

/// Converts a CC value (0-127) to a normalized play rate (0.0-1.0), where
/// CC=64 maps to normalized=0.2 (1.0x playback rate). The lower half of
/// the knob (0-64) covers rates 0.25x-1.0x, and the upper half (64-127)
/// covers rates 1.0x-4.0x.
pub fn ccToNormalizedRate(cc: u8) f64 {
    const cc_f: f64 = @floatFromInt(cc);
    if (cc <= 64) {
        return (cc_f / 64.0) * 0.2;
    } else {
        return 0.2 + ((cc_f - 64.0) / 63.0) * 0.8;
    }
}

/// Converts a normalized play rate (0.0-1.0) back to a CC value (0-127),
/// the inverse of ccToNormalizedRate.
pub fn normalizedRateToCC(normalized: f64) u8 {
    const clamped = if (normalized < 0.0) 0.0 else if (normalized > 1.0) 1.0 else normalized;
    if (clamped <= 0.2) {
        const val = clamped / 0.2 * 64.0;
        return @intFromFloat(@round(val));
    } else {
        const val = 64.0 + (clamped - 0.2) / 0.8 * 63.0;
        return @intFromFloat(@round(val));
    }
}

test "ccToNormalizedRate" {
    const testing = std.testing;
    const tolerance = 0.001;
    try testing.expectApproxEqAbs(@as(f64, 0.0), ccToNormalizedRate(0), tolerance);
    try testing.expectApproxEqAbs(@as(f64, 0.1), ccToNormalizedRate(32), tolerance);
    try testing.expectApproxEqAbs(@as(f64, 0.2), ccToNormalizedRate(64), tolerance);
    try testing.expectApproxEqAbs(@as(f64, 0.606), ccToNormalizedRate(96), 0.01);
    try testing.expectApproxEqAbs(@as(f64, 1.0), ccToNormalizedRate(127), tolerance);
}

test "normalizedRateToCC" {
    const testing = std.testing;
    try testing.expectEqual(@as(u8, 0), normalizedRateToCC(0.0));
    try testing.expectEqual(@as(u8, 32), normalizedRateToCC(0.1));
    try testing.expectEqual(@as(u8, 64), normalizedRateToCC(0.2));
    try testing.expectEqual(@as(u8, 127), normalizedRateToCC(1.0));
    // Clamping: values outside 0-1 are clamped
    try testing.expectEqual(@as(u8, 0), normalizedRateToCC(-0.5));
    try testing.expectEqual(@as(u8, 127), normalizedRateToCC(1.5));
}

test "ccToNormalizedRate round-trip" {
    // For every CC value, converting to normalized and back should return
    // the original CC value.
    for (0..128) |i| {
        const cc: u8 = @intCast(i);
        const normalized = ccToNormalizedRate(cc);
        std.debug.assert(normalized >= 0.0 and normalized <= 1.0);
        const roundtrip = normalizedRateToCC(normalized);
        try std.testing.expectEqual(cc, roundtrip);
    }
}

pub const Guid = struct {
    bytes: [16]u8,

    pub fn fromReaperGUID(reaper_guid: *const reaper.GUID) Guid {
        // Safe to reinterpret the opaque pointer as a pointer to 16 bytes
        const bytes_ptr: *const [16]u8 = @ptrCast(reaper_guid);
        return .{ .bytes = bytes_ptr.* };
    }

    pub fn fromString(str: []const u8) !Guid {
        if (str.len != 38 or str[0] != '{' or str[37] != '}')
            return error.InvalidGuidFormat;

        var bytes: [16]u8 = undefined;
        var byte_idx: usize = 0;

        var i: usize = 1;
        while (byte_idx < 16) : (byte_idx += 1) {
            while (str[i] == '-') i += 1;

            const high = try std.fmt.parseInt(u4, str[i..][0..1], 16);
            const low = try std.fmt.parseInt(u4, str[i + 1 ..][0..1], 16);
            bytes[byte_idx] = @as(u8, high) << 4 | @as(u8, low);
            i += 2;
        }

        return Guid{ .bytes = bytes };
    }

    pub fn toString(self: Guid, buf: *[38:0]u8) void {
        // Format: {XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}
        buf[0] = '{';
        buf[37] = '}';

        var str_idx: usize = 1;
        for (self.bytes, 0..) |byte, i| {
            // Add hyphens at appropriate positions
            if (i == 4 or i == 6 or i == 8 or i == 10) {
                buf[str_idx] = '-';
                str_idx += 1;
            }

            // Convert each byte to two hex digits
            const high: u4 = @truncate(byte >> 4);
            const low: u4 = @truncate(byte & 0x0F);
            buf[str_idx] = std.fmt.digitToChar(@as(u8, high), .upper);
            buf[str_idx + 1] = std.fmt.digitToChar(@as(u8, low), .upper);
            str_idx += 2;
        }
        buf[38] = 0;
    }
};

test "Guid conversion" {
    const testing = std.testing;
    const guid_str = "{6FE63880-278A-F842-B9E4-FE7E6A81FDA4}";

    // Test string to Guid
    const guid = try Guid.fromString(guid_str);

    // Test Guid back to string
    var buf: [38:0]u8 = undefined;
    guid.toString(&buf);

    try testing.expectEqualStrings(guid_str, &buf);

    // Test another conversion round-trip
    const guid2 = try Guid.fromString(&buf);
    try testing.expectEqual(guid, guid2);
}

pub const StringPool = struct {
    bytes: std.ArrayListUnmanaged(u8),
    table: std.HashMapUnmanaged(StringRef, void, TableContext, std.hash_map.default_max_load_percentage),

    pub const empty: @This() = .{ .bytes = .empty, .table = .empty };
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

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        self.bytes.deinit(allocator);
        self.table.deinit(allocator);
    }

    pub fn add(self: *@This(), allocator: std.mem.Allocator, bytes: []const u8) !StringRef {
        const gop = try self.table.getOrPutContextAdapted(
            allocator,
            @as([]const u8, bytes),
            @as(TableIndexAdapter, .{ .bytes = self.bytes.items }),
            @as(TableContext, .{ .bytes = self.bytes.items }),
        );
        if (gop.found_existing) return gop.key_ptr.*;
        try self.bytes.ensureUnusedCapacity(allocator, bytes.len + 1);

        const new_off: StringRef = @enumFromInt(self.bytes.items.len);

        self.bytes.appendSliceAssumeCapacity(bytes);
        self.bytes.appendAssumeCapacity(0);

        gop.key_ptr.* = new_off;
        return new_off;
    }

    pub fn getString(self: @This(), name: StringRef) [:0]const u8 {
        const start_slice = self.bytes.items[@intFromEnum(name)..];
        return start_slice[0..std.mem.indexOfScalar(u8, start_slice, 0).? :0];
    }
};

test StringPool {

    // Initialize the buffer-backed string pool
    const allocator = std.testing.allocator;
    var pool: StringPool = .empty;
    defer pool.deinit(allocator);

    // Add some strings
    const hello_ref = try pool.add(allocator, "hello");
    const world_ref = try pool.add(allocator, "world");
    const zig_ref = try pool.add(allocator, "zig");

    try std.testing.expectEqualStrings("hello", pool.getString(hello_ref));
    try std.testing.expectEqualStrings("world", pool.getString(world_ref));
    try std.testing.expectEqualStrings("zig", pool.getString(zig_ref));
}
