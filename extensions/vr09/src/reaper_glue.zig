//! The plugin's way into REAPER's API.
//!
//! A CLAP plugin is not an extension, so REAPER does not call
//! `ReaperPluginEntry` for it. REAPER does hand every plugin the same
//! `reaper_plugin_info_t` through the host extension "cockos.reaper_extension"
//! (see `reaper_plugin.h`), and its `getFunc` resolves the whole API. From it
//! the plugin reads the MIDI devices, sets its track's hardware routing,
//! registers a timer for the user interface, and registers the hook that
//! moves audio to and from the audio device.
const std = @import("std");
const builtin = @import("builtin");
const Reaper = @import("reaper").reaper;
const clap = @import("clap.zig");
const c = clap.c;
const audio = @import("audio.zig");
const placement = @import("placement.zig");

const log = std.log.scoped(.reaper);

/// The REAPER functions this plugin calls. Because `initSubset` leaves an
/// unlisted function as a null pointer, a test in `tests.zig` scans the
/// sources for names missing here.
pub const reaper_api = [_][:0]const u8{
    "my_getViewport",
    "plugin_register",
    "plugin_getapi",
    "GetResourcePath",
    "GetNumMIDIOutputs",
    "GetMIDIOutputName",
    "GetNumMIDIInputs",
    "GetMIDIInputName",
    "GetMediaTrackInfo_Value",
    "SetMediaTrackInfo_Value",
    "GetNumAudioInputs",
    "GetNumAudioOutputs",
    "GetInputChannelName",
    "GetOutputChannelName",
    "GetMousePosition",
    "Audio_RegHardwareHook",
    "GetInputOutputLatency",
    "GetUserFileNameForRead",
    "GetProjectPath",
    "ShowConsoleMsg",
    "ShowMessageBox",
    "EnumProjectMarkers",
    "GetFXEnvelope",
    "CountEnvelopePoints",
    "GetEnvelopePoint",
    "SetEnvelopePoint",
    "InsertEnvelopePoint",
    "Envelope_SortPoints",
    "CountAutomationItems",
    "CountEnvelopePointsEx",
    "GetEnvelopePointEx",
    "SetEnvelopePointEx",
    "Envelope_SortPointsEx",
    "GetCursorPosition",
    "TrackFX_GetParamEx",
    "Undo_BeginBlock",
    "Undo_EndBlock",
    "UpdateArrange",
};

/// The context codes of `clap_get_reaper_context`.
pub const Context = enum(c_int) {
    track = 1,
    take = 2,
    project = 3,
    fx_dsp = 4,
    track_channels = 5,
    fx_index = 6,
};

pub var ready: bool = false;
var rec: ?*Reaper.plugin_info_t = null;
const GetContextFn = *const fn (host: [*c]const c.clap_host_t, sel: c_int) callconv(.C) ?*anyopaque;
var get_context: ?GetContextFn = null;

/// Resolves REAPER's API once. False when the host is not REAPER, in which
/// case the plugin still works as a plain MIDI and audio plugin.
pub fn init(host: [*c]const c.clap_host_t) bool {
    if (ready) return true;
    const get_ext = host.*.get_extension orelse return false;
    const ptr = get_ext(host, "cockos.reaper_extension") orelse return false;
    const info: *Reaper.plugin_info_t = @constCast(@ptrCast(@alignCast(ptr)));
    if (!Reaper.initSubset(info, &reaper_api)) {
        log.warn("REAPER's API could not be resolved", .{});
        return false;
    }
    rec = info;
    if (info.getFunc) |get_func| {
        const f = get_func("clap_get_reaper_context");
        get_context = @ptrCast(@alignCast(f));
    }
    ready = true;
    return true;
}

/// The track the plugin sits on, or null for a take, the monitoring chain or
/// an older REAPER.
pub fn trackOf(host: [*c]const c.clap_host_t) Reaper.MediaTrack {
    if (!ready) return null;
    const f = get_context orelse return null;
    return @ptrCast(f(host, @intFromEnum(Context.track)));
}

pub fn resourcePath() []const u8 {
    return std.mem.span(Reaper.GetResourcePath());
}

// ---- MIDI devices and the track's routing ----

pub const Direction = enum { output, input };

pub fn deviceCount(dir: Direction) usize {
    const n = switch (dir) {
        .output => Reaper.GetNumMIDIOutputs(),
        .input => Reaper.GetNumMIDIInputs(),
    };
    return if (n < 0) 0 else @intCast(n);
}

/// REAPER's documentation gives 5 bits to a track's output device and 6 to
/// its input device, but REAPER itself stores larger indices (the ALSA
/// bridge's entries sit around 90): its own menu stores the input device 86
/// as 4096 | 86 << 5. So any index up to 127 can be written, except the
/// input's 62 and 63, which mean the virtual keyboard and every device.
pub fn addressable(dir: Direction, index: usize) bool {
    return if (dir == .output) index < 128 else index < 62 or (index > 63 and index < 128);
}

/// Copies the device's name into `buf` and returns it, or null when REAPER
/// has no name for that index. REAPER answers false for a device that is
/// not currently open (a JACK port, for one) but still gives its name, and
/// such a device is a valid target for a track.
pub fn deviceName(dir: Direction, index: usize, buf: []u8) ?[]const u8 {
    if (buf.len < 2) return null;
    @memset(buf, 0);
    const ptr: [*]c_char = @ptrCast(buf.ptr);
    _ = switch (dir) {
        .output => Reaper.GetMIDIOutputName(@intCast(index), ptr, @intCast(buf.len - 1)),
        .input => Reaper.GetMIDIInputName(@intCast(index), ptr, @intCast(buf.len - 1)),
    };
    const name = std.mem.sliceTo(buf, 0);
    if (name.len == 0) return null;
    return name;
}

/// The first device a track can use whose name looks like a VR-09 (VR-09,
/// VR09, VR-09B).
pub fn findKeyboard(dir: Direction) ?usize {
    var buf: [128]u8 = undefined;
    for (0..deviceCount(dir)) |i| {
        if (!addressable(dir, i)) continue;
        const name = deviceName(dir, i, &buf) orelse continue;
        if (looksLikeVr09(name)) return i;
    }
    return null;
}

pub fn looksLikeVr09(name: []const u8) bool {
    var lower: [128]u8 = undefined;
    const n = @min(name.len, lower.len);
    for (name[0..n], 0..) |ch, i| lower[i] = std.ascii.toLower(ch);
    const s = lower[0..n];
    return std.mem.indexOf(u8, s, "vr-09") != null or std.mem.indexOf(u8, s, "vr09") != null or
        std.mem.indexOf(u8, s, "vr-730") != null;
}

/// The device a track sends MIDI to, or null when its hardware output is off.
/// `I_MIDIHWOUT` holds the channel in the low five bits (0 for all) and the
/// device index above them.
pub fn trackMidiOutput(track: Reaper.MediaTrack) ?usize {
    const v = Reaper.GetMediaTrackInfo_Value(track, "I_MIDIHWOUT");
    if (v < 0) return null;
    const bits: u32 = @intFromFloat(v);
    return (bits >> 5) & 127;
}

pub fn setTrackMidiOutput(track: Reaper.MediaTrack, device: ?usize) void {
    const value: f64 = if (device) |d| @floatFromInt(d << 5) else -1;
    _ = Reaper.SetMediaTrackInfo_Value(track, "I_MIDIHWOUT", value);
}

/// The device a track records MIDI from. 63 in `I_RECINPUT`'s device field
/// means every device, which is reported as null here along with an input
/// that is not MIDI at all.
pub fn trackMidiInput(track: Reaper.MediaTrack) ?usize {
    const v = Reaper.GetMediaTrackInfo_Value(track, "I_RECINPUT");
    if (v < 0) return null;
    const bits: u32 = @intFromFloat(v);
    if (bits & 4096 == 0) return null;
    const dev = (bits >> 5) & 127;
    if (dev == 62 or dev == 63) return null;
    return dev;
}

pub fn setTrackMidiInput(track: Reaper.MediaTrack, device: usize) void {
    const value: f64 = @floatFromInt(4096 | (device << 5));
    _ = Reaper.SetMediaTrackInfo_Value(track, "I_RECINPUT", value);
}

/// 0 off, 1 on, 2 automatic (on while armed).
pub fn trackMonitoring(track: Reaper.MediaTrack) i32 {
    return @intFromFloat(Reaper.GetMediaTrackInfo_Value(track, "I_RECMON"));
}

pub fn setTrackMonitoring(track: Reaper.MediaTrack, mode: i32) void {
    _ = Reaper.SetMediaTrackInfo_Value(track, "I_RECMON", @floatFromInt(mode));
}

pub fn trackArmed(track: Reaper.MediaTrack) bool {
    return Reaper.GetMediaTrackInfo_Value(track, "I_RECARM") > 0;
}

/// REAPER only delivers a track's MIDI input to its FX chain while the track
/// is record-armed (found by testing REAPER 7.69: monitoring alone is not
/// enough), and the keyboard's replies arrive as MIDI input.
pub fn setTrackArmed(track: Reaper.MediaTrack, armed: bool) void {
    _ = Reaper.SetMediaTrackInfo_Value(track, "I_RECARM", if (armed) 1 else 0);
}

/// Anticipative FX processing runs a track's plugins ahead of the audio
/// device, which would break the lockstep the audio loop depends on. Bit 2 of
/// `I_PERFFLAGS` turns it off for the track.
pub fn setNoAnticipativeFx(track: Reaper.MediaTrack, off: bool) void {
    const current: u32 = @intFromFloat(Reaper.GetMediaTrackInfo_Value(track, "I_PERFFLAGS"));
    const wanted: u32 = if (off) current | 2 else current & ~@as(u32, 2);
    if (wanted != current) _ = Reaper.SetMediaTrackInfo_Value(track, "I_PERFFLAGS", @floatFromInt(wanted));
}

// ---- audio channels ----

pub fn audioChannelCount(dir: Direction) usize {
    const n = switch (dir) {
        .output => Reaper.GetNumAudioOutputs(),
        .input => Reaper.GetNumAudioInputs(),
    };
    return if (n < 0) 0 else @intCast(n);
}

pub fn audioChannelName(dir: Direction, index: usize) []const u8 {
    const p = switch (dir) {
        .output => Reaper.GetOutputChannelName(@intCast(index)),
        .input => Reaper.GetInputChannelName(@intCast(index)),
    };
    return std.mem.span(p);
}

// ---- the user interface's timer ----

pub fn registerTimer(callback: *const fn () callconv(.C) void) void {
    if (!ready) return;
    _ = Reaper.plugin_register("timer", @constCast(@ptrCast(callback)));
}

pub fn unregisterTimer(callback: *const fn () callconv(.C) void) void {
    if (!ready) return;
    _ = Reaper.plugin_register("-timer", @constCast(@ptrCast(callback)));
}

/// The usable area of the screen that holds the point (the screen without its
/// taskbars), or null when REAPER does not give one.
pub fn workAreaAt(x: i32, y: i32) ?placement.Rect {
    if (!ready) return null;
    // The binding types a RECT as a pointer to an opaque value, whose
    // alignment is 8, so the two rectangles are aligned to match.
    var area: placement.Rect align(8) = .{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
    const around: placement.Rect align(8) = .{ .left = x, .top = y, .right = x + 1, .bottom = y + 1 };
    Reaper.my_getViewport(@ptrCast(&area), @ptrCast(&around), true);
    return if (placement.isUsable(area)) area else null;
}

pub fn mousePosition() struct { x: i32, y: i32 } {
    var x: c_int = 0;
    var y: c_int = 0;
    if (ready) Reaper.GetMousePosition(&x, &y);
    return .{ .x = x, .y = y };
}

// ---- the audio hook ----

/// The layout of `audio_hook_register_t` in `reaper_plugin.h`.
pub const HookRegister = extern struct {
    on_audio_buffer: ?*const fn (is_post: bool, len: c_int, srate: f64, reg: *HookRegister) callconv(.C) void,
    userdata1: ?*anyopaque,
    userdata2: ?*anyopaque,
    input_nch: c_int,
    output_nch: c_int,
    get_buffer: ?*const fn (is_output: bool, idx: c_int) callconv(.C) ?[*]f64,
};

pub var bridge: ?*audio.Bridge = null;
var hook_reg = HookRegister{
    .on_audio_buffer = onAudioBuffer,
    .userdata1 = null,
    .userdata2 = null,
    .input_nch = 0,
    .output_nch = 0,
    .get_buffer = null,
};
var hook_registered: bool = false;

fn hookGet(ctx: *anyopaque, is_output: bool, index: usize) ?[*]f64 {
    const reg: *HookRegister = @ptrCast(@alignCast(ctx));
    const f = reg.get_buffer orelse return null;
    return f(is_output, @intCast(index));
}

fn onAudioBuffer(is_post: bool, len: c_int, srate: f64, reg: *HookRegister) callconv(.C) void {
    _ = srate;
    const b = bridge orelse return;
    if (len <= 0) return;
    const host = audio.HostBuffers{
        .ctx = reg,
        .input_nch = if (reg.input_nch < 0) 0 else @intCast(reg.input_nch),
        .output_nch = if (reg.output_nch < 0) 0 else @intCast(reg.output_nch),
        .get = hookGet,
    };
    b.onBuffer(is_post, @intCast(len), host);
}

/// Registers the hook once, the first time a loop is wanted.
pub fn registerHook(b: *audio.Bridge) void {
    if (!ready or hook_registered) return;
    bridge = b;
    _ = Reaper.Audio_RegHardwareHook(true, @ptrCast(&hook_reg));
    hook_registered = true;
}

/// Removes the hook. Because REAPER calls it from the audio thread, it must
/// be gone before the library unloads.
pub fn unregisterHook() void {
    if (!ready or !hook_registered) return;
    _ = Reaper.Audio_RegHardwareHook(false, @ptrCast(&hook_reg));
    hook_registered = false;
    bridge = null;
}

test "the keyboard is recognised by its device name" {
    try std.testing.expect(looksLikeVr09("VR-09"));
    try std.testing.expect(looksLikeVr09("Roland VR-09 MIDI 1"));
    try std.testing.expect(looksLikeVr09("vr09"));
    try std.testing.expect(!looksLikeVr09("IAC Driver Bus 1"));
}

test "the hook register has the layout REAPER expects" {
    // The offsets below are those of a 64-bit build: three pointers, two ints
    // and a pointer. On 32-bit targets the pointers are narrower.
    if (@sizeOf(usize) != 8) return error.SkipZigTest;
    try std.testing.expectEqual(@as(usize, 40), @sizeOf(HookRegister));
    try std.testing.expectEqual(@as(usize, 24), @offsetOf(HookRegister, "input_nch"));
    try std.testing.expectEqual(@as(usize, 32), @offsetOf(HookRegister, "get_buffer"));
}

test "every REAPER function the sources call is in reaper_api" {
    // Because initSubset leaves an unlisted function as a null pointer, a
    // forgotten name compiles fine and then crashes REAPER when it is
    // called. This test reads the sources and fails on such a name instead.
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var unlisted = std.ArrayList([]const u8).init(std.testing.allocator);
    defer unlisted.deinit();
    const api = @import("reaper");
    try api.unlistedCallsInPaths(arena.allocator(), @import("test_paths").sources, &reaper_api, &unlisted);
    for (unlisted.items) |name| std.debug.print("REAPER function used but missing from reaper_api: {s}\n", .{name});
    try std.testing.expectEqual(@as(usize, 0), unlisted.items.len);
}
