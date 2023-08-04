  -- @noindex
  
reaper.Undo_BeginBlock() -- to create a consolidated undo point in the Undo History
local midieditor = reaper.MIDIEditor_GetActive()
local take = reaper.MIDIEditor_GetTake(midieditor)
local retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)

-- count selected notes, find the first selected one
for k = 0, notes - 1 do
  retval, sel, muted, startppqposOut, endppqposOut, chan, pitch, vel = reaper.MIDI_GetNote(take, k)

  if sel == true then
    reaper.MIDIEditor_SetSetting_int(midieditor, 'active_note_row', pitch)
  end
end

reaper.Undo_EndBlock("setPitchCursorToSelectedNote", -1 )
