const std = @import("std");
const imgui = @import("reaper_imgui");
const UiState = @import("ui_state.zig").UiState;
const styles = @import("styles.zig");
const action_types = @import("action_types.zig");

const log = std.log.scoped(.hotreload);

const UiInitFn = *const fn (*anyopaque) callconv(.c) bool;
const UiRenderFn = *const fn (imgui.ContextPtr, c_int, *UiState, *styles.StyleManager) callconv(.c) c_int;
const UiGetLastActionFn = *const fn () callconv(.c) *const action_types.ModeAction;

pub const RenderResult = union(enum) {
    no_action,
    action: action_types.ModeAction,
    render_error,
};

pub const HotReloader = struct {
    lib: ?std.DynLib = null,
    ui_init: ?UiInitFn = null,
    ui_render: ?UiRenderFn = null,
    ui_get_last_action: ?UiGetLastActionFn = null,
    last_mtime: i128 = 0,
    lib_path: [:0]const u8,
    plugin_getapi: *anyopaque,
    frame_counter: u32 = 0,
    // Because macOS caches dlopen'd libraries even after dlclose, we need to
    // copy the dylib to a unique temp path before each load so the OS treats
    // it as a new library.
    temp_path_buf: [std.fs.max_path_bytes:0]u8 = undefined,
    reload_counter: u32 = 0,

    pub fn init(
        io: std.Io,
        lib_path: [:0]const u8,
        plugin_getapi: *anyopaque,
    ) HotReloader {
        var self = HotReloader{
            .lib_path = lib_path,
            .plugin_getapi = plugin_getapi,
        };
        self.tryLoad(io);
        return self;
    }

    pub fn deinit(self: *HotReloader) void {
        self.unload();
    }

    /// Called each frame. Checks for file changes every 60 frames (~1 second)
    /// and reloads if needed. Then calls the UI render function.
    pub fn render(
        self: *HotReloader,
        io: std.Io,
        ctx: imgui.ContextPtr,
        win_flags: c_int,
        globals: *UiState,
        style_manager: *styles.StyleManager,
    ) RenderResult {
        self.frame_counter += 1;
        if (self.frame_counter >= 60) {
            self.frame_counter = 0;
            self.checkAndReload(io);
        }

        if (self.ui_render) |render_fn| {
            const result = render_fn(ctx, win_flags, globals, style_manager);
            return switch (result) {
                0 => .render_error,
                1 => .no_action,
                2 => {
                    if (self.ui_get_last_action) |get_action| {
                        return .{ .action = get_action().* };
                    }
                    return .no_action;
                },
                else => .no_action,
            };
        }

        return .no_action;
    }

    fn checkAndReload(self: *HotReloader, io: std.Io) void {
        const mtime = getFileMtime(io, self.lib_path) orelse return;
        if (mtime != self.last_mtime and self.last_mtime != 0) {
            log.info("UI lib changed on disk, reloading...", .{});
            self.unload();
            self.tryLoad(io);
        }
    }

    fn tryLoad(self: *HotReloader, io: std.Io) void {
        self.last_mtime = getFileMtime(io, self.lib_path) orelse {
            log.warn("UI lib not found at {s}", .{self.lib_path});
            return;
        };

        // Because macOS caches shared libraries by path, we copy to a temp
        // file with a unique name so dlopen loads the fresh binary.
        self.reload_counter += 1;
        const temp_path = self.copyToTemp(io) orelse {
            log.err("Failed to copy UI lib to temp path", .{});
            return;
        };

        // Because macOS kills processes that dlopen unsigned binaries,
        // we ad-hoc sign the temp copy before loading it.
        if (comptime @import("builtin").os.tag == .macos and @import("builtin").mode == .debug) {
            var codesign = std.process.spawn(io, .{ .argv = &.{ "codesign", "-s", "-", temp_path } }) catch |err| {
                log.err("Failed to codesign temp UI lib: {s}", .{@errorName(err)});
                return;
            };
            const term = codesign.wait(io) catch |err| {
                log.err("Failed to codesign temp UI lib: {s}", .{@errorName(err)});
                return;
            };
            if (!term.success()) {
                log.err("codesign failed: {f}", .{term});
                return;
            }
        }

        var lib = std.DynLib.open(temp_path) catch |err| {
            log.err("Failed to open UI lib: {s}", .{@errorName(err)});
            return;
        };

        const init_fn = lib.lookup(UiInitFn, "ui_init") orelse {
            log.err("UI lib missing ui_init symbol", .{});
            lib.close();
            return;
        };

        const render_fn = lib.lookup(UiRenderFn, "ui_render") orelse {
            log.err("UI lib missing ui_render symbol", .{});
            lib.close();
            return;
        };

        const get_action_fn = lib.lookup(UiGetLastActionFn, "ui_get_last_action") orelse {
            log.err("UI lib missing ui_get_last_action symbol", .{});
            lib.close();
            return;
        };

        // Because the UI lib needs to resolve ImGui function pointers after
        // each load, we call ui_init with the plugin_getapi function.
        if (!init_fn(self.plugin_getapi)) {
            log.err("ui_init failed", .{});
            lib.close();
            return;
        }

        self.lib = lib;
        self.ui_init = init_fn;
        self.ui_render = render_fn;
        self.ui_get_last_action = get_action_fn;
        log.info("UI lib loaded successfully (reload #{d})", .{self.reload_counter});
    }

    fn copyToTemp(self: *HotReloader, io: std.Io) ?[:0]const u8 {
        const result = std.fmt.bufPrint(&self.temp_path_buf, "/tmp/reaper_ui_reload_{d}.dylib", .{
            self.reload_counter,
        }) catch return null;
        self.temp_path_buf[result.len] = 0;
        const dest: [:0]const u8 = self.temp_path_buf[0..result.len :0];

        // Delete previous temp file if it exists.
        if (self.reload_counter > 1) {
            var prev_buf: [std.fs.max_path_bytes]u8 = undefined;
            const prev = std.fmt.bufPrint(&prev_buf, "/tmp/reaper_ui_reload_{d}.dylib", .{
                self.reload_counter - 1,
            }) catch null;
            if (prev) |prev_path| {
                std.Io.Dir.deleteFileAbsolute(io, prev_path) catch {};
            }
        }

        // Copy contents.
        std.Io.Dir.copyFileAbsolute(self.lib_path, dest, io, .{}) catch return null;

        return dest;
    }

    fn unload(self: *HotReloader) void {
        if (self.lib) |*lib| {
            lib.close();
        }
        self.lib = null;
        self.ui_init = null;
        self.ui_render = null;
        self.ui_get_last_action = null;
    }

    fn getFileMtime(io: std.Io, path: [:0]const u8) ?i128 {
        const file = std.Io.Dir.openFileAbsolute(io, path, .{}) catch return null;
        defer file.close(io);
        const stat = file.stat(io) catch return null;
        return stat.mtime.nanoseconds;
    }
};
