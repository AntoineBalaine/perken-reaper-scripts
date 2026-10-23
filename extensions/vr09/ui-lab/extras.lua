-- The parameters that Roland's MIDI Implementation documents for the VR-09 and that the plugin's catalog
-- does not have yet, so that the lab can show where they would go. They have the shape of the catalog's
-- entries (an id, a label, a range and the names of the values), and the lab keeps their values the way
-- it keeps the catalog's; nothing here is sent to a keyboard.
--
-- The names and the ranges come from the System, Part and Organ tables of the document
-- (docs/VR-09_VR-730_MIDI_Implementation.pdf of the roland-vr09 project). A parameter whose values are
-- not consecutive lists them in `values`, in the order of its names; `shift` and `signed` are for a
-- value that is stored as 52 to 76 and shown as -12 to +12.
--
-- Read once, when the lab starts.
local extras = {}

-- What a parameter's `disabled` says, when the unit does not take the parameter. Roland documents these
-- addresses, but writing to them leaves the value at 0 (checked on 2026-10-11, see "Documented
-- addresses that this unit refuses" in the roland-vr09 project's docs/midi-capabilities.md). They may
-- exist only on the VR-730, which the same document covers.
local REFUSED = "The unit refuses writes at this address, although Roland documents it. It may exist only on the VR-730."

local function add(param)
  extras[#extras + 1] = param
end

-- ---- the organ ----

add { id = "organ-type", label = "Organ type", short = "type", low = 0, high = 2, names = { "Jazz", "Rock", "Transistor" } }
add { id = "rotary-type", label = "Rotary type", short = "rotary type", low = 0, high = 2, names = { "Type 1", "Type 2", "Type 3" } }
add { id = "percussion", label = "Percussion", short = "percussion", low = 0, high = 66,
  values = { 0, 1, 2, 65, 66 }, names = { "Off", "2nd short", "3rd short", "2nd long", "3rd long" } }
add { id = "organ-eq-high", label = "Organ EQ high", short = "EQ high", low = 52, high = 76, default = 64, shift = -64, signed = true, unit = " dB", disabled = REFUSED }
add { id = "organ-eq-low", label = "Organ EQ low", short = "EQ low", low = 52, high = 76, default = 64, shift = -64, signed = true, unit = " dB", disabled = REFUSED }

-- The vibrato / chorus is switched on for the upper part, the lower part, or both, by two switches.
add { id = "vibrato-upper", label = "Vibrato / chorus on the upper part", low = 0, high = 1 }
add { id = "vibrato-lower", label = "Vibrato / chorus on the lower part", low = 0, high = 1 }
add { id = "rotary-on", label = "Rotary speaker", low = 0, high = 1 }

-- The pedal part has an organ block like the upper and the lower part, so that it would have drawbars.
-- The lab shows them disabled, since nothing is known of them on the unit.
local drawbars = { { "d16", "16'" }, { "d5f", "5 1/3'" }, { "d8", "8'" }, { "d4", "4'" }, { "d2f", "2 2/3'" },
  { "d2", "2'" }, { "d1f", "1 3/5'" }, { "d1ff", "1 1/3'" }, { "d1", "1'" } }
for _, drawbar in ipairs(drawbars) do
  add { id = "organ-pedal-" .. drawbar[1], label = "Pedal organ drawbar " .. drawbar[2], low = 0, high = 8 }
end

-- ---- the parts ----

-- Every part with a tone has an octave shift (-3 to +3, stored as 28 to 100 in steps of 12) and a
-- portamento. The drum part has none of them.
local tone_parts = { "upper-piano", "upper-piano-dual2", "lower-piano", "upper-synth", "upper-synth-dual2", "lower-synth" }
for _, part in ipairs(tone_parts) do
  add { id = part .. "-octave", label = "Octave shift", short = "octave", low = 28, high = 100, default = 64,
    values = { 28, 40, 52, 64, 76, 88, 100 }, names = { "-3", "-2", "-1", "0", "+1", "+2", "+3" } }
  add { id = part .. "-portamento", label = "Portamento", short = "portamento", low = 0, high = 2, default = 2,
    names = { "Off", "On", "Default" } }
  -- The upper and the lower synth refuse their portamento time; the others were not tried.
  local refused = (part == "upper-synth" or part == "lower-synth") and REFUSED or nil
  add { id = part .. "-portamento-time", label = "Portamento time", short = "porta time", low = 0, high = 127, disabled = refused }
end

add { id = "drum-volume", label = "Drum volume", short = "volume", low = 0, high = 127, default = 100 }

-- ---- the keyboard ----

add { id = "transpose", label = "Transpose", short = "transpose", low = 0, high = 11, default = 4,
  names = { "Ab", "A", "Bb", "B", "C", "C#", "D", "Eb", "E", "F", "F#", "G" } }
add { id = "initial-touch", label = "Initial touch", short = "initial touch", low = 1, high = 11,
  names = { "Off", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10" } }

-- What the two footswitches do. The document lists the values and the names in the same order.
local foot_values = { 0, 3, 4, 9, 10, 12, 13, 14 }
local foot_names = { "Rotary fast/slow", "Rhythm start/stop", "Song start/stop", "Damper of upper", "Damper of lower",
  "N.control 1", "N.control 2", "Off" }
add { id = "footswitch-left", label = "Left footswitch", short = "left", low = 0, high = 14, values = foot_values, names = foot_names }
add { id = "footswitch-right", label = "Right footswitch", short = "right", low = 0, high = 14, values = foot_values, names = foot_names }

-- What the D-Beam does. The values are not consecutive: 0, 1, 7, 9, 12, 13, 14, 18, 19, then 21 to 34.
local dbeam_values = { 0, 1, 7, 9, 12, 13, 14, 18, 19 }
for value = 21, 34 do dbeam_values[#dbeam_values + 1] = value end
add { id = "d-beam", label = "D-Beam", short = "D-Beam", low = 0, high = 34, values = dbeam_values,
  names = { "Off", "Pitch", "Rotary fast/slow", "Modulation", "N.control 1", "N.control 2", "Crash cymbal", "Big gong",
    "Wind chime down", "Vibraslap", "Wind whistle", "Big shot", "Smash glass", "Wheel brake", "Scratch 1",
    "Spring shock", "Scratch 2", "Reverse cym", "TR kick", "TR cymbal", "Explosion", "Sci-fi beam", "Laser shot" } }

-- ---- the space and the level ----

add { id = "wall-type", label = "Reverb wall type", short = "wall", low = 0, high = 7,
  names = { "Drapery", "Carpet", "Acoustic tile", "Wood", "Brick", "Plaster", "Concrete block", "Marble" } }
add { id = "tone-level", label = "Tone level", short = "tone level", low = 0, high = 127, default = 64, shift = -64, signed = true }

return extras
