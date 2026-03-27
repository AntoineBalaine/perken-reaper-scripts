const std = @import("std");
const ModulesList = @import("statemachine.zig").ModulesList;
const log = std.log.scoped(.mapping_list);
const ini = @import("ini");
const fs_helpers = @import("fs_helpers.zig");
const StringPool = @import("string_pool.zig").StringPool;

pub const MapEntry = struct {
    name_offset: StringPool.StringRef, // mapping name (filename without .ini) in StringPool
    path_offset: StringPool.StringRef, // absolute file path in StringPool
};

pub const ModuleMap = std.ArrayHashMapUnmanaged(StringPool.StringRef, std.ArrayList(MapEntry), std.array_hash_map.AutoContext(StringPool.StringRef), false);

pub const IniHeader = struct {
    module: ModulesList,
    fx_name: [:0]const u8,
};

// Store hierarchical FX names with their mapping entries using StringPool offsets.
// Keys are FX name StringRefs, values are ArrayLists of MapEntry.
// Using ArrayHashMap to maintain insertion order for scrolling/indexing.
list: std.EnumArray(ModulesList, ModuleMap),
strings: StringPool,
allocator: std.mem.Allocator,

pub fn empty(arena: std.mem.Allocator) @This() {
    return .{
        .list = std.EnumArray(ModulesList, ModuleMap).init(.{
            .INPUT = .empty,
            .GATE = .empty,
            .EQ = .empty,
            .COMP = .empty,
            .OUTPT = .empty,
            .STRIP = .empty,
        }),
        .strings = .empty,
        .allocator = arena,
    };
}

pub fn init(arena: std.mem.Allocator, resource_path: [:0]const u8) @This() {
    var strings: StringPool = .empty;
    var list = std.EnumArray(ModulesList, ModuleMap).initUndefined();

    inline for (comptime std.enums.values(ModulesList)) |module| {
        list.set(module, .empty);
    }

    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const maps_path = fs_helpers.joinStrings(&path_buffer, &.{
        resource_path,
        std.fs.path.sep_str,
        "maps",
    });

    var maps_dir = std.fs.openDirAbsolute(maps_path, .{ .iterate = true }) catch {
        return .{
            .list = list,
            .strings = strings,
            .allocator = arena,
        };
    };
    defer maps_dir.close();

    var walk_ctx = WalkContext{
        .strings = &strings,
        .list = &list,
        .arena = arena,
        .base_path_buf = undefined,
        .base_path_len = maps_path.len,
    };
    @memcpy(walk_ctx.base_path_buf[0..maps_path.len], maps_path);

    walkDir(&walk_ctx, maps_dir);

    return .{
        .list = list,
        .strings = strings,
        .allocator = arena,
    };
}

pub fn deinit(self: *@This()) void {
    inline for (comptime std.enums.values(ModulesList)) |module| {
        var mod_map = self.list.getPtr(module);
        var iter = mod_map.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        mod_map.deinit(self.allocator);
    }
    self.strings.deinit(self.allocator);
}

pub fn lookupPath(self: *@This(), module: ModulesList, fx_name: [:0]const u8, mapping_name: [:0]const u8) ?[:0]const u8 {
    const mod_map = self.list.getPtr(module);

    // Because StringPool does not deduplicate, the same string can have multiple
    // offsets. We compare by string value rather than by offset to avoid mismatches
    // when the same fx_name was interned more than once (e.g. from files in
    // different directories).
    var iter = mod_map.iterator();
    while (iter.next()) |map_entry| {
        const stored_fx_name = self.strings.get(map_entry.key_ptr.*);
        if (std.mem.eql(u8, stored_fx_name, fx_name)) {
            for (map_entry.value_ptr.items) |entry| {
                const stored_mapping_name = self.strings.get(entry.name_offset);
                if (std.mem.eql(u8, stored_mapping_name, mapping_name)) {
                    return self.strings.get(entry.path_offset);
                }
            }
        }
    }
    return null;
}

pub fn registerPath(self: *@This(), module: ModulesList, fx_name: [:0]const u8, mapping_name: [:0]const u8, file_path: [:0]const u8) !void {
    const fx_offset = try self.strings.intern(self.allocator, fx_name);
    const name_offset = try self.strings.intern(self.allocator, mapping_name);
    const path_offset = try self.strings.intern(self.allocator, file_path);

    const mod_map = self.list.getPtr(module);
    const gop = try mod_map.getOrPut(self.allocator, fx_offset);
    if (!gop.found_existing) {
        gop.value_ptr.* = std.ArrayList(MapEntry).init(self.allocator);
    }

    // Check if an entry with the same mapping name already exists
    for (gop.value_ptr.items) |*entry| {
        if (entry.name_offset == name_offset) {
            entry.path_offset = path_offset;
            return;
        }
    }

    try gop.value_ptr.append(.{
        .name_offset = name_offset,
        .path_offset = path_offset,
    });
}

const WalkContext = struct {
    strings: *StringPool,
    list: *std.EnumArray(ModulesList, ModuleMap),
    arena: std.mem.Allocator,
    base_path_buf: [std.fs.max_path_bytes]u8,
    base_path_len: usize,
};

fn walkDir(ctx: *WalkContext, dir: std.fs.Dir) void {
    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind == .directory) {
            var sub_dir = dir.openDir(entry.name, .{ .iterate = true }) catch continue;
            defer sub_dir.close();

            // Extend path: current_path / entry.name
            const old_len = ctx.base_path_len;
            const sep = std.fs.path.sep_str;
            if (old_len + 1 + entry.name.len > std.fs.max_path_bytes) continue;
            @memcpy(ctx.base_path_buf[old_len .. old_len + sep.len], sep);
            @memcpy(ctx.base_path_buf[old_len + sep.len .. old_len + sep.len + entry.name.len], entry.name);
            ctx.base_path_len = old_len + sep.len + entry.name.len;

            walkDir(ctx, sub_dir);

            // Restore path length
            ctx.base_path_len = old_len;
        } else if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".ini")) {
            processIniFile(ctx, dir, entry.name);
        }
    }
}

fn processIniFile(ctx: *WalkContext, dir: std.fs.Dir, file_name: []const u8) void {
    const header = readIniHeader(ctx.arena, dir, file_name) orelse return;

    // Extract mapping name (filename without .ini extension)
    const mapping_name_slice = file_name[0 .. file_name.len - 4];
    var name_buf: [256:0]u8 = undefined;
    const mapping_name = std.fmt.bufPrintZ(&name_buf, "{s}", .{mapping_name_slice}) catch return;

    // Build absolute file path
    const sep = std.fs.path.sep_str;
    const path_len = ctx.base_path_len;
    if (path_len + sep.len + file_name.len > std.fs.max_path_bytes) return;

    var abs_path_buf: [std.fs.max_path_bytes:0]u8 = undefined;
    @memcpy(abs_path_buf[0..path_len], ctx.base_path_buf[0..path_len]);
    @memcpy(abs_path_buf[path_len .. path_len + sep.len], sep);
    @memcpy(abs_path_buf[path_len + sep.len .. path_len + sep.len + file_name.len], file_name);
    abs_path_buf[path_len + sep.len + file_name.len] = 0;
    const abs_path: [:0]const u8 = abs_path_buf[0 .. path_len + sep.len + file_name.len :0];

    const fx_offset = ctx.strings.intern(ctx.arena, header.fx_name) catch return;
    const name_offset = ctx.strings.intern(ctx.arena, mapping_name) catch return;
    const path_offset = ctx.strings.intern(ctx.arena, abs_path) catch return;

    // Because StringPool deduplicates, the same fx_name always returns the same
    // StringRef, so getOrPut finds existing entries without a linear scan.
    const mod_map = ctx.list.getPtr(header.module);
    const gop = mod_map.getOrPut(ctx.arena, fx_offset) catch return;
    if (!gop.found_existing) {
        gop.value_ptr.* = std.ArrayList(MapEntry).init(ctx.arena);
    }

    gop.value_ptr.append(.{
        .name_offset = name_offset,
        .path_offset = path_offset,
    }) catch return;
}

fn readIniHeader(arena: std.mem.Allocator, dir: std.fs.Dir, file_name: []const u8) ?IniHeader {
    const file = dir.openFile(file_name, .{}) catch return null;
    defer file.close();

    var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer temp_arena.deinit();

    var parser = ini.parse(temp_arena.allocator(), file.reader());
    defer parser.deinit();

    var module: ?ModulesList = null;
    var fx_name: ?[:0]const u8 = null;

    while (parser.next() catch null) |record| {
        if (record == .property) {
            if (std.mem.eql(u8, record.property.key, "module")) {
                inline for (comptime std.enums.values(ModulesList)) |mod_val| {
                    if (std.mem.eql(u8, record.property.value, @tagName(mod_val))) {
                        module = mod_val;
                    }
                }
            } else if (std.mem.eql(u8, record.property.key, "fx_name")) {
                fx_name = arena.dupeZ(u8, record.property.value) catch return null;
            }
        }
        if (module != null and fx_name != null) break;
    }

    if (module != null and fx_name != null) {
        return IniHeader{
            .module = module.?,
            .fx_name = fx_name.?,
        };
    }
    return null;
}

test "init scans resources/maps/defaults and finds default mappings" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var mem: [std.fs.max_path_bytes]u8 = undefined;
    const pth = try std.fs.cwd().realpath(".", &mem);
    const config_path = try std.fs.path.resolve(allocator, &.{ pth, "src/resources/" });
    const config_path_z = try allocator.dupeZ(u8, config_path);

    var ml = init(allocator, config_path_z);
    _ = &ml;

    try testing.expect(ml.list.getPtr(.COMP).count() >= 1);
    try testing.expect(ml.list.getPtr(.EQ).count() >= 1);
    try testing.expect(ml.list.getPtr(.GATE).count() >= 1);
    try testing.expect(ml.list.getPtr(.INPUT).count() >= 1);
    try testing.expect(ml.list.getPtr(.OUTPT).count() >= 1);

    // Verify lookupPath works for a known default
    const path = ml.lookupPath(.COMP, "VST: ReaComp (Cockos)", "default");
    try testing.expect(path != null);
}

test "StringPool offsets remain valid after buffer reallocation" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var strings: StringPool = .empty;
    defer strings.deinit(allocator);

    // Intern multiple strings to force buffer reallocation
    var offsets = std.ArrayList(StringPool.StringRef).init(allocator);
    defer offsets.deinit();

    const test_strings = [_][:0]const u8{
        "JS: RBJ Highpass/Lowpass Filters",
        "JS: Volume Adjustment",
        "JS: Volume/Pan Smoother v5",
        "VST: ReaComp (Cockos)",
        "VST: ReaEQ (Cockos)",
        "VST: ReaGate (Cockos)",
        "JS: ReaAnalog",
        "JS: Saturation",
    };

    // Store all offsets
    for (test_strings) |str| {
        const offset = try strings.intern(allocator, str);
        try offsets.append(offset);
    }

    // Verify all strings can be retrieved correctly using their offsets
    for (test_strings, 0..) |expected, i| {
        const actual = strings.get(offsets.items[i]);
        try testing.expectEqualStrings(expected, actual);
    }
}

test "mappings_list stores FX names with slashes correctly" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var strings: StringPool = .empty;
    defer strings.deinit(allocator);

    var list = ModuleMap{};
    defer {
        var iter = list.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        list.deinit(allocator);
    }

    // Test that FX names with slashes are stored correctly
    const fx_names = [_][:0]const u8{
        "JS: Volume/Pan Smoother v5",
        "JS: RBJ Highpass/Lowpass Filters",
    };

    var stored_offsets = std.ArrayList(StringPool.StringRef).init(allocator);
    defer stored_offsets.deinit();

    for (fx_names) |fx_name| {
        const fx_offset = try strings.intern(allocator, fx_name);
        try stored_offsets.append(fx_offset);

        // Create a MapEntry with a dummy mapping
        const mapping_name_offset = try strings.intern(allocator, "default");
        const path_offset = try strings.intern(allocator, "/some/path/default.ini");

        var entries = std.ArrayList(MapEntry).init(allocator);
        try entries.append(.{
            .name_offset = mapping_name_offset,
            .path_offset = path_offset,
        });

        try list.put(allocator, fx_offset, entries);
    }

    // Verify we can retrieve FX names correctly
    try testing.expectEqual(@as(usize, 2), list.count());

    for (fx_names, 0..) |expected_name, i| {
        const fx_offset = stored_offsets.items[i];
        const actual_name = strings.get(fx_offset);
        try testing.expectEqualStrings(expected_name, actual_name);

        // Verify it's in the map
        try testing.expect(list.contains(fx_offset));
    }
}

test "multiple maps for the same FX are grouped under one key" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Because we need two map files for the same FX to test grouping,
    // we create them in a temp directory rather than keeping fixtures
    // in src/resources (which could be installed by the backup code path).
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    try tmp_dir.dir.makePath("maps/EQ/reaeq");
    {
        const f = try tmp_dir.dir.createFile("maps/EQ/reaeq/default.ini", .{});
        defer f.close();
        try f.writeAll("version=1\nmodule=EQ\nfx_name=VST: ReaEQ (Cockos)\nEq_HiFrq=0\n");
    }
    {
        const f = try tmp_dir.dir.createFile("maps/EQ/reaeq/alternate.ini", .{});
        defer f.close();
        try f.writeAll("version=1\nmodule=EQ\nfx_name=VST: ReaEQ (Cockos)\nEq_HiFrq=9\n");
    }

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const tmp_path = try tmp_dir.dir.realpath(".", &path_buf);
    const config_path_z = try allocator.dupeZ(u8, tmp_path);

    var ml = init(allocator, config_path_z);
    _ = &ml;

    const eq_map = ml.list.getPtr(.EQ);
    var reaeq_count: usize = 0;
    var iter = eq_map.iterator();
    while (iter.next()) |entry| {
        const fx_name = ml.strings.get(entry.key_ptr.*);
        if (std.mem.eql(u8, fx_name, "VST: ReaEQ (Cockos)")) {
            reaeq_count = entry.value_ptr.items.len;
        }
    }

    try testing.expectEqual(@as(usize, 2), reaeq_count);
}
