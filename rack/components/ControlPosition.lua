local fx_box_helpers = require("helpers.fx_box_helpers")


---Allow updating the positions of the control in the window
---@param ctx ImGui_Context
---@param label string
---@param obj {["x_prop"]: number, ["y_prop"]: number}
---@param x_prop string
---@param y_prop string
---@param max_x number
---@param max_y number
---@param keep_ratio? boolean
function ControlPosition(ctx, label, obj, x_prop, y_prop, max_x, max_y, keep_ratio)
    -- add two drags, one vertical and one horizontal
    -- to control the position in window
    reaper.ImGui_Text(ctx, label)
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_PushItemWidth(ctx, 100)
    local cursor_x, cursor_y = reaper.ImGui_GetCursorPos(ctx)
    -- add an invisible button that will allow the user to drag the control VERTICALLY.
    reaper.ImGui_Button(ctx, "drag me##" .. label, reaper.ImGui_CalcTextSize(ctx, label) + 10, 20)
    if reaper.ImGui_IsItemActive(ctx) then
        local delta_x, delta_y = reaper.ImGui_GetMouseDragDelta(ctx, cursor_x, cursor_y)
        if delta_x ~= 0.0 or delta_y ~= 0.0 then
            if delta_x ~= 0.0 then
                local new_x = fx_box_helpers.fitBetweenMinMax(obj[x_prop] + delta_x, 0, max_x)
                if keep_ratio then
                    local ratio = obj[x_prop] / obj[y_prop]
                    obj[y_prop] = (new_x * (ratio == ratio and ratio or 1)) // 1 | 0
                end
                obj[x_prop] = new_x
            end
            if delta_y ~= 0.0 then
                local new_y = fx_box_helpers.fitBetweenMinMax(obj[y_prop] + delta_y, 0, max_y)
                if keep_ratio then
                    local ratio = obj[y_prop] / obj[x_prop]
                    obj[x_prop] = (new_y * (ratio == ratio and ratio or 1)) // 1 | 0
                end
                obj[y_prop] = new_y
            end


            reaper.ImGui_ResetMouseDragDelta(ctx, reaper.ImGui_MouseButton_Left())
        end
    end
    if reaper.ImGui_IsItemHovered(ctx) then
        reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeAll())
    end
    reaper.ImGui_SameLine(ctx)
    reaper.ImGui_Text(ctx, "X: " .. obj[x_prop] .. ", Y: " .. obj[y_prop])
    reaper.ImGui_PopItemWidth(ctx)
    -- return changed, delta_x, delta_y
end

return ControlPosition
