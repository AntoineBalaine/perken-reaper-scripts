const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Preferences = @import("settings.zig");
const globals = @import("globals.zig");
const ModulesList = @import("statemachine.zig").ModulesList;
const styles = @import("styles.zig");
const State = @import("statemachine.zig").State;
const TrackList = @import("fx_ctrl_state.zig").TrackList;
const PushWindowStyle = styles.PushStyle;
const safePrint = @import("debug_panel.zig").safePrint;

pub fn drawTrackList(ctx: imgui.ContextPtr, state: *State) !?usize {
    const PopStyle = try styles.PushStyle(ctx, .main);
    defer PopStyle(ctx) catch {};

    // Calculate window placement (right side of main window)
    try imgui.SetNextWindowDockID(.{ ctx, styles.Docker.RIGHT });

    var selected_track: ?usize = null;

    if (try imgui.Begin(.{ ctx, "Track List" })) {
        defer imgui.End(.{ctx}) catch {};

        const page_start = state.fx_ctrl.current_page * TrackList.PageSize;

        var buf: [TrackList.TrackNameSize + 4:0]u8 = undefined; // +4 for "XX. " prefix

        for (state.fx_ctrl.track_list.track_names, 0..) |name, i| {
            const track_number = page_start + i + 1;
            const is_selected = state.selectedTracks.contains(@intCast(track_number));

            if (is_selected) {
                const bg_color = try imgui.GetStyleColor(.{ ctx, imgui.Col_WindowBg });
                const text_color = try imgui.GetStyleColor(.{ ctx, imgui.Col_Text });
                try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, bg_color });
                try imgui.PushStyleColor(.{ ctx, imgui.Col_FrameBg, text_color });
            }
            defer if (is_selected) imgui.PopStyleColor(.{ ctx, 2 }) catch {};

            const label = try safePrint(&buf, "{d:>2}. {s}", .{ i + 1, name });

            if (try imgui.Selectable(.{ ctx, label })) {
                selected_track = track_number;
            }

            if (is_selected) {
                try imgui.PopStyleColor(.{ctx});
            }
        }
    }

    return selected_track;
}
