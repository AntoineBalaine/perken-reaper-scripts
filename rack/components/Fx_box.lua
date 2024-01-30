local ThemeReader            = require("themeReader.theme_read")
local fx_box_helpers         = require("helpers.fx_box_helpers")
local drag_drop              = require("state.dragAndDrop")
local fx_box                 = {}
local winFlg                 = reaper.ImGui_WindowFlags_NoScrollWithMouse() + reaper.ImGui_WindowFlags_NoScrollbar()
local DefaultWidth           = 220
local Default_FX_Width       = 200
local Width                  = DefaultWidth

function fx_box:dragDropSource()
    if reaper.ImGui_BeginDragDropSource(self.ctx, reaper.ImGui_DragDropFlags_None()) then
        reaper.ImGui_SetDragDropPayload(self.ctx, drag_drop.types.drag_fx, tostring(self.fx.index))
        reaper.ImGui_EndDragDropSource(self.ctx)
    end
end

---@param fx TrackFX
function fx_box:display(fx)
    self.fx = fx

    reaper.ImGui_BeginGroup(self.ctx)


    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_ChildBg(),
        ThemeReader.IntToRgba(self.theme.colors.selcol_tr2_bg.color))                                                                -- fx’s bg color
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_Border(),
        ThemeReader.IntToRgba(self.theme.colors.col_gridlines2.color))                                                               -- fx box’s border color

    if reaper.ImGui_BeginChild(self.ctx, fx.name, Width, DefaultWidth, true, winFlg) then                                            ----START CHILD WINDOW
        local display_name = fx_box_helpers.getDisplayName(fx.name)                                                                  -- get name of fx
        local btn_width = Default_FX_Width - 30
        local btn_height = 20
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

        fx_box:dragDropSource()             -- attach the drag/drop source to the preceding button
        reaper.ImGui_EndChild(self.ctx)     -- END CHILD WINDOW
    end
    reaper.ImGui_PopStyleColor(self.ctx, 2) -- pop the bg and border colors
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
