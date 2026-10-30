//! perken-utilities: editing helpers for REAPER as a compiled extension.
//!
//! Every action in the modules' `entries` tables is registered as a REAPER
//! action named "Perken: <description>" with the command id
//! `_PERKEN_<name>`, so that it shows up in the action list and can be bound
//! from any keymap, including reavim-ext's bindings.ini. Actions flagged
//! `midi_command` are registered in the MIDI editor section.
const std = @import("std");
const globals = @import("globals.zig");
const host_io = @import("host_io");
const build_options = @import("build_options");
const Reaper = @import("reaper").reaper;
const logger = @import("logger.zig");
const actions = @import("actions.zig");
const drums = @import("drums.zig");
const kawa = @import("kawa.zig");
const routing = @import("routing.zig");
const fx = @import("fx.zig");
const items = @import("items.zig");
const tracks = @import("tracks.zig");
const envelope = @import("envelope.zig");
const keysnap = @import("keysnap.zig");
const batch_rename = @import("batch_rename.zig");
const action_search = @import("action_search.zig");
const action_palette = @import("action_palette.zig");
const auto_lane_watcher = @import("auto_lane_watcher.zig");
const surface = @import("surface.zig");
const tempo_window = @import("beat/tempo_window.zig");
const abc_export = @import("abc_export.zig");
const rhythm_action = @import("rhythm_action.zig");
const paste_rhythm = @import("paste_rhythm.zig");
const terminal = @import("terminal.zig");

pub const std_options = std.Options{
    .log_level = switch (@import("builtin").mode) {
        .debug => .debug,
        .safe => .info,
        .fast => .warn,
        .small => .err,
    },
    .logFn = logger.logFn,
};

const log = std.log.scoped(.extension);

// REAPER API functions this extension uses — resolved selectively at load
// (reaziglib.reaper.initSubset). This covers the action modules and the
// shared reaper_helpers module from reaziglib.
const reaper_api = [_][:0]const u8{
    "AddMediaItemToTrack",           "CountEnvelopePoints",              "CountSelectedMediaItems",
    "CountSelectedTracks",           "CountTakes",                       "CountTracks",
    "CreateTrackSend",               "DeleteEnvelopePointRange",         "DeleteTrack",
    "EnumProjectMarkers",            "EnumProjects",                     "GetProjectPath",
    "GetActiveTake",                 "GetCursorPosition",                "GetEnvelopePoint",
    "GetEnvelopeScalingMode",        "GetEnvelopeStateChunk",            "GetExtState",
    "GetItemStateChunk",             "GetLastMarkerAndCurRegion",        "GetMediaItemInfo_Value",
    "GetMediaItemTakeInfo_Value",    "GetMediaTrackInfo_Value",          "GetParentTrack",
    "GetProjectLength",              "GetResourcePath",                  "GetSelectedEnvelope",
    "GetSelectedMediaItem",          "GetSelectedTrack",                 "GetSetMediaTrackInfo_String",
    "GetSet_LoopTimeRange",          "GetTake",                          "GetToggleCommandStateEx",
    "GetTrack",                      "GetTrackMediaItem",                "GetTrackNumMediaItems",
    "GetTrackNumSends",              "GetUserInputs",                    "InsertEnvelopePoint",
    "InsertTrackAtIndex",            "IsMediaItemSelected",              "kbd_enumerateActions",
    "SectionFromUniqueID",           "MIDIEditor_GetActive",             "MIDI_GetGrid",
    "MIDIEditor_GetTake",            "MIDIEditor_LastFocused_OnCommand", "MIDIEditor_OnCommand",
    "MIDI_CountEvts",                "MIDI_GetNote",                     "MIDI_GetPPQPosFromProjQN",
    "MIDI_GetProjQNFromPPQPos",      "MIDI_GetProjTimeFromPPQPos",       "MIDI_InsertNote",
    "MIDI_SetNote",                  "MIDI_Sort",                        "Main_OnCommand",
    "MIDI_GetPPQPos_StartOfMeasure", "MoveEditCursor",                   "NamedCommandLookup",
    "PreventUIRefresh",              "ScaleToEnvelopeMode",              "SetEnvelopePoint",
    "SetExtState",                   "SetItemStateChunk",                "SetMediaItemInfo_Value",
    "SetMediaItemTakeInfo_Value",    "SetMediaTrackInfo_Value",          "ShowMessageBox",
    "SnapToGrid",                    "SplitMediaItem",                   "TakeIsMIDI",
    "TimeMap2_beatsToTime",          "TrackFX_GetFXName",                "TrackFX_GetInstrument",
    "TrackFX_GetPreset",             "Undo_BeginBlock",                  "Undo_EndBlock",
    "UpdateArrange",                 "UpdateItemInProject",              "get_config_var",
    "plugin_register",               "plugin_getapi",                    "GetFXEnvelope",
    "GetGlobalAutomationOverride",   "TrackFX_GetParam",                 "SetOnlyTrackSelected",
    "CountTrackEnvelopes",           "GetTrackEnvelope",                 "Envelope_GetParentTrack",
    "GetLastTouchedFX",              "CreateTakeAudioAccessor",          "GetAudioAccessorSamples",
    "DestroyAudioAccessor",          "GetAudioAccessorStartTime",        "GetAudioAccessorEndTime",
    "GetMediaItemTake_Source",       "GetMediaSourceNumChannels",        "SetTakeMarker",
    "DeleteTakeMarker",              "GetNumTakeMarkers",                "GetTakeMarker",
    "ValidatePtr2",                  "GetTakeName",                      "TimeMap2_timeToQN",
    "TimeMap2_QNToTime",             "TimeMap2_timeToBeats",             "GetTakeNumStretchMarkers",
    "SetTakeStretchMarker",          "CountTempoTimeSigMarkers",         "GetMediaItemTake_Item",
    "SetCurrentBPM",                 "TimeMap2_GetDividedBpmAtTime",     "SetTempoTimeSigMarker",
    "UpdateTimeline",                "TimeMap_GetTimeSigAtTime",         "AddProjectMarker2",
    "SetProjectMarker",              "GetMediaSourceFileName",           "MIDI_DeleteNote",
    "GetMediaItemNumTakes",          "GetMediaItemTake",                 "SetActiveTake",
};

/// Every action this extension provides.
pub const all_entries = drums.entries ++ kawa.entries ++ routing.entries ++ fx.entries ++
    items.entries ++ tracks.entries ++ envelope.entries ++ keysnap.entries ++ batch_rename.entries ++
    auto_lane_watcher.entries ++ tempo_window.entries ++ action_search.entries ++
    action_palette.entries ++ abc_export.entries ++ terminal.entries ++
    rhythm_action.entries ++ paste_rhythm.entries;

const main_section: c_int = 0;
const midi_editor_section: c_int = 32060;

/// The custom_action registrations, built at compile time so that the id and
/// name strings live for the whole session, as REAPER requires.
const registrations = blk: {
    var regs: [all_entries.len]Reaper.custom_action_register_t = undefined;
    // Because Zig 0.17's formatter spends more branches per comptimePrint, the
    // quota grows with the number of actions.
    @setEvalBranchQuota(all_entries.len * 2000);
    for (all_entries, 0..) |e, i| {
        regs[i] = .{
            .section = if (e.def.midi_command) midi_editor_section else main_section,
            .id_str = std.fmt.comptimePrint("PERKEN_{s}", .{e.name}),
            .name = std.fmt.comptimePrint("Perken: {s}", .{e.def.desc orelse e.name}),
        };
    }
    break :blk regs;
};

/// Command ids REAPER assigned to the registrations, in the same order.
var cmd_ids: [all_entries.len]c_int = @splat(0);

export fn ReaperPluginEntry(instance: Reaper.HINSTANCE, rec: ?*Reaper.plugin_info_t) c_int {
    _ = instance;

    if (rec == null) {
        // Unload: make sure REAPER no longer holds our control surface.
        while (surface.holders > 0) surface.release();
        tempo_window.stopTimer();
        tempo_window.discardJob();
        globals.io_threaded.deinit();
        // Because a freed instance must not be used again, the single-threaded default takes its place.
        globals.io_threaded = .init_single_threaded;
        return 0;
    }

    globals.io_threaded = host_io.create();

    if (!Reaper.initSubset(rec.?, &reaper_api))
        return 0;

    for (&registrations, 0..) |*reg, i| {
        cmd_ids[i] = Reaper.plugin_register("custom_action", @ptrCast(@constCast(reg)));
        if (cmd_ids[i] == 0) log.err("failed to register action {s}", .{reg.id_str});
    }
    _ = Reaper.plugin_register("hookcommand2", @ptrCast(@constCast(&onCommand)));
    _ = Reaper.plugin_register("toggleaction", @ptrCast(@constCast(&toggleActionHook)));

    log.info("v{s} loaded {d} actions (search \"Perken:\" in the action list)", .{ build_options.version, all_entries.len });
    return 1;
}

fn onCommand(sec: ?Reaper.KbdSectionInfo, command: c_int, val: c_int, val2hw: c_int, relmode: c_int, hwnd: Reaper.HWND) callconv(.c) c_char {
    _ = .{ sec, val, val2hw, relmode, hwnd };
    if (command == 0) return 0;
    for (cmd_ids, 0..) |id, i| {
        if (id != command) continue;
        const def = &all_entries[i].def;
        // Switching a mode on or off (a toggle action) changes no project
        // state, so it gets no undo point.
        if (def.toggle_state != null) {
            actions.run(def);
            return 1;
        }
        Reaper.Undo_BeginBlock();
        actions.run(def);
        // The undo point carries the action's name from the action list.
        Reaper.Undo_EndBlock(registrations[i].name, -1);
        Reaper.UpdateArrange();
        return 1;
    }
    return 0;
}

/// Reports on/off actions' state: -1 = not ours or not a toggle, 0 = off,
/// 1 = on.
fn toggleActionHook(command_id: c_int) callconv(.c) c_int {
    if (command_id == 0) return -1;
    for (cmd_ids, 0..) |id, i| {
        if (id != command_id) continue;
        const state = all_entries[i].def.toggle_state orelse return -1;
        return if (state()) 1 else 0;
    }
    return -1;
}

test {
    _ = @import("actions.zig");
    _ = @import("surface.zig");
    _ = @import("sws.zig");
    _ = @import("auto_lane_watcher.zig");
    _ = @import("beat/beat.zig");
    _ = @import("beat/grid.zig");
    _ = @import("beat/commit.zig");
    _ = @import("beat/tempo_window.zig");
    _ = @import("config.zig");
    _ = @import("drums.zig");
    _ = @import("kawa.zig");
    _ = @import("routing.zig");
    _ = @import("fx.zig");
    _ = @import("items.zig");
    _ = @import("tracks.zig");
    _ = @import("envelope.zig");
    _ = @import("keysnap.zig");
    _ = @import("batch_rename.zig");
    _ = @import("action_search.zig");
    _ = @import("action_palette.zig");
    _ = @import("abc_export.zig");
    _ = @import("terminal.zig");
    _ = @import("rational.zig");
    _ = @import("paste_rhythm.zig");
    _ = @import("meter.zig");
    _ = @import("rhythm_simplify.zig");
    _ = @import("hegel.zig");
    _ = @import("timemap.zig");
    _ = @import("rhythm_action.zig");
    _ = @import("rhythm_simplify_pbt.zig");
}

test "every action gets a unique command id string" {
    for (all_entries, 0..) |a, i| {
        for (all_entries[i + 1 ..]) |b| {
            try std.testing.expect(!std.mem.eql(u8, a.name, b.name));
        }
    }
}

test "every REAPER function the sources call is in reaper_api" {
    const io = std.testing.io;
    // Because initSubset leaves an unlisted function as a null pointer, a
    // forgotten name compiles fine and then crashes REAPER when the action
    // runs. This test reads the sources and fails on such a name instead.
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var unlisted: std.ArrayList([]const u8) = .empty;
    defer unlisted.deinit(std.testing.allocator);
    const api = @import("reaper");
    try api.unlistedCallsInPaths(arena.allocator(), std.testing.allocator, io, &.{ @import("test_paths").src_dir, @import("test_paths").reaper_helpers }, &reaper_api, &unlisted);
    for (unlisted.items) |name| std.debug.print("REAPER function used but missing from reaper_api: {s}\n", .{name});
    try std.testing.expectEqual(@as(usize, 0), unlisted.items.len);
}
