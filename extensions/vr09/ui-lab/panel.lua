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

local function header(ctx, S)
  local m, th = S.model, env.theme
  if m.connected then
    if m.mode == "mode2" then
      ImGui.TextColored(ctx, th.green, "Keyboard connected (MIDI IN mode 2)")
    elseif m.mode == "mode1" then
      ImGui.TextColored(ctx, th.amber, "Keyboard connected, but in MIDI IN mode 1: switch it to mode 2")
    else
      ImGui.TextColored(ctx, th.amber, "Keyboard answers, mode unknown")
    end
  else
    ImGui.TextColored(ctx, th.red, "The keyboard does not answer: see the MIDI tab")
  end
  if m.job then
    local caption = ("%s %d/%d"):format(m.job.label, m.job.done, m.job.total)
    ImGui.ProgressBar(ctx, m.job.done / m.job.total, -1, nil, caption)
  end
  ImGui.Text(ctx, "Patch: " .. m.patch)
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
  if not widgets.begin_card(ctx, group.name) then return end
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

-- A card of knobs for the groups that hold levels, in one row. `strip` is what the labels start with
-- that the card's title already says, `bipolar` is true for values that rest in the middle, and
-- `brackets` lists the captions engraved over the knobs they group.
local function card_of_knobs(ctx, S, group, strip, bipolar, brackets)
  local widgets, values = env.widgets, S.model.values
  if not widgets.begin_card(ctx, group.name) then return end
  if brackets then widgets.bracket_row(ctx, brackets, #group.params) end
  for i, param in ipairs(group.params) do
    ImGui.PushID(ctx, param.id)
    local label = widgets.short_label(param.label, strip or group.name)
    local changed, v = widgets.knob(ctx, param, values[param.id], label, bipolar)
    ImGui.PopID(ctx)
    if changed then values[param.id] = v end
    if i < #group.params then ImGui.SameLine(ctx) end
  end
  widgets.end_card(ctx)
end

-- The rotary speaker: its switch and the three knobs of the woofer on one row, and the three knobs
-- of the tweeter under them. Because the catalog lists the switch first, then the woofer, then the
-- tweeter, the parameters are taken by their position.
local function card_of_rotary(ctx, S, group)
  local widgets, values = env.widgets, S.model.values
  if not widgets.begin_card(ctx, group.name) then return end
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

-- The synth's envelope and filter values rest in the middle of their range (64), so that their
-- knobs are bipolar. The card's title says which part it is, and its labels do not repeat it.
local function card_of_synth(ctx, S, group)
  local strip = group.name == "Synth upper" and "Upper synth" or "Lower synth"
  -- The catalog lists the resonance first, then the attack, the decay and the release.
  local brackets = {
    { label = "Filter", from = 1, to = 1 },
    { label = "Envelope", from = 2, to = 4 },
  }
  card_of_knobs(ctx, S, group, strip, true, brackets)
end

-- The groups drawn as a row of knobs, and the function that draws each one.
local CARDS_OF_KNOBS = {
  ["Organ"] = card_of_knobs,
  ["Rotary"] = card_of_rotary,
  ["Synth upper"] = card_of_synth,
  ["Synth lower"] = card_of_synth,
}

-- Because the synth's upper and lower parts are two panels of the same kind, their cards are put
-- one under the other, while the other knob cards share a row.
local STACKED = {
  ["Synth upper"] = true,
  ["Synth lower"] = true,
}

-- The instrument's sections, each one a tab, with the catalog's groups that it shows. Because the
-- catalog has no group for drums, the rhythm and song levels stay in the Mixer, and the piano's
-- volumes too.
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
  local m, th, ui = S.model, env.theme, S.ui
  ImGui.SeparatorText(ctx, "Registrations")
  local regs = m.registrations
  if #regs == 0 then
    ImGui.TextColored(ctx, th.grey, "No registrations folder: run build-install.sh vr09 to fill Data/Perken/vr09/registrations.")
    return
  end
  ImGui.SetNextItemWidth(ctx, 280)
  local _
  _, ui.reg_filter = ImGui.InputTextWithHint(ctx, "##regfilter", "filter by name or bank-slot", ui.reg_filter)
  if ImGui.BeginChild(ctx, "##registrations", -1, 200) then
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
end

local function patches(ctx, S)
  local m = S.model
  if ImGui.Button(ctx, "Read the keyboard") then
    S.start_job("Reading", 22)
    S.notice("Reading the keyboard's state into this plugin.", false)
  end
  ImGui.SameLine(ctx)
  if ImGui.Button(ctx, "Send to the keyboard") then
    S.start_job("Writing", 66)
    S.notice("Writing this plugin's state to the keyboard.", false)
  end
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "Only what differs is written: about 0.15 seconds when the keyboard has been read, a few seconds otherwise.")
  end

  local _
  _, m.split = ImGui.Checkbox(ctx, "This patch splits at middle C", m.split)
  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, "The keyboard cannot report its split. When this is on, the track's notes below middle C go to the Lower part (channel 3) and the others to the Upper part (channel 4); when off, every note goes to the Upper part. The setting is remembered for this patch.")
  end
  _, m.follow_panel = ImGui.Checkbox(ctx, "Follow changes made on the keyboard's panel", m.follow_panel)
  _, m.recall_on_load = ImGui.Checkbox(ctx, "Send the patch to the keyboard when the project opens", m.recall_on_load)

  registrations(ctx, S)
end

-- ---- the audio loop and MIDI tabs (mock) ----

local function audio_loop(ctx, S)
  local ui, th = S.ui, env.theme
  ImGui.TextWrapped(ctx, "The loop sends this track's audio to the keyboard's audio input and takes the keyboard's output back, the way ReaInsert does for outboard gear. Wire the interface's output to the keyboard's input, and the keyboard's output to the interface's input.")
  ImGui.Spacing(ctx)
  local _
  _, ui.loop_on = ImGui.Checkbox(ctx, "Use the audio loop", ui.loop_on)
  ImGui.SetNextItemWidth(ctx, 320)
  _, ui.send_db = ImGui.SliderInt(ctx, "Send level (dB)", ui.send_db, -60, 12)
  ImGui.SetNextItemWidth(ctx, 320)
  _, ui.return_db = ImGui.SliderInt(ctx, "Return level (dB)", ui.return_db, -60, 12)
  ImGui.SeparatorText(ctx, "Latency")
  if ImGui.Button(ctx, "Measure the round trip") then S.notice("Measuring (mock).", false) end
  ImGui.SameLine(ctx)
  ImGui.TextColored(ctx, th.grey, "not measured yet")
  ImGui.SeparatorText(ctx, "Status")
  ImGui.TextColored(ctx, ui.loop_on and th.green or th.amber, ui.loop_on and "The loop is running." or "The loop is off: the audio passes through.")
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
  local ui, th = S.ui, env.theme
  ImGui.SeparatorText(ctx, "The track's MIDI devices")
  ImGui.Text(ctx, "MIDI output (to the keyboard)")
  ui.midi_out = device_combo(ctx, "##midiout", ui.midi_out)
  ImGui.Text(ctx, "MIDI input (record from the keyboard)")
  ui.midi_in = device_combo(ctx, "##midiin", ui.midi_in)
  local _
  _, ui.armed = ImGui.Checkbox(ctx, "Record-arm the track", ui.armed)
  _, ui.monitor = ImGui.Checkbox(ctx, "Monitor input", ui.monitor)
  ImGui.SeparatorText(ctx, "Behavior")
  _, ui.pass = ImGui.Checkbox(ctx, "Pass this track's MIDI through to the keyboard", ui.pass)
  _, ui.bare = ImGui.Checkbox(ctx, "Send SysEx without its F0 and F7 bytes", ui.bare)
  ImGui.SeparatorText(ctx, "Connection")
  if ImGui.Button(ctx, "Look for the keyboard again") then S.notice("Asking the keyboard who it is.", false) end
  ImGui.Text(ctx, "Messages: sent 137, received 654, bad checksums 0")
  ImGui.TextColored(ctx, th.grey, "(mock values)")
end

-- ---- the window's content ----

function M.draw(ctx, S)
  header(ctx, S)
  ImGui.Separator(ctx)
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
    ImGui.Separator(ctx)
    ImGui.TextColored(ctx, S.notice_is_error and env.theme.red or env.theme.green, S.notice_text)
  end
end

return M
