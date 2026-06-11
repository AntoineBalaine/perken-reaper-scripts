//! Native port of reavim custom_actions/tracks.lua (all 4 functions).
//! Action names and flags mirror definitions/extended_defaults/actions.lua.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const actions = @import("../actions.zig");
const helpers = @import("helpers.zig");

// ---- track volume nudges ------------------------------------------------------

fn nudgeSelectedTracksVolume(db: f64) void {
    const factor = std.math.pow(f64, 10.0, 0.05 * db);
    const n = Reaper.CountSelectedTracks(0);
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        const track = Reaper.GetSelectedTrack(0, i) orelse continue;
        const vol = Reaper.GetMediaTrackInfo_Value(track, "D_VOL");
        _ = Reaper.SetMediaTrackInfo_Value(track, "D_VOL", vol * factor);
    }
}

fn trackVolumeDown3(_: *actions.RunCtx) void {
    nudgeSelectedTracksVolume(-3);
}

fn trackVolumeUp3(_: *actions.RunCtx) void {
    nudgeSelectedTracksVolume(3);
}

// ---- rename track to its VSTi / preset name ------------------------------------

/// Lua: fx_name:gsub("VSTi: ", ""):gsub(" %(.-%)", "") — drop every
/// "VSTi: " occurrence and every " ( ... )" group (shortest match).
fn cleanFxName(in: []const u8, out: []u8) []const u8 {
    var n: usize = 0;
    var i: usize = 0;
    while (i < in.len and n < out.len) {
        if (std.mem.startsWith(u8, in[i..], "VSTi: ")) {
            i += "VSTi: ".len;
            continue;
        }
        if (in[i] == ' ' and i + 1 < in.len and in[i + 1] == '(') {
            if (std.mem.indexOfScalarPos(u8, in, i + 2, ')')) |close| {
                i = close + 1;
                continue;
            }
        }
        out[n] = in[i];
        n += 1;
        i += 1;
    }
    return out[0..n];
}

fn renameTrackToVstiPresetName(_: *actions.RunCtx) void {
    const n = Reaper.CountSelectedTracks(0);
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        const track = Reaper.GetSelectedTrack(0, i) orelse continue;
        const vsti = Reaper.TrackFX_GetInstrument(track);
        if (vsti < 0) continue;

        var fx_buf: [512]u8 = undefined;
        fx_buf[0] = 0;
        _ = Reaper.TrackFX_GetFXName(track, vsti, @ptrCast(&fx_buf), fx_buf.len);
        var clean_buf: [512]u8 = undefined;
        const fx_name = cleanFxName(std.mem.sliceTo(&fx_buf, 0), &clean_buf);

        var preset_buf: [512]u8 = undefined;
        preset_buf[0] = 0;
        const has_preset = Reaper.TrackFX_GetPreset(track, vsti, @ptrCast(&preset_buf), preset_buf.len);
        const preset = std.mem.sliceTo(&preset_buf, 0);

        // FIXED vs lua: the Lua compared TrackFX_GetPreset's boolean retval
        // against 0 ("retval == 0" is always false), so it always wrote the
        // preset name even when none existed. Restore the intent: use the
        // preset name when there is one, else the cleaned FX name.
        const new_name = if (has_preset and preset.len > 0) preset else fx_name;
        _ = helpers.setTrackString(track, "P_NAME", new_name);
    }
}

// ---- exclusive solo toggle ------------------------------------------------------

fn soloExclusive(_: *actions.RunCtx) void {
    // FIXED vs lua: no nil check — GetMediaTrackInfo_Value(nil) errored when
    // nothing was selected.
    const track = Reaper.GetSelectedTrack(0, 0) orelse return;
    const solo = Reaper.GetMediaTrackInfo_Value(track, "I_SOLO");
    Reaper.Main_OnCommand(40340, 0); // unsolo all tracks
    if (solo == 0)
        _ = Reaper.SetMediaTrackInfo_Value(track, "I_SOLO", 1);
}

// ---- registry entries -------------------------------------------------------------

pub const entries = [_]actions.Entry{
    .{ .name = "TrackVolumeDown3", .def = .{ .steps = &.{.{ .func = &trackVolumeDown3 }}, .prefix_repetition_count = true } },
    .{ .name = "TrackVolumeUp3", .def = .{ .steps = &.{.{ .func = &trackVolumeUp3 }}, .prefix_repetition_count = true } },
    .{ .name = "RenameTrackToVstiPresetName", .def = .{ .steps = &.{.{ .func = &renameTrackToVstiPresetName }} } },
    .{ .name = "toggleSoloExclusive", .def = .{ .steps = &.{.{ .func = &soloExclusive }} } },
};

// ---- tests ------------------------------------------------------------------

test "cleanFxName strips VSTi prefix and parentheticals" {
    var buf: [128]u8 = undefined;
    try std.testing.expectEqualStrings(
        "Serum",
        cleanFxName("VSTi: Serum (Xfer Records)", &buf),
    );
    try std.testing.expectEqualStrings(
        "Kontakt 7",
        cleanFxName("VSTi: Kontakt 7 (Native Instruments) (16 out)", &buf),
    );
    // unmatched "(" is kept, like Lua's non-greedy pattern
    try std.testing.expectEqualStrings("Foo (bar", cleanFxName("Foo (bar", &buf));
    try std.testing.expectEqualStrings("Plain", cleanFxName("Plain", &buf));
}

test {
    _ = helpers;
}
