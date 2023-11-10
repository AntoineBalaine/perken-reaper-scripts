local os_separator = package.config:sub(1, 1)
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
local helpers = require("shortcutManager_helpers")

local r = reaper

--[[Returns ShortcutManager, a class with methods to create, delete, and save shortcuts in the ImGui context.

-------------------
Usage:
-------------------
```lua
local shortcuts = ShortcutManager(ctx, { "quit" }, "/path/to/shortcuts/file") -- initiate, and ask ShortcutManager to create a "quit" action, it will assign `ESC` by default. If a config file is provided, it will load the shortcuts from it. Don't put this in your `loop()` funtion
local programRun = true
if shortcuts:Read("quit") then -- will return true if the shortcut for this action has been pressed
  programRun = false -- then tell the program to quit or whatever else you need to do
end
shortcuts:Create("save", { [reaper.ImGui_Key_S() .. ""] = true }) -- will create a shortcut for this action, and assign `s` to it.
---note that the key must be a string, and that the value must be `true`. ShortcutManager uses key-indices internally.
shortcuts:Delete("quit") -- will delete the shortcut for this action
```

-------------------
If you want to display the actions list to the user:
-------------------
```lua
shortcuts:Create("display action list") .. ""] = true })
-- in your loop() function:
if shortcuts:Read("display action list") or shortcuts.isShortcutListOpen() then
  shortcuts:DisplayShortcutList()-- open a pop-up window that contains the action list, and its corresponding shortcuts
end
```

-------------------
In case you'd like to create a table of shortcuts from the caller script, you can do:
-------------------
```lua
local shortcuts = ShortcutManager(ctx) -- initiate, but don't pass anything.
local actions = {"quit" = reaper.ImGui_Key_Escape(), "save" = reaper.ImGui_Key_S()} -- your list of actions
for k, v in pairs(actions) do
  shortcuts:Create(k, {[v .. ""] = true})
end
```


]]
---@param ctx ImGui_Context
---@param actions_list? string[] list of actions for which to create shortcuts
---@param config_path? string path to config file that contains pre-recorded shortcuts
local function ShortcutManager(ctx, actions_list, config_path)
  local S = {}
  ---@alias Shortcut table<string, boolean|nil>
  ---@type table<string, Shortcut>
  S.actions = {}
  S.shortcutListOpen = false
  S.openRecordPopup = false
  S.recordedAction = nil
  S.isRecordPopupOpen = false
  function S:init()
    if actions_list then
      for i, action in ipairs(actions_list) do
        self:Create(action)
      end
    end
    return self
  end

  --- Upon hitting key in the keyboard, record the shortcut.
  --- Check all the keys in AllAvailableKeys.
  --- Whichever ones have been hit, add them to the shortcut.
  ---@param action string
  ---@return boolean hasPressed false while the user doesn't press any key
  ---@return string|nil takenAction name of the action that's using the currently-pressed shortcut. Prompt the user to replace
  function S:recordShortcut(action)
    local ActionTaken = nil ---@type nil|string  ---name of the action that's using the currently-pressed shortcut
    local keysPressed = self:getKeysPressed()
    if keysPressed == nil or helpers.onlyModKeys(keysPressed) then
      return false
    end
    ---close popup if user presses escape
    if keysPressed[reaper.ImGui_Key_Escape() .. ""] then
      self.openRecordPopup = false
      self.recordedAction = nil
      return true
    end
    --[[
        if there's already a shortcut for this action, we're going to replace it.
        We need to first check whether this shortcut isn't already used.
        If so, prompt the user to confirm that they want to replace the existing shortcut.
        If so, remove the existing shortcut, and add the new one to the table
        ]]
    --iterate all actions, and check compareShortcuts
    for actionName, val in pairs(self.actions) do
      if helpers.compareShortcuts(keysPressed, val) then
        if actionName == action then
          return true
        else
          ActionTaken = actionName
          return true, ActionTaken
        end
      end
    end
    ---Since there is no existing shortcut, we can add the new one to the table
    self.actions[action] = keysPressed
    self.recordedAction  = nil
    return true
  end

  ---check all the keys that have been pressed
  ---@return Shortcut|nil keys_pressed array of key codes, each at the index of the code, i.e. key code 1 is at index 1, key code 2 is at index 2, etc.
  function S:getKeysPressed()
    local keysPressed = {} ---@type Shortcut
    for keyName, keyCode in pairs(helpers.AllAvailableKeys) do
      if helpers.isModifier(keyCode) and r.ImGui_IsKeyDown(ctx, keyCode) then
        keysPressed[keyCode .. ""] = true
      end
      if r.ImGui_IsKeyPressed(ctx, keyCode) then
        keysPressed[keyCode .. ""] = true
      end
    end
    return next(keysPressed) and keysPressed or nil
  end

  ---@param action string
  ---@return Shortcut
  function S:lookUp(action)
    return self.actions[action] or { nil }
  end

  ---Read shortcut: check if shortcut was pressed for the action
  ---@param action string
  ---@return boolean
  function S:Read(action)
    if self.isRecordPopupOpen then
      return false
    end
    ---check all the keys that have been pressed
    ---iterate them
    ---if one of the keys is not in the shortcut, return false
    ---reciprocal is also true: if one of the keys of keypressed is not in shortcut, return false
    local keysPressed = self:getKeysPressed()
    local shortcut = self:lookUp(action)
    if keysPressed == nil or next(keysPressed) == nil or next(shortcut) == nil then return false end
    for k, _ in pairs(shortcut) do
      if not keysPressed[k] then return false end
    end
    for k, _ in pairs(keysPressed) do
      if not shortcut[k] then return false end
    end
    return true
  end

  ---create Action
  ---@param action string
  ---@param shortcut? Shortcut
  function S:Create(action, shortcut)
    -- insert in the action table with value nil.
    -- if user opens the shortcut list, he can update the value
    -- when user adds the value
    self.actions[action] = shortcut or { [""] = true }
  end

  ---update Action
  ---@param action string
  ---@param shortcut? Shortcut[]
  function S:Update(action, shortcut)
    -- update an entry in the in the actions table with value nil.
    self.actions[action] = shortcut
  end

  ---delete Action
  ---@param action string
  function S:Delete(action)
    self.actions[action] = { [""] = true }
  end

  ---shorthand alias of «read Action»
  ---@param action string
  ---@return boolean
  function S:R(action)
    return self:Read(action)
  end

  ---shorthand alias of «create Action»
  ---@param action string
  ---@param shortcut? Shortcut
  function S:C(action, shortcut)
    return self:Create(action, shortcut)
  end

  ---shorthand alias of «update Action»
  ---@param action string
  ---@param shortcut? Shortcut[]
  function S:U(action, shortcut)
    return self:Update(action, shortcut)
  end

  ---shorthand alias of «delete Action»
  ---@param action string
  function S:D(action)
    self.actions[action] = nil
  end

  function S:isShortcutListOpen()
    return self.shortcutListOpen
  end

  function S:openShortcutList()
    self.shortcutListOpen = true
  end

  function S:DisplayRecordPopup()
    if self.openRecordPopup then
      self.openRecordPopup = false
      if not r.ImGui_IsPopupOpen(ctx, "Record Shortcut") then
        r.ImGui_OpenPopup(ctx, "Record Shortcut")
        if self.isRecordPopupOpen then
          self.isRecordPopupOpen = false
        end
      end
    elseif not r.ImGui_IsPopupOpen(ctx, "Record Shortcut") then
      if self.isRecordPopupOpen then
        self.isRecordPopupOpen = false
      end
    end
    local center = { r.ImGui_Viewport_GetCenter(r.ImGui_GetWindowViewport(ctx)) } ---window styling
    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
    r.ImGui_SetNextWindowSize(ctx, 270, 100)
    if r.ImGui_BeginPopupModal(ctx, "Record Shortcut", true, r.ImGui_WindowFlags_TopMost()) then ---begin popup
      if not self.isRecordPopupOpen then
        self.isRecordPopupOpen = true
      end
      if not ActionTaken then
        r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(), 0xFFFF)
        r.ImGui_InputText(ctx, "shortcut", "<<Type key>>", r.ImGui_InputTextFlags_ReadOnly())
        r.ImGui_PopStyleColor(ctx, 1)
        r.ImGui_Checkbox(ctx, "Automatically close on key input", true)
        ---I hate leaving globals behind, but this is a case where it's needed.
        HasPressed, ActionTaken = self:recordShortcut(self.recordedAction)
        if HasPressed and not ActionTaken then
          self.isRecordPopupOpen = false
          r.ImGui_CloseCurrentPopup(ctx)
        end
      else
        r.ImGui_Text(ctx, "Shortcut already taken by action: ")
        r.ImGui_Text(ctx, ActionTaken or "")

        r.ImGui_Text(ctx, "Do you want to replace the shortcut ?")
        if r.ImGui_Button(ctx, "Yes") then
          self:Update(self.recordedAction, self.actions[ActionTaken])
          self:Delete(ActionTaken)
          self.recordedAction    = nil
          self.isRecordPopupOpen = false
          ActionTaken            = nil
          HasPressed             = nil
          r.ImGui_CloseCurrentPopup(ctx)
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_Button(ctx, "Cancel") then
          self.recordedAction    = nil
          self.isRecordPopupOpen = false
          ActionTaken            = nil
          HasPressed             = nil
          r.ImGui_CloseCurrentPopup(ctx)
        end
      end

      r.ImGui_EndPopup(ctx)
    end
  end

  ---display ImGui window with list of shortcuts and their mappings
  function S:DisplayShortcutList()
    if self.shortcutListOpen then
      self.shortcutListOpen = false
      if not r.ImGui_IsPopupOpen(ctx, "Shortcut List") then
        r.ImGui_OpenPopup(ctx, "Shortcut List")
      end
    end
    local center = { r.ImGui_Viewport_GetCenter(r.ImGui_GetWindowViewport(ctx)) } ---window styling
    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
    r.ImGui_SetNextWindowSize(ctx, 400, 300)
    if r.ImGui_BeginPopupModal(ctx, "Shortcut List", true, r.ImGui_WindowFlags_TopMost()) then ---begin popup
      ---click/dblClick on shortcut: update
      ---ctrl+click: delete
      ---add indication as text
      r.ImGui_Text(ctx, "Click/double click on a shortcut to update it")
      r.ImGui_Text(ctx, "Ctrl+click on a shortcut to delete it")

      ---TABLE
      ---iterate every shortcut in the actions table
      ---display the action name
      ---display the shortcut
      if r.ImGui_BeginTable(ctx, "Shortcut List", 3, r.ImGui_TableFlags_RowBg()) then
        ---COLUMNS
        ---display the headers of the table
        r.ImGui_TableSetupColumn(ctx, "Shortcut")
        r.ImGui_TableSetupColumn(ctx, "Action")
        r.ImGui_TableSetupColumn(ctx, "Context")
        r.ImGui_TableHeadersRow(ctx)

        ---display rows
        for action, shortcut in pairs(self.actions) do
          r.ImGui_TableNextRow(ctx)
          ---Shortcut row
          r.ImGui_TableSetColumnIndex(ctx, 0)
          -- r.ImGui_Button(ctx, S:displayShortcut(shortcut), 0, 0)
          if r.ImGui_Selectable(ctx, helpers.displayShortcut(shortcut), false, r.ImGui_SelectableFlags_DontClosePopups()) then
            ---delete the shortcut if user held «ctrl» down while clicking
            if r.ImGui_IsKeyDown(ctx, helpers.AllAvailableKeys.Ctrl) then
              self:Delete(action)
            else
              self.openRecordPopup = true
              self.recordedAction = action
            end
          end
          ---Action row
          r.ImGui_TableSetColumnIndex(ctx, 1)
          r.ImGui_Text(ctx, action)
        end
        r.ImGui_EndTable(ctx)
        self:DisplayRecordPopup()
      end
      r.ImGui_EndPopup(ctx)
    end
  end

  return S:init()
end

return ShortcutManager
