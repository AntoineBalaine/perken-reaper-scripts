const std = @import("std");
const builtin = @import("builtin");
const imgui = @import("reaper_imgui");
const reaper = @import("reaper").reaper;
const MftGlobals = @import("mft_globals.zig").MftGlobals;
const MftActiveModule = @import("mft_state.zig").MftActiveModule;
const mappings = @import("mft_mappings.zig");
const MappableModule = mappings.MappableModule;
const mft_fx = @import("mft_fx.zig");
const mft_transport = @import("mft_transport.zig");
const mft_settings = @import("mft_settings.zig");
const theme = @import("panel_theme");
const panel_fonts = @import("panel_fonts");
const widgets = @import("panel_widgets");
const wizard = @import("mft_wizard.zig");
const log = std.log.scoped(.mft_imgui);

const color_pass: c_int = @bitCast(@as(u32, 0x66CC66FF));
const color_fail: c_int = @bitCast(@as(u32, 0xFF5555FF));
const color_muted: c_int = @bitCast(@as(u32, 0x999999FF));

const plugin_name = "MFT";
// The width of a cell's screen, and the distance from one column of cells to the next.
const CELL_W: f64 = 96.0;
const CELL_PITCH: f64 = 108.0;
const SIDE_W: f64 = 72.0;
const WINDOW_W: f64 = 640.0;
const WINDOW_H: f64 = 620.0;

// A dial shows a normalized parameter as a percentage.
const dial_control = widgets.Control{ .id = "mft-dial", .low = 0, .high = 100, .unit = "%" };

const left_labels = [3][:0]const u8{ "L1 Chain", "L2 Hide", "L3 FXsel" };
const right_labels = [3][:0]const u8{ "R1 Mute", "R2 Solo", "R3 Phase" };

var ctx: imgui.ContextPtr = null;
var disabled = false;
var ready = false;
// The fonts belong to the ReaImGui context, and the kit's state (the heights its cards measured) to the window drawn
// in it, so both are made and dropped with the context.
var fonts: panel_fonts.Fonts = .{};
var kit: widgets.Panel = .{};

// Short module names shown on the bottom-row selector cells.
const module_labels = [6][:0]const u8{ "IO", "GATE", "EQ", "COMP", "SETTINGS", "TRANSPORT" };

// Convert an HSV color (h in degrees, s and v in 0..1) to a packed 0xRRGGBBAA
// ImGui color.
fn hsvToRgb(h: f32, s: f32, v: f32) c_int {
    const c = v * s;
    const hp = h / 60.0;
    const x = c * (1.0 - @abs(@mod(hp, 2.0) - 1.0));
    var r: f32 = 0;
    var g: f32 = 0;
    var b: f32 = 0;
    if (hp < 1.0) {
        r = c;
        g = x;
    } else if (hp < 2.0) {
        r = x;
        g = c;
    } else if (hp < 3.0) {
        g = c;
        b = x;
    } else if (hp < 4.0) {
        g = x;
        b = c;
    } else if (hp < 5.0) {
        r = x;
        b = c;
    } else {
        r = c;
        b = x;
    }
    const m = v - c;
    const ri: u32 = @intFromFloat(std.math.clamp((r + m) * 255.0, 0.0, 255.0));
    const gi: u32 = @intFromFloat(std.math.clamp((g + m) * 255.0, 0.0, 255.0));
    const bi: u32 = @intFromFloat(std.math.clamp((b + m) * 255.0, 0.0, 255.0));
    return @bitCast((ri << 24) | (gi << 16) | (bi << 8) | 0xFF);
}

// Map the MFT color-wheel hue (0-127) to an RGB color for the panel, so the UI
// matches the controller's color code. On the wheel red sits near 0x56 (86);
// increasing hue moves toward blue below it and purple above, so the HSV angle
// is roughly (86 - hue) * (360/128).
fn hueToRgb(hue: u8) c_int {
    const deg = @mod((86.0 - @as(f32, @floatFromInt(hue))) * (360.0 / 128.0), 360.0);
    return hsvToRgb(deg, 1.0, 1.0);
}

fn moduleColor(globals: *MftGlobals, module: MftActiveModule) c_int {
    return hueToRgb(globals.preferences.colorForModule(module));
}

// Per-frame display data for the eight top-row knobs of the active module.
const KnobInfo = struct {
    vals: [8]f64 = [_]f64{0.0} ** 8,
    mapped: [8]bool = [_]bool{false} ** 8,
    name_bufs: [8][64:0]u8 = undefined,
    has_name: [8]bool = [_]bool{false} ** 8,

    fn name(self: *const KnobInfo, slot: usize) [:0]const u8 {
        return std.mem.sliceTo(&self.name_bufs[slot], 0);
    }
};

// The module a bottom-row encoder selects, or null for the two reserved cells.
fn moduleForCell(idx: usize) ?MftActiveModule {
    return switch (idx) {
        8 => .IO,
        9 => .GATE,
        10 => .EQ,
        11 => .COMP,
        12 => .SETTINGS,
        13 => .TRANSPORT,
        else => null,
    };
}

pub fn register() void {
    if (comptime builtin.is_test) return;
    _ = reaper.plugin_register("timer", @constCast(@ptrCast(&onTimer)));
}

fn onTimer() callconv(.C) void {
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
            _ = reaper.plugin_register("-timer", @constCast(@ptrCast(&onTimer)));
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

fn draw(globals: *MftGlobals) !void {
    // Only called while the panel is visible: onTimer owns the hide/show cycle by
    // dropping the context when hidden, so draw always submits the window.
    kit.ctx = ctx;
    kit.fonts = fonts;

    // The palette and style of the shared panel kit go around the whole window, and so does the text font.
    theme.push(ctx);
    defer theme.pop(ctx);
    if (fonts.text != null) imgui.api.PushFont(ctx, fonts.text);
    defer if (fonts.text != null) imgui.api.PopFont(ctx);

    imgui.api.SetNextWindowSize(ctx, WINDOW_W, WINDOW_H, &imgui.Cond_FirstUseEver);
    if (try imgui.Begin(.{ ctx, plugin_name })) {
        defer imgui.End(.{ctx}) catch {};

        const active = globals.mft.active_module;
        const accent = moduleColor(globals, active);
        std.debug.assert(accent != 0);

        // Because a card that is not drawn is not followed by `endCard`, each card is closed by a defer inside the
        // branch that opened it.
        if (widgets.beginCard(&kit, plugin_name, null, null, accent)) {
            defer widgets.endCard(&kit);
            widgets.display(&kit, @tagName(active), accent, 160);
        }

        // Settings mode draws its form above the grid; otherwise the buffers stay
        // synced from preferences for the next time it is opened.
        if (active == .SETTINGS) {
            try mft_settings.drawForm(ctx, globals);
        } else {
            mft_settings.markUnsynced();
        }

        const info = readKnobInfo(globals, active);

        if (widgets.beginCard(&kit, "Encoders", null, null, accent)) {
            defer widgets.endCard(&kit);
            drawSideColumn(&left_labels);
            imgui.api.SameLine(ctx, null, null);
            drawGrid(globals, &info, active, accent);
            imgui.api.SameLine(ctx, null, null);
            drawSideColumn(&right_labels);
        }

        try drawWizard(globals);
    }
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
        if (reaper.TrackFX_GetParamName(track, target.fx_index, @intCast(target.param), @ptrCast(&info.name_bufs[slot]), 64)) {
            info.has_name[slot] = true;
        }
    }
    return info;
}

// A column of the side buttons, each shown on a recessed screen with the function it has. Because the panel mirrors
// the controller, they are screens and not buttons: a button that answers the mouse and does nothing would mislead.
fn drawSideColumn(labels: *const [3][:0]const u8) void {
    imgui.api.BeginGroup(ctx);
    defer imgui.api.EndGroup(ctx);
    for (labels) |label| widgets.display(&kit, label, theme.text, SIDE_W);
}

// The 4x4 grid of the encoders. Each column starts at a fixed distance from the first, so that the cells line up
// whatever the width of their text.
fn drawGrid(globals: *MftGlobals, info: *const KnobInfo, active: MftActiveModule, accent: c_int) void {
    imgui.api.BeginGroup(ctx);
    defer imgui.api.EndGroup(ctx);
    for (0..4) |row| {
        for (0..4) |col| {
            if (col > 0) {
                var offset = @as(f64, @floatFromInt(col)) * CELL_PITCH;
                imgui.api.SameLine(ctx, &offset, null);
            }
            drawCell(globals, row * 4 + col, info, active, accent);
        }
    }
}

// Draws one cell of the grid: a dial or the transport functions for the top eight encoders, and the module selector
// for the bottom eight.
fn drawCell(globals: *MftGlobals, idx: usize, info: *const KnobInfo, active: MftActiveModule, accent: c_int) void {
    imgui.api.BeginGroup(ctx);
    defer imgui.api.EndGroup(ctx);
    var lbl_buf: [8:0]u8 = undefined;
    const klabel = std.fmt.bufPrintZ(&lbl_buf, "K{d}", .{idx + 1}) catch "K";
    if (idx < 8) {
        drawKnobCell(idx, info, active, accent, klabel);
    } else {
        drawModuleCell(globals, idx, active, klabel);
    }
}

// One of the top eight encoders.
fn drawKnobCell(idx: usize, info: *const KnobInfo, active: MftActiveModule, accent: c_int, klabel: [:0]const u8) void {
    switch (active) {
        // Transport mode shows each encoder's rotation and press function.
        .TRANSPORT => {
            widgets.centeredValue(&kit, klabel, CELL_W, theme.label);
            widgets.centeredValue(&kit, mft_transport.rotationLabel(idx), CELL_W, theme.text);
            widgets.centeredValue(&kit, mft_transport.pressLabel(idx), CELL_W, theme.text_dim);
        },
        .SETTINGS => {
            widgets.centeredValue(&kit, klabel, CELL_W, theme.label);
            widgets.centeredValue(&kit, "-", CELL_W, theme.text_dim);
        },
        // A mappable module: the mapped parameter's name is the dial's label. An encoder with nothing mapped shows
        // a dim dial at zero under its own number.
        else => {
            const name: []const u8 = if (info.has_name[idx]) info.name(idx) else klabel;
            const normalized = std.math.clamp(info.vals[idx], 0.0, 1.0);
            const percent: i32 = @intFromFloat(@round(normalized * 100.0));
            widgets.dial(&kit, dial_control, if (info.mapped[idx]) percent else 0, name, if (info.mapped[idx]) accent else theme.text_dim);
            widgets.tooltip(&kit, "Hold the encoder while turning for fine adjustment");
        },
    }
}

// One of the bottom eight encoders: a module selector, with a lamp in the module's color that is lit for the active
// module, or a reserved cell.
fn drawModuleCell(globals: *MftGlobals, idx: usize, active: MftActiveModule, klabel: [:0]const u8) void {
    const module = moduleForCell(idx) orelse {
        widgets.centeredValue(&kit, klabel, CELL_W, theme.label);
        widgets.display(&kit, "-", theme.text_dim, CELL_W);
        return;
    };
    const color = moduleColor(globals, module);
    const lit = module == active;
    widgets.lamp(&kit, color, lit);
    imgui.api.SameLine(ctx, null, null);
    widgets.centeredValue(&kit, klabel, CELL_W - 24, theme.label);
    widgets.display(&kit, module_labels[idx - 8], if (lit) color else theme.text_dim, CELL_W);
}

fn drawWizard(globals: *MftGlobals) !void {
    const w = &globals.wizard;
    try imgui.Separator(.{ctx});

    // LED test toggle. The actual color/ring sweep is driven from the control
    // surface's run loop; here the panel only flips the flag so it stays free of
    // the MIDI-out cImport and remains unit-testable.
    if (w.led_test_active) {
        if (try imgui.Button(.{ ctx, "Stop LED test" })) w.led_test_active = false;
    } else if (try imgui.Button(.{ ctx, "LED test" })) {
        w.led_test_active = true;
        w.led_frame = 0;
    }

    if (!w.active) {
        if (try imgui.Button(.{ ctx, "Start calibration" })) w.start();
        return;
    }

    const step = wizard.steps[w.current];
    const result = w.results[w.current];

    var buf: [128:0]u8 = undefined;
    try imgui.Text(.{ ctx, std.fmt.bufPrintZ(&buf, "Calibration {d}/{d}", .{ w.current + 1, wizard.STEP_COUNT }) catch "Calibration" });
    try imgui.Text(.{ ctx, wizard.describe(step, &buf) });
    try imgui.TextColored(.{ ctx, color_muted, wizard.expectedText(step, &buf) });
    try imgui.Text(.{ ctx, wizard.observedText(result, &buf) });

    const status_color = switch (result.status) {
        .pass => color_pass,
        .fail => color_fail,
        .pending, .skipped => color_muted,
    };
    try imgui.TextColored(.{ ctx, status_color, @tagName(result.status) });

    if (try imgui.Button(.{ ctx, "Retry" })) w.retry();
    try imgui.SameLine(.{ctx});
    if (try imgui.Button(.{ ctx, "Skip" })) w.skip();
    try imgui.SameLine(.{ctx});
    if (w.isLast()) {
        if (try imgui.Button(.{ ctx, "Finish" })) {
            wizard.writeReport(w, globals.resource_path) catch |err| log.err("report write failed: {s}", .{@errorName(err)});
            w.stop();
        }
    } else {
        if (try imgui.Button(.{ ctx, "Next" })) w.next();
    }
    try imgui.SameLine(.{ctx});
    if (try imgui.Button(.{ ctx, "Stop" })) {
        wizard.writeReport(w, globals.resource_path) catch {};
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
}

test "every cell of the grid leaves the stacks balanced, mapped or not, in every kind of mode" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    var info = KnobInfo{};
    // The first encoder has a parameter mapped, with a name, and the second has one without a name.
    info.mapped[0] = true;
    info.vals[0] = 0.5;
    info.has_name[0] = true;
    @memcpy(info.name_bufs[0][0..4], "Gain");
    info.name_bufs[0][4] = 0;
    info.mapped[1] = true;
    info.vals[1] = 2.0;

    for ([_]MftActiveModule{ .IO, .TRANSPORT, .SETTINGS }) |module| {
        const accent = moduleColor(&globals, module);
        for (0..16) |idx| drawCell(&globals, idx, &info, module, accent);
    }
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
