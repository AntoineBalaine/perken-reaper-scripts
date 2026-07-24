const std = @import("std");
const builtin = @import("builtin");
const imgui = @import("reaper_imgui");
const reaper = @import("reaper").reaper;
const MftGlobals = @import("mft_globals.zig").MftGlobals;
const MftActiveModule = @import("mft_state.zig").MftActiveModule;
const mappings = @import("mft_mappings.zig");
const MappableModule = mappings.MappableModule;
const mft_fx = @import("mft_fx.zig");
const log = std.log.scoped(.mft_imgui);

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

    // Read the eight top-row parameter values for the active module.
    var vals = [_]f64{0.0} ** 8;
    var mapped = [_]bool{false} ** 8;
    if (MappableModule.fromActive(active)) |module| {
        if (globals.current_track) |track| {
            if (mft_fx.resolveFx(globals, track, module)) |resolved| {
                var slot: u3 = 0;
                while (true) : (slot += 1) {
                    if (resolved.mapping.slotToParam(slot)) |param| {
                        vals[slot] = reaper.TrackFX_GetParamNormalized(track, resolved.fx_index, @intCast(param));
                        mapped[slot] = true;
                    }
                    if (slot == 7) break;
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
}

fn drawCell(idx: usize, vals: *const [8]f64, mapped: *const [8]bool, active: MftActiveModule) !void {
    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    if (idx < 8) {
        try imgui.Text(.{ ctx, knob_labels[idx] });
        const value: f64 = if (mapped[idx]) vals[idx] else 0.0;
        try imgui.ProgressBar(.{ ctx, value, 72.0, 12.0 });
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
