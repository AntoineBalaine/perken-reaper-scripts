//! reavim-ext: vim mode for REAPER as a compiled extension.
//!
//! Keystrokes are intercepted via the "<accelerator" hook (front of REAPER's
//! keyboard processing queue — the undocumented prefix js_ReaScriptAPI uses;
//! plain "accelerator" registers at the back and never sees MIDI editor keys).
//! Vim off / insert mode passes everything through, so the user's native
//! key bindings stay untouched. A "ReaVim: Toggle vim mode" action is
//! registered in the main section to switch it on and off.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const accel = @import("accel.zig");
const logger = @import("logger.zig");
const vim = @import("vim.zig");
const config = @import("config.zig");
const ui = @import("ui.zig");
const runner = @import("runner.zig");
const actions_mod = @import("actions.zig");
const defaults_actions = @import("defaults_actions.zig");
const lib_state = @import("lib_state.zig");
const ported_movement = @import("ported/movement.zig");
const ported_selection = @import("ported/selection.zig");

const default_bindings = @embedFile("default_bindings.ini");

pub const std_options = std.Options{
    .log_level = switch (@import("builtin").mode) {
        .Debug => .debug,
        .ReleaseSafe => .info,
        .ReleaseFast => .warn,
        .ReleaseSmall => .err,
    },
    .logFn = logger.logFn,
};

const log = std.log.scoped(.accel);
const ext_log = std.log.scoped(.extension);

var accel_reg = accel.accelerator_register_t{
    .translateAccel = &translateAccel,
    .isLocal = true,
    .user = null,
};

var toggle_cmd_id: c_int = 0;
var bindings: ?config.Bindings = null;
var registry: ?actions_mod.Registry = null;

/// User config beats the embedded defaults:
/// <resource>/perken/reavim-ext/bindings.ini
fn loadBindings() void {
    const alloc = std.heap.c_allocator;

    registry = actions_mod.Registry.init(alloc, &.{
        &defaults_actions.entries,
        &lib_state.entries,
        &ported_movement.entries,
        &ported_selection.entries,
    }) catch |err| {
        ext_log.err("action registry init failed: {s}", .{@errorName(err)});
        return;
    };
    runner.registry = &registry.?;

    const resource = std.mem.span(Reaper.GetResourcePath());
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = std.fmt.bufPrint(&path_buf, "{s}/perken/reavim-ext/bindings.ini", .{resource}) catch "";

    if (std.fs.openFileAbsolute(path, .{})) |file| {
        defer file.close();
        if (config.parse(alloc, &registry.?, file.reader())) |b| {
            bindings = b;
            ext_log.info("bindings loaded from {s}", .{path});
        } else |err| {
            ext_log.err("failed to parse {s}: {s} — falling back to defaults", .{ path, @errorName(err) });
        }
    } else |_| {
        ext_log.info("no user bindings at {s} — using built-in defaults", .{path});
    }

    if (bindings == null) {
        bindings = config.parseString(alloc, &registry.?, default_bindings) catch |err| {
            ext_log.err("default bindings failed to parse: {s}", .{@errorName(err)});
            return;
        };
    }
    vim.setBindings(&bindings.?);
}

export fn ReaperPluginEntry(instance: Reaper.HINSTANCE, rec: ?*Reaper.plugin_info_t) c_int {
    _ = instance;

    if (rec == null)
        return 0; // cleanup

    if (!Reaper.init(rec.?))
        return 0;

    if (Reaper.plugin_register("<accelerator", @ptrCast(&accel_reg)) == 0) {
        ext_log.err("failed to register accelerator hook", .{});
        return 0;
    }

    const toggle_action: Reaper.custom_action_register_t = .{
        .section = 0,
        .id_str = "REAVIM_TOGGLE",
        .name = "ReaVim: Toggle vim mode",
    };
    toggle_cmd_id = Reaper.plugin_register("custom_action", @constCast(@ptrCast(&toggle_action)));
    if (toggle_cmd_id == 0)
        ext_log.err("failed to register toggle action", .{});

    _ = Reaper.plugin_register("hookcommand2", @constCast(@ptrCast(&onCommand)));
    _ = Reaper.plugin_register("toggleaction", @constCast(@ptrCast(&toggleActionHook)));

    loadBindings();
    ui.register();

    ext_log.info("loaded — bind \"ReaVim: Toggle vim mode\" to a key, or run it from the action list", .{});
    return 1;
}

fn onCommand(sec: *Reaper.KbdSectionInfo, command: c_int, val: c_int, val2hw: c_int, relmode: c_int, hwnd: Reaper.HWND) callconv(.C) c_char {
    _ = .{ sec, val, val2hw, relmode, hwnd };
    if (toggle_cmd_id != 0 and command == toggle_cmd_id) {
        vim.toggle();
        return 1;
    }
    return 0;
}

// -1 = not ours / doesn't toggle, 0 = ours and off, 1 = ours and on
fn toggleActionHook(command_id: c_int) callconv(.C) c_int {
    if (toggle_cmd_id != 0 and command_id == toggle_cmd_id)
        return if (vim.mode() != .off) 1 else 0;
    return -1;
}

fn translateAccel(msg: *accel.MSG, ctx: *accel.accelerator_register_t) callconv(.C) c_int {
    _ = ctx;

    if (std.log.logEnabled(.debug, .accel)) {
        const midi_hwnd = @intFromPtr(Reaper.MIDIEditor_GetActive());
        const msg_hwnd = if (msg.hwnd) |h| @intFromPtr(h) else 0;
        const vk: u8 = @truncate(msg.wParam);
        const printable: u8 = if (vk >= 0x20 and vk < 0x7f) vk else '.';
        log.debug("{s}(0x{x:0>4}) vk=0x{x:0>2} '{c}' hwnd=0x{x} midi_editor=0x{x}", .{
            accel.msgName(msg.message), msg.message, vk, printable, msg_hwnd, midi_hwnd,
        });
    }

    return vim.onKey(msg);
}

// Force the SWELL_dllMain export into the shared library.
comptime {
    _ = @import("swell_win.zig");
}

test {
    _ = @import("accel.zig");
    _ = @import("logger.zig");
    _ = @import("vim.zig");
    _ = @import("swell_win.zig");
    _ = @import("key.zig");
    _ = @import("trie.zig");
    _ = @import("ported/helpers.zig");
    _ = @import("ported/movement.zig");
    _ = @import("ported/selection.zig");
}
