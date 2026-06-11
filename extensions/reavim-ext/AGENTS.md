# AGENTS.md — working on reavim-ext

reavim-ext is a compiled Zig REAPER extension (a vim mode) that intercepts
keystrokes via REAPER's `<accelerator` hook. See `README.md` for the
architecture and milestones; this file is the operational guide for an agent
making changes: how to build, and how to run and inspect a real REAPER
headlessly so changes can be verified without a human at the keyboard.

## Toolchain and persistent locations

Everything needed lives under `/tank/projects` so it survives container resets
(only `/tank` and `~/.claude` persist; the rest of `/home/claude` is wiped).

- Zig 0.14.1: `/tank/projects/.toolchains/zig-x86_64-linux-0.14.1/zig`
- Headless X stack (Xvfb, xdotool, GL/xkb libs, all rootless): `/tank/projects/.toolchains/xtools/prefix`
- Portable REAPER 7.74 (licensed): `/tank/projects/reaper-portable`
- The extension is symlinked into REAPER: `reaper-portable/UserPlugins/reaper_reavim.so -> /tank/projects/reavim-ext/zig-out/reaper_reavim.so`

## Build

From the repo root:

```sh
Z=/tank/projects/.toolchains/zig-x86_64-linux-0.14.1/zig
$Z fmt src/            # format (CONVENTION.md from reaperConsole1: always fmt)
$Z build test          # unit tests — must be green before commit
$Z build               # Debug .so (per-key + post-exec logging ACTIVE)
$Z build -Doptimize=ReleaseSafe   # quiet build to hand to the user
```

Debug builds log every keystroke and an API readout after each executed
command (see Logging below). ReleaseSafe compiles that out. The symlink means
a rebuild is picked up by the next REAPER launch with no copy step.

## Running REAPER headlessly

`testing/run-headless.sh` (deployed at `reaper-portable/run-headless.sh`)
starts Xvfb on `:99` if needed, launches REAPER into it, and dismisses the
startup audio-device dialog. With the license installed there is no eval nag.

```sh
/tank/projects/reaper-portable/run-headless.sh [project.RPP]
tail -f /tmp/reaper-test.log     # extension stderr (logging)
```

Drive input with xdotool against display `:99`:

```sh
P=/tank/projects/.toolchains/xtools/prefix
export LD_LIBRARY_PATH=$P/usr/lib/x86_64-linux-gnu DISPLAY=:99
X=$P/usr/bin/xdotool
W=$($X search --name "REAPER v7" | head -1); $X windowfocus $W
$X key w        # send a key to REAPER
```

### Rig quirks (important, these cost real debugging time)

- **F-keys arrive with a spurious Alt** under this Xvfb (they come as
  `SYSKEYDOWN` with the alt flag). Don't bind test triggers to F-keys; use the
  action list or Ctrl-combos instead.
- **You cannot open the action list (`?`) while vim mode is ON** — vim eats the
  key. Toggle vim off first, or trigger actions by a key vim passes through
  (unbound Ctrl/Alt combos pass through in normal mode).
- The license is installed by copying `reaper-license.rk` to the resource-dir
  **root** (`reaper-portable/reaper-license.rk`). This is the only
  non-interactive license method; there is no CLI flag. The key file is
  gitignored — never commit it.

## Logging (reading state out of the extension)

The Debug build logs to stderr (→ `/tmp/reaper-test.log`), scope-prefixed:

- `(accel)`: every raw key message with `lParam` modifier flags and `virt=`
  (FVIRTKEY — distinguishes VK codes from literal ASCII punctuation).
- `(engine)`: the decision per key — `key token 'X' -> buffer '...'`, then one
  of `built: <Action> (comp=...)`, `pending (N continuations)`, or
  `undefined sequence, cleared`; and after execution
  `post-exec: cursor=<pos> sel_tracks=<n>` (a direct REAPER API readout).

For most behavioral assertions (did the cursor move? how far?) the `post-exec`
line is enough — it is the REAPER API answer, not a screenshot. Do NOT verify
state by screenshotting and eyeballing pixels.

## Querying the REAPER API externally

REAPER's API is only callable in-process (compiled extension or a ReaScript in
its embedded Lua 5.4). There is **no external RPC and no CLI flag to run a
script and exit**. To read arbitrary API values from the shell, run a Lua
ReaScript that writes results to a file, then read the file. Full survey of
options (file-watching deferred REPL, python-reapy, OSC limits, js_ReaScriptAPI)
is in `REAPER_external_control_research.md`.

The lightweight recipe this repo uses:

1. A probe script writes API values to a file — `testing/reavim_dump_state.lua`
   dumps cursor, track count, selection, and every item position to
   `/tmp/reaper-state.txt`.
2. **Register it without a GUI load** via a `SCR` line in
   `reaper-portable/reaper-kb.ini` (see `testing/reaper-kb.ini.sample`):
   ```
   SCR 4 0 RS_reavimdump "Custom: reavim_dump_state.lua" "reavim_dump_state.lua"
   ```
   `reaper-kb.ini` is read at launch, so the script becomes an action with the
   named command id `_RS_reavimdump` — no one-time "Load ReaScript" click.
3. Trigger it (action list by description while vim is off, or a passthrough
   key binding) and read `/tmp/reaper-state.txt` from the shell.

`testing/reavim_setup.lua` is the companion that selects track 0 and parks the
edit cursor at 0 — useful to establish a known state before sending keys
(motions like `w`/`NextItemStart` operate on items of the *selected* track, so
with no track selected they appear to do nothing).

For a persistent two-way channel (inject arbitrary API calls, not just a fixed
dump), the deferred file-watching REPL in the research doc is the way; it has
not been needed yet for this project.

## Commit conventions (from reaperConsole1)

`<module-or-area>: <message>` prefix (e.g. `key:`, `engine:`, `ui:`,
`chore:`). Build + tests must pass before any commit. Commit only when the user
asks. Never commit `reaper-license.rk`.
