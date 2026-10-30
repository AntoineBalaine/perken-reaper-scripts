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

const ColorsEnum = styles.ColorsEnum;
const StyleStruct = styles.StyleStruct;

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
                drawColorList(ctx, style_manager.MainStyle);
            }

            if (try imgui.BeginTabItem(.{ ctx, "Config" })) {
                defer imgui.EndTabItem(.{ctx}) catch {};
                drawColorList(ctx, style_manager.ConfigStyle);
            }
        }

        try imgui.Separator(.{ctx});
        if (try imgui.Button(.{ ctx, "Save Theme" })) {
            rv = .save;
        }
    }

    return rv;
}

fn drawColorList(ctx: imgui.ContextPtr, style_struct: *StyleStruct) void {
    @setEvalBranchQuota(10_000);
    inline for (@typeInfo(ColorsEnum).@"enum".field_names, @typeInfo(ColorsEnum).@"enum".field_values) |field_name, field_value| {
        const color = style_struct.colors.getPtr(@fromBackingInt(@intCast(field_value)));
        _ = imgui.ColorEdit4(.{ ctx, field_name, color, imgui.ColorEditFlags_NoInputs }) catch {};
    }
}

pub const SaveAction = enum { save };
