# reavim-ext

A compiled REAPER extension (Zig, built on [reaziglib](https://github.com/AntoineBalaine/reaziglib))
reimplementing reavim's vim mode — without taking over the user's keymap.

## Install

A release archive contains the extension library (`reaper_reavim.so` / `.dylib` /
`.dll`) and an optional `bindings.ini`.

1. Copy `reaper_reavim.*` into REAPER's `UserPlugins` folder. To find it, open
   `Options -> Show REAPER resource path...` in REAPER and go into `UserPlugins`.
   Restart REAPER. (macOS, if downloaded: `xattr -dr com.apple.quarantine
   reaper_reavim.dylib`, or REAPER silently won't load it.)
2. Optional, to customize the keymap: copy `bindings.ini` to
   `<resource path>/Data/Perken/bindings.ini` (same resource folder as
   `UserPlugins`; create the subfolders). The extension ships with built-in
   defaults, so this is only needed to change keys. Bindings are read once at
   startup — restart REAPER after editing. The format is documented at the top
   of the file.
3. In `Actions -> Show action list` (search "ReaVim"), bind `ReaVim: Toggle vim
   mode` to a key. `ReaVim: Toggle whichkey window` shows/hides the feedback
   window (which needs ReaImGui, installable via ReaPack; the extension works
   without it).

With vim mode on you start in normal mode; press `i` for insert (keys pass
through to REAPER) and `Esc` to return.

## Why an extension instead of the script approach

Today reavim installs a ~2100-entry `.ReaperKeyMap` that rebinds every key to a Lua
dispatch script. Every keystroke launches a fresh Lua instance, reloads modules,
deserializes the whole state machine from ExtState, and re-walks the binding tables.

The extension instead registers REAPER's `"accelerator"` hook
(`plugin_register("accelerator", &accelerator_register_t)`), which sees every keyboard
message **before** REAPER's keymap processing:

- **vim off / insert mode** → `translateAccel` returns `0`: the key passes through and
  the user's native REAPER bindings work untouched. No keymap overwrite, no install step.
- **normal / visual mode** → returns `1`: the key is eaten and fed to the resident vim
  engine. In insert mode only the escape key is intercepted, to flip back to normal.

Guards: never eat keys when focus is in a text field (track rename etc.); a bindable
toggle action (registered via `custom_action` + `hookcommand2`) turns vim mode on/off.

## Engine design

- **Tries built once at startup** from config files. One trie per (context, mode),
  where context ∈ {main, midi} and mode ∈ {normal, visual_track, visual_timeline}.
  Terminal nodes are tagged with their action type (track_motion, track_operator, …).
- **A small sequence state machine on top** handles reavim's compositional grammar:
  after a `track_operator` terminal the cursor moves to the motion/selector tries;
  counts and `"register` postfixes are handled by a lexer layer in front of the trie.
- **State between keystrokes** is just: trie cursor + pending count + pending register +
  current mode. All resident in memory — a keystroke is one node lookup.
- **Completion hints** for the feedback window (ReaImGui, timer hook) are the children
  of the current trie node — free.
- **Terminal actions** resolve to one of:
  1. a native REAPER command ID / named command (`Main_OnCommand`,
     `MIDIEditor_LastFocused_OnCommand`),
  2. a named ReaScript command ID — existing reavim custom Lua actions keep working
     unchanged through their registered script IDs,
  3. a native Zig function (custom actions get ported here over time; unported ones
     start as stubs that print their name to the console).

## Config format

INI (via [ini](https://github.com/AntoineBalaine/ini), the same fork reaziglib already depends on). The nesting in
reavim's Lua definitions is an authoring convenience, not structural — the trie
flattens everything — so full key sequences become keys under dotted section headers:

```ini
[main.normal.track_motion]
gg = FirstTrack
G  = LastTrack
j  = NextTrack

[main.folders]
c = change/fit          ; label shown in completion hints

[action.FitByLooping]   ; richer action definitions: one section per action
cmd = _RS_my_script_id
midiCommand = true
repetitions = 5
```

## Milestones

- [x] **0 — probe**: register the accelerator hook, eat nothing, log every key message
  with window context to stderr (std.log, Console1-style — launch REAPER from a
  terminal to see it). Verifies on a real REAPER install which
  windows route through the hook (arrange view, MIDI editor, text fields, docked vs
  floating) before the engine is built on top of it.
- [x] **1 — key encoding + focus guards**: vim-mode toggle action (with action-list
  checkmark via `toggleaction`), "ReaVim: Enter normal mode" action, off/normal/insert
  modes, modifier tracking from hook traffic (no SWELL GetAsyncKeyState needed),
  text-field guard (window class via minimal pure-Zig SWELL modstub, `src/swell_win.zig`),
  context detection (main vs midi via parent-chain walk).
  Note: keystroke interception requires registering `"<accelerator"` (undocumented
  front-of-queue prefix, used by js_ReaScriptAPI) — plain `"accelerator"` sits at
  the back of the queue and never sees MIDI editor keys.
- [x] **2 — trie + config**: vim-notation key encoding (`src/key.zig`), binding trie
  (`src/trie.zig`), INI config (`src/config.zig`, user file at
  `<resource>/Data/Perken/bindings.ini`, embedded defaults otherwise), counts
  (`3j`), per-context dispatch (Main_OnCommand / MIDIEditor_LastFocused_OnCommand),
  named-command + builtin + stub action kinds. Pending: punctuation keys (needs a
  SWELL VK probe round — ASCII/VK collisions), sequence timeout policy for
  prefix-ambiguous bindings.
- [x] **4 — feedback UI** (`src/ui.zig`): dockable ReaImGui window (Console1 theme),
  whichkey-style alphabetical columns with pagination, mode/context/pending/REC
  status line, action names via kbd_getTextFromCmd.
- [x] **3 — grammar**: full reavim composition grammar (`src/grammar.zig`,
  `src/builder.zig`, `src/runner.zig`): operator+motion/selector compositions,
  counts, registers, visual track/timeline modes. Punctuation keys solved via
  SWELL's FVIRTKEY-in-lParam distinction (`src/key.zig` is_char).
- [x] **5 — full port**: 644 data actions + 588 bindings generated from the
  inventories in `port/`; ~97 custom Lua functions ported native across
  `src/ported/` (movement, selection, tracks, items, routing, marks, envelope,
  fx, midi, kawa, drums, misc); macros/repeat/`.` in `src/meta.zig`.
  Remaining stubs by design: InsertFxAtSlot, toggleKeySnap, QuantizeTool,
  midi_arranging (HARD), midi_controller + dev (SKIP), pasteRhythm (HARD).

## Build

```sh
zig build                      # → zig-out/reaper_reavim.so
zig build test
```

Zig 0.14.1 (a toolchain lives at `/tank/projects/.toolchains/zig-x86_64-linux-0.14.1/`).
Deploy by copying `zig-out/reaper_reavim.so` to REAPER's `UserPlugins` directory and
restarting REAPER.

## Changelog

0.1.1
Add the readme in the release - with install instructions
