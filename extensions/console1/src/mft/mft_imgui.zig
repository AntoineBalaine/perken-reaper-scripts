const std = @import("std");
const i18n = @import("mft_i18n.zig");
const mft_globals = @import("mft_globals.zig");
const builtin = @import("builtin");
const imgui = @import("reaper_imgui");
const reaper = @import("reaper").reaper;
const MftGlobals = @import("mft_globals.zig").MftGlobals;
const mft_state = @import("mft_state.zig");
const MftActiveModule = mft_state.MftActiveModule;
const mappings = @import("mft_mappings.zig");
const MappableModule = mappings.MappableModule;
const mft_fx = @import("mft_fx.zig");
const mft_settings = @import("mft_settings.zig");
const theme = @import("panel_theme");
const panel_fonts = @import("panel_fonts");
const widgets = @import("panel_widgets");
const device = @import("mft_device.zig");
const mft_fxsel = @import("mft_fxsel.zig");
const browser_source = @import("mft_browser_source.zig");
const fx_browser = @import("fx_browser");
const colors = @import("mft_colors.zig");
const mft_port = @import("mft_port.zig");
const mft_auto = @import("mft_auto.zig");
const settings_rows = @import("mft_settings_rows.zig");
const mft_actions = @import("mft_actions.zig");
const map_store = @import("mft_map_store.zig");
const plugin_state = @import("mft_plugin_state.zig");
const rgba = @import("ui_palette").rgba;
const pi = std.math.pi;
const log = std.log.scoped(.mft_imgui);

const plugin_name = "MFT";

var ctx: imgui.ContextPtr = null;
var disabled = false;
var ready = false;
// The fonts belong to the ReaImGui context, and the kit's state (the heights its cards measured) to the window drawn
// in it, so both are made and dropped with the context.
var fonts: panel_fonts.Fonts = .{};
var kit: widgets.Panel = .{};
// The window of the FX Selection has its own kit state: the heights that the cards of a window measured belong to that window.
var fxsel_kit: widgets.Panel = .{};
// Whether the device is folded to its header row. Because the player folds the panel for the whole session, the state
// is kept when the context is dropped.
var folded = false;
// When each top encoder was last turned, so that the pop-up of its value can show for a moment after the turn.
var activity: Activity = .{};
// The formatted values of the knobs that show one, kept until the value changes.
var formatted_values: FormattedValues = .{};

const KnobInfo = device.KnobInfo;
const knob_count = mappings.knob_count;

fn moduleColor(globals: *MftGlobals, module: MftActiveModule) c_int {
    return colors.hueToRgb(globals.preferences.colorForModule(module));
}

/// How long the pop-up of a value stays after the last moment that its knob was hovered, held or turned, in
/// milliseconds. Because the pop-up must not flicker when the mouse crosses the gap between two knobs or a turn pauses,
/// it lingers for a short time.
pub const value_linger_ms: i64 = @import("mft_state.zig").linger_ms;

/// Remembers when each of the top encoders was last engaged, which is when the mouse was over it, it was held, or its
/// value changed. Because the panel mirrors the controller, a turn is only known by the value changing between two
/// frames.
pub const Activity = struct {
    last: [knob_count]f64 = @splat(0.0),
    engaged_at: [knob_count]i64 = @splat(never),
    module: ?MftActiveModule = null,
    track: reaper.MediaTrack = null,

    /// The time of an encoder that has never been engaged.
    pub const never: i64 = std.math.minInt(i64) / 2;
    /// The smallest change of a value that is a turn, and not the noise of a parameter that reports itself again.
    pub const threshold: f64 = 0.0005;

    /// Compares the values of this frame with those of the last one. `engaged` has a bit for each encoder that the
    /// mouse is over or that is held right now. Returns a bit for each mapped encoder that was engaged or turned less
    /// than `value_linger_ms` ago. Because a new module or a new track brings other values that nobody turned, the
    /// comparison starts again when either one changes.
    pub fn update(self: *Activity, module: MftActiveModule, track: reaper.MediaTrack, info: *const KnobInfo, engaged: u16, now_ms: i64) u16 {
        if (self.module != module or self.track != track) {
            self.module = module;
            self.track = track;
            self.last = info.vals;
            self.engaged_at = @splat(never);
        }
        var bits: u16 = 0;
        for (0..knob_count) |slot| {
            const turned = info.mapped[slot] and @abs(info.vals[slot] - self.last[slot]) > threshold;
            const bit = @as(u16, 1) << @intCast(slot);
            if (turned or engaged & bit != 0) self.engaged_at[slot] = now_ms;
            self.last[slot] = info.vals[slot];
            if (info.mapped[slot] and now_ms - self.engaged_at[slot] < value_linger_ms) bits |= bit;
        }
        return bits;
    }
};

/// Asks the plugin for the text of a parameter value, as REAPER displays it. Returns false when the plugin has none.
pub const FormatSource = *const fn (track: reaper.MediaTrack, fx: c_int, param: c_int, buf: *[formatted_len:0]u8) bool;

const formatted_len = device.formatted_len;

fn reaperFormat(track: reaper.MediaTrack, fx: c_int, param: c_int, buf: *[formatted_len:0]u8) bool {
    buf[0] = 0;
    return reaper.TrackFX_GetFormattedParamValue(track, fx, param, buf, formatted_len + 1);
}

/// The formatted values of the top encoders. Because formatting calls into the plugin, a value is asked for only when
/// its knob shows one, and again only when the value changed since it was asked. Owning the buffers here keeps them
/// out of the frame's data until the panel copies them in.
pub const FormattedValues = struct {
    bufs: [knob_count][formatted_len:0]u8 = undefined,
    ok: [knob_count]bool = @splat(false),
    asked_for: [knob_count]f64 = @splat(-1.0),
    module: ?MftActiveModule = null,
    track: reaper.MediaTrack = null,
    source: FormatSource = &reaperFormat,
    /// How many times the plugin was asked, which the tests count.
    asks: usize = 0,

    /// Fills the formatted values of `info` for the encoders in `wanted`, one bit each. An empty text or a failed call
    /// leaves the encoder with its percentage.
    pub fn fill(self: *FormattedValues, module: MftActiveModule, track: reaper.MediaTrack, info: *KnobInfo, wanted: u16) void {
        if (self.module != module or self.track != track) {
            self.module = module;
            self.track = track;
            self.ok = @splat(false);
            self.asked_for = @splat(-1.0);
        }
        const track_ptr = track orelse return;
        for (0..knob_count) |slot| {
            const bit = @as(u16, 1) << @intCast(slot);
            if (!info.mapped[slot] or info.is_action[slot] or wanted & bit == 0) continue;
            if (self.asked_for[slot] != info.vals[slot]) {
                self.asked_for[slot] = info.vals[slot];
                self.asks += 1;
                // A source that writes nothing must not leave the text of the last value behind.
                self.bufs[slot][0] = 0;
                self.ok[slot] = self.source(track_ptr, info.fx_index[slot], info.param[slot], &self.bufs[slot]) and self.bufs[slot][0] != 0;
            }
            if (self.ok[slot]) {
                info.formatted_bufs[slot] = self.bufs[slot];
                info.has_formatted[slot] = true;
            }
        }
    }
};

pub fn register() void {
    if (comptime builtin.is_test) return;
    _ = reaper.plugin_register("timer", @ptrCast(@constCast(&onTimer)));
}

fn onTimer() callconv(.c) void {
    if (disabled) return;
    // Skip the first tick so other extensions (ReaImGui) finish loading.
    if (!ready) {
        ready = true;
        return;
    }

    const globals = MftGlobals.get();

    // A ReaImGui context stays valid only while it is used every defer cycle (see
    // the CreateContext docs); one left unused is garbage-collected. Hiding the
    // panel by skipping Begin therefore leaves `ctx` pointing at a reclaimed
    // context, so the next Begin on re-show errors on every frame. So we drop our
    // handle while hidden and let onTimer recreate a fresh context on re-show.
    if (!globals.mft.panel_visible) {
        dropContext();
        return;
    }

    if (ctx == null) {
        imgui.init(reaper.plugin_getapi) catch {
            log.err("ReaImGui not available; disabling MFT panel", .{});
            disabled = true;
            _ = reaper.plugin_register("-timer", @ptrCast(@constCast(&onTimer)));
            return;
        };
        ctx = imgui.CreateContext(.{plugin_name}) catch {
            disabled = true;
            return;
        };
        // ReaImGui needs every font attached before the context's first frame.
        fonts = panel_fonts.create(ctx);
        kit = .{};
    }
    drawWindows(globals) catch |err| {
        log.err("MFT panel draw error: {s}", .{@errorName(err)});
        if (imgui.last_error) |msg| log.err("imgui: {s}", .{std.mem.span(msg)});
        // Because ReaImGui destroys a context after an ImGui assertion fails, our
        // handle may now be dangling. We drop it so that the next tick creates a
        // fresh context instead of failing on every frame.
        dropContext();
    };
}

/// The window of the device and, while the FX SEL mode is open, the window of the mode.
fn drawWindows(globals: *MftGlobals) !void {
    // The windows are drawn in the language of the settings, which can change at any time.
    i18n.language = globals.preferences.language;
    try draw(globals);
    try drawFxSelWindow(globals);
    try drawMappingWindow(globals);
    try drawSettingsWindow(globals);
}

// The window of the settings has its own kit state, as the other windows do.
var settings_kit: widgets.Panel = .{};

/// The window of the SETTINGS page, which is a window of its own, as the mapping panel is, and is shown while the page is in use.
fn drawSettingsWindow(globals: *MftGlobals) !void {
    if (globals.mft.active_module != .SETTINGS or globals.mft.fxsel != null) return;
    settings_kit.ctx = ctx;
    settings_kit.fonts = fonts;
    theme.push(ctx);
    defer theme.pop(ctx);
    if (fonts.text != null) imgui.api.PushFont(ctx, fonts.text);
    defer if (fonts.text != null) imgui.api.PopFont(ctx);
    imgui.api.SetNextWindowPos(ctx, fxsel_window_x, window_y, &imgui.Cond_FirstUseEver, null, null);
    imgui.api.SetNextWindowSize(ctx, 1200, 760, &imgui.Cond_FirstUseEver);
    theme.pushVar2(ctx, imgui.StyleVar_WindowPadding, 16, 16);
    const flags: c_int = imgui.WindowFlags_NoCollapse | imgui.WindowFlags_NoTitleBar;
    const visible = try imgui.Begin(.{ ctx, "MFT Settings", null, flags });
    var window_vars: c_int = 1;
    imgui.api.PopStyleVar(ctx, &window_vars);
    if (!visible) return;
    defer imgui.End(.{ctx}) catch {};
    try mft_settings.drawPanel(&settings_kit, globals, moduleColor(globals, .SETTINGS));
}

// Forgets the context and what was made in it: the fonts and the kit's state belong to it.
fn dropContext() void {
    ctx = null;
    fonts = .{};
    kit = .{};
    fxsel_kit = .{};
    settings_kit = .{};
}

/// Where the window opens the first time, in pixels from the top left of the screen.
const window_x: f64 = 80;
const window_y: f64 = 60;
/// The roundness of the window's corners, which is the roundness of the device's body, so that the body fills the window
/// to its edges.
const window_rounding: f64 = 16;

fn draw(globals: *MftGlobals) !void {
    const io = mft_globals.hostIo();
    // Only called while the panel is visible: onTimer owns the hide/show cycle by
    // dropping the context when hidden, so draw always submits the window.
    kit.ctx = ctx;
    kit.fonts = fonts;

    // The palette and style of the shared panel kit go around the whole window, and so does the text font.
    theme.push(ctx);
    defer theme.pop(ctx);
    if (fonts.text != null) imgui.api.PushFont(ctx, fonts.text);
    defer if (fonts.text != null) imgui.api.PopFont(ctx);

    // The window has no title bar, because the device has its own close and fold buttons, and the window moves when
    // the mouse drags an empty part of it. It sizes itself to what the panel shows, so that folding the device shrinks
    // the window.
    imgui.api.SetNextWindowPos(ctx, window_x, window_y, &imgui.Cond_FirstUseEver, null, null);
    const flags: c_int = imgui.WindowFlags_NoCollapse | imgui.WindowFlags_NoTitleBar | imgui.WindowFlags_AlwaysAutoResize;
    // The device fills the window to its edges: while the window begins, it has no padding and no border, and its
    // corners are rounded like the body's. Because the window keeps what it read when it began, the style is popped
    // right after `Begin`, and the cards inside the window have their own padding and corners.
    theme.pushVar2(ctx, imgui.StyleVar_WindowPadding, 0, 0);
    theme.pushVar(ctx, imgui.StyleVar_WindowBorderSize, 0);
    theme.pushVar(ctx, imgui.StyleVar_WindowRounding, window_rounding);
    const visible = try imgui.Begin(.{ ctx, plugin_name, null, flags });
    var window_vars: c_int = 3;
    imgui.api.PopStyleVar(ctx, &window_vars);
    if (!visible) return;
    defer imgui.End(.{ctx}) catch {};

    const active = globals.mft.active_module;
    std.debug.assert(moduleColor(globals, active) != 0);
    var view = readView(globals);
    const now_ms = std.Io.Timestamp.now(io, .awake).toMilliseconds();
    for (0..8) |i| {
        const bit = @as(u8, 1) << @intCast(i);
        if (globals.mft.activity.turnLit(i, now_ms)) view.turn_lit |= bit;
        if (globals.mft.activity.pressLit(i, now_ms)) view.press_lit |= bit;
    }
    for (0..3) |i| view.left_lit[i] = globals.mft.activity.sideLit(i, now_ms);
    // The key that bypasses is lit while the plugin of the page is bypassed, and not while it is pressed.
    if (MappableModule.fromActive(active)) |module| {
        view.left_lit[1] = if (globals.current_track) |track| mft_fx.moduleBypassed(track, module) else false;
    }
    // The pop-ups of the values follow the mouse and the held encoders, and linger for a moment after them.
    // A held knob that has a push is not engaged: the click that follows shows what the push changed, and a turn still shows the value.
    var push_bits: u16 = 0;
    for (0..mappings.push_count) |i| {
        if (view.knobs.push_mapped[i]) push_bits |= @as(u16, 1) << @intCast(i);
    }
    const engaged = device.hoveredKnobs(&kit, widgets.cursorScreenPos(&kit), &view) | (view.held & ~push_bits);
    const note = &globals.mft.push_note;
    if (note.lit(now_ms)) view.push_note = .{ .encoder = note.encoder, .text = note.text };
    view.show_value = activity.update(active, globals.current_track, &view.knobs, engaged, now_ms);
    // Only the knobs whose pop-up shows ask the plugin for the text of their value.
    formatted_values.fill(active, globals.current_track, &view.knobs, view.show_value);
    const response = device.draw(&kit, &view);
    if (response.close) globals.mft.panel_visible = false;
    if (response.fold) folded = !folded;

    // The settings have a window of their own; otherwise the buffers stay synced from the preferences for the next time it is opened.
    if (active != .SETTINGS) mft_settings.markUnsynced();
}

/// Where the window of the FX Selection opens the first time, to the right of the device, and how big it is.
const fxsel_window_x: f64 = window_x + 640;
const fxsel_window_w: f64 = 480;
/// The padding of the window. The cards are as wide as the window lets them be, all alike, and take the height that is left, so that the window can be
/// resized and the cards follow; the window opens at the size that holds the two cards of the first level.
const fxsel_padding: f64 = 6;

/// The height of a card that shows `rows` rows of text: its title, its rows, and its edges. Because the card has a height of its own, its size does not
/// change with the entries that it holds.
fn fxselCardHeight(line_height: f64, rows: usize) f64 {
    return line_height * (@as(f64, @floatFromInt(rows)) + 1.7) + 18;
}

/// The height that the window opens at, which holds the search, the line of menus, and the two cards of the first level.
fn fxselWindowHeight(line_height: f64, menu_count: usize) f64 {
    const mapped_rows = fxsel_rows - menu_count;
    return line_height * 2 + 12 + fxselCardHeight(line_height, mapped_rows) + fxselCardHeight(line_height, menu_count) + 2 * 8 + 2 * fxsel_padding + 24;
}

/// How many rows of a list show at a time when the window has its default size. The cursor stays in the middle when the list is longer.
const fxsel_rows: usize = 12;

/// How many rows a card of the height `height` shows, and how many the last drawn list showed, which the page keys move the cursor by.
fn fxselRowsFor(line_height: f64, height: f64) usize {
    const rows = (height - line_height * 1.7 - 18) / line_height;
    return @max(1, @as(usize, @intFromFloat(@max(rows, 1))));
}

var fxsel_page_rows: usize = fxsel_rows;

/// A browser source that has nothing in it, for the screens that are not the browser but share its click, which does not read it.
const null_source: fx_browser.Source = undefined;

/// The path of the menus that are open, as a line of names.
fn fxSelBreadcrumb(buf: [:0]u8, state: *const mft_fxsel.FxSelState, source: fx_browser.Source) [:0]const u8 {
    var length: usize = 0;
    buf[0] = 0;
    // The first name is the module, as in the window of the Console 1.
    const module_name = @tagName(state.module);
    @memcpy(buf[0..module_name.len], module_name);
    length = module_name.len;
    var level: fx_browser.Level = .root;
    for (state.browse_path[0..state.browse_depth]) |index| {
        const text = mft_fxsel.entryName(state, source, level, index);
        const written = std.fmt.bufPrint(buf[length .. buf.len - 1], "  >  {s}", .{text}) catch break;
        length += written.len;
        level = fx_browser.enter(source, level, index) orelse break;
    }
    buf[length] = 0;
    return buf[0..length :0];
}

/// The search field of the browser: it takes the keyboard when the browser opens, so that what is typed goes in it right away, and it has a hint
/// while it is empty.
fn drawFxSelSearch(state: *mft_fxsel.FxSelState) !void {
    // Because what is typed in the window is always meant for the search, the field takes the keyboard on every frame that the window has the focus, so
    // that a click elsewhere in the window does not stop the typing.
    if (state.focus_search or imgui.api.IsWindowFocused(ctx, null)) {
        try imgui.SetKeyboardFocusHere(.{ctx});
        state.focus_search = false;
    }
    try imgui.SetNextItemWidth(.{ ctx, 240 });
    _ = try imgui.InputText(.{ ctx, "##fxsel_search", @as([*]u8, @ptrCast(&state.search)), state.search.len, null, null });
    const active = try imgui.IsItemActive(.{ctx});
    state.syncSearch();
    if (state.search[0] == 0 and !active) {
        var x1: f64 = undefined;
        var y1: f64 = undefined;
        var x2: f64 = undefined;
        var y2: f64 = undefined;
        try imgui.GetItemRectMin(.{ ctx, &x1, &y1 });
        try imgui.GetItemRectMax(.{ ctx, &x2, &y2 });
        const hint = i18n.t("Type to search");
        var hint_w: f64 = undefined;
        var hint_h: f64 = undefined;
        try imgui.CalcTextSize(.{ ctx, hint, &hint_w, &hint_h });
        const dl = try imgui.GetWindowDrawList(.{ctx});
        try imgui.DrawList_AddText(.{ dl, x1 + 8, (y1 + y2) / 2 - hint_h / 2, theme.text_dim, hint });
    }
}

/// What the keys of the computer do in the window, as the controller does: the arrows move the cursor by one entry and the page keys by a page,
/// Enter chooses the entry, and Escape steps back.
fn fxSelKeys(state: *mft_fxsel.FxSelState, source: ?fx_browser.Source) !mft_fxsel.Outcome {
    const page: i32 = @intCast(@max(fxsel_page_rows, 2) - 1);
    if (try imgui.IsKeyPressed(.{ ctx, imgui.Key_DownArrow })) mft_fxsel.moveCursor(state, 1, source);
    if (try imgui.IsKeyPressed(.{ ctx, imgui.Key_UpArrow })) mft_fxsel.moveCursor(state, -1, source);
    if (try imgui.IsKeyPressed(.{ ctx, imgui.Key_PageDown })) mft_fxsel.moveCursor(state, page, source);
    if (try imgui.IsKeyPressed(.{ ctx, imgui.Key_PageUp })) mft_fxsel.moveCursor(state, -page, source);
    if (try imgui.IsKeyPressed(.{ ctx, imgui.Key_Enter }) or try imgui.IsKeyPressed(.{ ctx, imgui.Key_KeypadEnter })) return mft_fxsel.press(state, mft_fxsel.list_encoder, source);
    if (try imgui.IsKeyPressed(.{ ctx, imgui.Key_Escape })) return mft_fxsel.press(state, mft_fxsel.cancel_encoder, source);
    return .none;
}

/// The rows of a list that show: the window of `fxsel_rows` entries that has the cursor in the middle, or the start of the list when the cursor is
/// not in it.
const RowRange = struct { first: usize, last: usize };

fn rowRange(cursor: ?usize, count: usize, rows: usize) RowRange {
    const middle = cursor orelse 0;
    const first = if (cursor == null or middle < rows / 2) 0 else @min(middle - rows / 2, count -| rows);
    return .{ .first = first, .last = @min(count, first + rows) };
}

/// One row of a list: the entry that the cursor is on has the color of the module and an arrow before it, the others are in the bright of the text, and a
/// menu has an arrow after it. It returns whether the row was clicked.
fn drawFxSelRow(label: [:0]const u8, index: usize, is_menu: bool, is_cursor: bool, accent: c_int) !bool {
    var buf: [220:0]u8 = undefined;
    const text = std.mem.printSentinel(&buf, "{s} {s}{s}##row{d}", .{ if (is_cursor) ">" else " ", label, if (is_menu) "  >" else "", index }, 0) catch return false;
    try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, if (is_cursor) accent else theme.text });
    defer imgui.PopStyleColor(.{ ctx, 1 }) catch {};
    return try imgui.Selectable(.{ ctx, text });
}

/// What the Default key of a row makes the default: the plugin of the module, or the map of the plugin.
const DefaultOf = enum { plugin, map };

/// What a click on the row of a plugin did: nothing, a click on the row, or a click on its Default key.
const PluginRowClick = enum { none, row, default };

/// The width of the Default key on the right of the row of a plugin, and the gap before it.
const default_key_w: f64 = 74;
const default_key_gap: f64 = 6;

/// The row of a plugin in the browser: the row itself, which loads the plugin, and a key on its right that makes the plugin the default of the module. The
/// key of the default plugin is lit and has a check, so that the default is seen in the list.
fn drawFxSelPluginRow(label: [:0]const u8, index: usize, is_cursor: bool, accent: c_int, is_default: bool, what: DefaultOf) !PluginRowClick {
    var avail_w: f64 = undefined;
    var avail_h: f64 = undefined;
    imgui.api.GetContentRegionAvail(ctx, &avail_w, &avail_h);
    var buf: [220:0]u8 = undefined;
    const text = std.mem.printSentinel(&buf, "{s} {s}##row{d}", .{ if (is_cursor) ">" else " ", label, index }, 0) catch return .none;
    imgui.api.PushStyleColor(ctx, imgui.Col_Text, if (is_cursor) accent else theme.text);
    var row_w = @max(avail_w - default_key_w - default_key_gap, 40);
    var row_h: f64 = 0;
    const row_clicked = imgui.api.Selectable(ctx, text, null, null, &row_w, &row_h);
    var pushed_colors: c_int = 1;
    imgui.api.PopStyleColor(ctx, &pushed_colors);
    var y_min: f64 = undefined;
    var y_max: f64 = undefined;
    var x_unused: f64 = undefined;
    imgui.api.GetItemRectMin(ctx, &x_unused, &y_min);
    imgui.api.GetItemRectMax(ctx, &x_unused, &y_max);
    var gap = default_key_gap;
    imgui.api.SameLine(ctx, null, &gap);
    var key_buf: [32:0]u8 = undefined;
    const key_id = std.mem.printSentinel(&key_buf, "##default{d}", .{index}, 0) catch return .none;
    const at = widgets.cursorScreenPos(&fxsel_kit);
    const key_clicked = imgui.api.InvisibleButton(ctx, key_id, default_key_w, y_max - y_min, null);
    const hovered = imgui.api.IsItemHovered(ctx, null);
    const dl = imgui.api.GetWindowDrawList(ctx);
    const top = at.y + 1;
    const bottom = at.y + (y_max - y_min) - 1;
    const right = at.x + default_key_w;
    widgets.rectFilled(dl, at.x, top, right, bottom, if (is_default) widgets.faded(accent, 0x55) else theme.slot_bg, 4);
    widgets.rect(dl, at.x, top, right, bottom, if (hovered or is_default) accent else theme.slot_edge, 4, 1);
    const word: [:0]const u8 = i18n.t("Default");
    const size = widgets.textSize(&fxsel_kit, word);
    const check_w: f64 = if (is_default) 12 else 0;
    const text_x = at.x + (default_key_w - size.w - check_w) / 2 + check_w;
    const middle = (top + bottom) / 2;
    const ink = if (is_default) theme.text else theme.text_dim;
    if (is_default) {
        // Because the check is drawn with two lines, it does not depend on the font having the glyph.
        const check_x = text_x - check_w;
        widgets.line(dl, check_x, middle, check_x + 3, middle + 3.5, ink, 1.6);
        widgets.line(dl, check_x + 3, middle + 3.5, check_x + 8, middle - 3.5, ink, 1.6);
    }
    imgui.api.DrawList_AddText(dl, text_x, middle - size.h / 2, ink, word);
    if (hovered) widgets.tooltip(&fxsel_kit, switch (what) {
        .plugin => if (is_default) i18n.t("This is the default plugin of the module.") else i18n.t("Make this plugin the default of the module: a module button inserts it on a track that has none."),
        .map => if (is_default) i18n.t("This is the default map of the plugin.") else i18n.t("Make this map the default of the plugin: the plugin is loaded with it from now on."),
    });
    if (key_clicked) return .default;
    return if (row_clicked) .row else .none;
}

/// The outcome of a click on the row of a plugin: the row is the click of an entry, and the key makes the plugin the default.
fn pluginRowOutcome(click: PluginRowClick, state: *mft_fxsel.FxSelState, index: usize, name: [:0]const u8, source: fx_browser.Source) mft_fxsel.Outcome {
    return switch (click) {
        .none => .none,
        .row => mft_fxsel.clickEntry(state, index, source),
        .default => .{ .set_default_plugin = name },
    };
}

/// The card of the first screen, which has the actions that can be done to the module.
fn drawFxSelActions(k: *widgets.Panel, state: *mft_fxsel.FxSelState, accent: c_int, title: [:0]const u8, line_height: f64, card_w: f64) !mft_fxsel.Outcome {
    var outcome: mft_fxsel.Outcome = .none;
    // The label of the window is the title of the card, in the color of the module.
    if (!widgets.beginCard(k, title, card_w, fxselCardHeight(line_height, mft_fxsel.action_count), accent)) return outcome;
    defer widgets.endCard(k);
    inline for (@typeInfo(mft_fxsel.Action).@"enum".field_names, 0..) |_, i| {
        const action: mft_fxsel.Action = @fromBackingInt(@intCast(i));
        if (try drawFxSelRow(action.label(), i, false, state.action_cursor == i, accent)) {
            state.action_cursor = @intCast(i);
            outcome = mft_fxsel.press(state, mft_fxsel.list_encoder, null);
        }
    }
    return outcome;
}

/// The contents of the browser: the cards of the level that is open, or the results of the search.
fn drawFxSelBrowser(k: *widgets.Panel, state: *mft_fxsel.FxSelState, source: fx_browser.Source, default_plugin: []const u8, accent: c_int, line_height: f64, card_w: f64, room: f64) !mft_fxsel.Outcome {
    var outcome: mft_fxsel.Outcome = .none;
    // A card that holds one list takes all the height that is left, and shows the rows that fit in it.
    const list_height = @max(room, fxselCardHeight(line_height, 3));
    const list_rows = fxselRowsFor(line_height, list_height);
    fxsel_page_rows = list_rows;
    if (state.searching()) {
        // The results take the place of the cards: the plugins of every type that match what was typed, the best first.
        var hits: [fx_browser.search_capacity]@import("fuzzy").Ranked = undefined;
        const count = fx_browser.search(source, state.searchText(), &hits);
        state.search_cursor = @min(state.search_cursor, @as(u16, @intCast(count -| 1)));
        if (!widgets.beginCard(k, i18n.t("Results"), card_w, list_height, accent)) return outcome;
        defer widgets.endCard(k);
        if (count == 0) try imgui.Text(.{ ctx, i18n.t("No plugin matches.") });
        const range = rowRange(state.search_cursor, count, list_rows);
        for (range.first..range.last) |i| {
            const name = fx_browser.pluginAt(source, hits[i].index) orelse continue;
            const click = try drawFxSelPluginRow(name, i, i == state.search_cursor, accent, std.mem.eql(u8, name, default_plugin), .plugin);
            if (click != .none) outcome = pluginRowOutcome(click, state, i, name, source);
        }
        return outcome;
    }
    const level = state.level(source);
    switch (level) {
        .root => {
            // The plugins that have a map are in one card, and the menus of the browser in another.
            const menu_count = fx_browser.rootMenuCount(source);
            const cursor: usize = state.cursor();
            // Both cards are as wide as the window, and have the height of their rows, so that the window holds them without being resized.
            // The menus have the height of their rows, and the plugins that have a map take what is left.
            const menus_height = fxselCardHeight(line_height, menu_count);
            const mapped_height = @max(room - menus_height - 8, fxselCardHeight(line_height, 3));
            const mapped_rows = fxselRowsFor(line_height, mapped_height);
            fxsel_page_rows = mapped_rows;
            if (widgets.beginCard(k, if (state.strip_target) i18n.t("Channel strips with a map") else i18n.t("Mapped plugins"), card_w, mapped_height, accent)) {
                defer widgets.endCard(k);
                if (state.browser.count == 0) try imgui.Text(.{ ctx, i18n.t("No plugin has a map for this module.") });
                const range = rowRange(if (cursor < state.browser.count) cursor else null, state.browser.count, mapped_rows);
                for (range.first..range.last) |i| {
                    const name = state.browser.get(i);
                    const click = try drawFxSelPluginRow(name, i, cursor == i, accent, std.mem.eql(u8, name, default_plugin), .plugin);
                    if (click != .none) outcome = pluginRowOutcome(click, state, i, name, source);
                }
            }
            if (widgets.beginCard(k, i18n.t("Browse"), card_w, menus_height, accent)) {
                defer widgets.endCard(k);
                var listed: usize = 0;
                for (std.enums.values(fx_browser.RootMenu)) |menu| {
                    if (source.hidden_menus.contains(menu)) continue;
                    const index = source.mapped_count + listed;
                    listed += 1;
                    if (try drawFxSelRow(mft_fxsel.rootMenuName(menu), index, fx_browser.isMenu(source, level, index), cursor == index, accent)) {
                        outcome = mft_fxsel.clickEntry(state, index, source);
                    }
                }
            }
        },
        else => {
            // The card is named after the menu that is open, which is the last name of the line of menus.
            var crumb_buf: [512:0]u8 = undefined;
            const crumb = fxSelBreadcrumb(&crumb_buf, state, source);
            var title_buf: [128:0]u8 = undefined;
            const last = if (std.mem.lastIndexOf(u8, crumb, "  >  ")) |at| crumb[at + 5 ..] else crumb;
            const title = std.mem.printSentinel(&title_buf, "{s}", .{last}, 0) catch i18n.t("Plugins");
            if (!widgets.beginCard(k, title, card_w, list_height, accent)) return outcome;
            defer widgets.endCard(k);
            const count = fx_browser.entryCount(source, level);
            if (count == 0) try imgui.Text(.{ ctx, i18n.t("Nothing in this list.") });
            const cursor: usize = state.cursor();
            const menus_end = fx_browser.leafStart(level);
            const range = rowRange(cursor, count, list_rows);
            for (range.first..range.last) |index| {
                const label = fx_browser.entryName(source, level, index) orelse continue;
                if (index < menus_end) {
                    if (try drawFxSelRow(label, index, true, cursor == index, accent)) outcome = mft_fxsel.clickEntry(state, index, source);
                    continue;
                }
                const click = try drawFxSelPluginRow(label, index, cursor == index, accent, std.mem.eql(u8, label, default_plugin), .plugin);
                if (click != .none) outcome = pluginRowOutcome(click, state, index, label, source);
            }
        },
    }
    return outcome;
}

/// The card of the maps of the plugin that was chosen in the browser: a click on a map loads the plugin with it, and its Default key makes it the map that
/// the plugin is loaded with from now on.
fn drawFxSelMaps(k: *widgets.Panel, state: *mft_fxsel.FxSelState, default_map: []const u8, accent: c_int, line_height: f64, card_w: f64, room: f64) !mft_fxsel.Outcome {
    var outcome: mft_fxsel.Outcome = .none;
    const height = @max(room, fxselCardHeight(line_height, 3));
    const rows = fxselRowsFor(line_height, height);
    fxsel_page_rows = rows;
    var title_buf: [200:0]u8 = undefined;
    const title = i18n.print(&title_buf, "Maps of {s}", .{state.mapsPlugin()}) catch i18n.t("Maps");
    if (!widgets.beginCard(k, title, card_w, height, accent)) return outcome;
    defer widgets.endCard(k);
    const cursor: usize = state.maps_cursor;
    const range = rowRange(cursor, state.maps.count, rows);
    for (range.first..range.last) |i| {
        const name = state.maps.get(i);
        switch (try drawFxSelPluginRow(name, i, cursor == i, accent, std.mem.eql(u8, name, default_map), .map)) {
            .none => {},
            .row => outcome = mft_fxsel.clickEntry(state, i, null_source),
            .default => outcome = .{ .set_default_map = name },
        }
    }
    return outcome;
}

/// The card of the presets of the plugin of the module, which the cursor scrolls and a click or a press loads.
fn drawFxSelPresets(k: *widgets.Panel, state: *mft_fxsel.FxSelState, accent: c_int, line_height: f64, card_w: f64, room: f64) !mft_fxsel.Outcome {
    var outcome: mft_fxsel.Outcome = .none;
    const height = @max(room, fxselCardHeight(line_height, 3));
    const rows = fxselRowsFor(line_height, height);
    fxsel_page_rows = rows;
    if (!widgets.beginCard(k, i18n.t("Presets"), card_w, height, accent)) return outcome;
    defer widgets.endCard(k);
    if (state.presets.count == 0) try imgui.Text(.{ ctx, i18n.t("This plugin has no presets saved.") });
    const cursor: usize = state.preset_cursor;
    const range = rowRange(cursor, state.presets.count, rows);
    for (range.first..range.last) |i| {
        if (try drawFxSelRow(state.presets.get(i), i, false, cursor == i, accent)) outcome = mft_fxsel.clickEntry(state, i, null_source);
    }
    return outcome;
}

/// The field for the name of a preset, which takes the typing while the window has the focus, and the presets that exist, so that a name can be
/// chosen that is not taken.
fn drawFxSelSave(k: *widgets.Panel, state: *mft_fxsel.FxSelState, accent: c_int, line_height: f64, card_w: f64, room: f64) !void {
    if (state.focus_search or imgui.api.IsWindowFocused(ctx, null)) {
        try imgui.SetKeyboardFocusHere(.{ctx});
        state.focus_search = false;
    }
    try imgui.SetNextItemWidth(.{ ctx, 240 });
    _ = try imgui.InputText(.{ ctx, "##fxsel_save", @as([*]u8, @ptrCast(&state.save_name)), state.save_name.len, null, null });
    if (state.save_name[0] == 0 and !try imgui.IsItemActive(.{ctx})) {
        var x1: f64 = undefined;
        var y1: f64 = undefined;
        var x2: f64 = undefined;
        var y2: f64 = undefined;
        try imgui.GetItemRectMin(.{ ctx, &x1, &y1 });
        try imgui.GetItemRectMax(.{ ctx, &x2, &y2 });
        const dl = try imgui.GetWindowDrawList(.{ctx});
        try imgui.DrawList_AddText(.{ dl, x1 + 8, y1 + 3, theme.text_dim, i18n.t("Name of the preset, then Enter") });
    }
    const height = @max(room - line_height * 1.5, fxselCardHeight(line_height, 3));
    const rows = fxselRowsFor(line_height, height);
    if (!widgets.beginCard(k, i18n.t("Presets that exist"), card_w, height, accent)) return;
    defer widgets.endCard(k);
    if (state.presets.count == 0) try imgui.Text(.{ ctx, i18n.t("None yet.") });
    for (0..@min(state.presets.count, rows)) |i| {
        try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, theme.text });
        try imgui.Text(.{ ctx, state.presets.get(i) });
        try imgui.PopStyleColor(.{ ctx, 1 });
    }
}

// ---- the mapping panel ----
//
// The window that the mapping mode draws, as the mock of the design has it: one panel for all the modules at once, with a bar of keys at the left, a plate
// for each module under the line of its plugin, and the card of the assignments. A plate has the layout of the controller, its sixteen encoders in four rows,
// each drawn as the device draws it with the window under it that has a combo for the knob and a combo for the push, so that every control of every module
// can be mapped at any time. The mapping of a module is saved as soon as it changes, and a save that fails leaves a mark on the plate.

/// The geometry of a cell of a plate, from the mock: the encoder is 58 pixels, and the cell 88 wide.
const map_cell_w: f64 = 88;
const map_cell_gap: f64 = 4;
const map_enc: f64 = 58;
const map_win_h: f64 = 44;
/// The radius of the well of an encoder drawn at the size of the plates: the well of the device (30) at the scale of the mock's encoder.
const map_well_r: f64 = 30 * map_enc / 80.0;

/// Where the parts of a cell are, from its top: the center of the encoder, and the window under its well.
const MapCellLayout = struct {
    enc_cy: f64,
    win_y: f64,
    height: f64,
};

fn mapCellLayout() MapCellLayout {
    const enc_cy = 2 + map_enc / 2;
    // The window sits a little under the well of the encoder.
    const win_y = enc_cy + map_well_r + 5;
    return .{ .enc_cy = enc_cy, .win_y = win_y, .height = win_y + map_win_h + 8 };
}
const map_grid_w: f64 = 4 * map_cell_w + 3 * map_cell_gap;
const map_plate_w: f64 = map_grid_w + 28;

/// The titles of the plates, which are the names that the modules have on the panel of the Console 1.
fn mapTitle(module: mft_fxsel.MappableModule) [:0]const u8 {
    return switch (module) {
        .INPUT => i18n.t("Input"),
        .GATE => i18n.t("Shape"),
        .EQ => i18n.t("Equalizer"),
        .COMP => i18n.t("Compressor"),
        .OUTPUT => i18n.t("Output"),
    };
}

/// The name of a parameter of an FX, or its number when REAPER gives no name.
fn paramLabel(track: reaper.MediaTrack, fx: c_int, param: u16, buf: *[96:0]u8) [:0]const u8 {
    if (param == mappings.wet_param) return i18n.t("Dry/Wet");
    var name: [64:0]u8 = undefined;
    name[0] = 0;
    if (track != null and reaper.TrackFX_GetParamName(track, fx, param, &name, 64) and name[0] != 0) {
        return std.mem.printSentinel(buf, "{d}: {s}", .{ param, std.mem.sliceTo(&name, 0) }, 0) catch "?";
    }
    return std.mem.printSentinel(buf, "{d}", .{param}, 0) catch "?";
}

/// Whether Alt is held, which turns a click on a combo of the mapping panel into the removal of its mapping.
fn altHeld() bool {
    return imgui.api.IsKeyDown(ctx, imgui.Mod_Alt);
}

/// The combo of a control while Alt is held: it has the same text, and a click takes the mapping of the control away instead of opening the list. It returns
/// whether it was clicked.
fn altClearRow(id: [:0]const u8, full: [:0]const u8, width: f64) bool {
    var fit_buf: [96:0]u8 = undefined;
    const preview = device.fitText(&fxsel_kit, full, width - 6, &fit_buf);
    var label_buf: [200:0]u8 = undefined;
    const label = std.mem.printSentinel(&label_buf, "{s}##alt{s}", .{ preview, id }, 0) catch return false;
    var w = width;
    var h: f64 = 0;
    const clicked = imgui.api.Selectable(ctx, label, null, null, &w, &h);
    if (imgui.api.IsItemHovered(ctx, null)) widgets.tooltip(&fxsel_kit, i18n.t("Alt-click removes this mapping"));
    return clicked;
}

/// The combo of a control while the MIDI learn is on: it has the same text, a click selects the control (the knob on the turn line, the push on the press
/// line) instead of opening the list, so that the parameter that is moved next goes to it, and the line of the control that is selected is lit. It
/// returns whether it was clicked.
fn learnSelectRow(id: [:0]const u8, full: [:0]const u8, width: f64, selected: bool) bool {
    var fit_buf: [96:0]u8 = undefined;
    const preview = device.fitText(&fxsel_kit, full, width - 6, &fit_buf);
    var label_buf: [200:0]u8 = undefined;
    const label = std.mem.printSentinel(&label_buf, "{s}##learn{s}", .{ preview, id }, 0) catch return false;
    var lit = selected;
    var w = width;
    var h: f64 = 0;
    const clicked = imgui.api.Selectable(ctx, label, &lit, null, &w, &h);
    if (imgui.api.IsItemHovered(ctx, null)) widgets.tooltip(&fxsel_kit, i18n.t("Click to choose this control, then move a parameter in the plugin"));
    return clicked;
}

/// A combo that has no frame and no arrow, as the combos in the windows of the mock are: its text is the parameter that the control has, or a dash.
/// Choosing a parameter puts the control in focus and gives it the parameter. It returns whether the mapping changed.
fn drawMapCombo(state: *mft_fxsel.FxSelState, track: reaper.MediaTrack, module: mft_fxsel.MappableModule, control: usize, x: f64, y: f64, width: f64) !bool {
    const mi = mft_fxsel.moduleIndex(module);
    const fx = mft_fxsel.mapFx(state, module);
    var id: [32:0]u8 = undefined;
    _ = std.mem.printSentinel(&id, "##map{d}_{d}", .{ mi, control }, 0) catch return false;
    var param_buf: [96:0]u8 = undefined;
    const param = mft_fxsel.controlParam(state, module, control);
    const param_text: [:0]const u8 = if (param) |p| paramLabel(track, fx, p, &param_buf) else "-";
    // A control that the user named shows its name, in amber, and its parameter in its tooltip.
    const plate: mft_fxsel.NamedPlate = .{ .module = module };
    const custom = mft_fxsel.namesOf(state, plate).get(control);
    const preview: [:0]const u8 = custom orelse param_text;
    imgui.api.SetCursorScreenPos(ctx, x, y);
    imgui.api.PushStyleColor(ctx, imgui.Col_FrameBg, 0);
    imgui.api.PushStyleColor(ctx, imgui.Col_FrameBgHovered, theme.amber_soft);
    imgui.api.PushStyleColor(ctx, imgui.Col_FrameBgActive, theme.amber_soft);
    imgui.api.PushStyleColor(ctx, imgui.Col_Text, if (custom != null) theme.amber else if (param != null) theme.label else theme.text_dim);
    theme.pushVar2(ctx, imgui.StyleVar_FramePadding, 2, 0);
    defer {
        var vars: c_int = 1;
        imgui.api.PopStyleVar(ctx, &vars);
        var colors_pushed: c_int = 4;
        imgui.api.PopStyleColor(ctx, &colors_pushed);
    }
    if (altHeld()) {
        if (!altClearRow(&id, preview, width)) return false;
        mft_fxsel.selectControl(state, module, control);
        mft_fxsel.assign(state, null);
        return true;
    }
    if (state.map_learn) {
        const selected = !state.map_focus_auto and state.module == module and state.map_selected == control;
        if (learnSelectRow(&id, preview, width, selected)) mft_fxsel.selectControl(state, module, control);
        return false;
    }
    try imgui.SetNextItemWidth(.{ ctx, width });
    var fit_buf: [96:0]u8 = undefined;
    const shown = device.fitText(&fxsel_kit, preview, width - 6, &fit_buf);
    const open = try imgui.BeginCombo(.{ ctx, &id, shown, imgui.ComboFlags_NoArrowButton });
    comboNaming(state, plate, control, param_text, custom);
    if (!open) return false;
    defer imgui.EndCombo(.{ctx}) catch {};
    mft_fxsel.selectControl(state, module, control);
    var changed = false;
    if (try imgui.Selectable(.{ ctx, "-" })) {
        mft_fxsel.assign(state, null);
        changed = true;
    }
    // The dry/wet of the FX has no fixed number, so it is a choice of its own, as in the maps.
    if (try imgui.Selectable(.{ ctx, i18n.t("Dry/Wet") })) {
        mft_fxsel.assign(state, mappings.wet_param);
        changed = true;
    }
    const count: usize = @intCast(@max(reaper.TrackFX_GetNumParams(track, fx), 0));
    for (0..@min(count, 1024)) |p| {
        var label_buf: [96:0]u8 = undefined;
        if (try imgui.Selectable(.{ ctx, paramLabel(track, fx, @intCast(p), &label_buf) })) {
            mft_fxsel.assign(state, @intCast(p));
            changed = true;
        }
    }
    return changed;
}

/// What the mouse does to a combo of the mapping panel, beyond opening it: its tooltip says what it maps and how to name it, and a right click starts
/// naming its control.
fn comboNaming(state: *mft_fxsel.FxSelState, plate: mft_fxsel.NamedPlate, control: usize, target: [:0]const u8, custom: ?[:0]const u8) void {
    if (imgui.api.IsItemHovered(ctx, null)) {
        var tip_buf: [256:0]u8 = undefined;
        const tip = if (custom) |name|
            i18n.print(&tip_buf, "{s}: {s}\nRight-click to rename the control.", .{ name, target }) catch target
        else
            i18n.print(&tip_buf, "{s}\nRight-click to name the control.", .{target}) catch target;
        widgets.tooltip(&fxsel_kit, tip);
    }
    var right: c_int = 1;
    if (imgui.api.IsItemClicked(ctx, &right)) mft_fxsel.openNamer(state, plate, control);
}

/// Whether the popup of the namer was opened, so that it is opened once, and is known to have closed when ImGui stops drawing it; and how many more
/// frames its field asks for the keyboard (ImGui can miss the first ask while the popup appears).
var namer_opened = false;
var namer_focus: u8 = 0;
const namer_focus_frames = 6;

/// The popup that names a control, which a right click on its combo opens: a field that has the name, which Enter or OK gives the control, Clear that takes
/// its name away, and Escape or a click outside that leaves it as it was. It returns whether a name changed.
fn drawNamer(state: *mft_fxsel.FxSelState) !bool {
    const namer = state.map_namer orelse {
        namer_opened = false;
        return false;
    };
    if (!namer_opened) {
        imgui.api.OpenPopup(ctx, "##namer", null);
        namer_opened = true;
        namer_focus = namer_focus_frames;
    }
    if (!imgui.api.BeginPopup(ctx, "##namer", null)) {
        // A click outside closed the popup: the name stays as it was.
        state.map_namer = null;
        namer_opened = false;
        return false;
    }
    defer imgui.api.EndPopup(ctx);
    var title_buf: [64:0]u8 = undefined;
    const title = if (namer.control < mappings.knob_count)
        i18n.print(&title_buf, "Name of the knob {d}", .{namer.control + 1}) catch i18n.t("Name")
    else
        i18n.print(&title_buf, "Name of the push {d}", .{namer.control - mappings.knob_count + 1}) catch i18n.t("Name");
    try imgui.Text(.{ ctx, title });
    if (namer_focus > 0) {
        imgui.api.SetKeyboardFocusHere(ctx, null);
        namer_focus -= 1;
    }
    imgui.api.SetNextItemWidth(ctx, 240);
    var flags: c_int = imgui.InputTextFlags_EnterReturnsTrue | imgui.InputTextFlags_AutoSelectAll;
    const entered = imgui.api.InputTextWithHint(ctx, "##namertext", i18n.t("Name of the control"), @as([*]u8, @ptrCast(&state.map_namer_text)), state.map_namer_text.len + 1, &flags, null);
    if (imgui.api.IsItemActive(ctx)) namer_focus = 0;
    var changed = false;
    var done = false;
    if (entered) {
        changed = mft_fxsel.applyNamer(state);
        done = true;
    }
    if (!done and imgui.api.IsKeyPressed(ctx, imgui.Key_Escape, null)) {
        state.map_namer = null;
        done = true;
    }
    if (!done and widgets.pushButton(&fxsel_kit, i18n.t("OK"), 0)) {
        changed = mft_fxsel.applyNamer(state);
        done = true;
    }
    if (!done) {
        imgui.api.SameLine(ctx, null, null);
        if (widgets.pushButton(&fxsel_kit, i18n.t("Clear"), 0)) {
            @memset(&state.map_namer_text, 0);
            changed = mft_fxsel.applyNamer(state);
            done = true;
        }
    }
    if (done) {
        imgui.api.CloseCurrentPopup(ctx);
        namer_opened = false;
    }
    return changed;
}

/// A line of text at a place, in the label font of the panel.
fn mapText(dl: imgui.DrawListPtr, x: f64, y: f64, color: c_int, text: [:0]const u8) void {
    if (fonts.label != null) imgui.api.PushFont(ctx, fonts.label);
    defer if (fonts.label != null) imgui.api.PopFont(ctx);
    imgui.api.DrawList_AddText(dl, x, y, color, text);
}

/// The width of a text in the label font.
fn mapTextWidth(text: [:0]const u8) f64 {
    if (fonts.label != null) imgui.api.PushFont(ctx, fonts.label);
    defer if (fonts.label != null) imgui.api.PopFont(ctx);
    var w: f64 = 0;
    var h: f64 = 0;
    imgui.CalcTextSize(.{ ctx, text, &w, &h }) catch {};
    return w;
}

/// One cell of a plate: its number, the encoder as the device draws it, and the window under it with the combo of the
/// knob (the turn line) and the combo of the push (the press line). The push of the encoders of the bottom row is global, so their press line is the name of
/// their page and is no combo. The cell of the control that is selected is washed with amber.
fn drawMapCell(state: *mft_fxsel.FxSelState, track: reaper.MediaTrack, module: mft_fxsel.MappableModule, index: usize, x0: f64, y0: f64, layout: MapCellLayout, color: c_int, changed: *bool) !void {
    const dl = imgui.api.GetWindowDrawList(ctx);
    const mi = mft_fxsel.moduleIndex(module);
    const has_plugin = mft_fxsel.mapFx(state, module) >= 0;
    const top = index < mappings.push_count;
    const knob_param = mft_fxsel.controlParam(state, module, index);
    const push_param = if (top) mft_fxsel.controlParam(state, module, mappings.knob_count + index) else null;
    const mapped = knob_param != null or push_param != null;
    const selected = state.module == module and (state.map_selected % mappings.knob_count == index) and (state.map_selected < mappings.knob_count or top);

    if (selected) {
        widgets.rectFilled(dl, x0, y0, x0 + map_cell_w, y0 + layout.height - 4, theme.amber_soft, 7);
        widgets.rect(dl, x0, y0, x0 + map_cell_w, y0 + layout.height - 4, widgets.faded(theme.amber, 0x80), 7, 1);
    }
    var number_buf: [8:0]u8 = undefined;
    mapText(dl, x0 + 4, y0 + 2, theme.text_dim, std.mem.printSentinel(&number_buf, "{d}", .{index + 1}, 0) catch "");
    const value: ?f64 = if (!mapped) null else if (push_param != null and knob_param == null) 1.0 else 0.5;
    device.drawEncoder(dl, x0 + map_cell_w / 2, y0 + layout.enc_cy, .{ .value = value, .color = color, .scale = map_enc / 80.0 });

    // The window under the encoder: lit in the color of the module when the control is mapped, with a turn line and a press line.
    const win_y = y0 + layout.win_y;
    device.drawLedWindowRect(dl, x0 + 1, win_y, x0 + map_cell_w - 1, map_win_h, color, if (mapped) 0.8 else 0);
    const zone_h = (map_win_h - 4) / 2;
    const glyph_x = x0 + 9;
    device.turnGlyph(dl, glyph_x, win_y + 2 + zone_h / 2, if (knob_param != null) color else theme.text_dim);
    device.pressGlyph(dl, glyph_x, win_y + 2 + zone_h * 1.5, if (push_param != null) color else theme.text_dim);
    const combo_x = x0 + 17;
    const combo_w = map_cell_w - 22;
    if (!has_plugin) {
        mapText(dl, combo_x, win_y + 4, theme.text_dim, "-");
        mapText(dl, combo_x, win_y + 4 + zone_h, theme.text_dim, "-");
        return;
    }
    if (try drawMapCombo(state, track, module, index, combo_x, win_y + 2, combo_w)) changed.* = true;
    if (top) {
        if (try drawMapCombo(state, track, module, mappings.knob_count + index, combo_x, win_y + 2 + zone_h, combo_w)) changed.* = true;
    } else {
        // The press line of the bottom row says the page that the push selects, which is no combo because that push is global.
        mapText(dl, combo_x, win_y + 4 + zone_h, theme.text_dim, @tagName(@as(MftActiveModule, @fromBackingInt(@intCast(index - 8)))));
    }
    // A click on the cell that is not on a combo selects its knob, as touching its encoder does.
    imgui.api.SetCursorScreenPos(ctx, x0, y0);
    var cell_id: [32:0]u8 = undefined;
    _ = std.mem.printSentinel(&cell_id, "##cell{d}_{d}", .{ mi, index }, 0) catch return;
    if (imgui.api.InvisibleButton(ctx, &cell_id, map_cell_w, 2 + map_enc, null)) mft_fxsel.selectControl(state, module, index);
}

/// Where a text after the title of a card goes: right of the title, with its baseline on the baseline of the title. The card engraves its title at its
/// top left, inside its padding, in the title font; a text in another font is moved down by the difference of the ascents, which are about four fifths of
/// the sizes of the fonts. It is called inside the card, whose window it reads.
fn mapTitleLine(title: [:0]const u8) struct { x: f64, y: f64 } {
    var card_x: f64 = 0;
    var card_y: f64 = 0;
    imgui.api.GetWindowPos(ctx, &card_x, &card_y);
    var padding_x: f64 = 0;
    var padding_y: f64 = 0;
    imgui.api.GetStyleVar(ctx, imgui.StyleVar_WindowPadding, &padding_x, &padding_y);
    var upper_buf: [48:0]u8 = undefined;
    const upper = widgets.upperText(upper_buf[0..@min(title.len, upper_buf.len - 1)], title);
    upper_buf[upper.len] = 0;
    const pushed = widgets.pushTitleFont(&fxsel_kit);
    const title_w = widgets.textSize(&fxsel_kit, upper_buf[0..upper.len :0]).w;
    const title_size = imgui.api.GetFontSize(ctx);
    widgets.popFont(&fxsel_kit, pushed);
    const text_size = imgui.api.GetFontSize(ctx);
    return .{ .x = card_x + padding_x + title_w + 12, .y = card_y + padding_y + 0.8 * (title_size - text_size) };
}

/// A button on the line of the title of a card, after the title. It returns whether it was clicked.
/// What a button on the line of a title did, and where it was drawn, so that a key can follow it with the same top and height.
const TitleButton = struct { clicked: bool, right: f64, top: f64, bottom: f64 };

fn mapTitleButton(title: [:0]const u8, label: [:0]const u8) !TitleButton {
    const line = mapTitleLine(title);
    // A small button has no padding above its text, so its text starts where the button does.
    imgui.api.SetCursorScreenPos(ctx, line.x, line.y);
    const clicked = imgui.api.SmallButton(ctx, label);
    var x1: f64 = 0;
    var y1: f64 = 0;
    var x2: f64 = 0;
    var y2: f64 = 0;
    imgui.api.GetItemRectMin(ctx, &x1, &y1);
    imgui.api.GetItemRectMax(ctx, &x2, &y2);
    return .{ .clicked = clicked, .right = x2, .top = y1, .bottom = y2 };
}

/// A small square key with a wrench on it, as the key of the mock that opens the window of a plugin. It follows the button of the plugin with the top and
/// the height that ImGui gave that button, which are read from it, so that the two are as tall as each other on the line of the title. Its words are in its
/// tooltip. It returns whether it was clicked.
fn mapWrenchKey(id: [:0]const u8, tip: [:0]const u8, after: TitleButton) bool {
    const dl = imgui.api.GetWindowDrawList(ctx);
    var spacing_x: f64 = 0;
    var spacing_y: f64 = 0;
    imgui.api.GetStyleVar(ctx, imgui.StyleVar_ItemSpacing, &spacing_x, &spacing_y);
    const at = widgets.Point{ .x = after.right + spacing_x, .y = after.top };
    const size = after.bottom - after.top;
    imgui.api.SetCursorScreenPos(ctx, at.x, at.y);
    const clicked = imgui.api.InvisibleButton(ctx, id, size, size, null);
    const hovered = imgui.api.IsItemHovered(ctx, null);
    widgets.rectFilled(dl, at.x, at.y, at.x + size, at.y + size, theme.knob_top, 4);
    widgets.rect(dl, at.x, at.y, at.x + size, at.y + size, if (hovered) theme.amber else theme.knob_edge, 4, 1);
    // The wrench: a handle from the lower left, and the ring of its head at the upper right, open on its far side.
    const tone = if (hovered) theme.amber else theme.label;
    const cx = at.x + size / 2;
    const cy = at.y + size / 2;
    const r = size * 0.18;
    widgets.line(dl, cx - size * 0.28, cy + size * 0.28, cx + size * 0.05, cy - size * 0.05, tone, 2.2);
    widgets.arc(dl, cx + size * 0.12, cy - size * 0.12, r, pi * 0.95, pi * 2.55, tone, 1.8);
    if (hovered) widgets.tooltip(&fxsel_kit, tip);
    return clicked;
}

/// What the picker of the maps of a plugin asked for: nothing, to use one of the maps, or to make a new map of that name from the one that is shown.
const MapPick = union(enum) { none, use: [:0]const u8, create: [:0]const u8 };

/// The maps that the open picker lists, and the plate that it was opened for (the strip being the plate after the modules). Because the list is read
/// from the disk, it is read when the picker opens, and not on every frame.
var map_picker_list: mft_fxsel.BrowserList = .{};
var map_picker_for: ?usize = null;
/// The name of a new map, which is typed in the picker.
var new_map_name: [map_store.map_name_len:0]u8 = @splat(0);
/// The plate of the channel strip, in the places of the picker.
const strip_plate = mappings.module_count;

/// The picker of the maps of a plugin, on the line of the title of its plate, after the key of the window of the plugin (`after` is the button of the
/// plugin, which the key follows). It lists the maps of the plugin, the one in use being checked, and has a field for the name of a new map, which is made
/// from the map that the plate shows.
fn drawMapPicker(globals: *MftGlobals, owner: map_store.Owner, fx_name: [:0]const u8, plate: usize, after: TitleButton) !MapPick {
    const io = mft_globals.hostIo();
    imgui.api.SetCursorScreenPos(ctx, titleKeyX(after, 2), after.top);
    const in_use = globals.map_store.mapInUse(io, owner, fx_name);
    var preview_buf: [96:0]u8 = undefined;
    const preview = i18n.print(&preview_buf, "Map: {s}  v", .{in_use}) catch i18n.t("Map");
    // The combo has no padding above its text, as the small button of the plugin, so that the two are as tall as each other.
    theme.pushVar2(ctx, imgui.StyleVar_FramePadding, 4, 0);
    imgui.api.SetNextItemWidth(ctx, widgets.textSize(&fxsel_kit, preview).w + 12);
    var id_buf: [32:0]u8 = undefined;
    const id = std.mem.printSentinel(&id_buf, "##mappick{d}", .{plate}, 0) catch "##mappick";
    const open = try imgui.BeginCombo(.{ ctx, id, preview, imgui.ComboFlags_NoArrowButton });
    var popped: c_int = 1;
    imgui.api.PopStyleVar(ctx, &popped);
    if (!open) {
        if (map_picker_for == plate) map_picker_for = null;
        if (imgui.api.IsItemHovered(ctx, null)) widgets.tooltip(&fxsel_kit, i18n.t("The map of the plugin: choose another, or make a new one from this one."));
        return .none;
    }
    defer imgui.EndCombo(.{ctx}) catch {};
    if (map_picker_for != plate) {
        globals.map_store.listMaps(io, owner, fx_name, &map_picker_list);
        map_picker_for = plate;
        new_map_name[0] = 0;
    }
    var pick: MapPick = .none;
    for (0..map_picker_list.count) |i| {
        const name = map_picker_list.get(i);
        var item_buf: [96:0]u8 = undefined;
        const item = std.mem.printSentinel(&item_buf, "{s}##mapitem{d}", .{ name, i }, 0) catch continue;
        var selected = std.mem.eql(u8, name, in_use);
        if (imgui.api.Selectable(ctx, item, &selected, null, null, null)) pick = .{ .use = name };
    }
    imgui.api.Separator(ctx);
    try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, theme.text_dim });
    try imgui.Text(.{ ctx, i18n.t("New map, made from this one:") });
    try imgui.PopStyleColor(.{ ctx, 1 });
    try imgui.SetNextItemWidth(.{ ctx, 200 });
    _ = try imgui.InputText(.{ ctx, "##newmap", @as([*]u8, @ptrCast(&new_map_name)), new_map_name.len + 1, null, null });
    const typed = std.mem.trim(u8, std.mem.sliceTo(&new_map_name, 0), " \t");
    if (typed.len > 0) {
        var create_buf: [96:0]u8 = undefined;
        const create = i18n.print(&create_buf, "Create \"{s}\"##createmap", .{typed}) catch "Create##createmap";
        if (try imgui.Selectable(.{ ctx, create })) {
            // The name is trimmed in place, since the slice has to outlive the call and the buffer is the picker's.
            const start = @intFromPtr(typed.ptr) - @intFromPtr(&new_map_name);
            new_map_name[start + typed.len] = 0;
            pick = .{ .create = new_map_name[start .. start + typed.len :0] };
        }
    }
    return pick;
}

/// Where the key `index` after the button of a plugin goes, on the line of the title: the keys are squares as tall as the button, with the spacing of ImGui
/// between them; the key 0 is the key of the window of the plugin.
fn titleKeyX(after: TitleButton, index: usize) f64 {
    var spacing_x: f64 = 0;
    var spacing_y: f64 = 0;
    imgui.api.GetStyleVar(ctx, imgui.StyleVar_ItemSpacing, &spacing_x, &spacing_y);
    const key_size = after.bottom - after.top;
    return after.right + spacing_x + @as(f64, @floatFromInt(index)) * (key_size + spacing_x);
}

/// Whether the map in use of each plate keeps a state, as it was read for the plugin and the map that the plate shows. Because the answer is on the disk,
/// it is read again only when the plugin or the map changes, or the key changed it.
const StateMark = struct { key: u64 = 0, has: bool = false };
var state_marks: [mappings.module_count + 1]StateMark = @splat(.{});

fn mapKeepsState(globals: *MftGlobals, owner: map_store.Owner, fx_name: []const u8, plate: usize) bool {
    const io = mft_globals.hostIo();
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(fx_name);
    hasher.update(globals.map_store.mapInUse(io, owner, fx_name));
    const key = hasher.final() | 1;
    if (state_marks[plate].key != key) {
        var state: plugin_state.PluginState = undefined;
        state_marks[plate] = .{ .key = key, .has = globals.map_store.readState(io, owner, fx_name, &state) };
    }
    return state_marks[plate].has;
}

/// The key that makes the map keep the state of the plugin, after the key of the window of the plugin. A click stores the state that the plugin has now
/// (its preset and the values of its parameters), which loading the plugin with the map restores, and an Alt-click makes the map keep none. The key is lit
/// while the map keeps one.
fn drawStateKey(globals: *MftGlobals, track: reaper.MediaTrack, fx: c_int, owner: map_store.Owner, fx_name: [:0]const u8, plate: usize, after: TitleButton, error_buf: *[96:0]u8) void {
    const io = mft_globals.hostIo();
    const has = mapKeepsState(globals, owner, fx_name, plate);
    const dl = imgui.api.GetWindowDrawList(ctx);
    const size = after.bottom - after.top;
    const at = widgets.Point{ .x = titleKeyX(after, 1), .y = after.top };
    imgui.api.SetCursorScreenPos(ctx, at.x, at.y);
    var id_buf: [24:0]u8 = undefined;
    const clicked = imgui.api.InvisibleButton(ctx, std.mem.printSentinel(&id_buf, "##state{d}", .{plate}, 0) catch "##state", size, size, null);
    const hovered = imgui.api.IsItemHovered(ctx, null);
    widgets.rectFilled(dl, at.x, at.y, at.x + size, at.y + size, if (has) widgets.faded(theme.amber, 0x55) else theme.knob_top, 4);
    widgets.rect(dl, at.x, at.y, at.x + size, at.y + size, if (hovered or has) theme.amber else theme.knob_edge, 4, 1);
    // A pin: its head, and its needle under it.
    const tone = if (hovered or has) theme.amber else theme.label;
    const cx = at.x + size / 2;
    widgets.circleFilled(dl, cx, at.y + size * 0.36, size * 0.17, tone);
    widgets.line(dl, cx - size * 0.24, at.y + size * 0.52, cx + size * 0.24, at.y + size * 0.52, tone, 1.8);
    widgets.line(dl, cx, at.y + size * 0.52, cx, at.y + size * 0.82, tone, 1.6);
    if (hovered) widgets.tooltip(&fxsel_kit, if (has)
        i18n.t("The map keeps the state of the plugin, which loading the plugin with the map restores. Click to store the state that it has now; Alt-click to keep none.")
    else
        i18n.t("Store the state of the plugin in the map (its preset and the values of its parameters): loading the plugin with the map restores it."));
    if (!clicked) return;
    state_marks[plate] = .{};
    if (altHeld()) {
        globals.map_store.removeState(io, owner, fx_name) catch |err| {
            _ = i18n.print(error_buf, "The state could not be removed: {s}.", .{@errorName(err)}) catch {};
        };
        return;
    }
    var state: plugin_state.PluginState = undefined;
    mft_fx.captureState(track, fx, &state);
    globals.map_store.saveState(io, owner, fx_name, &state) catch |err| {
        _ = i18n.print(error_buf, "The state could not be written: {s}.", .{@errorName(err)}) catch {};
        return;
    };
    error_buf[0] = 0;
}

/// Carries out what the picker of a module plate asked for: the plate edits the map that was chosen, or a new map made from the one it shows. A name that
/// cannot be the name of a map leaves its reason in `error_buf`, which the plate shows.
fn applyMapPick(globals: *MftGlobals, state: *mft_fxsel.FxSelState, owner: map_store.Owner, fx_name: [:0]const u8, pick: MapPick, error_buf: *[96:0]u8) void {
    const io = mft_globals.hostIo();
    switch (pick) {
        .none => return,
        .use => |name| {
            globals.map_store.useMap(owner, fx_name, name) catch |err| {
                _ = i18n.print(error_buf, "The map could not be chosen: {s}.", .{@errorName(err)}) catch {};
                return;
            };
        },
        .create => |typed| {
            // Because the name of a map is the name of its file, the characters that a file name cannot have are replaced, as for the plugins.
            var name_buf: [512:0]u8 = undefined;
            const name = @import("fs_helpers").sanitizeFxName(&name_buf, typed) catch {
                _ = i18n.print(error_buf, "That name is too long for a map.", .{}) catch {};
                return;
            };
            if (std.mem.indexOfScalar(u8, name, '=') != null) {
                _ = i18n.print(error_buf, "The name of a map cannot have an equal sign.", .{}) catch {};
                return;
            }
            if (map_picker_list.contains(name)) {
                _ = i18n.print(error_buf, "The plugin has a map of that name already.", .{}) catch {};
                return;
            }
            globals.map_store.useMap(owner, fx_name, name) catch |err| {
                _ = i18n.print(error_buf, "The map could not be made: {s}.", .{@errorName(err)}) catch {};
                return;
            };
            // The new map is the map that the plate shows, written under its new name.
            const saved = switch (owner) {
                .module => |module| globals.map_store.saveUser(io, module, fx_name, mft_fxsel.editOf(state, module)),
                .strip => globals.map_store.saveStrip(io, fx_name, &state.map_strip),
            };
            saved catch |err| {
                _ = i18n.print(error_buf, "The map file could not be written: {s}.", .{@errorName(err)}) catch {};
                return;
            };
        },
    }
    error_buf[0] = 0;
    map_picker_for = null;
    // The plate reads the map that the plugin uses now.
    switch (owner) {
        .module => |module| {
            const i = mft_fxsel.moduleIndex(module);
            state.map_edits[i] = globals.map_store.get(io, module, fx_name) orelse .{};
            state.map_loaded[i] = state.map_edits[i];
        },
        .strip => {
            state.map_strip = globals.map_store.getStrip(io, fx_name) orelse .{};
            state.map_strip_loaded = state.map_strip;
        },
    }
}

/// A note on the line of the title of a card, after the title, in the dim of the panel.
fn mapTitleNote(title: [:0]const u8, note: [:0]const u8) void {
    const line = mapTitleLine(title);
    imgui.api.SetCursorScreenPos(ctx, line.x, line.y);
    imgui.api.PushStyleColor(ctx, imgui.Col_Text, theme.text_dim);
    imgui.api.Text(ctx, note);
    var popped: c_int = 1;
    imgui.api.PopStyleColor(ctx, &popped);
}

/// A plate: the title of the module with the button of its plugin next to it, and under them the grid of its sixteen cells. The plate of the module in focus has
/// the color of its module.
fn drawMapPlate(globals: *MftGlobals, state: *mft_fxsel.FxSelState, track: reaper.MediaTrack, module: mft_fxsel.MappableModule, color: c_int, changed: *bool) !void {
    const mi = mft_fxsel.moduleIndex(module);
    const focus = state.module == module;
    imgui.api.BeginGroup(ctx);
    defer imgui.api.EndGroup(ctx);
    if (state.map_error[mi][0] != 0) {
        try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, theme.amber });
        try imgui.Text(.{ ctx, std.mem.sliceTo(&state.map_error[mi], 0) });
        try imgui.PopStyleColor(.{ ctx, 1 });
    }
    if (!widgets.beginCard(&fxsel_kit, mapTitle(module), map_plate_w, null, if (focus) color else null)) return;
    defer widgets.endCard(&fxsel_kit);
    const origin = widgets.cursorScreenPos(&fxsel_kit);
    // The button of the plugin is on the line of the title, after it: a click opens the browser for the module, to swap the plugin. A module that has
    // none says so on the button.
    var button_buf: [200:0]u8 = undefined;
    const plugin = std.mem.sliceTo(&state.map_fx_name[mi], 0);
    const shown = plugin[0..@min(plugin.len, 34)];
    const button = if (state.map_fx_index[mi] >= 0)
        std.mem.printSentinel(&button_buf, "{s}{s}  v##plugin{d}", .{ shown, if (shown.len < plugin.len) "..." else "", mi }, 0) catch "?"
    else
        i18n.print(&button_buf, "no plugin: Load FX  v##plugin{d}", .{mi}) catch "?";
    const plugin_button = try mapTitleButton(mapTitle(module), button);
    if (plugin_button.clicked) {
        // The browser opens over the panel, which stays open and is where the controller goes back to.
        mft_fxsel.browseFromMapping(state, module);
        state.pending = .fill_browser;
    }
    // A module that has a plugin has a second button after it, which opens the window of the plugin, or closes it.
    if (state.map_fx_index[mi] >= 0 and track != null) {
        var ui_id: [24:0]u8 = undefined;
        if (mapWrenchKey(std.mem.printSentinel(&ui_id, "##ui{d}", .{mi}, 0) catch "##ui", i18n.t("Open FX window"), plugin_button)) mft_fx.toggleFxWindow(track, state.map_fx_index[mi]);
        const fx_name = state.map_fx_name[mi][0..plugin.len :0];
        drawStateKey(globals, track, state.map_fx_index[mi], .{ .module = module }, fx_name, mi, plugin_button, &state.map_error[mi]);
        const pick = try drawMapPicker(globals, .{ .module = module }, fx_name, mi, plugin_button);
        applyMapPick(globals, state, .{ .module = module }, fx_name, pick, &state.map_error[mi]);
    }
    imgui.api.SetCursorScreenPos(ctx, origin.x, origin.y);
    const layout = mapCellLayout();
    imgui.api.Dummy(ctx, map_grid_w, 4 * layout.height);
    for (0..mappings.knob_count) |i| {
        const col: f64 = @floatFromInt(i % 4);
        const row: f64 = @floatFromInt(i / 4);
        try drawMapCell(state, track, module, i, origin.x + col * (map_cell_w + map_cell_gap), origin.y + row * layout.height, layout, color, changed);
    }
}

/// What a control of the AUTO page does, in words: the name of its action, or the plugin and the name of its parameter.
fn autoTargetLabel(track: reaper.MediaTrack, target: mft_auto.Target, buf: *[160:0]u8) [:0]const u8 {
    switch (target) {
        .action, .named_action => return mft_fx.actionName(target, buf),
        .fx_param => |fx| {
            var param_name: [64:0]u8 = undefined;
            param_name[0] = 0;
            if (track != null) {
                if (mft_fx.findFxByName(track, fx.name())) |index| _ = reaper.TrackFX_GetParamName(track, index, fx.param, &param_name, 64);
            }
            if (param_name[0] == 0) return std.mem.printSentinel(buf, "{s} / {d}", .{ fx.name(), fx.param }, 0) catch "?";
            return std.mem.printSentinel(buf, "{s} / {s}", .{ fx.name(), std.mem.sliceTo(&param_name, 0) }, 0) catch "?";
        },
    }
}

/// A combo of the AUTO plate, which offers the REAPER actions and the parameters of the FX of the track, in two groups, as the mock does. It returns whether
/// the map changed.
fn drawAutoCombo(state: *mft_fxsel.FxSelState, track: reaper.MediaTrack, control: usize, x: f64, y: f64, width: f64) !bool {
    var id: [32:0]u8 = undefined;
    _ = std.mem.printSentinel(&id, "##auto{d}", .{control}, 0) catch return false;
    var label_buf: [160:0]u8 = undefined;
    const target = state.map_auto.control(control);
    const target_text: [:0]const u8 = if (target) |t| autoTargetLabel(track, t, &label_buf) else "-";
    const custom = mft_fxsel.namesOf(state, .auto).get(control);
    const preview: [:0]const u8 = custom orelse target_text;
    imgui.api.SetCursorScreenPos(ctx, x, y);
    imgui.api.PushStyleColor(ctx, imgui.Col_FrameBg, 0);
    imgui.api.PushStyleColor(ctx, imgui.Col_FrameBgHovered, theme.amber_soft);
    imgui.api.PushStyleColor(ctx, imgui.Col_FrameBgActive, theme.amber_soft);
    imgui.api.PushStyleColor(ctx, imgui.Col_Text, if (custom != null) theme.amber else if (target != null) theme.label else theme.text_dim);
    theme.pushVar2(ctx, imgui.StyleVar_FramePadding, 2, 0);
    defer {
        var vars: c_int = 1;
        imgui.api.PopStyleVar(ctx, &vars);
        var colors_pushed: c_int = 4;
        imgui.api.PopStyleColor(ctx, &colors_pushed);
    }
    if (altHeld()) {
        if (!altClearRow(&id, preview, width)) return false;
        mft_fxsel.selectAuto(state, control);
        mft_fxsel.assignAuto(state, control, null);
        return true;
    }
    if (state.map_learn) {
        const selected = state.map_focus_auto and state.map_selected == control;
        if (learnSelectRow(&id, preview, width, selected)) mft_fxsel.selectAuto(state, control);
        return false;
    }
    try imgui.SetNextItemWidth(.{ ctx, width });
    var fit_buf: [96:0]u8 = undefined;
    const shown = device.fitText(&fxsel_kit, preview, width - 6, &fit_buf);
    const open = try imgui.BeginCombo(.{ ctx, &id, shown, imgui.ComboFlags_NoArrowButton });
    comboNaming(state, .auto, control, target_text, custom);
    if (!open) return false;
    defer imgui.EndCombo(.{ctx}) catch {};
    mft_fxsel.selectAuto(state, control);
    var changed = false;
    if (try imgui.Selectable(.{ ctx, "-" })) {
        mft_fxsel.assignAuto(state, control, null);
        changed = true;
    }
    try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, theme.text_dim });
    try imgui.Text(.{ ctx, i18n.t("REAPER actions") });
    try imgui.PopStyleColor(.{ ctx, 1 });
    // Any action can be chosen in REAPER's own Action List, which opens and gives back the one that is chosen there.
    if (try imgui.Selectable(.{ ctx, i18n.t("Choose in the Action List...") })) {
        const current: c_int = if (target) |t| (mft_fx.autoCommand(t) orelse 0) else 0;
        _ = reaper.PromptForAction(1, current, 0);
        state.map_prompt = @intCast(control);
    }
    for (mft_auto.actions, 0..) |action, i| {
        var item: [96:0]u8 = undefined;
        if (try imgui.Selectable(.{ ctx, std.mem.printSentinel(&item, "{s}##act{d}", .{ i18n.dyn(action.label), i }, 0) catch continue })) {
            mft_fxsel.assignAuto(state, control, .{ .action = action.id });
            changed = true;
        }
    }
    // The actions of the controller itself, which REAPER lists with the others: they are kept by their name, as the actions of an extension are.
    try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, theme.text_dim });
    try imgui.Text(.{ ctx, i18n.t("MFT actions") });
    try imgui.PopStyleColor(.{ ctx, 1 });
    for (mft_actions.entries, 0..) |action, i| {
        var item: [96:0]u8 = undefined;
        if (try imgui.Selectable(.{ ctx, std.mem.printSentinel(&item, "{s}##mft{d}", .{ action.name, i }, 0) catch continue })) {
            mft_fxsel.assignAuto(state, control, .{ .named_action = mft_auto.NamedAction.init(action.command) });
            changed = true;
        }
    }
    try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, theme.text_dim });
    try imgui.Text(.{ ctx, i18n.t("FX parameters on the track") });
    try imgui.PopStyleColor(.{ ctx, 1 });
    if (track == null) return changed;
    const fx_count = reaper.TrackFX_GetCount(track);
    var fx: c_int = 0;
    while (fx < fx_count) : (fx += 1) {
        var name_buf: [160:0]u8 = undefined;
        const name = mft_fx.fxMapName(track, fx, &name_buf) orelse continue;
        const params: usize = @intCast(@max(reaper.TrackFX_GetNumParams(track, fx), 0));
        for (0..@min(params, 512)) |p| {
            var param_name: [64:0]u8 = undefined;
            param_name[0] = 0;
            _ = reaper.TrackFX_GetParamName(track, fx, @intCast(p), &param_name, 64);
            var item: [240:0]u8 = undefined;
            const text = std.mem.printSentinel(&item, "{s} / {s}##fx{d}_{d}", .{ name, std.mem.sliceTo(&param_name, 0), fx, p }, 0) catch continue;
            if (try imgui.Selectable(.{ ctx, text })) {
                mft_fxsel.assignAuto(state, control, .{ .fx_param = mft_auto.FxParam.init(name, @intCast(p)) });
                changed = true;
            }
        }
    }
    return changed;
}

/// A cell of the AUTO plate, with the layout of the cells of the modules, whose combos offer actions and parameters.
fn drawAutoCell(state: *mft_fxsel.FxSelState, track: reaper.MediaTrack, index: usize, x0: f64, y0: f64, layout: MapCellLayout, color: c_int, changed: *bool) !void {
    const dl = imgui.api.GetWindowDrawList(ctx);
    const top = index < mappings.push_count;
    const knob = state.map_auto.control(index);
    const push = if (top) state.map_auto.control(mappings.knob_count + index) else null;
    const mapped = knob != null or push != null;
    const selected = state.map_focus_auto and (state.map_selected % mappings.knob_count == index) and (state.map_selected < mappings.knob_count or top);
    if (selected) {
        widgets.rectFilled(dl, x0, y0, x0 + map_cell_w, y0 + layout.height - 4, theme.amber_soft, 7);
        widgets.rect(dl, x0, y0, x0 + map_cell_w, y0 + layout.height - 4, widgets.faded(theme.amber, 0x80), 7, 1);
    }
    var number_buf: [8:0]u8 = undefined;
    mapText(dl, x0 + 4, y0 + 2, theme.text_dim, std.mem.printSentinel(&number_buf, "{d}", .{index + 1}, 0) catch "");
    // A knob that moves a parameter has its ring half lit, and a control that runs an action a full ring, as the mock marks them.
    const value: ?f64 = if (knob) |t| (if (t == .fx_param) 0.5 else 1.0) else if (push != null) 1.0 else null;
    device.drawEncoder(dl, x0 + map_cell_w / 2, y0 + layout.enc_cy, .{ .value = value, .color = color, .scale = map_enc / 80.0 });
    const win_y = y0 + layout.win_y;
    device.drawLedWindowRect(dl, x0 + 1, win_y, x0 + map_cell_w - 1, map_win_h, color, if (mapped) 0.8 else 0);
    const zone_h = (map_win_h - 4) / 2;
    device.turnGlyph(dl, x0 + 9, win_y + 2 + zone_h / 2, if (knob != null) color else theme.text_dim);
    device.pressGlyph(dl, x0 + 9, win_y + 2 + zone_h * 1.5, if (push != null) color else theme.text_dim);
    const combo_x = x0 + 17;
    const combo_w = map_cell_w - 22;
    if (try drawAutoCombo(state, track, index, combo_x, win_y + 2, combo_w)) changed.* = true;
    if (top) {
        if (try drawAutoCombo(state, track, mappings.knob_count + index, combo_x, win_y + 2 + zone_h, combo_w)) changed.* = true;
    } else {
        mapText(dl, combo_x, win_y + 4 + zone_h, theme.text_dim, @tagName(@as(MftActiveModule, @fromBackingInt(@intCast(index - 8)))));
    }
    imgui.api.SetCursorScreenPos(ctx, x0, y0);
    var cell_id: [32:0]u8 = undefined;
    _ = std.mem.printSentinel(&cell_id, "##autocell{d}", .{index}, 0) catch return;
    if (imgui.api.InvisibleButton(ctx, &cell_id, map_cell_w, 2 + map_enc, null)) mft_fxsel.selectAuto(state, index);
}

/// The plate of the AUTO page, which has no plugin: the line above it says what its combos list.
fn drawMapAutoPlate(state: *mft_fxsel.FxSelState, track: reaper.MediaTrack, color: c_int, changed: *bool) !void {
    imgui.api.BeginGroup(ctx);
    defer imgui.api.EndGroup(ctx);
    if (state.map_auto_error[0] != 0) {
        try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, theme.amber });
        try imgui.Text(.{ ctx, std.mem.sliceTo(&state.map_auto_error, 0) });
        try imgui.PopStyleColor(.{ ctx, 1 });
    }
    if (!widgets.beginCard(&fxsel_kit, i18n.t("Auto"), map_plate_w, null, if (state.map_focus_auto) color else null)) return;
    defer widgets.endCard(&fxsel_kit);
    const origin = widgets.cursorScreenPos(&fxsel_kit);
    // The AUTO page has no plugin: the line of its title says what its combos list.
    mapTitleNote(i18n.t("Auto"), i18n.t("REAPER actions and FX parameters, user page"));
    imgui.api.SetCursorScreenPos(ctx, origin.x, origin.y);
    const layout = mapCellLayout();
    imgui.api.Dummy(ctx, map_grid_w, 4 * layout.height);
    for (0..mappings.knob_count) |i| {
        const col: f64 = @floatFromInt(i % 4);
        const row: f64 = @floatFromInt(i / 4);
        try drawAutoCell(state, track, i, origin.x + col * (map_cell_w + map_cell_gap), origin.y + row * layout.height, layout, color, changed);
    }
}

/// The card of the channel strip, in the single FX mode: the button of the strip and the key of its window on the line of its title, and a section for each
/// module, with the title of the module and its sixteen cells, which edit the page of the strip for that module. The section of the module in focus has its
/// title in the color of the module.
fn drawMapStripCard(state: *mft_fxsel.FxSelState, track: reaper.MediaTrack, globals: *MftGlobals, changed: *bool) !void {
    imgui.api.BeginGroup(ctx);
    defer imgui.api.EndGroup(ctx);
    if (state.map_strip_error[0] != 0) {
        try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, theme.amber });
        try imgui.Text(.{ ctx, std.mem.sliceTo(&state.map_strip_error, 0) });
        try imgui.PopStyleColor(.{ ctx, 1 });
    }
    var available_w: f64 = 0;
    var available_h: f64 = 0;
    try imgui.GetContentRegionAvail(.{ ctx, &available_w, &available_h });
    const section_gap: f64 = 18;
    const per_row: usize = @max(1, @as(usize, @intFromFloat(@max((available_w - 28 + section_gap) / (map_grid_w + section_gap), 1))));
    const card_w = @as(f64, @floatFromInt(per_row)) * (map_grid_w + section_gap) - section_gap + 28;
    const title = i18n.t("Channel strip");
    if (!widgets.beginCard(&fxsel_kit, title, card_w, null, colors.hueToRgb(globals.preferences.color_fxsel))) return;
    defer widgets.endCard(&fxsel_kit);
    const origin = widgets.cursorScreenPos(&fxsel_kit);

    var button_buf: [200:0]u8 = undefined;
    const strip = std.mem.sliceTo(&state.map_strip_name, 0);
    const button = if (state.map_strip_fx >= 0)
        std.mem.printSentinel(&button_buf, "{s}  v##strip", .{strip[0..@min(strip.len, 60)]}, 0) catch "?"
    else
        i18n.print(&button_buf, "no channel strip: Load FX  v##strip", .{}) catch "?";
    const strip_button = try mapTitleButton(title, button);
    if (strip_button.clicked) {
        // The browser lists the channel strips, and the strip that is chosen there replaces the one of the track.
        state.strip_target = true;
        mft_fxsel.browseFromMapping(state, state.module);
        state.pending = .fill_browser;
    }
    if (state.map_strip_fx >= 0 and track != null) {
        if (mapWrenchKey("##uistrip", i18n.t("Open FX window"), strip_button)) mft_fx.toggleFxWindow(track, state.map_strip_fx);
        const strip_name = state.map_strip_name[0..strip.len :0];
        drawStateKey(globals, track, state.map_strip_fx, .strip, strip_name, strip_plate, strip_button, &state.map_strip_error);
        const pick = try drawMapPicker(globals, .strip, strip_name, strip_plate, strip_button);
        applyMapPick(globals, state, .strip, strip_name, pick, &state.map_strip_error);
    }

    // The sections, as many to a row as the card has room for.
    const layout = mapCellLayout();
    const title_h = imgui.api.GetTextLineHeightWithSpacing(ctx) + 4;
    const section_h = title_h + 4 * layout.height;
    const rows_count = (mappings.module_count + per_row - 1) / per_row;
    imgui.api.SetCursorScreenPos(ctx, origin.x, origin.y);
    imgui.api.Dummy(ctx, card_w - 28, @as(f64, @floatFromInt(rows_count)) * (section_h + 10));
    inline for (@typeInfo(mft_fxsel.MappableModule).@"enum".field_names, 0..) |field_name, i| {
        const module = @field(mft_fxsel.MappableModule, field_name);
        const color = colors.hueToRgb(globals.preferences.colorForModule(mft_fxsel.pageOf(module)));
        const sx = origin.x + @as(f64, @floatFromInt(i % per_row)) * (map_grid_w + section_gap);
        const sy = origin.y + @as(f64, @floatFromInt(i / per_row)) * (section_h + 10);
        const dl = imgui.api.GetWindowDrawList(ctx);
        var upper_buf: [32:0]u8 = undefined;
        const upper = widgets.upperText(upper_buf[0..mapTitle(module).len], mapTitle(module));
        upper_buf[upper.len] = 0;
        const focus = !state.map_focus_auto and state.module == module;
        mapText(dl, sx, sy, if (focus) color else theme.text_dim, upper_buf[0..upper.len :0]);
        for (0..mappings.knob_count) |cell| {
            const col: f64 = @floatFromInt(cell % 4);
            const row: f64 = @floatFromInt(cell / 4);
            try drawMapCell(state, track, module, cell, sx + col * (map_cell_w + map_cell_gap), sy + title_h + row * layout.height, layout, color, changed);
        }
    }
    // The last cell moved the cursor by hand, so an item closes the card at its bottom.
    imgui.api.SetCursorScreenPos(ctx, origin.x, origin.y + @as(f64, @floatFromInt(rows_count)) * (section_h + 10));
    imgui.api.Dummy(ctx, 1, 1);
}

/// A round key of the bar at the left of the panel. It returns whether it was clicked.
fn drawMapKey(id: [:0]const u8, kind: enum { learn, single, close }, on: bool, enabled: bool, tip: [:0]const u8) bool {
    const dl = imgui.api.GetWindowDrawList(ctx);
    const at = widgets.cursorScreenPos(&fxsel_kit);
    const size: f64 = 32;
    const clicked = imgui.api.InvisibleButton(ctx, id, size, size, null);
    const hovered = imgui.api.IsItemHovered(ctx, null);
    const cx = at.x + size / 2;
    const cy = at.y + size / 2;
    const lit = on and kind == .learn;
    const single_on = on and kind == .single;
    widgets.circleFilled(dl, cx, cy + 2, size / 2, rgba(0x00000099));
    widgets.circleFilled(dl, cx, cy, size / 2, if (lit) rgba(0xE03A3AFF) else theme.knob_top);
    widgets.circle(dl, cx, cy, size / 2, if (single_on) rgba(0xFF9A3CFF) else if (hovered and enabled) theme.amber else theme.knob_edge, 1);
    const tone = if (lit) rgba(0xFFFFFFFF) else if (single_on) rgba(0xFFB066FF) else if (!enabled) theme.text_dim else if (hovered) theme.amber else theme.label;
    switch (kind) {
        .learn => widgets.circleFilled(dl, cx, cy, 5.5, tone),
        .single => {
            widgets.rect(dl, cx - 6.5, cy - 6.5, cx + 6.5, cy + 6.5, tone, 2.5, 1.7);
            widgets.circleFilled(dl, cx, cy, 2.2, tone);
        },
        .close => {
            widgets.line(dl, cx - 5, cy - 5, cx + 5, cy + 5, tone, 1.9);
            widgets.line(dl, cx - 5, cy + 5, cx + 5, cy - 5, tone, 1.9);
        },
    }
    if (hovered) widgets.tooltip(&fxsel_kit, tip);
    return clicked and enabled;
}

/// The card of the assignments: every control that has a parameter, in the order of the modules, the knobs and then the pushes, with a key that takes the
/// parameter away. Its entries go down ten to a column.
fn drawMapAssignments(state: *mft_fxsel.FxSelState, track: reaper.MediaTrack, color: c_int, changed: *bool) !void {
    if (!widgets.beginCard(&fxsel_kit, i18n.t("Assignments"), null, null, color)) return;
    defer widgets.endCard(&fxsel_kit);
    const origin = widgets.cursorScreenPos(&fxsel_kit);
    const row_h = imgui.api.GetTextLineHeightWithSpacing(ctx) + 2;
    const column_w: f64 = 270;
    // The room of the entries is reserved first, because ImGui wants an item under a cursor that was moved by hand, and the entries are then put in it.
    var total: usize = 0;
    inline for (@typeInfo(mft_fxsel.MappableModule).@"enum".field_names) |field_name| {
        const module = @field(mft_fxsel.MappableModule, field_name);
        for (0..mft_fxsel.control_count) |control| {
            if (mft_fxsel.controlParam(state, module, control) != null) total += 1;
        }
    }
    for (0..mft_fxsel.control_count) |control| {
        if (state.map_auto.control(control) != null) total += 1;
    }
    const columns: f64 = @floatFromInt(@max((total + 9) / 10, 1));
    imgui.api.Dummy(ctx, columns * column_w, @as(f64, @floatFromInt(@max(@min(total, 10), 1))) * row_h);
    var count: usize = 0;
    inline for (@typeInfo(mft_fxsel.MappableModule).@"enum".field_names) |field_name| {
        const module = @field(mft_fxsel.MappableModule, field_name);
        const mi = mft_fxsel.moduleIndex(module);
        for (0..mft_fxsel.control_count) |control| {
            const param = mft_fxsel.controlParam(state, module, control) orelse continue;
            const is_push = control >= mappings.knob_count;
            var param_buf: [96:0]u8 = undefined;
            var line_buf: [220:0]u8 = undefined;
            const role = mft_port.roleLabel(module, is_push, if (is_push) control - mappings.knob_count else control);
            const line = std.mem.printSentinel(&line_buf, "{s} {s}{s} > {s}", .{ field_name, role, if (is_push) i18n.t(" (push)") else "", paramLabel(track, mft_fxsel.mapFx(state, module), param, &param_buf) }, 0) catch "?";
            const x = origin.x + @as(f64, @floatFromInt(count / 10)) * column_w;
            const y = origin.y + @as(f64, @floatFromInt(count % 10)) * row_h;
            imgui.api.SetCursorScreenPos(ctx, x, y);
            var key_id: [32:0]u8 = undefined;
            _ = std.mem.printSentinel(&key_id, "x##rm{d}_{d}", .{ mi, control }, 0) catch continue;
            if (imgui.api.SmallButton(ctx, &key_id)) {
                mft_fxsel.assignTo(state, module, control, null);
                changed.* = true;
            }
            imgui.api.SameLine(ctx, null, null);
            try imgui.Text(.{ ctx, line });
            count += 1;
        }
    }
    for (0..mft_fxsel.control_count) |control| {
        const target = state.map_auto.control(control) orelse continue;
        var target_buf: [160:0]u8 = undefined;
        var line_buf: [240:0]u8 = undefined;
        const name = mft_fxsel.controlName(control);
        const line = std.mem.printSentinel(&line_buf, "AUTO {s} > {s}", .{ name, autoTargetLabel(track, target, &target_buf) }, 0) catch "?";
        const x = origin.x + @as(f64, @floatFromInt(count / 10)) * column_w;
        const y = origin.y + @as(f64, @floatFromInt(count % 10)) * row_h;
        imgui.api.SetCursorScreenPos(ctx, x, y);
        var key_id: [32:0]u8 = undefined;
        _ = std.mem.printSentinel(&key_id, "x##rmauto{d}", .{control}, 0) catch continue;
        if (imgui.api.SmallButton(ctx, &key_id)) {
            mft_fxsel.assignAuto(state, control, null);
            changed.* = true;
        }
        imgui.api.SameLine(ctx, null, null);
        try imgui.Text(.{ ctx, line });
        count += 1;
    }
    if (count == 0) {
        imgui.api.SetCursorScreenPos(ctx, origin.x, origin.y);
        try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, theme.text_dim });
        try imgui.Text(.{ ctx, i18n.t("Nothing is assigned yet.") });
        try imgui.PopStyleColor(.{ ctx, 1 });
    }
}

/// Asks REAPER whether the Action List that a combo of the AUTO plate opened has an action chosen. The chosen action goes to the control that waits for it;
/// when the list was closed without one, the control stops waiting. It returns whether the map changed.
fn pollActionList(state: *mft_fxsel.FxSelState) bool {
    const control = state.map_prompt orelse return false;
    const chosen = reaper.PromptForAction(0, 0, 0);
    if (chosen == 0) return false;
    _ = reaper.PromptForAction(-1, 0, 0);
    state.map_prompt = null;
    if (chosen < 0) return false;
    mft_fxsel.selectAuto(state, control);
    mft_fxsel.assignAuto(state, control, mft_fx.actionTarget(chosen));
    return true;
}

/// The window of the mapping mode, which is a window of its own. Its keys at the left are the MIDI learn (a parameter moved in a plugin goes to the selected
/// control), the single FX mode, and the one that leaves the mapping. The encoders select the control that they touch, and the module buttons put another
/// module in focus.
fn drawMappingWindow(globals: *MftGlobals) !void {
    const state = &(globals.mft.fxsel orelse return);
    // The panel stays open while the browser is open over it.
    if (state.screen != .map and !state.map_return) return;
    fxsel_kit.ctx = ctx;
    fxsel_kit.fonts = fonts;
    theme.push(ctx);
    defer theme.pop(ctx);
    if (fonts.text != null) imgui.api.PushFont(ctx, fonts.text);
    defer if (fonts.text != null) imgui.api.PopFont(ctx);
    imgui.api.SetNextWindowPos(ctx, window_x + 40, window_y + 20, &imgui.Cond_FirstUseEver, null, null);
    imgui.api.SetNextWindowSize(ctx, 1280, 820, &imgui.Cond_FirstUseEver);
    theme.pushVar2(ctx, imgui.StyleVar_WindowPadding, 16, 16);
    const flags: c_int = imgui.WindowFlags_NoCollapse | imgui.WindowFlags_NoTitleBar;
    const visible = try imgui.Begin(.{ ctx, "MFT Mapping", null, flags });
    var window_vars: c_int = 1;
    imgui.api.PopStyleVar(ctx, &window_vars);
    if (!visible) return;
    defer imgui.End(.{ctx}) catch {};

    const track = globals.current_track;
    const accent = colors.hueToRgb(globals.preferences.colorForModule(mft_fxsel.pageOf(state.module)));
    var changed = false;
    if (pollActionList(state)) changed = true;

    // The bar of keys at the left.
    imgui.api.BeginGroup(ctx);
    imgui.api.Spacing(ctx);
    imgui.api.Spacing(ctx);
    if (drawMapKey("##learn", .learn, state.map_learn, true, if (state.map_learn) i18n.t("MIDI learn is on: touch an encoder to choose the control, then move a parameter in the plugin") else i18n.t("MIDI learn: touch an encoder, then move a parameter in the plugin window"))) state.map_learn = !state.map_learn;
    if (drawMapKey("##single", .single, state.map_single, true, if (state.map_single) i18n.t("Back to a plugin for each module") else i18n.t("Single FX mode: one channel strip for all the modules"))) {
        state.map_single = !state.map_single;
        state.strip_target = state.map_single;
        state.map_selected = 0;
    }
    if (drawMapKey("##close", .close, false, true, i18n.t("Close the mapping"))) state.screen = .actions;
    imgui.api.EndGroup(ctx);
    imgui.api.SameLine(ctx, null, null);

    // The plates, as many to a row as the window has room for.
    imgui.api.BeginGroup(ctx);
    var available_w: f64 = undefined;
    var available_h: f64 = undefined;
    try imgui.GetContentRegionAvail(.{ ctx, &available_w, &available_h });
    const per_row: usize = @max(1, @as(usize, @intFromFloat(@max((available_w + 14) / (map_plate_w + 14), 1))));
    var placed: usize = 0;
    if (state.map_single) {
        // The single FX mode: one card for the channel strip, with a section for each module, instead of a plate for each. The AUTO plate goes under it.
        try drawMapStripCard(state, track, globals, &changed);
        placed = per_row;
    } else {
        inline for (@typeInfo(mft_fxsel.MappableModule).@"enum".field_names) |field_name| {
            const module = @field(mft_fxsel.MappableModule, field_name);
            var plate_gap: f64 = 14;
            if (placed % per_row != 0) imgui.api.SameLine(ctx, null, &plate_gap);
            try drawMapPlate(globals, state, track, module, colors.hueToRgb(globals.preferences.colorForModule(mft_fxsel.pageOf(module))), &changed);
            placed += 1;
        }
    }
    {
        var plate_gap: f64 = 14;
        if (placed % per_row != 0) imgui.api.SameLine(ctx, null, &plate_gap);
        try drawMapAutoPlate(state, track, colors.hueToRgb(globals.preferences.colorForModule(.AUTO)), &changed);
    }
    try drawMapAssignments(state, track, accent, &changed);
    // What the learn is waiting for, or what the last press said.
    if (state.map_learn) {
        try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, theme.amber });
        try imgui.Text(.{ ctx, i18n.t("MIDI learn is on: touch an encoder to choose the control, then move a parameter in the plugin window.") });
        try imgui.PopStyleColor(.{ ctx, 1 });
    }
    if (state.noteText().len > 0) {
        try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, theme.amber });
        try imgui.Text(.{ ctx, state.noteText() });
        try imgui.PopStyleColor(.{ ctx, 1 });
    }
    imgui.api.EndGroup(ctx);
    // The mapping is saved as soon as it changes.
    if (try drawNamer(state)) changed = true;
    if (changed and state.pending == .none) state.pending = .store_mapping;
}

/// The window of the FX Selection mode, which is a window of its own, as the one of the Console 1 is, and is shown only while the mode is open. It
/// has the look of the panel: cards of the panel kit with the rows of the lists, and the heading in the color of the module.
fn drawFxSelWindow(globals: *MftGlobals) !void {
    const state = &(globals.mft.fxsel orelse return);
    // The mapping mode has a window of its own.
    if (state.screen == .map) return;
    fxsel_kit.ctx = ctx;
    fxsel_kit.fonts = fonts;
    theme.push(ctx);
    defer theme.pop(ctx);
    if (fonts.text != null) imgui.api.PushFont(ctx, fonts.text);
    defer if (fonts.text != null) imgui.api.PopFont(ctx);

    imgui.api.SetNextWindowPos(ctx, fxsel_window_x, window_y, &imgui.Cond_FirstUseEver, null, null);
    // The window opens at the size that holds the two cards of the first level, so that it does not have to be resized to see them.
    const line_height = imgui.api.GetTextLineHeightWithSpacing(ctx);
    imgui.api.SetNextWindowSize(ctx, fxsel_window_w, fxselWindowHeight(line_height, fx_browser.rootMenuCount(.{
        .mapped_count = 0,
        .fx_chains = undefined,
        .track_templates = undefined,
        .plugins_by_type = undefined,
        .tags = undefined,
        .hidden_menus = mft_fxsel.hidden_menus,
    })), &imgui.Cond_FirstUseEver);
    theme.pushVar2(ctx, imgui.StyleVar_WindowPadding, fxsel_padding, fxsel_padding);
    const flags: c_int = imgui.WindowFlags_NoCollapse | imgui.WindowFlags_NoTitleBar;
    const visible = try imgui.Begin(.{ ctx, "MFT FX Selection", null, flags });
    var window_vars: c_int = 1;
    imgui.api.PopStyleVar(ctx, &window_vars);
    if (!visible) return;
    defer imgui.End(.{ctx}) catch {};

    const accent = colors.hueToRgb(globals.preferences.colorForModule(mft_fxsel.pageOf(state.module)));
    var title_buf: [64:0]u8 = undefined;
    const title = if (state.strip_target)
        i18n.t("FX Selection - Channel strip")
    else
        i18n.print(&title_buf, "FX Selection - {s}", .{i18n.dyn(@tagName(state.module))}) catch i18n.t("FX Selection");

    const source: ?fx_browser.Source = if (state.screen == .browse) browser_source.get(globals, state.browser.count) else null;
    if (state.screen == .browse) {
        try drawFxSelSearch(state);
        if (source) |data| {
            var crumb_buf: [512:0]u8 = undefined;
            const crumb = fxSelBreadcrumb(&crumb_buf, state, data);
            if (crumb.len > 0) {
                // The line is a label, so it is engraved in the font of the titles of the cards, in capitals like them.
                var upper: [512:0]u8 = undefined;
                const shown = widgets.upperText(upper[0..crumb.len], crumb);
                upper[shown.len] = 0;
                widgets.engravedText(&fxsel_kit, upper[0..shown.len :0], accent);
            }
        }
    }

    // The cards are as wide as the window and share the height that is left under the search, less the line of the note.
    var available_w: f64 = undefined;
    var available_h: f64 = undefined;
    try imgui.GetContentRegionAvail(.{ ctx, &available_w, &available_h });
    const card_w = @max(available_w, 200);
    const room = available_h - (if (state.noteText().len > 0) line_height else 0);

    var outcome: mft_fxsel.Outcome = .none;
    switch (state.screen) {
        .actions => {
            outcome = try drawFxSelActions(&fxsel_kit, state, accent, title, line_height, card_w);
            // Under the card, the buttons do what the controller does: OK runs the action that the cursor is on, as the push of the encoder 13, and
            // Cancel leaves the mode, as the push of the encoder 14.
            if (widgets.pushButton(&fxsel_kit, i18n.t("OK"), 0)) outcome = mft_fxsel.press(state, mft_fxsel.list_encoder, null);
            imgui.api.SameLine(ctx, null, null);
            if (widgets.pushButton(&fxsel_kit, i18n.t("Cancel"), 0)) outcome = mft_fxsel.press(state, mft_fxsel.cancel_encoder, null);
        },
        .browse => if (source) |data| {
            outcome = try drawFxSelBrowser(&fxsel_kit, state, data, globals.preferences.defaultPlugin(state.module, state.strip_target), accent, line_height, card_w, room);
        } else {
            try imgui.Text(.{ ctx, i18n.t("The list of plugins could not be read.") });
        },
        .presets => outcome = try drawFxSelPresets(&fxsel_kit, state, accent, line_height, card_w, room),
        .maps => {
            const owner: map_store.Owner = if (state.strip_target) .strip else .{ .module = state.module };
            outcome = try drawFxSelMaps(&fxsel_kit, state, globals.map_store.defaultMapName(mft_globals.hostIo(), owner, state.mapsPlugin()), accent, line_height, card_w, room);
        },
        .save => try drawFxSelSave(&fxsel_kit, state, accent, line_height, card_w, room),
        .map => {},
    }
    if (outcome == .none) outcome = try fxSelKeys(state, source);
    if (state.noteText().len > 0) {
        try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, theme.amber });
        try imgui.Text(.{ ctx, state.noteText() });
        try imgui.PopStyleColor(.{ ctx, 1 });
    }
    // The surface carries the choice out on its next run.
    if (outcome != .none) state.pending = outcome;
}

/// What the device shows this frame: the colors of the modules, the parameters of the active module, the encoders that
/// are held, and the state of the track's mute, solo and phase.
fn readView(globals: *MftGlobals) device.View {
    var module_colors: [mft_state.page_count]c_int = undefined;
    inline for (@typeInfo(MftActiveModule).@"enum".field_values, 0..) |field_value, i| {
        module_colors[i] = moduleColor(globals, @fromBackingInt(@intCast(field_value)));
    }
    const active = globals.mft.active_module;
    var view = device.View{
        .active = active,
        .colors = module_colors,
        .knobs = if (globals.mft.fxsel == null) readKnobInfo(globals, active) else .{},
        .held = globals.mft.held_encoders,
        .side_lit = readSideLit(globals),
        .online = globals.online,
        .collapsed = folded,
    };
    if (active == .SETTINGS) {
        const cursor: usize = @min(globals.mft.settings_cursor, settings_rows.row_count - 1);
        const row = settings_rows.rows[cursor];
        view.settings = .{
            .cursor = @as(f64, @floatFromInt(cursor)) / @as(f64, @floatFromInt(settings_rows.row_count - 1)),
            .value = settings_rows.fraction(&globals.preferences, row),
            .row_label = i18n.dyn(row.label),
        };
    }
    if (globals.mft.fxsel) |*state| {
        var labels: [16]mft_fxsel.Label = undefined;
        for (&labels, 0..) |*each, i| each.* = mft_fxsel.label(state, i);
        view.fxsel_labels = labels;
        view.fxsel_color = colors.hueToRgb(globals.preferences.color_fxsel);
    }
    return view;
}

// Reads whether the track is muted, soloed and phase-inverted, which the keys on the right of the device show.
fn readSideLit(globals: *MftGlobals) [3]bool {
    const track = globals.current_track orelse return @splat(false);
    return .{
        reaper.GetMediaTrackInfo_Value(track, "B_MUTE") != 0,
        reaper.GetMediaTrackInfo_Value(track, "I_SOLO") != 0,
        reaper.GetMediaTrackInfo_Value(track, "B_PHASE") != 0,
    };
}

/// The word under a push: the name of the parameter that a click steps, or "Shape" for the shape of an EQ band.
fn pushName(track: reaper.MediaTrack, route: mft_fx.PushRoute, buf: *[32:0]u8) void {
    buf[0] = 0;
    switch (route.action) {
        .param => |param| {
            if (!reaper.TrackFX_GetParamName(track, route.fx_index, @intCast(param), @ptrCast(buf), 32)) _ = std.mem.printSentinel(buf, "{s}", .{i18n.t("Push")}, 0) catch {};
        },
        .band => _ = std.mem.printSentinel(buf, "{s}", .{i18n.t("Shape")}, 0) catch {},
    }
}

/// Copies a name into a buffer of the panel, cut to its size.
fn copyName(buf: anytype, name: []const u8) void {
    const n = @min(name.len, buf.len);
    @memcpy(buf[0..n], name[0..n]);
    buf[n] = 0;
}

// Reads the parameter values and names of the sixteen encoders for the active page.
fn readKnobInfo(globals: *MftGlobals, active: MftActiveModule) KnobInfo {
    var info = KnobInfo{};
    const track = globals.current_track orelse return info;
    const routing = if (active == .AUTO) mft_fx.resolveAuto(globals, track) else blk: {
        const module = MappableModule.fromActive(active) orelse return info;
        break :blk mft_fx.resolveModule(globals, track, module);
    };
    for (routing.targets, 0..) |maybe_target, slot| {
        const target = maybe_target orelse continue;
        info.vals[slot] = reaper.TrackFX_GetParamNormalized(track, target.fx_index, @intCast(target.param));
        info.mapped[slot] = true;
        info.fx_index[slot] = target.fx_index;
        info.param[slot] = @intCast(target.param);
        if (reaper.TrackFX_GetParamName(track, target.fx_index, @intCast(target.param), @ptrCast(&info.name_bufs[slot]), 64)) {
            info.has_name[slot] = true;
        }
    }
    for (routing.pushes, 0..) |maybe_route, push| {
        const route = maybe_route orelse continue;
        info.push_mapped[push] = true;
        pushName(track, route, &info.push_name_bufs[push]);
    }
    // The names that the user gave the controls take the place of the names of the parameters.
    for (0..mappings.knob_count) |slot| {
        const name = routing.names.get(slot) orelse continue;
        copyName(&info.name_bufs[slot], name);
        info.has_name[slot] = true;
    }
    for (0..mappings.push_count) |push| {
        const name = routing.names.get(mappings.knob_count + push) orelse continue;
        copyName(&info.push_name_bufs[push], name);
    }
    // The controls of the AUTO page that run an action have the name of the action, unless the user named them.
    if (active == .AUTO) {
        const map = globals.map_store.getAuto(mft_globals.hostIo());
        for (map.knobs, 0..) |maybe, slot| {
            const target = maybe orelse continue;
            if (target == .fx_param) continue;
            info.mapped[slot] = true;
            info.is_action[slot] = true;
            info.has_name[slot] = true;
            if (map.names.get(slot) != null) continue;
            var name_buf: [160:0]u8 = undefined;
            copyName(&info.name_bufs[slot], mft_fx.actionName(target, &name_buf));
        }
        for (map.pushes, 0..) |maybe, push| {
            const target = maybe orelse continue;
            if (target == .fx_param) continue;
            info.push_mapped[push] = true;
            if (map.names.get(mappings.knob_count + push) != null) continue;
            var name_buf: [160:0]u8 = undefined;
            copyName(&info.push_name_bufs[push], mft_fx.actionName(target, &name_buf));
        }
    }
    return info;
}

// Run the panel against the mock ImGui and assert every window, child, group,
// and style-color push/pop is balanced.
const MockImGui = @import("mock_imgui").MockImGui;

fn assertPanelBalanced(module: MftActiveModule) !void {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    globals.mft.active_module = module;
    try draw(&globals);
    try mock.assertBalanced();
}

test "panel balanced across modes" {
    try assertPanelBalanced(.INPUT);
    try assertPanelBalanced(.TRANSPORT);
    try assertPanelBalanced(.SETTINGS);
}

test "a folded panel is balanced too" {
    folded = true;
    defer folded = false;
    try assertPanelBalanced(.SETTINGS);
    try assertPanelBalanced(.TRANSPORT);
}

test "the buttons of the corner fold the device and hide the panel" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    defer folded = false;
    mock.click("##cornerfold");
    try draw(&globals);
    try std.testing.expect(folded);
    try std.testing.expect(globals.mft.panel_visible);
    mock.click("##cornerclose");
    try draw(&globals);
    try std.testing.expect(!globals.mft.panel_visible);
    try mock.assertBalanced();
}

test "dropping the context takes the fonts and the kit's state with it" {
    kit.accent = theme.green;
    fonts.text = @ptrFromInt(0x10);
    dropContext();
    try std.testing.expect(ctx == null);
    try std.testing.expect(kit.accent == null);
    try std.testing.expect(fonts.text == null);
}

test "the settings have a window of their own, which leaves the stacks balanced on every row, with every switch on and off" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    globals.mft.active_module = .SETTINGS;
    for (0..settings_rows.row_count) |cursor| {
        globals.mft.settings_cursor = @intCast(cursor);
        try drawWindows(&globals);
    }
    globals.preferences.single_fx_mode = true;
    globals.preferences.auto_insert = false;
    globals.preferences.show_plugin_ui = true;
    try drawWindows(&globals);
    // A value of the knobs that is being typed has its field.
    mft_settings.startTyping(9);
    globals.mft.settings_cursor = 9;
    try drawWindows(&globals);
    // A click on the key that cancels reads the file again, says so, and asks to go back to the page.
    mock.click("##stcancel");
    try drawWindows(&globals);
    try std.testing.expectEqualStrings("Back to the saved values.", mft_settings.statusText());
    try std.testing.expect(globals.mft.settings_leave);
    // A save that cannot write the file says so, and stays on the page.
    globals.mft.settings_leave = false;
    mock.resetInteractions();
    mock.click("##stsave");
    try drawWindows(&globals);
    try std.testing.expectEqualStrings("The settings could not be saved to preferences.ini.", mft_settings.statusText());
    try std.testing.expect(!globals.mft.settings_leave);
    try mock.assertBalanced();
}

test "a value shows in its pop-up while the knob is turned, hovered or held, and for the linger time after" {
    var tracker = Activity{};
    var info = KnobInfo{};
    info.mapped[0] = true;
    info.mapped[1] = true;
    info.vals[0] = 0.2;
    info.vals[1] = 0.7;
    const first: u16 = 0b01;
    const linger = value_linger_ms;

    // The first frame of a module only learns the values, because nobody turned anything.
    try std.testing.expectEqual(@as(u16, 0), tracker.update(.INPUT, null, &info, 0, 1000));
    try std.testing.expectEqual(@as(u16, 0), tracker.update(.INPUT, null, &info, 0, 1016));
    // The first encoder turns, and its pop-up stays for the linger time.
    info.vals[0] = 0.3;
    try std.testing.expectEqual(first, tracker.update(.INPUT, null, &info, 0, 2000));
    try std.testing.expectEqual(first, tracker.update(.INPUT, null, &info, 0, 2000 + linger - 1));
    try std.testing.expectEqual(@as(u16, 0), tracker.update(.INPUT, null, &info, 0, 2000 + linger));
    // The mouse hovers over the first encoder: the pop-up stays as long as the mouse is there, then lingers.
    try std.testing.expectEqual(first, tracker.update(.INPUT, null, &info, first, 5000));
    try std.testing.expectEqual(first, tracker.update(.INPUT, null, &info, first, 9000));
    try std.testing.expectEqual(first, tracker.update(.INPUT, null, &info, 0, 9000 + linger - 1));
    try std.testing.expectEqual(@as(u16, 0), tracker.update(.INPUT, null, &info, 0, 9000 + linger));
    // An encoder with nothing mapped never shows a value, and a change of module brings values nobody turned.
    try std.testing.expectEqual(@as(u16, 0), tracker.update(.INPUT, null, &info, 0b100, 12000));
    info.vals[1] = 0.9;
    try std.testing.expectEqual(@as(u16, 0), tracker.update(.GATE, null, &info, 0, 13000));
}

test "the mouse over a knob is found, and a folded device has no knob to hover" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var panel = widgets.Panel{};
    var view = device.View{ .active = .INPUT, .colors = @splat(0x11) };
    // The mock's cursor is at the origin, so that the second knob of the first row is at this place.
    const cell = device.cellAt(1, device.pad + device.side_w + device.side_gap, device.pad + device.header_h);
    mock.mouse_x = cell.cx;
    mock.mouse_y = cell.cy;
    try std.testing.expectEqual(@as(u16, 0b10), device.hoveredKnobs(&panel, .{ .x = 0, .y = 0 }, &view));
    view.collapsed = true;
    try std.testing.expectEqual(@as(u16, 0), device.hoveredKnobs(&panel, .{ .x = 0, .y = 0 }, &view));
}

const FakeFormat = struct {
    var calls: usize = 0;
    var empty = false;
    fn format(_: reaper.MediaTrack, _: c_int, param: c_int, buf: *[formatted_len:0]u8) bool {
        calls += 1;
        if (empty) return true;
        _ = std.mem.printSentinel(buf, "{d}.0 dB", .{param}, 0) catch return false;
        return true;
    }
};

test "the plugin's text is asked for the knobs that show a value, once per value, and the percentage is the fallback" {
    var values = FormattedValues{ .source = &FakeFormat.format };
    const track: reaper.MediaTrack = @ptrFromInt(0x10);
    var info = KnobInfo{};
    for (0..3) |slot| {
        info.mapped[slot] = true;
        info.param[slot] = @intCast(slot + 5);
        info.vals[slot] = 0.5;
    }
    FakeFormat.calls = 0;
    // Only the first and third knobs show a value.
    values.fill(.COMP, track, &info, 0b101);
    try std.testing.expectEqual(@as(usize, 2), FakeFormat.calls);
    try std.testing.expect(info.has_formatted[0] and !info.has_formatted[1] and info.has_formatted[2]);
    try std.testing.expectEqualStrings("5.0 dB", info.formatted(0));
    try std.testing.expectEqualStrings("7.0 dB", info.formatted(2));
    // The same values in the next frame are not asked for again, and are still shown.
    var next = KnobInfo{ .mapped = info.mapped, .vals = info.vals, .param = info.param };
    values.fill(.COMP, track, &next, 0b101);
    try std.testing.expectEqual(@as(usize, 2), FakeFormat.calls);
    try std.testing.expectEqualStrings("5.0 dB", next.formatted(0));
    // A value that changed is asked for again.
    next.vals[0] = 0.6;
    values.fill(.COMP, track, &next, 0b101);
    try std.testing.expectEqual(@as(usize, 3), FakeFormat.calls);
    // A plugin that gives an empty text leaves the percentage, and no track leaves everything as it is.
    FakeFormat.empty = true;
    defer FakeFormat.empty = false;
    var other = KnobInfo{ .mapped = info.mapped, .vals = info.vals, .param = info.param };
    values.fill(.EQ, track, &other, 0xFF);
    try std.testing.expect(!other.has_formatted[0]);
    var no_track = KnobInfo{ .mapped = info.mapped };
    values.fill(.EQ, null, &no_track, 0xFF);
    try std.testing.expect(!no_track.has_formatted[0]);
}

test "a transport turn, a press and a left key light the panel while they last, and the stacks balance" {
    const io = std.testing.io;
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    globals.mft.active_module = .TRANSPORT;
    const now = std.Io.Timestamp.now(io, .awake).toMilliseconds();
    globals.mft.activity.markTurn(0, now);
    globals.mft.activity.markPress(1, true, now);
    globals.mft.activity.markSide(2, true, now);
    try draw(&globals);
    try mock.assertBalanced();
    try std.testing.expect(globals.mft.activity.turnLit(0, now));
    try std.testing.expect(globals.mft.activity.sideLit(2, now + 10 * value_linger_ms));
}

test "the FX SEL mode has a window of its own, drawn on both screens with the stacks balanced" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    globals.mft.fxsel = mft_fxsel.FxSelState{};
    const state = &globals.mft.fxsel.?;
    try drawWindows(&globals);
    state.action_cursor = 3;
    state.setNote("Mapping is not done yet.");
    try drawWindows(&globals);
    // The list of plugins: empty, then longer than the rows that fit, with the cursor at the start, in the middle and at the end.
    state.screen = .browse;
    try drawWindows(&globals);
    for (0..30) |i| {
        var name: [24]u8 = undefined;
        state.browser.add(std.fmt.bufPrint(&name, "JS: Plugin {d}", .{i}) catch "x");
    }
    for ([_]u16{ 0, 15, 29 }) |cursor| {
        state.browse_cursors[0] = cursor;
        try drawWindows(&globals);
    }
    try mock.assertBalanced();
}

test "the FX Selection window draws the browser with its cards, a menu that is open, and the results of a search, with the stacks balanced" {
    const t = std.testing;
    const types = @import("fx_parser_types");
    var chains: types.Directory = .{ .path = "/chains", .name = "chains", .subdirs = null, .files = null };
    var templates: types.Directory = .{ .path = "/templates", .name = "templates", .subdirs = null, .files = null };
    var by_type = types.FxByType.initFill(.{});
    defer for (&by_type.values) |*list| list.deinit(t.allocator);
    var tags: types.FxTags = .{ .category = .{}, .developer = .{} };
    try by_type.getPtr(.VST).put(t.allocator, "ReaEQ", {});
    try by_type.getPtr(.VST).put(t.allocator, "ReaComp", {});
    browser_source.test_source = .{ .mapped_count = 0, .fx_chains = &chains, .track_templates = &templates, .plugins_by_type = &by_type, .tags = &tags, .hidden_menus = mft_fxsel.hidden_menus };
    defer browser_source.test_source = null;

    var mock = MockImGui.init(t.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    globals.mft.fxsel = mft_fxsel.FxSelState{};
    const state = &globals.mft.fxsel.?;
    state.screen = .browse;
    state.browser.add("VST: ReaEQ (Cockos)");
    try drawWindows(&globals);
    // The menu of all the plugins, then the list of the VST ones, which scrolls to the cursor.
    state.browse_depth = 1;
    state.browse_path[0] = 1;
    try drawWindows(&globals);
    state.browse_depth = 2;
    state.browse_path[1] = 0;
    state.browse_cursors[2] = 1;
    try drawWindows(&globals);
    // A search takes the place of the cards.
    state.resetBrowser();
    const text = "rea";
    @memcpy(state.search[0..text.len], text);
    state.search[text.len] = 0;
    state.syncSearch();
    try drawWindows(&globals);
    try mock.assertBalanced();
}

test "the FX Selection window draws the preset screens with the stacks balanced" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    globals.mft.fxsel = mft_fxsel.FxSelState{};
    const state = &globals.mft.fxsel.?;
    state.screen = .presets;
    try drawWindows(&globals);
    state.presets.add("Warm");
    state.presets.add("Bright");
    state.preset_cursor = 1;
    try drawWindows(&globals);
    state.screen = .save;
    try drawWindows(&globals);
    const name = "My sound";
    @memcpy(state.save_name[0..name.len], name);
    state.save_name[name.len] = 0;
    state.setNote("A preset has that name: confirm again to replace it.");
    try drawWindows(&globals);
    try mock.assertBalanced();
}

test "the mapping panel draws a plate for every module, with and without a plugin, the assignments, a save error and the learn, with the stacks balanced" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    globals.mft.fxsel = mft_fxsel.FxSelState{};
    const state = &globals.mft.fxsel.?;
    state.screen = .map;
    state.module = .COMP;
    // The compressor and the EQ have a plugin, and the other modules have none.
    const comp = mft_fxsel.moduleIndex(.COMP);
    const eq = mft_fxsel.moduleIndex(.EQ);
    const name = "VST: ReaComp (Cockos)";
    @memcpy(state.map_fx_name[comp][0..name.len], name);
    state.map_fx_index[comp] = 3;
    state.map_fx_index[eq] = 2;
    state.map_edits[comp].knobs[0] = 3;
    state.map_edits[comp].knobs[15] = mappings.wet_param;
    state.map_edits[comp].pushes[1] = .{ .param = 7 };
    state.map_edits[eq].knobs[9] = 4;
    state.map_selected = mappings.knob_count + 1;
    state.setNote("The mapping could not be saved.");
    const error_text = "The map file could not be written: AccessDenied.";
    @memcpy(state.map_error[comp][0..error_text.len], error_text);
    try drawWindows(&globals);
    // The learn is on, a bottom-row control is selected, and nothing is assigned anywhere.
    state.map_learn = true;
    state.map_selected = 9;
    state.map_edits = @splat(.{});
    try drawWindows(&globals);
    try mock.assertBalanced();
}

test "the browser opened from the mapping panel is drawn over the panel, which stays" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    globals.mft.fxsel = mft_fxsel.FxSelState{};
    const state = &globals.mft.fxsel.?;
    state.screen = .map;
    state.map_edits[mft_fxsel.moduleIndex(.COMP)].knobs[2] = 5;
    state.map_fx_index[mft_fxsel.moduleIndex(.COMP)] = 3;
    try drawWindows(&globals);
    const panel_widgets = mock.widgetCount(.selectable);
    mft_fxsel.browseFromMapping(state, .COMP);
    try drawWindows(&globals);
    // The panel still draws its plates, and the browser draws its window too.
    try std.testing.expect(mock.widgetCount(.selectable) >= panel_widgets);
    try mock.assertBalanced();
}

test "the mapping panel draws the AUTO plate with its actions and parameters, in focus or not, with the stacks balanced" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    globals.mft.fxsel = mft_fxsel.FxSelState{};
    const state = &globals.mft.fxsel.?;
    state.screen = .map;
    state.map_auto.setControl(0, .{ .action = 40364 });
    state.map_auto.setControl(mappings.knob_count + 1, .{ .fx_param = mft_auto.FxParam.init("JS: Saturation", 2) });
    state.map_auto.setControl(12, .{ .action = 99999 });
    try drawWindows(&globals);
    mft_fxsel.selectAuto(state, 1);
    const error_text = "The map file could not be written: AccessDenied.";
    @memcpy(state.map_auto_error[0..error_text.len], error_text);
    try drawWindows(&globals);
    try mock.assertBalanced();
}

test "the OK and Cancel buttons under the actions run the action under the cursor and leave the mode" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    globals.mft.fxsel = mft_fxsel.FxSelState{};
    const state = &globals.mft.fxsel.?;
    mock.click("##buttonCancel");
    try drawWindows(&globals);
    try std.testing.expectEqual(mft_fxsel.Outcome.leave, state.pending);

    state.pending = .none;
    state.action_cursor = @backingInt(mft_fxsel.Action.select_preset);
    mock.resetInteractions();
    mock.click("##buttonOK");
    try drawWindows(&globals);
    try std.testing.expectEqual(mft_fxsel.Outcome.fill_presets, state.pending);
    try std.testing.expectEqual(mft_fxsel.Screen.presets, state.screen);
    try mock.assertBalanced();
}

test "while the MIDI learn is on, a click on the press line of a cell selects its push, and on the turn line its knob" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    globals.mft.fxsel = mft_fxsel.FxSelState{};
    const state = &globals.mft.fxsel.?;
    state.screen = .map;
    state.map_learn = true;
    const comp = mft_fxsel.moduleIndex(.COMP);
    state.map_fx_index[comp] = 3;
    // The press line of the second encoder of the compressor is the push 2, which is the control 17.
    var label_buf: [64:0]u8 = undefined;
    mock.selectItem(std.mem.printSentinel(&label_buf, "-##learn##map{d}_{d}", .{ comp, mappings.knob_count + 1 }, 0) catch unreachable);
    try drawWindows(&globals);
    try std.testing.expectEqual(mft_fxsel.MappableModule.COMP, state.module);
    try std.testing.expectEqual(@as(u8, mappings.knob_count + 1), state.map_selected);
    mock.resetInteractions();
    mock.selectItem(std.mem.printSentinel(&label_buf, "-##learn##map{d}_{d}", .{ comp, 4 }, 0) catch unreachable);
    try drawWindows(&globals);
    try std.testing.expectEqual(@as(u8, 4), state.map_selected);
    try mock.assertBalanced();
}

test "the single FX mode of the mapping panel draws the card of the channel strip, with or without a strip, with the stacks balanced" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    globals.mft.fxsel = mft_fxsel.FxSelState{};
    const state = &globals.mft.fxsel.?;
    state.screen = .map;
    state.map_single = true;
    try drawWindows(&globals);
    const name = "JS: Lumina Channel Strip";
    @memcpy(state.map_strip_name[0..name.len], name);
    state.map_strip_fx = 2;
    state.map_strip.pages[mft_fxsel.moduleIndex(.EQ)].knobs[0] = 3;
    const error_text = "The map file could not be written: AccessDenied.";
    @memcpy(state.map_strip_error[0..error_text.len], error_text);
    try drawWindows(&globals);
    // The key of the single FX mode goes back to the plates of the modules.
    mock.click("##single");
    try drawWindows(&globals);
    try std.testing.expect(!state.map_single);
    try mock.assertBalanced();
}

test "every window draws in French, with the stacks balanced: the device, the settings, the FX Selection on each screen, and the mapping panel" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();
    defer i18n.language = .en;

    var globals: MftGlobals = .{};
    globals.preferences.language = .fr;
    for ([_]MftActiveModule{ .INPUT, .TRANSPORT, .SETTINGS, .AUTO }) |page| {
        globals.mft.active_module = page;
        try drawWindows(&globals);
    }
    try std.testing.expect(i18n.isFrench());
    for (0..settings_rows.row_count) |cursor| {
        globals.mft.settings_cursor = @intCast(cursor);
        try drawWindows(&globals);
    }
    globals.mft.active_module = .INPUT;
    globals.mft.fxsel = mft_fxsel.FxSelState{};
    const state = &globals.mft.fxsel.?;
    try drawWindows(&globals);
    try std.testing.expectEqualStrings("Charger un effet", mft_fxsel.Action.load_fx.label());
    for ([_]mft_fxsel.Screen{ .browse, .presets, .save }) |screen| {
        state.screen = screen;
        try drawWindows(&globals);
    }
    state.maps.add("default");
    state.maps.add("Voix");
    mft_fxsel.openMaps(state, "VST: ReaEQ (Cockos)", "default");
    try drawWindows(&globals);
    state.screen = .map;
    const comp = mft_fxsel.moduleIndex(.COMP);
    const name = "VST: ReaComp (Cockos)";
    @memcpy(state.map_fx_name[comp][0..name.len], name);
    state.map_fx_index[comp] = 3;
    state.map_edits[comp].knobs[0] = 3;
    state.map_edits[comp].names.set(0, "Seuil");
    try drawWindows(&globals);
    state.map_learn = true;
    try drawWindows(&globals);
    state.map_single = true;
    try drawWindows(&globals);
    try mock.assertBalanced();
}

test "every name of the data that the windows translate when they draw it has its French: the REAPER actions, the side keys, the pages" {
    const t = std.testing;
    for (mft_auto.actions) |action| try t.expect(i18n.has(action.label));
    inline for (@typeInfo(MftActiveModule).@"enum".field_names) |page| try t.expect(i18n.has(page));
    inline for (@typeInfo(mft_fxsel.MappableModule).@"enum".field_names) |module| try t.expect(i18n.has(module));
    for ([_][]const u8{ "CHAIN", "HIDE", "FXSEL", "BYPASS", "MUTE", "SOLO", "PHASE" }) |key| try t.expect(i18n.has(key));
}
