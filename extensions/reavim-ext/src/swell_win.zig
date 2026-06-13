//! Minimal pure-Zig SWELL modstub (Linux/macOS). On load, REAPER looks for an
//! exported SWELL_dllMain and passes it a GetFunc resolver for the SWELL API
//! (same mechanism WDL's swell-modstub-generic.cpp uses — see its SWELL_dllMain).
//! We resolve only the window functions the vim engine needs. On Windows these
//! would be native win32 calls; that platform is wired up when needed.
const std = @import("std");
const builtin = @import("builtin");
const Reaper = @import("reaper").reaper;

const log = std.log.scoped(.swell);

const HWND = Reaper.HWND;
// Nullable name: the macOS version handshake is GetFunc(NULL) == 0x100.
const GetFuncT = *const fn (name: ?[*:0]const u8) callconv(.C) ?*anyopaque;

// Signatures from WDL/swell/swell-functions.h
var fnGetFocus: ?*const fn () callconv(.C) ?HWND = null;
var fnGetParent: ?*const fn (hwnd: HWND) callconv(.C) ?HWND = null;
var fnIsChild: ?*const fn (parent: HWND, child: HWND) callconv(.C) c_int = null;
var fnGetClassName: ?*const fn (hwnd: HWND, buf: [*]u8, bufsz: c_int) callconv(.C) c_int = null;

const DLL_PROCESS_ATTACH: c_uint = 1;

export fn SWELL_dllMain(hInst: ?*anyopaque, callMode: c_uint, getFunc: ?*anyopaque) callconv(.C) c_int {
    _ = hInst;
    if (callMode == DLL_PROCESS_ATTACH) {
        // The third parameter is the SWELL resolver on Linux only. On macOS
        // the host passes NULL and the resolver comes from the app delegate
        // (WDL swell-modstub.mm). Never return 0 here — that makes REAPER
        // abandon the plugin without ever calling ReaperPluginEntry.
        const gf: ?GetFuncT = if (getFunc) |g|
            @as(GetFuncT, @ptrCast(@alignCast(g)))
        else
            macosHostGetFunc();
        if (gf) |g| {
            fnGetFocus = @ptrCast(@alignCast(g("GetFocus") orelse null));
            fnGetParent = @ptrCast(@alignCast(g("GetParent") orelse null));
            fnIsChild = @ptrCast(@alignCast(g("IsChild") orelse null));
            fnGetClassName = @ptrCast(@alignCast(g("GetClassName") orelse null));
        }
        if (fnGetFocus == null or fnGetParent == null or fnIsChild == null or fnGetClassName == null)
            log.warn("some SWELL window functions failed to resolve", .{});
    }
    return 1; // allows DllMain to be called, if available
}

/// macOS: [[NSApp delegate] swellGetAPPAPIFunc] returns the SWELL resolver;
/// resolver(NULL) == 0x100 is the API version handshake. The objc runtime is
/// reached through dlsym so non-macOS builds need no extra link inputs.
fn macosHostGetFunc() ?GetFuncT {
    if (builtin.os.tag != .macos) return null;

    const MsgSend0 = *const fn (?*anyopaque, ?*anyopaque) callconv(.C) ?*anyopaque;
    const MsgSendBool = *const fn (?*anyopaque, ?*anyopaque, ?*anyopaque) callconv(.C) bool;
    const GetClass = *const fn ([*:0]const u8) callconv(.C) ?*anyopaque;
    const SelName = *const fn ([*:0]const u8) callconv(.C) ?*anyopaque;

    // dlsym's pseudo-handle for "search everything" is (void*)-2, not NULL.
    const RTLD_DEFAULT: ?*anyopaque = @ptrFromInt(@as(usize, @bitCast(@as(isize, -2))));
    const objc_getClass: GetClass = @ptrCast(@alignCast(std.c.dlsym(RTLD_DEFAULT, "objc_getClass") orelse return null));
    const sel_registerName: SelName = @ptrCast(@alignCast(std.c.dlsym(RTLD_DEFAULT, "sel_registerName") orelse return null));
    const msg_send_raw = std.c.dlsym(RTLD_DEFAULT, "objc_msgSend") orelse return null;
    const msgSend0: MsgSend0 = @ptrCast(@alignCast(msg_send_raw));
    const msgSendBool: MsgSendBool = @ptrCast(@alignCast(msg_send_raw));

    const nsapp_class = objc_getClass("NSApplication") orelse return null;
    const app = msgSend0(nsapp_class, sel_registerName("sharedApplication")) orelse return null;
    const delegate = msgSend0(app, sel_registerName("delegate")) orelse return null;

    const api_sel = sel_registerName("swellGetAPPAPIFunc");
    if (!msgSendBool(delegate, sel_registerName("respondsToSelector:"), api_sel)) {
        log.warn("host app delegate has no swellGetAPPAPIFunc", .{});
        return null;
    }
    const raw = msgSend0(delegate, api_sel) orelse return null;
    const gf: GetFuncT = @ptrCast(@alignCast(raw));
    if (@intFromPtr(gf(null)) != 0x100) {
        log.warn("SWELL API provider returned unexpected version", .{});
        return null;
    }
    return gf;
}

pub fn available() bool {
    return fnGetFocus != null and fnGetParent != null and fnGetClassName != null;
}

pub fn getFocus() ?HWND {
    const f = fnGetFocus orelse return null;
    return f();
}

pub fn getParent(hwnd: HWND) ?HWND {
    const f = fnGetParent orelse return null;
    return f(hwnd);
}

/// Writes the window's class name into buf, returns it as a slice ("" on failure).
pub fn getClassName(hwnd: HWND, buf: []u8) []const u8 {
    const f = fnGetClassName orelse return "";
    if (buf.len == 0) return "";
    const n = f(hwnd, buf.ptr, @intCast(buf.len));
    if (n <= 0) return "";
    return buf[0..@min(@as(usize, @intCast(n)), buf.len)];
}

/// True if `hwnd` equals `ancestor` or is a descendant of it.
pub fn isInWindow(ancestor: HWND, hwnd: HWND) bool {
    var cur: ?HWND = hwnd;
    var depth: usize = 0;
    while (cur) |c| : (depth += 1) {
        if (c == ancestor) return true;
        if (depth > 32) return false; // cycle guard
        cur = getParent(c);
    }
    return false;
}
