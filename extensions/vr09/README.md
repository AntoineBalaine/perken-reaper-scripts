# vr09

A CLAP plugin for REAPER that controls a Roland VR-09 (and the VR-09B and VR-730, which share its MIDI implementation). It sits on a track, and from there it can:

- show and change the keyboard's documented parameters (organ drawbars, rotary, mixer levels, synth envelope, and 20 controllers sent as MIDI CC), and expose them to the host as automatable parameters;
- take the keyboard's current state as a patch, save it as a preset, and write a preset back to the keyboard, in about 0.15 seconds when the keyboard has been read;
- follow what you do on the keyboard's panel, so that the knobs and the project hold what the keyboard does;
- save the patch in the REAPER project, and send it to the keyboard when the project opens;
- import and export patches as the dump files that `vr09.py` of the roland-vr09 project reads and writes;
- send the track's audio to the keyboard's audio input and take its output back, like ReaInsert, with the round trip measured and reported to REAPER for delay compensation.

The keyboard's own Registrations cannot be selected, read or edited over MIDI. A patch is a dump of the keyboard's parameter values, and recalling it writes those values back. `docs/midi-capabilities.md` in the roland-vr09 project explains this, and the protocol this plugin speaks.

## Build and install

You need Zig 0.14.x. There is no C++ and no other dependency to install: the CLAP headers are fetched by `zig build`.

```
extensions/build-install.sh vr09
```

copies the plugin to REAPER's CLAP folder (`~/Library/Audio/Plug-Ins/CLAP` on macOS, `~/.clap` on Linux). To build by hand:

```
cd extensions/vr09
zig build test
zig build -Doptimize=ReleaseSafe          # zig-out/vr09.clap (a bundle on macOS)
zig build -Dtarget=x86_64-windows -Doptimize=ReleaseSafe
```

Every target builds from any host: `x86_64-macos`, `aarch64-macos`, `x86_64-linux-gnu`, `aarch64-linux-gnu`, `x86_64-windows` and `aarch64-windows`. A bundle downloaded from the release page carries macOS's quarantine flag; run `xattr -dr com.apple.quarantine vr09.clap` once.

The panel is drawn with ReaImGui, so install ReaImGui from ReaPack. Without it the plugin still works, with REAPER's generic parameter window.

## First use

1. Plug the keyboard in over USB and put it in MIDI IN Mode 2 (the Identity reply tells the plugin which mode it is in, and the panel says when it is Mode 1).
2. Add "VR-09 (Perken)" to a track's FX chain. About a second later the plugin picks the keyboard as the track's MIDI hardware output, arms the track and turns its input monitoring on, if the track had no MIDI output of its own. REAPER only delivers the keyboard's replies to a track's plugins while the track is armed, which is why the plugin arms it.
3. Open the plugin's window from the FX chain. The host's own view is a small placeholder; the panel opens as a ReaImGui window next to the mouse.

The plugin then asks the keyboard who it is and reads its 22 memory blocks. If you plug the keyboard in later, it asks again every three seconds.

## Where the notes go

The plugin passes the track's MIDI to the keyboard by default, so the track's items play it. A REAPER track takes either audio or MIDI as its input, so the keyboard's sound goes to a second track, which records the keyboard's audio input.

In MIDI IN Mode 2 the keyboard plays its Lower part from channel 3 and its Upper part from channel 4. The plugin sends the notes of channels 1, 3 and 4 to those parts the way the keyboard's own keys would:

- without a split, every note goes to the Upper part;
- with "This patch splits at middle C" on (Patches tab), the notes below middle C go to the Lower part and the others to the Upper part; controllers and pitch bend reach both.

The keyboard does not report its split: no readable address changes with its split buttons. So the setting is kept per patch, in `Data/Perken/vr09/splits.txt`, and comes back when the patch is loaded. Drums (channel 11) and the GM2 channels pass unchanged.

## Changing patches from the session

A scene is selected by the Scene parameter, from an automation lane (see "The session's scenes"). The plugin no longer reads Program Change: the keyboard ignores it, and one way to select a scene is easier to remember than two. A scene loads on REAPER's main thread and is then written to the keyboard in about 0.15 s, so place a scene's point a little ahead of the first note it should play.

The Scene parameter and the Split parameter work from an envelope:

- Scene: 0 is none, n selects the session's scene n (see "The session's scenes"; the value shows as `n Name`). Only a new value loads a scene, so a held envelope does not reload it. The range is fixed at 0 to 127, so that adding a scene never rescales the points of a lane.
- Split at middle C: overrides the current patch's split until the next patch is loaded. Unlike the Patches tab's checkbox, it is not remembered for the patch.

REAPER does not tell the notes you play from the notes a track plays back. On a track that records the keyboard's MIDI while monitoring it, turn off "Pass this track's MIDI through to the keyboard" in the MIDI tab, or switch the keyboard's Local Control off, so that the keyboard does not sound its notes twice.

## The session's scenes

A scene is a named copy of a patch, kept in the plugin's state in the project. Because it is a copy, editing or deleting a preset or a registration afterwards cannot change what a project plays. The Scene parameter holds a position in the list (from 1), so an automation lane of that parameter, a MIDI-learned control or a script all select scenes the same way. Give the lane's points the square shape, so that no scene is selected on the way between two.

`VR09_Command` manages the list (positions count from 1):

- `scenes`: the list, and the current scene.
- `scene_add` with `<patch>|<name>`, where the patch is `current` (the plugin's state now), `registrations/<file>` or `presets/<file>` of `Data/Perken/vr09`; the name is optional.
- `scene_add_tone` with `<part> <tone number> <bank MSB> <bank LSB>|<name>`: a scene that holds only that tone, for `upper_piano`, `upper_piano_dual2`, `lower_piano`, `upper_synth`, `upper_synth_dual2` or `lower_synth`. Selecting it sends one three-byte message. This assumes that a tone replaces the whole sound of the keyboard, which has not been tried on the unit.
- `scene_move` with `<from>,<to>` and `scene_remove` with `<position>`: the reply holds `map`, the new position of every old position (0 for the removed scene), which a lane needs for its points, so that the project keeps playing the same scenes.
- `scene_rename` with `<position>|<name>`, `scene_select` with a position (loads it, as the parameter does), and `scene_clear`.

## The actions

The plugin registers three REAPER actions when its first instance loads, so they appear in the action list, and can be bound to keys, toolbars or a pedal, once a VR-09 has been added to a project. They act on the instance on a selected track, or else the first one.

- `VR-09: next scene` (`_VR09_NEXT_SCENE`) and `VR-09: previous scene` (`_VR09_PREVIOUS_SCENE`): select the next or previous scene. They stop at the last and the first scene instead of wrapping, so that a page-turner pedal pressed once too often does not jump back to the start in the middle of a song. With no scene selected, both go to the first.
- `VR-09: put a scene point at each marker named like a scene` (`_VR09_SCENE_POINTS_FROM_MARKERS`): puts a square point on the Scene lane at each marker, or region start, whose name is a scene's name (any case) or a scene's position as a number. It creates the lane if the track has none, and running it again moves the points that are already there. The markers that matched nothing are counted on REAPER's console.

## The panel

The panel opens at the mouse, moved to the nearest place where it fits on the screen's usable area. A window that sticks out of the screen is moved by the window manager without ImGui being told, and the mouse then lands a few dozen pixels away from where ImGui believes the window to be, which looked like a frozen window. For the first moments of each opening the plugin logs a line whenever what ImGui sees of the mouse changes, beside where REAPER says the mouse is, so that an offset shows in the log.

- Controls: every parameter of the catalog, by group. The organ drawbars are drawn as drawbars, and the type parameters of the Effects group show their name ("5  Plate") beside the number.
- Patches: read the keyboard into the plugin, send the plugin's state to the keyboard, browse the Registrations library, save the state as a preset, load, delete, import and export files.
- Audio loop: see below.
- MIDI: the track's output and input devices, record arm and monitoring, the SysEx counters, and the behavior switches.

Presets are files named `<name>.vr09` in `<REAPER resource folder>/Data/Perken/vr09/presets`. They hold the JSON that `vr09.py dump` writes, so the dumps in the roland-vr09 project load as they are (the panel lists `.json` files in that folder too).

## The Registrations library

The Patches tab lists the dumps of the keyboard's 70 Registrations, by bank with four slots each, with a filter box (a name, or `bank-slot` such as `12-3`). A double click, or the "Load and send registration" button, loads the dump and writes it to the keyboard, the same way a preset is recalled. The files are named `<bank>-<slot>_<Name>.json`, as the roland-vr09 project stores them in its `dumps` folder; other JSON files there (scans, checks) are ignored.

`extensions/build-install.sh vr09` copies them from `~/projects/roland-vr09/dumps` (or the folder in `VR09_REGISTRATIONS`) to `<REAPER resource folder>/Data/Perken/vr09/registrations`. A file already there is never overwritten, so your edits stay, and the roland-vr09 project is only read. The names are the ones the files carry: the keyboard's own names could not be read over MIDI. The tone list (`docs/tones.json`) is used by tone scenes (`scene_add_tone`), which write a part's tone bytes with a SysEx message: the keyboard ignores Program Change and Bank Select.

## The effects

The Effects group of the Controls tab holds the keyboard's reverb (type, level and variation), vibrato or chorus type, MFX (type and level), delay (type and level) and compressor level. They are parameters of the keyboard's system block (`00 00 xx` of the keyboard model), so each one is automatable and is written with a DT1 message, like the others.

- The reverb type and level are two bytes that the keyboard only accepts together, so changing either sends both, with the other one taken from the plugin's state. If the plugin has not read the keyboard yet (Patches tab, "Read the keyboard") it does not know the other byte and sends nothing.
- The reverb variation picks between two sets of types: Standard has Room (2), Hall (3), Plate (5) and Spring (7), and Cathedral / Stage has Cathedral (3) and Stage (4).
- The effects are not in the Touché remap catalog of the roland-vr09 project, so they are listed in `tools/effects.json`, which `tools/gen_catalog.py` appends to the catalog. Their addresses and ranges are those of Roland's MIDI implementation. The MFX and delay entries were verified by recalling dumps; the reverb, vibrato / chorus and compressor entries are documented in the implementation but have not been tried on the unit through the plugin.

## The audio loop

The loop needs the keyboard's audio input and output wired to an audio interface (the VR-09 has no USB audio): an interface output to the keyboard's input, and the keyboard's output to an interface input.

1. Open the Audio loop tab, choose the pair of interface outputs to send to and the pair of inputs to return from, and turn the loop on.
2. Turn the keyboard's volume down, and press "Measure the round trip". The plugin sends one click to the keyboard's audio input and listens for it, then reports the delay to REAPER as the plugin's latency. REAPER's delay compensation lines the track up. The value is saved in the project, and it is only used while the sample rate matches the one it was measured at.

While the loop is on, REAPER's anticipative FX processing is turned off for the track, because the loop needs the plugin to run in step with the audio device. Without a running audio device (an offline render) or without channels, the audio passes through unchanged.

## How it talks to the keyboard

The unit's buffer overflows when messages come back to back, so the plugin spaces them by 2 ms. A recall writes only what differs between the patch and what the keyboard last said: a full write of the mapped blocks is about 1,600 messages, and a normal switch between two patches is a few dozen. Panel changes arrive as DT1 messages and move the knobs. The engine and its tests are in `src/engine.zig`.

## What was checked, and what was not

Checked in REAPER 7.69 on macOS arm64, with a stand-in for the keyboard (`tools/fakevr09.swift`, which loads a dump and answers like the unit):

- the plugin is scanned, loaded, and shows its 74 parameters;
- SysEx goes out through the track's MIDI output and the replies come back through its input, with F0 and F7 included both ways;
- the Identity exchange, the 22 block reads, a parameter write, the follow-the-panel path, and the automatic choice of the keyboard's device;
- the project state is saved and restored;
- the audio hook runs in step with the audio device without dropouts (853 callbacks, none lost).

Not checked, and worth trying first with the real hardware:

- everything with the real VR-09 (the stand-in only follows `docs/midi-capabilities.md`);
- the audio round trip and its measurement, which need the cables;
- that the ReaImGui panel looks right (it drew frames without a ReaImGui error, but no one has looked at it);
- REAPER's preset browser listing the presets: REAPER asks for the preset discovery factory and its descriptor, but did not create the provider during the headless test. The panel's list shows the same folder;
- playback of the track's own notes with "Pass this track's MIDI through" on;
- Linux and Windows at run time. They build.

The checklist for the untested parts is in [TESTING.md](TESTING.md).

If the keyboard ignores the plugin's messages, try "Send SysEx without its F0 and F7 bytes" in the MIDI tab; the spec leaves the framing to the host, and REAPER 7.69 passes it through.

## Debugging from a Lua script

Because the plugin registers a ReaScript function when it loads, a script running in REAPER can query and drive it, for instance through the Lua bridge of `debug-bridge`:

```
reaper.VR09_Command(track, fxindex, command, arg)   -- returns a JSON string
```

REAPER builds the `reaper` table of a script when the script starts, so a script started before the plugin loaded does not see the function (`reaper.APIExists("VR09_Command")` tells); restart the bridge after loading the plugin. The instance is the one on `track` at `fxindex`, else the first on that track; a nil track chooses the first instance.

Commands that read:

- `state`: `track_found`, `I_MIDIHWOUT`, `I_RECINPUT`, `midi_out_device`, `midi_in_device`, `midi_in_is_midi`, `midi_in_all_devices`, `armed`, `monitoring`, `fx_index`, `pass_midi`, `split`, `sysex_bare`, `autoconnect_done`, `loop_enabled`, `loop_state`, `midi_dropped`, `tx`, `rx`, `bad_checksum`, `host_sysex_in`, `host_sysex_out`, `host_sysex_refused`, `connected`, `mode`, `known_bytes`, `blocks_failed`, `patch_name`, `scene` (the current scene, 0 for none), `scenes` (how many), `panel_open`, `frames_drawn`, `ui_contexts` (how many ImGui contexts the panel has created), `ui_ctx_valid`, `ticks`, `instances`, `devices_out`, `devices_in`, `device_names_out`, `device_names_in`.
- `log`: the last lines the plugin logged (`arg` is how many, 50 by default, 256 at most), as `{"total":N,"lines":[...]}`.
- `devices`: the MIDI output and input names as REAPER reports them (null for an absent device).

Commands that act:

- `set` with `arg` `name=value` for `pass_midi`, `sysex_bare`, `autoconnect_done` or `split` (1, 0, true, false, on, off). `split` is remembered for the current patch, like the Patches tab's checkbox.
- `reconnect`: the panel's "Look for the keyboard again".
- `load_registration` with a file name of `Data/Perken/vr09/registrations`.
- `save_preset` with a name: reads the keyboard first, and writes it as `<name>.vr09` in the presets folder (the same file the Patches tab's "Save as preset" writes) when the read ends. The reply only says that the save began (`pending`); `save_status` says how it went: `idle`, `reading`, `done` (with the `file`, and `known` and `total`, the bytes read and the bytes of a whole patch) or `failed` (with the `error`, such as the keyboard not answering). It refuses when the keyboard is not connected. `load_preset` and `delete_preset` take a file name of that folder.
- `load_tone` with `<part> <tone number> <bank MSB> <bank LSB>|<name>`: writes that tone to the keyboard, as a tone scene does, without adding a scene.
- `open_panel`.
- `capture` reads the whole keyboard into the plugin, `job` reports the read's progress, and `export` with an absolute path writes the plugin's state as a `vr09.py` dump.
- `tab` with `controls`, `patches`, `audio` or `midi`: brings that tab of the panel to the front, so that a script can drive the panel.

An unknown command, or a bad argument, gives `{"ok":false,"error":"..."}`.

## Development

```
zig build test              # protocol, engine, audio loop, state and CLAP interface tests
python3 tools/gen_catalog.py ~/projects/roland-vr09/web/public/maps/targets.json > src/catalog.zig
```

The panel's look is worked on in a Lua design lab, `ui-lab/`, which reloads its files as they are saved and runs with a mock keyboard (see `ui-lab/README.md`). `python3 tools/gen_lua_catalog.py > ui-lab/catalog.lua` makes the lab's copy of the catalog.

The committed catalog was generated from an older state of that catalog than the one in the roland-vr09 project today. Generating it again now would also drop the upper pan and the upper and piano reverb sends (marked unavailable since) and add seven controllers of the lower part, which changes what automation lanes in existing projects point to; it is a decision of its own, so the effects were added without regenerating the rest.

`tools/fakevr09.swift` (macOS) creates a virtual MIDI device called "VR-09 Fake" that behaves like the keyboard in Mode 2. Build it with `swiftc -O tools/fakevr09.swift -o fakevr09`, start `./fakevr09 dump.json log.txt` before REAPER, and install the plugin in a scratch resource folder (`REAPER_RESOURCE_PATH`, and `CLAP_PATH` for the plugin) to try the whole path without the hardware.

The source map:

| File | Role |
|---|---|
| `roland.zig` | DT1 and RQ1 messages, checksum, parsing |
| `dump.zig` | the block table, dumps, the write grouping and the diff, the JSON format of `vr09.py` |
| `catalog.zig` | the parameters (generated; the effects come from `tools/effects.json`) |
| `engine.zig` | the audio-thread engine: pacing, reads, recall, following the panel |
| `audio.zig` | the audio loop: rings, the hardware hook bridge, the latency ping |
| `plugin.zig`, `clap_entry.zig`, `discovery.zig` | the CLAP plugin, entry point and preset discovery |
| `reaper_glue.zig` | REAPER's API through the host extension: track, MIDI devices, hook, timer |
| `ui.zig` | the ReaImGui panel |
| `state.zig`, `fileio.zig` | the project state, presets, file access |
