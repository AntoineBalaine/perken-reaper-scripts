--[[
command id+name
hover: display shortcut?
api register an acion and its context: return  shortcut caller function

  TODO keymap
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

---@param ctx ImGui_Context
---@param actions_list ActionName[]
---@param config_path? string
local function ShortcutManager(ctx, actions_list, config_path)
  local S = {}
  ---@alias Shortcut {string: boolean|nil}
  ---@type table<string, Shortcut[]>
  S.actions = {}
  function S:init()
    if actions_list[1] == "quit" then
      self:Create("quit", { [reaper.ImGui_Key_Escape() .. ""] = true })
    end
    --[[     for i, action in ipairs(actions_list) do
      self:Create(action)
    end ]]
    return self
  end

  --- Upon hitting key in the keyboard, record the shortcut.
  --- Check all the keys in AllAvailableKeys.
  --- Whichever ones have been hit, add them to the shortcut.
  ---TODO show a confirm message before including in the table/writing to config file
  ---@param action string
  function S:recordShortcut(action)
    for i, shortCut in ipairs(self:getKeysPressed()) do
      table.insert(S.actions[action], shortCut)
    end
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

  ---display ImGui window with list of shortcuts and their mappings
  function S:displayShortcutList()
    --[[     if not r.ImGui_IsPopupOpen(ctx, "Shortcut List") then
      r.ImGui_OpenPopup(ctx, "Shortcut List")
    end
    local center = { r.ImGui_Viewport_GetCenter(r.ImGui_GetWindowViewport(ctx)) }
    r.ImGui_SetNextWindowPos(ctx, center[1], center[2], r.ImGui_Cond_Appearing(), 0.5, 0.5)
    r.ImGui_SetNextWindowSizeConstraints(ctx, 400, 300, 400, 300)
    if r.ImGui_BeginPopupModal(ctx, "Shortcut List", true, r.ImGui_WindowFlags_TopMost() |  r.ImGui_WindowFlags_NoResize()) then
      r.ImGui_EndPopup(ctx)
    end
    r.ImGui_End(ctx) ]]
  end

  function S:lookUp(action)
    return self.actions[action] or { nil }
  end

  ---Read shortcut: check if shortcut was pressed for the action
  ---@param action string
  ---@return boolean
  function S:Read(action)
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

  return S:init()
end

return ShortcutManager
