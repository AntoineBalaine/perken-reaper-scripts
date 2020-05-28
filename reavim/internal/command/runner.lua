local definitions = require('utils.definitions')
local getAction = require('utils.get_action')
local log = require('utils.log')
local format = require('utils.format')
local state_functions = require('state_machine.state_functions')

local runner = {}

function runSubAction(id, midi_command)
  if type(id) == "function" then
    id()
    return
  end

  local numeric_id = id
  if type(id) == 'string' then
    local action = getAction(id)
    if action then
      runner.runAction(action)
      return
    end

    numeric_id = reaper.NamedCommandLookup(id)
    if numeric_id == 0 then
      log.fatal("Could not find action in reaper or action list for: " .. id)
      return
    end
  end

  if midi_command then
    reaper.MIDIEditor_LastFocused_OnCommand(numeric_id, false)
  else
    reaper.Main_OnCommand(numeric_id, 0)
  end
end

function runner.runAction(action)
  local sub_actions = action
  if type(action) ~= 'table' then
    runSubAction(action, false)
    return
  end

  local repetitions = 1
  if sub_actions['repetitions'] then
    repetitions = action['repetitions']
  end

  local midi_command = false
  if sub_actions['midiCommand'] then
    midi_command = sub_actions['midiCommand']
  end

  log.trace("running action: " .. format.block(sub_actions))

  for i=1,repetitions do
    for _, sub_action in ipairs(sub_actions) do
      if type(sub_action) == 'table' then
        runner.runAction(sub_action)
      else
        runSubAction(sub_action, midi_command)
      end
    end
  end
end

function runner.runActionNTimes(action, times)
  for i=1,times,1 do
    runner.runAction(action)
  end
end

function runner.makeSelectionFromTimelineMotion(timeline_motion, repetitions)
  local sel_start = reaper.GetCursorPosition()
  runner.runActionNTimes(timeline_motion, repetitions)
  local sel_end = reaper.GetCursorPosition()
  reaper.SetEditCurPos(sel_start, false, false)

  reaper.GetSet_LoopTimeRange(true, false, sel_start, sel_end, false)
end

function runner.extendTimelineSelection(movement, args)
  local left, right = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if not left or not right then
    left, right = start_pos, end_pos
  end

  local start_pos = reaper.GetCursorPosition()
  movement(table.unpack(args))
  local end_pos = reaper.GetCursorPosition()

  if state_functions.getTimelineSelectionSide() == 'right' then
    if end_pos <= left then
      state_functions.setTimelineSelectionSide('left')
      reaper.GetSet_LoopTimeRange(true, false, end_pos, left, false)
    else
      reaper.GetSet_LoopTimeRange(true, false, left, end_pos, false)
    end
  else
    if end_pos >= right then
      state_functions.setTimelineSelectionSide('right')
      reaper.GetSet_LoopTimeRange(true, false, right, end_pos, false)
    else
      reaper.GetSet_LoopTimeRange(true, false, end_pos, right, false)
    end
  end
end

function runner.extendTrackSelection(movement, args)
  movement(table.unpack(args))
  local end_pos = runner.getTrackPosition()
  local pivot_i = state_functions.getVisualTrackPivotIndex()

  runner.runAction("UnselectTracks")

  local i = end_pos
  while pivot_i ~= i do
    local track = reaper.GetTrack(0, i)
    reaper.SetTrackSelected(track, true)

    if pivot_i > i then
      i = i + 1
    else
      i = i - 1
    end
  end

  local pivot_track = reaper.GetTrack(0, pivot_i)
  reaper.SetTrackSelected(pivot_track, true)
end

-- reaper provides no function to get the current 'track cursor' position but it
-- is implicitly contained in which track is selected when we do and up down
-- motion
function runner.getTrackPosition()
  local selected_tracks = {}
  for i=0,reaper.CountSelectedTracks()-1 do
    local track = reaper.GetSelectedTrack(0, i)
    selected_tracks[i] = track
  end

  runner.runAction("UnselectTracks")
  runner.runAction("SelectLastTouchedTrack")

  local track_at_index = reaper.GetSelectedTrack(0, 0)
  local index = reaper.GetMediaTrackInfo_Value(track_at_index, "IP_TRACKNUMBER") - 1

  runner.runAction("UnselectTracks")
  for _,track in ipairs(selected_tracks) do
    reaper.SetTrackSelected(track, true)
  end

  return index
end

function runner.makeSelectionFromTrackMotion(track_motion, repetitions)
  local first_index = runner.getTrackPosition()
  runner.runActionNTimes(track_motion, repetitions)
  local end_track = reaper.GetSelectedTrack(0, 0)
  if not end_track then
    return
  end

  local second_index = reaper.GetMediaTrackInfo_Value(end_track, "IP_TRACKNUMBER") - 1

  if first_index > second_index then
    local swp = second_index
    second_index = first_index
    first_index = swp
  end

  for i=first_index,second_index do
    local track = reaper.GetTrack(0, i)
    reaper.SetTrackSelected(track, true)
  end
end

return runner
