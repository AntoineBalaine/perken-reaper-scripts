// A color palette, containing a color picker and the list of reaper’s Theme colors.

const std = @import("std");
const reaper = @import("../reaper.zig").reaper;
const imgui = @import("../reaper_imgui.zig");
const Theme = @import("../theme/Theme.zig");

const PaletteContent = struct {
    themePaletteTag: [:0]const u8 = "##themePalette",
    themePalette: [:0]const u8 = "Theme Palette",
    pickerTag: [:0]const u8 = "##picker",
    current: [:0]const u8 = "Current",
    currentTag: [:0]const u8 = "##current",
    previous: [:0]const u8 = "Previous",
    previousTag: [:0]const u8 = "##previous",
    themeColors: [:0]const u8 = "Theme Colors",
    themeColorsPaletteTag: [:0]const u8 = "##themeColorsPalette",
    paletteTag: [:0]const u8 = "##palette",
};

const content = PaletteContent{};
var backup_col: ?c_int = null;
var buf: [512:0]u8 = undefined;
var titleBuf: [512:0]u8 = undefined;
// FIXME: pass ids correctly
pub fn Palette(ctx: imgui.ContextPtr, cur_col: *c_int, name: [:0]const u8) !bool {
    var rv = false;

    const popupTitle = try std.fmt.bufPrintZ(
        &titleBuf,
        "{s}{s}",
        .{ content.themePalette, name },
    );
    try imgui.PushStyleColor(.{ ctx, imgui.Col_Button, cur_col.* });
    const themePaletteTag = try std.fmt.bufPrintZ(
        &buf,
        "{s}{s}",
        .{ content.themePaletteTag, name },
    );
    if (try imgui.Button(.{ ctx, @as(
        [*:0]const u8,
        themePaletteTag,
    ), 20, 20 })) {
        try imgui.OpenPopup(.{ ctx, @as([*:0]const u8, popupTitle) });
        backup_col = cur_col.*;
    }
    try imgui.PopStyleColor(.{ctx});

    try imgui.SetNextWindowSize(.{ ctx, 470, 295 });
    if (try imgui.BeginPopup(.{ ctx, @as([*:0]const u8, popupTitle) })) {
        defer imgui.EndPopup(.{ctx}) catch {};
        try imgui.Separator(.{ctx});

        const pickerTag = try std.fmt.bufPrintZ(
            &buf,
            "{s}{s}",
            .{ content.pickerTag, name },
        );
        if (try imgui.ColorPicker4(.{ ctx, @as([*:0]const u8, pickerTag), cur_col, imgui.ColorEditFlags_NoSidePreview | imgui.ColorEditFlags_NoSmallPreview })) {
            cur_col.* = try imgui.ColorConvertNative(.{cur_col.*});
        }
        try imgui.SameLine(.{ctx});

        try imgui.BeginGroup(.{ctx}); // lock x position
        defer imgui.EndGroup(.{ctx}) catch {};

        { // current
            try imgui.BeginGroup(.{ctx}); // lock next items to be on the same line
            defer imgui.EndGroup(.{ctx}) catch {};
            try imgui.Text(.{ ctx, @as([*:0]const u8, content.current) });
            _ = try imgui.ColorButton(.{ ctx, @as([*:0]const u8, content.currentTag), cur_col.*, imgui.ColorEditFlags_NoPicker | imgui.ColorEditFlags_AlphaPreviewHalf, 60, 40 });
        }
        try imgui.SameLine(.{ctx});
        { // previous
            try imgui.BeginGroup(.{ctx}); // lock next items to be on the same line
            defer imgui.EndGroup(.{ctx}) catch {};
            try imgui.Text(.{ ctx, @as([*:0]const u8, content.previous) });
            if (try imgui.ColorButton(.{ ctx, @as([*:0]const u8, content.previousTag), backup_col.?, imgui.ColorEditFlags_NoPicker | imgui.ColorEditFlags_AlphaPreviewHalf, 60, 40 })) {
                cur_col.* = backup_col.?;
            }
        }
        try imgui.Separator(.{ctx});
        try imgui.Text(.{ ctx, @as([*:0]const u8, content.themeColors) });
        if (try imgui.BeginChild(.{ ctx, @as([*:0]const u8, content.themeColorsPaletteTag) })) {
            defer imgui.EndChild(.{ctx}) catch {};
            inline for (comptime @typeInfo(Theme.ThemeTypes.ColorTable).Struct.fields, 0..) |field, idx| {
                const themeColor = Theme.clrs.getPtr(std.meta.stringToEnum(std.meta.FieldEnum(Theme.ThemeTypes.ColorTable), field.name).?);
                const col = themeColor.color;
                const description = themeColor.description;
                try imgui.PushID(.{ ctx, field.name });
                defer imgui.PopID(.{ctx}) catch {};
                if (@rem(idx, 8) != 0) {
                    var spc_x: f64 = undefined;
                    var spc_y: f64 = undefined;
                    try imgui.GetStyleVar(.{ ctx, imgui.StyleVar_ItemSpacing, &spc_x, &spc_y });
                    try imgui.SameLine(.{ ctx, 0, spc_y });
                }
                if (try imgui.ColorButton(.{ ctx, description, col, imgui.ColorEditFlags_NoPicker, 20, 20 })) {
                    cur_col.* = col;
                    rv = true;
                }
                if (try imgui.BeginDragDropTarget(.{ctx})) {
                    defer imgui.EndDragDropTarget(.{ctx}) catch {};
                    var dropCol: c_int = undefined;
                    if (try imgui.AcceptDragDropPayloadRGB(.{ ctx, &dropCol })) {
                        themeColor.color = try imgui.ColorConvertNative(.{dropCol});
                    }
                }
            }
        }
    }

    return rv;
}
