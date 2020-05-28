return {
  track_motion = {
    ["G"] = "LastTrack",
    ["gg"] = "FirstTrack",
    ["J"] = "NextFolderNear",
    ["K"] = "PrevFolderNear",
    ["/"] = "MatchedTrackForward",
    ["?"] = "MatchedTrackBackward",
    ["n"] = "NextTrackMatchForward",
    [":"] = "TrackWithNumber",
    ["N"] = "NextTrackMatchBackward",
    ["j"] = "NextTrack",
    ["k"] = "PrevTrack",
    ["<C-b>"] = "Prev10Track",
    ["<C-f>"] = "Next10Track",
    ["<C-d>"] = "Next5Track",
    ["<C-u>"] = "Prev5Track",
  },
  visual_track_command = {
    ["o"] = "SwitchTrackSelectionSide",
    ["V"] = "SetModeNormal",
  },
  track_selector = {
    ["V"] = "Selection",
    ["i"] = {"+inner", {
               ["f"] = "InnerFolder",
               ["F"] = "InnerFolderAndParent",
               ["g"] = "AllTracks",
    }},
    ["c"] = "SelectFoldersChildren",
    ["F"] = "SelectFolderParent",
  },
  track_operator = {
      ["z"] = "ZoomTrackSelection",
      ["<C-s>"] = "ToggleShowTracksInMixer",
      ["f"] = "MakeFolder",
      ["d"] = "CutTrack",
      ["a"] = "ArmTracks",
      ["s"] = "SelectTracks",
      ["S"] = "ToggleSolo",
      ["m"] = "ToggleMute",
      ["y"] = "CopyTrack",
      ["<M-C>"] = "ColorTrackGradient",
      ["<M-c>"] = "ColorTrack",
  },
  timeline_operator = {
    ["s"] = "SelectItemsAndSplit",
    ["<M-p>"] = "CopyAndFitByLooping",
    ["<M-s>"] = "SelectEnvelopePoints",
    ["d"] = "CutItems",
    ["y"] = "CopyItems",
    ["<M-d>"] = "CutEnvelopePoints",
    ["<M-y>"] = "CopyEnvelopePoints",
    ["<C-D>"] = "DeleteTimeline",
    ["<M-i>"] = "InsertAutomationItem",
    ["g"] = "GlueItems",
    ["%"] = "HealSplits",
    ["#"] = "SetItemFadeBoundaries",
    ["z"] = "ZoomTimeSelection",
    ["c"] = {"+change/fit selected", {
            ["f"] = "FitByLoopingNoShift",
            ["l"] = "FitByLooping",
            ["p"] = "FitByPadding",
            ["s"] = "FitByStretching",
    }},
    ["i"] = "InsertOrExtendMidiItem",
  },
  timeline_selector = {
    ["s"] = "SelectedItems",
    ["<M-s>"] = "AutomationItem",
  },
  timeline_motion = {
    ["B"] = "PrevBigItemStart",
    ["E"] = "NextBigItemEnd",
    ["W"] = "NextBigItemStart",
    ["b"] = "PrevItemStart",
    ["<CM-l>"] = "NextTransientInItem",
    ["<CM-h>"] = "PrevTransientInItem",
    ["<M-b>"] = "PrevEnvelopePoint",
    ["e"] = "NextItemEnd",
    ["w"] = "NextItemStart",
    ["<M-w>"] = "NextEnvelopePoint",
    ["<C-a>"] = "FirstItemStart",
    ["$"] = "LastItemEnd",
  },
  command = {
    ["S"] = "SelectItemsUnderEditCursor",
    ["<TAB>"] = "CycleFolderCollapsedState",
    ["zp"] = "ZoomProject",
    ["D"] = "CutSelectedItems",
    ["Y"] = "CopySelectedItems",
    ["V"] = "SetModeVisualTrack",
    ["<M-j>"] = "NextEnvelope",
    ["<M-k>"] = "PrevEnvelope",
    ["<C-+>"] = "ZoomInHoriz",
    ["<C-->"] = "ZoomOutHoriz",
    ["+"] = "ZoomInVert",
    ["-"] = "ZoomOutVert",
    ["<C-m>"] = "TapTempo",
    ["dd"] = "CutTrack",
    ["aa"] = "ArmTracks",
    ["O"] = "EnterTrackAbove",
    ["o"] = "EnterTrackBelow",
    ["p"] = "Paste",
    ["P"] = "PasteAbove",
    ["yy"] = "CopyTrack",
    ["zz"] = "ScrollToSelectedTracks",
  },
}
