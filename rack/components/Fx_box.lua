local fx_box_helpers   = require("helpers.fx_box_helpers")
local drag_drop        = require("state.dragAndDrop")
local fx_box           = {}
local winFlg           = reaper.ImGui_WindowFlags_NoScrollWithMouse() + reaper.ImGui_WindowFlags_NoScrollbar()
local DefaultWidth     = 220
local Default_FX_Width = 200
local Width            = DefaultWidth

function fx_box:dragDropSource()
    if reaper.ImGui_BeginDragDropSource(self.ctx, reaper.ImGui_DragDropFlags_None()) then
        reaper.ImGui_SetDragDropPayload(self.ctx, drag_drop.types.drag_fx, tostring(self.fx.index))
        reaper.ImGui_EndDragDropSource(self.ctx)
    end
end

function fx_box:fxBoxStyleStart()
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_ChildBg(),
        self.theme.colors.selcol_tr2_bg.color)  -- fx’s bg color
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_Border(),
        self.theme.colors.col_gridlines2.color) -- fx box’s border color
end

function fx_box:fxBoxStyleEnd()
    reaper.ImGui_PopStyleColor(self.ctx, 2) -- pop the bg, button bg and border colors
end

function fx_box:buttonStyleStart()
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_Button(),
        self.theme.colors.col_buttonbg.color) -- fx’s bg color
    local button_text_color ---@type number

    if self.fx.enabled then -- set a dark-colored text if the fx is bypassed
        button_text_color = self.theme.colors.col_toolbar_text_on.color
    else
        button_text_color = self.theme.colors.col_tcp_textsel.color
    end
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_Text(),
        button_text_color) -- fx’s bg color
end

function fx_box:buttonStyleEnd()
    reaper.ImGui_PopStyleColor(self.ctx, 2)
end

function fx_box:toggleButton()
    local round_flag = reaper.ImGui_DrawFlags_RoundCornersAll()
    local draw_list = reaper.ImGui_GetWindowDrawList(self.ctx)
    local xs, ys = reaper.ImGui_GetCursorScreenPos(self.ctx)
    local xe, ye = xs + 20, ys + 20
    local is_enabled = reaper.TrackFX_GetEnabled(self.state.Track.track, self.fx.index - 1)


    -- reaper.ImGui_DrawList_AddRectFilled(draw_list, xs, ys, xe, ye, 0x00000000, 10,
    --     round_flag)
    -- reaper.ImGui_DrawList_AddRectFilled(draw_list, xs + 5, ys + 5, xe - 5, ye - 5, 0xFFFFFFFF, 10,
    --     round_flag)

    if reaper.ImGui_InvisibleButton(self.ctx, "##fx_toggle", 20, 20) then
        reaper.TrackFX_SetEnabled(self.state.Track.track, self.fx.index - 1,
            not is_enabled)
    end

    local button_color = is_enabled and self.theme.colors.col_toolbar_text.color or
        self.theme.colors.col_toolbar_text_on.color
    if reaper.ImGui_IsItemHovered(self.ctx) then
        button_color = button_color + self.theme.colors.col_toolbar_text.color
    end

    local circle_x_center = xs + 10
    local circle_y_center = ys + 10
    reaper.ImGui_DrawList_AddCircle(draw_list, circle_x_center, circle_y_center, 10, 0x00000FFF, nil, nil)
    reaper.ImGui_DrawList_AddCircle(draw_list, circle_x_center, circle_y_center, 8, button_color, nil, 2)

    local rect_x_start, rect_y_start = xs + 8, ys + 8
    local rect_x_end, rect_y_end = rect_x_start + 2, rect_y_start + 5

    -- reaper.ImGui_DrawList_AddRectFilled(draw_list, rect_x_start, rect_y_start, rect_x_end, rect_y_end, 0xFFFFFFFF, 10,
    --     round_flag)
    reaper.ImGui_SameLine(self.ctx, nil, 5)
end

---@param fx TrackFX
function fx_box:display(fx)
    self.fx = fx

    reaper.ImGui_BeginGroup(self.ctx)

    self:fxBoxStyleStart()

    if reaper.ImGui_BeginChild(self.ctx, fx.name, Width, DefaultWidth, true, winFlg) then ----START CHILD WINDOW
        local display_name = fx_box_helpers.getDisplayName(fx.name)                       -- get name of fx
        local btn_width = Default_FX_Width - 30
        local btn_height = 20
        fx_box:toggleButton()
        self:buttonStyleStart()
        if reaper.ImGui_Button(self.ctx, display_name, btn_width, btn_height) then        -- create window name button
            local is_remove_fx = reaper.ImGui_IsKeyDown(self.ctx, reaper.ImGui_Mod_Alt()) -- if ALT is held when clicking, remove fx
            if is_remove_fx then
                self.state:deleteFx(fx.index)
            else
                local focused_fx_idx = reaper.TrackFX_GetChainVisible(self.state.Track.track) -- if not ALT, show fx
                local show_flag = focused_fx_idx == fx.index - 1 and 0 or
                    1                                                                         -- if fxchain window is open and the fx is already focused, hide it
                reaper.TrackFX_Show(self.state.Track.track, fx.index - 1, show_flag)
            end
        end
        self:buttonStyleEnd()
        fx_box:dragDropSource()         -- attach the drag/drop source to the preceding button
        reaper.ImGui_EndChild(self.ctx) -- END CHILD WINDOW
    end
    self:fxBoxStyleEnd()
    reaper.ImGui_EndGroup(self.ctx)

    reaper.ImGui_SameLine(self.ctx, nil, 0)
end

---@param parent_state Rack
function fx_box:init(parent_state)
    self.state = parent_state.state
    self.actions = parent_state.actions
    self.ctx = parent_state.ctx
    self.theme = parent_state.theme
end

return fx_box
