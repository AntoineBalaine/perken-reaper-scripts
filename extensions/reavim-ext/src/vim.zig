//! The vim engine: trie-backed key dispatch over the accelerator hook.
//!
//! State between keystrokes is just: mode + trie cursor + pending count +
//! pending-keys display buffer. Modifier state is tracked from the hook
//! traffic itself (the hook is first in queue, so it sees the modifier
//! keydowns/keyups) — the same approach js_ReaScriptAPI uses for VKeys.
//!
//! Normal-mode policy:
//!   - keys in text fields always pass through
//!   - unbound ctrl/alt combos pass through (native Ctrl+S keeps working)
//!   - unbound plain keys are eaten (vim-like; no surprise spacebar playback)
//!   - digits accumulate a count before a sequence starts
//!   - ESC clears the pending sequence / leaves insert mode
const std = @import("std");
const Reaper = @import("reaper").reaper;
const accel = @import("accel.zig");
const swell = @import("swell_win.zig");
const keymod = @import("key.zig");
const config = @import("config.zig");

const log = std.log.scoped(.engine);

pub const Mode = enum { off, normal, insert };
pub const Context = config.Context;

pub var mode: Mode = .off;
var bindings: ?*config.Bindings = null;

const Mods = struct { ctrl: bool = false, shift: bool = false, alt: bool = false };
var mods: Mods = .{};

var cursor: ?config.KeyTrie.Cursor = null;
var active_ctx: Context = .main;
var count: u32 = 0;

// For the feedback UI.
var pending_buf: [128]u8 = undefined;
var pending_len: usize = 0;
var last_action_buf: [128]u8 = undefined;
var last_action_len: usize = 0;

const VK_SHIFT: u8 = 0x10;
const VK_CONTROL: u8 = 0x11;
const VK_MENU: u8 = 0x12;
const VK_ESCAPE: u8 = 0x1b;

pub fn setBindings(b: *config.Bindings) void {
    bindings = b;
    clearPending();
}

pub fn toggle() void {
    mode = if (mode == .off) .normal else .off;
    mods = .{};
    clearPending();
    log.info("vim mode: {s}", .{@tagName(mode)});
}

/// "ReaVim: Enter normal mode" — bindable, works from insert (and as a panic reset).
pub fn enterNormal() void {
    if (mode == .off) return;
    mode = .normal;
    clearPending();
    log.info("mode: normal", .{});
}

pub fn pending() []const u8 {
    return pending_buf[0..pending_len];
}

pub fn lastAction() []const u8 {
    return last_action_buf[0..last_action_len];
}

pub fn pendingCount() u32 {
    return count;
}

pub fn activeContext() Context {
    return active_ctx;
}

pub const Completion = config.KeyTrie.Cursor.Completion;

/// Children of the current trie position (root when no sequence is pending).
pub fn completions(buf: []Completion) []Completion {
    const b = bindings orelse return buf[0..0];
    var c = cursor orelse b.get(active_ctx, .normal).cursor();
    return c.completions(buf);
}

fn clearPending() void {
    cursor = null;
    count = 0;
    pending_len = 0;
}

fn appendPending(k: keymod.Key) void {
    var buf: [16]u8 = undefined;
    const s = keymod.format(k, &buf);
    if (pending_len + s.len <= pending_buf.len) {
        @memcpy(pending_buf[pending_len..][0..s.len], s);
        pending_len += s.len;
    }
}

fn setLastAction(action: config.Action, n: u32) void {
    var dbuf: [96]u8 = undefined;
    const desc = action.describe(&dbuf);
    const s = if (n > 1)
        std.fmt.bufPrint(&last_action_buf, "{d}x {s}", .{ n, desc }) catch return
    else
        std.fmt.bufPrint(&last_action_buf, "{s}", .{desc}) catch return;
    last_action_len = s.len;
}

fn contextOf(msg: *accel.MSG) Context {
    const editor = Reaper.MIDIEditor_GetActive();
    if (@intFromPtr(editor) == 0) return .main;
    const h = msg.hwnd orelse return .main;
    return if (swell.isInWindow(editor, h)) .midi else .main;
}

/// Keys targeting a text field must never be eaten — typing in a track rename
/// box behaves like insert mode regardless of the vim mode.
fn isTextField(msg: *accel.MSG) bool {
    const h = msg.hwnd orelse return false;
    var buf: [64]u8 = undefined;
    const cls = swell.getClassName(h, &buf);
    return std.mem.eql(u8, cls, "Edit") or
        std.ascii.eqlIgnoreCase(cls, "combobox") or
        std.ascii.startsWithIgnoreCase(cls, "richedit");
}

fn execute(action: config.Action, ctx: Context, n: u32) void {
    setLastAction(action, n);
    switch (action) {
        .cmd => |id| dispatchCmd(id, ctx, n),
        .named => |name| {
            const id = Reaper.NamedCommandLookup(name.ptr);
            if (id == 0) {
                log.warn("named command not found: {s}", .{name});
                return;
            }
            dispatchCmd(id, ctx, n);
        },
        .builtin => |b| switch (b) {
            .insert => {
                mode = .insert;
                log.info("mode: insert (native bindings active)", .{});
            },
            .normal => enterNormal(),
            .off => {
                mode = .off;
                log.info("vim mode: off", .{});
            },
            .clear => {},
        },
        .stub => |name| log.warn("action '{s}' not ported yet (stub)", .{name}),
    }
}

fn dispatchCmd(id: c_int, ctx: Context, n: u32) void {
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        switch (ctx) {
            .main => Reaper.Main_OnCommand(id, 0),
            .midi => _ = Reaper.MIDIEditor_LastFocused_OnCommand(id, false),
        }
    }
}

/// Returns the translateAccel return value: 0 = pass through, 1 = eat.
pub fn onKey(msg: *accel.MSG) c_int {
    if (mode == .off) return 0;

    const down = msg.message == accel.WM_KEYDOWN or msg.message == accel.WM_SYSKEYDOWN;
    const up = msg.message == accel.WM_KEYUP or msg.message == accel.WM_SYSKEYUP;
    if (!down and !up) return 0;

    const vk: u8 = @truncate(msg.wParam);
    switch (vk) {
        VK_SHIFT => {
            mods.shift = down;
            return 0;
        },
        VK_CONTROL => {
            mods.ctrl = down;
            return 0;
        },
        VK_MENU => {
            mods.alt = down;
            return 0;
        },
        else => {},
    }

    if (mode == .insert) {
        if (down and vk == VK_ESCAPE and !mods.ctrl and !mods.alt) {
            enterNormal();
            return 1;
        }
        return 0;
    }

    // ---- normal mode ----
    if (isTextField(msg)) return 0;

    const b = bindings orelse return 0;

    const ctx = contextOf(msg);
    if (ctx != active_ctx) {
        clearPending();
        active_ctx = ctx;
    }

    // ESC clears any pending sequence; with nothing pending it passes through.
    if (vk == VK_ESCAPE and !mods.ctrl and !mods.alt) {
        if (cursor != null or count > 0) {
            if (down) clearPending();
            return 1;
        }
        return 0;
    }

    // Key-ups: eat for anything we'd handle on the down, pass otherwise.
    // (Eating ups of eaten downs keeps REAPER from seeing orphan key-ups.)
    if (up) return if (mods.ctrl or mods.alt) 0 else 1;

    // Count accumulation: digits before/within a count, not mid-sequence.
    if (!mods.ctrl and !mods.alt and !mods.shift and cursor == null) {
        if (vk >= '0' and vk <= '9' and !(count == 0 and vk == '0')) {
            count = count *| 10 +| (vk - '0');
            return 1;
        }
    }

    const k = keymod.Key{ .vk = vk, .ctrl = mods.ctrl, .shift = mods.shift, .alt = mods.alt };
    var c = cursor orelse b.get(ctx, .normal).cursor();

    switch (c.step(k)) {
        .nomatch => {
            const had_pending = cursor != null;
            clearPending();
            // Unbound ctrl/alt combos keep their native behavior;
            // unbound plain keys are eaten in normal mode.
            if ((mods.ctrl or mods.alt) and !had_pending) return 0;
            return 1;
        },
        .pending => {
            appendPending(k);
            cursor = c;
            return 1;
        },
        .exact => |action| {
            const n = if (count == 0) 1 else count;
            clearPending();
            execute(action, ctx, n);
            return 1;
        },
        .ambiguous => |a| {
            // A binding and longer sequences both exist: wait for the next key
            // (no timeout yet — ESC executes nothing, this is v1 policy).
            _ = a;
            appendPending(k);
            cursor = c;
            return 1;
        },
    }
}

test {
    _ = @import("config.zig");
}
