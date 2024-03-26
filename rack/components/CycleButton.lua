local text_helpers = require("helpers.text")

---@class CycleButton
local CycleButton = {}

---Create a new CycleButton
---Currently not passing any styling options
---@param ctx ImGui_Context
---@param id string
---@param param ParamData
---@param on_activate? function
---@param radius number
function CycleButton.new(ctx, id, param, on_activate, radius)
    ---@class CycleButton
    local new_cycleButton = {}
    setmetatable(new_cycleButton, { __index = CycleButton })
    new_cycleButton._ctx = ctx
    new_cycleButton._id = id
    new_cycleButton._param = param
    new_cycleButton._on_activate = on_activate
    ---re-using the radius measurement from the Knob here
    new_cycleButton._radius = radius
    return new_cycleButton
end

---@param variant integer
---@param flags? integer
---@param param ParamData
---@return boolean changed, number new_value
function CycleButton:draw(variant, flags, param)
    self._param = param
    if self._param.details.display_settings.Pos_X and self._param.details.display_settings.Pos_Y then
        reaper.ImGui_SetCursorPos(self._ctx, self._param.details.display_settings.Pos_X,
            self._param.details.display_settings.Pos_Y)
    end

    self._child_width  = self._radius * 2 * 1.5
    self._child_height = 20 + self._radius * reaper.ImGui_GetTextLineHeightWithSpacing(self._ctx) * 2
    local changed      = false
    local new_val      = self._param.details.value
    if reaper.ImGui_BeginChild(self._ctx, "##CycleButton" .. self._param.guid, self._child_width, self._child_height, false) then
        if reaper.ImGui_Button(self._ctx, self._param.details.fmt_val, self._child_width - reaper.ImGui_GetStyleVar(self._ctx, reaper.ImGui_StyleVar_WindowPadding())) then
            if self._on_activate then
                self._on_activate()
            end
            -- set value to next increment
            -- if current value is max value, set to 0
            new_val = self._param.details.value + self._param.details.step
            if new_val > self._param.details.maxval then
                new_val = self._param.details.minval
            end

            changed = true
        end
        text_helpers.centerText(self._ctx, self._param.name, self._child_width, 2)
        reaper.ImGui_EndChild(self._ctx)
    end
    return changed, new_val
end

return CycleButton
