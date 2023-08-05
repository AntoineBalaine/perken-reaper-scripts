-- @description Paste Rhythm To Pitches
-- @version 0.0.1
-- @author Perken
-- @about
--   # Paste Rhythm to Pitches
--   Mod from Pandabot's excellent [Paste Rhythm](https://forum.cockos.com/showthread.php?t=214231). Difference is, my version doesn't require a special copy action
--   HOW TO USE:
--   - call action from arrange view
--
--   BEHAVIOUR:
--   - assuming all the needed busses are already in the session,
--   - route all tracks with "bus" in name to receive from other tracks with same color
-- @links
--  Perken Scripts repo https://github.com/AntoineBalaine/perken-reaper-scripts
-- @changelog
--   0.0.1 Setup the script

local function getRhythmNoteIndex(rhythmNotes, startingNotePosition, endingNotePosition)
  for i = 1, #rhythmNotes do
    local rhythmNote = rhythmNotes[i]
    local rhythmNotePositions = rhythmNote[1]

    if rhythmNotePositions[1] == startingNotePosition and rhythmNotePositions[2] == endingNotePosition then
      return i
    end
  end

  return nil
end

-- rhythmNote
-- {{startPosition, endPosition}, {channels}, {velocities}}
-- if there are more notes on the destination then get the default channel/velocity
---@alias rhythmNote {{startPosition, endPosition}, {channels}, {velocities}}

---@param take MediaItem_Take
---@return rhythmNote[]
local function getRhythmNotes(take)
  local numberOfNotes = reaper.MIDI_CountEvts(take)
  local rhythmNotes = {}

  for noteIndex = 0, numberOfNotes - 1 do
    local _, _, _, noteStartPositionPPQ, noteEndPositionPPQ, noteChannel, notePitch, noteVelocity =
        reaper.MIDI_GetNote(take, noteIndex)

    if not (noteStartPositionPPQ == 0 and noteEndPositionPPQ == 0) then
      local rhythmNoteIndex = getRhythmNoteIndex(rhythmNotes, noteStartPositionPPQ, noteEndPositionPPQ)

      if rhythmNoteIndex == nil then
        local rhythmNote = {}

        ---@type number[][] @{{startPosition, endPosition} }
        local rhythmNotePositions = {}
        table.insert(rhythmNotePositions, noteStartPositionPPQ)
        table.insert(rhythmNotePositions, noteEndPositionPPQ)

        ---@type number[] {channels}
        local rhythmNoteChannels = {}
        table.insert(rhythmNoteChannels, noteChannel)

        ---@type number[] {velocities}
        local rhythmNoteVelocities = {}
        table.insert(rhythmNoteVelocities, noteVelocity)

        table.insert(rhythmNote, rhythmNotePositions)
        table.insert(rhythmNote, rhythmNoteChannels)
        table.insert(rhythmNote, rhythmNoteVelocities)

        table.insert(rhythmNotes, rhythmNote)
      else
        local rhythmNote = rhythmNotes[rhythmNoteIndex]

        table.insert(rhythmNote[2], noteChannel)
        table.insert(rhythmNote[3], noteVelocity)

        table.insert(rhythmNotes[rhythmNoteIndex], rhythmNote)
      end
    end
  end

  return rhythmNotes
end
local function getExistingNoteIndex(existingNotes, startingNotePosition)
  for i = 1, #existingNotes do
    local existingNote = existingNotes[i]
    local existingNoteStartingPosition = existingNotes[i][1]

    if existingNoteStartingPosition == startingNotePosition then
      return i
    end
  end

  return nil
end
local function getExistingNotes(selectedTake)
  local numberOfNotes = reaper.MIDI_CountEvts(selectedTake)

  local existingNotes = {}

  for noteIndex = 0, numberOfNotes - 1 do
    local _, noteIsSelected, noteIsMuted, noteStartPositionPPQ, noteEndPositionPPQ, noteChannel, notePitch, noteVelocity =
        reaper.MIDI_GetNote(selectedTake, noteIndex)

    local existingNoteIndex = getExistingNoteIndex(existingNotes, noteStartPositionPPQ)

    if existingNoteIndex == nil then
      local existingNote = {}
      table.insert(existingNote, noteStartPositionPPQ)

      local existingNoteChannels = {}
      table.insert(existingNoteChannels, noteChannel)

      local existingNoteVelocities = {}
      table.insert(existingNoteVelocities, noteVelocity)

      local existingNotePitches = {}
      table.insert(existingNotePitches, notePitch)

      table.insert(existingNote, existingNoteChannels)
      table.insert(existingNote, existingNoteVelocities)
      table.insert(existingNote, existingNotePitches)

      table.insert(existingNotes, existingNote)
    else
      local existingNote = existingNotes[existingNoteIndex]

      table.insert(existingNote[2], noteChannel)
      table.insert(existingNote[3], noteVelocity)
      table.insert(existingNote[4], notePitch)

      table.insert(existingNotes[existingNoteIndex], existingNote)
    end
  end

  return existingNotes
end
local function deleteAllNotes(selectedTake)
  local numberOfNotes = reaper.MIDI_CountEvts(selectedTake)

  for noteIndex = numberOfNotes - 1, 0, -1 do
    reaper.MIDI_DeleteNote(selectedTake, noteIndex)
  end
end
local function getNearestSetOfNotePitches(existingNotes, rhythmStartingPosition)
  local nearestSetOfNotePitches = nil
  local minimumPpqDelta = 999999999

  for i = 1, #existingNotes do
    local existingNote = existingNotes[i]

    local existingNoteStartingPosition = existingNote[1]
    local existingNotePitches = existingNote[4]

    local ppqDelta = rhythmStartingPosition - existingNoteStartingPosition

    if ppqDelta >= 0 and ppqDelta <= minimumPpqDelta then
      nearestSetOfNotePitches = existingNotePitches
      minimumPpqDelta = ppqDelta
    end
  end

  if nearestSetOfNotePitches == nil then
    for i = 1, #existingNotes do
      local existingNote = existingNotes[i]

      local existingNoteStartingPosition = existingNote[1]
      local existingNotePitches = existingNote[4]

      local ppqDelta = math.abs(rhythmStartingPosition - existingNoteStartingPosition)

      if ppqDelta <= minimumPpqDelta then
        nearestSetOfNotePitches = existingNotePitches
        minimumPpqDelta = ppqDelta
      end
    end
  end

  return nearestSetOfNotePitches
end
local function getNearestSetOfNoteChannels(existingNotes, rhythmStartingPosition)
  local nearestSetOfNoteChannels = nil
  local minimumPpqDelta = 999999999

  for i = 1, #existingNotes do
    local existingNote = existingNotes[i]

    local existingNoteStartingPosition = existingNote[1]
    local existingNoteChannels = existingNote[2]

    local ppqDelta = rhythmStartingPosition - existingNoteStartingPosition

    if ppqDelta >= 0 and ppqDelta <= minimumPpqDelta then
      nearestSetOfNoteChannels = existingNoteChannels
      minimumPpqDelta = ppqDelta
    end
  end

  if nearestSetOfNoteChannels == nil then
    for i = 1, #existingNotes do
      local existingNote = existingNotes[i]

      local existingNoteStartingPosition = existingNote[1]
      local existingNoteChannels = existingNote[2]

      local ppqDelta = math.abs(rhythmStartingPosition - existingNoteStartingPosition)

      if ppqDelta <= minimumPpqDelta then
        nearestSetOfNoteChannels = existingNoteChannels
        minimumPpqDelta = ppqDelta
      end
    end
  end

  return nearestSetOfNoteChannels
end
local function getCurrentChannel(channelArg)
  if channelArg ~= nil then
    return channelArg
  end

  return 0
end

local function getCurrentVelocity(velocityArg)
  if velocityArg ~= nil then
    return velocityArg
  end

  return 96
end

local function insertMidiNote(selectedTake, startingPositionArg, endingPositionArg, noteChannelArg, notePitchArg,
                              noteVelocityArg)
  local keepNotesSelected = false
  local noteIsMuted = false

  local channel = getCurrentChannel(noteChannelArg)
  local velocity = getCurrentVelocity(noteVelocityArg)

  local noSort = false

  reaper.MIDI_InsertNote(selectedTake, keepNotesSelected, noteIsMuted, startingPositionArg, endingPositionArg, channel,
    notePitchArg, velocity, noSort)
end

local function pasteRhythm(rhythmNotes, mediaItem)
  local selectedTake = reaper.GetActiveTake(mediaItem)

  local existingNotes = getExistingNotes(selectedTake)

  if #existingNotes == 0 then
    return
  end

  deleteAllNotes(selectedTake)

  local previousNoteVelocity

  for i = 1, #rhythmNotes do
    local rhythmNote = rhythmNotes[i]

    local rhythmNoteStartingPosition = rhythmNote[1][1]
    local rhythmNoteEndingPosition = rhythmNote[1][2]

    --local rhythmNoteChannels = rhythmNote[2]

    local notePitches = getNearestSetOfNotePitches(existingNotes, rhythmNoteStartingPosition)
    local noteChannels = getNearestSetOfNoteChannels(existingNotes, rhythmNoteStartingPosition)

    local rhythmNoteVelocities = rhythmNote[3]

    for j = 1, #notePitches do
      local velocity = rhythmNoteVelocities[j]

      if velocity == nil then
        velocity = previousNoteVelocity
      else
        previousNoteVelocity = velocity
      end

      insertMidiNote(selectedTake, rhythmNoteStartingPosition, rhythmNoteEndingPosition, noteChannels[j], notePitches[j],
        velocity)
    end
  end
end

---@alias TakeIdentifier {take:MediaItem_Take, name:string}
---@param item MediaItem
---@return TakeIdentifier[]
local function getItemTakes(item)
  local takes = {}
  local takes_count = reaper.GetMediaItemNumTakes(item)
  for i = 1, takes_count do
    local take = reaper.GetMediaItemTake(item, i - 1)
    local take_name = reaper.GetTakeName(take)
    table.insert(takes, { take = take, name = take_name })
  end
  return takes
end

---@param takes1 TakeIdentifier[]
---@param takes2 TakeIdentifier[]
---@return TakeIdentifier[]
local function findNewTakes(takes1, takes2)
  local new_takes = {}
  for i = 1, #takes2 do
    local new_take = takes2[i]
    local found = false
    for j = 1, #takes1 do
      local old_take = takes1[j]
      if old_take.take == new_take.take then
        found = true
        break
      end
    end
    if not found then
      new_take.idx = i
      table.insert(new_takes, new_take)
    end
  end
  return new_takes
end

function pasteRhythm()
  -- get select item takes
  -- get selected item
  local items = reaper.CountSelectedMediaItems(0)
  if items == 0 then return end
  local item = reaper.GetSelectedMediaItem(0, 0)
  local takes = getItemTakes(item)
  local takes_count = reaper.GetMediaItemNumTakes(item)
  local active_take = reaper.GetActiveTake(item)

  reaper.Main_OnCommand(40603, 0) -- paste item as item takes


  local takes_count2 = reaper.GetMediaItemNumTakes(item)
  if takes_count2 ~= takes_count then
    local takes2 = getItemTakes(item)
    local new_takes = findNewTakes(takes, takes2)

    local new_take = new_takes[1]
    -- local new_take = reaper.GetMediaItemTake(item, takes_count + 1)
    local rhythmNotes = getRhythmNotes(new_take.take)
    reaper.SetActiveTake(active_take)
    pasteRhythm(rhythmNotes, item)
    -- remove new takes
    for i = 1, #new_takes do
      reaper.SetActiveTake(new_takes[i].take)
      reaper.Main_OnCommand(40129, 0) -- delete active take
    end
    reaper.SetActiveTake(active_take)
  end
end

pasteRhythm()
