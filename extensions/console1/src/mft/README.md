# MFT extension

A REAPER control-surface extension for the DJ TechTools MIDI Fighter Twister (MFT), built from the Console 1 extension of this repository. It is a
separate shared library (`reaper_mft`) that shares no symbols with the Console 1 extension, so the two can be installed side by side, and a track that
one of them set up is recognized by the other.

The MFT has sixteen push encoders in a 4x4 grid and six side keys. Because it has far fewer controls than the Console 1, the controller is organized in
pages: the bottom row selects the page, and the sixteen encoders work on the page in use.

## Building and installing

The toolchain is Zig 0.17.0, because the extension uses the `std.Io` convention of that version (see `mft_globals.hostIo`).

```
zig build mft        # builds reaper_mft into zig-out/
zig build mft-test   # runs the unit tests of the MFT
```

The artifact is `reaper_mft.dylib` on macOS, `reaper_mft.so` on Linux and `reaper_mft.dll` on Windows. `extensions/build-install.sh -n mft` builds it,
copies it into the `UserPlugins` folder of REAPER, and installs the factory maps with `extensions/install-maps.sh`. Because the maps are installed apart
from the binary, a map that the user edited is kept, and the new factory map is written beside it as `<map>.ini.new`.

A release (the tag `mft-v<version>`, built by `.github/workflows/mft.yml`) has the binary of each platform, the font licenses, and
`mft-factory-maps.zip` with `install-maps.sh`. To install the maps of a release, unzip them and run
`install-maps.sh maps/factory "<REAPER resource folder>/Data/Perken/MFT/maps/factory"`.

In REAPER, enable the surface under Preferences, Control/OSC/web: add a surface of type `PRKN_MFT`, and choose the MFT as its MIDI input and output.
The on-screen windows need ReaImGui; without it the extension runs headless.

## Pages

Encoders are numbered 1 to 16, left to right and top to bottom. A push of an encoder of the bottom row selects a page:

| encoder | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| page | INPUT | GATE | EQ | COMP | SETTINGS | TRANSPORT | AUTO | OUTPUT |

The LEDs of the bottom row have the color of their page, and the top rows the color of the page in use.

### Module pages

INPUT, GATE (the shape), EQ, COMP and OUTPUT are the modules of the Console 1. Each one has a plugin on the track, and its map gives each of the sixteen
knobs a parameter, and each of the eight pushes of the top rows a parameter to step or the shape of an EQ band to change. The sixteenth knob is the
dry/wet of the plugin on every factory map.

- A turn moves the parameter of the knob; turning an encoder while it is held is a fine adjustment (the fine multiplier of the settings). A parameter
  that is a switch, or that has 64 steps or fewer, moves one step for four ticks.
- A click on a push steps its parameter, and a pop-up over the knob in the window of the device says what it changed.
- Pressing a module button inserts the default plugin of the module when the track has none (the settings can turn this off, or insert the plugin
  bypassed). In the single FX mode, a track that has none of the plugins of the modules gets the default channel strip instead, which takes every page.
- The settings can also put the shape, the EQ and the compressor in the preferred order on each module button.

### TRANSPORT

The top two rows have a turn and a push each:

| encoder | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| turn | Jog | Item | Zoom H | Zoom V | Rate | Grid | Track | Marker |
| push | Play/Stop | Play/Pause | Fit H | Fit V | Rate = 1 | Snap | Record | Marker |

Encoder 3 turned while it is held zooms vertically. The turns of the bottom row are Loop In, Loop Out, Order (the order of the modules of the track,
whose pop-up shows the order it put the track in), Loop, and the volume and the pan of the track, whose rings follow REAPER with 0 dB at noon.

### AUTO

The page that the user fills: each knob and push can run a REAPER action, an action of an extension (kept by its name), an action of the MFT, or move a
parameter of a plugin of the track, found by its name. The factory map has the automation modes on the first five pushes.

### SETTINGS

Encoder 1 scrolls the rows of the settings, encoder 2 changes the row that is lit, push 2 flips a switch, push 7 saves and push 8 cancels. The settings
have a window of their own (see below), and are saved to `Data/Perken/MFT/preferences.ini`.

## Side keys

The side keys are on channel 4, CCs 8 to 13, in the order L1, L2, L3, R1, R2, R3.

- L1 opens the FX chain of the track on the plugin of the page in use, and opens an empty chain when the track has no plugin.
- L2 bypasses the plugin of the page in use; on the TRANSPORT page it hides and shows the window of the device.
- L3 opens the FX Selection, and closes it.
- R1, R2 and R3 toggle the mute, the solo and the phase of the track.

The controller works on the track that REAPER last touched.

## FX Selection

L3 opens the FX Selection for the page in use, in a window of its own and on the controller. Encoder 13 scrolls and its push confirms, encoder 14 goes
back, the bottom row chooses the module, and encoder 15 toggles the single FX mode (the channel strip). Its first screen has four actions:

- Load FX: the plugins that have a map for the module, and every plugin of REAPER by type and by tag, with a fuzzy search that takes the typing. A
  plugin that has several maps asks which one to load it with. The Default button of a plugin makes it the default of the module, and the Default
  button of a map makes it the map that the plugin is loaded with.
- Select preset and Save preset: the user presets of the plugin of the module.
- Create mapping: the mapping panel.

## Mapping panel

The mapping panel edits the maps of every module at once, with a plate for each module and one for the AUTO page, in the layout of the controller.
Each knob has a combo for its turn and, on the top rows, one for its push. A change is saved as soon as it is made, as the user's map.

- MIDI learn: touch an encoder to choose its control, then move a parameter in the window of the plugin.
- Alt-click a combo to clear its control, and right-click it to give the control a name of its own (up to 31 letters), which the window of the device
  shows instead of the name of the parameter.
- On the line of the title of a plate: the plugin (a click opens the browser to swap it), the window of the plugin, the state key, and the map in use.
  The state key stores the preset and the parameter values of the plugin in the map, which loading the plugin with the map restores (Alt-click to keep
  none). The map picker chooses another map of the plugin, or makes a new one from the map that the plate shows.
- The single FX mode edits the map of the channel strip, with a section for each page.

## Maps

A map is an INI file under `Data/Perken/MFT/maps/<user or factory>/<MODULE>/<plugin>/<map>.ini`, where MODULE is INPUT, GATE, EQ, COMP, OUTPUT, STRIP or
AUTO, and the plugin folder is the name of the plugin with the characters that a file name cannot have replaced. A map of the user is read before the
factory map of the same name.

```
version = 2
module = EQ
fx_name = VST: ReaEQ (Cockos)
knob_1 = 0
knob_16 = wet
push_1 = band:0

[labels]
knob_1 = Low freq
```

A knob is a parameter number or `wet`, a push is a parameter number, `wet` or `band:N` (the shape of the band N of the EQ). The section `[labels]` has the
names that the user gave the controls. The map of a channel strip has a section for each page (`[EQ]`) and `[<PAGE>.labels]` for its names; the map of
the AUTO page has values `action:<id>`, `action:_<named command>` and `fx:<plugin>|<parameter>`. A map of version 1 (eight knobs) still loads.

A plugin can have several maps: `default.ini`, the maps that come from a pack (named after the pack), and the maps that the user made. A plugin uses its
default map, which is `default` until the user makes another one the default; the defaults are kept in `Data/Perken/MFT/default_maps.ini`. The state
that a map keeps is in `<map>.state`, next to it.

A plugin of a module is recognized as the Console 1 recognizes it: by a `(C1-X)` suffix on its renamed name, where X is I, S, E, C or O (input, shape,
EQ, comp, output), and X for a channel strip. The factory maps are ported from the maps of the Console 1 by `zig build port-maps`, including the channel
strips of the chmaha and Tukan packs.

## Windows

With ReaImGui, the extension draws the controller as an object in a window of its own: the sixteen encoders with their rings and the window under each
one that says what a turn and a push do, the side keys, and a header with a fold button and a close button. A value shows in a pop-up over its knob,
as the plugin formats it, while the knob is hovered, held or turned. The action "MFT: Toggle UI" shows and hides the window, and can be bound to a key.

The FX Selection, the mapping panel and the settings have windows of their own. The settings window has a plate for each group of rows: the colors of
the pages, the knobs (sensitivity and fine multiplier, which a double click lets the user type), the general options, the options of the tracks, and the
default plugins, chosen from lists that have a fuzzy search.

## Actions

The extension adds these actions to the Action List of REAPER, which can be bound to keys and run from the AUTO page:

- MFT: Toggle UI
- MFT: Module order EQ-S-C, MFT: Module order S-C-EQ, MFT: Module order S-EQ-C, MFT: Next module order, MFT: Previous module order

## Tests

The layout of the windows is checked by unit tests that draw them against the mock of ImGui from reaziglib (`zig build mft-test`).
