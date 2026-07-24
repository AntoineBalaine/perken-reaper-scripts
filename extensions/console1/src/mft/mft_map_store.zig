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
    IO: std.StringArrayHashMapUnmanaged(?MftModuleMapping) = .{},
    GATE: std.StringArrayHashMapUnmanaged(?MftModuleMapping) = .{},
    EQ: std.StringArrayHashMapUnmanaged(?MftModuleMapping) = .{},
    COMP: std.StringArrayHashMapUnmanaged(?MftModuleMapping) = .{},
    controller_dir: [:0]const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, controller_dir: [:0]const u8) MftMapStore {
        return .{ .controller_dir = controller_dir, .allocator = allocator };
    }

    fn cacheFor(self: *MftMapStore, module: MappableModule) *std.StringArrayHashMapUnmanaged(?MftModuleMapping) {
        return switch (module) {
            .IO => &self.IO,
            .GATE => &self.GATE,
            .EQ => &self.EQ,
            .COMP => &self.COMP,
        };
    }

    // Return the cached mapping for (module, fx_name), loading it from disk on
    // the first request. A null cache entry records a prior failed load so we
    // do not retry the disk read on every knob turn.
    pub fn get(self: *MftMapStore, module: MappableModule, fx_name: [:0]const u8) ?MftModuleMapping {
        const cache = self.cacheFor(module);
        if (cache.get(fx_name)) |cached| return cached;

        const loaded = self.loadFromDisk(module, fx_name) catch |err| {
            log.debug("mft mapping load failed for {s}: {s}", .{ fx_name, @errorName(err) });
            const owned = self.allocator.dupeZ(u8, fx_name) catch return null;
            cache.put(self.allocator, owned, null) catch {};
            return null;
        };
        const owned = self.allocator.dupeZ(u8, fx_name) catch return loaded;
        cache.put(self.allocator, owned, loaded) catch {};
        return loaded;
    }

    fn loadFromDisk(self: *MftMapStore, module: MappableModule, fx_name: [:0]const u8) !MftModuleMapping {
        var name_buf: [512:0]u8 = undefined;
        const sanitized = try fs_helpers.sanitizeFxName(&name_buf, fx_name);

        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = fs_helpers.joinStrings(&path_buf, &.{
            self.controller_dir, std.fs.path.sep_str, "maps",           std.fs.path.sep_str,
            "factory",           std.fs.path.sep_str, module.dirName(), std.fs.path.sep_str,
            sanitized,           std.fs.path.sep_str, "default.ini",
        });

        const file = try std.fs.openFileAbsolute(path, .{});
        defer file.close();

        var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer temp_arena.deinit();
        var parser = ini.parse(temp_arena.allocator(), file.reader());
        defer parser.deinit();

        return try parseMapping(&parser);
    }

    pub fn deinit(self: *MftMapStore) void {
        inline for (.{ &self.IO, &self.GATE, &self.EQ, &self.COMP }) |cache| {
            cache.deinit(self.allocator);
        }
    }
};

// Parse a mapping from key/value records. Keys are "version" and "knob_1"
// through "knob_8"; "module" and "fx_name" headers are ignored here because
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
                if (parseKnobKey(kv.key)) |slot| {
                    const val = std.fmt.parseInt(u16, kv.value, 10) catch continue;
                    mapping.setSlot(slot, val);
                }
            },
            .section, .enumeration => {},
        }
    }

    if (!version_found) return error.MissingVersion;
    return mapping;
}

// Match "knob_N" for N in 1..8 and return the zero-based slot index.
fn parseKnobKey(key: []const u8) ?u3 {
    const prefix = "knob_";
    if (!std.mem.startsWith(u8, key, prefix)) return null;
    const n = std.fmt.parseInt(u8, key[prefix.len..], 10) catch return null;
    if (n < 1 or n > 8) return null;
    return @intCast(n - 1);
}

test "parseKnobKey" {
    const t = std.testing;
    try t.expectEqual(@as(?u3, 0), parseKnobKey("knob_1"));
    try t.expectEqual(@as(?u3, 7), parseKnobKey("knob_8"));
    try t.expectEqual(@as(?u3, null), parseKnobKey("knob_9"));
    try t.expectEqual(@as(?u3, null), parseKnobKey("knob_0"));
    try t.expectEqual(@as(?u3, null), parseKnobKey("version"));
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
    var fbs = std.io.fixedBufferStream(example);
    var parser = ini.parse(t.allocator, fbs.reader());
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
    var fbs = std.io.fixedBufferStream(example);
    var parser = ini.parse(t.allocator, fbs.reader());
    defer parser.deinit();

    try t.expectError(error.MissingVersion, parseMapping(&parser));
}
