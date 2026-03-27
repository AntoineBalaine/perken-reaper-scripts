const std = @import("std");
const ImGui = @import("reaper_imgui");
const Reaper = @import("../reaper.zig");
const reaper = Reaper.reaper;
pub const ThemeTypes = @import("themeTypes.zig");
const c1_theme = @import("c1_theme.zig");
const fontello = @embedFile("../assets/fontello1.ttf");
const systemfont = "sans-serif";

pub const FONT_SMALL_SIZE: c_int = 14;
pub const ICON_FONT_SMALL_SIZE: c_int = 13;

const Fonts = struct {
    MAIN: ImGui.FontPtr = undefined,
    ICON_FONT_SMALL: ImGui.FontPtr = undefined,
};

pub const RColorsEnum = std.meta.FieldEnum(ThemeTypes.ColorTable);
pub var clrs: std.EnumArray(RColorsEnum, ThemeTypes.ThemeColor) = undefined;

pub var fonts = Fonts{};

/// Attach the fonts to the ImGui context
pub fn attachFonts(ctx: ImGui.ContextPtr) !void {
    const mainFontResource: ImGui.ResourcePtr = @ptrCast(fonts.MAIN);
    try ImGui.Attach(.{ ctx, mainFontResource });

    const fontelloResource: ImGui.ResourcePtr = @ptrCast(fonts.ICON_FONT_SMALL);
    try ImGui.Attach(.{ ctx, fontelloResource });
}

/// Load theme colors from the c1_theme INI file and set up fonts.
/// styles.zig reads colors directly from c1_theme.theme.WindowColors,
/// so we no longer need to populate Theme.clrs with our colors.
/// Theme.clrs is still initialized (zeroed) for the legacy Palette/StyleEditor.
pub fn init(ctx: ImGui.ContextPtr) !void {
    c1_theme.init();
    clrs = std.EnumArray(RColorsEnum, ThemeTypes.ThemeColor).initUndefined();
    inline for (@typeInfo(ThemeTypes.ThemeVars).@"struct".fields) |themeVar| {
        const varName: [:0]const u8 = themeVar.name;
        const description = @field(ThemeTypes.themeVars, varName);
        clrs.getPtr(std.meta.stringToEnum(RColorsEnum, varName).?).* = .{
            .color = 0,
            .description = description,
        };
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
