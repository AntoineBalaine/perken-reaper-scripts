# Architecture

How this repository fits together: what lives where, how the compiled
extensions relate to each other and to the older Lua scripts, which Lua code
has been ported, and what the extensions keep in REAPER's resource folder.
For the mechanics of releasing, building and installing, see
[README.md](README.md).

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
  (currently 0.14.x), and the install scripts check it.

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
| `custom_actions/midi.lua` | `reavim-ext/src/ported/midi.zig` | The 9 bound actions; `toggleKeySnap` is a stub, see below |
| `custom_actions/custom_actions.lua` | `reavim-ext/src/ported/misc.zig` | The aggregator's own 5 functions |
| `custom_actions/items.lua` | `perken-utilities/src/items.zig` | All 8 functions, 9 actions |
| `custom_actions/tracks.lua` | `perken-utilities/src/tracks.zig` | All 4 functions |
| `custom_actions/envelope.lua` | `perken-utilities/src/envelope.zig` | The 9 bound actions; `autoMode` is unbound in the Lua too, so it was not ported |
| `custom_actions/kawa.lua` | `perken-utilities/src/kawa.zig` | All 23 bound actions |
| `custom_actions/routing.lua` | `perken-utilities/src/routing.zig` | Both functions (route to busses by colour, build busses) |
| `custom_actions/drums.lua` | `perken-utilities/src/drums.zig` | Flam, ras and crescendo are native |
| `utils.lua`, `utils/reaper_state.lua` | `reaziglib/src/reaper_helpers.zig` | Shared by all the ports |

### Registered but not functional yet (stubs)

These actions exist and log a message when run, so that bindings to them do not
break, but they do nothing yet.

| Action | Where | Why |
|---|---|---|
| `toggleKeySnap` | `perken-utilities/src/keysnap.zig` | Toggles the MIDI editor's key-snap checkbox; the port is still to do |
| The single `fx.lua` action | `perken-utilities/src/fx.zig` | Rated HARD in the inventory (`insertFXAtSlot`) |
| `drums.quantizeTool` | `perken-utilities/src/drums.zig` | It launches a user-local quantize script by its registered command id, which only exists on the original install |

### Not ported yet

| Lua source | Size | State |
|---|---|---|
| `custom_actions/harmonizer.lua` | 171 lines | On hold |
| `custom_actions/midi_arranging.lua` | 377 lines, 5 functions | On hold |
| `custom_actions/pasteRhythm.lua` | 341 lines | On hold |

### Not planned

| Lua source | Why |
|---|---|
| `custom_actions/MFT.lua`, `Mapping_types.lua` | A Realearn mapping generator for the MIDI Fighter Twister, and the types it uses. MIDI Fighter Twister support exists separately, as the compiled `reaper_mft` in `console1` |
| `custom_actions/midi_controller.lua` | A personal modulation-routing workflow built on serpent ExtState handoff and ultraschall chunk APIs |
| `custom_actions/dev.lua` | Developer scratch code and launchers for user-local scripts |

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

### Standalone Lua scripts that stay Lua

`main/`, `midi/`, `media_explorer/`, `realearn/` and `imgui/` hold ReaScripts
that are not part of the vim mode and have no compiled port. Some cover the
same ground as a compiled action (the drum and routing scripts in `main/`,
for instance), and they remain available through ReaPack as they are. The Lua
vim mode in `reavim/` is also still here; marking it deprecated in favour of
`reavim-ext` is still to do.

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
