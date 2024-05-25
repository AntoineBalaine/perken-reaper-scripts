// zig build-lib -dynamic -O ReleaseFast -femit-bin=reaper_zig.so hello_world.zig

const std = @import("std");
const ImGui = @import("reaper_imgui.zig");

pub const HINSTANCE = *opaque {};
pub const HWND = *opaque {};
pub const KbdSectionInfo = opaque {};
pub const MediaTrack = *opaque {};
const reaper = struct { // @import("reaper");
    pub const PLUGIN_VERSION = 0x20E;

    pub const plugin_info_t = extern struct {
        caller_version: c_int,
        hwnd_main: HWND,
        register: ?@TypeOf(plugin_register),
        getFunc: ?@TypeOf(plugin_getapi),
    };

    pub const custom_action_register_t = extern struct {
        section: c_int,
        id_str: [*:0]const u8,
        name: [*:0]const u8,
        extra: ?*anyopaque = null,
    };

    pub fn init(rec: *plugin_info_t) bool {
        if (rec.caller_version != PLUGIN_VERSION) {
            std.debug.print("expected REAPER API version {x}, got {x}\n", .{ PLUGIN_VERSION, rec.caller_version });
            return false;
        }

        const getFunc = rec.getFunc.?;
        inline for (@typeInfo(@This()).Struct.decls) |decl| {
            comptime var decl_type = @typeInfo(@TypeOf(@field(@This(), decl.name)));
            const is_optional = decl_type == .Optional;
            if (is_optional)
                decl_type = @typeInfo(decl_type.Optional.child);
            if (decl_type != .Pointer or @typeInfo(decl_type.Pointer.child) != .Fn)
                continue;
            if (getFunc(decl.name)) |func|
                @field(@This(), decl.name) = @ptrCast(func)
            else if (is_optional)
                @field(@This(), decl.name) = null
            else {
                std.debug.print("unable to import the API function '{s}'\n", .{decl.name});
                return false;
            }
        }

        return true;
    }

    pub var plugin_register: *fn (name: [*:0]const u8, infostruct: *anyopaque) callconv(.C) c_int = undefined;
    pub var plugin_getapi: *fn (name: [*:0]const u8) callconv(.C) ?*anyopaque = undefined;
    pub var ShowMessageBox: *fn (body: [*:0]const u8, title: [*:0]const u8, flags: c_int) callconv(.C) void = undefined;
    pub var ShowConsoleMsg: *fn (str: [*:0]const u8) callconv(.C) void = undefined;
};

const plugin_name = "Hello, Zig!";
var action_id: c_int = undefined;
var ctx: ImGui.ContextPtr = null;
var click_count: u32 = 0;
var text = std.mem.zeroes([255:0]u8);

fn loop() !void {
    if (ctx == null) {
        try ImGui.init(reaper.plugin_getapi);
        ctx = try ImGui.CreateContext(.{plugin_name});
    }

    try ImGui.SetNextWindowSize(.{ ctx, 400, 80, ImGui.Cond_FirstUseEver });

    var open: bool = true;
    if (try ImGui.Begin(.{ ctx, plugin_name, &open })) {
        if (try ImGui.Button(.{ ctx, "Click me!" }))
            click_count +%= 1;

        if (click_count & 1 != 0) {
            try ImGui.SameLine(.{ctx});
            try ImGui.Text(.{ ctx, "\\o/" });
        }

        _ = try ImGui.InputText(.{ ctx, "text input", &text, text.len });
        try ImGui.End(.{ctx});
    }

    if (!open)
        reset();
}

fn init() void {
    _ = reaper.plugin_register("timer", @constCast(@ptrCast(&onTimer)));
}

fn reset() void {
    _ = reaper.plugin_register("-timer", @constCast(@ptrCast(&onTimer)));
    ctx = null;
}

fn onTimer() callconv(.C) void {
    loop() catch {
        reset();
        reaper.ShowMessageBox(ImGui.last_error.?, plugin_name, 0);
    };
}

fn onCommand(sec: *KbdSectionInfo, command: c_int, val: c_int, val2hw: c_int, relmode: c_int, hwnd: HWND) callconv(.C) c_char {
    _ = .{ sec, val, val2hw, relmode, hwnd };

    if (command == action_id) {
        if (ctx == null) init() else reset();
        return 1;
    }

    return 0;
}
// to implement the csurf interface, you'd probably want to do that from C++ instead of Zig to not have to deal with ABI headaches...
// eg. the C++ csurf implementation just forwarding the calls to extern "C" functions implemented in Zig
const IReaperControlSurface = extern struct {
    pub fn GetTypeString(self: *IReaperControlSurface) callconv(.C) [*:0]const u8 {
        _ = self;
        reaper.ShowConsoleMsg("GetTypeString", .{});
        return "TypeString";
    }

    pub fn GetDescString(self: *IReaperControlSurface) callconv(.C) [*:0]const u8 {
        _ = self;
        reaper.ShowConsoleMsg("GetDescString", .{});
        return "DescString";
    }

    pub fn GetConfigString(self: *IReaperControlSurface) callconv(.C) [*:0]const u8 {
        _ = self;
        reaper.ShowConsoleMsg("GetConfigString", .{});
        return "ConfigString";
    }

    pub fn CloseNoReset(self: *IReaperControlSurface) callconv(.C) void {
        _ = self;
        reaper.ShowConsoleMsg("CloseNoReset", .{});
    }

    pub fn Run(self: *IReaperControlSurface) callconv(.C) void {
        _ = self;
        reaper.ShowConsoleMsg("Run", .{});
    }

    pub fn SetTrackListChange(self: *IReaperControlSurface) callconv(.C) void {
        _ = self;
        reaper.ShowConsoleMsg("SetTrackListChange", .{});
    }

    pub fn SetSurfaceVolume(self: *IReaperControlSurface, trackid: *MediaTrack, volume: f64) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = volume;
        reaper.ShowConsoleMsg("SetSurfaceVolume", .{});
    }

    pub fn SetSurfacePan(self: *IReaperControlSurface, trackid: *MediaTrack, pan: f64) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = pan;
        reaper.ShowConsoleMsg("SetSurfacePan", .{});
    }

    pub fn SetSurfaceMute(self: *IReaperControlSurface, trackid: *MediaTrack, mute: bool) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = mute;
        reaper.ShowConsoleMsg("SetSurfaceMute", .{});
    }

    pub fn SetSurfaceSelected(self: *IReaperControlSurface, trackid: *MediaTrack, selected: bool) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = selected;
        reaper.ShowConsoleMsg("SetSurfaceSelected", .{});
    }

    pub fn SetSurfaceSolo(self: *IReaperControlSurface, trackid: *MediaTrack, solo: bool) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = solo;
        reaper.ShowConsoleMsg("SetSurfaceSolo", .{});
    }

    pub fn SetSurfaceRecArm(self: *IReaperControlSurface, trackid: *MediaTrack, recarm: bool) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = recarm;
        reaper.ShowConsoleMsg("SetSurfaceRecArm", .{});
    }

    pub fn SetPlayState(self: *IReaperControlSurface, play: bool, pause: bool, rec: bool) callconv(.C) void {
        _ = self;
        _ = play;
        _ = pause;
        _ = rec;
        reaper.ShowConsoleMsg("SetPlayState", .{});
    }

    pub fn SetRepeatState(self: *IReaperControlSurface, rep: bool) callconv(.C) void {
        _ = self;
        _ = rep;
        reaper.ShowConsoleMsg("SetRepeatState", .{});
    }

    pub fn SetTrackTitle(self: *IReaperControlSurface, trackid: *MediaTrack, title: [*:0]const u8) callconv(.C) void {
        _ = self;
        _ = trackid;
        _ = title;
        reaper.ShowConsoleMsg("SetTrackTitle", .{});
    }

    pub fn GetTouchState(self: *IReaperControlSurface, trackid: *MediaTrack, isPan: c_int) callconv(.C) bool {
        _ = self;
        _ = trackid;
        _ = isPan;
        reaper.ShowConsoleMsg("GetTouchState", .{});
        return false;
    }

    pub fn SetAutoMode(self: *IReaperControlSurface, mode: c_int) callconv(.C) void {
        _ = self;
        _ = mode;
        reaper.ShowConsoleMsg("SetAutoMode", .{});
    }

    pub fn ResetCachedVolPanStates(self: *IReaperControlSurface) callconv(.C) void {
        _ = self;
        reaper.ShowConsoleMsg("ResetCachedVolPanStates", .{});
    }

    pub fn OnTrackSelection(self: *IReaperControlSurface, trackid: *MediaTrack) callconv(.C) void {
        _ = self;
        _ = trackid;
        reaper.ShowConsoleMsg("OnTrackSelection", .{});
    }

    pub fn IsKeyDown(self: *IReaperControlSurface, key: c_int) callconv(.C) bool {
        _ = self;
        _ = key;
        reaper.ShowConsoleMsg("IsKeyDown", .{});
        return false;
    }

    pub fn Extended(self: *IReaperControlSurface, call: c_int, parm1: ?*void, parm2: ?*void, parm3: ?*void) callconv(.C) c_int {
        _ = self;
        _ = call;
        _ = parm1;
        _ = parm2;
        _ = parm3;
        reaper.ShowConsoleMsg("Extended", .{});
        return 0;
    }
};

export fn ReaperPluginEntry(instance: HINSTANCE, rec: ?*reaper.plugin_info_t) c_int {
    _ = instance;

    if (rec == null)
        return 0 // cleanup here
    else if (!reaper.init(rec.?))
        return 0;

    const action = reaper.custom_action_register_t{ .section = 0, .id_str = "REAIMGUI_ZIG", .name = "ReaImGui Zig example" };
    action_id = reaper.plugin_register("custom_action", @constCast(@ptrCast(&action)));
    _ = reaper.plugin_register("hookcommand2", @constCast(@ptrCast(&onCommand)));
    // reaper.ShowConsoleMsg("Hello, Zig!\n");

    // Define the opaque struct to represent IReaperControlSurface
    const surfaceHandle: *anyopaque = @constCast(&IReaperControlSurface);
    _ = reaper.plugin_register("csurf_inst", surfaceHandle);
    return 1;
}
