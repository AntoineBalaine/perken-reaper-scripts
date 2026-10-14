//! The action palette ("Perken: Search actions (palette)"): a ReaImGui window
//! with a text box and a fuzzy-matched list of every action in REAPER's main
//! section (extensions and scripts included). Typing narrows the list, Up and
//! Down (or Ctrl+P and Ctrl+N) move the selection, Enter or a click runs the
//! action, and Escape closes the window. It needs no terminal, so there is no
//! launcher script, no permission prompt and no files to exchange.
//!
//! The window is drawn from a timer that only runs while it is open. ReaImGui
//! is resolved on the first tick, because it may load after this extension.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const imgui = @import("reaper_imgui");
const actions = @import("actions.zig");
const action_search = @import("action_search.zig");
const fuzzy = @import("fuzzy.zig");

const log = std.log.scoped(.action_palette);

const MAX_RESULTS = 200;
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

    const section = action_search.mainSection() orelse {
        log.warn("REAPER has no main actions section", .{});
        return false;
    };
    var list = std.ArrayList(Entry).init(alloc);
    var idx: c_int = 0;
    while (idx < MAX_ACTIONS) : (idx += 1) {
        var name: ?[*:0]const u8 = null;
        const id = action_search.enumerateActions(section, idx, &name);
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
    }
    const ctx = state.ctx;
    imgui.api.SetNextWindowSize(ctx, 560, 400, &imgui.Cond_FirstUseEver);
    var is_open: bool = true;
    var flags: c_int = imgui.WindowFlags_NoSavedSettings | imgui.WindowFlags_NoCollapse;
    if (imgui.api.Begin(ctx, "Perken: search actions", &is_open, &flags)) drawContent(ctx);
    imgui.api.End(ctx);
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
    imgui.api.SetNextItemWidth(ctx, -1);
    var input_flags: c_int = imgui.InputTextFlags_None;
    _ = imgui.api.InputText(ctx, "##query", &state.query, state.query.len, &input_flags, null);

    if (!std.mem.eql(u8, std.mem.sliceTo(&state.query, 0), std.mem.sliceTo(&state.shown_query, 0))) refilter();

    handleKeys(ctx);

    var label_buf: [MAX_RESULTS_LABEL:0]u8 = undefined;
    var counter: [64:0]u8 = undefined;
    const counter_text = std.fmt.bufPrintZ(&counter, "{d} of {d} actions", .{ state.result_count, state.entries.len }) catch "";
    imgui.api.TextDisabled(ctx, counter_text);

    var chosen: ?usize = null;
    if (imgui.api.BeginChild(ctx, "##results", null, null, null, null)) {
        var i: usize = 0;
        while (i < state.result_count) : (i += 1) {
            const entry = state.entries[state.results[i].index];
            const label = std.fmt.bufPrintZ(&label_buf, "{s}##{d}", .{ entry.name, entry.id }) catch continue;
            var is_selected = i == state.selected;
            var sel_flags: c_int = imgui.SelectableFlags_None;
            if (imgui.api.Selectable(ctx, label, &is_selected, &sel_flags, null, null)) {
                state.selected = i;
                chosen = i;
            }
            if (i == state.selected and state.follow_selection) {
                imgui.api.SetScrollHereY(ctx, null);
                state.follow_selection = false;
            }
        }
    }
    imgui.api.EndChild(ctx);

    if (chosen) |c| runEntry(c);
}

const MAX_RESULTS_LABEL = 512;

/// Up/Down and Ctrl+P/Ctrl+N move the selection, Enter runs it, Escape closes.
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
        if (keyPressed(ctx, imgui.Key_Enter) or keyPressed(ctx, imgui.Key_KeypadEnter)) {
            runEntry(state.selected);
            return;
        }
    }
    if (keyPressed(ctx, imgui.Key_Escape)) close();
}

/// The selection after one step up or down. It stops at both ends instead of
/// wrapping, so holding a key does not jump from the last result to the first.
pub fn moveSelection(selected: usize, count: usize, step: i32) usize {
    if (count == 0) return 0;
    if (step > 0) return @min(selected + 1, count - 1);
    return if (selected > 0) selected - 1 else 0;
}

test "moveSelection stops at both ends" {
    try std.testing.expectEqual(@as(usize, 1), moveSelection(0, 3, 1));
    try std.testing.expectEqual(@as(usize, 2), moveSelection(2, 3, 1));
    try std.testing.expectEqual(@as(usize, 0), moveSelection(0, 3, -1));
    try std.testing.expectEqual(@as(usize, 1), moveSelection(2, 3, -1));
    try std.testing.expectEqual(@as(usize, 0), moveSelection(0, 0, 1));
}
