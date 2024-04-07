-- dofile("/home/antoine/Documents/Experiments/lua/debug_connect.lua")
--[[
This component is the display for each FX.
order of steps are:
- instantiate with init() from the parent component.
- display using the main() function

Bear in mind that this component is a singleton, so it’s a single instance that is re-used for each FX.
As a result, its internal state has to be updated every time it’s called. I’m not sure yet whether I like this or would rather have one instance per appearance.
]]
local drag_drop       = require("state.dragAndDrop")
local MainWindowStyle = require("helpers.MainWindowStyle")
local layout_enums    = require("state.layout_enums")
local Knob            = require("components.knobs.Knobs")
local CycleButton     = require("components.CycleButton")
local Slider          = require("components.Slider")
local layoutEnums     = require("state.layout_enums")
local defaults        = require("helpers.defaults")
local Decorations     = require("components.Decorations")
local fx_box          = {}
local winFlg          = reaper.ImGui_WindowFlags_NoScrollWithMouse() + reaper.ImGui_WindowFlags_NoScrollbar()
local Theme           = Theme --- localize the global

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
    -- add horizontal grid
    for i = 0, self.fx.displaySettings.window_width, self.fx.displaySettings._grid_size do
        reaper.ImGui_DrawList_AddLine(WinDrawList,
            start_x,
            start_y + i,
            end_x,
            end_y + i,
            self.fx.displaySettings._grid_color)
    end

    -- add vertical grid
    for i = 0, self.fx.displaySettings.window_width, self.fx.displaySettings._grid_size do
        reaper.ImGui_DrawList_AddLine(WinDrawList,
            start_x + i,
            start_y,
            start_x + i,
            start_y + self.fx.displaySettings.window_height,
            self.fx.displaySettings._grid_color)
    end
    -- end
end

function fx_box:fxBoxStyleEnd()
    reaper.ImGui_PopStyleColor(self.ctx, 1) -- pop the bg, button bg and border colors
end

function fx_box:labelButtonStyleStart()
    local bg_col ---@type number
    if not self.state.Track.fx_chain_enabled then
        bg_col = self.fx.displaySettings.labelButtonStyle.background_offline
    elseif self.fx.enabled then
        bg_col = self.fx.displaySettings.labelButtonStyle.background
    else
        bg_col = self.fx.displaySettings.labelButtonStyle.background_disabled
    end
    reaper.ImGui_PushStyleColor(self.ctx,
        reaper.ImGui_Col_Button(),
        bg_col) -- fx’s bg color
    local button_text_color ---@type number

    if not self.state.Track.fx_chain_enabled then
        button_text_color = self.displaySettings.labelButtonStyle.text_offline
    elseif self.fx.enabled then -- set a dark-colored text if the fx is bypassed
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
    local width, height      = reaper.ImGui_CalcTextSize(self.ctx, self.fx.display_name)
    -- invert the width and height to represent the component size
    local temp               = height
    height                   = width
    width                    = temp
    local btn_x, btn_y       = reaper.ImGui_GetCursorPos(self.ctx)

    -- fill the rest of the line with the button width
    local lineSpacing        = reaper.ImGui_GetStyleVar(self.ctx, reaper.ImGui_StyleVar_ItemSpacing())
    local lineHeightWSpacing = reaper.ImGui_GetTextLineHeightWithSpacing(self.ctx)
    local btn_height         = select(2, reaper.ImGui_GetContentRegionAvail(self.ctx)) - defaults.button_size -
        reaper.ImGui_GetStyleVar(self.ctx, lineHeightWSpacing)

    self:labelButtonStyleStart()
    if reaper.ImGui_Button(self.ctx, "##" .. self.fx.display_name, defaults.button_size, btn_height) then
        self:LabelButtonCB()
    end
    if reaper.ImGui_IsItemHovered(self.ctx) then
        reaper.ImGui_SetMouseCursor(self.ctx, reaper.ImGui_MouseCursor_Hand())
    end
    self:dragDropSource() -- attach the drag/drop source to the preceding button

    reaper.ImGui_SetCursorPosX(self.ctx, btn_x)
    reaper.ImGui_Indent(self.ctx, 5)
    reaper.ImGui_SetCursorPosY(self.ctx, btn_y)
    for k = 1, #self.fx.display_name do
        -- if there's no more space to the bottom of the window, don't display any more letters
        local _, cur_y = reaper.ImGui_GetCursorPos(self.ctx)
        if cur_y + lineHeightWSpacing > btn_y + btn_height
        then
            break
        else
            reaper.ImGui_Text(self.ctx, string.sub(self.fx.display_name, k, k))
        end
    end
    reaper.ImGui_SetCursorPosX(self.ctx, btn_x)
    reaper.ImGui_SetCursorPosY(self.ctx, btn_y + btn_height + lineSpacing / 2)
    reaper.ImGui_Unindent(self.ctx, 5)
    self:labelButtonStyleEnd()
end

function fx_box:LabelButton()
    --- either use `GetContentRegionAvail()` or `self.displaySettings.title_Width`
    local btn_width = reaper.ImGui_GetContentRegionAvail(self.ctx) - defaults.button_size -
        reaper.ImGui_GetStyleVar(self.ctx, reaper.ImGui_StyleVar_ItemSpacing())
    self:labelButtonStyleStart()
    if reaper.ImGui_Button(self.ctx, self.fx.display_name .. "##" .. self.fx.guid, btn_width, defaults.button_size) then -- create window name button
        self:LabelButtonCB()
    end
    reaper.ImGui_MouseButton_Left()

    if reaper.ImGui_IsItemHovered(self.ctx) then
        reaper.ImGui_SetMouseCursor(self.ctx, reaper.ImGui_MouseCursor_Hand())
    end
    self:labelButtonStyleEnd()
    self:dragDropSource() -- attach the drag/drop source to the preceding button
end

---Also store the button size as default button’s size.
function fx_box:EditLayoutButton()
    local wrench_icon = Theme.letters[75]
    reaper.ImGui_PushFont(self.ctx, Theme.fonts.ICON_FONT_SMALL)

    if reaper.ImGui_Button(self.ctx, wrench_icon, defaults.button_size, defaults.button_size) then -- create window name button
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
    reaper.ImGui_PushFont(self.ctx, Theme.fonts.ICON_FONT_SMALL)
    local saver = Theme.letters[164]
    if reaper.ImGui_Button(self.ctx, saver, defaults.button_size, defaults.button_size) then -- create window name button
        if not reaper.ImGui_IsPopupOpen(self.ctx, "Save Preset##presetsave") then
            reaper.ImGui_OpenPopup(self.ctx, "Save Preset##presetsave")
        end
    end
    reaper.ImGui_PopFont(self.ctx)
    if reaper.ImGui_IsItemHovered(self.ctx, reaper.ImGui_HoveredFlags_DelayNormal()) then
        reaper.ImGui_SetTooltip(self.ctx, "save fx preset")
    end

    reaper.ImGui_SetNextWindowSize(self.ctx, 300, 100)
    local PopMainWindowStyle = MainWindowStyle(self.ctx)
    self.open = reaper.ImGui_BeginPopupModal(self.ctx, "Save Preset##presetsave")
    if reaper.ImGui_IsWindowAppearing(self.ctx) then -- focus the input box when the window appears
        reaper.ImGui_SetKeyboardFocusHere(self.ctx)
    end
    if self.open then
        self.open = true
        local new_val = ""
        reaper.ImGui_Text(self.ctx, "Preset name:")
        reaper.ImGui_InputText(self.ctx, "##preset_name", new_val)
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
    PopMainWindowStyle()
end

function fx_box:CollapseButton()
    reaper.ImGui_PushFont(self.ctx, Theme.fonts.ICON_FONT_SMALL)
    local collapse_arrow = Theme.letters[self.fx.displaySettings._is_collapsed and 94 or 97]

    if reaper.ImGui_Button(self.ctx, collapse_arrow, defaults.button_size, defaults.button_size) then -- create window name button
        self.fx.displaySettings._is_collapsed = not self.fx.displaySettings._is_collapsed
    end

    reaper.ImGui_PopFont(self.ctx)
    if reaper.ImGui_IsItemHovered(self.ctx, reaper.ImGui_HoveredFlags_DelayNormal()) then
        reaper.ImGui_SetTooltip(self.ctx, "collapse fx box")
    end
end

function fx_box:AddParamsBtn()
    local popup_name = "addFxParams" .. "##" .. self.fx.guid

    -- "+" ICON 
    reaper.ImGui_PushFont(self.ctx, Theme.fonts.ICON_FONT_SMALL)
    local plus = Theme.letters[34]

    if reaper.ImGui_Button(self.ctx, plus, defaults.button_size, defaults.button_size) then -- create window name button
        if not reaper.ImGui_IsPopupOpen(self.ctx, popup_name) then
            reaper.ImGui_OpenPopup(self.ctx, popup_name)
        end
    end
    reaper.ImGui_PopFont(self.ctx)
    if reaper.ImGui_IsItemHovered(self.ctx, reaper.ImGui_HoveredFlags_DelayNormal()) then
        reaper.ImGui_SetTooltip(self.ctx, "add params to display")
    end

    local PopWindowStyle = MainWindowStyle(self.ctx)
    -- ADD PARAMS POPUP
    reaper.ImGui_SetWindowSize(self.ctx, 400, 300)
    if reaper.ImGui_BeginPopup(self.ctx, popup_name) then
        ---TODO fix this guy during fx's state updates.
        ---TODO implement text filter here, so that user can filter the fx-params' list.
        for i = 1, #self.fx.params_list - 1 do
            local param = self.fx.params_list[i]
            -- Dunno why, but some params might be registerd without a name, so we skip them.
            -- Need to investigate: ReaRack2 - LFO
            if param.name == "" then
                goto continue
            end
            local _, new_val = reaper.ImGui_Checkbox(self.ctx, param.name, param.display)
            if new_val ~= param.display then
                param.display = new_val
                if new_val then
                    self.fx:createParamDetails(param, nil)
                else
                    self.fx:removeParamDetails(param)
                end
            end
            ::continue::
        end
        reaper.ImGui_EndPopup(self.ctx)
    end
    PopWindowStyle()
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
        if self.fx.editing then
            self:DrawGrid()


            --- allow resizing the width of the box by dragging the right border
            --- sadly I can't use «is window focused» here,
            -- there are cases where the outer rack might be focused, but the inner box isn't.
            local win_width, win_height = reaper.ImGui_GetWindowSize(self.ctx)
            local cur_pos_x, cur_pos_y = reaper.ImGui_GetCursorPos(self.ctx) ---current position of the draw cursor
            ---move the cursor to the edge of the window, add the invisible button and move it back to the original position
            reaper.ImGui_SetCursorPos(self.ctx,
                win_width - 10,
                0)
            reaper.ImGui_InvisibleButton(self.ctx, "##resizeEW", 10, win_height)
            reaper.ImGui_SetCursorPos(self.ctx, cur_pos_x, cur_pos_y)
            if reaper.ImGui_IsItemHovered(self.ctx) then
                reaper.ImGui_SetMouseCursor(self.ctx, reaper.ImGui_MouseCursor_ResizeEW())
            end
            if reaper.ImGui_IsItemActive(self.ctx) then
                local delta_x, _ = reaper.ImGui_GetMouseDragDelta(self.ctx,
                    reaper.ImGui_GetCursorPosX(self.ctx),
                    reaper.ImGui_GetCursorPosY(self.ctx))

                if delta_x ~= 0.0 then
                    self.fx.displaySettings.window_width = self.fx.displaySettings.window_width + delta_x
                    reaper.ImGui_ResetMouseDragDelta(self.ctx, reaper.ImGui_MouseButton_Left())
                end
            end
        end

        -- draw the decorations after the grid, so they appear on top of it.
        if self.fx.displaySettings.decorations then
            for _, decoration in ipairs(self.fx.displaySettings.decorations) do
                Decorations.drawDecoration(self.ctx, decoration)
            end
        end

        for idx, param in ipairs(self.fx.display_params) do
            local radius = reaper.ImGui_GetTextLineHeight(self.ctx) * 3.0 * 0.5
            if not param.details.display_settings.component then
                local on_activate = function() --- on activate function
                    -- TODO refactor: move the call to new() into the fx display_param’s state.
                    -- this violates the principle of separating the view from the state,
                    -- but otherwise the newly created knob keeps on appearing as «not active» and this callback
                    -- is being called at every frame the user holds the button.
                    -- Otherwise, if we really want this to be clean, we’d have to refactor the whole
                    -- thing to instantiate each fx’s ui as classes
                    reaper.TrackFX_SetNamedConfigParm(self.state.Track.track, self.fx.index, param.name,
                        "last_touched")
                end
                if param.details.display_settings.type == layoutEnums.Param_Display_Type.Knob then
                    -- if this is the first in the list and the item doesn't have any coordinates attached, set to 0, 0
                    -- if this is not the first in the list, and the doesn't have any coordinates attached, use the previous item's coordinates,
                    param.details.display_settings.component = Knob.new(
                        self.ctx,
                        "knob" .. idx,
                        param,
                        true,
                        on_activate
                    )
                elseif param.details.display_settings.type == layoutEnums.Param_Display_Type.CycleButton then
                    param.details.display_settings.component = CycleButton.new(
                        self.ctx,
                        "cycle" .. idx,
                        param,
                        on_activate,
                        radius
                    )
                elseif param.details.display_settings.type == layoutEnums.Param_Display_Type.Slider then
                    param.details.display_settings.variant = Slider.Variant.horizontal
                    param.details.display_settings.component = Slider.new(
                        self.ctx,
                        "cycle" .. idx,
                        param,
                        on_activate
                    )
                elseif param.details.display_settings.type == layoutEnums.Param_Display_Type.vSlider then
                    param.details.display_settings.variant = Slider.Variant.vertical
                    param.details.display_settings.component = Slider.new(
                        self.ctx,
                        "cycle" .. idx,
                        param,
                        on_activate
                    )
                end
            else
                if not param.details.display_settings.x and not param.details.display_settings.y then
                    local pos_x, pos_y = reaper.ImGui_GetCursorPos(self.ctx)
                    param.details.display_settings.x = pos_x
                    param.details.display_settings.y = pos_y
                end
                local changed, new_val = param.details.display_settings.component:draw()

                if changed then
                    param.details.value = new_val
                    param.details:setValue(new_val)
                end
            end

            reaper.ImGui_SameLine(self.ctx)
            local x_avail, y_avail = reaper.ImGui_GetContentRegionAvail(self.ctx)
            local next_height = radius * 2
            local next_width = radius * 2
            if param.details.display_settings.component and param.details.display_settings.component._child_height and param.details.display_settings.component._child_width then
                next_height = param.details.display_settings.component._child_height
                next_width = param.details.display_settings.component._child_width
            end
            if x_avail < next_width then
                if y_avail < next_height then
                    -- extend size of box
                    self.fx.displaySettings.window_width = self.fx.displaySettings.window_width + next_width + 10
                    reaper.ImGui_NewLine(self.ctx)
                else
                    reaper.ImGui_SameLine(self.ctx, nil, 0)
                end
                reaper.ImGui_NewLine(self.ctx)
            end
        end
        reaper.ImGui_EndChild(self.ctx)
    end
    reaper.ImGui_PopStyleVar(self.ctx, 2)
    reaper.ImGui_PopStyleColor(self.ctx)
end

function fx_box:DryWetKnob()
    local param = self.fx.DryWetParam
    if not param or not param.details then
        return
    end
    local radius = 10
    if not param.details.display_settings.component then
        param.details.display_settings.component =
            Knob.new(
                self.ctx,
                "dry_wet" .. param.index,
                param,
                true,
                nil
            )
    else
        -- TODO when pushing the knob beyon its max value, don’t update the display
        local changed, new_val = param.details.display_settings.component:draw()
        if changed then
            param.details.value = new_val
            param.details:setValue(new_val)
        end
    end
end

---@param fx TrackFX
function fx_box:main(fx)
    self.fx = fx
    self.displaySettings = fx.displaySettings

    local collapsed = self.fx.displaySettings._is_collapsed

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
            self:AddSavePresetBtn()
            self:VerticalLabelButton()
            self:CollapseButton()
        else
            if self.fx.displaySettings.buttons_layout == layout_enums.buttons_layout.vertical then
                self:EditLayoutButton()
                self:AddSavePresetBtn()
                self:VerticalLabelButton()
                self:CollapseButton()

                reaper.ImGui_SetCursorPosX(self.ctx, 40)
                reaper.ImGui_SetCursorPosY(self.ctx,
                    0 + reaper.ImGui_GetStyleVar(self.ctx, reaper.ImGui_StyleVar_FramePadding()))
                self:Canvas()
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
                self:DryWetKnob()
                -- self:CollapseButton()
                self:Canvas()
            end
        end
        reaper.ImGui_EndChild(self.ctx)
    end
    self:fxBoxStyleEnd()

    reaper.ImGui_SameLine(self.ctx, nil, 0)
end

---@param parent_state Rack
function fx_box:init(parent_state)
    self.state = parent_state.state
    self.settings = parent_state.settings
    self.actions = parent_state.actions
    self.ctx = parent_state.ctx
    self.LayoutEditor = parent_state.LayoutEditor
end

return fx_box
