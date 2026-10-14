//! The action palette ("Perken: Search actions (palette)"): a ReaImGui window
//! with a text box and a fuzzy-matched list of every action in REAPER's main
//! section (extensions and scripts included). Typing narrows the list, Up and
//! Down (or Ctrl+P and Ctrl+N) move the selection by a row, PageUp and
//! PageDown by a page, Home and End jump to the first and last result, Enter
//! or a click runs the action, and Escape closes the window. It needs no terminal, so there is no launcher script, no
//! permission prompt and no files to exchange.
//!
//! The window is drawn from a timer that only runs while it is open. ReaImGui
//! is resolved on the first tick, because it may load after this extension.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const imgui = @import("reaper_imgui");
const palette = @import("ui_palette");
const actions = @import("actions.zig");
const fuzzy = @import("fuzzy.zig");

const log = std.log.scoped(.action_palette);

const MAX_RESULTS = 200;
/// Larger than the whichkey window's 14, because this window is read while
/// typing and scanning a list.
const FONT_SIZE: c_int = 18;
const QUERY_CAP = 256;
const MAX_ACTIONS = 500_000;

pub const ImguiState = enum { unchecked, present, missing };

pub const Entry = struct {
    id: c_int,
    name: [:0]const u8,
};

pub const State = struct {
    imgui_state: ImguiState = .unchecked,
    ctx: imgui.ContextPtr = null,
    font: imgui.FontPtr = null,
    open: bool = false,
    timer_registered: bool = false,
    /// Owns the names of `entries`; rebuilt every time the palette opens, so
    /// that actions added since (scripts, extensions) appear.
    arena: ?std.heap.ArenaAllocator = null,
    entries: []Entry = &.{},
    query: [QUERY_CAP:0]u8 = [_:0]u8{0} ** QUERY_CAP,
    /// The query the current results were computed for.
    shown_query: [QUERY_CAP:0]u8 = [_:0]u8{0} ** QUERY_CAP,
    results: [MAX_RESULTS]fuzzy.Ranked = undefined,
    result_count: usize = 0,
    selected: usize = 0,
    /// Scroll the list to the selected row on the next frame (set when the
    /// selection moves by keyboard, not by mouse).
    follow_selection: bool = false,
    /// How many list rows fit in the window, measured while drawing the list
    /// and used by PageUp and PageDown on the next frame.
    visible_rows: usize = 10,
    /// The window just opened: focus the text box.
    focus_input: bool = false,
    /// The command chosen by the user. It runs on the next tick, after the
    /// window has stopped being drawn, so that it does not run with the
    /// palette still on screen.
    pending_cmd: c_int = 0,
};

pub var state: State = .{};

// ---- the action ----

fn paletteAction(_: *actions.RunCtx) void {
    if (state.imgui_state == .missing) {
        showMissingImgui();
        return;
    }
    if (state.open) return;
    if (!loadEntries()) return;
    state.query[0] = 0;
    state.shown_query[0] = 0;
    state.selected = 0;
    state.follow_selection = true;
    state.focus_input = true;
    refilter();
    state.open = true;
    ensureTimer();
}

fn showMissingImgui() void {
    _ = Reaper.ShowMessageBox("The action palette needs ReaImGui (install it with ReaPack).", "Perken: action palette", 0);
}

pub const entries = [_]actions.Entry{
    .{ .name = "SearchActionsPalette", .def = .{ .steps = &.{.{ .func = &paletteAction }}, .desc = "Search actions (palette)" } },
};

// ---- the action list ----

/// Reads every action of the main section into `state.entries`.
fn loadEntries() bool {
    if (state.arena) |*a| a.deinit();
    state.arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    state.entries = &.{};
    const alloc = state.arena.?.allocator();

    const section = Reaper.SectionFromUniqueID(0) orelse {
        log.warn("REAPER has no main actions section", .{});
        return false;
    };
    var list = std.ArrayList(Entry).init(alloc);
    var idx: c_int = 0;
    while (idx < MAX_ACTIONS) : (idx += 1) {
        var name: ?[*:0]const u8 = null;
        const id = Reaper.kbd_enumerateActions(section, idx, &name);
        if (id == 0) break;
        const text = if (name) |n| std.mem.span(n) else "";
        if (text.len == 0) continue; // unnamed commands cannot be searched for
        const owned = alloc.dupeZ(u8, text) catch return false;
        list.append(.{ .id = id, .name = owned }) catch return false;
    }
    state.entries = list.items;
    return state.entries.len > 0;
}

/// Recomputes the ranked results for the current query.
fn refilter() void {
    const query = std.mem.sliceTo(&state.query, 0);
    state.result_count = 0;
    for (state.entries, 0..) |e, i| {
        const s = fuzzy.score(query, e.name) orelse continue;
        fuzzy.insertRanked(&state.results, &state.result_count, .{
            .index = @intCast(i),
            .score = s,
            .len = @intCast(e.name.len),
        });
    }
    @memcpy(&state.shown_query, &state.query);
    state.selected = 0;
    state.follow_selection = true;
}

// ---- timer and window ----

fn ensureTimer() void {
    if (state.timer_registered) return;
    _ = Reaper.plugin_register("timer", @constCast(@ptrCast(&onTimer)));
    state.timer_registered = true;
}

fn stopTimer() void {
    if (!state.timer_registered) return;
    _ = Reaper.plugin_register("-timer", @constCast(@ptrCast(&onTimer)));
    state.timer_registered = false;
}

fn ensureImgui() void {
    if (state.imgui_state != .unchecked) return;
    imgui.init(Reaper.plugin_getapi) catch {
        state.imgui_state = .missing;
        log.warn("ReaImGui not available — the action palette needs it (install via ReaPack)", .{});
        return;
    };
    state.imgui_state = .present;
}

pub fn onTimer() callconv(.C) void {
    if (state.pending_cmd != 0) {
        const id = state.pending_cmd;
        state.pending_cmd = 0;
        Reaper.Main_OnCommand(id, 0);
    }

    ensureImgui();
    if (state.imgui_state == .missing) {
        if (state.open) {
            state.open = false;
            showMissingImgui();
        }
        stopTimer();
        return;
    }

    if (state.open) drawWindow();

    if (!state.open and state.pending_cmd == 0) {
        state.ctx = null; // a new context is created at the next opening
        stopTimer();
    }
}

fn close() void {
    state.open = false;
}

fn runEntry(result_index: usize) void {
    const entry = state.entries[state.results[result_index].index];
    log.info("running {d}: {s}", .{ entry.id, entry.name });
    state.pending_cmd = entry.id;
    close();
}

fn drawWindow() void {
    if (state.ctx == null) {
        var cfg_flags: c_int = 0;
        state.ctx = imgui.api.CreateContext("Perken action palette", &cfg_flags);
        if (state.ctx == null) {
            state.open = false;
            return;
        }
        state.font = imgui.api.CreateFont("sans-serif", FONT_SIZE, null);
        if (state.font != null) imgui.api.Attach(state.ctx, @ptrCast(state.font));
    }
    const ctx = state.ctx;

    // The font and colors are pushed before the window begins, so that its
    // title bar and size use them too, exactly as the whichkey window does.
    if (state.font != null) imgui.api.PushFont(ctx, state.font);
    palette.push(ctx, &palette.window_colors);
    imgui.api.SetNextWindowSize(ctx, 680, 460, &imgui.Cond_FirstUseEver);
    var is_open: bool = true;
    var flags: c_int = imgui.WindowFlags_NoSavedSettings | imgui.WindowFlags_NoCollapse;
    if (imgui.api.Begin(ctx, "Perken: search actions", &is_open, &flags)) drawContent(ctx);
    imgui.api.End(ctx);
    palette.pop(ctx, palette.window_colors.len);
    if (state.font != null) imgui.api.PopFont(ctx);
    if (!is_open) close();
}

fn keyPressed(ctx: imgui.ContextPtr, key: c_int) bool {
    return imgui.api.IsKeyPressed(ctx, key, null);
}

fn drawContent(ctx: imgui.ContextPtr) void {
    if (state.focus_input) {
        imgui.api.SetKeyboardFocusHere(ctx, null);
        state.focus_input = false;
    }
    const field_colors = palette.fieldColors(palette.border);
    palette.push(ctx, &field_colors);
    imgui.api.SetNextItemWidth(ctx, -1);
    var input_flags: c_int = imgui.InputTextFlags_None;
    _ = imgui.api.InputTextWithHint(ctx, "##query", "search actions", &state.query, state.query.len, &input_flags, null);
    palette.pop(ctx, field_colors.len);

    if (!std.mem.eql(u8, std.mem.sliceTo(&state.query, 0), std.mem.sliceTo(&state.shown_query, 0))) refilter();

    handleKeys(ctx);

    var label_buf: [MAX_RESULTS_LABEL:0]u8 = undefined;
    var counter: [64:0]u8 = undefined;
    const counter_text = std.fmt.bufPrintZ(&counter, "{d} of {d} actions", .{ state.result_count, state.entries.len }) catch "";
    imgui.api.Text(ctx, counter_text);

    var chosen: ?usize = null;
    palette.push(ctx, &palette.list_colors);
    if (imgui.api.BeginChild(ctx, "##results", null, null, null, null)) {
        var avail_w: f64 = 0;
        var avail_h: f64 = 0;
        imgui.api.GetContentRegionAvail(ctx, &avail_w, &avail_h);
        const row_h = imgui.api.GetTextLineHeightWithSpacing(ctx);
        if (row_h > 0 and avail_h > 0) state.visible_rows = @intFromFloat(avail_h / row_h);
        var i: usize = 0;
        while (i < state.result_count) : (i += 1) {
            const entry = state.entries[state.results[i].index];
            const label = std.fmt.bufPrintZ(&label_buf, "{s}##{d}", .{ entry.name, entry.id }) catch continue;
            // Because Selectable writes its click back into `is_selected`,
            // the push and the matching pop test a separate copy.
            const highlighted = i == state.selected;
            var is_selected = highlighted;
            var sel_flags: c_int = imgui.SelectableFlags_None;
            // The selected row's text takes the bright key color, because
            // the regular text color is too dim on the lighter highlight.
            if (highlighted) imgui.api.PushStyleColor(ctx, imgui.Col_Text, palette.key);
            if (imgui.api.Selectable(ctx, label, &is_selected, &sel_flags, null, null)) {
                state.selected = i;
                chosen = i;
            }
            if (highlighted) imgui.api.PopStyleColor(ctx, null);
            if (i == state.selected and state.follow_selection) {
                imgui.api.SetScrollHereY(ctx, null);
                state.follow_selection = false;
            }
        }
    }
    imgui.api.EndChild(ctx);
    palette.pop(ctx, palette.list_colors.len);

    if (chosen) |c| runEntry(c);
}

const MAX_RESULTS_LABEL = 512;

/// Up/Down and Ctrl+P/Ctrl+N move the selection by a row, PageUp/PageDown by
/// a page, Home/End to the first/last result, Enter runs it, Escape closes.
fn handleKeys(ctx: imgui.ContextPtr) void {
    const ctrl = (imgui.api.GetKeyMods(ctx) & imgui.Mod_Ctrl) != 0;
    if (state.result_count > 0) {
        if (keyPressed(ctx, imgui.Key_DownArrow) or (ctrl and keyPressed(ctx, imgui.Key_N))) {
            state.selected = moveSelection(state.selected, state.result_count, 1);
            state.follow_selection = true;
        }
        if (keyPressed(ctx, imgui.Key_UpArrow) or (ctrl and keyPressed(ctx, imgui.Key_P))) {
            state.selected = moveSelection(state.selected, state.result_count, -1);
            state.follow_selection = true;
        }
        if (keyPressed(ctx, imgui.Key_PageDown)) {
            state.selected = moveSelection(state.selected, state.result_count, pageStep(state.visible_rows));
            state.follow_selection = true;
        }
        if (keyPressed(ctx, imgui.Key_PageUp)) {
            state.selected = moveSelection(state.selected, state.result_count, -pageStep(state.visible_rows));
            state.follow_selection = true;
        }
        if (keyPressed(ctx, imgui.Key_Home)) {
            state.selected = edgeSelection(state.result_count, false);
            state.follow_selection = true;
        }
        if (keyPressed(ctx, imgui.Key_End)) {
            state.selected = edgeSelection(state.result_count, true);
            state.follow_selection = true;
        }
        if (keyPressed(ctx, imgui.Key_Enter) or keyPressed(ctx, imgui.Key_KeypadEnter)) {
            runEntry(state.selected);
            return;
        }
    }
    if (keyPressed(ctx, imgui.Key_Escape)) close();
}

/// The selection after moving `step` rows (positive is down). It stops at
/// both ends instead of wrapping, so holding a key does not jump from the
/// last result to the first.
pub fn moveSelection(selected: usize, count: usize, step: i32) usize {
    if (count == 0) return 0;
    if (step > 0) return @min(selected + @as(usize, @intCast(step)), count - 1);
    return selected -| @as(usize, @intCast(-step));
}

/// The first or last row of a list of `count` rows.
pub fn edgeSelection(count: usize, last: bool) usize {
    if (count == 0 or !last) return 0;
    return count - 1;
}

/// How far PageUp and PageDown move: the rows that fit in the list, less one,
/// so that the row at the edge stays in view as the next page begins. It is
/// never below 1.
pub fn pageStep(visible_rows: usize) i32 {
    return @intCast(@max(visible_rows, 2) - 1);
}

test "moveSelection stops at both ends" {
    try std.testing.expectEqual(@as(usize, 1), moveSelection(0, 3, 1));
    try std.testing.expectEqual(@as(usize, 2), moveSelection(2, 3, 1));
    try std.testing.expectEqual(@as(usize, 0), moveSelection(0, 3, -1));
    try std.testing.expectEqual(@as(usize, 1), moveSelection(2, 3, -1));
    try std.testing.expectEqual(@as(usize, 0), moveSelection(0, 0, 1));
}

test "moveSelection moves by a page and stops at the ends" {
    try std.testing.expectEqual(@as(usize, 9), moveSelection(0, 50, 9));
    try std.testing.expectEqual(@as(usize, 49), moveSelection(45, 50, 9));
    try std.testing.expectEqual(@as(usize, 11), moveSelection(20, 50, -9));
    try std.testing.expectEqual(@as(usize, 0), moveSelection(3, 50, -9));
}

test "edgeSelection picks the first or last row" {
    try std.testing.expectEqual(@as(usize, 0), edgeSelection(5, false));
    try std.testing.expectEqual(@as(usize, 4), edgeSelection(5, true));
    try std.testing.expectEqual(@as(usize, 0), edgeSelection(0, true));
    try std.testing.expectEqual(@as(usize, 0), edgeSelection(1, true));
}

test "pageStep keeps one row of overlap and is never zero" {
    try std.testing.expectEqual(@as(i32, 9), pageStep(10));
    try std.testing.expectEqual(@as(i32, 1), pageStep(2));
    try std.testing.expectEqual(@as(i32, 1), pageStep(1));
    try std.testing.expectEqual(@as(i32, 1), pageStep(0));
}
