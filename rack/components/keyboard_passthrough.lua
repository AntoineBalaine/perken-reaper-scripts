--[[
Pass through module to handle passing shortcuts from the rack to reaper.

This has been adapted from js_ReaScriptAPI's implementation, which can be found at
https://github.com/juliansader/js_ReaScriptAPI/blob/52b2f2c6eae11437acabbd7a1e6017820cfb6ee3/js_ReaScriptAPI.cpp#L520

```lua
 local PassThrough = require 'keyboard_passthrough'
 PassThrough:init():loop()
```

]]
local keyboard_passthrough = {}

---@param ctx ImGui_Context
function keyboard_passthrough:init(ctx)
    self._ctx = ctx
    self._startTime = reaper.time_precise()
    self.cur_pref = reaper.SNM_GetIntConfigVar("alwaysallowkb", 1)
    reaper.SNM_SetIntConfigVar("alwaysallowkb", 1)
    return self
end

function keyboard_passthrough:onClose()
    reaper.SNM_SetIntConfigVar("alwaysallowkb", self.cur_pref)
end

function keyboard_passthrough:run()
    -- don't run the shortcuts if the window is not focused
    -- I can’t seem to get this to work: this should trigger from any child window
    if not reaper.ImGui_IsWindowFocused(self._ctx, reaper.ImGui_FocusedFlags_AnyWindow()) or reaper.ImGui_IsAnyItemActive(self._ctx) then
        return
    end
    local keys = reaper.JS_VKeys_GetState(self._startTime - 0.03)
    for k = 1, #keys do
        if k ~= 0xD and keys:byte(k) ~= 0 then
            reaper.CF_SendActionShortcut(reaper.GetMainHwnd(), 0, k)
        end
    end

    if reaper.ImGui_IsKeyPressed(self._ctx, reaper.ImGui_Key_Enter()) then
        reaper.CF_SendActionShortcut(reaper.GetMainHwnd(), 0, 0xD)
    end
    if reaper.ImGui_IsKeyPressed(self._ctx, reaper.ImGui_Key_KeypadEnter()) then
        reaper.CF_SendActionShortcut(reaper.GetMainHwnd(), 0, 0x800D)
    end

    self._startTime = reaper.time_precise()
end

return keyboard_passthrough
