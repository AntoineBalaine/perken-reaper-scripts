local helpers = {}
---from FX constants
helpers.AllAvailableKeys = {
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
  Ctrl = reaper.ImGui_Mod_Ctrl(),
  Shift = reaper.ImGui_Mod_Shift(),
  Alt = reaper.ImGui_Mod_Alt(),
  Super = reaper.ImGui_Mod_Super(),
}

---return true if shortcuts are same
---@param shortcutA Shortcut
---@param shortcutB Shortcut
function helpers.compareShortcuts(shortcutA, shortcutB)
  if shortcutA == nil or shortcutB == nil then
    return false
  else
    local hasKeys = false
    for keyCode, val in pairs(shortcutA) do
      if not hasKeys then hasKeys = true end
      if shortcutB[keyCode] == nil then
        return false
      end
    end
    for keyCode, val in pairs(shortcutB) do
      if shortcutA[keyCode] == nil then
        return false
      end
    end
    return hasKeys
  end
end

---check that a keyCode is a modifier key
---@param keyCode integer|string
---@return boolean
function helpers.isModifier(keyCode)
  keyCode = keyCode .. ""
  return keyCode == helpers.AllAvailableKeys.Ctrl .. ""
      or keyCode == helpers.AllAvailableKeys.Shift .. ""
      or keyCode == helpers.AllAvailableKeys.Alt .. ""
      or keyCode == helpers.AllAvailableKeys.Super .. ""
end

---check that current shortcut is only modifier keys
---@param shortcut Shortcut
---@return boolean
function helpers.onlyModKeys(shortcut)
  ---iterate through the shortcut and see if there are any non-modifier keys in it
  for keyCode, _ in pairs(shortcut) do
    if not helpers.isModifier(keyCode) then
      return false
    end
  end
  return true
end

---format shortcut for display in shortcuts list
---@param shortcut Shortcut
---@return string
function helpers.displayShortcut(shortcut)
  local rv = ""
  local idx = 0
  for keyCode, _ in pairs(shortcut) do
    if idx > 0 then rv = rv .. " + " end
    idx = idx + 1
    local key = ""
    -- find k in all availablekeys, use the key
    for availkey, availKeyCode in pairs(helpers.AllAvailableKeys) do
      if keyCode == availKeyCode .. "" then key = availkey end
    end
    rv = rv .. (key ~= "" and key or keyCode)
  end
  return rv
end

---@alias ActionName unknown

return helpers
