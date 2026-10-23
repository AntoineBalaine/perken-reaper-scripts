-- The panel: header, tabs, notice. This is a port of what the plugin draws today (src/ui.zig), and
-- the file we edit live. Saving it redraws the open window at once; an error shows in the window
-- and the lab waits for the next save.
--
-- `S` is the lab's state: S.model (the mock keyboard), S.ui (what the panel remembers between
-- frames, such as the tab and the filter), S.notice(text, is_error), S.start_job(label, total).
local env = ...
local ImGui = env.ImGui

local M = {}

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

local function card_of_drawbars(ctx, S, group)
  local widgets, values = env.widgets, S.model.values
  if not widgets.begin_card(ctx, group.name, nil, nil, env.theme.part.organ) then return end
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
--   accent:        the card's accent color.
local function card_of_knobs(ctx, S, group, options)
  options = options or {}
  local widgets, values = env.widgets, S.model.values
  if not widgets.begin_card(ctx, options.title or group.name, nil, nil, options.accent) then return end
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
local function card_of_rotary(ctx, S, group)
  local widgets, values = env.widgets, S.model.values
  if not widgets.begin_card(ctx, group.name, nil, nil, env.theme.part.organ) then return end
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
local function card_of_organ(ctx, S, group)
  card_of_knobs(ctx, S, group, { accent = env.theme.part.organ })
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
    { title = "Upper", from = 3, to = 5, part = "upper" },
    { title = "Backing", from = 1, to = 2, part = "backing", beside_previous = true },
    { title = "Lower", from = 6, to = 7, part = "lower" },
  }
  for _, band in ipairs(bands) do
    options.title = band.title
    options.accent = env.theme.part[band.part]
    if band.beside_previous then ImGui.SameLine(ctx) end
    card_of_knobs(ctx, S, { name = band.title, params = slice(group.params, band.from, band.to) }, options)
  end
end

-- The piano: the volumes of its upper and lower parts, then the controllers of the piano that is
-- the second layer of a dual patch.
local function card_of_piano(ctx, S, group)
  local params = {}
  for _, id in ipairs(PIANO_VOLUMES) do
    params[#params + 1] = param_with_id(S.model.catalog, id)
  end
  for _, param in ipairs(group.params) do params[#params + 1] = param end
  local brackets = {
    { label = "Volume", from = 1, to = 2 },
    { label = "Dual 2", from = 3, to = 5 },
  }
  card_of_knobs(ctx, S, { name = "Piano", params = params },
    { strip = "Piano (dual 2)", suffixes = { " volume" }, brackets = brackets, accent = env.theme.part.piano })
end

-- The controllers that rest in the middle of their range (64) are bipolar knobs: the vibrato, the pan,
-- the cutoff, the resonance and the envelope. The others, the sends and the expression, are levels.
local BIPOLAR_CONTROLLERS = {
  ["cc-upper-vibrato-depth"] = true, ["cc-upper-vibrato-rate"] = true, ["cc-upper-pan"] = true,
  ["cc-upper-cutoff"] = true, ["cc-upper-resonance"] = true, ["cc-upper-release"] = true,
  ["cc-upper-attack"] = true, ["cc-upper-decay"] = true, ["cc-lower-cutoff"] = true,
}

-- The upper part has twelve controllers, in two rows of six. Because the catalog lists them in this
-- order, the brackets are placed by position: vibrato and sends over the first row, filter and
-- envelope over the second.
local function card_of_upper_controllers(ctx, S, group)
  card_of_knobs(ctx, S, group, {
    title = "Upper controllers", strip = "Upper", columns = 6, bipolar_ids = BIPOLAR_CONTROLLERS,
    accent = env.theme.part.upper,
    brackets_by_row = {
      { { label = "Vibrato", from = 1, to = 2 }, { label = "Sends", from = 3, to = 4 } },
      { { label = "Filter", from = 1, to = 2 }, { label = ENVELOPE_OF .. " envelope", from = 3, to = 5 } },
    },
  })
end

local function card_of_lower_controllers(ctx, S, group)
  card_of_knobs(ctx, S, group, { title = "Lower controllers", strip = "Lower", bipolar_ids = BIPOLAR_CONTROLLERS, accent = env.theme.part.lower })
end

local function card_of_master_controller(ctx, S, group)
  card_of_knobs(ctx, S, group, { title = "Master", accent = env.theme.part.master, labels = { ["cc-master-expression"] = "overall volume" } })
end

-- The effects, one card for each, in two rows. Each lists the ids of its parameters in the order
-- they are shown. A parameter with named values is a stop knob, and a level is a knob.
local EFFECT_ROWS = {
  {
    { title = "Reverb", color = "reverb", ids = { "reverb-type", "reverb-variation", "reverb-level" } },
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
    local param = param_with_id(S.model.catalog, id)
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
-- each card looks its parameters up by id. Because the cards of a row sit side by side, the first card
-- of a row sets the height of the others, so that the row has an even edge: in the second row, the
-- MFX card, with its display, sets the height of the delay and the compressor.
local function card_of_effects(ctx, S, group)
  for _, row in ipairs(EFFECT_ROWS) do
    local row_height = nil
    for i, effect in ipairs(row) do
      if i > 1 then ImGui.SameLine(ctx) end
      local _, height = card_of_effect(ctx, S, effect, row_height)
      if i == 1 then row_height = height end
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

-- The instrument's sections, each one a tab, with the catalog's groups that it shows. Because the
-- catalog has no group for drums, the rhythm and song levels stay in the Mixer. The piano's volumes
-- are in the Mixer, where the catalog lists them, and in the Piano tab as well.
local SECTIONS = {
  { name = "Organ", groups = { "Organ upper drawbars", "Organ lower drawbars", "Organ", "Rotary" } },
  { name = "Synth", groups = { "Synth upper", "Synth lower" } },
  { name = "Piano", groups = { "Control change piano" } },
  { name = "Mixer", groups = { "Mixer" } },
  { name = "FX", groups = { "Effects" } },
  { name = "Controllers", groups = { "Control change upper", "Control change lower", "Control change master" } },
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
local function section(ctx, S, names)
  if not ImGui.BeginChild(ctx, "##section") then return end
  local groups = groups_named(groups_of(S.model.catalog), names)
  local drawbars_drawn = false
  for _, group in ipairs(groups) do
    if group.drawbars then
      if drawbars_drawn then ImGui.SameLine(ctx) end
      card_of_drawbars(ctx, S, group)
      drawbars_drawn = true
    end
  end
  local knobs_drawn = false
  for _, group in ipairs(groups) do
    local card = CARDS_OF_KNOBS[group.name]
    if card then
      if knobs_drawn and not STACKED[group.name] then ImGui.SameLine(ctx) end
      card(ctx, S, group)
      knobs_drawn = true
    end
  end
  for _, group in ipairs(groups) do
    if not group.drawbars and not CARDS_OF_KNOBS[group.name] then card_of_sliders(ctx, S, group) end
  end
  ImGui.EndChild(ctx)
end

-- The Controls tab holds a tab bar of its own, with one tab for each section of the instrument.
local function controls(ctx, S)
  if not ImGui.BeginTabBar(ctx, "##sections") then return end
  for _, s in ipairs(SECTIONS) do
    if ImGui.BeginTabItem(ctx, s.name) then
      section(ctx, S, s.groups)
      ImGui.EndTabItem(ctx)
    end
  end
  ImGui.EndTabBar(ctx)
end

-- ---- the patches ----

local function matches(entry, filter)
  if filter == "" then return true end
  local f = filter:lower()
  if entry.name:lower():find(f, 1, true) then return true end
  return ("%d-%d"):format(entry.bank, entry.slot):find(f, 1, true) ~= nil
end

local function program_of(entry)
  return (entry.bank - 1) * 4 + entry.slot - 1
end

local function load_registration(S, entry)
  if S.model_api.load_registration(S.model, entry) then
    S.notice(("Loaded registration %d-%d."):format(entry.bank, entry.slot), false)
  else
    S.notice(("Could not load registration %d-%d."):format(entry.bank, entry.slot), true)
  end
end

local function registrations(ctx, S)
  local m, th, ui, widgets = S.model, env.theme, S.ui, env.widgets
  if not widgets.begin_card(ctx, "Registrations") then return end
  local regs = m.registrations
  if #regs == 0 then
    ImGui.TextColored(ctx, th.grey, "No registrations folder: run build-install.sh vr09 to fill Data/Perken/vr09/registrations.")
    widgets.end_card(ctx)
    return
  end
  ImGui.SetNextItemWidth(ctx, 280)
  local _
  _, ui.reg_filter = ImGui.InputTextWithHint(ctx, "##regfilter", "filter by name or bank-slot", ui.reg_filter)
  -- The list has a width of its own, because the card grows with what it holds.
  if ImGui.BeginChild(ctx, "##registrations", 460, 200) then
    local i = 1
    while i <= #regs do
      local bank = regs[i].bank
      local j, any = i, false
      while j <= #regs and regs[j].bank == bank do
        if matches(regs[j], ui.reg_filter) then any = true end
        j = j + 1
      end
      if any then
        -- A filter opens the banks that match, so the result is visible.
        if ui.reg_filter ~= "" then ImGui.SetNextItemOpen(ctx, true) end
        if ImGui.TreeNode(ctx, ("Bank %d##bank%d"):format(bank, bank)) then
          for k = i, j - 1 do
            local e = regs[k]
            if matches(e, ui.reg_filter) then
              local label = ("%d-%d  %s  (PC %d)##reg%d"):format(e.bank, e.slot, e.name:gsub("_", " "), program_of(e), k)
              local clicked = ImGui.Selectable(ctx, label, ui.reg_selected == k, ImGui.SelectableFlags_AllowDoubleClick)
              if clicked then
                ui.reg_selected = k
                if ImGui.IsMouseDoubleClicked(ctx, 0) then load_registration(S, e) end
              end
            end
          end
          ImGui.TreePop(ctx)
        end
      end
      i = j
    end
    ImGui.EndChild(ctx)
  end
  if ui.reg_selected and regs[ui.reg_selected] then
    if ImGui.Button(ctx, "Load and send registration") then load_registration(S, regs[ui.reg_selected]) end
  end
  widgets.end_card(ctx)
end

local function patches(ctx, S)
  local m, widgets = S.model, env.widgets
  if widgets.begin_card(ctx, "Keyboard") then
    if ImGui.Button(ctx, "Read the keyboard") then
      S.start_job("Reading", 22)
      S.notice("Reading the keyboard's state into this plugin.", false)
    end
    if ImGui.Button(ctx, "Send to the keyboard") then
      S.start_job("Writing", 66)
      S.notice("Writing this plugin's state to the keyboard.", false)
    end
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "Only what differs is written: about 0.15 seconds when the keyboard has been read, a few seconds otherwise.")
    end
    widgets.end_card(ctx)
  end
  ImGui.SameLine(ctx)
  if widgets.begin_card(ctx, "Options") then
    local _
    _, m.split = ImGui.Checkbox(ctx, "This patch splits at middle C", m.split)
    if ImGui.IsItemHovered(ctx) then
      ImGui.SetTooltip(ctx, "The keyboard cannot report its split. When this is on, the track's notes below middle C go to the Lower part (channel 3) and the others to the Upper part (channel 4); when off, every note goes to the Upper part. The setting is remembered for this patch.")
    end
    _, m.follow_panel = ImGui.Checkbox(ctx, "Follow changes made on the keyboard's panel", m.follow_panel)
    _, m.recall_on_load = ImGui.Checkbox(ctx, "Send the patch to the keyboard when the project opens", m.recall_on_load)
    widgets.end_card(ctx)
  end

  registrations(ctx, S)
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
    ImGui.TextColored(ctx, ui.loop_on and th.green or th.amber, ui.loop_on and "The loop is running." or "The loop is off: the audio passes through.")
    widgets.end_card(ctx)
  end

  if widgets.begin_card(ctx, "Latency") then
    if ImGui.Button(ctx, "Measure the round trip") then S.notice("Measuring (mock).", false) end
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
    _, ui.armed = ImGui.Checkbox(ctx, "Record-arm the track", ui.armed)
    _, ui.monitor = ImGui.Checkbox(ctx, "Monitor input", ui.monitor)
    widgets.end_card(ctx)
  end
  if widgets.begin_card(ctx, "Behavior") then
    _, ui.pass = ImGui.Checkbox(ctx, "Pass this track's MIDI through to the keyboard", ui.pass)
    _, ui.bare = ImGui.Checkbox(ctx, "Send SysEx without its F0 and F7 bytes", ui.bare)
    widgets.end_card(ctx)
  end
  if widgets.begin_card(ctx, "Connection") then
    if ImGui.Button(ctx, "Look for the keyboard again") then S.notice("Asking the keyboard who it is.", false) end
    widgets.display(ctx, "sent 137   received 654   bad checksums 0", th.amber, 360)
    ImGui.TextColored(ctx, th.grey, "(mock values)")
    widgets.end_card(ctx)
  end
end

-- ---- the window's content ----

function M.draw(ctx, S)
  header(ctx, S)
  if ImGui.BeginTabBar(ctx, "##tabs") then
    if ImGui.BeginTabItem(ctx, "Controls") then
      controls(ctx, S)
      ImGui.EndTabItem(ctx)
    end
    if ImGui.BeginTabItem(ctx, "Patches") then
      patches(ctx, S)
      ImGui.EndTabItem(ctx)
    end
    if ImGui.BeginTabItem(ctx, "Audio loop") then
      audio_loop(ctx, S)
      ImGui.EndTabItem(ctx)
    end
    if ImGui.BeginTabItem(ctx, "MIDI") then
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
