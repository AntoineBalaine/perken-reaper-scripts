dofile("/home/antoine/Documents/Experiments/lua/debug_connect.lua")

local os_separator = package.config:sub(1, 1)
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
local SM = require("shortcutManager")

local r = reaper

-- -- CTX MUST BE GLOBAL
Ctx = r.ImGui_CreateContext("shortcut manager")



---initialise the shortcuts manager
local shortcuts = SM(Ctx)
---name all the actions you want to create
local list_action = "shortcut_lst"
local dummy_action = "dummy_action"
local quit_action = "quit"
---create the actions with the name you gave them, and pass the key code that you want to assign to them
shortcuts:Create(list_action, { [reaper.ImGui_Key_L() .. ""] = true })
shortcuts:Create(dummy_action, { [reaper.ImGui_Key_X() .. ""] = true, [reaper.ImGui_Mod_Ctrl() .. ""] = true })
shortcuts:Create(quit_action, { [reaper.ImGui_Key_Escape() .. ""] = true })

function Main()
  r.ImGui_SetWindowSize(Ctx, 400, 300)
  r.ImGui_SetWindowPos(Ctx, 100, 100)
  local visible, open = reaper.ImGui_Begin(Ctx, "shortcut manager", true)
  if visible then
    reaper.ImGui_Text(Ctx, "Hajime!")
    reaper.ImGui_Text(Ctx, "Open the shortcut list with the «L» key")
    ---check whether the shortcut for this action has been triggered
    ---Read() and R() are both the same
    ---Shortcut manager provides shorthand aliases for all CRUD operations
    if shortcuts:Read(list_action) or shortcuts:R(list_action) then
      ---tell ShortcutsManager to display the shortcut list
      shortcuts:openShortcutList()
    end
    ---this is the component that displays the shortcut list in a pop-up window
    shortcuts:DisplayShortcutList()
    r.ImGui_End(Ctx)
  end

  if shortcuts:Read(quit_action) then
    open = false
  end
  if open then
    r.defer(Main)
  else
    reaper.ImGui_DestroyContext(Ctx)
  end
end

reaper.defer(Main)
