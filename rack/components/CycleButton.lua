local text_helpers = require("helpers.text")
local layoutEnums = require("state.layout_enums")
local EditControl = require("components.EditControl")

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

---@return boolean changed, number new_value
function CycleButton:draw()
    local no_title                               = self._param.details.display_settings.flags &
        layoutEnums.KnobFlags.NoTitle ==
        layoutEnums.KnobFlags.NoTitle
    local no_input                               = self._param.details.display_settings.flags &
        layoutEnums.KnobFlags.NoInput ==
        layoutEnums.KnobFlags.NoInput
    -- no_value is un-used by CycleButton
    -- local no_value = self._param.details.display_settings.flags &
    --     layoutEnums.KnobFlags.NoValue ==
    --     layoutEnums.KnobFlags.NoValue
    local fxbox_pos_x, fxbox_pos_y               = reaper.ImGui_GetCursorPos(self._ctx)
    local fxbox_max_x, fx_box_max_y              = reaper.ImGui_GetWindowContentRegionMax(self._ctx)
    local fx_box_min_x, fx_box_min_y             = reaper.ImGui_GetWindowContentRegionMin(self._ctx)
    local fxbox_screen_pos_x, fxbox_screen_pos_y = reaper.ImGui_GetWindowPos(self._ctx)

    if self._param.details.display_settings.Pos_X and self._param.details.display_settings.Pos_Y then
        reaper.ImGui_SetCursorPos(self._ctx, self._param.details.display_settings.Pos_X,
            self._param.details.display_settings.Pos_Y)
    end

    -- If there’s no title or value (such as for the dry/wet knob), the knob’s frame is shrunk to the minimum size
    self._child_width  = self._param.details.display_settings.width * 2 * 2
    self._child_height = self._param.details.display_settings.height * 1.5 + (no_title and 0 or 20) +
        reaper.ImGui_GetTextLineHeightWithSpacing(self._ctx) * (no_title and 0 or 1)
    -- self._child_height = reaper.ImGui_GetTextLineHeightWithSpacing(self._ctx) * 4
    local changed      = false
    local new_val      = self._param.details.value
    if reaper.ImGui_BeginChild(self._ctx, "##CycleButton" .. self._param.guid, self._child_width, self._child_height, false) then
        if self._param.details.parent_fx.editing then
            reaper.ImGui_BeginDisabled(self._ctx, true)
        end

        if not no_title then
            text_helpers.centerText(self._ctx, self._param.name, self._child_width, 2)
        end

        -- if this logic comes reproduced again, let’s make into a component.
        if self._param.details.istoggle then
            local bg_col ---@type number
            if self._param.details.value > self._param.details.minval then
                bg_col = self._param.details.parent_fx.displaySettings.labelButtonStyle.background
            else
                bg_col = self._param.details.parent_fx.displaySettings.labelButtonStyle.background_disabled
            end
            reaper.ImGui_PushStyleColor(self._ctx, reaper.ImGui_Col_Button(), bg_col)
            reaper.ImGui_PushStyleColor(self._ctx, reaper.ImGui_Col_ButtonHovered(), bg_col)
            reaper.ImGui_PushStyleColor(self._ctx, reaper.ImGui_Col_ButtonActive(), bg_col)
        end

        -- reaper.ImGui_Col_ButtonHovered()
        -- reaper.ImGui_Col_ButtonActive()
        if self._param.details.parent_fx.editing and no_title then
            local win_pos_x, win_pos_y = reaper.ImGui_GetWindowPos(self._ctx)
            local pos_x, pos_y = reaper.ImGui_GetCursorPos(self._ctx)
            local button_color = reaper.ImGui_GetColor(self._ctx, reaper.ImGui_Col_FrameBg())
            reaper.ImGui_DrawList_AddRectFilled(reaper.ImGui_GetWindowDrawList(self._ctx),
                win_pos_x + pos_x,
                win_pos_y + pos_y,
                win_pos_x + pos_x + self._child_width,
                win_pos_y + pos_y + reaper.ImGui_GetTextLineHeightWithSpacing(self._ctx) * 2 +
                reaper.ImGui_GetStyleVar(self._ctx, reaper.ImGui_StyleVar_FramePadding()),
                button_color)
            reaper.ImGui_SetCursorPosX(self._ctx, pos_x)
            reaper.ImGui_SetCursorPosY(self._ctx, pos_y)
            text_helpers.centerText(self._ctx, self._param.details.fmt_val, self._child_width, 2)
        elseif reaper.ImGui_Button(self._ctx,
                self._param.details.fmt_val,
                self._child_width - reaper.ImGui_GetStyleVar(self._ctx,
                    reaper.ImGui_StyleVar_WindowPadding()))
            and not self._param.details.parent_fx.editing and not no_input then
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
        if self._param.details.istoggle then
            reaper.ImGui_PopStyleColor(self._ctx, 3)
        end
        if self._param.details.parent_fx.editing then
            reaper.ImGui_EndDisabled(self._ctx)
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
                self._param.details.display_settings.width
            )

            if size_changed then
                self._param.details.display_settings.width = new_radius
            end
        end
        reaper.ImGui_EndChild(self._ctx)
    end
    return changed, new_val
end

return CycleButton
