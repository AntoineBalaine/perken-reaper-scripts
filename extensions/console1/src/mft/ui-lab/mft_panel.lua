-- @noindex
-- The MFT panel: a MIDI Fighter Twister drawn as an object. A dark metal body with a recessed faceplate, sixteen
-- push encoders in four rows of four, each with a ring of eleven LEDs around a metal cap, and three keys on each
-- side. The top eight encoders show the parameters of the mode, or the transport functions, and the bottom eight
-- select the mode. Under the device are the settings form and the calibration card, which the settings mode shows.
-- Saving this file redraws the window at once.
--
-- A module reads what it needs from `env` when it runs, not when it loads, so that a reloaded `theme` takes effect
-- without reloading this file.
local env = ...
local ImGui = env.ImGui

local M = {}

-- ---- the sizes of the device, in pixels ----

local PITCH, ROW_H = 118, 136 -- the distance from one encoder to the next, across and down
local RING_R, WELL_R, CAP_R = 36, 30, 23 -- the ring of LEDs, the well that the cap sits in, and the cap
local SIDE_W, SIDE_H, SIDE_GAP = 76, 34, 14
local PAD, HEADER_H, FOOTER_H = 22, 46, 40
local LEDS = 11
local SWEEP_FROM, SWEEP_TO = math.pi * 0.75, math.pi * 2.25 -- the ring starts at the lower left and ends at the lower right

-- ---- colors ----

local function faded(color, alpha)
  return (color & 0xFFFFFF00) | alpha
end

local function byte(fraction, offset)
  return math.max(0, math.min(255, math.floor((fraction + offset) * 255 + 0.5)))
end

local function hsv_to_rgba(hue, saturation, value)
  local c = value * saturation
  local hp = hue / 60
  local x = c * (1 - math.abs(hp % 2 - 1))
  local r, g, b = 0, 0, 0
  if hp < 1 then
    r, g = c, x
  elseif hp < 2 then
    r, g = x, c
  elseif hp < 3 then
    g, b = c, x
  elseif hp < 4 then
    g, b = x, c
  elseif hp < 5 then
    r, b = x, c
  else
    r, b = c, x
  end
  local m = value - c
  return (byte(r, m) << 24) | (byte(g, m) << 16) | (byte(b, m) << 8) | 0xFF
end

-- The color of a hue of the controller's wheel, as the plugin's panel converts it: red sits near 86, and a higher
-- hue moves toward purple.
local function hue_to_rgba(hue)
  return hsv_to_rgba(((86 - hue) * 360 / 128) % 360, 1, 1)
end

-- ---- text ----

local function push_font(ctx, name)
  local font = env.fonts and env.fonts[name]
  if font then ImGui.PushFont(ctx, font) end
  return font ~= nil
end

-- Text centered on `cx`, with a dark copy one pixel below it, like lettering printed on the panel.
local function printed_text(ctx, dl, cx, y, text, color)
  local w = ImGui.CalcTextSize(ctx, text)
  ImGui.DrawList_AddText(dl, cx - w / 2, y + 1, 0x00000099, text)
  ImGui.DrawList_AddText(dl, cx - w / 2, y, color, text)
end

-- ---- the body ----

local SCREW_ANGLES = { 0.4, 1.2, 2.1, 2.9 }

local function draw_screw(dl, x, y, angle)
  local th = env.theme
  ImGui.DrawList_AddCircleFilled(dl, x + 1, y + 1, 4, 0x000000AA)
  ImGui.DrawList_AddCircleFilled(dl, x, y, 4, th.screw_body)
  ImGui.DrawList_AddCircle(dl, x, y, 4, th.card_bevel_dark, 0, 1)
  ImGui.DrawList_AddCircleFilled(dl, x - 1.2, y - 1.2, 1, th.screw_light)
  local dx, dy = math.cos(angle) * 2.8, math.sin(angle) * 2.8
  ImGui.DrawList_AddLine(dl, x - dx, y - dy, x + dx, y + dy, th.screw_slot, 1.5)
end

-- The case: anodized metal with a lit upper edge, a faint brushed grain, a bevel all around and a screw in each
-- corner.
local function draw_body(dl, x, y, w, h)
  ImGui.DrawList_AddRectFilled(dl, x + 3, y + 7, x + w + 3, y + h + 7, 0x00000088, 18)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, 0x1A1A1CFF, 16)
  ImGui.DrawList_AddRectFilledMultiColor(dl, x + 10, y + 3, x + w - 10, y + h * 0.55, 0xFFFFFF16, 0xFFFFFF16, 0xFFFFFF00, 0xFFFFFF00)
  for ly = y + 8, y + h - 8, 3 do ImGui.DrawList_AddLine(dl, x + 10, ly, x + w - 10, ly, 0xFFFFFF05, 1) end
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, 0x040405FF, 16, 0, 2)
  ImGui.DrawList_AddRect(dl, x + 2, y + 2, x + w - 2, y + h - 2, 0xFFFFFF1E, 15, 0, 1)
  draw_screw(dl, x + 13, y + 13, SCREW_ANGLES[1])
  draw_screw(dl, x + w - 13, y + 13, SCREW_ANGLES[2])
  draw_screw(dl, x + 13, y + h - 13, SCREW_ANGLES[3])
  draw_screw(dl, x + w - 13, y + h - 13, SCREW_ANGLES[4])
end

-- The faceplate of the encoders, cut into the case: a dark shade along its upper edge and a lit one along its lower.
local function draw_faceplate(dl, x, y, w, h)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + w, y + h, 0x0E0E10FF, 10)
  ImGui.DrawList_AddRect(dl, x, y, x + w, y + h, 0x000000DD, 10, 0, 2)
  ImGui.DrawList_AddLine(dl, x + 10, y + h + 1.5, x + w - 10, y + h + 1.5, 0xFFFFFF26, 1)
end

-- ---- an encoder ----

local WHITE = 0xF2F2F2FF

-- Draws one encoder around (cx, cy): a ring of eleven white LEDs around a round rubber cap that sits in a well. `e`
-- says what it shows:
--   value     0 to 1, where the ring ends and the pointer points; nil for a ring that shows nothing
--   lit_all   every LED of the ring is lit (the selected mode)
--   color     the color of the mode's LED, which is the accent of the cap's details
--   pressed   the cap is held down
--   hot       the mouse is over the cap
--   icon      the name of an icon to draw on the cap instead of the pointer
local function draw_encoder(dl, cx, cy, e)
  local color = e.color

  -- The ring: the LEDs are white, and lit up to the value.
  for i = 0, LEDS - 1 do
    local a = SWEEP_FROM + (SWEEP_TO - SWEEP_FROM) * i / (LEDS - 1)
    local x, y = cx + math.cos(a) * RING_R, cy + math.sin(a) * RING_R
    local lit = e.lit_all or (e.value ~= nil and i / (LEDS - 1) <= e.value + 0.001)
    if lit then
      ImGui.DrawList_AddCircleFilled(dl, x, y, 7, faded(WHITE, 0x30))
      ImGui.DrawList_AddCircleFilled(dl, x, y, 3.5, WHITE)
    else
      ImGui.DrawList_AddCircleFilled(dl, x, y, 3.2, 0x060607FF)
      ImGui.DrawList_AddCircle(dl, x, y, 3.2, 0xFFFFFF14, 0, 1)
    end
  end

  -- The well the cap sits in.
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, WELL_R, 0x070708FF)
  ImGui.DrawList_AddCircle(dl, cx, cy, WELL_R, 0x000000FF, 0, 2)
  ImGui.DrawList_AddCircle(dl, cx, cy + 1, WELL_R + 1, 0xFFFFFF18, 0, 1)

  -- The cap is rubber: matte, with a soft dome and fine ribs around its edge. It stands out of the well with a
  -- shadow under it, and sinks a little when it is pressed.
  local sink = e.pressed and 1.5 or 0
  local r = CAP_R - sink * 0.5
  local y = cy + sink
  ImGui.DrawList_AddCircleFilled(dl, cx + 1, cy + 3 - sink, r + 1, 0x000000AA)
  ImGui.DrawList_AddCircleFilled(dl, cx, y, r, 0x161617FF)
  ImGui.DrawList_AddCircleFilled(dl, cx - 1, y - 1, r - 3, 0x222224FF)
  ImGui.DrawList_AddCircleFilled(dl, cx - r * 0.3, y - r * 0.35, r * 0.45, 0xFFFFFF0A)
  for i = 0, 23 do
    local a = i * math.pi / 12
    ImGui.DrawList_AddLine(dl, cx + math.cos(a) * (r - 3), y + math.sin(a) * (r - 3), cx + math.cos(a) * r, y + math.sin(a) * r, 0xFFFFFF0C, 1)
  end
  if e.pressed then ImGui.DrawList_AddCircleFilled(dl, cx, y, r - 3, faded(color, 0x30)) end
  ImGui.DrawList_AddCircle(dl, cx, y, r, (e.hot or e.pressed) and color or 0x0A0A0BFF, 0, 1)

  if e.icon then
    -- The cap carries the icon of the function.
    env.mft_icons.draw(dl, e.icon, cx, y, r * 0.62, 0xE6E6E6FF, color)
  elseif e.value ~= nil then
    -- The pointer is a white line from near the center toward the ring, with the LED's color on its tip.
    local a = SWEEP_FROM + (SWEEP_TO - SWEEP_FROM) * e.value
    local c, s = math.cos(a), math.sin(a)
    ImGui.DrawList_AddLine(dl, cx + c * r * 0.3, y + s * r * 0.3, cx + c * r * 0.86, y + s * r * 0.86, WHITE, 2)
    ImGui.DrawList_AddCircleFilled(dl, cx + c * r * 0.86, y + s * r * 0.86, 2.2, color)
  end
end

-- ---- a side key ----

-- The icon and the color scheme of each side key. A key that stays on (mute, solo, phase) is a toggle: when it is off
-- its icon and lettering are a dimmed tone of its color, and when it is on the key is washed with the color, its
-- outline and lettering are bright, and a glow comes out of it. The red, the yellow, the blue and the green are
-- those of mute, solo, phase and the plugin selector; the chain and the hide keys are neutral.
local function side_scheme(label)
  local th = env.theme
  local schemes = {
    ["L1 Chain"] = { icon = "chain", color = 0xE6E6E6FF },
    ["L2 Hide"] = { icon = "hide", color = 0xE6E6E6FF },
    ["L3 FXsel"] = { icon = "fxsel", color = th.green },
    ["R1 Mute"] = { icon = "mute", color = th.red, toggle = true },
    ["R2 Solo"] = { icon = "solo", color = th.amber, toggle = true },
    ["R3 Phase"] = { icon = "phase", color = 0x4FA0E8FF, toggle = true },
  }
  return schemes[label]
end

-- A rubber key with an icon and its label. It is lit while it is held and, for a toggle, until it is pressed
-- again. Returns true when it was clicked.
local function side_key(ctx, dl, x, y, label, on)
  local th = env.theme
  local scheme = side_scheme(label)
  local color = scheme.color
  ImGui.SetCursorScreenPos(ctx, x, y)
  local clicked = ImGui.InvisibleButton(ctx, "##side" .. label, SIDE_W, SIDE_H)
  local hovered, held = ImGui.IsItemHovered(ctx), ImGui.IsItemActive(ctx)
  local lit = on or held
  local sink = held and 1 or 0
  if not held then ImGui.DrawList_AddRectFilled(dl, x, y + 2, x + SIDE_W, y + SIDE_H + 2, 0x000000AA, 6) end
  ImGui.DrawList_AddRectFilled(dl, x, y + sink, x + SIDE_W, y + SIDE_H + sink, held and th.knob_body or th.knob_top, 6)
  ImGui.DrawList_AddRectFilledMultiColor(dl, x + 2, y + sink + 2, x + SIDE_W - 2, y + sink + SIDE_H / 2, 0xFFFFFF18, 0xFFFFFF18, 0xFFFFFF00, 0xFFFFFF00)
  if lit then
    ImGui.DrawList_AddRectFilled(dl, x - 2, y + sink - 2, x + SIDE_W + 2, y + SIDE_H + sink + 2, faded(color, 0x22), 8)
    ImGui.DrawList_AddRectFilled(dl, x, y + sink, x + SIDE_W, y + SIDE_H + sink, faded(color, 0x4A), 6)
  elseif scheme.toggle then
    -- A key that can stay on shows its color faintly even when it is off, so that the keys can be told apart.
    ImGui.DrawList_AddRectFilled(dl, x, y + sink, x + SIDE_W, y + SIDE_H + sink, faded(color, 0x12), 6)
  end
  ImGui.DrawList_AddRect(dl, x, y + sink, x + SIDE_W, y + SIDE_H + sink, lit and color or (hovered and faded(color, 0xAA) or th.knob_edge), 6, 0, 1)
  ImGui.DrawList_AddLine(dl, x + 6, y + sink + 1.5, x + SIDE_W - 6, y + sink + 1.5, 0xFFFFFF30, 1)

  -- The icon on the left, and the label on the right: the key's name on the first line, its function on the second.
  local tone = lit and color or faded(color, 0x99)
  env.mft_icons.draw(dl, scheme.icon, x + 16, y + sink + SIDE_H / 2, 7, tone, tone)
  local pushed = push_font(ctx, "label")
  local name, function_name = label:match("^(%S+)%s+(.*)$")
  printed_text(ctx, dl, x + 49, y + sink + 3, name, lit and color or th.label)
  printed_text(ctx, dl, x + 49, y + sink + 17, function_name:upper(), lit and color or faded(color, 0xB0))
  if pushed then ImGui.PopFont(ctx) end
  return clicked
end

-- ---- the cells ----

local LABEL_W, LABEL_H = 94, 36

-- The lettering under an encoder, where the controller's color LED is. The LED lights a small window in the color of
-- the mode, `strength` being how bright it is (0 for an LED that is off), and the lettering is printed over it: the
-- name of the parameter, and under it its value or its press function.
local function led_label(ctx, dl, cx, y, first, second, color, strength, second_color)
  local th = env.theme
  local x1, x2 = cx - LABEL_W / 2, cx + LABEL_W / 2
  ImGui.DrawList_AddRectFilled(dl, x1, y, x2, y + LABEL_H, 0x08080AFF, 5)
  if strength > 0 then
    local top, bottom = faded(color, math.floor(0x14 * strength)), faded(color, math.floor(0x58 * strength))
    ImGui.DrawList_AddRectFilledMultiColor(dl, x1 + 1, y + 1, x2 - 1, y + LABEL_H - 1, top, top, bottom, bottom)
    ImGui.DrawList_AddRectFilled(dl, x1 + 8, y + LABEL_H - 3, x2 - 8, y + LABEL_H - 1, faded(color, math.floor(0xCC * strength)), 1)
  end
  ImGui.DrawList_AddRect(dl, x1, y, x2, y + LABEL_H, 0x000000DD, 5, 0, 1)
  ImGui.DrawList_AddLine(dl, x1 + 5, y + LABEL_H + 1, x2 - 5, y + LABEL_H + 1, 0xFFFFFF1E, 1)
  local pushed = push_font(ctx, "label")
  if first then
    local line_y = second and y + 3 or y + (LABEL_H - 16) / 2
    printed_text(ctx, dl, cx, line_y, first:upper(), strength > 0 and th.text or th.text_dim)
  end
  if second then printed_text(ctx, dl, cx, y + 18, second, second_color or (strength > 0 and color or th.text_dim)) end
  if pushed then ImGui.PopFont(ctx) end
end

-- Draws the sixteen encoders and answers the mouse. Dragging an encoder of the top eight changes its value, and
-- clicking one of the bottom six selects its mode. The LED color of the mode in use is the accent of its knobs.
local function draw_cells(ctx, dl, S, gx, gy)
  local th = env.theme
  local m = S.mft
  local mode = S.model.modes[m.mode]
  local mode_color = hue_to_rgba(mode.hue)
  for idx = 1, 16 do
    local col, row = (idx - 1) % 4, (idx - 1) // 4
    local cx = gx + PITCH * (col + 0.5)
    local cy = gy + ROW_H * row + RING_R + 14
    local label_y = cy + RING_R + 6
    local reach = RING_R + 6
    ImGui.SetCursorScreenPos(ctx, cx - reach, cy - reach)
    ImGui.InvisibleButton(ctx, "##enc" .. idx, reach * 2, reach * 2)
    local hot, held = ImGui.IsItemHovered(ctx), ImGui.IsItemActive(ctx)

    if idx <= 8 then
      local param = mode.params[idx]
      local transport = mode.id == "TRANSPORT" and S.model.transport[idx]
      if transport then
        draw_encoder(dl, cx, cy, { value = 0.5, color = mode_color, pressed = held, hot = hot, icon = transport.icon })
        led_label(ctx, dl, cx, label_y, transport.rotation, transport.press, mode_color, 1, th.text_dim)
      elseif param then
        local mapped = m.mapped[m.mode][idx]
        local value = m.values[m.mode][idx]
        if held and mapped then
          local _, dy = ImGui.GetMouseDragDelta(ctx, nil, nil, ImGui.MouseButton_Left, 0)
          m.values[m.mode][idx] = math.max(0, math.min(1, value - dy * 0.005))
          ImGui.ResetMouseDragDelta(ctx, ImGui.MouseButton_Left)
          value = m.values[m.mode][idx]
        end
        draw_encoder(dl, cx, cy, { value = mapped and value or nil, color = mode_color, pressed = held, hot = hot })
        if mapped then
          led_label(ctx, dl, cx, label_y, param, ("%d%%"):format(math.floor(value * 100 + 0.5)), mode_color, 1)
        else
          led_label(ctx, dl, cx, label_y, nil, nil, mode_color, 0)
        end
      else
        -- The settings mode: the encoders move the form, so the ring shows nothing and the LED is off.
        draw_encoder(dl, cx, cy, { color = mode_color, pressed = held, hot = hot })
        led_label(ctx, dl, cx, label_y, nil, nil, mode_color, 0)
      end
    else
      -- The bottom two rows: the first six select a mode, and light their LED in its color, brighter for the mode in
      -- use. The last two are reserved.
      local selected_mode = S.model.modes[idx - 8]
      if selected_mode then
        local color = hue_to_rgba(selected_mode.hue)
        local active = (idx - 8) == m.mode
        if hot and ImGui.IsItemClicked(ctx) then m.mode = idx - 8 end
        draw_encoder(dl, cx, cy, { color = color, lit_all = active, pressed = held or active, hot = hot })
        led_label(ctx, dl, cx, label_y, selected_mode.id, nil, color, active and 1 or 0.4)
      else
        draw_encoder(dl, cx, cy, { color = th.text_dim, pressed = held, hot = hot })
        led_label(ctx, dl, cx, label_y, nil, nil, th.text_dim, 0)
      end
    end
  end
end

-- Draws the six side keys. The mute, solo and phase keys stay lit once pressed.
local function draw_side_keys(ctx, dl, S, x0, x1, gy)
  local m = S.mft
  for row = 0, 2 do
    local cy = gy + ROW_H * row + RING_R + 14
    local y = cy - SIDE_H / 2
    local left, right = S.model.side_left[row + 1], S.model.side_right[row + 1]
    side_key(ctx, dl, x0, y, left, false)
    if side_key(ctx, dl, x1, y, right, m.lit[right]) then m.lit[right] = not m.lit[right] end
  end
end

-- ---- the header and the footer ----

local function draw_header(ctx, S, x, y)
  local th = env.theme
  local mode = S.model.modes[S.mft.mode]
  ImGui.SetCursorScreenPos(ctx, x, y)
  env.widgets.display(ctx, mode.id, hue_to_rgba(mode.hue), 190)
  ImGui.SameLine(ctx)
  env.widgets.lamp(ctx, th.green, true)
  ImGui.SameLine(ctx)
  ImGui.TextColored(ctx, th.text_dim, "mirror of the controller")
end

local function draw_footer(ctx, dl, cx, y)
  local th = env.theme
  local font = env.fonts and env.fonts.tab
  if font then ImGui.PushFont(ctx, font) end
  printed_text(ctx, dl, cx, y, "MIDI FIGHTER TWISTER", th.text_dim)
  if font then ImGui.PopFont(ctx) end
end

-- ---- under the device ----

-- The settings form: the colors of the modes and the sensitivity, which the real panel moves with the encoders, and
-- the five default plugins, which are chosen in drop-downs.
local function draw_settings(ctx, S)
  local th = env.theme
  local w = env.widgets
  local m = S.mft
  local mode = S.model.modes[m.mode]
  local color = hue_to_rgba(mode.hue)
  if not w.begin_card(ctx, "Settings", nil, nil, color) then return end
  ImGui.TextColored(ctx, th.grey, "Encoder 1 scrolls, encoder 2 adjusts")
  local rows = { "IO color: 15", "GATE color: 94", "EQ color: 60", "COMP color: 86", "SETTINGS color: 73", "TRANSPORT color: 107", "Sensitivity: 1.00" }
  for i, text in ipairs(rows) do
    ImGui.SetNextItemAllowOverlap(ctx)
    w.display(ctx, text, m.settings_cursor == i and color or th.text_dim, 260)
    if ImGui.IsItemClicked(ctx) then m.settings_cursor = i end
  end
  ImGui.Spacing(ctx)
  ImGui.TextColored(ctx, th.grey, "Default plugin per slot (keyboard):")
  for i, slot in ipairs(S.model.slots) do
    w.display(ctx, slot, m.settings_cursor == 7 + i and color or th.text_dim, 110)
    ImGui.SameLine(ctx)
    if w.begin_pick_list(ctx, "slot" .. i, m.slot_plugin[i], 400) then
      if ImGui.BeginChild(ctx, "##plugins" .. i, 0, 200) then
        for _, plugin in ipairs(S.model.plugins) do
          if w.pick_item(ctx, plugin, plugin == m.slot_plugin[i], true) then m.slot_plugin[i] = plugin end
        end
        ImGui.EndChild(ctx)
      end
      w.end_pick_list(ctx)
    end
  end
  ImGui.Spacing(ctx)
  w.push_button(ctx, "Save settings", 0)
  ImGui.SameLine(ctx)
  w.push_button(ctx, "Cancel", 0)
  w.end_card(ctx)
end

-- The calibration card: the LED test, and the steps of the calibration with their result.
local function draw_calibration(ctx, S)
  local th = env.theme
  local w = env.widgets
  local m = S.mft
  if not w.begin_card(ctx, "Calibration", nil, nil, th.amber) then return end
  local _, led_test = w.toggle(ctx, "LED test", m.led_test)
  m.led_test = led_test
  if not m.calibrating then
    if w.push_button(ctx, "Start calibration", 0) then m.calibrating, m.calibration_step = true, 1 end
  else
    w.display(ctx, ("Calibration %d/38"):format(m.calibration_step), th.amber, 200)
    ImGui.Text(ctx, "Turn encoder 1 to the right")
    ImGui.TextColored(ctx, th.grey, "expects: CC 0 on channel 1, value 1 to 63")
    ImGui.Text(ctx, "observed: nothing yet")
    w.lamp(ctx, th.grey, false)
    ImGui.SameLine(ctx)
    w.display(ctx, "pending", th.grey, 90)
    if w.push_button(ctx, "Retry", 0) then m.calibration_step = m.calibration_step end
    ImGui.SameLine(ctx)
    if w.push_button(ctx, "Skip", 0) then m.calibration_step = m.calibration_step % 38 + 1 end
    ImGui.SameLine(ctx)
    if w.push_button(ctx, "Next", 0) then m.calibration_step = m.calibration_step % 38 + 1 end
    ImGui.SameLine(ctx)
    if w.push_button(ctx, "Stop", 0) then m.calibrating = false end
  end
  w.end_card(ctx)
end

-- ---- the whole panel ----

function M.draw(ctx, S)
  local mode = S.model.modes[S.mft.mode]
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local grid_w = 4 * PITCH
  local body_w = PAD * 2 + (SIDE_W + SIDE_GAP) * 2 + grid_w
  local body_h = PAD + HEADER_H + 4 * ROW_H + FOOTER_H + PAD
  ImGui.Dummy(ctx, body_w, body_h)
  local dl = ImGui.GetWindowDrawList(ctx)

  local gx = x + PAD + SIDE_W + SIDE_GAP
  local gy = y + PAD + HEADER_H
  draw_body(dl, x, y, body_w, body_h)
  draw_faceplate(dl, gx - 4, gy - 4, grid_w + 8, 4 * ROW_H + 2)
  draw_header(ctx, S, x + PAD, y + PAD)
  draw_side_keys(ctx, dl, S, x + PAD, x + body_w - PAD - SIDE_W, gy)
  draw_cells(ctx, dl, S, gx, gy)
  draw_footer(ctx, dl, x + body_w / 2, y + body_h - PAD - FOOTER_H + 12)

  -- What follows the device starts under it.
  ImGui.SetCursorScreenPos(ctx, x, y + body_h + 10)
  ImGui.Dummy(ctx, 1, 1)
  -- The settings form and the calibration card belong to the settings mode, and are not shown in the others.
  if mode.id == "SETTINGS" then
    draw_settings(ctx, S)
    draw_calibration(ctx, S)
  end
end

return M
