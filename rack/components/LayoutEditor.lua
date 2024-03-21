--[[
- When an FX wants to edit layout, it calls the LayoutEditor"s `editLayout()` and passes it its state (`displaySettings`, track ID, `onClose` callbacks, etc.)
- The LayoutEditor adds the data to its state, and displays the edit window.
- The rack keeps on displaying the edited FX, but uses the `displaySettings_copy` instead of the `displaySettings`

For now, keep a single instance for the whole app.
- run it on its own defer cycle, instead of continuously calling from the app.

TBD
- Singleton or one instance per fx?
Singleton assumes that changing without saving is going to affect all instances of the same plug-in. That doesn"t have to be true.
Let"s go with one instance per fx:
- allow one un-saved layout per FX. Eeach fx can have its own look.
- If we want to persist unsaved layouts between re-starts, we"ll have to either store this in external state or in the track.

]]
local layoutEnums = require("state.fx_layout_types")
local Table = require("helpers.table")
local Palette = require("components.Palette")
local LayoutEditor = {}

---@param ctx ImGui_Context
---@param theme Theme
function LayoutEditor:init(ctx, theme)
    self.open = false
    self.ctx = ctx
    self.theme = theme
    return self
end

---display button examples from fonts
function LayoutEditor:FontButton()
    reaper.ImGui_PushFont(self.ctx, self.theme.fonts.ICON_FONT_SMALL)

    local wrench_icon = self.theme.letters[75]
    local arrow_right = self.theme.letters[97]
    local arrow_down = self.theme.letters[94]
    local saver = self.theme.letters[164]
    local kebab = self.theme.letters[191]
    local plus = self.theme.letters[34]
    reaper.ImGui_Button(self.ctx, wrench_icon)
    reaper.ImGui_Button(self.ctx, arrow_right)
    reaper.ImGui_Button(self.ctx, arrow_down)
    reaper.ImGui_Button(self.ctx, saver)
    reaper.ImGui_Button(self.ctx, kebab)
    reaper.ImGui_Button(self.ctx, plus)
    -- for i = 1, #self.theme.letters do
    --     reaper.ImGui_Button(self.ctx, self.theme.letters[i])
    -- end
    reaper.ImGui_PopFont(self.ctx)
    -- reaper.ImGui_PushFont(self.ctx, self.theme.fonts.ICON_FONT_SMALL)
    -- reaper.ImGui_DrawList_AddTextEx(draw_list, nil, self.theme.ICON_FONT_SMALL_SIZE, i_x, i_y, font_color, icon)
    -- reaper.ImGui_PopFont(self.ctx)
end

function LayoutEditor:Sketch()
    for k, v in ipairs(self.theme.colors) do
        reaper.ImGui_BeginGroup(self.ctx)
        reaper.ImGui_text(self.ctx, k)
        reaper.ImGui_colorPicker(self.ctx, v.color)
        reaper.ImGui_EndGroup(self.ctx)
    end
end

---Display button to save changes to layout or discard them.
--TODO  implement
function LayoutEditor:SaveCancelButton()
    reaper.ImGui_BeginGroup(self.ctx)
    reaper.ImGui_Button(self.ctx, "save")
    reaper.ImGui_SameLine(self.ctx)
    if reaper.ImGui_Button(self.ctx, "close") then
        self:close()
    end
    reaper.ImGui_SameLine(self.ctx)
    if reaper.ImGui_Button(self.ctx, "discard changes") then
        self.fx.displaySettings = self.displaySettings_backup
        self:close()
    end

    reaper.ImGui_EndGroup(self.ctx)
end

function LayoutEditor:AddParams()
    local all_params = false
    if reaper.ImGui_Checkbox(self.ctx, "All params", false) then
        all_params = true
    end

    -- select last touched parameter
    -- this allows the user to click a param in the fx window,
    -- and add it to the fx_box from here
    local last_touched_rv, last_touched_selected = reaper.ImGui_Selectable(
        self.ctx,
        "last touched"
    )
    if last_touched_rv and last_touched_selected then
        local retval,
        tracknumber,
        fxnumber,
        paramnumber =
            reaper.GetLastTouchedFX()
        if retval and tracknumber == self.fx.state.Track.number and fxnumber == self.fx.number then
            -- iterate through the params to find the one with the corresponding paramnumber
            for _, param in ipairs(self.fx.params_list) do
                if param.index == paramnumber then
                    self.selectedParam._selected = false
                    self.selectedParam = param
                    if not self.selectedParam.details then
                        self.selectedParam = self.fx:createParamDetails(param)
                        self.selectedParam.display = true
                    end
                    self.selectedParam._selected = true
                    goto continue
                end
            end
            ::continue::
        end
    end

    ---TODO implement text filter here, so that user can filter the fx-params" list.
    for i = 1, #self.fx.params_list - 1 do
        local param      = self.fx.params_list[i]
        local _, new_val = reaper.ImGui_Checkbox(self.ctx, "##" .. param.name, param.display)
        reaper.ImGui_SameLine(self.ctx)
        if all_params then
            param.display = true
        end
        if new_val ~= param.display then
            param.display = new_val
            if new_val then
                self.selectedParam = self.fx:createParamDetails(param)
                self.selectedParam._selected = true
            else
                self.fx:removeParamDetails(param)
            end
        end

        local rv, selected = reaper.ImGui_Selectable(
            self.ctx,
            param.name,
            self.selectedParam and param.guid == self.selectedParam.guid)
        if rv and selected then
            self.selectedParam._selected = false
            self.selectedParam = param
            self.selectedParam._selected = true
        end
    end
end

function LayoutEditor:ParamInfo()
    if not self.selectedParam then
        return
    end


    if self.selectedParam.details == nil or not self.selectedParam.details.display_settings then
        reaper.ImGui_Text(self.ctx, "This param is not enabled for display.")
        return
    end
    reaper.ImGui_Text(self.ctx, "Param Display Type")
    reaper.ImGui_BeginTable(self.ctx, "##radioBtnTable", layoutEnums.Param_Display_Type_Length)
    for type_name, type_idx in pairs(layoutEnums.Param_Display_Type) do
        reaper.ImGui_TableNextColumn(self.ctx)
        _, self.selectedParam.details.display_settings.type = reaper.ImGui_RadioButtonEx(
            self.ctx,
            type_name,
            self.selectedParam.details.display_settings.type,
            type_idx)

        reaper.ImGui_TableNextColumn(self.ctx)
    end
    reaper.ImGui_EndTable(self.ctx)

    ---TODO implement param display/selection logic
    reaper.ImGui_Text(self.ctx, self.selectedParam.name)
    reaper.ImGui_Text(self.ctx, "min " .. tostring(self.selectedParam.details.minval))
    reaper.ImGui_Text(self.ctx, "max " .. tostring(self.selectedParam.details.maxval))
    reaper.ImGui_Text(self.ctx, "mid " .. tostring(self.selectedParam.details.midval))
    reaper.ImGui_Text(self.ctx, "guid" .. self.selectedParam.guid)
    reaper.ImGui_Text(self.ctx, "val " .. tostring(self.selectedParam.details.value))
end

--- TODO Left pane to contain list of params and list of colors? or just the list of params?
function LayoutEditor:LeftPane()
    if reaper.ImGui_BeginChild(self.ctx, "left pane", 150, -25, true) then
        self:AddParams()
        reaper.ImGui_EndChild(self.ctx)
    end

    reaper.ImGui_SameLine(self.ctx)
end

--- displays a button which can be dragged around the canvas
--- and which writes its position to the selectedParam’s X and Y values
-- function LayoutEditor:Canvas()
--     if reaper.ImGui_BeginChild(self.ctx, "##canvas", nil, nil, true, reaper.ImGui_WindowFlags_NoScrollbar()) then
--         local max_x, max_y = reaper.ImGui_GetWindowContentRegionMax(self.ctx)
--         local min_x, min_y = reaper.ImGui_GetWindowContentRegionMin(self.ctx)
--         local cur_pos_x = reaper.ImGui_GetCursorPosX(self.ctx)
--         local cur_pos_y = reaper.ImGui_GetCursorPosY(self.ctx)

--         if self.selectedParam._is_active then
--             local delta_x, delta_y = reaper.ImGui_GetMouseDragDelta(
--                 self.ctx,
--                 cur_pos_x,
--                 cur_pos_y)

--             local new_pos_x = cur_pos_x + self.selectedParam.details.display_settings.Pos_X + delta_x
--             local new_pos_y = cur_pos_y + self.selectedParam.details.display_settings.Pos_Y + delta_y
--             ---clamp the values within the current frame.
--             ---TODO dunno why the frame is currently bigger than the window.
--             if new_pos_x < min_x then
--                 new_pos_x = min_x
--             elseif new_pos_x > max_x then
--                 new_pos_x = max_x
--             end
--             if new_pos_y < min_y then
--                 new_pos_y = min_y
--             elseif new_pos_y > max_y then
--                 new_pos_y = max_y
--             end

--             reaper.ImGui_SetCursorPosX(self.ctx, new_pos_x)
--             reaper.ImGui_SetCursorPosY(self.ctx, new_pos_y)

--             if delta_y ~= 0.0 and delta_x ~= 0.0 then
--                 self.selectedParam.details.display_settings.Pos_X = new_pos_x - cur_pos_x
--                 self.selectedParam.details.display_settings.Pos_Y = new_pos_y - cur_pos_y
--                 reaper.ImGui_ResetMouseDragDelta(self.ctx, reaper.ImGui_MouseButton_Left())
--             end
--         else
--             reaper.ImGui_SetCursorPosX(self.ctx, self.selectedParam.details.display_settings.Pos_X)
--             reaper.ImGui_SetCursorPosY(self.ctx, self.selectedParam.details.display_settings.Pos_Y)
--         end

--         reaper.ImGui_Button(self.ctx, "drag me")
--         local is_active = reaper.ImGui_IsItemActive(self.ctx)
--         if is_active ~= self.selectedParam._is_active then
--             self.selectedParam._is_active = is_active
--         end
--         reaper.ImGui_EndChild(self.ctx)
--     end
-- end

function LayoutEditor:RightPane()
    if not self.selectedParam or not self.selectedParam.details then
        return
    end
    reaper.ImGui_BeginGroup(self.ctx)

    self:ParamInfo()
    reaper.ImGui_Text(self.ctx, "Editing the layout!")
    self:Sketch()
    -- self:FontButton()
    reaper.ImGui_EndGroup(self.ctx)
end

function LayoutEditor:FxDisplaySettings()
    local displaySettings = self.fx.displaySettings

    -- reaper.ImGui_Text(self.ctx, "height: " .. s.height .. "")
    reaper.ImGui_Text(self.ctx, "Window_Width: ")
    reaper.ImGui_SameLine(self.ctx)
    reaper.ImGui_PushItemWidth(self.ctx, 100)
    _, displaySettings.window_width = reaper.ImGui_DragInt(self.ctx, "##width", displaySettings.window_width)
    reaper.ImGui_PopItemWidth(self.ctx)
    -- reaper.ImGui_Text(self.ctx, "Edge_Rounding: " .. s.Edge_Rounding .. "")
    -- reaper.ImGui_Text(self.ctx, "Grb_Rounding: " .. s.Grb_Rounding .. "")
    reaper.ImGui_Text(self.ctx, "Background color: ")
    reaper.ImGui_SameLine(self.ctx)
    displaySettings.background = Palette(self.ctx, self.theme, displaySettings.background, "background")

    reaper.ImGui_Text(self.ctx, "BorderColor: ")
    reaper.ImGui_SameLine(self.ctx)
    displaySettings.borderColor = Palette(self.ctx, self.theme, displaySettings.borderColor, "border")

    reaper.ImGui_Text(self.ctx, "Title_Clr: ")
    reaper.ImGui_SameLine(self.ctx)
    displaySettings.title_Clr = Palette(self.ctx, self.theme, displaySettings.title_Clr, "title")
    -- increase/decrease grid size
    if reaper.ImGui_Button(self.ctx, "Grid +") then
        self.fx.displaySettings._grid_size = math.min(60,
            self.fx.displaySettings._grid_size + 10)
    end
    reaper.ImGui_SameLine(self.ctx)
    if reaper.ImGui_Button(self.ctx, "Grid -") then
        self.fx.displaySettings._grid_size = math.max(5,
            self.fx.displaySettings._grid_size - 10)
    end
end

function LayoutEditor:Tabs()
    if reaper.ImGui_BeginChild(self.ctx, "##tabs", self.width - 20, self.height - 60, false, reaper.ImGui_WindowFlags_NoScrollbar()) then
        if reaper.ImGui_BeginTabBar(self.ctx, "##Tabs", reaper.ImGui_TabBarFlags_None()) then
            if reaper.ImGui_BeginTabItem(self.ctx, "FX layout") then
                self:FxDisplaySettings()
                reaper.ImGui_EndTabItem(self.ctx)
            end
            if reaper.ImGui_BeginTabItem(self.ctx, "Params") then
                self:LeftPane()
                self:RightPane()
                reaper.ImGui_EndTabItem(self.ctx)
            end
            reaper.ImGui_EndTabBar(self.ctx)
        end
        reaper.ImGui_EndChild(self.ctx)
    end
end

function LayoutEditor:Main()
    if not self.open then
        return
    end
    local flags = reaper.ImGui_WindowFlags_TopMost() + reaper.ImGui_WindowFlags_NoScrollbar() +
        reaper.ImGui_WindowFlags_NoCollapse()
    local visible, open = reaper.ImGui_Begin(self.ctx, self.windowLabel, true, flags) ---begin popup
    self.open = open
    if visible then
        self:Tabs()

        self:SaveCancelButton()
        reaper.ImGui_End(self.ctx)
    end
    if not visible or not open then
        self:close()
    end
    if open then
        reaper.defer(function() self:Main() end)
    end
end

--- perform clean up: call the FX"s `onClose()` and clean-up the state
---@param action? EditLayoutCloseAction
function LayoutEditor:close(action)
    if action then
        self.fx:onEditLayoutClose(action)
    end
    if self.selectedParam then
        self.selectedParam._selected = false
    end
    if self.fx then
        self.fx.editing = false
        self.fx.setSelectedParam = nil
    end
    self.open = false
    self.fx = nil
    self.displaySettings = nil
    self.displaySettings_backup = nil
end

---@param fx TrackFX
function LayoutEditor:edit(fx)
    self.fx = fx
    self.fx.setSelectedParam =
    ---@param param ParamData
        function(param)
            if self.selectedParam then
                self.selectedParam._selected = false
            end
            self.selectedParam = param
            self.selectedParam._selected = true
        end
    self.fx.editing = true
    self.displaySettings = fx.displaySettings
    self.displaySettings_backup = Table.deepCopy(fx.displaySettings)
    self.open = true
    self.windowLabel = self.fx.name .. " - " .. "Edit layout"
    self.selectedParam = self.fx.params_list[1] -- select the first param in the list by default
    self.selectedParam._selected = true
    self.width = 650
    self.height = 300
    reaper.ImGui_SetNextWindowSize(self.ctx, self.width, self.height)
    self:Main()
end

return LayoutEditor
