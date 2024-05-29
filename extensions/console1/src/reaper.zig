const std = @import("std");

pub const reaper = struct { // @import("reaper");
    pub const HINSTANCE = *opaque {};
    pub const HWND = *opaque {};
    pub const KbdSectionInfo = opaque {};
    pub const MediaTrack = *opaque {};
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
