const imgui = @import("reaper_imgui");
const statemachine = @import("statemachine.zig");
const ModulesList = statemachine.ModulesList;
const styles = @import("styles.zig");
const styles_components = @import("styles_components.zig");
const State = @import("statemachine.zig").State;
const TrackList = @import("fx_ctrl_state.zig").TrackList;
const safePrint = @import("utils").safePrint;
const c1 = @import("c1.zig");
const widgets = @import("components/widgets.zig");
const roundButton = widgets.roundButton;
const vSeparator = widgets.vSeparator;
const section_spacing = @import("styles.zig").section_spacing;
const Translations = @import("translations.zig");
const TranslationStore = Translations.TranslationStore;
const TranslationKey = Translations.TranslationKey;
const tr = @import("translations.zig").tr;
const TrackListPanelAction = union(enum) {
    select_track: c_int,
    open_module_browser: ModulesList,
    open_strip_browser,
    open_settings,
};

pub fn drawTrackList(ctx: imgui.ContextPtr, state: *State, modifier_active: bool, style_manager: *styles.StyleManager, translations: *TranslationStore) !?TrackListPanelAction {
    const PopStyle = try styles_components.PushStyle(ctx, .main, style_manager);
    defer PopStyle(ctx) catch {};

    try imgui.SetNextWindowDockID(.{ ctx, styles.Docker.RIGHT });

    var action: ?TrackListPanelAction = null;

    if (try imgui.Begin(.{ ctx, tr(translations, .track_list_title) })) {
        defer imgui.End(.{ctx}) catch {};

        var buf: [TrackList.TrackNameSize + 4:0]u8 = undefined;

        for (state.fx_ctrl.track_list.track_names, 0..) |track, i| {
            const name = track.name;
            const tr_id = track.id;
            const is_selected = state.selectedTracks.contains(@intCast(tr_id));

            // Special handling for modifier keys
            if (modifier_active and (i < 6 or i == 19)) {
                const label = safePrint(&buf, "{d:>2}. {s}", .{
                    i + 1,
                    switch (i) {
                        0 => tr(translations, .track_list_input_load),
                        1 => tr(translations, .track_list_gate_load),
                        2 => tr(translations, .track_list_eq_load),
                        3 => tr(translations, .track_list_comp_load),
                        4 => tr(translations, .track_list_output_load),
                        5 => "channel strip",
                        19 => tr(translations, .track_list_settings),
                        else => unreachable,
                    },
                });

                if (try imgui.Selectable(.{ ctx, label })) {
                    action = switch (i) {
                        19 => .{ .open_settings = {} },
                        5 => .{ .open_strip_browser = {} },
                        0 => .{ .open_module_browser = .INPUT },
                        1 => .{ .open_module_browser = .GATE },
                        2 => .{ .open_module_browser = .EQ },
                        3 => .{ .open_module_browser = .COMP },
                        4 => .{ .open_module_browser = .OUTPT },
                        else => unreachable,
                    };
                }
                continue;
            }

            // Normal track selection handling
            if (is_selected) {
                const text_color = try imgui.GetStyleColor(.{ ctx, imgui.Col_TextSelectedBg });
                try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, text_color });
            }
            defer if (is_selected) imgui.PopStyleColor(.{ ctx, 1 }) catch {};

            const button_id = safePrint(&buf, "btn_{d}", .{i});
            if (try roundButton(.{ ctx, "", button_id })) {
                action = .{ .select_track = tr_id };
            }

            try imgui.SameLine(.{ctx});

            const label = safePrint(&buf, "{d:>2}. {s}", .{ i + 1, name });

            if (try imgui.Selectable(.{ ctx, label })) {
                action = .{ .select_track = tr_id };
            }
        }
    }

    return action;
}

pub fn drawTrackListTwoColumns(ctx: imgui.ContextPtr, state: *State, style_manager: *styles.StyleManager, translations: *TranslationStore) !?c1.CCs {
    const mode = state.current_mode;
    const PopStyle = try styles_components.PushStyle(ctx, .main, style_manager);
    defer PopStyle(ctx) catch {};

    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });
    // Add vertical separator after Input section
    try vSeparator(.{ ctx, try imgui.GetStyleColor(.{ ctx, imgui.Col_Border }) });

    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });

    var rv: ?c1.CCs = null;
    var buf: [TrackList.TrackNameSize + 4:0]u8 = undefined;

    const widest_name: [TrackList.TrackNameSize - 1]u8 = @splat('X');
    const max_label = safePrint(&buf, "{d:>2}. {s}", .{ 20, &widest_name });
    var max_label_width: f64 = undefined;
    var max_label_height: f64 = undefined;
    try imgui.CalcTextSize(.{ ctx, max_label, &max_label_width, &max_label_height, false, -1.0 });

    // Get starting X position
    const start_x = try imgui.GetCursorPosX(.{ctx});
    const second_column_x = start_x + max_label_width + 20 + 10; // 20px spacing + 10px for next column’s buttons

    // Get frame padding for accurate selectable width
    var frame_padding_x: f64 = undefined;
    var frame_padding_y: f64 = undefined;
    try imgui.GetStyleVar(.{ ctx, imgui.StyleVar_FramePadding, &frame_padding_x, &frame_padding_y });
    const selectable_width = max_label_width + (frame_padding_x * 2);

    try imgui.BeginGroup(.{ctx});
    defer imgui.EndGroup(.{ctx}) catch {};

    const page_text = safePrint(&buf, "{s} {d}", .{ tr(translations, .track_list_page), state.fx_ctrl.current_page + 1 });
    try imgui.Text(.{ ctx, page_text });

    // Add page up/down buttons on the same line as the page indicator
    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + 20 });

    const pg_dn_key: ?TranslationKey = switch (mode) {
        .fx_ctrl => .fx_ctrl_Tr_pg_dn,
        else => null,
    };
    const pg_dn_label_val = if (pg_dn_key) |key| tr(translations, key) else null;
    const pg_dn_label = pg_dn_label_val orelse "-";
    const pg_dn_id = safePrint(&buf, "btn_pg_dn", .{});
    if (try roundButton(.{ ctx, pg_dn_label, pg_dn_id, null, 5.0, .right, pg_dn_label_val == null })) {
        rv = .Tr_pg_dn;
    }

    try imgui.SameLine(.{ctx});
    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + 10 });

    const pg_up_key: ?TranslationKey = switch (mode) {
        .fx_ctrl => .fx_ctrl_Tr_pg_up,
        else => null,
    };
    const pg_up_label_val = if (pg_up_key) |key| tr(translations, key) else null;
    const pg_up_label = pg_up_label_val orelse "-";
    const pg_up_id = safePrint(&buf, "btn_pg_up", .{});
    if (try roundButton(.{ ctx, pg_up_label, pg_up_id, null, 5.0, .right, pg_up_label_val == null })) {
        rv = .Tr_pg_up;
    }
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
                    const button_id = safePrint(&buf, "btn_col1_{d}", .{i});
                    if (try roundButton(.{ ctx, "", button_id })) {
                        rv = cc;
                    }

                    try imgui.SameLine(.{ctx});

                    const cc_key: ?TranslationKey = switch (mode) {
                        .fx_sel => switch (cc) {
                            .Tr_tr1 => .fx_sel_Tr_tr1,
                            .Tr_tr2 => .fx_sel_Tr_tr2,
                            .Tr_tr3 => .fx_sel_Tr_tr3,
                            .Tr_tr4 => .fx_sel_Tr_tr4,
                            .Tr_tr5 => .fx_sel_Tr_tr5,
                            .Tr_tr6 => .fx_sel_Tr_tr6,
                            else => null,
                        },
                        .transport => switch (cc) {
                            .Tr_tr1 => .trsprt_Tr_tr1,
                            .Tr_tr2 => .trsprt_Tr_tr2,
                            .Tr_tr3 => .trsprt_Tr_tr3,
                            .Tr_tr4 => .trsprt_Tr_tr4,
                            .Tr_tr5 => .trsprt_Tr_tr5,
                            .Tr_tr6 => .trsprt_Tr_tr6,
                            else => null,
                        },
                        else => null,
                    };
                    const cc_label = if (cc_key) |key| tr(translations, key) else null;
                    const cc_display_label: [:0]const u8 = cc_label orelse "-";
                    const label = safePrint(&buf, "{d:>2}. {s}", .{ i + 1, cc_display_label });

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

                    const button_id = safePrint(&buf, "btn_col1_fx_{d}", .{i});
                    if (try roundButton(.{ ctx, "", button_id })) {
                        rv = cc;
                    }

                    try imgui.SameLine(.{ctx});

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
                    const button_id = safePrint(&buf, "btn_col2_{d}", .{i});
                    if (try roundButton(.{ ctx, "", button_id })) {
                        rv = cc;
                    }

                    try imgui.SameLine(.{ctx});

                    const cc_key: ?TranslationKey = switch (mode) {
                        .transport => switch (cc) {
                            .Tr_tr11 => .trsprt_Tr_tr11,
                            .Tr_tr12 => .trsprt_Tr_tr12,
                            .Tr_tr13 => .trsprt_Tr_tr13,
                            .Tr_tr14 => .trsprt_Tr_tr14,
                            .Tr_tr15 => .trsprt_Tr_tr15,
                            .Tr_tr17 => .trsprt_Tr_tr17,
                            .Tr_tr18 => .trsprt_Tr_tr18,
                            .Tr_tr19 => .trsprt_Tr_tr19,
                            .Tr_tr20 => .trsprt_Tr_tr20,
                            else => null,
                        },
                        else => null,
                    };
                    const cc_label = if (cc_key) |key| tr(translations, key) else null;
                    const cc_display_label: [:0]const u8 = cc_label orelse "-";
                    const label = safePrint(&buf, "{d:>2}. {s}", .{ i + 1, cc_display_label });

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

                    const button_id = safePrint(&buf, "btn_col2_fx_{d}", .{i});
                    if (try roundButton(.{ ctx, "", button_id })) {
                        rv = cc;
                    }

                    try imgui.SameLine(.{ctx});

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
