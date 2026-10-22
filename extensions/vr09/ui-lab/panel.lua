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

local function controls(ctx, S)
  -- EndChild only follows a BeginChild that returned true.
  if not ImGui.BeginChild(ctx, "##controls") then return end
  local widgets, catalog, values = env.widgets, S.model.catalog, S.model.values
  local drawn = {}
  for i, param in ipairs(catalog) do
    if not drawn[i] then
      -- One header per group, listing every parameter of the group once.
      local open = ImGui.CollapsingHeader(ctx, param.group, nil, ImGui.TreeNodeFlags_DefaultOpen)
      local as_drawbars = param.group:find("drawbars", 1, true) ~= nil
      for j = i, #catalog do
        local other = catalog[j]
        if not drawn[j] and other.group == param.group then
          drawn[j] = true
          if open then
            ImGui.PushID(ctx, other.id)
            local changed, v
            if as_drawbars then
              changed, v = widgets.drawbar(ctx, other, values[other.id])
            else
              changed, v = widgets.param_slider(ctx, other, values[other.id])
            end
            ImGui.PopID(ctx)
            if changed then values[other.id] = v end
            if as_drawbars then ImGui.SameLine(ctx) end
          end
        end
      end
      if open and as_drawbars then ImGui.NewLine(ctx) end
    end
  end
  ImGui.EndChild(ctx)
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
