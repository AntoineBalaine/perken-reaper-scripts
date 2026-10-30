# Console 1 in sysex mode: decisions and plan

## Goal

Because the Console 1 only reports shift, relative knob ticks and its other controls after the Softube handshake, and because it then lights nothing by itself, the extension has to change how it talks to the unit. After this change the extension tries the sysex mode first and falls back to today's CC mode when the handshake fails. In the sysex mode, shift works, the knobs are relative, and the LEDs, rings and meters are driven with state frames.

This file records the decisions and the plan to implement them. The protocol is in `tools/sniff-usb/PROTOCOL.md`. The analysis behind the decisions (the options that were compared, what Softube's manual says, how other controllers handle encoders, the measurements) is in `sysex-mode-assessment.md`. Every statement about the extension comes from reading the code on branch `c1UI` at commit `e20e0fba`.

## Decisions

Taken in the discussion of 2026-10-29 and 2026-10-30.

Architecture

- A device layer sits under the existing code, in a new folder `src/unit/`, and the state machine, the GUI and the mappings do not change in the first phase. A retrofit of the whole extension is not done first, because the contact points with the CC protocol are few, and because the layer keeps the legacy mode available.
- The extension always tries the sysex mode first. If the handshake fails, it falls back to the legacy CC mode with the code that works today. The legacy backend stays for good, because there is one unit to test with and nothing proves that the handshake works on every unit.
- When the handshake fails and the unit runs in the legacy mode, the UI says so, next to the existing branch for a missing device (`src/fx_ctrl_panel.zig:262`).

Shift and the buttons, in the fx_ctrl mode of the sysex backend

- Shift held on a knob is the fine adjust. The knob functions under shift of Softube's own unit (the sends on Drive, Character and Pan, the internal volume) are not wanted.
- Shift with Tr1 loads the strip, with Tr2 the shape (gate) module, with Tr3 the EQ, with Tr4 the compressor, with Tr5 the input and with Tr6 the output. The transport mode keeps its own loaders. The face of the unit prints History on Tr5, which is dropped.
- Shift with Tr20 opens the settings.
- Shift with Volume selects the previous or the next track, at once and with no confirmation, and the page of 20 tracks follows the selection.
- Shift with Preset saves a preset. A plain Preset loads one. See the presets decisions.
- No other shift function is wanted: not Bypass, the Sends, OK, Cancel or All, not History, and not shift with Page Up or Page Down.
- The transport mode and the mode button stay as they are, in both backends.

Presets and mappings, which are two things

- A preset is what Softube calls one: the settings of the strip or of some sections. It integrates with REAPER's own preset features, and not with a format of the extension's own.
- A mapping is the controller mapping of a plugin or of a channel strip, and it stays in the mapping panel. A plain Preset no longer opens the mapping panel. Unless it is changed, the mapping panel opens from the screen, and by itself when a plugin has no mapping.

The step of a knob

- The value of a parameter is not limited to 127 steps: the step is a real number in the normalized range, and the 7 bits remain only in the display of the rings and meters.
- The step starts at 1/127 per tick, with a user `sensitivity` setting and shift as a tenth of the step. The other settings (a multiplier per control, a step per parameter, acceleration) come later, and so does the custom scale.
- A custom scale is a curve for one parameter, kept in the map file of the plugin and drawn by the user in a window of its own. It is a later phase.

Deferred

- The extra assignments of the knobs under shift (a second set of mappings in the map files, and a shift view in the UI). It waits because shift is the fine adjust.
- History (the undo of the settings).
- Fixing `zig build test` is the first task of the plan, now that the discussion is over.

## Behavior after the change

### Shift in the fx_ctrl mode

The functions that the face of the unit prints, as the user wants them in the fx_ctrl mode:

| shift and | does | today |
|---|---|---|
| Preset | save preset: the settings of the strip or of chosen sections, as in Softube's software | a plain Preset opens the mapping panel in browse mode today (`midi_events.zig:39`, `fx_ctrl_actions.zig:42`). It becomes the presets menu |
| Tr1 | load strip | in the transport mode, Tr6 is the strip (`toggle_module_browser = .STRIP`) |
| Tr2 | load shape (the gate module) | in the transport mode, Tr2 |
| Tr3 | load EQ | in the transport mode, Tr3 |
| Tr4 | load comp | in the transport mode, Tr4 |
| Tr5 | load input | in the transport mode, Tr1 loads the input. The face prints History here, which is not implemented |
| Tr6 | load output | in the transport mode, Tr5 loads the output |
| Tr20 | settings | opens settings from the transport and fx_sel modes (`.Tr_tr20`); in fx_ctrl it selects the track 20 of the page |
| Volume | select: a tick selects the previous or the next track at once, with no confirmation | Out_Vol scrolls the browse modes; in fx_ctrl it is the track volume |

The list is complete as given: the other functions that the face prints (Bypass, Send 1 to 3, OK, Cancel, All) are not wanted in the fx_ctrl mode.


In the sysex backend, the transport mode, the browse modes and the settings keep the controls that they have today. A plain press of a track button selects a track, as today. The functions above only apply in the fx_ctrl mode, and only while shift is held.

The code for these functions, as pseudo-code:

```
fn onControl(globals: *Globals, cc: c1.CCs, val: u8)              // src/csurf/midi_events.zig, split from OnMidiEvent
    if globals.state.current_mode == .fx_ctrl and globals.unit.shift_held
        if shiftFunction(globals, cc, val): return
    ... the switch on the mode, as today ...

fn shiftFunction(globals: *Globals, cc: c1.CCs, val: u8) bool    // new, src/csurf/midi_events_fxctrl.zig
    switch cc
        Tr_tr1 -> dispatch fx_sel.toggle_module_browser = STRIP
        Tr_tr2 -> dispatch fx_sel.toggle_module_browser = GATE
        Tr_tr3 -> dispatch fx_sel.toggle_module_browser = EQ
        Tr_tr4 -> dispatch fx_sel.toggle_module_browser = COMP
        Tr_tr5 -> dispatch fx_sel.toggle_module_browser = INPUT
        Tr_tr6 -> dispatch fx_sel.toggle_module_browser = OUTPT
        Tr_tr20 -> dispatch settings.open
        Inpt_preset -> dispatch the presets action          // phase 4
        else -> return false
    return true

Volume with shift is not a press, it is a tick:
    ControlEvent.tick{ cc = Out_Vol, delta, fine = true } while shift is held
    -> dispatch track_list.step_track(direction)            // new action in src/tracklist_actions.zig
       the track is the current one plus or minus 1, in the order of REAPER, and current_page follows
```

`fx_sel.toggle_module_browser` is the action that the transport mode already dispatches for Tr1 to Tr6 (`midi_events.zig`, `.transport`). `ModulesList` is in `src/statemachine.zig`. The release of a button is dropped, and a shifted press does not also select a track.

### The presets

A plain Preset opens the presets menu, and shift and Preset saves a preset. The flow is Softube's: the menu lists the whole strip, shape, EQ, compressor and the user's presets, Volume scrolls, Solo confirms, and Mute cancels, as the browse modes of the extension already do. To save, shift and Preset is pressed, then the on/off buttons of the sections to include (or none for the whole strip), then Solo, then a name is asked for. This is a new mode, with its own state, actions and panel, and its details are in the open questions. It is phase 4.

### The legacy notice

`UiState` gets `legacy_mode: bool` and `shift_held: bool`, filled where the UI state is built (`src/imgui_loop.zig:145`), and the panel draws a notice while `legacy_mode` is true. While the unit runs in the legacy mode there is no shift, so the functions above do not exist there, and the mode button and the transport mode are how the extra functions are reached.

### The step of a knob tick

The value of a parameter is not limited to 127 steps. The step is a real number in the normalized range of the parameter, and REAPER takes a double (`TrackFX_SetParamNormalized`), so the only place that stays at 127 is the display: the value byte of a ring or of a meter has 7 bits.

Because a measurement cannot say what feels right, the step is a set of settings with a default that is meant to be adjusted:

```
step      = delta * base_step * sensitivity * control_scale * (fine ? fine_multiplier : 1)
new_value = clamp(value read from REAPER + step, 0, 1)
```

| setting | default | where it lives |
|---|---|---|
| `base_step`, the part of the range that one tick moves | 1/127, as on the MFT: 127 ticks for the whole range, and about 0.35 of the range for a revolution at the 45 or so ticks measured | preferences |
| `sensitivity`, a global multiplier, as on the MFT | 1.0 | preferences, and the settings panel |
| `fine_multiplier`, applied while shift is held | 0.1 | preferences |
| `control_scale`, a multiplier for one control, for the knobs that need a coarser or a finer step (a frequency, say) | 1.0 for each | preferences |
| a step for one parameter of one plugin | none | the map file of the plugin, as a key such as `step.Comp_Ratio` (an older build skips keys it does not know, so the format version stays at 1) |
| the ticks that a stepped parameter takes before it moves one step | 1 | preferences. `TrackState.stepDiscreteParam` already accumulates ticks for such parameters |
| acceleration (the speed curve of the delta) | off | preferences, later |

The default 1/127 is where it starts, as the user chose, and the other settings of the table come later; the first version needs only `base_step`, `sensitivity` and `fine_multiplier`. For volume and pan the step is taken in REAPER's slider scale (`SLIDER2DB` and its inverse), as `u8ToVol` does now, and not on the raw value.

#### The custom scale of a parameter (a later phase)

The decision is that a custom scale is a curve for one parameter, kept in the map file of the plugin and drawn by the user in a window of its own. The map file already ties each control to one parameter of one plugin (`Comp_Ratio=12`), so a curve under the name of the control, such as `scale.Comp_Ratio=0:0,0.25:0.1,0.5:0.4,1:1` (a list of points), is a curve for that parameter. An older build skips keys that it does not know, so the format version stays at 1.

How it fits a relative knob, because the unit has no position of its own. The curve `f` runs from the position of the knob `u` in 0 to 1 to the value of the parameter in 0 to 1, and it has to be increasing, so that it has an inverse:

```
u         = f_inverse(value of the parameter, read from REAPER)
u_new     = clamp(u + step, 0, 1)
new_value = f(u_new)
```

The value is still read from REAPER on every tick, so a parameter that was moved by the automation or with the mouse does not make the knob jump, and the extension keeps no position of its own. The inverse of a curve of points is a search along them.

- The curve applies to continuous parameters. A stepped parameter keeps the accumulation of ticks that it has today.
- The ring is a choice to make when this is built: it can show the value of the parameter or the position of the knob `u`. The position makes the ring follow the turning of the knob on a parameter that is logarithmic, and the value is what the parameter really is.
- The drawing window is a curve editor with draggable points that cannot cross each other in the horizontal direction, and some starting shapes (linear, logarithmic, exponential, S-shaped). The mapping panel, where the assignments are made, is where it opens from, with a shape button next to each assigned control. The widget does not exist in the panel kit yet, and every ReaImGui call that it adds needs a mock in `models/mock_imgui.zig`.
- Tests: the curve is increasing, and `f(f_inverse(x))` returns `x` to within a tolerance, for any list of points that the editor can produce, which is a property for zlowcheck.

It is a later phase. It does not change the first version, where the step is a plain multiple of the delta.


## The layer


The code sits in a new folder `src/unit/`. The existing files only change where they talk to the device.

```
src/unit/protocol.zig      the bytes: handshake constants, state frame builder with its checksum, event parser
src/unit/led_state.zig     the 97-byte shadow of the state frame, with a dirty flag
src/unit/ids.zig           control id <-> c1.CCs, and which controls are knobs, buttons and meters
src/unit/input.zig         sysex event -> ControlEvent, shift, the emulated knob positions
src/unit/unit.zig          Unit: the backend, the handshake state machine, poll and flush
```

Types and where they come from (each is new, and `Globals` gets one new field):

```
Backend = enum { legacy_cc, sysex }                         // src/unit/unit.zig

Link = union(enum)                                          // src/unit/unit.zig
    idle
    handshaking: struct { step: u8, deadline_ms: u64 }
    ready
    failed                                                  // chose legacy_cc

Unit = struct                                               // src/unit/unit.zig
    backend: Backend
    link: Link
    leds: LedState                                          // src/unit/led_state.zig
    shift_held: bool
    knob_pos: std.EnumArray(c1.CCs, u8)                     // the emulated absolute positions (phase 1)
    button_state: std.EnumArray(c1.CCs, u8)                 // for the 00, 3F, 7F cycle of Order and Sidechain
    counter: u7
    last_flush_ms: u64

ControlEvent = union(enum)                                  // src/unit/input.zig
    press: c1.CCs
    release: c1.CCs
    tick: struct { cc: c1.CCs, delta: i8, fine: bool }          // signed, like the MFT's value minus 64: its size grows with the speed
    legacy: struct { cc: c1.CCs, val: u8 }                  // what OnMidiEvent gets today

Globals.unit: Unit                                          // src/globals.zig, next to m_midi_in and m_midi_out
```

`c1.CCs` is the enum of `src/c1.zig`, and `std.EnumArray` is from `std`. The ids table in `ids.zig` is the table of `PROTOCOL.md` as code. `Comp_HiCut` and `Comp_LoCut` have no id because they are virtual, and the two display buttons and the shape and gate controls use the corrected ids of that table.

The flow of one `zRun`:

```
fn zRun()
    unit.poll(globals)
        for each event in the input list
            if event is sysex
                if kind is 00 (control)
                    handle(control event)             // below
                else if kind is 24 (ack)
                    note the ack of the counter
                else if kind is a handshake answer
                    advance the handshake
            else if event is a CC
                if backend is sysex and link is ready
                    // the unit sent a CC although it was in sysex mode: it was unplugged and replugged
                    link = idle                       // the handshake starts again
                else
                    legacy path: OnMidiEvent as today
    unit.tick(now)
        if link is handshaking and now > deadline
            step to the next try; after 3 tries, backend = legacy_cc and log it
        if backend is sysex and link is ready and leds.dirty and now - last_flush >= 30 ms
            send one state frame from leds; leds.dirty = false
    the rest of zRun as today

fn handle(control event)
    cc = ids.ccOf(event.id)
    if cc is shift
        shift_held = value != 0
    else if cc is a button
        if value == 0x7F                               // a press; the release is dropped in phase 1
            emit legacy(cc, button value)              // 7F, or the next of 00, 3F, 7F for Order and Sidechain
    else if cc is a knob
        tick = if value == 0x7F then +1 else -1
        step = if shift_held then 1 else 3             // what the legacy unit did
        knob_pos[cc] = clamp(knob_pos[cc] + tick * step, 0, 127)
        emit legacy(cc, knob_pos[cc])                  // phase 1
        (phase 2: emit tick(cc, delta, shift_held) instead, with delta from the speed of the last ticks)

fn setLed(cc, value)                                    // replaces c.MidiOut_Send(0xB0, cc, value)
    if backend is legacy_cc
        send the CC as today
    else
        leds.setValue(cc, value)                       // value byte = id + 1, and the bank A flag bit
        if cc is a knob: knob_pos[cc] = value          // the emulated ring follows the host, as the legacy ring did
```

The handshake is the four captured requests, sent one after the other, each after the answer to the one before; the state frame that the handshake sends is the first `leds` frame. The flag bits, the reversed bit order, byte 95 at 0x20 and byte 96 at 0x03 are all in `PROTOCOL.md`, and `led_state.zig` is a port of `tools/sniff-usb/state_frame.py`.


## What changes in the existing files


- `src/globals.zig`: a field `unit: Unit` (import `unit/unit.zig`), initialized where `m_midi_in` is.
- `src/csurf/control_surface.zig`: `init` (line 23) builds the `Unit` with the two device handles and starts the handshake. `zRun` (line 112) calls `unit.poll` and `unit.tick`. `deinit` (line 71) switches the LEDs off through the unit.
- `src/csurf/midi_events.zig`: `OnMidiEvent` is split into a decoder that reads the bytes and a function `onControl(globals: *Globals, cc: c1.CCs, val: u8)` with the whole `switch` of the modes. The decoder is only used by the legacy backend, and the unit calls `onControl` for the sysex events.
- `src/midi_out.zig`: every function that takes `midi_out: reaper.midi_Output` takes `unit: *Unit` (from `unit/unit.zig`) instead, and the 16 `c.MidiOut_Send` calls become `unit.setLed(cc, value)`. `sendMidiFeedback` passes `&globals.unit` and no longer needs `globals.m_midi_out`. `clearAllLEDs` clears the flag bits, with the compressor and shape meters at 7F as today.
- `src/tracklist_actions.zig:49`: the one send becomes `unit.setLed`. `led_state.midi_out` in that action becomes the unit.
- `src/csurf/midi_wrapper.cpp` and `midi_wrapper.h`: `MidiOut_SendMsg` is already there. A helper is added that builds a `MIDI_event_t` of the size of the frame (the struct holds 4 bytes and says that it can be longer, so the helper allocates the header and the bytes together).
- `src/ui_state.zig`: `UiState` gets `legacy_mode: bool` (true when `globals.unit.backend` is `.legacy_cc`) and, for the shift views later, `shift_held: bool`. `src/imgui_loop.zig:145` fills them where it builds the `UiState`, next to `midi_connected`. The UI library is a separate hot-reloadable compilation unit that cannot import `globals.zig`, so the flags travel in `UiState`. `src/models/test_ui_state.zig:24` and `src/tests/gui_integration_test.zig:110` build a `UiState` too, and need the new fields.
- `src/fx_ctrl_panel.zig`: next to the branch at line 262, a notice while `ui.legacy_mode` is true, so that the user sees that the handshake failed and that the unit runs in the legacy mode.
- Apart from the notice, nothing in the modes, the GUI, the mappings or the state machine changes in phase 1.


Added by the shift functions and the presets:

- `src/csurf/midi_events.zig`: `onControl` calls `shiftFunction` first in the fx_ctrl mode while `globals.unit.shift_held` is true. In the mapping panel entry, a plain `.Inpt_preset` no longer dispatches `.change_mode = .mapping_panel` (line 39); it dispatches the presets action once the presets exist, and does nothing before that.
- `src/fx_ctrl_actions.zig:42`: the `.Inpt_preset` case of `panel_input`, which is the Preset button of the screen, changes in the same way. The screen then needs another way to open the mapping panel, which is a button of the panel, or the automatic opening.
- `src/csurf/midi_events_fxctrl.zig`: `shiftFunction` is added here.
- `src/tracklist_actions.zig`: a `step_track` action (`TrackListAction` in `src/action_types.zig`) with a direction, which selects the neighbor of the current track and moves `current_page` with it.
- Phase 4, the presets (done, see the section on the presets screen below):

19. The screen, its actions and its state (`src/presets_actions.zig`, `src/presets_panel.zig`, `PresetsState` in `src/statemachine.zig`), the preset file format (`src/preset_store.zig`) and the REAPER calls (`src/fx_presets.zig`).

Later: the other step settings (a multiplier per control, a step per parameter, acceleration), the custom scale of a parameter (the `scale.` keys of the map structs and their reader and writer in `mappings.zig`, the curve and its inverse with their tests, the curve editor widget in the panel kit with its mocks, and the shape button in the mapping panel), and the second set of mappings on the knobs.

## The presets screen

Because REAPER has no call that saves a preset, `src/preset_store.zig` writes REAPER's own preset file (`<resource>/presets/<kind>-<plugin>.ini`, found with `TrackFX_GetUserPresetFilename`), in the way that EUGEN27771's script "Save VST Preset to preset file" does (Cockos forum, thread 178127): the state is the decoded base64 lines of the VST chunk of the track, or the slider line of a JS, followed by the name, in hex, with two hex digits of checksum at the end of every Data line, and Len as the number of bytes. The checksum and length rules and the JS layout were checked against 1092 of the 1100 presets of a REAPER preset folder. Loading is `TrackFX_SetPreset` by name. Only the user presets of the .ini files are listed, as in ReaLearn's pot browser, and not the factory presets of the plug-in. Only a VST (VST3 included), a JS and a CLAP can be saved.

The stages: the modules with their FX (a module without an FX cannot be picked), then the presets of that FX to load one, or a text box for the name to save under, and a question when the name is taken. On the unit, Preset opens the loading and shift with Preset opens the saving; Volume scrolls, Solo confirms and Mute cancels, and the name is typed on the keyboard. The window bar has two buttons for the same. In the legacy mode the unit's Preset still opens the mapping panel, and the two buttons of the window bar are the way to the presets.

## Open questions

1. Whether the first preset that is saved really loads in REAPER, for each kind of plug-in, which only a run on the unit's computer can show. The unit tests check the file that is written.
2. The mapping panel from the unit. The default is the screen only, and the automatic opening when a plugin has no mapping.
3. When the custom scale is built, whether the ring shows the value of the parameter or the position of the knob.
4. The value of the step, which is tuned on the unit. It starts at 1/127.
