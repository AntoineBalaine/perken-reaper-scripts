# Console 1 in sysex mode: retrofit or layer

This is the analysis behind the decisions. The decisions and the plan to implement them are in `sysex-mode-plan.md`.

## Goal

Because the unit only reports shift, relative knob ticks and its other controls after the Softube handshake, and because it then lights nothing by itself, the extension has to change how it talks to the unit. This document compares two ways of doing it, a retrofit of the whole extension and a device layer under the existing code, and recommends one. The protocol itself is in `tools/sniff-usb/PROTOCOL.md`. Every statement about the unit below comes from that file, and every statement about the extension comes from reading the code on branch `c1UI` at commit `163a3022`.

## Recommendation

Build a device layer under the existing code, keep the legacy CC mode as a fallback behind it, and then move the consumers of the knobs to relative ticks one at a time. Do not retrofit first.

- The extension already touches the CC protocol in very few places: one input function, one feedback module, one stray send and the device setup. A layer can sit exactly there, and the state machine, the GUI and the tests do not change.
- The handshake was captured from firmware 1.19 of one unit. Because nothing proves that other firmware accepts the same bytes, the extension needs a way back to the mode that works today. A layer gives that for free (the handshake times out, the layer chooses the CC backend). A retrofit cannot.
- The gain of relative mode is in a few consumers: parameter knobs, volume and pan, and the scroll and jog knobs. A layer lets each of those move on its own, with its own tests, after the unit works end to end.

## What the unit changed

| | legacy CC mode (what the code is written for) | sysex mode (after the handshake) |
|---|---|---|
| knob input | an absolute value 0 to 127, kept by the unit, in steps of 3 (1 with shift) | one message per tick: 7F clockwise, 00 counter-clockwise, no magnitude |
| button input | one CC per press; the unit seems to toggle the value, and Order and Sidechain cycle 00, 3F, 7F (inferred from the code, not measured) | 7F on press, 00 on release |
| shift | no message | its own control event, so the host decides what it does |
| LEDs and rings | the unit moves its own ring as you turn, and the host corrects it with CC feedback | the unit lights nothing by itself; the host sends the state of every LED in a state frame |
| meters | CC 0x6E to 0x73, value 0 to 127 | value bytes 67 to 72 of the state frame, plus a flag bit each |
| start | works on connect | needs the handshake every time the unit appears, and falls back to legacy after a replug |

## What exists today

The contact points with the unit, with the lines that matter:

- Device setup: `src/csurf/control_surface.zig:23` `init(indev, outdev, errStats)` opens the input with `CreateMIDIInput` and the output with `CreateThreadedMIDIOutput`, from the device numbers in REAPER's control surface settings. `deinit` is at line 71. There is no hot-plug handling: a device that goes away is not noticed.
- Input: `zRun` (`control_surface.zig:112`) swaps the input buffers and calls `OnMidiEvent` (`src/csurf/midi_events.zig:10`) for each event. `OnMidiEvent` reads only 0xB0 messages, with a running-status shortcut, turns the CC number into a `c1.CCs` and switches on the mode. It ends in `actions.dispatch` with a `(cc: c1.CCs, val: u8)` pair. A sysex event is read as an unknown CC and ignored.
- Feedback: `src/midi_out.zig:16` `sendMidiFeedback(globals, action)` takes a `MidiOutAction` (`mode_entry`, `clear_all`, `track_select`, `page_change`, `set_param`, `blink`, `reset_meters`, `queryMeters`, `settings_changed`). It has 16 `c.MidiOut_Send` calls, `setParamLED` at line 149 and `clearAllLEDs` at line 58, all as CC and a value from 0 to 127. One more send is in `src/tracklist_actions.zig:49` (the blink of the selected tracks). Six files dispatch `.midi_out` actions in 36 places (`control_surface.zig` 9, `fx_ctrl_actions.zig` 9, `transport_actions.zig` 9, `midi_events_fxctrl.zig` 5, `csurf_actions.zig` 3, `settings_actions.zig` 1).
- Tests: none of the test files injects CC bytes. `src/models/c1_model.zig` and `src/models/midi_wrapper_mock.zig` are the only users of the absolute model, and two tests say in a comment that `OnMidiEvent` cannot be tested directly (`tests/fx_sel_fx_ctrl_forward_test.zig:61`, `tests/mapping_panel_fx_ctrl_forward_test.zig:36`).

The places that assume an absolute value:

- Parameter knobs: `setPrmVal` (`midi_events_fxctrl.zig:249`) turns `val` into `val / 127`, and takes the previous value from the UI state to know the direction for stepped parameters (`TrackState.stepDiscreteParam`).
- Volume and pan: `u8ToVol` (line 233) and `u8ToPan` (line 227) map the 0 to 127 position through REAPER's slider curve.
- Scrolling and transport: the browse, settings and mapping scrolls, and the transport grid, jog, marker jog, item jog and zoom, each keep an absolute position that mirrors the knob and turn it into a delta with `utils.calculateNewScrollPosition` or `utils.calculateClampedDelta` (`fx_sel_actions.zig:204`, `settings_actions.zig:136`, `transport_actions.zig:21` to `164`). They then write the position back to the unit as feedback, so that the ring and the state agree.
- Keeping the ring in step with REAPER: `zSetSurfaceVolume` with `vol_lastpos` (`control_surface.zig:142`) and `syncFilterKnobs` (`midi_events_fxctrl.zig:303`) push the REAPER value to the unit, because the unit would otherwise report an old position.
- Three-state buttons: `Tr_order` and `Tr_ext_sidechain` read `val` as 0x00, 0x3F or 0x7F.
- The mapping panel: `assign_update_knob` takes `value / 127`.

The MFT extension in the same repository already decodes relative encoders (`src/mft/mft.zig:30` `decodeRelative`, `FINE_SENSITIVITY_MULTIPLIER = 0.1`). It is a separate library that cannot import files outside `src/mft`, so it is a precedent for the behavior and not code to share.

One thing seen on the way and not related to this work: in `zRun` the meter query (`queryMeters`) sits inside `if (mode == .fx_ctrl and selectedTracks.count() > 1)`, together with the blink. It reads as if the meters are only updated while several tracks are selected. This should be checked before the meters move to state frames, because it decides how often a frame is sent.

## The options

### A. Retrofit

Replace the `(cc, val)` model in every consumer with a control event that carries a press, a release or a tick.

- It touches many of the 37 files that mention `c1.CCs` or import `c1.zig`, in particular `midi_events.zig`, `midi_events_fxctrl.zig`, `midi_out.zig`, `fx_ctrl_actions.zig`, `fx_sel_actions.zig`, `settings_actions.zig`, `transport_actions.zig`, `mapping_actions.zig`, `track_state.zig` and the models.
- The gain is the cleanest end state: no second copy of the knob position, no feedback only to keep a ring in step, full resolution.
- The cost is a large change to the mode logic at once, with the legacy mode gone. If the handshake fails on another unit, the extension has nothing to fall back to.

### B. Layer that emulates the legacy unit

A new layer turns sysex into the same `(cc, val)` calls that `OnMidiEvent` makes today, and turns the CC feedback into state frames. It keeps a virtual absolute position for each knob: a tick moves it by 3 (1 with shift, as the legacy unit did) and a feedback value sets it. Nothing above the layer changes.

- It is the smallest change, and it keeps the legacy mode as a fallback.
- It keeps every absolute-value workaround, and the quantization to 127 steps. It adds a fake knob position that must stay in step with the host, which is the same job that the feedback does today.

### C. Layer with a relative seam (recommended)

B first, and then the layer also offers the real events, so that each consumer can leave the emulation when it is ready: a `tick` event carrying `(cc, direction, fine)` next to the legacy `(cc, val)`.

- It has the speed and safety of B and a path to the end state of A, in steps that can each be tested and each be undone.
- It needs the seam to be designed once, below, and not to grow with the first consumer that uses it.

| | A retrofit | B emulate | C layer and seam |
|---|---|---|---|
| files changed at first | about 15, plus tests | 5 | 5 |
| keeps the legacy mode as a fallback | no | yes | yes |
| risk to the mode logic | high | none | none at first, then per consumer |
| full resolution and fine adjust | yes | no | yes, consumer by consumer |
| code for the fake knob positions | none | yes | yes, shrinking |

## Shift

Shift is a control event of its own (id 02), so the unit tells the host when it is held. The layer keeps `shift_held` and passes it on. The legacy backend has no shift, and the mode button and the transport mode stay as they are there, because the transport mode was the way around the missing shift.

### What Softube's own manual says

The Console 1 user manual of December 2018 (the version of Mk I and Mk II, found at [klangfarbe.com](https://www.klangfarbe.com/files/Shop/Artikel/43083/A-S43083_1.pdf); the page numbers below are those of its table of contents) describes the shift functions that the extension is copying. It calls the key Shift/Fine Adjust.

- Fine Adjust/Shift, held while a knob is turned: smaller increments, "or to access the extra functions labeled in orange". So Softube uses shift as the fine adjust and, where a knob has an orange label, as the extra function. The knobs with a label are Drive, Character and Pan, which become Send 1, 2 and 3 under shift (in a DAW with integrated control), and Volume, which controls Console 1's internal volume under shift. This is the fourth way of the section on why shift cannot be both, and it is Softube's own.
- Preset (page 39): "Press the Preset/Save Preset button to call up a list of entire channel strip presets." Then Volume/Select picks a category: Factory Channel Strip (the entire strip), Factory Shape, Factory Equalizer, Factory Compressor (each only that section), and the user's own Presets. Solo/OK confirms. "A preset can contain the entire channel strip, or one or several sections", and loading an equalizer preset only overwrites the equalizer.
- Shift and Preset saves (page 40): Solo/OK saves the entire strip, or the on/off buttons of some sections are pressed first (shape, EQ, compressor), and then Solo/OK saves only those. A name is asked for, in a file browser.
- History (page 43), shift and Tr5: "an unlimited undo function for its settings". Volume/Select scrolls back and forward in time and the parameters change back; Solo/OK (or Mute/Cancel) ends it. Entering History again and going back one step undoes the undo. It undoes the settings of the Console 1 plug-in, not the DAW.
- Page Up and Page Down with shift: "step between tracks instead of pages".
- Copy with shift: select all tracks at once, so that any adjustment affects all of them (page 36). The user's face prints this as Dupe and All.
- Display On with shift: the on-screen display appears when a setting changes, and goes away after a few seconds.
- Phase Invert with shift: bypass the whole plug-in.
- In menus and dialogs, Solo is OK, Mute is Cancel and Volume is Select, without shift.

Of these, the user wants none of Page Up and Page Down with shift, Copy with shift, Display On with shift and Phase Invert with shift in the fx_ctrl mode. What Softube's software calls a preset, the settings of a strip or of some sections, is what the Preset button is for here too. The mapping panel is a separate thing, the mapping of a plugin or of a strip, and is not reached from Preset any more.

### Why shift cannot be both

The user wants the finer step of the MFT, with shift as the fine adjust, as the legacy unit had it. The user also wants a second set of mappings on the knobs while shift is down. Both need the same key. The ways out:

1. Keep shift as the fine adjust, and put the second set on another modifier: a button held down, or a button that latches a second layer and lights its LED, like a page.
2. Make the fine adjust automatic: the step depends on how fast the knob turns, small for slow ticks and large for fast ones, as it does on the MFT. Then shift is free for the second set. The cost is a feel that is less predictable than a fixed fine step, and the speed has to be computed in the layer (see the section on the step of a tick).
3. Tap and hold: holding shift while turning a knob is the fine adjust, and a short tap of shift, with no other control used, latches the second layer. The cost is a rule that has to be learned.
4. Decide per control, from the map: a knob that has a shift assignment uses shift for the assignment, and a knob without one keeps the fine adjust. The cost is that the fine adjust disappears from the knobs that get a second assignment. This is what Softube's own unit does, see the next section.

The decision for now is to keep the fine adjust. Because the map reader skips keys that it does not know (`readToU8Struct` in `mappings.zig:741` only matches the fields of the struct and ignores the rest and the sections), shift assignments can be added to the map files later as new keys, with the format version still at 1, and a build that does not know them still loads the file. That keeps the choice open. Volume is the one knob that is not a fine adjust under shift, because shift and Volume is Select on the face.

### The step of a tick

The numbers to start the discussion from:

| | step of one tick |
|---|---|
| legacy unit | 3 of 127 (0.0236), and 1 of 127 (0.0079) with shift. Fixed, whatever the speed |
| MFT in this repository | the delta times 1 of 127, times a user setting `sensitivity` (default 1.0), and times 0.1 while a key is held. It reads the parameter from REAPER on each tick and clamps the new value (`src/mft/csurf/midi_events_mft.zig:66`, `mft.zig:11`) |

The MFT does not accelerate in the extension. The controller does: its relative mode is centered on 64, one click sends 65 or 63, and faster turns send values further from 64 (`decodeRelative` in `mft.zig:30`, which says that this was confirmed on hardware by the calibration wizard). The Midi Fighter Utility has a velocity-sensitive setting for this, which is on the settings of the user's MFT. So what the user feels on the MFT is the controller's acceleration, then the 1 of 127 and the held fine multiplier.

The Console 1 cannot do that in the unit. In the sysex mode every tick is the same message, 7F or 00, with no magnitude. The only speed there is is the time between messages. In the mapping session (870 knob ticks) the median gap between two ticks of one knob was 13 ms (about 77 a second), the fast end was 6 ms (about 167 a second), and the most that one knob sent in 200 ms was 29 ticks. Because several messages can arrive in one USB packet, single gaps are noisy (some are 0 ms), so a speed has to come from a short window of ticks and not from one gap.

So the speed has to be computed in the layer, and the way to keep the rest of the code simple is to give consumers what the MFT gives them: a signed delta whose size grows with the speed. The layer turns ticks into `delta` (1 for a slow turn, larger for a fast one), and the consumer does what the MFT code does, the delta times a base step times the fine multiplier, on the value read from REAPER. A fixed step is the same code with the delta always 1. How the delta grows with the speed, the base step and the user setting are the things left to decide.

How other controllers and DAWs handle it, from what could be found (forum posts, manuals and manufacturer pages, not specifications, and each point is only as good as its source):

- Acceleration in the hardware. Mackie Control V-Pots send a tick count in the low six bits and a direction bit, so a faster turn is a bigger number and the host maps it ([Bome forum on the MCU protocol](https://forum.bome.com/t/motormix-pan-knobs-using-mackie-mcu-protocol/1076)). The Twister has a velocity-sensitive option and the relative mode of 3F and 41 ([DJ TechTools forum](https://forum.djtechtools.com/t/question-about-twister-relative-3fh-41h-encoder-mode-firmware/77270)). A Cubase user reports that Cubase has no setting for how fine an encoder step is, and that a Digidesign Control 24 has a button for velocity-sensitive encoders, which puts the acceleration in the hardware or its driver ([Steinberg forum](https://forums.steinberg.net/t/can-i-make-one-encoder-encode-faster/844973)).
- A modifier for the fine adjust. Native Instruments lists shift and a knob as the fine adjust for Logic and Cubase ([Kontrol S MK3 manual](https://www.native-instruments.com/ni-tech-manuals/kontrol-s-mk3-manual/en/daw-control)), a Tascam manual gives control and the encoder as the fine adjust in Cubase LE ([Tascam FW-1884 notes](https://tascam.com/downloads/tascam/229/fw1884_cubase_le_notes.pdf)), and Ableton Push is described as using shift for a much finer step ([Elektronauts thread](https://www.elektronauts.com/t/fine-midi-cc-adjustments-on-every-midi-controller-like-abletons-push-shift-button-does/194203)). This is the most common pattern in these sources, and it is what the legacy Console 1 did.
- A resolution setting in the host. An older Logic manual has a control surface preference for the resolution of relative controls ([Logic Pro 7 manual](https://www.manualsdir.com/manuals/547416/apple-logic-pro-7.html?page=664)), which is the same idea as the `sensitivity` setting of the MFT.
- Acceleration computed by the host from the timing of the ticks. Users of ReaLearn have asked for it, to simulate the acceleration for controllers that have none, from the time between messages ([Helgobox issue 715](https://github.com/helgoboss/helgobox/issues/715)). The request was open when it was filed, and it was not checked whether it was done since. That it is requested suggests that it is not usual in host software.
- More resolution in the hardware: Nektar lists the Panorama CS12 as having fine control with up to 10x 14-bit resolution ([Thomann listing](https://www.thomann.pt/nektar_panorama_cs12.htm)), and the BCR2000 has 14-bit relative modes.

None of these sources calls one way the standard. In short, acceleration is usually the controller's job, and a host that receives plain ticks usually offers a fixed step with a modifier for the fine adjust and a sensitivity setting. Bitwig and Eucon could not be checked from what was found.

Measured, and not very reliably: a revolution of the input Gain knob by hand gave 34, 41 and 47 ticks clockwise, in 0.4 to 0.8 s, and 52 and 57 counter-clockwise, in 0.7 to 0.8 s (`tools/sniff-usb/count_ticks.py`, one run of five usable turns, 2026-10-29). The count follows how fast the turn was, because a hand does not turn exactly one revolution. The turns that took longer gave more ticks, which may mean that the unit sends fewer messages when it is turned fast, but five turns do not show that. The user's MFT setting `sensitivity` is 1.00 (`Data/Perken/MFT/preferences.ini`).

A rough comparison, with the caution that the numbers are soft: about 45 ticks for a revolution at 3 of 127 per tick is about one full range per revolution, which is the legacy feel. A step of 1 of 127 would be about 0.35 of the range per revolution. A forum post says that the Twister sends about 100 messages for 360 degrees (not checked here), which at 1 of 127 is about 0.8 of the range per revolution at the slowest speed. If that holds, a Console 1 tick has to be about twice the MFT's to travel the same distance per revolution.
