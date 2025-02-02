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
    select_track: c_int,
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

        var buf: [TrackList.TrackNameSize + 4:0]u8 = undefined;

        for (state.fx_ctrl.track_list.track_names, 0..) |tr, i| {
            const name = tr.name;
            const tr_id = tr.id;
            const is_selected = state.selectedTracks.contains(@intCast(tr_id));

            // Special handling for modifier keys
            if (modifier_active and (i < 5 or i == 19)) {
                const label = safePrint(&buf, "{d:>2}. {s}", .{
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
                const text_color = try imgui.GetStyleColor(.{ ctx, imgui.Col_TextSelectedBg });
                try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, text_color });
            }
            defer if (is_selected) imgui.PopStyleColor(.{ ctx, 1 }) catch {};

            const label = safePrint(&buf, "{d:>2}. {s}", .{ i + 1, name });

            if (try imgui.Selectable(.{ ctx, label })) {
                action = .{ .select_track = tr_id };
            }
        }
    }

    return action;
}

pub fn drawTrackListTwoColumns(ctx: imgui.ContextPtr, state: *State, modifier_active: bool) !?TrackListPanelAction {
    const PopStyle = try styles.PushStyle(ctx, .rack);
    defer PopStyle(ctx) catch {};

    var action: ?TrackListPanelAction = null;
    var buf: [TrackList.TrackNameSize + 4:0]u8 = undefined;

    const max_label = safePrint(&buf, "{d:>2}. {s}", .{ 20, "X" ** (TrackList.TrackNameSize - 1) });
    var max_label_width: f64 = undefined;
    var max_label_height: f64 = undefined;
    try imgui.CalcTextSize(.{ ctx, max_label, &max_label_width, &max_label_height, false, -1.0 });

    // Get starting X position
    const start_x = (try imgui.GetCursorPosX(.{ctx}));
    const second_column_x = start_x + max_label_width + 20; // 20px spacing

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    const page_text = safePrint(&buf, "Page {d}", .{state.fx_ctrl.current_page + 1});
    try imgui.Text(.{ ctx, page_text });
    try imgui.SetCursorPosY(.{ ctx, try imgui.GetCursorPosY(.{ctx}) + 10 });

    // First column (tracks 1-10)
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        for (state.fx_ctrl.track_list.track_names[0..10], 0..) |tr, i| {
            var name: [TrackList.TrackNameSize:0]u8 = undefined;
            name[0] = '\x00';
            var is_selected = false;
            var tr_id: ?c_int = null;
            if (i < state.fx_ctrl.track_list.name_count) {
                name = tr.name;
                tr_id = tr.id;
                is_selected = state.selectedTracks.contains(@intCast(tr_id.?));
            }

            // Special handling for modifier keys
            if (modifier_active and i < 5) {
                const label = safePrint(&buf, "{d:>2}. {s}", .{
                    i + 1,
                    switch (i) {
                        0 => "Input Load",
                        1 => "Gate Load",
                        2 => "EQ Load",
                        3 => "Comp Load",
                        4 => "Output Load",
                        else => unreachable,
                    },
                });

                if (try imgui.Selectable(.{ ctx, label })) {
                    action = .{ .open_module_browser = switch (i) {
                        0 => .INPUT,
                        1 => .GATE,
                        2 => .EQ,
                        3 => .COMP,
                        4 => .OUTPT,
                        else => unreachable,
                    } };
                }
                continue;
            } else {
                // Normal track selection handling
                if (is_selected) {
                    const text_color = try imgui.GetStyleColor(.{ ctx, imgui.Col_TextSelectedBg });
                    try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, text_color });
                }
                defer if (is_selected) imgui.PopStyleColor(.{ ctx, 1 }) catch {};

                const label = safePrint(&buf, "{d:>2}. {s}{s}", .{ i + 1, if (i + 1 > 10) " " else "", name });

                if (try imgui.Selectable(.{ ctx, label })) {
                    if (tr_id) |trid| {
                        action = .{ .select_track = trid };
                    }
                }
            }
        }
    }

    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, second_column_x });

    // Second column (tracks 11-20)
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};
        for (state.fx_ctrl.track_list.track_names[10..], 10..) |tr, i| {
            var name: [TrackList.TrackNameSize:0]u8 = undefined;
            name[0] = '\x00';
            var is_selected = false;
            var tr_id: ?c_int = null;
            if (i < state.fx_ctrl.track_list.name_count) {
                name = tr.name;
                tr_id = tr.id;
                is_selected = state.selectedTracks.contains(@intCast(tr_id.?));
            }

            try imgui.PushItemWidth(.{ ctx, max_label_width });
            defer imgui.PopItemWidth(.{ctx}) catch {};
            // Special handling for settings (i == 19)
            if (modifier_active and i == 19) {
                const label = safePrint(&buf, "{d:>2}. Settings", .{i + 1});
                if (try imgui.Selectable(.{ ctx, label })) {
                    action = .{ .open_settings = {} };
                }
                continue;
            } else {

                // Normal track selection handling
                if (is_selected) {
                    const text_color = try imgui.GetStyleColor(.{ ctx, imgui.Col_TextSelectedBg });
                    try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, text_color });
                }
                defer if (is_selected) imgui.PopStyleColor(.{ ctx, 1 }) catch {};

                const label = safePrint(&buf, "{d:>2}. {s}{s}", .{ i + 1, if (i + 1 > 10) " " else "", name });

                if (try imgui.Selectable(.{ ctx, label })) {
                    if (tr_id) |trid| {
                        action = .{ .select_track = trid };
                    }
                }
            }
        }
    }

    return action;
}
