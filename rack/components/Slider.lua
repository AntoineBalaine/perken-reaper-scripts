local text_helpers = require("helpers.text")
local EditControl = require("components.EditControl")

---@class Slider
local Slider = {}

---Create a new Slider
---Currently not passing any styling options
---@param ctx ImGui_Context
---@param id string
---@param param ParamData
---@param on_activate? function
---@param radius number
function Slider.new(ctx, id, param, on_activate, radius)
    ---@class Slider
    local new_Slider = {}
    setmetatable(new_Slider, { __index = Slider })
    new_Slider._ctx = ctx
    new_Slider._id = id
    new_Slider._param = param
    new_Slider._on_activate = on_activate
    ---re-using the radius measurement from the Knob here
    new_Slider._radius = radius
    return new_Slider
end

---@param variant integer
---@param flags? integer
---@param param ParamData
---@return boolean changed, number new_value
function Slider:draw(variant, flags)
    local fxbox_pos_x, fxbox_pos_y               = reaper.ImGui_GetCursorPos(self._ctx)
    local fxbox_max_x, fx_box_max_y              = reaper.ImGui_GetWindowContentRegionMax(self._ctx)
    local fx_box_min_x, fx_box_min_y             = reaper.ImGui_GetWindowContentRegionMin(self._ctx)
    local fxbox_screen_pos_x, fxbox_screen_pos_y = reaper.ImGui_GetWindowPos(self._ctx)

    if self._param.details.display_settings.Pos_X and self._param.details.display_settings.Pos_Y then
        reaper.ImGui_SetCursorPos(self._ctx, self._param.details.display_settings.Pos_X,
            self._param.details.display_settings.Pos_Y)
    end

    self._child_width  = self._radius * 2 * 1.5
    self._child_height = reaper.ImGui_GetTextLineHeightWithSpacing(self._ctx) * 4
    local changed      = false
    local new_val      = self._param.details.value
    if reaper.ImGui_BeginChild(self._ctx, "##Slider" .. self._param.guid, self._child_width, self._child_height, false) then
        if self._param.details.parent_fx.editing then
            reaper.ImGui_BeginDisabled(self._ctx, true)
        end
        text_helpers.centerText(self._ctx, self._param.name, self._child_width, 2)
        reaper.ImGui_PushItemWidth(self._ctx, self._child_width - reaper.ImGui_GetStyleVar(self._ctx,
            reaper.ImGui_StyleVar_WindowPadding()))
        --- If there's only 10 steps, use a stepped slider
        if self._param.details.steps_count then
            -- use a stepped slider, using integer values
            local int_val = (self._param.details.value / self._param.details.step) // 1 |0
            changed, int_val = reaper.ImGui_SliderInt(self._ctx,
                "##slider" .. self._param.guid,
                int_val,
                (self._param.details.minval / self._param.details.step) // 1 | 0,
                (self._param.details.maxval / self._param.details.step) // 1 | 0,
                self._param.details.fmt_val
            )
            if changed then
                new_val = int_val * self._param.details.step
            end
        else
            changed, new_val = reaper.ImGui_SliderDouble(self._ctx,
                "##slider" .. self._param.guid,
                self._param.details.value,
                self._param.details.minval,
                self._param.details.maxval,
                self._param.details.fmt_val)
        end

        if self._param.details.parent_fx.editing then
            reaper.ImGui_EndDisabled(self._ctx)
        end
        if changed and not self._param.details.parent_fx.editing then
            if self._on_activate then
                self._on_activate()
            end
        end


        if self._param.details.parent_fx.editing then
            local size_changed, new_radius = EditControl(
                self._ctx,
                self._param,
                fxbox_pos_x,
                fxbox_pos_y,
                fxbox_max_x,
                fx_box_max_y,
                fx_box_min_x,
                fx_box_min_y,
                fxbox_screen_pos_x,
                fxbox_screen_pos_y,
                self._radius
            )

            if size_changed then
                self._radius = new_radius
            end
        end
        reaper.ImGui_EndChild(self._ctx)
    end
    return not self._param.details.parent_fx.editing and changed, new_val
end

return Slider
