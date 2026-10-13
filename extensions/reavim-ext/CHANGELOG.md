# Changelog

## [v0.2.0]

### Added
- **Doubled track operators**: a single-key track operator typed twice applies to the current track only (`MM` mute, `SS` solo, `dd` cut, `yy` copy, `aa` arm, …). Explicit bindings for a doubled sequence (e.g. `zz`, `ss`) keep priority. The whichkey offers the repeated key after an operator.
- **Search keys & commands** (`<space>/`): a search box at the top of the whichkey window lists every binding usable in the current context and mode, filtered by the words you type (matched against keys, action names and descriptions). Typing is captured by vim, so the arrange view keeps focus; Up/Down or `<C-n>`/`<C-p>` select, Enter runs the binding as if its keys were typed (an operator then waits for its motion), Esc closes. The box also works by clicking it with the mouse
- **Batch rename** (`<space>tb`, or the REAPER action `ReaVim: Batch rename selected tracks in editor`): the selected tracks' names open in vim, one per line, in a new terminal window; saving and quitting renames the tracks in one undo step, and `:cq` cancels. The editor defaults to your `$VISUAL` / `$EDITOR` (vim fallback), and on macOS the Terminal.app window closes by itself after the editor exits. The terminal, editor and auto-close are set in the new `[rename]` section of `bindings.ini`
- **Whichkey focus handoff**: keys typed while the whichkey window has focus move focus back to the arrange view and run there, instead of being silently swallowed

### Fixed
- The whichkey window no longer stays missing when ReaImGui loads after ReaVim: because extension load order is not guaranteed, ReaImGui is now detected on the first timer tick, once every extension has finished loading, instead of at ReaVim's own load
- Without ReaImGui installed, the search action no longer makes the keyboard appear dead: it used to capture every key into a search box that is never drawn, and it now does nothing in that case
- `t` (`CurrentTrack`) was an empty placeholder, so `Mt` and similar applied the operator to the whole track selection; it now selects only the current track

### Changed
- The `dd`, `yy` and `aa` command bindings are removed from the defaults: they now go through the doubled-operator rule and act on the current track only, instead of on every selected track

## [v0.1.3]

### Fixed
- macOS: text fields (track rename, etc.) no longer have their keys eaten by vim — on macOS the accelerator hook delivers a container HWND rather than the focused child control, so `GetFocus()` is now checked alongside `msg.hwnd`

## [v0.1.2]

### Added
- **macOS support**: plugin now loads correctly on macOS — REAPER passes NULL to `SWELL_dllMain` on macOS and the resolver is now retrieved from the app delegate via the ObjC runtime, matching WDL's own `swell-modstub.mm` pattern
- **Whichkey fold chevron**: `▼/▶` button at the start of the status line collapses the window to a single line and expands it back (window height resize not yet working)
- **Edit bindings action**: `ReaVim: Edit bindings` registered as a REAPER action (also bound to `<space>B`) — opens `bindings.ini` in the OS default editor, creating it from embedded defaults if absent

### Fixed
- Script floating windows (`reaper_imgui_context`, `Lua_LICE_gfx_standalone`) no longer have their keys eaten by vim — they are parented under the main HWND so the ancestry check incorrectly passed them through to the engine

### Changed
- Vim on/off state persists across restarts via `Data/Perken/reavim.ini`
- Bindings file consolidated to `Data/Perken/bindings.ini` (single location for both the loader and the edit action)

## [v0.1.0]

Initial release.
