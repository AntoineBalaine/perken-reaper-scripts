const std = @import("std");
const reaper = @import("reaper.zig").reaper;
const imgui = @import("reaper_imgui.zig");
const Theme = @import("theme/Theme.zig");

pub const Docker = struct {
    pub const UNDOCKED: i32 = 0;
    pub const RIGHT: i32 = -2; // Or whichever docker number you want to use
    pub const BOTTOM: i32 = -1;
    // ... other docker positions
};

pub const WinStyle = enum { rack, main };

const MAXCHAN: f64 = 128;
pub const WIDTH_MIN: f64 = 150;
pub const HEIGHT_MIN: f64 = 150;
pub const WIDTH_MAX: f64 = 800;
pub const HEIGHT_MAX: f64 = 400;
pub var rack_style_open: bool = false;
pub var main_style_open: bool = false;

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
pub const StyleVarsEnum = T.stylevars_enum;
pub const ColorsEnum = T.colors_enum;

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
pub var MainWinStyle: StyleStruct = undefined;
pub const StyleManager = struct {
    RackStyle: *StyleStruct,
    MainWinStyle: *StyleStruct,
    rack_style_open: *bool,
    main_style_open: *bool,
};

pub fn init(ctx: imgui.ContextPtr) !void {
    RackStyle = std.mem.zeroes(StyleStruct);
    try getStyleData(ctx, &RackStyle);
    MainWinStyle = RackStyle; // copy
    try loadStyle(&RackStyle, RACK_STYLEVARS, RACK_COLORS);
    try loadStyle(&MainWinStyle, MAIN_WIN_STYLEVARS, MAIN_WIN_COLORS);
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
