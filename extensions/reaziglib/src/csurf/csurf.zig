//! Zig side of the control surface shim (csurf_shim.cpp).
//!
//! A control surface is how REAPER tells an extension that its state
//! changed: track selection, volume/pan/mute/solo, play state, last-touched
//! FX, parameter changes, and so on. REAPER calls a surface through a C++
//! virtual table, so the shim provides a C++ subclass of
//! IReaperControlSurface whose methods forward to the `Callbacks` table
//! below. Register the returned surface with
//! `plugin_register("csurf_inst", surface)` — a surface added "behind the
//! scenes", without an entry in REAPER's control surface preferences — and
//! remove it with `plugin_register("-csurf_inst", surface)` before
//! `destroy`.
//!
//! Extensions opt in with `reaziglib.addCsurf`, which adds this module and
//! compiles csurf_shim.cpp with REAPER's own toolchain: REAPER calls the shim
//! through C++ virtual methods (see extensions/README.md).
const std = @import("std");
const Reaper = @import("reaper").reaper;

pub const Callbacks = extern struct {
    ctx: ?*anyopaque = null,
    get_type_string: *const fn (ctx: ?*anyopaque) callconv(.c) [*:0]const u8,
    get_desc_string: *const fn (ctx: ?*anyopaque) callconv(.c) [*:0]const u8,
    get_config_string: ?*const fn (ctx: ?*anyopaque) callconv(.c) [*:0]const u8 = null,
    close_no_reset: ?*const fn (ctx: ?*anyopaque) callconv(.c) void = null,
    run: ?*const fn (ctx: ?*anyopaque) callconv(.c) void = null,
    set_track_list_change: ?*const fn (ctx: ?*anyopaque) callconv(.c) void = null,
    set_surface_volume: ?*const fn (ctx: ?*anyopaque, track: ?*anyopaque, volume: f64) callconv(.c) void = null,
    set_surface_pan: ?*const fn (ctx: ?*anyopaque, track: ?*anyopaque, pan: f64) callconv(.c) void = null,
    set_surface_mute: ?*const fn (ctx: ?*anyopaque, track: ?*anyopaque, mute: bool) callconv(.c) void = null,
    set_surface_selected: ?*const fn (ctx: ?*anyopaque, track: ?*anyopaque, selected: bool) callconv(.c) void = null,
    set_surface_solo: ?*const fn (ctx: ?*anyopaque, track: ?*anyopaque, solo: bool) callconv(.c) void = null,
    set_surface_rec_arm: ?*const fn (ctx: ?*anyopaque, track: ?*anyopaque, recarm: bool) callconv(.c) void = null,
    set_play_state: ?*const fn (ctx: ?*anyopaque, play: bool, pause: bool, rec: bool) callconv(.c) void = null,
    set_repeat_state: ?*const fn (ctx: ?*anyopaque, rep: bool) callconv(.c) void = null,
    set_track_title: ?*const fn (ctx: ?*anyopaque, track: ?*anyopaque, title: [*:0]const u8) callconv(.c) void = null,
    get_touch_state: ?*const fn (ctx: ?*anyopaque, track: ?*anyopaque, is_pan: c_int) callconv(.c) bool = null,
    set_auto_mode: ?*const fn (ctx: ?*anyopaque, mode: c_int) callconv(.c) void = null,
    reset_cached_vol_pan_states: ?*const fn (ctx: ?*anyopaque) callconv(.c) void = null,
    on_track_selection: ?*const fn (ctx: ?*anyopaque, track: ?*anyopaque) callconv(.c) void = null,
    is_key_down: ?*const fn (ctx: ?*anyopaque, key: c_int) callconv(.c) bool = null,
    extended: ?*const fn (ctx: ?*anyopaque, call: c_int, parm1: ?*anyopaque, parm2: ?*anyopaque, parm3: ?*anyopaque) callconv(.c) c_int = null,
};

extern fn zcsurf_create(callbacks: *const Callbacks) ?*anyopaque;
extern fn zcsurf_destroy(surface: ?*anyopaque) void;

/// An IReaperControlSurface* to hand to plugin_register("csurf_inst").
pub const Surface = *anyopaque;

/// Creates a surface forwarding to `callbacks`, which must outlive it.
pub fn create(callbacks: *const Callbacks) ?Surface {
    return zcsurf_create(callbacks);
}

/// Destroys a surface. Unregister it from REAPER first.
pub fn destroy(surface: Surface) void {
    zcsurf_destroy(surface);
}

/// Adds the surface to REAPER behind the scenes. Returns false on failure.
pub fn register(surface: Surface) bool {
    return Reaper.plugin_register("csurf_inst", surface) != 0;
}

/// Removes a surface added with `register`.
pub fn unregister(surface: Surface) void {
    _ = Reaper.plugin_register("-csurf_inst", surface);
}

/// `call` values of IReaperControlSurface::Extended (reaper_plugin.h).
pub const ext = struct {
    pub const RESET: c_int = 0x0001FFFF;
    pub const SETINPUTMONITOR: c_int = 0x00010001;
    pub const SETMETRONOME: c_int = 0x00010002;
    pub const SETAUTORECARM: c_int = 0x00010003;
    pub const SETRECMODE: c_int = 0x00010004;
    pub const SETSENDVOLUME: c_int = 0x00010005;
    pub const SETSENDPAN: c_int = 0x00010006;
    pub const SETFXENABLED: c_int = 0x00010007;
    /// parm1=(MediaTrack*)track, parm2=(int*)(fxidx<<16|paramidx), parm3=(double*)normalized value
    pub const SETFXPARAM: c_int = 0x00010008;
    pub const SETFXPARAM_RECFX: c_int = 0x00010018;
    pub const SETBPMANDPLAYRATE: c_int = 0x00010009;
    /// parm1=(MediaTrack*)track, parm2=(int*)mediaitemidx (may be NULL), parm3=(int*)fxidx. all NULL=clear
    pub const SETLASTTOUCHEDFX: c_int = 0x0001000A;
    /// parm1=(MediaTrack*)track, parm2=(int*)mediaitemidx (may be NULL), parm3=(int*)fxidx. all NULL=clear
    pub const SETFOCUSEDFX: c_int = 0x0001000B;
    /// parm1=(MediaTrack*)track
    pub const SETLASTTOUCHEDTRACK: c_int = 0x0001000C;
    pub const SETMIXERSCROLL: c_int = 0x0001000D;
    pub const SETPAN_EX: c_int = 0x0001000E;
    pub const SETRECVVOLUME: c_int = 0x00010010;
    pub const SETRECVPAN: c_int = 0x00010011;
    /// parm1=(MediaTrack*)track, parm2=(int*)fxidx, parm3=0 if UI closed, !0 if open
    pub const SETFXOPEN: c_int = 0x00010012;
    /// parm1=(MediaTrack*)track, whenever FX are added, deleted, or change order
    pub const SETFXCHANGE: c_int = 0x00010013;
};

// ---- tests ----
//
// csurf_shim_test.cpp plays REAPER's part: it calls the surface through
// IReaperControlSurface's virtual table, as REAPER would.

extern fn zcsurf_test_call_type_string(surface: Surface) [*:0]const u8;
extern fn zcsurf_test_call_extended(surface: Surface, call: c_int, p1: ?*anyopaque, p2: ?*anyopaque, p3: ?*anyopaque) c_int;
extern fn zcsurf_test_call_set_surface_mute(surface: Surface, track: ?*anyopaque, mute: bool) void;
extern fn zcsurf_test_call_get_touch_state(surface: Surface, track: ?*anyopaque, is_pan: c_int) bool;

pub const TestRecorder = struct {
    extended_calls: u32 = 0,
    last_call: c_int = 0,
    last_mute: ?bool = null,
};

fn testTypeString(_: ?*anyopaque) callconv(.c) [*:0]const u8 {
    return "TESTSURFACE";
}

fn testExtended(ctx: ?*anyopaque, call: c_int, _: ?*anyopaque, _: ?*anyopaque, _: ?*anyopaque) callconv(.c) c_int {
    const rec: *TestRecorder = @ptrCast(@alignCast(ctx.?));
    rec.extended_calls += 1;
    rec.last_call = call;
    return 7;
}

fn testMute(ctx: ?*anyopaque, _: ?*anyopaque, mute: bool) callconv(.c) void {
    const rec: *TestRecorder = @ptrCast(@alignCast(ctx.?));
    rec.last_mute = mute;
}

test "virtual calls reach the Zig callbacks; unset callbacks use the defaults" {
    var rec = TestRecorder{};
    const cb = Callbacks{
        .ctx = &rec,
        .get_type_string = &testTypeString,
        .get_desc_string = &testTypeString,
        .set_surface_mute = &testMute,
        .extended = &testExtended,
    };
    const s = create(&cb).?;
    defer destroy(s);

    try std.testing.expectEqualStrings("TESTSURFACE", std.mem.span(zcsurf_test_call_type_string(s)));
    try std.testing.expectEqual(@as(c_int, 7), zcsurf_test_call_extended(s, ext.SETLASTTOUCHEDTRACK, null, null, null));
    try std.testing.expectEqual(@as(u32, 1), rec.extended_calls);
    try std.testing.expectEqual(ext.SETLASTTOUCHEDTRACK, rec.last_call);
    zcsurf_test_call_set_surface_mute(s, null, true);
    try std.testing.expectEqual(@as(?bool, true), rec.last_mute);
    // get_touch_state is unset, so the IReaperControlSurface default answers.
    try std.testing.expect(!zcsurf_test_call_get_touch_state(s, null, 0));
}
