const std = @import("std");
const Reaper = @import("reaper");
const reaper = Reaper.reaper;
const control_surface = @import("csurf/control_surface_mft.zig");
const defaults_mft = @import("defaults_mft.zig");
const fs_helpers = @import("fs_helpers");
const MftGlobals = @import("mft_globals.zig").MftGlobals;
const mft_imgui = @import("mft_imgui.zig");

pub const std_options = std.Options{
    .log_level = switch (@import("builtin").mode) {
        .Debug => .debug,
        .ReleaseSafe => .info,
        .ReleaseFast => .warn,
        .ReleaseSmall => .err,
    },
};

fn init() !void {
    defaults_mft.ensureConfigPath(fs_helpers.RealFileSystem.fileSystemOps()) catch {};
    MftGlobals.get().init();
}

export fn ReaperPluginEntry(instance: reaper.HINSTANCE, rec: ?*reaper.plugin_info_t) c_int {
    _ = instance;

    if (rec == null or !reaper.init(rec.?)) {
        return 0;
    }

    init() catch {
        return 0;
    };

    _ = reaper.plugin_register("csurf", @ptrCast(@constCast(&control_surface.mft_reg)));

    mft_imgui.register();

    return 1;
}
