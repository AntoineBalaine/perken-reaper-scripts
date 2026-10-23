-- The panel's colors and styles. Saving this file restyles the open window at once.
--
-- Colors are 0xRRGGBBAA. The look imitates a hardware organ: a dark metal face, engraved labels,
-- recessed slots, and caps in the colors of a tonewheel organ's drawbars.
local env = ...
local ImGui = env.ImGui

local M = {}

-- The face of the instrument and the surfaces cut into it.
M.window_bg = 0x1E1E20FF
M.panel_bg = 0x2A2A2DFF
M.panel_edge_light = 0x4A4A4EFF
M.panel_edge_dark = 0x101011FF
M.slot_bg = 0x0E0E0FFF
M.slot_edge = 0x050505FF
-- The faint grid on the screens that draw a curve.
M.screen_grid = 0x1E1E21FF

M.text = 0xD6D2C6FF
M.text_dim = 0x8C8A82FF
-- The labels under the knobs, which must be readable at a glance.
M.label = 0xBCB9AEFF
M.text_engraved_shadow = 0x0A0A0BFF
M.border = 0x3A3A3EFF
-- The outline of the checkboxes, the combos and the other framed widgets, light enough to be seen on
-- the dark frame.
M.frame_border = 0x76767CFF
M.title_bg = 0x2A2A2DFF
M.title_bg_active = 0x36363AFF
M.frame_bg = 0x151517FF
M.frame_bg_hover = 0x202023FF

M.green = 0x4FD68AFF
M.red = 0xE05050FF
M.amber = 0xF0B840FF
M.grey = 0x8C8A82FF

-- The caps of the drawbars: white, brown and black, as on a tonewheel organ.
M.cap_white = 0xEAE6D8FF
M.cap_brown = 0x7B4B2CFF
M.cap_black = 0x1C1C1EFF
M.stem = 0xB8B4A8FF

-- The surface of the cards: a gradient from a lit top to a shaded bottom, a fine brushed grain, a
-- bevel on the edges, and screws in the corners.
M.card_light = 0xFFFFFF0E
M.card_shade = 0x00000028
M.card_grain = 0xFFFFFF06
M.card_bevel_light = 0xFFFFFF1C
M.card_bevel_dark = 0x00000070
M.screw_body = 0x5C5C62FF
M.screw_light = 0x9A9AA2FF
M.screw_slot = 0x1A1A1CFF

-- The knobs and switches: a body of dark metal with a slightly lighter top and a thin edge.
-- The accent of each effect's card. It takes the place of the amber on the lit parts of the controls
-- inside the card.
M.fx = {
  reverb = 0x4FB0E8FF,
  chorus = 0x4FD6A8FF,
  mfx = 0xB67CF0FF,
  delay = 0xF07A5AFF,
  compressor = 0xE86AA8FF,
}

-- The accent of each part of the instrument, in the cards of the Synth, Mixer and Controllers tabs.
M.part = {
  upper = 0x5AC8F0FF,
  lower = 0xF08C5AFF,
  backing = 0xF0B840FF,
  master = 0xC8C4B8FF,
  -- The organ keeps the amber that the lit parts of the controls have by default.
  organ = 0xF0B840FF,
  -- The ivory of a piano's keys.
  piano = 0xF2EBD3FF,
}

M.knob_body = 0x232326FF
M.knob_top = 0x3A3A3FFF
M.knob_edge = 0x56565BFF

-- Because a black cap disappears into the dark slot and panel, each cap has a discreet contour of a
-- lighter tone of its own color, which is only strong enough to show the black cap's lower edge.
M.cap_white_edge = 0x8A877CFF
M.cap_brown_edge = 0x9C6A44FF
M.cap_black_edge = 0x6A6862FF

-- A color from the name ImGui gives it, or nil when this version of ReaImGui does not have it. The
-- tab colors changed names between versions, so that a missing one must not stop the theme.
local function color_id(name)
  local ok, id = pcall(function() return ImGui[name] end)
  if ok then return id end
  return nil
end

-- Pushes the colors and styles for one frame and returns what to pass to `pop`.
function M.push(ctx)
  local colors = {
    { ImGui.Col_WindowBg, M.window_bg },
    { ImGui.Col_ChildBg, 0x00000000 },
    { ImGui.Col_Text, M.text },
    { ImGui.Col_Border, M.frame_border },
    { ImGui.Col_TitleBg, M.title_bg },
    { ImGui.Col_TitleBgActive, M.title_bg_active },
    { ImGui.Col_FrameBg, M.frame_bg },
    { ImGui.Col_FrameBgHovered, M.amber & 0xFFFFFF00 | 0x40 },
    { ImGui.Col_FrameBgActive, M.amber },
    { ImGui.Col_SliderGrab, M.amber },
    { ImGui.Col_SliderGrabActive, 0xFFD060FF },
    { ImGui.Col_CheckMark, M.amber },
    { ImGui.Col_Button, 0x3A3A3EFF },
    { ImGui.Col_ButtonHovered, M.amber & 0xFFFFFF00 | 0x55 },
    { ImGui.Col_ButtonActive, M.amber },
    { ImGui.Col_Header, 0x3A3A3EFF },
    { ImGui.Col_HeaderHovered, M.amber & 0xFFFFFF00 | 0x40 },
    { ImGui.Col_HeaderActive, M.amber },
    { ImGui.Col_Separator, M.border },
    { ImGui.Col_Tab, M.panel_bg },
    { ImGui.Col_TabHovered, 0x4A4A4EFF },
    { color_id("Col_TabSelected") or color_id("Col_TabActive"), 0x3E3E42FF },
    { ImGui.Col_PlotHistogram, M.amber },
  }
  local pushed_colors = 0
  for _, c in ipairs(colors) do
    if c[1] then
      ImGui.PushStyleColor(ctx, c[1], c[2])
      pushed_colors = pushed_colors + 1
    end
  end

  local vars = {
    { ImGui.StyleVar_WindowRounding, 0 },
    { ImGui.StyleVar_FrameRounding, 3 },
    { ImGui.StyleVar_FrameBorderSize, 1 },
    { ImGui.StyleVar_ChildRounding, 6 },
    { ImGui.StyleVar_TabRounding, 3 },
    { ImGui.StyleVar_GrabRounding, 3 },
    { ImGui.StyleVar_WindowPadding, 12, 12 },
    { ImGui.StyleVar_ItemSpacing, 8, 7 },
  }
  for _, v in ipairs(vars) do ImGui.PushStyleVar(ctx, v[1], v[2], v[3]) end
  return { colors = pushed_colors, vars = #vars }
end

function M.pop(ctx, pushed)
  if pushed.vars > 0 then ImGui.PopStyleVar(ctx, pushed.vars) end
  ImGui.PopStyleColor(ctx, pushed.colors)
end

return M
