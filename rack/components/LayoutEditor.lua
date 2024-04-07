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
local layout_enums    = require("state.layout_enums")
local Table           = require("helpers.table")
local Palette         = require("components.Palette")
local MainWindowStyle = require("helpers.MainWindowStyle")
local Decorations     = require("components.Decorations")
local ControlPosition = require("components.ControlPosition")
local defaults        = require("helpers.defaults")
local Theme           = Theme --- localize the global
local LayoutEditor    = {}

---@param ctx ImGui_Context
function LayoutEditor:init(ctx)
    self.open = false
    self.ctx = ctx
    return self
end

---display button examples from fonts
function LayoutEditor:FontButton()
    reaper.ImGui_PushFont(self.ctx, Theme.fonts.ICON_FONT_SMALL)

    local wrench_icon = Theme.letters[75]
    local arrow_right = Theme.letters[97]
    local arrow_down = Theme.letters[94]
    local saver = Theme.letters[164]
    local kebab = Theme.letters[191]
    local plus = Theme.letters[34]
    reaper.ImGui_Button(self.ctx, wrench_icon)
    reaper.ImGui_Button(self.ctx, arrow_right)
    reaper.ImGui_Button(self.ctx, arrow_down)
    reaper.ImGui_Button(self.ctx, saver)
    reaper.ImGui_Button(self.ctx, kebab)
    reaper.ImGui_Button(self.ctx, plus)
    -- for i = 1, #Theme.letters do
    --     reaper.ImGui_Button(self.ctx, Theme.letters[i])
    -- end
    reaper.ImGui_PopFont(self.ctx)
    -- reaper.ImGui_PushFont(self.ctx, Theme.fonts.ICON_FONT_SMALL)
    -- reaper.ImGui_DrawList_AddTextEx(draw_list, nil, Theme.ICON_FONT_SMALL_SIZE, i_x, i_y, font_color, icon)
    -- reaper.ImGui_PopFont(self.ctx)
end

function LayoutEditor:Sketch()
    for k, v in ipairs(Theme.colors) do
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
        "last touched",
        false
    )
    if last_touched_rv and last_touched_selected then
        local retval,
        tracknumber,
        fxnumber,
        paramnumber =
            reaper.GetLastTouchedFX()
        if retval and tracknumber == self.fx.state.Track.number and fxnumber == self.fx.number then
            local param = self.fx.params_list[paramnumber + 1]
            if param ~= nil then -- avoid the case where the user’s clicked the dry/wet knob, or the bypass button
                self.selectedParam._selected = false
                self.selectedParam = param
                if not self.selectedParam.details then
                    self.selectedParam = self.fx:createParamDetails(param, nil)
                    self.selectedParam.display = true
                end
                self.selectedParam._selected = true
            end
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
                self.selectedParam._selected = false
                self.selectedParam = self.fx:createParamDetails(param, nil)
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

function LayoutEditor:FlagsEdit()
    local flags = layout_enums.KnobFlags
    local current_flags = self.selectedParam.details.display_settings.flags
    if current_flags == nil then
        return
    end
    local rv_NoTitle, NoTitle = reaper.ImGui_Checkbox(self.ctx, "hide label",
        current_flags & flags.NoTitle == flags.NoTitle)
    local rv_NoValue, NoValue = reaper.ImGui_Checkbox(self.ctx, "hide value",
        current_flags & flags.NoValue == flags.NoValue)
    local rv_NoInput, NoInput = reaper.ImGui_Checkbox(self.ctx, "not controllable",
        current_flags & flags.NoInput == flags.NoInput)

    if rv_NoTitle then
        if NoTitle then
            self.selectedParam.details.display_settings.flags = self.selectedParam.details.display_settings.flags |
                flags.NoTitle
        else
            self.selectedParam.details.display_settings.flags = self.selectedParam.details.display_settings.flags &
                ~flags.NoTitle
        end
    end

    if rv_NoValue then
        if NoValue then
            self.selectedParam.details.display_settings.flags = self.selectedParam.details.display_settings.flags |
                flags.NoValue
        else
            self.selectedParam.details.display_settings.flags = self.selectedParam.details.display_settings.flags &
                ~flags.NoValue
        end
    end

    if rv_NoInput then
        if NoInput then
            self.selectedParam.details.display_settings.flags = self.selectedParam.details.display_settings.flags |
                flags.NoInput
        else
            self.selectedParam.details.display_settings.flags = self.selectedParam.details.display_settings.flags &
                ~flags.NoInput
        end
    end
end

function LayoutEditor:KnobColors()
    local component = self.selectedParam.details.display_settings.colors
    -- local component = self.selectedParam.details.display_settings.component
    if not component then return end
    reaper.ImGui_Text(self.ctx, "Dot color: ")
    reaper.ImGui_SameLine(self.ctx)
    local dot_changed, new_dot_base = Palette(self.ctx, component.dot_color.base, "knob dot##knob_dot")
    if dot_changed then
        self.selectedParam.details.display_settings.colors.dot_color:update(new_dot_base)
    end

    reaper.ImGui_Text(self.ctx, "Wiper color: ")
    reaper.ImGui_SameLine(self.ctx)
    local track_changed, new_track_base = Palette(self.ctx, component.wiper_color.base, "knob wiper##knob_wiper")
    if track_changed then
        self.selectedParam.details.display_settings.colors.wiper_color:update(new_track_base)
    end

    reaper.ImGui_Text(self.ctx, "Track color: ")
    reaper.ImGui_SameLine(self.ctx)
    local circle_changed, new_circle_base = Palette(self.ctx, component.circle_color.base, "knob track##knob_track")
    if circle_changed then
        self.selectedParam.details.display_settings.colors.circle_color:update(new_circle_base)
    end
    reaper.ImGui_Text(self.ctx, "Text color:")
    reaper.ImGui_SameLine(self.ctx)
    local text_changed, new_text_col = Palette(self.ctx, component.text_color, "knob text##knob_text")
    if text_changed then
        self.selectedParam.details.display_settings.colors.text_color = new_text_col
    end
end

function LayoutEditor:KnobVariant()
    ---TODO maybe include these in the layoutEnums file?
    local knob_variants = "wiper_knob\0wiper_dot\0wiper_only\0tick\0dot\0space\0stepped\0ableton\0readrum\0imgui\0"
    reaper.ImGui_Text(self.ctx, "Knob Variant")
    reaper.ImGui_SameLine(self.ctx)
    reaper.ImGui_PushItemWidth(self.ctx, 100)
    _, self.selectedParam.details.display_settings.variant = reaper.ImGui_Combo(self.ctx,
        "##knob_style",
        self.selectedParam.details.display_settings.variant,
        knob_variants)

    reaper.ImGui_Text(self.ctx, "Wiper Start Position")
    reaper.ImGui_SameLine(self.ctx)
    local wiper_start_variants = "left\0right\0center\0"
    _, self.selectedParam.details.display_settings.wiper_start = reaper.ImGui_Combo(self.ctx, "##wiper_start_variants",
        self.selectedParam.details.display_settings.wiper_start, wiper_start_variants)
    reaper.ImGui_PopItemWidth(self.ctx)
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
    reaper.ImGui_BeginTable(self.ctx, "##radioBtnTable", layout_enums.Param_Display_Type_Length)
    for type_name, type_idx in pairs(layout_enums.Param_Display_Type) do
        reaper.ImGui_TableNextColumn(self.ctx)
        local changed, new_type = reaper.ImGui_RadioButtonEx(
            self.ctx,
            type_name,
            self.selectedParam.details.display_settings.type,
            type_idx)
        if changed and new_type ~= self.selectedParam.details.display_settings.type then
            self.selectedParam.details.display_settings.type = new_type
            self.selectedParam.details.display_settings.component = nil
            self.selectedParam.details.display_settings = defaults.getDefaultParamDisplaySettings(
                self.selectedParam.details.steps_count, new_type)
        end

        reaper.ImGui_TableNextColumn(self.ctx)
    end
    reaper.ImGui_EndTable(self.ctx)
    ControlPosition(self.ctx,
        "position",
        self.selectedParam.details.display_settings,
        "Pos_X",
        "Pos_Y",
        self.fx.displaySettings.window_width,
        self.fx.displaySettings.window_height)
    if self.selectedParam.details.display_settings.type == layout_enums.Param_Display_Type.vSlider then
        ControlPosition(self.ctx,
            "width/height:",
            self.selectedParam.details.display_settings,
            "width",
            "height",
            self.fx.displaySettings.window_width,
            self.fx.displaySettings.window_height)
    end
    if self.selectedParam.details.display_settings.type == layout_enums.Param_Display_Type.Knob then
        self:KnobVariant()
        self:KnobColors()
    end
    self:FlagsEdit()


    ---TODO implement param display/selection logic
    reaper.ImGui_Text(self.ctx, self.selectedParam.name)
    reaper.ImGui_Text(self.ctx, "min " .. tostring(self.selectedParam.details.minval))
    reaper.ImGui_Text(self.ctx, "max " .. tostring(self.selectedParam.details.maxval))
    reaper.ImGui_Text(self.ctx, "mid " .. tostring(self.selectedParam.details.midval))
    reaper.ImGui_Text(self.ctx, "guid" .. self.selectedParam.guid)
    reaper.ImGui_Text(self.ctx, "val " .. tostring(self.selectedParam.details.value))
end

--- TODO Left pane to contain list of params and list of colors? or just the list of params?
function LayoutEditor:LeftPaneParams()
    if reaper.ImGui_BeginChild(self.ctx, "left pane params", 150, -25, true) then
        self:AddParams()
        reaper.ImGui_EndChild(self.ctx)
    end

    reaper.ImGui_SameLine(self.ctx)
end

function LayoutEditor:LeftPaneDecorations()
    if reaper.ImGui_BeginChild(self.ctx, "left pane decorations", 150, -25, true) then
        if reaper.ImGui_Selectable(self.ctx, "add decoration", false) then
            if not self.fx.displaySettings.decorations then
                self.fx.displaySettings.decorations = {}
            end
            local new_decoration = Decorations.createDecoration(self.fx)
            if self.selectedDecoration then
                self.selectedDecoration._selected = false
            end
            self.selectedDecoration = new_decoration
            self.selectedDecoration._selected = true
        end
        if not self.fx.displaySettings.decorations then goto continue end
        for idx, decoration in ipairs(self.fx.displaySettings.decorations) do
            local rv, selected = reaper.ImGui_Selectable(
                self.ctx,
                idx .. ". " .. layout_enums.DecorationLabel[decoration.type],
                self.selectedDecoration.guid == decoration.guid)
            if rv and selected then
                self.selectedDecoration._selected = false
                self.selectedDecoration = decoration
                self.selectedDecoration._selected = true
            end
        end
        ::continue::
        reaper.ImGui_EndChild(self.ctx)
    end

    reaper.ImGui_SameLine(self.ctx)
end

function LayoutEditor:RightPaneDecorations()
    if not self.selectedDecoration then
        reaper.ImGui_Text(self.ctx, "no decorations added yet!")
        return
    end
    reaper.ImGui_BeginGroup(self.ctx)

    reaper.ImGui_Text(self.ctx, "Decoration type:")
    for type_index, type_name in ipairs(layout_enums.DecorationLabel) do
        local changed, new_val = reaper.ImGui_RadioButtonEx(
            self.ctx,
            type_name,
            self.selectedDecoration.type,
            type_index)
        if changed and new_val ~= self.selectedDecoration.type then
            self.selectedDecoration.type = new_val
            -- TODO
            -- update the actual component being displayed
            -- remove any incompatible properties, and add the new ones
            Decorations.updateType(self.selectedDecoration, new_val)
        end
        if type_index < #layout_enums.DecorationLabel then
            reaper.ImGui_SameLine(self.ctx)
        end
    end


    -- add controls for decoration's position
    ControlPosition(self.ctx,
        "position",
        self.selectedDecoration,
        "Pos_X",
        "Pos_Y",
        self.fx.displaySettings.window_width,
        self.fx.displaySettings.window_height
    )

    -- add controls for decoration's color
    if self.selectedDecoration.type ~= layout_enums.DecorationType.background_image then
        reaper.ImGui_Text(self.ctx, "Color:")
        reaper.ImGui_SameLine(self.ctx)
        _, self.selectedDecoration.color = Palette(self.ctx, self.selectedDecoration.color, "color")
    end
    --
    reaper.ImGui_PushItemWidth(self.ctx, 100)

    if self.selectedDecoration.width and self.selectedDecoration.height then
        ControlPosition(self.ctx,
            "width/height:",
            self.selectedDecoration,
            "width",
            "height",
            self.fx.displaySettings.window_width,
            self.fx.displaySettings.window_height,
            self.selectedDecoration.keep_ratio
        )
    end

    -- add specific controls depending on the type of decoration
    -- text type
    if self.selectedDecoration.type == layout_enums.DecorationType.text then
        reaper.ImGui_Text(self.ctx, "Text size:")
        reaper.ImGui_SameLine(self.ctx)

        _, self.selectedDecoration.font_size = reaper.ImGui_DragInt(self.ctx, "##font_size",
            self.selectedDecoration.font_size)

        reaper.ImGui_Text(self.ctx, "Text:")
        reaper.ImGui_SameLine(self.ctx)
        _, self.selectedDecoration.text = reaper.ImGui_InputTextWithHint(self.ctx, "##text",
            "text to display", self.selectedDecoration.text)

        -- line type
    elseif self.selectedDecoration.type == layout_enums.DecorationType.line then
        ControlPosition(self.ctx,
            "position end",
            self.selectedDecoration,
            "Pos_X_end",
            "Pos_Y_end",
            self.fx.displaySettings.window_width,
            self.fx.displaySettings.window_height)
        _, self.selectedDecoration.thickness = reaper.ImGui_DragInt(
            self.ctx,
            "thickness",
            self.selectedDecoration.thickness,
            nil,
            0,
            self.fx.displaySettings.window_width,
            "%d")

        -- rectangle type
    elseif self.selectedDecoration.type == layout_enums.DecorationType.rectangle then
        reaper.ImGui_Text(self.ctx, "Rounding:")
        reaper.ImGui_SameLine(self.ctx)
        _, self.selectedDecoration.rounding = reaper.ImGui_DragDouble(self.ctx, "##rounding",
            self.selectedDecoration.rounding, 0.005, 0.0, 1.0, "%.2f")


        -- image type
    elseif self.selectedDecoration.type == layout_enums.DecorationType.background_image then
        reaper.ImGui_Text(self.ctx, "Path:")
        reaper.ImGui_SameLine(self.ctx)
        if reaper.ImGui_Button(self.ctx, "choose image") then
            local rv, file_path = reaper.GetUserFileNameForRead("", "select image", "jpg")
            if rv then
                self.selectedDecoration.path = file_path
            end
        end
        if self.selectedDecoration.path and #self.selectedDecoration.path then
            local path_width = reaper.ImGui_CalcTextSize(self.ctx, self.selectedDecoration.path)
            reaper.ImGui_PushItemWidth(self.ctx, path_width)
            _, self.selectedDecoration.path = reaper.ImGui_InputTextWithHint(
                self.ctx,
                "path to image",
                "my_image.jpg",
                self.selectedDecoration.path

            )
            reaper.ImGui_PopItemWidth(self.ctx)
        end


        _, self.selectedDecoration.keep_ratio = reaper.ImGui_Checkbox(self.ctx,
            "keep width/height ratio when resizing",
            self.selectedDecoration.keep_ratio)
    end
    reaper.ImGui_PopItemWidth(self.ctx)



    if reaper.ImGui_Button(self.ctx, "delete decoration") then
        for k, v in ipairs(self.fx.displaySettings.decorations) do
            if v.guid == self.selectedDecoration.guid then
                table.remove(self.fx.displaySettings.decorations, k)

                break
            end
        end
        -- set selected decoration to first in list or nil if there's no more elements in list
        if #self.fx.displaySettings.decorations then
            self.selectedDecoration = self.fx.displaySettings.decorations[1]
        else
            self.selectedDecoration = nil
        end
    end
    reaper.ImGui_EndGroup(self.ctx)
end

function LayoutEditor:RightPaneParams()
    if not self.selectedParam then
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
    reaper.ImGui_Text(self.ctx, "Window_Width: ")
    reaper.ImGui_SameLine(self.ctx)
    reaper.ImGui_PushItemWidth(self.ctx, 100)
    _, self.fx.displaySettings.window_width = reaper.ImGui_DragInt(self.ctx, "##width",
        self.fx.displaySettings.window_width)

    if reaper.ImGui_IsItemHovered(self.ctx) then
        reaper.ImGui_SetMouseCursor(self.ctx, reaper.ImGui_MouseCursor_ResizeEW())
    end
    reaper.ImGui_PopItemWidth(self.ctx)
    -- reaper.ImGui_Text(self.ctx, "Edge_Rounding: " .. s.Edge_Rounding .. "")
    -- reaper.ImGui_Text(self.ctx, "Grb_Rounding: " .. s.Grb_Rounding .. "")
    reaper.ImGui_Text(self.ctx, "Background color: ")
    reaper.ImGui_SameLine(self.ctx)
    _, self.fx.displaySettings.background = Palette(self.ctx, self.fx.displaySettings.background, "background")

    reaper.ImGui_Text(self.ctx, "BorderColor: ")
    reaper.ImGui_SameLine(self.ctx)
    _, self.fx.displaySettings.borderColor = Palette(self.ctx, self.fx.displaySettings.borderColor, "border")
    reaper.ImGui_Text(self.ctx, "Title_Clr: ")
    reaper.ImGui_SameLine(self.ctx)
    _, self.fx.displaySettings.title_Clr = Palette(self.ctx, self.fx.displaySettings.title_Clr, "title")


    reaper.ImGui_SeparatorText(self.ctx, "Buttons Bar Layout")
    -- vertical or horizontal buttons bar
    _, self.fx.displaySettings.buttons_layout = reaper.ImGui_RadioButtonEx(
        self.ctx,
        "horizontal",
        self.fx.displaySettings.buttons_layout,
        layout_enums.buttons_layout.horizontal)
    _, self.fx.displaySettings.buttons_layout = reaper.ImGui_RadioButtonEx(
        self.ctx,
        "vertical",
        self.fx.displaySettings.buttons_layout,
        layout_enums.buttons_layout.vertical)

    reaper.ImGui_SeparatorText(self.ctx, "Display Title as: ")
    --fx name
    --preset name
    --custom name
    _, self.fx.displaySettings.title_display = reaper.ImGui_RadioButtonEx(
        self.ctx,
        "fx name",
        self.fx.displaySettings.title_display,
        layout_enums.Title_Display_Style.fx_name)

    _, self.fx.displaySettings.title_display = reaper.ImGui_RadioButtonEx(
        self.ctx,
        "preset name",
        self.fx.displaySettings.title_display,
        layout_enums.Title_Display_Style.preset_name)

    _, self.fx.displaySettings.title_display = reaper.ImGui_RadioButtonEx(
        self.ctx,
        "custom title",
        self.fx.displaySettings.title_display,
        layout_enums.Title_Display_Style.custom_title)
    reaper.ImGui_SameLine(self.ctx)
    _, self.fx.displaySettings.custom_Title = reaper.ImGui_InputTextWithHint(self.ctx, "##custom_title" .. self.fx.guid,
        self.fx.name, self.fx.displaySettings.custom_Title)

    _, self.fx.displaySettings.title_display = reaper.ImGui_RadioButtonEx(
        self.ctx,
        "fx instance name",
        self.fx.displaySettings.title_display,
        layout_enums.Title_Display_Style.fx_instance_name)





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

---@param ctx ImGui_Context
---@param label "FX layout"|"Params"|"Decorations"
---@param p_open? boolean
---@param flags? integer
function LayoutEditor:Tab(ctx, label, p_open, flags)
    if label == "FX layout" and not self._tab_text_fx then
        self._tab_text_fx = Theme.colors.genlist_selfg.color
    elseif label == "Params" and not self._tab_text_params then
        self._tab_text_params = Theme.colors.genlist_selfg.color
    elseif label == "Decorations" and not self._tab_text_decorations then
        self._tab_text_decorations = Theme.colors.genlist_selfg.color
    end
    if label == "FX layout" then
        reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_Text(), self._tab_text_fx)
    elseif label == "Params" then
        reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_Text(), self._tab_text_params)
    else
        reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_Text(), self._tab_text_decorations)
    end

    local rv = reaper.ImGui_BeginTabItem(ctx, label, p_open, flags)

    if rv then
        if label == "FX layout" then
            self._tab_text_fx = Theme.colors.genlist_selfg.color
        elseif label == "Params" then
            self._tab_text_params = Theme.colors.genlist_selfg.color
        else
            self._tab_text_decorations = Theme.colors.genlist_selfg.color
        end
    else
        if label == "FX layout" then
            self._tab_text_fx = Theme.colors.genlist_fg.color
        elseif label == "Params" then
            self._tab_text_params = Theme.colors.genlist_fg.color
        else
            self._tab_text_decorations = Theme.colors.genlist_fg.color
        end
    end
    reaper.ImGui_PopStyleColor(self.ctx, 1)
    return rv
end

function LayoutEditor:Tabs()
    local win_width, win_height = reaper.ImGui_GetWindowSize(self.ctx)

    if reaper.ImGui_BeginChild(self.ctx, "##tabs", win_width - 20, win_height - 60, false) then
        if reaper.ImGui_BeginTabBar(self.ctx, "##Tabs", reaper.ImGui_TabBarFlags_None()) then
            if self:Tab(self.ctx, "FX layout") then
                self:FxDisplaySettings()
                reaper.ImGui_EndTabItem(self.ctx)
            end
            if self:Tab(self.ctx, "Params") then
                self:LeftPaneParams()
                self:RightPaneParams()
                reaper.ImGui_EndTabItem(self.ctx)
            end
            if self:Tab(self.ctx, "Decorations") then
                reaper.ImGui_Text(self.ctx, "Decorations")
                self:LeftPaneDecorations()
                self:RightPaneDecorations()
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

    local PopMainWindowStyle = MainWindowStyle(self.ctx)
    local visible, open = reaper.ImGui_Begin(self.ctx, self.windowLabel, true, flags) ---begin popup
    self.open = open
    if visible then
        self:Tabs()

        self:SaveCancelButton()

        reaper.ImGui_End(self.ctx)
    end
    PopMainWindowStyle()
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
    if self.selectedDecoration then
        self.selectedDecoration._selected = false
    end
    if self.fx then
        self.fx.editing = false
        self.fx.setSelectedParam = nil
        self.fx.setSelectedDecoration = nil
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

    self.fx.setSelectedDecoration =
        function(decoration)
            if self.selectedDecoration then
                self.selectedDecoration._selected = false
            end
            self.selectedDecoration = decoration
            self.selectedDecoration._selected = true
        end
    self.fx.editing = true
    self.displaySettings = fx.displaySettings
    self.displaySettings_backup = Table.deepCopy(fx.displaySettings)
    self.open = true
    self.windowLabel = self.fx.name .. " - " .. "Edit layout"
    -- select the first param being displayed , or the first param in the list by default.
    for _, v in ipairs(self.fx.params_list) do
        if v.details then
            self.selectedParam = v
            goto continue
        end
    end
    ::continue::
    if not self.selectedParam then
        self.selectedParam = self.fx.params_list[1]
    end
    self.selectedParam._selected = true
    if not self.selectedDecoration and self.fx.displaySettings.decorations and #self.fx.displaySettings.decorations > 0 then
        self.selectedDecoration = self.fx.displaySettings.decorations[1]
        self.selectedDecoration._selected = true
    end
    self.width = 825
    self.height = 400
    reaper.ImGui_SetNextWindowSize(self.ctx, self.width, self.height)
    self:Main()
end

return LayoutEditor
