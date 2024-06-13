const std = @import("std");
const Reaper = @import("../reaper.zig");
const reaper = Reaper.reaper;

const namespace = "prkn_c1";

/// This is the barebones trackFx info,
/// Without the class functions that can be found in
/// @see TrackFX
/// This type is used for testing and for passing data when instantiating `TrackFX`
const FxData = struct {
    enabled: bool,
    guid: [*:0]const u8,
    name: [*:0]const u8,
    number: u8,
    // param?: table,
    index: u8,
};

pub const Track = struct {
    /// all fx in the track, using GUID as key. Duplicate of fx_list for easier access.
    fx_by_guid: std.StringHashMap(TrackFX),
    /// array of fx in the track. duplicate of fx_by_guid for easier iteration.
    fx_list: []TrackFX,
    fx_count: u8,
    guid: [*:0]const u8,
    name: [*:0]const u8,
    /// 0-indexed track index (0 is for master track)
    number: u8,
    track: *reaper.MediaTrack,
    fx_chain_enabled: bool,
    automation_mode: AutomationMode,
};

/// 0=trim/off, 1=read, 2=touch, 3=write, 4=latch
/// @enum AutomationMode
const AutomationMode = enum(u8) { trim = 0, read = 1, touch = 2, write = 3, latch = 4, preview = 5 };

const Parameter = struct {
    defaultval: u8,
    editSelected: bool = false,
    fmt_val: ?[*:0]const u8,
    guid: [*:0]const u8,
    ident: [*:0]const u8,
    index: u8,
    istoggle: bool,
    largestep: f16,
    maxval: f16,
    midval: f16,
    minval: f16,
    name: [*:0]const u8,
    // new: fn (state: *State, param_index: u8, parent_fx: *TrackFX, guid: [*:0]const u8) *Parameter,
    parent_fx: TrackFX,
    // query_value: fn (self: *Parameter) *Parameter,
    // setValue: fn (self: *Parameter, value: u8) void,
    smallstep: u8,
    ///  normalized step
    step: u8,
    value: u8,
    ///Used for params that have a limited u8 of steps (like a dropdown)
    steps_count: ?u8,
};

///ParamData is an intermediary datum for a param that's not being displayed.
///
///Basically we don't need to query the param's values if it's not displayed
///so we only need its name and guid.
const ParamData = struct {
    details: ?*Parameter,
    display: bool = false,
    guid: [*:0]const u8,
    index: u8,
    name: [*:0]const u8,
};

const CreatedParams = struct { params_list: []*ParamData, params_by_guid: std.StringHashMap(ParamData) };

const TrackFX = struct {
    createParamDetails: *const fn (self: TrackFX, param: ParamData, addToDisplayParams: ?bool) ParamData,
    createParams: *const fn (self: TrackFX) CreatedParams,
    ///name of fx, or preset, or renamed name, or fx instance name.,
    display_name: [*:0]const u8,
    enabled: ?bool,
    guid: [*:0]const u8,
    index: u8,
    name: ?[*:0]const u8,
    // new: fn (state: *State, index: u8, number: u8, guid: [*:0]const u8) *TrackFX,
    number: u8,
    params_by_guid: []const ParamData,
    params_list: []const ParamData,
    presetname: ?[*:0]const u8,
    renamed_name: ?[*:0]const u8,
    // update: fn (self: *TrackFX) void,
    DryWetParam: *ParamData,
};

pub const ControllerConfig = struct {
    paramData: []*ParamData,
    /// list of modes (fx ctrl, settings),
    Modes: [][*:0]const u8,
    channelStripPath: [*:0]const u8,
    realearnPath: [*:0]const u8,
};

pub const UserSettings = struct {
    show_start_up_message: bool = true,
    ///  -- should the UI display?
    show_feedback_window: bool = true,
    ///  -- show plugin UI when tweaking corresponding knob.
    show_plugin_ui: bool = true,
};
