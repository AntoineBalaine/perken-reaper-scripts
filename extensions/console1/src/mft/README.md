# MFT extension

A REAPER control-surface extension for the DJ TechTools MIDI Fighter Twister
(MFT), built from the Console One extension in this repository. It is a separate
shared library (`reaper_mft`) that shares no symbols with the Console One
extension; the two can be installed side by side.

The MFT has sixteen push encoders in a 4x4 grid and six side buttons. Because it
has far fewer controls than the Console One, the eight top-row encoders are
reused across modules: the bottom eight encoders select which module the top row
drives.

## Building

The toolchain is Zig 0.14.1.

```
zig build mft        # builds reaper_mft.so into zig-out/
zig build mft-test   # runs the MFT unit tests
```

On Linux the artifact is `reaper_mft.so`, on macOS `reaper_mft.dylib`, on Windows
`reaper_mft.dll`. Install it by copying it into the REAPER `UserPlugins`
directory, then enable it under Preferences, Control/OSC/web, adding a new
surface of type `PRKN_MFT` and choosing the MFT as the MIDI input and output.

The optional on-screen panel requires ReaImGui. If ReaImGui is not installed the
extension still runs headless; only the panel is skipped.

## Controls

Encoders are numbered 1 to 16, left to right and top to bottom.

- Encoders 1 to 8 (top two rows): parameter control for the active module.
  Turning applies a relative change to the mapped FX parameter. Holding an
  encoder while turning engages fine-tune (a tenth of the normal step).
- Encoders 9 to 14 (bottom two rows): module selection. Pressing selects IO,
  GATE, EQ, COMP, SETTINGS, or TRANSPORT respectively. Encoders 15 and 16 are
  reserved.

The six side buttons are on channel 4, CCs 8 to 13, ordered L1, L2, L3, R1,
R2, R3:

- L1 toggles the track's FX chain window, focused on the active module's plugin
  (the last-tweaked FX in that module, else the module's primary FX).
- L2 hides and shows the on-screen panel.
- R1, R2, R3 toggle mute, solo, and phase invert on the current track.
- L3 is reserved for the fx/map selector.

The panel can also be toggled from REAPER's action list via the action "MFT:
Toggle UI" (id `PRKN_MFT_TOGGLE_UI`), which can be bound to a key, so the panel
can be reopened without the controller.

The extension drives REAPER's last-touched track, so selecting a track or
touching one of its FX points the encoders at that track. There is no
controller-based track selector; in transport mode encoder 7 scrolls the
selected track.

### Transport mode

Selecting TRANSPORT reuses the eight top encoders for transport control. Each
has a rotation function and a press function:

- Rotations: jog, item navigation (select and move to next/previous item), zoom
  horizontal, zoom vertical, playrate, grid, track select, marker jog.
- Presses reset or toggle their own knob's function: the zoom-horizontal and
  zoom-vertical knob presses fit the project horizontally and fit/minimize the
  tracks vertically, the track-select knob press inserts a new track, the
  playrate knob press resets the playrate to 1, the grid knob press toggles
  snap, and the marker-jog knob press inserts a marker at the cursor or removes
  the one already there.
- Experiment: knob 3 (zoom horizontal) can be turned while held to zoom
  vertically instead. Turning it normally zooms horizontally; holding it and
  turning zooms vertically; a plain click (press and release without turning)
  fits the project horizontally.

### Settings mode

Selecting SETTINGS edits the preferences, persisted to
`Data/Perken/MFT/preferences.ini`. Encoder 1 scrolls a highlight through the
settings list; encoder 2 adjusts the highlighted value. The numeric settings are
the four module LED hues (previewed live on every knob as you adjust) and the
encoder sensitivity. The five default plugins are chosen from drop-downs that list the
plugins installed in REAPER, with a filter at the top of each list. Save writes the ini; Cancel reloads it, discarding edits.

## LED feedback

Two kinds of feedback go back to the device:

- Ring position (channel 1): after each parameter change the new value is scaled
  to 0 to 127 and sent to the encoder's LED ring.
- Color (channel 2): on a module switch every knob is recolored to the active
  module's hue, so the surface always shows which module is live.

## Maps

Each module maps its eight encoders to FX parameter indices through an INI file:

```
version = 1
module = EQ
fx_name = VST: ReaEQ (Cockos)
knob_1 = 0
knob_2 = 3
...
knob_8 = 10
```

Maps live under `Data/Perken/MFT/maps/factory/<MODULE>/<fx_name>/default.ini`,
where `<MODULE>` is IO, GATE, EQ, or COMP.

FX are identified the same way as the Console One: by a `(C1-X)` suffix on the
FX's renamed name, where X is I, S, E, C, or O (input, gate, EQ, comp, output).
The MFT reuses this scheme, so a track set up by either extension is recognized
by the other. When an encoder is turned, the extension scans the track for FX
whose suffix names one of the active module's slots and merges their maps: each
FX fills the encoder slots its map defines, and the first FX to claim a slot
wins.

The IO module folds the Console One input and output plugins into one surface.
Input plugins (the RBJ filters, the two volume smoothers) map to knobs 1 to 4;
output plugins (ReaAnalog, Saturation) map to knobs 5 to 8. So an input plugin
and an output plugin on the same track drive one IO panel together without
colliding.

Factory maps for ReaEQ, ReaComp, ReaGate, and the five input/output plugins are
embedded in the binary and written to disk on first run. They are derived from
the Console One factory maps.

Switching to a module auto-inserts that module's default plugin onto the current
track if the slot is not already filled, matching the Console One behavior. The
defaults follow the Console One defaults: ReaEQ, ReaComp, ReaGate, and for IO
both the Volume/Pan Smoother (input) and Saturation (output). Insertion respects
the canonical track order (input, gate, EQ, comp, output) regardless of the
order the modules are selected, so selecting gate and then IO still places the
IO input ahead of the gate. An existing un-suffixed instance of a default plugin
is adopted (suffixed) rather than duplicated.

Not yet handled: reordering FX that are already on the track in the wrong order
(only newly inserted FX are positioned), and a preference to choose a different
default plugin per slot.

## On-screen panel

When ReaImGui is present, a panel draws the hardware as an object, as an object. The window has no title bar: a dark metal body with a screw in
each corner, a header row, a recessed faceplate with the sixteen encoders in four rows of four, and three keys on each
side (L1 chain, L2 hide, L3 FX select on the left; R1 mute, R2 solo, R3 phase on the right).

- Each encoder is a round rubber cap in a well, ringed by eleven white LEDs that light up to the value. The window under
  an encoder sits where the controller's color LED is: it is lit in the color of the module, and that color is the
  accent of the module's knobs. The color of each module is the controller's own color code for it (the LED hue
  converted to RGB), so the panel matches the hardware.
- In a module that maps parameters, a mapped encoder shows the name of its parameter under it, and an encoder with
  nothing mapped has a dark ring and an unlit window. The value shows as the plugin formats it ("-12.0 dB", "1.5 kHz", read with
  `TrackFX_GetFormattedParamValue`, only for the knobs that show one and again only when the value changed), or as a
  percentage when the plugin gives no text. It appears in a small pop-up over the knob while the mouse is
  over the knob or the encoder is held or turned, and for 500 ms after the last of these (`value_linger_ms` in
  `mft_imgui.zig`).
- In transport mode, the caps carry an icon for the function of their rotation, and the window under the knob has two
  lines: what a turn does, with a curved arrow, and under it what a press does, with a ring and a dot. A turn of the
  encoder lights the turn line, and a press lights the press line and sinks the cap, for as long as the encoder is held
  and for 500 ms (`linger_ms` in `mft_state.zig`) after the last message from it. The keys on the left light the same way
  while they are held.
- The bottom eight encoders select the module. The first six have the press line alone, lit in the color of the module,
  and the cap of the module in use is sunk. The last two are reserved.
- The keys on the right light up while the track is muted, soloed or phase-inverted.
- The header row has the card of the module in use on the left, the name of the controller in the middle with a green
  lamp (hover over it to read what the panel is), and two buttons on the right: the chevron folds the device to its
  header row, or opens it again, and the cross hides the panel (the L2 key or the action "MFT: Toggle UI" shows it).
- The settings form and the calibration card are drawn under the device, in the settings mode only (the calibration
  card also while a calibration is under way). The form shows the hue of each module on a bar that has the controller's
  color wheel, and the sensitivity on a plain bar. A click or a drag on a bar sets the value through the same code as
  the encoders, so the LED color is sent to the controller and the preference is updated.

The look comes from the shared panel kit of `reaziglib` (`panel_theme`, `panel_fonts` and `panel_widgets`), the same one
that the VR-09 plugin uses, in the embedded Saira Condensed and Librestile fonts. The drawing of the device is in
`mft_device.zig`, and the transport icons, drawn with geometry, are in `mft_icons.zig`. The panel only mirrors the
controller, so the encoders and the keys do not answer the mouse. The only parts that do are the two buttons of
the corner, the settings form (the bars, the drop-downs, Save and Cancel), and the calibration card.

## Calibration

The MIDI CC numbers, the relative encoding direction, and the LED color and ring
values are taken from a ReaLearn controller configuration and from the device
documentation, not from testing on hardware. On first use with a real MFT,
expect to confirm the encoder direction and tune the color hues. Those live in
`mft.zig` (channels, sensitivity, two's-complement decode) and `mft_state.zig`
(the per-module hue table).

To make that first calibration easier, the panel has a calibration wizard. Press
Start calibration and it walks through every control in turn: turn each encoder
one click clockwise, press each encoder, then press each side button. While the
wizard is active it captures the incoming MIDI instead of driving parameters, and
for each step it shows what it expected against what it observed and a
pass/fail/skip marker. Retry re-captures the current step, Skip moves on, Next
advances. Because the six side-button CCs are not firmly known, those steps just
capture and report whatever arrives, which is how you discover their real CCs.

Every step is also logged to the console (run REAPER from a terminal to see it),
and Finish or Stop writes a full report to
`Data/Perken/MFT/wizard_report.md`. A failed encoder-direction step means the
relative decode in `decodeRelative` is off; an unexpected CC means the CC map is
offset.

The panel also has an LED test button. While it runs, every knob cycles through
the MFT color palette and the rings sweep, so the color and ring feedback path
can be eyeballed independently of input. Stopping it restores the active
module's color. The module colors and the test palette are taken from the
verified values in `synth_map_midiFighter.lua`.

The panel's ImGui layout is checked for balanced Begin/End, group, and
style-color push/pop pairs by a unit test that runs it against the mock ImGui
from reaziglib (`zig build mft-test`).

## Planned / TODO

- Per-plugin sidechain routing. Because each module has eight push encoders
  available, sidechain routing can be exposed per plugin rather than as a global
  gate-to-comp link like the Console One. Deferred as a later feature.
- A preferences system so settings mode can edit the per-module default plugin,
  encoder sensitivity, and the LED colors.
- Full reordering of an FX chain that is already out of order (today only newly
  inserted FX are positioned).
- Confirm the physical side-button order (L1-L3, R1-R3) against the CC order
  8-13 on hardware; the wizard reports the observed CCs.
