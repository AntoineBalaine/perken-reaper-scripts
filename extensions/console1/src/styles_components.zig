const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Theme = @import("theme/Theme.zig");
const Palette = @import("components/Palette.zig").Palette;
const styles = @import("styles.zig");

const Content = struct {
    rackWindowLabel: [:0]const u8 = "Rack Style Configurations",
    mainWindowLabel: [:0]const u8 = "Window Style Configurations",
    trackChannels: [:0]const u8 = "sizes",
    containerChannels: [:0]const u8 = "colors",
};
const content = Content{};

const WinStyle = styles.WinStyle;
const StyleVarsEnum = styles.StyleVarsEnum;
const ColorsEnum = styles.ColorsEnum;

pub fn StyleEditor(ctx: imgui.ContextPtr, win: WinStyle, style_manager: *styles.StyleManager) !void {
    var is_open = switch (win) {
        .rack => style_manager.rack_style_open,
        .main => style_manager.main_style_open,
    };
    _ = &is_open;
    std.debug.assert(is_open.*);
    const PopStyle = try PushStyle(ctx, .main, style_manager);
    defer PopStyle(ctx) catch {};
    try imgui.SetNextWindowSizeConstraints(.{ ctx, styles.WIDTH_MIN, styles.HEIGHT_MIN, styles.WIDTH_MAX, styles.HEIGHT_MAX });

    const flags = imgui.WindowFlags_TopMost + imgui.WindowFlags_NoCollapse + imgui.WindowFlags_AlwaysAutoResize;
    if (try imgui.Begin(.{ ctx, switch (win) {
        .rack => content.rackWindowLabel,
        .main => content.mainWindowLabel,
    }, is_open, flags })) {
        defer imgui.End(.{ctx}) catch {};
        try ShowStyleEditor(ctx, win, style_manager);
    }
}

fn slider(comptime variant: std.meta.FieldEnum(styles.StyleStruct), ctx: imgui.ContextPtr, style_struct: *styles.StyleStruct, comptime varname: [:0]const u8, min: f64, max: f64, format: [:0]const u8) !void {
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

fn ShowStyleEditor(ctx: imgui.ContextPtr, window: WinStyle, style_manager: *styles.StyleManager) !void {
    var style_struct = switch (window) {
        .rack => style_manager.RackStyle,
        .main => style_manager.MainWinStyle,
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
                try imgui.SetNextWindowSizeConstraints(.{ ctx, @as(f64, @floatCast(0.0)), try imgui.GetTextLineHeightWithSpacing(.{ctx}) * 10, styles.WIDTH_MAX, styles.HEIGHT_MAX });
                if (try imgui.BeginChild(.{ ctx, "##colors", 0, 0, imgui.WindowFlags_None })) {
                    defer imgui.EndChild(.{
                        ctx,
                    }) catch {};
                    var colors = &@field(style_struct, "colors");
                    _ = &colors;

                    inline for (@typeInfo(ColorsEnum).@"enum".fields) |field| {
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

pub fn PushStyle(ctx: imgui.ContextPtr, win_style: WinStyle, style_manager: *styles.StyleManager) !*const fn (ctx: imgui.ContextPtr) anyerror!void {
    var style_push_count: u8 = 0;
    var color_push_count: u8 = 0;
    const style = switch (win_style) {
        .rack => style_manager.RackStyle.*,
        .main => style_manager.MainWinStyle.*,
    };
    try imgui.PushFont(.{ ctx, Theme.fonts.MAIN });
    inline for (@typeInfo(StyleVarsEnum).@"enum".fields) |field| {
        const xy = style.style_vars.get(@enumFromInt(field.value));
        const stylevar = @field(imgui, field.name);
        if (styles.VEC.get(field.name[9..])) |_| {
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
        .rack => struct {
            fn pop(cntx: imgui.ContextPtr) !void {
                try imgui.PopFont(.{cntx});
                try imgui.PopStyleVar(.{ cntx, @typeInfo(StyleVarsEnum).@"enum".fields.len });
                try imgui.PopStyleColor(.{ cntx, @typeInfo(ColorsEnum).@"enum".fields.len });
            }
        }.pop,
        .main => struct {
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
