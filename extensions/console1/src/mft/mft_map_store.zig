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

/// Whose maps a list or a choice is about: the plugin of a module, or a channel strip, whose maps are in a folder of their own.
pub const Owner = union(enum) {
    module: MappableModule,
    strip,

    pub fn dirName(self: Owner) [:0]const u8 {
        return switch (self) {
            .module => |m| m.dirName(),
            .strip => "STRIP",
        };
    }
};

/// The name of the map that a plugin has when nobody chose another one, which is the file `default.ini` of the plugin.
pub const default_map = "default";

/// The file that keeps the default map of each plugin, in the folder of the controller. Because a plugin can have several maps, and the user picks one of
/// them as the one that the plugin starts from, the choice is kept in a file of its own, which a reinstall of the factory maps leaves alone. It has a
/// section for each folder of maps (`[EQ]`), and a line `<plugin> = <map>` for each plugin whose default is not `default`.
pub const default_maps_file = "default_maps.ini";

/// How long the name of a map can be.
pub const map_name_len = 63;

// Lazily loads and caches per-module FX mappings from
// <controller_dir>/maps/<user or factory>/<MODULE>/<fx_name>/<map name>.ini. Each module
// keeps its own cache keyed by FX name, which holds the map that the plugin uses.
pub const MftMapStore = struct {
    INPUT: std.StringArrayHashMapUnmanaged(?MftModuleMapping) = .{},
    GATE: std.StringArrayHashMapUnmanaged(?MftModuleMapping) = .{},
    EQ: std.StringArrayHashMapUnmanaged(?MftModuleMapping) = .{},
    COMP: std.StringArrayHashMapUnmanaged(?MftModuleMapping) = .{},
    OUTPUT: std.StringArrayHashMapUnmanaged(?MftModuleMapping) = .{},
    STRIP: std.StringArrayHashMapUnmanaged(?mappings.StripMapping) = .{},
    /// The map of the AUTO page, once it was read.
    auto: ?mft_auto.AutoMap = null,
    /// The map that each plugin uses in this session, when it is not its default: the map that was chosen in the FX Selection or in the mapping
    /// panel. The keys are `<folder>|<plugin>` (see `choiceKey`).
    in_use: std.StringArrayHashMapUnmanaged([:0]const u8) = .{},
    /// The default maps of the plugins, which `default_maps.ini` keeps, read the first time that they are needed.
    defaults: std.StringArrayHashMapUnmanaged([:0]const u8) = .{},
    defaults_read: bool = false,
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
        var opened = try self.openInUse(io, .{ .module = module }, fx_name, &file_buffer);
        defer opened.file.close(io);
        var parser = ini.parse(temp_arena.allocator(), &opened.reader.interface, ";#");
        defer parser.deinit();
        return try parseMapping(&parser);
    }

    /// Saves a map that the user made, as `maps/user/<MODULE>/<plugin>/<map>.ini`, the map being the one that the plugin uses, which the loader reads
    /// before the factory map of the same name. The map that was kept in memory for the plugin is dropped, so that the next turn of an encoder reads the
    /// new one.
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
        const file_path = fs_helpers.joinStrings(&file_buf, &.{ dir_path, std.fs.path.sep_str, self.mapInUse(io, .{ .module = module }, fx_name), ".ini" });
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
        const file_path = fs_helpers.joinStrings(&file_buf, &.{ dir_path, std.fs.path.sep_str, self.mapInUse(io, .strip, fx_name), ".ini" });
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
        var opened = try self.openInUse(io, .strip, fx_name, &file_buffer);
        defer opened.file.close(io);
        var parser = ini.parse(temp_arena.allocator(), &opened.reader.interface, ";#");
        defer parser.deinit();
        return try parseStripMapping(&parser);
    }

    const OpenedMap = struct { file: std.Io.File, reader: std.Io.File.Reader };

    /// Opens `maps/<root>/<dir>/<sanitized fx name>/<map>.ini`, where the root is `user` or `factory`. The reader reads into `buffer`, which the caller keeps alive.
    fn openMap(self: *MftMapStore, io: std.Io, root: []const u8, dir: []const u8, fx_name: [:0]const u8, map_name: []const u8, buffer: []u8) !OpenedMap {
        var name_buf: [512:0]u8 = undefined;
        const sanitized = try fs_helpers.sanitizeFxName(&name_buf, fx_name);
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const path = fs_helpers.joinStrings(&path_buf, &.{
            self.controller_dir, std.fs.path.sep_str, "maps",   std.fs.path.sep_str,
            root,                std.fs.path.sep_str, dir,      std.fs.path.sep_str,
            sanitized,           std.fs.path.sep_str, map_name, ".ini",
        });
        const file = try std.Io.Dir.openFileAbsolute(io, path, .{});
        return .{ .file = file, .reader = file.reader(io, buffer) };
    }

    /// Opens a map of the user or the factory map of the same name, the user's first.
    fn openEither(self: *MftMapStore, io: std.Io, dir: []const u8, fx_name: [:0]const u8, map_name: []const u8, buffer: []u8) !OpenedMap {
        return self.openMap(io, "user", dir, fx_name, map_name, buffer) catch |err| switch (err) {
            error.FileNotFound => try self.openMap(io, "factory", dir, fx_name, map_name, buffer),
            else => return err,
        };
    }

    /// Opens the map that the plugin uses. Because a map that was chosen can be gone from the disk (the user deleted its file), the map `default` is
    /// opened when it is not there.
    fn openInUse(self: *MftMapStore, io: std.Io, owner: Owner, fx_name: [:0]const u8, buffer: []u8) !OpenedMap {
        const name = self.mapInUse(io, owner, fx_name);
        return self.openEither(io, owner.dirName(), fx_name, name, buffer) catch |err| switch (err) {
            error.FileNotFound => if (std.mem.eql(u8, name, default_map)) err else try self.openEither(io, owner.dirName(), fx_name, default_map, buffer),
            else => return err,
        };
    }

    /// The key of a plugin in the choices of the maps: its folder and its name, which tell apart a plugin that has maps for two modules.
    fn choiceKey(buf: []u8, owner: Owner, fx_name: []const u8) ?[]const u8 {
        return std.fmt.bufPrint(buf, "{s}|{s}", .{ owner.dirName(), fx_name }) catch null;
    }

    /// The default map of a plugin: the one that the user made its default, or `default`.
    pub fn defaultMapName(self: *MftMapStore, io: std.Io, owner: Owner, fx_name: []const u8) [:0]const u8 {
        self.readDefaults(io);
        var key_buf: [600]u8 = undefined;
        const key = choiceKey(&key_buf, owner, fx_name) orelse return default_map;
        return self.defaults.get(key) orelse default_map;
    }

    /// The map that a plugin uses: the one that was chosen in this session, or its default map.
    pub fn mapInUse(self: *MftMapStore, io: std.Io, owner: Owner, fx_name: []const u8) [:0]const u8 {
        var key_buf: [600]u8 = undefined;
        const key = choiceKey(&key_buf, owner, fx_name) orelse return default_map;
        return self.in_use.get(key) orelse self.defaultMapName(io, owner, fx_name);
    }

    /// Puts a name in one of the tables of the choices, the key and the name being copied into the allocator of the store.
    fn putChoice(self: *MftMapStore, table: *std.StringArrayHashMapUnmanaged([:0]const u8), owner: Owner, fx_name: []const u8, map_name: []const u8) !void {
        var key_buf: [600]u8 = undefined;
        const key = choiceKey(&key_buf, owner, fx_name) orelse return error.NameTooLong;
        const owned_name = try self.allocator.dupeSentinel(u8, map_name, 0);
        if (table.getPtr(key)) |slot| {
            slot.* = owned_name;
            return;
        }
        try table.put(self.allocator, try self.allocator.dupe(u8, key), owned_name);
    }

    /// Drops the map that was kept in memory for a plugin, so that the next turn of an encoder reads the map that the plugin uses now.
    fn dropCached(self: *MftMapStore, owner: Owner, fx_name: []const u8) void {
        switch (owner) {
            .module => |m| _ = self.cacheFor(m).swapRemove(fx_name),
            .strip => _ = self.STRIP.swapRemove(fx_name),
        }
    }

    /// Makes a plugin use one of its maps for the rest of the session, which the FX Selection does when a map is chosen to load the plugin with, and the
    /// mapping panel when a map is chosen or made.
    pub fn useMap(self: *MftMapStore, owner: Owner, fx_name: []const u8, map_name: []const u8) !void {
        try self.putChoice(&self.in_use, owner, fx_name, map_name);
        self.dropCached(owner, fx_name);
    }

    /// Makes a map the default of its plugin, which the plugin also uses from now on, and writes the choice to `default_maps.ini` at once. Because the
    /// file has one `<plugin> = <map>` line for each plugin, a name that has an equal sign is refused.
    pub fn setDefaultMap(self: *MftMapStore, io: std.Io, owner: Owner, fx_name: []const u8, map_name: []const u8) !void {
        if (std.mem.indexOfScalar(u8, fx_name, '=') != null or std.mem.indexOfScalar(u8, map_name, '=') != null) return error.UnsupportedName;
        self.readDefaults(io);
        try self.putChoice(&self.defaults, owner, fx_name, map_name);
        try self.useMap(owner, fx_name, map_name);
        try self.writeDefaults(io);
    }

    fn defaultsPath(self: *const MftMapStore, buf: []u8) []const u8 {
        return fs_helpers.joinStrings(buf, &.{ self.controller_dir, std.fs.path.sep_str, default_maps_file });
    }

    /// Reads `default_maps.ini`, once. A missing file only means that no default was chosen yet.
    fn readDefaults(self: *MftMapStore, io: std.Io) void {
        if (self.defaults_read) return;
        self.defaults_read = true;
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        var text_buf: [16384]u8 = undefined;
        const text = std.Io.Dir.cwd().readFile(io, self.defaultsPath(&path_buf), &text_buf) catch return;
        var choices = DefaultsReader{ .text = text };
        while (choices.next()) |choice| {
            self.putChoice(&self.defaults, choice.owner, choice.fx_name, choice.map_name) catch |err| {
                log.warn("skipped the default map {s} of {s}: {s}", .{ choice.map_name, choice.fx_name, @errorName(err) });
            };
        }
    }

    /// Writes `default_maps.ini` from the defaults that the store has, a section for each folder of maps.
    fn writeDefaults(self: *MftMapStore, io: std.Io) !void {
        var aw: std.Io.Writer.Allocating = .init(self.allocator);
        defer aw.deinit();
        try writeDefaultsText(&self.defaults, &aw.writer);
        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = self.defaultsPath(&path_buf), .data = aw.written() });
    }

    /// Fills `list` with the names of the maps of a plugin, the user's and the factory ones, a name that both have being listed once. The map `default`
    /// comes first, and the others in the order of the alphabet.
    pub fn listMaps(self: *MftMapStore, io: std.Io, owner: Owner, fx_name: [:0]const u8, list: *BrowserList) void {
        list.clear();
        var name_buf: [512:0]u8 = undefined;
        const sanitized = fs_helpers.sanitizeFxName(&name_buf, fx_name) catch return;
        for ([_][]const u8{ "user", "factory" }) |root| {
            var path_buf: [std.fs.max_path_bytes]u8 = undefined;
            const path = fs_helpers.joinStrings(&path_buf, &.{ self.controller_dir, std.fs.path.sep_str, "maps", std.fs.path.sep_str, root, std.fs.path.sep_str, owner.dirName(), std.fs.path.sep_str, sanitized });
            var dir = std.Io.Dir.openDirAbsolute(io, path, .{ .iterate = true }) catch continue;
            defer dir.close(io);
            var iter = dir.iterate();
            while (iter.next(io) catch null) |entry| {
                if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".ini")) continue;
                const name = entry.name[0 .. entry.name.len - ".ini".len];
                if (name.len == 0 or list.contains(name)) continue;
                list.add(name);
            }
        }
        list.sort();
        putFirst(list, default_map);
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
                // The name of the plugin is in the header of any of its maps; the map `default` is read first, since nearly every plugin has it.
                if (pluginNameIn(io, dir, entry.name)) |name| {
                    if (!list.contains(name.slice())) list.add(name.slice());
                }
            }
        }
        list.sort();
    }

    pub fn deinit(self: *MftMapStore) void {
        self.in_use.deinit(self.allocator);
        self.defaults.deinit(self.allocator);
        inline for (.{ &self.INPUT, &self.GATE, &self.EQ, &self.COMP, &self.OUTPUT }) |cache| {
            cache.deinit(self.allocator);
        }
        self.STRIP.deinit(self.allocator);
    }
};

/// The name of a plugin, read from the header of one of its maps.
const PluginName = struct {
    buf: [256]u8 = undefined,
    len: usize = 0,

    pub fn slice(self: *const PluginName) []const u8 {
        return self.buf[0..self.len];
    }
};

/// Reads the name of the plugin of a folder from the header of one of its maps: `default.ini` when it is there, and the first map otherwise.
fn pluginNameIn(io: std.Io, parent: std.Io.Dir, folder: []const u8) ?PluginName {
    var out = PluginName{};
    var text_buf: [1024]u8 = undefined;
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const default_path = std.fmt.bufPrint(&path_buf, "{s}/" ++ default_map ++ ".ini", .{folder}) catch return null;
    if (parent.readFile(io, default_path, &text_buf)) |text| {
        const name = fxNameFromHeader(text) orelse return null;
        const n = @min(name.len, out.buf.len);
        @memcpy(out.buf[0..n], name[0..n]);
        out.len = n;
        return out;
    } else |_| {}
    var dir = parent.openDir(io, folder, .{ .iterate = true }) catch return null;
    defer dir.close(io);
    var iter = dir.iterate();
    while (iter.next(io) catch null) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".ini")) continue;
        const text = dir.readFile(io, entry.name, &text_buf) catch continue;
        const name = fxNameFromHeader(text) orelse continue;
        const n = @min(name.len, out.buf.len);
        @memcpy(out.buf[0..n], name[0..n]);
        out.len = n;
        return out;
    }
    return null;
}

/// Moves an entry of a list to its front, when the list has it.
fn putFirst(list: *BrowserList, name: []const u8) void {
    var at: usize = 0;
    while (at < list.count and !std.mem.eql(u8, list.get(at), name)) : (at += 1) {}
    if (at == list.count or at == 0) return;
    const moved = list.names[at];
    var i = at;
    while (i > 0) : (i -= 1) list.names[i] = list.names[i - 1];
    list.names[0] = moved;
}

/// A default map that `default_maps.ini` names: the folder of its plugin, the plugin, and the map.
const DefaultChoice = struct { owner: Owner, fx_name: []const u8, map_name: []const u8 };

/// Reads the lines of `default_maps.ini`. A line before the first section, in a section that is not a folder of maps, or without an equal sign, is skipped.
const DefaultsReader = struct {
    text: []const u8,
    at: usize = 0,
    owner: ?Owner = null,

    pub fn next(self: *DefaultsReader) ?DefaultChoice {
        while (self.at < self.text.len) {
            const end = std.mem.indexOfScalarPos(u8, self.text, self.at, '\n') orelse self.text.len;
            const line = std.mem.trim(u8, self.text[self.at..end], " \t\r");
            self.at = end + 1;
            if (line.len == 0 or line[0] == ';' or line[0] == '#') continue;
            if (line[0] == '[' and line[line.len - 1] == ']') {
                self.owner = ownerOfDir(line[1 .. line.len - 1]);
                continue;
            }
            const owner = self.owner orelse continue;
            const eq = std.mem.indexOfScalar(u8, line, '=') orelse continue;
            const fx_name = std.mem.trim(u8, line[0..eq], " \t");
            const map_name = std.mem.trim(u8, line[eq + 1 ..], " \t");
            if (fx_name.len == 0 or map_name.len == 0) continue;
            return .{ .owner = owner, .fx_name = fx_name, .map_name = map_name };
        }
        return null;
    }
};

/// The owner of a folder of maps, from its name, or null for a name that is not one.
fn ownerOfDir(name: []const u8) ?Owner {
    if (std.mem.eql(u8, name, "STRIP")) return .strip;
    inline for (@typeInfo(MappableModule).@"enum".field_names) |field_name| {
        const module = @field(MappableModule, field_name);
        if (std.mem.eql(u8, name, module.dirName())) return .{ .module = module };
    }
    return null;
}

/// Writes the defaults of the maps as `default_maps.ini` has them: a section for each folder that has one, and a line for each plugin of that folder.
fn writeDefaultsText(defaults: *const std.StringArrayHashMapUnmanaged([:0]const u8), w: *std.Io.Writer) !void {
    const folders = [_][]const u8{ "INPUT", "GATE", "EQ", "COMP", "OUTPUT", "STRIP" };
    for (folders) |folder| {
        var wrote_heading = false;
        var it = defaults.iterator();
        while (it.next()) |entry| {
            const key = entry.key_ptr.*;
            const bar = std.mem.indexOfScalar(u8, key, '|') orelse continue;
            if (!std.mem.eql(u8, key[0..bar], folder)) continue;
            if (!wrote_heading) {
                try w.print("[{s}]\n", .{folder});
                wrote_heading = true;
            }
            try w.print("{s} = {s}\n", .{ key[bar + 1 ..], entry.value_ptr.* });
        }
        if (wrote_heading) try w.writeByte('\n');
    }
}

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

test "a plugin can have several maps: the list has default first, a chosen map is used, and the default is kept in default_maps.ini" {
    const t = std.testing;
    const io = t.io;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const root = try tmp.dir.realPathFileAlloc(io, ".", t.allocator);
    defer t.allocator.free(root);
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    var store = MftMapStore.init(arena.allocator(), root);
    const fx = "VST: ReaEQ (Cockos)";
    const dir = try std.fmt.allocPrint(t.allocator, "{s}/maps/factory/EQ/VST_ ReaEQ (Cockos)", .{root});
    defer t.allocator.free(dir);
    try std.Io.Dir.cwd().createDirPath(io, dir);
    for ([_]struct { name: []const u8, knob: []const u8 }{ .{ .name = "default", .knob = "5" }, .{ .name = "Vocals", .knob = "7" }, .{ .name = "Bass", .knob = "8" } }) |m| {
        const file = try std.fmt.allocPrint(t.allocator, "{s}/{s}.ini", .{ dir, m.name });
        defer t.allocator.free(file);
        const text = try std.fmt.allocPrint(t.allocator, "version = 2\nmodule = EQ\nfx_name = {s}\nknob_1 = {s}\n", .{ fx, m.knob });
        defer t.allocator.free(text);
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = file, .data = text });
    }
    var list = BrowserList{};
    store.listMaps(io, .{ .module = .EQ }, fx, &list);
    try t.expectEqual(@as(usize, 3), list.count);
    try t.expectEqualStrings("default", list.get(0));
    try t.expectEqualStrings("Bass", list.get(1));
    try t.expectEqualStrings("Vocals", list.get(2));
    // The plugin is listed once in the browser, from the header of its maps.
    store.listFx(io, .EQ, &list);
    try t.expectEqual(@as(usize, 1), list.count);

    try t.expectEqual(@as(?u16, 5), store.get(io, .EQ, fx).?.slotToParam(0));
    try store.useMap(.{ .module = .EQ }, fx, "Vocals");
    try t.expectEqual(@as(?u16, 7), store.get(io, .EQ, fx).?.slotToParam(0));
    try t.expectEqualStrings("default", store.defaultMapName(io, .{ .module = .EQ }, fx));

    try store.setDefaultMap(io, .{ .module = .EQ }, fx, "Bass");
    try t.expectEqual(@as(?u16, 8), store.get(io, .EQ, fx).?.slotToParam(0));
    // A new store, as in the next session, reads the default from the file.
    var next = MftMapStore.init(arena.allocator(), root);
    try t.expectEqualStrings("Bass", next.defaultMapName(io, .{ .module = .EQ }, fx));
    try t.expectEqualStrings("default", next.defaultMapName(io, .{ .module = .COMP }, fx));
    try t.expectEqual(@as(?u16, 8), next.get(io, .EQ, fx).?.slotToParam(0));
    // A map that is gone from the disk leaves the plugin with its map default.
    try next.useMap(.{ .module = .EQ }, fx, "Gone");
    try t.expectEqual(@as(?u16, 5), next.get(io, .EQ, fx).?.slotToParam(0));
    try t.expectError(error.UnsupportedName, next.setDefaultMap(io, .{ .module = .EQ }, fx, "a=b"));
}

test "default_maps.ini: the lines of its sections are read back as they are written, and the lines that are not choices are skipped" {
    const t = std.testing;
    var reader = DefaultsReader{ .text = "eq = x\n[EQ]\nVST: ReaEQ (Cockos) = Vocals\n; a comment\nno equal sign\n[NOPE]\nA = B\n[STRIP]\nJS: Strip = Mix\n" };
    const first = reader.next().?;
    try t.expectEqual(Owner{ .module = .EQ }, first.owner);
    try t.expectEqualStrings("VST: ReaEQ (Cockos)", first.fx_name);
    try t.expectEqualStrings("Vocals", first.map_name);
    const second = reader.next().?;
    try t.expectEqual(Owner.strip, second.owner);
    try t.expectEqualStrings("Mix", second.map_name);
    try t.expectEqual(@as(?DefaultChoice, null), reader.next());
}
