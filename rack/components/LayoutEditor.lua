--[[
- When an FX wants to edit layout, it calls the LayoutEditor's `editLayout()` and passes it its state (`displaySettings_copy`, track ID, `onClose` callbacks, etc.)
- The LayoutEditor adds the data to its state, and displays the edit window.
- The rack keeps on displaying the edited FX, but uses the `displaySettings_copy` instead of the `displaySettings`

For now, keep a single instance for the whole app.
- run it on its own defer cycle, instead of continuously calling from the app.

TBD
- Singleton or one instance per fx?
Singleton assumes that changing without saving is going to affect all instances of the same plug-in. That doesn't have to be true.
Let's go with one instance per fx:
- allow one un-saved layout per FX. Eeach fx can have its own look.
- If we want to persist unsaved layouts between re-starts, we'll have to either store this in external state or in the track.

]]
local layoutEnums = require("state.fx_layout_types")
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
    if reaper.ImGui_Button(self.ctx, "cancel") then
        self.open = false
    end

    reaper.ImGui_EndGroup(self.ctx)
end

function LayoutEditor:AddParams()
    local all_params = false
    if reaper.ImGui_Checkbox(self.ctx, "All params", false) then
        all_params = true
    end
    ---TODO implement text filter here, so that user can filter the fx-params' list.
    for i = 1, #self.fx.params_list - 1 do
        ---@class ParamData
        local param      = self.fx.params_list[i]
        local _, new_val = reaper.ImGui_Checkbox(self.ctx, "##" .. param.name, param.display)
        reaper.ImGui_SameLine(self.ctx)
        if all_params then
            param.display = true
        end
        if new_val ~= param.display then
            param.display = new_val
            if new_val then
                self.selectedParam = self.fx:createParamDetails(param.guid)
            else
                self.fx:removeParamDetails(param.guid)
            end
        end

        local _, selected = reaper.ImGui_Selectable(
            self.ctx,
            param.name,
            self.selectedParam and param.guid == self.selectedParam.guid)
        if selected then
            self.selectedParam = param
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
    if reaper.ImGui_BeginChild(self.ctx, 'left pane', 150, -25, true) then
        self:AddParams()
        reaper.ImGui_EndChild(self.ctx)
    end

    reaper.ImGui_SameLine(self.ctx)
end

function LayoutEditor:RightPane()
    if not self.selectedParam or not self.selectedParam.details then
        return
    end
    reaper.ImGui_BeginGroup(self.ctx)

    self:ParamInfo()
    -- reaper.ImGui_Text(self.ctx, "Editing the layout!")
    -- self:Sketch()
    -- self:FontButton()
    reaper.ImGui_BeginChild(self.ctx, "##canvas", nil, nil, true, reaper.ImGui_WindowFlags_NoScrollbar())

    local max_x, max_y = reaper.ImGui_GetWindowContentRegionMax(self.ctx)
    local min_x, min_y = reaper.ImGui_GetWindowContentRegionMin(self.ctx)
    local cur_pos_x = reaper.ImGui_GetCursorPosX(self.ctx)
    local cur_pos_y = reaper.ImGui_GetCursorPosY(self.ctx)

    if self.selectedParam._is_active then
        local delta_x, delta_y = reaper.ImGui_GetMouseDragDelta(
            self.ctx,
            cur_pos_x,
            cur_pos_y)

        local new_pos_x = cur_pos_x + self.selectedParam.details.display_settings.Pos_X + delta_x
        local new_pos_y = cur_pos_y + self.selectedParam.details.display_settings.Pos_Y + delta_y
        ---clamp the values within the current frame.
        ---TODO dunno why the frame is currently bigger than the window.
        if new_pos_x < min_x then
            new_pos_x = min_x
        elseif new_pos_x > max_x then
            new_pos_x = max_x
        end
        if new_pos_y < min_y then
            new_pos_y = min_y
        elseif new_pos_y > max_y then
            new_pos_y = max_y
        end

        reaper.ImGui_SetCursorPosX(self.ctx, new_pos_x)
        reaper.ImGui_SetCursorPosY(self.ctx, new_pos_y)

        if delta_y ~= 0.0 and delta_x ~= 0.0 then
            self.selectedParam.details.display_settings.Pos_X = new_pos_x - cur_pos_x
            self.selectedParam.details.display_settings.Pos_Y = new_pos_y - cur_pos_y
            reaper.ImGui_ResetMouseDragDelta(self.ctx, reaper.ImGui_MouseButton_Left())
        end
    else
        reaper.ImGui_SetCursorPosX(self.ctx, self.selectedParam.details.display_settings.Pos_X)
        reaper.ImGui_SetCursorPosY(self.ctx, self.selectedParam.details.display_settings.Pos_Y)
    end

    reaper.ImGui_Button(self.ctx, "drag me")
    local is_active = reaper.ImGui_IsItemActive(self.ctx)
    if is_active ~= self.selectedParam._is_active then
        self.selectedParam._is_active = is_active
    end
    reaper.ImGui_EndChild(self.ctx)
    reaper.ImGui_EndGroup(self.ctx)
end

function LayoutEditor:Main()
    if not self.open then
        return
    end

    reaper.ImGui_SetNextWindowSize(self.ctx, 650, 300)
    local flags = reaper.ImGui_WindowFlags_TopMost() + reaper.ImGui_WindowFlags_NoScrollbar()
    local visible, open = reaper.ImGui_Begin(self.ctx, self.windowLabel, true, flags) ---begin popup
    self.open = open
    if visible then
        self:LeftPane()
        self:RightPane()

        self:SaveCancelButton()
        reaper.ImGui_End(self.ctx)
    end
    if open then
        reaper.defer(function() self:Main() end)
    end
end

---@param action EditLayoutCloseAction
function LayoutEditor:close(action)
    -- perform clean up: call the FX's `onClose()` and clean-up the state
    self.fx:onEditLayoutClose(action)
    self.open = false
    self.fx = nil
    self.displaySettings = nil
end

---@param fx TrackFX
function LayoutEditor:edit(fx)
    self.fx = fx
    self.displaySettings = fx.displaySettings_copy
    self.open = true
    self.windowLabel = self.fx.name .. self.fx.index .. " - Layout Editor"
    self.selectedParam = self.fx.params_list[1] -- select the first param in the list by default
    self:Main()
end

return LayoutEditor
