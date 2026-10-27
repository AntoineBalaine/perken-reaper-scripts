//! The plugin's window, drawn with ReaImGui from REAPER's timer.
//!
//! The host asks the plugin to show its interface through the CLAP gui
//! extension. Because a ReaImGui window is its own window, not a view inside
//! the host's, the host's embedded view stays a small placeholder and this
//! window opens beside it. It is drawn about thirty times a second from the
//! timer, and it only talks to the audio thread through `engine.Shared`.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const imgui = @import("reaper_imgui");
const palette = @import("ui_palette");
const plugin = @import("plugin.zig");
const engine = @import("engine.zig");
const catalog = @import("catalog.zig");
const dump = @import("dump.zig");
const state = @import("state.zig");
const placement = @import("placement.zig");
const glue = @import("reaper_glue.zig");
const fileio = @import("fileio.zig");
const audio = @import("audio.zig");
const roland = @import("roland.zig");
const registrations = @import("registrations.zig");
const panel_fonts = @import("fonts.zig");
const theme = @import("theme.zig");
const widgets = @import("widgets.zig");
const controls_panel = @import("controls_panel.zig");
const patches_panel = @import("patches_panel.zig");
const scenes_panel = @import("scenes_panel.zig");

const Plugin = plugin.Plugin;
const log = std.log.scoped(.ui);

const name_cap = 64;
const max_devices = 256;
const device_name_cap = 96;

const ImguiState = enum { unchecked, present, missing };
var imgui_state: ImguiState = .unchecked;

const green = palette.rgba(0x13BD99FF);
const amber = palette.rgba(0xE0A030FF);
const red = palette.rgba(0xE05050FF);
const grey = palette.rgba(0x818989FF);

/// A device name in a fixed buffer, so that the list can be drawn without
/// allocating.
const DeviceName = [device_name_cap:0]u8;

/// The panel's size when it first opens.
const window_width = 1200;
const window_height = 800;

/// The part of the plugin that belongs to its window.
pub const Window = struct {
    open: bool = false,
    ctx: imgui.ContextPtr = null,
    fonts: panel_fonts.Fonts = .{},
    /// What the Controls tab keeps between frames.
    panel: controls_panel.State = .{},
    /// What the library of patches keeps between frames.
    patches: patches_panel.State = .{},
    /// What the list of the session's scenes keeps between frames.
    scenes_panel: scenes_panel.State = .{},
    frame: u32 = 0,
    errors_logged: u32 = 0,
    /// How many ImGui contexts this window has created, to tell a reopened
    /// window from one that kept its context.
    contexts_created: u32 = 0,
    // The input probe (see `probeInput`).
    probe_lines: u32 = 0,
    probe_last: i64 = 0,

    // The preset list.
    preset_names: ?std.ArrayList([]u8) = null,
    preset_refresh_at: u32 = 0,
    // The window is placed at the mouse once per opening. ImGui's "appearing"
    // condition also fires when the window's OS window is recreated, which
    // made the window jump to the mouse on a click.
    placed: bool = false,
    // A tab to bring to the front on the next frame (0 for none, else the
    // tab's number from 1), so that a script can drive the panel.
    select_tab: u8 = 0,
    save_name: [name_cap:0]u8 = [_:0]u8{0} ** name_cap,
    export_path: [fileio.max_path:0]u8 = [_:0]u8{0} ** fileio.max_path,

    // The keyboard's Registrations library.
    reg_library: ?registrations.Library = null,

    // The devices, refreshed a few times a second.
    device_refresh_at: u32 = 0,
    output_names: [max_devices]DeviceName = [_]DeviceName{[_:0]u8{0} ** device_name_cap} ** max_devices,
    output_present: [max_devices]bool = [_]bool{false} ** max_devices,
    input_names: [max_devices]DeviceName = [_]DeviceName{[_:0]u8{0} ** device_name_cap} ** max_devices,
    input_present: [max_devices]bool = [_]bool{false} ** max_devices,

    // The last notice to the user.
    notice: [160:0]u8 = [_:0]u8{0} ** 160,
    notice_until: u32 = 0,
    notice_is_error: bool = false,
};

pub fn open(p: *Plugin) void {
    ensureImgui();
    if (imgui_state == .missing) {
        if (glue.ready) Reaper.ShowConsoleMsg("VR-09: the panel needs ReaImGui (install it with ReaPack).\n");
        return;
    }
    log.info("opening the panel", .{});
    p.ui.open = true;
    p.ui.placed = false;
    p.ui.probe_lines = 0;
    p.ui.probe_last = 0;
    p.ui.preset_refresh_at = 0;
    p.ui.device_refresh_at = 0;
}

/// Whether the window's ImGui context still exists in ReaImGui.
pub fn contextValid(p: *Plugin) bool {
    if (imgui_state != .present or p.ui.ctx == null) return false;
    return imgui.api.ValidatePtr(@ptrCast(p.ui.ctx), "ImGui_Context*");
}

/// Brings a tab to the front: "controls", "scenes", "patches", "audio" or "midi".
pub fn selectTab(p: *Plugin, name: []const u8) bool {
    const names = [_][]const u8{ "controls", "scenes", "patches", "audio", "midi" };
    for (names, 1..) |n, i| {
        if (std.mem.eql(u8, n, name)) {
            p.ui.select_tab = @intCast(i);
            return true;
        }
    }
    return false;
}

pub fn close(p: *Plugin) void {
    p.ui.open = false;
    // The pointers are dropped, and ReaImGui destroys the context by itself
    // once it has gone unused for a few frames.
    p.ui.ctx = null;
    p.ui.fonts = .{};
    freePresets(&p.ui);
    freeRegistrations(&p.ui);
    scenes_panel.free(&p.ui.scenes_panel);
}

pub fn shutdown() void {}

fn ensureImgui() void {
    if (imgui_state != .unchecked) return;
    if (!glue.ready) {
        imgui_state = .missing;
        return;
    }
    imgui.init(Reaper.plugin_getapi) catch {
        imgui_state = .missing;
        log.warn("ReaImGui is not available", .{});
        return;
    };
    imgui_state = .present;
}

/// Draws every open window. REAPER's timer calls it.
pub fn drawAll() void {
    if (imgui_state != .present) return;
    for (plugin.instances) |maybe| {
        const p = maybe orelse continue;
        if (!p.ui.open) continue;
        draw(p);
    }
}

pub fn notice(w: *Window, comptime fmt: []const u8, args: anytype, is_error: bool) void {
    _ = std.fmt.bufPrintZ(&w.notice, fmt, args) catch {
        w.notice[0] = 0;
    };
    w.notice_until = w.frame + 240;
    w.notice_is_error = is_error;
}

fn freePresets(w: *Window) void {
    if (w.preset_names) |*list| {
        fileio.freeList(plugin.allocator, list);
        w.preset_names = null;
    }
}

fn freeRegistrations(w: *Window) void {
    if (w.reg_library) |*lib| {
        lib.deinit(plugin.allocator);
        w.reg_library = null;
    }
}

fn refreshRegistrations(w: *Window) void {
    freeRegistrations(w);
    if (!glue.ready) return;
    var buf: [fileio.max_path]u8 = undefined;
    const folder = state.registrationFolder(&buf, glue.resourcePath()) catch return;
    w.reg_library = registrations.scan(plugin.allocator, folder) catch null;
}

fn presetFolder(buf: []u8) ?[]const u8 {
    if (!glue.ready) return null;
    return state.presetFolder(buf, glue.resourcePath()) catch null;
}

fn refreshPresets(w: *Window) void {
    freePresets(w);
    var buf: [fileio.max_path]u8 = undefined;
    const folder = presetFolder(&buf) orelse return;
    const list = fileio.listFiles(plugin.allocator, folder, &state.preset_extensions) catch return;
    std.mem.sort([]u8, list.items, {}, lessName);
    w.preset_names = list;
}

fn lessName(_: void, a: []u8, b: []u8) bool {
    return std.ascii.lessThanIgnoreCase(a, b);
}

fn refreshDevices(w: *Window) void {
    refreshDirection(w, .output);
    refreshDirection(w, .input);
}

fn refreshDirection(w: *Window, dir: glue.Direction) void {
    const names = if (dir == .output) &w.output_names else &w.input_names;
    const present = if (dir == .output) &w.output_present else &w.input_present;
    const count = glue.deviceCount(dir);
    for (0..max_devices) |i| {
        present[i] = false;
        if (i >= count) continue;
        var buf: [device_name_cap]u8 = undefined;
        // Because REAPER reports the ports of a JACK setup as absent while
        // they are unconnected, an absent device is listed too, by its number.
        var fallback: [32]u8 = undefined;
        const name = glue.deviceName(dir, i, &buf) orelse
            (std.fmt.bufPrint(&fallback, "device {d} (not present)", .{i}) catch continue);
        const len = @min(name.len, device_name_cap - 1);
        @memcpy(names[i][0..len], name[0..len]);
        names[i][len] = 0;
        present[i] = true;
    }
}

// ---- the window ----

fn draw(p: *Plugin) void {
    const w = &p.ui;
    w.frame +%= 1;
    // ReaImGui destroys a context after a failed assertion, or when a frame
    // goes by without it. Drawing with the stale pointer leaves a frozen
    // window, so a destroyed context is replaced.
    if (w.ctx != null and !imgui.api.ValidatePtr(@ptrCast(w.ctx), "ImGui_Context*")) {
        log.warn("the ImGui context was destroyed; creating a new one", .{});
        w.placed = false;
        w.ctx = null;
        w.fonts = .{};
    }
    if (w.ctx == null) {
        var config: c_int = 0;
        var title_buf: [48:0]u8 = undefined;
        // The name is unique to each context: two contexts of the same name
        // may share a native window, and the end of the old one would take
        // the new one's window with it.
        const title = std.fmt.bufPrintZ(&title_buf, "VR-09 {x}-{d}", .{ @intFromPtr(p), w.contexts_created + 1 }) catch "VR-09";
        w.ctx = imgui.api.CreateContext(title, &config);
        if (w.ctx == null) {
            w.open = false;
            return;
        }
        w.contexts_created += 1;
        log.info("ImGui context {d} created at frame {d}", .{ w.contexts_created, w.frame });
        w.fonts = panel_fonts.create(w.ctx);
    }
    const ctx = w.ctx;
    if (w.frame == 1) log.info("drawing the first frame", .{});
    if (w.frame >= w.preset_refresh_at) {
        refreshPresets(w);
        refreshRegistrations(w);
        w.preset_refresh_at = w.frame +% 150;
    }
    if (w.frame >= w.device_refresh_at) {
        if (glue.ready) refreshDevices(w);
        w.device_refresh_at = w.frame +% 30;
    }

    if (w.fonts.text != null) imgui.api.PushFont(ctx, w.fonts.text);
    theme.push(ctx);
    widgets.frame.fonts = w.fonts;
    const mouse = glue.mousePosition();
    if (!w.placed) {
        w.placed = true;
        // The window opens where it fits on the screen: a window that sticks
        // out is moved by the window manager without ImGui being told, and
        // the mouse then lands a few dozen pixels off.
        var at = placement.Point{ .x = mouse.x, .y = mouse.y };
        if (glue.workAreaAt(mouse.x, mouse.y)) |area| {
            at = placement.fitInto(area, mouse.x, mouse.y, window_width, window_height);
            if (at.x != mouse.x or at.y != mouse.y) log.info("the panel opens at {d},{d} instead of {d},{d}, to fit the screen ({d},{d} to {d},{d})", .{ at.x, at.y, mouse.x, mouse.y, area.left, area.top, area.right, area.bottom });
        }
        imgui.api.SetNextWindowPos(ctx, @floatFromInt(at.x), @floatFromInt(at.y), &imgui.Cond_Always, null, null);
    }
    imgui.api.SetNextWindowSize(ctx, window_width, window_height, &imgui.Cond_FirstUseEver);
    var is_open: bool = true;
    var flags: c_int = imgui.WindowFlags_NoSavedSettings | imgui.WindowFlags_NoCollapse;
    var title: [80:0]u8 = undefined;
    const track_number: u32 = if (p.track != null) @intFromFloat(Reaper.GetMediaTrackInfo_Value(p.track, "IP_TRACKNUMBER")) else 0;
    const label = if (track_number > 0)
        std.fmt.bufPrintZ(&title, "VR-09, track {d}##{x}-{d}", .{ track_number, @intFromPtr(p), w.contexts_created }) catch "VR-09"
    else
        std.fmt.bufPrintZ(&title, "VR-09##{x}-{d}", .{ @intFromPtr(p), w.contexts_created }) catch "VR-09";
    if (imgui.api.Begin(ctx, label, &is_open, &flags)) {
        drawContent(p, ctx);
        probeInput(w, ctx);
    }
    imgui.api.End(ctx);
    theme.pop(ctx);
    if (w.fonts.text != null) imgui.api.PopFont(ctx);
    if (!is_open) {
        log.info("ImGui reported the panel closed (frame {d}, context {d})", .{ w.frame, w.contexts_created });
        close(p);
    }
    reportImguiError(w);
}

fn quantize(v: f64) i64 {
    return @intFromFloat(std.math.clamp(@round(v), -100000, 100000));
}

/// The panel can come up deaf to the mouse. Each time what ImGui sees of the
/// mouse changes, a line (at most 40 per opening) puts it beside where REAPER
/// says the mouse is, so that a frozen panel shows whether ImGui sees the
/// mouse in the wrong place, never hovered, or never focused.
fn probeInput(w: *Window, ctx: imgui.ContextPtr) void {
    if (w.probe_lines >= 40) return;
    var mx: f64 = 0;
    var my: f64 = 0;
    imgui.api.GetMousePos(ctx, &mx, &my);
    var wx: f64 = 0;
    var wy: f64 = 0;
    imgui.api.GetWindowPos(ctx, &wx, &wy);
    var ww: f64 = 0;
    var wh: f64 = 0;
    imgui.api.GetWindowSize(ctx, &ww, &wh);
    // Child windows count: the panel's lists are children.
    var hover_flags: c_int = imgui.HoveredFlags_ChildWindows;
    var focus_flags: c_int = imgui.FocusedFlags_ChildWindows;
    const hovered = imgui.api.IsWindowHovered(ctx, &hover_flags);
    const focused = imgui.api.IsWindowFocused(ctx, &focus_flags);
    const down = imgui.api.IsMouseDown(ctx, 0);
    const key = ((quantize(mx) *% 1_000_003 +% quantize(my)) *% 8 +% @as(i64, @intFromBool(hovered)) *% 4 +% @as(i64, @intFromBool(focused)) *% 2 +% @as(i64, @intFromBool(down)));
    if (key == w.probe_last) return;
    w.probe_last = key;
    w.probe_lines += 1;
    const os = glue.mousePosition();
    log.info("input (context {d}, frame {d}): ImGui mouse {d:.0},{d:.0} down {} | window at {d:.0},{d:.0} size {d:.0}x{d:.0} hovered {} focused {} | REAPER mouse {d},{d}", .{ w.contexts_created, w.frame, mx, my, down, wx, wy, ww, wh, hovered, focused, os.x, os.y });
}

/// ReaImGui records an error instead of raising it when a call is misused, so
/// the first few are written to the log.
fn reportImguiError(w: *Window) void {
    checkpoint(w, "end of frame");
}

/// Because ReaImGui keeps only the error of the last call, and a failed
/// assertion destroys the context so that every later call fails too, the
/// sections of the window check it as they go, to name the one that broke.
fn checkpoint(w: *Window, section: []const u8) void {
    const get_error = imgui.getError orelse return;
    const message = get_error() orelse return;
    if (w.errors_logged < 5) {
        w.errors_logged += 1;
        log.warn("ReaImGui reported after {s}: {s}", .{ section, std.mem.span(message) });
    }
}

fn drawContent(p: *Plugin, ctx: imgui.ContextPtr) void {
    drawHeader(p, ctx);
    imgui.api.Separator(ctx);
    if (imgui.api.BeginTabBar(ctx, "##tabs", null)) {
        const select = p.ui.select_tab;
        p.ui.select_tab = 0;
        var flags = [5]c_int{ 0, 0, 0, 0, 0 };
        if (select >= 1 and select <= flags.len) flags[select - 1] = imgui.TabItemFlags_SetSelected;
        if (widgets.beginTab(ctx, "CONTROLS", &flags[0])) {
            drawControls(p, ctx);
            imgui.api.EndTabItem(ctx);
        }
        if (widgets.beginTab(ctx, "SCENES", &flags[1])) {
            patches_panel.drawLibrary(p, ctx);
            imgui.api.SameLine(ctx, null, null);
            scenes_panel.draw(p, ctx);
            imgui.api.EndTabItem(ctx);
        }
        if (widgets.beginTab(ctx, "PATCHES", &flags[2])) {
            patches_panel.drawPatches(p, ctx);
            imgui.api.EndTabItem(ctx);
        }
        if (widgets.beginTab(ctx, "AUDIO LOOP", &flags[3])) {
            drawAudioLoop(p, ctx);
            imgui.api.EndTabItem(ctx);
        }
        if (widgets.beginTab(ctx, "MIDI", &flags[4])) {
            drawMidi(p, ctx);
            imgui.api.EndTabItem(ctx);
        }
        imgui.api.EndTabBar(ctx);
    }
    if (p.ui.frame < p.ui.notice_until and p.ui.notice[0] != 0) {
        imgui.api.Separator(ctx);
        imgui.api.TextColored(ctx, if (p.ui.notice_is_error) red else green, &p.ui.notice);
    }
}

// ---- the header ----

/// The status of the keyboard, in a card: a lamp and a line saying whether it answers, the progress of a
/// read or a write when there is one, and the patch's name on a display.
fn drawHeader(p: *Plugin, ctx: imgui.ContextPtr) void {
    if (!widgets.beginCard(ctx, "Status", null, null, null)) return;
    defer widgets.endCard(ctx);
    const s = p.shared;
    const connected = s.connected.load(.acquire);
    const mode: roland.MidiInMode = @enumFromInt(s.mode.load(.monotonic));
    var color = theme.red;
    var text: [:0]const u8 = "The keyboard does not answer: see the MIDI tab";
    if (connected) {
        switch (mode) {
            .mode2 => {
                color = theme.green;
                text = "Keyboard connected (MIDI IN mode 2)";
            },
            .mode1 => {
                color = theme.amber;
                text = "Keyboard connected, but in MIDI IN mode 1: switch it to mode 2";
            },
            .unknown => {
                color = theme.amber;
                text = "Keyboard answers, mode unknown";
            },
        }
    } else if (!p.processing) {
        color = theme.grey;
        text = "Waiting for the host to run the plugin (record-arm the track)";
    }
    widgets.lamp(ctx, color, connected);
    imgui.api.SameLine(ctx, null, null);
    imgui.api.TextColored(ctx, color, text);

    const job: engine.JobKind = @enumFromInt(s.job.load(.monotonic));
    if (job != .idle) {
        const done = s.progress_done.load(.monotonic);
        const total = s.progress_total.load(.monotonic);
        var caption_buf: [64:0]u8 = undefined;
        const caption = std.fmt.bufPrintZ(&caption_buf, "{s} {d}/{d}", .{ if (job == .reading) "Reading" else "Writing", done, total }) catch "";
        const fraction: f64 = if (total == 0) 0 else @as(f64, @floatFromInt(done)) / @as(f64, @floatFromInt(total));
        var width: f64 = 420;
        imgui.api.ProgressBar(ctx, fraction, &width, null, caption);
    }
    const preset = p.settings.presetName();
    var name: [96:0]u8 = undefined;
    const shown = std.fmt.bufPrintZ(&name, "{s}", .{if (preset.len == 0) "(none)" else preset}) catch "Patch";
    imgui.api.TextColored(ctx, theme.label, "Patch");
    imgui.api.SameLine(ctx, null, null);
    widgets.display(ctx, shown, theme.amber, 260);
}

// ---- the controls ----

fn drawControls(p: *Plugin, ctx: imgui.ContextPtr) void {
    controls_panel.draw(p.shared, &p.ui.panel, ctx);
    // The cards cannot reach the window's notice, so they leave theirs in the tab's state.
    if (p.ui.panel.overflow) {
        p.ui.panel.overflow = false;
        notice(&p.ui, "Too many changes at once, the last one was dropped.", .{}, true);
    }
    if (p.ui.panel.notice[0] != 0) {
        notice(&p.ui, "{s}", .{std.mem.sliceTo(&p.ui.panel.notice, 0)}, false);
        p.ui.panel.notice[0] = 0;
    }
}

// ---- the patches ----

pub fn loadRegistration(p: *Plugin, entry: registrations.Entry) void {
    p.loadRegistration(entry) catch |err| {
        notice(&p.ui, "Could not load registration {d}-{d}: {s}", .{ entry.bank, entry.slot, @errorName(err) }, true);
        return;
    };
    notice(&p.ui, "Loaded registration {d}-{d}.", .{ entry.bank, entry.slot }, false);
}

pub fn loadPreset(p: *Plugin, file_name: []const u8) void {
    var folder_buf: [fileio.max_path]u8 = undefined;
    const folder = presetFolder(&folder_buf) orelse return;
    var path_buf: [fileio.max_path]u8 = undefined;
    const path = state.presetPath(&path_buf, folder, file_name) catch return;
    p.loadPresetFile(path, state.displayName(file_name)) catch |err| {
        notice(&p.ui, "Could not load {s}: {s}", .{ file_name, @errorName(err) }, true);
        return;
    };
    notice(&p.ui, "Loaded {s}.", .{state.displayName(file_name)}, false);
}

pub fn deletePreset(p: *Plugin, file_name: []const u8) void {
    var folder_buf: [fileio.max_path]u8 = undefined;
    const folder = presetFolder(&folder_buf) orelse return;
    var path_buf: [fileio.max_path]u8 = undefined;
    const path = state.presetPath(&path_buf, folder, file_name) catch return;
    fileio.deleteFile(path) catch |err| {
        notice(&p.ui, "Could not delete {s}: {s}", .{ file_name, @errorName(err) }, true);
        return;
    };
    p.ui.preset_refresh_at = 0;
    notice(&p.ui, "Deleted {s}.", .{state.displayName(file_name)}, false);
}

pub fn savePreset(p: *Plugin) void {
    var clean: [name_cap]u8 = undefined;
    const name = state.sanitizeName(&clean, std.mem.sliceTo(&p.ui.save_name, 0));
    if (name.len == 0) {
        notice(&p.ui, "Type a name for the preset first.", .{}, true);
        return;
    }
    var folder_buf: [fileio.max_path]u8 = undefined;
    const folder = presetFolder(&folder_buf) orelse {
        notice(&p.ui, "REAPER's resource folder is not known.", .{}, true);
        return;
    };
    fileio.makePath(folder) catch |err| {
        notice(&p.ui, "Could not create the preset folder: {s}", .{@errorName(err)}, true);
        return;
    };
    var path_buf: [fileio.max_path]u8 = undefined;
    const path = state.presetPath(&path_buf, folder, name) catch return;
    const scene = plugin.allocator.create(dump.Dump) catch return;
    defer plugin.allocator.destroy(scene);
    p.shared.desiredSnapshot(scene);
    state.savePresetFile(plugin.allocator, path, scene) catch |err| {
        notice(&p.ui, "Could not write {s}: {s}", .{ name, @errorName(err) }, true);
        return;
    };
    p.settings.setPresetName(name);
    p.ui.preset_refresh_at = 0;
    notice(&p.ui, "Saved {s}.", .{name}, false);
}

pub fn importFile(p: *Plugin) void {
    if (!glue.ready) return;
    var path: [4096]u8 = [_]u8{0} ** 4096;
    if (!Reaper.GetUserFileNameForRead(@ptrCast(&path), "Import a VR-09 dump or preset", "json")) return;
    const chosen = std.mem.sliceTo(&path, 0);
    p.loadPresetFile(chosen, state.displayName(std.fs.path.basename(chosen))) catch |err| {
        notice(&p.ui, "Could not import the file: {s}", .{@errorName(err)}, true);
        return;
    };
    notice(&p.ui, "Imported {s}.", .{std.fs.path.basename(chosen)}, false);
}

pub fn exportFile(p: *Plugin) void {
    const target = std.mem.sliceTo(&p.ui.export_path, 0);
    if (target.len == 0 or !std.fs.path.isAbsolute(target)) {
        notice(&p.ui, "Type the full path of the file to write.", .{}, true);
        return;
    }
    const scene = plugin.allocator.create(dump.Dump) catch return;
    defer plugin.allocator.destroy(scene);
    p.shared.desiredSnapshot(scene);
    state.savePresetFile(plugin.allocator, target, scene) catch |err| {
        notice(&p.ui, "Could not write the file: {s}", .{@errorName(err)}, true);
        return;
    };
    notice(&p.ui, "Exported to {s}.", .{target}, false);
}

// ---- the audio loop ----

fn drawChannelPairCombo(ctx: imgui.ContextPtr, id: [:0]const u8, dir: glue.Direction, current: i32, out: *i32) bool {
    var preview: [96:0]u8 = undefined;
    const count = glue.audioChannelCount(dir);
    const preview_text = if (current < 0 or current + 1 >= count)
        std.fmt.bufPrintZ(&preview, "none", .{}) catch "none"
    else
        std.fmt.bufPrintZ(&preview, "{s} + {s}", .{ glue.audioChannelName(dir, @intCast(current)), glue.audioChannelName(dir, @intCast(current + 1)) }) catch "?";
    var changed = false;
    if (widgets.beginPickList(ctx, id, preview_text, 320)) {
        if (widgets.pickItem(ctx, "none", current < 0, true)) {
            out.* = -1;
            changed = true;
        }
        var ch: usize = 0;
        while (ch + 1 < count) : (ch += 2) {
            var label: [128:0]u8 = undefined;
            const text = std.fmt.bufPrintZ(&label, "{s} + {s}##{d}", .{ glue.audioChannelName(dir, ch), glue.audioChannelName(dir, ch + 1), ch }) catch continue;
            if (widgets.pickItem(ctx, text, current == @as(i32, @intCast(ch)), true)) {
                out.* = @intCast(ch);
                changed = true;
            }
        }
        widgets.endPickList(ctx);
    }
    return changed;
}

/// The loop's levels go from -60 to 12 dB and rest at 0 dB.
const loop_send = widgets.Control{ .id = "loop-send", .low = -60, .high = 12, .default = 0, .unit = " dB" };
const loop_return = widgets.Control{ .id = "loop-return", .low = -60, .high = 12, .default = 0, .unit = " dB" };

/// A paragraph in the label color, broken at `width` pixels from where it starts.
fn labelNote(ctx: imgui.ContextPtr, text: [:0]const u8, width: f64) void {
    var wrap = imgui.api.GetCursorPosX(ctx) + width;
    imgui.api.PushTextWrapPos(ctx, &wrap);
    imgui.api.TextColored(ctx, theme.label, text);
    imgui.api.PopTextWrapPos(ctx);
}

/// A line of text in the label font, for what stands beside a combo.
fn labelLine(ctx: imgui.ContextPtr, text: [:0]const u8) void {
    const pushed = widgets.pushLabelFont(ctx);
    imgui.api.TextColored(ctx, theme.label, text);
    widgets.popFont(ctx, pushed);
}

fn drawAudioLoop(p: *Plugin, ctx: imgui.ContextPtr) void {
    if (!glue.ready) {
        labelNote(ctx, "The audio loop needs REAPER. In another host the plugin only passes the audio through.", 560);
        return;
    }
    labelNote(ctx, "The loop sends this track's audio to the keyboard's audio input and takes the keyboard's output back, the way ReaInsert does for outboard gear. Wire the interface's output to the keyboard's input, and the keyboard's output to the interface's input.", 560);
    imgui.api.Spacing(ctx);

    const loop_state: audio.LoopState = @enumFromInt(p.loop_state.load(.monotonic));
    if (widgets.beginCard(ctx, "Loop", null, null, null)) {
        const brackets = [_]widgets.Bracket{.{ .label = "Levels", .from = 2, .to = 3 }};
        widgets.bracketRow(ctx, &brackets, 3);
        const enabled = p.settings.loop_enabled.load(.monotonic);
        imgui.api.PushID(ctx, "loop-on");
        const switched = widgets.switchControl(ctx, if (enabled) 1 else 0, "audio loop", "ON", "OFF");
        imgui.api.PopID(ctx);
        if (switched.changed) p.setLoopEnabled(switched.value == 1);
        // Because the two knobs draw the same widgets, each one gets an id of its own.
        imgui.api.SameLine(ctx, null, null);
        imgui.api.PushID(ctx, "loop-send");
        const send = widgets.knob(ctx, loop_send, @intFromFloat(@round(p.settings.sendDb())), "send level", false);
        imgui.api.PopID(ctx);
        if (send.changed) p.settings.setSendDb(@floatFromInt(send.value));
        imgui.api.SameLine(ctx, null, null);
        imgui.api.PushID(ctx, "loop-return");
        const back = widgets.knob(ctx, loop_return, @intFromFloat(@round(p.settings.returnDb())), "return level", false);
        imgui.api.PopID(ctx);
        if (back.changed) p.settings.setReturnDb(@floatFromInt(back.value));

        const running = loop_state == .running;
        const tint = if (running) theme.green else theme.amber;
        widgets.lamp(ctx, tint, running);
        imgui.api.SameLine(ctx, null, null);
        imgui.api.TextColored(ctx, tint, switch (loop_state) {
            .off => "The loop is off: the audio passes through.",
            .no_device => "The audio device is not running (an offline render, or REAPER's audio is stopped): the audio passes through.",
            .no_channels => "Choose a pair of channels to send to and to return from: the audio passes through.",
            .running => "The loop is running.",
        });
        if (p.slot) |slot| {
            var drops: [96:0]u8 = undefined;
            imgui.api.TextColored(ctx, theme.grey, std.fmt.bufPrintZ(&drops, "Dropouts: send {d}, return {d}", .{ slot.out_underruns.load(.monotonic), slot.in_overruns.load(.monotonic) }) catch "");
        } else {
            imgui.api.TextColored(ctx, theme.grey, "The plugin is not active yet.");
        }
        widgets.endCard(ctx);
    }

    if (widgets.beginCard(ctx, "Channels", null, null, null)) {
        var out_channel = p.settings.out_channel.load(.monotonic);
        labelLine(ctx, "Send to (interface outputs)");
        if (drawChannelPairCombo(ctx, "##send", .output, out_channel, &out_channel)) {
            p.settings.out_channel.store(out_channel, .monotonic);
            p.applyLoopSettings();
        }
        var in_channel = p.settings.in_channel.load(.monotonic);
        labelLine(ctx, "Return from (interface inputs)");
        if (drawChannelPairCombo(ctx, "##return", .input, in_channel, &in_channel)) {
            p.settings.in_channel.store(in_channel, .monotonic);
            p.applyLoopSettings();
        }
        widgets.endCard(ctx);
    }

    if (widgets.beginCard(ctx, "Latency", null, null, null)) {
        labelNote(ctx, "The plugin tells REAPER how long the round trip takes, and REAPER's delay compensation lines the track up. Measuring sends a short click to the keyboard's audio input, so turn the keyboard's volume down first.", 420);
        const ping: audio.PingState = @enumFromInt(p.ping_state.load(.acquire));
        const busy = ping == .listening_noise or ping == .sending or ping == .listening;
        if (busy) imgui.api.BeginDisabled(ctx, null);
        if (widgets.pushButton(ctx, "Measure the round trip", 0)) p.startPing();
        if (busy) imgui.api.EndDisabled(ctx);
        imgui.api.SameLine(ctx, null, null);
        var text: [128:0]u8 = undefined;
        const frames = p.settings.latency_frames.load(.monotonic);
        const rate = p.settings.latency_rate.load(.monotonic);
        switch (ping) {
            .idle => if (frames == 0) widgets.display(ctx, "not measured yet", theme.text_dim, 160) else widgets.display(ctx, latencyText(&text, frames, rate), theme.amber, 160),
            .listening_noise, .sending, .listening => widgets.display(ctx, "measuring...", theme.amber, 160),
            .done => widgets.display(ctx, latencyText(&text, frames, rate), theme.green, 160),
            .failed => {
                widgets.display(ctx, "no click came back", theme.red, 160);
                imgui.api.TextColored(ctx, theme.red, "Check the cables, the channels and that the track is processing.");
            },
        }
        widgets.endCard(ctx);
    }
}

fn latencyText(buf: []u8, frames: u32, rate: u32) [:0]const u8 {
    const ms: f64 = if (rate == 0) 0 else @as(f64, @floatFromInt(frames)) * 1000.0 / @as(f64, @floatFromInt(rate));
    return std.fmt.bufPrintZ(buf, "{d} samples ({d:.1} ms)", .{ frames, ms }) catch "?";
}

// ---- the MIDI tab ----

fn drawDeviceCombo(w: *Window, ctx: imgui.ContextPtr, id: [:0]const u8, dir: glue.Direction, current: ?usize, out: *?usize) bool {
    const names = if (dir == .output) &w.output_names else &w.input_names;
    const present = if (dir == .output) &w.output_present else &w.input_present;
    var preview: [128:0]u8 = undefined;
    const preview_text = if (current) |c|
        (if (c < max_devices and present[c]) std.fmt.bufPrintZ(&preview, "{s}", .{std.mem.sliceTo(&names[c], 0)}) catch "?" else std.fmt.bufPrintZ(&preview, "device {d} (not present)", .{c}) catch "?")
    else
        std.fmt.bufPrintZ(&preview, "none", .{}) catch "none";
    var changed = false;
    if (widgets.beginPickList(ctx, id, preview_text, 360)) {
        if (dir == .output and widgets.pickItem(ctx, "none", current == null, true)) {
            out.* = null;
            changed = true;
        }
        for (0..max_devices) |i| {
            if (!present[i]) continue;
            var label: [160:0]u8 = undefined;
            const text = std.fmt.bufPrintZ(&label, "{s}##{d}", .{ std.mem.sliceTo(&names[i], 0), i }) catch continue;
            // Because a track's device field is too narrow for the later entries, they are shown but cannot be chosen.
            if (widgets.pickItem(ctx, text, current != null and current.? == i, glue.addressable(dir, i))) {
                out.* = i;
                changed = true;
            }
        }
        widgets.endPickList(ctx);
    }
    return changed;
}

fn drawMidi(p: *Plugin, ctx: imgui.ContextPtr) void {
    const w = &p.ui;
    const s = p.shared;
    if (widgets.beginCard(ctx, "The track's MIDI devices", null, null, null)) {
        if (!glue.ready or p.track == null) {
            labelNote(ctx, "The MIDI routing can only be set from a track's FX chain in REAPER. In another host, or on a take or the monitoring chain, route the plugin's MIDI yourself.", 460);
        } else {
            if (glue.findKeyboard(.output) == null) {
                imgui.api.TextColored(ctx, theme.amber, "No VR-09 found among REAPER's MIDI outputs: plug it in (USB), or choose its device below.");
            }
            labelLine(ctx, "MIDI output (to the keyboard)");
            var out_dev = glue.trackMidiOutput(p.track);
            if (drawDeviceCombo(w, ctx, "##midiout", .output, out_dev, &out_dev)) {
                glue.setTrackMidiOutput(p.track, out_dev);
                p.settings.autoconnect_done.store(true, .monotonic);
            }
            labelLine(ctx, "MIDI input (record from the keyboard)");
            var in_dev = glue.trackMidiInput(p.track);
            if (drawDeviceCombo(w, ctx, "##midiin", .input, in_dev, &in_dev)) {
                if (in_dev) |d| glue.setTrackMidiInput(p.track, d);
            }
            if (in_dev == null) imgui.api.TextColored(ctx, theme.grey, "The track's input is not a single MIDI device.");

            const monitoring = glue.trackMonitoring(p.track);
            var armed = glue.trackArmed(p.track);
            if (widgets.toggle(ctx, "Record-arm the track", &armed)) glue.setTrackArmed(p.track, armed);
            widgets.tooltip(ctx, "REAPER only delivers MIDI input to a track's plugins while the track is armed. The keyboard's replies are MIDI input.");
            var monitor_on = monitoring == 1;
            if (widgets.toggle(ctx, "Monitor input", &monitor_on)) glue.setTrackMonitoring(p.track, if (monitor_on) 1 else 0);
            if (!armed) {
                imgui.api.TextColored(ctx, theme.amber, "The track is not armed: the keyboard's replies cannot reach the plugin.");
            } else if (monitoring == 0) {
                imgui.api.TextColored(ctx, theme.amber, "The track does not monitor its input: the keyboard's replies cannot reach the plugin.");
            }
        }
        widgets.endCard(ctx);
    }

    if (widgets.beginCard(ctx, "Behavior", null, null, null)) {
        var pass = p.settings.pass_midi.load(.monotonic);
        if (widgets.toggle(ctx, "Pass this track's MIDI through to the keyboard", &pass)) p.settings.pass_midi.store(pass, .monotonic);
        widgets.tooltip(ctx, "Off by default. REAPER does not tell the notes you play from the notes the track plays back, and the track must monitor its input for the keyboard's replies to arrive, so the keyboard would sound its own notes twice. Keep the notes on a separate MIDI track, or turn this on and switch the keyboard's Local Control off.");
        const dropped = s.midi_dropped.load(.monotonic);
        if (!pass and dropped > 0) {
            var note: [128:0]u8 = undefined;
            imgui.api.TextColored(ctx, theme.grey, std.fmt.bufPrintZ(&note, "{d} MIDI messages on this track were not passed on.", .{dropped}) catch "");
        }
        var bare = p.settings.sysex_bare.load(.monotonic);
        if (widgets.toggle(ctx, "Send SysEx without its F0 and F7 bytes", &bare)) p.settings.sysex_bare.store(bare, .monotonic);
        widgets.tooltip(ctx, "Switch this on if the keyboard ignores the plugin's messages: hosts differ on whether they add the framing bytes themselves.");
        widgets.endCard(ctx);
    }

    if (widgets.beginCard(ctx, "Connection", null, null, null)) {
        if (widgets.pushButton(ctx, "Look for the keyboard again", 0)) {
            _ = s.sendCommand(.reconnect);
            p.settings.autoconnect_done.store(false, .monotonic);
            p.ticks = 0;
            notice(w, "Asking the keyboard who it is.", .{}, false);
        }
        var text: [160:0]u8 = undefined;
        widgets.display(ctx, std.fmt.bufPrintZ(&text, "sent {d}   received {d}   bad checksums {d}", .{ s.tx_count.load(.monotonic), s.rx_count.load(.monotonic), s.bad_count.load(.monotonic) }) catch "", theme.amber, 360);
        imgui.api.TextColored(ctx, theme.grey, std.fmt.bufPrintZ(&text, "SysEx events: from the host {d}, accepted by the host {d}, refused {d}", .{ s.host_sysex_in.load(.monotonic), s.host_sysex_out.load(.monotonic), s.host_sysex_refused.load(.monotonic) }) catch "");
        var trace: [96]u8 = undefined;
        imgui.api.TextColored(ctx, theme.grey, std.fmt.bufPrintZ(&text, "First received: {s}", .{s.trace_in.format(&trace)}) catch "");
        imgui.api.TextColored(ctx, theme.grey, std.fmt.bufPrintZ(&text, "First sent: {s}", .{s.trace_out.format(&trace)}) catch "");
        imgui.api.TextColored(ctx, theme.grey, std.fmt.bufPrintZ(&text, "Known keyboard bytes: {d} of {d}, blocks that never answered: {d}", .{ s.mirror_known.load(.monotonic), dump.total_bytes, s.blocks_failed.load(.monotonic) }) catch "");
        widgets.endCard(ctx);
    }
}
