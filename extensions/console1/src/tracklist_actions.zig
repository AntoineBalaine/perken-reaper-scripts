const std = @import("std");
const c1 = @import("c1.zig");
const reaper = @import("reaper.zig").reaper;
const statemachine = @import("statemachine.zig");
const State = statemachine.State;
const log = std.log.scoped(.track_list);
const TrackList = @import("fx_ctrl_state.zig").TrackList;
const constants = @import("constants.zig");
const csurf = @import("csurf/control_surface.zig");
const c = @cImport({
    @cDefine("SWELL_PROVIDED_BY_APP", "");
    // ARM64 has unsigned char by default, skip WDL's signedness assertion
    @cDefine("WDL_ALLOW_UNSIGNED_DEFAULT_CHAR", "1");
    @cInclude("csurf/control_surface_wrapper.h");
    @cInclude("WDL/swell/swell-types.h");
    @cInclude("WDL/swell/swell-functions.h");
    @cInclude("WDL/win32_utf8.h");
    @cInclude("WDL/wdltypes.h");
    @cInclude("resource.h");
    @cInclude("csurf/midi_wrapper.h");
});
const actions = @import("actions.zig");
const pReaper = @import("pReaper.zig");
const Globals = @import("globals.zig").Globals;

pub const TrackListAction = @import("action_types.zig").TrackListAction;
pub const PgDirection = @import("action_types.zig").PgDirection;

pub fn trackListAction(globals: *Globals, action: TrackListAction) void {
    switch (action) {
        .page_change => |direction| handlePageChange(globals, direction),
        .track_select => |track_id| {
            const track = setReaperTrackSelection(globals, track_id);
            if (track) |tr| {
                actions.dispatch(globals, .{ .fx_ctrl = .{ .on_track_entry = tr } });
            }
        },
        .blink_leds => |led_state| {
            const page_start = globals.state.fx_ctrl.current_page * TrackList.PageSize;
            const track_count = reaper.GetNumTracks() + 1; // +  1 to account for master

            // Iterate through track buttons in current page
            var i: usize = 0;
            while (i < TrackList.PageSize) : (i += 1) {
                const track_id: c_int = @intCast(page_start + i);
                if (track_id >= track_count) break;

                // Skip if this is the last touched track
                if (track_id == globals.state.current_tr_id) {
                    continue;
                }

                // If track is selected, blink its LED
                if (globals.state.selectedTracks.contains(track_id)) {
                    const cc = @intFromEnum(c1.CCs.Tr_tr1) + @as(u8, @intCast(i));
                    const value: u8 = if (led_state.blink_state) 0x7f else 0x0;
                    c.MidiOut_Send(led_state.midi_out, 0xb0, cc, value, -1);
                }
            }
        },
        .refresh => updateTrackNames(globals),
    }
}

fn updateTrackLEDs(state: *State, midi_out: *reaper.midi_Output) !void {
    const page_start = state.fx_ctrl.current_page * TrackList.PageSize;

    // Turn off all track LEDs first
    inline for (std.enums.values(c1.Tracks)) |track_cc| {
        try midi_out.send(0xB0, track_cc, 0);
    }

    // Light up selected tracks (blinking)
    const should_blink = (state.fx_ctrl.track_list.blink_counter & 0x20) != 0;

    if (should_blink) {
        var it = state.selectedTracks.iterator();
        while (it.next()) |track| {
            const track_num = track.key;
            if (track_num >= page_start and
                track_num < page_start + TrackList.PageSize)
            {
                const cc = @intFromEnum(c1.Tracks.Tr_tr1) +
                    (track_num - page_start);
                try midi_out.send(0xB0, cc, 0x7F);
            }
        }
    }

    // Always light up last touched track
    if (state.current_tr_id) |track_id| {
        if (track_id >= page_start and
            track_id < page_start + TrackList.PageSize)
        {
            const cc = @intFromEnum(c1.Tracks.Tr_tr1) +
                (track_id - page_start);
            try midi_out.send(0xB0, cc, 0x7F);
        }
    }
}

fn handlePageChange(globals: *Globals, direction: PgDirection) void {
    const track_count = reaper.GetNumTracks() + 1;
    if (track_count <= 0) return;

    // Calculate total pages (ceiling division)
    const track_count_uz = @as(usize, @intCast(@max(0, track_count)));
    const total_pages = (track_count_uz + TrackList.PageSize - 1) / TrackList.PageSize;

    // Update page with wrapping
    globals.state.fx_ctrl.current_page = switch (direction) {
        .up => if (globals.state.fx_ctrl.current_page >= total_pages - 1)
            0
        else
            globals.state.fx_ctrl.current_page + 1,
        .down => if (globals.state.fx_ctrl.current_page == 0)
            @intCast(total_pages - 1)
        else
            globals.state.fx_ctrl.current_page - 1,
    };

    // Update track names for new page
    updateTrackNames(globals);

    // Focus tracks in TCP if enabled
    if (globals.preferences.focus_page_tracks) {
        focusPageTracks(globals);
    }
}

fn updateTrackNames(globals: *Globals) void {
    log.debug("refresh track names", .{});
    const page_start = globals.state.fx_ctrl.current_page * TrackList.PageSize;

    // Clear existing names
    globals.state.fx_ctrl.track_list.name_count = 0;

    // Get names for tracks in current page
    var i: usize = 0;
    while (i < TrackList.PageSize) : (i += 1) {
        const track_id: c_int = @intCast(page_start + i);

        if (track_id >= reaper.GetNumTracks() + 1) break; // +  1 to account for master

        // ASSUMPTION: csurf track ids are sequential, start 0 for master track
        const track = reaper.CSurf_TrackFromID(@intCast(track_id), constants.g_csurf_mcpmode);
        globals.state.fx_ctrl.track_list.track_names[i].id = track_id;
        _ = reaper.GetTrackName(track, &globals.state.fx_ctrl.track_list.track_names[i].name, TrackList.TrackNameSize);
        globals.state.fx_ctrl.track_list.name_count += 1;
    }
}

fn focusPageTracks(globals: *Globals) void {
    const page_start = globals.state.fx_ctrl.current_page * TrackList.PageSize;

    // Set vertical scroll to show selected tracks
    // Note: this requires SWS extension
    if (reaper.APIExists("BR_GetArrangeView")) {
        // FIXME: there should be a way to have this using the type system.
        // // Get arrange view info
        // var start_time: f64 = undefined;
        // var end_time: f64 = undefined;
        // _ = reaper.BR_GetArrangeView(null, &start_time, &end_time);

        // // Get first and last track positions
        // if (reaper.GetTrack(0, @intCast(page_start))) |first_tr| {
        //     if (reaper.GetTrack(0, @intCast(page_end - 1))) |last_tr| {
        //         const first_y = reaper.GetMediaTrackInfo_Value(first_tr, "I_TCPY");
        //         const last_y = reaper.GetMediaTrackInfo_Value(last_tr, "I_TCPY");
        //         const last_h = reaper.GetMediaTrackInfo_Value(last_tr, "I_TCPH");

        //         // Adjust view to show all selected tracks
        //         _ = reaper.BR_SetArrangeView(null, start_time, end_time, first_y, last_y + last_h);
        //     }
        // }
    } else {
        // Fallback if SWS not available: use basic scroll
        const first_tr = reaper.GetTrack(0, @intCast(page_start));
        _ = reaper.SetMixerScroll(first_tr);
    }

    // Optional: adjust track heights to fit in view
    if (globals.preferences.focus_page_tracks) {
        // FIXME: should be able to query the arrange view height
        // const arrange_h = reaper.GetMainHwnd(); // Get arrange window height
        // const target_height = @as(i32, @intFromFloat(@as(f32, @floatFromInt(arrange_h)) / @as(f32, @floatFromInt(TrackList.PageSize))));

        // i = page_start;
        // while (i < page_end) : (i += 1) {
        //     if (reaper.GetTrack(0, @intCast(i))) |tr| {
        //         _ = reaper.SetMediaTrackInfo_Value(tr, "I_TCPH", target_height);
        //     }
        // }
    }
    unreachable;
}

// unselect all other tracks.
pub fn setReaperTrackSelection(globals: *Globals, csurf_id: c_int) ?reaper.MediaTrack {
    // 1. Check if index is valid
    const track_count = reaper.GetNumTracks() + 1; // including master
    if (csurf_id >= track_count) {
        log.warn("invalid track index: track {d} doesn't exist\n", .{csurf_id});
    }

    // First unselect all tracks
    var it = globals.state.selectedTracks.iterator();
    while (it.next()) |entry| {
        const tr_id = entry.key_ptr.*;
        const track = reaper.CSurf_TrackFromID(tr_id, constants.g_csurf_mcpmode);
        pReaper.CSurf_SetSurfaceSelected(.{ track, pReaper.CSurf_OnSelectedChange(.{ track, 0 }), @as(reaper.IReaperControlSurface, @ptrCast(csurf.my_csurf)) });
    }
    globals.state.selectedTracks.clearRetainingCapacity();

    const media_track = reaper.CSurf_TrackFromID(csurf_id, constants.g_csurf_mcpmode);

    globals.state.selectedTracks.put(globals.arena, csurf_id, {}) catch {};

    pReaper.CSurf_SetSurfaceSelected(.{ media_track, pReaper.CSurf_OnSelectedChange(.{ media_track, 1 }), @as(reaper.IReaperControlSurface, @ptrCast(csurf.my_csurf)) });
    return media_track;
}
