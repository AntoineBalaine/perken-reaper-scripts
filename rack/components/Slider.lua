local text_helpers = require("helpers.text")
local layoutEnums = require("state.layout_enums")
local EditControl = require("components.EditControl")


---@class Slider
local Slider = {}

---@enum SliderVariant
Slider.Variant = {
    horizontal = 0,
    vertical = 1,
}

---Create a new Slider
---Currently not passing any styling options
---@param ctx ImGui_Context
---@param id string
---@param param ParamData
---@param on_activate? function
function Slider.new(ctx, id, param, on_activate)
    ---@class Slider
    local new_Slider = {}
    setmetatable(new_Slider, { __index = Slider })
    new_Slider._ctx = ctx
    new_Slider._id = id
    new_Slider._param = param
    new_Slider._on_activate = on_activate

    return new_Slider
end

---@return boolean changed, number new_value
function Slider:draw()
    local no_title                               = self._param.details.display_settings.flags &
        layoutEnums.KnobFlags.NoTitle ==
        layoutEnums.KnobFlags.NoTitle
    local no_input                               = self._param.details.display_settings.flags &
        layoutEnums.KnobFlags.NoInput ==
        layoutEnums.KnobFlags.NoInput
    local no_value                               = self._param.details.display_settings.flags &
        layoutEnums.KnobFlags.NoValue ==
        layoutEnums.KnobFlags.NoValue

    local fxbox_pos_x, fxbox_pos_y               = reaper.ImGui_GetCursorPos(self._ctx)
    local fxbox_max_x, fx_box_max_y              = reaper.ImGui_GetWindowContentRegionMax(self._ctx)
    local fx_box_min_x, fx_box_min_y             = reaper.ImGui_GetWindowContentRegionMin(self._ctx)
    local fxbox_screen_pos_x, fxbox_screen_pos_y = reaper.ImGui_GetWindowPos(self._ctx)

    if self._param.details.display_settings.x and self._param.details.display_settings.y then
        reaper.ImGui_SetCursorPos(self._ctx, self._param.details.display_settings.x,
            self._param.details.display_settings.y)
    end
    local window_padding = reaper.ImGui_GetStyleVar(self._ctx,
        reaper.ImGui_StyleVar_WindowPadding())

    ---TODO maybe make these values editable
    self._child_width    = self._param.details.display_settings.width
    local slider_width
    local slider_height
    if self._param.details.display_settings.variant == Slider.Variant.vertical then
        self._child_height = self._param.details.display_settings.height
        slider_width       = self._child_width - window_padding - 20
        slider_height      = self._child_height - reaper.ImGui_GetTextLineHeightWithSpacing(self._ctx) * 4
    else
        self._child_height = self._param.details.display_settings.height
        slider_width = self._child_width -- horizontal slider has to be full width of the frame
        -- no need to update the height of the horizontal slider
    end
    local changed = false
    local new_val = self._param.details.value

    if reaper.ImGui_BeginChild(self._ctx, "##Slider" .. self._param.guid, self._child_width, self._child_height, false) then
        if self._param.details.parent_fx.editing then
            reaper.ImGui_BeginDisabled(self._ctx, true)
        end
        reaper.ImGui_PushStyleColor(self._ctx, reaper.ImGui_Col_Text(),
            self._param.details.display_settings.color.text_color)
        if not no_title then
            text_helpers.centerText(self._ctx, self._param.name, self._child_width, 2)
        end
        --- If there's only 10 steps, use a stepped slider
        if self._param.details.steps_count then
            -- use a stepped slider, using integer values
            local int_val = (self._param.details.value / self._param.details.step) // 1 |0
            if self._param.details.display_settings.variant == Slider.Variant.horizontal then
                reaper.ImGui_PushItemWidth(self._ctx, slider_width)
                changed, int_val = reaper.ImGui_SliderInt(self._ctx,
                    "##slider" .. self._param.guid,
                    int_val,
                    (self._param.details.minval / self._param.details.step) // 1 | 0,
                    (self._param.details.maxval / self._param.details.step) // 1 | 0,
                    self._param.details.fmt_val
                )
                reaper.ImGui_PopItemWidth(self._ctx)
            else
                local indent_width = (self._child_width - slider_width) / 2
                reaper.ImGui_Indent(self._ctx, indent_width)

                changed, int_val = reaper.ImGui_VSliderInt(self._ctx,

                    "##slider" .. self._param.guid,
                    slider_width,
                    slider_height,
                    int_val,
                    (self._param.details.minval / self._param.details.step) // 1 | 0,
                    (self._param.details.maxval / self._param.details.step) // 1 | 0,
                    ""
                )

                if not no_value then
                    text_helpers.centerText(self._ctx,
                        self._param.details.fmt_val,
                        self._child_width, 2)
                end
                reaper.ImGui_Unindent(self._ctx, indent_width)
            end
            if changed then
                new_val = int_val * self._param.details.step
            end
        else -- non-stepped slider
            if self._param.details.display_settings.variant == Slider.Variant.horizontal then
                reaper.ImGui_PushItemWidth(self._ctx, slider_width)
                changed, new_val = reaper.ImGui_SliderDouble(self._ctx,
                    "##slider" .. self._param.guid,
                    self._param.details.value,
                    self._param.details.minval,
                    self._param.details.maxval,
                    self._param.details.fmt_val)

                reaper.ImGui_PopItemWidth(self._ctx)
            else
                local indent_width = (self._child_width - slider_width) / 2
                reaper.ImGui_Indent(self._ctx, indent_width)
                changed, new_val = reaper.ImGui_VSliderDouble(
                    self._ctx,
                    "##slider" .. self._param.guid,
                    slider_width,
                    slider_height,
                    self._param.details.value,
                    self._param.details.minval,
                    self._param.details.maxval,
                    "")
                if not no_value then
                    text_helpers.centerText(self._ctx,
                        self._param.details.fmt_val,
                        self._child_width, 2)
                end
                reaper.ImGui_Unindent(self._ctx, indent_width)
            end
        end
        reaper.ImGui_PopStyleColor(self._ctx, 1) -- pop text color

        if self._param.details.parent_fx.editing then
            reaper.ImGui_EndDisabled(self._ctx)
        end
        if changed and not self._param.details.parent_fx.editing then
            if self._on_activate then
                self._on_activate()
            end
        end


        if self._param.details.parent_fx.editing then
            if self._param.details.display_settings.variant == Slider.Variant.horizontal then
                local size_changed, _, new_width, _ = EditControl(
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
                    nil,
                    self._param.details.display_settings.width,
                    nil
                )
                if size_changed then
                    self._param.details.display_settings.width = new_width
                end
            else
                local size_changed, _, new_width, new_height = EditControl(
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
                    nil,
                    self._param.details.display_settings.width,
                    self._param.details.display_settings.height
                )
                if size_changed then
                    self._param.details.display_settings.width = new_width
                    self._param.details.display_settings.height = new_height
                end
            end
        end
        reaper.ImGui_EndChild(self._ctx)
    end
    if not self._param.details.parent_fx.editing and no_input then
        return false, self._param.details.value
    else
        return changed, new_val
    end
end

--[[Adding here the draft of slider, based on Ableton's version (with triangle)]]
-- function fx_box:slider()
--     reaper.ImGui_NewLine(self.ctx)
--     reaper.ImGui_Button(self.ctx, "hello")
--     local p_value              = 50
--     local v_min                = 10
--     local v_max                = 100

--     local Radius               = 30
--     local draw_list            = reaper.ImGui_GetWindowDrawList(self.ctx)
--     local pos                  = { reaper.ImGui_GetCursorScreenPos(self.ctx) } ---@type {[1]:number, [2]:number}
--     Radius                     = Radius or 0
--     local radius_outer         = Radius
--     local t                    = (p_value - v_min) / (v_max - v_min)
--     local ANGLE_MIN            = 3.141592 * 0.75
--     local ANGLE_MAX            = 3.141592 * 2.25
--     local angle                = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * t
--     local angle_cos, angle_sin = math.cos(angle), math.sin(angle)
--     -- local radius_inner         = radius_outer * 0.40
--     local center               = { pos[1] + radius_outer, pos[2] + radius_outer }
--     reaper.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_outer,
--         reaper.ImGui_GetColor(self.ctx, reaper.ImGui_Col_Button()))
--     local p1_x = center[1] --  + angle_cos * radius_inner
--     local p1_y = center[2] --  + angle_sin * radius_inner
--     local p2_x = center[1] + angle_cos * (radius_outer - 2)
--     local p2_y = center[2] + angle_sin * (radius_outer - 2)
--     local col = 0x123456ff
--     local thickness = 2
--     reaper.ImGui_DrawList_AddLine(draw_list,
--         p1_x,
--         p1_y,
--         p2_x,
--         p2_y,
--         col,
--         thickness)
--     -- reaper.ImGui_DrawList_PathArcTo(draw_list, center[1], center[2], radius_outer / 2, ANGLE_MIN, angle)
--     -- reaper.ImGui_DrawList_PathStroke(draw_list, 0xFFFFFFFF, nil, radius_outer * 0.6)
--     -- reaper.ImGui_DrawList_PathClear(draw_list)
--     -- local white = 0xFFFFFFFF
--     -- local draw_list =
--     -- local  p1_x =
--     -- local  p1_y =
--     -- local  p2_x =
--     -- local  p2_y =
--     -- local  p3_x =
--     -- local  p3_y =
--     -- local col_rgba = white
--     -- local vertices = calculateTriangleVertices(center[1], center[2], radius_outer)
--     -- local c = vertices[1]
--     -- local b = vertices[2]
--     -- local a = vertices[3]

--     -- reaper.ImGui_DrawList_AddTriangleFilled(draw_list, c.x, c.y, b.x, b.y, a.x, a.y, col_rgba)
--     -- reaper.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_inner,
--     --     reaper.ImGui_GetColor(self.ctx,
--     --         reaper.ImGui_IsItemActive(self.ctx) and reaper.ImGui_Col_FrameBgActive() or
--     --         reaper.ImGui_IsItemHovered(self.ctx) and reaper.ImGui_Col_FrameBgHovered() or reaper.ImGui_Col_FrameBg()))

--     -- reaper.ImGui_DrawList_PathArcTo(draw_list, center[1], center[2], radius_outer / 2, ANGLE_MIN, angle)
--     -- -- reaper.ImGui_DrawList_PathStroke(draw_list, white, nil, radius_outer * 0.6)
--     -- reaper.ImGui_DrawList_PathClear(draw_list)
-- end


return Slider
