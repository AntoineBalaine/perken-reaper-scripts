return {
  timeline_motion = {
    ["0"] = "ProjectStart",
    ["<C-$>"] = "ProjectEnd",
    ["f"] = "PlayPosition",
    ["x"] = "MousePosition",
    ["["] = "LoopStart",
    ["]"] = "LoopEnd",
    ["<left>"] = "PrevMarker",
    ["<right>"] = "NextMarker",
    ["<M-left>"] = "PrevTimeSignatureMarker",
    ["<M-right>"] = "NextTimeSignatureMarker",
    ["<M-h>"] = "Left10Pix",
    ["<M-l>"] = "Right10Pix",
    ["<M-H>"] = "Left40Pix",
    ["<M-L>"] = "Right40Pix",
    ["h"] = "LeftGridDivision",
    ["l"] = "RightGridDivision",
    ["H"] = "PrevMeasure",
    ["L"] = "NextMeasure",
    ["<S-right>"] = "NextMeasure",
    ["<S-left>"] = "PrevMeasure",
    ["<C-i>"] = "MoveRedo",
    ["<C-o>"] = "MoveUndo",
    ["<C-h>"] = "Prev4Beats",
    ["<C-l>"] = "Next4Beats",
    ["<C-H>"] = "Prev4Measures",
    ["<C-L>"] = "Next4Measures",
    ["`"] = "MarkedTimelinePosition",
  },
  timeline_operator = {
    ["r"] = "Record",
    ["<C-p>"] = "DuplicateTimeline",
    ["t"] = "PlayAndLoop",
    ["|"] = "CreateMeasures",
    ["<C-|>"] = "CreateProjectTempo"
  },
  timeline_selector = {
    ["~"] = "MarkedRegion",
    ["!"] = "LoopSelection",
    ["<S-right>"] = "NextRegion",
    ["<S-left>"] = "PrevRegion",
    ["<CS-right>"] = "TimeSelectionShiftedRight",
    ["<CS-left>"] = "TimeSelectionShiftedLeft",
    ["i"] = {"+inner", {
               ["<M-w>"] = "AutomationItem",
               ["l"] = "AllTrackItems",
               ["r"] = "Region",
               ["p"] = "ProjectTimeline",
               ["w"] = "Item",
               ["W"] = "BigItem",
    }},
  },
  visual_timeline_command = {
    ["v"] = "SetModeNormal",
    ["o"] = "SwitchTimelineSelectionSide",
  },
  command = {
    ["."] = "RepeatLastCommand",
    ["@"] = "PlayMacro",
    [","] = "RecordMacro",
    ["m"] = "Mark",
    ["~"] = "MarkedRegion",
    ["<C-'>"] = "DeleteMark",
    ["<S-right>"] = "NextRegion",
    ["<S-left>"] = "PrevRegion",
    ["<C-r>"] = "Redo",
    ["u"] = "Undo",
    ["R"] = "ToggleRecord",
    ["T"] = "Play",
    ["<C-T>"] = "PlayAndSkipTimeSelection",
    ["<M-t>"] = "PlayFromMousePosition",
    ["<M-T>"] = "PlayFromMouseAndSoloTrack",
    ["<C-t>"] = "PlayFromEditCursorAndSoloTrackUnderMouse",
    ["tt"] = "PlayFromTimeSelectionStart",
    ["F"] = "Pause",
    ["<C-z>"] = "ZoomUndo",
    ["<C-Z>"] = "ZoomRedo",
    ["v"] = "SetModeVisualTimeline",
    ["<M-v>"] = "ClearTimelineSelectionAndSetModeVisualTimeline",
    ["<C-SPC>"] = "ToggleViewMixer",
    ["<ESC>"] = "Reset",
    ["<return>"] = "StartStop",
    -- ["X"] = "MoveToMousePositionAndPlay",
    ["dr"] = "RemoveRegion",
    ["!"] = "ToggleLoop",
    ["<C-a>"] = "ToggleBetweenReadAndTouchAutomationMode",
    ["<M-n>"] = "ShowNextFx",
    ["<M-N>"] = "ShowPrevFx",
    ["<M-g>"] = "FocusMain",
    ["<M-f>"] = "ToggleShowFx",
    ["<M-F>"] = "CloseFx",
    ["<CM-f>"] = "MidiLearnLastTouchedFxParam",
    ["<CM-m>"] = "ModulateLastTouchedFxParam",
    ["<M-x>"] = "ShowBindingList",
    ["<C-m>"] = "TapTempo",
    ['"'] = {"+snapshots", {
            ["j"] = "RecallNextSnapshot",
            ["k"] = "RecallPreviousSnapshot",
            ["D"] = "DeleteAllSnapshots",
            ["t"] = "ToggleSnapshotsWindow",
            ["y"] = "CopyCurrentSnapshot",
            ["p"] = "PasteSnapshot",
            ["r"] = "RecallCurrentSnapshot",
            ["#"] = {"+recall #", {
                        ["1"] = "RecallSnapshot1",
                        ["2"] = "RecallSnapshot2",
                        ["3"] = "RecallSnapshot3",
                        ["4"] = "RecallSnapshot4",
                        ["5"] = "RecallSnapshot5",
                        ["6"] = "RecallSnapshot6",
                        ["7"] = "RecallSnapshot7",
                        ["8"] = "RecallSnapshot8",
                        ["9"] = "RecallSnapshot9",
            }},
    }},
    ["q"] = {"+options", {
               ["p"] = "TogglePlaybackPreroll",
               ["r"] = "ToggleRecordingPreroll",
               ["z"] = "TogglePlaybackAutoScroll",
               ["v"] = "ToggleLoopSelectionFollowsTimeSelection",
               ["s"] = "ToggleSnap",
               ["m"] = "ToggleMetronome",
               ["t"] = "ToggleStopAtEndOfTimeSelectionIfNoRepeat",
               ["x"] = "ToggleAutoCrossfade",
               ["e"] = "ToggleEnvelopePointsMoveWithItems",
               ["c"] = "CycleRippleEditMode",
               ["f"] = "ResetFeedbackWindow",
    }},
    ["<SPC>"] = { "+leader commands", {
      ["<SPC>"] = "ShowActionList",
      ["z"] = { "+zoom/scroll", {
                  ["t"] = "ScrollToPlayPosition",
                  ["e"] = "ScrollToEditCursor",
      }},
      ["m"] = { "+midi", {
                  ["g"] = "SetMidiGridDivision",
                  ["q"] = "Quantize",
                  [","] = {"+options", {
                             ["g"] = "ToggleMidiEditorUsesMainGridDivision",
                             ["s"] = "ToggleMidiSnap",
                  }},
      }},
      ["r"] = { "+recording", {
                  ["o"] = "SetRecordMidiOutput",
                  ["d"] = "SetRecordMidiOverdub",
                  ["t"] = "SetRecordMidiTouchReplace",
                  ["R"] = "SetRecordMidiReplace",
                  ["v"] = "SetRecordMonitorOnly",
                  ["r"] = "SetRecordInput",
                  [","] = {"+options", {
                             ["n"] = "SetRecordModeNormal",
                             ["s"] = "SetRecordModeItemSelectionAutoPunch",
                             ["v"] = "SetRecordModeTimeSelectionAutoPunch",
                             ["p"] = "ToggleRecordingPreroll",
                             ["z"] = "ToggleRecordingAutoScroll",
                             ["t"] = "ToggleRecordToTapeMode",
                  }},
      }},
      ["a"] = { "+automation", {
                  ["r"] = "SetAutomationModeTrimRead",
                  ["R"] = "SetAutomationModeRead",
                  ["l"] = "SetAutomationModeLatch",
                  ["g"] = "SetAutomationModeLatchAndArm",
                  ["p"] = "SetAutomationModeLatchPreview",
                  ["t"] = "SetAutomationModeTouch",
                  ["w"] = "SetAutomationModeWrite",
      }},
      ["s"] = { "+selected items", {
                  ["j"] = "NextTake",
                  ["k"] = "PrevTake",
                  ["m"] = "ToggleMuteItem",
                  ["d"] = "DeleteActiveTake",
                  ["c"] = "CropToActiveTake",
                  ["o"] = "OpenInMidiEditor",
                  ["n"] = "ItemNormalize",
                  ["g"] = "GroupItems",
                  ["q"] = "QuantizeItems",
                  ["h"] = "HealItemsSplits",
                  ["s"] = "ToggleSoloItem",
                  ["b"] = "MoveItemContentToEditCursor",
                  ["x"] = {"+explode takes", {
                             ["p"] = "ExplodeTakesInPlace",
                             ["o"] = "ExplodeTakesInOrder",
                             ["a"] = "ExplodeTakesInAcrossTracks"
                  }},
                  ["S"] = {"+stretch", {
                             ["a"] = "AddStretchMarker",
                             ["d"] = "DeleteStretchMarker",
                  }},
                  ["#"] = {"+fade", {
                             ["i"] = "CycleItemFadeInShape",
                             ["o"] = "CycleItemFadeOutShape",
                  }},
                  ["t"] = {"+transients", {
                             ["a"] = "AdjustTransientDetection",
                             ["t"] = "CalculateTransientGuides",
                             ["c"] = "ClearTransientGuides",
                             ["s"] = "SplitItemAtTransients"
                  }},
                  ["e"] = {"+envelopes", {
                             ["s"] = "ViewTakeEnvelopes",
                             ["m"] = "ToggleTakeMuteEnvelope",
                             ["p"] = "ToggleTakePanEnvelope",
                             ["P"] = "ToggleTakePitchEnvelope",
                             ["v"] = "ToggleTakeVolumeEnvelope",
                  }},
                  ["f"] = {"+fx", {
                             ["a"] = "ApplyFxToItem",
                             ["p"] = "PasteItemFxChain",
                             ["d"] = "CutItemFxChain",
                             ["y"] = "CopyItemFxChain",
                             ["c"] = "ToggleShowTakeFxChain",
                             ["b"] = "ToggleTakeFxBypass",
                  }},
                  ["r"] = {"+rename", {
                             ["s"] = "RenameTakeSourceFile",
                             ["t"] = "RenameTake",
                             ["r"] = "RenameTakeAndSourceFile",
                             ["a"] = "AutoRenameTake",
                  }},
                  ["b"] = { "+timebase", {
                              ["t"] = "SetItemsTimebaseToTime",
                              ["b"] = "SetItemsTimebaseToBeatsPos",
                              ["r"] = "SetItemsTimebaseToBeatsPosLengthAndRate",
                  }},
      }},
      ["t"] = { "+track", {
                  ["n"] = "ResetTrackToNormal",
                  ["R"] = "RenderTrack",
                  ["r"] = "RenameTrack",
                  ["z"] = "MinimizeTracks",
                  ["m"] = "CycleRecordMonitor",
                  ["f"] = "CycleFolderState",
                  ["i"] = "SetTrackInputToMatchFirstSelected",
                  ["y"] = "SaveTrackAsTemplate",
                  ["i"] = {"+insert", {
                             ["c"] = "InsertClickTrack",
                             ["t"] = "InsertTrackFromTemplate",
                             ["v"] = "InsertVirtualInstrumentTrack",
                             ["1"] = "InsertTrackFromTemplateSlot1",
                             ["2"] = "InsertTrackFromTemplateSlot2",
                             ["3"] = "InsertTrackFromTemplateSlot3",
                             ["4"] = "InsertTrackFromTemplateSlot4",
                  }},
                  ["x"] = {"+routing", {
                            ["p"] = "TrackToggleSendToParent",
                            ["s"] = "ToggleShowTrackRouting",
                  }},
                  ["F"] = { "+freeze", {
                            ["f"] = "FreezeTrack",
                            ["u"] = "UnfreezeTrack",
                            ["s"] = "ShowTrackFreezeDetails",
                  }},
      }},
      ["e"] = {"+envelopes", {
                 ["t"]  = "ToggleShowAllEnvelope",
                 ["a"] = "ToggleArmAllEnvelopes",
                 ["A"] = "UnarmAllEnvelopes",
                 ["d"] = "ClearAllEnvelope",
                 ["v"] = "ToggleVolumeEnvelope",
                 ["p"] = "TogglePanEnvelope",
                 ["w"] = "SelectWidthEnvelope",
                 ["s"] = {"+selected", {
                            ["d"] = "ClearEnvelope",
                            ["a"] = "ToggleArmEnvelope",
                            ["y"] = "CopyEnvelope",
                            ["t"] = "ToggleShowSelectedEnvelope",
                            ["b"] = "ToggleEnvelopeBypass",
                            ["s"] = {"+shape", {
                                       ["b"] = "SetEnvelopeShapeBezier",
                                       ["e"] = "SetEnvelopeShapeFastEnd",
                                       ["f"] = "SetEnvelopeShapeFastStart",
                                       ["l"] = "SetEnvelopeShapeLinear",
                                       ["s"] = "SetEnvelopeShapeSlowStart",
                                       ["S"] = "SetEnvelopeShapeSquare",
                            }},
                 }},
      }},
      ["f"] = { "+fx", {
                  ["a"] = "AddFx",
                  ["c"] = "ToggleShowFxChain",
                  ["d"] = "CutFxChain",
                  ["y"] = "CopyFxChain",
                  ["p"] = "PasteFxChain",
                  ["b"] = "ToggleFxBypass",
                  ["i"] = {"+input", {
                             ["s"] = "ToggleShowInputFxChain",
                             ["d"] = "CutInputFxChain",
                  }},
                  ["s"] = {"+show", {
                             ["1"] = "ToggleShowFx1",
                             ["2"] = "ToggleShowFx2",
                             ["3"] = "ToggleShowFx3",
                             ["4"] = "ToggleShowFx4",
                             ["5"] = "ToggleShowFx5",
                             ["6"] = "ToggleShowFx6",
                             ["7"] = "ToggleShowFx7",
                             ["8"] = "ToggleShowFx8"
                  }},
      }},
      ["T"] = { "+timeline", {
                  ["a"] = "AddTimeSignatureMarker",
                  ["e"] = "EditTimeSignatureMarker",
                  ["d"] = "DeleteTimeSignatureMarker",
                  ["s"] = "ToggleShowTempoEnvelope"
      }},
      ["g"] = { "+global", {
                  ["g"] = "SetGridDivision",
                  ["r"] = "ResetControlDevices",
                  [","] = "ShowPreferences",
                  ["S"] = "UnsoloAllItems",
                  ["s"] = {"+show/hide", {
                             ["x"] = "ToggleShowRoutingMatrix",
                             ["w"] = "ToggleShowWiringDiagram",
                             ["t"] = "ToggleShowTrackManager",
                             ["m"] = "ShowMasterTrack",
                             ["M"] = "HideMasterTrack",
                             ["r"] = "ToggleShowRegionMarkerManager",
                  }},
                  ["f"] = {"+fx", {
                             ["x"] = "CloseAllFxChainsAndWindows",
                             ["c"] = "ViewFxChainMaster",
                  }},
                  ["e"] = { "+envelope", {
                            ["t"] = "ToggleShowAllEnvelopeGlobal",
                  }},
                  ["t"] = { "+track", {
                            ["R"] = "RenderTrack",
                            ["r"] = "RenameTrack",
                            ["m"] = "CycleRecordMonitor",
                            ["f"] = "CycleFolderState",
                            ["y"] = "SaveTrackAsTemplate",
                            ["p"] = "InsertTrackFromTemplate",
                            ["1"] = "InsertTrackFromTemplateSlot1",
                            ["2"] = "InsertTrackFromTemplateSlot2",
                            ["3"] = "InsertTrackFromTemplateSlot3",
                            ["4"] = "InsertTrackFromTemplateSlot4",
                            ["c"] = "InsertClickTrack",
                            ["v"] = "InsertVirtualInstrumentTrack",
                            ["x"] = {"+routing", {
                                      ["p"] = "TrackToggleSendToParent",
                                      ["s"] = "ToggleShowTrackRouting",
                            }},
                            ["F"] = { "+freeze", {
                                      ["f"] = "FreezeTrack",
                                      ["u"] = "UnfreezeTrack",
                                      ["s"] = "ShowTrackFreezeDetails",
                            }},
                  }},
                  ["a"] = { "+automation", {
                              ["r"] = "SetGlobalAutomationModeTrimRead",
                              ["l"] = "SetGlobalAutomationModeLatch",
                              ["p"] = "SetGlobalAutomationModeLatchPreview",
                              ["t"] = "SetGlobalAutomationModeTouch",
                              ["R"] = "SetGlobalAutomationModeRead",
                              ["w"] = "SetGlobalAutomationModeWrite",
                              ["S"] = "SetGlobalAutomationModeOff",
                  }},
      }},
      ["p"] = { "+project", {
                  [","] = "ShowProjectSettings",
                  ["n"] = "NextTab",
                  ["p"] = "PrevTab",
                  ["s"] = "SaveProject",
                  ["o"] = "OpenProject",
                  ["c"] = "NewProjectTab",
                  ["x"] = "CloseProject",
                  ["C"] = "CleanProjectDirectory",
                  ["S"] = "SaveProjectWithNewVersion",
                  ["t"] = { "+timebase", {
                              ["t"] = "SetProjectTimebaseToTime",
                              ["b"] = "SetProjectTimebaseToBeatsPos",
                              ["r"] = "SetProjectTimebaseToBeatsPosLengthAndRate",
                  }},
                  ["r"] = { "+render", {
                              ["."] = "RenderProjectWithLastSetting",
                              ["r"] = "RenderProject",
                  }},
      }},
    }},
  },
}
