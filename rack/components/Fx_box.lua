-- dofile("/home/antoine/Documents/Experiments/lua/debug_connect.lua")
--[[
This component is the display for each FX.
order of steps are:
- instantiate with init() from the parent component.
- display using the main() function

Bear in mind that this component is a singleton, so it’s a single instance that is re-used for each FX.
As a result, its internal state has to be updated every time it’s called. I’m not sure yet whether I like this or would rather have one instance per appearance.
]]
local fx_box_helpers = require("helpers.fx_box_helpers")
local LayoutEditor   = require("components.LayoutEditor")
local drag_drop      = require("state.dragAndDrop")
local layout_enums   = require("state.fx_layout_types")

local fx_box         = {}
local winFlg         = reaper.ImGui_WindowFlags_NoScrollWithMouse() + reaper.ImGui_WindowFlags_NoScrollbar()

function fx_box:dragDropSource()
    if reaper.ImGui_BeginDragDropSource(self.ctx, reaper.ImGui_DragDropFlags_None()) then
        reaper.ImGui_SetDragDropPayload(self.ctx, drag_drop.types.drag_fx, tostring(self.fx.index))
        reaper.ImGui_EndDragDropSource(self.ctx)
    end
end

function fx_box:fxBoxStyleStart()
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_ChildBg(),
        self.displaySettings.background)  -- fx’s bg color
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_Border(),
        self.displaySettings.BorderColor) -- fx box’s border color
end

function fx_box:fxBoxStyleEnd()
    reaper.ImGui_PopStyleColor(self.ctx, 2) -- pop the bg, button bg and border colors
end

function fx_box:buttonStyleStart()
    reaper.ImGui_PushStyleColor(self.ctx,
        reaper.ImGui_Col_Button(),
        self.displaySettings.buttonStyle.background) -- fx’s bg color
    local button_text_color ---@type number

    if self.fx.enabled then -- set a dark-colored text if the fx is bypassed
        button_text_color = self.displaySettings.buttonStyle.text_enabled
    else
        button_text_color = self.displaySettings.buttonStyle.text_disabled
    end
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_Text(),
        button_text_color) -- fx’s bg color
end

function fx_box:buttonStyleEnd()
    reaper.ImGui_PopStyleColor(self.ctx, 2)
end

function fx_box:BypassToggle()
    local is_enabled = reaper.TrackFX_GetEnabled(self.state.Track.track, self.fx.index - 1)
    if reaper.ImGui_Checkbox(self.ctx, "##bypass", is_enabled) then
        reaper.TrackFX_SetEnabled(self.state.Track.track, self.fx.index - 1,
            not is_enabled)
    end
    -- --leaving the toggle button as WIP for now
    -- local round_flag = reaper.ImGui_DrawFlags_RoundCornersAll()
    -- local draw_list = reaper.ImGui_GetWindowDrawList(self.ctx)
    -- local xs, ys = reaper.ImGui_GetCursorScreenPos(self.ctx)
    -- local xe, ye = xs + 20, ys + 20


    -- reaper.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, 0x00000000, 10,
    --     round_flag)
    -- reaper.ImGui_DrawList_AddRectFilled(draw_list, xs + 5, ys + 5, xe - 5, ye - 5, 0xFFFFFFFF, 10,
    --     round_flag)

    -- if reaper.ImGui_InvisibleButton(self.ctx, "##fx_toggle", 20, 20) then
    --     reaper.TrackFX_SetEnabled(self.state.Track.track, self.fx.index - 1,
    --         not is_enabled)
    -- end

    -- local button_color = is_enabled and self.theme.colors.col_toolbar_text.color or
    --     self.theme.colors.col_toolbar_text_on.color
    -- if reaper.ImGui_IsItemHovered(self.ctx) then
    --     button_color = button_color + self.theme.colors.col_toolbar_text.color
    -- end

    -- local circle_x_center = xs + 10
    -- local circle_y_center = ys + 10
    -- reaper.ImGui_DrawList_AddCircle(draw_list, circle_x_center, circle_y_center, 10, 0x00000FFF, nil, nil)
    -- reaper.ImGui_DrawList_AddCircle(draw_list, circle_x_center, circle_y_center, 8, button_color, nil, 2)

    -- local rect_x_start, rect_y_start = xs + 8, ys + 8
    -- local rect_x_end, rect_y_end = rect_x_start + 2, rect_y_start + 5

    -- reaper.ImGui_DrawList_AddRectFilled(draw_list, rect_x_start, rect_y_start, rect_x_end, rect_y_end, 0xFFFFFFFF, 10,
    --     round_flag)
    reaper.ImGui_SameLine(self.ctx, nil, 5)
end

local function calculateTriangleVertices(centerX, centerY, radius)
    local vertices = {}

    -- Calculate the angles for each point
    local angle1 = 0
    local angle2 = (2 * math.pi) / 3
    local angle3 = (4 * math.pi) / 3

    -- Calculate the coordinates for each point
    local x1 = centerX + radius * math.cos(angle1)
    local y1 = centerY + radius * math.sin(angle1)
    table.insert(vertices, { x = x1, y = y1 })

    local x2 = centerX + radius * math.cos(angle2)
    local y2 = centerY + radius * math.sin(angle2)
    table.insert(vertices, { x = x2, y = y2 })

    local x3 = centerX + radius * math.cos(angle3)
    local y3 = centerY + radius * math.sin(angle3)
    table.insert(vertices, { x = x3, y = y3 })

    return vertices
end

function fx_box:slider()
    reaper.ImGui_NewLine(self.ctx)
    reaper.ImGui_Button(self.ctx, "hello")
    local p_value              = 50
    local v_min                = 10
    local v_max                = 100

    local Radius               = 30
    local draw_list            = reaper.ImGui_GetWindowDrawList(self.ctx)
    local pos                  = { reaper.ImGui_GetCursorScreenPos(self.ctx) } ---@type {[1]:number, [2]:number}
    Radius                     = Radius or 0
    local radius_outer         = Radius
    local t                    = (p_value - v_min) / (v_max - v_min)
    local ANGLE_MIN            = 3.141592 * 0.75
    local ANGLE_MAX            = 3.141592 * 2.25
    local angle                = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * t
    local angle_cos, angle_sin = math.cos(angle), math.sin(angle)
    local radius_inner         = radius_outer * 0.40
    local center               = { pos[1] + radius_outer, pos[2] + radius_outer }
    reaper.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_outer,
        reaper.ImGui_GetColor(self.ctx, reaper.ImGui_Col_Button()))
    local p1_x = center[1] --  + angle_cos * radius_inner
    local p1_y = center[2] --  + angle_sin * radius_inner
    local p2_x = center[1] + angle_cos * (radius_outer - 2)
    local p2_y = center[2] + angle_sin * (radius_outer - 2)
    local col = 0x123456ff
    local thickness = 2
    reaper.ImGui_DrawList_AddLine(draw_list,
        p1_x,
        p1_y,
        p2_x,
        p2_y,
        col,
        thickness)
    -- reaper.ImGui_DrawList_PathArcTo(draw_list, center[1], center[2], radius_outer / 2, ANGLE_MIN, angle)
    -- reaper.ImGui_DrawList_PathStroke(draw_list, 0xFFFFFFFF, nil, radius_outer * 0.6)
    -- reaper.ImGui_DrawList_PathClear(draw_list)
    local white = 0xFFFFFFFF
    -- local draw_list =
    -- local  p1_x =
    -- local  p1_y =
    -- local  p2_x =
    -- local  p2_y =
    -- local  p3_x =
    -- local  p3_y =
    local col_rgba = white
    -- local vertices = calculateTriangleVertices(center[1], center[2], radius_outer)
    -- local c = vertices[1]
    -- local b = vertices[2]
    -- local a = vertices[3]

    -- reaper.ImGui_DrawList_AddTriangleFilled(draw_list, c.x, c.y, b.x, b.y, a.x, a.y, col_rgba)
    -- reaper.ImGui_DrawList_AddCircleFilled(draw_list, center[1], center[2], radius_inner,
    --     reaper.ImGui_GetColor(self.ctx,
    --         reaper.ImGui_IsItemActive(self.ctx) and reaper.ImGui_Col_FrameBgActive() or
    --         reaper.ImGui_IsItemHovered(self.ctx) and reaper.ImGui_Col_FrameBgHovered() or reaper.ImGui_Col_FrameBg()))

    -- reaper.ImGui_DrawList_PathArcTo(draw_list, center[1], center[2], radius_outer / 2, ANGLE_MIN, angle)
    -- -- reaper.ImGui_DrawList_PathStroke(draw_list, white, nil, radius_outer * 0.6)
    -- reaper.ImGui_DrawList_PathClear(draw_list)
end

function fx_box:Knob()
    local text_color = self.theme.colors.col_toolbar_text_on.color
    local label = "Volume"
    -- reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_Text(),
    --     text_color) -- label text's color
    -- reaper.ImGui_Text(self.ctx, "Volume")
    if not self.knob_value then
        self.knob_value = 42
    end
    -- reaper.ImGui_PopStyleColor(self.ctx, 1)

    local line_height = reaper.ImGui_GetTextLineHeight(self.ctx)
    local Radius = 20
    if reaper.ImGui_BeginChild(self.ctx, "##knob", Radius * 2) then ----START CHILD WINDOW
        local label_text_width, _  = reaper.ImGui_CalcTextSize(self.ctx, label)

        local v_min                = 0
        local v_max                = 100

        local draw_list            = reaper.ImGui_GetWindowDrawList(self.ctx)
        local pos                  = { reaper.ImGui_GetCursorScreenPos(self.ctx) } ---@type {[1]:number, [2]:number}
        Radius                     = Radius or 0
        local radius_outer         = Radius
        local t                    = (self.knob_value - v_min) / (v_max - v_min) -- is this tangent?
        local ANGLE_MIN            = 3.141592 * 0.75
        local ANGLE_MAX            = 3.141592 * 2.25
        local angle                = ANGLE_MIN + (ANGLE_MAX - ANGLE_MIN) * t
        local angle_cos, angle_sin = math.cos(angle), math.sin(angle)
        local radius_inner         = radius_outer * 0.40
        local center               = {
            x = pos[1] + radius_outer,
            y = pos[2] + radius_outer + line_height + 3
        }



        local pointer_end_x  = center.x + angle_cos * (radius_outer - 2)
        local pointer_end_y  = center.y + angle_sin * (radius_outer - 2)
        local path_color     = self.theme.colors.col_vuind4.color
        local path_thickness = radius_outer * 0.1



        reaper.ImGui_DrawList_AddText(
            draw_list,
            center.x - label_text_width / 2,
            pos[2], -- 1.6 is somewhat arbitary here, just enough so that the text is *right* below the knob
            text_color,
            label)

        -- Add a drag behind the knob’s drawing, make it transparent.
        -- That way it’s easy to have the drag mechanic and the knob drawing.
        reaper.ImGui_PushStyleVar(self.ctx, reaper.ImGui_StyleVar_Alpha(), 0)

        _, self.knob_value = reaper.ImGui_VSliderInt(self.ctx,
            "##test",
            radius_outer * 2,
            radius_outer * 2 - 5,
            self.knob_value,
            0,
            100,
            nil,
            reaper.ImGui_SliderFlags_AlwaysClamp())
        reaper.ImGui_PopStyleVar(self.ctx)
        --- knob's circle
        reaper.ImGui_DrawList_AddCircleFilled(draw_list, center.x, center.y, radius_outer,
            0x00000000)

        --- knob pointer
        reaper.ImGui_DrawList_AddLine(draw_list,
            center.x, --  + angle_cos * radius_inner
            center.y, --  + angle_sin * radius_inner
            pointer_end_x,
            pointer_end_y,
            0x000000FF,
            path_thickness)

        --- knob's filled path/values
        --full black contour
        reaper.ImGui_DrawList_PathArcTo(draw_list, center.x, center.y, radius_outer * 0.95, ANGLE_MIN, ANGLE_MAX)
        local transparent_color = 0x000000FF
        reaper.ImGui_DrawList_PathStroke(draw_list, transparent_color, nil, path_thickness)
        reaper.ImGui_DrawList_PathClear(draw_list)
        -- current-value contour
        reaper.ImGui_DrawList_PathArcTo(draw_list, center.x, center.y, radius_outer * 0.95, ANGLE_MIN, angle)
        reaper.ImGui_DrawList_PathStroke(draw_list, path_color, nil, path_thickness)
        reaper.ImGui_DrawList_PathClear(draw_list)

        -- value’ text-display
        local value_text_width, _ = reaper.ImGui_CalcTextSize(self.ctx, tostring(self.knob_value))
        reaper.ImGui_DrawList_AddText(
            draw_list,
            center.x - value_text_width / 2,
            pos[2] + radius_outer * 2 + 10, -- pos[2] is very start of the component, radius*2 is the circle, +10 for spacing
            text_color,
            tostring(self.knob_value))
        reaper.ImGui_EndChild(self.ctx)
    end
end

function fx_box:toggleFxWindow()
    if self.settings.prefer_fx_chain then
        local focused_fx_idx = reaper.TrackFX_GetChainVisible(self.state.Track.track) -- if not ALT, show fx
        local show_flag = focused_fx_idx == self.fx.index - 1 and 0 or
            1                                                                         -- if fxchain window is open and the fx is already focused, hide it
        reaper.TrackFX_Show(self.state.Track.track, self.fx.index - 1, show_flag)
    else
        local hwnd = reaper.TrackFX_GetFloatingWindow(self.state.Track.track, self.fx.index - 1)
        reaper.TrackFX_SetOpen(self.state.Track.track, self.fx.index - 1, hwnd == nil)
    end
end

function fx_box:LabelButton()
    local display_name = fx_box_helpers.getDisplayName(self.fx.name) -- get name of fx
    local btn_width = self.displaySettings.Title_Width
    local btn_height = 20
    self:buttonStyleStart()
    if reaper.ImGui_Button(self.ctx, display_name, btn_width, btn_height) then        -- create window name button
        local is_remove_fx = reaper.ImGui_IsKeyDown(self.ctx, reaper.ImGui_Mod_Alt()) -- if ALT is held when clicking, remove fx
        if is_remove_fx then
            self.state:deleteFx(self.fx.index)
        else
            self:toggleFxWindow()
        end
    end

    if reaper.ImGui_IsItemHovered(self.ctx) then
        reaper.ImGui_SetMouseCursor(self.ctx, reaper.ImGui_MouseCursor_Hand())
    end
    self:buttonStyleEnd()
    self:dragDropSource() -- attach the drag/drop source to the preceding button
    reaper.ImGui_SameLine(self.ctx, nil, 5)
end

function fx_box:EditLayoutButton()
    if reaper.ImGui_Button(self.ctx, "E") then -- create window name button
        if (LayoutEditor.open) then
            LayoutEditor:close(layout_enums.EditLayoutCloseAction.discard)
        else
            self.fx:editLayout()
            LayoutEditor:edit(self.fx)
        end
    end
    reaper.ImGui_SameLine(self.ctx, nil, 5)
end

function fx_box:AddParamsBtn()
    local popup_name = "addFxParams"
    if reaper.ImGui_Button(self.ctx, "+") then -- create window name button
        if not reaper.ImGui_IsPopupOpen(self.ctx, popup_name) then
            reaper.ImGui_OpenPopup(self.ctx, popup_name)
        end
    end
    if reaper.ImGui_IsItemHovered(self.ctx) then
        reaper.ImGui_SetTooltip(self.ctx, "add params to display")
    end

    reaper.ImGui_SetWindowSize(self.ctx, 400, 300)
    if reaper.ImGui_BeginPopup(self.ctx, popup_name) then
        ---TODO fix this guy during fx's state updates.
        local all_params = false
        if reaper.ImGui_Checkbox(self.ctx, "All params", false) then
            all_params = true
        end
        ---TODO implement text filter here, so that user can filter the fx-params' list.
        for _, param in ipairs(self.fx.param_list) do
            param.display = select(2, reaper.ImGui_Checkbox(self.ctx, param.name, param.display))
            if all_params then
                param.display = true
            end
        end
        reaper.ImGui_EndPopup(self.ctx)
    end
end

---@param fx TrackFX
function fx_box:main(fx)
    self.fx = fx
    -- use the displaySettings_copy if it's not null: this means that the user is editing the layout and we should work on a copy of state.
    if fx.displaySettings_copy then
        self.displaySettings = fx.displaySettings_copy
    else
        self.displaySettings = fx.displaySettings
    end

    reaper.ImGui_BeginGroup(self.ctx)

    self:fxBoxStyleStart()

    if reaper.ImGui_BeginChild(self.ctx,
            fx.name,
            self.displaySettings.Window_Width,
            self.displaySettings.height,
            true,
            winFlg)
    then
        self:BypassToggle()
        self:EditLayoutButton()
        self:LabelButton()

        self:AddParamsBtn()


        -- self:slider()
        self:Knob()
        reaper.ImGui_EndChild(self.ctx)
    end
    self:fxBoxStyleEnd()
    reaper.ImGui_EndGroup(self.ctx)

    reaper.ImGui_SameLine(self.ctx, nil, 0)
end

---@param parent_state Rack
function fx_box:init(parent_state)
    self.state = parent_state.state
    self.settings = parent_state.settings
    self.actions = parent_state.actions
    self.ctx = parent_state.ctx
    self.theme = parent_state.theme
    LayoutEditor:init(parent_state.ctx)
end

return fx_box
