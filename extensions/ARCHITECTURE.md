# Architecture

How this repository fits together: what lives where, how the compiled
extensions relate to each other and to the older Lua scripts, which Lua code
has been ported, and what the extensions keep in REAPER's resource folder.
For the mechanics of releasing, building and installing, see
[README.md](README.md); to build, test, extend or debug an extension, see
[CONTRIBUTING.md](CONTRIBUTING.md).

## The repository at a glance

The repository holds two generations of the same work. Because the Lua
scripts came first and are still distributed, both live side by side.

| Folder | What it is | State |
|---|---|---|
| `extensions/` | Compiled REAPER extensions written in Zig | Active |
| `reavim/` | The Lua vim mode (state machine, definitions, custom actions, docs) | Kept; `reavim-ext` is its compiled successor |
| `main/`, `midi/`, `media_explorer/`, `realearn/` | Standalone ReaScripts (drum actions, routing, chord voicings and note selection, media explorer helpers, Realearn mappings) | Kept as Lua; some have compiled counterparts, see below |
| `imgui/` | Reusable ReaImGui Lua components (`knobs`, `shortcut_list`) | Kept as Lua |
| `deprecated/` | Old scripts that are no longer maintained | Frozen |
| `index.xml` | The ReaPack index that publishes the Lua scripts | Generated |
| `.github/workflows/` | One workflow per extension | Active |

## The compiled extensions

```
                    reaziglib  (shared Zig modules, no binary of its own)
                   /     |      \
          reavim-ext   perken-utilities   console1 ── reaper_c1, reaper_c1_ui
        (vim grammar)  (editing helpers)           └─ reaper_mft
              \             /
   binds Perken actions by name (_PERKEN_<Action>)
```

| Extension | Binaries | Role |
|---|---|---|
| [`reaziglib`](reaziglib) | none | REAPER API bindings, ReaImGui bindings, shared helpers, the shared window palette, the control surface shim |
| [`reavim-ext`](reavim-ext) | `reaper_reavim` | The vim grammar: modes, operators, motions, the whichkey window and its search box. It owns the keymap |
| [`perken-utilities`](perken-utilities) | `reaper_perken_utilities` | Editing helpers (drums, chord voicings, item, track and envelope tools, batch rename, tempo detection, the action search). Every action is registered in REAPER as `Perken: <name>` with the command id `_PERKEN_<name>` |
| [`vr09`](vr09) | `vr09.clap` | A CLAP plugin, not an extension: a Roland VR-09 controller that sits on a track. It reaches REAPER's API through the host extension `cockos.reaper_extension` and needs no extension of its own. It builds on reaziglib's API bindings and has no C++ |
| [`console1`](console1) | `reaper_c1`, `reaper_c1_ui`, `reaper_mft` | The Softube Console1 MKII control surface and its hot-reloadable panel, and MIDI Fighter Twister support. They are built and released separately (`console1-v*`, `mft-v*`) |

How they depend on each other:

- **reaziglib is a source dependency.** The other extensions reference it by
  path (`.path = "../reaziglib"`), so a change to the library and to its
  users lands in one commit. It is never released on its own.
- **reavim-ext and perken-utilities know nothing of each other at build
  time.** Because Perken Utilities registers its actions as named REAPER
  commands, reavim-ext binds them like any other command. The keymap lists
  those entries commented out (`; <keys> = _PERKEN_<Action>`), so that the
  keymap works without Perken Utilities; uncomment them after installing it.
- **Anything can bind a Perken action.** They also appear in REAPER's own
  action list, so REAPER's keymap, toolbars and ReaLearn can use them.

### Shared pieces worth knowing

- **`ui_palette`** (reaziglib) holds the colours of the whichkey window.
  The action palette uses it too, so both windows look alike.
- **The C++ toolchain rule.** REAPER calls some extension code through C++
  virtual methods (control surfaces, MIDI devices), so that C++ has to be
  compiled with REAPER's own toolchain: `cl` on Windows, Apple clang on macOS,
  `gcc` on Linux. See the last section of [README.md](README.md). reavim-ext
  has no C++ and cross-compiles every target from one runner; perken-utilities
  and console1 build natively on each OS.
- **Zig version.** Every extension pins its series in `.zigversion`
  (currently 0.17.x), and the install scripts check it.

## What was ported from Lua, and what was not

The vim mode and its custom actions were Lua code under
`reavim/internal/`. The port inventories in
[`reavim-ext/port/`](reavim-ext/port) record every function and how hard it
was to port. This is where each file ended up.

### Ported

| Lua source | Compiled counterpart | Notes |
|---|---|---|
| `state_machine`, `definitions`, the vim grammar and its bindings | `reavim-ext` (`grammar`, `builder`, `runner`, `vim`, `default_bindings.ini`) | Operators, motions and selectors, visual modes, counts, registers and macros |
| `library/marks.lua` | `reavim-ext/src/ported/marks.zig` | The five register actions; marks are kept in project ext state |
| `custom_actions/movement.lua` | `reavim-ext/src/ported/movement.zig` | All 22 functions |
| `custom_actions/selection.lua` | `reavim-ext/src/ported/selection.zig` | All 5 functions |
| `custom_actions/midi.lua` | `reavim-ext/src/ported/midi.zig` | The 9 bound actions in the vim grammar; `toggleKeySnap` moved to `perken-utilities` as a stub, see below |
| `custom_actions/custom_actions.lua` | `reavim-ext/src/ported/misc.zig` | The aggregator's own 5 functions |
| `custom_actions/items.lua` | `perken-utilities/src/items.zig` | All 8 functions, 9 actions |
| `custom_actions/tracks.lua` | `perken-utilities/src/tracks.zig` | All 4 functions |
| `custom_actions/envelope.lua` | `perken-utilities/src/envelope.zig` | The 9 bound actions; `autoMode` is unbound in the Lua too, so it was not ported |
| `custom_actions/kawa.lua` | `perken-utilities/src/kawa.zig` | All 23 bound actions |
| `custom_actions/routing.lua` | `perken-utilities/src/routing.zig` | Both functions (route to busses by colour, build busses) |
| `custom_actions/drums.lua` | `perken-utilities/src/drums.zig` | Flam, ras and crescendo are native |
| `utils.lua`, `utils/reaper_state.lua` | `reaziglib/src/reaper_helpers.zig` | Shared by all the ports |

### Registered but not functional yet (stubs)

These actions are registered and log a message when run, so that a binding to
them does not break, but they do nothing yet. Both are bound (commented out)
in the default keymap.

| Action | Key | Where | Why it is a stub |
|---|---|---|---|
| `InsertFxAtSlot` | `<space>fi` | `perken-utilities/src/fx.zig` | Rated hard. The Lua opens the FX browser and detects the FX you picked by parsing a locale-dependent undo label. The better design is to watch a temporary track's FX count from a timer |
| `toggleKeySnap` | `<space>ks` (MIDI) | `perken-utilities/src/keysnap.zig` | The Lua clicks the MIDI editor's key-snap checkbox through js_ReaScriptAPI. A compiled extension can send the window message itself, so it needs no JS_* bindings, but that is still to write |

### Not ported yet

Everything below is an editing helper, not part of the vim grammar, so it
would be added to `perken-utilities`. In suggested order, easiest first:

| Lua source | Tier | State |
|---|---|---|
| `midi.LoadScreenSetWhenClosingEditor` | Easy | One REAPER command (40444), unbound, never ported |
| `harmonizer.harmonize` | Medium | Pure music theory (parses chord symbols such as "Cmin7" and voices a melody note) with no REAPER calls, so it can be fully unit-tested. Only `midi_arranging` uses it |
| `midi_arranging.insert_chord` | Medium | Prompts for a chord symbol and writes it as a text event at the cursor |
| `midi_arranging` (4 more functions) | Hard | Group notes by text tags and send each group to its own MIDI channel or track, and harmonize a melody in close position. They need note and text-event snapshots plus `harmonizer`, and are unbound in the default keymap |
| `pasteRhythm` | Hard | Applies the clipboard's MIDI rhythm to the selected item's pitches, a multi-step manipulation of MIDI takes |

### Not planned

| Lua source | Why |
|---|---|
| `dev.lua` (3 functions) | Launchers for user-local scripts and developer scratch code |
| `drums.quantizeTool` | It launches a third-party quantize script by its command id, which only exists on the original install; kept as a stub |
| `midi_controller.lua` (3 functions), `MFT.lua`, `Mapping_types.lua` | The Realearn and MIDI Fighter Twister workflow, which the `mft` and Console1 extensions replace |
| `envelope.autoMode` | Unbound and blocked on SWS functions that reaziglib does not wrap; the auto lane watcher in `perken-utilities` does the same job better |

### Compiled features with no Lua origin

- **Batch rename of tracks in your editor** and the **action search**
  (a ReaImGui fuzzy palette, and an fzf variant that runs in a terminal) in
  `perken-utilities`.
- **Tempo detection** (qm-dsp beat tracking, grid fitting, take and stretch
  markers) in `perken-utilities`.
- **The auto lane watcher**, moved from the former `reaperConsole1`
  repository, whose Console1 control surface used to feed it.
- **Console1 and MIDI Fighter Twister support**, which came from
  `reaperConsole1` when it was merged here.

### The standalone Lua scripts

The scripts in `main/`, `midi/` and the other folders came first, as
individual ReaScripts. Later they were folded into reavim as custom actions,
and the custom actions are what was ported. The table follows the file and
action names; it was not checked script by script for identical behaviour.
All of the Lua scripts remain in the repository. They also stay on ReaPack,
except `reavim.lua`, which `reavim-ext` replaces and which is marked
`@noindex`.

| Folder | Compiled counterpart | State |
|---|---|---|
| `main/drum_actions/` (flam, 3stroke, 5stroke, crescendo, decrescendo) | `perken-utilities` drums: `Flam`, `Ras3`, `Ras5`, `Crescendo`, `Decrescendo` | Ported |
| `main/Routing/` (`CreateBusses`, `routeColorsToBusses`) | `perken-utilities` routing: `BuildBusses`, `RouteToBusses` | Ported |
| `midi/` (25 chord-voicing and note-selection scripts, plus helper folders: `doubleFifthUp`, `drop_2`, `select_top_note`, …) | `perken-utilities` kawa actions (23) | Ported |
| `main/pasteRhythmToPitches.lua` | `perken-utilities` paste_rhythm: `PasteRhythmToPitches` | Ported; the Lua is `@noindex` |
| `main/utilities/` | Their shared helpers live in `reaziglib/src/reaper_helpers.zig` | Helpers only; `itemNamesToMarkers.lua` has no counterpart |
| `imgui/knobs` | The Zig `knob` module in reaziglib | Same purpose, written in Zig |
| `imgui/shortcut_list` | None | Not ported |
| `media_explorer/` (2 scripts) | None | Not ported, no plan |
| `realearn/` (`lua_mapper`, `synth_map`) | None | Not ported; MIDI Fighter Twister support is the compiled `mft` extension |
| `reavim/` | `reavim-ext` | Ported; the Lua version is `@noindex` and no longer on ReaPack |
| `deprecated/` | None | Frozen |

## What the extensions keep in REAPER's resource folder

Paths are relative to REAPER's resource folder (`Options > Show REAPER
resource path`).

| Path | Written by | Contents |
|---|---|---|
| `UserPlugins/reaper_reavim`, `reaper_perken_utilities`, `reaper_c1`, `reaper_c1_ui`, `reaper_mft` | `build-install.sh` or a release | The extension binaries (`.dylib`, `.so` or `.dll`) |
| `Data/Perken/bindings.ini` | `install-bindings.sh`, the user | The keymap. Optional: reavim-ext embeds its defaults and uses them when the file is absent |
| `Data/Perken/bindings.ini.new`, `.bindings.ini.installed-sha` | `install-bindings.sh` | New defaults beside an edited keymap, and the checksum of the last installed defaults |
| `Data/Perken/reavim.ini` | reavim-ext | Whether vim mode is on |
| `Data/Perken/perken-utilities.ini` | the user | Optional settings; `[rename] terminal`, `editor` and `close_terminal` configure the terminal used by batch rename and the fzf action search |
| `Data/Perken/rename/`, `Data/Perken/actions/` | perken-utilities | Scratch files exchanged with the terminal while a batch rename or an fzf search runs |
| `Data/Perken/Console1/` | console1 | Preferences and the plugin parameter maps |
| `Data/Perken/MFT/` | mft | The MIDI Fighter Twister maps |

## Platforms

| Extension | macOS | Linux | Windows |
|---|---|---|---|
| reavim-ext | arm64 and x86_64 | x86_64 and aarch64 | Cross-compiled; never run in a Windows REAPER |
| perken-utilities | arm64 and x86_64 | x86_64 and aarch64 | In progress: it needs `cl` and the MSVC runtime, and is not yet confirmed in CI |
| console1, mft | arm64 and x86_64 | x86_64 and aarch64 | Not supported: the Zig code calls SWELL, which exists on macOS and Linux only |

Batch rename and the fzf search need a terminal and are refused on Windows. The
x86_64 macOS builds are cross-built on an arm64 runner, so their tests only
run on the arm64 row.

## Conventions

- **Commit messages** start with the area: `<module-or-area>: <message>`, for
  example `reavim-ext:`, `perken-utilities:`, `reaziglib:` or `chore:`.
- **Build and tests must pass** before a commit. Each extension runs
  `zig build test`; `extensions/linux-ci/linux-ci.sh` runs the Linux CI steps
  locally in Docker, which a Mac cannot otherwise do.
- **Each extension keeps its own `CHANGELOG.md`** and releases from its own
  tags.

## The vim grammar in brief

`reavim-ext` turns key sequences into commands with a small grammar
(`src/grammar.zig`). Each binding in the keymap has an action type, and the
type decides how the key combines with the others.

| Action type | Role | Example |
|---|---|---|
| `command` | Runs by itself | `p` (paste) |
| `track_motion`, `timeline_motion` | Moves along the tracks or along time | `j`, `G`; `w`, `e` |
| `track_operator`, `timeline_operator` | Acts on what a motion or selector spans | `d` (cut tracks), `s` (select items) |
| `track_selector`, `timeline_selector` | Names a span without moving | `ig` (all tracks) |
| `visual_track_command`, `visual_timeline_command` | A command that exists only inside a visual mode | `o` in `v` (switch the selection side) |

There are three modes: normal, visual track (`V`) and visual timeline (`v`).

- In **normal mode** an operator is followed by a motion or a selector, and
  the pair runs as one command (`dj`, `se`). The type of the second key
  decides which family runs, so the same operator letter can exist for both:
  `dj` cuts tracks and `dw` cuts items. A counted motion (`d3j`) repeats it. A
  track operator typed twice (`dd`, `yy`) applies to the current track.
- In **visual track mode** the track motions extend a selection of tracks, a
  track operator acts on it, and a timeline operator followed by a timeline
  motion (`se`) acts on the selected tracks over that stretch of time.
- In **visual timeline mode** the timeline motions extend a time selection,
  and a timeline operator acts on it.

The sections of the keymap (`[main.command]`, `[midi.timeline_motion]`, …)
name the context (`main` or `midi`) and the action type.
`reavim-ext/port/bindings_inventory.md` lists every binding and explains how
the keymap files merge.

## Licences

| Part | Licence |
|---|---|
| `reavim/` (the Lua vim mode) | MIT, copyright 2016 ggVGc |
| `extensions/reaziglib` | LGPL-3.0-or-later |
| `extensions/perken-utilities` | GPL-3.0, because it includes qm-dsp, which is GPL-2.0-or-later |
| `extensions/reavim-ext` | No licence file yet. It ports the MIT-licensed Lua code, whose notice has to stay with it |
| `extensions/console1` | No licence file yet; its README says the terms are still to be settled |

The Tukan Studios SumChannel S2 JSFX that `reaperConsole1` used to vendor is
not in this repository, because Tukan publishes it without a licence. Do not
add it back.

## History of this repository

The extensions began as separate repositories (`reavim-ext`, `reaziglib` and
the private `reaperConsole1`) and were merged here on 2026-10-13. Their
histories were rewritten into `extensions/<name>/` and replayed one after the
other on top of the scripts history, with no merge commits, so the history is
linear. Two consequences:

- The commit hashes differ from those in the old standalone repositories, so a
  hash quoted from one of them will not be found here.
- Tags are prefixed with the extension name (`reavim-ext-v0.2.0`), and a tag
  triggers only its own extension's workflow.

