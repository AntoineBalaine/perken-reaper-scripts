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
const mft_theme = @import("mft_theme.zig");
const wizard = @import("mft_wizard.zig");
const log = std.log.scoped(.mft_imgui);

const color_pass: c_int = @bitCast(@as(u32, 0x66CC66FF));
const color_fail: c_int = @bitCast(@as(u32, 0xFF5555FF));
const color_muted: c_int = @bitCast(@as(u32, 0x999999FF));

const plugin_name = "MFT";
const CELL_W: f64 = 96.0;
const CELL_H: f64 = 80.0;
const SIDE_W: f64 = 72.0;
const SIDE_H: f64 = 26.0;

var ctx: imgui.ContextPtr = null;
var disabled = false;
var ready = false;

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
        if (imgui.last_error) |msg| log.err("imgui: {s}", .{std.mem.span(msg)});
    };
}

fn draw(globals: *MftGlobals) !void {
    // Side button L2 hides the panel: with no Begin call the window disappears.
    if (!globals.mft.panel_visible) return;

    // Match the Console One palette and style around the whole window.
    const style = mft_theme.pushStyle(ctx);
    defer mft_theme.popStyle(ctx, style);

    if (try imgui.Begin(.{ ctx, plugin_name, null, imgui.WindowFlags_NoCollapse })) {
        defer imgui.End(.{ctx}) catch {};

        const active = globals.mft.active_module;
        try imgui.TextColored(.{ ctx, moduleColor(globals, active), @tagName(active) });
        try imgui.Separator(.{ctx});

        // Settings mode draws its form above the grid; otherwise the buffers stay
        // synced from preferences for the next time it is opened.
        if (active == .SETTINGS) {
            try mft_settings.drawForm(ctx, globals);
            try imgui.Separator(.{ctx});
        } else {
            mft_settings.markUnsynced();
        }

        // Read the eight top-row parameter values and names for the active module.
        var info = KnobInfo{};
        if (MappableModule.fromActive(active)) |module| {
            if (globals.current_track) |track| {
                const routing = mft_fx.resolveModule(globals, track, module);
                for (routing.targets, 0..) |maybe_target, slot| {
                    if (maybe_target) |target| {
                        info.vals[slot] = reaper.TrackFX_GetParamNormalized(track, target.fx_index, @intCast(target.param));
                        info.mapped[slot] = true;
                        if (reaper.TrackFX_GetParamName(track, target.fx_index, @intCast(target.param), @ptrCast(&info.name_bufs[slot]), 64)) {
                            info.has_name[slot] = true;
                        }
                    }
                }
            }
        }

        // Each group result is captured before the defer so EndGroup is always called
        // even if BeginGroup errors, keeping the ImGui group stack balanced.
        // Left side buttons, labeled with their function.
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            _ = try imgui.Button(.{ ctx, "L1 Chain", SIDE_W, SIDE_H });
            _ = try imgui.Button(.{ ctx, "L2 Hide", SIDE_W, SIDE_H });
            _ = try imgui.Button(.{ ctx, "L3 FXsel", SIDE_W, SIDE_H });
        }
        try imgui.SameLine(.{ctx});

        // 4x4 encoder grid.
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            var row: usize = 0;
            while (row < 4) : (row += 1) {
                var col: usize = 0;
                while (col < 4) : (col += 1) {
                    const idx = row * 4 + col;
                    if (col > 0) try imgui.SameLine(.{ctx});
                    try drawCell(globals, idx, &info, active);
                }
            }
        }
        try imgui.SameLine(.{ctx});

        // Right side buttons, labeled with their function.
        {
            try imgui.BeginGroup(.{ctx});
            defer imgui.EndGroup(.{ctx}) catch {};
            _ = try imgui.Button(.{ ctx, "R1 Mute", SIDE_W, SIDE_H });
            _ = try imgui.Button(.{ ctx, "R2 Solo", SIDE_W, SIDE_H });
            _ = try imgui.Button(.{ ctx, "R3 Phase", SIDE_W, SIDE_H });
        }

        try drawWizard(globals);
    }
}

// Draw one knob or module-selector cell as a bordered box holding its label and,
// depending on the mode, its value and press action. Module cells carry the
// module's color on the border and show the mode name under the knob label.
fn drawCell(globals: *MftGlobals, idx: usize, info: *const KnobInfo, active: MftActiveModule) !void {
    var id_buf: [12:0]u8 = undefined;
    const cell_id = std.fmt.bufPrintZ(&id_buf, "##c{d}", .{idx}) catch "##c";

    const border_color: ?c_int = if (moduleForCell(idx)) |m| moduleColor(globals, m) else null;
    if (border_color) |bc| try imgui.PushStyleColor(.{ ctx, imgui.Col_Border, bc });
    defer if (border_color != null) imgui.PopStyleColor(.{ ctx, 1 }) catch {};

    // NoScrollbar prevents a too-tight box from spawning a scrollbar; the box is
    // sized to fit its lines. Same defer-before-try pattern as the outer Begin.
    const child_result = imgui.BeginChild(.{ ctx, cell_id, CELL_W, CELL_H, imgui.ChildFlags_Border, imgui.WindowFlags_NoScrollbar });
    defer imgui.EndChild(.{ctx}) catch {};
    _ = try child_result;

    var lbl_buf: [8:0]u8 = undefined;
    const klabel = std.fmt.bufPrintZ(&lbl_buf, "K{d}", .{idx + 1}) catch "K";

    if (idx < 8) {
        switch (active) {
            // Transport mode shows each encoder's rotation and press function.
            .TRANSPORT => {
                try imgui.Text(.{ ctx, klabel });
                try imgui.Text(.{ ctx, mft_transport.rotationLabel(idx) });
                try imgui.Text(.{ ctx, mft_transport.pressLabel(idx) });
            },
            .SETTINGS => {
                try imgui.Text(.{ ctx, klabel });
                try imgui.Text(.{ ctx, "-" });
            },
            // A mappable module: the mapped parameter's name is the knob label,
            // shown above the value gauge and the press action.
            else => {
                if (info.has_name[idx]) {
                    try imgui.Text(.{ ctx, info.name(idx) });
                } else {
                    try imgui.Text(.{ ctx, klabel });
                }
                var gauge_buf: [16:0]u8 = undefined;
                try imgui.Text(.{ ctx, gauge(if (info.mapped[idx]) info.vals[idx] else 0.0, &gauge_buf) });
                try imgui.Text(.{ ctx, "hold:fine" });
            },
        }
        return;
    }

    // Module selector cells: label above the mode it selects, on its own line.
    if (moduleForCell(idx)) |module| {
        var txt_buf: [24:0]u8 = undefined;
        const txt = std.fmt.bufPrintZ(&txt_buf, "{s}\n{s}", .{ klabel, module_labels[idx - 8] }) catch klabel;
        if (module == active) {
            try imgui.TextColored(.{ ctx, moduleColor(globals, module), txt });
        } else {
            try imgui.Text(.{ ctx, txt });
        }
    } else {
        var txt_buf: [12:0]u8 = undefined;
        const txt = std.fmt.bufPrintZ(&txt_buf, "{s}\n-", .{klabel}) catch klabel;
        try imgui.Text(.{ ctx, txt });
    }
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
