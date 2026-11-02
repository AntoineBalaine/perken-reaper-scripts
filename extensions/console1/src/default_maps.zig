const std = @import("std");
const ini = @import("ini");
const fs_helpers = @import("fs_helpers");
const ModulesList = @import("statemachine.zig").ModulesList;
const log = std.log.scoped(.default_maps);

/// The file that holds the default maps, next to the preferences.
pub const file_name = "default_maps.ini";

/// The name of the map of each FX, by the name of the FX.
pub const Table = std.StringArrayHashMapUnmanaged([:0]const u8);

const DefaultMaps = @This();

/// The map that each FX uses when none is chosen, for each module. Because an FX can have several maps, and the user picks one
/// of them as the one to start from, the choice is saved in a file of its own, which a reinstall of the factory maps leaves alone.
tables: std.EnumArray(ModulesList, Table) = .initFill(.empty),

pub const empty: DefaultMaps = .{};

/// The name of the map that is the default of an FX, or null when the user has not picked one.
pub fn get(self: *const DefaultMaps, module: ModulesList, fx_name: []const u8) ?[:0]const u8 {
    return self.tables.getPtrConst(module).get(fx_name);
}

/// Makes a map the default of an FX. Because the file has one `name = map` line for each FX, a name that holds an equal sign
/// cannot be written back, so it is refused.
pub fn set(self: *DefaultMaps, allocator: std.mem.Allocator, module: ModulesList, fx_name: []const u8, map_name: []const u8) !void {
    if (fx_name.len == 0 or map_name.len == 0) return error.EmptyName;
    if (std.mem.indexOfScalar(u8, fx_name, '=') != null) return error.UnsupportedName;

    const value = try allocator.dupeSentinel(u8, map_name, 0);
    const table = self.tables.getPtr(module);
    if (table.getPtr(fx_name)) |existing| {
        existing.* = value;
        return;
    }
    try table.put(allocator, try allocator.dupe(u8, fx_name), value);
}

/// Reads the default maps from the folder `dir`. Because a missing file only means that nothing was picked yet, it is not an error.
pub fn load(self: *DefaultMaps, allocator: std.mem.Allocator, io: std.Io, dir: []const u8) void {
    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const path = fs_helpers.joinStrings(&path_buffer, &.{ dir, std.fs.path.sep_str, file_name });
    const file = std.Io.Dir.openFileAbsolute(io, path, .{}) catch return;
    defer file.close(io);

    var temp_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer temp_arena.deinit();
    var file_buffer: [4096]u8 = undefined;
    var file_reader = file.reader(io, &file_buffer);
    var parser = ini.parse(temp_arena.allocator(), &file_reader.interface, ";#");

    var module: ?ModulesList = null;
    while (parser.next() catch |err| {
        log.warn("Failed to read {s}: {s}", .{ file_name, @errorName(err) });
        return;
    }) |record| {
        switch (record) {
            .section => |heading| module = std.meta.stringToEnum(ModulesList, heading),
            .property => |kv| if (module) |m| {
                self.set(allocator, m, kv.key, kv.value) catch |err| {
                    log.warn("Skipped the default map of {s}: {s}", .{ kv.key, @errorName(err) });
                };
            },
            .enumeration => {},
        }
    }
}

/// Writes the default maps in the folder `dir`, over the file that was there.
pub fn save(self: *const DefaultMaps, io: std.Io, dir: []const u8) !void {
    var path_buffer: [std.fs.max_path_bytes]u8 = undefined;
    const path = fs_helpers.joinStrings(&path_buffer, &.{ dir, std.fs.path.sep_str, file_name });
    const file = try std.Io.Dir.createFileAbsolute(io, path, .{ .truncate = true });
    defer file.close(io);

    // Because file writers are buffered, the writer is flushed before the file closes.
    var writer_buffer: [4096]u8 = undefined;
    var file_writer = file.writer(io, &writer_buffer);
    const writer = &file_writer.interface;

    try writer.writeAll("; Console1 default maps: the map that a plugin uses when none is chosen.\n");
    inline for (comptime std.enums.values(ModulesList)) |module| {
        const table = self.tables.getPtrConst(module);
        if (table.count() > 0) {
            try writer.print("\n[{s}]\n", .{@tagName(module)});
            for (table.keys(), table.values()) |fx_name, map_name| {
                try writer.print("{s} = {s}\n", .{ fx_name, map_name });
            }
        }
    }
    try writer.flush();
}

pub fn deinit(self: *DefaultMaps, allocator: std.mem.Allocator) void {
    for (&self.tables.values) |*table| table.deinit(allocator);
}

test "the default maps are saved and read back, and a new choice replaces the old one" {
    const testing = std.testing;
    const io = testing.io;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir = path_buf[0..try tmp_dir.dir.realPathFile(io, ".", &path_buf)];

    var maps: DefaultMaps = .empty;
    try maps.set(allocator, .COMP, "VST: ReaComp (Cockos)", "punchy");
    try maps.set(allocator, .OUTPT, "JS: Saturation", "test_output_saturation");
    try maps.set(allocator, .COMP, "VST: ReaComp (Cockos)", "gentle");
    try maps.save(io, dir);

    var loaded: DefaultMaps = .empty;
    loaded.load(allocator, io, dir);
    try testing.expectEqualStrings("gentle", loaded.get(.COMP, "VST: ReaComp (Cockos)").?);
    try testing.expectEqualStrings("test_output_saturation", loaded.get(.OUTPT, "JS: Saturation").?);
    // Because the choice is made for one module, the same name in another module has none.
    try testing.expect(loaded.get(.EQ, "VST: ReaComp (Cockos)") == null);

    try testing.expectError(error.UnsupportedName, maps.set(allocator, .COMP, "a=b", "x"));
    try testing.expectError(error.EmptyName, maps.set(allocator, .COMP, "x", ""));
}

test "a folder without the file has no default maps" {
    const testing = std.testing;
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir = path_buf[0..try tmp_dir.dir.realPathFile(testing.io, ".", &path_buf)];

    var loaded: DefaultMaps = .empty;
    loaded.load(testing.allocator, testing.io, dir);
    try testing.expect(loaded.get(.COMP, "anything") == null);
}
