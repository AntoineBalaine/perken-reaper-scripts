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
    @cInclude("csurf/control_surface_wrapper.h");
    @cInclude("WDL/swell/swell-types.h");
    @cInclude("WDL/swell/swell-functions.h");
    @cInclude("WDL/win32_utf8.h");
    @cInclude("WDL/wdltypes.h");
    @cInclude("resource.h");
    @cInclude("csurf/midi_wrapper.h");
});
const globals = @import("globals.zig");
const actions = @import("actions.zig");

pub const TrackListAction = union(enum) {
    page_change: PgDirection,
    track_select: u8,
    blink_leds: struct {
        blink_state: bool,
        midi_out: reaper.midi_Output,
    },
    refresh,
};

pub fn trackListAction(state: *State, action: TrackListAction) void {
    switch (action) {
        .page_change => |direction| handlePageChange(state, direction),
        .track_select => |track_idx| {
            const track = setReaperTrackSelection(state, track_idx);
            if (track) |tr| {
                actions.dispatch(state, .{ .fx_ctrl = .{ .update_console_for_track = tr } });
            }
        },
        .blink_leds => |led_state| {
            const page_start = state.fx_ctrl.current_page * TrackList.PageSize;
            const track_count = reaper.CountTracks(0);

            // Iterate through track buttons in current page
            var i: usize = 0;
            while (i < TrackList.PageSize) : (i += 1) {
                const track_idx = page_start + i;
                if (track_idx >= track_count) break;

                // Skip if this is the last touched track
                if (track_idx == state.last_touched_tr_id) {
                    continue;
                }

                // If track is selected, blink its LED
                if (state.selectedTracks.contains(@intCast(track_idx))) {
                    const cc = @intFromEnum(c1.CCs.Tr_tr1) + @as(u8, @intCast(i));
                    const value: u8 = if (led_state.blink_state) 0x7f else 0x0;
                    c.MidiOut_Send(led_state.midi_out, 0xb0, cc, value, -1);
                }
            }
        },
        .refresh => updateTrackNames(state),
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
    if (state.last_touched_tr_id) |track_id| {
        if (track_id >= page_start and
            track_id < page_start + TrackList.PageSize)
        {
            const cc = @intFromEnum(c1.Tracks.Tr_tr1) +
                (track_id - page_start);
            try midi_out.send(0xB0, cc, 0x7F);
        }
    }
}

const PgDirection = enum { up, down };

fn handlePageChange(state: *State, direction: PgDirection) void {
    const track_count = reaper.CountTracks(0);
    if (track_count <= 0) return;

    // Calculate total pages (ceiling division)
    const track_count_uz = @as(usize, @intCast(@max(0, track_count)));
    const total_pages = (track_count_uz + TrackList.PageSize - 1) / TrackList.PageSize;

    // Update page with wrapping
    state.fx_ctrl.current_page = switch (direction) {
        .up => if (state.fx_ctrl.current_page >= total_pages - 1)
            0
        else
            state.fx_ctrl.current_page + 1,
        .down => if (state.fx_ctrl.current_page == 0)
            @intCast(total_pages - 1)
        else
            state.fx_ctrl.current_page - 1,
    };

    // Update track names for new page
    updateTrackNames(state);

    // Focus tracks in TCP if enabled
    if (globals.preferences.focus_page_tracks) {
        focusPageTracks(state);
    }
}

fn updateTrackNames(state: *State) void {
    log.debug("refresh track names", .{});
    const page_start = state.fx_ctrl.current_page * TrackList.PageSize;

    // Clear existing names
    state.fx_ctrl.track_list.name_count = 0;

    // Get names for tracks in current page
    var i: usize = 0;
    while (i < TrackList.PageSize) : (i += 1) {
        const track_idx = page_start + i;

        if (track_idx >= reaper.CountTracks(0)) break;

        const track = reaper.GetTrack(0, @intCast(track_idx));
        _ = reaper.GetTrackName(track, &state.fx_ctrl.track_list.track_names[i], TrackList.TrackNameSize);
        state.fx_ctrl.track_list.name_count += 1;
    }
}

fn focusPageTracks(state: *State) void {
    const page_start = state.fx_ctrl.current_page * TrackList.PageSize;
    const track_count = reaper.CountTracks(0);
    const page_end = @min(page_start + TrackList.PageSize, track_count);

    // First, unselect all tracks
    var i: usize = 0;
    while (i < track_count) : (i += 1) {
        const track = reaper.GetTrack(0, @intCast(i));
        reaper.CSurf_OnTrackSelection(track);
    }

    // Select tracks in current page
    i = page_start;
    while (i < page_end) : (i += 1) {
        const track = reaper.GetTrack(0, @intCast(i));
        reaper.CSurf_OnTrackSelection(track);
    }

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
}

// unselect all other tracks.
fn setReaperTrackSelection(state: *State, idx: u8) ?reaper.MediaTrack {
    // 1. Check if index is valid
    const track_count = reaper.CountTracks(0);
    if (idx >= track_count) {
        log.warn("invalid track index: track {d} doesn't exist\n", .{idx});
    }

    // First unselect all tracks

    var it = globals.state.selectedTracks.iterator();
    while (it.next()) |entry| {
        const tr_id = entry.key_ptr.*;
        const track = reaper.CSurf_TrackFromID(tr_id, constants.g_csurf_mcpmode);
        reaper.CSurf_SetSurfaceSelected(track, reaper.CSurf_OnSelectedChange(track, 0), @ptrCast(csurf.my_csurf));
    }
    globals.state.selectedTracks.clearRetainingCapacity();

    const media_track = reaper.GetTrack(0, idx);
    const id = reaper.CSurf_TrackToID(media_track, constants.g_csurf_mcpmode);

    globals.state.selectedTracks.put(globals.allocator, id, {}) catch {};
    // 2. Don't unselect if same track (your existing check)
    if (id == state.last_touched_tr_id) return null;

    reaper.CSurf_SetSurfaceSelected(media_track, reaper.CSurf_OnSelectedChange(media_track, 1), @ptrCast(csurf.my_csurf));
    return media_track;
}
