const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Reaper = @import("reaper.zig");
const reaper = Reaper.reaper;
const Theme = @import("theme/Theme.zig");
const fx_parser = @import("fx_parser.zig");
const PushWindowStyle = @import("styles.zig").PushStyle;
const safePrint = @import("debug_panel.zig").safePrint;
const globals = @import("globals.zig");
const fx_sel_actions = @import("fx_sel_actions.zig");
const log = std.log.scoped(.fx_sel_panel);
const FxBrowser = @This();

pub const NAME: [:0]const u8 = "Fx Browser";
/// last used fx name
var last_used_fx: ?[:0]const u8 = null;

///Recursively draw the fx chains or track templates
///pass the `isFxChain` boolean to distinguish between the two
fn Directory(ctx: imgui.ContextPtr, directory: fx_parser.Directory, isFxChain: bool) !?fx_sel_actions.FxSelActions {
    var buf: [std.fs.MAX_PATH_BYTES:0]u8 = undefined;

    var rv: ?fx_sel_actions.FxSelActions = null;
    if (directory.subdirs) |subdirs| {
        var subdirIt = subdirs.iterator();
        while (subdirIt.next()) |subdir| {
            if (try imgui.BeginMenu(.{ ctx, subdir.value_ptr.*.name, null })) {
                defer imgui.EndMenu(.{ctx}) catch {};
                if (try Directory(ctx, subdir.value_ptr.*, isFxChain)) |action| {
                    rv = action;
                }
            }
        }
    }
    if (directory.files) |files| {
        var filesIt = files.iterator();
        while (filesIt.next()) |entry| {
            const file = @as([:0]const u8, @ptrCast(entry.key_ptr.*));
            if (try imgui.Selectable(.{ ctx, file })) {
                const fullPathFile = safePrint(&buf, "{s}/{s}", .{ directory.path, file });
                if (isFxChain) {
                    rv = .{ .fx_chain = .{ .path = fullPathFile } };
                } else {
                    rv = .{ .track_template = .{ .path = fullPathFile } };
                }
            }
        }
    }
    return rv;
}

fn FxList(ctx: imgui.ContextPtr, menuName: [:0]const u8, fxList: fx_parser.FxList) !?fx_sel_actions.FxSelActions {
    var rv: ?fx_sel_actions.FxSelActions = null;
    if (try imgui.BeginMenu(.{ ctx, @as([*:0]const u8, @ptrCast(menuName)), null })) {
        defer imgui.EndMenu(.{ctx}) catch {};
        var iterator = fxList.iterator();
        while (iterator.next()) |entry| {
            const cast = @as([:0]const u8, @ptrCast(entry.key_ptr.*));
            if (cast.len >= 9 and std.mem.eql(u8, cast[0..9], "WaveShell")) {
                continue;
            }
            if (try imgui.Selectable(.{ ctx, cast })) {
                rv = .{ .plugin = .{ .name = cast } };
            }
        }
    }
    return rv;
}

fn PluginsByType(ctx: imgui.ContextPtr) !?fx_sel_actions.FxSelActions {
    var rv: ?fx_sel_actions.FxSelActions = null;
    if (try imgui.BeginMenu(.{ ctx, @as([*:0]const u8, @ptrCast("all plugins")), null })) {
        defer imgui.EndMenu(.{ctx}) catch {};
        var iterator = fx_parser.pluginsByType.iterator();
        while (iterator.next()) |entry| {
            if (try FxList(ctx, @tagName(entry.key), entry.value.*)) |selection| {
                rv = selection;
            }
        }
    }
    return rv;
}

fn FxTags(ctx: imgui.ContextPtr) !?fx_sel_actions.FxSelActions {
    var rv: ?fx_sel_actions.FxSelActions = null;
    inline for (@typeInfo(@TypeOf(fx_parser.fx_tags)).Struct.fields) |field| {
        var tagList = @field(fx_parser.fx_tags, field.name);
        if (try imgui.BeginMenu(.{ ctx, @as([*:0]const u8, @ptrCast(field.name)), null })) {
            defer imgui.EndMenu(.{ctx}) catch {};
            var iterator = tagList.iterator();
            while (iterator.next()) |entry| {
                const tagName = @as([:0]const u8, @ptrCast(entry.key_ptr.*));
                if (try FxList(ctx, tagName, entry.value_ptr.*)) |selection| {
                    rv = selection;
                }
            }
        }
    }
    return rv;
}

fn Menus(ctx: imgui.ContextPtr) !?fx_sel_actions.FxSelActions {
    const filteredFxCount = null;
    if (filteredFxCount != null) return null; // don't display the component if there's some filtered fx

    var rv: ?fx_sel_actions.FxSelActions = null;

    if (try imgui.BeginMenu(.{ ctx, "fx chains", null })) {
        defer imgui.EndMenu(.{ctx}) catch {};
        if (try Directory(ctx, fx_parser.fx_chains, true)) |selection| {
            rv = selection;
        }
    }

    if (try imgui.BeginMenu(.{ ctx, "track templates", null })) {
        defer imgui.EndMenu(.{ctx}) catch {};
        if (try Directory(ctx, fx_parser.track_templates, false)) |selection| {
            rv = selection;
        }
    }

    if (try PluginsByType(ctx)) |selection| {
        rv = selection;
    }

    if (try FxTags(ctx)) |selection| {
        rv = selection;
    }

    const elements = [3][:0]const u8{ "Container", "Video processor", "recent: " };
    for (elements) |element| {
        if (try imgui.Selectable(.{ ctx, element })) {
            const isLastUsed = std.mem.eql(u8, element, "recent: ");
            const lastUsed = if (isLastUsed) if (last_used_fx) |lastUsed| lastUsed else element else element;
            rv = .{ .plugin = .{ .name = lastUsed } };
        }
    }

    return rv;
}

var counter: ?u8 = null;

fn RescanButton(ctx: imgui.ContextPtr) !void {
    if (try imgui.Button(.{ ctx, "Rescan plugin list" })) {
        fx_parser.deinit();
        fx_parser.init();
        counter = 0;
    }

    if (counter) |count| { // display «done» for 1 second
        if (count == 60) {
            count = null; // reset
        } else {
            count += 1;
            try imgui.Text(.{ ctx, "Done!" });
        }
    }
}

pub fn ModulePopup(
    ctx: imgui.ContextPtr,
    module: @import("statemachine.zig").ModulesList,
    mappings: std.StringArrayHashMap(void),
    current_index: usize,
    display_menus: bool,
) !?fx_sel_actions.FxSelActions {
    var rv: ?fx_sel_actions.FxSelActions = null;

    const PopWindowStyle = try PushWindowStyle(ctx, .main);
    defer PopWindowStyle(ctx) catch {};

    try imgui.SetNextWindowSize(.{ ctx, 400, 300, null });

    var open = true;

    if (try imgui.Begin(.{ ctx, "FX Browser", &open })) {
        defer imgui.End(.{ctx}) catch {};

        try imgui.Text(.{ ctx, @tagName(module) });
        var iterator = mappings.iterator();
        var i: usize = 0;
        while (iterator.next()) |entry| : (i += 1) {
            const is_selected = (i == current_index);

            const fx_name: [:0]const u8 = @ptrCast(entry.key_ptr.*);
            if (try imgui.Selectable(.{ ctx, fx_name })) {
                rv = .{ .plugin = .{ .name = fx_name } };
            }
            if (is_selected) {
                try drawInvertedSlctblColors(ctx, fx_name);
            }
        }

        if (display_menus) {
            // Separator between mapped and unmapped FX
            try imgui.Separator(.{ctx});

            if (try Menus(ctx)) |selection| {
                rv = selection;
            }

            // Optional: Add rescan button at bottom
            try imgui.Separator(.{ctx});
            // try RescanButton(ctx);
        }
    }
    if (!open) rv = .close_browser;

    return rv;
}

fn drawInvertedSlctblColors(ctx: imgui.ContextPtr, fx_name: [:0]const u8) !void {
    const drw_ls = try imgui.GetWindowDrawList(.{ctx});
    if (globals.drwls_splitter == null or !try imgui.ValidatePtr(.{ @as(*anyopaque, @ptrCast(globals.drwls_splitter.?)), "ImGui_DrawListSplitter*" })) {
        globals.drwls_splitter = try imgui.CreateDrawListSplitter(.{drw_ls});
    }
    const splitter = globals.drwls_splitter;

    try imgui.DrawListSplitter_Split(.{ splitter, 2 });
    defer imgui.DrawListSplitter_Merge(.{splitter}) catch {};
    try imgui.DrawListSplitter_SetCurrentChannel(.{ splitter, 0 });

    var prev_min_x: f64 = undefined;
    var prev_min_y: f64 = undefined;
    try imgui.GetItemRectMin(.{ ctx, &prev_min_x, &prev_min_y });

    var prev_max_x: f64 = undefined;
    var prev_max_y: f64 = undefined;
    try imgui.GetItemRectMax(.{ ctx, &prev_max_x, &prev_max_y });

    const bg_color = Theme.clrs.get(std.meta.stringToEnum(Theme.RColorsEnum, "genlist_fg").?).color;
    try imgui.DrawList_AddRectFilled(.{
        drw_ls,
        prev_min_x,
        prev_min_y,
        prev_max_x,
        prev_max_y,
        bg_color,
    });

    // Draw text in inverted color
    try imgui.DrawListSplitter_SetCurrentChannel(.{ splitter, 1 });
    const text_color = Theme.clrs.get(std.meta.stringToEnum(Theme.RColorsEnum, "genlist_bg").?).color;
    var frame_padding_x: f64 = undefined;
    var frame_padding_y: f64 = undefined;
    try imgui.GetStyleVar(.{ ctx, imgui.StyleVar_FramePadding, &frame_padding_x, &frame_padding_y });
    try imgui.DrawList_AddText(.{
        drw_ls,
        prev_min_x + frame_padding_x,
        prev_min_y + frame_padding_y,
        text_color,
        fx_name,
    });
}
