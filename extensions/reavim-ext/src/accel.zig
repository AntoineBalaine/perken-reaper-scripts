//! SWELL/Win32 keyboard-message types not yet wrapped by reaziglib.
//! Layouts match reaper_plugin.h / swell-types.h.
const Reaper = @import("reaper").reaper;

pub const POINT = extern struct { x: c_int, y: c_int };

pub const MSG = extern struct {
    hwnd: ?Reaper.HWND,
    message: c_uint,
    wParam: usize,
    lParam: isize,
    time: c_uint,
    pt: POINT,
};

/// translateAccel return values (reaper_plugin.h):
///   0    not our window
///   1    eat the keystroke
///  -1    pass it on to the window
///  -666  force to the main window's accel table (except ESC)
///  -667  force to the main window's accel table, even from a text field
pub const accelerator_register_t = extern struct {
    translateAccel: *const fn (msg: *MSG, ctx: *accelerator_register_t) callconv(.c) c_int,
    isLocal: bool,
    user: ?*anyopaque,
};

const std = @import("std");

// SWELL key-message lParam flags (swell-generic-gdk.cpp packs the win32 ACCEL
// modifier mask into lParam): FVIRTKEY distinguishes VK codes from raw ASCII
// punctuation characters, which otherwise collide (e.g. '.' 0x2E == VK_DELETE).
pub const FVIRTKEY: isize = 0x01;
pub const FSHIFT: isize = 0x04;
pub const FCONTROL: isize = 0x08;
pub const FALT: isize = 0x10;
/// On macOS, SWELL reports the physical Control key with this flag, and the
/// Command key as FCONTROL; on Linux it is the Super key.
pub const FLWIN: isize = 0x20;

/// Whether a key message counts as Ctrl-modified. Because SWELL reports
/// Command as FCONTROL and the physical Control key as FLWIN on macOS, a
/// user who types Ctrl+Plus expects the same binding as Cmd+Plus, so both
/// count there. Elsewhere only FCONTROL does, since FLWIN is the Super key.
pub fn ctrlHeld(lparam: isize, os: std.Target.Os.Tag) bool {
    const mask: isize = if (os == .macos) FCONTROL | FLWIN else FCONTROL;
    return (lparam & mask) != 0;
}

test "ctrlHeld counts the physical Control key on macOS only" {
    try std.testing.expect(ctrlHeld(FCONTROL, .macos));
    try std.testing.expect(ctrlHeld(FLWIN, .macos));
    try std.testing.expect(ctrlHeld(FVIRTKEY | FSHIFT | FLWIN, .macos));
    try std.testing.expect(!ctrlHeld(FVIRTKEY | FSHIFT, .macos));
    try std.testing.expect(ctrlHeld(FCONTROL, .linux));
    try std.testing.expect(!ctrlHeld(FLWIN, .linux));
}

pub const WM_KEYDOWN: c_uint = 0x0100;
pub const WM_KEYUP: c_uint = 0x0101;
pub const WM_CHAR: c_uint = 0x0102;
pub const WM_SYSKEYDOWN: c_uint = 0x0104;
pub const WM_SYSKEYUP: c_uint = 0x0105;
pub const WM_SYSCHAR: c_uint = 0x0106;

pub fn msgName(m: c_uint) [:0]const u8 {
    return switch (m) {
        WM_KEYDOWN => "KEYDOWN",
        WM_KEYUP => "KEYUP",
        WM_CHAR => "CHAR",
        WM_SYSKEYDOWN => "SYSKEYDOWN",
        WM_SYSKEYUP => "SYSKEYUP",
        WM_SYSCHAR => "SYSCHAR",
        else => "OTHER",
    };
}
