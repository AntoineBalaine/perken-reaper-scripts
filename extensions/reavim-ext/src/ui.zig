//! Feedback window: dockable ReaImGui window showing mode, pending keys,
//! and completion hints. Timer-driven, Console1-style; ImGui init is deferred
//! to REAPER's first post-boot timer tick, since register() runs inside
//! ReaperPluginEntry during REAPER's plugin-load phase -- before REAPER's
//! main loop starts and before other extensions' own ReaperPluginEntry
//! calls are guaranteed to have run yet.
//! Colors are Console1's main palette (reaperConsole1 default_reaper_theme.ini).
const std = @import("std");
const Reaper = @import("reaper").reaper;
const imgui = @import("reaper_imgui");
const vim = @import("vim.zig");
const config = @import("config.zig");
const keymod = @import("key.zig");
const meta = @import("meta.zig");
const utils = @import("utils");
const actions = @import("actions.zig");
const builder = @import("builder.zig");
const grammar = @import("grammar.zig");
const search = @import("search.zig");
const state = @import("state.zig");

const log = std.log.scoped(.extension);

/// Because ReaImGui may load after us, its API can only be probed once boot
/// is done, so the state starts `unchecked` and the first timer tick resolves
/// it to `absent` or `present`.
var imgui_state: enum { unchecked, absent, present } = .unchecked;
var ctx: imgui.ContextPtr = null;
var font: imgui.FontPtr = null;
var hidden = false;
var prev_mode: vim.Mode = .off;
/// Whether ImGui reported the whichkey window as focused on the last frame.
/// The vim engine reads it to redirect keys typed into the window back to the
/// arrange view, because those keys would otherwise be swallowed silently.
pub var window_focused = false;

/// Show/hide the feedback window (bindable action). No-op without ReaImGui.
pub fn toggleVisible() bool {
    if (imgui_state != .present) return false;
    hidden = !hidden;
    return !hidden;
}

pub fn isVisible() bool {
    return imgui_state == .present and !hidden;
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
const col_accent_dim = rgba(0xFF00A566); // accent at 40% for text selection

/// Always subscribe the timer. ReaImGui availability is resolved lazily on
/// the first timer tick instead of here (see ensureImguiChecked) -- REAPER
/// only starts delivering timer callbacks once every plugin has finished
/// loading and the main loop is running, which makes the first onTimer call
/// a reliable, order-independent "boot is done" signal.
pub fn register() void {
    _ = Reaper.plugin_register("timer", @constCast(@ptrCast(&onTimer)));
}

pub fn unregister() void {
    _ = Reaper.plugin_register("-timer", @constCast(@ptrCast(&onTimer)));
}

pub fn available() bool {
    return imgui_state == .present;
}

// ---- binding search (pinned at the top of the window) ----

pub const MAX_RESULTS = 512;
const RESULT_ROWS: usize = 10;
const QUERY_LEN = 128;

pub const SearchState = struct {
    /// Set by the SearchBindings action: the vim engine then routes typed
    /// keys into the query, so the arrange view keeps keyboard focus.
    capturing: bool = false,
    /// Whether the ImGui text field itself is being edited (after a mouse
    /// click). The engine must then let keys reach the field.
    input_active: bool = false,
    query: [QUERY_LEN:0]u8 = [_:0]u8{0} ** QUERY_LEN,
    selected: usize = 0,
    index: ?search.Index = null,
    results: [MAX_RESULTS]usize = undefined,
    results_len: usize = 0,

    pub fn queryText(self: *const SearchState) []const u8 {
        return std.mem.sliceTo(&self.query, 0);
    }

    pub fn active(self: *const SearchState) bool {
        return self.capturing or self.input_active or self.queryText().len > 0;
    }
};

pub var search_state: SearchState = .{};

/// The index descriptions use the same names as the whichkey grid.
fn searchDesc(value: builder.BindingValue, context: grammar.Context, buf: [:0]u8) []const u8 {
    return displayName(value, context, buf);
}

/// Rebuilds the index when it is missing or was built for another context
/// or mode, then recomputes the results for the current query.
pub fn refreshResults() void {
    const tables = vim.tables() orelse return;
    const ctx_now = vim.activeContext();
    const mode_now = state.grammarMode();
    if (search_state.index == null) search_state.index = search.Index.init(std.heap.c_allocator);
    const index = &search_state.index.?;
    if (index.entries.items.len == 0 or index.ctx != ctx_now or index.mode != mode_now) {
        search.rebuild(index, tables, ctx_now, mode_now, &searchDesc) catch |err| {
            log.warn("search index failed: {s}", .{@errorName(err)});
            return;
        };
    }
    search_state.results_len = search.filter(index, search_state.queryText(), &search_state.results).len;
    if (search_state.selected >= search_state.results_len)
        search_state.selected = if (search_state.results_len == 0) 0 else search_state.results_len - 1;
}

/// Opens the search box with typing captured by vim (the SearchBindings
/// action). The window is shown and unfolded, because the box lives in it.
/// Without ReaImGui, the box would never be drawn while vim still swallowed
/// every key into it, so the action does nothing in that case.
pub fn openSearch() void {
    if (imgui_state != .present) return;
    hidden = false;
    folded = false;
    search_state.capturing = true;
    search_state.query[0] = 0;
    search_state.selected = 0;
    refreshResults();
}

pub fn closeSearch() void {
    search_state.capturing = false;
    search_state.query[0] = 0;
    search_state.selected = 0;
    search_state.results_len = 0;
}

/// Runs the result at `slot` (an index into the current results) by feeding
/// its key sequence to the engine.
pub fn runResult(slot: usize) void {
    if (slot >= search_state.results_len) return;
    const index = &(search_state.index orelse return);
    const entry = index.entries.items[search_state.results[slot]];
    const was_in_field = search_state.input_active;
    closeSearch();
    if (was_in_field) vim.focusArrange();
    vim.feedKeys(entry.keys);
}

pub fn moveSelection(delta: isize) void {
    if (search_state.results_len == 0) return;
    const n: isize = @intCast(search_state.results_len);
    const cur: isize = @intCast(search_state.selected);
    search_state.selected = @intCast(@mod(cur + delta, n));
}

/// Handles one key-down while vim captures typing for the search box.
pub fn searchKey(k: keymod.Key) void {
    const plain = !k.ctrl and !k.alt and !k.shift and !k.is_char;
    if (plain and k.vk == keymod.VK.ESCAPE) return closeSearch();
    if (plain and k.vk == keymod.VK.RETURN) return runResult(search_state.selected);
    if (plain and (k.vk == keymod.VK.UP)) return moveSelection(-1);
    if (plain and (k.vk == keymod.VK.DOWN or k.vk == keymod.VK.TAB)) return moveSelection(1);
    if (k.ctrl and !k.alt and !k.is_char and (k.vk == 'P' or k.vk == 'K')) return moveSelection(-1);
    if (k.ctrl and !k.alt and !k.is_char and (k.vk == 'N' or k.vk == 'J')) return moveSelection(1);
    if (plain and k.vk == keymod.VK.BACK) {
        const len = search_state.queryText().len;
        if (len > 0) search_state.query[len - 1] = 0;
        search_state.selected = 0;
        return refreshResults();
    }
    const c = search.keyChar(k) orelse return;
    const len = search_state.queryText().len;
    if (len + 1 >= QUERY_LEN) return;
    search_state.query[len] = c;
    search_state.query[len + 1] = 0;
    search_state.selected = 0;
    refreshResults();
}

fn searchBindingsAction(_: *actions.RunCtx) void {
    openSearch();
}

pub const entries = [_]actions.Entry{
    .{ .name = "SearchBindings", .def = .{ .steps = &.{.{ .func = &searchBindingsAction }}, .desc = "Search keys & commands" } },
};

/// The search box row. While vim captures typing, the field gets the accent
/// border, because the arrange view keeps keyboard focus and the user needs
/// to see where the typing goes.
fn renderSearchBox() void {
    const capturing = search_state.capturing;
    // The field sets every color it uses, because the inherited defaults gave
    // dark text on the dark frame: typed text uses the bright key color, the
    // hint the regular text color, on a frame lighter than the window. While
    // vim captures typing, the accent border shows where the keys go.
    const field_colors = [_]struct { col: *c_int, val: c_int }{
        .{ .col = &imgui.Col_Text, .val = col_key },
        .{ .col = &imgui.Col_TextDisabled, .val = col_text },
        .{ .col = &imgui.Col_FrameBg, .val = col_title_bg },
        .{ .col = &imgui.Col_FrameBgHovered, .val = col_title_bg_active },
        .{ .col = &imgui.Col_FrameBgActive, .val = col_title_bg_active },
        .{ .col = &imgui.Col_TextSelectedBg, .val = col_accent_dim },
        .{ .col = &imgui.Col_Border, .val = if (capturing) col_accent else col_border },
    };
    inline for (field_colors) |fc| imgui.api.PushStyleColor(ctx, fc.col.*, fc.val);
    imgui.api.PushStyleVar(ctx, imgui.StyleVar_FrameBorderSize, if (capturing) 1 else 0, null);

    imgui.api.SetNextItemWidth(ctx, -std.math.floatMin(f64));
    const before_len = search_state.queryText().len;
    var flags: c_int = imgui.InputTextFlags_EnterReturnsTrue | imgui.InputTextFlags_AutoSelectAll;
    const hint: [*:0]const u8 = if (capturing)
        "type to search, Up/Down to select, Enter to run, Esc to close"
    else
        "search keys & commands (<space>/)";
    const entered = imgui.api.InputTextWithHint(ctx, "##reavim_search", hint, &search_state.query, QUERY_LEN, &flags, null);
    search_state.input_active = imgui.api.IsItemActive(ctx);

    imgui.api.PopStyleVar(ctx, null);
    var n_colors: c_int = field_colors.len;
    imgui.api.PopStyleColor(ctx, &n_colors);

    if (search_state.input_active) {
        // Mouse-focused editing: the field owns the keyboard, so the result
        // navigation keys are read from ImGui instead of the vim engine.
        if (search_state.queryText().len != before_len) search_state.selected = 0;
        if (imgui.api.IsKeyPressed(ctx, imgui.Key_UpArrow, null)) moveSelection(-1);
        if (imgui.api.IsKeyPressed(ctx, imgui.Key_DownArrow, null)) moveSelection(1);
    }
    if (search_state.active()) refreshResults();
    if (entered) runResult(search_state.selected);
}

fn renderSearchResults() void {
    var line: [256:0]u8 = undefined;
    const index = &(search_state.index orelse return);
    const n = search_state.results_len;
    if (n == 0) {
        if (search_state.queryText().len > 0) imgui.api.Text(ctx, "no match");
        return;
    }
    // The visible window of rows follows the selection.
    const first = if (search_state.selected >= RESULT_ROWS) search_state.selected + 1 - RESULT_ROWS else 0;
    const last = @min(n, first + RESULT_ROWS);
    var slot = first;
    while (slot < last) : (slot += 1) {
        const e = index.entries.items[search_state.results[slot]];
        var selected = slot == search_state.selected;
        const label = utils.safePrint(&line, "{s: >10}   {s}##sr{d}", .{ e.keys_text, e.desc, slot });
        if (imgui.api.Selectable(ctx, label, &selected, null, null, null)) runResult(slot);
    }
    const pos = utils.safePrint(&line, "{d}/{d}", .{ search_state.selected + 1, n });
    textColored(ctx, col_text, pos);
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
    ensureImguiChecked();
    if (imgui_state != .present) return;

    if (vim.mode() != .off and prev_mode == .off) hidden = false;
    prev_mode = vim.mode();

    if (hidden) {
        window_focused = false;
        return;
    }

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
    var focus_flags: c_int = imgui.FocusedFlags_RootAndChildWindows;
    window_focused = visible and imgui.api.IsWindowFocused(ctx, &focus_flags);
    if (visible) renderContent();
    imgui.api.End(ctx);

    if (!is_open) {
        hidden = true;
        window_focused = false;
    }
}

/// Resolve the ReaImGui API exactly once, on REAPER's first post-boot timer
/// tick. Safe to call unconditionally from onTimer every frame; the state
/// makes this a no-op after the first call. Because the timer has no other
/// use when ReaImGui is absent, we unregister it in that case so that the
/// extension does not pay for a callback on every main-loop tick.
fn ensureImguiChecked() void {
    if (imgui_state != .unchecked) return;
    imgui.init(Reaper.plugin_getapi) catch {
        log.warn("ReaImGui not available — feedback window disabled (install via ReaPack)", .{});
        imgui_state = .absent;
        _ = Reaper.plugin_register("-timer", @constCast(@ptrCast(&onTimer)));
        return;
    };
    imgui_state = .present;
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

    if (m == .off) {
        if (search_state.capturing) closeSearch();
        return;
    }

    imgui.api.SameLine(ctx, null, null);
    var pbuf: [96]u8 = undefined;
    const pending = vim.pending(&pbuf);
    imgui.api.Text(ctx, utils.safePrint(&line, "[{s}]", .{@tagName(vim.activeContext())}));
    if (meta.recording) {
        const k: keymod.Key = @bitCast(meta.record_register);
        const reg_ch: u8 = if (k.vk >= 'A' and k.vk <= 'Z') k.vk + 32 else k.vk;
        var rbuf: [24:0]u8 = undefined;
        imgui.api.SameLine(ctx, null, null);
        textColored(ctx, rgba(0xFF3333FF), utils.safePrint(&rbuf, "  \xe2\x97\x8f REC @{c}", .{reg_ch}));
    }
    if (pending.len > 0) {
        imgui.api.SameLine(ctx, null, null);
        imgui.api.Text(ctx, utils.safePrint(&line, "  {s}", .{pending}));
    }
    if (vim.lastAction().len > 0) {
        imgui.api.SameLine(ctx, null, null);
        imgui.api.Text(ctx, utils.safePrint(&line, "  last: {s}", .{vim.lastAction()}));
    }

    if (folded) return;

    renderSearchBox();
    if (search_state.active()) {
        last_n_pages = 1;
        renderSearchResults();
        return;
    }

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
