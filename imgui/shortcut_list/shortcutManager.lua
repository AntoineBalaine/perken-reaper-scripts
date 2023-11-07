--[[
command id+name
hover: display shortcut?
api register an acion and its context: return  shortcut caller function

]]
---from FX constants
AllAvailableKeys = {
  ['0'] = reaper.ImGui_Key_0(),
  ['1'] = reaper.ImGui_Key_1(),
  ['2'] = reaper.ImGui_Key_2(),
  ['3'] = reaper.ImGui_Key_3(),
  ['4'] = reaper.ImGui_Key_4(),
  ['5'] = reaper.ImGui_Key_5(),
  ['6'] = reaper.ImGui_Key_6(),
  ['7'] = reaper.ImGui_Key_7(),
  ['8'] = reaper.ImGui_Key_8(),
  ['9'] = reaper.ImGui_Key_9(),
  A = reaper.ImGui_Key_A(),
  B = reaper.ImGui_Key_B(),
  C = reaper.ImGui_Key_C(),
  D = reaper.ImGui_Key_D(),
  E = reaper.ImGui_Key_E(),
  F = reaper.ImGui_Key_F(),
  G = reaper.ImGui_Key_G(),
  H = reaper.ImGui_Key_H(),
  I = reaper.ImGui_Key_I(),
  J = reaper.ImGui_Key_J(),
  K = reaper.ImGui_Key_K(),
  L = reaper.ImGui_Key_L(),
  M = reaper.ImGui_Key_M(),
  N = reaper.ImGui_Key_N(),
  O = reaper.ImGui_Key_O(),
  P = reaper.ImGui_Key_P(),
  Q = reaper.ImGui_Key_Q(),
  R = reaper.ImGui_Key_R(),
  S = reaper.ImGui_Key_S(),
  T = reaper.ImGui_Key_T(),
  U = reaper.ImGui_Key_U(),
  V = reaper.ImGui_Key_V(),
  W = reaper.ImGui_Key_W(),
  X = reaper.ImGui_Key_X(),
  Y = reaper.ImGui_Key_Y(),
  Z = reaper.ImGui_Key_Z(),
  Esc = reaper.ImGui_Key_Escape(),
  F1 = reaper.ImGui_Key_F1(),
  F2 = reaper.ImGui_Key_F2(),
  F3 = reaper.ImGui_Key_F3(),
  F4 = reaper.ImGui_Key_F4(),
  F5 = reaper.ImGui_Key_F5(),
  F6 = reaper.ImGui_Key_F6(),
  F7 = reaper.ImGui_Key_F7(),
  F8 = reaper.ImGui_Key_F8(),
  F9 = reaper.ImGui_Key_F9(),
  F10 = reaper.ImGui_Key_F10(),
  F11 = reaper.ImGui_Key_F11(),
  F12 = reaper.ImGui_Key_F12(),
  Apostrophe = reaper.ImGui_Key_Apostrophe(),
  Backslash = reaper.ImGui_Key_Backslash(),
  Backspace = reaper.ImGui_Key_Backspace(),
  Comma = reaper.ImGui_Key_Comma(),
  Delete = reaper.ImGui_Key_Delete(),
  DownArrow = reaper.ImGui_Key_DownArrow(),
  Enter = reaper.ImGui_Key_Enter(),
  End = reaper.ImGui_Key_End(),
  Equal = reaper.ImGui_Key_Equal(),
  GraveAccent = reaper.ImGui_Key_GraveAccent(),
  Home = reaper.ImGui_Key_Home(),
  ScrollLock = reaper.ImGui_Key_ScrollLock(),
  Insert = reaper.ImGui_Key_Insert(),
  Minus = reaper.ImGui_Key_Minus(),
  LeftArrow = reaper.ImGui_Key_LeftArrow(),
  LeftBracket = reaper.ImGui_Key_LeftBracket(),
  Period = reaper.ImGui_Key_Period(),
  PageDown = reaper.ImGui_Key_PageDown(),
  PageUp = reaper.ImGui_Key_PageUp(),
  Pause = reaper.ImGui_Key_Pause(),
  RightBracket = reaper.ImGui_Key_RightBracket(),
  RightArrow = reaper.ImGui_Key_RightArrow(),
  SemiColon = reaper.ImGui_Key_Semicolon(),
  Slash = reaper.ImGui_Key_Slash(),
  Space = reaper.ImGui_Key_Space(),
  Tab = reaper.ImGui_Key_Tab(),
  UpArrow = reaper.ImGui_Key_UpArrow(),
  Pad0 = reaper.ImGui_Key_Keypad0(),
  Pad1 = reaper.ImGui_Key_Keypad1(),
  Pad2 = reaper.ImGui_Key_Keypad2(),
  Pad3 = reaper.ImGui_Key_Keypad3(),
  Pad4 = reaper.ImGui_Key_Keypad4(),
  Pad5 = reaper.ImGui_Key_Keypad5(),
  Pad6 = reaper.ImGui_Key_Keypad6(),
  Pad7 = reaper.ImGui_Key_Keypad7(),
  Pad8 = reaper.ImGui_Key_Keypad8(),
  Pad9 = reaper.ImGui_Key_Keypad9(),
  PadAdd = reaper.ImGui_Key_KeypadAdd(),
  PadDecimal = reaper.ImGui_Key_KeypadDecimal(),
  PadDivide = reaper.ImGui_Key_KeypadDivide(),
  PadEnter = reaper.ImGui_Key_KeypadEnter(),
  PadEqual = reaper.ImGui_Key_KeypadEqual(),
  PadMultiply = reaper.ImGui_Key_KeypadMultiply(),
  PadSubtract = reaper.ImGui_Key_KeypadSubtract(),
}


---@alias ActionName unknown

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

TODO create shorthand aliases for crud functions

TODO include modifier keys
]]
---@param ctx ImGui_Context
---@param actions_list? ActionName[] list of actions for which to create shortcuts
---@param config_path? string path to config file that contains pre-recorded shortcuts
local function ShortcutManager(ctx, actions_list, config_path)
  local S = {}
  ---@alias Shortcut {string: boolean|nil}
  ---@type table<string, Shortcut[]>
  S.actions = {}
  S.shortcutListOpen = false
  S.openRecordPopup = false
  S.recordActionShortcut = nil
  S.isRecordPopupOpen = false
  function S:init()
    if actions_list ~= nil and actions_list[1] == "quit" then
      self:Create("quit", { [reaper.ImGui_Key_Escape() .. ""] = true })
    end
    ---TODO fix this
    --[[     for i, action in ipairs(actions_list) do
      self:Create(action)
    end ]]
    return self
  end

  --- Upon hitting key in the keyboard, record the shortcut.
  --- Check all the keys in AllAvailableKeys.
  --- Whichever ones have been hit, add them to the shortcut.
  ---TODO check that the shortcut doesn't already exist
  ---TODO show a confirmation message before including in the table/writing to config file
  ---@param action string
  function S:recordShortcut(action)
    local alreadyTaken = false
    local keysPressed = self:getKeysPressed()
    local hasPressed = false
    -- if keysPressed[reaper.ImGui_Key_Escape() .. ""] then
    if keysPressed[reaper.ImGui_Key_A() .. ""] then
      self.openRecordPopup = false
      self.recordActionShortcut = nil
      return true, false
    end
    for keyCode, val in pairs(keysPressed) do
      if not hasPressed then
        hasPressed = true
      end
      --[[       if self.actions[action] == nil then
        self.actions[action] = {}
      end ]]
      self.actions[action] = {}
      table.insert(self.actions[action], { [keyCode] = val })
    end
    return hasPressed, alreadyTaken
  end

  ---check all the keys that have been pressed
  ---@return Shortcut keys_pressed array of key codes, each at the index of the code, i.e. key code 1 is at index 1, key code 2 is at index 2, etc.
  function S:getKeysPressed()
    local keysPressed = {} ---@type Shortcut
    for keyName, keyCode in pairs(AllAvailableKeys) do
      if reaper.ImGui_IsKeyPressed(ctx, keyCode) then
        keysPressed[keyCode .. ""] = true
      end
    end
    return keysPressed
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
    if next(keysPressed) == nil or next(shortcut) == nil then return false end
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
    self.actions[action] = shortcut
  end

  ---update Action
  ---TODO is this really useful?
  ---@param action string
  ---@param shortcut? Shortcut[]
  function S:Update(action, shortcut)
    -- update an entry in the in the actions table with value nil.
    self.actions[action] = shortcut
  end

  ---delete Action
  ---@param action string
  function S:Delete(action)
    self.actions[action] = nil
  end

  function S:isShortcutListOpen()
    return self.shortcutListOpen
  end

  ---format shortcut for display in table
  ---@param shortcut Shortcut
  ---@return string
  function S:displayShortcut(shortcut)
    local rv = ""
    local idx = 0
    for keyCode, _ in pairs(shortcut) do
      if idx > 0 then rv = rv .. " + " end
      idx = idx + 1
      local key = ""
      -- find k in all availablekeys, use the key
      for availkey, availKeyCode in pairs(AllAvailableKeys) do
        if keyCode == availKeyCode .. "" then key = availkey end
      end
      rv = rv .. key ~= "" and key or keyCode
    end
    return rv
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
    if r.ImGui_BeginPopupModal(ctx, "Record Shortcut", true, r.ImGui_WindowFlags_TopMost() |  r.ImGui_WindowFlags_NoResize()) then ---begin popup
      if not self.isRecordPopupOpen then
        self.isRecordPopupOpen = true
      end
      r.ImGui_PushStyleColor(ctx, r.ImGui_Col_FrameBg(), 0xFFFF)
      r.ImGui_InputText(ctx, "shortcut", "<<Type key>>", r.ImGui_InputTextFlags_ReadOnly())
      r.ImGui_PopStyleColor(ctx, 1)
      r.ImGui_Checkbox(ctx, "Automatically close on key input", true)
      local hasPressed, alreadyTaken = self:recordShortcut(self.recordActionShortcut)
      if hasPressed then
        self.isRecordPopupOpen = false
        r.ImGui_CloseCurrentPopup(ctx)
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
    if r.ImGui_BeginPopupModal(ctx, "Shortcut List", true, r.ImGui_WindowFlags_TopMost() |  r.ImGui_WindowFlags_NoResize()) then ---begin popup
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
          if r.ImGui_Selectable(ctx, self:displayShortcut(shortcut), false, r.ImGui_SelectableFlags_DontClosePopups()) then
            self.openRecordPopup = true
            self.recordActionShortcut = action
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
