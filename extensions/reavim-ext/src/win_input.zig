//! Live keyboard modifier state on Windows, via user32's GetKeyState.
//!
//! vim.zig's modifier extraction reads msg.lParam using FSHIFT/FCONTROL/
//! FALT (accel.zig) — bit positions SWELL's own GDK translation layer
//! (swell-generic-gdk.cpp) invents to mimic a win32 ACCEL modifier mask,
//! packed into lParam purely as a SWELL-internal convention. That format has
//! nothing to do with the real Windows WM_KEYDOWN/WM_SYSKEYDOWN lParam
//! layout (repeat count, scan code, extended-key flag, context code,
//! previous-state and transition-state bits) — a real Windows message's
//! lParam happens to have *some* bits at those same positions, but they mean
//! something else entirely, so the SWELL-shaped mask reads noise on native
//! Windows. This is why modifier keys did not work when this codebase's
//! Windows support was first exercised: the read was never wrong on Linux/
//! macOS, it was reading a value that never existed in that shape on
//! Windows to begin with.
//!
//! GetKeyState reflects modifier state as of the last message retrieved
//! from the queue — the right call inside a message handler like this one,
//! as opposed to GetAsyncKeyState's real-time-but-possibly-out-of-step-with-
//! message-order semantics.
const std = @import("std");

const user32 = struct {
    extern "user32" fn GetKeyState(nVirtKey: c_int) callconv(.C) i16;
};

/// True if the given win32 virtual-key code is currently held down.
/// GetKeyState's high bit (0x8000 in the unsigned reading of its return
/// value) signals "down"; the low bit is toggle state (e.g. for caps lock),
/// irrelevant here.
pub fn keyDown(vk: u8) bool {
    const state: u16 = @bitCast(user32.GetKeyState(@intCast(vk)));
    return (state & 0x8000) != 0;
}
