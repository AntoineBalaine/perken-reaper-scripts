const std = @import("std");
const c1 = @import("c1.zig");
const reaper = @import("reaper").reaper;
const statemachine = @import("statemachine.zig");
const State = statemachine.State;
const MidiEvtsFxCtrl = @import("csurf/midi_events_fxctrl.zig");
const log = std.log.scoped(.track_list);
const TrackList = @import("fx_ctrl_state.zig").TrackList;
const constants = @import("constants.zig");
const csurf = @import("csurf/control_surface.zig");
const builtin = @import("builtin");
// The C declarations, translated by the build from src/csurf/c_bindings.h.
const c = @import("c");
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
                    const cc: c1.CCs = @fromBackingInt(@intCast(@backingInt(c1.CCs.Tr_tr1) + @as(u8, @intCast(i))));
                    const value: u8 = if (led_state.blink_state) 0x7f else 0x0;
                    globals.unit.setLed(cc, value);
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
                const cc = @backingInt(c1.Tracks.Tr_tr1) +
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
            const cc = @backingInt(c1.Tracks.Tr_tr1) +
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
        globals.state.fx_ctrl.track_list.track_names[i].color = MidiEvtsFxCtrl.trackListColor(track_id);
        _ = reaper.GetTrackName(track, &globals.state.fx_ctrl.track_list.track_names[i].name, TrackList.TrackNameSize);
        globals.state.fx_ctrl.track_list.name_count += 1;
    }
}

fn focusPageTracks(globals: *Globals) void {
    const page_start: c_int = @intCast(globals.state.fx_ctrl.current_page * TrackList.PageSize);

    // The track list uses CSurf IDs (0=master, 1=first track, ...).
    // CSurf_TrackFromID maps these to MediaTrack pointers correctly.
    const first_tr = reaper.CSurf_TrackFromID(page_start, constants.g_csurf_mcpmode);
    if (first_tr == null) return;

    // Resize tracks so the current page fills the TCP viewport.
    // Because the scroll position depends on track heights, we must
    // apply the height zoom before scrolling.
    const GetDlgItem_fn = c.GetDlgItem orelse return;
    const GetClientRect_fn = c.GetClientRect orelse return;

    const main_hwnd: c.HWND = @ptrCast(reaper.GetMainHwnd());
    const arrange_hwnd = GetDlgItem_fn(main_hwnd, 0x3E8);
    if (arrange_hwnd == null) return;

    var rect: c.RECT = undefined;
    GetClientRect_fn(arrange_hwnd, &rect);
    // On macOS, SWELL can return flipped Y coordinates (bottom < top),
    // so we use @abs to normalize.
    const tcp_height: c_int = @intCast(@abs(rect.bottom - rect.top));
    if (tcp_height > 0) {
        applyTrackHeightZoom(tcp_height, @intCast(globals.state.fx_ctrl.current_page), TrackList.PageSize);
    }

    // Scroll after height changes so the scroll position accounts for
    // the new track heights.
    _ = reaper.SetMixerScroll(first_tr);

    // Scroll the arrange TCP to the first track on the page using the
    // same approach as SWS's ScrollToTrackIfNotInArrange: compute the
    // absolute Y by summing I_WNDH for all preceding tracks, then set
    // the scrollbar position via CoolSB_SetScrollInfo + WM_VSCROLL.
    scrollArrangeTCPToTrack(arrange_hwnd, page_start);
}

/// Scrolls the arrange TCP so that the track at the given CSurf ID is
/// at the top of the viewport. Uses CoolSB_SetScrollInfo (resolved via
/// plugin_getapi at runtime) followed by SendMessage(WM_VSCROLL) to
/// match the pattern used by the SWS extension.
fn scrollArrangeTCPToTrack(arrange_hwnd: c.HWND, target_csurf_id: c_int) void {
    const CoolSB_SetScrollInfoFn = *fn (c.HWND, c_int, *c.SCROLLINFO, c_int) callconv(.c) c_int;
    const CoolSB_GetScrollInfoFn = *fn (c.HWND, c_int, *c.SCROLLINFO) callconv(.c) c_int;

    const set_fn_ptr = reaper.plugin_getapi("CoolSB_SetScrollInfo");
    const get_fn_ptr = reaper.plugin_getapi("CoolSB_GetScrollInfo");
    if (set_fn_ptr == null or get_fn_ptr == null) return;

    const coolsb_set: CoolSB_SetScrollInfoFn = @ptrCast(@alignCast(set_fn_ptr));
    const coolsb_get: CoolSB_GetScrollInfoFn = @ptrCast(@alignCast(get_fn_ptr));

    // Get current scrollbar state
    var si: c.SCROLLINFO = std.mem.zeroes(c.SCROLLINFO);
    si.cbSize = @sizeOf(c.SCROLLINFO);
    si.fMask = c.SIF_ALL;
    _ = coolsb_get(arrange_hwnd, c.SB_VERT, &si);

    // Compute the absolute Y of the target track by summing I_WNDH
    // for all tracks before it (I_WNDH includes spacers).
    var abs_y: c_int = 0;
    var i: c_int = 0;
    while (i < target_csurf_id) : (i += 1) {
        const tr = reaper.CSurf_TrackFromID(i, constants.g_csurf_mcpmode);
        if (tr != null) {
            abs_y += @intFromFloat(reaper.GetMediaTrackInfo_Value(tr, "I_WNDH"));
        }
    }

    si.nPos = abs_y;
    _ = coolsb_set(arrange_hwnd, c.SB_VERT, &si, 1);

    const SendMessage_fn = c.SendMessage orelse return;
    _ = SendMessage_fn(arrange_hwnd, c.WM_VSCROLL, c.SB_THUMBPOSITION | (@as(c.WPARAM, @intCast(abs_y)) << 16), 0);
}

/// Resizes tracks so that the tracks on the given page fill the TCP viewport,
/// and resets tracks outside the page to their default height. Uses CSurf track
/// IDs (0=master, 1=first regular track, ...) to stay consistent with the
/// track list's indexing.
pub fn applyTrackHeightZoom(tcp_height: c_int, current_page: usize, page_size: usize) void {
    if (tcp_height <= 0) return;

    const track_height: f64 = @floatFromInt(@divFloor(tcp_height, @as(c_int, @intCast(page_size))));
    // CSurf track IDs: 0=master, 1..N=regular tracks. Total count = GetNumTracks() + 1.
    const track_count: usize = @intCast(reaper.GetNumTracks() + 1);
    const page_start = current_page * page_size;
    const page_end = @min(page_start + page_size, track_count);

    var i: usize = 0;
    while (i < track_count) : (i += 1) {
        const tr = reaper.CSurf_TrackFromID(@intCast(i), constants.g_csurf_mcpmode);
        if (tr == null) continue;

        if (i >= page_start and i < page_end) {
            _ = pReaper.SetMediaTrackInfo_Value(.{ tr, "I_HEIGHTOVERRIDE", track_height });
        } else {
            // Reset non-page tracks to default height
            _ = pReaper.SetMediaTrackInfo_Value(.{ tr, "I_HEIGHTOVERRIDE", 0 });
        }
    }

    reaper.TrackList_AdjustWindows(false);
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

    globals.state.selectedTracks.put(globals.arena_int.allocator(), csurf_id, {}) catch {};

    pReaper.CSurf_SetSurfaceSelected(.{ media_track, pReaper.CSurf_OnSelectedChange(.{ media_track, 1 }), @as(reaper.IReaperControlSurface, @ptrCast(csurf.my_csurf)) });
    return media_track;
}
