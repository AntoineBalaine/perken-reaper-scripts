-- The panel's colors and styles. Saving this file restyles the open window at once.
--
-- Colors are 0xRRGGBBAA. These are the plugin's own (reaziglib's theme/palette.zig): ReaImGui's
-- defaults give the blue sliders and tabs, and only the window itself is repainted here.
local env = ...
local ImGui = env.ImGui

local M = {}

M.window_bg = 0x333333FF
M.text = 0x818989FF
M.border = 0x4F4F4FFF
M.title_bg = 0x464646FF
M.title_bg_active = 0x606060FF
M.frame_bg = 0x333333FF

M.green = 0x13BD99FF
M.red = 0xE05050FF
M.amber = 0xE0B040FF
M.grey = 0x818989FF

-- Pushes the colors and styles for one frame and returns what to pass to `pop`.
function M.push(ctx)
  local colors = {
    { ImGui.Col_WindowBg, M.window_bg },
    { ImGui.Col_Text, M.text },
    { ImGui.Col_Border, M.border },
    { ImGui.Col_TitleBg, M.title_bg },
    { ImGui.Col_TitleBgActive, M.title_bg_active },
    { ImGui.Col_FrameBg, M.frame_bg },
  }
  for _, c in ipairs(colors) do ImGui.PushStyleColor(ctx, c[1], c[2]) end
  return { colors = #colors, vars = 0 }
end

function M.pop(ctx, pushed)
  if pushed.vars > 0 then ImGui.PopStyleVar(ctx, pushed.vars) end
  ImGui.PopStyleColor(ctx, pushed.colors)
end

return M
