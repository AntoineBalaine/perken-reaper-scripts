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

The extension drives REAPER's last-touched track, so selecting a track or
touching one of its FX points the encoders at that track. There is no
controller-based track selector.

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
where `<MODULE>` is IO, GATE, EQ, or COMP. When an encoder is turned, the
extension scans the current track's FX chain for the first FX whose name has a
map for the active module.

Factory default maps for ReaEQ, ReaComp, ReaGate, and the RBJ filters are
embedded in the binary and written to disk on first run. They are derived from
the Console One factory maps.

## On-screen panel

When ReaImGui is present, a panel mirrors the hardware: a 4x4 grid of encoders
with three side buttons on each edge. The top eight cells show the live value of
each mapped parameter as a bar; the bottom eight are the module selectors, with
the active module highlighted in its color.

## Calibration

The MIDI CC numbers, the relative encoding direction, and the LED color and ring
values are taken from a ReaLearn controller configuration and from the device
documentation, not from testing on hardware. On first use with a real MFT,
expect to confirm the encoder direction and tune the color hues. Those live in
`mft.zig` (channels, sensitivity, two's-complement decode) and `mft_state.zig`
(the per-module hue table).
