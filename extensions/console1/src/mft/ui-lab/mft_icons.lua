-- @noindex
-- The icons of the transport mode, drawn with geometry (lines, circles, arcs and triangles) so that they need no font
-- and no image. Each one is drawn around a center, inside a square of `r` pixels from the center, in two colors: the
-- one of the strokes, and the accent of the details that move or point. Saving this file redraws the window at once.
local env = ...
local ImGui = env.ImGui

local M = {}

local function triangle(dl, x1, y1, x2, y2, x3, y3, color)
  ImGui.DrawList_AddTriangleFilled(dl, x1, y1, x2, y2, x3, y3, color)
end

local function line(dl, x1, y1, x2, y2, color, thickness)
  ImGui.DrawList_AddLine(dl, x1, y1, x2, y2, color, thickness)
end

local function arc(dl, cx, cy, radius, from, to, color, thickness)
  ImGui.DrawList_PathArcTo(dl, cx, cy, radius, from, to)
  ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_None, thickness)
end

-- The jog wheel: a ring with a hub, and an arrow on each side of it.
local function jog(dl, cx, cy, r, color, accent)
  ImGui.DrawList_AddCircle(dl, cx, cy, r * 0.5, color, 0, 2)
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, r * 0.12, color)
  triangle(dl, cx - r, cy, cx - r * 0.66, cy - r * 0.3, cx - r * 0.66, cy + r * 0.3, accent)
  triangle(dl, cx + r, cy, cx + r * 0.66, cy - r * 0.3, cx + r * 0.66, cy + r * 0.3, accent)
end

-- The next item: a bar, an arrow that goes to the right, and the item.
local function item(dl, cx, cy, r, color, accent)
  line(dl, cx - r * 0.95, cy - r * 0.55, cx - r * 0.95, cy + r * 0.55, color, 2)
  triangle(dl, cx - r * 0.6, cy - r * 0.4, cx - r * 0.6, cy + r * 0.4, cx - r * 0.05, cy, accent)
  ImGui.DrawList_AddRect(dl, cx + r * 0.2, cy - r * 0.45, cx + r * 0.95, cy + r * 0.45, color, 2, 0, 2)
end

-- A magnifying glass: the lens, and its handle.
local function lens(dl, cx, cy, r, color)
  ImGui.DrawList_AddCircle(dl, cx, cy, r * 0.5, color, 0, 2)
  line(dl, cx + r * 0.36, cy + r * 0.36, cx + r * 0.82, cy + r * 0.82, color, 3)
end

-- The horizontal zoom: a lens, and a double arrow under it that points left and right.
local function zoom_h(dl, cx, cy, r, color, accent)
  lens(dl, cx - r * 0.2, cy - r * 0.3, r * 0.8, color)
  local y = cy + r * 0.85
  line(dl, cx - r * 0.7, y, cx + r * 0.7, y, accent, 2)
  triangle(dl, cx - r * 0.95, y, cx - r * 0.65, y - r * 0.2, cx - r * 0.65, y + r * 0.2, accent)
  triangle(dl, cx + r * 0.95, y, cx + r * 0.65, y - r * 0.2, cx + r * 0.65, y + r * 0.2, accent)
end

-- The vertical zoom: a lens, and a double arrow beside it that points up and down.
local function zoom_v(dl, cx, cy, r, color, accent)
  lens(dl, cx - r * 0.4, cy - r * 0.2, r * 0.8, color)
  local x = cx + r * 0.85
  line(dl, x, cy - r * 0.7, x, cy + r * 0.7, accent, 2)
  triangle(dl, x, cy - r * 0.95, x - r * 0.2, cy - r * 0.65, x + r * 0.2, cy - r * 0.65, accent)
  triangle(dl, x, cy + r * 0.95, x - r * 0.2, cy + r * 0.65, x + r * 0.2, cy + r * 0.65, accent)
end

-- The play rate: a gauge with its scale and a needle.
local function rate(dl, cx, cy, r, color, accent)
  local from, to = math.pi * 0.8, math.pi * 2.2
  arc(dl, cx, cy + r * 0.2, r * 0.9, from, to, color, 2)
  for i = 0, 4 do
    local a = from + (to - from) * i / 4
    line(dl, cx + math.cos(a) * r * 0.9, cy + r * 0.2 + math.sin(a) * r * 0.9,
      cx + math.cos(a) * r * 0.68, cy + r * 0.2 + math.sin(a) * r * 0.68, color, 1)
  end
  local needle = from + (to - from) * 0.55
  line(dl, cx, cy + r * 0.2, cx + math.cos(needle) * r * 0.75, cy + r * 0.2 + math.sin(needle) * r * 0.75, accent, 2)
  ImGui.DrawList_AddCircleFilled(dl, cx, cy + r * 0.2, r * 0.12, accent)
end

-- The grid: a square cut by two lines each way.
local function grid(dl, cx, cy, r, color, accent)
  local a = r * 0.85
  ImGui.DrawList_AddRect(dl, cx - a, cy - a, cx + a, cy + a, color, 2, 0, 2)
  for _, offset in ipairs({ -a / 3, a / 3 }) do
    line(dl, cx + offset, cy - a, cx + offset, cy + a, accent, 1)
    line(dl, cx - a, cy + offset, cx + a, cy + offset, accent, 1)
  end
end

-- The track select: three tracks one above the other, and an arrow that goes down.
local function track(dl, cx, cy, r, color, accent)
  for i = -1, 1 do
    local y = cy + i * r * 0.55
    ImGui.DrawList_AddRectFilled(dl, cx - r * 0.95, y - r * 0.15, cx + r * 0.35, y + r * 0.15, i == 0 and accent or color, 2)
  end
  line(dl, cx + r * 0.7, cy - r * 0.7, cx + r * 0.7, cy + r * 0.45, color, 2)
  triangle(dl, cx + r * 0.7, cy + r * 0.95, cx + r * 0.45, cy + r * 0.45, cx + r * 0.95, cy + r * 0.45, color)
end

-- The marker: a pole, and a flag.
local function marker(dl, cx, cy, r, color, accent)
  line(dl, cx - r * 0.55, cy - r * 0.95, cx - r * 0.55, cy + r * 0.95, color, 2)
  triangle(dl, cx - r * 0.55, cy - r * 0.95, cx + r * 0.9, cy - r * 0.45, cx - r * 0.55, cy + r * 0.05, accent)
end

-- ---- the icons of the side keys, small ones ----

-- The chain: two links, one through the other.
local function chain(dl, cx, cy, r, color)
  ImGui.DrawList_AddRect(dl, cx - r, cy - r * 0.5, cx + r * 0.25, cy + r * 0.5, color, r * 0.5, 0, 1.6)
  ImGui.DrawList_AddRect(dl, cx - r * 0.25, cy - r * 0.5, cx + r, cy + r * 0.5, color, r * 0.5, 0, 1.6)
end

-- Hide: an eye with a line across it.
local function hide(dl, cx, cy, r, color)
  arc(dl, cx, cy + r * 0.6, r * 1.05, math.pi * 1.25, math.pi * 1.75, color, 1.6)
  arc(dl, cx, cy - r * 0.6, r * 1.05, math.pi * 0.25, math.pi * 0.75, color, 1.6)
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, r * 0.28, color)
  line(dl, cx - r, cy + r * 0.85, cx + r, cy - r * 0.85, color, 1.6)
end

-- The plugin selector: a chip with pins on its two sides.
local function fxsel(dl, cx, cy, r, color)
  ImGui.DrawList_AddRect(dl, cx - r * 0.55, cy - r * 0.65, cx + r * 0.55, cy + r * 0.65, color, 2, 0, 1.6)
  for i = -1, 1 do
    local y = cy + i * r * 0.4
    line(dl, cx - r * 0.95, y, cx - r * 0.55, y, color, 1.4)
    line(dl, cx + r * 0.55, y, cx + r * 0.95, y, color, 1.4)
  end
  ImGui.DrawList_AddCircleFilled(dl, cx, cy, r * 0.16, color)
end

-- Mute: a loudspeaker with a cross.
local function mute(dl, cx, cy, r, color)
  ImGui.DrawList_AddRectFilled(dl, cx - r, cy - r * 0.32, cx - r * 0.4, cy + r * 0.32, color, 0)
  triangle(dl, cx - r * 0.4, cy - r * 0.32, cx + r * 0.2, cy - r * 0.85, cx + r * 0.2, cy + r * 0.85, color)
  triangle(dl, cx - r * 0.4, cy - r * 0.32, cx + r * 0.2, cy + r * 0.85, cx - r * 0.4, cy + r * 0.32, color)
  line(dl, cx + r * 0.5, cy - r * 0.4, cx + r * 1.05, cy + r * 0.4, color, 1.6)
  line(dl, cx + r * 0.5, cy + r * 0.4, cx + r * 1.05, cy - r * 0.4, color, 1.6)
end

-- Solo: headphones.
local function solo(dl, cx, cy, r, color)
  arc(dl, cx, cy + r * 0.1, r * 0.85, math.pi, math.pi * 2, color, 1.8)
  ImGui.DrawList_AddRectFilled(dl, cx - r * 1.0, cy + r * 0.05, cx - r * 0.5, cy + r * 0.9, color, 2)
  ImGui.DrawList_AddRectFilled(dl, cx + r * 0.5, cy + r * 0.05, cx + r * 1.0, cy + r * 0.9, color, 2)
end

-- Phase: the sign of an inverted phase, a circle with a line across it.
local function phase(dl, cx, cy, r, color)
  ImGui.DrawList_AddCircle(dl, cx, cy, r * 0.7, color, 0, 1.7)
  line(dl, cx - r * 0.95, cy + r * 0.95, cx + r * 0.95, cy - r * 0.95, color, 1.7)
end

local ICONS = { jog = jog, chain = chain, hide = hide, fxsel = fxsel, mute = mute, solo = solo, phase = phase, item = item, zoom_h = zoom_h, zoom_v = zoom_v, rate = rate, grid = grid, track = track, marker = marker }

-- Draws the icon of that name around the center (cx, cy), `r` pixels from the center to the edge of its square. A
-- name that has no icon draws nothing.
function M.draw(dl, name, cx, cy, r, color, accent)
  local draw = ICONS[name]
  if draw then draw(dl, cx, cy, r, color, accent) end
end

return M
