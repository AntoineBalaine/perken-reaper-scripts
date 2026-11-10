const std = @import("std");
const ini = @import("ini");
const fs_helpers = @import("fs_helpers");
const mappings = @import("mft_mappings.zig");
const MappableModule = mappings.MappableModule;
const MftModuleMapping = mappings.MftModuleMapping;
const log = std.log.scoped(.mft_maps);

// Lazily loads and caches per-module FX mappings from
// <controller_dir>/maps/factory/<MODULE>/<fx_name>/default.ini. Each module
// keeps its own cache keyed by FX name.
pub const MftMapStore = struct {
    INPUT: std.StringArrayHashMapUnmanaged(?MftModuleMapping) = .{},
    GATE: std.StringArrayHashMapUnmanaged(?MftModuleMapping) = .{},
    EQ: std.StringArrayHashMapUnmanaged(?MftModuleMapping) = .{},
    COMP: std.StringArrayHashMapUnmanaged(?MftModuleMapping) = .{},
    OUTPUT: std.StringArrayHashMapUnmanaged(?MftModuleMapping) = .{},
    controller_dir: [:0]const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, controller_dir: [:0]const u8) MftMapStore {
        return .{ .controller_dir = controller_dir, .allocator = allocator };
    }

    fn cacheFor(self: *MftMapStore, module: MappableModule) *std.StringArrayHashMapUnmanaged(?MftModuleMapping) {
        return switch (module) {
            .INPUT => &self.INPUT,
            .GATE => &self.GATE,
            .EQ => &self.EQ,
            .COMP => &self.COMP,
            .OUTPUT => &self.OUTPUT,
        };
    }

    // Return the cached mapping for (module, fx_name), loading it from disk on
    // the first request. A null cache entry records a prior failed load so we
    // do not retry the disk read on every knob turn.
    pub fn get(self: *MftMapStore, io: std.Io, module: MappableModule, fx_name: [:0]const u8) ?MftModuleMapping {
        const cache = self.cacheFor(module);
        if (cache.get(fx_name)) |cached| return cached;

        const loaded = self.loadFromDisk(io, module, fx_name) catch |err| {
            log.debug("mft mapping load failed for {s}: {s}", .{ fx_name, @errorName(err) });
            const owned = self.allocator.dupeSentinel(u8, fx_name, 0) catch return null;
            cache.put(self.allocator, owned, null) catch {};
            return null;
        };
        const owned = self.allocator.dupeSentinel(u8, fx_name, 0) catch return loaded;
        cache.put(self.allocator, owned, loaded) catch {};
        return loaded;
    }

    fn loadFromDisk(self: *MftMapStore, io: std.Io, module: MappableModule, fx_name: [:0]const u8) !MftModuleMapping {
        var name_buf: [512:0]u8 = undefined;
        const sanitized = try fs_helpers.sanitizeFxName(&name_buf, fx_name);

        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = fs_helpers.joinStrings(&path_buf, &.{
            self.controller_dir, std.fs.path.sep_str, "maps",           std.fs.path.sep_str,
            "factory",           std.fs.path.sep_str, module.dirName(), std.fs.path.sep_str,
            sanitized,           std.fs.path.sep_str, "default.ini",
        });

        const file = try std.Io.Dir.openFileAbsolute(io, path, .{});
        defer file.close(io);

        var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer temp_arena.deinit();
        var file_buffer: [4096]u8 = undefined;
        var file_reader = file.reader(io, &file_buffer);
        var parser = ini.parse(temp_arena.allocator(), &file_reader.interface, ";#");
        defer parser.deinit();

        return try parseMapping(&parser);
    }

    pub fn deinit(self: *MftMapStore) void {
        inline for (.{ &self.INPUT, &self.GATE, &self.EQ, &self.COMP, &self.OUTPUT }) |cache| {
            cache.deinit(self.allocator);
        }
    }
};

// Parse a mapping from key/value records. Keys are "version", "knob_1"
// through "knob_16" and "push_1" through "push_8"; "module" and "fx_name" headers are ignored here because
// the module is already known from the lookup.
fn parseMapping(parser: anytype) !MftModuleMapping {
    var mapping = MftModuleMapping{};
    var version_found = false;

    while (try parser.next()) |record| {
        switch (record) {
            .property => |kv| {
                if (std.mem.eql(u8, kv.key, "version")) {
                    const v = std.fmt.parseInt(u8, kv.value, 10) catch continue;
                    if (v > mappings.MFT_MAPPING_FORMAT_VERSION) return error.UnsupportedMapVersion;
                    mapping.version = v;
                    version_found = true;
                    continue;
                }
                if (parsePositionKey(kv.key, "knob_", mappings.knob_count)) |position| {
                    const val = std.fmt.parseInt(u16, kv.value, 10) catch continue;
                    mapping.setSlot(@intCast(position), val);
                } else if (parsePositionKey(kv.key, "push_", mappings.push_count)) |position| {
                    const val = std.fmt.parseInt(u16, kv.value, 10) catch continue;
                    mapping.setPush(@intCast(position), val);
                }
            },
            .section, .enumeration => {},
        }
    }

    if (!version_found) return error.MissingVersion;
    return mapping;
}

// Matches a key made of `prefix` and a number from 1 to `count`, and returns the zero-based position.
fn parsePositionKey(key: []const u8, prefix: []const u8, count: usize) ?usize {
    if (!std.mem.startsWith(u8, key, prefix)) return null;
    const n = std.fmt.parseInt(usize, key[prefix.len..], 10) catch return null;
    if (n < 1 or n > count) return null;
    return n - 1;
}

test "parsePositionKey: the ends of the knobs and of the pushes, and what is outside them" {
    const t = std.testing;
    try t.expectEqual(@as(?usize, 0), parsePositionKey("knob_1", "knob_", mappings.knob_count));
    try t.expectEqual(@as(?usize, 15), parsePositionKey("knob_16", "knob_", mappings.knob_count));
    try t.expectEqual(@as(?usize, null), parsePositionKey("knob_17", "knob_", mappings.knob_count));
    try t.expectEqual(@as(?usize, null), parsePositionKey("knob_0", "knob_", mappings.knob_count));
    try t.expectEqual(@as(?usize, 7), parsePositionKey("push_8", "push_", mappings.push_count));
    try t.expectEqual(@as(?usize, null), parsePositionKey("push_9", "push_", mappings.push_count));
    try t.expectEqual(@as(?usize, null), parsePositionKey("version", "knob_", mappings.knob_count));
}

test "parseMapping: a version 2 map has knobs up to 16 and pushes, and a version 1 map still loads" {
    const t = std.testing;
    const v2 =
        \\version = 2
        \\knob_16 = 7
        \\push_1 = 3
    ;
    var fbs2: std.Io.Reader = .fixed(v2);
    var parser2 = ini.parse(t.allocator, &fbs2, ";#");
    defer parser2.deinit();
    const m2 = try parseMapping(&parser2);
    try t.expectEqual(@as(?u16, 7), m2.slotToParam(15));
    try t.expectEqual(@as(?u16, 3), m2.pushToParam(0));

    const v1 =
        \\version = 1
        \\knob_8 = 2
    ;
    var fbs1: std.Io.Reader = .fixed(v1);
    var parser1 = ini.parse(t.allocator, &fbs1, ";#");
    defer parser1.deinit();
    try t.expectEqual(@as(?u16, 2), (try parseMapping(&parser1)).slotToParam(7));

    const v3 =
        \\version = 3
    ;
    var fbs3: std.Io.Reader = .fixed(v3);
    var parser3 = ini.parse(t.allocator, &fbs3, ";#");
    defer parser3.deinit();
    try t.expectError(error.UnsupportedMapVersion, parseMapping(&parser3));
}

test "parseMapping: reads knobs and version" {
    const t = std.testing;
    const example =
        \\version = 1
        \\module = EQ
        \\fx_name = VST: ReaEQ (Cockos)
        \\knob_1 = 9
        \\knob_3 = 6
    ;
    var fbs: std.Io.Reader = .fixed(example);
    var parser = ini.parse(t.allocator, &fbs, ";#");
    defer parser.deinit();

    const m = try parseMapping(&parser);
    try t.expectEqual(@as(?u16, 9), m.slotToParam(0));
    try t.expectEqual(@as(?u16, null), m.slotToParam(1));
    try t.expectEqual(@as(?u16, 6), m.slotToParam(2));
}

test "parseMapping: missing version errors" {
    const t = std.testing;
    const example =
        \\module = EQ
        \\knob_1 = 9
    ;
    var fbs: std.Io.Reader = .fixed(example);
    var parser = ini.parse(t.allocator, &fbs, ";#");
    defer parser.deinit();

    try t.expectError(error.MissingVersion, parseMapping(&parser));
}

test "parseMapping: shipped EQ factory map matches expected slots" {
    const t = std.testing;
    const content = @embedFile("resources/maps/factory/EQ/reaeq/default.ini");
    var fbs: std.Io.Reader = .fixed(content);
    var parser = ini.parse(t.allocator, &fbs, ";#");
    defer parser.deinit();

    const m = try parseMapping(&parser);
    // Top row: the four band frequencies; bottom row: the four gains.
    try t.expectEqual(@as(?u16, 0), m.slotToParam(0));
    try t.expectEqual(@as(?u16, 9), m.slotToParam(3));
    try t.expectEqual(@as(?u16, 1), m.slotToParam(4));
    try t.expectEqual(@as(?u16, 10), m.slotToParam(7));
}
