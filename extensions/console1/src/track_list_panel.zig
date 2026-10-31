const std = @import("std");
const imgui = @import("reaper_imgui");
const knob = @import("knob");
const module_plate = @import("components/module_plate.zig");
const c1_theme = @import("theme/c1_theme.zig");
const statemachine = @import("statemachine.zig");
const ModulesList = statemachine.ModulesList;
const styles = @import("styles.zig");
const styles_components = @import("styles_components.zig");
const State = @import("statemachine.zig").State;
const TrackList = @import("fx_ctrl_state.zig").TrackList;
const safePrint = @import("utils").safePrint;
const substituteFirst = @import("translations.zig").substituteFirst;
const ui_helpers = @import("ui_helpers.zig");
const panel_theme = @import("panel_theme");
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

const row_key_radius = @import("components/button.zig").default_radius;
/// The room that the key takes at the left of a row: the key, its margin and the space before the label.
const row_key_width = row_key_radius * 2 + 8;

/// The color with its alpha (the last byte of 0xRRGGBBAA) replaced.
fn withAlpha(color: c_int, alpha: u32) c_int {
    const bits: u32 = @bitCast(color);
    return @bitCast((bits & 0xFFFFFF00) | alpha);
}

/// The alternative use of a row: a text in its own color, at the right edge of the row. It lies under the name of the track,
/// and over it while shift is held, which is when the row does that use.
const AltText = struct { text: [:0]const u8, color: c_int, on_top: bool };

/// The color that the row shows behind its text: the plate, with the highlight of the row over it. It follows the colors
/// that the row gives its `Selectable`, which are the tint of the track at three opacities.
fn rowBackground(tint: c_int, selected: bool, hovered: bool, held: bool) c_int {
    const alpha: u32 = if (held) 0x50 else if (hovered) 0x26 else if (selected) 0x38 else 0;
    const base: u32 = @bitCast(panel_theme.panel_bg);
    const over: u32 = @bitCast(tint);
    var result: u32 = base & 0xFF;
    inline for ([_]u5{ 24, 16, 8 }) |shift| {
        const below: u32 = (base >> shift) & 0xFF;
        const above: u32 = (over >> shift) & 0xFF;
        result |= ((below * (0xFF - alpha) + above * alpha) / 0xFF) << shift;
    }
    return @bitCast(result);
}

/// A row of the track list: a round key and a label that share one area, so that the key lights up
/// when the mouse is on the label, and sinks when the row is held. Because the key is drawn in the
/// middle of the row's height, it stays level with the text. The key and the label are in the color of the track.
/// Returns true when the row was clicked.
fn trackRow(ctx: imgui.ContextPtr, tag: []const u8, index: usize, label: [:0]const u8, width: ?f64, color: ?c_int, selected: bool, alt: ?AltText) !bool {
    var id_buf: [32:0]u8 = undefined;
    const id = safePrint(&id_buf, "##row_{s}_{d}", .{ tag, index });
    // The highlight of the row is a faint tint of the color of the track, and not the accent of the theme,
    // which hides the label. A track without a color is tinted with a light grey.
    const tint = color orelse @as(c_int, @bitCast(@as(u32, 0xD8D8D8FF)));
    try imgui.PushStyleColor(.{ ctx, imgui.Col_Header, withAlpha(tint, 0x38) });
    try imgui.PushStyleColor(.{ ctx, imgui.Col_HeaderHovered, withAlpha(tint, 0x26) });
    try imgui.PushStyleColor(.{ ctx, imgui.Col_HeaderActive, withAlpha(tint, 0x50) });
    var shown_selected = selected;
    const clicked = try imgui.Selectable(.{ ctx, id, &shown_selected, null, width });
    try imgui.PopStyleColor(.{ ctx, 3 });
    const hovered = try imgui.IsItemHovered(.{ctx});
    const held = try imgui.IsItemActive(.{ctx});

    var min_x: f64 = undefined;
    var min_y: f64 = undefined;
    var max_x: f64 = undefined;
    var max_y: f64 = undefined;
    try imgui.GetItemRectMin(.{ ctx, &min_x, &min_y });
    try imgui.GetItemRectMax(.{ ctx, &max_x, &max_y });
    var text_w: f64 = undefined;
    var text_h: f64 = undefined;
    try imgui.CalcTextSize(.{ ctx, label, &text_w, &text_h });

    const radius = row_key_radius;
    const center_x = min_x + radius + 2;
    const center_y = (min_y + max_y) / 2;
    const dl = try imgui.GetWindowDrawList(.{ctx});
    try knob.drawRoundKey(dl, center_x, center_y, radius, color orelse -1, .{ .hovered = hovered, .active = held });
    // The label is cut at the edge of the row, so that a long name does not run into the next column.
    try imgui.PushClipRect(.{ ctx, min_x, min_y, max_x, max_y, true });
    const text_x = center_x + radius + 6;
    const background = rowBackground(tint, shown_selected, hovered, held);
    const name_color = color orelse try imgui.GetStyleColor(.{ ctx, imgui.Col_Text });
    if (alt) |alternative| {
        var alt_w: f64 = undefined;
        var alt_h: f64 = undefined;
        try imgui.CalcTextSize(.{ ctx, alternative.text, &alt_w, &alt_h });
        const alt_x = max_x - alt_w - 6;
        if (alternative.on_top) {
            // The name is drawn first, and the alternative covers what it overlaps with a background of the plate.
            try imgui.DrawList_AddText(.{ dl, text_x, center_y - text_h / 2, name_color, label });
            try imgui.DrawList_AddRectFilled(.{ dl, alt_x - 4, min_y + 1, max_x, max_y - 1, background, 0 });
            try imgui.DrawList_AddText(.{ dl, alt_x, center_y - alt_h / 2, alternative.color, alternative.text });
        } else {
            // The alternative is drawn first, so that it lies under the name, which has a background of the plate that
            // hides the part of the alternative that it overlaps.
            try imgui.DrawList_AddText(.{ dl, alt_x, center_y - alt_h / 2, alternative.color, alternative.text });
            try imgui.DrawList_AddRectFilled(.{ dl, text_x - 2, min_y + 1, text_x + text_w + 4, max_y - 1, background, 0 });
            try imgui.DrawList_AddText(.{ dl, text_x, center_y - text_h / 2, name_color, label });
        }
    } else {
        try imgui.DrawList_AddText(.{ dl, text_x, center_y - text_h / 2, name_color, label });
    }
    try imgui.PopClipRect(.{ctx});
    return clicked;
}

/// The text of the page. Because the language packs write it as "Page {d}", the number takes the place of the "{d}", and
/// a pack that only says "Page" gets the number after it.
pub fn pageText(buf: [:0]u8, template: [:0]const u8, page: usize) [:0]const u8 {
    const placeholder = "{d}";
    var number_buf: [24]u8 = undefined;
    const number = std.fmt.bufPrint(&number_buf, "{d}", .{page}) catch return template;
    const index = std.mem.indexOf(u8, template, placeholder) orelse return safePrint(buf, "{s} {s}", .{ template, number });
    return safePrint(buf, "{s}{s}{s}", .{ template[0..index], number, template[index + placeholder.len ..] });
}

test "the page number takes the place of the placeholder, or follows a template without one" {
    var buf: [64:0]u8 = undefined;
    try std.testing.expectEqualStrings("Page 3", pageText(&buf, "Page {d}", 3));
    try std.testing.expectEqualStrings("Page 3", pageText(&buf, "Page", 3));
    try std.testing.expectEqualStrings("3rd page", pageText(&buf, "{d}rd page", 3));
}

pub fn drawTrackList(ctx: imgui.ContextPtr, state: *State, modifier_active: bool, style_manager: *styles.StyleManager, translations: *TranslationStore) !?TrackListPanelAction {
    const PopStyle = try styles_components.PushStyle(ctx, .main, style_manager);
    defer PopStyle(ctx) catch {};

    try imgui.SetNextWindowDockID(.{ ctx, styles.Docker.RIGHT, imgui.Cond_FirstUseEver });

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

            const label = safePrint(&buf, "{d:>2}. {s}", .{ i + 1, name });
            if (try trackRow(ctx, "list", i, label, null, if (track.color != 0) track.color else null, is_selected, null)) {
                action = .{ .select_track = tr_id };
            }
        }
    }

    return action;
}

/// What a button of the track list does while shift is held in the fx_ctrl mode, as `shiftFunction` of the MIDI events
/// has it: the browsers of the plugins on the first six rows, and the settings on the last one. The other rows keep
/// their track.
pub fn shiftLabel(cc: c1.CCs, translations: *TranslationStore) ?[:0]const u8 {
    const key: TranslationKey = switch (cc) {
        .Tr_tr1 => .trsprt_Tr_tr6,
        .Tr_tr2 => .trsprt_Tr_tr2,
        .Tr_tr3 => .trsprt_Tr_tr3,
        .Tr_tr4 => .trsprt_Tr_tr4,
        .Tr_tr5 => .trsprt_Tr_tr1,
        .Tr_tr6 => .trsprt_Tr_tr5,
        .Tr_tr20 => .trsprt_Tr_tr20,
        else => return null,
    };
    return tr(translations, key);
}

/// What a button of the track list does in the browser of the plugins: the plugin browser of a module on the first six
/// rows, and the settings on the last one, as the buttons of the controller do there. Unlike the rows of the fx_ctrl mode,
/// they do it without shift.
pub fn browserLabel(cc: c1.CCs, translations: *TranslationStore) ?[:0]const u8 {
    const key: TranslationKey = switch (cc) {
        .Tr_tr1 => .fx_sel_Tr_tr1,
        .Tr_tr2 => .fx_sel_Tr_tr2,
        .Tr_tr3 => .fx_sel_Tr_tr3,
        .Tr_tr4 => .fx_sel_Tr_tr4,
        .Tr_tr5 => .fx_sel_Tr_tr5,
        .Tr_tr6 => .fx_sel_Tr_tr6,
        .Tr_tr20 => .trsprt_Tr_tr20,
        else => return null,
    };
    return tr(translations, key);
}

/// The alternative use that a row shows, in the accent color, at its right edge: the use with shift in the fx_ctrl mode,
/// under the name of the track until shift is held, and the use of the browser in the browser mode, which needs no shift
/// and has no track name to share the row with.
fn altText(mode: statemachine.Mode, cc: c1.CCs, shift_held: bool, translations: *TranslationStore) ?AltText {
    return switch (mode) {
        .fx_ctrl => if (shiftLabel(cc, translations)) |text| .{ .text = text, .color = ui_helpers.altColor(shift_held), .on_top = shift_held } else null,
        .fx_sel => if (browserLabel(cc, translations)) |text| .{ .text = text, .color = ui_helpers.altColor(true), .on_top = true } else null,
        else => null,
    };
}

/// The label of a row of the transport mode that maps a module, which is "Map" and the name of the module. Only a module that
/// has an FX on the track is mapped, so the other rows have none.
fn mapRowLabel(buf: [:0]u8, state: *const State, cc: c1.CCs, translations: *TranslationStore) ?[:0]const u8 {
    const module = statemachine.moduleOfTrackRow(cc) orelse return null;
    if (state.fx_ctrl.track_state.fxIndexOf(module) == null) return null;
    const name = shiftLabel(cc, translations) orelse return null;
    return substituteFirst(buf, tr(translations, .trsprt_map_module), name);
}

pub fn drawTrackListTwoColumns(ctx: imgui.ContextPtr, state: *State, shift_held: bool, style_manager: *styles.StyleManager, translations: *TranslationStore) !?c1.CCs {
    const mode = state.current_mode;
    const PopStyle = try styles_components.PushStyle(ctx, .main, style_manager);
    defer PopStyle(ctx) catch {};

    try imgui.SetCursorPosX(.{ ctx, try imgui.GetCursorPosX(.{ctx}) + section_spacing });

    var rv: ?c1.CCs = null;
    var buf: [TrackList.TrackNameSize + 4:0]u8 = undefined;

    // The width of a row is that of a name of this many letters of average width: a longer name is cut by the row.
    const widest_name: [22]u8 = @splat('n');
    const max_label = safePrint(&buf, "{d:>2}. {s}", .{ 20, &widest_name });
    var max_label_width: f64 = undefined;
    var max_label_height: f64 = undefined;
    try imgui.CalcTextSize(.{ ctx, max_label, &max_label_width, &max_label_height, false, -1.0 });

    // Get frame padding for accurate selectable width
    var frame_padding_x: f64 = undefined;
    var frame_padding_y: f64 = undefined;
    try imgui.GetStyleVar(.{ ctx, imgui.StyleVar_FramePadding, &frame_padding_x, &frame_padding_y });
    const selectable_width = max_label_width + (frame_padding_x * 2) + row_key_width;
    var spacing_x: f64 = undefined;
    var spacing_y: f64 = undefined;
    try imgui.GetStyleVar(.{ ctx, imgui.StyleVar_ItemSpacing, &spacing_x, &spacing_y });

    const pg_dn_key: ?TranslationKey = switch (mode) {
        .fx_ctrl => .fx_ctrl_Tr_pg_dn,
        else => null,
    };
    const pg_dn_label_val = if (pg_dn_key) |key| tr(translations, key) else null;
    const pg_dn_label = pg_dn_label_val orelse "-";
    const pg_up_key: ?TranslationKey = switch (mode) {
        .fx_ctrl => .fx_ctrl_Tr_pg_up,
        else => null,
    };
    const pg_up_label_val = if (pg_up_key) |key| tr(translations, key) else null;
    const pg_up_label = pg_up_label_val orelse "-";
    const page_text = pageText(&buf, tr(translations, .track_list_page), state.fx_ctrl.current_page + 1);

    // The page column is as wide as its widest line: the page number, or a button with its label.
    const button_r = @import("components/button.zig").default_radius;
    var page_w: f64 = 0;
    var line_h: f64 = undefined;
    // The buttons show "-" in the modes that do not change the page, so their width is that of the labels of the
    // mode that does: it must not change when the mode does.
    const pg_dn_widest = tr(translations, .fx_ctrl_Tr_pg_dn);
    const pg_up_widest = tr(translations, .fx_ctrl_Tr_pg_up);
    inline for (.{ "Page 99", pg_dn_widest, pg_up_widest }, 0..) |text, line| {
        var w: f64 = undefined;
        try imgui.CalcTextSize(.{ ctx, @as([:0]const u8, text), &w, &line_h });
        page_w = @max(page_w, if (line == 0) w else button_r * 2 + 4 + w);
    }
    {
        var w: f64 = undefined;
        try imgui.CalcTextSize(.{ ctx, page_text, &w, &line_h });
        page_w = @max(page_w, w);
    }
    const column_gap = 12.0;
    const rows = 10;
    const plate = try module_plate.Plate.begin(ctx, .{
        .slots = &.{},
        .columns = 1,
        .widest_label = "Ag",
        .title = "TRACKS",
        .title_font = c1_theme.fonts.TAB,
        .min_width = page_w + column_gap + selectable_width * 2 + 10,
        .min_content_h = rows * max_label_height + (rows - 1) * spacing_y,
    });

    // The page number, and under it the buttons that change the page, in a small column of their own.
    const page_x = plate.origin.x;
    try imgui.SetCursorScreenPos(.{ ctx, page_x, plate.origin.y });
    try imgui.Text(.{ ctx, page_text });

    const pg_dn_id = safePrint(&buf, "btn_pg_dn", .{});
    try imgui.SetCursorScreenPos(.{ ctx, page_x, plate.origin.y + line_h + 8 });
    if (try roundButton(.{ ctx, pg_dn_label, pg_dn_id, null, null, .right, pg_dn_label_val == null })) {
        rv = .Tr_pg_dn;
    }

    const pg_up_id = safePrint(&buf, "btn_pg_up", .{});
    try imgui.SetCursorScreenPos(.{ ctx, page_x, plate.origin.y + line_h + 8 + button_r * 2 + 12 });
    if (try roundButton(.{ ctx, pg_up_label, pg_up_id, null, null, .right, pg_up_label_val == null })) {
        rv = .Tr_pg_up;
    }

    const first_column_x = page_x + page_w + column_gap;
    const second_column_x = first_column_x + selectable_width + 10;

    try imgui.SetCursorScreenPos(.{ ctx, first_column_x, plate.origin.y });
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
                .transport => {
                    const cc_key: ?TranslationKey = switch (mode) {
                        .transport => null,
                        else => null,
                    };
                    var map_buf: [96:0]u8 = undefined;
                    const cc_label = if (cc_key) |key| tr(translations, key) else mapRowLabel(&map_buf, state, cc, translations);
                    const cc_display_label: [:0]const u8 = cc_label orelse "-";
                    const label = safePrint(&buf, "{d:>2}. {s}", .{ i + 1, cc_display_label });

                    if (try trackRow(ctx, "col", i, label, selectable_width, null, false, null)) {
                        rv = cc;
                    }
                },
                .fx_ctrl, .fx_sel => {
                    var name: [TrackList.TrackNameSize:0]u8 = undefined;
                    name[0] = '\x00';
                    var track_color: ?c_int = null;
                    var is_selected = false;

                    // The browser mode shows the keys of the browser and not the tracks, so its rows have no name.
                    if (mode == .fx_ctrl and i < state.fx_ctrl.track_list.name_count) {
                        name = state.fx_ctrl.track_list.track_names[i].name;
                        const tr_id = state.fx_ctrl.track_list.track_names[i].id;
                        const color = state.fx_ctrl.track_list.track_names[i].color;
                        if (color != 0) track_color = color;
                        is_selected = state.selectedTracks.contains(@intCast(tr_id));
                    }

                    const label = safePrint(&buf, "{d:>2}. {s}", .{ i + 1, name });
                    // A row that has an alternative use always shows it, in the accent: under the name, and over it while
                    // shift is held.
                    const alt = altText(mode, cc, shift_held, translations);

                    if (try trackRow(ctx, "col", i, label, selectable_width, track_color, is_selected, alt)) {
                        rv = cc;
                    }
                },
                else => {},
            }
        }
    }

    try imgui.SetCursorScreenPos(.{ ctx, second_column_x, plate.origin.y });

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
                .transport => {
                    const cc_key: ?TranslationKey = switch (mode) {
                        .transport => switch (cc) {
                            .Tr_tr11 => .trsprt_Tr_tr11,
                            .Tr_tr12 => .trsprt_Tr_tr12,
                            .Tr_tr13 => .trsprt_Tr_tr13,
                            .Tr_tr14 => .trsprt_Tr_tr14,
                            .Tr_tr15 => .trsprt_Tr_tr15,
                            else => null,
                        },
                        else => null,
                    };
                    const cc_label = if (cc_key) |key| tr(translations, key) else null;
                    const cc_display_label: [:0]const u8 = cc_label orelse "-";
                    const label = safePrint(&buf, "{d:>2}. {s}", .{ i + 1, cc_display_label });

                    if (try trackRow(ctx, "col", i, label, selectable_width, null, false, null)) {
                        rv = cc;
                    }
                },
                .fx_ctrl, .fx_sel => {
                    var name: [TrackList.TrackNameSize:0]u8 = undefined;
                    name[0] = '\x00';
                    var track_color: ?c_int = null;
                    var is_selected = false;

                    // The browser mode shows the keys of the browser and not the tracks, so its rows have no name.
                    if (mode == .fx_ctrl and i < state.fx_ctrl.track_list.name_count) {
                        name = state.fx_ctrl.track_list.track_names[i].name;
                        const tr_id = state.fx_ctrl.track_list.track_names[i].id;
                        const color = state.fx_ctrl.track_list.track_names[i].color;
                        if (color != 0) track_color = color;
                        is_selected = state.selectedTracks.contains(@intCast(tr_id));
                    }

                    const label = safePrint(&buf, "{d:>2}. {s}", .{ i + 1, name });
                    // A row that has an alternative use always shows it, in the accent: under the name, and over it while
                    // shift is held.
                    const alt = altText(mode, cc, shift_held, translations);

                    if (try trackRow(ctx, "col", i, label, selectable_width, track_color, is_selected, alt)) {
                        rv = cc;
                    }
                },
                else => {},
            }
        }
    }

    try plate.end(ctx);
    return rv;
}
