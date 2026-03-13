const std = @import("std");
const imgui = @import("reaper_imgui.zig");

const log = std.log.scoped(.hotreload);

const UiInitFn = *const fn (*anyopaque) callconv(.C) bool;
const UiRenderFn = *const fn (imgui.ContextPtr, c_int) callconv(.C) bool;

pub const HotReloader = struct {
    lib: ?std.DynLib = null,
    ui_init: ?UiInitFn = null,
    ui_render: ?UiRenderFn = null,
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
        lib_path: [:0]const u8,
        plugin_getapi: *anyopaque,
    ) HotReloader {
        var self = HotReloader{
            .lib_path = lib_path,
            .plugin_getapi = plugin_getapi,
        };
        self.tryLoad();
        return self;
    }

    pub fn deinit(self: *HotReloader) void {
        self.unload();
    }

    /// Called each frame. Checks for file changes every 60 frames (~1 second)
    /// and reloads if needed. Then calls the UI render function.
    pub fn render(self: *HotReloader, ctx: imgui.ContextPtr, win_flags: c_int) bool {
        self.frame_counter += 1;
        if (self.frame_counter >= 60) {
            self.frame_counter = 0;
            self.checkAndReload();
        }

        if (self.ui_render) |render_fn| {
            return render_fn(ctx, win_flags);
        }

        return true;
    }

    fn checkAndReload(self: *HotReloader) void {
        const mtime = getFileMtime(self.lib_path) orelse return;
        if (mtime != self.last_mtime and self.last_mtime != 0) {
            log.info("UI lib changed on disk, reloading...", .{});
            self.unload();
            self.tryLoad();
        }
    }

    fn tryLoad(self: *HotReloader) void {
        self.last_mtime = getFileMtime(self.lib_path) orelse {
            log.warn("UI lib not found at {s}", .{self.lib_path});
            return;
        };

        // Because macOS caches shared libraries by path, we copy to a temp
        // file with a unique name so dlopen loads the fresh binary.
        self.reload_counter += 1;
        const temp_path = self.copyToTemp() orelse {
            log.err("Failed to copy UI lib to temp path", .{});
            return;
        };

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
        log.info("UI lib loaded successfully (reload #{d})", .{self.reload_counter});
    }

    fn copyToTemp(self: *HotReloader) ?[:0]const u8 {
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
                std.fs.deleteFileAbsolute(prev_path) catch {};
            }
        }

        const src = std.fs.openFileAbsoluteZ(self.lib_path, .{}) catch return null;
        defer src.close();
        const dst = std.fs.createFileAbsoluteZ(dest, .{}) catch return null;
        defer dst.close();

        // Copy contents.
        var buf: [8192]u8 = undefined;
        while (true) {
            const n = src.read(&buf) catch return null;
            if (n == 0) break;
            dst.writeAll(buf[0..n]) catch return null;
        }

        return dest;
    }

    fn unload(self: *HotReloader) void {
        if (self.lib) |*lib| {
            lib.close();
        }
        self.lib = null;
        self.ui_init = null;
        self.ui_render = null;
    }

    fn getFileMtime(path: [:0]const u8) ?i128 {
        const file = std.fs.openFileAbsoluteZ(path, .{}) catch return null;
        defer file.close();
        const stat = file.stat() catch return null;
        return stat.mtime;
    }
};
