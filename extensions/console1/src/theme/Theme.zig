const std = @import("std");
const ImGui = @import("../reaper_imgui.zig");
const Reaper = @import("../reaper.zig");
const reaper = Reaper.reaper;
pub const ThemeTypes = @import("themeTypes.zig");
const fontello = @embedFile("../assets/fontello1.ttf");
const systemfont = "sans-serif";

pub const FONT_SMALL_SIZE: c_int = 14;
pub const ICON_FONT_SMALL_SIZE: c_int = 13;

const Fonts = struct {
    MAIN: ImGui.FontPtr = undefined,
    ICON_FONT_SMALL: ImGui.FontPtr = undefined,
};

pub var clrs: std.EnumArray(std.meta.FieldEnum(ThemeTypes.ColorTable), ThemeTypes.ThemeColor) = undefined;

pub var fonts = Fonts{};

const ThemeErr = error{
    ThemePathFail,
};

/// Attach the fonts to the ImGui context
pub fn attachFonts(ctx: ImGui.ContextPtr) !void {
    const mainFontResource: ImGui.ResourcePtr = @ptrCast(fonts.MAIN);
    try ImGui.Attach(.{ ctx, mainFontResource });

    const fontelloResource: ImGui.ResourcePtr = @ptrCast(fonts.ICON_FONT_SMALL);
    try ImGui.Attach(.{ ctx, fontelloResource });
}

/// Query the theme from reaper
/// and store it in a table containing its colors and fonts.
///
/// If an ImGui context is provided, the fonts will be attached to the context, and created
pub fn init(ctx: ImGui.ContextPtr, convert_colors: bool) !void {
    clrs = std.EnumArray(std.meta.FieldEnum(ThemeTypes.ColorTable), ThemeTypes.ThemeColor).initUndefined();
    inline for (@typeInfo(ThemeTypes.ThemeVars).Struct.fields) |themeVar| {
        const varName: [:0]const u8 = themeVar.name;
        const description = @field(ThemeTypes.themeVars, varName);
        // const description = themeVar.default_value;
        var col = reaper.GetThemeColor(@as([*:0]const u8, varName), 0); // NOTE: Flag doesn't seem to work (v6.78). Channel are swapped on MacOS and Linux.
        if (convert_colors) {
            const converted = try ImGui.ColorConvertNative(.{col});
            col = (converted << 8) | 0xff;
        }
        const cl = ThemeTypes.ThemeColor{
            .color = col,
            .description = description,
        };
        clrs.getPtr(std.meta.stringToEnum(std.meta.FieldEnum(ThemeTypes.ColorTable), varName).?).* = cl;
    }

    fonts.MAIN = try ImGui.CreateFont(.{ systemfont, FONT_SMALL_SIZE, null });

    fonts.ICON_FONT_SMALL = try ImGui.CreateFontFromMem(.{ fontello, fontello.len, ICON_FONT_SMALL_SIZE, null });
    if (ctx) |context| {
        try attachFonts(context);
    }
}

const IconsList = enum {
    arrow_down,
    arrow_right,
    close,
    kebab,
    plus,
    save,
    wrench,
    pin,
};

// BUG: not all of these icons are correct
pub const Icons = std.EnumArray(IconsList, [:0]const u8).init(.{
    .arrow_down = "~",
    .arrow_right = "_", // wrong, again…
    .close = "?",
    .kebab = "ß",
    .plus = "B",
    .save = "Ä",
    .wrench = "k",
    .pin = "R",
});
