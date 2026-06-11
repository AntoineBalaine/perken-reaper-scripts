//! Native port of reavim custom_actions/routing.lua (both functions).
//! Color-based bus routing: tracks are routed to a bus when they share its
//! custom color, are not folder children, and are not the bus itself.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const actions = @import("../actions.zig");
const helpers = @import("helpers.zig");

/// Bus name prefixes created by buildBusses (verbatim from routing.lua,
/// including the trailing space in "PRC ").
const bus_names = [_][]const u8{
    "BA", "BGV", "BR", "Choir", "DR",   "FX",  "FullMix", "GTR", "Keys",
    "LD", "PD",  "PL", "PNO",   "PRC ", "STR", "TXT",     "WD",
};

/// GetParentTrack returns NULL for top-level tracks; the binding's return
/// type is non-optional, so re-type it (ABI identical).
fn getParentTrack(track: Reaper.MediaTrack) ?*Reaper.MediaTrack {
    const f: *const fn (track: Reaper.MediaTrack) callconv(.C) ?*Reaper.MediaTrack = @ptrCast(Reaper.GetParentTrack);
    return f(track);
}

/// routing.lua sendColorToMatchingBuss: route every top-level track with the
/// bus's custom color to the bus and cut its master send.
fn sendColorToMatchingBus(bus: Reaper.MediaTrack) void {
    const bus_tp = helpers.trackPtr(bus) orelse return;
    const bus_color = Reaper.GetMediaTrackInfo_Value(bus, "I_CUSTOMCOLOR");
    const bus_number = Reaper.GetMediaTrackInfo_Value(bus, "IP_TRACKNUMBER");
    const n = Reaper.CountTracks(0);
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        const track = Reaper.GetTrack(0, i) orelse continue;
        if (getParentTrack(track) != null) continue; // child tracks follow their folder
        const color = Reaper.GetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR");
        const number = Reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER");
        if (color != bus_color or number == bus_number) continue;
        _ = Reaper.CreateTrackSend(helpers.trackPtr(track).?, bus_tp);
        _ = Reaper.SetMediaTrackInfo_Value(track, "B_MAINSEND", 0);
    }
}

/// Route all tracks whose name contains "bus" (case-sensitive, like the Lua
/// string.find) to receive from same-colored tracks.
fn routeTracksToBusses(_: *actions.RunCtx) void {
    var busses = std.ArrayList(Reaper.MediaTrack).init(helpers.allocator);
    defer busses.deinit();

    const n = Reaper.CountTracks(0);
    var i: c_int = 0;
    while (i < n) : (i += 1) {
        const track = Reaper.GetTrack(0, i) orelse continue;
        var name_buf: [512]u8 = undefined;
        const name = helpers.getTrackString(track, "P_NAME", &name_buf) orelse continue;
        if (std.mem.indexOf(u8, name, "bus") != null)
            busses.append(track) catch return;
    }

    for (busses.items) |bus| sendColorToMatchingBus(bus);
}

/// Create a bus per prefix in `bus_names`, SWS-auto-color it, route matching
/// tracks to it, and delete it again if nothing got routed. Relies on SWS
/// auto-color rules existing in the user config (runNamedCommand warns when
/// SWS is missing).
fn buildBusses(_: *actions.RunCtx) void {
    for (bus_names) |name| {
        Reaper.InsertTrackAtIndex(0, true);
        const bus = Reaper.GetTrack(0, 0) orelse continue;
        _ = helpers.setTrackString(bus, "P_NAME", name);
        helpers.runNamedCommand("_SWSAUTOCOLOR_APPLY");
        sendColorToMatchingBus(bus);
        const receives = Reaper.GetTrackNumSends(helpers.trackPtr(bus).?, -1);
        if (receives == 0)
            Reaper.DeleteTrack(bus);
    }
}

// ---- registry entries -------------------------------------------------------------

pub const entries = [_]actions.Entry{
    .{ .name = "RouteToBusses", .def = .{ .steps = &.{.{ .func = &routeTracksToBusses }} } },
    .{ .name = "BuildBusses", .def = .{ .steps = &.{.{ .func = &buildBusses }} } },
};

test {
    _ = helpers;
}
