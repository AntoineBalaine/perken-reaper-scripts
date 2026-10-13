# perken-extensions

Editing helpers for REAPER as a compiled extension (Zig, built on
[reaziglib](../reaziglib)). Every action shows up in REAPER's action list as
`Perken: <name>` and can be bound to any key, from REAPER's own keymap or from
[reavim-ext](../reavim-ext)'s `bindings.ini`.

## Actions

| Module | Actions |
|---|---|
| drums | Flam, Ras3, Ras5, Crescendo, Decrescendo, QuantizeTool (stub) |
| kawa (MIDI editor) | chord note selection, drop-2/3/2&4 voicings, octave/interval doublings |
| routing | RouteToBusses, BuildBusses |
| fx | InsertFxAtSlot (stub) |
| items | paste before cursor, 2 ms fades, fades and trims from the mouse, split at note starts, stretch to cursor |
| tracks | volume ±3 dB, rename from the VSTi preset, exclusive solo |
| envelope | point min/max/center, nudge points, delete points, toggle at time selection, select points |
| keysnap (MIDI editor) | toggleKeySnap (stub) |
| batch_rename | BatchRenameTracks: rename the selected tracks in your editor |
| auto_lane_watcher | AutoLaneWatcher (toggle): touching an FX parameter shows its envelope lane and hides the track's others; the lane is dismissed when you change track or close the FX, and removed if it received no automation. In trim/read mode, plugin-UI tweaks trim the lane. Removing unused lanes needs SWS. |

Each action's command id is `_PERKEN_<name>` (e.g. `_PERKEN_Flam`). Actions
for the MIDI editor are registered in the MIDI editor section.

The auto lane watcher reacts to REAPER's state changes through a hidden
control surface (reaziglib's `csurf` shim), registered only while the
watcher is on; it does not appear in REAPER's control surface preferences.

## Settings

Optional, in `<resource path>/Data/Perken/perken-extensions.ini`:

```ini
[rename]
terminal = open -a iTerm      ; default: Terminal.app on macOS, x-terminal-emulator elsewhere
editor = nvim                 ; default: $VISUAL, else $EDITOR, else vim
close_terminal = true         ; macOS: close the Terminal.app window afterwards
```

## Build

```sh
zig build test        # unit tests
zig build             # Debug build into zig-out/
zig build -Doptimize=ReleaseSafe
```
