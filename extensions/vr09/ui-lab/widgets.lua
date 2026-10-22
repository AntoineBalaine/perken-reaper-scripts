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
function M.engraved_text(ctx, text)
  local th = env.theme
  local pushed = push_label_font(ctx)
  local dl = ImGui.GetWindowDrawList(ctx)
  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.DrawList_AddText(dl, x, y + 1, th.text_engraved_shadow, text)
  ImGui.DrawList_AddText(dl, x, y, th.text_dim, text)
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
  ImGui.TextColored(ctx, th.amber, text)

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
    ImGui.DrawList_AddRect(dl, cap_x1, cap_y1, cap_x2, cap_y2, th.amber, 3)
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

-- "Rotary woofer slow speed" is shown as "woofer slow speed" in the card of the group "Rotary".
function M.short_label(label, group_name)
  local prefix = group_name .. " "
  if label:sub(1, #prefix) == prefix then return label:sub(#prefix + 1) end
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
  ImGui.TextColored(ctx, env.theme.amber, text)
end

-- A rotary knob: the value above it, a ring that fills as the value rises, a pointer, and the label
-- under it. The user drags up or down, or turns the mouse wheel over it.
-- When `bipolar` is true, the value rests in the middle of the range, so that the ring fills from the
-- top, to the left or to the right of it, and a tick marks the middle.
-- Returns true when the user changed the value, and the new value.
function M.knob(ctx, param, value, label, bipolar)
  local th = env.theme
  ImGui.BeginGroup(ctx)
  centered_value(ctx, tostring(value), KNOB_W)

  local x, y = ImGui.GetCursorScreenPos(ctx)
  ImGui.InvisibleButton(ctx, "##knob", KNOB_W, KNOB_D + 8)
  local range = param.high - param.low
  local result = value
  if ImGui.IsItemActivated(ctx) then drag_start[param.id] = value end
  if ImGui.IsItemActive(ctx) then
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
    ImGui.DrawList_PathStroke(dl, th.amber, ImGui.DrawFlags_None, 3)
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
  ImGui.DrawList_AddCircle(dl, cx, cy, body, hot and th.amber or th.knob_edge, 0, 1)

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
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, hot and th.amber or th.knob_edge, 5, 0, 1)

  -- The lamp: a glow around it when it is lit.
  local lx, ly = (x1 + x2) / 2, y1 + 14
  if on then ImGui.DrawList_AddCircleFilled(dl, lx, ly, 9, 0xF0B84055) end
  ImGui.DrawList_AddCircleFilled(dl, lx, ly, 5, on and th.amber or th.slot_bg)
  ImGui.DrawList_AddCircle(dl, lx, ly, 5, th.slot_edge, 0, 1)

  local state = on and on_text or off_text
  local state_w = ImGui.CalcTextSize(ctx, state)
  ImGui.DrawList_AddText(dl, lx - state_w / 2, y2 - 18, on and th.amber or th.text_dim, state)

  centered_label(ctx, label, KNOB_W, KNOB_LABEL_LINES)
  ImGui.EndGroup(ctx)
  return result ~= value, result
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

-- ---- the slider of a parameter ----

-- A horizontal slider labelled with the parameter's name; a type shows its name beside the number.
function M.param_slider(ctx, param, value)
  ImGui.SetNextItemWidth(ctx, 260)
  local name = M.value_name(param, value)
  local format = name and ("%d  " .. name) or "%d"
  return ImGui.SliderInt(ctx, param.label, value, param.low, param.high, format)
end

-- ---- the card ----

-- A framed section of the panel, with its title engraved on top. Returns true when the card is
-- drawn, and then `end_card` must follow; it grows with what it holds.
function M.begin_card(ctx, title)
  local th = env.theme
  ImGui.PushStyleColor(ctx, ImGui.Col_ChildBg, th.panel_bg)
  ImGui.PushStyleColor(ctx, ImGui.Col_Border, th.panel_edge_dark)
  local flags = ImGui.ChildFlags_Border | ImGui.ChildFlags_AutoResizeX | ImGui.ChildFlags_AutoResizeY
  local visible = ImGui.BeginChild(ctx, "##card" .. title, 0, 0, flags)
  if visible then
    M.engraved_text(ctx, title:upper())
    ImGui.Spacing(ctx)
  else
    -- Because `end_card` does not follow a card that is not drawn, its colors are popped here.
    ImGui.PopStyleColor(ctx, 2)
  end
  return visible
end

function M.end_card(ctx)
  ImGui.EndChild(ctx)
  ImGui.PopStyleColor(ctx, 2)
end

return M
