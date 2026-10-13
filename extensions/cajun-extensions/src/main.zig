//! cajun-extensions: editing helpers for REAPER as a compiled extension.
//!
//! Every action in the modules' `entries` tables is registered as a REAPER
//! action named "Cajun: <description>" with the command id
//! `_CAJUN_<name>`, so that it shows up in the action list and can be bound
//! from any keymap, including reavim-ext's bindings.ini. Actions flagged
//! `midi_command` are registered in the MIDI editor section.
const std = @import("std");
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
const auto_lane_watcher = @import("auto_lane_watcher.zig");
const surface = @import("surface.zig");

pub const std_options = std.Options{
    .log_level = switch (@import("builtin").mode) {
        .Debug => .debug,
        .ReleaseSafe => .info,
        .ReleaseFast => .warn,
        .ReleaseSmall => .err,
    },
    .logFn = logger.logFn,
};

const log = std.log.scoped(.extension);

// REAPER API functions this extension uses — resolved selectively at load
// (reaziglib.reaper.initSubset). This covers the action modules and the
// shared reaper_helpers module from reaziglib.
const reaper_api = [_][:0]const u8{
    "AddMediaItemToTrack",         "CountEnvelopePoints",        "CountSelectedMediaItems",
    "CountSelectedTracks",         "CountTakes",                 "CountTracks",
    "CreateTrackSend",             "DeleteEnvelopePointRange",   "DeleteTrack",
    "EnumProjectMarkers",          "GetActiveTake",              "GetCursorPosition",
    "GetEnvelopePoint",            "GetEnvelopeScalingMode",     "GetEnvelopeStateChunk",
    "GetExtState",                 "GetItemStateChunk",          "GetLastMarkerAndCurRegion",
    "GetMediaItemInfo_Value",      "GetMediaItemTakeInfo_Value", "GetMediaTrackInfo_Value",
    "GetParentTrack",              "GetProjectLength",           "GetResourcePath",
    "GetSelectedEnvelope",         "GetSelectedMediaItem",       "GetSelectedTrack",
    "GetSetMediaTrackInfo_String", "GetSet_LoopTimeRange",       "GetTake",
    "GetToggleCommandStateEx",     "GetTrack",                   "GetTrackMediaItem",
    "GetTrackNumMediaItems",       "GetTrackNumSends",           "GetUserInputs",
    "InsertEnvelopePoint",         "InsertTrackAtIndex",         "IsMediaItemSelected",
    "MIDIEditor_GetActive",        "MIDIEditor_GetTake",         "MIDIEditor_LastFocused_OnCommand",
    "MIDIEditor_OnCommand",        "MIDI_CountEvts",             "MIDI_GetNote",
    "MIDI_GetPPQPosFromProjQN",    "MIDI_GetProjQNFromPPQPos",   "MIDI_GetProjTimeFromPPQPos",
    "MIDI_InsertNote",             "MIDI_SetNote",               "MIDI_Sort",
    "Main_OnCommand",              "MoveEditCursor",             "NamedCommandLookup",
    "PreventUIRefresh",            "ScaleToEnvelopeMode",        "SetEnvelopePoint",
    "SetExtState",                 "SetItemStateChunk",          "SetMediaItemInfo_Value",
    "SetMediaItemTakeInfo_Value",  "SetMediaTrackInfo_Value",    "ShowMessageBox",
    "SnapToGrid",                  "SplitMediaItem",             "TakeIsMIDI",
    "TimeMap2_beatsToTime",        "TrackFX_GetFXName",          "TrackFX_GetInstrument",
    "TrackFX_GetPreset",           "Undo_BeginBlock",            "Undo_EndBlock",
    "UpdateArrange",               "UpdateItemInProject",        "get_config_var",
    "plugin_register",             "plugin_getapi",              "GetFXEnvelope",
    "GetGlobalAutomationOverride", "TrackFX_GetParam",           "SetOnlyTrackSelected",
    "CountTrackEnvelopes",         "GetTrackEnvelope",           "Envelope_GetParentTrack",
    "GetLastTouchedFX",
};

/// Every action this extension provides.
pub const all_entries = drums.entries ++ kawa.entries ++ routing.entries ++ fx.entries ++
    items.entries ++ tracks.entries ++ envelope.entries ++ keysnap.entries ++ batch_rename.entries ++
    auto_lane_watcher.entries;

const main_section: c_int = 0;
const midi_editor_section: c_int = 32060;

/// The custom_action registrations, built at compile time so that the id and
/// name strings live for the whole session, as REAPER requires.
const registrations = blk: {
    var regs: [all_entries.len]Reaper.custom_action_register_t = undefined;
    for (all_entries, 0..) |e, i| {
        regs[i] = .{
            .section = if (e.def.midi_command) midi_editor_section else main_section,
            .id_str = std.fmt.comptimePrint("CAJUN_{s}", .{e.name}),
            .name = std.fmt.comptimePrint("Cajun: {s}", .{e.def.desc orelse e.name}),
        };
    }
    break :blk regs;
};

/// Command ids REAPER assigned to the registrations, in the same order.
var cmd_ids = [_]c_int{0} ** all_entries.len;

export fn ReaperPluginEntry(instance: Reaper.HINSTANCE, rec: ?*Reaper.plugin_info_t) c_int {
    _ = instance;

    if (rec == null) {
        // Unload: make sure REAPER no longer holds our control surface.
        while (surface.holders > 0) surface.release();
        return 0;
    }

    if (!Reaper.initSubset(rec.?, &reaper_api))
        return 0;

    for (&registrations, 0..) |*reg, i| {
        cmd_ids[i] = Reaper.plugin_register("custom_action", @constCast(@ptrCast(reg)));
        if (cmd_ids[i] == 0) log.err("failed to register action {s}", .{reg.id_str});
    }
    _ = Reaper.plugin_register("hookcommand2", @constCast(@ptrCast(&onCommand)));
    _ = Reaper.plugin_register("toggleaction", @constCast(@ptrCast(&toggleActionHook)));

    log.info("v{s} loaded {d} actions (search \"Cajun:\" in the action list)", .{ build_options.version, all_entries.len });
    return 1;
}

fn onCommand(sec: *Reaper.KbdSectionInfo, command: c_int, val: c_int, val2hw: c_int, relmode: c_int, hwnd: Reaper.HWND) callconv(.C) c_char {
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
fn toggleActionHook(command_id: c_int) callconv(.C) c_int {
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
}

test "every action gets a unique command id string" {
    for (all_entries, 0..) |a, i| {
        for (all_entries[i + 1 ..]) |b| {
            try std.testing.expect(!std.mem.eql(u8, a.name, b.name));
        }
    }
}
