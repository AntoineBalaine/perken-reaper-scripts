//! Minimal pure-Zig SWELL modstub (Linux/macOS). On load, REAPER looks for an
//! exported SWELL_dllMain and passes it a GetFunc resolver for the SWELL API
//! (same mechanism WDL's swell-modstub-generic.cpp uses — see its SWELL_dllMain).
//! We resolve only the window functions the vim engine needs. On Windows these
//! would be native win32 calls; that platform is wired up when needed.
const std = @import("std");
const Reaper = @import("reaper").reaper;

const log = std.log.scoped(.swell);

const HWND = Reaper.HWND;
const GetFuncT = *const fn (name: [*:0]const u8) callconv(.C) ?*anyopaque;

// Signatures from WDL/swell/swell-functions.h
var fnGetFocus: ?*const fn () callconv(.C) ?HWND = null;
var fnGetParent: ?*const fn (hwnd: HWND) callconv(.C) ?HWND = null;
var fnIsChild: ?*const fn (parent: HWND, child: HWND) callconv(.C) c_int = null;
var fnGetClassName: ?*const fn (hwnd: HWND, buf: [*]u8, bufsz: c_int) callconv(.C) c_int = null;

const DLL_PROCESS_ATTACH: c_uint = 1;

export fn SWELL_dllMain(hInst: ?*anyopaque, callMode: c_uint, getFunc: ?*anyopaque) callconv(.C) c_int {
    _ = hInst;
    if (callMode == DLL_PROCESS_ATTACH) {
        if (getFunc == null) return 0;
        const gf: GetFuncT = @ptrCast(@alignCast(getFunc));
        fnGetFocus = @ptrCast(@alignCast(gf("GetFocus") orelse null));
        fnGetParent = @ptrCast(@alignCast(gf("GetParent") orelse null));
        fnIsChild = @ptrCast(@alignCast(gf("IsChild") orelse null));
        fnGetClassName = @ptrCast(@alignCast(gf("GetClassName") orelse null));
        if (fnGetFocus == null or fnGetParent == null or fnIsChild == null or fnGetClassName == null)
            log.warn("some SWELL window functions failed to resolve", .{});
    }
    return 1; // allows DllMain to be called, if available
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
