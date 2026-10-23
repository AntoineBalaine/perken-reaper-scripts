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

-- ---- more of the system ----

-- The rotary speaker's rise and fall times, for the woofer and the tweeter.
add { id = "woofer-rise", label = "Rotary woofer rise time", short = "woofer rise", low = 0, high = 127 }
add { id = "woofer-fall", label = "Rotary woofer fall time", short = "woofer fall", low = 0, high = 127 }
add { id = "tweeter-rise", label = "Rotary tweeter rise time", short = "tweeter rise", low = 0, high = 127 }
add { id = "tweeter-fall", label = "Rotary tweeter fall time", short = "tweeter fall", low = 0, high = 127 }
add { id = "rotary-brake", label = "Rotary brake", short = "brake", low = 0, high = 1, names = { "Off", "On" }, disabled = REFUSED }
add { id = "overdrive-dry", label = "Overdrive dry mix level", short = "dry mix", low = 0, high = 127, disabled = REFUSED }

-- The percussion's soft level goes from 0 to 15, and its normal level is 18.
local percussion_values, percussion_names = {}, {}
for level = 0, 15 do
  percussion_values[#percussion_values + 1] = level
  percussion_names[#percussion_names + 1] = "Soft " .. level
end
percussion_values[#percussion_values + 1] = 18
percussion_names[#percussion_names + 1] = "Normal"
add { id = "percussion-level", label = "Percussion level", short = "perc. level", low = 0, high = 18, default = 18,
  values = percussion_values, names = percussion_names }

-- The document gives the expression curve a range of 0 to 3 and no names for it.
add { id = "expression-curve", label = "Expression curve", short = "expr. curve", low = 0, high = 3,
  names = { "1", "2", "3", "4" } }

-- The two N.control switches are the two bits of one value, 0 to 3. The document does not say which bit
-- is which, so the lab takes the first bit for N.control 1.
add { id = "n-control", label = "N.control", low = 0, high = 3 }

add { id = "damper-part", label = "Damper part", short = "damper", low = 0, high = 2, names = { "Upper", "Lower", "All" } }
add { id = "wheel-brake", label = "Wheel brake", short = "wheel brake", low = 0, high = 1, names = { "Off", "On" } }

-- ---- the synth engine ----

-- Roland documents a whole synth, with an oscillator, a filter, an amplifier and an LFO for each of the
-- three partials of a tone. Its addresses (19 21, 19 41 and 1A 21) stay silent on the unit, so that the
-- lab shows one partial's controls disabled.
local ENGINE_SILENT = "Roland documents the synth tone, but the unit does not answer at its addresses (19 21, 19 41 and 1A 21 read silent), so the controls are disabled."

local function engine(id, label, short, low, high, more)
  local param = { id = "engine-" .. id, label = label, short = short, low = low, high = high, disabled = ENGINE_SILENT }
  for key, value in pairs(more or {}) do param[key] = value end
  add(param)
end

local BIPOLAR = { default = 64, shift = -64, signed = true }

local function bipolar(more)
  local copy = {}
  for key, value in pairs(BIPOLAR) do copy[key] = value end
  for key, value in pairs(more or {}) do copy[key] = value end
  return copy
end

engine("osc-wave", "Oscillator wave", "wave", 0, 7, { names = { "Saw", "Square", "PW square", "Triangle", "Sine", "Noise", "Super-saw", "PCM" } })
engine("osc-variation", "Oscillator wave variation", "variation", 0, 2, { names = { "A", "B", "C" } })
engine("osc-pitch", "Oscillator pitch", "pitch", 40, 88, bipolar { unit = " st" })
engine("osc-detune", "Oscillator detune", "detune", 14, 114, bipolar { unit = " ct" })
engine("osc-pwm-depth", "Oscillator pulse width mod depth", "PWM depth", 0, 127)
engine("osc-pulse-width", "Oscillator pulse width", "pulse width", 0, 127)

engine("pitch-env-attack", "Pitch envelope attack time", "attack", 0, 127)
engine("pitch-env-decay", "Pitch envelope decay", "decay", 0, 127)
engine("pitch-env-depth", "Pitch envelope depth", "depth", 1, 127, bipolar())

engine("filter-mode", "Filter mode", "mode", 0, 4, { names = { "Bypass", "LPF", "HPF", "BPF", "PKG" } })
engine("filter-slope", "Filter slope", "slope", 0, 1, { names = { "-12 dB", "-24 dB" } })
engine("filter-cutoff", "Filter cutoff", "cutoff", 0, 127, { default = 127 })
engine("filter-keyfollow", "Filter cutoff keyfollow", "keyfollow", 54, 74, bipolar { scale = 10, unit = "%" })
engine("filter-resonance", "Filter resonance", "resonance", 0, 127)
engine("filter-env-attack", "Filter envelope attack time", "attack", 0, 127)
engine("filter-env-decay", "Filter envelope decay time", "decay", 0, 127)
engine("filter-env-sustain", "Filter envelope sustain level", "sustain", 0, 127)
engine("filter-env-release", "Filter envelope release time", "release", 0, 127)
engine("filter-env-depth", "Filter envelope depth", "depth", 1, 127, bipolar())

engine("amp-level", "Amplifier level", "level", 0, 127, { default = 127 })
engine("amp-velocity", "Amplifier level velocity sensitivity", "velocity", 1, 127, bipolar())
engine("amp-pan", "Amplifier pan", "pan", 0, 127, bipolar())
engine("amp-env-attack", "Amplifier envelope attack time", "attack", 0, 127)
engine("amp-env-decay", "Amplifier envelope decay time", "decay", 0, 127)
engine("amp-env-sustain", "Amplifier envelope sustain level", "sustain", 0, 127, { default = 127 })
engine("amp-env-release", "Amplifier envelope release time", "release", 0, 127)

engine("lfo-shape", "LFO shape", "shape", 0, 5, { names = { "Tri", "Sin", "Saw", "Sqr", "S&H", "Rnd" } })
engine("lfo-rate", "LFO rate", "rate", 0, 127)
engine("lfo-sync", "LFO tempo sync", "tempo sync", 0, 1, { names = { "Off", "On" } })
engine("lfo-sync-note", "LFO tempo sync note", "sync note", 0, 19, { names = { "16", "12", "8", "4", "2", "1", "3/4",
  "2/3", "1/2", "3/8", "1/3", "1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16", "1/24", "1/32" } })
engine("lfo-fade", "LFO fade time", "fade", 0, 127)
engine("lfo-pitch-depth", "LFO pitch depth", "pitch", 1, 127, bipolar())
engine("lfo-filter-depth", "LFO filter depth", "filter", 1, 127, bipolar())

engine("unison", "Unison", "unison", 0, 1, { names = { "Off", "On" } })
engine("unison-size", "Unison size", "size", 0, 3, { names = { "2", "4", "6", "8" } })
engine("ring", "Ring modulator", "ring", 0, 2, { names = { "Off", "---", "On" } })

-- ---- the leftovers ----

-- The volume of the upper piano's second layer, which the catalog's mixer does not have.
add { id = "upper-piano-dual2-volume", label = "Upper piano (dual 2) volume", short = "volume", low = 0, high = 127, default = 100 }

-- The sound shaping that every part's block has: the cutoff, the resonance, and the attack, decay and release.
-- The catalog uses them for the synth parts only, and the synth's cutoff is refused by the unit.
local shaping = { { "cutoff", "cutoff" }, { "resonance", "resonance" }, { "attack", "attack" }, { "decay", "decay" }, { "release", "release" } }
for _, part in ipairs({ "upper-piano", "upper-piano-dual2", "lower-piano" }) do
  for _, item in ipairs(shaping) do
    add { id = part .. "-" .. item[1], label = part .. " " .. item[2], short = item[2], low = 0, high = 127, default = 64 }
  end
end

-- The channel volume (CC 7) and the pan (CC 10) of the parts that the catalog does not have them for.
add { id = "cc-upper-volume", label = "Upper volume (CC7)", short = "volume", low = 0, high = 127, default = 100 }
add { id = "cc-lower-volume", label = "Lower volume (CC7)", short = "volume", low = 0, high = 127, default = 100 }
add { id = "cc-lower-pan", label = "Lower pan (CC10)", short = "pan", low = 0, high = 127, default = 64 }
add { id = "cc-piano-volume", label = "Piano (dual 2) volume (CC7)", short = "volume", low = 0, high = 127, default = 100 }
add { id = "cc-piano-pan", label = "Piano (dual 2) pan (CC10)", short = "pan", low = 0, high = 127, default = 64 }

-- The rest of the synth tone's common block: which partials sound and which are selected for editing, the
-- tone's level, its wave shape and its category. The tone's name is a display in the lab.
for partial = 1, 3 do
  engine("partial" .. partial .. "-switch", "Partial " .. partial .. " switch", "partial " .. partial, 0, 1, { names = { "Off", "On" }, default = 1 })
  engine("partial" .. partial .. "-select", "Partial " .. partial .. " select", "edit " .. partial, 0, 1, { names = { "Off", "On" }, default = partial == 1 and 1 or 0 })
end
engine("tone-level", "Synth tone level", "tone level", 0, 127, { default = 100 })
engine("wave-shape", "Wave shape", "wave shape", 0, 127)
engine("tone-category", "Tone category", "category", 0, 127)

-- The rest of the synth tone: its portamento and its mono / poly setting (the document gives no names for
-- the two values of the last), the PCM wave number and the super-saw detune of a partial, the LFO's
-- amplitude depth, and the modulation LFO, which has the shape, the rate and the sync of the LFO and its
-- own depths.
engine("porta-switch", "Portamento switch", "portamento", 0, 1, { names = { "Off", "On" } })
engine("porta-time", "Portamento time", "time", 0, 127)
engine("mono-poly", "Mono / poly", "mono / poly", 0, 1, { names = { "0", "1" } })
engine("wave-number", "PCM wave number", "wave number", 0, 16384)
engine("super-saw-detune", "Super saw detune", "super saw", 0, 127)
engine("lfo-amp-depth", "LFO amplitude depth", "amp", 1, 127, bipolar())

local sync_notes = { "16", "12", "8", "4", "2", "1", "3/4", "2/3", "1/2", "3/8", "1/3", "1/4", "3/16", "1/6", "1/8",
  "3/32", "1/12", "1/16", "1/24", "1/32" }
engine("mod-lfo-shape", "Modulation LFO shape", "shape", 0, 5, { names = { "Tri", "Sin", "Saw", "Sqr", "S&H", "Rnd" } })
engine("mod-lfo-rate", "Modulation LFO rate", "rate", 0, 127)
engine("mod-lfo-sync", "Modulation LFO tempo sync", "tempo sync", 0, 1, { names = { "Off", "On" } })
engine("mod-lfo-sync-note", "Modulation LFO tempo sync note", "sync note", 0, 19, { names = sync_notes })
engine("mod-lfo-pitch-depth", "Modulation LFO pitch depth", "pitch", 1, 127, bipolar())
engine("mod-lfo-filter-depth", "Modulation LFO filter depth", "filter", 1, 127, bipolar())
engine("mod-lfo-amp-depth", "Modulation LFO amplitude depth", "amp", 1, 127, bipolar())
engine("mod-lfo-rate-control", "Modulation LFO rate control", "rate control", 1, 127, bipolar())

-- ---- the GM2 sounds ----

-- The General MIDI 2 sound generator plays on the other channels, with Program Change and Bank Select.
for _, channel in ipairs({ 5, 6, 7, 8, 9, 10, 12, 14, 15 }) do
  add { id = "gm2-ch" .. channel .. "-program", label = "GM2 channel " .. channel .. " program", short = "ch " .. channel,
    low = 0, high = 127, shift = 1 }
end

return extras
