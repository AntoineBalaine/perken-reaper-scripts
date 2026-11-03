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

local PITCH = 118 -- the distance from one encoder to the next, across
-- The distance from one row to the next, and from the top of a row to the center of its encoder. Both depend on where
-- the values are printed, and `M.draw` sets them at the start of each frame.
local ROW_H, TOP = 136, 14
local RING_R, WELL_R, CAP_R = 36, 30, 23 -- the ring of LEDs, the well that the cap sits in, and the cap
local SIDE_W, SIDE_H, SIDE_GAP = 76, 34, 14
-- HEADER_ROW_H is the height of the card of the mode, which sets the height of the row; HEADER_H is the room from the top
-- of the device to the first row of encoders.
local PAD, HEADER_H, FOOTER_H, HEADER_ROW_H = 22, 46, 8, 26
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

-- The color of a mode, from the hue that the settings form holds.
local function mode_rgba(S, index)
  return hue_to_rgba(S.mft.hues[index])
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

-- The white of the LEDs is soft, and not as bright as the lettering.
local WHITE = 0xBFBFBFFF
-- The radius of a white LED of the ring, in pixels, and the radius of the circle that the LEDs sit on: just outside
-- the well of the cap. `RING_R` is the room that the ring takes in the layout, and stays a little larger.
local LED_R = 2.4
local LED_RING_R = 34

-- Draws one encoder around (cx, cy): a ring of eleven white LEDs around a round rubber cap that sits in a well. The
-- LEDs light up to the value, and only a value lights them. `e` says what it shows:
--   value     0 to 1, where the ring ends and the pointer points; nil for a ring that shows nothing
--   color     the color of the mode's LED, which is the accent of the cap's details
--   pressed   the cap is held down
--   hot       the mouse is over the cap
--   icon      the name of an icon to draw on the cap instead of the pointer
local function draw_encoder(dl, cx, cy, e)
  local color = e.color

  -- The ring: the LEDs are white, and lit up to the value.
  for i = 0, LEDS - 1 do
    local a = SWEEP_FROM + (SWEEP_TO - SWEEP_FROM) * i / (LEDS - 1)
    local x, y = cx + math.cos(a) * LED_RING_R, cy + math.sin(a) * LED_RING_R
    local lit = e.value ~= nil and i / (LEDS - 1) <= e.value + 0.001
    if lit then
      ImGui.DrawList_AddCircleFilled(dl, x, y, LED_R + 2.5, faded(WHITE, 0x1C))
      ImGui.DrawList_AddCircleFilled(dl, x, y, LED_R, WHITE)
    else
      ImGui.DrawList_AddCircleFilled(dl, x, y, LED_R - 0.4, 0x060607FF)
      ImGui.DrawList_AddCircle(dl, x, y, LED_R - 0.4, 0xFFFFFF14, 0, 1)
    end
  end

  -- The well the cap sits in.
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, WELL_R, 0x070708FF)
  ImGui.DrawList_AddCircle(dl, cx, cy, WELL_R, 0x000000FF, 0, 2)
  ImGui.DrawList_AddCircle(dl, cx, cy + 1, WELL_R + 1, 0xFFFFFF18, 0, 1)

  -- The cap has the layers of the knobs of the shared panel kit, which give it its volume. From the back to the front: a
  -- shadow, the body, a lighter dome shifted toward the upper left, a veil of the mode's color, the edge, three fine
  -- grooves, a lit arc on the upper left of the edge, and a shine. It stands out of the well and sinks a little when it is
  -- pressed, and its edge takes the color of the mode under the mouse.
  local th = env.theme
  local sink = e.pressed and 1.5 or 0
  local r = CAP_R - sink * 0.5
  local y = cy + sink
  ImGui.DrawList_AddCircleFilled(dl, cx + 1, cy + 3 - sink, r + 1, 0x00000099)
  ImGui.DrawList_AddCircleFilled(dl, cx, y, r, th.knob_body)
  ImGui.DrawList_AddCircleFilled(dl, cx - 1, y - 1, r - 4, th.knob_top)
  ImGui.DrawList_AddCircleFilled(dl, cx - 1.5, y - 2, r - 9, 0xFFFFFF0C)
  ImGui.DrawList_AddCircleFilled(dl, cx, y, r - 4, faded(color, e.pressed and 0x3A or 0x14))
  ImGui.DrawList_AddCircle(dl, cx, y, r, (e.hot or e.pressed) and color or th.knob_edge, 0, 1)
  ImGui.DrawList_AddCircle(dl, cx, y, r - 3, 0xFFFFFF14, 0, 1)
  ImGui.DrawList_AddCircle(dl, cx, y, r - 6, 0x00000040, 0, 1)
  ImGui.DrawList_AddCircle(dl, cx, y, r - 9, 0xFFFFFF0C, 0, 1)
  ImGui.DrawList_PathArcTo(dl, cx, y, r - 0.5, math.pi, math.pi * 1.5)
  ImGui.DrawList_PathStroke(dl, 0xFFFFFF40, ImGui.DrawFlags_None, 1.5)
  ImGui.DrawList_AddCircleFilled(dl, cx - r * 0.35, y - r * 0.4, r * 0.22, 0xFFFFFF1E)

  if e.icon then
    -- The cap carries the icon of the function.
    -- The icon is the off-white of the labels, and stands out of the rubber; its shadow is the color of the mode.
    env.mft_icons.draw(dl, e.icon, cx, y, r * 0.62, env.theme.text, env.theme.text, true, color)
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

  -- The icon on the left, and the function of the key on the right. The number of the key (L1, R2) is not printed,
  -- because the position of the key already says it. Because the words differ in width, the icon and the word are
  -- centered together in the key, and the word is centered in the height of the key by the size of its text.
  local tone = lit and color or faded(color, 0x99)
  local pushed = push_font(ctx, "label")
  local function_name = label:match("^%S+%s+(.*)$"):upper()
  local text_w, text_h = ImGui.CalcTextSize(ctx, function_name)
  local icon_w, gap = 14, 7
  local left = x + (SIDE_W - (icon_w + gap + text_w)) / 2
  env.mft_icons.draw(dl, scheme.icon, left + icon_w / 2, y + sink + SIDE_H / 2, 7, tone, tone)
  printed_text(ctx, dl, left + icon_w + gap + text_w / 2, y + sink + (SIDE_H - text_h) / 2, function_name, lit and color or th.label)
  if pushed then ImGui.PopFont(ctx) end
  return clicked
end

-- ---- the cells ----

local LABEL_W, LABEL_H = 94, 36
-- How many pixels the lettering of the encoders is lifted from where it would be centered, in the window under a knob and
-- above it.
local TEXT_UP = 2

-- The lettering under an encoder, where the controller's color LED is. The LED lights a small window in the color of
-- the mode, `strength` being how bright it is (0 for an LED that is off), and the lettering is printed over it: the
-- name of the parameter, and under it its value or its press function.
-- The window of the color LED under an encoder: dark glass that the LED lights in `color`, as much as `strength` (0 for an
-- LED that is off).
local function led_window(dl, cx, y, color, strength)
  local x1, x2 = cx - LABEL_W / 2, cx + LABEL_W / 2
  ImGui.DrawList_AddRectFilled(dl, x1, y, x2, y + LABEL_H, 0x08080AFF, 5)
  if strength > 0 then
    local top, bottom = faded(color, math.floor(0x14 * strength)), faded(color, math.floor(0x58 * strength))
    ImGui.DrawList_AddRectFilledMultiColor(dl, x1 + 1, y + 1, x2 - 1, y + LABEL_H - 1, top, top, bottom, bottom)
    ImGui.DrawList_AddRectFilled(dl, x1 + 8, y + LABEL_H - 3, x2 - 8, y + LABEL_H - 1, faded(color, math.floor(0xCC * strength)), 1)
  end
  ImGui.DrawList_AddRect(dl, x1, y, x2, y + LABEL_H, 0x000000DD, 5, 0, 1)
  ImGui.DrawList_AddLine(dl, x1 + 5, y + LABEL_H + 1, x2 - 5, y + LABEL_H + 1, 0xFFFFFF1E, 1)
end

local function led_label(ctx, dl, cx, y, first, second, color, strength, second_color)
  local th = env.theme
  led_window(dl, cx, y, color, strength)
  local pushed = push_font(ctx, "label")
  if first then
    -- The name is always on the top line, as the turn is in the two-zone window, with a thin line under it. When the
    -- knob has no second line, the bottom half is left empty: it is the place of the press, and of the mapping.
    printed_text(ctx, dl, cx, y + 3 - TEXT_UP, first:upper(), strength > 0 and th.text or th.text_dim)
    ImGui.DrawList_AddLine(dl, cx - LABEL_W / 2 + 6, y + LABEL_H / 2, cx + LABEL_W / 2 - 6, y + LABEL_H / 2, 0xFFFFFF22, 1)
  end
  if second then printed_text(ctx, dl, cx, y + 18 - TEXT_UP, second, second_color or (strength > 0 and color or th.text_dim)) end
  if pushed then ImGui.PopFont(ctx) end
end

-- ---- the labels of what a knob does when it is turned and when it is pressed ----

local GLYPH_W, GLYPH_GAP = 10, 5

-- The sign of a press: a ring with a dot in it, which reads as a button.
local function press_glyph(dl, x, y, color)
  ImGui.DrawList_AddCircle(dl, x, y, 4.4, color, 0, 1.4)
  ImGui.DrawList_AddCircleFilled(dl, x, y, 1.8, color)
end

-- The sign of a turn: an arc with an arrowhead at its end.
local function turn_glyph(dl, x, y, color)
  local from, to, radius = math.pi * 0.15, math.pi * 1.65, 4.4
  ImGui.DrawList_PathArcTo(dl, x, y, radius, from, to)
  ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_None, 1.4)
  -- The arrowhead sits on the end of the arc and points along it, clockwise on the screen.
  local ex, ey = x + math.cos(to) * radius, y + math.sin(to) * radius
  local tx, ty = -math.sin(to), math.cos(to)
  local nx, ny = math.cos(to), math.sin(to)
  ImGui.DrawList_AddTriangleFilled(dl, ex + tx * 3.6, ey + ty * 3.6, ex + nx * 2.8 - tx * 0.4, ey + ny * 2.8 - ty * 0.4,
    ex - nx * 2.8 - tx * 0.4, ey - ny * 2.8 - ty * 0.4, color)
end

-- Tells what the player is doing with a knob that is held: a drag of more than a few pixels is a turn, and holding it
-- still is a press. Returns "turn", "press" or nil when the knob is not held.
local function interaction(ctx, held)
  if not held then return nil end
  local _, dy = ImGui.GetMouseDragDelta(ctx, nil, nil, ImGui.MouseButton_Left, 0)
  if math.abs(dy) > 3 then return "turn" end
  return "press"
end

-- One line of the two-zone window: a glyph, then the word, centered together on `cx`. A line that `lit` is washed with the
-- color of the mode, and its word is bright.
local function zone_line(ctx, dl, cx, top, bottom, glyph, text, color, lit, text_color)
  local th = env.theme
  local text_w = ImGui.CalcTextSize(ctx, text)
  if lit then
    ImGui.DrawList_AddRectFilled(dl, cx - LABEL_W / 2 + 3, top, cx + LABEL_W / 2 - 3, bottom, faded(color, 0x55), 3)
  end
  local left = cx - (GLYPH_W + GLYPH_GAP + text_w) / 2
  glyph(dl, left + GLYPH_W / 2, (top + bottom) / 2, lit and color or faded(color, 0xB0))
  printed_text(ctx, dl, left + GLYPH_W + GLYPH_GAP + text_w / 2, (top + bottom) / 2 - 8 - TEXT_UP, text, lit and th.text or text_color)
end

-- The window under a knob that does two things: what a turn does on the top line, with the sign of a turn, and what a
-- press does under it, with the sign of a press, the two separated by a thin line. `state` is "turn", "press" or nil
-- (see `interaction`), and lights the line of what is being done. A knob that only has a press (a mode button) has the
-- press line alone, still in the bottom half, and the top half empty; `strength` is how bright the LED is.
local function dual_label(ctx, dl, cx, y, turn_text, press_text, color, strength, state, press_color)
  local th = env.theme
  led_window(dl, cx, y, color, strength)
  local pushed = push_font(ctx, "label")
  local x1, x2 = cx - LABEL_W / 2, cx + LABEL_W / 2
  -- The top half is the place of what a turn does, which is also where the mapping of the knob is shown; it stays empty for a
  -- knob that is only pressed. The press is always in the bottom half, under the line.
  if turn_text then
    zone_line(ctx, dl, cx, y + 2, y + LABEL_H / 2, turn_glyph, turn_text:upper(), color, state == "turn", th.text)
  end
  ImGui.DrawList_AddLine(dl, x1 + 6, y + LABEL_H / 2, x2 - 6, y + LABEL_H / 2, 0xFFFFFF22, 1)
  zone_line(ctx, dl, cx, y + LABEL_H / 2, y + LABEL_H - 2, press_glyph, press_text, color, state == "press", press_color or th.text_dim)
  if pushed then ImGui.PopFont(ctx) end
end

-- How many pixels the bottom of a pop-up is above the circle that the LEDs sit on. A negative number puts it over the
-- LEDs: -8 puts it over the top of the ring and of the well, and stops it 3 pixels above the cap.
local BUBBLE_GAP = -8

-- The pop-up of a value: a small dark rounded box, outlined and lettered in the color of the mode. `top` is where its
-- bottom edge is.
local function draw_bubble(ctx, dl, bubble)
  local pushed = push_font(ctx, "label")
  local text_w, text_h = ImGui.CalcTextSize(ctx, bubble.text)
  local w, h = text_w + 22, text_h + 10
  local x1, y2 = bubble.cx - w / 2, bubble.top
  local y1 = y2 - h
  ImGui.DrawList_AddRectFilled(dl, x1 + 1, y1 + 3, x1 + w + 1, y2 + 3, 0x00000099, 6)
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x1 + w, y2, 0x0B0B0DF2, 6)
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x1 + w, y2, faded(bubble.color, 0x22), 6)
  ImGui.DrawList_AddRect(dl, x1, y1, x1 + w, y2, bubble.color, 6, 0, 1.2)
  ImGui.DrawList_AddText(dl, bubble.cx - text_w / 2, y1 + 5, bubble.color, bubble.text)
  if pushed then ImGui.PopFont(ctx) end
end

-- Draws the sixteen encoders and answers the mouse. Dragging an encoder of the top eight changes its value, and
-- clicking one of the bottom six selects its mode. The LED color of the mode in use is the accent of its knobs.
local function draw_cells(ctx, dl, S, gx, gy)
  local th = env.theme
  local m = S.mft
  local mode = S.model.modes[m.mode]
  local mode_color = mode_rgba(S, m.mode)
  local bubbles = {}
  for idx = 1, 16 do
    local col, row = (idx - 1) % 4, (idx - 1) // 4
    local cx = gx + PITCH * (col + 0.5)
    local cy = gy + ROW_H * row + RING_R + TOP
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
        dual_label(ctx, dl, cx, label_y, transport.rotation, transport.press, mode_color, 1, interaction(ctx, held), th.text_dim)
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
          local value_text = ("%d%%"):format(math.floor(value * 100 + 0.5))
          if S.value_mode == "above" then
            -- The value is printed over the ring, in the color of the mode, and the window under the knob keeps the name.
            local pushed = push_font(ctx, "label")
            printed_text(ctx, dl, cx, cy - LED_RING_R - 22 - TEXT_UP, value_text, mode_color)
            if pushed then ImGui.PopFont(ctx) end
            led_label(ctx, dl, cx, label_y, param, nil, mode_color, 1)
          elseif S.value_mode == "popup" then
            -- The value shows in a bubble over the knob for as long as the knob is held, and not a moment more.
            if held then
              bubbles[#bubbles + 1] = { cx = cx, top = cy - LED_RING_R - BUBBLE_GAP, text = value_text, color = mode_color }
            end
            led_label(ctx, dl, cx, label_y, param, nil, mode_color, 1)
          else
            led_label(ctx, dl, cx, label_y, param, value_text, mode_color, 1)
          end
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
        local color = mode_rgba(S, idx - 8)
        local active = (idx - 8) == m.mode
        if hot and ImGui.IsItemClicked(ctx) then m.mode = idx - 8 end
        -- The ring stays dark: its LEDs are for showing a value. The mode in use is shown by the sunk cap, the lit window
        -- and the color of its word.
        draw_encoder(dl, cx, cy, { color = color, pressed = held or active, hot = hot })
        -- The word under a mode button says what a click does, so it is written as a press: with the sign of a press, and
        -- lit while the button is held. The mode in use is in the color of the mode.
        dual_label(ctx, dl, cx, label_y, nil, selected_mode.id, color, active and 1 or 0.4, held and "press" or nil, active and color or th.text_dim)
      else
        draw_encoder(dl, cx, cy, { color = th.text_dim, pressed = held, hot = hot })
        led_label(ctx, dl, cx, label_y, nil, nil, th.text_dim, 0)
      end
    end
  end
  for _, bubble in ipairs(bubbles) do draw_bubble(ctx, dl, bubble) end
end

-- Draws the six side keys. The mute, solo and phase keys stay lit once pressed.
local function draw_side_keys(ctx, dl, S, x0, x1, gy)
  local m = S.mft
  for row = 0, 2 do
    local cy = gy + ROW_H * row + RING_R + TOP
    local y = cy - SIDE_H / 2
    local left, right = S.model.side_left[row + 1], S.model.side_right[row + 1]
    side_key(ctx, dl, x0, y, left, false)
    if side_key(ctx, dl, x1, y, right, m.lit[right]) then m.lit[right] = not m.lit[right] end
  end
end

-- ---- the buttons of the corner ----

local CORNER = 24

-- The glyphs of the corner buttons, drawn with lines around (cx, cy).
local function close_glyph(dl, cx, cy, color)
  ImGui.DrawList_AddLine(dl, cx - 4, cy - 4, cx + 4, cy + 4, color, 1.9)
  ImGui.DrawList_AddLine(dl, cx - 4, cy + 4, cx + 4, cy - 4, color, 1.9)
end

-- A chevron: it points up when the device is open (a click folds it), and down when it is folded (a click opens it).
local function chevron_glyph(dl, cx, cy, color, pointing_up)
  local tip, side = pointing_up and -2.5 or 2.5, pointing_up and 2.5 or -2.5
  ImGui.DrawList_AddLine(dl, cx - 5, cy + side, cx, cy + tip, color, 1.9)
  ImGui.DrawList_AddLine(dl, cx, cy + tip, cx + 5, cy + side, color, 1.9)
end

local function chevron_up_glyph(dl, cx, cy, color)
  chevron_glyph(dl, cx, cy, color, true)
end

local function chevron_down_glyph(dl, cx, cy, color)
  chevron_glyph(dl, cx, cy, color, false)
end

-- A small raised key with a glyph on it. The close key turns red under the mouse. Returns true when it was clicked.
local function corner_button(ctx, dl, id, x, y, glyph, hover_color)
  local th = env.theme
  ImGui.SetCursorScreenPos(ctx, x, y)
  local clicked = ImGui.InvisibleButton(ctx, "##corner" .. id, CORNER, CORNER)
  local hovered, held = ImGui.IsItemHovered(ctx), ImGui.IsItemActive(ctx)
  local sink = held and 1 or 0
  if not held then ImGui.DrawList_AddRectFilled(dl, x, y + 2, x + CORNER, y + CORNER + 2, 0x000000AA, 5) end
  ImGui.DrawList_AddRectFilled(dl, x, y + sink, x + CORNER, y + CORNER + sink, held and th.knob_body or th.knob_top, 5)
  ImGui.DrawList_AddRectFilledMultiColor(dl, x + 2, y + sink + 2, x + CORNER - 2, y + sink + CORNER / 2, 0xFFFFFF18, 0xFFFFFF18, 0xFFFFFF00, 0xFFFFFF00)
  ImGui.DrawList_AddRect(dl, x, y + sink, x + CORNER, y + CORNER + sink, hovered and hover_color or th.knob_edge, 5, 0, 1)
  glyph(dl, x + CORNER / 2, y + CORNER / 2 + sink, hovered and hover_color or th.label)
  return clicked
end

-- ---- the header and the footer ----

local TITLE = "MIDI FIGHTER TWISTER"

-- The header row. On the left, the card of the mode in use, as wide as the longest name of a mode (TRANSPORT), so that it
-- keeps its width when the mode changes. In the middle, the name of the controller, centered on the device, with the green
-- lamp next to it; the lamp tells in a pop-up what the panel is. The buttons of the corner are on the right. `x` and `y`
-- are the top left of the device.
local function draw_header(ctx, dl, S, x, y, body_w)
  local th = env.theme
  local mode = S.model.modes[S.mft.mode]
  local pushed = push_font(ctx, "label")
  local widest = 0
  for _, each in ipairs(S.model.modes) do widest = math.max(widest, (ImGui.CalcTextSize(ctx, each.id))) end
  if pushed then ImGui.PopFont(ctx) end
  ImGui.SetCursorScreenPos(ctx, x + PAD, y + PAD)
  env.widgets.display(ctx, mode.id, mode_rgba(S, S.mft.mode), widest + 20)

  local cx = x + body_w / 2
  local font = env.fonts and env.fonts.tab
  if font then ImGui.PushFont(ctx, font) end
  local title_w, title_h = ImGui.CalcTextSize(ctx, TITLE)
  printed_text(ctx, dl, cx, y + PAD + (HEADER_ROW_H - title_h) / 2, TITLE, th.text_dim)
  if font then ImGui.PopFont(ctx) end
  local lamp = ImGui.GetTextLineHeight(ctx)
  ImGui.SetCursorScreenPos(ctx, cx - title_w / 2 - 8 - lamp, y + PAD + (HEADER_ROW_H - lamp) / 2)
  env.widgets.lamp(ctx, th.green, true)
  env.widgets.tooltip(ctx, "online, mirroring the controller")
end

-- ---- under the device ----

-- The color of the hue wheel at a position of a bar, from 0 to 1.
local function hue_wheel_color(fraction)
  return hue_to_rgba(fraction * 127)
end

-- A bar that the mouse sets: a click or a drag puts the thumb where the mouse is. `fraction` is the position, from 0 to 1,
-- and `color_at` gives the color of the bar at a position (the hue wheel, for a hue), or is nil for a plain bar that fills
-- up to the thumb in `fill`. Returns the position after the mouse.
local function slider(ctx, id, fraction, width, color_at, fill)
  local th = env.theme
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local h = 22
  ImGui.InvisibleButton(ctx, "##slider" .. id, width, h)
  if ImGui.IsItemActive(ctx) then
    local mouse_x = ImGui.GetMousePos(ctx)
    fraction = math.max(0, math.min(1, (mouse_x - x) / width))
  end
  ImGui.DrawList_AddRectFilled(dl, x, y + 6, x + width, y + h - 6, th.slot_bg, 3)
  if color_at then
    local segments = 64
    for i = 0, segments - 1 do
      local x1, x2 = x + width * i / segments, x + width * (i + 1) / segments
      ImGui.DrawList_AddRectFilled(dl, x1, y + 7, x2 + 0.5, y + h - 7, color_at((i + 0.5) / segments), 0)
    end
  else
    ImGui.DrawList_AddRectFilled(dl, x, y + 6, x + width * fraction, y + h - 6, faded(fill, 0xCC), 3)
  end
  ImGui.DrawList_AddRect(dl, x, y + 6, x + width, y + h - 6, th.slot_edge, 3, 0, 1)
  local thumb = x + width * fraction
  ImGui.DrawList_AddRectFilled(dl, thumb - 3, y + 2, thumb + 3, y + h - 2, th.knob_top, 2)
  ImGui.DrawList_AddRect(dl, thumb - 3, y + 2, thumb + 3, y + h - 2, ImGui.IsItemHovered(ctx) and 0xFFFFFFFF or th.knob_edge, 2, 0, 1)
  return fraction
end

-- The settings form. A hue is set on a bar that shows the wheel of the controller's LEDs, the sensitivity on a plain bar,
-- and the five default plugins in drop-downs. All of them answer the mouse: a click or a drag on a bar sets it, and the
-- colors of the device change as the bar moves. (On the controller, the same rows are scrolled with encoder 1 and
-- adjusted with encoder 2.)
local function draw_settings(ctx, S)
  local th = env.theme
  local w = env.widgets
  local m = S.mft
  local color = mode_rgba(S, m.mode)
  if not w.begin_card(ctx, "Settings", nil, nil, color) then return end
  ImGui.TextColored(ctx, th.grey, "Click or drag a bar to change a value")
  for i, mode in ipairs(S.model.modes) do
    w.display(ctx, mode.id .. " color", th.text_dim, 150)
    ImGui.SameLine(ctx)
    local fraction = slider(ctx, "hue" .. i, m.hues[i] / 127, 280, hue_wheel_color)
    m.hues[i] = math.floor(fraction * 127 + 0.5)
    ImGui.SameLine(ctx)
    ImGui.TextColored(ctx, hue_to_rgba(m.hues[i]), ("%3d"):format(m.hues[i]))
  end
  w.display(ctx, "Sensitivity", th.text_dim, 150)
  ImGui.SameLine(ctx)
  local fraction = slider(ctx, "sensitivity", (m.sensitivity - 0.1) / 3.9, 280, nil, color)
  m.sensitivity = math.floor((0.1 + fraction * 3.9) * 20 + 0.5) / 20
  ImGui.SameLine(ctx)
  ImGui.TextColored(ctx, color, ("%.2f"):format(m.sensitivity))
  ImGui.Spacing(ctx)
  ImGui.TextColored(ctx, th.grey, "Default plugin per slot (keyboard):")
  for i, slot in ipairs(S.model.slots) do
    w.display(ctx, slot, th.text_dim, 150)
    ImGui.SameLine(ctx)
    if w.begin_pick_list(ctx, "slot" .. i, m.slot_plugin[i], 400) then
      -- The list has a width of its own: a pop-up grows to fit what it holds, and a child that asks for the rest of the
      -- width of one gets none, so that the list would stay empty.
      if ImGui.BeginChild(ctx, "##plugins" .. i, 440, 220) then
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
  if w.push_button(ctx, "Cancel", 0) then
    -- Cancel puts the form back as it was when the lab started.
    for i, mode in ipairs(S.model.modes) do m.hues[i] = mode.hue end
    m.sensitivity = 1.0
  end
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
  S.model.upgrade(S.mft)
  local mode = S.model.modes[S.mft.mode]
  -- A value printed over the knob needs a line of room above the ring, and leaves a line under it.
  if S.value_mode == "above" then
    ROW_H, TOP = 128, 30
  else
    ROW_H, TOP = 136, 14
  end
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local grid_w = 4 * PITCH
  local body_w = PAD * 2 + (SIDE_W + SIDE_GAP) * 2 + grid_w
  -- A folded device is its header row alone.
  local body_h = S.collapsed and (PAD * 2 + HEADER_ROW_H) or (PAD + HEADER_H + 4 * ROW_H + FOOTER_H + PAD)
  ImGui.Dummy(ctx, body_w, body_h)
  local dl = ImGui.GetWindowDrawList(ctx)
  draw_body(dl, x, y, body_w, body_h)
  draw_header(ctx, dl, S, x, y, body_w)

  -- The buttons of the top right corner: fold or open the device, and close the lab.
  local close_x = x + body_w - PAD - CORNER
  local corner_y = y + PAD + 1
  if corner_button(ctx, dl, "close", close_x, corner_y, close_glyph, env.theme.red) then S.close_requested = true end
  local chevron = S.collapsed and chevron_down_glyph or chevron_up_glyph
  if corner_button(ctx, dl, "fold", close_x - 6 - CORNER, corner_y, chevron, env.theme.amber) then S.collapsed = not S.collapsed end

  -- A folded device ends here, and nothing is under it: the window shrinks to the height of the header row.
  if S.collapsed then return end

  local gx = x + PAD + SIDE_W + SIDE_GAP
  local gy = y + PAD + HEADER_H
  draw_faceplate(dl, gx - 4, gy - 4, grid_w + 8, 4 * ROW_H + 2)
  draw_side_keys(ctx, dl, S, x + PAD, x + body_w - PAD - SIDE_W, gy)
  draw_cells(ctx, dl, S, gx, gy)

  -- The settings form and the calibration card belong to the settings mode, and are not shown in the others. They start a
  -- little under the device. In the other modes nothing follows the device, so that the window ends where it ends.
  if mode.id == "SETTINGS" then
    ImGui.SetCursorScreenPos(ctx, x, y + body_h + 10)
    ImGui.Dummy(ctx, 1, 1)
    draw_settings(ctx, S)
    draw_calibration(ctx, S)
  end
end

return M
