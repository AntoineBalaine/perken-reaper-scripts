const std = @import("std");
const reaper = @import("reaper.zig").reaper;
pub fn volToU8(vol: f64) u8 {
    var d: f64 = (reaper.DB2SLIDER(VAL2DB(vol)) * 127.0 / 1000.0);
    d = if (d < 0.0) 0.0 else if (d > 127.0) 127.0 else d;
    const t: u8 = @intFromFloat(d + 0.5);
    return t;
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
