const std = @import("std");
const reaper = @import("reaper").reaper;
const c1_theme = @import("theme/c1_theme.zig");
const WindowColors = c1_theme.WindowColors;

pub fn saveThemeToFile(io: std.Io) void {
    const resource_path = std.mem.span(reaper.GetResourcePath());
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/Data/Perken/Console1/theme.ini", .{resource_path}) catch {
        _ = reaper.ShowMessageBox("Failed to build output path", "Theme Save", 0);
        return;
    };

    const file = std.Io.Dir.createFileAbsolute(io, path, .{ .truncate = true }) catch {
        _ = reaper.ShowMessageBox("Failed to create theme file", "Theme Save", 0);
        return;
    };
    defer file.close(io);

    // Because file writers are buffered since Zig 0.15, the writer is flushed before the file closes.
    var writer_buffer: [4096]u8 = undefined;
    var writer_file_writer = file.writer(io, &writer_buffer);
    const writer = &writer_file_writer.interface;
    defer writer.flush() catch {};
    writeWindowColors(writer, "[config]", &c1_theme.theme.config) catch return;
    writer.writeAll("\n") catch return;
    writeWindowColors(writer, "[main]", &c1_theme.theme.main) catch return;

    var msg_buf: [512]u8 = undefined;
    const msg = std.mem.printSentinel(&msg_buf, "Theme saved to:\n{s}", .{path}, 0) catch "Theme saved.";
    _ = reaper.ShowMessageBox(msg, "Theme Save", 0);
}

fn writeWindowColors(writer: anytype, header: []const u8, colors: *const WindowColors) !void {
    try writer.writeAll(header);
    try writer.writeAll("\n");
    inline for (@typeInfo(WindowColors).@"struct".field_names) |field_name| {
        const val: u32 = @bitCast(@field(colors, field_name));
        try writer.print("{s} = {X:0>8}\n", .{ field_name, val });
    }
}
