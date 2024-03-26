---@class CycleButton
local CycleButton = {}

---Create a new CycleButton
---Currently not passing any styling options
---@param ctx ImGui_Context
---@param id string
---@param param ParamData
---@param on_activate? function
function CycleButton.new(ctx, id, param, on_activate)
    ---@class CycleButton
    local new_cycleButton = {}
    setmetatable(new_cycleButton, { __index = CycleButton })
    new_cycleButton._ctx = ctx
    new_cycleButton._id = id
    new_cycleButton._param = param
    new_cycleButton._on_activate = on_activate
    return new_cycleButton
end

---@param variant integer
---@param flags? integer
---@param param ParamData
---@return boolean changed, number new_value
function CycleButton:draw(variant, flags, param)
    self._param = param
    reaper.ImGui_SetCursorPos(self._ctx, self._param.details.display_settings.Pos_X,
        self._param.details.display_settings.Pos_Y)
    if reaper.ImGui_Button(self._ctx, self._param.details.fmt_val) then
        if self._on_activate then
            self._on_activate()
        end
        -- set value to next increment
        -- if current value is max value, set to 0
        local new_val = self._param.details.value + self._param.details.step
        if self._param.details.value == self._param.details.maxval then
            new_val = self._param.details.minval
        else
            new_val = self._param.details.value + self._param.details.step
        end
        return true, new_val
    end
    -- TODO display label for current value
    return false, self._param.details.value
end

return CycleButton
