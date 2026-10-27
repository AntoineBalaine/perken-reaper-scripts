-- @noindex
-- The VR-09 design lab: the plugin's panel drawn from Lua with a mock keyboard, so that the look can
-- be worked on without recompiling and without the keyboard. Run it from REAPER's Actions list
-- ("Script: vr09_lab.lua"); run it again to close it.
--
-- The runner watches theme.lua, widgets.lua and panel.lua. Saving one of them reloads it, and the
-- open window changes at once. An error in a file is shown in the window instead of stopping the
-- script, and the window keeps its place; the next save loads the file again. model.lua, catalog.lua and
-- tones.lua are read once, when the lab starts; extras.lua is read again when it changes.
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
local MODULES = { "theme", "widgets", "scenes", "fuzzy", "scene_link", "panel" } -- in this order
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
-- Reads extras.lua again when it changes, so that a parameter added to it appears without starting the lab
-- again. A value that the lab already holds is kept.
local extras_source = nil

local function check_extras()
  local text = read(dir .. "extras.lua")
  if not text or text == extras_source then return end
  extras_source = text
  local chunk, err = load(text, "@" .. dir .. "extras.lua")
  local ok, extras = false, err
  if chunk then ok, extras = pcall(chunk) end
  if not ok then
    S.errors.extras = extras
    return
  end
  S.errors.extras = nil
  S.extras, S.extras_by_id = extras, {}
  for _, param in ipairs(extras) do
    S.extras_by_id[param.id] = param
    if S.model.values[param.id] == nil then S.model.values[param.id] = param.default or param.low end
  end
end

local function check_reload(force)
  local t = reaper.time_precise()
  if not force and t < next_check then return end
  next_check = t + 0.3
  check_extras()
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
S.tones = dofile(dir .. "tones.lua")
local model_api = dofile(dir .. "model.lua")
S.model_api = model_api
S.model = model_api.new(catalog, reaper.GetResourcePath())
if S.model.registrations[1] then model_api.load_registration(S.model, S.model.registrations[1]) end

-- The parameters that the documentation has and the catalog does not: their values live with the
-- catalog's, by id, and each starts at its default or its lowest value.
-- extras.lua is read by `check_reload`, now and each time the file changes.
S.ui = {
  reg_filter = "", reg_selected = nil,
  scenes = {}, lane = {}, scene_current = 0, -- the session's scenes, the mock automation lane, the Scene parameter's value
  tone = {}, tone_filter = {}, -- the chosen tone of each part (a position in its list), and its search text
  part_on = {}, -- whether each part sounds, by the part's id; a part that is not here is on
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
-- Because each system has different fonts, every role has an ordered list of families for each system.
-- The first family of the list that is installed, or that the lab ships, is used, and the last one,
-- which is the system's own, is used without a check, so that a font that is missing on a computer
-- never leaves the panel without one.
-- The text that no role below claims, such as the notes, the buttons and the tables, is drawn in
-- Saira Condensed in its regular weight, and in the system's sans-serif if its files are missing.
local TEXT_FAMILIES = {
  macos = { "Saira Condensed", "sans-serif" },
  windows = { "Saira Condensed", "sans-serif" },
  linux = { "Saira Condensed", "sans-serif" },
}
local TEXT_SIZE = 15

local LABEL_FAMILIES = {
  macos = { "Saira Condensed", "DIN Alternate" },
  windows = { "Saira Condensed", "Bahnschrift" },
  linux = { "Saira Condensed", "Barlow Semi Condensed", "Roboto Condensed", "Liberation Sans Narrow", "DejaVu Sans Condensed", "Noto Sans", "sans-serif" },
}
local LABEL_SIZE = 14

-- The families that the labels and the titles ask in bold, because the bold weight of such a family is a
-- style of it and not a family of its own, and the regular weight is the one that the text uses.
local BOLD_FAMILIES = { ["Saira Condensed"] = true }

-- The flags of a font: bold for the families of the table above.
local function font_flags(family)
  return BOLD_FAMILIES[family] and ImGui.FontFlags_Bold or ImGui.FontFlags_None
end

-- The card titles are drawn in a heavier face than the controls' labels, so that the two levels of the
-- panel's lettering are told apart: Saira Condensed in bold, a blocky face close to the heavy lettering
-- of the VR-09's section headers. The Lab window offers other faces for the titles, and remembers the
-- choice.
local TITLE_FAMILIES = {
  macos = { "Saira Condensed", "Arial Black" },
  windows = { "Saira Condensed", "Arial Black" },
  linux = { "Saira Condensed", "DejaVu Sans", "Noto Sans", "sans-serif" },
}
local TITLE_SIZE = 18

-- The tabs have a face of their own, so that it can be changed apart from the card titles, and the
-- choice is remembered like the titles'. It is OPTIEdgarBold-Extended when it is installed, because the
-- wide, squared lettering of the VR-09's section headers is close to it. Because that font has no
-- license that allows sharing it, the lab does not ship it. The lab ships Librestile Extended Bold
-- instead, an open font of the same kind, and the tabs use it when Edgar is not installed.
local TAB_FAMILIES = {
  macos = { "OPTIEdgarBold-Extended", "Librestile Extended Bold", "Arial Black" },
  windows = { "OPTIEdgarBold-Extended", "Librestile Extended Bold", "Arial Black" },
  linux = { "OPTIEdgarBold-Extended", "Librestile Extended Bold", "DejaVu Sans", "Noto Sans", "sans-serif" },
}
local TAB_SIZE = 13

-- The numbers of the displays and of the knobs are drawn in a monospaced font, so that every digit has
-- the same width and a value does not shift its neighbors as it changes.
local MONO_FAMILIES = {
  macos = { "Menlo" },
  windows = { "Consolas" },
  linux = { "DejaVu Sans Mono", "Liberation Mono", "Noto Sans Mono", "monospace" },
}
local MONO_SIZE = 13

-- The key of the running system in the tables of families.
local function system_key()
  local os_name = reaper.GetOS()
  if os_name:find("^OSX") or os_name:find("^macOS") then return "macos" end
  if os_name:find("^Win") then return "windows" end
  return "linux"
end

-- What lists the installed fonts on each system. Because macOS and Windows keep one file for each font
-- and the lab cannot ask them for the family names, the file names of their font folders are listed
-- instead, and Linux's fontconfig lists the family names.
local LISTING_COMMANDS = {
  macos = "ls ~/Library/Fonts /Library/Fonts /System/Library/Fonts /System/Library/Fonts/Supplemental 2>/dev/null",
  windows = 'dir /b "%WINDIR%\\Fonts" "%LOCALAPPDATA%\\Microsoft\\Windows\\Fonts" 2>nul',
  linux = "fc-list : family 2>/dev/null",
}

-- The listing is read once, and kept here.
local FONT_LISTING = { read = false, text = nil }

-- The text in lower case and without spaces, hyphens and underscores, so that the family
-- "Saira Condensed" is found in the file name "SairaCondensed-Bold.ttf".
local function squeeze(text)
  return (text:lower():gsub("[ _%-]", ""))
end

-- The squeezed listing of the installed fonts, or nil when the system's command cannot be run.
local function installed_families()
  if FONT_LISTING.read then return FONT_LISTING.text end
  FONT_LISTING.read = true
  local ok, pipe = pcall(io.popen, LISTING_COMMANDS[system_key()])
  if not ok or not pipe then return nil end
  local text = pipe:read("a")
  pipe:close()
  if text and text ~= "" then FONT_LISTING.text = squeeze(text) end
  return FONT_LISTING.text
end

-- The font files that the lab ships, in the plugin's `fonts` folder next to the lab's, by the family name that they answer to. A
-- family has a file for its regular weight and, when it has one, a file for its bold weight. Their
-- licenses are in the same folder.
local BUNDLED_FONTS = {
  ["Saira Condensed"] = { regular = "../fonts/SairaCondensed-Regular.ttf", bold = "../fonts/SairaCondensed-Bold.ttf" },
  ["Librestile Extended Bold"] = { regular = "../fonts/LibrestileExtBold.ttf" },
}

-- The path of the shipped file of a family in a weight, or nil when the family has none or its file is
-- missing. A family without a bold file gives its regular one.
local function bundled_path(family, bold)
  local files = BUNDLED_FONTS[family]
  if not files then return nil end
  local file = bold and files.bold or files.regular
  local handle = io.open(dir .. file, "rb")
  if not handle then return nil end
  handle:close()
  return dir .. file
end

-- Makes a font of a family. A family that the lab ships is loaded from its file, so that it needs no
-- installation, and the family name is used when the file cannot be loaded. Because the bold weight
-- of a shipped family is a file of its own, the bold flag is asked of the system's fonts only.
local function create_font(family, size, flags)
  local bold = flags ~= nil and ImGui.FontFlags_Bold ~= nil and (flags & ImGui.FontFlags_Bold) ~= 0
  local path = bundled_path(family, bold)
  if path then
    local has_bold_file = BUNDLED_FONTS[family].bold ~= nil
    local ok, font = pcall(ImGui.CreateFont, path, size, has_bold_file and ImGui.FontFlags_None or flags)
    if ok and font then return font end
  end
  return ImGui.CreateFont(family, size, flags)
end

-- Whether a family can be used: the family that the lab ships, the generic families ("sans-serif" and
-- "monospace"), and the installed ones. Every family is taken as installed when the listing could
-- not be read.
local function is_installed(family)
  if bundled_path(family) then return true end
  local installed = installed_families()
  if not installed or family == "sans-serif" or family == "monospace" then return true end
  return installed:find(squeeze(family), 1, true) ~= nil
end

-- The first family of the system's list that is installed. The last family is the system's own, and
-- it is returned without a check.
local function pick_family(families)
  local list = families[system_key()]
  for index, family in ipairs(list) do
    if index == #list or is_installed(family) then return family end
  end
end

-- The families the Lab window offers for the card titles, so that a font can be judged by eye: the blocky
-- and the squared ones of each system first. On Linux only the installed ones are offered.
local FONT_CHOICES = {
  macos = { "Arial", "DIN Alternate", "DIN Condensed", "Impact", "Krungthep", "Phosphate", "Monaco", "Arial Black",
    "Rockwell", "Avenir Next Condensed", "Menlo", "Andale Mono", "PT Mono", "Courier New",
    "Helvetica Neue", "Helvetica", "Arial Narrow", "Futura",
    "OPTIEdgarBold-Extended", "Librestile Extended Bold", "Big Shoulders Display Black", "Saira Condensed", "Michroma", "Barlow Condensed", "Barlow Condensed SemiBold", "Roboto Condensed", "Archivo Narrow" },
  windows = { "Arial", "Bahnschrift", "Impact", "Arial Black", "Consolas", "Lucida Console", "Courier New",
    "Arial Narrow", "Librestile Extended Bold" },
  linux = { "Librestile Extended Bold", "Liberation Sans", "DejaVu Sans", "Barlow Semi Condensed", "Roboto Condensed", "Liberation Sans Narrow",
    "DejaVu Sans Condensed", "DejaVu Sans Mono", "Liberation Mono", "Noto Sans Mono", "Noto Sans", "sans-serif", "monospace" },
}

-- The families that the Lab window offers: the installed ones. Because the font files of Windows are not
-- named after their families, all of that system's list is offered.
local function font_choices()
  local key = system_key()
  if key == "windows" then return FONT_CHOICES.windows end
  local found = {}
  for _, family in ipairs(FONT_CHOICES[key]) do
    if is_installed(family) then found[#found + 1] = family end
  end
  return found
end

local FONT_OPTIONS = font_choices()

local LABEL_FAMILY = pick_family(LABEL_FAMILIES)

-- The family chosen in the Lab window for the titles is remembered between runs; without one, the
-- system's default.
local function remembered_family(key, families)
  local family = reaper.GetExtState(SECTION, key)
  for _, option in ipairs(FONT_OPTIONS) do
    if option == family then return family end
  end
  return pick_family(families)
end

local TITLE_FAMILY = remembered_family("title_font", TITLE_FAMILIES)
local TAB_FAMILY = remembered_family("tab_font", TAB_FAMILIES)
local MONO_FAMILY = pick_family(MONO_FAMILIES)

local function new_context()
  contexts = contexts + 1
  -- Each context has a name of its own, so that two never share a window.
  ctx = ImGui.CreateContext("VR-09 lab " .. contexts)
  font = create_font(pick_family(TEXT_FAMILIES), TEXT_SIZE)
  ImGui.Attach(ctx, font)
  env.fonts = {
    label = create_font(LABEL_FAMILY, LABEL_SIZE, font_flags(LABEL_FAMILY)),
    title = create_font(TITLE_FAMILY, TITLE_SIZE, font_flags(TITLE_FAMILY)),
    tab = create_font(TAB_FAMILY, TAB_SIZE),
    mono = create_font(MONO_FAMILY, MONO_SIZE),
  }
  ImGui.Attach(ctx, env.fonts.label)
  ImGui.Attach(ctx, env.fonts.title)
  ImGui.Attach(ctx, env.fonts.tab)
  ImGui.Attach(ctx, env.fonts.mono)
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
  local visible = ImGui.Begin(ctx, "Lab###vr09labctl", nil, ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_AlwaysAutoResize)
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
    -- The title font is chosen by eye. A font is attached to a context, so that a new choice makes the
    -- loop drop this context and start a new one, as it does after an error.
    ImGui.Text(ctx, "Card title font")
    ImGui.SetNextItemWidth(ctx, 240)
    if ImGui.BeginCombo(ctx, "##titlefont", TITLE_FAMILY) then
      for _, family in ipairs(FONT_OPTIONS) do
        if ImGui.Selectable(ctx, family, family == TITLE_FAMILY) then
          TITLE_FAMILY = family
          reaper.SetExtState(SECTION, "title_font", family, true)
          S.font_changed = true
        end
      end
      ImGui.EndCombo(ctx)
    end
    ImGui.Text(ctx, "Tab font")
    ImGui.SetNextItemWidth(ctx, 240)
    if ImGui.BeginCombo(ctx, "##tabfont", TAB_FAMILY) then
      for _, family in ipairs(FONT_OPTIONS) do
        if ImGui.Selectable(ctx, family, family == TAB_FAMILY) then
          TAB_FAMILY = family
          reaper.SetExtState(SECTION, "tab_font", family, true)
          S.font_changed = true
        end
      end
      ImGui.EndCombo(ctx)
    end
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
    if S.font_changed then
      S.font_changed = false
      ctx = nil
      restore_window = true
    end
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
