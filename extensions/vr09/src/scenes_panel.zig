//! The session's scenes, ported from the design lab's `panel.lua`: the table of the scenes, with a drag that
//! moves a row, a double click that renames it and a button that removes it; the button that puts a point of
//! the Scene parameter at the edit cursor; and the scene templates.
//!
//! The scenes are copies of patches that live in the plugin's saved state, and the Scene parameter holds a
//! position in the list. When a scene moves or goes, the points of the parameter's lane follow, so that the
//! song keeps playing the same scenes (see `scene_lane.zig`).
//!
//! A template is a file of `Data/Perken/vr09/scenes`: the scenes' names and the IDs of their patches, one scene
//! to a line, the two separated by a tab. Because it holds an ID and not the patch, a template follows the
//! library: a patch that is no longer there is counted as missing when the template is read.
const std = @import("std");
const imgui = @import("reaper_imgui");
const plugin = @import("plugin.zig");
const ui = @import("ui.zig");
const scenes = @import("scenes.zig");
const fileio = @import("fileio.zig");
const glue = @import("reaper_glue.zig");
const theme = @import("theme.zig");
const widgets = @import("widgets.zig");
const patches_panel = @import("patches_panel.zig");
const scene_lane = @import("scene_lane.zig");

const Plugin = plugin.Plugin;

const template_extension = ".scenes";
const template_name_cap = 64;

/// What the scene list keeps between frames.
pub const State = struct {
    /// Because the rows change places while one is dragged, each is known by an ID of its scene, which moves
    /// with it. The IDs are the panel's own: the plugin's scenes have none.
    uids: [scenes.max_scenes]u32 = [_]u32{0} ** scenes.max_scenes,
    uid_count: usize = 0,
    next_uid: u32 = 1,
    /// True while a row is dragged, so that the click that ends the drag does not select a scene.
    dragged: bool = false,
    /// The ID of the scene whose name is being edited, or 0, and the text of the field.
    editing: u32 = 0,
    focus: bool = false,
    edit_text: [scenes.max_name:0]u8 = [_:0]u8{0} ** scenes.max_name,
    template_name: [template_name_cap:0]u8 = [_:0]u8{0} ** template_name_cap,
    template_selected: [template_name_cap:0]u8 = [_:0]u8{0} ** template_name_cap,
    templates: ?std.ArrayList([]u8) = null,
    templates_at: u32 = 0,
};

/// Gives every scene an ID, and forgets the IDs of scenes that are gone.
fn ensureUids(w: *State, count: usize) void {
    while (w.uid_count < count) {
        w.uids[w.uid_count] = w.next_uid;
        w.next_uid += 1;
        w.uid_count += 1;
    }
    if (w.uid_count > count) w.uid_count = count;
}

fn moveUid(w: *State, from: usize, to: usize) void {
    const uid = w.uids[from - 1];
    if (from < to) {
        for (from - 1..to - 1) |i| w.uids[i] = w.uids[i + 1];
    } else {
        var i = from - 1;
        while (i > to - 1) : (i -= 1) w.uids[i] = w.uids[i - 1];
    }
    w.uids[to - 1] = uid;
}

fn removeUid(w: *State, at: usize) void {
    for (at - 1..w.uid_count - 1) |i| w.uids[i] = w.uids[i + 1];
    w.uid_count -= 1;
}

/// Frees what the list holds. The window calls it when it closes.
pub fn free(w: *State) void {
    if (w.templates) |*list| fileio.freeList(plugin.allocator, list);
    w.templates = null;
}

// ---- the rows ----

/// Whether the mouse has left the item above or below, which says to move the dragged scene one place.
/// Returns -1, 1 or 0. Because the scene then sits under the mouse again, the next step needs the mouse to
/// leave it again.
fn dragStep(ctx: imgui.ContextPtr) i32 {
    if (!imgui.api.IsItemActive(ctx) or imgui.api.IsItemHovered(ctx, null)) return 0;
    var mx: f64 = 0;
    var my: f64 = 0;
    imgui.api.GetMousePos(ctx, &mx, &my);
    var left: f64 = 0;
    var top: f64 = 0;
    imgui.api.GetItemRectMin(ctx, &left, &top);
    var right: f64 = 0;
    var bottom: f64 = 0;
    imgui.api.GetItemRectMax(ctx, &right, &bottom);
    if (my < top) return -1;
    if (my > bottom) return 1;
    return 0;
}

fn selectScene(p: *Plugin, position: usize) void {
    p.selectScene(@intCast(position)) catch {
        ui.notice(&p.ui, "There is no scene {d}.", .{position}, true);
    };
}

/// Moves a scene. The lane's points follow, so that the song keeps playing the same scenes. The list moves at
/// once, so that a dragged row stays under the mouse.
fn moveScene(p: *Plugin, from: usize, to: usize) void {
    const count = p.scene_list.count;
    var map: scenes.Mapping = undefined;
    if (!p.moveScene(@intCast(from), @intCast(to), &map)) return;
    moveUid(&p.ui.scenes_panel, from, to);
    const changed = if (scene_lane.target(p)) |t| scene_lane.remapLane(t, count, &map) else 0;
    if (changed > 0) ui.notice(&p.ui, "Moved a scene; {d} lane points moved with it.", .{changed}, false);
}

fn removeScene(p: *Plugin, position: usize) void {
    const count = p.scene_list.count;
    var map: scenes.Mapping = undefined;
    if (!p.removeScene(@intCast(position), &map)) return;
    removeUid(&p.ui.scenes_panel, position);
    const changed = if (scene_lane.target(p)) |t| scene_lane.remapLane(t, count, &map) else 0;
    ui.notice(&p.ui, "Removed scene {d}; {d} lane points moved with it.", .{ position, changed }, false);
}

/// The scene's name: plain text, which becomes a text input on a double click and goes back to text when the
/// player presses Enter or leaves the field. Because a name is read far more often than it is changed, it is
/// not an input by default. Returns whether the name was clicked.
fn nameCell(p: *Plugin, ctx: imgui.ContextPtr, scene: *const scenes.Scene, position: usize, uid: u32) bool {
    const w = &p.ui.scenes_panel;
    if (w.editing != uid) {
        var shown_buf: [scenes.max_name + 16:0]u8 = undefined;
        const name = if (scene.name().len > 0) scene.name() else "(no name)";
        const shown = std.fmt.bufPrintZ(&shown_buf, "{s}##scenename", .{name}) catch "?";
        var flags: c_int = imgui.SelectableFlags_AllowOverlap;
        const clicked = imgui.api.Selectable(ctx, shown, null, &flags, null, null);
        if (imgui.api.IsItemHovered(ctx, null) and imgui.api.IsMouseDoubleClicked(ctx, 0)) {
            w.editing = uid;
            w.focus = true;
            _ = std.fmt.bufPrintZ(&w.edit_text, "{s}", .{scene.name()}) catch {};
        }
        return clicked;
    }
    imgui.api.SetNextItemWidth(ctx, -1);
    // The field takes the keyboard on the frame that it appears, with its text selected.
    if (w.focus) {
        imgui.api.SetKeyboardFocusHere(ctx, null);
        w.focus = false;
    }
    var flags: c_int = imgui.InputTextFlags_AutoSelectAll;
    _ = imgui.api.InputText(ctx, "##name", &w.edit_text, w.edit_text.len, &flags, null);
    if (imgui.api.IsItemDeactivated(ctx) or imgui.api.IsKeyPressed(ctx, imgui.Key_Enter, null) or imgui.api.IsKeyPressed(ctx, imgui.Key_KeypadEnter, null)) {
        w.editing = 0;
        _ = p.scene_list.rename(position, std.mem.sliceTo(&w.edit_text, 0));
    }
    return false;
}

fn sceneRows(p: *Plugin, ctx: imgui.ContextPtr) void {
    const w = &p.ui.scenes_panel;
    const list = p.scene_list;
    const count: usize = list.count;
    ensureUids(w, count);
    const current = p.scene.load(.monotonic);
    var move_from: usize = 0;
    var move_to: usize = 0;
    var remove_at: usize = 0;
    imgui.api.PushStyleColor(ctx, imgui.Col_Header, widgets.faded(theme.amber, 0x70));
    const pushed = widgets.pushLabelFont(ctx);
    var table_flags: c_int = imgui.TableFlags_RowBg | imgui.TableFlags_Borders;
    if (imgui.api.BeginTable(ctx, "##scenetable", 4, &table_flags, null, null, null)) {
        var fixed: c_int = imgui.TableColumnFlags_WidthFixed;
        var stretch: c_int = imgui.TableColumnFlags_WidthStretch;
        var fixed_no_label: c_int = imgui.TableColumnFlags_WidthFixed | imgui.TableColumnFlags_NoHeaderLabel;
        var w_param: f64 = 70;
        var w_scene: f64 = 170;
        var w_remove: f64 = 70;
        imgui.api.TableSetupColumn(ctx, "Param #", &fixed, &w_param, null);
        imgui.api.TableSetupColumn(ctx, "Scene", &fixed, &w_scene, null);
        imgui.api.TableSetupColumn(ctx, "Patch", &stretch, null, null);
        imgui.api.TableSetupColumn(ctx, "##remove", &fixed_no_label, &w_remove, null);
        imgui.api.TableHeadersRow(ctx);
        var position: usize = 1;
        while (position <= count) : (position += 1) {
            const scene = list.get(position) orelse break;
            const uid = w.uids[position - 1];
            // Because the rows change places while one is dragged, each is known by the ID of its scene.
            var id: [16:0]u8 = undefined;
            imgui.api.PushID(ctx, std.fmt.bufPrintZ(&id, "{d}", .{uid}) catch "row");
            imgui.api.TableNextRow(ctx, null, null);
            _ = imgui.api.TableNextColumn(ctx);
            // Because ImGui knows an item by its label, the label must not hold the position: a row that
            // changes its label while it is dragged would lose the mouse, and the window would move instead.
            // The position is drawn over the item afterwards, with the draw list so that the cursor stays put.
            const cell = widgets.cursorScreenPos(ctx);
            // The item spans the row, so that a click anywhere on it selects the scene and a drag from anywhere
            // on it moves the scene; the name and the Remove button are drawn over it and take their own clicks.
            var selected = current == position;
            var flags: c_int = imgui.SelectableFlags_SpanAllColumns | imgui.SelectableFlags_AllowOverlap;
            const clicked = imgui.api.Selectable(ctx, "##grab", &selected, &flags, null, null);
            const step = dragStep(ctx);
            var number: [8:0]u8 = undefined;
            imgui.api.DrawList_AddText(imgui.api.GetWindowDrawList(ctx), cell.x + 4, cell.y, theme.text, std.fmt.bufPrintZ(&number, "{d}", .{position}) catch "");
            const target_position = @as(i64, @intCast(position)) + step;
            if (step != 0 and target_position >= 1 and target_position <= count) {
                move_from = position;
                move_to = @intCast(target_position);
                w.dragged = true;
            }
            // A click that ends a drag does not select the scene.
            if (clicked and !w.dragged) selectScene(p, position);
            _ = imgui.api.TableNextColumn(ctx);
            // A click on the name selects the scene too, and a double click edits the name.
            if (nameCell(p, ctx, scene, position, uid) and !w.dragged) selectScene(p, position);
            _ = imgui.api.TableNextColumn(ctx);
            var label: [scenes.max_name + 1:0]u8 = undefined;
            const patch_name = if (scene.label().len > 0) scene.label() else "(the plugin's state)";
            imgui.api.TextColored(ctx, theme.grey, std.fmt.bufPrintZ(&label, "{s}", .{patch_name}) catch "");
            _ = imgui.api.TableNextColumn(ctx);
            if (imgui.api.SmallButton(ctx, "Remove")) remove_at = position;
            imgui.api.PopID(ctx);
        }
        imgui.api.EndTable(ctx);
    }
    widgets.popFont(ctx, pushed);
    var one: c_int = 1;
    imgui.api.PopStyleColor(ctx, &one);
    if (!imgui.api.IsMouseDown(ctx, 0)) w.dragged = false;
    // Because a move changes the list that the loop above reads, it is applied after the loop.
    if (move_from != 0) {
        moveScene(p, move_from, move_to);
    } else if (remove_at != 0) {
        removeScene(p, remove_at);
    }
}

// ---- the templates ----

/// Keeps the letters, digits, spaces, dashes and underscores, because the name becomes a file name.
fn cleanTemplateName(buf: []u8, name: []const u8) []const u8 {
    var n: usize = 0;
    for (name) |c| {
        if (n == buf.len) break;
        if (std.ascii.isAlphanumeric(c) or c == ' ' or c == '-' or c == '_') {
            buf[n] = c;
            n += 1;
        }
    }
    return std.mem.trim(u8, buf[0..n], " ");
}

fn templateFolder(buf: []u8) ?[]const u8 {
    if (!glue.ready) return null;
    const sep = std.fs.path.sep;
    return std.fmt.bufPrint(buf, "{s}{c}Data{c}Perken{c}vr09{c}scenes", .{ glue.resourcePath(), sep, sep, sep, sep }) catch null;
}

fn templatePath(buf: []u8, folder: []const u8, name: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(buf, "{s}{c}{s}{s}", .{ folder, std.fs.path.sep, name, template_extension }) catch null;
}

fn lessName(_: void, a: []u8, b: []u8) bool {
    return std.ascii.lessThanIgnoreCase(a, b);
}

/// The templates of the folder, read again every second or so.
fn refreshTemplates(w: *State, frame: u32) void {
    if (w.templates != null and frame -% w.templates_at < 60) return;
    free(w);
    w.templates_at = frame;
    var buf: [fileio.max_path]u8 = undefined;
    const folder = templateFolder(&buf) orelse return;
    const list = fileio.listFiles(plugin.allocator, folder, &.{template_extension}) catch return;
    std.mem.sort([]u8, list.items, {}, lessName);
    w.templates = list;
}

fn saveTemplate(p: *Plugin) void {
    const w = &p.ui.scenes_panel;
    var clean_buf: [template_name_cap]u8 = undefined;
    const clean = cleanTemplateName(&clean_buf, std.mem.sliceTo(&w.template_name, 0));
    if (clean.len == 0) {
        ui.notice(&p.ui, "Give the template a name first.", .{}, true);
        return;
    }
    var folder_buf: [fileio.max_path]u8 = undefined;
    const folder = templateFolder(&folder_buf) orelse {
        ui.notice(&p.ui, "REAPER's resource folder is not known.", .{}, true);
        return;
    };
    fileio.makePath(folder) catch {
        ui.notice(&p.ui, "Could not make the templates folder.", .{}, true);
        return;
    };
    var text = std.ArrayList(u8).init(plugin.allocator);
    defer text.deinit();
    var saved: usize = 0;
    var position: usize = 1;
    while (position <= p.scene_list.count) : (position += 1) {
        const scene = p.scene_list.get(position) orelse break;
        // A scene made from the plugin's own state has no library patch, so a template cannot hold it.
        if (scene.patch_id == 0) continue;
        for (scene.name()) |c| text.append(if (c == '\t' or c == '\r' or c == '\n') ' ' else c) catch return;
        text.writer().print("\t{d}\n", .{scene.patch_id}) catch return;
        saved += 1;
    }
    var path_buf: [fileio.max_path]u8 = undefined;
    const path = templatePath(&path_buf, folder, clean) orelse return;
    fileio.writeAll(path, text.items) catch {
        ui.notice(&p.ui, "Could not write the template.", .{}, true);
        return;
    };
    w.templates_at = 0;
    free(w);
    ui.notice(&p.ui, "Saved {d} scenes as the template \"{s}\".", .{ saved, clean }, false);
}

/// Loads a template: it replaces the session's scenes, or goes after them. Each scene is taken from the
/// library, by the patch ID that the template holds.
fn loadTemplate(p: *Plugin, name: []const u8, append: bool) void {
    var folder_buf: [fileio.max_path]u8 = undefined;
    const folder = templateFolder(&folder_buf) orelse return;
    var path_buf: [fileio.max_path]u8 = undefined;
    const path = templatePath(&path_buf, folder, name) orelse return;
    const text = fileio.readAll(plugin.allocator, path) catch {
        ui.notice(&p.ui, "Could not read the template.", .{}, true);
        return;
    };
    defer plugin.allocator.free(text);
    patches_panel.buildRows(p);
    if (!append) {
        p.scene_list.clear();
        p.scene.store(0, .monotonic);
        p.rescanParamValues();
    }
    var missing: usize = 0;
    var lines = std.mem.tokenizeScalar(u8, text, '\n');
    while (lines.next()) |line| {
        const tab = std.mem.lastIndexOfScalar(u8, line, '\t') orelse continue;
        const id = std.fmt.parseInt(u32, std.mem.trim(u8, line[tab + 1 ..], " \r"), 10) catch continue;
        const row = patches_panel.rowByValue(id) orelse {
            missing += 1;
            continue;
        };
        _ = patches_panel.addToScenes(p, row, line[0..tab]);
    }
    if (missing > 0) {
        ui.notice(&p.ui, "Loaded the template \"{s}\"; {d} scenes left out, their patches are not in the library.", .{ name, missing }, true);
    } else {
        ui.notice(&p.ui, "Loaded the template \"{s}\".", .{name}, false);
    }
}

fn drawTemplates(p: *Plugin, ctx: imgui.ContextPtr) void {
    const w = &p.ui.scenes_panel;
    if (!imgui.api.CollapsingHeader(ctx, "Scene templates", null, null)) return;
    imgui.api.SetNextItemWidth(ctx, 240);
    var input_flags: c_int = imgui.InputTextFlags_None;
    _ = imgui.api.InputTextWithHint(ctx, "##templatename", "name of the template", &w.template_name, w.template_name.len, &input_flags, null);
    imgui.api.SameLine(ctx, null, null);
    if (widgets.pushButton(ctx, "Save the scenes as a template", 0)) saveTemplate(p);
    refreshTemplates(w, p.ui.frame);
    const count = if (w.templates) |list| list.items.len else 0;
    if (count == 0) imgui.api.TextColored(ctx, theme.grey, "No templates yet.");
    var list_w: f64 = 460;
    var list_h: f64 = 110;
    if (imgui.api.BeginChild(ctx, "##templates", &list_w, &list_h, null, null)) {
        if (w.templates) |list| {
            for (list.items) |file_name| {
                const name = file_name[0 .. file_name.len - template_extension.len];
                var label: [template_name_cap + 24:0]u8 = undefined;
                var selected = std.mem.eql(u8, std.mem.sliceTo(&w.template_selected, 0), name);
                if (imgui.api.Selectable(ctx, std.fmt.bufPrintZ(&label, "{s}##tpl{s}", .{ name, name }) catch "?", &selected, null, null, null)) {
                    _ = std.fmt.bufPrintZ(&w.template_selected, "{s}", .{name}) catch {};
                    _ = std.fmt.bufPrintZ(&w.template_name, "{s}", .{name}) catch {};
                }
            }
        }
        imgui.api.EndChild(ctx);
    }
    const chosen = std.mem.sliceTo(&w.template_selected, 0);
    if (chosen.len == 0) return;
    if (widgets.pushButton(ctx, "Load, replacing the scenes", 0)) loadTemplate(p, chosen, false);
    imgui.api.SameLine(ctx, null, null);
    if (widgets.pushButton(ctx, "Add to the scenes", 0)) loadTemplate(p, chosen, true);
    imgui.api.SameLine(ctx, null, null);
    if (widgets.pushButton(ctx, "Delete", 0)) {
        var folder_buf: [fileio.max_path]u8 = undefined;
        if (templateFolder(&folder_buf)) |folder| {
            var path_buf: [fileio.max_path]u8 = undefined;
            if (templatePath(&path_buf, folder, chosen)) |path| fileio.deleteFile(path) catch {};
        }
        w.template_selected[0] = 0;
        w.templates_at = 0;
        free(w);
    }
}

// ---- the card ----

/// Puts a square point at the edit cursor on the lane of the Scene parameter, set to the selected scene. The
/// lane is created when the track does not have one yet.
fn insertScenePoint(p: *Plugin) void {
    const current = p.scene.load(.monotonic);
    if (current < 1) {
        ui.notice(&p.ui, "Select a scene first: click its row.", .{}, true);
        return;
    }
    const t = scene_lane.target(p) orelse {
        ui.notice(&p.ui, "REAPER has not said where the plugin is on its track yet.", .{}, true);
        return;
    };
    const time = scene_lane.insertPoint(t, current) orelse {
        ui.notice(&p.ui, "REAPER could not create the lane.", .{}, true);
        return;
    };
    ui.notice(&p.ui, "Inserted scene {d} at {d:.2} s.", .{ current, time }, false);
}

/// The card of the session's scenes.
pub fn draw(p: *Plugin, ctx: imgui.ContextPtr) void {
    if (!widgets.beginCard(ctx, "Scenes of this session", null, null, null)) return;
    defer widgets.endCard(ctx);
    if (p.scene_list.count == 0) {
        imgui.api.TextColored(ctx, theme.grey, "No scenes yet. Press Add on a patch.");
        p.ui.scenes_panel.uid_count = 0;
    } else {
        sceneRows(p, ctx);
    }
    imgui.api.Separator(ctx);
    const current = p.scene.load(.monotonic);
    const scene = p.scene_list.get(current);
    var line: [96:0]u8 = undefined;
    imgui.api.Text(ctx, std.fmt.bufPrintZ(&line, "Scene parameter: {d}  {s}", .{ current, if (scene) |s| s.name() else "(no scene)" }) catch "");
    if (widgets.pushButton(ctx, "Insert a lane point at the cursor", 0)) insertScenePoint(p);
    widgets.tooltip(ctx, "Puts a square point on the Scene parameter's lane at the edit cursor, set to the selected scene. The lane is created if the track does not have one yet.");
    drawTemplates(p, ctx);
}

test "the IDs of the rows follow a move" {
    var w = State{};
    ensureUids(&w, 4);
    try std.testing.expectEqualSlices(u32, &.{ 1, 2, 3, 4 }, w.uids[0..4]);
    moveUid(&w, 1, 3);
    try std.testing.expectEqualSlices(u32, &.{ 2, 3, 1, 4 }, w.uids[0..4]);
    moveUid(&w, 4, 2);
    try std.testing.expectEqualSlices(u32, &.{ 2, 4, 3, 1 }, w.uids[0..4]);
    removeUid(&w, 2);
    try std.testing.expectEqualSlices(u32, &.{ 2, 3, 1 }, w.uids[0..3]);
    try std.testing.expectEqual(@as(usize, 3), w.uid_count);
}

test "a template name keeps only what a file name can hold" {
    var buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings("Sundayset 2", cleanTemplateName(&buf, "  Sunday/set: 2 "));
}

test "every declaration compiles" {
    std.testing.refAllDecls(@This());
}
