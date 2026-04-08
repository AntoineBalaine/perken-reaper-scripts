const std = @import("std");
const Reaper = @import("reaper").reaper;
const imgui = @import("reaper_imgui");

var imgui_available = false;
var ctx: imgui.ContextPtr = null;
var is_open: bool = true;

export fn ReaperPluginEntry(instance: Reaper.HINSTANCE, rec: ?*Reaper.plugin_info_t) c_int {
    _ = instance;

    if (rec == null)
        return 0; // cleanup

    if (!Reaper.init(rec.?))
        return 0;

    // Register the timer unconditionally. ImGui init is deferred to the first
    // timer tick because ReaImGui may not have loaded yet at plugin entry time
    // (REAPER loads plugins alphabetically, and reaper_hello < reaper_imgui).
    _ = Reaper.plugin_register("timer", @constCast(@ptrCast(&onTimer)));

    return 1;
}

fn loadImGui() bool {
    imgui.init(Reaper.plugin_getapi) catch return false;
    return true;
}

fn onTimer() callconv(.C) void {
    if (!imgui_available) {
        imgui_available = loadImGui();
        if (!imgui_available) return;
    }

    if (ctx == null) {
        ctx = imgui.api.CreateContext("reaziglib example", null);
        if (ctx == null) return;
    }

    const visible = imgui.api.Begin(ctx, "Hello reaziglib", &is_open, null);

    if (visible) {
        imgui.api.Text(ctx, "This window is rendered by a reaziglib-based extension.");

        const track_count = Reaper.CountTracks(0);
        var buf: [256]u8 = undefined;
        const label = std.fmt.bufPrintZ(&buf, "Track count: {d}", .{track_count}) catch "?";
        imgui.api.Text(ctx, label);

        if (imgui.api.Button(ctx, "Print to console", null, null)) {
            Reaper.ShowConsoleMsg("Button clicked!\n");
        }
    }

    imgui.api.End(ctx);

    if (!is_open) {
        ctx = null;
        is_open = true;
        _ = Reaper.plugin_register("-timer", @constCast(@ptrCast(&onTimer)));
    }
}

test {
    _ = @import("tests/mock_reaper_test.zig");
    _ = @import("tests/mock_imgui_test.zig");
    _ = @import("tests/flag_constants_test.zig");
}
