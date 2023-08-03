---@alias tbparsed "min" | "maj" | "-" | "dim" | "aug" | "sus2" | "sus4" | "7" | "maj7" | "min7" | "dim7" | "aug7" | "minmaj7" | "6" | "min6" | "9" | "maj9" | "min9" | "11" | "maj11" | "min11" | "13" | "maj13" | "min13" | "add9" | "minadd9" | "6add9" | "min6add9" | "7sus2" | "7sus4" | "7dim5" | "7dim9" | "7aug5" | "7aug9" | "7dim5dim9" | "7dim5aug9" | "7aug5dim9" | "7aug5aug9" | "7dim5dim9dim11" | "7dim5dim9aug11" | "7dim5aug9dim11" | "7dim5aug9aug11" | "7aug5dim9dim11" | "7aug5dim9aug11" | "7aug5aug9dim11" | "7aug5aug9aug11" | "7dim5dim9dim13" | "7dim5dim9aug13" | "7dim5aug9dim13" | "7dim5aug9aug13" | "7aug5dim9dim13" | "7aug5dim9aug13" | "7aug5aug9dim13" | "7aug5aug9aug13"

---@alias note_name "C" | "Db" | "C#" | "D" | "Eb" | "D#" | "E" | "F" | "Gb" | "F#" | "G"|"G#"|"Ab"|"A"|"A#"|"Bb"|"B"
---@type table<note_name>[]
local notes_list = {
  [0] = { "C" },
  [1] = { "Db", "C#" },
  [2] = { "D" },
  [3] = { "Eb", "D#" },
  [4] = { "E" },
  [5] = { "F" },
  [6] = { "Gb", "F#" },
  [7] = { "G" },
  [8] = { "Ab", "G#" },
  [9] = { "A" },
  [10] = { "Bb", "A#" },
  [11] = { "B" }
}



local get_note_idx_from_name = function(name) ---@param name string
  for idx, notes in pairs(notes_list) do
    if notes[1] == name then
      return idx
    elseif notes[2] ~= nil and notes[2] == name then
      return idx
    end
  end
  return nil
end

local get_note_pos_from_note_midi_number = function(note_midi_number) ---@param note_midi_number number
  return note_midi_number % 12
end

---@param melody_midi_number number
---@param fundamental_midi_number number
local get_interval_to_fundamental = function(melody_midi_number, fundamental_midi_number)
  local melody_note_pos = get_note_pos_from_note_midi_number(melody_midi_number)
  local fundamental_note_pos = get_note_pos_from_note_midi_number(fundamental_midi_number)
  local interval = melody_note_pos - fundamental_note_pos
  if interval < 0 then
    interval = interval + 12
  end
  return interval
end

local get_midi_number_from_interval = function(note_pos, melody_midi_number)
  local melody_note_pos = get_note_pos_from_note_midi_number(melody_midi_number)
  local interval = melody_note_pos - note_pos
  if interval < 0 then
    interval = interval + 12
  end
  local midi_note = melody_midi_number - interval
  return midi_note
end

---@param quality "min" | "maj"
local chord_quality_to_interval = function(quality)
  if quality == "min" then
    return 3
  elseif quality == "maj" then
    return 4
  end
end

---@param seventh "major" | "minor "
local seventh_to_interval = function(seventh)
  if seventh == "maj" then
    return 11
  elseif seventh == "min" then
    return 10
  end
end

local fifth_to_interval = function(fifth)
  if fifth == "just" then
    return 7
  elseif fifth == "aug" then
    return 8
  elseif fifth == "dim" then
    return 6
  end
end


---@alias quality "min" | "maj" | "dim" | "just" | "aug"
---for now assuming format Fund (Letter), Quality (min, "-" or nothing = "major"), Seventh (Maj7, or 7), Fifth ("" or "b5")
---@return note_name fundamental, quality quality, quality seventh, quality fifth
local parse_chord_symbol = function(chord_symbol) ---@param chord_symbol string
  local fundamental = chord_symbol:match("[ABCDEFG][b#]?")
  -- match "-" or "min"
  local quality = (chord_symbol:sub(#fundamental):match("min") or chord_symbol:sub(#fundamental):match("-") or chord_symbol:sub(#fundamental):match("m[b#]?[2-9]")) and
      "min" or "maj"

  local seventh = chord_symbol:match("7") and (chord_symbol:match("Maj7") or chord_symbol:match("maj7")) and "maj" or
      "min"
  local fifth = chord_symbol:match("b5") and "dim" or chord_symbol:match("#5") and "aug" or "just"

  return fundamental, quality, seventh, fifth
end

---@alias Chord_note "fund"|"third"| "fifth" | "seventh"
---@alias note_pos number

local get_chord_notes = function(fundamental, quality, seventh, fifth) ---@param fundamental note_name
  local fundamental_pos = get_note_idx_from_name(fundamental)
  local interval_to_fundamental = chord_quality_to_interval(quality)
  local interval_to_seventh = seventh_to_interval(seventh)
  local interval_to_fifth = fifth_to_interval(fifth)


  ---@type table<Chord_note, note_pos>
  local notes = {}
  notes["fund"] = fundamental_pos
  notes["third"] = (fundamental_pos + interval_to_fundamental) % 12
  notes["fifth"] = (fundamental_pos + interval_to_fifth) % 12
  notes["seventh"] = (fundamental_pos + interval_to_seventh) % 12

  return notes
end

---@param note_pos number
---@param chord_notes table<Chord_note, note_pos>
local is_chord_note = function(note_pos, chord_notes)
  for _, chord_note in pairs(chord_notes) do
    if note_pos == chord_note then
      return true
    end
  end
  return false
end

local bring_note_number_below_melody = function(note_number, melody_number)
  while note_number > melody_number do
    note_number = note_number - 12
  end
  return note_number
end

---takes a midi note's pitch, a chord symbol, and returns a list of midi pitches that harmonize the given note
---@param melody_midi_number number
---@param chord_symbol string
---@return number[]
local harmonize = function(melody_midi_number, chord_symbol)
  -- local melody_note = "Eb"
  -- local note_idx = get_note_idx_from_name(melody_note)
  local mel_idx = get_note_pos_from_note_midi_number(melody_midi_number)


  local chord = get_chord_notes(parse_chord_symbol(chord_symbol))
  local chord_notes = {}
  if mel_idx and is_chord_note(mel_idx, chord) then
    --- bring all the chord notes other than mel_idx below the melody note
    for _, chord_note_idx in pairs(chord) do
      if chord_note_idx ~= mel_idx then
        local chord_note_midi = get_midi_number_from_interval(chord_note_idx, melody_midi_number)
        table.insert(chord_notes, chord_note_midi)
      end
    end
  end
  return chord_notes
end

local harmonizer = {
  harmonize = harmonize
}

return harmonizer
