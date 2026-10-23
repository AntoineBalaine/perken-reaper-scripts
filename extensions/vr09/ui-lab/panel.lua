-- The panel: header, tabs, notice. This is a port of what the plugin draws today (src/ui.zig), and
-- the file we edit live. Saving it redraws the open window at once; an error shows in the window
-- and the lab waits for the next save.
--
-- `S` is the lab's state: S.model (the mock keyboard), S.ui (what the panel remembers between
-- frames, such as the tab and the filter), S.notice(text, is_error), S.start_job(label, total).
local env = ...
local ImGui = env.ImGui

local M = {}

-- Because the runner loads only the modules of its own list, a lab that was started before a module
-- was added to that list has no such module in `env`. The panel then reads the file from its own
-- folder, so that a new module works without starting the lab again (it reloads when the panel does).
local SOURCE_DIR = debug.getinfo(1, "S").source:match("^@(.*[/\\])") or ""
local loaded_here = {}

local function module(name)
  if env[name] then return env[name] end
  if not loaded_here[name] then
    local chunk = loadfile(SOURCE_DIR .. name .. ".lua")
    loaded_here[name] = chunk and chunk(env)
  end
  return loaded_here[name]
end

-- Begins a tab, with its name drawn in the tab font, or in the title font when the lab has none.
-- Because ImGui draws the name when the tab begins, the font is popped at once, and the tab's content
-- keeps the usual one.
local function begin_tab(ctx, label)
  local tab_font = env.fonts and (env.fonts.tab or env.fonts.title)
  if tab_font then ImGui.PushFont(ctx, tab_font) end
  local open = ImGui.BeginTabItem(ctx, label)
  if tab_font then ImGui.PopFont(ctx) end
  return open
end

-- ---- the header ----

-- The keyboard's state in a card: a lamp and a line saying whether it answers, the progress of a
-- read or a write when there is one, and the patch's name on a display.
local function header(ctx, S)
  local m, th, widgets = S.model, env.theme, env.widgets
  if not widgets.begin_card(ctx, "Status") then return end
  local color, text
  if m.connected then
    if m.mode == "mode2" then
      color, text = th.green, "Keyboard connected (MIDI IN mode 2)"
    elseif m.mode == "mode1" then
      color, text = th.amber, "Keyboard connected, but in MIDI IN mode 1: switch it to mode 2"
    else
      color, text = th.amber, "Keyboard answers, mode unknown"
    end
  else
    color, text = th.red, "The keyboard does not answer: see the MIDI tab"
  end
  widgets.lamp(ctx, color, true)
  ImGui.SameLine(ctx)
  ImGui.TextColored(ctx, color, text)
  if m.job then
    local caption = ("%s %d/%d"):format(m.job.label, m.job.done, m.job.total)
    ImGui.ProgressBar(ctx, m.job.done / m.job.total, 420, nil, caption)
  end
  ImGui.TextColored(ctx, th.label, "Patch")
  ImGui.SameLine(ctx)
  widgets.display(ctx, m.patch, th.amber, 260)
  -- The keyboard sends a steady MIDI clock. Whether it follows the tempo setting is not known, so the
  -- lab shows a mock value.
  ImGui.SameLine(ctx)
  ImGui.TextColored(ctx, th.label, "Clock")
  ImGui.SameLine(ctx)
  widgets.display(ctx, ("%d BPM"):format(S.ui.clock_bpm or 120), th.amber, 0, true)
  widgets.end_card(ctx)
end

-- ---- the controls ----

-- The groups of the catalog in the order they first appear, each with its parameters.
local function groups_of(catalog)
  local groups, by_name = {}, {}
  for _, param in ipairs(catalog) do
    local group = by_name[param.group]
    if not group then
      group = { name = param.group, params = {}, drawbars = param.group:find("drawbars", 1, true) ~= nil }
      by_name[param.group] = group
      groups[#groups + 1] = group
    end
    group.params[#group.params + 1] = param
  end
  return groups
end

-- The height the tallest card of a row needs, from the last time each was drawn, so that the cards
-- of the row can all take it; nil the first time, when the cards size themselves.
local function row_height(titles)
  local tallest = nil
  for _, title in ipairs(titles) do
    local height = env.widgets.natural_height(title)
    if height and (not tallest or height > tallest) then tallest = height end
  end
  return tallest
end

-- The switch that says whether a part sounds. The lab keeps it by the part's id, and a part that is not
-- in the table is on.
local function part_toggle(ctx, S, key)
  local on = S.ui.part_on[key]
  if on == nil then on = true end
  local changed, value = env.widgets.toggle(ctx, "Part on", on)
  if changed then S.ui.part_on[key] = value end
end

local function card_of_drawbars(ctx, S, group, height)
  local widgets, values = env.widgets, S.model.values
  if not widgets.begin_card(ctx, group.name, nil, height, env.theme.part.organ) then return end
  part_toggle(ctx, S, group.name)
  for i, param in ipairs(group.params) do
    ImGui.PushID(ctx, param.id)
    local changed, v = widgets.drawbar(ctx, param, values[param.id])
    ImGui.PopID(ctx)
    if changed then values[param.id] = v end
    if i < #group.params then ImGui.SameLine(ctx) end
  end
  widgets.end_card(ctx)
end

local function card_of_sliders(ctx, S, group)
  local widgets, values = env.widgets, S.model.values
  if not widgets.begin_card(ctx, group.name) then return end
  for _, param in ipairs(group.params) do
    ImGui.PushID(ctx, param.id)
    local changed, v = widgets.param_slider(ctx, param, values[param.id])
    ImGui.PopID(ctx)
    if changed then values[param.id] = v end
  end
  widgets.end_card(ctx)
end

-- A card of knobs for the groups that hold levels. `options` may hold:
--   title:         the card's title, which is the group's name by default;
--   strip:         what the labels start with that the card's title already says;
--   suffixes:      words the labels end with, which the knob does not need ("volume");
--   labels:        the label of a knob, by the parameter's id, when the catalog's is too long;
--   bipolar:       true for a card whose values all rest in the middle of their range;
--   bipolar_ids:   the ids of the knobs that rest in the middle, when only some of them do;
--   columns:       how many knobs a row holds, when the card has more than one row;
--   brackets:      the captions engraved over the knobs of the first row;
--   brackets_by_row: the same, for each row, when the card has several;
--   accent:        the card's accent color;
--   height:        the card's height, when it takes the height of a row.
local function card_of_knobs(ctx, S, group, options)
  options = options or {}
  local widgets, values = env.widgets, S.model.values
  if not widgets.begin_card(ctx, options.title or group.name, nil, options.height, options.accent) then return end
  local count = #group.params
  local per_row = options.columns or count
  for i, param in ipairs(group.params) do
    if (i - 1) % per_row == 0 then
      local row = (i - 1) // per_row + 1
      local brackets = options.brackets_by_row and options.brackets_by_row[row] or (row == 1 and options.brackets)
      if brackets then widgets.bracket_row(ctx, brackets, math.min(per_row, count - i + 1)) end
    end
    ImGui.PushID(ctx, param.id)
    local label = options.labels and options.labels[param.id]
      or widgets.short_label(param.label, options.strip or group.name, options.suffixes)
    local bipolar = options.bipolar or (options.bipolar_ids ~= nil and options.bipolar_ids[param.id] == true)
    local changed, v = widgets.knob(ctx, param, values[param.id], label, bipolar)
    ImGui.PopID(ctx)
    if changed then values[param.id] = v end
    if i < count and i % per_row ~= 0 then ImGui.SameLine(ctx) end
  end
  widgets.end_card(ctx)
  -- The size of the card is returned, so that a card beside it can match it.
  return ImGui.GetItemRectSize(ctx)
end

-- The rotary speaker: its switch and the three knobs of the woofer on one row, and the three knobs
-- of the tweeter under them. Because the catalog lists the switch first, then the woofer, then the
-- tweeter, the parameters are taken by their position.
local function card_of_rotary(ctx, S, group, height)
  local widgets, values = env.widgets, S.model.values
  if not widgets.begin_card(ctx, group.name, nil, height, env.theme.part.organ) then return end
  local params = group.params
  for i, param in ipairs(params) do
    ImGui.PushID(ctx, param.id)
    local label = widgets.short_label(param.label, group.name)
    local changed, v
    if i == 1 then
      changed, v = widgets.switch(ctx, param, values[param.id], "speaker speed", "FAST", "SLOW")
    else
      changed, v = widgets.knob(ctx, param, values[param.id], label)
    end
    ImGui.PopID(ctx)
    if changed then values[param.id] = v end
    if i == 1 or i == 2 or i == 3 or i == 5 or i == 6 then
      ImGui.SameLine(ctx)
    elseif i == 4 then
      -- The second row starts under the switch, which is left empty.
      ImGui.Dummy(ctx, 76, 1)
      ImGui.SameLine(ctx)
    end
  end
  widgets.end_card(ctx)
end

-- The parameter of a group whose id ends with the suffix, such as "-attack".
local function param_ending(group, suffix)
  for _, param in ipairs(group.params) do
    if param.id:sub(-#suffix) == suffix then return param end
  end
  return nil
end

-- What the synth's attack, decay and release shape. The catalog does not say, so this is the part of
-- the sound that Roland's controllers 72, 73 and 75 (release, attack and decay time) act on in a
-- General MIDI 2 module, which is its volume; the cutoff and resonance are the filter.
local ENVELOPE_OF = "volume"

-- A card beside the synth's knobs, with the screen that draws their envelope and lets the user drag
-- its handles.
local function card_of_envelope(ctx, S, group, title, width, height, accent)
  local widgets, values = env.widgets, S.model.values
  local params = {
    attack = param_ending(group, "-attack"),
    decay = param_ending(group, "-decay"),
    release = param_ending(group, "-release"),
  }
  if not (params.attack and params.decay and params.release) then return end
  if not widgets.begin_card(ctx, title .. " " .. ENVELOPE_OF .. " envelope", width, height, accent) then return end
  for id, v in pairs(widgets.envelope(ctx, params, values)) do values[id] = v end
  widgets.end_card(ctx)
end

-- The organ's knobs take the organ's accent, the same as its drawbars and its rotary speaker.
local function card_of_organ(ctx, S, group, height)
  card_of_knobs(ctx, S, group, { accent = env.theme.part.organ, height = height })
end

-- The synth's envelope and filter values rest in the middle of their range (64), so that their
-- knobs are bipolar. The card's title says which part it is, and its labels do not repeat it.
local function card_of_synth(ctx, S, group)
  local strip = group.name == "Synth upper" and "Upper synth" or "Lower synth"
  -- The catalog lists the resonance first, then the attack, the decay and the release.
  local brackets = {
    { label = "Filter", from = 1, to = 1 },
    { label = ENVELOPE_OF .. " envelope", from = 2, to = 4 },
  }
  local accent = group.name == "Synth upper" and env.theme.part.upper or env.theme.part.lower
  local width, height = card_of_knobs(ctx, S, group, { strip = strip, bipolar = true, brackets = brackets, accent = accent })
  ImGui.SameLine(ctx)
  card_of_envelope(ctx, S, group, strip, width, height, accent)
end

-- The piano's two volumes are in the catalog's Mixer group, and they belong with the piano's other
-- controls too. Because both cards read and write the same values by the parameters' ids, a volume
-- moved in the Piano card also moves in the Mixer card.
local PIANO_VOLUMES = { "upper-piano-volume", "lower-piano-volume" }

-- The parameter of the catalog with this id, or nil.
local function param_with_id(catalog, id)
  for _, param in ipairs(catalog) do
    if param.id == id then return param end
  end
  return nil
end

-- The parameter with this id: one of the extras that the documentation has and the catalog does not
-- (when the lab has loaded them), or one of the catalog's.
local function find_param(S, id)
  local extra = S.extras_by_id and S.extras_by_id[id]
  if extra then return extra end
  return param_with_id(S.model.catalog, id)
end

-- The stop knobs that show their chosen name in a display that opens a list, even though they have
-- eight stops or fewer, because their names are too long to be written around the knob.
local AS_LIST = {
  ["footswitch-left"] = true,
  ["footswitch-right"] = true,
  ["engine-osc-wave"] = true,
}

-- Draws the control of a parameter: a stop knob when its values have names, a knob otherwise, and
-- writes the new value back. `bipolar` is true for a knob whose value rests in the middle.
local function control_of(ctx, S, param, label, bipolar)
  local widgets, values = env.widgets, S.model.values
  ImGui.PushID(ctx, param.id)
  local changed, v
  if param.names then
    changed, v = widgets.stop_knob(ctx, param, values[param.id], label, AS_LIST[param.id])
  else
    changed, v = widgets.knob(ctx, param, values[param.id], label, bipolar)
  end
  ImGui.PopID(ctx)
  if changed then values[param.id] = v end
end

-- A card of the extras, in one row, each labelled with its short name.
local function card_of_extras(ctx, S, title, ids, accent, height)
  local widgets = env.widgets
  if not widgets.begin_card(ctx, title, nil, height, accent) then return end
  -- Because a lab that was started before a parameter was added to extras.lua does not have it, the card
  -- says which one is missing instead of failing.
  for _, id in ipairs(ids) do
    if not S.extras_by_id[id] then
      ImGui.TextColored(ctx, env.theme.amber, "Not loaded: " .. id)
      widgets.end_card(ctx)
      return
    end
  end
  for i, id in ipairs(ids) do
    local param = S.extras_by_id[id]
    control_of(ctx, S, param, param.short, param.signed)
    if i < #ids then ImGui.SameLine(ctx) end
  end
  widgets.end_card(ctx)
end

-- Tells the user that the lab has to be started again, when it was started before a data file existed.
local function extras_missing(ctx, S)
  -- The last parameter of extras.lua is the sign that the lab has read the whole file.
  if S.extras_by_id and S.tones and S.extras_by_id["gm2-ch15-program"] then return false end
  ImGui.TextColored(ctx, env.theme.amber, "The documented parameters are not loaded: close the lab and run it again.")
  return true
end

-- The parameters of a list from the position `from` to the position `to`.
local function slice(params, from, to)
  local found = {}
  for i = from, to do found[#found + 1] = params[i] end
  return found
end

-- The mixer's levels, in the order of the catalog: the rhythm and the song, then the upper part's
-- piano and two synths, then the lower part's piano and synth. Each of the three is a card of its
-- own. Because the upper and lower parts are two panels of the same kind, they are put one under the
-- other, and the backing card follows the upper one on its row, so that the tab uses its width.
local function card_of_mixer(ctx, S, group)
  local options = { suffixes = { " volume", " level" } }
  local bands = {
    { title = "Upper", from = 3, to = 5, part = "upper", in_row = true },
    { title = "Backing", from = 1, to = 2, part = "backing", beside_previous = true, in_row = true },
    { title = "Lower", from = 6, to = 7, part = "lower" },
  }
  local row = row_height({ "Upper", "Backing" })
  for _, band in ipairs(bands) do
    options.title = band.title
    options.accent = env.theme.part[band.part]
    options.height = band.in_row and row or nil
    if band.beside_previous then ImGui.SameLine(ctx) end
    local params = slice(group.params, band.from, band.to)
    -- The volume of the upper piano's second layer comes after the upper piano's.
    local dual2 = band.title == "Upper" and S.extras_by_id and S.extras_by_id["upper-piano-dual2-volume"]
    if dual2 then table.insert(params, 2, dual2) end
    card_of_knobs(ctx, S, { name = band.title, params = params }, options)
  end
end

-- The piano: the volumes of its upper, upper dual 2 and lower parts, then the controllers of the piano that
-- is the second layer of a dual patch, with its channel volume and pan, which the catalog does not have.
local function card_of_piano_main(ctx, S, group)
  local params = {}
  for _, id in ipairs({ "upper-piano-volume", "upper-piano-dual2-volume", "lower-piano-volume" }) do
    params[#params + 1] = find_param(S, id)
  end
  for _, param in ipairs(group.params) do params[#params + 1] = param end
  for _, id in ipairs({ "cc-piano-volume", "cc-piano-pan" }) do
    params[#params + 1] = find_param(S, id)
  end
  local brackets = {
    { label = "Volume", from = 1, to = #params - #group.params - 2 },
    { label = "Dual 2", from = #params - #group.params - 1, to = #params },
  }
  card_of_knobs(ctx, S, { name = "Piano", params = params },
    { strip = "Piano (dual 2)", suffixes = { " volume" }, brackets = brackets, accent = env.theme.part.piano,
      bipolar_ids = { ["cc-piano-pan"] = true } })
end

-- The sound shaping of each of the three piano parts, in a card of its own: the cutoff and the resonance
-- under a filter bracket, and the attack, decay and release under an envelope bracket.
local PIANO_SHAPING = {
  { id = "upper-piano", title = "Upper piano shaping", part = "upper" },
  { id = "upper-piano-dual2", title = "Upper piano dual 2 shaping", part = "upper" },
  { id = "lower-piano", title = "Lower piano shaping", part = "lower" },
}

local function cards_of_piano_shaping(ctx, S)
  for _, shaping in ipairs(PIANO_SHAPING) do
    local params, labels = {}, {}
    for _, name in ipairs({ "cutoff", "resonance", "attack", "decay", "release" }) do
      local param = find_param(S, shaping.id .. "-" .. name)
      params[#params + 1] = param
      labels[param.id] = param.short
    end
    card_of_knobs(ctx, S, { name = shaping.title, params = params }, {
      title = shaping.title, labels = labels, bipolar = true, accent = env.theme.part[shaping.part],
      brackets = { { label = "Filter", from = 1, to = 2 }, { label = ENVELOPE_OF .. " envelope", from = 3, to = 5 } },
    })
  end
end

local function card_of_piano(ctx, S, group)
  if extras_missing(ctx, S) then return end
  card_of_piano_main(ctx, S, group)
  cards_of_piano_shaping(ctx, S)
end

-- The controllers that rest in the middle of their range (64) are bipolar knobs: the vibrato, the pan,
-- the cutoff, the resonance and the envelope. The others, the sends and the expression, are levels.
local BIPOLAR_CONTROLLERS = {
  ["cc-upper-vibrato-depth"] = true, ["cc-upper-vibrato-rate"] = true, ["cc-upper-pan"] = true,
  ["cc-upper-cutoff"] = true, ["cc-upper-resonance"] = true, ["cc-upper-release"] = true,
  ["cc-upper-attack"] = true, ["cc-upper-decay"] = true, ["cc-lower-cutoff"] = true,
  ["cc-lower-pan"] = true,
}

-- The upper part has twelve controllers, in two rows of six. Because the catalog lists them in this
-- order, the brackets are placed by position: vibrato and sends over the first row, filter and
-- envelope over the second.
local function card_of_upper_controllers(ctx, S, group)
  -- The channel volume (CC 7) goes after the expression, which makes seven knobs on the first row.
  local params = {}
  for _, param in ipairs(group.params) do
    params[#params + 1] = param
    local volume = S.extras_by_id and S.extras_by_id["cc-upper-volume"]
    if param.id == "cc-upper-expression" and volume then params[#params + 1] = volume end
  end
  card_of_knobs(ctx, S, { name = group.name, params = params }, {
    title = "Upper controllers", strip = "Upper", columns = 7, bipolar_ids = BIPOLAR_CONTROLLERS,
    accent = env.theme.part.upper,
    brackets_by_row = {
      { { label = "Vibrato", from = 1, to = 2 }, { label = "Sends", from = 3, to = 4 } },
      { { label = "Filter", from = 1, to = 2 }, { label = ENVELOPE_OF .. " envelope", from = 3, to = 5 } },
    },
  })
end

local function card_of_lower_controllers(ctx, S, group)
  -- The channel volume and the pan, which the catalog does not have for the lower part, come last.
  local params = {}
  for _, param in ipairs(group.params) do params[#params + 1] = param end
  for _, id in ipairs({ "cc-lower-volume", "cc-lower-pan" }) do
    local extra = S.extras_by_id and S.extras_by_id[id]
    if extra then params[#params + 1] = extra end
  end
  card_of_knobs(ctx, S, { name = group.name, params = params },
    { title = "Lower controllers", strip = "Lower", bipolar_ids = BIPOLAR_CONTROLLERS, accent = env.theme.part.lower })
end

-- The overall volume, and the tone level that the documentation has at the system address 61.
local function card_of_master_controller(ctx, S, group)
  local params = { group.params[1] }
  local labels = { ["cc-master-expression"] = "overall volume" }
  local tone_level = S.extras_by_id and S.extras_by_id["tone-level"]
  if tone_level then
    params[2] = tone_level
    labels["tone-level"] = "tone level"
  end
  card_of_knobs(ctx, S, { name = group.name, params = params },
    { title = "Master", accent = env.theme.part.master, labels = labels, bipolar_ids = { ["tone-level"] = true } })
end

-- The effects, one card for each, in two rows. Each lists the ids of its parameters in the order
-- they are shown. A parameter with named values is a stop knob, and a level is a knob.
local EFFECT_ROWS = {
  {
    { title = "Reverb", color = "reverb", ids = { "reverb-type", "reverb-variation", "reverb-level", "wall-type" } },
    { title = "Vibrato / chorus", color = "chorus", ids = { "vibrato-chorus-type" } },
  },
  {
    { title = "MFX", color = "mfx", ids = { "mfx-type", "mfx-level" } },
    { title = "Delay", color = "delay", ids = { "delay-type", "delay-level" } },
    { title = "Compressor", color = "compressor", ids = { "compressor-level" } },
  },
}

-- Draws the card of one effect, at the given height when there is one, and returns its size.
local function card_of_effect(ctx, S, effect, height)
  local widgets, values = env.widgets, S.model.values
  if not widgets.begin_card(ctx, effect.title, nil, height, env.theme.fx[effect.color]) then return end
  for i, id in ipairs(effect.ids) do
    local param = find_param(S, id)
    if param then
      ImGui.PushID(ctx, param.id)
      local label = widgets.short_label(param.label, effect.title)
      local changed, v
      if param.names then
        changed, v = widgets.stop_knob(ctx, param, values[param.id], label)
      else
        changed, v = widgets.knob(ctx, param, values[param.id], label)
      end
      ImGui.PopID(ctx)
      if changed then values[param.id] = v end
      if i < #effect.ids then ImGui.SameLine(ctx) end
    end
  end
  widgets.end_card(ctx)
  return ImGui.GetItemRectSize(ctx)
end

-- Draws the effects' cards. Because they come from several parameters of the catalog's Effects group,
-- each card looks its parameters up by id. Because the cards of a row sit side by side, they all take
-- the height of the tallest one, so that the row has an even edge: in the second row, the MFX card,
-- with its display, sets the height of the delay and the compressor.
local function card_of_effects(ctx, S, group)
  for _, row in ipairs(EFFECT_ROWS) do
    local titles = {}
    for _, effect in ipairs(row) do titles[#titles + 1] = effect.title end
    local height = row_height(titles)
    for i, effect in ipairs(row) do
      if i > 1 then ImGui.SameLine(ctx) end
      card_of_effect(ctx, S, effect, height)
    end
  end
end

-- The groups drawn as a row of knobs, and the function that draws each one.
local CARDS_OF_KNOBS = {
  ["Organ"] = card_of_organ,
  ["Rotary"] = card_of_rotary,
  ["Synth upper"] = card_of_synth,
  ["Synth lower"] = card_of_synth,
  ["Mixer"] = card_of_mixer,
  ["Control change piano"] = card_of_piano,
  ["Control change upper"] = card_of_upper_controllers,
  ["Control change lower"] = card_of_lower_controllers,
  ["Control change master"] = card_of_master_controller,
  ["Effects"] = card_of_effects,
}

-- Because the upper and lower parts are two panels of the same kind, their cards are put one under
-- the other, while the other knob cards share a row.
local STACKED = {
  ["Synth upper"] = true,
  ["Synth lower"] = true,
  ["Control change upper"] = true,
  ["Control change lower"] = true,
}

-- The organ's own settings in a card, and the pedal part beside it. The pedal is drawn disabled, with
-- the drawbars its organ block would have: the plugin has no parameter for it yet.
local function card_of_organ_voicing(ctx, S, height)
  local widgets, values = env.widgets, S.model.values
  if not widgets.begin_card(ctx, "Organ voicing", nil, height, env.theme.part.organ) then return end
  -- The organ's character on the first row, and its levels on the second: the EQ and the overdrive's dry
  -- mix, which the unit refuses and which are drawn disabled.
  local rows = {
    { "organ-type", "rotary-type", "percussion", "percussion-level" },
    { "organ-eq-high", "organ-eq-low", "overdrive-dry" },
  }
  for _, ids in ipairs(rows) do
    for i, id in ipairs(ids) do
      local param = S.extras_by_id[id]
      control_of(ctx, S, param, param.short, param.signed)
      if i < #ids then ImGui.SameLine(ctx) end
    end
  end
  local switches = {
    { id = "vibrato-upper", label = "Vibrato / chorus, upper" },
    { id = "vibrato-lower", label = "Vibrato / chorus, lower" },
    { id = "rotary-on", label = "Rotary speaker" },
  }
  for i, switch in ipairs(switches) do
    local changed, on = widgets.toggle(ctx, switch.label, values[switch.id] == 1)
    if changed then values[switch.id] = on and 1 or 0 end
    if i < #switches then ImGui.SameLine(ctx) end
  end
  widgets.end_card(ctx)
end

local function card_of_organ_pedal(ctx, S, height)
  local widgets, values, th = env.widgets, S.model.values, env.theme
  if not widgets.begin_card(ctx, "Organ pedal", nil, height) then return end
  local first = true
  for _, param in ipairs(S.extras) do
    if param.id:sub(1, 12) == "organ-pedal-" then
      if not first then ImGui.SameLine(ctx) end
      first = false
      ImGui.PushID(ctx, param.id)
      widgets.drawbar(ctx, param, values[param.id], true)
      ImGui.PopID(ctx)
    end
  end
  ImGui.TextColored(ctx, th.text_dim, "Not in the plugin yet (MIDI channel 2).")
  widgets.end_card(ctx)
end

local function organ_extras(ctx, S)
  if extras_missing(ctx, S) then return end
  local height = row_height({ "Organ voicing", "Organ pedal" })
  card_of_organ_voicing(ctx, S, height)
  ImGui.SameLine(ctx)
  card_of_organ_pedal(ctx, S, height)
  -- The rotary speaker's times and its brake, which the unit refuses, under them.
  card_of_extras(ctx, S, "Rotary times", { "woofer-rise", "woofer-fall", "tweeter-rise", "tweeter-fall", "rotary-brake" },
    env.theme.part.organ)
end

-- The drum part: its kit from the tone list, its volume, and a switch. The document lists these at
-- the drum block's offsets, but the unit's dumps do not match them, so the card says it is unconfirmed.
local function drums_section(ctx, S)
  if not ImGui.BeginChild(ctx, "##section") then return end
  if extras_missing(ctx, S) then
    ImGui.EndChild(ctx)
    return
  end
  local widgets, ui = env.widgets, S.ui
  if widgets.begin_card(ctx, "Drum kit", nil, nil, env.theme.part.master) then
    local list = S.tones.drum
    local index = ui.tone.drum or 1
    local new_index, filter = widgets.tone_picker(ctx, "drum", list, index, ui.tone_filter.drum or "")
    ui.tone.drum = new_index
    ui.tone_filter.drum = filter
    part_toggle(ctx, S, "drum")
    control_of(ctx, S, S.extras_by_id["drum-volume"], "volume")
    ImGui.PushTextWrapPos(ctx, 360)
    ImGui.TextColored(ctx, env.theme.text_dim, "Roland documents the kit and the volume at the drum block's offsets, but the unit's dumps do not match them: unconfirmed. The drums play on MIDI channel 11.")
    ImGui.PopTextWrapPos(ctx)
    widgets.end_card(ctx)
  end
  ImGui.EndChild(ctx)
end

-- The pedals' settings: the part the damper pedal acts on, the wheel brake, and the two N.control switches,
-- which are the two bits of one value.
local function card_of_pedals(ctx, S, accent)
  local widgets, values = env.widgets, S.model.values
  if not widgets.begin_card(ctx, "Pedals", nil, nil, accent) then return end
  for i, id in ipairs({ "damper-part", "wheel-brake" }) do
    local param = S.extras_by_id[id]
    control_of(ctx, S, param, param.short)
    ImGui.SameLine(ctx)
  end
  local n = values["n-control"]
  local first, second = n & 1 == 1, n & 2 == 2
  local changed_1, on_1 = widgets.toggle(ctx, "N.control 1", first)
  ImGui.SameLine(ctx)
  local changed_2, on_2 = widgets.toggle(ctx, "N.control 2", second)
  if changed_1 then first = on_1 end
  if changed_2 then second = on_2 end
  values["n-control"] = (first and 1 or 0) | (second and 2 or 0)
  widgets.end_card(ctx)
end

-- The keyboard's performance controls: what the two footswitches and the D-Beam do, and the
-- transposition and the touch.
local function performance_section(ctx, S)
  if not ImGui.BeginChild(ctx, "##section") then return end
  if extras_missing(ctx, S) then
    ImGui.EndChild(ctx)
    return
  end
  local accent = env.theme.part.master
  local height = row_height({ "Footswitches", "D-Beam", "Keyboard" })
  card_of_extras(ctx, S, "Footswitches", { "footswitch-left", "footswitch-right" }, accent, height)
  ImGui.SameLine(ctx)
  card_of_extras(ctx, S, "D-Beam", { "d-beam" }, accent, height)
  ImGui.SameLine(ctx)
  card_of_extras(ctx, S, "Keyboard", { "transpose", "initial-touch", "expression-curve" }, accent, height)
  card_of_pedals(ctx, S, accent)
  ImGui.EndChild(ctx)
end

-- The synth engine that Roland documents: one partial's oscillator, filter, amplifier and LFO, in rows of
-- cards. The unit does not answer at its addresses, so every control is disabled.
local ENGINE_ROWS = {
  {
    { title = "Oscillator", ids = { "engine-osc-wave", "engine-osc-variation", "engine-osc-pitch", "engine-osc-detune", "engine-osc-pwm-depth", "engine-osc-pulse-width" } },
    { title = "Pitch envelope", ids = { "engine-pitch-env-attack", "engine-pitch-env-decay", "engine-pitch-env-depth" } },
    { title = "PCM and super saw", ids = { "engine-wave-number", "engine-super-saw-detune" } },
  },
  {
    { title = "Filter", ids = { "engine-filter-mode", "engine-filter-slope", "engine-filter-cutoff", "engine-filter-keyfollow", "engine-filter-resonance" } },
    { title = "Filter envelope", ids = { "engine-filter-env-attack", "engine-filter-env-decay", "engine-filter-env-sustain", "engine-filter-env-release", "engine-filter-env-depth" } },
  },
  {
    { title = "Amplifier", ids = { "engine-amp-level", "engine-amp-velocity", "engine-amp-pan" } },
    { title = "Amplifier envelope", ids = { "engine-amp-env-attack", "engine-amp-env-decay", "engine-amp-env-sustain", "engine-amp-env-release" } },
    { title = "Unison and ring", ids = { "engine-unison", "engine-unison-size", "engine-ring" } },
  },
  {
    { title = "Synth tone", draw = "card_of_engine_tone" },
    { title = "Portamento", ids = { "engine-porta-switch", "engine-porta-time", "engine-mono-poly" } },
    { title = "Partials", ids = { "engine-partial1-switch", "engine-partial2-switch", "engine-partial3-switch", "engine-partial1-select", "engine-partial2-select", "engine-partial3-select" } },
  },
  {
    { title = "LFO", ids = { "engine-lfo-shape", "engine-lfo-rate", "engine-lfo-sync", "engine-lfo-sync-note", "engine-lfo-fade", "engine-lfo-pitch-depth", "engine-lfo-filter-depth", "engine-lfo-amp-depth" } },
    { title = "Modulation LFO", ids = { "engine-mod-lfo-shape", "engine-mod-lfo-rate", "engine-mod-lfo-sync", "engine-mod-lfo-sync-note", "engine-mod-lfo-pitch-depth", "engine-mod-lfo-filter-depth", "engine-mod-lfo-amp-depth", "engine-mod-lfo-rate-control" } },
  },
}

-- The synth tone's own card: its name on a display, and its level, wave shape and category.
local function card_of_engine_tone(ctx, S, height)
  local widgets = env.widgets
  if not widgets.begin_card(ctx, "Synth tone", nil, height) then return end
  widgets.display(ctx, "Init Tone", env.theme.text_dim, 160)
  for i, id in ipairs({ "engine-tone-level", "engine-wave-shape", "engine-tone-category" }) do
    local param = S.extras_by_id[id]
    control_of(ctx, S, param, param.short)
    if i < 3 then ImGui.SameLine(ctx) end
  end
  widgets.end_card(ctx)
end

local function engine_section(ctx, S)
  if not ImGui.BeginChild(ctx, "##section") then return end
  if extras_missing(ctx, S) then
    ImGui.EndChild(ctx)
    return
  end
  ImGui.PushTextWrapPos(ctx, 640)
  ImGui.TextColored(ctx, env.theme.text_dim, "One partial of the synth tone, as Roland documents it. The unit does not answer at these addresses, so the controls are disabled.")
  ImGui.PopTextWrapPos(ctx)
  for _, row in ipairs(ENGINE_ROWS) do
    local titles = {}
    for _, card in ipairs(row) do titles[#titles + 1] = card.title end
    local height = row_height(titles)
    for i, card in ipairs(row) do
      if i > 1 then ImGui.SameLine(ctx) end
      if card.draw then card_of_engine_tone(ctx, S, height) else card_of_extras(ctx, S, card.title, card.ids, nil, height) end
    end
  end
  ImGui.EndChild(ctx)
end

-- The General MIDI 2 sound generator: the program of each of the channels that it plays on.
local function gm2_section(ctx, S)
  if not ImGui.BeginChild(ctx, "##section") then return end
  if extras_missing(ctx, S) then
    ImGui.EndChild(ctx)
    return
  end
  ImGui.PushTextWrapPos(ctx, 640)
  ImGui.TextColored(ctx, env.theme.text_dim, "The GM2 sounds play on MIDI channels 5 to 10, 12, 14 and 15, chosen with Program Change and Bank Select. The names of the sounds are not in the lab yet.")
  ImGui.PopTextWrapPos(ctx)
  local ids = {}
  for _, channel in ipairs({ 5, 6, 7, 8, 9, 10, 12, 14, 15 }) do ids[#ids + 1] = "gm2-ch" .. channel .. "-program" end
  card_of_extras(ctx, S, "GM2 programs", ids, env.theme.part.master)
  ImGui.EndChild(ctx)
end

-- The parts that have a tone to choose, in two rows: the three pianos, then the three synths. Each has
-- an id, the list of tones it chooses from, and the part of the instrument whose accent it takes.
local TONE_PARTS = {
  { id = "upper-piano", title = "Upper piano", list = "piano", part = "upper" },
  { id = "upper-piano-dual2", title = "Upper piano dual 2", list = "piano", part = "upper" },
  { id = "lower-piano", title = "Lower piano", list = "piano", part = "lower" },
  { id = "upper-synth", title = "Upper synth", list = "synth", part = "upper" },
  { id = "upper-synth-dual2", title = "Upper synth dual 2", list = "synth", part = "upper" },
  { id = "lower-synth", title = "Lower synth", list = "synth", part = "lower" },
}
local TONE_PARTS_PER_ROW = 3

-- The card of one part's tone. The lab keeps the choice as a position in the part's list, since the
-- catalog has no tone parameters yet.
local function card_of_tone(ctx, S, part)
  local widgets, ui = env.widgets, S.ui
  if not widgets.begin_card(ctx, part.title, nil, nil, env.theme.part[part.part]) then return end
  local list = S.tones[part.list]
  local index = ui.tone[part.id] or 1
  local new_index, filter = widgets.tone_picker(ctx, part.id, list, index, ui.tone_filter[part.id] or "")
  ui.tone[part.id] = new_index
  ui.tone_filter[part.id] = filter
  if new_index ~= index then S.notice(("%s: %s (mock)."):format(part.title, list[new_index].name), false) end
  part_toggle(ctx, S, part.id)
  if S.extras_by_id then
    local ids = { part.id .. "-octave", part.id .. "-portamento", part.id .. "-portamento-time" }
    for i, id in ipairs(ids) do
      local param = S.extras_by_id[id]
      control_of(ctx, S, param, param.short)
      if i < #ids then ImGui.SameLine(ctx) end
    end
  end
  widgets.end_card(ctx)
end

-- The Tones tab: a card for each part, in rows of three.
local function tones_section(ctx, S)
  if not ImGui.BeginChild(ctx, "##section") then return end
  -- Because the runner reads tones.lua only when the lab starts, a lab that was started before the
  -- file existed has no tones; the tab says so instead of failing.
  if extras_missing(ctx, S) then
    ImGui.EndChild(ctx)
    return
  end
  for i, part in ipairs(TONE_PARTS) do
    if (i - 1) % TONE_PARTS_PER_ROW ~= 0 then ImGui.SameLine(ctx) end
    card_of_tone(ctx, S, part)
  end
  ImGui.EndChild(ctx)
end

-- The instrument's sections, each one a tab, with the catalog's groups that it shows. Because the
-- catalog has no group for drums, the rhythm and song levels stay in the Mixer. The piano's volumes
-- are in the Mixer, where the catalog lists them, and in the Piano tab as well.
local SECTIONS = {
  { name = "Organ", groups = { "Organ upper drawbars", "Organ lower drawbars", "Organ", "Rotary" }, after = organ_extras },
  -- A section with a `draw` function draws itself, when it does not show the catalog's groups.
  { name = "Tones", draw = tones_section },
  { name = "Synth", groups = { "Synth upper", "Synth lower" } },
  { name = "Engine", draw = engine_section },
  { name = "Piano", groups = { "Control change piano" } },
  { name = "Drums", draw = drums_section },
  { name = "Mixer", groups = { "Mixer" } },
  { name = "FX", groups = { "Effects" } },
  { name = "Controllers", groups = { "Control change upper", "Control change lower", "Control change master" } },
  { name = "Performance", draw = performance_section },
  { name = "GM2", draw = gm2_section },
}

-- The groups of a section, in the order of the section's list.
local function groups_named(all, names)
  local found = {}
  for _, name in ipairs(names) do
    for _, group in ipairs(all) do
      if group.name == name then found[#found + 1] = group end
    end
  end
  return found
end

-- Draws the cards of one section: the drawbars side by side first, because an organ player looks at
-- them first, then the organ's and the rotary speaker's knobs on one row, then every other group.
local function section(ctx, S, names, after)
  if not ImGui.BeginChild(ctx, "##section") then return end
  local groups = groups_named(groups_of(S.model.catalog), names)
  -- The cards that share a row take the height of the tallest of them: the drawbars together, and the
  -- knob cards that are not stacked together.
  local drawbar_names, row_names = {}, {}
  for _, group in ipairs(groups) do
    if group.drawbars then
      drawbar_names[#drawbar_names + 1] = group.name
    elseif CARDS_OF_KNOBS[group.name] and not STACKED[group.name] then
      row_names[#row_names + 1] = group.name
    end
  end
  local drawbar_height, knob_height = row_height(drawbar_names), row_height(row_names)

  local drawbars_drawn = false
  for _, group in ipairs(groups) do
    if group.drawbars then
      if drawbars_drawn then ImGui.SameLine(ctx) end
      card_of_drawbars(ctx, S, group, drawbar_height)
      drawbars_drawn = true
    end
  end
  local knobs_drawn = false
  for _, group in ipairs(groups) do
    local card = CARDS_OF_KNOBS[group.name]
    if card then
      if knobs_drawn and not STACKED[group.name] then ImGui.SameLine(ctx) end
      card(ctx, S, group, knob_height)
      knobs_drawn = true
    end
  end
  for _, group in ipairs(groups) do
    if not group.drawbars and not CARDS_OF_KNOBS[group.name] then card_of_sliders(ctx, S, group) end
  end
  -- Cards that the section draws after its groups, such as the organ's voicing and its pedal.
  if after then after(ctx, S) end
  ImGui.EndChild(ctx)
end

-- The Controls tab holds a tab bar of its own, with one tab for each section of the instrument.
local function controls(ctx, S)
  if not ImGui.BeginTabBar(ctx, "##sections") then return end
  for _, s in ipairs(SECTIONS) do
    if begin_tab(ctx, s.name) then
      if s.draw then s.draw(ctx, S) else section(ctx, S, s.groups, s.after) end
      ImGui.EndTabItem(ctx)
    end
  end
  ImGui.EndTabBar(ctx)
end

-- ---- the patches ----
--
-- Because a performer picks a sound by name, the registrations and the single tones share one table.
-- The last column is the value of the plugin's Patch parameter that selects the row, so that an
-- automation lane, a MIDI-learned control or the preset menu all reach the same row. A value never
-- changes once given: the registrations take 1 to 100 (their number in the keyboard's own order, plus
-- one), and the tones take 101 and up, in the order of tones.lua, which only grows at its end. The
-- value 0 means that no patch is asked for.

local PATCH_TYPES = { "All", "Registration", "Tone", "Preset" }
local FIRST_TONE_VALUE = 101

-- The tone lists in table order, each with the part of the lab that loading one of its tones fills.
local TONE_LISTS = {
  { list = "piano", part = "upper-piano" },
  { list = "synth", part = "upper-synth" },
  { list = "drum", part = nil },
}

local function program_of(entry)
  return (entry.bank - 1) * 4 + entry.slot - 1
end

-- ---- the player's own presets ----
--
-- A preset is a file of `Data/Perken/vr09/presets`, saved from the keyboard's state. A preset has no
-- number in the library, so its patch ID comes from its name: the same name gives the same ID on every
-- computer, and a template that holds it finds it again. The IDs run from 1000 up, past the
-- registrations (1 to 100) and the tones (from 101).

local PRESET_ID_FIRST = 1000
local PRESET_ID_SPAN = 60000

-- The patch ID of a preset: a hash of its name (FNV-1a), brought into the range of the IDs.
local function preset_id(name)
  local h = 2166136261
  for i = 1, #name do
    h = ((h ~ name:byte(i)) * 16777619) & 0xFFFFFFFF
  end
  return PRESET_ID_FIRST + h % PRESET_ID_SPAN
end

-- The presets of the folder, read again every second or so, and at once after the lab changes one.
local function presets_of(S)
  local ui = S.ui
  if ui.presets and S.frame - (ui.presets_at or 0) < 60 then return ui.presets end
  local list, i = {}, 0
  local folder = S.model.data .. "/presets"
  while true do
    local file = reaper.EnumerateFiles(folder, i)
    if not file then break end
    i = i + 1
    local name = file:match("^(.+)%.vr09$") or file:match("^(.+)%.json$")
    if name then list[#list + 1] = { file = file, name = name } end
  end
  table.sort(list, module("scenes").preset_less)
  ui.presets, ui.presets_at = list, S.frame
  return list
end

local function presets_changed(S)
  S.ui.presets = nil
end

-- Every patch of the table: the registrations, the tones, and then the player's presets.
local function patch_rows(S)
  local rows = {}
  for k, e in ipairs(S.model.registrations) do
    rows[#rows + 1] = {
      key = "reg" .. k, type = "Registration", number = ("%d-%d"):format(e.bank, e.slot),
      name = (e.name:gsub("_", " ")), group = "", value = program_of(e) + 1, registration = e,
    }
  end
  local position = 0
  for _, source in ipairs(TONE_LISTS) do
    for i, tone in ipairs(S.tones and S.tones[source.list] or {}) do
      rows[#rows + 1] = {
        key = "tone" .. source.list .. i, type = "Tone", number = "", name = tone.name, group = tone.group,
        value = FIRST_TONE_VALUE + position, tone = { part = source.part, list = source.list, index = i },
      }
      position = position + 1
    end
  end
  for _, preset in ipairs(presets_of(S)) do
    rows[#rows + 1] = {
      key = "preset" .. preset.file, type = "Preset", number = "", name = preset.name, group = "USER",
      value = preset_id(preset.name), preset = preset,
    }
  end
  return rows
end

local ALL_GROUPS = "All groups"

-- The groups of the table in the order that they first appear, after "All groups".
local function group_names(rows)
  local names, seen = { ALL_GROUPS }, {}
  for _, row in ipairs(rows) do
    if row.group ~= "" and not seen[row.group] then
      seen[row.group] = true
      names[#names + 1] = row.group
    end
  end
  return names
end

-- Whether the type and the group filters let a row through. The search text is not part of it: it
-- ranks the rows that remain, in `shown_rows`.
local function matches(row, type_filter, group_filter)
  if type_filter ~= "All" and row.type ~= type_filter then return false end
  if group_filter ~= ALL_GROUPS and row.group ~= group_filter then return false end
  return true
end

-- What the search is matched against: the name first, then the group, the number and the type.
local function search_text(row)
  return row.name .. " " .. row.group .. " " .. row.number .. " " .. row.type
end

local function load_registration(S, entry)
  if S.model_api.load_registration(S.model, entry) then
    S.notice(("Loaded registration %d-%d."):format(entry.bank, entry.slot), false)
  else
    S.notice(("Could not load registration %d-%d."):format(entry.bank, entry.slot), true)
  end
end

-- Because the lab has no tone parameters yet, a tone only moves the choice of the upper part (a
-- position in its list), the same way the Tones tab does.
local function load_patch(S, row)
  if row.registration then
    load_registration(S, row.registration)
  elseif row.preset then
    -- The lab's mock keyboard cannot read a preset file; the plugin has the real one.
    return
  elseif row.tone.part then
    S.ui.tone[row.tone.part] = row.tone.index
    S.notice(("Loaded tone %s on the upper part (mock)."):format(row.name), false)
  else
    S.notice("The lab does not load drum kits yet.", false)
  end
end

local PATCH_TABLE_FLAGS = ImGui.TableFlags_RowBg | ImGui.TableFlags_Borders | ImGui.TableFlags_ScrollY
  | ImGui.TableFlags_Sortable

-- The text that a row is ordered by when the table is sorted by `column` (counted from 0). Because
-- names and groups are compared in lower case, capitals do not sort apart from small letters. The
-- patch ID is not part of the text; it only breaks ties, in `key_less`.
local function sort_key(row, column)
  if column == 0 then return row.type end
  if column == 2 then return row.name:lower() end
  if column == 3 then return row.group:lower() end
  return ""
end

-- Because the text of two rows can be the same, or empty, the patch ID decides then, and the order is
-- the same from one frame to the next. A sort by the ID itself compares the numbers.
local function key_less(a, b)
  if a.sort_key ~= b.sort_key then return a.sort_key < b.sort_key end
  return a.value < b.value
end

local function sort_rows(rows, column, descending)
  for _, row in ipairs(rows) do row.sort_key = sort_key(row, column) end
  table.sort(rows, key_less)
  if not descending then return end
  local first, last = 1, #rows
  while first < last do
    rows[first], rows[last] = rows[last], rows[first]
    first, last = first + 1, last - 1
  end
end

-- The rows that the filters let through. A search ranks them by how well they match, best first.
local function shown_rows(rows, ui)
  local shown = {}
  for _, row in ipairs(rows) do
    if matches(row, ui.patch_type, ui.patch_group) then shown[#shown + 1] = row end
  end
  if ui.patch_filter == "" then return shown end
  local texts = {}
  for i, row in ipairs(shown) do texts[i] = search_text(row) end
  local ranked = {}
  for k, index in ipairs(module("fuzzy").rank(ui.patch_filter, texts)) do ranked[k] = shown[index] end
  return ranked
end

local SORT_COLUMNS = { "Type", "No.", "Name", "Group", "Patch ID" }

-- A small button, "Add" with an arrow pointing to the scenes. Because the font has no arrow, the arrow
-- is drawn as a triangle on the right of the button, in the room that trailing spaces leave.
local function add_button(ctx, th, id)
  local clicked = ImGui.SmallButton(ctx, "Add    ##" .. id)
  local left, top = ImGui.GetItemRectMin(ctx)
  local right, bottom = ImGui.GetItemRectMax(ctx)
  local x, y = right - 10, (top + bottom) / 2
  ImGui.DrawList_AddTriangleFilled(ImGui.GetWindowDrawList(ctx), x - 3, y - 4, x - 3, y + 4, x + 3, y, th.text)
  return clicked
end

-- The library's rows by patch ID.
local function patches_by_id(S)
  local by_id = {}
  for _, row in ipairs(patch_rows(S)) do by_id[row.value] = row end
  return by_id
end

-- ---- the link to the plugin ----
--
-- The scenes live in the plugin, which keeps them in the project. The lab asks the plugin to add, move
-- or remove them, and shows the list that the plugin has, so what the panel shows is what a lane plays.

local function link()
  return module("scene_link")
end

-- The fields of a plugin command are separated by `|`, so a name must not hold one.
local function field(text)
  return (text:gsub("|", "/"))
end

-- Whether two lists of scenes say the same, so that a list that did not change keeps its rows' IDs.
local function same_scenes(a, b)
  if #a ~= #b then return false end
  for i, scene in ipairs(a) do
    if scene.name ~= b[i].name or scene.patch_id ~= b[i].patch_id or scene.label ~= b[i].label then return false end
  end
  return true
end

-- Makes the lab's list the plugin's. A list that did not change is left alone, because the rows are
-- known by an ID while one of them is dragged.
local function sync_scenes(S, target)
  local reply = link().command(target, "scenes")
  if not link().ok(reply) then return end
  local list, current = link().read_scenes(reply)
  S.ui.scene_current = current
  if same_scenes(S.ui.scenes, list) then return end
  for i, scene in ipairs(list) do
    scene.patch = { name = scene.label ~= "" and scene.label or "(the plugin's state)", value = scene.patch_id }
    local old = S.ui.scenes[i]
    if old and old.name == scene.name and old.patch_id == scene.patch_id then scene.uid = old.uid end
  end
  S.ui.scenes = list
  module("scenes").ensure_uids(list)
end

-- Puts a library row at the end of the session's scenes, as a scene of the given name.
local function add_to_scenes(S, row, scene_name)
  local target, reason = link().target()
  if not target then
    S.notice(reason, true)
    return
  end
  local name = field(scene_name or row.name)
  local reply
  if row.registration then
    reply = link().command(target, "scene_add", ("registrations/%s|%s|%d|%s"):format(row.registration.file, name, row.value, field(row.name)))
  elseif row.preset then
    reply = link().command(target, "scene_add", ("presets/%s|%s|%d|%s"):format(row.preset.file, name, row.value, field(row.name)))
  elseif row.tone.part then
    local tone = S.tones[row.tone.list][row.tone.index]
    local part = (row.tone.part:gsub("-", "_"))
    reply = link().command(target, "scene_add_tone", ("%s %d %d %d|%s|%d|%s"):format(part, tone.number, tone.msb, tone.lsb, name, row.value, field(row.name)))
  else
    S.notice("The lab does not make scenes of drum kits yet.", false)
    return
  end
  if not link().ok(reply) then
    S.notice(link().error_of(reply), true)
    return
  end
  sync_scenes(S, target)
  S.notice(("Added \"%s\" as scene %d."):format(name, #S.ui.scenes), false)
end

-- Sends a patch to the keyboard through the plugin: a registration is loaded from its file, and a tone
-- is written to its part. The lab's own copy of the keyboard follows, so the Controls tab shows it.
local function send_patch(S, row)
  local target, reason = link().target()
  if not target then
    S.notice(reason, true)
    return
  end
  local reply
  if row.registration then
    reply = link().command(target, "load_registration", row.registration.file)
  elseif row.preset then
    reply = link().command(target, "load_preset", row.preset.file)
  elseif row.tone.part then
    local tone = S.tones[row.tone.list][row.tone.index]
    local part = (row.tone.part:gsub("-", "_"))
    reply = link().command(target, "load_tone", ("%s %d %d %d|%s"):format(part, tone.number, tone.msb, tone.lsb, field(row.name)))
  else
    S.notice("The lab does not send drum kits yet.", false)
    return
  end
  if not link().ok(reply) then
    S.notice(link().error_of(reply), true)
    return
  end
  load_patch(S, row)
  S.notice(("Sent \"%s\" to the keyboard."):format(row.name), false)
end

local function patch_table(ctx, S)
  local th, ui = env.theme, S.ui
  local rows = patch_rows(S)
  -- Because the theme's header color is nearly the table's own gray, the selected row takes the accent.
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, th.amber & 0xFFFFFF00 | 0x70)
  if ImGui.BeginTable(ctx, "##patchtable", 6, PATCH_TABLE_FLAGS, 700, 360) then
    ImGui.TableSetupScrollFreeze(ctx, 0, 1)
    ImGui.TableSetupColumn(ctx, "Type", ImGui.TableColumnFlags_WidthFixed, 110)
    ImGui.TableSetupColumn(ctx, "No.", ImGui.TableColumnFlags_WidthFixed, 50)
    ImGui.TableSetupColumn(ctx, "Name", ImGui.TableColumnFlags_WidthStretch)
    ImGui.TableSetupColumn(ctx, "Group", ImGui.TableColumnFlags_WidthFixed, 90)
    ImGui.TableSetupColumn(ctx, "Patch ID", ImGui.TableColumnFlags_WidthFixed, 90)
    ImGui.TableSetupColumn(ctx, "Scenes", ImGui.TableColumnFlags_WidthFixed | ImGui.TableColumnFlags_NoSort, 72)
    ImGui.TableHeadersRow(ctx)
    local shown = shown_rows(rows, ui)
    -- The first sort spec is the column the player clicked last. Because the table may report it only
    -- on the frame of the click, and the rows are rebuilt each frame, the choice is kept in `ui`;
    -- without one, the table keeps the order of its list.
    -- ReaImGui returns the column's index before the user id that TableSetupColumn can give it.
    local has_spec, column, _, direction = ImGui.TableGetColumnSortSpecs(ctx, 0)
    if has_spec then
      ui.patch_sort = { column = column, descending = direction == ImGui.SortDirection_Descending }
    end
    -- While a search is typed, the rows stay in the order of their match.
    if ui.patch_sort and ui.patch_filter == "" then
      sort_rows(shown, ui.patch_sort.column, ui.patch_sort.descending)
    end
    for _, row in ipairs(shown) do
      ImGui.TableNextRow(ctx)
      ImGui.TableNextColumn(ctx)
      -- One click selects the row; a double click sends it to the keyboard.
      if ImGui.Selectable(ctx, row.type .. "##" .. row.key, ui.patch_selected == row.key, ImGui.SelectableFlags_SpanAllColumns | ImGui.SelectableFlags_AllowOverlap | ImGui.SelectableFlags_AllowDoubleClick) then
        ui.patch_selected = row.key
        if ImGui.IsMouseDoubleClicked(ctx, 0) then send_patch(S, row) end
      end
      ImGui.TableNextColumn(ctx)
      ImGui.Text(ctx, row.number)
      ImGui.TableNextColumn(ctx)
      ImGui.Text(ctx, row.name)
      ImGui.TableNextColumn(ctx)
      ImGui.TextColored(ctx, th.grey, row.group)
      ImGui.TableNextColumn(ctx)
      ImGui.Text(ctx, tostring(row.value))
      ImGui.TableNextColumn(ctx)
      if add_button(ctx, th, "add" .. row.key) then add_to_scenes(S, row) end
    end
    ImGui.EndTable(ctx)
  end
  ImGui.PopStyleColor(ctx)
  if ui.patch_filter ~= "" then
    ImGui.TextColored(ctx, th.grey, "Ranked by how well each patch matches the search. Clear the search to sort by a column.")
  elseif ui.patch_sort then
    ImGui.TextColored(ctx, th.grey, ("Sorted by %s, %s."):format(SORT_COLUMNS[ui.patch_sort.column + 1] or "?", ui.patch_sort.descending and "descending" or "ascending"))
  else
    ImGui.TextColored(ctx, th.grey, "In list order. Click a header to sort.")
  end
end

-- ---- the session's scenes ----
--
-- The scenes are copies of patches that live in the plugin's saved state, and the Scene parameter holds
-- a position in the list. The lab shows a mock lane of that parameter beside the list, to see that
-- moving or removing a scene moves the lane's points with it.

local function scene_label(scene)
  return ("%s  (%s)"):format(scene.name, scene.patch.name)
end

-- Sets the Scene parameter: the plugin loads the scene's patch. The lab's own copy of the keyboard
-- shows the patch too, when the library has it.
local function select_scene(S, position)
  local target, reason = link().target()
  if not target then
    S.notice(reason, true)
    return
  end
  local reply = link().command(target, "scene_select", tostring(position))
  if not link().ok(reply) then
    S.notice(link().error_of(reply), true)
    return
  end
  S.ui.scene_current = position
  local scene = S.ui.scenes[position]
  local row = scene and scene.patch_id > 0 and patches_by_id(S)[scene.patch_id]
  if row then load_patch(S, row) end
end

-- Moves a scene. The plugin answers with where every position went, and the lane's points follow,
-- so that the song keeps playing the same scenes. The list moves at once, so that a dragged row stays
-- under the mouse.
local function move_scene(S, from, to)
  local target = link().target()
  if not target then return end
  local reply = link().command(target, "scene_move", ("%d,%d"):format(from, to))
  if not link().ok(reply) then
    S.notice(link().error_of(reply), true)
    return
  end
  module("scenes").move(S.ui.scenes, {}, from, to)
  local map = link().read_map(reply)
  local changed = map and link().remap_lane(target, map) or 0
  S.ui.scene_current = map and map[S.ui.scene_current] or S.ui.scene_current
  if changed > 0 then S.notice(("Moved a scene; %d lane points moved with it."):format(changed), false) end
end

local function remove_scene(S, position)
  local target = link().target()
  if not target then return end
  local reply = link().command(target, "scene_remove", tostring(position))
  if not link().ok(reply) then
    S.notice(link().error_of(reply), true)
    return
  end
  module("scenes").remove(S.ui.scenes, {}, position)
  local map = link().read_map(reply)
  local changed = map and link().remap_lane(target, map) or 0
  S.ui.scene_current = map and map[S.ui.scene_current] or 0
  S.notice(("Removed scene %d; %d lane points moved with it."):format(position, changed), false)
end

local function rename_scene(S, position, name)
  local target = link().target()
  if not target then return end
  link().command(target, "scene_rename", ("%d|%s"):format(position, field(name)))
end

local SCENE_TABLE_FLAGS = ImGui.TableFlags_RowBg | ImGui.TableFlags_Borders

-- Whether the mouse has left the item above or below, which says to move the dragged scene one place.
-- Returns -1, 1 or 0. Because the scene then sits under the mouse again, the next step needs the
-- mouse to leave it again.
local function drag_step(ctx)
  if not ImGui.IsItemActive(ctx) or ImGui.IsItemHovered(ctx) then return 0 end
  local _, mouse_y = ImGui.GetMousePos(ctx)
  local _, top = ImGui.GetItemRectMin(ctx)
  local _, bottom = ImGui.GetItemRectMax(ctx)
  if mouse_y < top then return -1 end
  if mouse_y > bottom then return 1 end
  return 0
end

-- The scene's name: plain text, which becomes a text input on a double click and goes back to text when
-- the player presses Enter or leaves the field. Because a name is read far more often than it is
-- changed, it is not an input by default. Returns whether the name was clicked.
local function scene_name_cell(ctx, S, scene, position)
  local ui = S.ui
  if ui.scene_editing ~= scene.uid then
    local shown = scene.name ~= "" and scene.name or "(no name)"
    local clicked = ImGui.Selectable(ctx, shown .. "##scenename", false, ImGui.SelectableFlags_AllowOverlap)
    if ImGui.IsItemHovered(ctx) and ImGui.IsMouseDoubleClicked(ctx, 0) then
      ui.scene_editing, ui.scene_focus = scene.uid, true
    end
    return clicked
  end
  ImGui.SetNextItemWidth(ctx, -1)
  -- The field takes the keyboard on the frame that it appears, with its text selected.
  if ui.scene_focus then
    ImGui.SetKeyboardFocusHere(ctx)
    ui.scene_focus = false
  end
  local _
  _, scene.name = ImGui.InputText(ctx, "##name", scene.name, ImGui.InputTextFlags_AutoSelectAll)
  if ImGui.IsItemDeactivated(ctx) or ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter) then
    ui.scene_editing = nil
    rename_scene(S, position, scene.name)
  end
  return false
end

local function scene_rows(ctx, S)
  local th, ui, scenes = env.theme, S.ui, module("scenes")
  local move_from, move_to, remove_at
  scenes.ensure_uids(ui.scenes)
  ImGui.PushStyleColor(ctx, ImGui.Col_Header, th.amber & 0xFFFFFF00 | 0x70)
  if ImGui.BeginTable(ctx, "##scenetable", 4, SCENE_TABLE_FLAGS) then
    ImGui.TableSetupColumn(ctx, "Param #", ImGui.TableColumnFlags_WidthFixed, 70)
    ImGui.TableSetupColumn(ctx, "Scene", ImGui.TableColumnFlags_WidthFixed, 170)
    ImGui.TableSetupColumn(ctx, "Patch", ImGui.TableColumnFlags_WidthStretch)
    ImGui.TableSetupColumn(ctx, "##remove", ImGui.TableColumnFlags_WidthFixed | ImGui.TableColumnFlags_NoHeaderLabel, 70)
    ImGui.TableHeadersRow(ctx)
    for i, scene in ipairs(ui.scenes) do
      -- Because the rows change places while one is dragged, each is known by the ID of its scene.
      ImGui.PushID(ctx, scene.uid)
      ImGui.TableNextRow(ctx)
      ImGui.TableNextColumn(ctx)
      -- Because ImGui knows an item by its label, the label must not hold the position: a row that
      -- changes its label while it is dragged would lose the mouse, and the window would move instead.
      -- The position is drawn over the item afterwards, with the draw list so that the cursor stays put.
      local cell_x, cell_y = ImGui.GetCursorScreenPos(ctx)
      -- The item spans the row, so that a click anywhere on it selects the scene and a drag from anywhere
      -- on it moves the scene; the name and the Remove button are drawn over it and take their own clicks.
      local clicked = ImGui.Selectable(ctx, "##grab", ui.scene_current == i, ImGui.SelectableFlags_SpanAllColumns | ImGui.SelectableFlags_AllowOverlap)
      local step = drag_step(ctx)
      ImGui.DrawList_AddText(ImGui.GetWindowDrawList(ctx), cell_x + 4, cell_y, th.text, tostring(i))
      if step ~= 0 and i + step >= 1 and i + step <= #ui.scenes then
        move_from, move_to = i, i + step
        ui.scene_dragged = true
      end
      -- A click that ends a drag does not select the scene.
      if clicked and not ui.scene_dragged then select_scene(S, i) end
      ImGui.TableNextColumn(ctx)
      -- A click on the name selects the scene too, and a double click edits the name.
      if scene_name_cell(ctx, S, scene, i) and not ui.scene_dragged then select_scene(S, i) end
      ImGui.TableNextColumn(ctx)
      ImGui.TextColored(ctx, th.grey, scene.patch.name)
      ImGui.TableNextColumn(ctx)
      if ImGui.SmallButton(ctx, "Remove") then remove_at = i end
      ImGui.PopID(ctx)
    end
    ImGui.EndTable(ctx)
  end
  ImGui.PopStyleColor(ctx)
  if not ImGui.IsMouseDown(ctx, 0) then ui.scene_dragged = false end
  -- Because a move changes the list that the loop above reads, it is applied after the loop.
  if move_from then
    move_scene(S, move_from, move_to)
  elseif remove_at then
    remove_scene(S, remove_at)
  end
end

-- ---- the scene templates ----
--
-- A template is a file of `Data/Perken/vr09/scenes`: the session's scenes by name and patch ID, so
-- that a set can be loaded into another session.

local TEMPLATE_EXTENSION = ".scenes"

local function templates_folder(S)
  return S.model.data .. "/scenes"
end

-- Keeps the letters, digits, spaces, dashes and underscores, because the name becomes a file name.
local function template_file_name(name)
  local clean = name:gsub("[^%w _%-]", ""):gsub("^%s+", ""):gsub("%s+$", "")
  if clean == "" then return nil end
  return clean
end

local function read_text(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local text = f:read("a")
  f:close()
  return text
end

local function template_names(S)
  local names, i = {}, 0
  local folder = templates_folder(S)
  while true do
    local file = reaper.EnumerateFiles(folder, i)
    if not file then break end
    i = i + 1
    local name = file:match("^(.+)" .. TEMPLATE_EXTENSION:gsub("%.", "%%.") .. "$")
    if name then names[#names + 1] = name end
  end
  table.sort(names, module("scenes").text_less)
  return names
end

local function save_template(S, name)
  local clean = template_file_name(name)
  if not clean then
    S.notice("Give the template a name first.", true)
    return
  end
  reaper.RecursiveCreateDirectory(templates_folder(S), 0)
  local f = io.open(templates_folder(S) .. "/" .. clean .. TEMPLATE_EXTENSION, "wb")
  if not f then
    S.notice("Could not write the template.", true)
    return
  end
  f:write(module("scenes").to_text(S.ui.scenes))
  f:close()
  S.notice(("Saved %d scenes as the template \"%s\"."):format(#S.ui.scenes, clean), false)
end

-- Loads a template: it replaces the session's scenes, or goes after them. The plugin gets each scene
-- from the library, by the patch ID that the template holds.
local function load_template(S, name, append)
  local text = read_text(templates_folder(S) .. "/" .. name .. TEMPLATE_EXTENSION)
  if not text then
    S.notice("Could not read the template.", true)
    return
  end
  local target, reason = link().target()
  if not target then
    S.notice(reason, true)
    return
  end
  local list, missing = module("scenes").from_text(text, patches_by_id(S))
  if not append then link().command(target, "scene_clear") end
  for _, scene in ipairs(list) do add_to_scenes(S, scene.patch, scene.name) end
  sync_scenes(S, target)
  local note = missing > 0 and ("; %d scenes left out, their patches are not in the library"):format(missing) or ""
  S.notice(("Loaded the template \"%s\"%s."):format(name, note), missing > 0)
end

local function templates(ctx, S)
  local th, ui, widgets = env.theme, S.ui, env.widgets
  ui.template_name = ui.template_name or ""
  if not ImGui.CollapsingHeader(ctx, "Scene templates") then return end
  ImGui.SetNextItemWidth(ctx, 240)
  local _
  _, ui.template_name = ImGui.InputTextWithHint(ctx, "##templatename", "name of the template", ui.template_name)
  ImGui.SameLine(ctx)
  if widgets.push_button(ctx, "Save the scenes as a template") then save_template(S, ui.template_name) end
  local names = template_names(S)
  if #names == 0 then ImGui.TextColored(ctx, th.grey, "No templates yet.") end
  if ImGui.BeginChild(ctx, "##templates", 460, 110) then
    for _, name in ipairs(names) do
      if ImGui.Selectable(ctx, name .. "##tpl" .. name, ui.template_selected == name) then
        ui.template_selected, ui.template_name = name, name
      end
    end
    ImGui.EndChild(ctx)
  end
  local chosen = ui.template_selected
  if chosen then
    if widgets.push_button(ctx, "Load, replacing the scenes") then load_template(S, chosen, false) end
    ImGui.SameLine(ctx)
    if widgets.push_button(ctx, "Add to the scenes") then load_template(S, chosen, true) end
    ImGui.SameLine(ctx)
    if widgets.push_button(ctx, "Delete") then
      os.remove(templates_folder(S) .. "/" .. chosen .. TEMPLATE_EXTENSION)
      ui.template_selected = nil
    end
  end
end

-- Puts a square point at the edit cursor on the lane of the Scene parameter, set to the selected scene.
-- The lane is created when the track does not have one yet.
local function insert_scene_point(S)
  local target, reason = link().target()
  if not target then
    S.notice(reason, true)
    return
  end
  if S.ui.scene_current < 1 then
    S.notice("Select a scene first: click its row.", true)
    return
  end
  local time, problem = link().insert_point(target, S.ui.scene_current)
  if not time then
    S.notice(problem, true)
    return
  end
  S.notice(("Inserted scene %d at %.2f s."):format(S.ui.scene_current, time), false)
end

local function scene_list(ctx, S)
  local th, ui, widgets = env.theme, S.ui, env.widgets
  if not widgets.begin_card(ctx, "Scenes of this session") then return end
  local target, reason = link().target()
  -- The list follows the plugin a few times a second, except while a row is dragged or a name is edited.
  if target and S.frame % 15 == 0 and not ui.scene_dragged and ui.scene_editing == nil then sync_scenes(S, target) end
  if not target then
    ImGui.TextColored(ctx, th.amber, reason)
  elseif #ui.scenes == 0 then
    ImGui.TextColored(ctx, th.grey, "No scenes yet. Press Add on a patch.")
  else
    scene_rows(ctx, S)
  end
  ImGui.Separator(ctx)
  local current = ui.scenes[ui.scene_current]
  ImGui.Text(ctx, ("Scene parameter: %d  %s"):format(ui.scene_current, current and current.name or "(no scene)"))
  if widgets.push_button(ctx, "Insert a lane point at the cursor") then insert_scene_point(S) end
  widgets.tooltip(ctx, "Puts a square point on the Scene parameter's lane at the edit cursor, set to the selected scene. The lane is created if the track does not have one yet.")
  templates(ctx, S)
  widgets.end_card(ctx)
end

-- Saves the keyboard as a preset, which then shows in the table. The plugin reads the keyboard first and
-- writes the file when the read ends, which takes a moment, so the button only starts it and `poll_save`
-- follows it.
local function save_keyboard(S, name)
  local target, reason = link().target()
  if not target then
    S.notice(reason, true)
    return
  end
  local reply = link().command(target, "save_preset", field(name))
  if not link().ok(reply) then
    S.notice(link().error_of(reply), true)
    return
  end
  S.ui.saving = true
end

-- Asks the plugin how the save is going, a few times a second, and reports when it ends.
local function poll_save(S)
  local ui = S.ui
  if not ui.saving or S.frame % 5 ~= 0 then return end
  local target = link().target()
  if not target then
    ui.saving = false
    return
  end
  local reply = link().command(target, "save_status")
  local state = reply and reply:match('"state":"(%a+)"')
  if state == "reading" then return end
  ui.saving = false
  if state == "done" then
    local file = reply:match('"file":"(.-)"') or "the preset"
    local known = tonumber(reply:match('"known":(%d+)')) or 0
    local total = tonumber(reply:match('"total":(%d+)')) or 0
    presets_changed(S)
    ui.patch_selected = "preset" .. file
    ui.save_name = ""
    -- A read that missed blocks gives a patch with gaps, which the notice must not hide.
    if total > 0 and known < total // 2 then
      S.notice(("Saved %s, but only %d of %d bytes of the keyboard were read."):format(file, known, total), true)
    else
      S.notice(("Read the keyboard and saved it as %s."):format(file), false)
    end
  else
    S.notice("The keyboard was not saved: " .. (reply and reply:match('"error":"(.-)"') or "no answer from the plugin") .. ".", true)
  end
end

-- Deletes the selected preset, after a second click. Registrations and tones cannot be deleted.
local function delete_preset(S, row)
  local target, reason = link().target()
  if not target then
    S.notice(reason, true)
    return
  end
  local reply = link().command(target, "delete_preset", row.preset.file)
  if not link().ok(reply) then
    S.notice(link().error_of(reply), true)
    return
  end
  presets_changed(S)
  S.ui.patch_selected, S.ui.delete_armed = nil, nil
  S.notice(("Deleted the preset %s."):format(row.name), false)
end

-- The row that is selected in the table, if it is one of the player's presets.
local function selected_preset(S)
  if not S.ui.patch_selected then return nil end
  for _, row in ipairs(patch_rows(S)) do
    if row.key == S.ui.patch_selected and row.preset then return row end
  end
  return nil
end

local function save_row(ctx, S)
  local ui, widgets = S.ui, env.widgets
  ui.save_name = ui.save_name or ""
  poll_save(S)
  ImGui.SetNextItemWidth(ctx, 280)
  local _
  _, ui.save_name = ImGui.InputTextWithHint(ctx, "##savename", "name of the new patch", ui.save_name)
  ImGui.SameLine(ctx)
  if ui.saving then
    ImGui.TextColored(ctx, env.theme.amber, "Reading the keyboard...")
  elseif widgets.push_button(ctx, "Save the keyboard as a patch") then
    save_keyboard(S, ui.save_name)
  end
  widgets.tooltip(ctx, "Reads the keyboard, then saves what it holds as a preset under this name. The preset then appears in the table, where it can be sent to the keyboard or added to the scenes.")
  local preset = selected_preset(S)
  if preset then
    ImGui.SameLine(ctx)
    local armed = ui.delete_armed == preset.key
    if widgets.push_button(ctx, armed and "Click again to delete" or "Delete the selected preset") then
      if armed then delete_preset(S, preset) else ui.delete_armed = preset.key end
    end
  else
    ui.delete_armed = nil
  end
end

local function patch_list(ctx, S)
  local m, th, ui, widgets = S.model, env.theme, S.ui, env.widgets
  -- Because these fields keep their values between frames, they start here the first time.
  ui.patch_type = ui.patch_type or "All"
  ui.patch_filter = ui.patch_filter or ""
  ui.patch_group = ui.patch_group or ALL_GROUPS
  if not widgets.begin_card(ctx, "Patches") then return end
  if #m.registrations == 0 then
    ImGui.TextColored(ctx, th.grey, "No registrations folder: run build-install.sh vr09 to fill Data/Perken/vr09/registrations.")
  end
  ImGui.SetNextItemWidth(ctx, 280)
  local _
  _, ui.patch_filter = ImGui.InputTextWithHint(ctx, "##patchfilter", "search: name, group, number (letters in order)", ui.patch_filter)
  ImGui.SameLine(ctx)
  ImGui.SetNextItemWidth(ctx, 140)
  if ImGui.BeginCombo(ctx, "##patchtype", ui.patch_type) then
    for _, kind in ipairs(PATCH_TYPES) do
      if ImGui.Selectable(ctx, kind, ui.patch_type == kind) then ui.patch_type = kind end
    end
    ImGui.EndCombo(ctx)
  end
  ImGui.SameLine(ctx)
  ImGui.SetNextItemWidth(ctx, 140)
  if ImGui.BeginCombo(ctx, "##patchgroup", ui.patch_group) then
    for _, name in ipairs(group_names(patch_rows(S))) do
      if ImGui.Selectable(ctx, name, ui.patch_group == name) then ui.patch_group = name end
    end
    ImGui.EndCombo(ctx)
  end
  patch_table(ctx, S)
  save_row(ctx, S)
  widgets.end_card(ctx)
end

local function patches(ctx, S)
  local m, widgets = S.model, env.widgets
  if widgets.begin_card(ctx, "Keyboard") then
    if widgets.push_button(ctx, "Read the keyboard") then
      S.start_job("Reading", 22)
      S.notice("Reading the keyboard's state into this plugin.", false)
    end
    if widgets.push_button(ctx, "Send to the keyboard") then
      S.start_job("Writing", 66)
      S.notice("Writing this plugin's state to the keyboard.", false)
    end
    widgets.tooltip(ctx, "Only what differs is written: about 0.15 seconds when the keyboard has been read, a few seconds otherwise.")
    widgets.end_card(ctx)
  end
  ImGui.SameLine(ctx)
  if widgets.begin_card(ctx, "Options") then
    local _
    _, m.split = widgets.toggle(ctx, "This patch splits at middle C", m.split)
    widgets.tooltip(ctx, "The keyboard cannot report its split. When this is on, the track's notes below middle C go to the Lower part (channel 3) and the others to the Upper part (channel 4); when off, every note goes to the Upper part. The setting is remembered for this patch.")
    _, m.follow_panel = widgets.toggle(ctx, "Follow changes made on the keyboard's panel", m.follow_panel)
    _, m.recall_on_load = widgets.toggle(ctx, "Send the patch to the keyboard when the project opens", m.recall_on_load)
    widgets.end_card(ctx)
  end
end

-- The Scenes tab: the library of patches, and beside it the session's scenes and the templates.
local function scenes_tab(ctx, S)
  patch_list(ctx, S)
  ImGui.SameLine(ctx)
  scene_list(ctx, S)
end

-- ---- the audio loop and MIDI tabs (mock) ----

-- The loop's settings are not parameters of the catalog, so the knobs and the switch get parameters
-- of their own: the levels go from -60 to 12 dB and rest at 0 dB.
local LOOP_SWITCH = { id = "loop-on", low = 0, high = 1 }
local LOOP_SEND = { id = "loop-send", low = -60, high = 12, default = 0, unit = " dB" }
local LOOP_RETURN = { id = "loop-return", low = -60, high = 12, default = 0, unit = " dB" }

local function audio_loop(ctx, S)
  local ui, th, widgets = S.ui, env.theme, env.widgets
  ImGui.PushTextWrapPos(ctx, ImGui.GetCursorPosX(ctx) + 560)
  ImGui.TextColored(ctx, th.label, "The loop sends this track's audio to the keyboard's audio input and takes the keyboard's output back, the way ReaInsert does for outboard gear. Wire the interface's output to the keyboard's input, and the keyboard's output to the interface's input.")
  ImGui.PopTextWrapPos(ctx)
  ImGui.Spacing(ctx)

  if widgets.begin_card(ctx, "Loop") then
    widgets.bracket_row(ctx, { { label = "Levels", from = 2, to = 3 } }, 3)
    local changed, v = widgets.switch(ctx, LOOP_SWITCH, ui.loop_on and 1 or 0, "audio loop", "ON", "OFF")
    if changed then ui.loop_on = v == 1 end
    -- Because the two knobs draw the same widgets, each one gets an id of its own.
    ImGui.SameLine(ctx)
    ImGui.PushID(ctx, LOOP_SEND.id)
    changed, v = widgets.knob(ctx, LOOP_SEND, ui.send_db, "send level")
    ImGui.PopID(ctx)
    if changed then ui.send_db = v end
    ImGui.SameLine(ctx)
    ImGui.PushID(ctx, LOOP_RETURN.id)
    changed, v = widgets.knob(ctx, LOOP_RETURN, ui.return_db, "return level")
    ImGui.PopID(ctx)
    if changed then ui.return_db = v end
    widgets.lamp(ctx, ui.loop_on and th.green or th.amber, ui.loop_on)
    ImGui.SameLine(ctx)
    -- Because the card grows with its widest line, the line is padded to the width of the longer of its
    -- two texts, so that the card keeps its width when the loop is switched on and off.
    local running, idle = "The loop is running.", "The loop is off: the audio passes through."
    local status = ui.loop_on and running or idle
    ImGui.TextColored(ctx, ui.loop_on and th.green or th.amber, status)
    -- Because CalcTextSize returns a width and a height, each width is read into a variable of its own.
    local running_w = ImGui.CalcTextSize(ctx, running)
    local idle_w = ImGui.CalcTextSize(ctx, idle)
    local status_w = ui.loop_on and running_w or idle_w
    ImGui.SameLine(ctx, 0, 0)
    ImGui.Dummy(ctx, math.max(running_w, idle_w) - status_w, 1)
    widgets.end_card(ctx)
  end

  if widgets.begin_card(ctx, "Latency") then
    if widgets.push_button(ctx, "Measure the round trip") then S.notice("Measuring (mock).", false) end
    ImGui.SameLine(ctx)
    widgets.display(ctx, "not measured yet", th.text_dim, 160)
    widgets.end_card(ctx)
  end
end

local DEVICES = { "none", "Roland VR-09 (mock)", "MIDI Output 2", "MIDI Output 3" }

local function device_combo(ctx, id, current)
  local result = current
  ImGui.SetNextItemWidth(ctx, 360)
  if ImGui.BeginCombo(ctx, id, DEVICES[current]) then
    for i, name in ipairs(DEVICES) do
      if ImGui.Selectable(ctx, name, current == i) then result = i end
    end
    ImGui.EndCombo(ctx)
  end
  return result
end

local function midi(ctx, S)
  local ui, th, widgets = S.ui, env.theme, env.widgets
  local _
  if widgets.begin_card(ctx, "The track's MIDI devices") then
    ImGui.TextColored(ctx, th.label, "MIDI output (to the keyboard)")
    ui.midi_out = device_combo(ctx, "##midiout", ui.midi_out)
    ImGui.TextColored(ctx, th.label, "MIDI input (record from the keyboard)")
    ui.midi_in = device_combo(ctx, "##midiin", ui.midi_in)
    _, ui.armed = widgets.toggle(ctx, "Record-arm the track", ui.armed)
    _, ui.monitor = widgets.toggle(ctx, "Monitor input", ui.monitor)
    widgets.end_card(ctx)
  end
  if widgets.begin_card(ctx, "Behavior") then
    _, ui.pass = widgets.toggle(ctx, "Pass this track's MIDI through to the keyboard", ui.pass)
    _, ui.bare = widgets.toggle(ctx, "Send SysEx without its F0 and F7 bytes", ui.bare)
    widgets.end_card(ctx)
  end
  if widgets.begin_card(ctx, "Connection") then
    if widgets.push_button(ctx, "Look for the keyboard again") then S.notice("Asking the keyboard who it is.", false) end
    widgets.display(ctx, "sent 137   received 654   bad checksums 0", th.amber, 360, true)
    ImGui.TextColored(ctx, th.grey, "(mock values)")
    widgets.end_card(ctx)
  end
end

-- ---- the window's content ----

function M.draw(ctx, S)
  header(ctx, S)
  if ImGui.BeginTabBar(ctx, "##tabs") then
    if begin_tab(ctx, "Controls") then
      controls(ctx, S)
      ImGui.EndTabItem(ctx)
    end
    if begin_tab(ctx, "Scenes") then
      scenes_tab(ctx, S)
      ImGui.EndTabItem(ctx)
    end
    if begin_tab(ctx, "Patches") then
      patches(ctx, S)
      ImGui.EndTabItem(ctx)
    end
    if begin_tab(ctx, "Audio loop") then
      audio_loop(ctx, S)
      ImGui.EndTabItem(ctx)
    end
    if begin_tab(ctx, "MIDI") then
      midi(ctx, S)
      ImGui.EndTabItem(ctx)
    end
    ImGui.EndTabBar(ctx)
  end
  if S.frame < S.notice_until and S.notice_text ~= "" then
    env.widgets.display(ctx, S.notice_text, S.notice_is_error and env.theme.red or env.theme.green, 0)
  end
end

return M
