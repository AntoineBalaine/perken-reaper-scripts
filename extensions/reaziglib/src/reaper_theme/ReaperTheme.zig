const std = @import("std");
const ImGui = @import("reaper_imgui");
const Reaper = @import("reaper");
const reaper = Reaper.reaper;
pub const ThemeTypes = @import("themeTypes.zig");

pub const ThemeClrs = std.EnumArray(std.meta.FieldEnum(ThemeTypes.ColorTable), ThemeTypes.ThemeColor);
pub var clrs: ThemeClrs = undefined;

/// Queries REAPER's native theme colors and populates clrs.
/// This function provides REAPER theme colors used by components for
/// FX box backgrounds, text colors, and decorations. Project-specific
/// INI-based theme systems (e.g. rack_theme) handle their own window
/// colors separately.
pub fn init(ctx: ImGui.ContextPtr, convert_colors: bool) !void {
    _ = ctx;
    clrs = std.EnumArray(std.meta.FieldEnum(ThemeTypes.ColorTable), ThemeTypes.ThemeColor).initUndefined();
    inline for (@typeInfo(ThemeTypes.ThemeVars).@"struct".fields) |themeVar| {
        const varName: [:0]const u8 = themeVar.name;
        const description = @field(ThemeTypes.themeVars, varName);
        var col = reaper.GetThemeColor(@as([*:0]const u8, varName), 0);
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
}
