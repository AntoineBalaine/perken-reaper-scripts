-- The VR-09 design lab: the plugin's panel drawn from Lua with a mock keyboard, so that the look can
-- be worked on without recompiling and without the keyboard. Run it from REAPER's Actions list
-- ("Script: vr09_lab.lua"); run it again to close it.
--
-- The runner watches theme.lua, widgets.lua and panel.lua. Saving one of them reloads it, and the
-- open window changes at once. An error in a file is shown in the window instead of stopping the
-- script, and the window keeps its place; the next save loads the file again. model.lua and
-- catalog.lua are read once, when the lab starts.
--
-- It needs ReaImGui. It speaks the same ReaImGui API as the plugin (0.9.3), so that what is
-- written here ports to Zig call for call.

local script_path = debug.getinfo(1, "S").source:match("^@(.*)$")
local dir = script_path:match("^(.*)[/\\][^/\\]*$") .. "/"

-- ---- one instance: running the action again closes the lab ----

local SECTION = "vr09_lab"
local heartbeat = tonumber(reaper.GetExtState(SECTION, "heartbeat"))
if heartbeat and reaper.time_precise() - heartbeat < 2 then
  reaper.SetExtState(SECTION, "quit", "1", false)
  return
end
reaper.SetExtState(SECTION, "quit", "", false)

if not reaper.ImGui_GetBuiltinPath then
  reaper.ShowMessageBox("The VR-09 lab needs ReaImGui. Install it with ReaPack.", "VR-09 lab", 0)
  return
end
-- ReaImGui's Lua loader lives in the resource folder; another resource folder (a scratch REAPER
-- used for tests) borrows the user's.
package.path = reaper.ImGui_GetBuiltinPath() .. "/?.lua;" .. (os.getenv("HOME") or "") .. "/.config/REAPER/Scripts/ReaTeam Extensions/API/?.lua"
local loaded, ImGui = pcall(function() return require("imgui")("0.9.3") end)
if not loaded then
  reaper.ShowConsoleMsg("VR-09 lab: ReaImGui's Lua loader failed:\n" .. tostring(ImGui) .. "\n")
  return
end

local _, _, action_section, action_command = reaper.get_action_context()

-- ---- the modules the lab reloads ----

local env = { ImGui = ImGui }
local MODULES = { "theme", "widgets", "panel" } -- in this order
local sources = {}
local S = { errors = {}, frame = 0, reloads = 0, notice_text = "", notice_until = 0, notice_is_error = false }

local function read(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local text = f:read("a")
  f:close()
  return text
end

-- Loads a module from its file text; keeps the old one and records the error when it does not load.
local function load_module(name, text)
  local path = dir .. name .. ".lua"
  local chunk, err = load(text, "@" .. path)
  if not chunk then
    S.errors[name] = err
    return false
  end
  local ok, mod = pcall(chunk, env)
  if not ok then
    S.errors[name] = mod
    return false
  end
  env[name] = mod
  S.errors[name] = nil
  return true
end

local next_check = 0
local function check_reload(force)
  local t = reaper.time_precise()
  if not force and t < next_check then return end
  next_check = t + 0.3
  for _, name in ipairs(MODULES) do
    local text = read(dir .. name .. ".lua")
    if text and text ~= sources[name] then
      sources[name] = text
      if load_module(name, text) then
        S.reloads = S.reloads + 1
        S.errors.runtime = nil
        S.reloaded_at = t
      end
    end
  end
end

-- ---- the mock keyboard and the panel's state ----

local catalog = dofile(dir .. "catalog.lua")
local model_api = dofile(dir .. "model.lua")
S.model_api = model_api
S.model = model_api.new(catalog, reaper.GetResourcePath())
if S.model.registrations[1] then model_api.load_registration(S.model, S.model.registrations[1]) end
S.ui = {
  reg_filter = "", reg_selected = nil,
  loop_on = false, send_db = 0, return_db = 0,
  midi_out = 2, midi_in = 2, armed = true, monitor = true, pass = true, bare = false,
}

function S.notice(text, is_error)
  S.notice_text = text
  S.notice_is_error = is_error and true or false
  S.notice_until = S.frame + 240
end

function S.start_job(label, total)
  S.model.job = { label = label, done = 0, total = total }
end

local function tick_job()
  local job = S.model.job
  if not job then return end
  job.done = job.done + 1
  if job.done >= job.total then S.model.job = nil end
end

-- ---- the window ----

local ctx, font
local contexts = 0
local window = nil -- { x, y, w, h } of the last frame, to put the window back after an error
local restore_window = false

-- The fonts of the panel. A font must be attached to the context before the first frame, so that
-- changing one here needs the lab to be closed and run again.
--
-- Because each system ships different fonts, the label font is the first family of the system's
-- list that is installed. On macOS and Windows the system's family is used without a check, because
-- DIN Alternate ships with every macOS and Bahnschrift with Windows 10 and later. On Linux, the
-- families that fontconfig knows are read once with `fc-list`, and the last entry, the generic
-- "sans-serif", is used when no other family is installed.
local LABEL_FAMILIES = {
  macos = { "DIN Alternate" },
  windows = { "Bahnschrift" },
  linux = { "Barlow Semi Condensed", "Roboto Condensed", "Liberation Sans Narrow", "DejaVu Sans Condensed", "Noto Sans", "sans-serif" },
}
local LABEL_SIZE = 14

-- The names of the installed font families, in lower case, or nil when `fc-list` cannot be run.
local function installed_families()
  local ok, pipe = pcall(io.popen, "fc-list : family 2>/dev/null")
  if not ok or not pipe then return nil end
  local text = pipe:read("a")
  pipe:close()
  if not text or text == "" then return nil end
  return text:lower()
end

local function label_family()
  local os_name = reaper.GetOS()
  if os_name:find("^OSX") or os_name:find("^macOS") then return LABEL_FAMILIES.macos[1] end
  if os_name:find("^Win") then return LABEL_FAMILIES.windows[1] end
  local installed = installed_families()
  for _, family in ipairs(LABEL_FAMILIES.linux) do
    if not installed or family == "sans-serif" or installed:find(family:lower(), 1, true) then return family end
  end
  return "sans-serif"
end

local LABEL_FAMILY = label_family()

local function new_context()
  contexts = contexts + 1
  -- Each context has a name of its own, so that two never share a window.
  ctx = ImGui.CreateContext("VR-09 lab " .. contexts)
  font = ImGui.CreateFont("sans-serif", 15)
  ImGui.Attach(ctx, font)
  env.fonts = { label = ImGui.CreateFont(LABEL_FAMILY, LABEL_SIZE) }
  ImGui.Attach(ctx, env.fonts.label)
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
  ImGui.SetNextWindowSize(ctx, 260, 210, ImGui.Cond_FirstUseEver)
  local visible = ImGui.Begin(ctx, "Lab###vr09labctl", nil, ImGui.WindowFlags_NoCollapse)
  if visible then
    local m = S.model
    local _
    _, m.connected = ImGui.Checkbox(ctx, "Keyboard connected", m.connected)
    ImGui.Text(ctx, "MIDI IN mode")
    for _, mode in ipairs({ "mode1", "mode2", "unknown" }) do
      if ImGui.RadioButton(ctx, mode, m.mode == mode) then m.mode = mode end
      ImGui.SameLine(ctx)
    end
    ImGui.NewLine(ctx)
    if ImGui.Button(ctx, "Reload now") then
      for _, name in ipairs(MODULES) do sources[name] = nil end
      check_reload(true)
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Error notice") then S.notice("Could not do that (mock error).", true) end
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
    ImGui.SetNextWindowPos(ctx, 80, 80, ImGui.Cond_FirstUseEver)
    ImGui.SetNextWindowSize(ctx, 640, 560, ImGui.Cond_FirstUseEver)
  end
  local flags = ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_NoSavedSettings
  local visible, open = ImGui.Begin(ctx, "VR-09 design lab###vr09lab", true, flags)
  if visible then
    local x, y = ImGui.GetWindowPos(ctx)
    local w, h = ImGui.GetWindowSize(ctx)
    window = { x = x, y = y, w = w, h = h }
    if failed then draw_errors() else env.panel.draw(ctx, S) end
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
  tick_job()
  if not ctx then new_context() end

  local ok, result = xpcall(draw_frame, debug.traceback)
  if ok then
    consecutive_failures = 0
    if result then reaper.defer(loop) else cleanup() end
  else
    -- A failure inside a frame leaves ImGui's stacks unbalanced, so the context is dropped (ReaImGui
    -- collects it) and the next frame starts a new one in the same place.
    consecutive_failures = consecutive_failures + 1
    S.errors.runtime = result
    ctx = nil
    restore_window = true
    if consecutive_failures >= 5 then
      -- The error view itself keeps failing: stop instead of looping.
      reaper.ShowConsoleMsg("VR-09 lab stopped:\n" .. tostring(result) .. "\n")
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
