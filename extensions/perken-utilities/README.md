# Perken Utilities

Editing helpers for REAPER as a compiled extension (Zig, built on
[reaziglib](../reaziglib)). Every action shows up in REAPER's action list as
`Perken: <name>` and can be bound to any key, from REAPER's own keymap or from
[reavim-ext](../reavim-ext)'s `bindings.ini`.

## Actions

| Module | Actions |
|---|---|
| drums | Flam, Ras3, Ras5, Crescendo, Decrescendo, QuantizeTool (stub) |
| kawa (MIDI editor) | chord note selection, drop-2/3/2&4 voicings, octave/interval doublings, QuantizeNoteEnds (selected notes, or all: ends snap to the grid, starts stay), Legato (selected notes, or all: each chord ends a tick before the next selected one; the last, before the next note, else at the item end) |
| rhythm (MIDI editor) | SimplifyNoteLengths: note ends move out to the simplest value each position allows, read from the project's own bar grid and time signatures. Of the notation rules it applies, only the note-plus-equal-rest collapse reaches the MIDI data — re-tiled rests are not MIDI objects and a tie keeps one note — so lengthening is the visible effect. Chords take one length; a note overlapping the next attack stops there. |
| routing | RouteToBusses, BuildBusses |
| fx | InsertFxAtSlot (stub) |
| items | paste before cursor, 2 ms fades, fades and trims from the mouse, split at note starts, stretch to cursor, ConformItemsToSessionTempo (asks for the original BPM of the selected items, then stretches them by session tempo / original tempo so that their notes land on the session grid; the session tempo is read at the start of the earliest item, and the item positions scale around that start) |
| tracks | volume ±3 dB, rename from the VSTi preset, exclusive solo |
| envelope | point min/max/center, nudge points, delete points, toggle at time selection, select points |
| keysnap (MIDI editor) | toggleKeySnap (stub) |
| batch_rename | BatchRenameTracks: rename the selected tracks in your editor |
| abc_export | CopyItemsAsAbc, OpenItemsAsAbc and PreviewItemsAsAbc: convert the selected MIDI items to ABC with the [abcls](https://github.com/AntoineBalaine/abcls) CLI, one tune per item in timeline order (titled after the take), then copy the text to the clipboard, or open it as a temporary `.abc` file in the editor, with or without the score preview (the preview needs an abc-ls VS Code extension that handles `vscode://antoinebalaine.abc-ls/open` links). The items can sit anywhere in the project; each one's tempo and time signature are read at its start. macOS and Linux only. |
| terminal | OpenTerminalInProjectDir: opens a shell in the folder of the current project (the recording path when the project was never saved). It uses the same terminal as batch rename, the `[rename] terminal` setting in `perken-utilities.ini`. macOS and Linux only. |
| auto_lane_watcher | AutoLaneWatcher (toggle): touching an FX parameter shows its envelope lane and hides the track's others; the lane is dismissed when you change track or close the FX, and removed if it received no automation. In trim/read mode, plugin-UI tweaks trim the lane. Removing unused lanes needs SWS. |

Each action's command id is `_PERKEN_<name>` (e.g. `_PERKEN_Flam`). Actions
for the MIDI editor are registered in the MIDI editor section.

The auto lane watcher reacts to REAPER's state changes through a hidden
control surface (reaziglib's `csurf` shim), registered only while the
watcher is on; it does not appear in REAPER's control surface preferences.

## Beat and tempo detection (in progress)

`src/beat/` tracks beats, downbeats and the tempo between beats in audio,
using [qm-dsp](https://github.com/c4dm/qm-dsp)'s bar and beat tracker (Queen
Mary, University of London; the tracker Ardour ships). qm-dsp is pinned in
`build.zig.zon` and compiled, unmodified, with REAPER's toolchain; a small C
bridge (`src/beat/qm_bridge.cpp`) follows qm-dsp's own Vamp plugin. The
REAPER action that analyses an item is not written yet.

## Settings

Optional, in `<resource path>/Data/Perken/perken-utilities.ini`:

```ini
[rename]
terminal = open -a iTerm      ; default: Terminal.app on macOS, x-terminal-emulator elsewhere
editor = nvim                 ; default: $VISUAL, else $EDITOR, else vim
close_terminal = true         ; macOS: close the Terminal.app window afterwards

[abc]
command = /path/to/abcls      ; default: found by search (/opt/homebrew/bin, /usr/local/bin, ~/.volta, nvm, then the login shell's PATH)
clipboard = pbcopy            ; default: pbcopy on macOS, xclip -selection clipboard elsewhere
editor = open -a "Visual Studio Code"   ; default: the system opener (`open` on macOS, `xdg-open` elsewhere)
```

## Build

The auto lane watcher's control surface is C++ that REAPER calls, so the build
compiles it with REAPER's own toolchain and must run on the target OS: Apple
clang on macOS (both architectures, `-Dtarget=x86_64-macos` from an arm64 Mac
works), gcc on Linux, MSVC's `cl` on Windows from a Visual Studio developer
prompt. See [the toolchain rule](../README.md#toolchain-rule-c-that-reaper-calls-must-use-reapers-toolchain).

```sh
zig build test        # unit tests
zig build             # Debug build into zig-out/
zig build -Doptimize=ReleaseSafe
```

`zig build test` statically links `libhegel` for the property-based tests
(test-only; the shipped extension does not link it) and downloads the pinned
release on first run, so that build needs network access.

Behaviour that needs REAPER is checked by hand:
[MANUAL_CHECKS.md](MANUAL_CHECKS.md) lists what to try after changing the
note-length simplification or anything it shares code with.

## License

GPL-3.0 (see `LICENSE`), because the extension includes qm-dsp, which is
licensed under the GPL (version 2 or later).
