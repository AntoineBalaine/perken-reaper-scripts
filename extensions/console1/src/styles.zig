const std = @import("std");
const reaper = @import("reaper.zig").reaper;
const imgui = @import("reaper_imgui.zig");
const Theme = @import("theme/Theme.zig");
const Palette = @import("components/Palette.zig").Palette;
const Content = struct {
    rackWindowLabel: [:0]const u8 = "Rack Style Configurations",
    mainWindowLabel: [:0]const u8 = "Window Style Configurations",
    trackChannels: [:0]const u8 = "sizes",
    containerChannels: [:0]const u8 = "colors",
};
const content = Content{};

const WinStyle = enum { rack, main };

const MAXCHAN: f64 = 128;
const WIDTH_MIN: f64 = 150;
const HEIGHT_MIN: f64 = 150;
const WIDTH_MAX: f64 = 800;
const HEIGHT_MAX: f64 = 400;
pub var rack_style_open: bool = false;

pub fn toggle_rack_style_win() !void {
    rack_style_open = !rack_style_open;
}

pub var main_style_open: bool = false;
pub fn toggle_main_style_win() !void {
    main_style_open = !main_style_open;
}

fn isColor(field: [:0]const u8) bool {
    return field.len >= 4 and std.mem.eql(u8, field[0..4], "Col_");
}

fn isStyleVar(field: [:0]const u8) bool {
    return field.len >= 9 and std.mem.eql(u8, field[0..9], "StyleVar_");
}

fn includeField(field: [:0]const u8) bool {
    return isColor(field) or isStyleVar(field);
}

pub const XYStruct = struct { x: f64, y: f64 };

pub fn usestruct() type {
    const stylevarEnumArr = std.EnumArray(StyleVarsEnum, XYStruct);
    const style_var_field = std.builtin.Type.StructField{
        .name = "style_vars",
        .type = stylevarEnumArr,
        .is_comptime = false,
        .alignment = @alignOf(stylevarEnumArr),
        .default_value = null,
    };

    const colorEnumArr = std.EnumArray(ColorsEnum, c_int);

    const color_field = std.builtin.Type.StructField{
        .name = "colors",
        .type = colorEnumArr,
        .is_comptime = false,
        .alignment = @alignOf(colorEnumArr),
        .default_value = null,
    };
    return @Type(.{ .Struct = .{
        .layout = .auto,
        .fields = &[2]std.builtin.Type.StructField{ style_var_field, color_field },
        .decls = &[_]std.builtin.Type.Declaration{},
        .is_tuple = false,
    } });
}

pub fn createstruct() struct { stylevars_enum: type, colors_enum: type } {
    var style_var_count = 0;
    var color_count = 0;
    @setEvalBranchQuota(10000);
    inline for (@typeInfo(imgui).Struct.decls) |field| {
        if (isStyleVar(field.name)) {
            style_var_count += 1;
        } else if (isColor(field.name)) {
            color_count += 1;
        }
    }

    var style_var_enum_fields: [style_var_count]std.builtin.Type.EnumField = undefined;
    var color_enum_fields: [color_count]std.builtin.Type.EnumField = undefined;

    var style_var_fields: [style_var_count]std.builtin.Type.StructField = undefined;
    var color_fields: [color_count]std.builtin.Type.StructField = undefined;
    var style_var_idx = -1;
    var color_idx = -1;
    for (@typeInfo(imgui).Struct.decls) |decl| {
        const tag_name = decl.name;
        if (isStyleVar(tag_name)) {
            const m_struct = std.builtin.Type.StructField{
                .name = tag_name,
                .type = XYStruct,
                .is_comptime = false,
                .alignment = @alignOf(XYStruct),
                .default_value = null,
            };
            style_var_idx += 1;
            style_var_fields[style_var_idx] = m_struct;
            style_var_enum_fields[style_var_idx] = .{
                .name = tag_name,
                .value = style_var_idx,
            };
        } else if (isColor(tag_name)) {
            const m_struct = std.builtin.Type.StructField{
                .name = tag_name,
                .type = c_int,
                .is_comptime = false,
                .alignment = @alignOf(c_int),
                .default_value = null,
            };
            color_idx += 1;
            color_fields[color_idx] = m_struct;
            color_enum_fields[color_idx] = .{
                .name = tag_name,
                .value = color_idx,
            };
        }
    }

    const stylevars_enum = @Type(.{ .Enum = .{
        .tag_type = i16,
        .fields = style_var_enum_fields[0..],
        .decls = &[_]std.builtin.Type.Declaration{},
        .is_exhaustive = true,
    } });
    const colors_enum = @Type(.{ .Enum = .{
        .tag_type = i16,
        .fields = color_enum_fields[0..],
        .decls = &[_]std.builtin.Type.Declaration{},
        .is_exhaustive = true,
    } });
    return .{ .stylevars_enum = stylevars_enum, .colors_enum = colors_enum };
}
const T = createstruct();
const StyleVarsEnum = T.stylevars_enum;
const ColorsEnum = T.colors_enum;

/// contains style_vars and colors of imgui
pub const StyleStruct = usestruct();

pub fn getStyleData(ctx: imgui.ContextPtr, stylesData: *StyleStruct) !void {
    inline for (@typeInfo(StyleVarsEnum).Enum.fields) |field| {
        const xy = stylesData.style_vars.getPtr(@enumFromInt(field.value));
        const imguiStyleVar = @field(imgui, field.name);
        try imgui.GetStyleVar(.{ ctx, imguiStyleVar, &@field(xy.*, "x"), &@field(xy.*, "y") });
    }
    inline for (@typeInfo(ColorsEnum).Enum.fields) |field| {
        const imguiColor = @field(imgui, field.name);
        const val = try imgui.GetStyleColor(.{ ctx, imguiColor });
        stylesData.colors.getPtr(@enumFromInt(field.value)).* = val;
    }
}

pub var RackStyle: StyleStruct = undefined;
var RackStyleBkp: StyleStruct = undefined;
pub var MainWinStyle: StyleStruct = undefined;
var MainWinStyleBkp: StyleStruct = undefined;
var has_been_init: bool = false;
pub fn init(ctx: imgui.ContextPtr) !void {
    if (has_been_init) {
        return;
    }
    RackStyle = std.mem.zeroes(StyleStruct);
    try getStyleData(ctx, &RackStyle);
    MainWinStyle = RackStyle; // copy
    try loadStyle(&RackStyle, RACK_STYLEVARS, RACK_COLORS);
    try loadStyle(&MainWinStyle, MAIN_WIN_STYLEVARS, MAIN_WIN_COLORS);
    RackStyleBkp = RackStyle; // make a copy
    MainWinStyleBkp = MainWinStyle; // make a copy
    has_been_init = true;
}

pub fn StyleEditor(ctx: imgui.ContextPtr, win: WinStyle) !void {
    var is_open = switch (win) {
        .rack => &rack_style_open,
        .main => &main_style_open,
    };
    _ = &is_open;
    std.debug.assert(is_open.*);
    const PopStyle = try PushStyle(ctx, .main);
    defer PopStyle(ctx) catch {};
    try imgui.SetNextWindowSizeConstraints(.{ ctx, WIDTH_MIN, HEIGHT_MIN, WIDTH_MAX, HEIGHT_MAX });

    const flags = imgui.WindowFlags_TopMost + imgui.WindowFlags_NoCollapse + imgui.WindowFlags_AlwaysAutoResize;
    if (try imgui.Begin(.{ ctx, switch (win) {
        .rack => content.rackWindowLabel,
        .main => content.mainWindowLabel,
    }, is_open, flags })) {
        defer imgui.End(.{ctx}) catch {};
        try ShowStyleEditor(ctx, win);
    }
}

fn slider(comptime variant: std.meta.FieldEnum(StyleStruct), ctx: imgui.ContextPtr, style_struct: *StyleStruct, comptime varname: [:0]const u8, min: f64, max: f64, format: [:0]const u8) !void {
    switch (variant) {
        .style_vars => {
            var style_vars = &@field(style_struct, "style_vars");
            _ = &style_vars;
            const propname = "StyleVar_" ++ varname;
            var xy = style_vars.getPtr(std.meta.stringToEnum(StyleVarsEnum, propname).?);
            _ = &xy;
            var x = &@field(xy.*, "x");
            _ = &x;
            var y = &@field(xy.*, "y");
            _ = &y;
            _ = try imgui.SliderDouble2(.{ ctx, varname, x, y, min, max, format });
        },
        .colors => {
            var colors = &@field(style_struct, "colors");

            _ = &colors;
            const propname = "Col_" ++ varname;
            var color = colors.getPtr(std.meta.stringToEnum(ColorsEnum, propname).?);
            _ = &color;
            try imgui.SliderInt(.{ ctx, varname, color, min, max, format });
        },
    }
}

fn ShowStyleEditor(ctx: imgui.ContextPtr, window: WinStyle) !void {
    var style_struct = switch (window) {
        .rack => &RackStyle,
        .main => &MainWinStyle,
    };
    _ = &style_struct;
    if (try imgui.BeginTabBar(.{ ctx, "##tabs", imgui.TabBarFlags_None })) {
        defer imgui.EndTabBar(.{ctx}) catch {};
        if (try imgui.BeginTabItem(.{ ctx, "Sizes" })) {
            defer imgui.EndTabItem(.{ctx}) catch {};

            try imgui.SeparatorText(.{ ctx, "Main" });

            try slider(.style_vars, ctx, style_struct, "WindowPadding", 0.0, 20.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "FramePadding", 0.0, 20.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "ItemSpacing", 0.0, 20.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "ItemInnerSpacing", 0.0, 20.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "IndentSpacing", 0.0, 30.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "ScrollbarSize", 1.0, 20.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "GrabMinSize", 1.0, 20.0, "%.0f");

            try imgui.SeparatorText(.{ ctx, "Borders" });
            try slider(.style_vars, ctx, style_struct, "WindowBorderSize", 0.0, 1.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "ChildBorderSize", 0.0, 1.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "PopupBorderSize", 0.0, 1.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "FrameBorderSize", 0.0, 1.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "TabBorderSize", 0.0, 1.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "TabBarBorderSize", 0.0, 2.0, "%.0f");
            try imgui.SameLine(.{ctx});
            try HelpMarker(ctx, "Overline is only drawn over the selected tab when imguiTabBarFlags_DrawSelectedOverline is set.");

            try imgui.SeparatorText(.{ ctx, "Rounding" });
            try slider(.style_vars, ctx, style_struct, "WindowRounding", 0.0, 12.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "ChildRounding", 0.0, 12.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "FrameRounding", 0.0, 12.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "PopupRounding", 0.0, 12.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "ScrollbarRounding", 0.0, 12.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "GrabRounding", 0.0, 12.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "TabRounding", 0.0, 12.0, "%.0f");

            try imgui.SeparatorText(.{ ctx, "Tables" });
            try slider(.style_vars, ctx, style_struct, "CellPadding", 0.0, 20.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "TableAngledHeadersAngle", -50.0, 50.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "TableAngledHeadersTextAlign", 0.0, 1.0, "%.2f");

            try imgui.SeparatorText(.{ ctx, "Widgets" });
            try slider(.style_vars, ctx, style_struct, "WindowTitleAlign", 0.0, 1.0, "%.2f");
            try slider(.style_vars, ctx, style_struct, "ButtonTextAlign", 0.0, 1.0, "%.2f");
            try imgui.SameLine(.{ctx});
            try HelpMarker(ctx, "Alignment applies when a button is larger than its text content.");
            try slider(.style_vars, ctx, style_struct, "SelectableTextAlign", 0.0, 1.0, "%.2f");
            try imgui.SameLine(.{ctx});
            try HelpMarker(ctx, "Alignment applies when a selectable is larger than its text content.");
            try slider(.style_vars, ctx, style_struct, "SeparatorTextBorderSize", 0.0, 10.0, "%.0f");
            try slider(.style_vars, ctx, style_struct, "SeparatorTextAlign", 0.0, 1.0, "%.2f");
            try slider(.style_vars, ctx, style_struct, "SeparatorTextPadding", 0.0, 40.0, "%.0f");
        }

        if (try imgui.BeginTabItem(.{ ctx, "Colors" })) {
            @setEvalBranchQuota(10_000);
            defer imgui.EndTabItem(.{ctx}) catch {};

            {
                try imgui.SetNextWindowSizeConstraints(.{ ctx, @as(f64, @floatCast(0.0)), try imgui.GetTextLineHeightWithSpacing(.{ctx}) * 10, WIDTH_MAX, HEIGHT_MAX });
                if (try imgui.BeginChild(.{ ctx, "##colors", 0, 0, imgui.WindowFlags_None })) {
                    defer imgui.EndChild(.{
                        ctx,
                    }) catch {};
                    var colors = &@field(style_struct, "colors");
                    _ = &colors;

                    inline for (@typeInfo(ColorsEnum).Enum.fields) |field| {
                        const name = field.name;
                        const val = colors.getPtr(@enumFromInt(field.value));
                        _ = try Palette(ctx, val, name);
                        try imgui.SameLine(.{ctx});

                        {
                            try imgui.PushItemWidth(.{ ctx, 100, 100 });
                            defer imgui.PopItemWidth(.{ctx}) catch {};
                            try imgui.Text(.{ ctx, field.name, 100, 100 });
                        }
                    }
                }
            }
        }
    }
}

const VEC = std.StaticStringMap(void).initComptime(.{
    .{ "ButtonTextAlign", {} },
    .{ "CellPadding", {} },
    .{ "FramePadding", {} },
    .{ "ItemInnerSpacing", {} },
    .{ "ItemSpacing", {} },
    .{ "SelectableTextAlign", {} },
    .{ "SeparatorTextAlign", {} },
    .{ "SeparatorTextPadding", {} },
    .{ "TableAngledHeadersTextAlign", {} },
    .{ "WindowMinSize", {} },
    .{ "WindowPadding", {} },
    .{ "WindowTitleAlign", {} },
});

const MAIN_WIN_STYLEVARS = std.StaticStringMap(XYStruct).initComptime(.{
    .{ "FrameBorderSize", .{ .x = 1, .y = 0 } },
});
const MAIN_WIN_COLORS = std.StaticStringMap([:0]const u8).initComptime(.{
    .{ "CheckMark", "genlist_selbg" },
    .{ "WindowBg", "col_main_bg" },
    .{ "ChildBg", "genlist_bg" },
    .{ "Text", "genlist_fg" },
    .{ "Tab", "genlist_seliabg" },
    .{ "PopupBg", "col_main_bg" },
    .{ "FrameBg", "genlist_seliabg" },
    .{ "Button", "genlist_seliabg" },
    .{ "Tab", "genlist_selbg" },
    .{ "TitleBg", "col_main_bg" },
    .{ "TitleBgActive", "genlist_bg" },
    .{ "TabHovered", "genlist_selbg" },
    .{ "TabSelected", "genlist_selfg" },
    .{ "TabSelectedOverline", "genlist_selfg" },
});

const RACK_STYLEVARS = std.StaticStringMap(XYStruct).initComptime(.{
    .{ "ChildRounding", .{ .x = 4, .y = 0 } },
    .{ "FrameBorderSize", .{ .x = 1, .y = 0 } },
    .{ "FrameRounding", .{ .x = 4, .y = 0 } },
    .{ "ItemSpacing", .{ .x = 4, .y = 2 } },
    .{ "WindowPadding", .{ .x = 4, .y = 4 } },
});
const RACK_COLORS = std.StaticStringMap([:0]const u8).initComptime(.{
    .{ "Border", "selcol_tr2_bg" }, // same as text, alternatively use selcol_tr2_bg
    .{ "Button", "col_main_bg2" },
    .{ "ButtonActive", "midi_endpt" },
    .{ "ButtonHovered", "col_env5" },
    .{ "CheckMark", "col_seltrack" }, // same as text
    .{ "DragDropTarget", "col_main_resize2" },
    .{ "FrameBg", "col_main_bg2" },
    .{ "FrameBgActive", "midi_endpt" },
    .{ "FrameBgHovered", "col_env5" },
    .{ "SliderGrab", "col_cursor" },
    .{ "SliderGrabActive", "col_cursor2" },
    .{ "Tab", "arrange_vgrid" },
    .{ "TabActive", "auto_item_unsel" },
    .{ "TabHovered", "genlist_selbg" },
    .{ "TabSelected", "genlist_selfg" },
    .{ "TabSelectedOverline", "genlist_selfg" },
    .{ "Text", "col_seltrack" }, // same as checkmark
    .{ "WindowBg", "col_main_bg2" },
});

pub fn loadStyle(stylesData: *StyleStruct, comptime stylevars_map: std.StaticStringMap(XYStruct), comptime colors_map: std.StaticStringMap([:0]const u8)) !void {
    // push theme colors into the styleStruct
    inline for (@typeInfo(StyleVarsEnum).Enum.fields) |field| {
        const xy = stylesData.style_vars.getPtr(@enumFromInt(field.value));
        const val = stylevars_map.get(field.name[9..]);
        if (val) |styleVarVal| {
            xy.x = styleVarVal.x;
            xy.y = styleVarVal.y;
        }
    }
    const rColorsEnum = std.meta.FieldEnum(Theme.ThemeTypes.ColorTable);
    inline for (@typeInfo(ColorsEnum).Enum.fields) |field| {
        const reaper_theme_col_name = comptime colors_map.get(field.name[4..]);
        if (reaper_theme_col_name) |theme_col| {
            const val = Theme.clrs.get(std.meta.stringToEnum(rColorsEnum, theme_col).?).color;
            stylesData.colors.getPtr(@enumFromInt(field.value)).* = val;
        }
    }
}

pub fn PushStyle(ctx: imgui.ContextPtr, win_style: WinStyle) !*const fn (ctx: imgui.ContextPtr) anyerror!void {
    var style_push_count: u8 = 0;
    var color_push_count: u8 = 0;
    const style = switch (win_style) {
        .rack => RackStyle,
        .main => MainWinStyle,
    };
    try imgui.PushFont(.{ ctx, Theme.fonts.MAIN });
    inline for (@typeInfo(StyleVarsEnum).Enum.fields) |field| {
        const xy = style.style_vars.get(@enumFromInt(field.value));
        const stylevar = @field(imgui, field.name);
        if (VEC.get(field.name[9..])) |_| {
            try imgui.PushStyleVar(.{ ctx, stylevar, xy.x, xy.y });
            style_push_count += 1;
        } else {
            try imgui.PushStyleVar(.{ ctx, stylevar, xy.x });
            style_push_count += 1;
        }
    }
    std.debug.assert(@typeInfo(StyleVarsEnum).Enum.fields.len == style_push_count);

    inline for (@typeInfo(ColorsEnum).Enum.fields) |field| {
        const stylevar = @field(imgui, field.name);
        const color = style.colors.get(@enumFromInt(field.value));
        try imgui.PushStyleColor(.{ ctx, stylevar, color });
        color_push_count += 1;
    }
    std.debug.assert(@typeInfo(ColorsEnum).Enum.fields.len == color_push_count);

    return switch (win_style) {
        .rack => struct {
            fn pop(cntx: imgui.ContextPtr) !void {
                try imgui.PopFont(.{cntx});
                try imgui.PopStyleVar(.{ cntx, @typeInfo(StyleVarsEnum).Enum.fields.len });
                try imgui.PopStyleColor(.{ cntx, @typeInfo(ColorsEnum).Enum.fields.len });
            }
        }.pop,
        .main => struct {
            fn pop(cntx: imgui.ContextPtr) !void {
                try imgui.PopFont(.{cntx});
                try imgui.PopStyleVar(.{ cntx, @typeInfo(StyleVarsEnum).Enum.fields.len });
                try imgui.PopStyleColor(.{ cntx, @typeInfo(ColorsEnum).Enum.fields.len });
            }
        }.pop,
    };
}

// Helper to display a little (?) mark which shows a tooltip when hovered.
// In your own code you may want to display an actual icon if you are using a merged icon fonts (see docs/FONTS.md)
pub fn HelpMarker(ctx: imgui.ContextPtr, desc: [:0]const u8) !void {
    try imgui.TextDisabled(.{ ctx, "(?)" });
    if (try imgui.BeginItemTooltip(.{ctx})) {
        try imgui.PushTextWrapPos(.{ ctx, try imgui.GetFontSize(.{ctx}) * 35.0 });
        try imgui.Text(.{ ctx, desc });
        try imgui.PopTextWrapPos(.{ctx});
        try imgui.EndTooltip(.{ctx});
    }
}
