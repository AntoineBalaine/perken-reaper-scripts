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
- R1, R2, R3 toggle mute, solo, and phase invert on the current track.
- L2 and L3 are unused for now.

The extension drives REAPER's last-touched track, so selecting a track or
touching one of its FX points the encoders at that track. There is no
controller-based track selector; in transport mode encoder 7 scrolls the
selected track.

### Transport mode

Selecting TRANSPORT reuses the eight top encoders for transport control. Each
has a rotation function and a press function:

- Rotations: jog, scrub, zoom horizontal, zoom vertical, playrate, grid, track
  select, marker jog.
- Presses reset or toggle their own knob's function: pressing the playrate knob
  resets the playrate to 1, pressing the grid knob toggles snap, and pressing the
  marker-jog knob inserts a marker at the cursor or removes the one already
  there. The other encoder presses are unassigned in transport mode.

### Settings mode

Selecting SETTINGS edits the preferences, persisted to
`Data/Perken/MFT/preferences.ini`. Encoder 1 scrolls a highlight through the
settings list; encoder 2 adjusts the highlighted value. The numeric settings are
the four module LED hues (previewed live on every knob as you adjust) and the
encoder sensitivity. The five default plugin names are edited with the keyboard
in their text fields. Save writes the ini; Cancel reloads it, discarding edits.

## LED feedback

Two kinds of feedback go back to the device:

- Ring position (channel 1): after each parameter change the new value is scaled
  to 0 to 127 and sent to the encoder's LED ring.
- Color (channel 3): on a module switch every knob is recolored to the active
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

When ReaImGui is present, a panel mirrors the hardware: a 4x4 grid of encoders
with three side buttons on each edge. The top eight cells show the live value of
each mapped parameter as a bar; the bottom eight are the module selectors, with
the active module highlighted in its color.

The panel uses the same color palette and style as the Console One UI. The
palette is a copy of the Console One theme INI (`resources/default_reaper_theme.ini`),
pushed as ImGui colors and style vars around the window each frame.

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
