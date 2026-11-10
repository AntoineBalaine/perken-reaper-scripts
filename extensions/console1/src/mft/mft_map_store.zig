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
    STRIP: std.StringArrayHashMapUnmanaged(?mappings.StripMapping) = .{},
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
        var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer temp_arena.deinit();
        var file_buffer: [4096]u8 = undefined;
        var opened = try self.openMap(io, module.dirName(), fx_name, &file_buffer);
        defer opened.file.close(io);
        var parser = ini.parse(temp_arena.allocator(), &opened.reader.interface, ";#");
        defer parser.deinit();
        return try parseMapping(&parser);
    }

    /// Returns the map of a channel strip plugin, loading it from `maps/factory/STRIP/<fx name>/default.ini` the first time. As for the other maps,
    /// a null entry in the cache records a load that failed, so that the disk is not read again on every turn.
    pub fn getStrip(self: *MftMapStore, io: std.Io, fx_name: [:0]const u8) ?mappings.StripMapping {
        if (self.STRIP.get(fx_name)) |cached| return cached;
        const loaded = self.loadStripFromDisk(io, fx_name) catch |err| {
            log.debug("mft strip mapping load failed for {s}: {s}", .{ fx_name, @errorName(err) });
            const owned = self.allocator.dupeSentinel(u8, fx_name, 0) catch return null;
            self.STRIP.put(self.allocator, owned, null) catch {};
            return null;
        };
        const owned = self.allocator.dupeSentinel(u8, fx_name, 0) catch return loaded;
        self.STRIP.put(self.allocator, owned, loaded) catch {};
        return loaded;
    }

    fn loadStripFromDisk(self: *MftMapStore, io: std.Io, fx_name: [:0]const u8) !mappings.StripMapping {
        var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer temp_arena.deinit();
        var file_buffer: [4096]u8 = undefined;
        var opened = try self.openMap(io, "STRIP", fx_name, &file_buffer);
        defer opened.file.close(io);
        var parser = ini.parse(temp_arena.allocator(), &opened.reader.interface, ";#");
        defer parser.deinit();
        return try parseStripMapping(&parser);
    }

    const OpenedMap = struct { file: std.Io.File, reader: std.Io.File.Reader };

    /// Opens `maps/factory/<dir>/<sanitized fx name>/default.ini`. The reader reads into `buffer`, which the caller keeps alive.
    fn openMap(self: *MftMapStore, io: std.Io, dir: []const u8, fx_name: [:0]const u8, buffer: []u8) !OpenedMap {
        var name_buf: [512:0]u8 = undefined;
        const sanitized = try fs_helpers.sanitizeFxName(&name_buf, fx_name);
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = fs_helpers.joinStrings(&path_buf, &.{
            self.controller_dir, std.fs.path.sep_str, "maps",        std.fs.path.sep_str,
            "factory",           std.fs.path.sep_str, dir,           std.fs.path.sep_str,
            sanitized,           std.fs.path.sep_str, "default.ini",
        });
        const file = try std.Io.Dir.openFileAbsolute(io, path, .{});
        return .{ .file = file, .reader = file.reader(io, buffer) };
    }

    pub fn deinit(self: *MftMapStore) void {
        inline for (.{ &self.INPUT, &self.GATE, &self.EQ, &self.COMP, &self.OUTPUT }) |cache| {
            cache.deinit(self.allocator);
        }
        self.STRIP.deinit(self.allocator);
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
                    const val = parseKnobValue(kv.value) orelse continue;
                    mapping.setSlot(@intCast(position), val);
                } else if (parsePositionKey(kv.key, "push_", mappings.push_count)) |position| {
                    const action = parsePushValue(kv.value) orelse continue;
                    mapping.setPush(@intCast(position), action);
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

/// Parses the map of a channel strip: the same keys as a module map, in a section for each page (`[EQ]`). A key before the first section, and a
/// section that is not a page, are ignored.
fn parseStripMapping(parser: anytype) !mappings.StripMapping {
    var strip = mappings.StripMapping{};
    var page: ?*MftModuleMapping = null;
    var version_found = false;
    while (try parser.next()) |record| {
        switch (record) {
            .section => |name| {
                page = null;
                inline for (@typeInfo(MappableModule).@"enum".field_names, 0..) |field_name, i| {
                    if (std.mem.eql(u8, name, field_name)) page = &strip.pages[i];
                }
            },
            .property => |kv| {
                if (std.mem.eql(u8, kv.key, "version")) {
                    const v = std.fmt.parseInt(u8, kv.value, 10) catch continue;
                    if (v > mappings.MFT_MAPPING_FORMAT_VERSION) return error.UnsupportedMapVersion;
                    version_found = true;
                    continue;
                }
                const target = page orelse continue;
                if (parsePositionKey(kv.key, "knob_", mappings.knob_count)) |position| {
                    target.setSlot(@intCast(position), parseKnobValue(kv.value) orelse continue);
                } else if (parsePositionKey(kv.key, "push_", mappings.push_count)) |position| {
                    target.setPush(@intCast(position), parsePushValue(kv.value) orelse continue);
                }
            },
            .enumeration => {},
        }
    }
    if (!version_found) return error.MissingVersion;
    return strip;
}

/// The value of a knob: a parameter number, or `wet`.
fn parseKnobValue(text: []const u8) ?u16 {
    if (std.mem.eql(u8, text, "wet")) return mappings.wet_param;
    return std.fmt.parseInt(u16, text, 10) catch null;
}

/// The value of a push: a parameter number, `wet`, or `band:N` for the shape of the band N of the EQ, counted from 0.
fn parsePushValue(text: []const u8) ?mappings.PushAction {
    const band_prefix = "band:";
    if (std.mem.startsWith(u8, text, band_prefix)) {
        const band = std.fmt.parseInt(u2, text[band_prefix.len..], 10) catch return null;
        return .{ .band = band };
    }
    return .{ .param = parseKnobValue(text) orelse return null };
}

test "parseKnobValue and parsePushValue: numbers, the dry/wet marker, the shape of a band, and what is not a value" {
    const t = std.testing;
    try t.expectEqual(@as(?u16, 12), parseKnobValue("12"));
    try t.expectEqual(@as(?u16, mappings.wet_param), parseKnobValue("wet"));
    try t.expectEqual(@as(?u16, null), parseKnobValue("loud"));
    try t.expectEqual(@as(?mappings.PushAction, .{ .param = 3 }), parsePushValue("3"));
    try t.expectEqual(@as(?mappings.PushAction, .{ .band = 3 }), parsePushValue("band:3"));
    try t.expectEqual(@as(?mappings.PushAction, null), parsePushValue("band:4"));
    try t.expectEqual(@as(?mappings.PushAction, null), parsePushValue("band:"));
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
    try t.expectEqual(@as(?mappings.PushAction, .{ .param = 3 }), m2.pushAt(0));

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
    const content = @embedFile("resources/maps/factory/EQ/VST_ ReaEQ (Cockos)/default.ini");
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

test "parseMapping: the shipped EQ map has the bandwidths on the third row, the shapes on the pushes, and the dry/wet on the last knob" {
    const t = std.testing;
    const content = @embedFile("resources/maps/factory/EQ/VST_ ReaEQ (Cockos)/default.ini");
    var fbs: std.Io.Reader = .fixed(content);
    var parser = ini.parse(t.allocator, &fbs, ";#");
    defer parser.deinit();

    const m = try parseMapping(&parser);
    try t.expectEqual(@as(?u16, 2), m.slotToParam(8));
    try t.expectEqual(@as(?u16, 11), m.slotToParam(11));
    try t.expectEqual(@as(?u16, mappings.wet_param), m.slotToParam(15));
    try t.expectEqual(@as(?mappings.PushAction, .{ .band = 0 }), m.pushAt(0));
    try t.expectEqual(@as(?mappings.PushAction, .{ .band = 3 }), m.pushAt(3));
    try t.expectEqual(@as(?mappings.PushAction, null), m.pushAt(4));
}

test "parseStripMapping: each section is a page, and keys outside a page are ignored" {
    const t = std.testing;
    const example =
        \\version = 2
        \\module = STRIP
        \\knob_1 = 99
        \\
        \\[INPUT]
        \\knob_1 = 0
        \\
        \\[EQ]
        \\knob_16 = wet
        \\push_4 = 10
        \\
        \\[NOPE]
        \\knob_2 = 5
    ;
    var fbs: std.Io.Reader = .fixed(example);
    var parser = ini.parse(t.allocator, &fbs, ";#");
    defer parser.deinit();
    const strip = try parseStripMapping(&parser);
    try t.expectEqual(@as(?u16, 0), strip.pageFor(.INPUT).slotToParam(0));
    try t.expectEqual(@as(?u16, mappings.wet_param), strip.pageFor(.EQ).slotToParam(15));
    try t.expectEqual(@as(?mappings.PushAction, .{ .param = 10 }), strip.pageFor(.EQ).pushAt(3));
    try t.expect(strip.pageFor(.GATE).isEmpty());
    try t.expect(strip.pageFor(.COMP).isEmpty());
}
