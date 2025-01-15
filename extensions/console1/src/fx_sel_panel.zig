const std = @import("std");
const imgui = @import("reaper_imgui.zig");
const Reaper = @import("reaper.zig");
const reaper = Reaper.reaper;
const Theme = @import("theme/Theme.zig");
const fx_parser = @import("fx_parser.zig");
const PushWindowStyle = @import("styles.zig").PushStyle;
const safePrint = @import("debug_panel.zig").safePrint;
const dispatch = @import("actions.zig").dispatch;
const globals = @import("globals.zig");
const fx_sel_actions = @import("fx_sel_actions.zig");

const FxBrowser = @This();

pub const NAME: [:0]const u8 = "Fx Browser";
/// last used fx name
var last_used_fx: ?[:0]const u8 = null;

///Recursively draw the fx chains or track templates
///pass the `isFxChain` boolean to distinguish between the two
fn Directory(ctx: imgui.ContextPtr, directory: fx_parser.Directory, isFxChain: bool) !?fx_sel_actions.FxSelActions {
    var buf: [std.fs.MAX_PATH_BYTES:0]u8 = undefined;

    if (directory.subdirs) |subdirs| {
        var subdirIt = subdirs.iterator();
        while (subdirIt.next()) |subdir| {
            if (try imgui.BeginMenu(.{ ctx, subdir.value_ptr.*.name, null })) {
                defer imgui.EndMenu(.{ctx}) catch {};
                if (try Directory(ctx, subdir.value_ptr.*, isFxChain)) |action| {
                    return action;
                }
            }
        }
    }
    if (directory.files) |files| {
        var filesIt = files.iterator();
        while (filesIt.next()) |entry| {
            const file = @as([:0]const u8, @ptrCast(entry.key_ptr.*));
            if (try imgui.Selectable(.{ ctx, file })) {
                const fullPathFile = try safePrint(&buf, "{s}/{s}", .{ directory.path, file });
                if (isFxChain) {
                    return .{ .fx_chain = .{ .path = fullPathFile } };
                } else {
                    return .{ .track_template = .{ .path = fullPathFile } };
                }
            }
        }
    }
    return null;
}

fn FxList(ctx: imgui.ContextPtr, menuName: [:0]const u8, fxList: fx_parser.FxList) !?fx_sel_actions.FxSelActions {
    if (try imgui.BeginMenu(.{ ctx, @as([*:0]const u8, @ptrCast(menuName)), null })) {
        defer imgui.EndMenu(.{ctx}) catch {};
        var iterator = fxList.iterator();
        while (iterator.next()) |entry| {
            const cast = @as([:0]const u8, @ptrCast(entry.key_ptr.*));
            if (cast.len >= 9 and std.mem.eql(u8, cast[0..9], "WaveShell")) {
                continue;
            }
            if (try imgui.Selectable(.{ ctx, cast })) {
                return .{ .plugin = .{ .name = cast } };
            }
        }
    }
    return null;
}

fn PluginsByType(ctx: imgui.ContextPtr) !?fx_sel_actions.FxSelActions {
    if (try imgui.BeginMenu(.{ ctx, @as([*:0]const u8, @ptrCast("all plugins")), null })) {
        defer imgui.EndMenu(.{ctx}) catch {};
        var iterator = fx_parser.pluginsByType.iterator();
        while (iterator.next()) |entry| {
            if (try FxList(ctx, @tagName(entry.key), entry.value.*)) |selection| {
                return selection;
            }
        }
    }
    return null;
}

fn FxTags(ctx: imgui.ContextPtr) !?fx_sel_actions.FxSelActions {
    inline for (@typeInfo(@TypeOf(fx_parser.fx_tags)).Struct.fields) |field| {
        var tagList = @field(fx_parser.fx_tags, field.name);
        if (try imgui.BeginMenu(.{ ctx, @as([*:0]const u8, @ptrCast(field.name)), null })) {
            defer imgui.EndMenu(.{ctx}) catch {};
            var iterator = tagList.iterator();
            while (iterator.next()) |entry| {
                const tagName = @as([:0]const u8, @ptrCast(entry.key_ptr.*));
                if (try FxList(ctx, tagName, entry.value_ptr.*)) |selection| {
                    return selection;
                }
            }
        }
    }
    return null;
}

fn Menus(ctx: imgui.ContextPtr) !?fx_sel_actions.FxSelActions {
    const filteredFxCount = null;
    if (filteredFxCount != null) return null; // don't display the component if there's some filtered fx

    if (try imgui.BeginMenu(.{ ctx, "fx chains", null })) {
        defer imgui.EndMenu(.{ctx}) catch {};
        if (try Directory(ctx, fx_parser.fx_chains, true)) |selection| {
            return selection;
        }
    }

    if (try imgui.BeginMenu(.{ ctx, "track templates", null })) {
        defer imgui.EndMenu(.{ctx}) catch {};
        if (try Directory(ctx, fx_parser.track_templates, false)) |selection| {
            return selection;
        }
    }

    if (try PluginsByType(ctx)) |selection| {
        return selection;
    }

    if (try FxTags(ctx)) |selection| {
        return selection;
    }

    const elements = [3][:0]const u8{ "Container", "Video processor", "recent: " };
    for (elements) |element| {
        if (try imgui.Selectable(.{ ctx, element })) {
            const isLastUsed = std.mem.eql(u8, element, "recent: ");
            const lastUsed = if (isLastUsed) if (last_used_fx) |lastUsed| lastUsed else element else element;
            return .{ .plugin = .{ .name = lastUsed } };
        }
    }

    return null;
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
    mappings: std.StringHashMap(void),
    current_index: usize,
) !bool {
    const PopWindowStyle = try PushWindowStyle(ctx, .main);
    defer PopWindowStyle(ctx) catch {};

    try imgui.SetNextWindowSize(.{ ctx, 400, 300, null });

    var buf: [128:0]u8 = undefined;
    const title = try safePrint(&buf, "{s} FX Browser", .{@tagName(module)});
    var open = true;
    if (try imgui.Begin(.{ ctx, title, &open })) {
        defer imgui.End(.{ctx}) catch {};

        try imgui.Text(.{ ctx, title });
        var iterator = mappings.iterator();
        var i: usize = 0;
        while (iterator.next()) |entry| : (i += 1) {
            const is_selected = (i == current_index);

            if (is_selected) try imgui.PushStyleColor(.{ ctx, imgui.Col_Text, Theme.clrs.get(std.meta.stringToEnum(Theme.RColorsEnum, "genlist_fg").?).color });
            defer if (is_selected) imgui.PopStyleColor(.{ctx}) catch {};

            const fx_name: [:0]const u8 = @ptrCast(entry.key_ptr.*);
            if (try imgui.Selectable(.{ ctx, fx_name })) {
                dispatch(&globals.state, .{ .fx_sel = .{ .plugin = .{ .name = fx_name } } });
            }
        }

        // Separator between mapped and unmapped FX
        try imgui.Separator(.{ctx});

        if (try Menus(ctx)) |selection| {
            dispatch(&globals.state, .{ .fx_sel = selection });
        }

        // Optional: Add rescan button at bottom
        try imgui.Separator(.{ctx});
        // try RescanButton(ctx);
    }

    return open;
}
