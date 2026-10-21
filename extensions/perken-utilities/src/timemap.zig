//! Null-safe wrappers over REAPER's time map.
//!
//! The generated bindings type `proj` and the optional out-parameters of
//! these functions as non-null pointers, while the C API takes NULL for the
//! active project and for every output a caller does not want. Each wrapper
//! below re-types its function through the signature the C API actually
//! has, which is the same trick abc_export.zig already uses for
//! `TimeMap_GetTimeSigAtTime` — gathered here so there is one copy.
//!
//! Positions are project quarter notes (QN) or project time in seconds, as
//! named. QN is the domain to prefer: bars are defined in beats, so tempo
//! changes do not affect QN-to-bar arithmetic at all, and a take's
//! PPQ-to-QN mapping accounts for playrate and time stretching, which raw
//! PPQ does not.

const std = @import("std");
const Reaper = @import("reaper").reaper;

pub fn qnToTime(qn: f64) f64 {
    const f: *const fn (proj: ?*anyopaque, qn: f64) callconv(.C) f64 = @ptrCast(Reaper.TimeMap2_QNToTime);
    return f(null, qn);
}

pub fn timeToQn(time: f64) f64 {
    const f: *const fn (proj: ?*anyopaque, time: f64) callconv(.C) f64 = @ptrCast(Reaper.TimeMap2_timeToQN);
    return f(null, time);
}

pub const Signature = struct { num: u32, denom: u32 };

/// The time signature in force at `time`.
pub fn sigAtTime(time: f64) Signature {
    const f: *const fn (proj: ?*anyopaque, time: f64, num: *c_int, denom: *c_int, tempo: *f64) callconv(.C) void =
        @ptrCast(Reaper.TimeMap_GetTimeSigAtTime);
    var num: c_int = 4;
    var denom: c_int = 4;
    var tempo: f64 = 120;
    f(null, time, &num, &denom, &tempo);
    // A project always has a signature; clamp anyway so a surprising reply
    // cannot produce a zero-length bar and hang a caller walking bars.
    return .{
        .num = if (num > 0) @intCast(num) else 4,
        .denom = if (denom > 0) @intCast(denom) else 4,
    };
}

/// The measure index containing `time`, as REAPER counts them.
pub fn measureAtTime(time: f64) c_int {
    const f: *const fn (
        proj: ?*anyopaque,
        tpos: f64,
        measures: ?*c_int,
        cml: ?*c_int,
        fullbeats: ?*f64,
        cdenom: ?*c_int,
    ) callconv(.C) f64 = @ptrCast(Reaper.TimeMap2_timeToBeats);
    var measure: c_int = 0;
    _ = f(null, time, &measure, null, null, null);
    return measure;
}

/// The time at which measure `measure` begins. Asking REAPER for the
/// measure's own start, rather than adding up nominal bar lengths, is what
/// keeps partial bars (a time-signature marker placed off a barline)
/// honest: REAPER's grid is what the user sees.
pub fn measureStartTime(measure: c_int) f64 {
    const f: *const fn (proj: ?*anyopaque, tpos: f64, measures: ?*const c_int) callconv(.C) f64 =
        @ptrCast(Reaper.TimeMap2_beatsToTime);
    var m = measure;
    return f(null, 0.0, &m);
}

/// The QN position where the measure containing `qn` begins.
pub fn barStartQn(qn: f64) f64 {
    const time = qnToTime(qn);
    return timeToQn(measureStartTime(measureAtTime(time)));
}

/// The QN position where the measure after the one containing `qn` begins.
pub fn nextBarStartQn(qn: f64) f64 {
    const time = qnToTime(qn);
    return timeToQn(measureStartTime(measureAtTime(time) + 1));
}

/// The time signature in force at a QN position.
pub fn sigAtQn(qn: f64) Signature {
    return sigAtTime(qnToTime(qn));
}
