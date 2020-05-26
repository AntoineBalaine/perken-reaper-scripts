-- provides functions which are specific to reaper-keys, such as macros
local lib = require('library')
-- provides functions which make use of the reaper api
local util = require('utils.reaper_util')

-- naming conventions:
-- a noun implies an action which selects the noun, or a movement to it's position
-- simple verbs are usually operators on selctions, such as 'change'

return {
      ActivateNextMidiItem = {40833, midiCommand=true},
      ActivatePrevMidiItem = {40834, midiCommand=true},
      AddTrackVirtualInstrument = 40701,
      AllTrackItems = {"SaveItemSelectionAll", "SelectItemsOnTrack", "SelectedItems", "RestoreItemSelection"},
      AllTracks = 40296,
      ArmToggle = 9,
      ArmToggleSelected = 9,
      AutomationItem = 42197,
      BigItem = util.selectInnerBigItem,
      Change = {"TimeSelectionStart", "TransportPlay", "ToggleRecording", setTimeSelection=true},
      ChangeUntilEnd = {"TransportPlay", "ToggleRecording"},
      CleanProjectDirectory = 40098,
      ClearAllEnvelope = "_S&M_REMOVE_ALLENVS",
      ClearAllRecordArm = 40491,
      ClearEnvelope = 40065,
      ClearFxChainCurrentTrack = "_S&M_CLRFXCHAIN3",
      ClearFxChainInputCurrentTrack = "_S&M_CLR_INFXCHAIN",
      ClearNoteSelection = {40214, midiCommand=true},
      CloseFloatingFxWindows = "_S&M_WNCLS3",
      CloseProject = 40860,
      CloseWindow = {2, midiCommand=true},
      ColorTrack = 40360,
      ColorTrackGradient = "_SWS_TRACKGRAD",
      ColorTrackWithTrackAbove = "_SWS_COLTRACKPREV",
      ColorTrackWithTrackBelow = "_SWS_COLTRACKNEXT",
      CopyAndFitByLooping = 41319,
      CopyEnvelopePoints = 40324,
      CopyFxChain = "_S&M_SMART_CPY_FXCHAIN",
      CopyItems = {"SaveItemSelection", "OnlySelectItemsCrossingTimeAndTrackSelection", "CopySelectedAreaOfItems", "RestoreItemSelection"},
      CopyNotes = {"SelectNotes", "CopySelectedEvents"},
      CopySelectedAreaOfItems = 40060,
      CopySelectedEvents = {40733, midiCommand=true},
      CopySelectedItems = 40698,
      CopySelEnvelope = 40035,
      CopyTrack = 40210,
      CropToActiveTake = 40131,
      CutEnvelopePoints = 40325,
      CutItems = {"SelectItems", "CutSelectedItems"},
      CutNotes = {"SelectNotes", "CutSelectedEvents"},
      CutSelectedEvents = {40734, midiCommand=true},
      CutSelectedItems = 40699,
      CutTrack = {"CopyTrack", "RemoveTrack", "PrevTrack", "NextTrack"},
      CycleFolderCollapsedState = 1042,
      CycleFolderState = 1041,
      CycleItemFadeInShape = 41520,
      CycleItemFadeOutShape = 41527,
      CycleRecordMonitor = 40495,
      CycleRippleEditMode = 1155,
      DecreaseTrackHeight = 41326,
      DeleteActiveTake = 40129,
      DeleteItem = 40006,
      DeleteNote = {40002, midiCommand=true},
      DeleteRegion = 40615,
      DelSelEnvelope = 40333,
      EnterTrackAbove = {"InsertTrackAbove", "ColorTrackWithTrackBelow", "RenameTrack"},
      EnterTrackBelow = {"InsertTrackBelow", "ColorTrackWithTrackAbove", "RenameTrack"},
      EventSelectionEnd = {40639, midiCommand=true},
      EventSelectionStart = {40440, midiCommand=true},
      FirstItemStart = util.moveToFirstItemStart,
      FirstTrack = {util.firstTrack, "ScrollToSelectedTracks"},
      FitByLooping = 41320,
      FitByLoopingNoShift = 41386,
      FitByPadding = 41385,
      FitByStretching = 41206,
      FitEnvelopePoints = "_BR_FIT_ENV_POINTS_TO_TIMESEL",
      FitNotes = {40754, midiCommand=true},
      FocusMain = "_S&M_WNMAIN",
      FolderParent = {"SelectFolderParent", "ScrollToSelectedTracks"},
      FreezeTrack = 41223,
      FxAdd = "_S&M_CONSOLE_ADDFX",
      FxChainToggleShow = "_S&M_TOGLFXCHAIN",
      FxCloseAll = "_S&M_WNCLS3",
      FxClose = "_S&M_WNCLS5",
      FxShowNextSel = "_S&M_WNONLY2",
      FxShowPrevSel = "_S&M_WNONLY1",
      FxToggleShow1 = "_S&M_TOGLFLOATFX1",
      FxToggleShow2 = "_S&M_TOGLFLOATFX2",
      FxToggleShow3 = "_S&M_TOGLFLOATFX3",
      FxToggleShow4 = "_S&M_TOGLFLOATFX4",
      FxToggleShow5 = "_S&M_TOGLFLOATFX5",
      FxToggleShow6 = "_S&M_TOGLFLOATFX6",
      FxToggleShow7 = "_S&M_TOGLFLOATFX7",
      FxToggleShow8 = "_S&M_TOGLFLOATFX8",
      FxToggleShow = "_S&M_WNTGL5",
      GlueItemIgnoringTimeSelection = 40362,
      GlueItems = {"SelectItems", "GlueSelectedItemsInTimeSelection"},
      GlueSelectedItemsInTimeSelection = 41588,
      GoToEnd = {40037, midiCommand=true},
      GoToStart = {40036, midiCommand=true},
      GroupItems = 40032,
      GrowItemLeft = {"TimeSelectionEnd", "SelectItemsUnderEditCursor", "TimeSelectionStart", "TrimSelectedItemLeftEdgeToEditCursor"},
      GrowItemRight = {"TimeSelectionStart", "SelectItemsUnderEditCursor", "TimeSelectionEnd", "TrimSelectedItemRightEdgeToEditCursor"},
      HealSelectedItemsSplits = 40548,
      HealSplits = {"SaveItemSelection", "OnlySelectItemsCrossingTimeAndTrackSelection", "HealSelectedItemsSplits", "RestoreItemSelection"},
      IncreaseTrackHeight = 41325,
      InnerFolderAndParent = {"FolderParent", "SelectFoldersChildren"},
      InnerFolder = {"FolderParent", "SelectOnlyFoldersChildren"},
      Input = 40496,
      InsertAutomationItem = 42082,
      InsertDefaultSizeNote = {40051, midiCommand=true},
      InsertNote = {"InsertDefaultSizeNote", "FitNotes"},
      InsertRegion = 40174,
      InsertTrack = 40001,
      InsertTrackAbove = "_SWS_INSRTTRKABOVE",
      InsertTrackBelow = 40001,
      InvertVoicingDownwards = {40910, midiCommand=true},
      InvertVoicingUpwards = {40909, midiCommand=true},
      ItemApplyFX = 40209,
      ItemNormalize = 40108,
      ItemSplitSelRight = "_SWS_AWSPLITXFADELEFT",
      Item = util.selectInnerItem,
      JoinNotes = {"SelectNotes", "JoinSelectedNotes"},
      JoinSelectedNotes = {40456, midiCommand=true},
      LastItemEnd = util.moveToLastItemEnd,
      LastTrack = {util.lastTrack, "ScrollToSelectedTracks"},
      Left10Pix = "_XENAKIOS_MOVECUR10PIX_LEFT",
      Left40Pix = {"Left10Pix", repetitions=4},
      LeftByGrid = {40047, midiCommand=true},
      LeftByMeasure = {40683, midiCommand=true},
      LeftPix = 40104,
      MakeFolder = "_SWS_MAKEFOLDER",
      MarkerRegion = {"PrevMarker", "SetTimeSelectionStart", "NextMarker", "SetTimeSelectionEnd", {"UndoMove", repetitions=2}},
      MatchedTrackBackward = {"MatchTrackNameBackward", "ScrollToSelectedTracks"},
      MatchedTrackForward = {"MatchTrackNameForward", "ScrollToSelectedTracks"},
      MatchTrackNameBackward = lib.matchTrackNameBackward,
      MatchTrackNameForward = lib.matchTrackNameForward,
      MidiLearnLastTouchedFX = 41144,
      MidiOutput = 40500,
      MidiOverdub = 40503,
      MidiPaste = {40011, midiCommand=true},
      MidiReplace = 40504,
      MidiTouchReplace = 40852,
      MidiZoomContent = {40466, midiCommand=true},
      MidiZoomInHoriz = {1012, midiCommand=true},
      MidiZoomInVert = {40111, midiCommand=true},
      MidiZoomOutHoriz = {1011, midiCommand=true},
      MidiZoomOutVert = {40112, midiCommand=true},
      MidiZoomSelHorizontal = {40726, midiCommand=true},
      MixerShowHideChildrenOfSelectedTrack = 41665,
      MonitorOnly = 40498,
      Mouse = 40514,
      MouseAndSnap = 40513,
      MoveEditCursorToNextTransientInSelectedItems = 40375,
      MoveEditCursorToPrevTransientInSelectedItems = 40376,
      MoveNoteDownOctave= {40180, midiCommand=true},
      MoveNoteDownSemitone = {40178, midiCommand=true},
      MoveNoteLeft = {40183, midiCommand=true},
      MoveNoteLeftFine = {40181, midiCommand=true},
      MoveNoteRight= {40184, midiCommand=true},
      MoveNoteRightFine = {40182, midiCommand=true},
      MoveNoteUpOctave= {40179, midiCommand=true},
      MoveNoteUpSemitone = {40177, midiCommand=true},
      MoveRedo = "_SWS_EDITCURREDO",
      MoveSelectedItemLeftToEditCursor = 41306,
      MoveSelectedItemRightToEditCursor = 41307,
      MoveToFirstItem = {"_XENAKIOS_SELFIRSTITEMSOFTRACKS", 41173},
      MoveToMouseAndPlay = {"Mouse", "TransportPlay"},
      MoveToMouseAndPlaySnap = {"MouseAndSnap", "TransportPlay"},
      MoveUndo = "_SWS_EDITCURUNDO",
      NewProjectTab = 40859,
      Next10Track = {"NextTrack", repetitions=10},
      Next4Beats = {"NextBeat", repetitions=4},
      Next4Measures = {"NextMeasure", repetitions=4},
      Next5Track = {"NextTrack", repetitions=5},
      NextBeat = 40841,
      NextBigItemEnd = util.moveToNextBigItemEnd,
      NextBigItemStart = util.moveToNextBigItemStart,
      NextEnvelope = 41864,
      NextEnvelopePoint = "_SWS_BRMOVEEDITTONEXTENV",
      NextFolderNear = {"_SWS_SELNEARESTNEXTFOLDER", "ScrollToSelectedTracks"},
      NextItemEnd = util.moveToNextItemEnd,
      NextItemStart = util.moveToNextItemStart,
      NextMarker = 40173,
      NextMeasure = 40839,
      NextNoteEnd = {"SelectNextNote", "EventSelectionEnd"},
      NextNoteSamePitchEnd = {"SelectNextNoteSamePitch", "EventSelectionEnd"},
      NextNoteSamePitchStart = {"SelectNextNoteSamePitch", "EventSelectionStart"},
      NextNoteStart = {"SelectNextNote", "EventSelectionStart"},
      NextRegion = "_SWS_SELNEXTREG",
      NextTab = 40861,
      NextTake = 40125,
      NextTrack = 40285,
      NextTrackMatchBackward = {"RepeatTrackNameMatchBackward", "ScrollToSelectedTracks"},
      NextTrackMatchForward = {"RepeatTrackNameMatchForward", "ScrollToSelectedTracks"},
      NextTransientInItem = {"SaveItemSelection", "SelectItemsUnderEditCursor", "MoveEditCursorToNextTransientInSelectedItems", "RestoreItemSelection"},
      NoOp = 65535,
      OnlySelectItemsCrossingTimeAndTrackSelection = {"UnselectItems", "SelectItemsCrossingTimeAndTrackSelection"},
      OpenMidiEditor = {40153, "MidiZoomContent"},
      OpenProject = 40025,
      PasteAbove = {"PrevTrack", "Paste"},
      PasteFxChain = "_S&M_SMART_PST_FXCHAIN",
      PasteItem = 40058,
      Paste = "_SWS_AWPASTE",
      PitchDown = {40050, midiCommand=true},
      PitchDown7 = {"PitchDown", repetitions=7},
      PitchDownOctave = {40188, midiCommand=true},
      PitchUp = {40049, midiCommand=true},
      PitchUp7 = {"PitchUp", repetitions=7},
      PitchUpOctave = {40187, midiCommand=true},
      PlayFromMouse = "_BR_PLAY_MOUSECURSOR",
      PlayMacro = "PlayMacro",
      PlayPosition = 40434,
      Play = {"TimeSelectionStart", "TransportPlay" , setTimeSelection=true},
      Preferences = 40016,
      Prev10Track = {"PrevTrack", repetitions=10},
      Prev4Beats = {"PrevBeat", repetitions=4},
      Prev4Measures = {"PrevMeasure", repetitions=4},
      Prev5Track = {"PrevTrack", repetitions=5},
      PrevBeat = 40842,
      PrevBigItemStart = util.moveToPrevBigItemStart,
      PrevEnvelope = 41863,
      PrevEnvelopePoint = "_SWS_BRMOVEEDITTOPREVENV",
      PrevFolderNear = {"_SWS_SELNEARESTPREVFOLDER", "ScrollToSelectedTracks"},
      PrevItemStart = util.moveToPrevItemStart,
      PrevMarker = 40172,
      PrevMeasure = 40840,
      PrevNoteEnd = {"SelectPrevNote", "EventSelectionEnd"},
      PrevNoteSamePitchEnd = {"SelectPrevNoteSamePitch", "EventSelectionEnd"},
      PrevNoteSamePitchStart = {"SelectPrevNoteSamePitch", "EventSelectionStart"},
      PrevNoteStart = {"SelectPrevNote", "EventSelectionStart"},
      PrevRegion = "_SWS_SELPREVREG",
      PrevTab = 40862,
      PrevTake = 40126,
      PrevTrack = 40286,
      PrevTransientInItem = {"SaveItemSelection", "SelectItemsUnderEditCursor", "MoveEditCursorToPrevTransientInSelectedItems", "RestoreItemSelection"},
      ProjectEnd = util.moveToProjectEnd,
      ProjectStart = util.moveToProjectStart,
      Project = util.selectInnerProject,
      Quantize = {40009, midiCommand=true},
      RecordMacro = "RecordMacro",
      Redo = 40030,
      RegionSelectItems = 40717,
      RemoveTrack = 40005,
      RenameTrack = 40696,
      RenderProject = 40015,
      RenderProjectWithLastSetting = 41824,
      RenderTrack = "_SWS_AWRENDERSTEREOSMART",
      RepeatLastCommand = "RepeatLastCommand",
      RepeatTrackNameMatchBackward = lib.repeatTrackNameMatchBackward,
      RepeatTrackNameMatchForward = lib.repeatTrackNameMatchForward,
      ResetAllControlSurfaceDevices = 42348,
      ResetAllMidiDevices = 41175,
      ResetControlDevices = {"ResetAllMidiDevices", "ResetAllControlSurfaceDevices"},
      Reset = {"Stop", "SetModeNormal"},
      RestoreItemSelection = "_SWS_RESTALLSELITEMS1",
      RestoreLastItemSelection = "_SWS_RESTLASTSEL",
      RestoreTimeSelectionSlot5 = "_SWS_RESTTIME5",
      RestoreTrackSelection = "_SWS_TOGSAVESEL",
      Right10Pix = "_XENAKIOS_MOVECUR10PIX_RIGHT",
      Right40Pix = {"Right10Pix", repetitions=4},
      RightByGrid = {40048, midiCommand=true},
      RightByMeasure = {40682, midiCommand=true},
      RightPix = 40105,
      RightPixel = 40105,
      SaveItemSelectionAll = "_SWS_SAVEALLSELITEMS1",
      SaveItemSelection = "_SWS_SAVEALLSELITEMS1",
      SaveProject = 40026,
      SaveTimeSelectionSlot5 = "_SWS_SAVETIME5",
      SaveTrackSelection = "_SWS_SAVESEL",
      ScrollToPlayPosition = 40150,
      ScrollToSelectedTracks = 40913,
      SelectAllItems = 40182,
      SelectAllNotesAtPitch = {41746, midiCommand=true},
      SelectAllTracks = 40296,
      SelectedItems = 41039,
      SelectedNotes = {40752, midiCommand=true},
      SelectEnvelopePoints = 40330,
      SelectEventsInTimeSelection = {40876, midiCommand=true},
      SelectFirstOfSelectedTracks = "_XENAKIOS_SELFIRSTOFSELTRAX",
      SelectFolderParent = "_SWS_SELPARENTS",
      SelectFoldersChildren = "_SWS_SELCHILDREN2",
      Selection = "NoOp",
      SelectItemsCrossingTimeAndTrackSelection = 40718,
      SelectItemsInGroups = 40034,
      SelectItems = {"OnlySelectItemsCrossingTimeAndTrackSelection", "SplitAtTimeSelection"},
      SelectItemsOnTrack = 40421,
      SelectItemsUnderEditCursor = "_XENAKIOS_SELITEMSUNDEDCURSELTX",
      SelectLastOfSelectedTracks = "_XENAKIOS_SELLASTOFSELTRAX",
      SelectNextNote = {40413, midiCommand=true},
      SelectNextNoteSamePitch = {40428, midiCommand=true},
      SelectNotes = "SelectNotesStartingInTimeSelection",
      SelectNotesStartingInTimeSelection = {40877, midiCommand=true},
      SelectOnlyFoldersChildren = "_SWS_SELCHILDREN",
      SelectPrevNote = {40414, midiCommand=true},
      SelectPrevNoteSamePitch = {40427, midiCommand=true},
      SelectTrackByNumber = util.selectTrackByNumber,
      SelectTracks = {setTrackSelection=true},
      SetEnvelopeModeLatch = 40404,
      SetEnvelopeModeLatchPreview = 42023,
      SetEnvelopeModeRead = 40401,
      SetEnvelopeModeTouch = 40402,
      SetEnvelopeModeTrimRead = 40400,
      SetEnvelopeModeWrite = 40403,
      SetEnvelopeShapeBezier = 40683,
      SetEnvelopeShapeFastEnd = 40429,
      SetEnvelopeShapeFastStart = 40428,
      SetEnvelopeShapeLinear = 40189,
      SetEnvelopeShapeSlowStart = 40424,
      SetEnvelopeShapeSquare = 40190,
      SetGlobalEnvelopeModeLatch = 40881,
      SetGlobalEnvelopeModeLatchPreview = 42022,
      SetGlobalEnvelopeModeOff = 40876,
      SetGlobalEnvelopeModeRead = 40879,
      SetGlobalEnvelopeModeTouch = 40880,
      SetGlobalEnvelopeModeTrimRead = 40878,
      SetGlobalEnvelopeModeWrite = 40882,
      SetItemFadeBoundaries = {"SelectItemsCrossingTimeAndTrackSelection", "SetSelectedItemFadeBoundaries"},
      SetModeNormal = lib.setModeNormal,
      SetModeVisualTimeline = lib.setModeVisualTimeline,
      SetModeVisualTrack = lib.setModeVisualTrack,
      SetRecordModeToNormal = 40252,
      SetSelectedItemFadeBoundaries = "_SWS_AWFADESEL",
      SetTimeSelectionEnd = 40223,
      SetTimeSelectionStart = 40222,
      SetTrackMidiAllChannels = "_S&M_MIDI_INPUT_ALL_CH",
      ShowActionList = 40605,
      ShowEnvelopeModulationLastTouchedFx = 41143,
      ShowReaperKeysHelp = "ShowReaperKeysHelp",
      ShowRoutingMatrix = 40251,
      ShowTrackFreezeDetails = 41654,
      ShowTrackManager = 40906,
      ShowTrackRouting = 40293,
      ShowWiringDiagram = 42031,
      SnapshotsAddAndName = "_SWSSNAPSHOT_NEWEDIT",
      SnapshotsAddNewAllTracks = "_SWSSNAPSHOT_NEWALL",
      SnapshotsAddNew = "_SWSSNAPSHOT_NEW",
      SnapshotsDeleteCurrent = "_SWSSNAPSHOT_DELCUR",
      SnapshotsOpenWindow = "_SWSSNAPSHOT_OPEN",
      SnapshotsRecallCurrent1 = "_SWSSNAPSHOT_GET",
      SnapshotsRecallCurrent = "_SWSSNAPSHOT_GET",
      SnapshotsRecallNext = "_SWSSNAPSHOT_GET_NEXT",
      SnapshotsRecallPrev = "_SWSSNAPSHOT_GET_PREVIOUS",
      SnapshotsSaveCurrent = "_SWSSNAPSHOT_SAVE",
      SplitAndSelectItemsInRegion = "_S&M_SPLIT11",
      SplitAtTimeSelection = 40061,
      StartOfSel = {40440, midiCommand=true},
      StartStop = 40044,
      Stop = 40667,
      SwitchTimelineSelectionSide = lib.switchTimelineSelectionSide,
      TapTempo = 1134,
      TimeSelectionEnd = 40633,
      TimeSelectionStart = 40632,
      ToggleArmAllEnvelope = "_S&M_TGLARMALLENVS",
      ToggleArmEnvelope = 40863,
      ToggleAutoCrossfade = 40041,
      ToggleCountInBeforePlayback = "_SWS_AWCOUNTPLAYTOG",
      ToggleCountInBeforeRec = "_SWS_AWCOUNTRECTOG",
      ToggleEnvelopePointsMoveWithItems = 40070,
      ToggleFloatingWindows = 41074,
      ToggleLoop = 1068,
      ToggleMetronome = 40364,
      ToggleMidiSnap = {1014, midiCommand=true},
      ToggleMute = 6,
      TogglePanEnvelope = 40407,
      TogglePlaybackAutoScroll = 40036,
      ToggleRecording = 1013,
      ToggleRecordingAutoScroll = 40262,
      ToggleShowAllEnvelope = 41151,
      ToggleShowAllEnvelopeGlobal = 41152,
      ToggleShowEnvelope = 40884,
      ToggleSnap = 1157,
      ToggleSolo = 7,
      ToggleStopAtEndOfTimeSelectionIfNoRepeat = 41834,
      ToggleViewMixer = 40078,
      ToggleVolumeEnvelope = 40406,
      TrackSetInputToMatchFirstSelected = "_SWS_INPUTMATCH",
      TrackToggleFXBypass = 8,
      TrackWithNumber = {"SelectTrackByNumber", "ScrollToSelectedTracks"},
      TransportPause = 1008,
      TransportPlay = 1007,
      TransportRecordOrStop = "_SWS_RECTOGGLE",
      TrimSelectedItemLeftEdgeToEditCursor = 41305,
      TrimSelectedItemRightEdgeToEditCursor = 41311,
      UncollapseFolder = "_SWS_UNCOLLAPSE",
      Undo = 40029,
      UndoMove = "_SWS_EDITCURUNDO",
      UnfreezeTrack = 41644,
      UnmuteAllTracks = 40339,
      UnselectAllEvents = {40214, midiCommand=true},
      UnselectAll = {"UnselectTracks", "UnselectItems"},
      UnselectEnvelopePoints = 40331,
      UnselectItems = 40289,
      UnselectTracks = 40297,
      UnsoloAllTracks = 40340,
      VerticalScrollEnd = "_XENAKIOS_TVPAGEEND",
      VerticalScrollStart = "_XENAKIOS_TVPAGEHOME",
      ViewFxChainInputCurrentTrack = 40844,
      ViewFxChainMaster = 40846,
      ZoomInHoriz = 1012,
      ZoomInVert = 40111,
      ZoomOutHoriz = 1011,
      ZoomOutVert = 40112,
      ZoomProject = 40295,
      ZoomRedo = "_SWS_REDOZOOM",
      ZoomSelHorizontal = 40031,
      ZoomSelVertical = "_SWS_VZOOMFITMIN",
      ZoomSel = {"ZoomSelHorizontal",  "ZoomSelVertical"},
      ZoomUndo = "_SWS_UNDOZOOM",
}

