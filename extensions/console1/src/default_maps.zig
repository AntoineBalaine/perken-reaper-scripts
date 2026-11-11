const std = @import("std");
const ini = @import("ini");
const fs_helpers = @import("fs_helpers");
const ModulesList = @import("statemachine.zig").ModulesList;
const MappingsList = @import("mappings_list.zig");
const log = std.log.scoped(.default_maps);

/// The file that holds the default maps, next to the preferences. Because an FX can have several maps, and the user picks one of
/// them as the one to start from, the choice is kept in a file of its own, which a reinstall of the factory maps leaves alone.
/// While the extension runs, the choice is the `is_default` flag of the entries of the maps list.
pub const file_name = "default_maps.ini";

/// Flags the maps that the file names as the defaults of their FX. Because a missing file only means that nothing was picked yet,
/// it is not an error, and a line that names an FX or a map that is not in the list anymore is skipped.
pub fn load(ml: *MappingsList, io: std.Io, dir: []const u8) void {
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
                ml.setDefault(m, kv.key, kv.value) catch |err| {
                    log.warn("Skipped the default map {s} of {s}: {s}", .{ kv.value, kv.key, @errorName(err) });
                };
            },
            .enumeration => {},
        }
    }
}

/// Writes the maps that are flagged as the defaults in the folder `dir`, over the file that was there. Because the file has one
/// `FX = map` line for each FX, an FX name that holds an equal sign cannot be read back, and `MapStore.setDefaultMap` refuses it.
pub fn save(ml: *MappingsList, io: std.Io, dir: []const u8) !void {
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
        var header_written = false;
        var iter = ml.list.getPtr(module).iterator();
        while (iter.next()) |fx| {
            for (fx.value_ptr.items) |entry| {
                if (!entry.is_default) continue;
                if (!header_written) {
                    try writer.print("\n[{s}]\n", .{@tagName(module)});
                    header_written = true;
                }
                try writer.print("{s} = {s}\n", .{ ml.strings.get(fx.key_ptr.*), ml.strings.get(entry.name_offset) });
                // Because two files can have the same name, the name of the map is written once for each FX.
                break;
            }
        }
    }
    try writer.flush();
}

test "the default maps are saved and read back into the flags of a new list" {
    const testing = std.testing;
    const io = testing.io;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir = path_buf[0..try tmp_dir.dir.realPathFile(io, ".", &path_buf)];

    var ml = MappingsList.empty(allocator);
    try ml.registerPath(.COMP, "VST: ReaComp (Cockos)", "default", "/maps/default.ini");
    try ml.registerPath(.COMP, "VST: ReaComp (Cockos)", "punchy", "/maps/punchy.ini");
    try ml.registerPath(.OUTPT, "JS: Saturation", "default", "/maps/sat_default.ini");
    try ml.registerPath(.OUTPT, "JS: Saturation", "test_output_saturation", "/maps/sat_test.ini");
    try testing.expectEqual(@as(?[:0]const u8, null), ml.defaultMapName(.COMP, "VST: ReaComp (Cockos)"));

    // Because a new choice replaces the old one, only one map of an FX is the default.
    try ml.setDefault(.COMP, "VST: ReaComp (Cockos)", "default");
    try ml.setDefault(.COMP, "VST: ReaComp (Cockos)", "punchy");
    try ml.setDefault(.OUTPT, "JS: Saturation", "test_output_saturation");
    try testing.expectEqualStrings("punchy", ml.defaultMapName(.COMP, "VST: ReaComp (Cockos)").?);
    try testing.expect(!ml.findFx(.COMP, "VST: ReaComp (Cockos)").?.maps[0].is_default);
    try save(&ml, io, dir);

    var reloaded = MappingsList.empty(allocator);
    try reloaded.registerPath(.COMP, "VST: ReaComp (Cockos)", "default", "/maps/default.ini");
    try reloaded.registerPath(.COMP, "VST: ReaComp (Cockos)", "punchy", "/maps/punchy.ini");
    try reloaded.registerPath(.OUTPT, "JS: Saturation", "default", "/maps/sat_default.ini");
    try reloaded.registerPath(.OUTPT, "JS: Saturation", "test_output_saturation", "/maps/sat_test.ini");
    load(&reloaded, io, dir);
    try testing.expectEqualStrings("punchy", reloaded.defaultMapName(.COMP, "VST: ReaComp (Cockos)").?);
    try testing.expectEqualStrings("test_output_saturation", reloaded.defaultMapName(.OUTPT, "JS: Saturation").?);
    // Because the choice is made for one module, the same name in another module has none.
    try testing.expectEqual(@as(?[:0]const u8, null), reloaded.defaultMapName(.EQ, "VST: ReaComp (Cockos)"));

    // A map or an FX that the list does not have is refused.
    try testing.expectError(error.MappingNotFound, ml.setDefault(.COMP, "VST: ReaComp (Cockos)", "missing"));
    try testing.expectError(error.FxNotFound, ml.setDefault(.COMP, "VST: Missing", "default"));
}

test "a folder without the file has no default maps" {
    const testing = std.testing;
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const dir = path_buf[0..try tmp_dir.dir.realPathFile(testing.io, ".", &path_buf)];

    var ml = MappingsList.empty(arena.allocator());
    try ml.registerPath(.COMP, "VST: ReaComp (Cockos)", "default", "/maps/default.ini");
    load(&ml, testing.io, dir);
    try testing.expectEqual(@as(?[:0]const u8, null), ml.defaultMapName(.COMP, "VST: ReaComp (Cockos)"));
}
