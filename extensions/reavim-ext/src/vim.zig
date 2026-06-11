//! The vim engine front-end: accumulates keys from the accelerator hook and
//! drives the builder/runner grammar machinery (faithful to reavim's
//! state_machine.lua). State between keystrokes: mode + key buffer.
//!
//! Policy:
//!   - keys in text fields always pass through
//!   - insert mode passes everything except ESC (back to normal)
//!   - unbound ctrl/alt combos at the start of a sequence pass through
//!   - unbound plain keys are eaten (vim-like; no surprise spacebar playback)
//!   - ESC clears a pending sequence; in visual modes it returns to normal;
//!     in normal mode with nothing pending it passes through
const std = @import("std");
const Reaper = @import("reaper").reaper;
const accel = @import("accel.zig");
const swell = @import("swell_win.zig");
const keymod = @import("key.zig");
const grammar = @import("grammar.zig");
const builder = @import("builder.zig");
const runner = @import("runner.zig");
const config = @import("config.zig");
const state = @import("state.zig");

const log = std.log.scoped(.engine);

pub const Mode = state.VimMode;
pub const Context = grammar.Context;
pub const Completion = builder.Completion;

var bindings: ?*config.Bindings = null;

const Mods = struct { ctrl: bool = false, shift: bool = false, alt: bool = false };
var mods: Mods = .{};

var key_buf: [32]keymod.Key = undefined;
var key_len: usize = 0;
var active_ctx: Context = .main;

// For the feedback UI.
var last_action_buf: [128]u8 = undefined;
var last_action_len: usize = 0;

const VK_SHIFT: u8 = 0x10;
const VK_CONTROL: u8 = 0x11;
const VK_MENU: u8 = 0x12;
const VK_ESCAPE: u8 = 0x1b;

pub fn mode() Mode {
    return state.mode;
}

pub fn setBindings(b: *config.Bindings) void {
    bindings = b;
    clearPending();
}

pub fn toggle() void {
    state.mode = if (state.mode == .off) .normal else .off;
    mods = .{};
    clearPending();
    log.info("vim mode: {s}", .{@tagName(state.mode)});
}

pub fn pending(buf: []u8) []const u8 {
    var len: usize = 0;
    for (key_buf[0..key_len]) |k| {
        var kb: [16]u8 = undefined;
        const s = keymod.format(k, &kb);
        if (len + s.len > buf.len) break;
        @memcpy(buf[len..][0..s.len], s);
        len += s.len;
    }
    return buf[0..len];
}

pub fn lastAction() []const u8 {
    return last_action_buf[0..last_action_len];
}

pub fn activeContext() Context {
    return active_ctx;
}

/// Possible next keys given the current buffer (for the feedback window).
pub fn completions(buf: []Completion) []Completion {
    const b = bindings orelse return buf[0..0];
    return builder.completions(&b.tables, active_ctx, state.grammarMode(), key_buf[0..key_len], buf);
}

fn clearPending() void {
    key_len = 0;
}

fn setLastAction(cmd: builder.Command) void {
    var fbs = std.io.fixedBufferStream(&last_action_buf);
    const w = fbs.writer();
    var i: usize = 0;
    while (i < cmd.n()) : (i += 1) {
        if (i > 0) w.writeAll(" + ") catch break;
        const k = cmd.keys[i];
        if (k.prefixed_repetitions > 1) w.print("{d}x ", .{k.prefixed_repetitions}) catch break;
        w.writeAll(k.name) catch break;
    }
    last_action_len = fbs.getWritten().len;
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

/// Returns the translateAccel return value: 0 = pass through, 1 = eat.
pub fn onKey(msg: *accel.MSG) c_int {
    if (state.mode == .off) return 0;

    const down = msg.message == accel.WM_KEYDOWN or msg.message == accel.WM_SYSKEYDOWN;
    const up = msg.message == accel.WM_KEYUP or msg.message == accel.WM_SYSKEYUP;
    if (!down and !up) return 0;

    const vk: u8 = @truncate(msg.wParam);
    if (vk == VK_SHIFT or vk == VK_CONTROL or vk == VK_MENU) return 0;

    // SWELL packs the win32 ACCEL modifier mask into lParam; FVIRTKEY
    // distinguishes virtual-key codes from raw ASCII punctuation chars.
    const virt = (msg.lParam & accel.FVIRTKEY) != 0;
    mods = .{
        .shift = (msg.lParam & accel.FSHIFT) != 0,
        .ctrl = (msg.lParam & accel.FCONTROL) != 0,
        .alt = (msg.lParam & accel.FALT) != 0,
    };

    if (state.mode == .insert) {
        if (down and vk == VK_ESCAPE and !mods.ctrl and !mods.alt) {
            state.setModeToNormal();
            log.info("mode: normal", .{});
            return 1;
        }
        return 0;
    }

    // ---- normal / visual modes ----
    if (isTextField(msg)) return 0;

    const b = bindings orelse return 0;

    const ctx = contextOf(msg);
    if (ctx != active_ctx) {
        clearPending();
        active_ctx = ctx;
    }

    // ESC: clear pending; exit visual modes; pass through otherwise.
    if (vk == VK_ESCAPE and !mods.ctrl and !mods.alt) {
        if (key_len > 0) {
            if (down) clearPending();
            return 1;
        }
        if (state.mode == .visual_track or state.mode == .visual_timeline) {
            if (down) {
                state.setModeToNormal();
                log.info("mode: normal", .{});
            }
            return 1;
        }
        return 0;
    }

    // Key-ups: eat plain ones (their downs were eaten), pass modified ones.
    if (up) return if (mods.ctrl or mods.alt) 0 else 1;

    const k = keymod.Key{
        .vk = vk,
        .ctrl = mods.ctrl,
        // ASCII char keys arrive pre-shifted ('?' is 0x3F); shift is meaningless there.
        .shift = if (virt) mods.shift else false,
        .alt = mods.alt,
        .is_char = !virt and vk != keymod.VK.SPACE,
    };
    if (key_len >= key_buf.len) clearPending();
    key_buf[key_len] = k;
    key_len += 1;

    const gmode = state.grammarMode();

    if (builder.build(&b.tables, ctx, gmode, key_buf[0..key_len])) |cmd| {
        setLastAction(cmd);
        clearPending();
        Reaper.Undo_BeginBlock();
        runner.execute(cmd, ctx);
        Reaper.Undo_EndBlock("reavim", 1);
        Reaper.UpdateArrange();
        return 1;
    }

    var comp_buf: [8]Completion = undefined;
    if (builder.completions(&b.tables, ctx, gmode, key_buf[0..key_len], &comp_buf).len > 0) {
        return 1; // pending — wait for more keys
    }

    // Undefined sequence.
    const was_start = key_len == 1;
    clearPending();
    if (was_start and (mods.ctrl or mods.alt)) return 0;
    return 1;
}

test {
    _ = @import("config.zig");
    _ = @import("builder.zig");
    _ = @import("grammar.zig");
    _ = @import("actions.zig");
}
