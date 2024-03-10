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
local Knobs          = require("components.knobs.Knobs")

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
        self.displaySettings.background) -- fx’s bg color
    -- reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_Border(),
    --     self.displaySettings.BorderColor) -- fx box’s border color
end

function fx_box:fxBoxStyleEnd()
    reaper.ImGui_PopStyleColor(self.ctx, 1) -- pop the bg, button bg and border colors
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
        button_text_color) -- fx's text color
end

function fx_box:buttonStyleEnd()
    reaper.ImGui_PopStyleColor(self.ctx, 2)
end

function fx_box:BypassToggle()
    if reaper.ImGui_Checkbox(self.ctx, "##bypass", self.fx.enabled) then
        reaper.TrackFX_SetEnabled(self.state.Track.track, self.fx.index - 1,
            not self.fx.enabled)
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
    local display_name = self.fx.presetname ~= nil
        and self.fx.presetname
        or fx_box_helpers.getDisplayName(self.fx.name) -- get name of fx
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
    local wrench_icon = self.theme.letters[75]
    reaper.ImGui_PushFont(self.ctx, self.theme.fonts.ICON_FONT_SMALL)

    if reaper.ImGui_Button(self.ctx, wrench_icon) then -- create window name button
        if (LayoutEditor.open) then
            LayoutEditor:close(layout_enums.EditLayoutCloseAction.discard)
        else
            self.fx:editLayout()
            LayoutEditor:edit(self.fx)
        end
    end
    reaper.ImGui_PopFont(self.ctx)
    if reaper.ImGui_IsItemHovered(self.ctx, reaper.ImGui_HoveredFlags_DelayNormal()) then
        reaper.ImGui_SetTooltip(self.ctx, "edit fx layout")
    end
    reaper.ImGui_SameLine(self.ctx, nil, 5)
end

function fx_box:AddSavePresetBtn()
    reaper.ImGui_PushFont(self.ctx, self.theme.fonts.ICON_FONT_SMALL)
    local saver = self.theme.letters[164]
    if reaper.ImGui_Button(self.ctx, saver) then -- create window name button
        if not reaper.ImGui_IsPopupOpen(self.ctx, "##presetsave") then
            reaper.ImGui_OpenPopup(self.ctx, "##presetsave")
        end
    end
    reaper.ImGui_PopFont(self.ctx)
    if reaper.ImGui_IsItemHovered(self.ctx, reaper.ImGui_HoveredFlags_DelayNormal()) then
        reaper.ImGui_SetTooltip(self.ctx, "save fx preset")
    end

    reaper.ImGui_SetNextWindowSize(self.ctx, 400, 100)
    self.open = reaper.ImGui_BeginPopupModal(self.ctx, "##presetsave")
    if reaper.ImGui_IsWindowAppearing(self.ctx) then -- focus the input box when the window appears
        reaper.ImGui_SetKeyboardFocusHere(self.ctx)
    end
    if self.open then
        self.open = true
        local new_val = ""
        reaper.ImGui_Text(self.ctx, "Preset name:")
        reaper.ImGui_InputText(self.ctx, "Preset name", new_val)
        if reaper.ImGui_Button(self.ctx, "ok") then
            -- TODO save presets
        end
        reaper.ImGui_SameLine(self.ctx)
        if reaper.ImGui_Button(self.ctx, "cancel") then
            new_val = ""
            reaper.ImGui_CloseCurrentPopup(self.ctx)
        end
        reaper.ImGui_EndPopup(self.ctx)
    end
end

function fx_box:AddParamsBtn()
    local popup_name = "addFxParams"

    -- "+" ICON 
    reaper.ImGui_PushFont(self.ctx, self.theme.fonts.ICON_FONT_SMALL)
    local plus = self.theme.letters[34]
    if reaper.ImGui_Button(self.ctx, plus) then -- create window name button
        if not reaper.ImGui_IsPopupOpen(self.ctx, popup_name) then
            reaper.ImGui_OpenPopup(self.ctx, popup_name)
        end
    end
    reaper.ImGui_PopFont(self.ctx)
    if reaper.ImGui_IsItemHovered(self.ctx, reaper.ImGui_HoveredFlags_DelayNormal()) then
        reaper.ImGui_SetTooltip(self.ctx, "add params to display")
    end

    -- ADD PARAMS POPUP
    reaper.ImGui_SetWindowSize(self.ctx, 400, 300)
    if reaper.ImGui_BeginPopup(self.ctx, popup_name) then
        ---TODO fix this guy during fx's state updates.
        ---TODO implement text filter here, so that user can filter the fx-params' list.
        for i = 1, #self.fx.params_list - 1 do
            local param = self.fx.params_list[i]
            local _, new_val = reaper.ImGui_Checkbox(self.ctx, param.name, param.display)
            if new_val ~= param.display then
                param.display = new_val
                if new_val then
                    self.fx:createParamDetails(param.guid)
                else
                    self.fx:removeParamDetails(param.guid)
                end
            end
        end
        reaper.ImGui_EndPopup(self.ctx)
    end
    reaper.ImGui_SameLine(self.ctx)
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
        self:AddSavePresetBtn()

        for idx, param in ipairs(self.fx.display_params) do
            local new_val = Knobs.Knob.new(self.ctx,
                "knob" .. idx,
                param.name,
                tonumber(param.value) or 0,
                param.minval,
                param.maxval,
                param.defaultval,
                reaper.ImGui_GetTextLineHeight(self.ctx) * 4.0 * 0.5,
                true,
                param.fmt_val,
                function() --- on activate function
                    -- TODO refactor: move the call to new() into the fx display_param’s state.
                    -- this violates the principle of separating the view from the state,
                    -- but otherwise the newly created knob keeps on appearing as «not active» and this callback
                    -- is being called at every frame the user holds the button.
                    -- Otherwise, if we really want this to be clean, we’d have to refactor the whole
                    -- thing to instantiate each fx’s ui as classes
                    reaper.TrackFX_SetNamedConfigParm(self.state.Track.track, self.fx.index, param.name, "last_touched")
                end
            ):draw(
                Knobs.Knob.KnobVariant.ableton,
                self.testcol,
                self.testcol,
                self.testcol
            )
            if new_val ~= param.value then
                param.value = new_val
                param:setValue(new_val)
            end
        end
        reaper.ImGui_EndChild(self.ctx)
    end
    self:fxBoxStyleEnd()
    reaper.ImGui_EndGroup(self.ctx)

    reaper.ImGui_SameLine(self.ctx, nil, 0)
end

---@return ColorSet
function fx_box:testcolors()
    ---@type ColorSet
    local test = {
        base = self.theme.colors.col_vuind2.color,
        hovered = self.theme.colors.col_vuind4.color,
        active = self.theme.colors.col_vuind3.color,
    }
    return Knobs.ColorSet.new(test.base, test.hovered, test.active)
end

---@param parent_state Rack
function fx_box:init(parent_state)
    self.state = parent_state.state
    self.settings = parent_state.settings
    self.actions = parent_state.actions
    self.ctx = parent_state.ctx
    self.theme = parent_state.theme
    self.testcol = self:testcolors()
    LayoutEditor:init(parent_state.ctx, parent_state.theme)
end

return fx_box
