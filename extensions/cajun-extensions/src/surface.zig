//! cajun-extensions' hidden control surface.
//!
//! REAPER reports state changes (last-touched FX, parameter changes, focused
//! FX, track changes, ...) to control surfaces. Features that react to those
//! changes acquire this surface; it is registered with REAPER behind the
//! scenes (no entry in the control surface preferences) while at least one
//! feature holds it, and removed when the last one releases it, so that
//! REAPER does not call into the extension when no feature needs it.
//!
//! Today the auto lane watcher is the only subscriber; the dispatch in
//! `extended` routes each notification to it.
const std = @import("std");
const reaper = @import("reaper").reaper;
const csurf = @import("csurf");
const auto_lane_watcher = @import("auto_lane_watcher.zig");

const log = std.log.scoped(.surface);

/// Set while a feature writes to REAPER in a way that would echo back as
/// notifications it should not react to (e.g. rewriting a track chunk).
pub var ignore_notifications = false;

pub var instance: ?csurf.Surface = null;
pub var holders: u32 = 0;

const callbacks = csurf.Callbacks{
    .get_type_string = &typeString,
    .get_desc_string = &descString,
    .extended = &extended,
};

/// Registers the surface if it is not registered yet. Returns false if REAPER
/// refused it; the caller must then not call `release`.
pub fn acquire() bool {
    if (holders == 0) {
        const s = csurf.create(&callbacks) orelse return false;
        if (!csurf.register(s)) {
            csurf.destroy(s);
            return false;
        }
        instance = s;
        log.debug("control surface registered", .{});
    }
    holders += 1;
    return true;
}

/// Removes the surface once its last holder releases it.
pub fn release() void {
    if (holders == 0) return;
    holders -= 1;
    if (holders > 0) return;
    if (instance) |s| {
        csurf.unregister(s);
        csurf.destroy(s);
        instance = null;
        log.debug("control surface removed", .{});
    }
}

fn typeString(_: ?*anyopaque) callconv(.C) [*:0]const u8 {
    return "CAJUNEXT";
}

fn descString(_: ?*anyopaque) callconv(.C) [*:0]const u8 {
    return "Cajun extensions (internal)";
}

fn extended(_: ?*anyopaque, call: c_int, parm1: ?*anyopaque, parm2: ?*anyopaque, parm3: ?*anyopaque) callconv(.C) c_int {
    if (ignore_notifications) return 0;
    if (!auto_lane_watcher.isActive()) return 0;

    switch (call) {
        // parm1=(MediaTrack*)track, parm2=(int*)mediaitemidx (NULL for track
        // FX), parm3=(int*)fxidx. All NULL means the focused FX was cleared.
        csurf.ext.SETFOCUSEDFX => {
            if (parm2 != null) return 0; // media item FX chains are ignored
            if (parm1 == null) auto_lane_watcher.onFocusDismissed();
        },
        // parm3 is 0 when the FX UI closed, non-zero when it opened.
        csurf.ext.SETFXOPEN => {
            if (parm3 == null) auto_lane_watcher.onFocusDismissed();
        },
        csurf.ext.SETLASTTOUCHEDTRACK => {
            if (parm1) |track| auto_lane_watcher.onTrackChanged(@ptrCast(track));
        },
        // parm2=(int*)(fxidx<<16|paramidx).
        csurf.ext.SETFXPARAM => {
            const track = parm1 orelse return 0;
            const packed_ids: c_int = (@as(*c_int, @alignCast(@ptrCast(parm2 orelse return 0)))).*;
            const fx_index: c_int = (packed_ids >> 16) & 0xFFFF;
            const param_index: c_int = packed_ids & 0xFFFF;
            auto_lane_watcher.onFxParamChanged(@ptrCast(track), fx_index, param_index);
        },
        // parm1=(MediaTrack*)track, parm2=(int*)mediaitemidx (NULL for track
        // FX), parm3=(int*)fxidx. All NULL means the last-touched FX was
        // cleared.
        csurf.ext.SETLASTTOUCHEDFX => {
            if (parm2 != null) return 0; // media item FX are ignored
            const track = parm1 orelse {
                auto_lane_watcher.onFocusDismissed();
                return 1;
            };
            // parm3 carries only the FX index; GetLastTouchedFX, which REAPER
            // updates together with this notification, gives the parameter.
            var tracknumber: c_int = 0;
            var fxnumber: c_int = 0;
            var paramnumber: c_int = 0;
            if (!reaper.GetLastTouchedFX(&tracknumber, &fxnumber, &paramnumber)) return 0;
            // The low 24 bits are the FX's index in the chain; the high bits
            // flag input/record FX.
            const fx_index: c_int = fxnumber & 0x00FFFFFF;
            auto_lane_watcher.onLastTouchedFx(@ptrCast(track), fx_index, paramnumber);
        },
        else => return 0,
    }
    return 1;
}
