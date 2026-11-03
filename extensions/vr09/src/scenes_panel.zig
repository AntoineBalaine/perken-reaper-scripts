//! The session's scenes, ported from the design lab's `panel.lua`: the table of the scenes, with a drag that
//! moves a row, a double click that renames it and a button that removes it; the button that puts a point of
//! the Scene parameter at the edit cursor; and the scene templates.
//!
//! The panel only draws and asks: a click, a drag or a button adds an action to the list, and `dispatch.zig`
//! carries it out, with the points of the Scene lane following a scene that moves or goes (see
//! `scene_lane.zig`).
//!
//! A template is a file of `Data/Perken/vr09/scenes`: the scenes' names and the IDs of their patches, one scene
//! to a line, the two separated by a tab. Because it holds an ID and not the patch, a template follows the
//! library: a patch that is no longer there is counted as missing when the template is read.
const std = @import("std");
const imgui = @import("reaper_imgui");
const plugin = @import("plugin.zig");
const types = @import("action_types.zig");
const strings = @import("strings.zig");
const dispatch = @import("dispatch.zig");
const scenes = @import("scenes.zig");
const fileio = @import("fileio.zig");
const theme = @import("panel_theme");
const widgets = @import("panel_widgets");

const Plugin = plugin.Plugin;

const template_extension = dispatch.template_extension;
const template_name_cap = 64;

/// What the scene list keeps between frames.
pub const State = struct {
    /// Because the rows change places while one is dragged, each is known by an ID of its scene, which moves
    /// with it. The IDs are the panel's own: the plugin's scenes have none.
    uids: [scenes.max_scenes]u32 = @splat(0),
    uid_count: usize = 0,
    next_uid: u32 = 1,
    /// True while a row is dragged, so that the click that ends the drag does not select a scene.
    dragged: bool = false,
    /// The ID of the scene whose name is being edited, or 0, and the text of the field.
    editing: u32 = 0,
    focus: bool = false,
    edit_text: [scenes.max_name:0]u8 = @splat(0),
    template_name: [template_name_cap:0]u8 = @splat(0),
    template_selected: [template_name_cap:0]u8 = @splat(0),
    templates: ?std.ArrayListUnmanaged(strings.Ref) = null,
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
    if (w.templates) |*list| list.deinit(plugin.allocator);
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

/// The action that moves a scene. The list of row IDs moves at once, so that a dragged row stays under the
/// mouse.
fn moveAction(p: *Plugin, from: usize, to: usize) types.Action {
    moveUid(&p.ui.scenes_panel, from, to);
    return .{ .move_scene = .{ .from = @intCast(from), .to = @intCast(to) } };
}

fn removeAction(p: *Plugin, position: usize) types.Action {
    removeUid(&p.ui.scenes_panel, position);
    return .{ .remove_scene = @intCast(position) };
}

/// What a name cell gives back: whether the name was clicked, and the rename that the player has just made.
const NameCell = struct { clicked: bool = false, rename: ?types.Action = null };

/// The scene's name: plain text, which becomes a text input on a double click and goes back to text when the
/// player presses Enter or leaves the field. Because a name is read far more often than it is changed, it is
/// not an input by default. Returns whether the name was clicked.
fn nameCell(p: *Plugin, ctx: imgui.ContextPtr, scene: *const scenes.Scene, position: usize, uid: u32) NameCell {
    const w = &p.ui.scenes_panel;
    if (w.editing != uid) {
        var shown_buf: [scenes.max_name + 16:0]u8 = undefined;
        const name = if (scene.name().len > 0) scene.name() else "(no name)";
        const shown = std.mem.printSentinel(&shown_buf, "{s}##scenename", .{name}, 0) catch "?";
        var flags: c_int = imgui.SelectableFlags_AllowOverlap;
        const clicked = imgui.api.Selectable(ctx, shown, null, &flags, null, null);
        if (imgui.api.IsItemHovered(ctx, null) and imgui.api.IsMouseDoubleClicked(ctx, 0)) {
            w.editing = uid;
            w.focus = true;
            _ = std.mem.printSentinel(&w.edit_text, "{s}", .{scene.name()}, 0) catch {};
        }
        return .{ .clicked = clicked };
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
        return .{ .rename = .{ .rename_scene = .{ .position = @intCast(position), .name = p.strings.intern(std.mem.sliceTo(&w.edit_text, 0)) } } };
    }
    return .{};
}

fn sceneRows(p: *Plugin, ctx: imgui.ContextPtr) ?types.Action {
    const kit = &p.ui.kit;
    const w = &p.ui.scenes_panel;
    const list = p.scene_list;
    const count: usize = list.count;
    ensureUids(w, count);
    const current = p.scene.load(.monotonic);
    var move_from: usize = 0;
    var move_to: usize = 0;
    var remove_at: usize = 0;
    var select_at: usize = 0;
    var rename: ?types.Action = null;
    imgui.api.PushStyleColor(ctx, imgui.Col_Header, widgets.faded(theme.amber, 0x70));
    const pushed = widgets.pushLabelFont(kit);
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
            imgui.api.PushID(ctx, std.mem.printSentinel(&id, "{d}", .{uid}, 0) catch "row");
            imgui.api.TableNextRow(ctx, null, null);
            _ = imgui.api.TableNextColumn(ctx);
            // Because ImGui knows an item by its label, the label must not hold the position: a row that
            // changes its label while it is dragged would lose the mouse, and the window would move instead.
            // The position is drawn over the item afterwards, with the draw list so that the cursor stays put.
            const cell = widgets.cursorScreenPos(kit);
            // The item spans the row, so that a click anywhere on it selects the scene and a drag from anywhere
            // on it moves the scene; the name and the Remove button are drawn over it and take their own clicks.
            var selected = current == position;
            var flags: c_int = imgui.SelectableFlags_SpanAllColumns | imgui.SelectableFlags_AllowOverlap;
            const clicked = imgui.api.Selectable(ctx, "##grab", &selected, &flags, null, null);
            const step = dragStep(ctx);
            var number: [8:0]u8 = undefined;
            imgui.api.DrawList_AddText(imgui.api.GetWindowDrawList(ctx), cell.x + 4, cell.y, theme.text, std.mem.printSentinel(&number, "{d}", .{position}, 0) catch "");
            const target_position = @as(i64, @intCast(position)) + step;
            if (step != 0 and target_position >= 1 and target_position <= count) {
                move_from = position;
                move_to = @intCast(target_position);
                w.dragged = true;
            }
            // A click that ends a drag does not select the scene.
            if (clicked and !w.dragged) select_at = position;
            _ = imgui.api.TableNextColumn(ctx);
            // A click on the name selects the scene too, and a double click edits the name.
            const name_cell = nameCell(p, ctx, scene, position, uid);
            if (name_cell.clicked and !w.dragged) select_at = position;
            rename = types.first(rename, name_cell.rename);
            _ = imgui.api.TableNextColumn(ctx);
            var label: [scenes.max_name + 1:0]u8 = undefined;
            const patch_name = if (scene.label().len > 0) scene.label() else "(the plugin's state)";
            imgui.api.TextColored(ctx, theme.grey, std.mem.printSentinel(&label, "{s}", .{patch_name}, 0) catch "");
            _ = imgui.api.TableNextColumn(ctx);
            if (imgui.api.SmallButton(ctx, "Remove")) remove_at = position;
            imgui.api.PopID(ctx);
        }
        imgui.api.EndTable(ctx);
    }
    widgets.popFont(kit, pushed);
    var one: c_int = 1;
    imgui.api.PopStyleColor(ctx, &one);
    if (!imgui.api.IsMouseDown(ctx, 0)) w.dragged = false;
    // Because a move changes the list that the loop above reads, it is asked for after the loop. The player
    // does one thing at a time, and when a click and a drag meet, the drag is the one that counts.
    if (remove_at != 0) return removeAction(p, remove_at);
    if (move_from != 0) return moveAction(p, move_from, move_to);
    if (rename != null) return rename;
    if (select_at != 0) return .{ .select_scene = @intCast(select_at) };
    return null;
}

// ---- the templates ----

fn templateFolder(buf: []u8) ?[]const u8 {
    return dispatch.templateFolder(buf);
}

fn lessName(_: void, a: [:0]u8, b: [:0]u8) bool {
    return std.ascii.lessThanIgnoreCase(a, b);
}

/// The templates of the folder, read again every second or so.
fn refreshTemplates(io: std.Io, p: *Plugin, w: *State, frame: u32) void {
    if (w.templates != null and frame -% w.templates_at < 60) return;
    free(w);
    w.templates_at = frame;
    var buf: [fileio.max_path]u8 = undefined;
    const folder = templateFolder(&buf) orelse return;
    var files = fileio.listFiles(plugin.allocator, io, folder, &.{template_extension}) catch return;
    defer fileio.freeList(plugin.allocator, &files);
    std.mem.sort([:0]u8, files.items, {}, lessName);
    var refs: std.ArrayListUnmanaged(strings.Ref) = .empty;
    for (files.items) |file_name| {
        refs.append(plugin.allocator, p.strings.intern(file_name)) catch break;
    }
    w.templates = refs;
}

fn drawTemplates(io: std.Io, p: *Plugin, ctx: imgui.ContextPtr) ?types.Action {
    const kit = &p.ui.kit;
    const w = &p.ui.scenes_panel;
    var action: ?types.Action = null;
    if (!imgui.api.CollapsingHeader(ctx, "Scene templates", null, null)) return null;
    imgui.api.SetNextItemWidth(ctx, 240);
    var input_flags: c_int = imgui.InputTextFlags_None;
    _ = imgui.api.InputTextWithHint(ctx, "##templatename", "name of the template", &w.template_name, w.template_name.len, &input_flags, null);
    imgui.api.SameLine(ctx, null, null);
    if (widgets.pushButton(kit, "Save the scenes as a template", 0)) action = .{ .save_template = p.strings.intern(std.mem.sliceTo(&w.template_name, 0)) };
    refreshTemplates(io, p, w, p.ui.frame);
    const count = if (w.templates) |list| list.items.len else 0;
    if (count == 0) imgui.api.TextColored(ctx, theme.grey, "No templates yet.");
    var list_w: f64 = 460;
    var list_h: f64 = 110;
    if (imgui.api.BeginChild(ctx, "##templates", &list_w, &list_h, null, null)) {
        if (w.templates) |list| {
            for (list.items) |ref| {
                // Because nothing is stored in the strings while the list is drawn, the slice stays valid.
                const file_name = p.strings.get(ref);
                const name = file_name[0 .. file_name.len - template_extension.len];
                var label: [template_name_cap + 24:0]u8 = undefined;
                var selected = std.mem.eql(u8, std.mem.sliceTo(&w.template_selected, 0), name);
                if (imgui.api.Selectable(ctx, std.mem.printSentinel(&label, "{s}##tpl{s}", .{ name, name }, 0) catch "?", &selected, null, null, null)) {
                    _ = std.mem.printSentinel(&w.template_selected, "{s}", .{name}, 0) catch {};
                    _ = std.mem.printSentinel(&w.template_name, "{s}", .{name}, 0) catch {};
                }
            }
        }
        imgui.api.EndChild(ctx);
    }
    const chosen = std.mem.sliceTo(&w.template_selected, 0);
    if (chosen.len == 0) return action;
    if (widgets.pushButton(kit, "Load, replacing the scenes", 0)) action = .{ .load_template = .{ .name = p.strings.intern(chosen), .append = false } };
    imgui.api.SameLine(ctx, null, null);
    if (widgets.pushButton(kit, "Add to the scenes", 0)) action = .{ .load_template = .{ .name = p.strings.intern(chosen), .append = true } };
    imgui.api.SameLine(ctx, null, null);
    if (widgets.pushButton(kit, "Delete", 0)) {
        action = .{ .delete_template = p.strings.intern(chosen) };
        w.template_selected[0] = 0;
        w.templates_at = 0;
        free(w);
    }
    return action;
}

// ---- the card ----

/// The card of the session's scenes.
pub fn draw(io: std.Io, p: *Plugin, ctx: imgui.ContextPtr) ?types.Action {
    const kit = &p.ui.kit;
    var action: ?types.Action = null;
    if (!widgets.beginCard(kit, "Scenes of this session", null, null, null)) return null;
    defer widgets.endCard(kit);
    if (p.scene_list.count == 0) {
        imgui.api.TextColored(ctx, theme.grey, "No scenes yet. Press Add on a patch.");
        p.ui.scenes_panel.uid_count = 0;
    } else {
        action = sceneRows(p, ctx);
    }
    imgui.api.Separator(ctx);
    const current = p.scene.load(.monotonic);
    const scene = p.scene_list.get(current);
    var line: [96:0]u8 = undefined;
    imgui.api.Text(ctx, std.mem.printSentinel(&line, "Scene parameter: {d}  {s}", .{ current, if (scene) |s| s.name() else "(no scene)" }, 0) catch "");
    if (widgets.pushButton(kit, "Insert a lane point at the cursor", 0)) action = types.first(action, .insert_lane_point);
    widgets.tooltip(kit, "Puts a square point on the Scene parameter's lane at the edit cursor, set to the selected scene. The lane is created if the track does not have one yet.");
    action = types.first(action, drawTemplates(io, p, ctx));
    return action;
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

test "every declaration compiles" {
    std.testing.refAllDecls(@This());
}
