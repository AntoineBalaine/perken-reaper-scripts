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

REAPER does not tell the notes you play from the notes a track plays back (live input events carry no flag), and the track must monitor its input for the keyboard's replies to arrive. If the plugin passed the track's MIDI to the keyboard, the keyboard would sound every note it plays twice. So the plugin drops the track's notes, controllers and pitch bend by default, and only handles SysEx.

The layout that follows:

- one track for the plugin (the controller track), with no items;
- a normal MIDI track for the notes, which records from the keyboard and plays back to it as usual.

To play items from the plugin's own track, turn on "Pass this track's MIDI through to the keyboard" in the MIDI tab, and switch the keyboard's Local Control off if you monitor while playing.

## The panel

- Controls: every parameter of the catalog, by group. The organ drawbars are drawn as drawbars.
- Patches: read the keyboard into the plugin, send the plugin's state to the keyboard, save the state as a preset, load, delete, import and export files.
- Audio loop: see below.
- MIDI: the track's output and input devices, record arm and monitoring, the SysEx counters, and the behavior switches.

Presets are files named `<name>.vr09` in `<REAPER resource folder>/Data/Perken/vr09/presets`. They hold the JSON that `vr09.py dump` writes, so the dumps in the roland-vr09 project load as they are (the panel lists `.json` files in that folder too).

## The audio loop

The loop needs the keyboard's audio input and output wired to an audio interface (the VR-09 has no USB audio): an interface output to the keyboard's input, and the keyboard's output to an interface input.

1. Open the Audio loop tab, choose the pair of interface outputs to send to and the pair of inputs to return from, and turn the loop on.
2. Turn the keyboard's volume down, and press "Measure the round trip". The plugin sends one click to the keyboard's audio input and listens for it, then reports the delay to REAPER as the plugin's latency. REAPER's delay compensation lines the track up. The value is saved in the project, and it is only used while the sample rate matches the one it was measured at.

While the loop is on, REAPER's anticipative FX processing is turned off for the track, because the loop needs the plugin to run in step with the audio device. Without a running audio device (an offline render) or without channels, the audio passes through unchanged.

## How it talks to the keyboard

The unit's buffer overflows when messages come back to back, so the plugin spaces them by 2 ms. A recall writes only what differs between the patch and what the keyboard last said: a full write of the mapped blocks is about 1,600 messages, and a normal switch between two patches is a few dozen. Panel changes arrive as DT1 messages and move the knobs. The engine and its tests are in `src/engine.zig`.

## What was checked, and what was not

Checked in REAPER 7.69 on macOS arm64, with a stand-in for the keyboard (`tools/fakevr09.swift`, which loads a dump and answers like the unit):

- the plugin is scanned, loaded, and shows its 68 parameters;
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

## Development

```
zig build test              # protocol, engine, audio loop, state and CLAP interface tests
python3 tools/gen_catalog.py ~/projects/roland-vr09/web/public/maps/targets.json > src/catalog.zig
```

`tools/fakevr09.swift` (macOS) creates a virtual MIDI device called "VR-09 Fake" that behaves like the keyboard in Mode 2. Build it with `swiftc -O tools/fakevr09.swift -o fakevr09`, start `./fakevr09 dump.json log.txt` before REAPER, and install the plugin in a scratch resource folder (`REAPER_RESOURCE_PATH`, and `CLAP_PATH` for the plugin) to try the whole path without the hardware.

The source map:

| File | Role |
|---|---|
| `roland.zig` | DT1 and RQ1 messages, checksum, parsing |
| `dump.zig` | the block table, dumps, the write grouping and the diff, the JSON format of `vr09.py` |
| `catalog.zig` | the parameters (generated) |
| `engine.zig` | the audio-thread engine: pacing, reads, recall, following the panel |
| `audio.zig` | the audio loop: rings, the hardware hook bridge, the latency ping |
| `plugin.zig`, `clap_entry.zig`, `discovery.zig` | the CLAP plugin, entry point and preset discovery |
| `reaper_glue.zig` | REAPER's API through the host extension: track, MIDI devices, hook, timer |
| `ui.zig` | the ReaImGui panel |
| `state.zig`, `fileio.zig` | the project state, presets, file access |
