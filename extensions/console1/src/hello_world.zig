// zig build-lib -dynamic -O ReleaseFast -femit-bin=reaper_zig.so hello_world.zig

const std = @import("std");
const ImGui = @import("reaper_imgui.zig");
const Reaper = @import("reaper.zig");
const reaper = Reaper.reaper;
const control_surface = @import("csurf/control_surface.zig");
const Allocator = std.mem.Allocator;
const ControllerConfig = @import("internals/ControllerConfigLoader.zig");
const appInit = @import("internals/init.zig");

const plugin_name = "Hello, Zig!";
var action_id: c_int = undefined;
var init_action_id: c_int = undefined;
var actionIds: std.ArrayList(c_int) = undefined;

var ctx: ImGui.ContextPtr = null;
var click_count: u32 = 0;
var text = std.mem.zeroes([255:0]u8);

var gpa_int = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_int.allocator();

fn onCommand(sec: *reaper.KbdSectionInfo, command: c_int, val: c_int, val2hw: c_int, relmode: c_int, hwnd: reaper.HWND) callconv(.C) c_char {
    _ = .{ sec, val, val2hw, relmode, hwnd };
    std.debug.print("{any}\n", .{init_action_id});

    if (command == init_action_id) {
        appInit.init(gpa) catch |err| {
            switch (err) {
                appInit.InitError.RealearnNotInstalled => {
                    _ = reaper.MB("Realearn not found. Please install realearn using reapack", "Error", 0);
                    return 0;
                },
                else => {
                    return 0;
                },
            }
        };
        return 1;
    }

    return 0;
}
// to implement the csurf interface, you'd probably want to do that from C++ instead of Zig to not have to deal with ABI headaches...
// eg. the C++ csurf implementation just forwarding the calls to extern "C" functions implemented in Zig

export fn ReaperPluginEntry(instance: reaper.HINSTANCE, rec: ?*reaper.plugin_info_t) c_int {
    _ = instance;

    if (rec == null) {
        return 0; // cleanup here
    } else if (!reaper.init(rec.?)) {
        return 0;
    }

    reaper.ShowConsoleMsg("Hello, Zig!\n");
    // Define the opaque struct to represent IReaperControlSurface
    const myCsurf = control_surface.init();
    if (myCsurf == null) {
        std.debug.print("Failed to create fake csurf\n", .{});
        return 0;
    }
    appInit.init(gpa) catch |err| {
        switch (err) {
            appInit.InitError.RealearnNotInstalled => {
                std.debug.print("Realearn not found. Please install realearn using reapack", .{});
            },
            else => {
                std.debug.print("other err\n", .{});
            },
        }
    };
    std.debug.print("registering\n", .{});
    _ = reaper.plugin_register("csurf_inst", myCsurf.?);

    const action = reaper.custom_action_register_t{ .section = 0, .id_str = "REAIMGUI_ZIG", .name = "ReaImGui Zig example" };
    action_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&action)));
    _ = reaper.plugin_register("hookcommand2", @constCast(@ptrCast(&onCommand)));

    return 1;
}

test {
    std.testing.refAllDecls(@This());
}
