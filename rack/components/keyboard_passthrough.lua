local keyboard_passthrough = {}

---@param ctx ImGui_Context
function keyboard_passthrough:init(ctx)
    self.ctx = ctx
    self.startTime = reaper.time_precise()
    return self
end

function keyboard_passthrough:loop()
    local keys = reaper.JS_VKeys_GetState(self.startTime - 0.03)
    for k = 1, #keys do
        if k ~= 0xD and keys:byte(k) ~= 0 then
            reaper.CF_SendActionShortcut(reaper.GetMainHwnd(), 0, k)
        end
    end

    if reaper.ImGui_IsKeyPressed(self.ctx, reaper.ImGui_Key_Enter()) then
        reaper.CF_SendActionShortcut(reaper.GetMainHwnd(), 0, 0xD)
    end
    if reaper.ImGui_IsKeyPressed(self.ctx, reaper.ImGui_Key_KeypadEnter()) then
        reaper.CF_SendActionShortcut(reaper.GetMainHwnd(), 0, 0x800D)
    end

    self.startTime = reaper.time_precise()
end

return keyboard_passthrough
