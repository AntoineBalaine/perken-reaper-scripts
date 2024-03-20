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
local drag_drop      = require("state.dragAndDrop")
local layout_enums   = require("state.fx_layout_types")
local Knob           = require("components.knobs.Knobs")
local layoutEnums    = require("state.fx_layout_types")
local ColorSet       = require("helpers.ColorSet")
local color_helpers  = require("helpers.color_helpers")
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

function fx_box:DrawGrid()
    local WinDrawList = reaper.ImGui_GetWindowDrawList(self.ctx)
    local start_x, start_y = reaper.ImGui_GetItemRectMin(self.ctx)
    local end_x, end_y = reaper.ImGui_GetItemRectMax(self.ctx)
    local gridsize = 10
    local grid_color = 0x444444AA -- TODO pick a color from the theme
    -- local grid_color = 0xFFFFFFFF

    -- add horizontal grid
    for i = 0, self.fx.displaySettings.window_width, gridsize do
        reaper.ImGui_DrawList_AddLine(WinDrawList,
            start_x,
            start_y + i,
            end_x,
            end_y + i,
            grid_color)
    end

    -- add vertical grid
    for i = 0, self.fx.displaySettings.window_width, gridsize do
        reaper.ImGui_DrawList_AddLine(WinDrawList,
            start_x + i,
            start_y,
            start_x + i,
            start_y + self.fx.displaySettings.window_height,
            grid_color)
    end
    -- end
end

function fx_box:fxBoxStyleEnd()
    reaper.ImGui_PopStyleColor(self.ctx, 1) -- pop the bg, button bg and border colors
end

function fx_box:labelButtonStyleStart()
    local bg_col ---@type number
    if self.fx.enabled then
        bg_col = self.fx.displaySettings.labelButtonStyle.background
        bg_col = self.fx.displaySettings.labelButtonStyle.background
    else
        bg_col = self.fx.displaySettings.labelButtonStyle.background_disabled
    end
    reaper.ImGui_PushStyleColor(self.ctx,
        reaper.ImGui_Col_Button(),
        bg_col) -- fx’s bg color
    local button_text_color ---@type number

    if self.fx.enabled then -- set a dark-colored text if the fx is bypassed
        button_text_color = self.displaySettings.labelButtonStyle.text_enabled
    else
        button_text_color = self.displaySettings.labelButtonStyle.text_disabled
    end
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_Text(),
        button_text_color) -- fx's text color
end

function fx_box:labelButtonStyleEnd()
    reaper.ImGui_PopStyleColor(self.ctx, 2)
end

function fx_box:BypassToggle()
    if reaper.ImGui_Checkbox(self.ctx, "##bypass", self.fx.enabled) then
        reaper.TrackFX_SetEnabled(self.state.Track.track, self.fx.index - 1,
            not self.fx.enabled)

        -- set last touched fx param to «bypass» if the checkbox's been clicked
        reaper.TrackFX_SetNamedConfigParm(self.state.Track.track, self.fx.index, "BYPASS",
            "last_touched")
    end
    if reaper.ImGui_IsItemHovered(self.ctx, reaper.ImGui_HoveredFlags_DelayNormal()) then
        reaper.ImGui_SetTooltip(self.ctx, "toggle bypass")
    end
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
    -- local radius_inner         = radius_outer * 0.40
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
    -- local white = 0xFFFFFFFF
    -- local draw_list =
    -- local  p1_x =
    -- local  p1_y =
    -- local  p2_x =
    -- local  p2_y =
    -- local  p3_x =
    -- local  p3_y =
    -- local col_rgba = white
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

---call upon clicking the fx name button
function fx_box:LabelButtonCB()
    local is_remove_fx = reaper.ImGui_IsKeyDown(self.ctx, reaper.ImGui_Mod_Alt()) -- if ALT is held when clicking, remove fx
    if is_remove_fx then
        self.state:deleteFx(self.fx.index)
    else
        self:toggleFxWindow()
    end
end

function fx_box:VerticalLabelButton()
    local display_name       = self.fx.presetname ~= nil
        and self.fx.presetname
        or fx_box_helpers.getDisplayName(self.fx.name) -- get name of fx
    local width, height      = reaper.ImGui_CalcTextSize(self.ctx, display_name)
    -- invert the width and height to represent the component size
    local temp               = height
    height                   = width
    width                    = temp
    local btn_x, btn_y       = reaper.ImGui_GetCursorPos(self.ctx)

    -- fill the rest of the line with the button width
    local lineSpacing        = reaper.ImGui_GetStyleVar(self.ctx, reaper.ImGui_StyleVar_ItemSpacing())
    local lineHeightWSpacing = reaper.ImGui_GetTextLineHeightWithSpacing(self.ctx)
    local btn_height         = select(2, reaper.ImGui_GetContentRegionAvail(self.ctx)) - self.default_button_size -
        reaper.ImGui_GetStyleVar(self.ctx, lineHeightWSpacing)

    self:labelButtonStyleStart()
    if reaper.ImGui_Button(self.ctx, "##" .. display_name, self.default_button_size, btn_height) then
        self:LabelButtonCB()
    end
    if reaper.ImGui_IsItemHovered(self.ctx) then
        reaper.ImGui_SetMouseCursor(self.ctx, reaper.ImGui_MouseCursor_Hand())
    end

    reaper.ImGui_SetCursorPosX(self.ctx, btn_x)
    reaper.ImGui_Indent(self.ctx, 5)
    reaper.ImGui_SetCursorPosY(self.ctx, btn_y)
    for k = 1, #display_name do
        -- if there's no more space to the bottom of the window, don't display any more letters
        local _, cur_y = reaper.ImGui_GetCursorPos(self.ctx)
        if cur_y + lineHeightWSpacing > btn_y + btn_height
        then
            break
        else
            reaper.ImGui_Text(self.ctx, string.sub(display_name, k, k))
        end
    end
    reaper.ImGui_SetCursorPosX(self.ctx, btn_x)
    reaper.ImGui_SetCursorPosY(self.ctx, btn_y + btn_height + lineSpacing / 2)
    reaper.ImGui_Unindent(self.ctx, 5)
    self:labelButtonStyleEnd()
end

function fx_box:LabelButton()
    local display_name = self.fx.presetname ~= nil
        and self.fx.presetname
        or fx_box_helpers.getDisplayName(self.fx.name) -- get name of fx
    --- either use `GetContentRegionAvail()` or `self.displaySettings.title_Width`
    local btn_width = reaper.ImGui_GetContentRegionAvail(self.ctx) - self.default_button_size -
        reaper.ImGui_GetStyleVar(self.ctx, reaper.ImGui_StyleVar_ItemSpacing())
    self:labelButtonStyleStart()
    if reaper.ImGui_Button(self.ctx, display_name, btn_width, self.default_button_size) then -- create window name button
        self:LabelButtonCB()
    end

    if reaper.ImGui_IsItemHovered(self.ctx) then
        reaper.ImGui_SetMouseCursor(self.ctx, reaper.ImGui_MouseCursor_Hand())
    end
    self:labelButtonStyleEnd()
    self:dragDropSource() -- attach the drag/drop source to the preceding button
end

---Also store the button size as default button’s size.
function fx_box:EditLayoutButton()
    local wrench_icon = self.theme.letters[75]
    reaper.ImGui_PushFont(self.ctx, self.theme.fonts.ICON_FONT_SMALL)

    if reaper.ImGui_Button(self.ctx, wrench_icon, self.default_button_size, self.default_button_size) then -- create window name button
        if (self.LayoutEditor.open) then
            self.LayoutEditor:close(layout_enums.EditLayoutCloseAction.discard)
        else
            self.fx:editLayout()
            self.LayoutEditor:edit(self.fx)
        end
    end
    reaper.ImGui_PopFont(self.ctx)

    if reaper.ImGui_IsItemHovered(self.ctx, reaper.ImGui_HoveredFlags_DelayNormal()) then
        reaper.ImGui_SetTooltip(self.ctx, "edit fx layout")
    end
end

function fx_box:AddSavePresetBtn()
    reaper.ImGui_PushFont(self.ctx, self.theme.fonts.ICON_FONT_SMALL)
    local saver = self.theme.letters[164]
    if reaper.ImGui_Button(self.ctx, saver, self.default_button_size, self.default_button_size) then -- create window name button
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
            new_val = ""
            reaper.ImGui_CloseCurrentPopup(self.ctx)
        end
        reaper.ImGui_SameLine(self.ctx)
        if reaper.ImGui_Button(self.ctx, "cancel") then
            new_val = ""
            reaper.ImGui_CloseCurrentPopup(self.ctx)
        end
        reaper.ImGui_EndPopup(self.ctx)
    end
end

function fx_box:CollapseButton()
    reaper.ImGui_PushFont(self.ctx, self.theme.fonts.ICON_FONT_SMALL)
    local collapse_arrow = self.theme.letters[self.fx.displaySettings._is_collapsed and 94 or 97]

    if reaper.ImGui_Button(self.ctx, collapse_arrow, self.default_button_size, self.default_button_size) then -- create window name button
        self.fx.displaySettings._is_collapsed = not self.fx.displaySettings._is_collapsed
    end

    reaper.ImGui_PopFont(self.ctx)
    if reaper.ImGui_IsItemHovered(self.ctx, reaper.ImGui_HoveredFlags_DelayNormal()) then
        reaper.ImGui_SetTooltip(self.ctx, "collapse fx box")
    end
end

function fx_box:AddParamsBtn()
    local popup_name = "addFxParams"

    -- "+" ICON 
    reaper.ImGui_PushFont(self.ctx, self.theme.fonts.ICON_FONT_SMALL)
    local plus = self.theme.letters[34]

    if reaper.ImGui_Button(self.ctx, plus, self.default_button_size, self.default_button_size) then -- create window name button
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
                    self.fx:createParamDetails(param)
                else
                    self.fx:removeParamDetails(param)
                end
            end
        end
        reaper.ImGui_EndPopup(self.ctx)
    end
end

function fx_box:Canvas()
    reaper.ImGui_PushStyleVar(self.ctx, reaper.ImGui_StyleVar_WindowPadding(), 2, 2)
    reaper.ImGui_PushStyleVar(self.ctx, reaper.ImGui_StyleVar_ItemSpacing(), 1, 0)

    --set background color to transparent
    reaper.ImGui_PushStyleColor(
        self.ctx,
        reaper.ImGui_Col_ChildBg(),
        0x00000000)

    if reaper.ImGui_BeginChild(self.ctx, "##paramDisplay", nil, nil, true, reaper.ImGui_WindowFlags_NoScrollbar()) then
        if self.fx.editing and not self.fx.displaySettings._is_collapsed then
            self:DrawGrid()
        end
        for idx, param in ipairs(self.fx.display_params) do
            local radius = reaper.ImGui_GetTextLineHeight(self.ctx) * 3.0 * 0.5
            if not param.details.display_settings.component then
                if param.details.display_settings.type == layoutEnums.Param_Display_Type.Knob then
                    -- if this is the first in the list and the item doesn't have any coordinates attached, set to 0, 0
                    -- if this is not the first in the list, and the doesn't have any coordinates attached, use the previous item's coordinates,
                    param.details.display_settings.component = Knob.new(
                        self.ctx,
                        "knob" .. idx,
                        param,
                        radius,
                        true,
                        function() --- on activate function
                            -- TODO refactor: move the call to new() into the fx display_param’s state.
                            -- this violates the principle of separating the view from the state,
                            -- but otherwise the newly created knob keeps on appearing as «not active» and this callback
                            -- is being called at every frame the user holds the button.
                            -- Otherwise, if we really want this to be clean, we’d have to refactor the whole
                            -- thing to instantiate each fx’s ui as classes
                            reaper.TrackFX_SetNamedConfigParm(self.state.Track.track, self.fx.index, param.name,
                                "last_touched")
                        end,
                        ColorSet.new( -- dot color
                            color_helpers.adjustBrightness(self.theme.colors.col_vuind3.color, -30),
                            self.theme.colors.col_vuind3.color,
                            color_helpers.adjustBrightness(self.theme.colors.col_vuind3.color, 50)
                        ),
                        ColorSet.new( -- track color
                            color_helpers.adjustBrightness(self.theme.colors.col_buttonbg.color, -30),
                            self.theme.colors.col_buttonbg.color,
                            color_helpers.adjustBrightness(self.theme.colors.col_buttonbg.color, 50)
                        ),
                        ColorSet.new( -- circle color
                            color_helpers.adjustBrightness(self.theme.colors.col_vuind4.color, -30),
                            self.theme.colors.col_vuind4.color,
                            color_helpers.adjustBrightness(self.theme.colors.col_vuind4.color, 50)
                        ),
                        0xFFFFFFFF -- text color
                    )
                end
            end
            if param.details.display_settings.Pos_X and param.details.display_settings.Pos_Y then
                reaper.ImGui_SetCursorPosX(self.ctx, param.details.display_settings.Pos_X)
                reaper.ImGui_SetCursorPosY(self.ctx, param.details.display_settings.Pos_Y)
            end

            local changed, new_val = param.details.display_settings.component:draw(
                Knob.KnobVariant.ableton, -- Keep ableton knob for now, though we have many more variants
                nil,
                nil,
                param
            )

            if changed then
                param.details.value = new_val
                param.details:setValue(new_val)
            end

            reaper.ImGui_SameLine(self.ctx)
            if reaper.ImGui_GetContentRegionAvail(self.ctx) < radius * 2 then
                reaper.ImGui_NewLine(self.ctx)
            end
        end
        reaper.ImGui_EndChild(self.ctx)
    end
    reaper.ImGui_PopStyleVar(self.ctx, 2)
    reaper.ImGui_PopStyleColor(self.ctx)
end

---@param fx TrackFX
function fx_box:main(fx)
    self.fx = fx
    self.displaySettings = fx.displaySettings

    local collapsed = self.fx.displaySettings._is_collapsed
    reaper.ImGui_BeginGroup(self.ctx)

    self:fxBoxStyleStart()
    if reaper.ImGui_BeginChild(self.ctx,
            fx.name,
            collapsed and 40 or self.displaySettings.window_width,
            self.displaySettings.window_height,
            true,
            winFlg)
    then
        self:BypassToggle()
        if collapsed then
            self:EditLayoutButton()
            -- self:AddParamsBtn()
            self:AddSavePresetBtn()
            self:VerticalLabelButton()
            self:CollapseButton()
        else
            reaper.ImGui_SameLine(self.ctx)
            self:EditLayoutButton()
            reaper.ImGui_SameLine(self.ctx)

            self:AddParamsBtn()
            reaper.ImGui_SameLine(self.ctx)
            self:AddSavePresetBtn()
            reaper.ImGui_SameLine(self.ctx)
            self:LabelButton()
            reaper.ImGui_SameLine(self.ctx)
            self:CollapseButton()
            self:Canvas()
        end
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
    self.default_button_size = 20
    self.LayoutEditor = parent_state.LayoutEditor
end

return fx_box
