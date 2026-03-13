const imgui = @import("reaper_imgui.zig");

/// Called by the host after loading/reloading the dylib so that the UI lib
/// can resolve all ImGui function pointers.
export fn ui_init(plugin_getapi_opaque: *anyopaque) callconv(.C) bool {
    const plugin_getapi: *fn ([*:0]const u8) callconv(.C) ?*anyopaque = @ptrCast(@alignCast(plugin_getapi_opaque));
    imgui.init(plugin_getapi) catch return false;
    return true;
}

/// Called by the host each frame. Renders a dummy UI to prove the mechanism.
/// Returns true if the window is still open, false if the user closed it.
export fn ui_render(ctx: imgui.ContextPtr, win_flags: c_int) callconv(.C) bool {
    _ = imgui.Begin(.{ ctx, "Hot-Reload POC", null, win_flags }) catch return false;
    defer imgui.End(.{ctx}) catch {};

    imgui.Text(.{ ctx, "This UI is rendered from a hot-reloaded dylib." }) catch {};
    imgui.Text(.{ ctx, "Edit ui_lib.zig, rebuild with 'zig build ui', and it updates live." }) catch {};

    return true;
}
