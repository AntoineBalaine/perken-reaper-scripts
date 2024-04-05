local fx_box_helpers = require("helpers.fx_box_helpers")


---Allow updating the positions of the control in the window
---@param ctx ImGui_Context
---@param label string
---@param obj {Pos_X: number, Pos_Y: number}
---@param max_x number
---@param max_y number
function ControlPosition(ctx, label, obj, max_x, max_y)
    -- add two drags, one vertical and one horizontal
    -- to control the position in window
    reaper.ImGui_Text(ctx, "Control Position:")
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_PushItemWidth(ctx, 100)
    local cursor_x, cursor_y = reaper.ImGui_GetCursorPos(ctx)
    -- add an invisible button that will allow the user to drag the control VERTICALLY.
    reaper.ImGui_Button(ctx, label, reaper.ImGui_CalcTextSize(ctx, label) + 10, 20)
    if reaper.ImGui_IsItemActive(ctx) then
        local delta_x, delta_y = reaper.ImGui_GetMouseDragDelta(ctx, cursor_x, cursor_y)
        if delta_x ~= 0.0 or delta_y ~= 0.0 then
            if delta_y ~= 0.0 then
                obj.Pos_Y = fx_box_helpers.fitBetweenMinMax(obj.Pos_Y + delta_y, 0, max_x)
            end
            if delta_x ~= 0.0 then
                obj.Pos_X = fx_box_helpers.fitBetweenMinMax(
                    obj.Pos_X + delta_x,
                    0,
                    max_y)
            end

            reaper.ImGui_ResetMouseDragDelta(ctx, reaper.ImGui_MouseButton_Left())
        end
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeNWSE())
    end
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Text(ctx, "X: " .. obj.Pos_X .. ", Y: " .. obj.Pos_Y)
    reaper.ImGui_PopItemWidth(ctx)
    -- return changed, delta_x, delta_y
end

return ControlPosition
