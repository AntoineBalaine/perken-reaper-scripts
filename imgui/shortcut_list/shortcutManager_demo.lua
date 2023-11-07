dofile("/home/antoine/Documents/Experiments/lua/debug_connect.lua")

local os_separator = package.config:sub(1, 1)
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
local SM = require("shortcutManager")

r = reaper

-- -- CTX MUST BE GLOBAL
ctx = r.ImGui_CreateContext("shortcut manager")



local shortcuts = SM(ctx, { "quit" })
local list_action = "shortcut_lst"
shortcuts:Create(list_action, { [reaper.ImGui_Key_L() .. ""] = true })

function Main()
  r.ImGui_SetWindowSize(ctx, 400, 300)
  -- TODO place imGui window in the center of the screen?
  r.ImGui_SetWindowPos(ctx, 100, 100)
  local visible, open = reaper.ImGui_Begin(ctx, "shortcut manager", true)
  if visible then
    reaper.ImGui_Text(ctx, "Hajime!")
    if shortcuts:Read("quit") then
      open = false
    end
    if shortcuts:Read(list_action) or shortcuts:isShortcutListOpen() then
      shortcuts:DisplayShortcutList()
    end
    r.ImGui_End(ctx)
  end
  if open then
    r.defer(Main)
  else
    reaper.ImGui_DestroyContext(ctx)
  end
end

reaper.defer(Main)
