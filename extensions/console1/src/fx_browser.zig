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

const FxBrowser = @This();

pub const NAME: [:0]const u8 = "Fx Browser";
/// last used fx name
var last_used_fx: ?[:0]const u8 = null;

///Recursively draw the fx chains or track templates
///pass the `isFxChain` boolean to distinguish between the two
fn Directory(ctx: imgui.ContextPtr, directory: fx_parser.Directory, isFxChain: bool) !void {
    var buf: [std.fs.MAX_PATH_BYTES:0]u8 = undefined;

    if (directory.subdirs) |subdirs| {
        var subdirIt = subdirs.iterator();
        while (subdirIt.next()) |subdir| {
            if (try imgui.BeginMenu(.{ ctx, subdir.value_ptr.*.name, null })) {
                defer imgui.EndMenu(.{ctx}) catch {};
                try Directory(ctx, subdir.value_ptr.*, isFxChain);
            }
        }
    }
    if (directory.files) |files| {
        var filesIt = files.iterator();
        while (filesIt.next()) |entry| {
            const file = @as([:0]const u8, @ptrCast(entry.key_ptr.*));
            if (try imgui.Selectable(.{ ctx, @as([*:0]const u8, file) })) {
                if (isFxChain) {
                    const fullPathFile = try safePrint(&buf, "{s}/{s}", .{ directory.path, file });
                    const tr = reaper.GetSelectedTrack(@as(c_int, 0), @as(c_int, 0));
                    if (tr) |track| {
                        _ = reaper.TrackFX_AddByName(
                            track,
                            @as([*:0]const u8, @ptrCast(fullPathFile)),
                            false,
                            -1000 - reaper.TrackFX_GetCount(track),
                        );
                    }
                } else {
                    const fullPathFile = try safePrint(&buf, "{s}/{s}", .{ directory.path, file });
                    reaper.Main_openProject(@as([*:0]const u8, @ptrCast(fullPathFile)));
                }
            }
        }
    }
}

fn FxList(ctx: imgui.ContextPtr, menuName: [:0]const u8, fxList: fx_parser.FxList) !void {
    if (try imgui.BeginMenu(.{ ctx, @as([*:0]const u8, @ptrCast(menuName)), null })) { // draw fx chains menu
        defer imgui.EndMenu(.{ctx}) catch {};
        var iterator = fxList.iterator();
        while (iterator.next()) |entry| {
            const cast = @as([:0]const u8, @ptrCast(entry.key_ptr.*));
            const name = @as([*:0]const u8, @ptrCast(cast));
            if (cast.len >= 9 and std.mem.eql(u8, cast[0..9], "WaveShell")) {
                continue;
            }
            if (try imgui.Selectable(.{ ctx, name })) {
                const track = reaper.GetSelectedTrack(@as(c_int, 0), @as(c_int, 0));
                if (track) |tr| {
                    dispatch(&globals.state, .{ .fx_sel = .{ .select_fx = cast } });
                    // FIXME: update the insert point, we want to replace here, not add to end of track.
                    _ = reaper.TrackFX_AddByName(
                        tr,
                        name,
                        false,
                        -1000 - reaper.TrackFX_GetCount(tr),
                    );
                }
                last_used_fx = cast;
            }
        }
    }
}

fn PluginsByType(ctx: imgui.ContextPtr) !void {
    if (try imgui.BeginMenu(.{ ctx, @as([*:0]const u8, @ptrCast("all plugins")), null })) { // draw fx chains menu
        defer imgui.EndMenu(.{ctx}) catch {};
        var iterator = fx_parser.pluginsByType.iterator();
        while (iterator.next()) |entry| {
            try FxList(ctx, @tagName(entry.key), entry.value.*);
        }
    }
}

fn FxTags(
    ctx: imgui.ContextPtr,
) !void {
    inline for (@typeInfo(@TypeOf(fx_parser.fx_tags)).Struct.fields) |field| {
        // FIXME: should field be a reference?
        var tagList = @field(fx_parser.fx_tags, field.name);
        if (try imgui.BeginMenu(.{ ctx, @as([*:0]const u8, @ptrCast(field.name)), null })) {
            defer imgui.EndMenu(.{ctx}) catch {};
            var iterator = tagList.iterator();
            while (iterator.next()) |entry| {
                const tagName = @as([:0]const u8, @ptrCast(entry.key_ptr.*));
                const fxList = entry.value_ptr.*;
                try FxList(ctx, tagName, fxList);
            }
        }
    }
}

fn Menus(
    ctx: imgui.ContextPtr,
) !void {
    // TODO: implement filterbox
    // const filteredFxCount = self.FilterBox();
    const filteredFxCount = null;
    if (filteredFxCount != null) return; // don't display the component if there's some filtered fx
    if (try imgui.BeginMenu(.{ ctx, "fx chains", null })) { // draw fx chains menu
        defer imgui.EndMenu(.{ctx}) catch {};
        try Directory(ctx, fx_parser.fx_chains, true);
    }
    if (try imgui.BeginMenu(.{ ctx, "track templates", null })) { // draw track templates menu
        defer imgui.EndMenu(.{ctx}) catch {};
        try Directory(ctx, fx_parser.track_templates, false);
    }
    try PluginsByType(ctx);
    try FxTags(ctx);

    const elements = [3][:0]const u8{ "Container", "Video processor", "recent: " };
    for (elements) |element| {
        if (try imgui.Selectable(.{ ctx, element })) {
            const tr = reaper.GetSelectedTrack(@as(c_int, 0), @as(c_int, 0));
            const isLastUsed = std.mem.eql(u8, element, "recent: ");

            if (tr) |track| {
                const lastUsed = if (isLastUsed) if (last_used_fx) |lastUsd| lastUsd else element else element;
                _ = reaper.TrackFX_AddByName(
                    track,
                    lastUsed,
                    false,
                    -1000 - reaper.TrackFX_GetCount(track),
                );
            }
            if (!isLastUsed) {
                last_used_fx = element;
            }
        }
    }
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

pub fn Popup(ctx: imgui.ContextPtr) !void {
    const PopWindowStyle = try PushWindowStyle(ctx, .main);
    defer PopWindowStyle(ctx) catch {};
    try imgui.SetNextWindowSize(.{ ctx, 400, 200, null });
    if (try imgui.BeginPopup(.{ ctx, @as([:0]const u8, NAME), null })) {
        defer imgui.EndPopup(.{ctx}) catch {};
        try Menus(ctx);
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

    // Size might need adjustment for the additional content
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
            if (is_selected) try imgui.PushStyleColor(.{ ctx, .Text, Theme.colors.active });
            defer if (is_selected) imgui.PopStyleColor(.{ctx}) catch {};

            const fx_name: [:0]const u8 = @ptrCast(entry.key_ptr.*);
            if (try imgui.Selectable(.{ ctx, fx_name })) {
                const track = reaper.GetSelectedTrack(@as(c_int, 0), @as(c_int, 0));
                if (track) |tr| {
                    dispatch(&globals.state, .{ .fx_sel = .{ .select_mapped_fx = .{ .fx_name = fx_name, .module = module } } });
                    // FIXME: update the insert point, we want to replace here, not add to end of track.
                    _ = reaper.TrackFX_AddByName(
                        tr,
                        fx_name,
                        false,
                        -1000 - reaper.TrackFX_GetCount(tr),
                    );
                }
                last_used_fx = fx_name;
            }
        }

        // Separator between mapped and unmapped FX
        try imgui.Separator(.{ctx});

        try Menus(ctx);

        // Optional: Add rescan button at bottom
        try imgui.Separator(.{ctx});
        // try RescanButton(ctx);
    }
    return open;
}
