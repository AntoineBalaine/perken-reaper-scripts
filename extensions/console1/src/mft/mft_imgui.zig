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
const wizard = @import("mft_wizard.zig");
const log = std.log.scoped(.mft_imgui);

const color_pass: c_int = @bitCast(@as(u32, 0x66CC66FF));
const color_fail: c_int = @bitCast(@as(u32, 0xFF5555FF));
const color_muted: c_int = @bitCast(@as(u32, 0x999999FF));

const plugin_name = "MFT";

var ctx: imgui.ContextPtr = null;
var disabled = false;
var ready = false;

// Encoder labels for the 4x4 grid. The top eight are parameter knobs; the
// bottom eight are module selectors (last two reserved).
const knob_labels = [8][:0]const u8{ "K1", "K2", "K3", "K4", "K5", "K6", "K7", "K8" };
const module_labels = [6][:0]const u8{ "IO", "GATE", "EQ", "COMP", "SET", "TRANS" };
const left_labels = [3][:0]const u8{ "L1", "L2", "L3" };
const right_labels = [3][:0]const u8{ "R1", "R2", "R3" };

// Panel display colors per module (packed 0xRRGGBBAA), chosen to echo the
// hardware LED hues.
fn uiColor(module: MftActiveModule) c_int {
    return switch (module) {
        .IO => @bitCast(@as(u32, 0x33CCFFFF)),
        .GATE => @bitCast(@as(u32, 0xFF99CCFF)),
        .EQ => @bitCast(@as(u32, 0x66CC66FF)),
        .COMP => @bitCast(@as(u32, 0xFF5555FF)),
        .SETTINGS, .TRANSPORT => @bitCast(@as(u32, 0x999999FF)),
    };
}

// Render a normalized value as an eight-segment bar like "[####----]".
fn gauge(value: f64, buf: *[16:0]u8) [:0]const u8 {
    const clamped = std.math.clamp(value, 0.0, 1.0);
    const filled: usize = @intFromFloat(@round(clamped * 8.0));
    var tmp: [8]u8 = undefined;
    for (0..8) |i| tmp[i] = if (i < filled) '#' else '-';
    return std.fmt.bufPrintZ(buf, "[{s}]", .{tmp[0..8]}) catch buf[0..0 :0];
}

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
    }
    draw(MftGlobals.get()) catch |err| {
        log.err("MFT panel draw error: {s}", .{@errorName(err)});
    };
}

fn draw(globals: *MftGlobals) !void {
    if (!try imgui.Begin(.{ ctx, plugin_name })) {
        imgui.End(.{ctx}) catch {};
        return;
    }
    defer imgui.End(.{ctx}) catch {};

    const active = globals.mft.active_module;
    try imgui.TextColored(.{ ctx, uiColor(active), @tagName(active) });
    try imgui.Separator(.{ctx});

    // Settings mode draws its form above the grid; otherwise the buffers stay
    // synced from preferences for the next time it is opened.
    if (active == .SETTINGS) {
        try mft_settings.drawForm(ctx, globals);
        try imgui.Separator(.{ctx});
    } else {
        mft_settings.markUnsynced();
    }

    // Read the eight top-row parameter values for the active module.
    var vals = [_]f64{0.0} ** 8;
    var mapped = [_]bool{false} ** 8;
    if (MappableModule.fromActive(active)) |module| {
        if (globals.current_track) |track| {
            const routing = mft_fx.resolveModule(globals, track, module);
            for (routing.targets, 0..) |maybe_target, slot| {
                if (maybe_target) |target| {
                    vals[slot] = reaper.TrackFX_GetParamNormalized(track, target.fx_index, @intCast(target.param));
                    mapped[slot] = true;
                }
            }
        }
    }

    // Left side buttons.
    try imgui.BeginGroup(.{ctx});
    for (left_labels) |lbl| {
        _ = try imgui.Button(.{ ctx, lbl, 34.0, 24.0 });
    }
    imgui.EndGroup(.{ctx}) catch {};
    try imgui.SameLine(.{ctx});

    // 4x4 encoder grid.
    try imgui.BeginGroup(.{ctx});
    var row: usize = 0;
    while (row < 4) : (row += 1) {
        var col: usize = 0;
        while (col < 4) : (col += 1) {
            const idx = row * 4 + col;
            if (col > 0) try imgui.SameLine(.{ctx});
            try drawCell(idx, &vals, &mapped, active);
        }
    }
    imgui.EndGroup(.{ctx}) catch {};
    try imgui.SameLine(.{ctx});

    // Right side buttons.
    try imgui.BeginGroup(.{ctx});
    for (right_labels) |lbl| {
        _ = try imgui.Button(.{ ctx, lbl, 34.0, 24.0 });
    }
    imgui.EndGroup(.{ctx}) catch {};

    try drawWizard(globals);
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

fn drawCell(idx: usize, vals: *const [8]f64, mapped: *const [8]bool, active: MftActiveModule) !void {
    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    if (idx < 8) {
        try imgui.Text(.{ ctx, knob_labels[idx] });
        switch (active) {
            // Transport mode labels the top row with each encoder's rotation
            // function and its press function.
            .TRANSPORT => {
                try imgui.Text(.{ ctx, mft_transport.rotationLabel(idx) });
                try imgui.Text(.{ ctx, mft_transport.pressLabel(idx) });
            },
            // Settings mode has no options yet.
            .SETTINGS => try imgui.Text(.{ ctx, "-" }),
            // A mappable module shows an eight-segment ASCII gauge for the value.
            // Text keeps the panel testable against the mock ImGui (which does
            // not mock ProgressBar).
            else => {
                var gauge_buf: [16:0]u8 = undefined;
                try imgui.Text(.{ ctx, gauge(if (mapped[idx]) vals[idx] else 0.0, &gauge_buf) });
            },
        }
        return;
    }

    if (moduleForCell(idx)) |module| {
        const is_active = module == active;
        if (is_active) try imgui.PushStyleColor(.{ ctx, imgui.Col_Button, uiColor(module) });
        defer if (is_active) imgui.PopStyleColor(.{ ctx, 1 }) catch {};
        _ = try imgui.Button(.{ ctx, module_labels[idx - 8], 72.0, 30.0 });
    } else {
        // Reserved encoder: a placeholder with a unique id.
        const label = if (idx == 14) "-##14" else "-##15";
        _ = try imgui.Button(.{ ctx, label, 72.0, 30.0 });
    }
}

// Run the panel against the mock ImGui and assert every Begin/End, group, and
// style-color push/pop is balanced. This is the balance checker Antoine's
// reaziglib provides; it catches a stray End or an unpopped style at compile of
// the test run rather than as a runtime ImGui error.
const MockImGui = @import("mock_imgui").MockImGui;

test "panel: begin/end pairs balanced (idle)" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    try draw(&globals);
    try mock.assertBalanced();
}

test "panel: begin/end pairs balanced (calibration active)" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    globals.wizard.start();
    try draw(&globals);
    try mock.assertBalanced();
}

test "panel: begin/end pairs balanced (transport mode)" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    globals.mft.active_module = .TRANSPORT;
    try draw(&globals);
    try mock.assertBalanced();
}

test "panel: begin/end pairs balanced (settings mode)" {
    var mock = MockImGui.init(std.testing.allocator);
    defer mock.deinit();
    mock.install();
    defer mock.restore();

    var globals: MftGlobals = .{};
    globals.mft.active_module = .SETTINGS;
    try draw(&globals);
    try mock.assertBalanced();
}
