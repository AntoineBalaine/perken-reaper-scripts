local midi = {}

---@return number notes
---@return MediaItem_Take take
---@return HWND midieditor
function midi.listNotes()
	local midieditor = reaper.MIDIEditor_GetActive()
	local take = reaper.MIDIEditor_GetTake(midieditor)
	local _, notes, _, _ = reaper.MIDI_CountEvts(take)
	return notes, take, midieditor
end

function midi.PitchCursorToSelectedNote()
	-- reaper.Undo_BeginBlock() -- to create a consolidated undo point in the Undo History
	local notes, take, midieditor = midi.listNotes()
	-- count selected notes, find the first selected one
	for note_idx = 0, notes - 1 do
		local _, sel, _, _, _, _, pitch, _ = reaper.MIDI_GetNote(take, note_idx)

		if sel == true then
			reaper.MIDIEditor_SetSetting_int(midieditor, "active_note_row", pitch)
			break
		end
	end

	-- reaper.Undo_EndBlock("setPitchCursorToSelectedNote", -1 )
end

function midi.jump_to_next_note()
	local notes, take, _ = midi.listNotes()
	for note_idx = 0, notes - 1 do
		local _, _, _, startppqposOut, _, _, _, _ = reaper.MIDI_GetNote(take, note_idx)
		local next_note_pos = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqposOut)
		if next_note_pos > reaper.GetCursorPosition() then
			reaper.SetEditCurPos(next_note_pos, 1, 0)
			break
		end
	end
end

function midi.jump_to_prev_note()
	local notes, take, _ = midi.listNotes()
	for note_idx = notes - 1, 0, -1 do
		local _, _, _, start_pos, endpos, _, _, _ = reaper.MIDI_GetNote(take, note_idx)
		local prev_note_pos = reaper.MIDI_GetProjTimeFromPPQPos(take, start_pos)
		if prev_note_pos < reaper.GetCursorPosition() then
			reaper.SetEditCurPos(prev_note_pos, 1, 0)
			break
		end
	end
end

---@alias NotePosition {startpos: number, endpos: number}

---comment
---@return Table<number, NotePosition>
function midi.getNotePositionsInEditor()
	local notes, take, _ = midi.listNotes()
	local note_positions = {}
	for i = 1, notes do
		local _, _, _, startpos, endpos, _, _, _ = reaper.MIDI_GetNote(take, i - 1)
		note_positions[i] = {
			startpos = startpos,
			endpos = endpos,
		}
	end
	return note_positions
end

---comment
---@return Table<number, NotePosition>
function midi.getBigNotePositions()
	local note_positions = midi.getNotePositionsInEditor()
	---@type Table<number, NotePosition>
	local big_note_positions = {}
	if #note_positions == 0 then
		return big_note_positions
	end

	local j = 1
	big_note_positions[j] = note_positions[1]
	for i = 2, #note_positions do
		---@type NotePosition
		local next_note = note_positions[i]
		---@type NotePosition
		local curbig = big_note_positions[j]

		if curbig.endpos >= next_note.startpos then
			if next_note.endpos > curbig.endpos then
				curbig.endpos = next_note.endpos
			end
			big_note_positions[j] = curbig
		else
			j = j + 1
			big_note_positions[j] = next_note
		end
	end
	return big_note_positions
end

---@param note_positions Table<number, NotePosition>
---@param startOrEnd "start" | "end"
local function moveToNextNote(note_positions, startOrEnd)
	local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
	local cursorPos = reaper.GetCursorPosition()
	local next_pos = nil
	for _, ppqPos in pairs(note_positions) do
		local pos = ppqPos.startpos
		if startOrEnd == "end" then
			pos = ppqPos.endpos
		end
		local notepos = reaper.MIDI_GetProjTimeFromPPQPos(take, pos)
		if notepos > cursorPos then
			next_pos = notepos
			break
		end
	end
	if next_pos then
		reaper.SetEditCurPos(next_pos, true, false)
	end
end

---@param note_positions Table<number, NotePosition>
---@param startOrEnd "start" | "end"
local function moveToPrevNote(note_positions, startOrEnd)
	local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
	local cursorPos = reaper.GetCursorPosition()
	local prev_pos = nil
	-- iterate backwards
	for i = #note_positions, 1, -1 do
		local ppqPos = note_positions[i]
		local pos = ppqPos.startpos
		if startOrEnd == "end" then
			pos = ppqPos.endpos
		end
		local notepos = reaper.MIDI_GetProjTimeFromPPQPos(take, pos)
		if notepos < cursorPos then
			prev_pos = notepos
			break
		end
	end
	if prev_pos then
		reaper.SetEditCurPos(prev_pos, true, false)
	end
end

---@param note_positions Table<number, NotePosition>
local function moveToNextNoteEnd(note_positions)
	moveToNextNote(note_positions, "end")
end

---@param note_positions Table<number, NotePosition>
local function moveToNextNoteStart(note_positions)
	moveToNextNote(note_positions, "start")
end

local function moveToPrevNoteStart(note_positions)
	moveToPrevNote(note_positions, "start")
end

local function moveToPrevNoteEnd(note_positions)
	moveToPrevNote(note_positions, "end")
end

function midi.nextBigNoteEnd()
	moveToNextNoteEnd(midi.getBigNotePositions())
end

function midi.nextBigNoteStart()
	moveToNextNoteStart(midi.getBigNotePositions())
end

function midi.prevBigNoteEnd()
	moveToPrevNoteEnd(midi.getBigNotePositions())
end

function midi.prevBigNoteStart()
	moveToPrevNoteStart(midi.getBigNotePositions())
end

return midi
