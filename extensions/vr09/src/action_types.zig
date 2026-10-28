//! The actions that the panel asks for.
//!
//! The panel only draws and reads. When the player does something (turns a knob, clicks a row, types a name) the
//! function that drew the widget returns an `Action`, the functions that drew the cards and the tabs pass up the
//! one that they got, and `ui.zig` hands it to `dispatch.zig` after the frame. The panel does not change anything
//! itself: the dispatcher is the only place where a request becomes an effect (a parameter written to the engine,
//! a scene moved, a file written, a setting changed). The debug API and the scene actions of REAPER use the same
//! functions, so that one operation is written once.
//!
//! This file has no dependency on the plugin, so that the panels can name the actions without importing the code
//! that carries them out.
const std = @import("std");
const strings = @import("strings.zig");
const tones = @import("tones.zig");

/// The ID of a text in the plugin's strings (see `strings.zig`). An action carries the IDs of the names that it
/// needs, and the dispatcher reads their text from the pool: the name of a patch, a file name, a name that the
/// player typed.
pub const Ref = strings.Ref;

/// Where the bytes of a patch come from.
pub const PatchSource = union(enum) {
    /// The plugin's state now.
    current,
    /// A file of the registrations folder, by its file name.
    registration: Ref,
    /// A file of the presets folder, by its file name.
    preset: Ref,
    /// One tone of a part, which is a patch that holds only that tone. `part` is one of the names of
    /// `scenes.tone_parts` (such as "upper_piano").
    tone: struct { part: Ref, number: u8, msb: u8, lsb: u8 },
    /// A patch that the panel cannot send or make a scene of yet (a drum kit).
    unsupported,
};

/// A patch of the library, with what a scene made of it needs to remember.
pub const Patch = struct {
    source: PatchSource,
    /// The name that a scene made of it takes, and that a notice says.
    name: Ref,
    /// The value of the Patch parameter that selects it in the library, or 0 for a patch that has none.
    id: u16 = 0,
    /// A short text for the scene list to show, which says which patch of the library the scene came from.
    label: Ref,
};

pub const MoveScene = struct { from: u8, to: u8 };
pub const RenameScene = struct { position: u8, name: Ref };
pub const LoadTemplate = struct { name: Ref, append: bool };
pub const SetParam = struct { index: usize, value: u8 };
/// A tone chosen in the card of a part. `part` is the position of the part in `scenes.tone_parts`, and `tone`
/// points to an entry of `tones.zig`, so the action carries no copy of a text.
pub const ChooseTone = struct { part: u8, tone: *const tones.Tone };

/// What the panel asks for.
pub const Action = union(enum) {
    // ---- parameters ----
    /// Writes a parameter of the catalog.
    set_param: SetParam,

    // ---- the keyboard ----
    read_keyboard,
    send_to_keyboard,
    /// Reads the keyboard, then saves what it holds as a preset of this name. The plugin's save job does it.
    save_keyboard: Ref,
    /// Sends a patch of the library to the keyboard.
    send_patch: Patch,
    /// Deletes a preset, by its file name.
    delete_preset: Ref,
    /// Reads the registrations and the presets folders again.
    refresh_library,
    import_file,
    /// Writes the plugin's state to a file, by its full path.
    export_file: Ref,

    // ---- scenes ----
    /// Puts a patch at the end of the session's scenes.
    add_scene: Patch,
    select_scene: u8,
    move_scene: MoveScene,
    remove_scene: u8,
    rename_scene: RenameScene,
    /// Puts a point of the Scene parameter at the edit cursor, set to the selected scene.
    insert_lane_point,
    save_template: Ref,
    load_template: LoadTemplate,
    delete_template: Ref,

    // ---- options ----
    set_split: bool,
    set_follow_panel: bool,
    set_recall_on_load: bool,

    // ---- the audio loop ----
    set_loop_enabled: bool,
    set_send_db: i32,
    set_return_db: i32,
    set_out_channel: i32,
    set_in_channel: i32,
    measure_latency,

    // ---- the track's MIDI ----
    set_midi_output: ?usize,
    set_midi_input: usize,
    set_armed: bool,
    set_monitoring: bool,
    set_pass_midi: bool,
    set_sysex_bare: bool,
    reconnect,

    // ---- the tones ----
    /// A tone was chosen in the card of a part. It is carried out as the same patch as a tone of the library.
    choose_tone: ChooseTone,
};

/// The action of a frame. A frame produces at most one, because the player works with one widget at a time, so
/// the draw functions return it, and a function that draws several widgets returns the first action that they
/// returned.
pub fn first(a: ?Action, b: ?Action) ?Action {
    return a orelse b;
}

test "a frame's action is the first one that its widgets returned" {
    const none: ?Action = null;
    try std.testing.expect(first(none, none) == null);
    try std.testing.expect(first(none, .read_keyboard).? == .read_keyboard);
    try std.testing.expect(first(.send_to_keyboard, .read_keyboard).? == .send_to_keyboard);
}
