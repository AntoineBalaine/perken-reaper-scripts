dofile("/home/antoine/Documents/Experiments/lua/debug_connect.lua")
---PassThrough module to handle passthrough of shortcuts
--
-- This is meant to be a singleton, so it has no constructor.
-- Instead, it is initialized with the `init` method.
---```lua
-- local PassThrough = require 'passthrough'
-- PassThrough:init():runShortcuts()
--```
---I might want to implement the option of defining custom shortcuts in the future.

local AllAvailableKeys = {
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
    Left = reaper.ImGui_Key_LeftArrow(),
    LeftBracket = reaper.ImGui_Key_LeftBracket(),
    Period = reaper.ImGui_Key_Period(),
    PGDOWN = reaper.ImGui_Key_PageDown(),
    PGUP = reaper.ImGui_Key_PageUp(),
    Pause = reaper.ImGui_Key_Pause(),
    RightBracket = reaper.ImGui_Key_RightBracket(),
    Right = reaper.ImGui_Key_RightArrow(),
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



local my_shortcuts = {
    ['Ctrl+Shift+X'] = function() print('Another one!') end,
    ['Ctrl+Shift+C'] = function() print('And another one!') end
}

local function initImGuiKeys()
    local rv = {} ---@type string[]
    for k, v in pairs(AllAvailableKeys) do
        rv[v] = k
    end
    return rv
end

local Keys = initImGuiKeys()

---PassThrough module to handle passthrough of shortcuts
---This is meant to be a singleton, so it has no constructor.
---Instead, it is initialized with the `init` method.
---@class PassThrough
local PassThrough = {}

---@param ctx? ImGui_Context
function PassThrough:init(ctx)
    ---@class PassThrough
    if not ctx then
        self._ctx = reaper.ImGui_CreateContext('ImGui')
    else
        self._ctx = ctx
    end
    self._clickedModifiers = {} ---@type string[]

    return self
end

function PassThrough:_getImGuiShortcut()
    local ctrl = false
    local shift = false
    local alt = false
    local hits ---@type string

    for keyname, keycode in pairs(AllAvailableKeys) do
        if reaper.ImGui_IsKeyDown(self._ctx, keycode) then
            if keyname == "Ctrl" then
                ctrl = true
            elseif keyname == "Shift" then
                shift = true
            elseif keyname == "Alt" then
                alt = true
            else
                hits = keyname
            end
        end
    end
    if not hits then return end
    -- assume that clicked modifiers is empty now
    if ctrl then table.insert(self._clickedModifiers, "Ctrl") end
    if shift then table.insert(self._clickedModifiers, "Shift") end
    if alt then table.insert(self._clickedModifiers, "Alt") end
    local modif_rv = table.concat(self._clickedModifiers, "+")
    local rv = modif_rv .. (modif_rv ~= "" and "+" or "") .. hits
    -- empty the modifiers after use
    local count = #self._clickedModifiers
    for i = 0, count do self._clickedModifiers[i] = nil end
    return rv
end

function GetCommandByShortcut(section_id, shortcut)
    -- Check REAPER version
    local version = tonumber(reaper.GetAppVersion():match('[%d.]+'))
    if version < 6.71 then return end
    -- On MacOS, replace Ctrl with Cmd etc.
    local is_macos = reaper.GetOS():match('OS')
    if is_macos then
        shortcut = shortcut:gsub('Ctrl%+', 'Cmd+', 1)
        shortcut = shortcut:gsub('Alt%+', 'Opt+', 1)
    end
    -- Go through all actions of the section
    local sec = reaper.SectionFromUniqueID(section_id)
    local i = 0
    repeat
        local cmd = reaper.kbd_enumerateActions(sec, i)
        if cmd ~= 0 then
            -- Go through all shortcuts of each action
            local shortcut_count = reaper.CountActionShortcuts(sec, cmd) - 1
            for shortcut_idx = 0, shortcut_count do
                -- Find the action that matches the given shortcut
                local _, desc = reaper.GetActionShortcutDesc(sec, cmd, shortcut_idx)
                if desc == shortcut then return cmd, shortcut_idx end
            end
        end
        i = i + 1
    until cmd == 0
end

function PassThrough:runShortcuts()
    local _, _, section_id = reaper.get_action_context()
    -- Handle received characters
    local shortcut = self:_getImGuiShortcut()
    if shortcut == nil then return end
    if shortcut == 'Ctrl+Alt+C' then
        -- Check whether it's a custom shortcut for your own script
        print('My custom script shortcut!')
    elseif my_shortcuts[shortcut] then
        -- Alternative: If you have a lot of custom shortcuts, it might
        -- be a good idea to put functions in a table instead
        my_shortcuts[shortcut]()
    else
        -- Check if script is executed through MIDI editor section
        if section_id == 32060 then
            -- Passthrough unused shortcut to MIDI editor
            local hwnd = reaper.MIDIEditor_GetActive()
            if hwnd then
                local cmd = GetCommandByShortcut(section_id, shortcut)
                if cmd then
                    reaper.MIDIEditor_OnCommand(hwnd, cmd)
                end
            end
        else
            -- Passthrough unused shortcut to main window
            local cmd = GetCommandByShortcut(0, shortcut)
            if cmd then reaper.Main_OnCommand(cmd, 0) end
        end
    end
end

return PassThrough
