# reavim custom_actions — Zig port inventory

Source: `/tank/projects/perken-reaper-scripts/reavim/internal/custom_actions/` (18 files, ~4300 LOC incl. helpers).
Difficulty legend:
- **EASY** — straight sequence of `reaper.*` calls, no nontrivial data structures.
- **MEDIUM** — loops/arithmetic over tracks/items/notes/envelope points; needs small in-memory lists.
- **HARD** — state-chunk/string serialization, `defer`-based polling, external Lua libs (serpent, ultraschall, Scythe), or multi-stage take manipulation.
- **SKIP** — hardware-specific (MFT/Realearn) or reavim-internal/dev plumbing; recommend not porting.

Convention note: line numbers are from the current files. "ItemPosition" = `{left, right}` in project seconds; "big item" = run of overlapping/contiguous items merged into one span.

---

## custom_actions.lua (76 LOC, module table aggregator)

This file also `require`s every submodule into one table — in Zig this becomes the action-registry/dispatch layer.

- `custom_actions.clearTimeSelection` (custom_actions.lua:24) — Reads the edit cursor with `GetCursorPosition`, then calls `GetSet_LoopTimeRange(true, false, pos, pos, false)` to collapse the time selection to a zero-length range at the cursor. **EASY**
- `custom_actions.setMidiGridDivision` (custom_actions.lua:47) — Prompts via `GetUserInputs` and parses a fraction string ("1/8" or "0.25") with the local helper `getUserGridDivisionInput` (:29). On success calls `SetMIDIEditorGrid(0, division)` and refocuses the MIDI editor via `Main_OnCommand(NamedCommandLookup("_SN_FOCUS_MIDI_EDITOR"))`. **EASY** (fraction parsing is trivial in Zig)
- `custom_actions.clearSelectedTimeline` (custom_actions.lua:55) — Exact duplicate of `clearTimeSelection` (same two calls). Port once, alias the binding. **EASY**
- `custom_actions.setGridDivision` (custom_actions.lua:60) — Same `GetUserInputs` fraction prompt, then `SetProjectGrid(0, division)` for the arrange grid. **EASY**
- `custom_actions.splitItemsAtTimeSelection` (custom_actions.lua:68) — Guards with `CountSelectedMediaItems(0) == 0` then runs native action 40061 (split at time selection) via `Main_OnCommand`. The guard prevents REAPER from splitting every track when nothing is selected. **EASY**

Local helper: `getUserGridDivisionInput` (:29) — `GetUserInputs` + numerator/denominator parse; shared by both grid setters. Port as a shared helper.

---

## selection.lua (48 LOC)

- `select.innerProjectTimeline` (selection.lua:6) — `GetProjectLength(0)` then `GetSet_LoopTimeRange(true, false, 0, project_end, false)`: selects the whole project timeline. **EASY**
- `select.innerItem` (selection.lua:11) — Builds the merged item-position list for all selected tracks (utils.getItemPositionsOnSelectedTracks), reads `GetCursorPosition`, iterates the list backwards and sets the time selection (`GetSet_LoopTimeRange`) to the first item span containing the cursor. **MEDIUM** (needs the item-position helper)
- `select.innerBigItem` (selection.lua:23) — Same as `innerItem` but over `getBigItemPositionsOnSelectedTracks` (overlapping items merged into one span). **MEDIUM**
- `select.onlyCurrentTrack` (selection.lua:35) — `GetSelectedTrack(0,0)`; if non-nil, `SetOnlyTrackSelected(track)`. Collapses multi-selection to the first selected track. **EASY**
- `select.innerRegion` (selection.lua:42) — `GetCursorPosition` → `GetLastMarkerAndCurRegion(0, pos)` for the region id → `utils.selectRegion(id)`, which does `EnumProjectMarkers(id)` and sets `GetSet_LoopTimeRange` to the region bounds. **EASY**

---

## fx.lua (61 LOC)

- `fx.insertFXAtSlot` (fx.lua:43) — Prompts for a slot number (`GetUserInputs`), snapshots selected tracks, saves selection (`_SWS_SAVESEL`), inserts a dummy track at index 0 (`InsertTrackAtIndex`), selects it, opens the FX browser (action 40271), then arms a `reaper.defer` polling loop (`wait_until_has_added_fx`, :8) that watches `Undo_CanUndo2(0)` until the undo string matches "Add FX: ..."; it then string-parses the undo description to confirm track/FX name, closes the chain window (`_S&M_WNCLS5`), copies the new FX from the dummy track to every originally-selected track at the requested slot (`TrackFX_CopyToTrack`), restores selection (`_SWS_RESTORESEL`) and deletes the dummy track (`DeleteTrack`). **HARD** — relies on a deferred polling loop and fragile undo-string parsing (locale-dependent); in a Zig extension you'd reimplement this with a timer callback or hook, and the undo-text matching is the risky part.

---

## tracks.lua (80 LOC)

- `tracks.trackVolumeDown3` (tracks.lua:15) — For each selected track (utils.cycleSelectedTracks), reads `GetMediaTrackInfo_Value(track,'D_VOL')` and writes it back multiplied by `10^(0.05*-3)` (−3 dB). **EASY**
- `tracks.trackVolumeUp3` (tracks.lua:23) — Same with +3 dB. Local helper `nudgeTrackVolumeAmount` (:9) does the dB math. **EASY**
- `tracks.renameTrackToVstiPresetName` (tracks.lua:47) — For each selected track: `TrackFX_GetInstrument` → if a VSTi exists, `TrackFX_GetFXName` (strips "VSTi: " prefix and trailing "(...)" via gsub), `TrackFX_GetPreset`; writes either the FX name or the preset name into `GetSetMediaTrackInfo_String(track,"P_NAME",...,true)`. **MEDIUM** (loop + small string munging)
- `tracks.soloExclusive` (tracks.lua:71) — Reads `I_SOLO` of the first selected track, unsolos all tracks (action 40340), and if the track wasn't soloed sets its `I_SOLO` to 1. Toggle-style exclusive solo. **EASY**

---

## Mapping_types.lua (82 LOC)

Pure LuaLS `---@class` annotations describing Realearn (Helgoboss) compartment/mapping/glue/target shapes used by MFT.lua. No executable code, no functions. **SKIP** — Realearn/MFT-specific type metadata; only needed if MFT.lua is ported.

---

## routing.lua (107 LOC)

- `routing.routeTracksToBusses` (routing.lua:61) — Finds all tracks whose `P_NAME` contains "bus" (`CountTracks`/`GetTrack`/`GetSetMediaTrackInfo_String` loop, local `getTracksNamesContainBus` :25); for each bus, local `sendColorToMatchingBuss` (:42) loops all tracks reading `I_CUSTOMCOLOR`, `IP_TRACKNUMBER`, `GetParentTrack`, and for every non-child same-colored track creates `CreateTrackSend(tr, bus)` and zeroes `B_MAINSEND`. **MEDIUM**
- `routing.buildBusses` (routing.lua:91) — For each name in the hardcoded `Busses` prefix list (BA, BGV, DR, GTR…): `InsertTrackAtIndex(0,true)`, rename via `GetSetMediaTrackInfo_String`, run SWS auto-color (`_SWSAUTOCOLOR_APPLY`), route matching-colored tracks to it (same helper), then `GetTrackNumSends(bus,-1)` and `DeleteTrack` if it received nothing. **MEDIUM** (note: relies on SWS auto-color rules existing in the user config)

---

## dev.lua (115 LOC)

- `dev.fxDevices` (dev.lua:6) — Single `Main_OnCommand(NamedCommandLookup("_RSa0b0..."))` launching a personal ReaScript by registered command id. **SKIP** — launcher for a user-local script; the command id won't exist outside this install.
- `dev.repl` (dev.lua:10) — Same pattern, launches a Lua REPL script. **SKIP** — dev tooling, install-specific command id.
- `dev.devAction` (dev.lua:102) — Scratchpad: currently launches a "shortcutManager demo" script by command id; body is mostly commented-out experiments. **SKIP** — dev scratch, changes constantly.

Globals defined here but unused by any binding: `GetOpenProjects` (:14, `EnumProjects`/`ValidatePtr` loop — trivial), `GetAllFloatingFXWindows` (:47, walks master + all tracks + input FX + all takes calling `TrackFX_GetFloatingWindow`/`TakeFX_GetFloatingWindow` — MEDIUM if ever needed), and the half-written `getAllFxChainWindows` (:29, references undefined `hwnd`, dead code).

---

## drums.lua (124 LOC)

- `drums.flam` (drums.lua:48) — For each selected item in each selected track (utils.cycleSelectedItemsInSelectedTracks), calls global `CreateFlams(item, track)` (:9): reads `D_POSITION`/`D_LENGTH`, temporarily shortens the item to 40 ms, copies the item to the same track at `pos - flamLength` via `utils.CopyMediaItemToTrack` (state-chunk copy), lowers the copy's volume (`D_VOL` × dB factor), sets `D_FADEINLEN`/`D_FADEOUTLEN`, pitches the copy's active take down (`SetMediaItemTakeInfo_Value 'D_PITCH'`), then restores the original `D_LENGTH`. **MEDIUM** (depends on the chunk-based item-copy helper — see utils notes)
- `drums.ras3` (drums.lua:55) — Same as flam with `reps=2` (two grace hits, tighter spacing/fades). **MEDIUM**
- `drums.ras5` (drums.lua:62) — Same with `reps=4`. **MEDIUM**
- `drums.crescendo` (drums.lua:69) — Per selected track runs global `CrescendoTrackSelectedItems` (:78): collects selected items (`CountTrackMediaItems`/`GetTrackMediaItem`/`IsMediaItemSelected`), reads the last item's `D_VOL`, then iterates items in reverse assigning linearly decreasing `D_VOL` and decreasing take `D_PITCH` so volume/pitch ramp up toward the last hit. **MEDIUM**
- `drums.decrescendo` (drums.lua:73) — Mirror image via `DecrescendoTrackSelectedItems` (:99), ramping down from the first item's volume. **MEDIUM**
- `drums.quantizeTool` (drums.lua:120) — `Main_OnCommand(NamedCommandLookup("_RS61423f..."))`. **SKIP** — launches a user-local third-party quantize script by command id.

---

## items.lua (168 LOC)

- `items.paste_before` (items.lua:8) — Pure command-id choreography to paste clipboard items *before* the cursor: store cursor (`_XENAKIOS_DOSTORECURPOS`), save selection (`_SWS_SAVESEL`), insert temp track (40001), paste (40058), recall cursor, trim right edge to cursor (41307), move cursor to item right edge (40318), cut (40699), delete temp track (40005), restore selection (`_SWS_RESTORESEL`), paste again (40058). **EASY** (long but branch-free sequence)
- `items.set2msFades` (items.lua:34) — For each selected item in selected tracks sets `D_FADEINLEN`/`D_FADEOUTLEN` to 0.002 s. **EASY**
- `items.splitItemsAtNoteStart` (items.lua:77) — Opens the built-in MIDI editor (40153), `MIDIEditor_GetActive`, selects all events (ME cmd 40006); then for each selected media item with an active MIDI take (`GetActiveTake`/`TakeIsMIDI`): `MIDI_CountEvts`, reads each note's start ppq (`MIDI_GetNote`), converts to project time (`MIDI_GetProjTimeFromPPQPos`), dedupes the times, and calls `SplitMediaItem(item, t)` at every note start except the first; finally closes the MIDI editor (ME cmd 40477). **MEDIUM**
- `items.stretchItem` (items.lua:125) — Arg `"start"|"end"`. For each selected item: compares cursor (`GetCursorPosition`) to `D_POSITION`; if extending, computes the new length, rescales every take's `D_PLAYRATE` by `old_len*rate/new_len` (`CountTakes`/`GetTake`/`Get/SetMediaItemTakeInfo_Value`), optionally runs action 41205 (move item start? trim to cursor) when stretching the start, sets `D_LENGTH`, `UpdateItemInProject`. Time-stretches item to the edit cursor keeping content. **MEDIUM**
- `items.fadeItemInFromMouse` (items.lua:152) / `items.fadeItemOutFromMouse` (:156) / `items.trimRightEdgeFromMouse` (:160) / `items.trimLeftEdgeFromMouse` (:164) — Four wrappers over local `editItemFromMouse(action, edge)` (:40): store cursor (`_XENAKIOS_DOSTORECURPOS`), move edit cursor to mouse (40514), if snap enabled (`GetToggleCommandStateEx(0,1157)`) snap cursor via `SnapToGrid` + `MoveEditCursor`, select item under mouse (40528), then one of fade-in-to-cursor 40509 / fade-out 40510 / trim-left 41300 / trim-right 41310, unselect all items (40289), restore cursor (`_XENAKIOS_DORECALLCURPOS`). **EASY** ×4 (one shared helper, command-id sequence with one branch)

---

## harmonizer.lua (171 LOC)

- `harmonizer.harmonize(melody_midi_number, chord_symbol)` (harmonizer.lua:147, exported :167) — Pure music-theory function, **zero reaper API calls**. Parses a chord symbol string ("Cmin7", "Ab-", "G7b5"…) with Lua pattern matches into fundamental/quality/seventh/fifth (`parse_chord_symbol` :92), builds pitch-classes for fund/third/fifth/seventh (`get_chord_notes` :108), and if the melody pitch is a chord tone, returns the other chord tones voiced directly below the melody note (`get_midi_number_from_interval` :50). Returns a list of MIDI pitches. **MEDIUM** — straightforward integer math; the chord-symbol pattern matching must be re-done with Zig string scanning. Used by `midi_arranging.soli_close_position`. Highly unit-testable.

---

## midi.lua (195 LOC)

- `midi.listNotes` (midi.lua:7) — `MIDIEditor_GetActive` → `MIDIEditor_GetTake` → `MIDI_CountEvts`; returns (note count, take, editor hwnd). Foundation helper for every other MIDI action. **EASY**
- `midi.PitchCursorToSelectedNote` (midi.lua:14) — Loops notes with `MIDI_GetNote` until the first selected one and writes its pitch to the editor's pitch cursor via `MIDIEditor_SetSetting_int(editor,"active_note_row",pitch)`. **MEDIUM** (one loop)
- `midi.jump_to_next_note` (midi.lua:30) — Loops notes, converts each start ppq with `MIDI_GetProjTimeFromPPQPos`, moves edit cursor (`SetEditCurPos`) to the first note start after `GetCursorPosition`. **MEDIUM**
- `midi.jump_to_prev_note` (midi.lua:42) — Same backwards (iterates notes from last to first, first start before cursor). **MEDIUM**
- `midi.getNotePositionsInEditor` (midi.lua:58) — Builds an array of `{startpos, endpos}` (in PPQ) for all notes via `MIDI_GetNote`. **MEDIUM**
- `midi.getBigNotePositions` (midi.lua:73) — Merges overlapping note spans from `getNotePositionsInEditor` into "big notes" (chord/legato regions) with a single linear pass. Pure arithmetic. **MEDIUM**
- `midi.nextBigNoteEnd` (midi.lua:166) / `midi.nextBigNoteStart` (:170) / `midi.prevBigNoteEnd` (:174) / `midi.prevBigNoteStart` (:178) — Wrappers over locals `moveToNextNote`/`moveToPrevNote` (:104/:126): for each big-note span converts PPQ→project time (`MIDI_GetProjTimeFromPPQPos`), finds first span boundary after/before the edit cursor, `SetEditCurPos`. **MEDIUM** ×4
- `midi.toggleKeySnap` (midi.lua:182) — js_ReaScriptAPI: `MIDIEditor_GetActive` → `JS_Window_FindChildByID(hwnd, 0x4EC)` (key-snap checkbox) → `JS_WindowMessage_Send` BM_GETCHECK / BM_SETCHECK / WM_COMMAND 1260. Straight-line but depends on the js_ReaScriptAPI extension and a hardcoded control id. **EASY** (sequence) — flag: extension dependency, Windows-message hack; verify it's still wanted.
- `midi.LoadScreenSetWhenClosingEditor` (midi.lua:191) — Single `Main_OnCommand(40444)` (load screenset #4 ... actually action 40444 = screenset load). **EASY**

---

## midi_controller.lua (219 LOC)

All three functions exist to wire a "modulation source" FX to a destination FX param via Realearn-style workflow; they form a pair (source must run before destination) and depend on **serpent** (Lua serializer) ExtState handoff and the **ultraschall** API.

- `midi_controller.setModSource` (midi_controller.lua:107) — Finds (or adds via `TrackFX_AddByName` + optional `TrackFX_SetPreset`) an FX by alias on the first selected track (locals `getTrackFxIdxByAlias` :68, `getFXIdxByName` :83); renaming the instance uses `setFXName` (:20) which **parses and rewrites the raw track state chunk** (`GetTrackStateChunk`/`SetTrackStateChunk`, quote-aware token splitting, GUID matching via `TrackFX_GetFXGUID`, `TrackFX_GetIOSize` to pick the field). Then serpent-dumps `{target_name, fxIdx, parmeterIdx}` into `SetExtState("reaper_keys","mod_source",...,persist)`. **HARD** + **SKIP-candidate** — chunk surgery + serpent ExtState; part of a personal MIDI-controller modulation workflow.
- `midi_controller.setModDestination` (midi_controller.lua:166) — Loads the serpent-encoded modulator from `GetExtState`, then uses **ultraschall** (`GetTrackStateChunk_Tracknumber`, `GetFXStateChunk`, `GetParmModTable_FXStateChunk`, `CreateDefaultParmModTable`, `Add/SetParmMod_ParmModTable`, `SetFXStateChunk`) to inject a parameter-modulation/param-link block into the destination FX's state chunk, then `SetTrackStateChunk`. **HARD** + **SKIP-candidate** — entire ultraschall ParmMod chunk machinery would need reimplementation in Zig.
- `midi_controller.devAction` (midi_controller.lua:210) — Hardcoded demo calling the two functions above with "JS: LFO" names. **SKIP** — dev scratch.

---

## movement.lua (231 LOC)

- `move.projectStart` (movement.lua:7) — `SetEditCurPos(0, true, false)`. **EASY**
- `move.projectEnd` (movement.lua:11) — `GetProjectLength(0)` → `SetEditCurPos`. **EASY**
- `move.lastItemEnd` (movement.lua:16) — Last entry of `getBigItemPositionsOnSelectedTracks` → `SetEditCurPos(right)`. **MEDIUM** (helper dependency)
- `move.firstItemStart` (movement.lua:24) — First entry → `SetEditCurPos(left)`. **MEDIUM**
- `move.midi.takeStart` (movement.lua:34) — Active MIDI editor take (`MIDIEditor_GetTake(MIDIEditor_GetActive())`) → its item (`GetMediaItemTake_Item`) → `D_POSITION` → `SetEditCurPos`. **EASY**
- `move.midi.takeEnd` (movement.lua:43) — Same, cursor to `D_POSITION + D_LENGTH`. **EASY**
- `move.prevBigItemStart` (movement.lua:78) / `move.prevItemStart` (:82) — Global `moveToPrevItemStart` (:54): scans the (sorted) item-position list to find the latest item start strictly before the cursor (with containment handling) and `SetEditCurPos`. **MEDIUM** ×2
- `move.nextBigItemStart` (movement.lua:102) / `move.nextItemStart` (:106) — Global `moveToNextItemStart` (:86): earliest item left edge after the cursor → `SetEditCurPos`. **MEDIUM** ×2
- `move.nextBigItemEnd` (movement.lua:126) / `move.nextItemEnd` (:130) — Global `moveToNextItemEnd` (:110): earliest right edge after cursor (2 ms tolerance) → `SetEditCurPos`. **MEDIUM** ×2
- `move.firstTrack` (movement.lua:134) — `GetTrack(0,0)` → `SetOnlyTrackSelected`. **EASY**
- `move.lastTrack` (movement.lua:139) — `GetNumTracks` → `GetTrack(0,n-1)` → `SetOnlyTrackSelected`. **EASY**
- `move.trackWithNumber` (movement.lua:145) — `GetUserInputs` prompt → `GetTrack(0, n-1)` → `SetOnlyTrackSelected`. **EASY**
- `move.firstTrackWithItem` (movement.lua:157) — Loops tracks, first with `GetTrackNumMediaItems > 0` → `SetOnlyTrackSelected`. **MEDIUM** (trivial loop)
- `move.snap` (movement.lua:168) — `GetCursorPosition` → `SnapToGrid(0,pos)` → `SetEditCurPos(snapped, false, false)`. **EASY**
- `move.storeCursorPosition` (movement.lua:174) — Pushes `GetCursorPosition` onto a "cursorPositionStack" persisted as a serpent-serialized Lua table in `SetExtState("reaper_keys","cursorPositionStack",...)` via `utils/reaper_state.lua`. **MEDIUM** — logic is a trivial stack; the only work is replacing serpent with a Zig-side format (e.g. CSV of floats in ExtState). Format change breaks nothing if both store/restore are ported together.
- `move.restoreCursorPosition` (movement.lua:184) — Pops the stack from ExtState, `SetEditCurPos(prevPos)`, writes the shortened stack back. **MEDIUM** (same serialization note)
- `move.jumpToBarNumber` (movement.lua:196) — `GetUserInputs` → `TimeMap2_beatsToTime(0, 0, bar-1)` → `MoveEditCursor(target - GetCursorPosition())`. **EASY**
- `move.moveItemUp` (movement.lua:223) / `move.moveItemDown` (:227) — Local `moveItem` (:206): for each selected item (`CountSelectedMediaItems`/`GetSelectedMediaItem` via utils.cycleSelectedItems), gets its track (`GetMediaItem_Track`), resolves the 0-based index from `IP_TRACKNUMBER` via `utils.getTrackIndex`, then `MoveMediaItemToTrack(item, GetTrack(0, idx±1))` and `SetOnlyTrackSelected` of the destination. No bounds check at first/last track. **MEDIUM** ×2

---

## envelope.lua (309 LOC)

- `envelope.setTimeSelectionToSelectedEnvelopePoints` (envelope.lua:6) — If no time selection exists (`GetSet_LoopTimeRange2` returns 0,0): `GetSelectedEnvelope(0)`, loops `CountEnvelopePoints`/`GetEnvelopePoint`, finds first/last selected point times, sets the time selection to that range. **MEDIUM**
- `envelope.SelectPointsCrossingTimeSelection` (envelope.lua:34) — If a time selection exists, loops all points of the selected envelope and calls `SetEnvelopePoint(..., selected=true)` for points whose time lies within the selection. **MEDIUM**
- `envelope.insertToggleAtTimeSelection` (envelope.lua:159) — Reads the time selection; gets selected envelope; computes the envelope's min/max/center via local `getEnvelopeMinMaxValues` (:114) → `getEnvelopeRange` (:57) which **parses the envelope state chunk** (`GetEnvelopeStateChunk`) for PARMENV ranges and uses `SNM_GetIntConfigVar` (volenvrange/pitchenvrange/tempoenv*) for built-in envelope types, plus `GetEnvelopeScalingMode`/`ScaleToEnvelopeMode` for fader-scaled volume; then `InsertEnvelopePoint` min at selection start and max at selection end (a square on/off toggle). **MEDIUM** — the loops are simple; the chunk sniff is a one-line pattern (first token + 3 numbers) that ports fine, but budget time for the per-envelope-type range table.
- `envelope.deletePoints` (envelope.lua:188) — Gets selected envelope; checks for a time selection; copies points (action 40335); if time selection exists, loops points and (intends to) delete the range — **bug:** it calls `DeleteAtTimeSelection()` with no arguments (:207), so the time-selection branch raises at runtime; otherwise scans for selected points and runs action 40333 (delete selected points) or 40325 (delete all points in envelope lane). Port the *intent*: with time selection → `DeleteEnvelopePointRange(env, start, end)`. **MEDIUM** (fix the bug in the port)
- `envelope.moveEnvelopePointDown` (envelope.lua:230) / `envelope.moveEnvelopePointUp` (:234) / `envelope.setPointMin` (:238) / `envelope.setPointMax` (:242) / `envelope.setPointCenter` (:246) — All call local `pegPoint(val)` (:133): resolves min/max/center via the chunk/config helper above, loops all envelope points and for selected ones calls `SetEnvelopePoint` with value = min/max/center or value ∓3 (note: ±3 in raw envelope units — only sensible for some envelope types). **MEDIUM** ×5 (one shared helper)
- `envelope.autoMode` (envelope.lua:278) — "Show only the last-touched FX param's envelope": `GetLastTouchedFX` → checks the FX's track equals the selected track (`IP_TRACKNUMBER`, `utils.getTrackIndex`); `GetFXEnvelope(track, fx, param, true)` creates/gets the param envelope; then iterates `CountTrackEnvelopes`/`GetTrackEnvelope`, and for every *other* visible envelope (visibility via SWS `BR_EnvAlloc`/`BR_EnvGetProperties`/`BR_EnvFree`) selects it (`SetCursorContext(2, env)`), toggles visibility off (action 40884), and if the envelope has ≤1 point bypasses it by writing `SetEnvelopeStateChunk(env, "BYPASS 1", false)` so empty envelopes get cleared. **HARD** — SWS BR_Env handle alloc/free lifecycle, cursor-context juggling, and a sketchy partial chunk write; also `GetLastTouchedFX` semantics. Unused locals `toggleVisible` (:250) and global `HideEnvelope` (:263) can be dropped.

---

## pasteRhythm.lua (341 LOC)

- `pasteRhythm.pasteRhythm` (pasteRhythm.lua:309) — Applies the *rhythm* of the clipboard MIDI to the selected item's existing pitches. Steps: snapshot takes of the first selected item (`CountSelectedMediaItems`/`GetSelectedMediaItem`/`GetMediaItemNumTakes`/`GetMediaItemTake`/`GetTakeName`, local `getItemTakes` :275); run action 40603 (paste as new take); diff old/new take lists (`findNewTakes` :289) to find the pasted take; extract its rhythm as `{startPPQ,endPPQ}+channels+velocities` groups (`getRhythmNotes` :23, via `MIDI_CountEvts`/`MIDI_GetNote`); switch back to the original take (`SetActiveTake`); then `pasteRhythm` (:231) groups the original take's notes by start position keeping pitches/channels (`getExistingNotes` :80), deletes all original notes (`MIDI_DeleteNote` loop :122), and re-inserts (`MIDI_InsertNote` :217) one note per original pitch at each rhythm position, choosing the nearest-preceding original chord's pitches/channels (`getNearestSetOfNotePitches`/`...Channels` :129/:165) and carrying velocities forward; finally deletes the temp takes (action 40129 per take) and restores the active take. **HARD** — multi-stage take diffing around a clipboard action, several nested grouping structures, and order-dependent ppq matching; portable but the most intricate single action in the set.

---

## midi_arranging.lua (377 LOC)

Depends on midi.lua, kawa.lua, harmonizer.lua, and Scythe's `Table`/`String` vendor helpers (forEach/filter/find/map, String.split — all replaceable with Zig std).

- `midi_arranging.getNotesTags` (midi_arranging.lua:130) — Reads all notes (local `getNotes` :71 over `MIDI_GetNote`) and all text/sysex events (local `getSysexEvts` :105 over `MIDI_CountEvts`+`MIDI_GetTextSysexEvt`); for each notation event whose msg contains `NOTE ... text ...`, string-parses channel/pitch/ppq plus space-separated tag words, matches the corresponding note by (startppqpos, pitch, chan), and buckets notes into a `tag → Note[]` map (notes can carry multiple tags). Returns (tags, take). **HARD** — REAPER notation-event text parsing plus multi-key matching; needs a real tokenizer in Zig and a hash map of tag→list.
- `midi_arranging.assignOneChannelPerTag` (midi_arranging.lua:275) — Calls `getNotesTags`, then local `assignOneChannelPerTag` (:183): iterates tags in (Lua hash) order, assigning incrementing MIDI channels; notes with multiple tags already consumed by a previous tag get *copied* (`MIDI_InsertNote` + `MIDI_InsertTextSysexEvt` of a new notation event) instead of moved; otherwise `MIDI_SetNote` rewrites the channel; ends with `MIDI_Sort`. Author comment says it "needs re-work" (channels mis-assigned, notes accidentally removed). **HARD** — known-buggy, order-dependent on Lua `pairs`, sysex round-tripping.
- `midi_arranging.assignOneTrackPerTag` (midi_arranging.lua:280) — For each tag: finds the take's track (`GetMediaItemTake_Track`), computes its index (`IP_TRACKNUMBER` + `utils.getTrackIndex`), `InsertTrackAtIndex` below it, renames the new track to the tag (`GetSetMediaTrackInfo_String`), creates a MIDI item matching the source item's position/length (`CreateNewMIDIItemInProj` using `GetMediaItemTake_Item` + `D_POSITION`/`D_LENGTH`), and copies the tag's notes into it (`MIDI_InsertNote` loop + `MIDI_Sort`). **HARD** (because it sits on getNotesTags; the body itself is medium)
- `midi_arranging.soli_close_position` (midi_arranging.lua:288) — Close-position soli harmonization: takes top notes from `kawa.get_top_notes()`, pulls chord symbols from take markers (`getSysexEvts` filtered to type 6/Marker), determines each chord's ppq span (next marker or `BR_GetMidiSourceLenPPQ`), and for each top note inside a chord span calls `harmonizer.harmonize(pitch, chord_symbol)` and inserts the returned pitches (`MIDI_InsertNote`, with QN↔PPQ conversion via `MIDI_GetPPQPosFromProjQN`). **HARD** — composition of three modules (kawa chord extraction, harmonizer parsing, sysex markers), but each piece is individually portable.
- `midi_arranging.insert_chord` (midi_arranging.lua:334) — Converts edit cursor to ppq (`MIDI_GetPPQPosFromProjTime`), prompts for a chord symbol (`GetUserInputs`), deletes any existing marker/notation events at that ppq (`MIDI_DeleteTextSysexEvt`), and inserts both a Marker event (type 6) with the chord symbol and a notation event (type 15, `"TRAC custom <symbol>"`) via `MIDI_InsertTextSysexEvt`. **MEDIUM**

---

## kawa.lua (581 LOC)

Internal engine: `createMIDIFunc3` (:26) is a re-minified port of kawa's MIDI helper — builds an object holding the active editor/take (`MIDIEditor_GetActive`/`MIDIEditor_GetTake`), pre-cleans with ME commands 40815 (delete <1/256 notes) and 40659 (correct overlapping) under `PreventUIRefresh`, then reads all notes via `MIDI_GetNote` converting PPQ→QN (`MIDI_GetProjQNFromPPQPos`), capping at 1000 notes (`ShowMessageBox` on overflow). The public functions only use `getMidiNotes` + `detectTargetNote` ("selected notes, else all notes") plus `get_chords` (:229, groups notes by identical startQn) and `sort_chords` (:273, pitch-descending within each chord). In Zig: one `collectNotes()` + one `groupChords()` helper replaces the whole object. Note `get_chords` keys a Lua table by fractional startQn — use a float-keyed hashmap or sort+group.

Selection actions (each: build chords, `MIDIEditor_OnCommand(editor, 40214)` to unselect all, then re-select target notes via `MIDI_SetNote` with QN→PPQ conversion `MIDI_GetPPQPosFromProjQN`; `UpdateArrange`):
- `kawa.select_bottom_note` (kawa.lua:391) — selects lowest pitch of every chord. **MEDIUM**
- `kawa.select_top_note` (kawa.lua:398) — highest pitch of every chord. **MEDIUM**
- `kawa.select_middle_note` (kawa.lua:405) — all but top and bottom. **MEDIUM**
- `kawa.select_all_but_top` (kawa.lua:417) — **MEDIUM**
- `kawa.select_all_but_bottom` (kawa.lua:428) — **MEDIUM**
- `kawa.select_all_but_middle` (kawa.lua:441) — keeps top+bottom only. **MEDIUM**

Voicing transforms (build chords, then `MIDI_SetNote` rewrite with pitch±12 via `transpose_notes` :455, or `MIDI_InsertNote` copies):
- `kawa.get_top_notes` (kawa.lua:311) — public helper returning the top note of each chord (used by soli_close_position). **MEDIUM**
- `kawa.drop2_4` (kawa.lua:463) — transposes the 2nd and 4th notes from the top down an octave (drop-2&4 voicing). **MEDIUM**
- `kawa.drop_3` (kawa.lua:473) — 3rd-from-top down an octave. **MEDIUM**
- `kawa.drop_2` (kawa.lua:483) — 2nd-from-top down an octave. **MEDIUM**
- `kawa.doubleTopNotesUp` (kawa.lua:494) — inserts a copy of each chord's top note +12. **MEDIUM**
- `kawa.doubleBottomNotesDown` (kawa.lua:507) — copy of bottom note −12. **MEDIUM**
- `kawa.doubleOctUp` (:533) / `doubleOctDown` (:537) / `doubleSeventhUp` (:541) / `doubleSeventhDown` (:545) / `doubleSixthUp` (:549) / `doubleSixthDown` (:553) / `doubleFifthUp` (:557) / `doubleFifthDown` (:561) / `doubleFourthUp` (:565) / `doubleFourthDown` (:569) / `doubleThirdUp` (:573) / `doubleThirdDown` (:577) — twelve wrappers over local `double_notes(semitones)` (:520): inserts a transposed copy (`MIDI_InsertNote`) of every target (selected-else-all) note at +12/−12/+10/−10/+9/−9/+7/−7/+5/−5/+4/−4 semitones. **MEDIUM** ×12 (one parametrized Zig function + 12 bindings)

---

## MFT.lua (614 LOC)

- `MFT.create_fx_map` (MFT.lua:604) — Generates a Realearn "MainCompartment" mapping for the MIDI Fighter Twister (16 encoders): reads the selected track's open FX chain (`TrackFX_GetChainVisible`, SWS `CF_GetTrackFXChain`/`CF_EnumSelectedFX`), enumerates every param of every selected FX (`TrackFX_GetFXName`/`TrackFX_GetNumParams`/`TrackFX_GetParamName`/`TrackFX_GetParam`), builds nested Lua mapping tables (banks, pagers, dummy fillers, LED-color MIDI feedback strings, Bypass→ToggleButton special-casing) via `Main_compartment_mapper.Map_selected_fx_in_visible_chain` (:360) and its `Bankk` page allocator (:236), serializes the whole structure with **serpent** and puts it on the system clipboard (`CF_SetClipboard`) for pasting into Realearn. **HARD**, **SKIP** — MIDI Fighter Twister / Realearn hardware-specific configuration generator built on deep nested-table serialization; out of scope for a Zig action port (and the reavim-ext project already has its own controller/mapping system).

---

# Summary

## Per-file counts (public/bound functions only)

| File | Functions | EASY | MEDIUM | HARD | SKIP |
|---|---|---|---|---|---|
| custom_actions.lua | 5 | 5 | – | – | – |
| selection.lua | 5 | 3 | 2 | – | – |
| fx.lua | 1 | – | – | 1 | – |
| tracks.lua | 4 | 3 | 1 | – | – |
| Mapping_types.lua | 0 | – | – | – | – (types only) |
| routing.lua | 2 | – | 2 | – | – |
| dev.lua | 3 | – | – | – | 3 |
| drums.lua | 6 | – | 5 | – | 1 |
| items.lua | 8 | 6 | 2 | – | – |
| harmonizer.lua | 1 | – | 1 | – | – |
| midi.lua | 12 | 3 | 9 | – | – |
| midi_controller.lua | 3 | – | – | – | 3 (2 of them HARD if ever ported) |
| movement.lua | 22 | 9 | 13 | – | – |
| envelope.lua | 10 | – | 9 | 1 | – |
| pasteRhythm.lua | 1 | – | – | 1 | – |
| midi_arranging.lua | 5 | – | 1 | 4 | – |
| kawa.lua | 24 | – | 24 | – | – |
| MFT.lua | 1 | – | – | – | 1 |
| **Total** | **113** | **29** | **69** | **7** | **8** |

SKIP list with reasons:
- `dev.fxDevices`, `dev.repl`, `dev.devAction` — launchers for user-local scripts via hardcoded `_RS...` command ids / dev scratchpad.
- `drums.quantizeTool` — launches a user-local quantize script by command id.
- `midi_controller.setModSource` / `setModDestination` / `devAction` — personal modulation-routing workflow built on serpent ExtState handoff + ultraschall chunk APIs.
- `MFT.create_fx_map` — MIDI Fighter Twister / Realearn mapping generator (Mapping_types.lua exists only for this).

## Shared helpers to port first

From `custom_actions/utils.lua` (390 LOC), in dependency order of how many actions need them:

1. **`utils.getSelectedTracks`** (utils.lua:171) — `CountSelectedTracks` + `GetSelectedTrack` loop. Used directly and via every `cycle*` helper. Port first.
2. **`utils.cycleSelectedTracks`** (:321), **`utils.cycleSelectedItems`** (:312, `CountSelectedMediaItems`/`GetSelectedMediaItem`), **`utils.cycleSelectedItemsInSelectedTracks`** (:299), **`utils.getSelectedItemsInTrack`** (:256, `CountTrackMediaItems`/`GetTrackMediaItem`/`IsMediaItemSelected`) — the iteration backbone for tracks.lua, drums.lua, items.lua, movement.lua. In Zig these become iterators or for-loops; no callbacks needed.
3. **`utils.getItemPositionsOnSelectedTracks`** (:67) + **`getItemPositionsOnTracks`** (:42) + **`mergeItemPositionsLists`** (:9) — builds a time-sorted `{left,right}` list across selected tracks (k-way merge of per-track lists, each from `GetTrackNumMediaItems`/`GetTrackMediaItem` + `D_POSITION`/`D_LENGTH`). Used by selection.innerItem and all 8 movement item-jump actions.
4. **`utils.getBigItemPositionsOnSelectedTracks`** (:78) — merges overlapping spans from (3) into "big items". Same consumers. (midi.lua has the PPQ-domain twin `getBigNotePositions` — consider one generic span-merge in Zig.)
5. **`utils.getTrackIndex(tracknumber)`** (:331) — maps `IP_TRACKNUMBER` → 0-based index by scanning `CountTracks`/`GetTrack`. Used by movement.moveItem, envelope.autoMode, midi_arranging.assignOneTrackPerTag, midi_controller. (In Zig this is just `tracknumber - 1` cast to int — the Lua scan exists only because the value comes back as a float; can be a one-liner.)
6. **`utils.selectRegion(id)`** (:107) — `EnumProjectMarkers` + `GetSet_LoopTimeRange`. selection.innerRegion.
7. **`utils.nudgeItemVolume(item, db)`** (:277) — `D_VOL` × `10^(0.05*db)` + `UpdateItemInProject`; same formula as tracks' `nudgeTrackVolumeAmount`. drums.lua. Make one shared dB-scale helper.
8. **`utils.CopyMediaItemToTrack(item, track, pos)`** (:287) — `GetItemStateChunk` → strip `{GUID}`s with gsub → `AddMediaItemToTrack` + `SetItemStateChunk` + `D_POSITION`, wrapped in `PreventUIRefresh`. Needed by drums flam/ras. This is the one genuinely chunk-string helper the MEDIUM actions depend on; budget for chunk-size handling (use `GetItemStateChunk` with a growable buffer in Zig).
9. **`midi.listNotes`** (midi.lua:7) and a `collectNotes(take) -> []Note` reader (`MIDI_GetNote` loop + PPQ/QN conversion) — backbone of midi.lua, kawa.lua, midi_arranging.lua, pasteRhythm.lua. Port once as a single notes snapshot API; kawa's `createMIDIFunc3` and midi_arranging's `getNotes` are both just this.
10. **Chord grouping** (kawa `get_chords`/`sort_chords`) — group notes by startQn, sort by pitch descending. Powers all 24 kawa actions + soli_close_position.
11. **`getSysexEvts(take)`** (midi_arranging.lua:105) — `MIDI_GetTextSysexEvt` snapshot; needed by midi_arranging (and insert_chord).
12. **Save/restore selection + cursor** — the Lua code leans on SWS `_SWS_SAVESEL`/`_SWS_RESTORESEL` and Xenakios `_XENAKIOS_DOSTORECURPOS`/`_XENAKIOS_DORECALLCURPOS` command ids (fx.lua, items.lua). Either keep calling those via `NamedCommandLookup`, or implement native save/restore (snapshot selected-track GUIDs + `GetCursorPosition`) — recommended for the Zig port to drop the SWS dependency where easy.
13. **ExtState table storage** (`utils/reaper_state.lua` get/set, namespace `"reaper_keys"`) — serpent-serialized tables in `Get/SetExtState`. Only movement's cursor-position stack needs it among the actions; replace with a simple delimited-floats format under the same or a new namespace.
14. **`getUserGridDivisionInput`** (custom_actions.lua:29) — `GetUserInputs` + "a/b" fraction parse; shared by both grid-division actions.
15. **Envelope range helper** (envelope.lua:57 `getEnvelopeRange` + :114 `getEnvelopeMinMaxValues`) — chunk-sniff envelope type, per-type min/max/center table, `SNM_GetIntConfigVar` for vol/pitch/tempo ranges, `ScaleToEnvelopeMode` for fader scaling. Prerequisite for 6 of the 10 envelope actions.
16. Misc: `utils.toHex`/`utils.TableConcat`/`utils.uuid` (:364/:370/:381) are only used by MFT.lua/midi_controller — skip with them. `utils.getMatchedTrack`, `setTrackSelection`, `setCurrentTrack`, `getTrackPosition`, `scrollToPosition`, `unselectAllButLastTouchedTrack`, `getSelectedTrackIndices`, `unselectTracks` are used by other reavim internals (state machine / marks), not by these action files — port only if those subsystems come over.

## Pre-existing bugs noticed (don't replicate)

- `envelope.deletePoints` (envelope.lua:207) calls `DeleteAtTimeSelection()` with zero arguments — the time-selection branch errors at runtime; reimplement as `DeleteEnvelopePointRange(env, start, end)`.
- `utils.getItemPositionsOnSelectedTracks` (utils.lua:70) loop runs `i = 0 .. CountSelectedTracks()` writing `selected_tracks[i] = GetSelectedTrack(0, i-1)` — works only by accident of Lua 1-based `#`; index cleanly in Zig.
- `utils.getTrackIdx` (utils.lua:349) iterates `GetTrack(0, 1..count)`, skipping track 0 — off-by-one; unused by the actions, drop it.
- `movement.moveItemUp/Down` has no bounds check at the first/last track (`GetTrack` returns nil → `MoveMediaItemToTrack(item, nil)`).
- `dev.getAllFxChainWindows` (dev.lua:29) references an undefined `hwnd` — dead/incomplete code.
- `midi_arranging.assignOneChannelPerTag` is flagged by the author as needing rework (channel assignment depends on Lua `pairs` hash order).
