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
const meta = @import("meta.zig");
const utils = @import("utils");

const log = std.log.scoped(.extension);

var imgui_available = false; // set once at register()
var ctx: imgui.ContextPtr = null;
var font: imgui.FontPtr = null;
var hidden = false;
var prev_mode: vim.Mode = .off;

/// Show/hide the feedback window (bindable action). No-op without ReaImGui.
pub fn toggleVisible() bool {
    if (!imgui_available) return false;
    hidden = !hidden;
    return !hidden;
}

pub fn isVisible() bool {
    return imgui_available and !hidden;
}

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

/// Resolve ReaImGui once at load. The feedback window is optional: if ReaImGui
/// isn't installed, set the flag and never subscribe the timer — the extension
/// runs fully without any UI. (reavim's plugin file sorts after
/// reaper_imgui-*, so ReaImGui's API is already registered by the time this
/// runs when it is installed.)
pub fn register() void {
    imgui.init(Reaper.plugin_getapi) catch {
        log.warn("ReaImGui not available — feedback window disabled (install via ReaPack)", .{});
        return;
    };
    imgui_available = true;
    _ = Reaper.plugin_register("timer", @constCast(@ptrCast(&onTimer)));
}

pub fn unregister() void {
    if (!imgui_available) return;
    _ = Reaper.plugin_register("-timer", @constCast(@ptrCast(&onTimer)));
}

pub fn available() bool {
    return imgui_available;
}

/// Action display name, reavim-style: real action names instead of raw ids.
fn displayName(bv: anytype, context: vim.Context, buf: [:0]u8) []const u8 {
    const def = bv.def;
    if (def.desc) |d| return d;
    if (def.steps.len == 1) {
        switch (def.steps[0]) {
            .cmd => |id| return commandName(id, context, buf),
            .named => |name| {
                const id = Reaper.NamedCommandLookup(name.ptr);
                if (id != 0) return commandName(id, context, buf);
                return name;
            },
            else => {},
        }
    }
    if (def.steps.len == 0)
        return utils.safePrint(buf, "{s} (stub)", .{bv.name});
    return bv.name;
}

fn commandName(id: c_int, context: vim.Context, buf: [:0]u8) []const u8 {
    const section_id: c_int = switch (context) {
        .main => 0,
        .midi => 32060,
    };
    const fallback = utils.safePrint(buf, "cmd:{d}", .{id});
    const section = Reaper.SectionFromUniqueID(section_id);
    if (@intFromPtr(section) == 0) return fallback;
    const ptr = Reaper.kbd_getTextFromCmd(id, section);
    if (@intFromPtr(ptr) == 0) return fallback;
    const name = std.mem.span(ptr);
    if (name.len > 0) return name;
    return fallback;
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
var last_n_pages: usize = 1; // set each render; used by keyboard pagination
var folded: bool = false;

const ROWS_PER_PAGE: usize = 8;
const COL_WIDTH: f64 = 270;
const DESC_BUF: usize = 256; // upper bound for a description + ellipsis
const MAX_HEIGHT: f64 = 235;

/// True when the completion grid currently spans more than one page.
pub fn hasPages() bool {
    return last_n_pages > 1;
}

/// Advance / retreat the whichkey page, wrapping. No-op with a single page.
pub fn pageNext() void {
    if (last_n_pages > 1) page = (page + 1) % last_n_pages;
}

pub fn pagePrev() void {
    if (last_n_pages > 1) page = (page + last_n_pages - 1) % last_n_pages;
}

/// Pixel width of a null-terminated string in the current font.
fn textWidth(c: imgui.ContextPtr, ztext: [*:0]const u8) f64 {
    var w: f64 = 0;
    var h: f64 = 0;
    imgui.api.CalcTextSize(c, ztext, &w, &h, null, null);
    return w;
}

/// Fit a description into max_w pixels: return it whole when it fits, otherwise
/// the longest prefix that fits with a trailing "..." appended. This fills the
/// actual (stretch-sized) column width instead of a fixed character count.
fn fitDesc(c: imgui.ContextPtr, desc: []const u8, max_w: f64, buf: []u8) [:0]const u8 {
    const full = std.fmt.bufPrintZ(buf, "{s}", .{desc}) catch return buf[0..0 :0];
    if (max_w <= 0 or textWidth(c, full) <= max_w) return full;

    // Largest n such that desc[0..n] + "..." still fits.
    var lo: usize = 0;
    var hi: usize = desc.len;
    var best: usize = 0;
    while (lo <= hi) {
        const mid = lo + (hi - lo) / 2;
        const cand = std.fmt.bufPrintZ(buf, "{s}...", .{desc[0..mid]}) catch {
            if (mid == 0) break;
            hi = mid - 1;
            continue;
        };
        if (textWidth(c, cand) <= max_w) {
            best = mid;
            lo = mid + 1;
        } else {
            if (mid == 0) break;
            hi = mid - 1;
        }
    }
    return std.fmt.bufPrintZ(buf, "{s}...", .{desc[0..best]}) catch buf[0..0 :0];
}

fn keyLessThan(_: void, a: vim.Completion, b: vim.Completion) bool {
    var abuf: [16]u8 = undefined;
    var bbuf: [16]u8 = undefined;
    const ka = keymod.format(a.key, &abuf);
    const kb = keymod.format(b.key, &bbuf);
    return std.ascii.lessThanIgnoreCase(ka, kb);
}

fn onTimer() callconv(.C) void {
    if (vim.mode() != .off and prev_mode == .off) hidden = false;
    prev_mode = vim.mode();

    if (hidden) return;

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
    if (folded) {
        const FOLDED_H: f64 = @as(f64, @floatFromInt(FONT_SIZE)) * 2.5;
        imgui.api.SetNextWindowSize(ctx, 0, FOLDED_H, &imgui.Cond_Always);
    }

    var is_open: bool = true;
    var begin_flags: c_int = imgui.WindowFlags_NoSavedSettings;
    const visible = imgui.api.Begin(ctx, "ReaVim", &is_open, &begin_flags);
    if (visible) renderContent();
    imgui.api.End(ctx);

    if (!is_open) hidden = true;
}

fn renderContent() void {
    var line: [256:0]u8 = undefined;
    const m = vim.mode();

    // Compact status line: mode, context, pending keys, last action.
    const mode_txt = utils.safePrint(&line, "-- {s} --", .{
        switch (m) {
            .normal => "NORMAL",
            .insert => "INSERT",
            .visual_track => "VISUAL TRACK",
            .visual_timeline => "VISUAL TLINE",
            .off => "OFF",
        },
    });
    const mode_col: c_int = switch (m) {
        .normal, .visual_track, .visual_timeline => col_accent,
        .insert => col_green,
        .off => col_text,
    };
    if (imgui.api.SmallButton(ctx, if (folded) "\xe2\x96\xb6" else "\xe2\x96\xbc")) folded = !folded;
    imgui.api.SameLine(ctx, null, null);
    textColored(ctx, mode_col, mode_txt);

    if (m == .off) return;

    imgui.api.SameLine(ctx, null, null);
    var status: [192]u8 = undefined;
    var pbuf: [96]u8 = undefined;
    const pending = vim.pending(&pbuf);
    var fbs = std.io.fixedBufferStream(&status);
    const w = fbs.writer();
    w.print("[{s}]", .{@tagName(vim.activeContext())}) catch {};
    if (meta.recording) w.writeAll("  REC") catch {};
    if (pending.len > 0) w.print("  {s}", .{pending}) catch {};
    if (vim.lastAction().len > 0) w.print("  last: {s}", .{vim.lastAction()}) catch {};
    const status_z = utils.safePrint(&line, "{s}", .{fbs.getWritten()});
    imgui.api.Text(ctx, status_z);

    if (folded) return;

    if (m == .insert) {
        last_n_pages = 1;
        return;
    }

    var comps: [96]vim.Completion = undefined;
    const items = vim.completions(&comps);
    if (items.len == 0) {
        last_n_pages = 1;
        return;
    }
    std.mem.sort(vim.Completion, items, {}, keyLessThan);

    var avail_w: f64 = 0;
    var avail_h: f64 = 0;
    imgui.api.GetContentRegionAvail(ctx, &avail_w, &avail_h);
    const columns: usize = @max(1, @min(4, @as(usize, @intFromFloat(avail_w / COL_WIDTH))));

    const page_size = columns * ROWS_PER_PAGE;
    const n_pages = (items.len + page_size - 1) / page_size;

    if (items.len != last_comp_count) {
        last_comp_count = items.len;
        page = 0;
        log.debug("whichkey: {d} items, avail_w={d:.0}, {d} cols, {d} pages", .{ items.len, avail_w, columns, n_pages });
    }
    last_n_pages = n_pages;
    if (page >= n_pages) page = n_pages - 1;

    const start = page * page_size;
    const page_items = items[start..@min(start + page_size, items.len)];

    const context = vim.activeContext();
    // Column-major layout: the alphabetical run reads DOWN column 0, then
    // column 1, etc. ImGui fills cells row-major, so we remap each cell to the
    // item that belongs at that (row, col) in column-major order.
    const np = page_items.len;
    const num_rows = (np + columns - 1) / columns;
    if (imgui.api.BeginTable(ctx, "bindings", @intCast(columns), null, null, null, null)) {
        var cell: usize = 0;
        while (cell < num_rows * columns) : (cell += 1) {
            _ = imgui.api.TableNextColumn(ctx);
            const vrow = cell / columns;
            const vcol = cell % columns;
            const idx = vcol * num_rows + vrow;
            if (idx >= np) continue; // trailing empty cell in a short last column
            const item = page_items[idx];

            var kbuf: [16]u8 = undefined;
            const kt = if (item.key.vk == 0) "a-z" else keymod.format(item.key, &kbuf);
            const ktz = utils.safePrint(&line, "{s: >5}", .{kt});
            textColored(ctx, col_key, ktz);
            imgui.api.SameLine(ctx, null, null);

            // Remaining pixel width in this cell for the description; fitDesc
            // trims to it so the label fills the stretched column width.
            var cell_w: f64 = 0;
            var cell_h: f64 = 0;
            imgui.api.GetContentRegionAvail(ctx, &cell_w, &cell_h);

            var dbuf: [192:0]u8 = undefined;
            var tbuf: [DESC_BUF]u8 = undefined;
            const desc = if (item.value) |v|
                displayName(v, context, &dbuf)
            else
                utils.safePrint(&dbuf, "+{s}", .{item.label orelse "..."});
            const row = fitDesc(ctx, desc, cell_w, &tbuf);
            imgui.api.Text(ctx, row);

            // When fitDesc trimmed the label to the column width, reveal the
            // full text on hover. fitDesc returns the whole desc verbatim when
            // it fits, so an inequality means it was truncated.
            if (!std.mem.eql(u8, row, desc)) {
                var full: [DESC_BUF:0]u8 = undefined;
                const full_z = utils.safePrint(&full, "{s}", .{desc});
                imgui.api.SetItemTooltip(ctx, full_z);
            }
        }
        imgui.api.EndTable(ctx);
    }

    if (n_pages > 1) {
        if (imgui.api.SmallButton(ctx, "<")) page = if (page == 0) n_pages - 1 else page - 1;
        imgui.api.SameLine(ctx, null, null);
        const pg = utils.safePrint(&line, "{d}/{d}", .{ page + 1, n_pages });
        imgui.api.Text(ctx, pg);
        imgui.api.SameLine(ctx, null, null);
        if (imgui.api.SmallButton(ctx, ">")) page = (page + 1) % n_pages;
    }
}
