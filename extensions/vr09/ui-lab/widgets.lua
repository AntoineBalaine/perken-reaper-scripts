-- The panel's components: the drawbar, the slider of a parameter, the card that frames a group.
-- A new component starts here, and the panel calls it. Saving this file redraws the window at once.
--
-- A module reads what it needs from `env` when it runs, not when it loads, so that a reloaded
-- `theme` takes effect without reloading this file.
local env = ...
local ImGui = env.ImGui

local M = {}

-- "Upper organ drawbar 16'" is shown as "16'" under its drawbar.
local function short_drawbar_name(label)
  return label:match("drawbar (.*)$") or label
end

-- The name of a value of a type parameter, or nil for a level.
function M.value_name(param, value)
  if not param.names then return nil end
  return param.names[value - param.low + 1]
end

-- ---- drawing helpers ----

local function clamp(x, low, high)
  if x < low then return low end
  if x > high then return high end
  return x
end

-- The accent of the card being drawn, which the lit parts of its controls take; amber when the card
-- has none. `begin_card` sets it and `end_card` clears it.
local current_accent = nil

local function accent()
  return current_accent or env.theme.amber
end

-- The same color at a fraction of its strength, for a glow around a lit part.
local function faded(color, alpha)
  return (color & 0xFFFFFF00) | alpha
end

-- Because a tonewheel organ's drawbars come in three colors by footage, the cap's color is found
-- from the end of the parameter's id ("organ-upper-d16" is "d16").
local CAP_BY_FOOTAGE = {
  d16 = "cap_brown", d5f = "cap_brown",
  d8 = "cap_white", d4 = "cap_white",
  d2f = "cap_black",
  d2 = "cap_white",
  d1f = "cap_black", d1ff = "cap_black",
  d1 = "cap_white",
}

-- Returns the color of the cap and the color of its contour.
local function cap_colors(param)
  local footage = param.id:match("%-(d%w+)$")
  local name = CAP_BY_FOOTAGE[footage] or "cap_white"
  return env.theme[name], env.theme[name .. "_edge"]
end

-- The labels are drawn in their own font. Returns true when the font was pushed, and then the
-- caller pops it.
local function push_label_font(ctx)
  local label_font = env.fonts and env.fonts.label
  if not label_font then return false end
  ImGui.PushFont(ctx, label_font)
  return true
end

-- Text that looks cut into the panel: a dark copy one pixel below, the light text over it.
function M.engraved_text(ctx, text, color)
  local th = env.theme
  local pushed = push_label_font(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.DrawList_AddText(dl, x, y + 1, th.text_engraved_shadow, text)
  ImGui.DrawList_AddText(dl, x, y, color or th.text_dim, text)
  local w, h = ImGui.CalcTextSize(ctx, text)
  ImGui.Dummy(ctx, w, h + 1)
  if pushed then ImGui.PopFont(ctx) end
end

-- ---- the drawbar ----

local DRAWBAR_W, DRAWBAR_H = 40, 150
local CAP_H = 20

-- A drawbar pulled out of the panel: the value above it, a slot with eight ticks, a stem and a cap
-- that slides down as the value rises, and the footage under it. The user drags the cap, or clicks
-- anywhere in the slot to bring the cap there.
-- Returns true when the user changed the value, and the new value.
function M.drawbar(ctx, param, value)
  local th = env.theme
  ImGui.BeginGroup(ctx)

  local text = tostring(value)
  local text_w = ImGui.CalcTextSize(ctx, text)
  ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (DRAWBAR_W - text_w) / 2)
  ImGui.TextColored(ctx, accent(), text)

  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, "##drawbar", DRAWBAR_W, DRAWBAR_H)

  local top = y + CAP_H / 2 + 2
  local bottom = y + DRAWBAR_H - CAP_H / 2 - 2
  local changed, result = false, value
  if ImGui.IsItemActive(ctx) then
    local _, my = ImGui.GetMousePos(ctx)
    local t = clamp((my - top) / (bottom - top), 0, 1)
    result = math.floor(param.low + t * (param.high - param.low) + 0.5)
    changed = result ~= value
  end

  local dl = ImGui.GetWindowDrawList(ctx)
  local cx = x + DRAWBAR_W / 2

  -- The slot, cut into the panel.
  ImGui.DrawList_AddRectFilled(dl, cx - 5, top - 6, cx + 5, bottom + 6, th.slot_bg, 4)
  ImGui.DrawList_AddRect(dl, cx - 5, top - 6, cx + 5, bottom + 6, th.slot_edge, 4)

  -- The ticks, one for each step of the drawbar.
  local steps = param.high - param.low
  for i = 0, steps do
    local ty = top + (bottom - top) * i / steps
    ImGui.DrawList_AddLine(dl, x + 2, ty, cx - 8, ty, th.text_dim, 1)
    ImGui.DrawList_AddLine(dl, cx + 8, ty, x + DRAWBAR_W - 2, ty, th.text_dim, 1)
  end

  -- The stem runs from the top of the slot down to the cap.
  local pos = top + (bottom - top) * (result - param.low) / steps
  ImGui.DrawList_AddRectFilled(dl, cx - 2, top - 4, cx + 2, pos, th.stem, 1)

  -- The cap, with a lit edge on its top and a dark line under it so that it stands out of the panel.
  local cap_x1, cap_x2 = x + 3, x + DRAWBAR_W - 3
  local cap_y1, cap_y2 = pos - CAP_H / 2, pos + CAP_H / 2
  ImGui.DrawList_AddRectFilled(dl, cap_x1, cap_y1 + 2, cap_x2, cap_y2 + 2, 0x00000099, 3)
  local body, edge = cap_colors(param)
  ImGui.DrawList_AddRectFilled(dl, cap_x1, cap_y1, cap_x2, cap_y2, body, 3)
  ImGui.DrawList_AddRect(dl, cap_x1, cap_y1, cap_x2, cap_y2, edge, 3, 0, 1)
  ImGui.DrawList_AddLine(dl, cap_x1 + 3, cap_y1 + 2, cap_x2 - 3, cap_y1 + 2, 0xFFFFFF55, 1)
  ImGui.DrawList_AddLine(dl, cap_x1 + 3, pos, cap_x2 - 3, pos, edge, 1)
  if ImGui.IsItemHovered(ctx) or ImGui.IsItemActive(ctx) then
    ImGui.DrawList_AddRect(dl, cap_x1, cap_y1, cap_x2, cap_y2, accent(), 3)
  end

  local name = short_drawbar_name(param.label)
  local pushed = push_label_font(ctx)
  local name_w = ImGui.CalcTextSize(ctx, name)
  ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (DRAWBAR_W - name_w) / 2)
  ImGui.TextColored(ctx, th.label, name)
  if pushed then ImGui.PopFont(ctx) end
  ImGui.EndGroup(ctx)
  return changed, result
end

-- ---- the knob and the switch ----

local KNOB_W, KNOB_D = 76, 46
local KNOB_LABEL_LINES = 2

-- The knob sweeps 270 degrees, from the lower left through the top to the lower right. ImGui's
-- angles start at the right and grow clockwise on screen.
local KNOB_FROM = math.pi * 0.75
local KNOB_TO = math.pi * 2.25

-- Because a drag moves the value relative to where it started, the start of each drag is kept here
-- by the parameter's id.
local drag_start = {}

-- The position a knob goes back to on an alt-click: the parameter's own default when it has one, the
-- middle of the range for a value that rests there, and the lowest value otherwise, because the
-- catalog does not hold a default for each one.
function M.default_value(param, bipolar)
  if param.default then return param.default end
  if bipolar then return math.floor((param.low + param.high) / 2 + 0.5) end
  return param.low
end

local function alt_is_down(ctx)
  return (ImGui.GetKeyMods(ctx) & ImGui.Mod_Alt) ~= 0
end

-- "Rotary woofer slow speed" is shown as "woofer slow speed" in the card of the group "Rotary".
-- The words in `suffixes` (such as " volume") are taken off the end of the label too.
function M.short_label(label, group_name, suffixes)
  local prefix = group_name .. " "
  if label:sub(1, #prefix) == prefix then label = label:sub(#prefix + 1) end
  for _, suffix in ipairs(suffixes or {}) do
    if label:sub(-#suffix) == suffix then
      label = label:sub(1, #label - #suffix)
      break
    end
  end
  return label
end

-- Breaks the text into lines that fit the width.
local function lines_of(ctx, text, width)
  local lines, line = {}, ""
  for word in text:gmatch("%S+") do
    local candidate = line == "" and word or (line .. " " .. word)
    if line ~= "" and ImGui.CalcTextSize(ctx, candidate) > width then
      lines[#lines + 1] = line
      line = word
    else
      line = candidate
    end
  end
  if line ~= "" then lines[#lines + 1] = line end
  return lines
end

-- Draws a label centered under a control, on as many lines as the control reserves, so that the
-- controls of one row keep the same height whatever their label.
local function centered_label(ctx, text, width, reserved_lines)
  local pushed = push_label_font(ctx)
  local lines = lines_of(ctx, text, width)
  local base = ImGui.GetCursorPosX(ctx)
  for i = 1, reserved_lines do
    local line = lines[i]
    if line then
      local line_w = ImGui.CalcTextSize(ctx, line)
      ImGui.SetCursorPosX(ctx, base + (width - line_w) / 2)
      ImGui.TextColored(ctx, env.theme.label, line)
    else
      ImGui.Dummy(ctx, 1, ImGui.GetTextLineHeight(ctx))
    end
  end
  if pushed then ImGui.PopFont(ctx) end
end

local function centered_value(ctx, text, width)
  local text_w = ImGui.CalcTextSize(ctx, text)
  ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + (width - text_w) / 2)
  ImGui.TextColored(ctx, accent(), text)
end

-- A rotary knob: the value above it, a ring that fills as the value rises, a pointer, and the label
-- under it. The user drags up or down, or turns the mouse wheel over it.
-- When `bipolar` is true, the value rests in the middle of the range, so that the ring fills from the
-- top, to the left or to the right of it, and a tick marks the middle.
-- Returns true when the user changed the value, and the new value.
function M.knob(ctx, param, value, label, bipolar)
  local th = env.theme
  ImGui.BeginGroup(ctx)
  centered_value(ctx, tostring(value) .. (param.unit or ""), KNOB_W)

  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, "##knob", KNOB_W, KNOB_D + 8)
  local range = param.high - param.low
  local result = value
  if ImGui.IsItemActivated(ctx) then
    -- Because an alt-click sets the value, and the drag that follows must not move it again, the
    -- start of that drag is recorded as false.
    if alt_is_down(ctx) then
      drag_start[param.id] = false
      result = M.default_value(param, bipolar)
    else
      drag_start[param.id] = value
    end
  end
  if ImGui.IsItemActive(ctx) and drag_start[param.id] ~= false then
    local _, dy = ImGui.GetMouseDragDelta(ctx, nil, nil, ImGui.MouseButton_Left, 0)
    local start = drag_start[param.id] or value
    result = math.floor(clamp(start - dy * range / 150, param.low, param.high) + 0.5)
  elseif ImGui.IsItemHovered(ctx) then
    local wheel = ImGui.GetMouseWheel(ctx)
    if wheel ~= 0 then
      local step = math.max(1, math.floor(range / 40))
      result = clamp(value + (wheel > 0 and step or -step), param.low, param.high)
    end
  end

  local dl = ImGui.GetWindowDrawList(ctx)
  local cx, cy, r = x + KNOB_W / 2, y + 4 + KNOB_D / 2, KNOB_D / 2
  local t = (result - param.low) / range
  local angle = KNOB_FROM + t * (KNOB_TO - KNOB_FROM)

  -- The ring: a dark track cut into the panel, and the amber part up to the value.
  ImGui.DrawList_PathArcTo(dl, cx, cy, r, KNOB_FROM, KNOB_TO)
  ImGui.DrawList_PathStroke(dl, th.slot_bg, ImGui.DrawFlags_None, 5)
  local fill_from = bipolar and (KNOB_FROM + KNOB_TO) / 2 or KNOB_FROM
  if angle ~= fill_from then
    ImGui.DrawList_PathArcTo(dl, cx, cy, r, math.min(fill_from, angle), math.max(fill_from, angle))
    ImGui.DrawList_PathStroke(dl, accent(), ImGui.DrawFlags_None, 3)
  end
  if bipolar then
    ImGui.DrawList_AddLine(dl, cx, cy - r - 5, cx, cy - r - 1, th.text_dim, 1)
  end

  -- The body stands out of the panel, with a shadow under it and a lit edge on its upper left.
  local body = r - 7
  ImGui.DrawList_AddCircleFilled(dl, cx + 1, cy + 3, body + 1, 0x00000099)
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, body, th.knob_body)
  ImGui.DrawList_AddCircleFilled(dl, cx - 1, cy - 1, body - 4, th.knob_top)
  local hot = ImGui.IsItemHovered(ctx) or ImGui.IsItemActive(ctx)
  ImGui.DrawList_AddCircle(dl, cx, cy, body, hot and accent() or th.knob_edge, 0, 1)

  -- The pointer runs from near the center toward the ring.
  local cos_a, sin_a = math.cos(angle), math.sin(angle)
  ImGui.DrawList_AddLine(dl, cx + cos_a * body * 0.25, cy + sin_a * body * 0.25,
    cx + cos_a * body * 0.9, cy + sin_a * body * 0.9, th.text, 2)

  centered_label(ctx, label, KNOB_W, KNOB_LABEL_LINES)
  ImGui.EndGroup(ctx)
  return result ~= value, result
end

-- A switch with a lamp, for a parameter that is either 0 or 1. The lamp is lit and the on text is
-- shown when the value is 1. Returns true when the user changed the value, and the new value.
function M.switch(ctx, param, value, label, on_text, off_text)
  local th = env.theme
  ImGui.BeginGroup(ctx)
  -- An empty line takes the place of the knobs' value, so that both line up in a row.
  ImGui.Dummy(ctx, 1, ImGui.GetTextLineHeight(ctx))

  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, "##switch", KNOB_W, KNOB_D + 8)
  local result = value
  if ImGui.IsItemClicked(ctx) then result = 1 - value end

  local dl = ImGui.GetWindowDrawList(ctx)
  local on = result == 1
  local x1, y1, x2, y2 = x + 6, y + 4, x + KNOB_W - 6, y + 4 + KNOB_D
  ImGui.DrawList_AddRectFilled(dl, x1, y1 + 2, x2, y2 + 2, 0x00000099, 5)
  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, on and th.knob_top or th.knob_body, 5)
  local hot = ImGui.IsItemHovered(ctx)
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, hot and accent() or th.knob_edge, 5, 0, 1)

  -- The lamp: a glow around it when it is lit.
  local lx, ly = (x1 + x2) / 2, y1 + 14
  if on then ImGui.DrawList_AddCircleFilled(dl, lx, ly, 9, faded(accent(), 0x55)) end
  ImGui.DrawList_AddCircleFilled(dl, lx, ly, 5, on and accent() or th.slot_bg)
  ImGui.DrawList_AddCircle(dl, lx, ly, 5, th.slot_edge, 0, 1)

  local state = on and on_text or off_text
  local state_w = ImGui.CalcTextSize(ctx, state)
  ImGui.DrawList_AddText(dl, lx - state_w / 2, y2 - 18, accent(), state)

  centered_label(ctx, label, KNOB_W, KNOB_LABEL_LINES)
  ImGui.EndGroup(ctx)
  return result ~= value, result
end

-- ---- the stop knob ----

-- Because a knob with more stops than this has no room for a label at each one, it shows the name of
-- the selected stop in a display under the knob instead.
local STOP_LABELS_MAX = 8

-- How far the mouse travels to move the knob by one stop, with a label at each stop and without.
local STOP_DRAG_LABELLED, STOP_DRAG_PLAIN = 18, 6

-- The values of a parameter that have a name, in order. A name of "(unused)" is a value the keyboard
-- does not use, so that it is not a stop.
local function stops_of(param)
  local stops = {}
  for i, name in ipairs(param.names) do
    if name ~= "(unused)" then stops[#stops + 1] = { value = param.low + i - 1, name = name } end
  end
  return stops
end

local function stop_index(stops, value)
  for i, stop in ipairs(stops) do
    if stop.value == value then return i end
  end
  return 1
end

-- The angle of a stop on the knob's sweep, and the side of the knob its label is on.
local function stop_angle(index, count)
  local t = count > 1 and (index - 1) / (count - 1) or 0.5
  return KNOB_FROM + t * (KNOB_TO - KNOB_FROM)
end

local function stop_side(angle)
  local c = math.cos(angle)
  if c > 0.35 then return "right" end
  if c < -0.35 then return "left" end
  return "top"
end

-- Measures what the stop knob needs around the knob for its labels, in the label font: the width on
-- its left and its right, and the height above it.
local function stop_margins(ctx, stops, labelled)
  local left, right, top = 0, 0, 0
  if labelled then
    local line = ImGui.GetTextLineHeight(ctx)
    for i, stop in ipairs(stops) do
      local side = stop_side(stop_angle(i, #stops))
      local text_w = ImGui.CalcTextSize(ctx, stop.name)
      if side == "left" then left = math.max(left, text_w + 8) end
      if side == "right" then right = math.max(right, text_w + 8) end
      if side == "top" then top = line + 4 end
    end
  end
  return left, right, top
end

-- A knob that turns between named stops: a dot on its ring at each stop, and the name of each stop
-- written beside its dot, with the selected one lit. The user drags up or down, turns the mouse wheel,
-- or clicks a name. A knob with more stops than STOP_LABELS_MAX shows the selected name in a display
-- under it instead of a label at each stop.
-- Returns true when the user changed the value, and the new value.
function M.stop_knob(ctx, param, value, label)
  local th = env.theme
  local stops = stops_of(param)
  local count = #stops
  local labelled = count <= STOP_LABELS_MAX
  local index = stop_index(stops, value)
  local result = index

  ImGui.BeginGroup(ctx)
  -- A normal knob has its value above it; the stop knob leaves the same room, so that both line up.
  local room_above = ImGui.GetTextLineHeightWithSpacing(ctx)
  local pushed = push_label_font(ctx)
  local line = ImGui.GetTextLineHeight(ctx)
  local left, right, top = stop_margins(ctx, stops, labelled)
  top = math.max(top, room_above)

  local r = KNOB_D / 2
  local display_w = 0
  if not labelled then
    for _, stop in ipairs(stops) do display_w = math.max(display_w, ImGui.CalcTextSize(ctx, stop.name) + 32) end
  end
  local label_w = ImGui.CalcTextSize(ctx, label)
  local width = math.max(left + 2 * r + 8 + right, display_w, label_w, KNOB_W)
  local height = top + 2 * r + 8 + (labelled and 0 or line + 12) + line + 8

  local x, y = ImGui.GetCursorScreenPos(ctx)
  local cx = x + width / 2 + (left - right) / 2
  if not labelled then cx = x + width / 2 end
  local cy = y + top + r + 4

  -- The buttons come first: the knob, and a label for each stop that selects it when clicked.
  local clicked = nil
  ImGui.PushID(ctx, param.id)
  ImGui.SetCursorScreenPos(ctx, cx - r - 4, cy - r - 4)
  ImGui.InvisibleButton(ctx, "##stopknob", 2 * r + 8, 2 * r + 8)
  local hot = ImGui.IsItemHovered(ctx) or ImGui.IsItemActive(ctx)
  if ImGui.IsItemActivated(ctx) then
    if alt_is_down(ctx) then
      drag_start[param.id] = false
      result = stop_index(stops, M.default_value(param, false))
    else
      drag_start[param.id] = index
    end
  end
  if ImGui.IsItemActive(ctx) and drag_start[param.id] ~= false then
    local _, dy = ImGui.GetMouseDragDelta(ctx, nil, nil, ImGui.MouseButton_Left, 0)
    local per_stop = labelled and STOP_DRAG_LABELLED or STOP_DRAG_PLAIN
    local start = drag_start[param.id] or index
    result = clamp(start - math.floor(dy / per_stop + 0.5), 1, count)
  elseif ImGui.IsItemHovered(ctx) then
    local wheel = ImGui.GetMouseWheel(ctx)
    if wheel ~= 0 then result = clamp(index + (wheel > 0 and 1 or -1), 1, count) end
  end

  -- The display of a knob with many stops is also a combo: a click on it opens the list of all stops.
  local display_x, display_y, display_h = cx - display_w / 2, cy + r + 6, line + 6
  local display_hot = false
  if not labelled then
    ImGui.SetCursorScreenPos(ctx, display_x, display_y)
    ImGui.InvisibleButton(ctx, "##stopcombo", display_w, display_h)
    display_hot = ImGui.IsItemHovered(ctx)
    if ImGui.IsItemClicked(ctx) then ImGui.OpenPopup(ctx, "##stoplist") end
  end

  local label_boxes = {}
  if labelled then
    for i, stop in ipairs(stops) do
      local angle = stop_angle(i, count)
      local side = stop_side(angle)
      local text_w = ImGui.CalcTextSize(ctx, stop.name)
      local ax, ay = cx + math.cos(angle) * (r + 9), cy + math.sin(angle) * (r + 9)
      local bx = ax
      if side == "left" then bx = ax - text_w elseif side == "top" then bx = ax - text_w / 2 end
      local by = side == "top" and (ay - line - 1) or (ay - line / 2)
      label_boxes[i] = { x = bx, y = by, w = text_w }
      ImGui.SetCursorScreenPos(ctx, bx, by)
      ImGui.InvisibleButton(ctx, "##stop" .. i, text_w, line)
      if ImGui.IsItemClicked(ctx) then clicked = i end
    end
  end
  ImGui.PopID(ctx)
  if clicked then result = clicked end

  -- Drawn last, with the stop this frame's input has just chosen.
  local dl = ImGui.GetWindowDrawList(ctx)
  local angle = stop_angle(result, count)
  ImGui.DrawList_PathArcTo(dl, cx, cy, r, KNOB_FROM, KNOB_TO)
  ImGui.DrawList_PathStroke(dl, th.slot_bg, ImGui.DrawFlags_None, 5)
  for i = 1, count do
    local a = stop_angle(i, count)
    local lit = i == result
    local dx, dy = math.cos(a) * r, math.sin(a) * r
    if lit then ImGui.DrawList_AddCircleFilled(dl, cx + dx, cy + dy, 5, faded(accent(), 0x55)) end
    ImGui.DrawList_AddCircleFilled(dl, cx + dx, cy + dy, lit and 2.8 or 1.8, lit and accent() or th.text_dim)
  end

  local body = r - 7
  ImGui.DrawList_AddCircleFilled(dl, cx + 1, cy + 3, body + 1, 0x00000099)
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, body, th.knob_body)
  ImGui.DrawList_AddCircleFilled(dl, cx - 1, cy - 1, body - 4, th.knob_top)
  ImGui.DrawList_AddCircle(dl, cx, cy, body, hot and accent() or th.knob_edge, 0, 1)
  local cos_a, sin_a = math.cos(angle), math.sin(angle)
  ImGui.DrawList_AddLine(dl, cx + cos_a * body * 0.25, cy + sin_a * body * 0.25,
    cx + cos_a * body * 0.9, cy + sin_a * body * 0.9, th.text, 2)

  if labelled then
    for i, stop in ipairs(stops) do
      local box = label_boxes[i]
      ImGui.DrawList_AddText(dl, box.x, box.y, i == result and accent() or th.label, stop.name)
    end
  else
    -- The display under the knob: a recessed screen with the selected name in the accent color, and
    -- a caret that shows it opens a list.
    ImGui.DrawList_AddRectFilled(dl, display_x, display_y, display_x + display_w, display_y + display_h, th.slot_bg, 3)
    ImGui.DrawList_AddRect(dl, display_x, display_y, display_x + display_w, display_y + display_h,
      display_hot and accent() or th.slot_edge, 3)
    local name = stops[result].name
    ImGui.DrawList_AddText(dl, display_x + (display_w - 14) / 2 - ImGui.CalcTextSize(ctx, name) / 2, display_y + 3, accent(), name)
    local tx, ty = display_x + display_w - 11, display_y + display_h / 2
    ImGui.DrawList_AddTriangleFilled(dl, tx - 4, ty - 2, tx + 4, ty - 2, tx, ty + 3, display_hot and accent() or th.text_dim)
  end

  local caption_y = cy + r + 8 + (labelled and 0 or line + 12) - 2
  ImGui.DrawList_AddText(dl, cx - label_w / 2, caption_y, th.label, label)

  -- The list of every stop, under the display, with the selected one in the accent color. It must be
  -- begun under the same id as the click that opened it.
  if not labelled then
    ImGui.PushID(ctx, param.id)
    ImGui.SetNextWindowPos(ctx, display_x, display_y + display_h + 2, ImGui.Cond_Appearing)
    if ImGui.BeginPopup(ctx, "##stoplist") then
      for i, stop in ipairs(stops) do
        -- Because a click changes `result` in the middle of the loop, whether the item is the selected
        -- one is read once, so that the color pushed is the color popped.
        local selected = i == result
        if selected then ImGui.PushStyleColor(ctx, ImGui.Col_Text, accent()) end
        if ImGui.Selectable(ctx, stop.name, selected) then result = i end
        if selected then ImGui.PopStyleColor(ctx) end
      end
      ImGui.EndPopup(ctx)
    end
    ImGui.PopID(ctx)
  end
  if pushed then ImGui.PopFont(ctx) end

  -- Because ImGui wants an item after every move of the cursor, the control's own space is taken last.
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.Dummy(ctx, width, height)
  ImGui.EndGroup(ctx)
  return result ~= index, stops[result].value
end

-- ---- the brackets over a row of knobs ----

-- A line that looks cut into the panel: a dark copy one pixel below, the light line over it.
local function engraved_line(dl, x1, y1, x2, y2)
  local th = env.theme
  ImGui.DrawList_AddLine(dl, x1, y1 + 1, x2, y2 + 1, th.text_engraved_shadow, 1)
  ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, th.text_dim, 1)
end

-- A row above a row of `count` knobs, with one bracket for each entry of `brackets`: a line that
-- spans the knobs from the entry's `from` to its `to` (counted from 1), with its caption engraved
-- in the line, as the silkscreen of a hardware panel groups its knobs.
function M.bracket_row(ctx, brackets, count)
  local th = env.theme
  local pushed = push_label_font(ctx)
  local spacing = ImGui.GetStyleVar(ctx, ImGui.StyleVar_ItemSpacing)
  local pitch = KNOB_W + spacing
  local x0, y0 = ImGui.GetCursorScreenPos(ctx)
  local height = ImGui.GetTextLineHeight(ctx) + 4
  ImGui.Dummy(ctx, count * pitch - spacing, height)

  local dl = ImGui.GetWindowDrawList(ctx)
  local ymid = y0 + height / 2
  for _, b in ipairs(brackets) do
    local x1 = x0 + (b.from - 1) * pitch + 4
    local x2 = x0 + b.to * pitch - spacing - 4
    local text = b.label:upper()
    local text_w, text_h = ImGui.CalcTextSize(ctx, text)
    local text_x = (x1 + x2) / 2 - text_w / 2
    -- The line is broken around the caption, unless the caption fills the whole bracket.
    if text_x - 6 > x1 then
      engraved_line(dl, x1, ymid, text_x - 6, ymid)
      engraved_line(dl, text_x + text_w + 6, ymid, x2, ymid)
    end
    engraved_line(dl, x1, ymid, x1, ymid + 5)
    engraved_line(dl, x2, ymid, x2, ymid + 5)
    ImGui.DrawList_AddText(dl, text_x, ymid - text_h / 2 + 1, th.text_engraved_shadow, text)
    ImGui.DrawList_AddText(dl, text_x, ymid - text_h / 2, th.text_dim, text)
  end
  if pushed then ImGui.PopFont(ctx) end
end

-- ---- the envelope screen ----

-- The screen is drawn for a plot this wide, and it is stretched when the card gives it more room.
local ENV_W, ENV_H = 240, 110
local ENV_PAD_X, ENV_PAD_TOP, ENV_PAD_BOTTOM = 14, 24, 14

-- Because the screen is a schematic of how the three values shape a note, a segment is drawn ENV_MIN
-- pixels wide when its value is at its lowest, and ENV_SPAN pixels wider when it is at its highest.
-- The note's hold between the decay and the release has a width and a level of its own.
local ENV_MIN, ENV_SPAN = 6, 48
local ENV_HOLD = 36
local ENV_SUSTAIN = 0.55

-- The strength of the curve's glow, a quarter of the accent's.
local ENV_GLOW = 0x44

local function envelope_width(param, value, scale)
  return (ENV_MIN + (value - param.low) / (param.high - param.low) * ENV_SPAN) * scale
end

local function envelope_value(param, width, scale)
  local t = clamp((width / scale - ENV_MIN) / ENV_SPAN, 0, 1)
  return math.floor(param.low + t * (param.high - param.low) + 0.5)
end

-- The five corners of the curve: the start, the top of the attack, the end of the decay, the end of
-- the hold, and the end of the release.
local function envelope_points(geom, attack, decay, release)
  local top_x = geom.left + attack
  local decay_x = top_x + decay
  local hold_x = decay_x + ENV_HOLD * geom.scale
  local sustain_y = geom.bottom - (geom.bottom - geom.top) * ENV_SUSTAIN
  return {
    { geom.left, geom.bottom },
    { top_x, geom.top },
    { decay_x, sustain_y },
    { hold_x, sustain_y },
    { hold_x + release, geom.bottom },
  }
end

-- The screen of an envelope: a dark recessed display that draws the attack, the decay and the
-- release of a note as a glowing curve. Each of the three values has a handle on the curve, which
-- the user drags sideways to change the value, or double-clicks or alt-clicks to bring back to the middle.
-- `params` holds the three parameters as `attack`, `decay` and `release`, and `values` the current
-- value of every parameter by id.
-- Returns the changes, a table of the new values by parameter id, which is empty when nothing moved.
function M.envelope(ctx, params, values)
  local th = env.theme
  local x, y = ImGui.GetCursorScreenPos(ctx)
  -- The screen takes the room the card leaves; the 2 pixels keep the card from showing a scrollbar.
  local avail_w, avail_h = ImGui.GetContentRegionAvail(ctx)
  local width = avail_w >= 120 and avail_w or ENV_W
  local height = avail_h >= 60 and avail_h - 2 or ENV_H
  local geom = { left = x + ENV_PAD_X, right = x + width - ENV_PAD_X, top = y + ENV_PAD_TOP, bottom = y + height - ENV_PAD_BOTTOM }
  geom.scale = (geom.right - geom.left) / (ENV_W - 2 * ENV_PAD_X)

  local attack, decay, release = params.attack, params.decay, params.release
  local points = envelope_points(geom, envelope_width(attack, values[attack.id], geom.scale),
    envelope_width(decay, values[decay.id], geom.scale), envelope_width(release, values[release.id], geom.scale))

  -- Each handle sits on a corner of the curve, and its value is the distance from where its segment
  -- starts, which is the previous corner (or the previous segment's end for the release).
  local handles = {
    { param = attack, corner = 2, origin = points[1][1] },
    { param = decay, corner = 3, origin = points[2][1] },
    { param = release, corner = 5, origin = points[4][1] },
  }
  local changes, hot = {}, nil
  ImGui.PushID(ctx, attack.id)
  for i, h in ipairs(handles) do
    ImGui.SetCursorScreenPos(ctx, points[h.corner][1] - 9, points[h.corner][2] - 9)
    ImGui.InvisibleButton(ctx, "##handle" .. i, 18, 18)
    local active, hovered = ImGui.IsItemActive(ctx), ImGui.IsItemHovered(ctx)
    if ImGui.IsItemActivated(ctx) and alt_is_down(ctx) then
      -- An alt-click brings the handle back to the middle, as it does for a knob.
      changes[h.param.id] = M.default_value(h.param, true)
    elseif active and not alt_is_down(ctx) then
      local mouse_x = ImGui.GetMousePos(ctx)
      local v = envelope_value(h.param, mouse_x - h.origin, geom.scale)
      if v ~= values[h.param.id] then changes[h.param.id] = v end
    elseif hovered and ImGui.IsMouseDoubleClicked(ctx, ImGui.MouseButton_Left) then
      changes[h.param.id] = M.default_value(h.param, true)
    end
    if active or hovered then
      hot = i
      ImGui.SetMouseCursor(ctx, ImGui.MouseCursor_ResizeEW)
    end
  end
  ImGui.PopID(ctx)
  -- Because ImGui wants an item after every move of the cursor, the screen's own space is taken last:
  -- the cursor goes back to the screen's corner, and a Dummy as large as the screen follows.
  ImGui.SetCursorScreenPos(ctx, x, y)
  ImGui.Dummy(ctx, width, height)

  -- The curve is drawn with the values this frame's drag has just set, so that it follows the mouse.
  local a = changes[attack.id] or values[attack.id]
  local d = changes[decay.id] or values[decay.id]
  local r = changes[release.id] or values[release.id]
  points = envelope_points(geom, envelope_width(attack, a, geom.scale), envelope_width(decay, d, geom.scale), envelope_width(release, r, geom.scale))

  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + height, th.slot_bg, 5)
  ImGui.DrawList_AddRect(dl, x, y, x + width, y + height, th.slot_edge, 5)
  ImGui.DrawList_AddLine(dl, x + 5, y + height + 1, x + width - 5, y + height + 1, th.panel_edge_light, 1)

  for i = 0, 8 do
    local gx = geom.left + (geom.right - geom.left) * i / 8
    ImGui.DrawList_AddLine(dl, gx, geom.top, gx, geom.bottom, th.screen_grid, 1)
  end
  for i = 0, 2 do
    local gy = geom.top + (geom.bottom - geom.top) * i / 2
    ImGui.DrawList_AddLine(dl, geom.left, gy, geom.right, gy, th.screen_grid, 1)
  end

  -- The curve, drawn twice: a wide faint line for the glow, and the line itself over it.
  for pass = 1, 2 do
    for _, p in ipairs(points) do ImGui.DrawList_PathLineTo(dl, p[1], p[2]) end
    ImGui.DrawList_PathStroke(dl, pass == 1 and faded(accent(), ENV_GLOW) or accent(), ImGui.DrawFlags_None, pass == 1 and 6 or 2)
  end

  for i, h in ipairs(handles) do
    local px, py = points[h.corner][1], points[h.corner][2]
    if hot == i then
      ImGui.DrawList_AddCircleFilled(dl, px, py, 6, accent())
    else
      ImGui.DrawList_AddCircleFilled(dl, px, py, 5, th.knob_top)
      ImGui.DrawList_AddCircle(dl, px, py, 5, accent(), 0, 1.5)
    end
  end

  -- The three values are read at the top of the screen, in the label font.
  local pushed = push_label_font(ctx)
  local readout = ("A %d    D %d    R %d"):format(a, d, r)
  ImGui.DrawList_AddText(dl, x + ENV_PAD_X, y + 5, accent(), readout)
  if pushed then ImGui.PopFont(ctx) end
  return changes
end

-- ---- the slider of a parameter ----

-- A horizontal slider labelled with the parameter's name; a type shows its name beside the number.
function M.param_slider(ctx, param, value)
  ImGui.SetNextItemWidth(ctx, 260)
  local name = M.value_name(param, value)
  local format = name and ("%d  " .. name) or "%d"
  return ImGui.SliderInt(ctx, param.label, value, param.low, param.high, format)
end

-- ---- the lamp and the display ----

-- A lamp, lit in the given color or dark, as big as a line of text, so that text can follow it.
function M.lamp(ctx, color, lit)
  local th = env.theme
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local size = ImGui.GetTextLineHeight(ctx)
  ImGui.Dummy(ctx, size, size)
  local dl = ImGui.GetWindowDrawList(ctx)
  local cx, cy = x + size / 2, y + size / 2
  if lit then ImGui.DrawList_AddCircleFilled(dl, cx, cy, size / 2 + 1, faded(color, 0x44)) end
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, 5, lit and color or th.slot_bg)
  ImGui.DrawList_AddCircle(dl, cx, cy, 5, th.slot_edge, 0, 1)
  if lit then ImGui.DrawList_AddCircleFilled(dl, cx - 1.5, cy - 1.5, 1.2, 0xFFFFFF99) end
end

-- A small recessed screen with a line of text in it, at least `min_width` pixels wide.
function M.display(ctx, text, color, min_width)
  local th = env.theme
  local x, y = ImGui.GetCursorScreenPos(ctx)
  local text_w, text_h = ImGui.CalcTextSize(ctx, text)
  local width, height = math.max(min_width or 0, text_w + 20), text_h + 10
  ImGui.Dummy(ctx, width, height)
  local dl = ImGui.GetWindowDrawList(ctx)
  ImGui.DrawList_AddRectFilled(dl, x, y, x + width, y + height, th.slot_bg, 3)
  ImGui.DrawList_AddRect(dl, x, y, x + width, y + height, th.slot_edge, 3)
  ImGui.DrawList_AddLine(dl, x + 3, y + height + 1, x + width - 3, y + height + 1, th.panel_edge_light, 1)
  ImGui.DrawList_AddText(dl, x + 10, y + 5, color or th.amber, text)
end

-- ---- the card ----

-- A framed section of the panel, with its title engraved on top. A card may have an accent color,
-- which tints its top and its title and is taken by the lit parts of the controls it holds. Returns true when the card is
-- drawn, and then `end_card` must follow; it grows with what it holds, unless it has a size.
function M.begin_card(ctx, title, width, height, card_accent)
  local th = env.theme
  current_accent = card_accent
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, th.panel_bg)
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, th.panel_edge_dark)
  -- A card that is given a width or a height keeps it; otherwise it grows with what it holds.
  local flags = ImGui.ChildFlags_Border
  if not width then flags = flags | ImGui.ChildFlags_AutoResizeX end
  if not height then flags = flags | ImGui.ChildFlags_AutoResizeY end
  local visible = ImGui.BeginChild(ctx, "##card" .. title, width or 0, height or 0, flags, ImGui.WindowFlags_NoScrollbar)
  if visible then
    M.engraved_text(ctx, title:upper(), card_accent)
    ImGui.Spacing(ctx)
  else
    -- Because `end_card` does not follow a card that is not drawn, its colors are popped here.
    ImGui.PopStyleColor(ctx, 2)
    current_accent = nil
  end
  return visible
end

-- The angle of the slot of each corner's screw, so that no two screws are alike.
local SCREW_ANGLES = { 0.4, 1.2, 2.1, 2.9 }

local function draw_screw(dl, x, y, angle)
  local th = env.theme
  ImGui.DrawList_AddCircleFilled(dl, x + 1, y + 1, 3.2, 0x000000AA)
  ImGui.DrawList_AddCircleFilled(dl, x, y, 3.2, th.screw_body)
  ImGui.DrawList_AddCircle(dl, x, y, 3.2, th.card_bevel_dark, 0, 1)
  ImGui.DrawList_AddCircleFilled(dl, x - 1, y - 1, 0.9, th.screw_light)
  local dx, dy = math.cos(angle) * 2.2, math.sin(angle) * 2.2
  ImGui.DrawList_AddLine(dl, x - dx, y - dy, x + dx, y + dy, th.screw_slot, 1.5)
end

-- Draws the surface of the card over its background: a gradient, a brushed grain, a bevel on its
-- edges, and a screw in each corner. Because the card grows with what it holds, this is drawn when it
-- ends, and the colors are so faint that what they cover stays readable.
local function draw_card_surface(ctx, card_accent)
  local th = env.theme
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetWindowPos(ctx)
  local w, h = ImGui.GetWindowSize(ctx)

  -- The inside of the rounded corners is left out, so that the square gradient does not show there.
  local x1, y1, x2, y2 = x + 3, y + 3, x + w - 3, y + h - 3
  ImGui.DrawList_AddRectFilledMultiColor(dl, x1, y1, x2, y2, th.card_light, th.card_light, th.card_shade, th.card_shade)
  for ly = y1, y2, 3 do ImGui.DrawList_AddLine(dl, x1, ly, x2, ly, th.card_grain, 1) end

  -- A card with an accent is washed with it at the top and has a band of it along its top edge.
  if card_accent then
    local wash = faded(card_accent, 0x30)
    ImGui.DrawList_AddRectFilledMultiColor(dl, x1, y1, x2, y1 + 34, wash, wash, 0x00000000, 0x00000000)
    ImGui.DrawList_AddRectFilled(dl, x + 10, y + 3, x + w - 10, y + 5, card_accent, 1)
  end

  ImGui.DrawList_AddLine(dl, x + 7, y + 1.5, x + w - 7, y + 1.5, th.card_bevel_light, 1)
  ImGui.DrawList_AddLine(dl, x + 7, y + h - 1.5, x + w - 7, y + h - 1.5, th.card_bevel_dark, 1)

  draw_screw(dl, x + 8, y + 8, SCREW_ANGLES[1])
  draw_screw(dl, x + w - 8, y + 8, SCREW_ANGLES[2])
  draw_screw(dl, x + 8, y + h - 8, SCREW_ANGLES[3])
  draw_screw(dl, x + w - 8, y + h - 8, SCREW_ANGLES[4])
end

function M.end_card(ctx)
  draw_card_surface(ctx, current_accent)
  current_accent = nil
  ImGui.EndChild(ctx)
  ImGui.PopStyleColor(ctx, 2)
end

return M
