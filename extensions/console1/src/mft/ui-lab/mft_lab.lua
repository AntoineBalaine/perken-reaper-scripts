-- @noindex
-- The MFT design lab: the MFT panel drawn from Lua with mock data, so that its look can be worked on without
-- recompiling and without the controller. It is a dummy: nothing in it talks to REAPER or to the plugin. Run it from
-- REAPER's Actions list ("Script: mft_lab.lua"); run it again to close it. Click the encoders of the bottom two rows
-- to switch modes, and drag the others to turn them.
--
-- The runner watches `mft_panel.lua` and `mft_icons.lua`, and the theme and the widgets of the VR-09 lab, which the
-- MFT panel shares. Saving one of them reloads it, and the open window changes at once. An error in a file is shown in
-- the window instead of stopping the script; the next save loads the file again. `mft_model.lua` is read once, when
-- the lab starts.
--
-- It needs ReaImGui. It speaks the same ReaImGui API as the plugin (0.9.3), so that what is written here ports to Zig
-- call for call.

local script_path = debug.getinfo(1, "S").source:match("^@(.*)$")
local dir = script_path:match("^(.*)[/\\][^/\\]*$") .. "/"
-- The theme and the widgets are the VR-09 lab's, and the fonts are the ones that reaziglib ships.
local vr09_dir = dir .. "../../../../vr09/ui-lab/"
local fonts_dir = dir .. "../../../../reaziglib/assets/fonts/"

-- ---- one instance: running the action again closes the lab ----

local SECTION = "mft_lab"
local heartbeat = tonumber(reaper.GetExtState(SECTION, "heartbeat"))
if heartbeat and reaper.time_precise() - heartbeat < 2 then
  reaper.SetExtState(SECTION, "quit", "1", false)
  return
end
reaper.SetExtState(SECTION, "quit", "", false)

if not reaper.ImGui_GetBuiltinPath then
  reaper.ShowMessageBox("The MFT lab needs ReaImGui. Install it with ReaPack.", "MFT lab", 0)
  return
end
-- ReaImGui's Lua loader lives in the resource folder; another resource folder (a scratch REAPER used for tests)
-- borrows the user's.
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua;" .. (os.getenv("HOME") or "") .. "/.config/REAPER/Scripts/ReaTeam Extensions/API/?.lua"
local loaded, ImGui = pcall(function() return require("imgui")("0.9.3") end)
if not loaded then
  reaper.ShowConsoleMsg("MFT lab: ReaImGui's Lua loader failed:\n" .. tostring(ImGui) .. "\n")
  return
end

local _, _, action_section, action_command = reaper.get_action_context()

-- ---- the modules the lab reloads ----

local env = { ImGui = ImGui, fonts = {} }
local MODULES = { -- in this order
  { name = "theme", path = vr09_dir .. "theme.lua" },
  { name = "widgets", path = vr09_dir .. "widgets.lua" },
  { name = "mft_icons", path = dir .. "mft_icons.lua" },
  { name = "mft_panel", path = dir .. "mft_panel.lua" },
}
local sources = {}
local S = { errors = {}, frame = 0, reloads = 0, animate = false }

local function read(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local text = f:read("a")
  f:close()
  return text
end

-- Loads a module from its file text; keeps the old one and records the error when it does not load.
local function load_module(module, text)
  local chunk, err = load(text, "@" .. module.path)
  if not chunk then
    S.errors[module.name] = err
    return false
  end
  local ok, result = pcall(chunk, env)
  if not ok then
    S.errors[module.name] = result
    return false
  end
  env[module.name] = result
  S.errors[module.name] = nil
  return true
end

local next_check = 0

local function check_reload(force)
  local t = reaper.time_precise()
  if not force and t < next_check then return end
  next_check = t + 0.3
  for _, module in ipairs(MODULES) do
    local text = read(module.path)
    if text and text ~= sources[module.name] then
      sources[module.name] = text
      if load_module(module, text) then
        S.reloads = S.reloads + 1
        S.errors.runtime = nil
        S.reloaded_at = t
      end
    end
  end
end

-- ---- the mock controller ----

S.model = dofile(dir .. "mft_model.lua")
S.mft = S.model.new()

-- ---- the window ----

local ctx, font
local contexts = 0
local window = nil -- { x, y, w, h } of the last frame, to put the window back after an error
local restore_window = false

-- Makes a font from one of the files that reaziglib ships, or the system's sans-serif when the file is missing.
local function create_font(file, size)
  if read(fonts_dir .. file) then
    local ok, made = pcall(ImGui.CreateFont, fonts_dir .. file, size)
    if ok and made then return made end
  end
  return ImGui.CreateFont("sans-serif", size)
end

-- A font must be attached to the context before its first frame.
local function new_context()
  contexts = contexts + 1
  -- Each context has a name of its own, so that two never share a window.
  ctx = ImGui.CreateContext("MFT lab " .. contexts)
  font = create_font("SairaCondensed-Regular.ttf", 15)
  env.fonts = {
    label = create_font("SairaCondensed-Bold.ttf", 14),
    title = create_font("SairaCondensed-Bold.ttf", 18),
    tab = create_font("LibrestileExtBold.ttf", 13),
  }
  env.fonts.mono = env.fonts.label
  ImGui.Attach(ctx, font)
  ImGui.Attach(ctx, env.fonts.label)
  ImGui.Attach(ctx, env.fonts.title)
  ImGui.Attach(ctx, env.fonts.tab)
end

local function error_lines()
  local lines = {}
  for name, err in pairs(S.errors) do lines[#lines + 1] = name .. ": " .. tostring(err) end
  table.sort(lines)
  return lines
end

local function draw_errors()
  ImGui.TextColored(ctx, 0xE05050FF, "The last change did not load. Fix it and save the file:")
  for _, line in ipairs(error_lines()) do ImGui.TextWrapped(ctx, line) end
end

local function draw_lab_controls()
  local visible = ImGui.Begin(ctx, "Lab###mftlabctl", nil, ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_AlwaysAutoResize)
  if visible then
    local _
    _, S.animate = ImGui.Checkbox(ctx, "Turn the encoders by themselves", S.animate)
    if ImGui.Button(ctx, "Reload now") then
      for _, module in ipairs(MODULES) do sources[module.name] = nil end
      check_reload(true)
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Reset the mock") then S.mft = S.model.new() end
    ImGui.Text(ctx, ("Reloads: %d"):format(S.reloads))
    if S.reloaded_at and reaper.time_precise() - S.reloaded_at < 1.5 then
      ImGui.SameLine(ctx)
      ImGui.TextColored(ctx, 0x13BD99FF, "reloaded")
    end
    ImGui.End(ctx)
  end
end

-- Draws one frame. Returns false when the window was closed.
local function draw_frame()
  local failed = next(S.errors) ~= nil
  local pushed = nil
  if not failed then pushed = env.theme.push(ctx) end
  ImGui.PushFont(ctx, font)
  if restore_window and window then
    ImGui.SetNextWindowPos(ctx, window.x, window.y, ImGui.Cond_Always)
    ImGui.SetNextWindowSize(ctx, window.w, window.h, ImGui.Cond_Always)
    restore_window = false
  else
    ImGui.SetNextWindowPos(ctx, 80, 60, ImGui.Cond_FirstUseEver)
    ImGui.SetNextWindowSize(ctx, 760, 800, ImGui.Cond_FirstUseEver)
  end
  local flags = ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_NoSavedSettings
  local visible, open = ImGui.Begin(ctx, "MFT design lab###mftlab", true, flags)
  if visible then
    local x, y = ImGui.GetWindowPos(ctx)
    local w, h = ImGui.GetWindowSize(ctx)
    window = { x = x, y = y, w = w, h = h }
    if failed then draw_errors() else env.mft_panel.draw(ctx, S) end
    ImGui.End(ctx)
  end
  ImGui.PopFont(ctx)
  if pushed then env.theme.pop(ctx, pushed) end
  draw_lab_controls()
  return open
end

-- ---- the loop ----

local function cleanup()
  reaper.SetExtState(SECTION, "heartbeat", "", false)
  reaper.SetToggleCommandState(action_section, action_command, 0)
  reaper.RefreshToolbar2(action_section, action_command)
end
reaper.atexit(cleanup)

local consecutive_failures = 0

local function loop()
  if reaper.GetExtState(SECTION, "quit") == "1" then
    reaper.SetExtState(SECTION, "quit", "", false)
    cleanup()
    return
  end
  reaper.SetExtState(SECTION, "heartbeat", tostring(reaper.time_precise()), false)
  S.frame = S.frame + 1
  check_reload(false)
  if S.animate then S.model.animate(S.mft, S.frame) end
  if not ctx then new_context() end

  local ok, result = xpcall(draw_frame, debug.traceback)
  if ok then
    consecutive_failures = 0
    if result then reaper.defer(loop) else cleanup() end
  else
    -- A failure inside a frame leaves ImGui's stacks unbalanced, so the context is dropped (ReaImGui collects it) and
    -- the next frame starts a new one in the same place.
    consecutive_failures = consecutive_failures + 1
    S.errors.runtime = result
    ctx = nil
    restore_window = true
    if consecutive_failures >= 5 then
      -- The error view itself keeps failing: stop instead of looping.
      reaper.ShowConsoleMsg("MFT lab stopped:\n" .. tostring(result) .. "\n")
      cleanup()
    else
      reaper.defer(loop)
    end
  end
end

check_reload(true)
reaper.SetToggleCommandState(action_section, action_command, 1)
reaper.RefreshToolbar2(action_section, action_command)
loop()
