const std = @import("std");
const ini = @import("ini");
const fs_helpers = @import("fs_helpers");
const mappings = @import("mft_mappings.zig");
const MappableModule = mappings.MappableModule;
const MftModuleMapping = mappings.MftModuleMapping;
const BrowserList = @import("mft_fxsel.zig").BrowserList;
const mft_port = @import("mft_port.zig");
const mft_auto = @import("mft_auto.zig");
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
    /// The map of the AUTO page, once it was read.
    auto: ?mft_auto.AutoMap = null,
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
        // The maps that the user made come before the factory ones, so that a map of the user replaces the factory map of the same plugin.
        var opened = self.openMap(io, "user", module.dirName(), fx_name, &file_buffer) catch |err| switch (err) {
            error.FileNotFound => try self.openMap(io, "factory", module.dirName(), fx_name, &file_buffer),
            else => return err,
        };
        defer opened.file.close(io);
        var parser = ini.parse(temp_arena.allocator(), &opened.reader.interface, ";#");
        defer parser.deinit();
        return try parseMapping(&parser);
    }

    /// Saves a map that the user made, as `maps/user/<MODULE>/<plugin>/default.ini`, which the loader reads before the factory map of the plugin. The
    /// map that was kept in memory for the plugin is dropped, so that the next turn of an encoder reads the new one.
    pub fn saveUser(self: *MftMapStore, io: std.Io, module: MappableModule, fx_name: [:0]const u8, mapping: *const MftModuleMapping) !void {
        var name_buf: [512:0]u8 = undefined;
        const sanitized = try fs_helpers.sanitizeFxName(&name_buf, fx_name);
        var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
        const dir_path = fs_helpers.joinStrings(&dir_buf, &.{
            self.controller_dir, std.fs.path.sep_str, "maps", std.fs.path.sep_str, "user", std.fs.path.sep_str, module.dirName(), std.fs.path.sep_str, sanitized,
        });
        try std.Io.Dir.cwd().createDirPath(io, dir_path);
        var aw: std.Io.Writer.Allocating = .init(self.allocator);
        defer aw.deinit();
        try mft_port.writeModuleMap(&aw.writer, module, fx_name, mapping);
        var file_buf: [std.fs.max_path_bytes]u8 = undefined;
        const file_path = fs_helpers.joinStrings(&file_buf, &.{ dir_path, std.fs.path.sep_str, "default.ini" });
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = file_path, .data = aw.written() });
        _ = self.cacheFor(module).swapRemove(fx_name);
    }

    /// The map of the AUTO page: the user's (`maps/user/AUTO/default.ini`) when there is one, and the factory one otherwise, read the first time.
    pub fn getAuto(self: *MftMapStore, io: std.Io) mft_auto.AutoMap {
        if (self.auto) |map| return map;
        const map = self.readAuto(io, "user") orelse self.readAuto(io, "factory") orelse mft_auto.AutoMap{};
        self.auto = map;
        return map;
    }

    fn readAuto(self: *MftMapStore, io: std.Io, root: []const u8) ?mft_auto.AutoMap {
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = fs_helpers.joinStrings(&path_buf, &.{ self.controller_dir, std.fs.path.sep_str, "maps", std.fs.path.sep_str, root, std.fs.path.sep_str, "AUTO", std.fs.path.sep_str, "default.ini" });
        var text_buf: [8192]u8 = undefined;
        const text = std.Io.Dir.cwd().readFile(io, path, &text_buf) catch return null;
        return mft_auto.parse(text);
    }

    /// Saves the map of the AUTO page as the user's, which is read before the factory one.
    pub fn saveAuto(self: *MftMapStore, io: std.Io, map: *const mft_auto.AutoMap) !void {
        var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
        const dir_path = fs_helpers.joinStrings(&dir_buf, &.{ self.controller_dir, std.fs.path.sep_str, "maps", std.fs.path.sep_str, "user", std.fs.path.sep_str, "AUTO" });
        try std.Io.Dir.cwd().createDirPath(io, dir_path);
        var aw: std.Io.Writer.Allocating = .init(self.allocator);
        defer aw.deinit();
        try mft_auto.write(map, &aw.writer);
        var file_buf: [std.fs.max_path_bytes]u8 = undefined;
        const file_path = fs_helpers.joinStrings(&file_buf, &.{ dir_path, std.fs.path.sep_str, "default.ini" });
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = file_path, .data = aw.written() });
        self.auto = map.*;
    }

    /// Saves the map of a channel strip as the user's, which is read before the factory one, and drops the one that was kept in memory.
    pub fn saveStrip(self: *MftMapStore, io: std.Io, fx_name: [:0]const u8, strip: *const mappings.StripMapping) !void {
        var name_buf: [512:0]u8 = undefined;
        const sanitized = try fs_helpers.sanitizeFxName(&name_buf, fx_name);
        var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
        const dir_path = fs_helpers.joinStrings(&dir_buf, &.{ self.controller_dir, std.fs.path.sep_str, "maps", std.fs.path.sep_str, "user", std.fs.path.sep_str, "STRIP", std.fs.path.sep_str, sanitized });
        try std.Io.Dir.cwd().createDirPath(io, dir_path);
        var aw: std.Io.Writer.Allocating = .init(self.allocator);
        defer aw.deinit();
        try mft_port.writeStripMap(&aw.writer, fx_name, strip);
        var file_buf: [std.fs.max_path_bytes]u8 = undefined;
        const file_path = fs_helpers.joinStrings(&file_buf, &.{ dir_path, std.fs.path.sep_str, "default.ini" });
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = file_path, .data = aw.written() });
        _ = self.STRIP.swapRemove(fx_name);
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
        // The map of a strip that the user made comes before the factory one.
        var opened = self.openMap(io, "user", "STRIP", fx_name, &file_buffer) catch |err| switch (err) {
            error.FileNotFound => try self.openMap(io, "factory", "STRIP", fx_name, &file_buffer),
            else => return err,
        };
        defer opened.file.close(io);
        var parser = ini.parse(temp_arena.allocator(), &opened.reader.interface, ";#");
        defer parser.deinit();
        return try parseStripMapping(&parser);
    }

    const OpenedMap = struct { file: std.Io.File, reader: std.Io.File.Reader };

    /// Opens `maps/<root>/<dir>/<sanitized fx name>/default.ini`, where the root is `user` or `factory`. The reader reads into `buffer`, which the caller keeps alive.
    fn openMap(self: *MftMapStore, io: std.Io, root: []const u8, dir: []const u8, fx_name: [:0]const u8, buffer: []u8) !OpenedMap {
        var name_buf: [512:0]u8 = undefined;
        const sanitized = try fs_helpers.sanitizeFxName(&name_buf, fx_name);
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = fs_helpers.joinStrings(&path_buf, &.{
            self.controller_dir, std.fs.path.sep_str, "maps",        std.fs.path.sep_str,
            root,                std.fs.path.sep_str, dir,           std.fs.path.sep_str,
            sanitized,           std.fs.path.sep_str, "default.ini",
        });
        const file = try std.Io.Dir.openFileAbsolute(io, path, .{});
        return .{ .file = file, .reader = file.reader(io, buffer) };
    }

    /// Fills `list` with the names of the plugins that have a map for the module, as the first level of the browser shows them. The name of a plugin is
    /// the one in the header of its map, because the name of its folder has lost the characters that a file name cannot have.
    pub fn listFx(self: *MftMapStore, io: std.Io, module: MappableModule, list: *BrowserList) void {
        self.listDir(io, module.dirName(), list);
    }

    /// Fills `list` with the names of the channel strips that have a map, which the browser lists in the single FX mode.
    pub fn listStrips(self: *MftMapStore, io: std.Io, list: *BrowserList) void {
        self.listDir(io, "STRIP", list);
    }

    fn listDir(self: *MftMapStore, io: std.Io, dir_name: []const u8, list: *BrowserList) void {
        list.clear();
        // The maps of the user and the factory maps of the module, a plugin that has both being listed once.
        for ([_][]const u8{ "user", "factory" }) |root| {
            var path_buf: [std.fs.max_path_bytes]u8 = undefined;
            const path = fs_helpers.joinStrings(&path_buf, &.{ self.controller_dir, std.fs.path.sep_str, "maps", std.fs.path.sep_str, root, std.fs.path.sep_str, dir_name });
            var dir = std.Io.Dir.openDirAbsolute(io, path, .{ .iterate = true }) catch continue;
            defer dir.close(io);
            var iter = dir.iterate();
            while (iter.next(io) catch null) |entry| {
                if (entry.kind != .directory) continue;
                var file_path_buf: [std.fs.max_path_bytes]u8 = undefined;
                const file_path = std.fmt.bufPrint(&file_path_buf, "{s}/default.ini", .{entry.name}) catch continue;
                var text_buf: [1024]u8 = undefined;
                const text = dir.readFile(io, file_path, &text_buf) catch continue;
                if (fxNameFromHeader(text)) |name| {
                    if (!list.contains(name)) list.add(name);
                }
            }
        }
        list.sort();
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

/// The name of the plugin in the header of a map (`fx_name = ...`), or null when the text has none.
pub fn fxNameFromHeader(text: []const u8) ?[]const u8 {
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "fx_name")) continue;
        const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const name = std.mem.trim(u8, line[eq + 1 ..], " \t\r");
        if (name.len > 0) return name;
    }
    return null;
}

test "fxNameFromHeader: the name after fx_name, trimmed, and null for a text without one" {
    const t = std.testing;
    try t.expectEqualStrings("VST: ReaEQ (Cockos)", fxNameFromHeader("version = 2\nmodule = EQ\nfx_name = VST: ReaEQ (Cockos)\r\nknob_1 = 0\n").?);
    try t.expectEqual(@as(?[]const u8, null), fxNameFromHeader("version = 2\nknob_1 = 0\n"));
    try t.expectEqual(@as(?[]const u8, null), fxNameFromHeader("fx_name =\n"));
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

test "a map that is written as the user's map reads back the same, with its pushes, its dry/wet and its bands" {
    const t = std.testing;
    var mapping = MftModuleMapping{};
    mapping.setSlot(0, 9);
    mapping.setSlot(15, mappings.wet_param);
    mapping.setPush(0, .{ .band = 2 });
    mapping.setPush(7, .{ .param = 4 });
    var aw: std.Io.Writer.Allocating = .init(t.allocator);
    defer aw.deinit();
    try mft_port.writeModuleMap(&aw.writer, .EQ, "VST: ReaEQ (Cockos)", &mapping);
    var fbs: std.Io.Reader = .fixed(aw.written());
    var parser = ini.parse(t.allocator, &fbs, ";#");
    defer parser.deinit();
    const read = try parseMapping(&parser);
    try t.expectEqual(mapping.knobs, read.knobs);
    try t.expectEqual(mapping.pushes, read.pushes);
    try t.expectEqualStrings("VST: ReaEQ (Cockos)", fxNameFromHeader(aw.written()).?);
}

test "saveUser writes the map of the user, the loader reads it before the factory map, and the plugin is listed once" {
    const t = std.testing;
    const io = t.io;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(io, ".", t.allocator);
    defer t.allocator.free(root);

    // The store keeps the names it caches in the allocator that it is given, which in the extension is an arena.
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    var store = MftMapStore.init(arena.allocator(), root);

    // A factory map of the plugin, with the knob 1 on the parameter 5.
    const factory_dir = try std.fmt.allocPrint(t.allocator, "{s}/maps/factory/EQ/VST_ ReaEQ (Cockos)", .{root});
    defer t.allocator.free(factory_dir);
    try std.Io.Dir.cwd().createDirPath(io, factory_dir);
    const factory_file = try std.fmt.allocPrint(t.allocator, "{s}/default.ini", .{factory_dir});
    defer t.allocator.free(factory_file);
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = factory_file, .data = "version = 2\nmodule = EQ\nfx_name = VST: ReaEQ (Cockos)\nknob_1 = 5\n" });
    try t.expectEqual(@as(?u16, 5), store.get(io, .EQ, "VST: ReaEQ (Cockos)").?.slotToParam(0));

    // The user's map replaces it at once, even though the factory map was kept in memory.
    var mine = MftModuleMapping{};
    mine.setSlot(0, 9);
    try store.saveUser(io, .EQ, "VST: ReaEQ (Cockos)", &mine);
    try t.expectEqual(@as(?u16, 9), store.get(io, .EQ, "VST: ReaEQ (Cockos)").?.slotToParam(0));

    var list = BrowserList{};
    store.listFx(io, .EQ, &list);
    try t.expectEqual(@as(usize, 1), list.count);
    try t.expectEqualStrings("VST: ReaEQ (Cockos)", list.get(0));
}

test "the map of the AUTO page is the factory one until the user saves one, which is read first" {
    const t = std.testing;
    const io = t.io;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(io, ".", t.allocator);
    defer t.allocator.free(root);
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    var store = MftMapStore.init(arena.allocator(), root);

    // Without any file, the map is empty.
    try t.expectEqual(@as(?mft_auto.Target, null), store.getAuto(io).pushes[0]);
    store.auto = null;
    const factory_dir = try std.fmt.allocPrint(t.allocator, "{s}/maps/factory/AUTO", .{root});
    defer t.allocator.free(factory_dir);
    try std.Io.Dir.cwd().createDirPath(io, factory_dir);
    const factory_file = try std.fmt.allocPrint(t.allocator, "{s}/default.ini", .{factory_dir});
    defer t.allocator.free(factory_file);
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = factory_file, .data = "version = 2\nmodule = AUTO\npush_1 = action:40400\n" });
    try t.expectEqual(@as(c_int, 40400), store.getAuto(io).pushes[0].?.action);

    var mine = mft_auto.AutoMap{};
    mine.setControl(0, .{ .fx_param = mft_auto.FxParam.init("JS: Saturation", 0) });
    try store.saveAuto(io, &mine);
    store.auto = null;
    const read = store.getAuto(io);
    try t.expect(read.eql(&mine));
}

test "the map of a channel strip that the user saves is read back before the factory one, and the strip is listed" {
    const t = std.testing;
    const io = t.io;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(io, ".", t.allocator);
    defer t.allocator.free(root);
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    var store = MftMapStore.init(arena.allocator(), root);
    var strip = mappings.StripMapping{};
    strip.pages[@backingInt(MappableModule.EQ)].setSlot(0, 3);
    strip.pages[@backingInt(MappableModule.OUTPUT)].setPush(1, .{ .param = 8 });
    try store.saveStrip(io, "JS: Lumina Channel Strip", &strip);
    const read = store.getStrip(io, "JS: Lumina Channel Strip").?;
    try t.expect(std.meta.eql(read, strip));
    var list = BrowserList{};
    store.listStrips(io, &list);
    try t.expectEqual(@as(usize, 1), list.count);
    try t.expectEqualStrings("JS: Lumina Channel Strip", list.get(0));
}
