const std = @import("std");

// Swell function pointers resolved at runtime by the swell-modstub.
// These open native OS dialogs (Cocoa on macOS, GTK on Linux).
extern "C" var BrowseForSaveFile: ?*const fn (
    text: [*:0]const u8,
    initialdir: [*:0]const u8,
    initialfile: [*:0]const u8,
    extlist: [*:0]const u8,
    fn_out: [*]u8,
    fn_out_size: c_int,
) callconv(.C) bool;

extern "C" var BrowseForDirectory: ?*const fn (
    text: [*:0]const u8,
    initialdir: [*:0]const u8,
    fn_out: [*]u8,
    fn_out_size: c_int,
) callconv(.C) bool;

pub fn isAvailable() bool {
    return BrowseForSaveFile != null;
}

pub fn browseForSaveFile(
    title: [*:0]const u8,
    initial_dir: [*:0]const u8,
    initial_file: [*:0]const u8,
    ext_filter: [*:0]const u8,
    buf: *[std.fs.max_path_bytes]u8,
) ?[]const u8 {
    const browse_fn = BrowseForSaveFile orelse return null;
    if (browse_fn(title, initial_dir, initial_file, ext_filter, buf, @intCast(buf.len))) {
        return std.mem.sliceTo(buf, 0);
    }
    return null;
}
