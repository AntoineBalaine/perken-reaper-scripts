//! Development tool: ports the maps of the Console 1 to maps of the MIDI Fighter Twister.
//!
//!     zig build port-maps -- <maps folder of the Console 1> <output folder> [--overwrite] [--only <source>]
//!
//! The maps of the Console 1 are in `<maps folder>/<source>/<MODULE>/<fx folder>/<name>.ini`, where the source is `factory` or the name of a pack. Each
//! one is converted with `mft_port.convert` and written to `<output>/<MODULE>/<fx folder>/<file>.ini`, where MODULE is INPUT, GATE, EQ, COMP, OUTPUT or
//! STRIP, and the file is `default.ini` for the factory maps and `<source>.ini` for those of a pack. Because a map that was ported by hand is better
//! than one that is generated, a file that exists is left as it is unless `--overwrite` is given. The controls that have no place on the
//! controller are printed, so that the table of `mft_port.zig` can be completed. With `--only factory` the maps of the packs are not ported. The factory
//! maps of the repository are installed apart from the binary, by `extensions/install-maps.sh`.
const std = @import("std");
const port = @import("mft_port");

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    var out_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(io, &out_buffer);
    const out = &stdout_writer.interface;
    defer out.flush() catch {};

    var overwrite = false;
    var only: ?[]const u8 = null;
    var folders: [2][]const u8 = undefined;
    var folder_count: usize = 0;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--overwrite")) {
            overwrite = true;
        } else if (std.mem.eql(u8, arg, "--only") and i + 1 < args.len) {
            i += 1;
            only = args[i];
        } else if (folder_count < 2) {
            folders[folder_count] = arg;
            folder_count += 1;
        }
    }
    if (folder_count < 2) {
        try out.print("usage: port-maps <maps folder of the Console 1> <output folder> [--overwrite]\n", .{});
        return;
    }

    var source_root = try std.Io.Dir.cwd().openDir(io, folders[0], .{ .iterate = true });
    defer source_root.close(io);
    try std.Io.Dir.cwd().createDirPath(io, folders[1]);
    var target_root = try std.Io.Dir.cwd().openDir(io, folders[1], .{});
    defer target_root.close(io);

    var written: usize = 0;
    var kept: usize = 0;
    var skipped: usize = 0;
    var walker = try source_root.walk(alloc);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.basename, ".ini")) continue;
        // <source>/<MODULE>/<fx folder>/<name>.ini
        var parts = std.mem.splitScalar(u8, entry.path, std.fs.path.sep);
        const source = parts.next() orelse continue;
        _ = parts.next() orelse continue;
        const fx_dir = parts.next() orelse continue;
        const file_name = parts.next() orelse continue;
        if (parts.next() != null) continue;
        if (only) |wanted| if (!std.mem.eql(u8, source, wanted)) continue;

        const text = try entry.dir.readFileAlloc(io, entry.basename, alloc, .limited(1 << 20));
        defer alloc.free(text);
        var converted = port.convert(alloc, text) catch |err| {
            try out.print("skipped {s}: {s}\n", .{ entry.path, @errorName(err) });
            skipped += 1;
            continue;
        };
        defer converted.deinit(alloc);
        for (converted.unplaced.items) |name| try out.print("no place for {s} in {s}\n", .{ name, entry.path });

        const target_module: []const u8 = if (converted.module) |module| module.dirName() else "STRIP";
        // The name of the file: the map that the store reads is `default.ini`, which is the default map of the factory. A pack names its default map after
        // itself, and its other maps after itself and their own name, so that two maps of a plugin never share a file.
        const stem = file_name[0 .. file_name.len - ".ini".len];
        const is_default = std.mem.eql(u8, stem, "default");
        const is_factory = std.mem.eql(u8, source, "factory");
        const target_file: []const u8 = if (is_factory and is_default)
            "default.ini"
        else if (is_factory)
            try std.fmt.allocPrint(alloc, "{s}.ini", .{stem})
        else if (is_default)
            try std.fmt.allocPrint(alloc, "{s}.ini", .{source})
        else
            try std.fmt.allocPrint(alloc, "{s}-{s}.ini", .{ source, stem });
        defer if (!(is_factory and is_default)) alloc.free(target_file);

        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const sub_path = try std.fmt.bufPrint(&path_buf, "{s}/{s}/{s}", .{ target_module, fx_dir, target_file });
        if (!overwrite) {
            if (target_root.access(io, sub_path, .{})) |_| {
                kept += 1;
                continue;
            } else |_| {}
        }
        var dir_buf: [std.fs.max_path_bytes]u8 = undefined;
        try target_root.createDirPath(io, try std.fmt.bufPrint(&dir_buf, "{s}/{s}", .{ target_module, fx_dir }));
        var aw: std.Io.Writer.Allocating = .init(alloc);
        defer aw.deinit();
        try port.write(&converted, &aw.writer);
        try target_root.writeFile(io, .{ .sub_path = sub_path, .data = aw.written() });
        written += 1;
    }
    try out.print("{d} maps written, {d} kept because they exist, {d} skipped\n", .{ written, kept, skipped });
}
