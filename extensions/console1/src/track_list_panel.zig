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
const TrackListPanelAction = union(enum) {
    select_track: usize,
    open_module_browser: ModulesList,
    open_settings,
};
pub fn drawTrackList(ctx: imgui.ContextPtr, state: *State, modifier_active: bool) !?TrackListPanelAction {
    const PopStyle = try styles.PushStyle(ctx, .rack);
    defer PopStyle(ctx) catch {};

    try imgui.SetNextWindowDockID(.{ ctx, styles.Docker.RIGHT });

    var action: ?TrackListPanelAction = null;

    if (try imgui.Begin(.{ ctx, "Track List" })) {
        defer imgui.End(.{ctx}) catch {};

        const page_start = state.fx_ctrl.current_page * TrackList.PageSize;
        var buf: [TrackList.TrackNameSize + 4:0]u8 = undefined;

        for (state.fx_ctrl.track_list.track_names, 0..) |name, i| {
            const track_number = page_start + i + 1;
            const is_selected = state.selectedTracks.contains(@intCast(track_number));

            // Special handling for modifier keys
            if (modifier_active and (i < 5 or i == 19)) {
                const label = try safePrint(&buf, "{d:>2}. {s}", .{
                    i + 1,
                    switch (i) {
                        0 => "Input Load",
                        1 => "Gate Load",
                        2 => "EQ Load",
                        3 => "Comp Load",
                        4 => "Output Load",
                        19 => "Settings",
                        else => unreachable,
                    },
                });

                if (try imgui.Selectable(.{ ctx, label })) {
                    action = if (i == 19)
                        .{ .open_settings = {} }
                    else
                        .{ .open_module_browser = switch (i) {
                            0 => .INPUT,
                            1 => .GATE,
                            2 => .EQ,
                            3 => .COMP,
                            4 => .OUTPT,
                            else => unreachable,
                        } };
                }
                continue;
            }

            // Normal track selection handling
            if (is_selected) {
                const bg_color = try imgui.GetStyleColor(.{ ctx, imgui.Col_WindowBg });
                const text_color = try imgui.GetStyleColor(.{ ctx, imgui.Col_Text });
                try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, bg_color });
                try imgui.PushStyleColor(.{ ctx, imgui.Col_FrameBg, text_color });
            }
            defer if (is_selected) imgui.PopStyleColor(.{ ctx, 2 }) catch {};

            const label = try safePrint(&buf, "{d:>2}. {s}", .{ i + 1, name });

            if (try imgui.Selectable(.{ ctx, label })) {
                action = .{ .select_track = track_number };
            }
        }
    }

    return action;
}
