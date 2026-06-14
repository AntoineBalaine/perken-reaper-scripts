# Changelog

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
