# reavim — Bindings Inventory & Composition Grammar (Zig port reference)

Source: `/tank/projects/perken-reaper-scripts/reavim` (Lua). Generated 2026-06-11 by mechanically
flattening the definition tables; every binding in the source files is listed.

## How definitions are loaded (replacement vs merge)

From `internal/utils/definitions.lua` and `definitions/config.lua`:

- `defaults/` and `extended_defaults/` are two **complete, independent binding sets**. Exactly one
  directory is selected wholesale by `config.use_extended_defaults` (currently `true`, so
  `extended_defaults` is active). They are **never merged with each other** — it is replacement,
  not merge. (`extended_defaults` is essentially a superset/evolution of `defaults` with some
  rebinds, e.g. `RecordMacro` is `,` in defaults but `q` in extended.)
- The chosen set is then **merged with user definitions** (`definitions/bindings.lua`, currently
  all empty tables) via `concatEntryTables`/`concatEntries`: per context (`global`/`main`/`midi`),
  per action_type, user entries override defaults key-by-key; a user value of `""` deletes a
  binding; if both sides have a **folder with the same label** at the same key, the folder
  contents merge recursively, otherwise the user value replaces the whole folder.
- At runtime, the possible entries for a keypress context are
  `definitions.getPossibleEntries(context)` = empty table merged with `global`, then merged with
  the context table (`main` or `midi`) on top — so **context-specific entries shadow global ones**
  on key conflicts, with the same recursive folder-merge rule.
- Folder values have the shape `{ "+label", { ...children... } }`. A child binding's effective
  key sequence is the folder key concatenated with the child key (flattened below). Folder labels
  ("+something") are display-only strings for the completion/feedback window.
- Action names map to action values in `definitions/defaults/actions.lua` overlaid by user
  `definitions/actions.lua` (`internal/utils/get_action.lua` — user actions override by name).

Key tokenization (`command/utils.splitKeysIntoTable`): a key sequence is split into units matching,
in order, `^(<[^<>]+>)`, `^(<[^<>]+[<>]>)` (special keys like `<C-d>`, `<M-->`, `<SPC>`, `<TAB>`),
else single characters. Multi-char plain keys like `gg`, `dd`, `tt`, `zp` are simply two units that
happen to be bound as one entry key.

# Part 1 — Bindings

Every `(context, action_type)` group below lists folder labels first (flattened folder prefix +
label), then every binding as flattened `keyseq` -> `ActionName`. Both binding sets are listed in
full; remember they are alternatives selected by `use_extended_defaults`, and `global` entries are
merged underneath both `main` and `midi` at runtime.

## Binding set: defaults

### main / `command`

Folders:

- folder `<SPC>` label "leader commands"
- folder `<SPC>D` label "dev"
- folder `<SPC>g` label "grid"
- folder `<SPC>o` label "options"
- folder `<SPC>m` label "midi"
- folder `<SPC>r` label "recording"
- folder `<SPC>r,` label "options"
- folder `<SPC>a` label "automation"
- folder `<SPC>i` label "items"
- folder `<SPC>is` label "stretch"
- folder `<SPC>ix` label "explode takes"
- folder `<SPC>i#` label "fade"
- folder `<SPC>it` label "transients"
- folder `<SPC>ie` label "envelopes"
- folder `<SPC>if` label "fx"
- folder `<SPC>iR` label "rename"
- folder `<SPC>ib` label "timebase"
- folder `<SPC>t` label "track"
- folder `<SPC>tx` label "routing"
- folder `<SPC>tF` label "freeze"
- folder `<SPC>e` label "envelopes"
- folder `<SPC>ep` label "point shapes"
- folder `<SPC>ev` label "point value"
- folder `<SPC>es` label "selected"
- folder `<SPC>f` label "fx"
- folder `<SPC>fi` label "input"
- folder `<SPC>fc` label "show"
- folder `<SPC>G` label "global"
- folder `<SPC>Gs` label "show/hide"
- folder `<SPC>Gf` label "fx"
- folder `<SPC>Ge` label "envelope"
- folder `<SPC>Gt` label "track"
- folder `<SPC>Ga` label "automation"
- folder `<SPC>p` label "project"
- folder `<SPC>pr` label "render"
- folder `<SPC>d` label "drums"

Bindings:

- `<ESC>` -> `Reset`
- `<M-n>` -> `ShowNextFx`
- `<M-N>` -> `ShowPrevFx`
- `<M-f>` -> `ToggleShowFx`
- `<M-F>` -> `CloseFx`
- `<M-i>` -> `InsertEnvelopePoint`
- `zp` -> `ZoomProject`
- `D` -> `CutSelectedItems`
- `Y` -> `CopySelectedItems`
- `V` -> `SetModeVisualTrack`
- `<C-w>` -> `NextEnvelope`
- `<C-W>` -> `PrevEnvelope`
- `<M-j>` -> `NextEnvelope`
- `<M-k>` -> `PrevEnvelope`
- `<C-+>` -> `ZoomInVert`
- `<C-->` -> `ZoomOutVert`
- `+` -> `ZoomInHoriz`
- `-` -> `ZoomOutHoriz`
- `;` -> `MoveItemToEditCursor`
- `dd` -> `CutTrack`
- `aa` -> `ArmTracks`
- `O` -> `EnterTrackAbove`
- `o` -> `EnterTrackBelow`
- `p` -> `Paste`
- `<C-v>` -> `Paste`
- `yy` -> `CopyTrack`
- `zz` -> `ScrollToSelectedTracks`
- `%` -> `SplitItemsAtEditCursor`
- `~` -> `MarkedTracks`
- `<C-j>` -> `NudgeTrackVolumeDownBy1Tenth`
- `<C-k>` -> `NudgeTrackVolumeUpBy1Tenth`
- `<C-J>` -> `NudgeTrackVolumeDownBy1`
- `<C-K>` -> `NudgeTrackVolumeUpBy1`
- `<CM-j>` -> `ShiftEnvelopePointsDownATinyBit`
- `<CM-k>` -> `ShiftEnvelopePointsUpATinyBit`
- `<CM-J>` -> `ShiftEnvelopePointsDown`
- `<CM-K>` -> `ShiftEnvelopePointsUp`
- `<M-S>` -> `SelectItemsUnderEditCursor`
- `'` -> `MarkedTracks`
- `<SPC><SPC>` -> `ShowActionList`
- `<SPC>Df` -> `FxDevices`
- `<SPC>Dr` -> `Repl`
- `<SPC>b` -> `MediaExplorer`
- `<SPC>gd` -> `SetGridDivision`
- `<SPC>gs` -> `ToggleSnap`
- `<SPC>op` -> `TogglePlaybackPreroll`
- `<SPC>or` -> `ToggleRecordingPreroll`
- `<SPC>oz` -> `TogglePlaybackAutoScroll`
- `<SPC>ov` -> `ToggleLoopSelectionFollowsTimeSelection`
- `<SPC>os` -> `ToggleSnap`
- `<SPC>om` -> `ToggleMetronome`
- `<SPC>ot` -> `ToggleStopAtEndOfTimeSelectionIfNoRepeat`
- `<SPC>ox` -> `ToggleAutoCrossfade`
- `<SPC>oe` -> `ToggleEnvelopePointsMoveWithItems`
- `<SPC>oc` -> `CycleRippleEditMode`
- `<SPC>of` -> `ResetFeedbackWindow`
- `<SPC>mg` -> `SetMidiGridDivision`
- `<SPC>mq` -> `Quantize`
- `<SPC>ra` -> `ArmTracks`
- `<SPC>ro` -> `SetRecordMidiOutput`
- `<SPC>rd` -> `SetRecordMidiOverdub`
- `<SPC>rt` -> `SetRecordMidiTouchReplace`
- `<SPC>rR` -> `SetRecordMidiReplace`
- `<SPC>rv` -> `SetRecordMonitorOnly`
- `<SPC>rr` -> `SetRecordInput`
- `<SPC>r,n` -> `SetRecordModeNormal`
- `<SPC>r,s` -> `SetRecordModeItemSelectionAutoPunch`
- `<SPC>r,v` -> `SetRecordModeTimeSelectionAutoPunch`
- `<SPC>r,p` -> `ToggleRecordingPreroll`
- `<SPC>r,z` -> `ToggleRecordingAutoScroll`
- `<SPC>r,t` -> `ToggleRecordToTapeMode`
- `<SPC>ar` -> `SetAutomationModeTrimRead`
- `<SPC>aR` -> `SetAutomationModeRead`
- `<SPC>al` -> `SetAutomationModeLatch`
- `<SPC>ag` -> `SetAutomationModeLatchAndArm`
- `<SPC>ap` -> `SetAutomationModeLatchPreview`
- `<SPC>at` -> `SetAutomationModeTouch`
- `<SPC>aw` -> `SetAutomationModeWrite`
- `<SPC>iP` -> `PasteItemBeforeCursor`
- `<SPC>ij` -> `NextTake`
- `<SPC>ik` -> `PrevTake`
- `<SPC>il` -> `LoopItem`
- `<SPC>iM` -> `ToggleMuteItem`
- `<SPC>id` -> `DeleteActiveTake`
- `<SPC>ic` -> `CropToActiveTake`
- `<SPC>io` -> `OpenInMidiEditor`
- `<SPC>in` -> `ItemNormalize`
- `<SPC>ig` -> `GlueItemsIgnoringTimeSelection`
- `<SPC>iF` -> `Set2msFades`
- `<SPC>isa` -> `AdjustTransientDetection`
- `<SPC>isc` -> `ClearTransientsAndStretchMarkers`
- `<SPC>isd` -> `DeleteStretchMarker`
- `<SPC>isi` -> `InsertStretchMarker`
- `<SPC>iss` -> `SplitItemAtTransients`
- `<SPC>ist` -> `CalculateTransientGuides`
- `<SPC>isD` -> `DynamicSplit`
- `<SPC>ixp` -> `ExplodeTakesInPlace`
- `<SPC>ixo` -> `ExplodeTakesInOrder`
- `<SPC>ixa` -> `ExplodeTakesInAcrossTracks`
- `<SPC>i#i` -> `CycleItemFadeInShape`
- `<SPC>i#o` -> `CycleItemFadeOutShape`
- `<SPC>ies` -> `ViewTakeEnvelopes`
- `<SPC>iem` -> `ToggleTakeMuteEnvelope`
- `<SPC>iep` -> `ToggleTakePanEnvelope`
- `<SPC>ieP` -> `ToggleTakePitchEnvelope`
- `<SPC>iev` -> `ToggleTakeVolumeEnvelope`
- `<SPC>ifa` -> `ApplyFxToItem`
- `<SPC>ifp` -> `PasteItemFxChain`
- `<SPC>ifd` -> `CutItemFxChain`
- `<SPC>ify` -> `CopyItemFxChain`
- `<SPC>ifc` -> `ToggleShowTakeFxChain`
- `<SPC>ifb` -> `ToggleTakeFxBypass`
- `<SPC>ir` -> `ReverseItems`
- `<SPC>iRs` -> `RenameTakeSourceFile`
- `<SPC>iRt` -> `RenameTake`
- `<SPC>iRr` -> `RenameTakeAndSourceFile`
- `<SPC>iRa` -> `AutoRenameTake`
- `<SPC>ibt` -> `SetItemsTimebaseToTime`
- `<SPC>ibb` -> `SetItemsTimebaseToBeatsPos`
- `<SPC>ibr` -> `SetItemsTimebaseToBeatsPosLengthAndRate`
- `<SPC>tv` -> `RenameTrackToVstiPresetName`
- `<SPC>tR` -> `RenderTrack`
- `<SPC>tr` -> `RenameTrack`
- `<SPC>tm` -> `CycleRecordMonitor`
- `<SPC>tf` -> `CycleFolderState`
- `<SPC>ty` -> `SaveTrackAsTemplate`
- `<SPC>tp` -> `InsertTrackFromTemplate`
- `<SPC>t1` -> `InsertTrackFromTemplateSlot1`
- `<SPC>t2` -> `InsertTrackFromTemplateSlot2`
- `<SPC>t3` -> `InsertTrackFromTemplateSlot3`
- `<SPC>t4` -> `InsertTrackFromTemplateSlot4`
- `<SPC>tc` -> `InsertClickTrack`
- `<SPC>t+` -> `TrackVolumeUp3`
- `<SPC>t-` -> `TrackVolumeDown3`
- `<SPC>txp` -> `TrackToggleSendToParent`
- `<SPC>txs` -> `ToggleShowTrackRouting`
- `<SPC>tFf` -> `FreezeTrack`
- `<SPC>tFu` -> `UnfreezeTrack`
- `<SPC>tFs` -> `ShowTrackFreezeDetails`
- `<SPC>epb` -> `BezierPointShape`
- `<SPC>epe` -> `FastEndPointShape`
- `<SPC>eps` -> `FastStartPointShape`
- `<SPC>epl` -> `LinearPointShape`
- `<SPC>epE` -> `SlowStartEndPointShape`
- `<SPC>epS` -> `SquarePointShape`
- `<SPC>ei` -> `InsertEnvelopePoint`
- `<SPC>ev-` -> `MoveEnvelopePointDown`
- `<SPC>ev+` -> `MoveEnvelopePointUp`
- `<SPC>evm` -> `SetPointMin`
- `<SPC>evM` -> `SetPointMax`
- `<SPC>evc` -> `SetPointCenter`
- `<SPC>et` -> `ToggleShowAllEnvelope`
- `<SPC>ea` -> `ToggleArmAllEnvelopes`
- `<SPC>eA` -> `UnarmAllEnvelopes`
- `<SPC>ed` -> `ClearAllEnvelope`
- `<SPC>eV` -> `ToggleVolumeEnvelope`
- `<SPC>eP` -> `TogglePanEnvelope`
- `<SPC>ew` -> `SelectWidthEnvelope`
- `<SPC>el` -> `ShowEnvelopeLastTouchedFxParam`
- `<SPC>esd` -> `ClearEnvelope`
- `<SPC>esa` -> `ToggleArmEnvelope`
- `<SPC>est` -> `ToggleShowSelectedEnvelope`
- `<SPC>fa` -> `AddFx`
- `<SPC>fs` -> `ToggleShowFxChain`
- `<SPC>fd` -> `CutFxChain`
- `<SPC>fy` -> `CopyFxChain`
- `<SPC>fp` -> `PasteFxChain`
- `<SPC>fb` -> `ToggleFxBypass`
- `<SPC>fm` -> `ModulateLastTouchedFxParam`
- `<SPC>fis` -> `ToggleShowInputFxChain`
- `<SPC>fid` -> `CutInputFxChain`
- `<SPC>fc1` -> `ToggleShowFx1`
- `<SPC>fc2` -> `ToggleShowFx2`
- `<SPC>fc3` -> `ToggleShowFx3`
- `<SPC>fc4` -> `ToggleShowFx4`
- `<SPC>fc5` -> `ToggleShowFx5`
- `<SPC>fc6` -> `ToggleShowFx6`
- `<SPC>fc7` -> `ToggleShowFx7`
- `<SPC>fc8` -> `ToggleShowFx8`
- `<SPC>Gq` -> `QuitReaper`
- `<SPC>Gg` -> `SetGridDivision`
- `<SPC>Gr` -> `ResetControlDevices`
- `<SPC>G,` -> `ShowPreferences`
- `<SPC>GS` -> `UnsoloAllItems`
- `<SPC>Gsx` -> `RoutingMatrix`
- `<SPC>Gsw` -> `ToggleShowWiringDiagram`
- `<SPC>Gst` -> `ToggleShowTrackManager`
- `<SPC>Gsm` -> `MasterTrack`
- `<SPC>Gsp` -> `RegionPlaylist`
- `<SPC>Gsr` -> `ToggleShowRegionMarkerManager`
- `<SPC>Gfx` -> `CloseAllFxChainsAndWindows`
- `<SPC>Gfc` -> `ViewFxChainMaster`
- `<SPC>Get` -> `ToggleShowAllEnvelopeGlobal`
- `<SPC>Gtt` -> `ToggleAutomaticRecordArm`
- `<SPC>Gta` -> `ClearAllRecordArm`
- `<SPC>Gts` -> `UnsoloAllTracks`
- `<SPC>Gtm` -> `UnmuteAllTracks`
- `<SPC>Gar` -> `SetGlobalAutomationModeTrimRead`
- `<SPC>Gal` -> `SetGlobalAutomationModeLatch`
- `<SPC>Gap` -> `SetGlobalAutomationModeLatchPreview`
- `<SPC>Gat` -> `SetGlobalAutomationModeTouch`
- `<SPC>GaR` -> `SetGlobalAutomationModeRead`
- `<SPC>Gaw` -> `SetGlobalAutomationModeWrite`
- `<SPC>GaS` -> `SetGlobalAutomationModeOff`
- `<SPC>pB` -> `BuildBusses`
- `<SPC>pm` -> `RoutingMatrix`
- `<SPC>pR` -> `RouteToBusses`
- `<SPC>pb` -> `ProjectBay`
- `<SPC>p,` -> `ShowProjectSettings`
- `<SPC>pn` -> `NextTab`
- `<SPC>pp` -> `PrevTab`
- `<SPC>ps` -> `SaveProject`
- `<SPC>po` -> `OpenProject`
- `<SPC>pc` -> `NewProjectTab`
- `<SPC>px` -> `CloseProject`
- `<SPC>pC` -> `CleanProjectDirectory`
- `<SPC>pS` -> `SaveProjectWithNewVersion`
- `<SPC>pr.` -> `RenderProjectWithLastSetting`
- `<SPC>prr` -> `RenderProject`
- `<SPC>df` -> `Flam`
- `<SPC>d3` -> `Ras3`
- `<SPC>d5` -> `Ras5`
- `<SPC>dc` -> `Crescendo`
- `<SPC>dd` -> `Decrescendo`
- `<SPC>dD` -> `DynamicSplit`
- `<SPC>dq` -> `QuantizeTool`

### main / `track_motion`

Bindings:

- `G` -> `LastTrack`
- `gg` -> `FirstTrack`
- `J` -> `NextFolderNear`
- `K` -> `PrevFolderNear`
- `/` -> `MatchedTrackForward`
- `?` -> `MatchedTrackBackward`
- `n` -> `NextTrackMatchForward`
- `N` -> `NextTrackMatchBackward`
- `j` -> `NextTrack`
- `:` -> `TrackWithNumber`
- `<down>` -> `NextTrack`
- `k` -> `PrevTrack`
- `<up>` -> `PrevTrack`
- `<C-d>` -> `Next5Track`
- `<C-u>` -> `Prev5Track`
- `t` -> `CurrentTrack`

### main / `track_operator`

Folders:

- folder `"` label "snapshots"

Bindings:

- `"s` -> `SaveTracksToCurrentSnapshot`
- `"c` -> `CreateNewSnapshotWithTracks`
- `"d` -> `DeleteTracksFromCurrentSnapshot`
- `z` -> `ZoomTrackSelection`
- `<TAB>` -> `MakeFolder`
- `d` -> `CutTrack`
- `a` -> `ArmTracks`
- `s` -> `SelectTracks`
- `S` -> `ToggleSolo`
- `M` -> `ToggleMute`
- `y` -> `CopyTrack`
- `<M-C>` -> `ColorTrackGradient`
- `<M-c>` -> `ColorTrack`

### main / `track_selector`

Folders:

- folder `i` label "inner"

Bindings:

- `'` -> `MarkedTracks`
- `F` -> `FolderParent`
- `ic` -> `InnerFolder`
- `if` -> `InnerFolderAndParent`
- `ig` -> `AllTracks`

### main / `visual_track_command`

Bindings:

- `V` -> `SetModeNormal`
- `<C-h>` -> `NudgeTrackPanLeft`
- `<C-l>` -> `NudgeTrackPanRight`
- `<C-H>` -> `NudgeTrackPanLeft10Times`
- `<C-L>` -> `NudgeTrackPanRight10Times`
- `<M-i>` -> `InsertEnvelopePointsAtSelection`

### main / `timeline_motion`

Bindings:

- `0` -> `ProjectStart`
- `<TAB>` -> `NextTransientInItems`
- `<S-TAB>` -> `PrevTransientInItems`
- `<S-left>` -> `PrevMeasure`
- `<S-right>` -> `NextMeasure`
- `B` -> `PrevBigItemStart`
- `E` -> `NextBigItemEnd`
- `W` -> `NextBigItemStart`
- `b` -> `PrevItemStart`
- `e` -> `NextItemEnd`
- `w` -> `NextItemStart`
- `$` -> `LastItemEnd`
- `<S-down>` -> `PitchItemDownSemi`
- `<S-up>` -> `PitchItemUpSemi`
- `<CS-down>` -> `PitchItemDownOct`
- `<CS-up>` -> `PitchItemUpOct`

### main / `timeline_operator`

Folders:

- folder `c` label "change/fit"

Bindings:

- `s` -> `SelectItems`
- `<M-p>` -> `CopyAndFitByLooping`
- `<M-s>` -> `SelectEnvelopePoints`
- `d` -> `CutItems`
- `y` -> `CopyItems`
- `<C-c>` -> `CopyItems`
- `<M-d>` -> `CutEnvelopePoints`
- `<M-y>` -> `CopyEnvelopePoints`
- `<C-D>` -> `DeleteTimeline`
- `g` -> `GlueItems`
- `#` -> `SetItemFadeBoundaries`
- `z` -> `ZoomTimeSelection`
- `Z` -> `ZoomTimeAndTrackSelection`
- `i` -> `InsertOrExtendMidiItem`
- `ca` -> `InsertOrExtendMidiItem`
- `cc` -> `FitByLoopingNoExtend`
- `cf` -> `FitByLooping`
- `cp` -> `FitByPadding`
- `cs` -> `FitByStretching`

### main / `timeline_selector`

Bindings:

- `s` -> `SelectedItems`

### global / `command`

Bindings:

- `<C-s>` -> `SaveProject`
- `.` -> `RepeatLastCommand`
- `@` -> `PlayMacro`
- `,` -> `RecordMacro`
- `m` -> `Mark`
- `~` -> `MarkedRegion`
- `<C-'>` -> `DeleteMark`
- `<C-r>` -> `Redo`
- `u` -> `Undo`
- `R` -> `ToggleRecord`
- `T` -> `Play`
- `tt` -> `PlayFromTimeSelectionStart`
- `<M-t>` -> `PlayFromMousePosition`
- `<M-T>` -> `PlayFromMouseAndSoloTrack`
- `F` -> `Pause`
- `<C-z>` -> `ZoomUndo`
- `<C-Z>` -> `ZoomRedo`
- `v` -> `SetModeVisualTimeline`
- `<M-v>` -> `ClearTimelineSelectionAndSetModeVisualTimeline`
- `<C-SPC>` -> `ToggleViewMixer`
- `<return>` -> `StartStop`
- `X` -> `MoveToMousePositionAndPlay`
- `dr` -> `RemoveRegion`
- `!` -> `ToggleLoop`
- `<CM-f>` -> `MidiLearnLastTouchedFxParam`
- `<CM-m>` -> `ModulateLastTouchedFxParam`
- `<M-x>` -> `ShowBindingList`
- `<C-m>` -> `TapTempo`

### global / `timeline_motion`

Bindings:

- `<M-+>` -> `DecreaseGrid`
- `<M-->` -> `IncreaseGrid`
- `<C-$>` -> `ProjectEnd`
- `f` -> `PlayPosition`
- `x` -> `MousePosition`
- `<M-h>` -> `Left10Pix`
- `<M-l>` -> `Right10Pix`
- `h` -> `LeftGridDivision`
- `<left>` -> `LeftGridDivision`
- `l` -> `RightGridDivision`
- `<right>` -> `RightGridDivision`
- `H` -> `PrevMeasure`
- `L` -> `NextMeasure`
- `<C-H>` -> `Prev4Measures`
- `<C-L>` -> `Next4Measures`
- ``` -> `MarkedTimelinePosition`

### global / `timeline_operator`

Bindings:

- `r` -> `Record`
- `<C-p>` -> `DuplicateTimeline`
- `t` -> `PlayAndLoop`
- `|` -> `CreateMeasures`
- `<C-|>` -> `CreateProjectTempo`

### global / `timeline_selector`

Folders:

- folder `i` label "inner"

Bindings:

- `~` -> `MarkedRegion`
- `!` -> `LoopSelection`
- `i<M-w>` -> `AutomationItem`
- `il` -> `AllTrackItems`
- `ir` -> `Region`
- `ip` -> `ProjectTimeline`
- `iw` -> `Item`
- `iW` -> `BigItem`
- `i<M-l>` -> `AllTrackEnvelopePoints`

### global / `visual_timeline_command`

Bindings:

- `o` -> `SwitchTimelineSelectionSide`

### midi / `command`

Folders:

- folder `<SPC>` label "leader commands"
- folder `<SPC>m` label "midi"
- folder `<SPC>c` label "CCs"
- folder `<SPC>v` label "view"

Bindings:

- `<ESC>` -> `ResetMidi`
- `+` -> `MidiZoomInVert`
- `-` -> `MidiZoomOutVert`
- `<C-+>` -> `MidiZoomInHoriz`
- `<C-->` -> `MidiZoomOutHoriz`
- `Z` -> `CloseWindow`
- `p` -> `MidiPaste`
- `S` -> `UnselectAllEvents`
- `Y` -> `CopySelectedEvents`
- `D` -> `CutSelectedEvents`
- `k` -> `PitchUp`
- `j` -> `PitchDown`
- `K` -> `PitchUpOctave`
- `zp` -> `MidiZoomContent`
- `J` -> `PitchDownOctave`
- `V` -> `SelectAllNotesAtPitch`
- `<M-k>` -> `MoveNoteUpSemitone`
- `<M-j>` -> `MoveNoteDownSemitone`
- `<M-K>` -> `MoveNoteUpOctave`
- `<M-J>` -> `MoveNoteDownOctave`
- `<SPC>q` -> `CloseUndockedMidiEditorOrPassToMainWindow`
- `<SPC><SPC>` -> `ShowMidiActionList`
- `<SPC>mg` -> `SetMidiGridDivision`
- `<SPC>mq` -> `Quantize`
- `<SPC>ct` -> `ToggleUsedCC`
- `<SPC>vd` -> `DrumsView`
- `<SPC>ve` -> `EventView`
- `<SPC>vn` -> `NotationView`
- `<SPC>vp` -> `PianoRollView`
- `<M-g>` -> `InsertG`
- `<M-s>` -> `InsertGb`
- `<M-f>` -> `InsertF`
- `<M-e>` -> `InsertE`
- `<M-m>` -> `InsertEb`
- `<M-d>` -> `InsertD`
- `<M-r>` -> `InsertDb`
- `<M-c>` -> `InsertC`
- `<M-b>` -> `InsertB`
- `<M-h>` -> `InsertBb`
- `<M-a>` -> `InsertA`
- `<M-l>` -> `InsertAb`
- `<M-G>` -> `InsertChordG`
- `<M-S>` -> `InsertChordGb`
- `<M-F>` -> `InsertChordF`
- `<M-E>` -> `InsertChordE`
- `<M-M>` -> `InsertChordEb`
- `<M-D>` -> `InsertChordD`
- `<M-R>` -> `InsertChordDb`
- `<M-C>` -> `InsertChordC`
- `<M-B>` -> `InsertChordB`
- `<M-H>` -> `InsertChordBb`
- `<M-A>` -> `InsertChordA`
- `<M-L>` -> `InsertChordAb`

### midi / `timeline_motion`

Bindings:

- `<right>` -> `RightMidiGridDivision`
- `<left>` -> `LeftMidiGridDivision`
- `l` -> `MoveNoteAndCursorRight`
- `h` -> `MoveNoteAndCursorLeft`
- `(` -> `MidiTimeSelectionStart`
- `)` -> `MidiTimeSelectionEnd`
- `w` -> `NextNoteStart`
- `b` -> `PrevNoteStart`
- `W` -> `NextBigNoteStart`
- `B` -> `PrevBigNoteStart`
- `E` -> `NextBigNoteEnd`
- `e` -> `NextNoteEnd`
- `<up>` -> `MoveNoteUpSemitone`
- `<down>` -> `MoveNoteDownSemitone`
- `<S-up>` -> `MoveNoteUpOctave`
- `<S-down>` -> `MoveNoteDownOctave`
- `<S-right>` -> `LengthenNotes`
- `<S-left>` -> `ShortenNotes`
- `n` -> `AddNextNoteToSelection`
- `N` -> `AddPrevNoteToSelection`
- `<TAB>` -> `JumpToNextNote`
- `<S-TAB>` -> `JumpToPrevNote`
- `<C-w>` -> `ActivateNextMidiTrack`
- `<C-W>` -> `ActivatePrevMidiTrack`

### midi / `timeline_operator`

Bindings:

- `d` -> `CutNotes`
- `y` -> `CopyNotes`
- `c` -> `FitNotes`
- `a` -> `InsertNote`
- `g` -> `JoinNotes`
- `s` -> `SelectNotes`
- `z` -> `MidiZoomTimeSelection`

### midi / `timeline_selector`

Bindings:

- `s` -> `SelectedNotes`


## Binding set: extended_defaults

### main / `command`

Folders:

- folder `<SPC>` label "leader commands"
- folder `<SPC>A` label "arrange"
- folder `<SPC>g` label "grid"
- folder `<SPC>o` label "options"
- folder `<SPC>z` label "zoom/scroll"
- folder `<SPC>m` label "marker"
- folder `<SPC>mt` label "TakeMarkers"
- folder `<SPC>M` label "midi"
- folder `<SPC>M,` label "options"
- folder `<SPC>r` label "recording"
- folder `<SPC>r,` label "options"
- folder `<SPC>a` label "automation"
- folder `<SPC>i` label "selected items"
- folder `<SPC>ix` label "explode takes"
- folder `<SPC>is` label "stretch"
- folder `<SPC>i#` label "fade"
- folder `<SPC>it` label "transients"
- folder `<SPC>ie` label "envelopes"
- folder `<SPC>if` label "fx"
- folder `<SPC>iR` label "rename"
- folder `<SPC>ib` label "timebase"
- folder `<SPC>t` label "track"
- folder `<SPC>ti` label "insert"
- folder `<SPC>tx` label "routing"
- folder `<SPC>tF` label "freeze"
- folder `<SPC>e` label "envelopes"
- folder `<SPC>ep` label "point shapes"
- folder `<SPC>ev` label "point value"
- folder `<SPC>es` label "selected"
- folder `<SPC>D` label "dev"
- folder `<SPC>f` label "fx"
- folder `<SPC>fI` label "input"
- folder `<SPC>fc` label "show"
- folder `<SPC>T` label "timeline"
- folder `<SPC>G` label "global"
- folder `<SPC>Gs` label "show/hide"
- folder `<SPC>Gf` label "fx"
- folder `<SPC>Ge` label "envelope"
- folder `<SPC>Gt` label "track"
- folder `<SPC>Gtx` label "routing"
- folder `<SPC>GtF` label "freeze"
- folder `<SPC>Ga` label "automation"
- folder `<SPC>p` label "project"
- folder `<SPC>pt` label "timebase"
- folder `<SPC>pr` label "render"
- folder `<SPC>d` label "drums"

Bindings:

- `<M-D>` -> `DeleteEnvelopePoints`
- `<C-a>` -> `devAction`
- `<C-B>` -> `FadeItemInFromMouse`
- `<C-E>` -> `FadeItemOutFromMouse`
- `<C-y>` -> `SplitAtMouse`
- `<C-b>` -> `TrimLeftEdgeFromMouse`
- `<C-e>` -> `TrimRightEdgeFromMouse`
- `<ESC>` -> `Reset`
- `>` -> `TrimItemRightEdge`
- `<` -> `TrimItemLeftEdge`
- `<M-)>` -> `StretchItemEndToCursor`
- `<M-(>` -> `StretchItemStartToCursor`
- `<M-n>` -> `ShowNextFx`
- `<M-N>` -> `ShowPrevFx`
- `<M-f>` -> `ToggleShowFx`
- `<M-F>` -> `CloseFx`
- `<M-i>` -> `InsertEnvelopePoint`
- `<M-I>` -> `InsertToggleAtTimeSelection`
- `zp` -> `ZoomProject`
- `D` -> `CutSelectedItems`
- `Y` -> `CopySelectedItems`
- `<M-Y>` -> `CopySelectedEnvelopePoints`
- `V` -> `SetModeVisualTrack`
- `<C-w>` -> `NextEnvelope`
- `<C-W>` -> `PrevEnvelope`
- `<M-j>` -> `NextEnvelope`
- `<M-k>` -> `PrevEnvelope`
- `<C-+>` -> `ZoomInVert`
- `<C-->` -> `ZoomOutVert`
- `+` -> `ZoomInHoriz`
- `-` -> `ZoomOutHoriz`
- `;` -> `MoveItemToEditCursor`
- `dd` -> `CutTrack`
- `aa` -> `ArmTracks`
- `O` -> `EnterTrackAbove`
- `o` -> `EnterTrackBelow`
- `p` -> `Paste`
- `<C-v>` -> `Paste`
- `yy` -> `CopyTrack`
- `zz` -> `ScrollToSelectedTracks`
- `zc` -> `CenterCursor`
- `%` -> `SplitItemsAtEditCursor`
- `~` -> `MarkedTracks`
- `<C-j>` -> `NudgeTrackVolumeDownBy1Tenth`
- `<C-k>` -> `NudgeTrackVolumeUpBy1Tenth`
- `<C-J>` -> `NudgeTrackVolumeDownBy1`
- `<C-K>` -> `NudgeTrackVolumeUpBy1`
- `<CM-j>` -> `ShiftEnvelopePointsDownATinyBit`
- `<CM-k>` -> `ShiftEnvelopePointsUpATinyBit`
- `<CM-J>` -> `ShiftEnvelopePointsDown`
- `<CM-K>` -> `ShiftEnvelopePointsUp`
- `<M-S>` -> `SelectItemsUnderEditCursor`
- `'` -> `MarkedTracks`
- `<SPC><SPC>` -> `ShowActionList`
- `<SPC>b` -> `MediaExplorer`
- `<SPC>AI` -> `ImplodeItemsOntoSingleTrack`
- `<SPC>Ai` -> `InsertSilence`
- `<SPC>Ad` -> `RemoveContentsOfTimeSel`
- `<SPC>Am` -> `MoveTimeSelToCursor`
- `<SPC>Ac` -> `CopyTimeSelToCursor`
- `<SPC>gd` -> `SetGridDivision`
- `<SPC>gs` -> `ToggleSnap`
- `<SPC>oc` -> `CycleRippleEditMode`
- `<SPC>oe` -> `ToggleEnvelopePointsMoveWithItems`
- `<SPC>of` -> `ResetFeedbackWindow`
- `<SPC>om` -> `ToggleMetronome`
- `<SPC>op` -> `TogglePlaybackPreroll`
- `<SPC>or` -> `ToggleRecordingPreroll`
- `<SPC>os` -> `ToggleSnap`
- `<SPC>ot` -> `ToggleStopAtEndOfTimeSelectionIfNoRepeat`
- `<SPC>ov` -> `ToggleLoopSelectionFollowsTimeSelection`
- `<SPC>ox` -> `ToggleAutoCrossfade`
- `<SPC>oz` -> `TogglePlaybackAutoScroll`
- `<SPC>zt` -> `ScrollToPlayPosition`
- `<SPC>ze` -> `ScrollToEditCursor`
- `<SPC>mi` -> `InsertProjectMarker`
- `<SPC>mw` -> `NextProjectMarker`
- `<SPC>mb` -> `PreviousProjectMarker`
- `<SPC>mti` -> `InsertTakeMarker`
- `<SPC>mtw` -> `NextTakeMarker`
- `<SPC>mtb` -> `PrevTakeMarker`
- `<SPC>Mg` -> `SetMidiGridDivision`
- `<SPC>Mq` -> `Quantize`
- `<SPC>M,g` -> `ToggleMidiEditorUsesMainGridDivision`
- `<SPC>M,s` -> `ToggleMidiSnap`
- `<SPC>ra` -> `ArmTracks`
- `<SPC>ro` -> `SetRecordMidiOutput`
- `<SPC>rd` -> `SetRecordMidiOverdub`
- `<SPC>rt` -> `SetRecordMidiTouchReplace`
- `<SPC>rR` -> `SetRecordMidiReplace`
- `<SPC>rv` -> `SetRecordMonitorOnly`
- `<SPC>rr` -> `SetRecordInput`
- `<SPC>r,n` -> `SetRecordModeNormal`
- `<SPC>r,s` -> `SetRecordModeItemSelectionAutoPunch`
- `<SPC>r,v` -> `SetRecordModeTimeSelectionAutoPunch`
- `<SPC>r,p` -> `ToggleRecordingPreroll`
- `<SPC>r,z` -> `ToggleRecordingAutoScroll`
- `<SPC>r,t` -> `ToggleRecordToTapeMode`
- `<SPC>ar` -> `SetAutomationModeTrimRead`
- `<SPC>aR` -> `SetAutomationModeRead`
- `<SPC>al` -> `SetAutomationModeLatch`
- `<SPC>ag` -> `SetAutomationModeLatchAndArm`
- `<SPC>ap` -> `SetAutomationModeLatchPreview`
- `<SPC>at` -> `SetAutomationModeTouch`
- `<SPC>aw` -> `SetAutomationModeWrite`
- `<SPC>i<down>` -> `MoveItemDown`
- `<SPC>i<up>` -> `MoveItemUp`
- `<SPC>ip` -> `pasteRhythmToPitches`
- `<SPC>iP` -> `PasteItemBeforeCursor`
- `<SPC>ij` -> `NextTake`
- `<SPC>ik` -> `PrevTake`
- `<SPC>il` -> `LoopItem`
- `<SPC>iM` -> `ToggleMuteItem`
- `<SPC>id` -> `DeleteActiveTake`
- `<SPC>ic` -> `CropToActiveTake`
- `<SPC>io` -> `OpenInMidiEditor`
- `<SPC>in` -> `ItemNormalize`
- `<SPC>ig` -> `GlueItemsIgnoringTimeSelection`
- `<SPC>iq` -> `QuantizeItems`
- `<SPC>ih` -> `HealItemsSplits`
- `<SPC>iS` -> `ToggleSoloItem`
- `<SPC>i%` -> `SplitItemsAtNoteStart`
- `<SPC>iB` -> `MoveItemContentToEditCursor`
- `<SPC>iF` -> `Set2msFades`
- `<SPC>ixp` -> `ExplodeTakesInPlace`
- `<SPC>ixo` -> `ExplodeTakesInOrder`
- `<SPC>ixa` -> `ExplodeTakesInAcrossTracks`
- `<SPC>isa` -> `AdjustTransientDetection`
- `<SPC>isc` -> `ClearTransientsAndStretchMarkers`
- `<SPC>isd` -> `DeleteStretchMarker`
- `<SPC>isi` -> `InsertStretchMarker`
- `<SPC>iss` -> `SplitItemAtTransients`
- `<SPC>ist` -> `CalculateTransientGuides`
- `<SPC>isD` -> `DynamicSplit`
- `<SPC>i#i` -> `CycleItemFadeInShape`
- `<SPC>i#o` -> `CycleItemFadeOutShape`
- `<SPC>ies` -> `ViewTakeEnvelopes`
- `<SPC>iem` -> `ToggleTakeMuteEnvelope`
- `<SPC>iep` -> `ToggleTakePanEnvelope`
- `<SPC>ieP` -> `ToggleTakePitchEnvelope`
- `<SPC>iev` -> `ToggleTakeVolumeEnvelope`
- `<SPC>ifa` -> `ApplyFxToItem`
- `<SPC>ifp` -> `PasteItemFxChain`
- `<SPC>ifd` -> `CutItemFxChain`
- `<SPC>ify` -> `CopyItemFxChain`
- `<SPC>ifs` -> `ToggleShowTakeFxChain`
- `<SPC>ifb` -> `ToggleTakeFxBypass`
- `<SPC>ir` -> `ReverseItems`
- `<SPC>iRs` -> `RenameTakeSourceFile`
- `<SPC>iRt` -> `RenameTake`
- `<SPC>iRr` -> `RenameTakeAndSourceFile`
- `<SPC>iRa` -> `AutoRenameTake`
- `<SPC>ibt` -> `SetItemsTimebaseToTime`
- `<SPC>ibb` -> `SetItemsTimebaseToBeatsPos`
- `<SPC>ibr` -> `SetItemsTimebaseToBeatsPosLengthAndRate`
- `<SPC>tv` -> `RenameTrackToVstiPresetName`
- `<SPC>tn` -> `ResetTrackToNormal`
- `<SPC>tR` -> `RenderTrack`
- `<SPC>tr` -> `RenameTrack`
- `<SPC>tz` -> `MinimizeTracks`
- `<SPC>tm` -> `CycleRecordMonitor`
- `<SPC>tf` -> `CycleFolderState`
- `<SPC>tI` -> `SetTrackInputToMatchFirstSelected`
- `<SPC>ty` -> `SaveTrackAsTemplate`
- `<SPC>t+` -> `TrackVolumeUp3`
- `<SPC>t-` -> `TrackVolumeDown3`
- `<SPC>tic` -> `InsertClickTrack`
- `<SPC>tit` -> `InsertTrackFromTemplate`
- `<SPC>tiv` -> `InsertVirtualInstrumentTrack`
- `<SPC>ti1` -> `InsertTrackFromTemplateSlot1`
- `<SPC>ti2` -> `InsertTrackFromTemplateSlot2`
- `<SPC>ti3` -> `InsertTrackFromTemplateSlot3`
- `<SPC>ti4` -> `InsertTrackFromTemplateSlot4`
- `<SPC>txp` -> `TrackToggleSendToParent`
- `<SPC>txs` -> `ToggleShowTrackRouting`
- `<SPC>tFf` -> `FreezeTrack`
- `<SPC>tFu` -> `UnfreezeTrack`
- `<SPC>tFs` -> `ShowTrackFreezeDetails`
- `<SPC>eh` -> `ToggleShowEnvelopesForTracks`
- `<SPC>epd` -> `DeleteEnvelopePoints`
- `<SPC>epb` -> `BezierPointShape`
- `<SPC>epe` -> `FastEndPointShape`
- `<SPC>eps` -> `FastStartPointShape`
- `<SPC>epl` -> `LinearPointShape`
- `<SPC>epE` -> `SlowStartEndPointShape`
- `<SPC>epS` -> `SquarePointShape`
- `<SPC>eI` -> `InsertToggleAtTimeSelection`
- `<SPC>ei` -> `InsertEnvelopePoint`
- `<SPC>evi` -> `InvertSelectedPoints`
- `<SPC>ev-` -> `MoveEnvelopePointDown`
- `<SPC>ev+` -> `MoveEnvelopePointUp`
- `<SPC>evm` -> `SetPointMin`
- `<SPC>evM` -> `SetPointMax`
- `<SPC>evc` -> `SetPointCenter`
- `<SPC>et` -> `ToggleShowAllEnvelope`
- `<SPC>ea` -> `ToggleArmAllEnvelopes`
- `<SPC>eA` -> `UnarmAllEnvelopes`
- `<SPC>ed` -> `ClearAllEnvelope`
- `<SPC>eV` -> `ToggleVolumeEnvelope`
- `<SPC>eP` -> `TogglePanEnvelope`
- `<SPC>ew` -> `SelectWidthEnvelope`
- `<SPC>el` -> `ShowEnvelopeLastTouchedFxParam`
- `<SPC>esd` -> `ClearEnvelope`
- `<SPC>esa` -> `ToggleArmEnvelope`
- `<SPC>esy` -> `CopyEnvelope`
- `<SPC>est` -> `ToggleShowSelectedEnvelope`
- `<SPC>esb` -> `ToggleEnvelopeBypass`
- `<SPC>Df` -> `FxDevices`
- `<SPC>Dr` -> `Repl`
- `<SPC>Dc` -> `commandIdLookup`
- `<SPC>fi` -> `InsertFxAtSlot`
- `<SPC>fa` -> `AddFx`
- `<SPC>fs` -> `ToggleShowFxChain`
- `<SPC>fd` -> `CutFxChain`
- `<SPC>fy` -> `CopyFxChain`
- `<SPC>fp` -> `PasteFxChain`
- `<SPC>fb` -> `ToggleFxBypass`
- `<SPC>fm` -> `ModulateLastTouchedFxParam`
- `<SPC>fIs` -> `ToggleShowInputFxChain`
- `<SPC>fId` -> `CutInputFxChain`
- `<SPC>fc1` -> `ToggleShowFx1`
- `<SPC>fc2` -> `ToggleShowFx2`
- `<SPC>fc3` -> `ToggleShowFx3`
- `<SPC>fc4` -> `ToggleShowFx4`
- `<SPC>fc5` -> `ToggleShowFx5`
- `<SPC>fc6` -> `ToggleShowFx6`
- `<SPC>fc7` -> `ToggleShowFx7`
- `<SPC>fc8` -> `ToggleShowFx8`
- `<SPC>Ta` -> `AddTimeSignatureMarker`
- `<SPC>Te` -> `EditTimeSignatureMarker`
- `<SPC>Td` -> `DeleteTimeSignatureMarker`
- `<SPC>Ts` -> `ToggleShowTempoEnvelope`
- `<SPC>Gq` -> `QuitReaper`
- `<SPC>Gg` -> `SetGridDivision`
- `<SPC>Gr` -> `ResetControlDevices`
- `<SPC>G,` -> `ShowPreferences`
- `<SPC>GS` -> `UnsoloAllItems`
- `<SPC>Gsx` -> `RoutingMatrix`
- `<SPC>Gsw` -> `ToggleShowWiringDiagram`
- `<SPC>Gst` -> `ToggleShowTrackManager`
- `<SPC>Gsm` -> `MasterTrack`
- `<SPC>Gsp` -> `RegionPlaylist`
- `<SPC>Gsr` -> `ToggleShowRegionMarkerManager`
- `<SPC>Gfx` -> `CloseAllFxChainsAndWindows`
- `<SPC>Gfc` -> `ViewFxChainMaster`
- `<SPC>Get` -> `ToggleShowAllEnvelopeGlobal`
- `<SPC>GtR` -> `RenderTrack`
- `<SPC>Gtr` -> `RenameTrack`
- `<SPC>Gtm` -> `CycleRecordMonitor`
- `<SPC>Gtf` -> `CycleFolderState`
- `<SPC>Gty` -> `SaveTrackAsTemplate`
- `<SPC>Gtp` -> `InsertTrackFromTemplate`
- `<SPC>Gt1` -> `InsertTrackFromTemplateSlot1`
- `<SPC>Gt2` -> `InsertTrackFromTemplateSlot2`
- `<SPC>Gt3` -> `InsertTrackFromTemplateSlot3`
- `<SPC>Gt4` -> `InsertTrackFromTemplateSlot4`
- `<SPC>Gtc` -> `InsertClickTrack`
- `<SPC>Gtv` -> `InsertVirtualInstrumentTrack`
- `<SPC>Gtxp` -> `TrackToggleSendToParent`
- `<SPC>Gtxs` -> `ToggleShowTrackRouting`
- `<SPC>GtFf` -> `FreezeTrack`
- `<SPC>GtFu` -> `UnfreezeTrack`
- `<SPC>GtFs` -> `ShowTrackFreezeDetails`
- `<SPC>Gar` -> `SetGlobalAutomationModeTrimRead`
- `<SPC>Gal` -> `SetGlobalAutomationModeLatch`
- `<SPC>Gap` -> `SetGlobalAutomationModeLatchPreview`
- `<SPC>Gat` -> `SetGlobalAutomationModeTouch`
- `<SPC>GaR` -> `SetGlobalAutomationModeRead`
- `<SPC>Gaw` -> `SetGlobalAutomationModeWrite`
- `<SPC>GaS` -> `SetGlobalAutomationModeOff`
- `<SPC>pB` -> `BuildBusses`
- `<SPC>pm` -> `RoutingMatrix`
- `<SPC>pR` -> `RouteToBusses`
- `<SPC>pb` -> `ProjectBay`
- `<SPC>p,` -> `ShowProjectSettings`
- `<SPC>pn` -> `NextTab`
- `<SPC>pp` -> `PrevTab`
- `<SPC>ps` -> `SaveProject`
- `<SPC>po` -> `OpenProject`
- `<SPC>pc` -> `NewProjectTab`
- `<SPC>px` -> `CloseProject`
- `<SPC>pC` -> `CleanProjectDirectory`
- `<SPC>pS` -> `SaveProjectWithNewVersion`
- `<SPC>ptt` -> `SetProjectTimebaseToTime`
- `<SPC>ptb` -> `SetProjectTimebaseToBeatsPos`
- `<SPC>ptr` -> `SetProjectTimebaseToBeatsPosLengthAndRate`
- `<SPC>pr.` -> `RenderProjectWithLastSetting`
- `<SPC>prr` -> `RenderProject`
- `<SPC>de` -> `ExplodeNoteRows`
- `<SPC>df` -> `Flam`
- `<SPC>d3` -> `Ras3`
- `<SPC>d5` -> `Ras5`
- `<SPC>dc` -> `Crescendo`
- `<SPC>dd` -> `Decrescendo`
- `<SPC>dD` -> `DynamicSplit`
- `<SPC>dq` -> `QuantizeTool`

### main / `track_motion`

Bindings:

- `G` -> `LastTrack`
- `gg` -> `FirstTrack`
- `J` -> `NextFolderNear`
- `K` -> `PrevFolderNear`
- `/` -> `MatchedTrackForward`
- `?` -> `MatchedTrackBackward`
- `n` -> `NextTrackMatchForward`
- `N` -> `NextTrackMatchBackward`
- `:` -> `TrackWithNumber`
- `<down>` -> `NextTrack`
- `j` -> `NextTrack`
- `k` -> `PrevTrack`
- `<up>` -> `PrevTrack`
- `<C-f>` -> `Next10Track`
- `<C-d>` -> `Next5Track`
- `<C-u>` -> `Prev5Track`
- `t` -> `CurrentTrack`

### main / `track_operator`

Folders:

- folder `"` label "snapshots"

Bindings:

- `"s` -> `SaveTracksToCurrentSnapshot`
- `"c` -> `CreateNewSnapshotWithTracks`
- `"d` -> `DeleteTracksFromCurrentSnapshot`
- `z` -> `ZoomTrackSelection`
- `<TAB>` -> `MakeFolder`
- `d` -> `CutTrack`
- `a` -> `ArmTracks`
- `s` -> `toggleSoloExclusive`
- `S` -> `ToggleSolo`
- `M` -> `ToggleMute`
- `y` -> `CopyTrack`
- `<M-C>` -> `ColorTrackGradient`
- `<M-c>` -> `ColorTrack`

### main / `track_selector`

Folders:

- folder `i` label "inner"

Bindings:

- `'` -> `MarkedTracks`
- `F` -> `FolderParent`
- `f` -> `Folder`
- `ic` -> `InnerFolder`
- `if` -> `InnerFolderAndParent`
- `ig` -> `AllTracks`

### main / `visual_track_command`

Bindings:

- `V` -> `SetModeNormal`
- `<C-h>` -> `NudgeTrackPanLeft`
- `<C-l>` -> `NudgeTrackPanRight`
- `<C-H>` -> `NudgeTrackPanLeft10Times`
- `<C-L>` -> `NudgeTrackPanRight10Times`
- `<M-i>` -> `InsertEnvelopePointsAtSelection`

### main / `timeline_motion`

Bindings:

- `0` -> `ProjectStart`
- `<TAB>` -> `NextTransientInItems`
- `<S-TAB>` -> `PrevTransientInItems`
- `<S-left>` -> `PrevMeasure`
- `<S-right>` -> `NextMeasure`
- `<CM-L>` -> `NextTransientInItemMinusFadeTime`
- `<CM-H>` -> `PrevTransientInItemMinusFadeTime`
- `B` -> `PrevBigItemStart`
- `E` -> `NextBigItemEnd`
- `W` -> `NextBigItemStart`
- `b` -> `PrevItemStart`
- `<M-b>` -> `SelPrevEnvelopePoint`
- `<M-w>` -> `SelNextEnvelopePoint`
- `<M-B>` -> `PrevEnvelopePoint`
- `<M-W>` -> `NextEnvelopePoint`
- `<M-n>` -> `AddNextEnvelopePointSel`
- `<M-N>` -> `AddPrevEnvelopePointSel`
- `e` -> `NextItemEnd`
- `w` -> `NextItemStart`
- `$` -> `LastItemEnd`
- `(` -> `TimeSelectionStart`
- `)` -> `TimeSelectionEnd`
- `<S-down>` -> `PitchItemDownSemi`
- `<S-up>` -> `PitchItemUpSemi`
- `<CS-down>` -> `PitchItemDownOct`
- `<CS-up>` -> `PitchItemUpOct`

### main / `timeline_operator`

Folders:

- folder `c` label "change/fit"

Bindings:

- `s` -> `SelectItems`
- `<M-p>` -> `CopyAndFitByLooping`
- `<M-s>` -> `SelectEnvelopePoints`
- `d` -> `CutItems`
- `y` -> `CopyItems`
- `<C-c>` -> `CopyItems`
- `<M-d>` -> `CutEnvelopePoints`
- `<M-y>` -> `CopyEnvelopePoints`
- `<C-D>` -> `DeleteTimeline`
- `g` -> `GlueItems`
- `#` -> `SetItemFadeBoundaries`
- `z` -> `ZoomTimeSelection`
- `Z` -> `ZoomTimeAndTrackSelection`
- `i` -> `InsertOrExtendMidiItem`
- `<M-a>` -> `InsertAutomationItem`
- `ca` -> `InsertOrExtendMidiItem`
- `cc` -> `FitByLoopingNoExtend`
- `cf` -> `FitByLooping`
- `cp` -> `FitByPadding`
- `cs` -> `FitByStretching`

### main / `timeline_selector`

Bindings:

- `s` -> `SelectedItems`

### global / `command`

Folders:

- folder `"` label "snapshots"
- folder `"#` label "recall #"

Bindings:

- `<V-1>` -> `VrtlBtn1`
- `<V-2>` -> `VrtlBtn2`
- `<V-3>` -> `VrtlBtn3`
- `<V-4>` -> `VrtlBtn4`
- `<V-5>` -> `VrtlBtn5`
- `<V-6>` -> `VrtlBtn6`
- `<V-7>` -> `VrtlBtn7`
- `<V-8>` -> `VrtlBtn8`
- `<V-9>` -> `VrtlBtn9`
- `<V-10>` -> `VrtlBtn10`
- `<V-11>` -> `VrtlBtn11`
- `<V-12>` -> `VrtlBtn12`
- `<V-13>` -> `VrtlBtn13`
- `<V-14>` -> `VrtlBtn14`
- `<V-15>` -> `VrtlBtn15`
- `<V-16>` -> `VrtlBtn16`
- `<C-s>` -> `SaveProject`
- `.` -> `RepeatLastCommand`
- `@` -> `PlayMacro`
- `q` -> `RecordMacro`
- `m` -> `Mark`
- `~` -> `MarkedRegion`
- `<C-'>` -> `DeleteMark`
- `<S-right>` -> `NextRegion`
- `<S-left>` -> `PrevRegion`
- `<C-r>` -> `Redo`
- `u` -> `Undo`
- `R` -> `ToggleRecord`
- `T` -> `Play`
- `<C-T>` -> `PlayAndSkipTimeSelection`
- `<M-t>` -> `PlayFromMousePosition`
- `<M-T>` -> `PlayFromMouseAndSoloTrack`
- `<C-t>` -> `PlayFromEditCursorAndSoloTrackUnderMouse`
- `tt` -> `PlayFromTimeSelectionStart`
- `F` -> `Pause`
- `<C-z>` -> `ZoomUndo`
- `<C-Z>` -> `ZoomRedo`
- `v` -> `SetModeVisualTimeline`
- `<M-v>` -> `ClearTimelineSelectionAndSetModeVisualTimeline`
- `<C-SPC>` -> `ToggleViewMixer`
- `<return>` -> `StartStop`
- `X` -> `MoveToMousePositionAndPlay`
- `dr` -> `RemoveRegion`
- `!` -> `ToggleLoop`
- `<C-a>` -> `ToggleBetweenReadAndTouchAutomationMode`
- `<M-n>` -> `ShowNextFx`
- `<M-N>` -> `ShowPrevFx`
- `<M-g>` -> `FocusMain`
- `<M-f>` -> `ToggleShowFx`
- `<M-F>` -> `CloseFx`
- `<CM-f>` -> `MidiLearnLastTouchedFxParam`
- `<CM-m>` -> `ModulateLastTouchedFxParam`
- `<M-x>` -> `ShowBindingList`
- `<C-m>` -> `TapTempo`
- `"j` -> `RecallNextSnapshot`
- `"k` -> `RecallPreviousSnapshot`
- `"D` -> `DeleteAllSnapshots`
- `"t` -> `ToggleSnapshotsWindow`
- `"y` -> `CopyCurrentSnapshot`
- `"p` -> `PasteSnapshot`
- `"r` -> `RecallCurrentSnapshot`
- `"#1` -> `RecallSnapshot1`
- `"#2` -> `RecallSnapshot2`
- `"#3` -> `RecallSnapshot3`
- `"#4` -> `RecallSnapshot4`
- `"#5` -> `RecallSnapshot5`
- `"#6` -> `RecallSnapshot6`
- `"#7` -> `RecallSnapshot7`
- `"#8` -> `RecallSnapshot8`
- `"#9` -> `RecallSnapshot9`

### global / `timeline_motion`

Bindings:

- `<M-+>` -> `DecreaseGrid`
- `<M-->` -> `IncreaseGrid`
- `<C-$>` -> `ProjectEnd`
- `f` -> `PlayPosition`
- `x` -> `MousePosition`
- `[` -> `LoopStart`
- `]` -> `LoopEnd`
- `<M-left>` -> `PrevTimeSignatureMarker`
- `<M-right>` -> `NextTimeSignatureMarker`
- `<M-h>` -> `Left10Pix`
- `<M-l>` -> `Right10Pix`
- `<M-H>` -> `Left40Pix`
- `<M-L>` -> `Right40Pix`
- `h` -> `LeftGridDivision`
- `<left>` -> `LeftGridDivision`
- `l` -> `RightGridDivision`
- `<right>` -> `RightGridDivision`
- `H` -> `PrevMeasure`
- `L` -> `NextMeasure`
- `<S-right>` -> `NextMeasure`
- `<S-left>` -> `PrevMeasure`
- `<C-i>` -> `MoveRedo`
- `<C-o>` -> `MoveUndo`
- `<C-h>` -> `Prev4Beats`
- `<C-l>` -> `Next4Beats`
- `<C-H>` -> `Prev4Measures`
- `<C-L>` -> `Next4Measures`
- ``` -> `MarkedTimelinePosition`

### global / `timeline_operator`

Bindings:

- `r` -> `Record`
- `<C-p>` -> `DuplicateTimeline`
- `t` -> `PlayAndLoop`
- `|` -> `CreateMeasures`
- `<C-|>` -> `CreateProjectTempo`

### global / `timeline_selector`

Folders:

- folder `i` label "inner"

Bindings:

- `~` -> `MarkedRegion`
- `!` -> `LoopSelection`
- `<CS-right>` -> `TimeSelectionShiftedRight`
- `<CS-left>` -> `TimeSelectionShiftedLeft`
- `i<M-w>` -> `AutomationItem`
- `il` -> `AllTrackItems`
- `ir` -> `Region`
- `ip` -> `ProjectTimeline`
- `iw` -> `Item`
- `iW` -> `BigItem`
- `i<M-l>` -> `AllTrackEnvelopePoints`

### global / `visual_timeline_command`

Bindings:

- `v` -> `SetModeNormal`
- `o` -> `SwitchTimelineSelectionSide`

### midi / `command`

Folders:

- folder `<SPC>` label "leader commands"
- folder `<SPC>m` label "midi"
- folder `<SPC>A` label "Arrange"
- folder `<SPC>c` label "CCs"
- folder `<SPC>k` label "key"
- folder `<SPC>C` label "Chord"
- folder `<SPC>Cs` label "select"
- folder `<SPC>Cd` label "drop"
- folder `<SPC>CD` label "doublings"
- folder `<SPC>CDu` label "up"
- folder `<SPC>CDd` label "down"
- folder `<SPC>v` label "view"

Bindings:

- `<C-a>` -> `devAction`
- `<ESC>` -> `ResetMidi`
- `:` -> `jumpToBar`
- `n` -> `AddNextNoteToSelection`
- `N` -> `AddPrevNoteToSelection`
- `+` -> `MidiZoomInVert`
- `-` -> `MidiZoomOutVert`
- `<C-+>` -> `MidiZoomInHoriz`
- `<C-->` -> `MidiZoomOutHoriz`
- `Z` -> `CloseWindow`
- `p` -> `MidiPaste`
- `S` -> `UnselectAllEvents`
- `Y` -> `CopySelectedEvents`
- `D` -> `CutSelectedEvents`
- `k` -> `PitchUp`
- `j` -> `PitchDown`
- `K` -> `PitchUpOctave`
- `zp` -> `MidiZoomContent`
- `J` -> `PitchDownOctave`
- `M` -> `MuteEvents`
- `<SPC>q` -> `CloseUndockedMidiEditorOrPassToMainWindow`
- `<SPC><SPC>` -> `ShowMidiActionList`
- `<SPC>mg` -> `SetMidiGridDivision`
- `<SPC>mq` -> `Quantize`
- `<SPC>At` -> `AddTextOrnament`
- `<SPC>Ae` -> `ExplodeRoutineFromAnnotations`
- `<SPC>ct` -> `ToggleUsedCC`
- `<SPC>ks` -> `toggleKeySnap`
- `<SPC>kf` -> `forceSelectedNotesToKey`
- `<SPC>Ci` -> `insertChordSymbol`
- `<SPC>Csb` -> `SelectBottomNotes`
- `<SPC>Cst` -> `SelectTopNotes`
- `<SPC>Csm` -> `SelectMiddleNotes`
- `<SPC>Cset` -> `SelectAllButTop`
- `<SPC>Cseb` -> `SelectAllButBottom`
- `<SPC>Csem` -> `SelectAllButMiddle`
- `<SPC>Cd2` -> `drop2`
- `<SPC>Cd3` -> `drop3`
- `<SPC>Cd4` -> `drop24`
- `<SPC>CDu8` -> `doubleOctUp`
- `<SPC>CDu7` -> `doubleSeventhUp`
- `<SPC>CDu6` -> `doubleSixthUp`
- `<SPC>CDu5` -> `doubleFifthUp`
- `<SPC>CDu4` -> `doubleFourthUp`
- `<SPC>CDu3` -> `doubleThirdUp`
- `<SPC>CDd8` -> `doubleOctDown`
- `<SPC>CDd7` -> `doubleSeventhDown`
- `<SPC>CDd6` -> `doubleSixthDown`
- `<SPC>CDd5` -> `doubleFifthDown`
- `<SPC>CDd4` -> `doubleFourthDown`
- `<SPC>CDd3` -> `doubleThirdDown`
- `<SPC>CDt` -> `doubleTopOctUp`
- `<SPC>CDb` -> `doubleBottomOctDown`
- `<SPC>CS` -> `soliHarmonize`
- `<SPC>vd` -> `DrumsView`
- `<SPC>ve` -> `EventView`
- `<SPC>vn` -> `NotationView`
- `<SPC>vp` -> `PianoRollView`
- `<M-g>` -> `InsertG`
- `<M-s>` -> `InsertGb`
- `<M-f>` -> `InsertF`
- `<M-e>` -> `InsertE`
- `<M-m>` -> `InsertEb`
- `<M-d>` -> `InsertD`
- `<M-r>` -> `InsertDb`
- `<M-c>` -> `InsertC`
- `<M-b>` -> `InsertB`
- `<M-h>` -> `InsertBb`
- `<M-a>` -> `InsertA`
- `<M-l>` -> `InsertAb`
- `<M-G>` -> `InsertChordG`
- `<M-S>` -> `InsertChordGb`
- `<M-F>` -> `InsertChordF`
- `<M-E>` -> `InsertChordE`
- `<M-M>` -> `InsertChordEb`
- `<M-D>` -> `InsertChordD`
- `<M-R>` -> `InsertChordDb`
- `<M-C>` -> `InsertChordC`
- `<M-B>` -> `InsertChordB`
- `<M-H>` -> `InsertChordBb`
- `<M-A>` -> `InsertChordA`
- `<M-L>` -> `InsertChordAb`

### midi / `timeline_motion`

Bindings:

- `0` -> `MidiItemStart`
- `$` -> `MidiItemEnd`
- `<right>` -> `RightMidiGridDivision`
- `<left>` -> `LeftMidiGridDivision`
- `l` -> `MoveNoteAndCursorRight`
- `h` -> `MoveNoteAndCursorLeft`
- `(` -> `MidiTimeSelectionStart`
- `)` -> `MidiTimeSelectionEnd`
- `w` -> `NextNoteStart`
- `b` -> `PrevNoteStart`
- `W` -> `NextBigNoteStart`
- `B` -> `PrevBigNoteStart`
- `E` -> `NextBigNoteEnd`
- `e` -> `NextNoteEnd`
- `<up>` -> `MoveNoteUpSemitone`
- `<down>` -> `MoveNoteDownSemitone`
- `<S-up>` -> `MoveNoteUpOctave`
- `<S-down>` -> `MoveNoteDownOctave`
- `<S-right>` -> `LengthenNotes`
- `<S-left>` -> `ShortenNotes`
- `n` -> `AddNextNoteToSelection`
- `N` -> `AddPrevNoteToSelection`
- `<TAB>` -> `JumpToNextNote`
- `<S-TAB>` -> `JumpToPrevNote`
- `<C-w>` -> `ActivateNextMidiTrack`
- `<C-W>` -> `ActivatePrevMidiTrack`

### midi / `timeline_operator`

Bindings:

- `d` -> `CutNotes`
- `y` -> `CopyNotes`
- `c` -> `FitNotes`
- `a` -> `InsertNote`
- `g` -> `JoinNotes`
- `s` -> `SelectNotes`
- `z` -> `MidiZoomTimeSelection`

### midi / `timeline_selector`

Bindings:

- `s` -> `SelectedNotes`

# Part 2 — Grammar

Sources: `internal/command/action_sequences.lua`, `internal/command/action_sequence_functions/{main,global,midi}.lua`,
`internal/command/builder.lua`, plus `runner.lua`, `executor.lua`, `handler.lua`, `meta_command.lua`,
`state_machine/*` and `library/state.lua` for the helpers the grammar functions call.

## Contexts and modes

- **Contexts**: `main`, `midi` (set per keypress; `global` is not a real keypress context but a
  shared pool of sequences/bindings merged into both).
- **Modes**: `normal`, `visual_track` (main only in practice), `visual_timeline`.
- State (`state_machine/constants.lua` reset state): `key_sequence=""`, `context="main"`,
  `mode="normal"`, `macro_recording=false`, `macro_register="+"`,
  `timeline_selection_side="left"`, `visual_track_pivot_i=0`, `last_command=<NoOp command>`,
  plus track-search memory (`last_searched_track_name`, direction flag).
- Keypress flow (`state_machine.lua`): if `key_sequence` is empty, adopt the keypress's context;
  if a partial sequence exists and the next key comes from a *different* context, the sequence is
  discarded with an error. Otherwise append the key, try `buildCommand`; if a command builds,
  handle it (and clear `key_sequence`); else if completions exist, stay pending and display them;
  else clear `key_sequence` ("Undefined key sequence").

## Legal action sequences per (context, mode)

`getPossibleActionSequenceFunctionPairs(context, mode)` concatenates, **in this priority order**
(the builder tries sequences in order and the first one that parses the whole key sequence wins):

1. `action_sequence_functions[context][mode]`
2. `action_sequence_functions["global"][mode]`
3. `action_sequence_functions[context]["all_modes"]`
4. `action_sequence_functions["global"]["all_modes"]`

`midi.lua` is an **empty table** — the midi context contributes no sequences of its own and uses
only the global ones. Resulting tables:

**main, normal** (in match order):
1. `[track_operator, track_motion]`
2. `[track_operator, track_selector]`
3. `[timeline_operator, timeline_selector]`
4. `[timeline_operator, timeline_motion]`
5. `[timeline_motion]`
6. `[track_motion]`
7. `[command]`

**main, visual_track**:
1. `[visual_track_command]`
2. `[track_operator]`
3. `[track_selector]`
4. `[track_motion]` (visual extend variant)
5. `[timeline_motion]` (gated by config)
6. `[track_motion]` (plain, from main.all_modes — shadowed by #4, never reached)
7. `[command]`

**main, visual_timeline**:
1. `[visual_timeline_command]`
2. `[timeline_operator]`
3. `[timeline_selector]`
4. `[timeline_motion]` (visual extend variant)
5. `[track_motion]` (from main.all_modes — plain run)
6. `[command]`

**midi, normal**:
1. `[timeline_operator, timeline_selector]`
2. `[timeline_operator, timeline_motion]`
3. `[timeline_motion]`
4. `[command]`

**midi, visual_timeline**:
1. `[visual_timeline_command]`
2. `[timeline_operator]`
3. `[timeline_selector]`
4. `[timeline_motion]` (visual extend variant)
5. `[command]`

(midi has no `visual_track` sequences beyond `[command]`; visual_track is only entered from main.)

## Composition functions, step by step

`runner.runAction` is the universal executor (see "Counts" below for its internals).
`setTimeSelection` / `setTrackSelection` are boolean options on the *operator's* action definition
(e.g. `SelectItems = { 40717, setTimeSelection = true }`, `SelectTracks = { setTrackSelection = true }`);
they mean "this operator's purpose IS the selection — don't restore it afterwards".

### global / all_modes / `[command]`
`runner.runAction(command_action)`. Nothing else.

### global / normal / `[timeline_operator, timeline_selector]`
1. Save the current time selection: `start_sel, end_sel = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)`.
2. `runner.runAction(timeline_selector)` — the selector sets the time selection (e.g. `Item`, `Region`, `LoopSelection`).
3. `runner.runAction(timeline_operator)`.
4. If the operator is not a table or lacks `setTimeSelection`: restore the saved selection with
   `reaper.GetSet_LoopTimeRange(true, false, start_sel, end_sel, false)`.

### global / normal / `[timeline_operator, timeline_motion]`
1. Save time selection (`GetSet_LoopTimeRange` get, as above).
2. `runner.makeSelectionFromTimelineMotion(timeline_motion, 1)`:
   - `sel_start = reaper.GetCursorPosition()`
   - `runner.runActionNTimes(timeline_motion, 1)` (the typed count, if any, lives *inside* the
     motion action as `prefixedRepetitions` and is applied by `runAction` itself)
   - `sel_end = reaper.GetCursorPosition()`
   - `reaper.SetEditCurPos(sel_start, false, false)` — cursor is put back
   - `reaper.GetSet_LoopTimeRange(true, false, sel_start, sel_end, false)` — time selection spans the motion
3. `runner.runAction(timeline_operator)`.
4. Restore the saved time selection unless the operator has `setTimeSelection`.

### global / normal / `[timeline_motion]`
`runner.runAction(timeline_motion)` (cursor simply moves).

### global / visual_timeline / `[visual_timeline_command]`
`runner.runAction(visual_timeline_command)`.

### global / visual_timeline / `[timeline_operator]`
1. `runner.runAction(timeline_operator)` — acts on the live visual time selection.
2. `state_interface.setModeToNormal()` — sets `key_sequence=""`, `context="main"`, `mode="normal"`,
   `timeline_selection_side="left"` (note: it also forces context to main).
3. If `not config.persist_visual_timeline_selection`: `runner.runAction("ClearTimeSelection")`.
   (Config currently `true`, so the selection persists.)

### global / visual_timeline / `[timeline_selector]`
`runner.runAction(timeline_selector)` — replaces the time selection, stays in visual_timeline.

### global / visual_timeline / `[timeline_motion]` (extend)
`runner.extendTimelineSelection(runner.runAction, {timeline_motion})`:
1. `left, right = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)` (current selection).
   (Faithful note: the Lua has a dead/buggy fallback `if not left or not right then left, right =
   start_pos, end_pos end` that reads `start_pos`/`end_pos` before they are assigned — effectively
   a no-op setting them to nil; don't replicate.)
2. `start_pos = reaper.GetCursorPosition()`; run the motion; `end_pos = reaper.GetCursorPosition()`.
3. If `state.timeline_selection_side == "right"`:
   - if `end_pos <= left`: flip side to `"left"` and set selection `(end_pos, left)`
   - else set selection `(left, end_pos)`
   Else (side `"left"`):
   - if `end_pos >= right`: flip side to `"right"` and set selection `(right, end_pos)`
   - else set selection `(end_pos, right)`
   All via `reaper.GetSet_LoopTimeRange(true, false, a, b, false)`.

### main / all_modes / `[track_motion]`
`runner.runAction(track_motion)`.

### main / normal / `[track_operator, track_motion]`
1. `runner.runAction("SaveTrackSelection")` (internal action: snapshots current track selection).
2. `runner.makeSelectionFromTrackMotion(track_motion, 1)`:
   - `first_index = reaper_utils.getTrackPosition()` (index of current/last-touched track)
   - `runner.runActionNTimes(track_motion, 1)` (count again carried inside the action)
   - `end_track = reaper.GetSelectedTrack(0, 0)`; if nil → bail out
   - `second_index = reaper.GetMediaTrackInfo_Value(end_track, "IP_TRACKNUMBER") - 1`
   - swap so `first_index <= second_index`, then for `i = first..second`:
     `reaper.SetTrackSelected(reaper.GetTrack(0, i), true)` — selects the whole spanned range
3. `runner.runAction(track_operator)`.
4. If the operator is not a table or lacks `setTrackSelection`: `runner.runAction("RestoreTrackSelection")`.

### main / normal / `[track_operator, track_selector]`
1. `runner.runAction("SaveTrackSelection")`.
2. `runner.runAction(track_selector)` (e.g. `InnerFolder`, `MarkedTracks` — sets track selection).
3. `runner.runAction(track_operator)`.
4. `RestoreTrackSelection` unless operator has `setTrackSelection`.

### main / visual_track / `[visual_track_command]`
`runner.runAction(visual_track_command)`.

### main / visual_track / `[track_operator]`
1. `runner.runAction(track_operator)` — acts on the live visual track selection.
2. `state_interface.setModeToNormal()`.
3. If `not config.persist_visual_track_selection` (currently false → condition true) and the
   operator lacks `setTrackSelection`: `reaper_utils.unselectAllButLastTouchedTrack()`.

### main / visual_track / `[track_selector]`
`runner.runAction(track_selector)` — stays in visual_track.

### main / visual_track / `[track_motion]` (extend)
`runner.extendTrackSelection(runner.makeSelectionFromTrackMotion, {track_motion, 1})`:
1. Run `makeSelectionFromTrackMotion(track_motion, 1)` (moves and range-selects as in normal mode).
2. `end_pos = reaper_utils.getTrackPosition()`; `pivot_i = state.visual_track_pivot_i`.
3. `runner.runAction("UnselectTracks")`, then walk `i` from `end_pos` one step at a time toward
   `pivot_i`, selecting each `reaper.GetTrack(0, i)`, and finally select the pivot track —
   i.e. the selection always spans pivot..cursor inclusive.

### main / visual_track / `[timeline_motion]`
If `config.allow_visual_track_timeline_movement` (currently true): `runner.runAction(timeline_motion)`;
otherwise the binding is a no-op.

## Builder: parsing a key sequence into a command

`command/builder.lua` — `buildCommand(state)`:
- Get the ordered candidate `action_sequences` for `(state.context, state.mode)` and the merged
  `entries = definitions.getPossibleEntries(state.context)` (global ⊕ context).
- For each candidate sequence, `buildCommandWithSequence(key_sequence, sequence, entries)`;
  the first that consumes the **entire** key sequence wins; result is
  `{action_sequence, action_keys, mode, context}`.

`buildCommandWithSequence`: for each `action_type` in the sequence, call
`stripNextActionKeyInKeySequence(rest, entries[action_type])`, which tries the whole remaining
key sequence against that action type first and then **repeatedly strips the last key unit** and
retries — i.e. longest-prefix match per action type; the stripped tail is passed to the next
action type. If any action type finds no match, or leftover keys remain at the end, the candidate
fails.

`getActionKey(key_sequence, entries)` — three ways a chunk can match, tried in order:
1. **Plain lookup**: `utils.getEntryForKeySequence` (exact key in the table, else split off the
   first key unit, descend into a folder under that key, recurse). Accepted only if the entry is
   not a folder and the action does **not** have `registerAction` set (or has `registerOptional`,
   e.g. `RecordMacro`, which works bare or with a register).
2. **Count prefix**: match `^[1-9][0-9]*`. Filter the entry table (recursively through folders) to
   actions whose definition has `prefixRepetitionCount = true`; recurse on the remainder. On
   success the action key becomes a table with `prefixedRepetitions = tonumber(digits)`.
   Because this runs per action-type chunk, counts can appear before any counted action:
   `3j` (3 tracks down), `d3j` (operator chunk `d`, motion chunk `3j`), `5.` (repeat 5×), `3@q`.
   Note digit keys can still be plain bindings (e.g. `<SPC>fc1`) because plain lookup is tried first.
3. **Register postfix**: split off the **last** key unit as the register. Filter entries to actions
   with `registerAction = true`; look up the remaining prefix. On success the action key becomes
   `{ ActionName, register = <last key> }`. The register is any single key unit (conventionally
   a–z). Register actions (without `registerOptional`) can *only* match this way — bare `m` or `@`
   never completes; `mq`, `'a`, `~x`, `` `b ``, `@q` do. Register-taking actions in the definitions:
   `Mark` (m), `MarkedTracks` (' / ~), `MarkedRegion` (~), `MarkedTimelinePosition` (`),
   `DeleteMark` (<C-'>), `RecordMacro` (q in extended, , in defaults; registerOptional),
   `PlayMacro` (@; also prefixRepetitionCount).

## Execution: from command to REAPER calls

`command/executor.lua`: `utils.getActionValues(command)` — for each `(action_type, action_key)`,
look the action name up via `getAction` and **merge** the action definition table into a copy of
the action key (so `prefixedRepetitions` / `register` from parsing coexist with `repetitions`,
`midiCommand`, `setTimeSelection`, sub-action list, etc. from the definition). Then the sequence's
composition function (above) is called with these merged action values as arguments.

`runner.runAction(action)`:
- If `action` is not a table: `runActionPart(action, false)`.
- If table:
  1. `repetitions = action.repetitions or 1` (a static multiplier baked into the definition,
     e.g. `Next4Measures = { "NextMeasure", repetitions = 4 }`).
  2. `prefixedRepetitions = action.prefixedRepetitions or 1` (the typed count).
  3. If `action.registerAction`: call `action[1](register)` — register actions are Lua functions
     taking the register key — and return (no repetition loop).
  4. `midi_command = action.midiCommand == true`.
  5. If `action.pre_action`: `runAction(pre_action)` once.
  6. Loop `repetitions * prefixedRepetitions` times: for each positional sub-action `action[i]`,
     recurse `runAction` if it's a table, else `runActionPart(sub, midi_command)`.
     **This loop is the single place where count multiplication happens.**
  7. If `action.post_action`: `runAction(post_action)` once.

`runActionPart(id, midi_command)`:
- function → call it;
- string → if it names another action in the action table, recurse `runAction` on that action
  (allows composite actions like `Reset = {"Stop","SetModeNormal",...}`); otherwise
  `reaper.NamedCommandLookup(id)` (SWS/extension command strings like `"_SWS_..."`);
- numeric id → `reaper.MIDIEditor_LastFocused_OnCommand(id, false)` if `midi_command` else
  `reaper.Main_OnCommand(id, 0)`.

## Command handling, repeat, macros (`handler.lua`, `meta_command.lua`)

`handleCommand(state, command)` wraps everything in `reaper.Undo_BeginBlock()` /
`Undo_EndBlock("reaper-keys: <description>", 1)` and `reaper.UpdateArrange()`:
- **Meta commands** are detected by the *name* of the command's `command`-type action key being a
  key of the `meta_commands` table: `PlayMacro`, `RecordMacro`, `RepeatLastCommand`,
  `ShowBindingList`. They receive and return state directly instead of going through executor.
- Otherwise `executeCommand(command)`; then if the executed command changed persisted state
  (mode switches do — `checkIfConsistentState`), reload it.
- If the command's `action_sequence` contains an action type whose name string-matches any of
  `config.repeatable_commands_action_type_match = {"command", "operator", "meta_command"}`
  (`:find` substring match, so `track_operator`/`timeline_operator`/`visual_track_command`/etc.
  all qualify; pure `[track_motion]`/`[timeline_motion]`/selector-only commands do not), it is
  stored as `state.last_command`.
- If `state.macro_recording`, the command is appended to `reaper_state` storage
  `macros[state.macro_register]`.
- `key_sequence` is cleared.

Meta command semantics:
- **RepeatLastCommand** (`.`): reads `prefixedRepetitions` off its own command key (so `5.` works);
  executes `state.last_command` that many times (recursively supports last command being a meta
  command); appends the last command to the macro if recording.
- **RecordMacro** (`q`+register in extended / `,`+register in defaults; `registerOptional` so bare
  press also matches): if already recording → stop (`macro_recording=false`); else initialise
  `macros[register] = {}` in reaper state, set `macro_register`, `macro_recording=true`.
- **PlayMacro** (`@`+register, count-prefixable): loads the command list from
  `macros[register]` and executes each stored command (meta or regular) `prefixedRepetitions` times
  through the normal executor.
- **ShowBindingList** (`<M-x>`): opens the binding-list GUI; state unchanged except key_sequence.

## Mode transitions

Mode is part of persisted state (`state_interface.setMode`). Mode-changing **actions** (in
`definitions/defaults/actions.lua`, implemented in `internal/library/state.lua`):

- **SetModeVisualTrack** (`V` in main command): `reaper.GetLastTouchedTrack()`; if present,
  `reaper.SetOnlyTrackSelected(track)`, compute `pivot = GetMediaTrackInfo_Value(track,
  "IP_TRACKNUMBER") - 1`, `setMode("visual_track")`, `setVisualTrackPivotIndex(pivot)`.
  The pivot anchors all subsequent extend-selections.
- **SetModeVisualTimeline** (`v` in global command): `setMode("visual_timeline")` and
  `reaper.Main_OnCommand(40625, 0)` ("Time selection: Set start point") so the selection anchors
  at the cursor.
- **ClearTimelineSelectionAndSetModeVisualTimeline** (`<M-v>`): composite action =
  `ClearSelectedTimeline` then `SetModeVisualTimeline`.
- **SetModeNormal**: `setMode("normal")`. Bound as `V` in `visual_track_command` and (extended
  only) `v` in `visual_timeline_command` — i.e. pressing the visual key again exits.
- **SwitchTimelineSelectionSide** (`o` in `visual_timeline_command`): if side is "right", run
  40630 (go to start of selection) and set side "left"; else run 40631 (go to end) and set side
  "right". The side determines which end `extendTimelineSelection` moves.
- **Operators exit visual modes implicitly**: the `[track_operator]` / `[timeline_operator]`
  visual sequences call `state_interface.setModeToNormal()` after running the operator
  (which also resets `context` to "main", clears `key_sequence`, side := "left"), then optionally
  clear the selection depending on `persist_visual_*_selection` config.
- **Reset** (`<ESC>`, main): composite `{ "Stop", "SetModeNormal", "SetRecordModeNormal",
  "ResetSelection", "RemoveTimeSelection" }`. **ResetMidi** (`<ESC>`, midi):
  `{ "Stop", "SetModeNormal", "ResetSelectionMidi", "RemoveTimeSelection" }`.

What changing mode does to the grammar: it swaps which sequence table is consulted (see "Legal
action sequences"). In visual modes, operators become **unary** (`[track_operator]` /
`[timeline_operator]` with no motion/selector argument — they act on the live selection), motions
become selection-extenders pivoting on `visual_track_pivot_i` / `timeline_selection_side`,
selectors replace the selection without leaving the mode, and the mode-specific command tables
(`visual_track_command` / `visual_timeline_command`) take highest priority.

Config knobs affecting grammar behaviour (`definitions/config.lua`):
`use_extended_defaults=true`, `persist_visual_timeline_selection=true`,
`persist_visual_track_selection=false`, `allow_visual_track_timeline_movement=true`,
`repeatable_commands_action_type_match={"command","operator","meta_command"}`.
