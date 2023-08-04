  -- @noindex
  
local info = debug.getinfo(1, "S")

local internal_root_path = info.source:match(".*perken.midi."):sub(2)

local windows_files = internal_root_path:match("\\$")
if windows_files then
  package.path = package.path .. ";" .. internal_root_path .. "dependencies\\?.lua"
else
  package.path = package.path .. ";" .. internal_root_path .. "dependencies/?.lua"
end

local Table = require("scythe_table")

local kawa = {}
--[[
* ReaScript Name: kawa_MIDI_SelectBottomNotes.
* Version: 2017/02/03
* Author: kawa_
* Author URI: http://forum.cockos.com/member.php?u=105939
* link: https://bitbucket.org/kawaCat/reascript-m2bpack/
--]]

---@alias KawaNote {selection: boolean, mute: boolean, startQn: number, endQn: number, chan: number, pitch: number, vel: number, take: MediaItem_Take, idx: number, length: number}

if (package.config:sub(1, 1) == "\\") then end
local Delete_all_notes_of_less_than_1_256_note_in_length = 40815
local Correct_overlapping_notes = 40659
---@param t unknown
local function deepcopy(t)
  local t_type = type(t)
  local retval
  if t_type == 'table' then
    retval = {}
    for t, n in next, t, nil do
      retval[deepcopy(t)] = deepcopy(n)
    end
    setmetatable(retval, deepcopy(getmetatable(t)))
  else
    retval = t
  end
  return retval
end

local function createMIDIFunc3(I)
  local e = {}
  e.allNotes = {}
  e.selectedNotes = {}
  e._editingNotes_Original = {}
  e.editingNotes = {}
  e.editorHwnd = nil
  e.take = nil
  e.mediaItem = nil
  e.mediaTrack = nil
  e._limitMaxCount = 1e3
  e._isSafeLimit = true
  function e:_showLimitNoteMsg()
    reaper.ShowMessageBox(
      "over " .. tostring(self._limitMaxCount) .. " clip num .\nstop process", "stop.", 0)
  end

  function e:getMidiNotes()
    reaper.PreventUIRefresh(2)
    reaper.MIDIEditor_OnCommand(self.editorHwnd, Delete_all_notes_of_less_than_1_256_note_in_length)
    reaper.MIDIEditor_OnCommand(self.editorHwnd, Correct_overlapping_notes)
    reaper.PreventUIRefresh(-1)

    local all_notes = {} ---@type KawaNote
    local selected_notes = {} ---@type KawaNote
    local retval, selected, muted, start, end_, chan, pitch, velo = reaper.MIDI_GetNote(self.take, 0)
    local idx = 0
    while retval do
      start = reaper.MIDI_GetProjQNFromPPQPos(self.take, start)
      end_ = reaper.MIDI_GetProjQNFromPPQPos(self.take, end_)
      ---@type KawaNote
      local d = {
        selection = selected,
        mute = muted,
        startQn = start,
        endQn = end_,
        chan = chan,
        pitch = pitch,
        vel = velo,
        take = self.take,
        idx = idx,
        length = end_ - start
      }
      table.insert(all_notes, d)
      if (selected == true) then
        table.insert(selected_notes, d)
      end
      idx = idx + 1
      retval, selected, muted, start, end_, chan, pitch, velo = reaper.MIDI_GetNote(self.take, idx)
      if (idx > self._limitMaxCount) then
        all_notes = {}
        selected_notes = {}
        self:_showLimitNoteMsg()
        self._isSafeLimit = false
        break
      end
    end
    self.m_existMaxNoteIdx = idx
    return all_notes, selected_notes
  end

  ---@return KawaNote[]
  function e:detectTargetNote()
    if (self._isSafeLimit == false) then return {} end
    if (#self.selectedNotes >= 1) then
      self._editingNotes_Original = deepcopy(self.selectedNotes)
      self.editingNotes = deepcopy(self.selectedNotes)
      return
          self.editingNotes
    else
      self._editingNotes_Original = deepcopy(self.allNotes)
      self.editingNotes = deepcopy(self.allNotes)
      return self
          .editingNotes
    end
  end

  function e:correctOverWrap() reaper.MIDIEditor_OnCommand(self.editorHwnd, Correct_overlapping_notes) end

  function e:flush(t, e)
    self:_deleteAllOriginalNote()
    self:_editingNoteToMediaItem(t)
    self:correctOverWrap()
    if (e == true) then
      reaper
          .MIDI_Sort(self.take)
    end
  end

  function e:insertNoteFromC(e)
    e.idx = self.m_existMaxNoteIdx + 1
    self.m_existMaxNoteIdx = self.m_existMaxNoteIdx + 1
    table.insert(
      self.editingNotes, e)
    return e
  end

  function e:insertNotesFromC(e)
    for t, e in ipairs(e) do self:insertNoteFromC(e) end
    return e
  end

  function e:insertMidiNote(n, o, e, t, i, r, a)
    local e = e
    local t = t
    local l = o
    local i = i or false
    local o = a or false
    local r = r or 1
    local a = n
    local n = self
        .m_existMaxNoteIdx + 1
    self.m_existMaxNoteIdx = self.m_existMaxNoteIdx + 1
    ---@type KawaNote
    local e = {
      selection = i,
      mute = o,
      startQn = e,
      endQn = t,
      chan = r,
      pitch = a,
      vel = l,
      take = self.take,
      idx = n,
      length = t - e
    }
    table.insert(self.editingNotes, e)
  end

  function e:deleteNote(n)
    for e, t in ipairs(self.editingNotes) do
      if (t.idx == n.idx) then
        table.remove(self.editingNotes, e)
        break
      end
    end
  end

  function e:deleteNotes(e)
    if (e == self.editingNotes) then
      self.editingNotes = {}
      return
    end
    for t, e in ipairs(e) do self:deleteNote(e) end
  end

  function e:_init(e)
    self.editorHwnd = reaper.MIDIEditor_GetActive()
    self.take = e or reaper.MIDIEditor_GetTake(self.editorHwnd)
    if (self.take == nil) then return end
    self.allNotes, self.selectedNotes = self:getMidiNotes()
    self.mediaItem = reaper.GetMediaItemTake_Item(self.take)
    self.mediaTrack = reaper.GetMediaItemTrack(self.mediaItem)
  end

  function e:_deleteAllOriginalNote(e)
    local e = e or self._editingNotes_Original
    while (#e > 0) do
      local t = #e
      reaper.MIDI_DeleteNote(e[t].take, e[t].idx)
      table.remove(e, #e)
    end
  end

  function e:_insertNoteToMediaItem(e, n)
    local t = self.take
    if t == nil then return end
    local d = e.selection or false
    local r = e.mute
    local l = reaper.MIDI_GetPPQPosFromProjQN(t, e.startQn)
    local a = reaper.MIDI_GetPPQPosFromProjQN(t, e.endQn)
    local i = e.chan
    local o = e.pitch
    local c = e.vel
    local e = 0
    if (n == true) then
      local n = .9
      local o = reaper.MIDI_GetProjQNFromPPQPos(t, n)
      local t = reaper.MIDI_GetProjQNFromPPQPos(t, n * 2)
      e = t - o
    end
    reaper.MIDI_InsertNote(t, d, r, l, a - e, i, o, c, true)
  end

  function e:_editingNoteToMediaItem(t) for n, e in ipairs(self.editingNotes) do self:_insertNoteToMediaItem(e, t) end end

  e:_init(I)
  return e
end

local function get_bottom_top_pitches(e)
  local top = nil
  local bottom = nil
  for o, e in ipairs(e) do
    top = math.max(top or e.pitch, e.pitch)
    bottom = math.min(bottom or e.pitch, e.pitch)
  end
  return top, bottom
end
---@alias KawaChord {notes: KawaNote[], startQn: number}

---@param e table<number, KawaNote>
---@return KawaChord[]
local function get_chords(e)
  ---@type KawaChord[]
  local chords = {}
  for e, note in ipairs(e) do
    local start_pos = note.startQn
    if (chords[start_pos] == nil) then
      chords[start_pos] = {}
      chords[start_pos].startQn = start_pos
      chords[start_pos].notes = {}
    end
    table.insert(chords[start_pos].notes, note)
  end
  return chords
end

---@param position "top" | "bottom" | "middle"
local function select_notes_in_chords(position)
  local midi_obj = createMIDIFunc3()
  local selected_notes = midi_obj:detectTargetNote()
  if (#selected_notes < 1) then
    return
  end
  local chords = get_chords(selected_notes)
  for t, chord in pairs(chords) do
    local top, bottom = get_bottom_top_pitches(chord.notes)
    for n, note in ipairs(chord.notes) do
      note.selection = false
      if position == "top" and (note.pitch == top) then
        note.selection = true
      elseif position == "bottom" and (note.pitch == bottom) then
        note.selection = true
      elseif position == "middle" and (note.pitch ~= top and note.pitch ~= bottom) then
        note.selection = true
      end
      ---select note
      reaper.MIDI_SetNote(note.take, note.idx, note.selection, note.mute,
        reaper.MIDI_GetPPQPosFromProjQN(note.take, note.startQn),
        reaper.MIDI_GetPPQPosFromProjQN(note.take, note.endQn), note.chan, note.pitch, note.vel, true)
    end
  end
  reaper.UpdateArrange()
end

---@return KawaChord[]
local function sort_chords()
  local midi_obj = createMIDIFunc3()
  local selected_notes = midi_obj:detectTargetNote()
  if (#selected_notes < 1) then
    return {}
  end
  local chords = get_chords(selected_notes)
  Table.forEach(chords,
    ---@param chord KawaChord
    function(chord)
      table.sort(chord.notes, function(a, b)
        return a.pitch > b.pitch
      end)
    end)
  return chords
end

---@param notes_tbl KawaNote[]
local function select_notes(notes_tbl)
  Table.map(notes_tbl,
    ---@param note KawaNote
    function(note)
      reaper.MIDI_SetNote(note.take, note.idx, true, note.mute,
        reaper.MIDI_GetPPQPosFromProjQN(note.take, note.startQn),
        reaper.MIDI_GetPPQPosFromProjQN(note.take, note.endQn), note.chan, note.pitch, note.vel, true)
    end)
end

---@return KawaNote[]
local function get_bottom_notes()
  return Table.map(sort_chords(),
    ---@param chord KawaChord
    function(chord)
      return chord.notes[#chord.notes]
    end)
end

---@return KawaNote[]
function kawa.get_top_notes()
  return Table.map(sort_chords(),
    ---@param chord KawaChord
    ---@return KawaNote
    function(chord)
      return chord.notes[1]
    end)
end

---@return KawaChord[]
local function get_middle_notes()
  return Table.map(sort_chords(),
    ---@param chord KawaChord
    ---@return KawaNote[]
    function(chord)
      ---@type KawaNote[]
      -- remove first and last note of chord
      table.remove(chord.notes, 1)
      table.remove(chord.notes, #chord.notes)
      return chord
    end)
end
---@return KawaChord[]
local function get_all_but_top()
  return Table.map(sort_chords(),
    ---@param chord KawaChord
    ---@return KawaNote[]
    function(chord)
      ---@type KawaNote[]
      -- remove first and last note of chord
      table.remove(chord.notes, 1)
      return chord
    end)
end

---@return KawaChord[]
local function get_all_but_middle()
  return Table.map(sort_chords(),
    ---@param chord KawaChord
    ---@return KawaNote[]
    function(chord)
      ---@type KawaNote[]
      -- remove first and last note of chord
      local top = Table.deepCopy(chord.notes[1])
      local bottom = Table.deepCopy(chord.notes[#chord.notes])
      chord.notes = {}
      table.insert(chord.notes, top)
      table.insert(chord.notes, bottom)
      return chord
    end)
end

---@return KawaChord[]
local function get_all_but_bottom()
  return Table.map(sort_chords(),
    ---@param chord KawaChord
    ---@return KawaNote[]
    function(chord)
      ---@type KawaNote[]
      -- remove first and last note of chord
      table.remove(chord.notes, #chord.notes)
      return chord
    end)
end
---@param indexes number[] put the values as the table's keys eg. { 1=1, 2=2, 6=6}
---@return KawaChord[]
local function get_chords_only_notes_at_idx(indexes)
  return Table.map(sort_chords(),
    ---@param chord KawaChord
    ---@return KawaChord
    function(chord)
      for i = #chord.notes, 1, -1 do
        if (indexes[i] == nil) then
          table.remove(chord.notes, i)
        end
      end
      return chord
    end)
end

function kawa.select_bottom_note()
  local bottom_notes = get_bottom_notes()
  --unselect all other events
  reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40214)
  select_notes(bottom_notes)
end

function kawa.select_top_note()
  local top_notes = kawa.get_top_notes()
  --unselect all other events
  reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40214)
  select_notes(top_notes)
end

function kawa.select_middle_note()
  local mid_notes = get_middle_notes()
  --unselect all other events
  reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40214)
  -- iterate of mid_notes, for each KawaNote[], call select_notes()
  Table.forEach(mid_notes,
    function(chord)
      select_notes(chord.notes)
    end
  )
end

function kawa.select_all_but_top()
  local notes = get_all_but_top()
  --unselect all other events
  reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40214)
  Table.forEach(notes,
    function(chord)
      select_notes(chord.notes)
    end
  )
end

function kawa.select_all_but_bottom()
  local notes = get_all_but_bottom()
  -- concatenated mid_notes and bottom_notes
  --unselect all other events
  reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40214)
  -- iterate of mid_notes, for each KawaNote[], call select_notes()
  Table.forEach(notes,
    function(chord)
      select_notes(chord.notes)
    end
  )
end

function kawa.select_all_but_middle()
  local notes = get_all_but_middle()
  --unselect all other events
  reaper.MIDIEditor_OnCommand(reaper.MIDIEditor_GetActive(), 40214)
  -- iterate of mid_notes, for each KawaNote[], call select_notes()
  Table.forEach(notes,
    function(chord)
      select_notes(chord.notes)
    end
  )
end

---@param note KawaNote
---@param semitones number
local function transpose_notes(note, semitones)
  reaper.MIDI_SetNote(note.take, note.idx, note.selection, note.mute,
    reaper.MIDI_GetPPQPosFromProjQN(note.take, note.startQn), reaper.MIDI_GetPPQPosFromProjQN(note.take, note.endQn),
    note.chan,
    note.pitch + semitones, note.vel)
end


function kawa.drop2_4()
  local chords_2 = get_chords_only_notes_at_idx({ [2] = 2, [4] = 4 })
  Table.forEach(chords_2,
    function(chord)
      Table.forEach(chord.notes, function(note)
        transpose_notes(note, -12)
      end)
    end)
end

function kawa.drop_3()
  local chords_2 = get_chords_only_notes_at_idx({ [3] = 3 })
  Table.forEach(chords_2,
    function(chord)
      Table.forEach(chord.notes, function(note)
        transpose_notes(note, -12)
      end)
    end)
end

function kawa.drop_2()
  -- get notes 2 and transpose them an octave lower
  local chords_2 = get_chords_only_notes_at_idx({ [2] = 2 })
  Table.forEach(chords_2,
    function(chord)
      Table.forEach(chord.notes, function(note)
        transpose_notes(note, -12)
      end)
    end)
end

function kawa.doubleTopNotesUp()
  -- get top notes and insert a copy of them an octave higher
  local top_notes = kawa.get_top_notes()
  Table.forEach(top_notes,
    ---@param note KawaNote
    function(note)
      reaper.MIDI_InsertNote(note.take, note.selection, note.mute,
        reaper.MIDI_GetPPQPosFromProjQN(note.take, note.startQn),
        reaper.MIDI_GetPPQPosFromProjQN(note.take, note.endQn), note.chan, note.pitch + 12, note.vel, true)
    end
  )
end

function kawa.doubleBottomNotesDown()
  -- get top notes and insert a copy of them an octave higher
  local top_notes = get_bottom_notes()
  Table.forEach(top_notes,
    ---@param note KawaNote
    function(note)
      reaper.MIDI_InsertNote(note.take, note.selection, note.mute,
        reaper.MIDI_GetPPQPosFromProjQN(note.take, note.startQn),
        reaper.MIDI_GetPPQPosFromProjQN(note.take, note.endQn), note.chan, note.pitch - 12, note.vel, true)
    end
  )
end

local function double_notes(semitones)
  local midi_obj = createMIDIFunc3()
  local selected_notes = midi_obj:detectTargetNote()
  Table.forEach(selected_notes,
    ---@param note KawaNote
    function(note)
      reaper.MIDI_InsertNote(note.take, note.selection, note.mute,
        reaper.MIDI_GetPPQPosFromProjQN(note.take, note.startQn),
        reaper.MIDI_GetPPQPosFromProjQN(note.take, note.endQn), note.chan, note.pitch + semitones, note.vel, true)
    end
  )
end

function kawa.doubleOctUp()
  double_notes(12)
end

function kawa.doubleOctDown()
  double_notes(-12)
end

function kawa.doubleSeventhUp()
  double_notes(10)
end

function kawa.doubleSeventhDown()
  double_notes(-10)
end

function kawa.doubleSixthUp()
  double_notes(9)
end

function kawa.doubleSixthDown()
  double_notes(-9)
end

function kawa.doubleFifthUp()
  double_notes(7)
end

function kawa.doubleFifthDown()
  double_notes(-7)
end

function kawa.doubleFourthUp()
  double_notes(5)
end

function kawa.doubleFourthDown()
  double_notes(-5)
end

function kawa.doubleThirdUp()
  double_notes(4)
end

function kawa.doubleThirdDown()
  double_notes(-4)
end

return kawa
