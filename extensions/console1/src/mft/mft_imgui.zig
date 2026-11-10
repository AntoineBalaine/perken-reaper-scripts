const std = @import("std");
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
const wizard = @import("mft_wizard.zig");
const device = @import("mft_device.zig");
const mft_fxsel = @import("mft_fxsel.zig");
const browser_source = @import("mft_browser_source.zig");
const fx_browser = @import("fx_browser");
const colors = @import("mft_colors.zig");
const log = std.log.scoped(.mft_imgui);

const plugin_name = "MFT";

var ctx: imgui.ContextPtr = null;
var disabled = false;
var ready = false;
// The fonts belong to the ReaImGui context, and the kit's state (the heights its cards measured) to the window drawn
// in it, so both are made and dropped with the context.
var fonts: panel_fonts.Fonts = .{};
var kit: widgets.Panel = .{};
// The FX SEL mode has a window of its own, as in the Console 1, so it has its own kit state: the heights that the cards of a window measured belong to it.
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
            if (!info.mapped[slot] or wanted & bit == 0) continue;
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
    try draw(globals);
    try drawFxSelWindow(globals);
}

// Forgets the context and what was made in it: the fonts and the kit's state belong to it.
fn dropContext() void {
    ctx = null;
    fonts = .{};
    kit = .{};
    fxsel_kit = .{};
}

/// Where the window opens the first time, in pixels from the top left of the screen.
const window_x: f64 = 80;
const window_y: f64 = 60;
/// The roundness of the window's corners, which is the roundness of the device's body, so that the body fills the window
/// to its edges.
const window_rounding: f64 = 16;
/// The room between the device and the cards under it.
const cards_gap: f64 = 10;

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

    // The settings form and the calibration card belong to the settings mode, and are not shown in the others, unless
    // a calibration is under way. Because a folded device is its header row alone, nothing is under it then.
    const show_cards = !folded and (active == .SETTINGS or globals.wizard.active);
    if (show_cards) {
        imgui.api.SetCursorScreenPos(ctx, response.left, response.bottom + cards_gap);
        imgui.api.Dummy(ctx, 1, 1);
    }
    // Settings mode draws its form under the device; otherwise the buffers stay synced from preferences for the next
    // time it is opened.
    if (show_cards and active == .SETTINGS) {
        try mft_settings.drawForm(&kit, globals, moduleColor(globals, active));
    } else {
        mft_settings.markUnsynced();
    }
    if (show_cards) drawWizard(globals);
}

/// The rows that the list of plugins shows at a time. The cursor stays in the middle when the list is longer.
const browser_rows = 12;

/// The card of the FX SEL mode, under the device: the module that the mode works on, the list of what can be done to it or the list of plugins
/// that can be loaded for it, with the cursor on its entry, and a line that says what the last press did.
fn drawFxSelList(k: *widgets.Panel, globals: *MftGlobals) void {
    const state = &(globals.mft.fxsel orelse return);
    const accent = colors.hueToRgb(mft_fxsel.hue);
    var buf: [160:0]u8 = undefined;
    const title = std.mem.printSentinel(&buf, "FX SEL: {s}", .{@tagName(state.module)}, 0) catch "FX SEL";
    if (!widgets.beginCard(k, title, null, null, accent)) return;
    defer widgets.endCard(k);

    switch (state.screen) {
        .actions => {
            imgui.api.TextColored(ctx, theme.grey, "Turn the encoder 13 and push it, or push a shortcut on the top row. The module is chosen with the buttons of the bottom row.");
            inline for (@typeInfo(mft_fxsel.Action).@"enum".field_names, 0..) |_, i| {
                const action: mft_fxsel.Action = @fromBackingInt(@intCast(i));
                const line = std.mem.printSentinel(&buf, "{s} {s}", .{ if (state.action_cursor == i) ">" else " ", action.label() }, 0) catch "";
                imgui.api.TextColored(ctx, if (state.action_cursor == i) accent else theme.grey, line);
            }
        },
        .browse => {
            const source = browser_source.get(globals, state.browser.count) orelse {
                imgui.api.TextColored(ctx, theme.grey, "The list of plugins could not be read.");
                if (state.noteText().len > 0) imgui.api.TextColored(ctx, theme.amber, state.noteText());
                return;
            };
            const level = state.level(source);
            const count = fx_browser.entryCount(source, level);
            if (count == 0) {
                imgui.api.TextColored(ctx, theme.grey, "Nothing in this list.");
            } else {
                const cursor: usize = state.cursor();
                const first = if (cursor < browser_rows / 2) 0 else @min(cursor - browser_rows / 2, if (count > browser_rows) count - browser_rows else 0);
                const last = @min(count, first + browser_rows);
                for (first..last) |i| {
                    const name = mft_fxsel.entryName(state, source, level, i);
                    const arrow = if (fx_browser.isMenu(source, level, i)) " >" else "";
                    const line = std.mem.printSentinel(&buf, "{s} {s}{s}", .{ if (cursor == i) ">" else " ", name, arrow }, 0) catch "";
                    imgui.api.TextColored(ctx, if (cursor == i) accent else theme.grey, line);
                }
                const where = std.mem.printSentinel(&buf, "{d} of {d}", .{ cursor + 1, count }, 0) catch "";
                imgui.api.TextColored(ctx, theme.grey, where);
            }
        },
    }
    if (state.noteText().len > 0) imgui.api.TextColored(ctx, theme.amber, state.noteText());
}

/// Where the window of the FX SEL mode opens the first time, to the right of the device.
const fxsel_window_x: f64 = window_x + 640;

/// The window of the FX SEL mode, which is a window of its own and is shown only while the mode is open.
fn drawFxSelWindow(globals: *MftGlobals) !void {
    if (globals.mft.fxsel == null) return;
    fxsel_kit.ctx = ctx;
    fxsel_kit.fonts = fonts;
    theme.push(ctx);
    defer theme.pop(ctx);
    if (fonts.text != null) imgui.api.PushFont(ctx, fonts.text);
    defer if (fonts.text != null) imgui.api.PopFont(ctx);
    imgui.api.SetNextWindowPos(ctx, fxsel_window_x, window_y, &imgui.Cond_FirstUseEver, null, null);
    const flags: c_int = imgui.WindowFlags_NoCollapse | imgui.WindowFlags_AlwaysAutoResize;
    const visible = try imgui.Begin(.{ ctx, "MFT FX SEL", null, flags });
    if (!visible) return;
    defer imgui.End(.{ctx}) catch {};
    drawFxSelList(&fxsel_kit, globals);
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
    if (globals.mft.fxsel) |*state| {
        var labels: [16]mft_fxsel.Label = undefined;
        for (&labels, 0..) |*each, i| each.* = mft_fxsel.label(state, i);
        view.fxsel_labels = labels;
        view.fxsel_color = colors.hueToRgb(mft_fxsel.hue);
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
            if (!reaper.TrackFX_GetParamName(track, route.fx_index, @intCast(param), @ptrCast(buf), 32)) _ = std.mem.printSentinel(buf, "Push", .{}, 0) catch {};
        },
        .band => _ = std.mem.printSentinel(buf, "Shape", .{}, 0) catch {},
    }
}

// Reads the parameter values and names of the sixteen encoders for the active page.
fn readKnobInfo(globals: *MftGlobals, active: MftActiveModule) KnobInfo {
    var info = KnobInfo{};
    const module = MappableModule.fromActive(active) orelse return info;
    const track = globals.current_track orelse return info;
    const routing = mft_fx.resolveModule(globals, track, module);
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
    return info;
}

// The calibration wizard is a card of its own: the LED test is a toggle, the step's status is a lamp and a screen in
// the color of the result, and the steps are pushed with buttons.
fn drawWizard(globals: *MftGlobals) void {
    const io = mft_globals.hostIo();
    const w = &globals.wizard;
    if (!widgets.beginCard(&kit, "Calibration", null, null, theme.amber)) return;
    defer widgets.endCard(&kit);

    // The actual color/ring sweep is driven from the control surface's run loop; here the panel only flips the flag
    // so it stays free of the MIDI-out cImport and remains unit-testable.
    var led_test = w.led_test_active;
    if (widgets.toggle(&kit, "LED test", &led_test)) {
        w.led_test_active = led_test;
        if (led_test) w.led_frame = 0;
    }

    if (!w.active) {
        if (widgets.pushButton(&kit, "Start calibration", 0)) w.start();
        return;
    }

    const step = wizard.steps[w.current];
    const result = w.results[w.current];

    var buf: [128:0]u8 = undefined;
    widgets.display(&kit, std.mem.printSentinel(&buf, "Calibration {d}/{d}", .{ w.current + 1, wizard.STEP_COUNT }, 0) catch "Calibration", theme.amber, 200);
    imgui.api.Text(ctx, wizard.describe(step, &buf));
    imgui.api.TextColored(ctx, theme.grey, wizard.expectedText(step, &buf));
    imgui.api.Text(ctx, wizard.observedText(result, &buf));

    const status_color = switch (result.status) {
        .pass => theme.green,
        .fail => theme.red,
        .pending, .skipped => theme.grey,
    };
    widgets.lamp(&kit, status_color, result.status == .pass or result.status == .fail);
    imgui.api.SameLine(ctx, null, null);
    widgets.display(&kit, @tagName(result.status), status_color, 90);

    if (widgets.pushButton(&kit, "Retry", 0)) w.retry();
    imgui.api.SameLine(ctx, null, null);
    if (widgets.pushButton(&kit, "Skip", 0)) w.skip();
    imgui.api.SameLine(ctx, null, null);
    if (w.isLast()) {
        if (widgets.pushButton(&kit, "Finish", 0)) {
            wizard.writeReport(w, io, globals.resource_path) catch |err| log.err("report write failed: {s}", .{@errorName(err)});
            w.stop();
        }
    } else {
        if (widgets.pushButton(&kit, "Next", 0)) w.next();
    }
    imgui.api.SameLine(ctx, null, null);
    if (widgets.pushButton(&kit, "Stop", 0)) {
        wizard.writeReport(w, io, globals.resource_path) catch {};
        w.stop();
    }
}

// Run the panel against the mock ImGui and assert every window, child, group,
// and style-color push/pop is balanced.
const MockImGui = @import("mock_imgui").MockImGui;

fn assertPanelBalanced(module: MftActiveModule, calibrating: bool) !void {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    globals.mft.active_module = module;
    if (calibrating) globals.wizard.start();
    try draw(&globals);
    try mock.assertBalanced();
}

test "panel balanced across modes" {
    try assertPanelBalanced(.INPUT, false);
    try assertPanelBalanced(.TRANSPORT, false);
    try assertPanelBalanced(.SETTINGS, false);
    try assertPanelBalanced(.INPUT, true);
    try assertPanelBalanced(.SETTINGS, true);
}

test "a folded panel is balanced too, with the cards of the settings mode hidden under the header row" {
    folded = true;
    defer folded = false;
    try assertPanelBalanced(.SETTINGS, true);
    try assertPanelBalanced(.TRANSPORT, false);
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

test "the settings form leaves the stacks balanced wherever the cursor is" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    globals.mft.active_module = .SETTINGS;
    // A color row, the sensitivity, the first and the last plugin name.
    for ([_]i16{ 0, mft_settings.SENSITIVITY_ROW, mft_settings.PLUGIN_ROW, mft_settings.ITEM_COUNT - 1 }) |cursor| {
        globals.mft.settings_cursor = @intCast(cursor);
        try draw(&globals);
    }
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
