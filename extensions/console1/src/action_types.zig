// This file contains all action type definitions shared between the host
// extension and the hot-reloadable UI library. Because the UI lib needs to
// return ModeAction values without pulling in the full action handler code
// (which depends on REAPER C headers and the config module), we define the
// types here with only lightweight imports.

const c1 = @import("c1.zig");
const statemachine = @import("statemachine.zig");
const reaper = @import("reaper.zig").reaper;
const fx_ctrl_state = @import("fx_ctrl_state.zig");
const settings = @import("settings.zig");

pub const Mode = statemachine.Mode;
pub const ModulesList = statemachine.ModulesList;
pub const CCs = c1.CCs;
pub const ModulesOrder = fx_ctrl_state.ModulesOrder;
pub const SCRouting = fx_ctrl_state.SCRouting;
pub const MediaTrack = reaper.MediaTrack;
pub const SettingsFields = settings.SettingsFields;

// FX Control

pub const MidiInput = struct {
    cc: CCs,
    value: u8,
};

pub const WidgetInput = struct {
    cc: CCs,
    value: f64,
};

pub const FxCtrlAction = union(enum) {
    midi_input: MidiInput,
    panel_input: WidgetInput,
    set_volume: f64,
    set_pan: f64,
    toggle_mute,
    toggle_solo,
    set_routing_order: ModulesOrder,
    set_sidechain: SCRouting,
    on_track_entry: MediaTrack,
    fx_win_disp: MediaTrack,
    toggle_phase_inv: MediaTrack,
};

// FX Selection

pub const FxSelActions = union(enum) {
    select_fx: [:0]const u8,
    scroll: u8,
    confirm: void,
    back: void,
    toggle_module_browser: ModulesList,
    fx_chain: struct { path: []const u8 },
    track_template: struct { path: [:0]const u8 },
    plugin: struct { name: [:0]const u8, mapping_name: ?[:0]const u8 },
    close_browser: void,
    rescan: void,
};

// Mapping Panel

pub const MappingPanelAction = union(enum) {
    enter_browse: void,
    enter_assign: ModulesList,
    exit_to_fx_ctrl: void,
    browse_scroll: u8,
    browse_select_module: ModulesList,
    browse_confirm: void,
    browse_cancel: void,
    assign_select_parameter: ?u32,
    assign_select_control: ?CCs,
    assign_toggle_midi_learn: void,
    assign_add_mapping: struct { param: u16, control: CCs },
    assign_midi_learned_param: u32,
    assign_update_knob: struct { cc: CCs, value: f32 },
    assign_remove_mapping: CCs,
    assign_change_module: ModulesList,
    assign_request_save: void,
    assign_cancel: void,
};

// Settings

pub const SettingsValUpdate = union(enum) {
    bool_val: struct { field: SettingsFields, val: bool },
    string_val: struct { field: SettingsFields, val: [:0]const u8 },
    enum_val: struct { field: SettingsFields, val: ModulesOrder },
};

pub const SettingsActions = union(enum) {
    open,
    save,
    cancel,
    scroll: u8,
    toggle,
    update_val: SettingsValUpdate,
};

// Transport

pub const TransportState = struct {
    jog: u8 = 64,
    jog_item: u8 = 64,
    jog_marker: u8 = 64,
    zoom_horizontal: u8 = 64,
    zoom_vertical: u8 = 64,
    rate: u8 = 64,
    scrub: u8 = 64,
    tr_sel: u8 = 0,
    grid: u8 = 0,
};

pub const AutomationMode = enum(c_int) {
    trim,
    read,
    touch,
    latch,
    preview,
    write,
};

pub const TransportAction = union(enum) {
    automation_mode: AutomationMode,
    grid: u8,
    snap_tgl,
    jog: u8,
    jog_item: u8,
    jog_marker: u8,
    loop_end,
    loop_start,
    loop_toggle,
    marker_set,
    play,
    rate: u8,
    rec,
    rec_arm,
    scrub: u8,
    stop,
    tr_sel: u8,
    zoom_horizontal: u8,
    zoom_vertical: u8,
};

// Track List

pub const PgDirection = enum { up, down };

pub const TrackListAction = union(enum) {
    page_change: PgDirection,
    track_select: c_int,
    blink_leds: struct {
        blink_state: bool,
        midi_out: reaper.midi_Output,
    },
    refresh,
};

// Control Surface

pub const WinChg = struct {
    track: MediaTrack,
    fx_index: i32,
    is_open: bool,
};

pub const ParamChg = struct {
    track: MediaTrack,
    fx_index: usize,
    param_index: usize,
    value: f64,
};

pub const CsurfAction = union(enum) {
    track_selected: struct { tr: MediaTrack, selected: bool },
    last_touched_track: MediaTrack,
    play_state_changed: struct { playing: bool, paused: bool },
    fx_chain_changed: MediaTrack,
    fx_param_changed: ParamChg,
    fx_window_state: WinChg,
    project_reset,
};

// MIDI Output

pub const MidiOutAction = union(enum) {
    mode_entry: Mode,
    clear_all,
    track_select: MediaTrack,
    page_change,
    set_param: struct { cc: CCs, value: u8 },
    blink,
    reset_meters,
    queryMeters,
    settings_changed: SettingsValUpdate,
};

// Top-level action union that the UI returns to the host.

pub const ModeAction = union(enum) {
    fx_ctrl: FxCtrlAction,
    fx_sel: FxSelActions,
    transport: TransportAction,
    mapping_panel: MappingPanelAction,
    settings: SettingsActions,
    default_fx_sel: FxSelActions,
    Csurf: CsurfAction,
    change_mode: Mode,
    set_fx_ctrl_gui,
    track_list: TrackListAction,
    midi_out: MidiOutAction,
};
