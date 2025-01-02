GAME PLAN
1. Theme Setup & GUI Foundation
   ✓ Reaper theme module
   ✓ Initial window setup
   ✓ Basic MIDI I/O

2. Debugging Infrastructure
   - Event system implementation
     * EventType enum and Event union
     * EventLog struct with ArrayList
     * Basic logging functions
   - Debug levels
     * LogLevel enum
     * Integration with Reaper console
   - Debug overlay prototype
     * Collapsible ImGui window
     * Event history display
     * State visualization
     * MIDI activity monitor

2. Core Data Structures & State
   - Define all state structures
   - Define action unions
   - Define mode transitions
   - Add logging points for state changes
   - Update debug overlay to show new structures

5. GUI Panel Prototyping & Debug Infrastructure
   A. Debug/Development Panel
      - Implement event logging system
      - Create debug overlay window with collapsible sections:
        * Current State/Mode
        * Recent Events Log
        * Track/FX State
        * MIDI Activity Monitor
      - Add LogLevel enum and logging utilities
      - Test state changes are properly logged and displayed

   B. Main Panel Implementation
      - FX Control panel (main view with C1 schematic)
        * Basic layout
        * Knob/button widgets
        * Interaction with state system
        * Verify events are logged

      - Module Selection browser
        * FX categorization display
        * Selection mechanics
        * State updates
        * Event logging for selections

      - Mapping Panel
        * Parameter list view
        * Mapping interface
        * MIDI learn functionality
        * Log mapping operations

      - Settings Panel
        * Settings categories
        * Input widgets
        * Save/Load mechanics
        * Log settings changes

      - Default Channel Strip Panel
        * FX selection interface
        * Order configuration
        * Update event logging

4. Config File Management
   - Move this earlier since other features depend on it
   - Settings loading/saving
   - Mapping file handling
   - Add logging for file operations
   - Add config visualization to debug overlay
   → Already implemented but might need adjustments for new structures

5. Mode & Action Implementation
   - State transitions
   - Mode handlers
   - Action mappings
   - Verify all state changes appear in debug overlay

6. MIDI Implementation
  - Handler functions for each mode
  - Action dispatching with event logging
  - Feedback handling with state tracking
  - Debug overlay MIDI monitor section
   → Depends on mode/action implementation

7. Integration & Testing
- Connect GUI actions to state changes
- Connect MIDI handlers to state changes
- Implement feedback loop (State → GUI → Controller)
- Comprehensive testing using debug overlay:
  * Mode transitions
  * MIDI routing
  * Parameter updates
  * Error conditions
- Final adjustments to logging levels and debug info
I’m trying to design the state machine for the reaper extension that will control the Console1 midi controller.
The extension is meant to be written in Zig, and I have the scaffold of the extension working.
The point now is to figure out how I want to design the state machine, and what needs to be stored in each mode of the state.

Each mode has a dedicated GUI window. The GUI is built using dearImgui. The GUI is meant to run while the extension takes input from the controller.
We want to reduce the amount of unknowns in the process of designing the state machine.
1. rough outline of the expected functionality
2. outline of what each mode is supposed to do
3. design the data structures that go around this.
    Update the state and its data, match controller feedback.

The C1 has CC controls which all can also receive feedback (displayed by LEDs on the C1). Some of them are knobs (CCKnobs) and some of them are buttons (CCBtns). Feedback for the knobs is displayed by LED rings around the knob, for the buttons it is a single LED below the button.
The C1 is an absolute mode midi controller, with each CC representing values between 1 and 127.

Here’s a list of the controls on the C1:
Comp_Attack, Comp_DryWet, Comp_Ratio, Comp_Release, Comp_Thresh, Comp_comp, Eq_HiFrq, Eq_HiGain, Eq_HiMidFrq, Eq_HiMidGain, Eq_HiMidQ, Eq_LoFrq, Eq_LoGain, Eq_LoMidFrq, Eq_LoMidGain, Eq_LoMidQ, Eq_eq, Eq_hp_shape, Eq_lp_shape, Inpt_Gain, Inpt_HiCut, Inpt_LoCut, Inpt_disp_mode, Inpt_disp_on, Inpt_filt_to_comp, Inpt_phase_inv, Inpt_preset, Inpt_MtrLft, Inpt_MtrRgt, Out_MtrLft, Out_MtrRgt, Shp_Mtr, Comp_Mtr, Out_Drive, Out_DriveChar, Out_Pan, Out_Vol, Out_mute, Out_solo, Shp_Gate, Shp_GateRelease, Shp_Punch, Shp_hard_gate, Shp_shape, Shp_sustain, Tr_ext_sidechain, Tr_order, Tr_pg_dn, Tr_pg_up, Tr_tr1, Tr_tr10, Tr_tr11, Tr_tr12, Tr_tr13, Tr_tr14, Tr_tr15, Tr_tr16, Tr_tr17, Tr_tr18, Tr_tr19, Tr_tr2, Tr_tr20, Tr_tr3, Tr_tr4, Tr_tr5, Tr_tr6, Tr_tr7, Tr_tr8, Tr_tr9, Tr_tr_copy, Tr_tr_grp.


Handling the messages back and forth with Console1 (aka C1) is done via the control surface (CSURF). CSURF is a list of callbacks include some for handling midi input, and the rest for handling DAW events which might trigger feedback to the controller.

The GUI is displayed in a window docked at the bottom of reaper’s UI. It runs on a timer which is subscribed to reaper as a callback function.

FX Ctrl
  Requires config files that describe the mappings of each FX to the CCknobs.
  The config files which describe the mappings are stored in a resource folder in the reaper path.
  Upon start-up, the extension reads the mapping files and stores the mappings in the state. TBD if _all_ mappings need to be loaded upon startup.
  When user selects a new track, CSURF notifies the extension, which validates the channel strip on the track.
  If no channel strip, load the default one.
  Else, load each of the mappings that correspond to the fx of the channel strip.
  - note:
    Channel strip here is an ambiguous term. In fact, the console’s channel strip is represented in reaper’s trackfx chain as a container which carries each fx that corresponds to the C1’s modules. Upon notification of a new track selection, or of changes to the trackfx chain, the extension re-runs the validation.
    Validation means that the extensions iterates through the trackfx in search for a container fx named "C1_CHANNEL" which contains the fx that correspond to the C1’s modules. If the container is found, the extension validates its contents - same iteration process.

  The extension queries the values of the fx params that are assigned by the mappings to each of the CCKnobs and CCBtns, and updates the LEDs accordingly.
  When CSURF notifies the extension about changes in the params, changes are reflected in the LEDs of the C1.
  In Fx_ctrl mode, the GUI displays a schematic of the C1 which contains clickable knob widgets.
  Upon clicking the UI, the extension updates the LEDs and calls the reaper API to update the corresponding fx param’s value.

  GUI Components
    Fx List
      A list of the track names in the currently-selected page. Pages contain 20 items, and can be selected via the PgUp/PgDn CCBtns.
      When user selects a new track, extension updates the corresponding LED and notifies reaper.
      When user selects a new page, the extension updates the LEDs and the GUI - if the selected track is in the current page, the corresponding LED is lit.
    C1 schematic
      A schematic UI of the CC knobs of the controller. The UI displays knob widgets that mirror the CCknobs. UIKnobs <=> CCknobs
      GATE | CMP  | EQ  | DRIVE etc.
      knobs| knobs|knobs| knobs etc.
SETTINGS
  A list of default preferences to be set by the user.
  Stored in the settings config file in the resource folder.
  Loaded upon startup.
  Changes to the settings at run time have to be save-able. This a view that has the classic SAVE/CLOSE buttons.
  Some options:
    - show_start_up_message
      show a message at start up in the GUI which can be dismissed. Dunno if this is useful.
    - show_feedback_window
      whether to display the GUI when in fx_ctrl mode.
      GUI should definitely be shown in other modes.
      User also has a button mapping to toggle the GUI in fx_ctrl mode at runtime, though the runtime toggle shouldn’t be stored in the defaults at every change - only when saved from the settings panel.
    - show_plugin_ui
      Whether to call the reaper API to tell it to show the plugin UI when the user tweaks one of the fx’s params. This also has a runtime toggle.
    - manual_routing
      Whether to enable the side chain routing capabilities of the extension. C1 has a button to cycle through routing configs, and this button should only be active when the manual routing is disabled.
    - default_channel_strip
      GUI : same as fx browser by category
        GATE | CMP  | EQ  | DRIVE (modules are selectable from dedicated button)
        list | list |list | list  (lists are scrollable)
    default modules order
      determines the order of the modules in the channel strip.
      C1 also has a button to cycle through routing modes at runtime: Gate->Eq->Comp, EQ->Gate->Comp, Gate->Comp->Eq, etc.

  What would be some other options that would be useful for the user?


  GUI Components:
    List of settings
      A list of the settings that can be changed.
      Selecting «default_channel_strip» should switch the GUI to display the fx browser by category - except in this mode, the changes are stored in the settings.
      If we’re going to be encoding the top-level states in an enum, it might be worth having this as an extra encoding, and only allow switching to this state from the settings panel. Could be simpler than nesting multiple mode encodings.
    Save/Cancel buttons
      If the user Cancels without saving, what’s the expectation? The user might have made changes to the settings at runtime, and then wants to cancel them.
      This means that we probably want a mechanism to revert the runtime changes: either by re-reading the settings file, or by storing the runtime changes in a separate struct that gets merged with the settings struct upon save. There’s also the option of a structural sharing tree, which I however have not implemented before.
    Which-Key style panel
      Since the menus in this mode are to be accessible via the C1 - we need a controller mapping for the whole settings panel.
      If we’re doing a controller mapping, the UI should have a which-key style GUI component which demonstrates the mappings.
      This mapping should be hard coded.

MODULE_SELECTION
  GUI :
    fx browser by category
      displays a list of fx categories that match the modules of the C1.
      Requires a parser for reaper’s fx categories `.ini` config files. Fx parser is already built, and most of the GUI logic is already built as well.
      Special bg color for fx that have a mapping
      C1 scroll ctrl + key/mouse input
      GATE | CMP  | EQ  | DRIVE (modules are selectable from dedicated buttons)
      list | list |list | list  (lists are scrollable)
    Which-key style panel
      Similar to the settings panel, this panel should display the mappings of the C1 to the GUI. Mapping’s hard coded.
      One interesting option for this panel would be to read the hardcoded mappings and just display them in the GUI.
      If it’s worth following this approach, I could picture reading sets of key/value pairs from a list, which would be automatically laid out in the window. What’s the mechanic for this?

MAPPING_PANEL
  comes up when user selects a plugin that doesn’t have a mapping
  CONFIG FILE
  keeps a state of the current mapping, but doesn’t commit it into the global mappings list.
  Two parallel lists - fx params list and c1 controls list.
  Or instead could have a midi learn button: in midi learn mode, user srolls to highlight a param, then turns the knob to map it.
  If we go the midi learn route, we probably want a C1 button mapping to trigger it.

  How to show feedback that the mapping has been set?
  1. Display a C1 schematic where those of the set mappings have the fx param’s name as label, and an em dash otherwise.
  2. Add the name of the C1 control next to the fx param in the list.
  … Any other options for this type of selection?
  Needs an UNMAP button

  GUI Components
    which-key style panel
      displays the mappings of the C1 to the GUI. Mapping is hard coded.
    list of fx params (scrollable)
    list of mappable C1 controls/module controls (scrollable)
    knob/ctrl panel | fx param panel (scrollable)
    selected ctrl = last touched
    BUTTONS = CANCEL (discard mapping) | SAVE_&_CLOSE (write to config file, store in global mappings list, assign to matching fx)


# Storage
1. **Persistent Storage**:
Settings and mapping files are stored in `ini` files in the resource path.
So far, the mappings are stored in a hashmap<fxName, FxMap>
```zig
// Comp, EQ, Inpt, Output and Shp
// are structs whichs Keys represent C1 ctrls,
// and Values represent Fx param Ids.
pub const FxMap = struct {
    COMP: ?std.meta.Tuple(&.{ u8, ?Comp }) = null,
    EQ: ?std.meta.Tuple(&.{ u8, ?Eq }) = null,
    INPUT: ?std.meta.Tuple(&.{ u8, ?Inpt }) = null,
    OUTPT: ?std.meta.Tuple(&.{ u8, ?Outpt }) = null,
    GATE: ?std.meta.Tuple(&.{ u8, ?Shp }) = null,
    // Trk: std.meta.Tuple(&.{ u8, Trk }),
};
```
When the track loads an FX, it fetches missing mappings from disk,
copies and assigns the mappings to the global FxMap variable.
What would a simple caching system involve ?
Would it be more efficient than this?

2. **State Management**:
- about a command pattern for state transitions
  I’m unsure what you mean. Describe an example command pattern.
- about undo/redo for mapping changes:
  Mappings in the mapping panel are not stored in the global mappings Hashmap until they’re commited.
  They’re also not assigned to the global FxMap variable.
  They should be stored in a temp var.
- I’m unfamiliar with the observer pattern. Describe how it works.


3. **Error Handling**:
- Add error union types for operations that might fail
- Implement proper cleanup for resources
- about validation for mapping configurations:
  I have the .ini parser that takes care of that already. It reads the config files and merges them with the default into the settingsState.

4. **Performance Considerations**:
  - Use arena allocators for temporary allocations during mapping operations
  - About lazy loading for FX mappings:
    Describe the lazy loading process.
    My current process is:
    found fx -> lookup in mappings hashmap -> if unfound, lookup on disk, -> if unfound, open the mapping panel
    Is lazy loading going faster than this?
   - About Caching frequently accessed track/FX data
    Would there be a simpler or more performant caching mechanism than what I just described?

```zig
const MidiAction = union(enum) {
    set_param: struct {
        cc: CC,
        module: Module,
        value: u7,
    },
    change_mode: Mode,
    scroll_list: i8,
    select_item: void,
    // ... other actions
};

// Each mode defines its own handler for MIDI events
const ModeHandler = struct {
    handleMidi: fn(cc: CC, value: u7) ?MidiAction,
    handleDaw: fn(msg: DawEvent) ?StateUpdate,
};

const mode_handlers = std.EnumMap(Mode, ModeHandler){
    .fx_ctrl = .{
        .handleMidi = handleFxCtrlMidi,
        .handleDaw = handleFxCtrlDaw,
    },
    .settings = .{
        .handleMidi = handleSettingsMidi,
        .handleDaw = handleSettingsDaw,
    },
    // ... other modes
};

fn handleFxCtrlMidi(cc: CC, value: u7) ?MidiAction {
    return switch (cc) {
        .Comp_DryWet => .{ .set_param = .{
            .cc = cc,
            .module = .COMP,
            .value = value,
        }},
        .Tr_pg_up => .{ .change_mode{ .module_selection } },
        // ... other mappings
    };
}

pub fn OnMidiEvent(evt: *c.MIDI_event_t) void {
    const cc_enum = decodeMidiEvent(event) orelse return;

    // Get current mode's handler
    const handler = mode_handlers.get(state.current_mode);

    // Get action from mode-specific handler
    const action = handler.handleMidi(cc_enum, evt.value) orelse return;

    // Execute the action
    switch (action) {
        .set_param => |param| setPrmVal(param.cc, param.module, track_ptr, param.value),
        .change_mode => |new_mode| state.current_mode = new_mode,
        .scroll_list => |delta| scrollCurrentList(delta),
        .select_item => selectHighlightedItem(),
        // ... handle other actions
    }
}
```
here's a breakdown of possible MidiAction variants for different modes (current csurf implementation):
```zig
const MidiAction = union(enum) {
    // FX Control Mode Actions
    set_param: struct {
        cc: c1.CCs,
        module: Conf.ModulesList,
        value: u7,
    },
    set_track_param: struct {
        param_type: enum { volume, pan, mute, solo, phase },
        value: u7,
    },
    toggle_fx_window: void,
    set_routing: struct {
        mode: ?Track.RouteMode,
        sidechain: ?Track.SideChainMode,
    },

    // Track Selection Actions
    select_track: struct {
        index: u8,
        page: u8,
    },
    change_page: enum { up, down },

    // Mode Switching Actions
    change_mode: State.Mode,

    // Module Selection Mode Actions
    select_module: struct {
        module_type: Conf.ModulesList,
        fx_index: u8,
    },

    // Mapping Panel Actions
    assign_mapping: struct {
        cc: c1.CCs,
        fx_param: u32,
    },
    clear_mapping: c1.CCs,
    save_mapping: void,
    cancel_mapping: void,
};

const StateUpdate = struct {
    action: MidiAction,
    validate: fn(*State) bool,
};
```



Additional Considerations:
- Consider implementing a simple event system early to handle state updates
```zig
const EventType = enum {
    state_change,
    midi_input,
    mode_transition,
    parameter_update,
    // etc.
};

const Event = struct {
    type: EventType,
    data: union(EventType) {
        state_change: struct {
            old_mode: Mode,
            new_mode: Mode,
        },
        midi_input: struct {
            cc: c1.CCs,
            value: u7,
        },
        mode_transition: Mode,
        parameter_update: struct {
            module: Conf.ModulesList,
            param: u32,
            value: f64,
        },
    },
    timestamp: i64,  // for debugging/logging
};

const EventLog = struct {
    events: std.ArrayList(Event),

    pub fn log(self: *@This(), event: Event) void {
        self.events.append(event);
        // Optionally: write to debug window/file
        if (debug_window_active) self.updateDebugView();
    }
};
- Add logging/debugging features early in the process
```zig
const LogLevel = enum {
    debug,
    info,
    warning,
    error,
};

pub fn log(
    level: LogLevel,
    comptime format: []const u8,
    args: anytype,
    event: ?Event,
) void {
    // Format timestamp
    const timestamp = std.time.timestamp();

    // Format message
    const message = std.fmt.allocPrint(
        allocator,
        "{s} [{s}] " ++ format,
        .{ timestamp, @tagName(level) } ++ args,
    ) catch return;
    defer allocator.free(message);

    // Log to Reaper console
    reaper.ShowConsoleMsg(message);

    // If event provided, add to event log
    if (event) |e| event_log.log(e);

    // Update debug overlay if active
    if (debug_overlay_active) updateDebugOverlay();
}
```
- Consider creating a test panel that can be used to verify MIDI input/output. Maybe add a debug overlay for state visualization
```zig
fn drawDebugOverlay() void {
    if (!debug_overlay_active) return;

    // Create a collapsible section in corner of main window
    if (imgui.begin("Debug Info", .{
        .flags = .{
            .no_move = true,
            .no_resize = true,
            .always_auto_resize = true,
        },
    })) {
        // Current State
        imgui.text("Mode: {s}", .{@tagName(state.current_mode)});

        // Last N Events
        if (imgui.collapsingHeader("Recent Events", .{})) {
            for (event_log.events.items[0..@min(10, event_log.events.items.len)]) |event| {
                imgui.text("{}: {s}", .{
                    event.timestamp,
                    @tagName(event.type),
                });
            }
        }

        // Current Track Info
        if (imgui.collapsingHeader("Track State", .{})) {
            if (state.track) |track| {
                imgui.text("Track: {s}", .{track.name});
                imgui.text("Order: {s}", .{@tagName(track.order)});
                // etc.
            }
        }

        // MIDI Activity
        if (imgui.collapsingHeader("MIDI", .{})) {
            // Show last N MIDI events
            // Show current CC values
        }
    }
    imgui.end();
}
```

Usage in your main loop:
```zig
pub fn draw() void {
    // Your normal GUI drawing
    drawMainPanel();

    // Debug overlay on top
    drawDebugOverlay();

    // Example logging
    log(.info, "Parameter changed: {d}", .{new_value}, .{
        .type = .parameter_update,
        .data = .{
            .parameter_update = .{
                .module = .COMP,
                .param = 1,
                .value = new_value,
            },
        },
        .timestamp = std.time.timestamp(),
    });
}
```
  How would the debug overlay work? Would it be separate window that prints state changes?
