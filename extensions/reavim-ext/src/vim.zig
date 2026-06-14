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
const meta = @import("meta.zig");
const ui = @import("ui.zig");

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

// On/off state persists across restarts in a small file the extension owns,
// under REAPER's resource path.
const persist_rel = "Data/Perken/reavim.ini";

fn persistPath(buf: []u8) ?[]const u8 {
    const resource = std.mem.span(Reaper.GetResourcePath());
    return std.fmt.bufPrint(buf, "{s}/{s}", .{ resource, persist_rel }) catch null;
}

fn persistEnabled(on: bool) void {
    const resource = std.mem.span(Reaper.GetResourcePath());
    var dbuf: [std.fs.max_path_bytes]u8 = undefined;
    const dir = std.fmt.bufPrint(&dbuf, "{s}/Data/Perken", .{resource}) catch return;
    std.fs.makeDirAbsolute(dir) catch {}; // ok if it already exists (Data/ always does)
    var pbuf: [std.fs.max_path_bytes]u8 = undefined;
    const path = persistPath(&pbuf) orelse return;
    const file = std.fs.createFileAbsolute(path, .{}) catch return;
    defer file.close();
    file.writeAll(if (on) "enabled=1\n" else "enabled=0\n") catch {};
}

pub fn toggle() void {
    state.mode = if (state.mode == .off) .normal else .off;
    mods = .{};
    clearPending();
    persistEnabled(state.mode != .off);
    log.info("vim mode: {s}", .{@tagName(state.mode)});
}

/// Restore the on/off state persisted by a previous session.
/// Call once at load, after bindings are set.
pub fn restoreState() void {
    var pbuf: [std.fs.max_path_bytes]u8 = undefined;
    const path = persistPath(&pbuf) orelse return;
    const file = std.fs.openFileAbsolute(path, .{}) catch return;
    defer file.close();
    var content: [64]u8 = undefined;
    const n = file.readAll(&content) catch return;
    if (std.mem.indexOf(u8, content[0..n], "enabled=1") != null) {
        state.mode = .normal;
        log.info("vim mode: normal (restored)", .{});
    }
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

/// True only when the key is destined for the arrange view (the main window or
/// a child of it) or the MIDI editor. Any other REAPER window — the action
/// list, FX browser, render/preferences dialogs, media explorer — must keep
/// its own key handling, so vim passes those through untouched.
fn focusInScope(msg: *accel.MSG) bool {
    const h = msg.hwnd orelse return false;
    const editor = Reaper.MIDIEditor_GetActive();
    if (@intFromPtr(editor) != 0 and swell.isInWindow(editor, h)) return true;
    return swell.isInWindow(Reaper.GetMainHwnd(), h);
}

/// Standard interactive controls consume their own navigation/text keys, so
/// vim must never eat them — this covers the action list (SysListView32) and
/// FX-browser/media-explorer lists, text fields (Edit/richedit), combo boxes,
/// trees and buttons, wherever they live (even parented under the main window).
/// The arrange surfaces have REAPER-prefixed classes and are NOT in this set.
fn classHandlesOwnKeys(cls: []const u8) bool {
    return std.mem.eql(u8, cls, "Edit") or
        std.ascii.startsWithIgnoreCase(cls, "richedit") or
        std.ascii.eqlIgnoreCase(cls, "combobox") or
        std.mem.eql(u8, cls, "SysListView32") or
        std.mem.eql(u8, cls, "SysTreeView32") or
        std.mem.eql(u8, cls, "Button") or
        std.mem.eql(u8, cls, "ScrollBar") or
        std.mem.eql(u8, cls, "msctls_trackbar32") or
        std.ascii.startsWithIgnoreCase(cls, "REAIMGUI_") or
        std.mem.eql(u8, cls, "reaper_imgui_context") or
        std.mem.eql(u8, cls, "Lua_LICE_gfx_standalone");
}

/// On macOS, msg.hwnd and GetFocus() can disagree — the accelerator hook may
/// deliver a container HWND while the actual focused control is a child Edit.
/// Check both so either one can grant passthrough.
fn focusHandlesOwnKeys(msg: *accel.MSG) bool {
    var buf: [64]u8 = undefined;
    if (msg.hwnd) |h| {
        if (classHandlesOwnKeys(swell.getClassName(h, &buf))) return true;
    }
    var fbuf: [64]u8 = undefined;
    if (swell.getFocus()) |f| {
        if (classHandlesOwnKeys(swell.getClassName(f, &fbuf))) return true;
    }
    return false;
}

/// Returns the translateAccel return value: 0 = pass through, 1 = eat.
pub fn onKey(msg: *accel.MSG) c_int {
    if (state.mode == .off) return 0;

    const down = msg.message == accel.WM_KEYDOWN or msg.message == accel.WM_SYSKEYDOWN;
    const up = msg.message == accel.WM_KEYUP or msg.message == accel.WM_SYSKEYUP;
    if (!down and !up) return 0;

    const vk: u8 = @truncate(msg.wParam);
    if (vk == VK_SHIFT or vk == VK_CONTROL or vk == VK_MENU) return 0;

    if (!focusInScope(msg)) return 0;
    if (focusHandlesOwnKeys(msg)) return 0;

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

    const b = bindings orelse return 0;

    const ctx = contextOf(msg);
    if (ctx != active_ctx) {
        clearPending();
        active_ctx = ctx;
    }

    // Whichkey pagination ([whichkey] config, default PageDown/PageUp). These
    // flip the completion grid's page and never touch the pending key sequence
    // — dedicated to the whichkey while vim owns the keyboard (no-op on a
    // single page), so they can't disrupt a sequence mid-flight. They are not
    // reached when a dialog/control has focus (the guards above pass those
    // through), so the action list keeps its own PageDown/PageUp.
    const k = keymod.fromEvent(vk, virt, mods.shift, mods.ctrl, mods.alt);
    if (k.eql(b.page_next) or k.eql(b.page_prev)) {
        if (down) {
            if (k.eql(b.page_next)) ui.pageNext() else ui.pagePrev();
        }
        return 1;
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

    if (key_len >= key_buf.len) clearPending();
    key_buf[key_len] = k;
    key_len += 1;

    const gmode = state.grammarMode();

    if (builder.build(&b.tables, ctx, gmode, key_buf[0..key_len])) |cmd| {
        setLastAction(cmd);
        clearPending();
        if (meta.metaKind(&cmd) != null) {
            meta.handle(cmd, ctx);
        } else {
            Reaper.Undo_BeginBlock();
            runner.execute(cmd, ctx);
            Reaper.Undo_EndBlock("reavim", 1);
            Reaper.UpdateArrange();
            meta.afterExecute(cmd);
        }
        return 1;
    }

    var comp_buf: [8]Completion = undefined;
    const conts = builder.completions(&b.tables, ctx, gmode, key_buf[0..key_len], &comp_buf);
    if (conts.len > 0) {
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
