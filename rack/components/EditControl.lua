local edit_frame_color = 0xFF0000FF

---Overlay a button on top of the knob's frame
--- and retrieve whether the user is doing click+drag.
--- If so, update the knob frame's coordinates.
---
--It's easy to get confused, because this button's coordinates within the frame
--are not the same as the coordinates of the knob's frame within the fx box.
--That's why we're having to pass the details of the fx box as params.
---@param ctx ImGui_Context
---@param param ParamData
---@param fxbox_pos_x number
---@param fxbox_pos_y number
---@param fxbox_max_x number
---@param fx_box_max_y number
---@param fx_box_min_x number
---@param fx_box_min_y number
---@param radius? number
---@param width? integer
---@param height? integer
function EditControl(
    ctx,
    param,
    fxbox_pos_x,
    fxbox_pos_y,
    fxbox_max_x,
    fx_box_max_y,
    fx_box_min_x,
    fx_box_min_y,
    fxbox_screen_pos_x,
    fxbox_screen_pos_y,
    radius,
    width,
    height
)
    local new_radius, new_width, new_height = radius, width, height

    local changed                           = false

    local _child_width, _child_height       = reaper.ImGui_GetWindowSize(ctx)
    -- put knob at start of the current child window
    reaper.ImGui_SetCursorPosX(ctx, 0)
    reaper.ImGui_SetCursorPosY(ctx, 0)

    if param._selected then
        -- reaper.ImGui_DrawList_AddRectFilled(self._draw_list, draw_cursor_x, draw_cursor_y,
        --     draw_cursor_x + self._child_width,
        --     draw_cursor_y + child_height, 0xFFFFFFAA)
        reaper.ImGui_DrawList_AddRect(reaper.ImGui_GetWindowDrawList(ctx),
            fxbox_screen_pos_x + (param.details.display_settings.Pos_X or fxbox_pos_x),
            fxbox_screen_pos_y + (param.details.display_settings.Pos_Y or fxbox_pos_y),
            fxbox_screen_pos_x + (param.details.display_settings.Pos_X or fxbox_pos_x) + _child_width,
            fxbox_screen_pos_y + (param.details.display_settings.Pos_Y or fxbox_pos_y) + _child_height,
            edit_frame_color,
            1.0,
            0,
            0.0)
    else
        reaper.ImGui_DrawList_AddRect(reaper.ImGui_GetWindowDrawList(ctx),
            fxbox_screen_pos_x + (param.details.display_settings.Pos_X or fxbox_pos_x),
            fxbox_screen_pos_y + (param.details.display_settings.Pos_Y or fxbox_pos_y),
            fxbox_screen_pos_x + (param.details.display_settings.Pos_X or fxbox_pos_x) + _child_width,
            fxbox_screen_pos_y + (param.details.display_settings.Pos_Y or fxbox_pos_y) + _child_height,
            edit_frame_color & 0x55,
            1.0,
            0,
            0.0)
    end



    local win_padding = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding())
    reaper.ImGui_InvisibleButton(ctx, "##EditControl" .. param.details.guid, _child_width - win_padding - 4,
        _child_height - win_padding - 4) -- make it shorter on the y-axis to leave room for the resize button

    if reaper.ImGui_IsItemActive(ctx) then
        if param.details.parent_fx.setSelectedParam then
            param.details.parent_fx.setSelectedParam(param)
        end
        local delta_x, delta_y = reaper.ImGui_GetMouseDragDelta(
            ctx,
            param.details.display_settings.Pos_X or fxbox_pos_x,
            param.details.display_settings.Pos_Y or fxbox_pos_y)
        if delta_y ~= 0.0 and delta_x ~= 0.0 then
            local new_pos_x = (param.details.display_settings.Pos_X or fxbox_pos_x) + delta_x
            local new_pos_y = (param.details.display_settings.Pos_Y or fxbox_pos_y) + delta_y
            ---clamp the values within the current frame.
            if new_pos_x < fx_box_min_x then
                new_pos_x = fx_box_min_x
            elseif new_pos_x + _child_width > fxbox_max_x then
                new_pos_x = fxbox_max_x - _child_width
            end
            if new_pos_y < fx_box_min_y then
                new_pos_y = fx_box_min_y
            elseif new_pos_y + _child_height > fx_box_max_y then
                new_pos_y = fx_box_max_y - _child_height
            end

            param.details.display_settings.Pos_X = new_pos_x
            param.details.display_settings.Pos_Y = new_pos_y
            reaper.ImGui_ResetMouseDragDelta(ctx, reaper.ImGui_MouseButton_Left())
        end
    end

    -- draw the resize button
    if param._selected then
        if radius then
            local dot_radius = 5

            reaper.ImGui_DrawList_AddCircleFilled(
                reaper.ImGui_GetWindowDrawList(ctx),
                fxbox_screen_pos_x + (param.details.display_settings.Pos_X or fxbox_pos_x) + _child_width - 3,
                fxbox_screen_pos_y + (param.details.display_settings.Pos_Y or fxbox_pos_y) + _child_height - 3,
                dot_radius,
                edit_frame_color
            )
            reaper.ImGui_SetCursorPosX(ctx, _child_width - 10)
            reaper.ImGui_SetCursorPosY(ctx, _child_height - 10)
            reaper.ImGui_InvisibleButton(ctx, "##extendsize" .. param.guid, 10, 10)
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeNWSE())
            end

            if reaper.ImGui_IsItemActive(ctx) then
                if param.details.parent_fx.setSelectedParam then
                    param.details.parent_fx.setSelectedParam(param)
                end
                local delta_x, delta_y = reaper.ImGui_GetMouseDragDelta(
                    ctx,
                    reaper.ImGui_GetCursorPosX(ctx),
                    reaper.ImGui_GetCursorPosY(ctx))
                if delta_y ~= 0.0 and delta_x ~= 0.0 then
                    new_radius = radius + (delta_y + delta_x) * 0.25
                    changed = true
                    reaper.ImGui_ResetMouseDragDelta(ctx, reaper.ImGui_MouseButton_Left())
                end
            end
        end
        if width then
            -- add width control
            reaper.ImGui_SetCursorPosX(ctx, _child_width - 10)
            reaper.ImGui_SetCursorPosY(ctx, 0)
            reaper.ImGui_Button(ctx, "##extendwidth" .. param.guid, 10, _child_height)
            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeEW())
            end

            if reaper.ImGui_IsItemActive(ctx) then
                if param.details.parent_fx.setSelectedParam then
                    param.details.parent_fx.setSelectedParam(param)
                end
                local delta_x, _ = reaper.ImGui_GetMouseDragDelta(
                    ctx,
                    reaper.ImGui_GetCursorPosX(ctx),
                    reaper.ImGui_GetCursorPosY(ctx))
                if delta_x ~= 0.0 then
                    new_width = width + delta_x
                    changed = true
                    reaper.ImGui_ResetMouseDragDelta(ctx, reaper.ImGui_MouseButton_Left())
                end
            end
        end

        -- add height control
        if height then
            reaper.ImGui_SetCursorPosX(ctx, 0)
            reaper.ImGui_SetCursorPosY(ctx, _child_height - 10)

            reaper.ImGui_Button(ctx, "##extendwidth" .. param.guid, _child_width, 10)

            if reaper.ImGui_IsItemHovered(ctx) then
                reaper.ImGui_SetMouseCursor(ctx, reaper.ImGui_MouseCursor_ResizeNS())
            end

            if reaper.ImGui_IsItemActive(ctx) then
                if param.details.parent_fx.setSelectedParam then
                    param.details.parent_fx.setSelectedParam(param)
                end
                local _, delta_y = reaper.ImGui_GetMouseDragDelta(
                    ctx,
                    reaper.ImGui_GetCursorPosX(ctx),
                    reaper.ImGui_GetCursorPosY(ctx))
                if delta_y ~= 0.0 then
                    new_height = height + delta_y
                    changed = true
                    reaper.ImGui_ResetMouseDragDelta(ctx, reaper.ImGui_MouseButton_Left())
                end
            end
        end
    end
    return changed, new_radius, new_width, new_height
end

return EditControl
