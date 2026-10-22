-- The panel's components: the drawbar, the slider of a parameter. A new component starts here, and
-- the panel calls it. Saving this file redraws the window at once.
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

-- A vertical slider with the value above it and the name below.
-- Returns true when the user changed the value, and the new value.
function M.drawbar(ctx, param, value)
  ImGui.BeginGroup(ctx)
  local changed, v = ImGui.VSliderInt(ctx, "##v", 34, 120, value, param.low, param.high)
  ImGui.Text(ctx, short_drawbar_name(param.label))
  ImGui.EndGroup(ctx)
  return changed, v
end

-- A horizontal slider labelled with the parameter's name; a type shows its name beside the number.
function M.param_slider(ctx, param, value)
  ImGui.SetNextItemWidth(ctx, 260)
  local name = M.value_name(param, value)
  local format = name and ("%d  " .. name) or "%d"
  return ImGui.SliderInt(ctx, param.label, value, param.low, param.high, format)
end

return M
