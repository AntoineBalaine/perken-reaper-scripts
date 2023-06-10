local midi = {}


function midi.PitchCursorToSelectedNote()
  -- reaper.Undo_BeginBlock() -- to create a consolidated undo point in the Undo History
  local midieditor = reaper.MIDIEditor_GetActive()
  local take = reaper.MIDIEditor_GetTake(midieditor)
  local _, notes, _, _ = reaper.MIDI_CountEvts(take)

  -- count selected notes, find the first selected one
  for note_idx = 0, notes - 1 do
    _, sel, _, _, _, _, pitch, _ = reaper.MIDI_GetNote(take, note_idx)

    if sel == true then
      reaper.MIDIEditor_SetSetting_int(midieditor, 'active_note_row', pitch)
      break
    end
  end

  -- reaper.Undo_EndBlock("setPitchCursorToSelectedNote", -1 )
end

function midi.jump_to_next_note()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  local _, notes, _, _ = reaper.MIDI_CountEvts(take)
  for note_idx = 0, notes -1 do
    local _, _, _, startppqposOut, _, _, _, _ = reaper.MIDI_GetNote(take, note_idx)
    local next_note_pos = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqposOut)
      if next_note_pos > reaper.GetCursorPosition()  then
        reaper.SetEditCurPos(next_note_pos, 1, 0)
        break
      end
  end
end

function midi.jump_to_prev_note()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  local _, notes, _, _ = reaper.MIDI_CountEvts(take)
  for note_idx = notes-1, 0, -1 do
    local _, _, _, start_pos, endpos, _, _, _ = reaper.MIDI_GetNote(take, note_idx)
    local prev_note_pos = reaper.MIDI_GetProjTimeFromPPQPos(take, start_pos)
      if prev_note_pos < reaper.GetCursorPosition()  then
        reaper.SetEditCurPos(prev_note_pos, 1, 0)
        break
      end
  end
end

return midi
