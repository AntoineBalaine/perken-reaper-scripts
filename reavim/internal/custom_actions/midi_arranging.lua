local midi = require("custom_actions.midi")
local Table = require("public.table")
local String = require("public.string")

local midi_arranging = {}

---@alias Sysexevt {retval: boolean, selected: boolean|nil, muted: boolean|nil, ppqpos: integer|nil, type: string|nil, msg: string|nil}
---@alias Note {retval: boolean, selected: boolean, muted: boolean, startppqpos: number, endppqpos: number, chan: integer, pitch: integer, vel: integer, idx?: integer, note_tags?: string[]}

---@param val boolean | nil
local function formatBool(val)
  if val == true then
    return "true"
  elseif val == false then
    return "false"
  else
    return "nil"
  end
end

---@return Note[], MediaItem_Take, HWND
local function getNotes()
  ---@type Note[]
  local note_table = {}
  local notes, take, midi_editor = midi.listNotes()
  for note_idx = 0, notes - 1 do
    local retval, sel, muted, start, end_, chan, pitch, velo = reaper.MIDI_GetNote(take, note_idx)
    table.insert(note_table,
      {
        retval = retval,
        selected = sel,
        muted = muted,
        startppqpos = start,
        endppqpos = end_,
        chan = chan,
        pitch = pitch,
        vel = velo,
        idx = note_idx
      })
  end
  return note_table, take, midi_editor
end

---@param s Sysexevt
local function printSysexEvt(s)
  reaper.ShowConsoleMsg("selected: " .. formatBool(s.selected) .. " ")
  reaper.ShowConsoleMsg("muted: " .. formatBool(s.muted) .. " ")
  reaper.ShowConsoleMsg("ppqpos: " .. s.ppqpos .. " ")
  reaper.ShowConsoleMsg("type_int: " .. s.type .. " ")
  reaper.ShowConsoleMsg("msg: " .. s.msg .. " ")
  reaper.ShowConsoleMsg("\n")
end


---@return Sysexevt[]
local function getSysexEvts()
  ---@type Sysexevt[]
  local sysexevts = {}
  local _, take, _ = midi.listNotes()
  local _, _, _, textsyxevtcnt = reaper.MIDI_CountEvts(take)
  for syxevt = 0, textsyxevtcnt - 1 do
    local retval, selected, muted, ppqpos, type, msg = reaper.MIDI_GetTextSysexEvt(take, syxevt)
    table.insert(sysexevts,
      { retval = retval, selected = selected, muted = muted, ppqpos = ppqpos, type = type, msg = msg })
  end
  return sysexevts
end

--[[
get all the instrument tags
get all the notes that carry each tag and add them to a table
  a note might have multiple tags, so don't remove notes from the notes table
assign a midi channel to each tag
assign the midi channel to each note of each tag
if a note has multiple tags, copy the note accross its tag

]]

---get text ornaments for selected notes
function midi_arranging.getNotesTags()
  local notes, take, midi_editor = getNotes()
  ---@type table<string, Note[]>
  local tags = {}
  Table.forEach(getSysexEvts(),
    ---@param sysexevt Sysexevt
    function(sysexevt)
      -- printSysexEvt(sysexevt)
      local msg = sysexevt.msg
      if msg then
        local start_note, _, _ = msg:find("NOTE")
        local start_text, _, _ = msg:find("text")
        if start_note and start_text then
          -- remove "text" prefix, trim whitespace, remove any double quotes from string
          local text_ornament = msg:sub(start_text):gsub("text", ""):gsub("^%s+", ""):gsub("%s+$", ""):gsub('"', "")
          local note_tags = String.split(text_ornament, " ")
          --=============
          local note_str = msg:sub(start_note, start_text - 1):gsub("NOTE", ""):gsub("^%s+", ""):gsub("%s+$", "")
          local note_info = String.split(note_str, " ")
          ---@type string, string
          local chan, pitch = table.unpack(note_info)
          local ppqpos = sysexevt.ppqpos

          for note_idx, note in ipairs(notes) do
            if note.startppqpos == ppqpos and tostring(note.pitch) == pitch and tostring(note.chan) == chan then
              if #note_tags > 1 then note.note_tags = note_tags end
              Table.forEach(note_tags, function(tag)
                if not tags[tag] then
                  tags[tag] = {}
                end
                table.insert(tags[tag], note)
              end)
              table.remove(notes, note_idx)
              break
            end
          end
        end
      end
    end)
  return tags, take
end

local function arrayContains(table, value)
  for _, v in ipairs(table) do
    if v == value then
      return true
    end
  end
  return false
end

---@param tags table<string, Note[]>
---@param take MediaItem_Take
local function assignOneChannelPerTag(tags, take)
  local past_tags = {}
  local channel = 0

  for tag, notes in pairs(tags) do
    Table.forEach(notes,
      ---@param note Note
      function(note)
        local should_copy = Table.find(past_tags,
          function(past_tag)
            return note.note_tags ~= nil and #note.note_tags > 1 and arrayContains(note.note_tags, past_tag)
          end)

        if note.note_tags and #note.note_tags > 1 and should_copy then
          -- [[ if current note contains one of the past tags, then copy the note, instead of just setting it.]]
          reaper.MIDI_InsertNote(take, note.selected, note.muted, note.startppqpos, note.endppqpos, channel, note
            .pitch,
            note.vel, true)
          -- create a sysex event for the tag of current note

          reaper.MIDI_InsertTextSysexEvt(take, false, false, note.startppqpos, 15,
            "NOTE " .. channel .. " " .. note.pitch .. " text " .. tag .. " ")
        else
          -- set midi channel of note
          reaper.MIDI_SetNote(
            take,
            note.idx,
            note.selected,
            note.muted,
            note.startppqpos,
            note.endppqpos,
            channel,
            note.pitch,
            note.vel,
            true)
        end
      end)
    channel = channel + 1
    table.insert(past_tags, tag)
  end

  reaper.MIDI_Sort(take)
end

---@param tracknumber number
local function getTrackIndex(tracknumber)
  local trackCount = reaper.CountTracks(0) -- Get the total number of tracks in the project

  for i = 0, trackCount - 1 do
    local t = reaper.GetTrack(0, i)
    if t then
      local cur_tr_num = reaper.GetMediaTrackInfo_Value(t, "IP_TRACKNUMBER")
      if cur_tr_num == tracknumber then
        return i
      end
    end
  end
  return nil
end


---@param tags table<string, Note[]>
---@param take MediaItem_Take
local function assignOneTrackPerTag(tags, take)
  local past_tags = {}
  local channel = 0

  for tag, notes in pairs(tags) do
    --[[ for each tag, create a new track,
        create a new item of same length as current item
        copy all the notes of the tag to the new track's item,
        ]]

    local track = reaper.GetMediaItemTake_Track(take)                           -- duplicate track
    local trackNumber = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER") -- get track number
    local trackIndex = getTrackIndex(trackNumber)
    reaper.InsertTrackAtIndex(trackIndex + 1, true)                             -- insert new track (duplicate)
    local new_tr = reaper.GetTrack(0, trackIndex + 1)                           -- get new track

    local itm = reaper.GetMediaItemTake_Item(take)
    local takeLength = reaper.GetMediaItemInfo_Value(itm, "D_LENGTH")                                   -- get current item length and position
    local takePosition = reaper.GetMediaItemInfo_Value(itm, "D_POSITION")                               -- Get the position of the take in seconds

    reaper.GetSetMediaTrackInfo_String(new_tr, "P_NAME", tag, true)                                     -- rename new track to tag

    local newMIDIItem = reaper.CreateNewMIDIItemInProj(new_tr, takePosition, takePosition + takeLength) -- create item of same length and position on new track
    local newTake = reaper.GetActiveTake(newMIDIItem)                                                   -- get take of new item

    -- copy all notes of tag to new item
    Table.forEach(notes,
      ---@param note Note
      function(note)
        reaper.MIDI_InsertNote(newTake, note.selected, note.muted, note.startppqpos, note.endppqpos, note.chan, note
          .pitch,
          note.vel, true)
      end)
    reaper.MIDI_Sort(newTake)

    channel = channel + 1
    table.insert(past_tags, tag)
  end
end


---needs re-work - part of the channels are not getting assigned correctly
---and some of the notes are being accidentally removed.
function midi_arranging.assignOneChannelPerTag()
  local tags, take = midi_arranging.getNotesTags()
  assignOneChannelPerTag(tags, take)
end

function midi_arranging.assignOneTrackPerTag()
  local tags, take = midi_arranging.getNotesTags()
  assignOneTrackPerTag(tags, take)
end

return midi_arranging
