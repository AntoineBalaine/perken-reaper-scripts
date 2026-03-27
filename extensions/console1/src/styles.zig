const std = @import("std");
const imgui = @import("reaper_imgui");
const Theme = @import("theme/Theme.zig");
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
    const style_var_field = std.builtin.Type.StructField{
        .name = "style_vars",
        .type = stylevarEnumArr,
        .is_comptime = false,
        .alignment = @alignOf(stylevarEnumArr),
        .default_value_ptr = null,
    };

    const colorEnumArr = std.EnumArray(ColorsEnum, c_int);

    const color_field = std.builtin.Type.StructField{
        .name = "colors",
        .type = colorEnumArr,
        .is_comptime = false,
        .alignment = @alignOf(colorEnumArr),
        .default_value_ptr = null,
    };
    return @Type(.{ .@"struct" = .{
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
    inline for (@typeInfo(imgui).@"struct".decls) |field| {
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
    for (@typeInfo(imgui).@"struct".decls) |decl| {
        const tag_name = decl.name;
        @setEvalBranchQuota(20_000);
        if (isStyleVar(tag_name)) {
            const m_struct = std.builtin.Type.StructField{
                .name = tag_name,
                .type = XYStruct,
                .is_comptime = false,
                .alignment = @alignOf(XYStruct),
                .default_value_ptr = null,
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
                .default_value_ptr = null,
            };
            color_idx += 1;
            color_fields[color_idx] = m_struct;
            color_enum_fields[color_idx] = .{
                .name = tag_name,
                .value = color_idx,
            };
        }
    }

    const stylevars_enum = @Type(.{ .@"enum" = .{
        .tag_type = i16,
        .fields = style_var_enum_fields[0..],
        .decls = &[_]std.builtin.Type.Declaration{},
        .is_exhaustive = true,
    } });
    const colors_enum = @Type(.{ .@"enum" = .{
        .tag_type = i16,
        .fields = color_enum_fields[0..],
        .decls = &[_]std.builtin.Type.Declaration{},
        .is_exhaustive = true,
    } });
    return .{ .stylevars_enum = stylevars_enum, .colors_enum = colors_enum };
}
const T = createstruct();
pub const StyleVarsEnum = T.stylevars_enum;
pub const ColorsEnum = T.colors_enum;

/// contains style_vars and colors of imgui
pub const StyleStruct = usestruct();

pub fn getStyleData(ctx: imgui.ContextPtr, stylesData: *StyleStruct) !void {
    inline for (@typeInfo(StyleVarsEnum).@"enum".fields) |field| {
        const xy = stylesData.style_vars.getPtr(@enumFromInt(field.value));
        const imguiStyleVar = @field(imgui, field.name);
        try imgui.GetStyleVar(.{ ctx, imguiStyleVar, &@field(xy.*, "x"), &@field(xy.*, "y") });
    }
    inline for (@typeInfo(ColorsEnum).@"enum".fields) |field| {
        const imguiColor = @field(imgui, field.name);
        const val = try imgui.GetStyleColor(.{ ctx, imguiColor });
        stylesData.colors.getPtr(@enumFromInt(field.value)).* = val;
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
    inline for (@typeInfo(StyleVarsEnum).@"enum".fields) |field| {
        const xy = stylesData.style_vars.getPtr(@enumFromInt(field.value));
        const val = stylevars_map.get(field.name[9..]);
        if (val) |styleVarVal| {
            xy.x = styleVarVal.x;
            xy.y = styleVarVal.y;
        }
    }
}

pub fn loadStyle(stylesData: *StyleStruct, comptime stylevars_map: std.StaticStringMap(XYStruct), comptime colors_map: std.StaticStringMap([:0]const u8)) !void {
    loadStyleVars(stylesData, stylevars_map);
    const rColorsEnum = std.meta.FieldEnum(Theme.ThemeTypes.ColorTable);
    inline for (@typeInfo(ColorsEnum).@"enum".fields) |field| {
        const reaper_theme_col_name = comptime colors_map.get(field.name[4..]);
        if (reaper_theme_col_name) |theme_col| {
            const val = Theme.clrs.get(std.meta.stringToEnum(rColorsEnum, theme_col).?).color;
            stylesData.colors.getPtr(@enumFromInt(field.value)).* = val;
        }
    }
}

/// Apply the theme colors from the c1_theme INI file into the style struct.
/// For standard ImGui colors (CheckMark, Text, Border, etc.), we match
/// the Col_ prefix-stripped name against WindowColors fields.
/// For our custom semantic colors (ActiveToggle, ErrorText), we map them
/// into unused ImGui color slots (Col_PlotLines, Col_PlotHistogram).
fn applyThemeColors(stylesData: *StyleStruct, window_colors: *const c1_theme.WindowColors) void {
    const WC = c1_theme.WindowColors;
    inline for (@typeInfo(ColorsEnum).@"enum".fields) |field| {
        const color_name = field.name[4..];
        if (@hasField(WC, color_name)) {
            const val = @field(window_colors, color_name);
            if (val != 0) {
                stylesData.colors.getPtr(@enumFromInt(field.value)).* = val;
            }
        }
    }
    // Map semantic colors into unused ImGui color slots
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
}

pub fn PushStyle(ctx: imgui.ContextPtr, win_style: WinStyle) !*const fn (ctx: imgui.ContextPtr) anyerror!void {
    var style_push_count: u8 = 0;
    var color_push_count: u8 = 0;
    const style = switch (win_style) {
        .main => MainStyle,
        .config => ConfigStyle,
    };
    try imgui.PushFont(.{ ctx, c1_theme.fonts.MAIN });
    inline for (@typeInfo(StyleVarsEnum).@"enum".fields) |field| {
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
    std.debug.assert(@typeInfo(StyleVarsEnum).@"enum".fields.len == style_push_count);

    inline for (@typeInfo(ColorsEnum).@"enum".fields) |field| {
        const stylevar = @field(imgui, field.name);
        const color = style.colors.get(@enumFromInt(field.value));
        try imgui.PushStyleColor(.{ ctx, stylevar, color });
        color_push_count += 1;
    }
    std.debug.assert(@typeInfo(ColorsEnum).@"enum".fields.len == color_push_count);

    return switch (win_style) {
        .main => struct {
            fn pop(cntx: imgui.ContextPtr) !void {
                try imgui.PopFont(.{cntx});
                try imgui.PopStyleVar(.{ cntx, @typeInfo(StyleVarsEnum).@"enum".fields.len });
                try imgui.PopStyleColor(.{ cntx, @typeInfo(ColorsEnum).@"enum".fields.len });
            }
        }.pop,
        .config => struct {
            fn pop(cntx: imgui.ContextPtr) !void {
                try imgui.PopFont(.{cntx});
                try imgui.PopStyleVar(.{ cntx, @typeInfo(StyleVarsEnum).@"enum".fields.len });
                try imgui.PopStyleColor(.{ cntx, @typeInfo(ColorsEnum).@"enum".fields.len });
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
