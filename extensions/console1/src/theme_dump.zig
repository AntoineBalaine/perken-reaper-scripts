const std = @import("std");
const reaper = @import("reaper.zig").reaper;
const log = std.log.scoped(.theme_dump);

const ColorEntry = struct { [:0]const u8, [:0]const u8 };

const main_colors = [_]ColorEntry{
    .{ "ActiveToggle", "" },
    .{ "Border", "selcol_tr2_bg" },
    .{ "ErrorText", "" },
    .{ "Button", "col_main_bg2" },
    .{ "ButtonActive", "midi_endpt" },
    .{ "ButtonHovered", "col_env5" },
    .{ "CheckMark", "col_seltrack" },
    .{ "DragDropTarget", "col_main_resize2" },
    .{ "FrameBg", "col_main_bg2" },
    .{ "FrameBgActive", "midi_endpt" },
    .{ "FrameBgHovered", "col_env5" },
    .{ "SliderGrab", "col_cursor" },
    .{ "SliderGrabActive", "col_cursor2" },
    .{ "Tab", "arrange_vgrid" },
    .{ "TabActive", "auto_item_unsel" },
    .{ "TabHovered", "genlist_selbg" },
    .{ "TabSelected", "genlist_selfg" },
    .{ "TabSelectedOverline", "genlist_selfg" },
    .{ "Text", "col_seltrack" },
    .{ "WindowBg", "col_main_bg2" },
};

const config_colors = [_]ColorEntry{
    .{ "Button", "genlist_seliabg" },
    .{ "CheckMark", "genlist_selbg" },
    .{ "ChildBg", "genlist_bg" },
    .{ "FrameBg", "genlist_seliabg" },
    .{ "PopupBg", "col_main_bg" },
    .{ "Tab", "genlist_seliabg" },
    .{ "TabHovered", "genlist_selbg" },
    .{ "TabSelected", "genlist_selfg" },
    .{ "TabSelectedOverline", "genlist_selfg" },
    .{ "Text", "genlist_fg" },
    .{ "TitleBg", "col_main_bg" },
    .{ "TitleBgActive", "genlist_bg" },
    .{ "WindowBg", "col_main_bg" },
};

pub fn dumpThemeToFile() void {
    const resource_path = std.mem.span(reaper.GetResourcePath());
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/Data/Perken/Console1/theme.ini", .{resource_path}) catch {
        _ = reaper.ShowMessageBox("Failed to build output path", "Theme Dump", 0);
        return;
    };

    const file = std.fs.createFileAbsolute(path, .{ .truncate = true }) catch {
        _ = reaper.ShowMessageBox("Failed to create theme file", "Theme Dump", 0);
        return;
    };
    defer file.close();

    var writer = file.writer();
    writeSection(&writer, "[config]", &config_colors) catch return;
    writer.writeAll("\n") catch return;
    writeSection(&writer, "[main]", &main_colors) catch return;

    var msg_buf: [512]u8 = undefined;
    const msg = std.fmt.bufPrintZ(&msg_buf, "Theme colors written to:\n{s}", .{path}) catch "Theme colors written.";
    _ = reaper.ShowMessageBox(msg, "Theme Dump", 0);
}

fn writeSection(writer: anytype, header: []const u8, entries: []const ColorEntry) !void {
    try writer.writeAll(header);
    try writer.writeAll("\n");
    for (entries) |entry| {
        const ini_name = entry[0];
        const reaper_name = entry[1];
        if (reaper_name.len == 0) {
            try writer.print("{s} = 00000000\n", .{ini_name});
        } else {
            const col: u32 = @bitCast(reaper.GetThemeColor(@as([*:0]const u8, reaper_name), 0));
            try writer.print("{s} = {X:0>8}\n", .{ ini_name, col });
        }
    }
}
