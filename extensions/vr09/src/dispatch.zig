//! Where the panel's requests become effects.
//!
//! The panel draws and reads, and its draw functions return the `Action` that the player asked for in a frame, if
//! any (see `action_types.zig`). After the frame, `dispatch` carries it out and says what happened in the panel's
//! notice. The functions that do the work are written once, and they can fail: the
//! debug API calls the same ones, and turns their errors into JSON instead of a notice.
//!
//! Because the panel names the actions and never changes the plugin, what an action does can be tested without
//! ImGui.
const std = @import("std");
const Reaper = @import("reaper").reaper;
const plugin = @import("plugin.zig");
const types = @import("action_types.zig");
const library = @import("library.zig");
const scene_lane = @import("scene_lane.zig");
const scenes = @import("scenes.zig");
const state = @import("state.zig");
const fileio = @import("fileio.zig");
const glue = @import("reaper_glue.zig");
const dump = @import("dump.zig");
const engine = @import("engine.zig");
const registrations = @import("registrations.zig");

const Plugin = plugin.Plugin;
const Action = types.Action;
const Patch = types.Patch;

pub const template_extension = ".scenes";
const name_cap = 64;

// ---- carrying out an action ----

/// What has to happen every frame, whatever the player did: a save that waits for the keyboard's read to end.
pub fn tick(p: *Plugin) void {
    const pending = &p.ui.pending_save;
    if (pending.phase == .idle) return;
    const job: engine.JobKind = @enumFromInt(p.shared.job.load(.monotonic));
    if (pending.phase == .waiting_for_start and job != .idle) pending.phase = .waiting_for_end;
    const waited = p.ui.frame -% pending.since;
    if ((pending.phase == .waiting_for_end and job == .idle) or waited > 600) {
        const name = pending.name;
        pending.phase = .idle;
        if (savePreset(p, name.slice())) |saved| {
            say(p, "Read the keyboard and saved it as {s}.", .{saved.slice()}, false);
        } else |err| {
            say(p, "The keyboard was not saved: {s}.", .{describe(err)}, true);
        }
    }
}

fn say(p: *Plugin, comptime fmt: []const u8, args: anytype, is_error: bool) void {
    p.ui.notice(fmt, args, is_error);
}

/// What an error says to the player.
pub fn describe(err: anyerror) []const u8 {
    return switch (err) {
        error.NoResourceFolder => "REAPER's resource folder is not known",
        error.NotSupported => "the panel does not do that with this patch yet",
        error.BadPart => "the part is not one that holds a tone",
        error.SceneListFull => "the scene list is full",
        error.NoSuchScene => "there is no such scene",
        error.NoSceneSelected => "select a scene first: click its row",
        error.NoTrack => "REAPER has not said where the plugin is on its track yet",
        error.NoLane => "REAPER could not create the lane",
        error.EmptyName => "give it a name first",
        error.BadFileName => "the file name does not look like a registration's",
        error.NeedFullPath => "type the full path of the file to write",
        else => @errorName(err),
    };
}

/// Carries out one action.
pub fn dispatch(p: *Plugin, action: Action) void {
    switch (action) {
        .set_param => |s| {
            if (!p.shared.changeParam(s.index, s.value)) say(p, "Too many changes at once, the last one was dropped.", .{}, true);
        },

        .read_keyboard => {
            _ = p.shared.sendCommand(.capture_keyboard);
            say(p, "Reading the keyboard's state into this plugin.", .{}, false);
        },
        .send_to_keyboard => {
            _ = p.shared.sendCommand(.recall);
            say(p, "Writing this plugin's state to the keyboard.", .{}, false);
        },
        .save_keyboard => |name| {
            _ = p.shared.sendCommand(.capture_keyboard);
            p.ui.pending_save = .{ .phase = .waiting_for_start, .since = p.ui.frame, .name = name };
        },
        .send_patch => |patch| {
            sendPatch(p, patch) catch |err| {
                say(p, "Could not send \"{s}\": {s}.", .{ patch.name.slice(), describe(err) }, err != error.NotSupported);
                return;
            };
            say(p, "Sent \"{s}\" to the keyboard.", .{patch.name.slice()}, false);
        },
        .delete_preset => |file| {
            deletePreset(p, file.slice()) catch |err| {
                say(p, "Could not delete {s}: {s}.", .{ file.slice(), describe(err) }, true);
                return;
            };
            say(p, "Deleted {s}.", .{state.displayName(file.slice())}, false);
        },
        .import_file => {
            const imported = importFile(p) catch |err| {
                say(p, "Could not import the file: {s}.", .{describe(err)}, true);
                return;
            };
            if (imported) |name| say(p, "Imported {s}.", .{name.slice()}, false);
        },
        .export_file => |path| {
            exportFile(p, path.slice()) catch |err| {
                say(p, "Could not write the file: {s}.", .{describe(err)}, true);
                return;
            };
            say(p, "Exported to {s}.", .{path.slice()}, false);
        },

        .add_scene => |patch| {
            const position = addScene(p, patch) catch |err| {
                say(p, "Could not add \"{s}\" to the scenes: {s}.", .{ patch.name.slice(), describe(err) }, err != error.NotSupported);
                return;
            };
            say(p, "Added \"{s}\" as scene {d}.", .{ patch.name.slice(), position }, false);
        },
        .select_scene => |position| {
            p.selectScene(position) catch {
                say(p, "There is no scene {d}.", .{position}, true);
            };
        },
        .move_scene => |m| {
            const moved = moveSceneWithLane(p, m.from, m.to) catch |err| {
                say(p, "Could not move the scene: {s}.", .{describe(err)}, true);
                return;
            };
            if (moved > 0) say(p, "Moved a scene; {d} lane points moved with it.", .{moved}, false);
        },
        .remove_scene => |position| {
            const moved = removeSceneWithLane(p, position) catch |err| {
                say(p, "Could not remove the scene: {s}.", .{describe(err)}, true);
                return;
            };
            say(p, "Removed scene {d}; {d} lane points moved with it.", .{ position, moved }, false);
        },
        .rename_scene => |r| {
            _ = p.scene_list.rename(r.position, r.name.slice());
        },
        .insert_lane_point => {
            const point = insertLanePoint(p) catch |err| {
                say(p, "Could not insert a point: {s}.", .{describe(err)}, true);
                return;
            };
            say(p, "Inserted scene {d} at {d:.2} s.", .{ point.position, point.time }, false);
        },
        .save_template => |name| {
            const saved = saveTemplate(p, name.slice()) catch |err| {
                say(p, "Could not save the template: {s}.", .{describe(err)}, true);
                return;
            };
            say(p, "Saved {d} scenes as the template \"{s}\".", .{ saved.scenes, saved.name.slice() }, false);
        },
        .load_template => |t| {
            const missing = loadTemplate(p, t.name.slice(), t.append) catch |err| {
                say(p, "Could not read the template: {s}.", .{describe(err)}, true);
                return;
            };
            if (missing > 0) {
                say(p, "Loaded the template \"{s}\"; {d} scenes left out, their patches are not in the library.", .{ t.name.slice(), missing }, true);
            } else {
                say(p, "Loaded the template \"{s}\".", .{t.name.slice()}, false);
            }
        },
        .delete_template => |name| {
            deleteTemplate(name.slice()) catch |err| say(p, "Could not delete the template: {s}.", .{describe(err)}, true);
        },

        .set_split => |on| plugin.setPatchSplit(p, on),
        .set_follow_panel => |on| p.shared.follow_panel.store(on, .monotonic),
        .set_recall_on_load => |on| p.shared.recall_on_load.store(on, .monotonic),

        .set_loop_enabled => |on| p.setLoopEnabled(on),
        .set_send_db => |db| p.settings.setSendDb(@floatFromInt(db)),
        .set_return_db => |db| p.settings.setReturnDb(@floatFromInt(db)),
        .set_out_channel => |channel| {
            p.settings.out_channel.store(channel, .monotonic);
            p.applyLoopSettings();
        },
        .set_in_channel => |channel| {
            p.settings.in_channel.store(channel, .monotonic);
            p.applyLoopSettings();
        },
        .measure_latency => p.startPing(),

        .set_midi_output => |device| {
            glue.setTrackMidiOutput(p.track, device);
            p.settings.autoconnect_done.store(true, .monotonic);
        },
        .set_midi_input => |device| glue.setTrackMidiInput(p.track, device),
        .set_armed => |on| glue.setTrackArmed(p.track, on),
        .set_monitoring => |on| glue.setTrackMonitoring(p.track, if (on) 1 else 0),
        .set_pass_midi => |on| p.settings.pass_midi.store(on, .monotonic),
        .set_sysex_bare => |on| p.settings.sysex_bare.store(on, .monotonic),
        .reconnect => {
            _ = p.shared.sendCommand(.reconnect);
            p.settings.autoconnect_done.store(false, .monotonic);
            p.ticks = 0;
            say(p, "Asking the keyboard who it is.", .{}, false);
        },

        .notify => |n| say(p, "{s}", .{n.text.slice()}, n.is_error),
    }
}

// ---- the folders ----

const Folder = enum { registrations, presets, templates };

fn folderOf(buf: []u8, which: Folder) ![]const u8 {
    if (!glue.ready) return error.NoResourceFolder;
    return switch (which) {
        .registrations => state.registrationFolder(buf, glue.resourcePath()),
        .presets => state.presetFolder(buf, glue.resourcePath()),
        .templates => std.fmt.bufPrint(buf, "{s}{c}Data{c}Perken{c}vr09{c}scenes", .{ glue.resourcePath(), std.fs.path.sep, std.fs.path.sep, std.fs.path.sep, std.fs.path.sep }),
    };
}

/// The folder of the scene templates, or null when REAPER's resource folder is not known.
pub fn templateFolder(buf: []u8) ?[]const u8 {
    return folderOf(buf, .templates) catch null;
}

fn pathIn(buf: []u8, folder: []const u8, file_name: []const u8) ![]const u8 {
    return std.fmt.bufPrint(buf, "{s}{c}{s}", .{ folder, std.fs.path.sep, file_name });
}

// ---- patches ----

/// Reads the bytes of a patch into `out`.
pub fn loadPatchDump(p: *Plugin, source: types.PatchSource, out: *dump.Dump) !void {
    switch (source) {
        .current => p.shared.desiredSnapshot(out),
        .registration => |file| try readFile(.registrations, file.slice(), out),
        .preset => |file| try readFile(.presets, file.slice(), out),
        .tone => |t| {
            if (!scenes.toneDump(out, t.part.slice(), t.number, t.msb, t.lsb)) return error.BadPart;
        },
        .unsupported => return error.NotSupported,
    }
}

fn readFile(which: Folder, file_name: []const u8, out: *dump.Dump) !void {
    var folder_buf: [fileio.max_path]u8 = undefined;
    const folder = try folderOf(&folder_buf, which);
    var path_buf: [fileio.max_path]u8 = undefined;
    try state.loadPresetFile(plugin.allocator, try pathIn(&path_buf, folder, file_name), out);
}

/// Sends a patch to the keyboard: a registration or a preset is loaded from its file, and a tone is written to
/// its part.
pub fn sendPatch(p: *Plugin, patch: Patch) !void {
    switch (patch.source) {
        .registration => |file| {
            const parsed = registrations.parseFileName(file.slice()) orelse return error.BadFileName;
            var owned: [types.text_cap]u8 = undefined;
            @memcpy(owned[0..file.len], file.slice());
            const file_name = owned[0..file.len];
            const entry = registrations.Entry{
                .bank = parsed.bank,
                .slot = parsed.slot,
                .file_name = file_name,
                .name = file_name[file_name.len - registrations.extension.len - parsed.name.len .. file_name.len - registrations.extension.len],
            };
            try p.loadRegistration(entry);
        },
        .preset => |file| try loadPreset(p, file.slice()),
        .tone => {
            const patch_dump = try plugin.allocator.create(dump.Dump);
            defer plugin.allocator.destroy(patch_dump);
            patch_dump.* = .{};
            try loadPatchDump(p, patch.source, patch_dump);
            p.loadScene(patch_dump, patch.name.slice());
        },
        .current, .unsupported => return error.NotSupported,
    }
}

/// Puts a patch at the end of the session's scenes. Returns the scene's position.
pub fn addScene(p: *Plugin, patch: Patch) !u8 {
    const patch_dump = try plugin.allocator.create(dump.Dump);
    defer plugin.allocator.destroy(patch_dump);
    patch_dump.* = .{};
    try loadPatchDump(p, patch.source, patch_dump);
    return p.scene_list.addFrom(patch.name.slice(), patch_dump, patch.id, patch.label.slice()) catch error.SceneListFull;
}

// ---- presets and files ----

fn loadPreset(p: *Plugin, file_name: []const u8) !void {
    var folder_buf: [fileio.max_path]u8 = undefined;
    const folder = try folderOf(&folder_buf, .presets);
    var path_buf: [fileio.max_path]u8 = undefined;
    const path = try state.presetPath(&path_buf, folder, file_name);
    try p.loadPresetFile(path, state.displayName(file_name));
}

fn deletePreset(p: *Plugin, file_name: []const u8) !void {
    var folder_buf: [fileio.max_path]u8 = undefined;
    const folder = try folderOf(&folder_buf, .presets);
    var path_buf: [fileio.max_path]u8 = undefined;
    try fileio.deleteFile(try state.presetPath(&path_buf, folder, file_name));
    p.ui.preset_refresh_at = 0;
}

/// Writes what the plugin holds as a preset of this name. Returns the name that was used, which is the name
/// cleaned of what a file name cannot hold.
fn savePreset(p: *Plugin, wanted: []const u8) !types.Text {
    var clean: [name_cap]u8 = undefined;
    const name = state.sanitizeName(&clean, wanted);
    if (name.len == 0) return error.EmptyName;
    var folder_buf: [fileio.max_path]u8 = undefined;
    const folder = try folderOf(&folder_buf, .presets);
    try fileio.makePath(folder);
    var path_buf: [fileio.max_path]u8 = undefined;
    const path = try state.presetPath(&path_buf, folder, name);
    const snapshot = try plugin.allocator.create(dump.Dump);
    defer plugin.allocator.destroy(snapshot);
    p.shared.desiredSnapshot(snapshot);
    try state.savePresetFile(plugin.allocator, path, snapshot);
    p.settings.setPresetName(name);
    p.ui.preset_refresh_at = 0;
    return types.Text.of(name);
}

/// Asks for a file with REAPER's dialog and loads it. Returns its name, or null when the player cancelled.
fn importFile(p: *Plugin) !?types.Text {
    if (!glue.ready) return error.NoResourceFolder;
    var path: [4096]u8 = [_]u8{0} ** 4096;
    if (!Reaper.GetUserFileNameForRead(@ptrCast(&path), "Import a VR-09 dump or preset", "json")) return null;
    const chosen = std.mem.sliceTo(&path, 0);
    try p.loadPresetFile(chosen, state.displayName(std.fs.path.basename(chosen)));
    return types.Text.of(std.fs.path.basename(chosen));
}

fn exportFile(p: *Plugin, target: []const u8) !void {
    if (target.len == 0 or !std.fs.path.isAbsolute(target)) return error.NeedFullPath;
    const snapshot = try plugin.allocator.create(dump.Dump);
    defer plugin.allocator.destroy(snapshot);
    p.shared.desiredSnapshot(snapshot);
    try state.savePresetFile(plugin.allocator, target, snapshot);
}

// ---- scenes ----

/// Moves a scene, and the points of the Scene lane with it. Returns how many points moved.
pub fn moveSceneWithLane(p: *Plugin, from: u8, to: u8) !usize {
    const count = p.scene_list.count;
    var map: scenes.Mapping = undefined;
    if (!p.moveScene(from, to, &map)) return error.NoSuchScene;
    const target = scene_lane.target(p) orelse return 0;
    return scene_lane.remapLane(target, count, &map);
}

/// Removes a scene, and moves the points of the Scene lane with the scenes that follow. Returns how many points
/// moved.
pub fn removeSceneWithLane(p: *Plugin, position: u8) !usize {
    const count = p.scene_list.count;
    var map: scenes.Mapping = undefined;
    if (!p.removeScene(position, &map)) return error.NoSuchScene;
    const target = scene_lane.target(p) orelse return 0;
    return scene_lane.remapLane(target, count, &map);
}

pub const LanePoint = struct { position: u8, time: f64 };

/// Puts a square point at the edit cursor on the lane of the Scene parameter, set to the selected scene.
pub fn insertLanePoint(p: *Plugin) !LanePoint {
    const current = p.scene.load(.monotonic);
    if (current < 1) return error.NoSceneSelected;
    const target = scene_lane.target(p) orelse return error.NoTrack;
    const time = scene_lane.insertPoint(target, current) orelse return error.NoLane;
    return .{ .position = current, .time = time };
}

// ---- the scene templates ----

/// Keeps the letters, digits, spaces, dashes and underscores, because the name becomes a file name.
pub fn cleanTemplateName(buf: []u8, name: []const u8) []const u8 {
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

fn templatePath(buf: []u8, folder: []const u8, name: []const u8) ![]const u8 {
    return std.fmt.bufPrint(buf, "{s}{c}{s}{s}", .{ folder, std.fs.path.sep, name, template_extension });
}

pub const SavedTemplate = struct { name: types.Text, scenes: usize };

/// The text of a template: a line for each scene that came from the library, the name and the patch ID
/// separated by a tab. A scene made from the plugin's own state has no library patch, so a template cannot hold it.
pub fn templateText(list: *const scenes.List, out: *std.ArrayList(u8)) !usize {
    var written: usize = 0;
    var position: usize = 1;
    while (position <= list.count) : (position += 1) {
        const scene = list.get(position) orelse break;
        if (scene.patch_id == 0) continue;
        for (scene.name()) |c| try out.append(if (c == '\t' or c == '\r' or c == '\n') ' ' else c);
        try out.writer().print("\t{d}\n", .{scene.patch_id});
        written += 1;
    }
    return written;
}

fn saveTemplate(p: *Plugin, wanted: []const u8) !SavedTemplate {
    var clean_buf: [name_cap]u8 = undefined;
    const clean = cleanTemplateName(&clean_buf, wanted);
    if (clean.len == 0) return error.EmptyName;
    var folder_buf: [fileio.max_path]u8 = undefined;
    const folder = try folderOf(&folder_buf, .templates);
    try fileio.makePath(folder);
    var text = std.ArrayList(u8).init(plugin.allocator);
    defer text.deinit();
    const written = try templateText(p.scene_list, &text);
    var path_buf: [fileio.max_path]u8 = undefined;
    try fileio.writeAll(try templatePath(&path_buf, folder, clean), text.items);
    return .{ .name = types.Text.of(clean), .scenes = written };
}

/// Loads a template: it replaces the session's scenes, or goes after them. Each scene is taken from the
/// library, by the patch ID that the template holds. Returns how many lines were left out because their patch
/// is not in the library.
fn loadTemplate(p: *Plugin, name: []const u8, append: bool) !usize {
    var folder_buf: [fileio.max_path]u8 = undefined;
    const folder = try folderOf(&folder_buf, .templates);
    var path_buf: [fileio.max_path]u8 = undefined;
    const text = try fileio.readAll(plugin.allocator, try templatePath(&path_buf, folder, name));
    defer plugin.allocator.free(text);
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
        var patch = library.patchById(p, id) orelse {
            missing += 1;
            continue;
        };
        patch.name = types.Text.of(line[0..tab]);
        _ = addScene(p, patch) catch continue;
    }
    return missing;
}

fn deleteTemplate(name: []const u8) !void {
    var folder_buf: [fileio.max_path]u8 = undefined;
    const folder = try folderOf(&folder_buf, .templates);
    var path_buf: [fileio.max_path]u8 = undefined;
    try fileio.deleteFile(try templatePath(&path_buf, folder, name));
}

test "a template name keeps only what a file name can hold" {
    var buf: [64]u8 = undefined;
    try std.testing.expectEqualStrings("Sundayset 2", cleanTemplateName(&buf, "  Sunday/set: 2 "));
}

test "every declaration compiles" {
    std.testing.refAllDecls(@This());
}
