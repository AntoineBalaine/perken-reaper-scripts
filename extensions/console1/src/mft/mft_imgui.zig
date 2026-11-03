const std = @import("std");
const mft_globals = @import("mft_globals.zig");
const builtin = @import("builtin");
const imgui = @import("reaper_imgui");
const reaper = @import("reaper").reaper;
const MftGlobals = @import("mft_globals.zig").MftGlobals;
const MftActiveModule = @import("mft_state.zig").MftActiveModule;
const mappings = @import("mft_mappings.zig");
const MappableModule = mappings.MappableModule;
const mft_fx = @import("mft_fx.zig");
const mft_settings = @import("mft_settings.zig");
const theme = @import("panel_theme");
const panel_fonts = @import("panel_fonts");
const widgets = @import("panel_widgets");
const wizard = @import("mft_wizard.zig");
const device = @import("mft_device.zig");
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
// Whether the device is folded to its header row. Because the player folds the panel for the whole session, the state
// is kept when the context is dropped.
var folded = false;
// When each top encoder was last turned, so that the pop-up of its value can show for a moment after the turn.
var activity: Activity = .{};
// The formatted values of the knobs that show one, kept until the value changes.
var formatted_values: FormattedValues = .{};

const KnobInfo = device.KnobInfo;

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
    last: [8]f64 = @splat(0.0),
    engaged_at: [8]i64 = @splat(never),
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
    pub fn update(self: *Activity, module: MftActiveModule, track: reaper.MediaTrack, info: *const KnobInfo, engaged: u8, now_ms: i64) u8 {
        if (self.module != module or self.track != track) {
            self.module = module;
            self.track = track;
            self.last = info.vals;
            self.engaged_at = @splat(never);
        }
        var bits: u8 = 0;
        for (0..8) |slot| {
            const turned = info.mapped[slot] and @abs(info.vals[slot] - self.last[slot]) > threshold;
            const bit = @as(u8, 1) << @intCast(slot);
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
    bufs: [8][formatted_len:0]u8 = undefined,
    ok: [8]bool = @splat(false),
    asked_for: [8]f64 = @splat(-1.0),
    module: ?MftActiveModule = null,
    track: reaper.MediaTrack = null,
    source: FormatSource = &reaperFormat,
    /// How many times the plugin was asked, which the tests count.
    asks: usize = 0,

    /// Fills the formatted values of `info` for the encoders in `wanted`, one bit each. An empty text or a failed call
    /// leaves the encoder with its percentage.
    pub fn fill(self: *FormattedValues, module: MftActiveModule, track: reaper.MediaTrack, info: *KnobInfo, wanted: u8) void {
        if (self.module != module or self.track != track) {
            self.module = module;
            self.track = track;
            self.ok = @splat(false);
            self.asked_for = @splat(-1.0);
        }
        const track_ptr = track orelse return;
        for (0..8) |slot| {
            const bit = @as(u8, 1) << @intCast(slot);
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
    draw(globals) catch |err| {
        log.err("MFT panel draw error: {s}", .{@errorName(err)});
        if (imgui.last_error) |msg| log.err("imgui: {s}", .{std.mem.span(msg)});
        // Because ReaImGui destroys a context after an ImGui assertion fails, our
        // handle may now be dangling. We drop it so that the next tick creates a
        // fresh context instead of failing on every frame.
        dropContext();
    };
}

// Forgets the context and what was made in it: the fonts and the kit's state belong to it.
fn dropContext() void {
    ctx = null;
    fonts = .{};
    kit = .{};
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
    // The pop-ups of the values follow the mouse and the held encoders, and linger for a moment after them.
    const engaged = device.hoveredKnobs(&kit, widgets.cursorScreenPos(&kit), &view) | @as(u8, @truncate(view.held));
    view.show_value = activity.update(active, globals.current_track, &view.knobs, engaged, now_ms);
    // Only the knobs that show a value ask the plugin for its text. The other modes than the pop-up show it always.
    const wanted: u8 = if (view.value_mode == .popup) view.show_value else 0xFF;
    formatted_values.fill(active, globals.current_track, &view.knobs, wanted);
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

/// What the device shows this frame: the colors of the modules, the parameters of the active module, the encoders that
/// are held, and the state of the track's mute, solo and phase.
fn readView(globals: *MftGlobals) device.View {
    var module_colors: [6]c_int = undefined;
    inline for (@typeInfo(MftActiveModule).@"enum".field_values, 0..) |field_value, i| {
        module_colors[i] = moduleColor(globals, @fromBackingInt(@intCast(field_value)));
    }
    const active = globals.mft.active_module;
    const view = device.View{
        .active = active,
        .colors = module_colors,
        .knobs = readKnobInfo(globals, active),
        .held = globals.mft.held_encoders,
        .side_lit = readSideLit(globals),
        .online = globals.online,
        .collapsed = folded,
    };
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

// Reads the eight top-row parameter values and names for the active module.
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
    try assertPanelBalanced(.IO, false);
    try assertPanelBalanced(.TRANSPORT, false);
    try assertPanelBalanced(.SETTINGS, false);
    try assertPanelBalanced(.IO, true);
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
    for ([_]u8{ 0, 6, 7, 11 }) |cursor| {
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
    info.vals = .{ 0.2, 0.7, 0, 0, 0, 0, 0, 0 };
    const first: u8 = 0b01;
    const linger = value_linger_ms;

    // The first frame of a module only learns the values, because nobody turned anything.
    try std.testing.expectEqual(@as(u8, 0), tracker.update(.IO, null, &info, 0, 1000));
    try std.testing.expectEqual(@as(u8, 0), tracker.update(.IO, null, &info, 0, 1016));
    // The first encoder turns, and its pop-up stays for the linger time.
    info.vals[0] = 0.3;
    try std.testing.expectEqual(first, tracker.update(.IO, null, &info, 0, 2000));
    try std.testing.expectEqual(first, tracker.update(.IO, null, &info, 0, 2000 + linger - 1));
    try std.testing.expectEqual(@as(u8, 0), tracker.update(.IO, null, &info, 0, 2000 + linger));
    // The mouse hovers over the first encoder: the pop-up stays as long as the mouse is there, then lingers.
    try std.testing.expectEqual(first, tracker.update(.IO, null, &info, first, 5000));
    try std.testing.expectEqual(first, tracker.update(.IO, null, &info, first, 9000));
    try std.testing.expectEqual(first, tracker.update(.IO, null, &info, 0, 9000 + linger - 1));
    try std.testing.expectEqual(@as(u8, 0), tracker.update(.IO, null, &info, 0, 9000 + linger));
    // An encoder with nothing mapped never shows a value, and a change of module brings values nobody turned.
    try std.testing.expectEqual(@as(u8, 0), tracker.update(.IO, null, &info, 0b100, 12000));
    info.vals[1] = 0.9;
    try std.testing.expectEqual(@as(u8, 0), tracker.update(.GATE, null, &info, 0, 13000));
}

test "the mouse over a knob is found, and a folded device has no knob to hover" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var panel = widgets.Panel{};
    var view = device.View{ .active = .IO, .colors = @splat(0x11) };
    // The mock's cursor is at the origin, so that the second knob of the first row is at this place.
    const cell = device.cellAt(1, device.pad + device.side_w + device.side_gap, device.pad + device.header_h, view.value_mode);
    mock.mouse_x = cell.cx;
    mock.mouse_y = cell.cy;
    try std.testing.expectEqual(@as(u8, 0b10), device.hoveredKnobs(&panel, .{ .x = 0, .y = 0 }, &view));
    view.collapsed = true;
    try std.testing.expectEqual(@as(u8, 0), device.hoveredKnobs(&panel, .{ .x = 0, .y = 0 }, &view));
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
