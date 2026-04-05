const std = @import("std");
const Reaper = @import("reaper").reaper;

export fn ReaperPluginEntry(instance: Reaper.HINSTANCE, rec: ?*Reaper.plugin_info_t) c_int {
    _ = instance;

    if (rec == null)
        return 0; // cleanup

    if (!Reaper.init(rec.?))
        return 0;

    Reaper.ShowConsoleMsg("Hello from reaziglib!\n");

    return 1;
}
