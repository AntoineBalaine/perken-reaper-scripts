const std = @import("std");
const imgui = @import("reaper_imgui");
const Theme = @import("theme/ReaperTheme.zig");
const c1_theme = @import("theme/c1_theme.zig");

pub const Docker = struct {
    pub const UNDOCKED: i32 = 0;
    pub const RIGHT: i32 = -2; // Or whichever docker number you want to use
    pub const BOTTOM: i32 = -1;
    // ... other docker positions
};

pub const WinStyle = enum { main, config };

const MAXCHAN: f64 = 128;
pub const WIDTH_MIN: f64 = 150;
pub const HEIGHT_MIN: f64 = 150;
pub const WIDTH_MAX: f64 = 800;
pub const HEIGHT_MAX: f64 = 400;
pub var main_style_open: bool = false;
pub var config_style_open: bool = false;
pub const section_spacing = 10.0;

pub fn isColor(field: [:0]const u8) bool {
    return field.len >= 4 and std.mem.eql(u8, field[0..4], "Col_");
}

pub fn isStyleVar(field: [:0]const u8) bool {
    return field.len >= 9 and std.mem.eql(u8, field[0..9], "StyleVar_");
}

pub fn includeField(field: [:0]const u8) bool {
    return isColor(field) or isStyleVar(field);
}

pub const XYStruct = struct { x: f64, y: f64 };

pub fn usestruct() type {
    const stylevarEnumArr = std.EnumArray(StyleVarsEnum, XYStruct);
    const colorEnumArr = std.EnumArray(ColorsEnum, c_int);
    // Because @Type is gone since Zig 0.16, the struct is reified with @Struct.
    return @Struct(.auto, null, &.{ "style_vars", "colors" }, &.{ stylevarEnumArr, colorEnumArr }, &@splat(.{}));
}

pub fn createstruct() struct { stylevars_enum: type, colors_enum: type } {
    var style_var_count = 0;
    var color_count = 0;
    @setEvalBranchQuota(10000);
    inline for (@typeInfo(imgui).@"struct".decl_names) |field_name| {
        if (isStyleVar(field_name)) {
            style_var_count += 1;
        } else if (isColor(field_name)) {
            color_count += 1;
        }
    }

    var style_var_names: [style_var_count][]const u8 = undefined;
    var style_var_values: [style_var_count]i16 = undefined;
    var color_names: [color_count][]const u8 = undefined;
    var color_values: [color_count]i16 = undefined;
    var style_var_idx = 0;
    var color_idx = 0;
    for (@typeInfo(imgui).@"struct".decl_names) |decl_name| {
        @setEvalBranchQuota(20_000);
        if (isStyleVar(decl_name)) {
            style_var_names[style_var_idx] = decl_name;
            style_var_values[style_var_idx] = style_var_idx;
            style_var_idx += 1;
        } else if (isColor(decl_name)) {
            color_names[color_idx] = decl_name;
            color_values[color_idx] = color_idx;
            color_idx += 1;
        }
    }

    // Because @Type is gone since Zig 0.16, the enums are reified with @Enum.
    const stylevars_enum = @Enum(i16, .exhaustive, &style_var_names, &style_var_values);
    const colors_enum = @Enum(i16, .exhaustive, &color_names, &color_values);
    return .{ .stylevars_enum = stylevars_enum, .colors_enum = colors_enum };
}
const T = createstruct();
pub const StyleVarsEnum = T.stylevars_enum;
pub const ColorsEnum = T.colors_enum;

/// contains style_vars and colors of imgui
pub const StyleStruct = usestruct();

pub fn getStyleData(ctx: imgui.ContextPtr, stylesData: *StyleStruct) !void {
    inline for (@typeInfo(StyleVarsEnum).@"enum".field_names, @typeInfo(StyleVarsEnum).@"enum".field_values) |field_name, field_value| {
        const xy = stylesData.style_vars.getPtr(@fromBackingInt(@intCast(field_value)));
        const imguiStyleVar = @field(imgui, field_name);
        try imgui.GetStyleVar(.{ ctx, imguiStyleVar, &@field(xy.*, "x"), &@field(xy.*, "y") });
    }
    inline for (@typeInfo(ColorsEnum).@"enum".field_names, @typeInfo(ColorsEnum).@"enum".field_values) |field_name, field_value| {
        const imguiColor = @field(imgui, field_name);
        const val = try imgui.GetStyleColor(.{ ctx, imguiColor });
        stylesData.colors.getPtr(@fromBackingInt(@intCast(field_value))).* = val;
    }
}

pub var MainStyle: StyleStruct = undefined;
pub var ConfigStyle: StyleStruct = undefined;
pub const StyleManager = struct {
    MainStyle: *StyleStruct,
    ConfigStyle: *StyleStruct,
    main_style_open: *bool,
    config_style_open: *bool,
};

pub fn init(ctx: imgui.ContextPtr) !void {
    MainStyle = std.mem.zeroes(StyleStruct);
    try getStyleData(ctx, &MainStyle);
    ConfigStyle = MainStyle; // copy
    loadStyleVars(&MainStyle, MAIN_STYLEVARS);
    loadStyleVars(&ConfigStyle, CONFIG_STYLEVARS);
    applyThemeColors(&MainStyle, &c1_theme.theme.main);
    applyThemeColors(&ConfigStyle, &c1_theme.theme.config);
}

pub const VEC = std.StaticStringMap(void).initComptime(.{
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

const CONFIG_STYLEVARS = std.StaticStringMap(XYStruct).initComptime(.{
    .{ "FrameBorderSize", XYStruct{ .x = 1, .y = 0 } },
});
/// Legacy: see MAIN_COLORS comment.
const CONFIG_COLORS = std.StaticStringMap([:0]const u8).initComptime(.{
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

const MAIN_STYLEVARS = std.StaticStringMap(XYStruct).initComptime(.{
    .{ "ChildRounding", XYStruct{ .x = 4, .y = 0 } },
    .{ "FrameBorderSize", XYStruct{ .x = 1, .y = 0 } },
    .{ "FrameRounding", XYStruct{ .x = 4, .y = 0 } },
    .{ "ItemSpacing", XYStruct{ .x = 4, .y = 2 } },
    .{ "WindowPadding", XYStruct{ .x = 4, .y = 4 } },
});
/// Legacy: maps ImGui color names to REAPER theme color names for ReaperTheme.zig's Theme.clrs.
/// Used by loadStyle, which is no longer called from init().
const MAIN_COLORS = std.StaticStringMap([:0]const u8).initComptime(.{
    .{ "Border", "selcol_tr2_bg" },
    .{ "Button", "col_main_bg2" },
    .{ "ButtonActive", "midi_endpt" },
    .{ "ButtonHovered", "col_env5" },
    .{ "CheckMark", "col_seltrack" },
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
    .{ "Text", "col_seltrack" },
    .{ "WindowBg", "col_main_bg2" },
});

fn loadStyleVars(stylesData: *StyleStruct, comptime stylevars_map: std.StaticStringMap(XYStruct)) void {
    inline for (@typeInfo(StyleVarsEnum).@"enum".field_names, @typeInfo(StyleVarsEnum).@"enum".field_values) |field_name, field_value| {
        const xy = stylesData.style_vars.getPtr(@fromBackingInt(@intCast(field_value)));
        const val = stylevars_map.get(field_name[9..]);
        if (val) |styleVarVal| {
            xy.x = styleVarVal.x;
            xy.y = styleVarVal.y;
        }
    }
}

/// Legacy: loads colors from ReaperTheme.zig's Theme.clrs. No longer called from init().
pub fn loadStyle(stylesData: *StyleStruct, comptime stylevars_map: std.StaticStringMap(XYStruct), comptime colors_map: std.StaticStringMap([:0]const u8)) !void {
    loadStyleVars(stylesData, stylevars_map);
    const rColorsEnum = std.meta.FieldEnum(Theme.ThemeTypes.ColorTable);
    inline for (@typeInfo(ColorsEnum).@"enum".field_names, @typeInfo(ColorsEnum).@"enum".field_values) |field_name, field_value| {
        const reaper_theme_col_name = comptime colors_map.get(field_name[4..]);
        if (reaper_theme_col_name) |theme_col| {
            const val = Theme.clrs.get(std.meta.stringToEnum(rColorsEnum, theme_col).?).color;
            stylesData.colors.getPtr(@fromBackingInt(@intCast(field_value))).* = val;
        }
    }
}

/// Apply the theme colors from the c1_theme INI file into the style struct.
pub fn applyThemeColors(stylesData: *StyleStruct, window_colors: *const c1_theme.WindowColors) void {
    const WC = c1_theme.WindowColors;
    @setEvalBranchQuota(10_000);
    inline for (@typeInfo(ColorsEnum).@"enum".field_names, @typeInfo(ColorsEnum).@"enum".field_values) |field_name, field_value| {
        const color_name = field_name[4..];
        if (@hasField(WC, color_name)) {
            const val = @field(window_colors, color_name);
            if (val != 0) {
                stylesData.colors.getPtr(@fromBackingInt(@intCast(field_value))).* = val;
            }
        }
    }
    if (window_colors.ActiveToggle != 0) {
        if (comptime std.meta.stringToEnum(ColorsEnum, "Col_PlotLines")) |idx| {
            stylesData.colors.getPtr(idx).* = window_colors.ActiveToggle;
        }
    }
    if (window_colors.ErrorText != 0) {
        if (comptime std.meta.stringToEnum(ColorsEnum, "Col_PlotHistogram")) |idx| {
            stylesData.colors.getPtr(idx).* = window_colors.ErrorText;
        }
    }
    if (window_colors.KnobBg != 0) {
        if (comptime std.meta.stringToEnum(ColorsEnum, "Col_PlotLinesHovered")) |idx| {
            stylesData.colors.getPtr(idx).* = window_colors.KnobBg;
        }
    }
}

pub fn PushStyle(ctx: imgui.ContextPtr, win_style: WinStyle) !*const fn (ctx: imgui.ContextPtr) anyerror!void {
    var style_push_count: u8 = 0;
    var color_push_count: u8 = 0;
    const style = switch (win_style) {
        .main => MainStyle,
        .config => ConfigStyle,
    };
    try imgui.PushFont(.{ ctx, c1_theme.fonts.MAIN });
    inline for (@typeInfo(StyleVarsEnum).@"enum".field_names, @typeInfo(StyleVarsEnum).@"enum".field_values) |field_name, field_value| {
        const xy = style.style_vars.get(@fromBackingInt(@intCast(field_value)));
        const stylevar = @field(imgui, field_name);
        if (VEC.get(field_name[9..])) |_| {
            try imgui.PushStyleVar(.{ ctx, stylevar, xy.x, xy.y });
            style_push_count += 1;
        } else {
            try imgui.PushStyleVar(.{ ctx, stylevar, xy.x });
            style_push_count += 1;
        }
    }
    std.debug.assert(@typeInfo(StyleVarsEnum).@"enum".field_names.len == style_push_count);

    inline for (@typeInfo(ColorsEnum).@"enum".field_names, @typeInfo(ColorsEnum).@"enum".field_values) |field_name, field_value| {
        const stylevar = @field(imgui, field_name);
        const color = style.colors.get(@fromBackingInt(@intCast(field_value)));
        try imgui.PushStyleColor(.{ ctx, stylevar, color });
        color_push_count += 1;
    }
    std.debug.assert(@typeInfo(ColorsEnum).@"enum".field_names.len == color_push_count);

    return switch (win_style) {
        .main => struct {
            fn pop(cntx: imgui.ContextPtr) !void {
                try imgui.PopFont(.{cntx});
                try imgui.PopStyleVar(.{ cntx, @typeInfo(StyleVarsEnum).@"enum".field_names.len });
                try imgui.PopStyleColor(.{ cntx, @typeInfo(ColorsEnum).@"enum".field_names.len });
            }
        }.pop,
        .config => struct {
            fn pop(cntx: imgui.ContextPtr) !void {
                try imgui.PopFont(.{cntx});
                try imgui.PopStyleVar(.{ cntx, @typeInfo(StyleVarsEnum).@"enum".field_names.len });
                try imgui.PopStyleColor(.{ cntx, @typeInfo(ColorsEnum).@"enum".field_names.len });
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
