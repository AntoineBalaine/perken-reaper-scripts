# Driving & querying a running REAPER (v7.74, Linux) from an external process

Research report. REAPER's API is only callable in-process (compiled C extension, or ReaScript Lua/EEL/Python in the embedded interpreter). There is no built-in external RPC. Below are the established community techniques, with code, exact Linux paths, latency/handshake characteristics, limitations, and a ranking for the use case "an automated agent asserts REAPER state in a test loop."

REAPER 7.x embeds **Lua 5.4** (6.x and earlier used 5.3). Source: https://www.reaper.fm/sdk/reascript/reascript.php

Resource directory on Linux (non-portable install): `~/.config/REAPER/`
Portable install: the resource dir is the folder containing the portable `reaper` binary.
Reveal it from the GUI via Options > Show REAPER resource path.

---

## 1. File-watching deferred ReaScript REPL  (THE primary technique)

### Mechanism
A persistent Lua script runs a `reaper.defer()` self-loop on REAPER's main thread (~30-60 ticks/sec). Each tick it stats a command file; if present, it reads the file, compiles it with `load()`, runs it under `pcall`, captures all return values, serializes them, and writes them to an output file. An external process (shell/agent) writes commands and reads results — arbitrary REAPER API calls in, return values out.

### Lua version detail — use `load()`, NOT `loadstring()`
`loadstring` is the Lua 5.1 name, removed in 5.2+. REAPER 5.3/5.4 wants `load()`. `load()` never raises: it returns `function, nil` on success or `nil, errString` on a compile error. To make an expression like `reaper.CountTracks(0)` echo its value REPL-style, prepend `return ` and fall back to plain compile for multi-statement chunks (the cfillion idiom). Source: https://www.lua.org/pil/8.html

### The defer loop + atexit (canonical template)
`reaper.defer(func)` schedules `func` once on the next main-thread tick; the loop persists by re-deferring itself ("tail-defer"). `reaper.atexit(cleanup)` runs cleanup when the script is terminated (from the Actions list, on REAPER quit, or on a runtime error). A deferred script CANNOT be re-invoked via `Main_OnCommand` while running (toggling its action terminates it) — which is exactly why an external driver must poll a file, not "call" the script. Source: https://www.reaper.fm/sdk/reascript/reascript.php

ReaTeam / X-Raym background-script template (verbatim):
https://github.com/ReaTeam/ReaScripts-Templates/blob/master/Templates/X-Raym_Background%20script.lua
```lua
function Main()
  reaper.defer( Main )
end
Main()
reaper.atexit( SetButtonState )   -- toolbar toggle cleanup
```

### REPL core — the gold-standard reference
cfillion's Interactive ReaScript (`ireascript.lua`) is the implementation behind the Cockos "Interactive ReaScript (Lua)" thread. It is the reference REPL: expression-first compile, then statement fallback, then `xpcall` capturing all returns into a table.
https://github.com/cfillion/reascripts/blob/master/ireascript.lua
```lua
local func, err = load('return ' .. code, scope)
if not func then func, err = load(code, scope) end
-- run under protected call, capture ALL return values:
local ok, values = xpcall(function() return {func()} end,
                          function(e) return e end)
```
`{func()}` matters because REAPER API calls are frequently multi-return.

### Architecture proof: reapy
python-reapy's server IS this exact loop topology (accept -> get -> process -> send -> `reaper.defer(self)`), just over a TCP socket instead of a file. Swap the socket for `io.open` and you have the file variant. It wraps every request in try/except so one bad call never kills the loop — adopt the same `pcall`-per-request discipline.
https://github.com/RomeoDespres/reapy  (module `reapy/reascripts/activate_reapy_server.py`)
defer rate (30-60/s): https://python-reapy.readthedocs.io/en/latest/api_guide.html

### File-watch handshake / locking
The defer loop is single-threaded on REAPER's main thread, so there is no internal race — the only race is between REAPER's reader and the external writer. Stock Lua `io.*` works in REAPER (`io.open`, `read("a")`, `io.write`; `io.popen` on 64-bit builds). Source: https://forum.cockos.com/archive/index.php/t-165856.html
- **Atomic rename (best):** external side writes `cmd.tmp`, then `os.rename("cmd.tmp","cmd.lua")` (atomic within one filesystem on POSIX). The poller only ever sees a complete file.
- **Numbered files (best for correlation):** external writes `cmd.0001.lua`; Lua processes it, writes `out.0001.txt`, then `os.remove`s the command file. Presence/absence is the handshake; gives request/response correlation a fixed filename cannot.
- **ExtState as doorbell:** `reaper.SetExtState/GetExtState` is a lock-free signal channel for "command ready"/"result ready", BUT ExtState is NOT newline-safe ("newlines should not be used in extstates as they might be cut when rereading them") — keep multiline code/results in the file, use ExtState only for short flags/sequence numbers. Source: https://www.reaper.fm/sdk/reascript/reascript.php
- **Never block the loop:** each tick, stat and return immediately if no command; don't run long external processes synchronously in a tick (use `reaper.ExecProcess(cmdline, timeout)` if needed). https://forums.cockos.com/showthread.php?t=226767

### Minimal known-good implementation
```lua
local CMD = reaper.GetResourcePath() .. '/reaper_repl_cmd.lua'
local OUT = reaper.GetResourcePath() .. '/reaper_repl_out.txt'

local function serialize(...)
  local n, parts = select('#', ...), {}
  for i = 1, n do parts[i] = tostring(select(i, ...)) end
  return table.concat(parts, '\t')
end

local function evalChunk(code)
  local fn, err = load('return ' .. code)   -- expression-first
  if not fn then fn, err = load(code) end    -- statement fallback
  if not fn then return false, 'compile error: ' .. err end
  return pcall(fn)                            -- ok, ...returns
end

local function loop()
  local f = io.open(CMD, 'r')
  if f then
    local code = f:read('a'); f:close()
    os.remove(CMD)
    local ok, a, b, c = evalChunk(code)
    local body = ok and ('OK\t'  .. serialize(a, b, c))
                     or  ('ERR\t' .. tostring(a))
    local tf = io.open(OUT .. '.tmp', 'w'); tf:write(body); tf:close()
    os.rename(OUT .. '.tmp', OUT)             -- atomic publish
  end
  reaper.defer(loop)
end

reaper.atexit(function() os.remove(CMD); os.remove(OUT) end)
loop()
```
External driver: write `reaper_repl_cmd.lua.tmp` -> rename to `reaper_repl_cmd.lua` -> busy-wait for `reaper_repl_out.txt` -> read -> delete. Use numbered cmd/out files to eliminate the race and get correlation.

### Paths (Linux)
Command/output files: anywhere; `reaper.GetResourcePath()` returns `~/.config/REAPER` (non-portable). Script itself: see section 2.

### Latency
defer ticks at ~30-60 Hz => round-trip floor ~16-33 ms plus your external poll interval. Fine for a test loop; not microsecond-grade.

### Limitations
Polling adds latency vs a socket; needs careful handshake to avoid partial reads; the script must be running (auto-start it, section 2); runs on the main thread so a heavy command briefly stalls REAPER's UI.

---

## 2. Auto-run a ReaScript at launch (Linux) + the CLI question

### `__startup.lua` (native, confirmed)
REAPER natively auto-runs a Lua file named `__startup.lua` (two leading underscores) on every launch if it sits in the `Scripts` subfolder of the resource dir.
- Non-portable Linux: `~/.config/REAPER/Scripts/__startup.lua`
- Portable: `<portable_install_dir>/Scripts/__startup.lua`
Just drop the file there; no further config. Sources:
https://reaper.blog/2021/03/startup-actions/ ("two underscores", "must be in scripts folder", "Runs at REAPER launch")
https://forum.cockos.com/showthread.php?t=161181 (canonical thread)
https://www.reaper.fm/sdk/reascript/reascript.php (Scripts resource-dir convention)

To auto-start the REPL: put the loop in `~/.config/REAPER/Scripts/__startup.lua`, or have `__startup.lua` `dofile()` your REPL script.

### SWS global startup action (alternative, needs SWS extension)
Action `SWS/S&M: Set global startup action` runs one action (by Command ID) at every launch — point it at your REPL ReaScript (or a macro). Project-scoped variant: `SWS/S&M: Set project startup action`. Stored in SWS config (`~/.config/REAPER/S&M.ini`).
https://forums.cockos.com/showthread.php?t=175485

### CLI flag to run a script and exit? NO (definitive, v7.x)
There is no headless/batch ReaScript-and-exit flag. You CAN pass a `.lua` positional arg — `reaper project.rpp script.lua` (supported since build 6.80) — but it runs inside a normal GUI session that launches and STAYS OPEN; passing the script does not execute-and-quit. No `-script`, no `-batch`, no `-headless`, no `-nogui`. Only `-renderproject` and `-close...:exit` exit. This remains an unfilled feature request.
Authoritative CLI reference (verbatim usage line):
`reaper.exe [options] [projectfile.rpp | mediafile.wav | scriptfile.lua [...]] | fxchainpreset.RfxChain | vstbank.fxb | vstpatch.fxp | vstpatch.vstpreset`
"Multiple media files and/or scripts may be specified, and will be added or run in order."
https://github.com/ReaTeam/Doc/blob/master/REAPER-CLI.md
Headless feature request (confirms absence): https://forum.cockos.com/showthread.php?t=263372

### Other CLI flags REAPER accepts (Linux, v7.x)
positional `projectfile.rpp|mediafile.wav|scriptfile.lua`; `-new`; `-template f.rpp`; `-saveas f.rpp`; `-renderproject f.rpp` (render+exit); `-peaktest f.cpp`; `-newinst`/`-nonewinst` (send to already-running instance); `-noactivate` (Linux/mac since 7.29); `-audiocfg`; `-cfgfile /full/path/file.ini` (alternate resource dir); `-ignoreerrors`; `-nosplash`; `-splashlog /path.log`; `-close[all][:save|:nosave][:exit]`; `-batchconvert filelist.txt` (media converter only, not ReaScript). Source: same ReaTeam CLI doc.

---

## 3. js_ReaScriptAPI — sockets / file mailbox? NO sockets.
Authoritative function list: `js_ReaScriptAPI_def.h`.
https://github.com/juliansader/js_ReaScriptAPI  (def: https://raw.githubusercontent.com/juliansader/js_ReaScriptAPI/master/js_ReaScriptAPI_def.h)
Forum: https://forum.cockos.com/showthread.php?t=212174
- NO socket/TCP/UDP/named-pipe functions (grep of the def for socket|tcp|udp|network|pipe = nothing). It gives Lua no network transport.
- File helpers: essentially only `JS_File_Stat` (size/times/inode/mode). NO `JS_File_Read`/`Write` mailbox — use stock Lua `io` for file read/write. (There is a full `JS_Zip_*` namespace and `JS_LICE_*` PNG/JPG load/write.)
- It is a Win32/GUI-and-OS bridge: `JS_Window_*` (69), `JS_LICE_*` (46), `JS_GDI_*` (26), `JS_WindowMessage_*` (16), `JS_Zip_*` (16), `JS_ListView_*` (15), `JS_Mouse_*` (13), `JS_VKeys_*` (5), `JS_Actions_*` (4), `JS_Dialog_*` (file/folder dialogs), `JS_Mem_*` (4), etc.
Bottom line: not a networking library. For IPC you fall back to file `io` (as in section 1), or EEL2's `tcp_connect()` in EEL scripts, or a separate native socket module.

---

## 4. OSC — predefined feedback only, NOT arbitrary API values
Docs: https://www.reaper.fm/sdk/osc/osc.php
Config deep-dive: https://konbear.com/articles/deep-dive-into-reaperosc-config-file
Limits / bridging: https://radugin.com/posts/2024-07-07/control-reaper-via-osc/
- OSC is a control-surface protocol limited to REAPER's hard-coded vocabulary, surfaced via the `.ReaperOSC` pattern file. You can rename/remap addresses but CANNOT invent new tokens.
- CAN report: transport (play/stop/record/pause/repeat, playhead time/beats), TEMPO, METRONOME, SCRUB; per-track VOLUME/PAN/MUTE/SOLO/SELECT/NAME/RECARM, VU meters; sends/receives; FX bypass and FX_PARAM values/names; markers/regions; track/bank navigation; generic ACTION trigger by command ID.
- CANNOT: call arbitrary API functions — no `GetMediaItemInfo_Value`, no item/take metadata, no arbitrary project state. UDP, no handshake: REAPER does not push full state on connect; you must trigger a refresh and catch feedback. Script-received OSC can read only the FIRST argument, and args are string/float only.
- Linux config: `~/.config/REAPER/OSC/` (holds `Default.ReaperOSC` and custom copies). Configure via Preferences > Control/OSC/web > Add > OSC (Open Sound Control); set local listen port, device IP/port, pattern config.
Bottom line: fixed-vocabulary feedback channel, not a general query mechanism.

---

## 5. Other approaches

### Built-in Web Browser Interface (web remote control surface)
Internal HTTP server enabled as a control surface: Preferences > Control/OSC/Web > Add > Web Browser Interface, default port 8080, `http://localhost:8080/`. HTML served from `reaper_www_root/` (stock under app `Plugins/reaper_www_root/`; override by putting `reaper_www_root` in the resource dir). It is a FIXED command protocol, NOT an API gateway: from the browser you can only send numeric action command IDs, registered ReaScript/custom action IDs, and a fixed token set (TRANSPORT, BEATPOS, MARKER, REGION, GET/SET/EXTSTATE, EXTSTATEPERSIST, PROJEXTSTATE, track/send). JS side: `wwr_start()`, `wwr_req()`, `wwr_onreply()`. To expose arbitrary state you write a ReaScript that publishes it into ExtState and the page polls via EXTSTATE — you cannot call `GetCursorPosition()` directly over the web remote. Reverse-engineered ref: https://mespotin.uber.space/Ultraschall/Reaper_API_Web_Documentation.html ; community front-end: https://github.com/RCJacH/RCRemote

### Shell-out from Lua: reaper.ExecProcess (core, no extension)
`string reaper.ExecProcess(string cmdline, integer timeoutmsec)` — runs a command synchronously; returns a string whose first line is the exit code, then newline, then captured stdout. `timeout 0` = run to completion. The standard way to invoke curl/nc/python and capture stdout back into Lua (REAPER Lua has NO socket library, so you do HTTP by shelling to curl). NOTE: does not inherit PATH — use absolute binary paths. Source: https://www.reaper.fm/sdk/reascript/reascripthelp.html
SWS `CF_ShellExecute` only launches (no stdout capture); for capture use ExecProcess. SWS also has `CF_GetClipboard`/`CF_SetClipboard`.

### python-reapy / MCP servers (full arbitrary API over network)
python-reapy enables a "distant API" — a self-deferring TCP server ReaScript that an external Python process drives, giving arbitrary in-process API access remotely (default ports 2306/2307, advertised via ExtState). Heavier than a file bridge but the most ergonomic for an external program. https://pypi.org/project/python-reapy/ , https://github.com/RomeoDespres/reapy , MCP wrapper: https://github.com/shiehn/total-reaper-mcp

---

## Ranking for "an automated agent asserts REAPER state in a test loop"

1. **File-watching deferred REPL (section 1).** Zero dependencies (stock Lua + defer + io), arbitrary API access, simple atomic-rename/numbered-file handshake, language-agnostic external driver. Best fit for an agent. ~16-33 ms + poll latency.
2. **python-reapy distant API.** Same arbitrary access with the nicest ergonomics IF your driver is Python; adds the reapy server + network setup as moving parts. Use if you want a real client library rather than hand-rolled file IO.
3. **Web Browser Interface + ExtState bridge.** Works, HTTP from anything, but you still must write a ReaScript publishing state into ExtState — i.e. you end up building the same in-process publisher as #1 with more ceremony.
4. **OSC.** Only for the predefined vocabulary (transport/track/FX-param). Cannot assert arbitrary state like `GetMediaItemInfo_Value`. Use only if your assertions happen to fall within its tokens.
5. **js_ReaScriptAPI.** Not applicable as a transport (no sockets, no mailbox). Useful only for GUI/window automation, not state RPC.
- No-go: a CLI flag to run a script headless and exit — does not exist (section 2).

Recommended setup: REPL loop in `~/.config/REAPER/Scripts/__startup.lua`, driver uses numbered cmd/out files in `~/.config/REAPER/` (or a tmpdir), atomic rename on write, busy-wait/inotify on the out file.

---

## 6. Non-interactive REAPER license install (.rk) on Linux

- Exact filename: **`reaper-license.rk`** (small text file, ~354 bytes). Confirmed: https://lacinato.com/cm/blog/25-reaperportable ("Find the file reaper-license.rk by ... Show REAPER resource path").
- Placement: at the ROOT of the resource directory. Non-portable Linux: `~/.config/REAPER/reaper-license.rk`. Portable: alongside the portable binary's config (the portable resource dir). REAPER reads it on startup; if a valid file is present it boots licensed with no nag/eval dialog and no GUI click.
- Non-interactive steps:
  1. `mkdir -p ~/.config/REAPER`
  2. copy your `reaper-license.rk` to `~/.config/REAPER/reaper-license.rk` BEFORE first launch.
  Equivalently, copy an entire already-licensed `~/.config/REAPER` dir, or stage an alternate resource dir and launch `reaper -cfgfile /path/to/reaper.ini`.
- CLI flag to import a license? NO. No `-license`/`-importkey`/activation flag exists. The file-drop is the only supported non-interactive method. Source (full flag list, confirms absence + documents `-cfgfile`): https://github.com/ReaTeam/Doc/blob/master/REAPER-CLI.md

---

## Source caveats
- forum.cockos.com is Cloudflare/login-gated to automated fetches; cited threads were corroborated via cfillion's public source, the ReaTeam CLI doc, reaper.fm, and the REAPER Blog rather than quoted directly.
- The atomic-rename/sentinel handshake is well-grounded engineering (built on REAPER-confirmed facts: single-threaded defer loop, working `io.*`, ExtState newline limitation) rather than a single verbatim community artifact.
