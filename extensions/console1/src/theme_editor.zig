const std = @import("std");
const imgui = @import("reaper_imgui");
const styles = @import("styles.zig");
const c1_theme = @import("theme/c1_theme.zig");
const WindowColors = c1_theme.WindowColors;

pub var theme_editor_open: bool = false;

const custom_colors = std.StaticStringMap(void).initComptime(.{
    .{ "ActiveToggle", {} },
    .{ "ErrorText", {} },
    .{ "KnobBg", {} },
});

fn isCustomColor(name: []const u8) bool {
    return custom_colors.get(name) != null;
}

fn nativeToImgui(native: c_int) c_int {
    const converted = imgui.ColorConvertNative(.{native}) catch return native;
    return (converted << 8) | 0xff;
}

fn imguiToNative(color: c_int) c_int {
    const without_alpha = color >> 8;
    return imgui.ColorConvertNative(.{without_alpha}) catch return color;
}

pub fn draw(ctx: imgui.ContextPtr, style_manager: *styles.StyleManager) !?SaveAction {
    if (!theme_editor_open) return null;
    var rv: ?SaveAction = null;

    try imgui.SetNextWindowSizeConstraints(.{ ctx, 300, 200, 600, 800 });
    const flags = imgui.WindowFlags_TopMost + imgui.WindowFlags_NoCollapse;
    if (try imgui.Begin(.{ ctx, "Theme Editor", &theme_editor_open, flags })) {
        defer imgui.End(.{ctx}) catch {};

        if (try imgui.BeginTabBar(.{ ctx, "##theme_tabs", imgui.TabBarFlags_None })) {
            defer imgui.EndTabBar(.{ctx}) catch {};

            if (try imgui.BeginTabItem(.{ ctx, "Main" })) {
                defer imgui.EndTabItem(.{ctx}) catch {};
                if (drawColorList(ctx, &c1_theme.theme.main)) {
                    styles.applyThemeColors(&styles.MainStyle, &c1_theme.theme.main);
                    _ = style_manager;
                }
            }

            if (try imgui.BeginTabItem(.{ ctx, "Config" })) {
                defer imgui.EndTabItem(.{ctx}) catch {};
                if (drawColorList(ctx, &c1_theme.theme.config)) {
                    styles.applyThemeColors(&styles.ConfigStyle, &c1_theme.theme.config);
                }
            }
        }

        try imgui.Separator(.{ctx});
        if (try imgui.Button(.{ ctx, "Save Theme" })) {
            rv = .save;
        }
    }

    return rv;
}

fn drawColorList(ctx: imgui.ContextPtr, colors: *WindowColors) bool {
    var changed = false;
    inline for (std.meta.fields(WindowColors)) |field| {
        const val = &@field(colors, field.name);
        var display_color: c_int = if (isCustomColor(field.name))
            val.*
        else
            nativeToImgui(val.*);

        if ((imgui.ColorEdit4(.{ ctx, field.name, &display_color, imgui.ColorEditFlags_NoInputs }) catch false)) {
            if (isCustomColor(field.name)) {
                val.* = display_color;
            } else {
                val.* = imguiToNative(display_color);
            }
            changed = true;
        }
    }
    return changed;
}

pub const SaveAction = enum { save };
