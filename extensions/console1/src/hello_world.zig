// zig build-lib -O ReleaseSmall hello_world.zig -dynamic -femit-bin=reaper_zig.so

const REAPER_PLUGIN_VERSION = 0x20E;

var KbdSectionInfo = anyopaque;
var HWND = anyopaque;

var reaper: struct {
    plugin_register: *fn (name: *const c_char, infostruct: *anyopaque) callconv(.C) c_int,
    plugin_getapi: *fn (name: [*c]const u8) callconv(.C) ?*anyopaque,
    ShowConsoleMsg: *fn (str: [*c]const u8) callconv(.C) void,
} = undefined;
var ImGui: struct {} = undefined;

const reaper_plugin_info_t = extern struct {
    caller_version: c_int,
    hwnd_main: *anyopaque,
    register: ?@TypeOf(reaper.plugin_register),
    getFunc: ?@TypeOf(reaper.plugin_getapi),
};

const HINSTANCE = *anyopaque;

export fn ReaperPluginEntry(instance: HINSTANCE, rec: ?*reaper_plugin_info_t) c_int {
    _ = instance;

    if (rec == null) {
        return 0; // cleanup here
    } else if (rec.?.caller_version != REAPER_PLUGIN_VERSION) {
        return 0;
    }

    reaper.ShowConsoleMsg = @ptrCast(rec.?.getFunc.?("ShowConsoleMsg") orelse return 0);
    reaper.ShowConsoleMsg("Hello, Zig!\n");

    return 1;
}
