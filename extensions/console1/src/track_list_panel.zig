const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Preferences = @import("settings.zig");
const globals = @import("globals.zig");
const statemachine = @import("statemachine.zig");
const ModulesList = statemachine.ModulesList;
const styles = @import("styles.zig");
const State = @import("statemachine.zig").State;
const TrackList = @import("fx_ctrl_state.zig").TrackList;
const PushWindowStyle = styles.PushStyle;
const safePrint = @import("debug_panel.zig").safePrint;
const c1 = @import("c1.zig");

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

pub fn drawTrackListTwoColumns(ctx: imgui.ContextPtr, state: *State) !?c1.CCs {
    const mode = state.current_mode;
    const PopStyle = try styles.PushStyle(ctx, .rack);
    defer PopStyle(ctx) catch {};

    var rv: ?c1.CCs = null;
    var buf: [TrackList.TrackNameSize + 4:0]u8 = undefined;

    const max_label = safePrint(&buf, "{d:>2}. {s}", .{ 20, "X" ** (TrackList.TrackNameSize - 1) });
    var max_label_width: f64 = undefined;
    var max_label_height: f64 = undefined;
    try imgui.CalcTextSize(.{ ctx, max_label, &max_label_width, &max_label_height, false, -1.0 });

    // Get starting X position
    const start_x = try imgui.GetCursorPosX(.{ctx});
    const second_column_x = start_x + max_label_width + 20; // 20px spacing

    // Get frame padding for accurate selectable width
    var frame_padding_x: f64 = undefined;
    var frame_padding_y: f64 = undefined;
    try imgui.GetStyleVar(.{ ctx, imgui.StyleVar_FramePadding, &frame_padding_x, &frame_padding_y });
    const selectable_width = max_label_width + (frame_padding_x * 2);

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    const page_text = safePrint(&buf, "Page {d}", .{state.fx_ctrl.current_page + 1});
    try imgui.Text(.{ ctx, page_text });
    try imgui.SetCursorPosY(.{ ctx, try imgui.GetCursorPosY(.{ctx}) + 10 });

    // First column (tracks 1-10)
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        const first_column_ccs = [_]c1.CCs{
            .Tr_tr1, .Tr_tr2, .Tr_tr3, .Tr_tr4, .Tr_tr5,
            .Tr_tr6, .Tr_tr7, .Tr_tr8, .Tr_tr9, .Tr_tr10,
        };
        for (first_column_ccs, 0..) |cc, i| {
            switch (mode) {
                .fx_sel, .transport => {
                    const label = safePrint(&buf, "{d:>2}. {s}", .{ i + 1, cc.getLabel(mode) });

                    if (try imgui.Selectable(.{ ctx, label, null, null, selectable_width })) {
                        rv = cc;
                    }
                },
                .fx_ctrl => {
                    var name: [TrackList.TrackNameSize:0]u8 = undefined;
                    name[0] = '\x00';
                    var tr_id: ?c_int = null;

                    if (i < state.fx_ctrl.track_list.name_count) {
                        name = state.fx_ctrl.track_list.track_names[i].name;
                        tr_id = state.fx_ctrl.track_list.track_names[i].id;
                        const is_selected = state.selectedTracks.contains(@intCast(tr_id.?));

                        if (is_selected) {
                            const text_color = try imgui.GetStyleColor(.{ ctx, imgui.Col_TextSelectedBg });
                            try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, text_color });
                        }
                        defer if (is_selected) imgui.PopStyleColor(.{ ctx, 1 }) catch {};
                    }

                    const label = safePrint(&buf, "{d:>2}. {s}", .{ i + 1, name });

                    if (try imgui.Selectable(.{ ctx, label, null, null, selectable_width })) {
                        rv = cc;
                    }
                },
                else => {},
            }
        }
    }

    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, second_column_x });

    // Second column (tracks 11-20)
    {
        try imgui.BeginGroup(.{ctx});
        defer imgui.EndGroup(.{ctx}) catch {};

        const second_column_ccs = [_]c1.CCs{
            .Tr_tr11, .Tr_tr12, .Tr_tr13, .Tr_tr14, .Tr_tr15,
            .Tr_tr16, .Tr_tr17, .Tr_tr18, .Tr_tr19, .Tr_tr20,
        };

        for (second_column_ccs, 10..) |cc, i| {
            switch (mode) {
                .fx_sel, .transport => {
                    const label = safePrint(&buf, "{d:>2}. {s}", .{ i + 1, cc.getLabel(mode) });

                    if (try imgui.Selectable(.{ ctx, label, null, null, selectable_width })) {
                        rv = cc;
                    }
                },
                .fx_ctrl => {
                    var name: [TrackList.TrackNameSize:0]u8 = undefined;
                    name[0] = '\x00';
                    var tr_id: ?c_int = null;

                    if (i < state.fx_ctrl.track_list.name_count) {
                        name = state.fx_ctrl.track_list.track_names[i].name;
                        tr_id = state.fx_ctrl.track_list.track_names[i].id;
                        const is_selected = state.selectedTracks.contains(@intCast(tr_id.?));

                        if (is_selected) {
                            const text_color = try imgui.GetStyleColor(.{ ctx, imgui.Col_TextSelectedBg });
                            try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, text_color });
                        }
                        defer if (is_selected) imgui.PopStyleColor(.{ ctx, 1 }) catch {};
                    }

                    const label = safePrint(&buf, "{d:>2}. {s}", .{ i + 1, name });

                    if (try imgui.Selectable(.{ ctx, label, null, null, selectable_width })) {
                        rv = cc;
                    }
                },
                else => {},
            }
        }
    }

    return rv;
}
