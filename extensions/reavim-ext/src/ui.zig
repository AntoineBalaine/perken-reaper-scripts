//! Feedback window: dockable ReaImGui window showing mode, pending keys,
//! and completion hints. Timer-driven, Console1-style; ImGui init is deferred
//! to the first tick where the window is needed (ReaImGui may load after us).
//! Colors are Console1's main palette (reaperConsole1 default_reaper_theme.ini).
const std = @import("std");
const Reaper = @import("reaper").reaper;
const imgui = @import("reaper_imgui");
const vim = @import("vim.zig");
const config = @import("config.zig");
const keymod = @import("key.zig");

const log = std.log.scoped(.extension);

var imgui_available: ?bool = null; // null = not attempted yet
var ctx: imgui.ContextPtr = null;
var font: imgui.FontPtr = null;
var user_closed = false;
var prev_mode: vim.Mode = .off;

const FONT_SIZE: c_int = 14;

fn rgba(comptime hex: u32) c_int {
    return @bitCast(hex);
}

// Console1 main palette.
const col_window_bg = rgba(0x333333FF);
const col_text = rgba(0x818989FF);
const col_border = rgba(0x4F4F4FFF);
const col_title_bg = rgba(0x464646FF);
const col_title_bg_active = rgba(0x606060FF);
const col_frame_bg = rgba(0x333333FF);
const col_accent = rgba(0xFF00A5FF); // ActiveToggle
const col_green = rgba(0x13BD99FF); // ButtonActive
const col_key = rgba(0xC1FFE1FF); // ButtonHovered, opaque

pub fn register() void {
    _ = Reaper.plugin_register("timer", @constCast(@ptrCast(&onTimer)));
}

pub fn unregister() void {
    _ = Reaper.plugin_register("-timer", @constCast(@ptrCast(&onTimer)));
}

fn ensureImGui() bool {
    if (imgui_available) |ok| return ok;
    imgui.init(Reaper.plugin_getapi) catch {
        imgui_available = false;
        log.warn("ReaImGui not available — feedback window disabled (install via ReaPack)", .{});
        return false;
    };
    imgui_available = true;
    return true;
}

/// Action display name, reavim-style: real action names instead of raw ids.
fn displayName(action: config.Action, context: vim.Context, buf: []u8) []const u8 {
    switch (action) {
        .cmd => |id| return commandName(id, context, buf),
        .named => |name| {
            const id = Reaper.NamedCommandLookup(name.ptr);
            if (id != 0) return commandName(id, context, buf);
            return name;
        },
        .builtin => |b| return switch (b) {
            .insert => "Enter insert mode",
            .normal => "Enter normal mode",
            .off => "Turn vim mode off",
            .clear => "Clear pending keys",
        },
        .stub => |name| return std.fmt.bufPrint(buf, "{s} (stub)", .{name}) catch name,
    }
}

fn commandName(id: c_int, context: vim.Context, buf: []u8) []const u8 {
    const section_id: c_int = switch (context) {
        .main => 0,
        .midi => 32060,
    };
    const section = Reaper.SectionFromUniqueID(section_id);
    const name = std.mem.span(Reaper.kbd_getTextFromCmd(id, section));
    if (name.len > 0) return name;
    return std.fmt.bufPrint(buf, "cmd:{d}", .{id}) catch "?";
}

fn textColored(c: imgui.ContextPtr, color: c_int, txt: [*:0]const u8) void {
    imgui.api.PushStyleColor(c, imgui.Col_Text, color);
    imgui.api.Text(c, txt);
    imgui.api.PopStyleColor(c, null);
}

const pushed_colors = [_]struct { col: *c_int, val: c_int }{
    .{ .col = &imgui.Col_WindowBg, .val = col_window_bg },
    .{ .col = &imgui.Col_Text, .val = col_text },
    .{ .col = &imgui.Col_Border, .val = col_border },
    .{ .col = &imgui.Col_TitleBg, .val = col_title_bg },
    .{ .col = &imgui.Col_TitleBgActive, .val = col_title_bg_active },
    .{ .col = &imgui.Col_FrameBg, .val = col_frame_bg },
};

var page: usize = 0;
var last_comp_count: usize = 0;

const ROWS_PER_PAGE: usize = 8;
const COL_WIDTH: f64 = 230;
const MAX_DESC_LEN: usize = 26;
const MAX_HEIGHT: f64 = 235;

fn truncDesc(desc: []const u8, buf: []u8) []const u8 {
    if (desc.len <= MAX_DESC_LEN) return desc;
    @memcpy(buf[0 .. MAX_DESC_LEN - 3], desc[0 .. MAX_DESC_LEN - 3]);
    @memcpy(buf[MAX_DESC_LEN - 3 ..][0..3], "...");
    return buf[0..MAX_DESC_LEN];
}

fn keyLessThan(_: void, a: vim.Completion, b: vim.Completion) bool {
    var abuf: [16]u8 = undefined;
    var bbuf: [16]u8 = undefined;
    const ka = keymod.format(a.key, &abuf);
    const kb = keymod.format(b.key, &bbuf);
    return std.ascii.lessThanIgnoreCase(ka, kb);
}

fn onTimer() callconv(.C) void {
    // Re-open on each off->on transition, even if the user closed the window.
    // The window itself stays up across mode changes (including off) so the
    // user can always see which mode they're in.
    if (vim.mode != .off and prev_mode == .off) user_closed = false;
    prev_mode = vim.mode;

    if (user_closed) return;
    if (!ensureImGui()) return;

    if (ctx == null) {
        var cfg_flags: c_int = imgui.ConfigFlags_DockingEnable;
        ctx = imgui.api.CreateContext("ReaVim", &cfg_flags);
        if (ctx == null) return;
        font = imgui.api.CreateFont("sans-serif", FONT_SIZE, null);
        if (font != null) imgui.api.Attach(ctx, @ptrCast(font));
    }

    if (font != null) imgui.api.PushFont(ctx, font);
    inline for (pushed_colors) |pc| imgui.api.PushStyleColor(ctx, pc.col.*, pc.val);
    defer {
        var n: c_int = pushed_colors.len;
        imgui.api.PopStyleColor(ctx, &n);
        if (font != null) imgui.api.PopFont(ctx);
    }

    // Default into REAPER's docker on first use; the user can move it after.
    imgui.api.SetNextWindowDockID(ctx, -1, &imgui.Cond_FirstUseEver);
    imgui.api.SetNextWindowSizeConstraints(ctx, 320, 60, 8192, MAX_HEIGHT, null);

    var is_open: bool = true;
    const visible = imgui.api.Begin(ctx, "ReaVim", &is_open, null);
    if (visible) renderContent();
    imgui.api.End(ctx);

    if (!is_open) user_closed = true;
}

fn renderContent() void {
    var line: [256]u8 = undefined;

    // Compact status line: mode, context, pending keys, last action.
    const mode_txt = std.fmt.bufPrintZ(&line, "-- {s} --", .{
        switch (vim.mode) {
            .normal => "NORMAL",
            .insert => "INSERT",
            .off => "OFF",
        },
    }) catch return;
    const mode_col: c_int = switch (vim.mode) {
        .normal => col_accent,
        .insert => col_green,
        .off => col_text,
    };
    textColored(ctx, mode_col, mode_txt);

    if (vim.mode == .off) return;

    imgui.api.SameLine(ctx, null, null);
    var status: [192]u8 = undefined;
    const pending = vim.pending();
    const n = vim.pendingCount();
    var fbs = std.io.fixedBufferStream(&status);
    const w = fbs.writer();
    w.print("[{s}]", .{@tagName(vim.activeContext())}) catch {};
    if (n > 0) w.print("  {d}{s}", .{ n, pending }) catch {} else if (pending.len > 0)
        w.print("  {s}", .{pending}) catch {};
    if (vim.lastAction().len > 0) w.print("  last: {s}", .{vim.lastAction()}) catch {};
    const status_z = std.fmt.bufPrintZ(&line, "{s}", .{fbs.getWritten()}) catch return;
    imgui.api.Text(ctx, status_z);

    if (vim.mode != .normal) return;

    var comps: [96]vim.Completion = undefined;
    const items = vim.completions(&comps);
    if (items.len == 0) return;
    std.mem.sort(vim.Completion, items, {}, keyLessThan);

    if (items.len != last_comp_count) {
        last_comp_count = items.len;
        page = 0;
    }

    var avail_w: f64 = 0;
    var avail_h: f64 = 0;
    imgui.api.GetContentRegionAvail(ctx, &avail_w, &avail_h);
    const columns: usize = @max(1, @min(4, @as(usize, @intFromFloat(avail_w / COL_WIDTH))));

    const page_size = columns * ROWS_PER_PAGE;
    const n_pages = (items.len + page_size - 1) / page_size;
    if (page >= n_pages) page = n_pages - 1;

    const start = page * page_size;
    const page_items = items[start..@min(start + page_size, items.len)];

    const context = vim.activeContext();
    if (imgui.api.BeginTable(ctx, "bindings", @intCast(columns), null, null, null, null)) {
        for (page_items) |item| {
            _ = imgui.api.TableNextColumn(ctx);

            var kbuf: [16]u8 = undefined;
            const kt = keymod.format(item.key, &kbuf);
            const ktz = std.fmt.bufPrintZ(&line, "{s: >5}", .{kt}) catch continue;
            textColored(ctx, col_key, ktz);
            imgui.api.SameLine(ctx, null, null);

            var dbuf: [192]u8 = undefined;
            var tbuf: [MAX_DESC_LEN]u8 = undefined;
            const desc = if (item.value) |v|
                displayName(v, context, &dbuf)
            else
                std.fmt.bufPrint(&dbuf, "+{s}", .{item.label orelse "..."}) catch "...";
            const row = std.fmt.bufPrintZ(&line, "{s}", .{truncDesc(desc, &tbuf)}) catch continue;
            imgui.api.Text(ctx, row);
        }
        imgui.api.EndTable(ctx);
    }

    if (n_pages > 1) {
        if (imgui.api.SmallButton(ctx, "<")) page = if (page == 0) n_pages - 1 else page - 1;
        imgui.api.SameLine(ctx, null, null);
        const pg = std.fmt.bufPrintZ(&line, "{d}/{d}", .{ page + 1, n_pages }) catch return;
        imgui.api.Text(ctx, pg);
        imgui.api.SameLine(ctx, null, null);
        if (imgui.api.SmallButton(ctx, ">")) page = (page + 1) % n_pages;
    }
}
