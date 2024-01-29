local fx_box_helpers = require("helpers.fx_box_helpers")
local drag_drop = require("state.dragAndDrop")
local fx_box = {}
local winFlg = reaper.ImGui_WindowFlags_NoScrollWithMouse() + reaper.ImGui_WindowFlags_NoScrollbar()
local DefaultWidth = 220
local Default_FX_Width = 200
local Width = DefaultWidth
local BG_COL = 0x151515ff
local CLR_BtwnFXs_Btn_Hover = 0x77777744
local CLR_BtwnFXs_Btn_Active = 0x777777aa

function fx_box:dragDropSource()
    if reaper.ImGui_BeginDragDropSource(self.ctx, reaper.ImGui_DragDropFlags_None()) then
        reaper.ImGui_SetDragDropPayload(self.ctx, drag_drop.types.drag_fx, tostring(self.fx.number))
        reaper.ImGui_EndDragDropSource(self.ctx)
    end
end

---@param fx TrackFX
function fx_box:display(fx)
    self.fx = fx

    local is_first = fx.index == 1

    reaper.ImGui_BeginGroup(self.ctx)

    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_ChildBg(), BG_COL)

    if reaper.ImGui_BeginChild(self.ctx, fx.name, Width, 220, nil, winFlg) then ----START CHILD WINDOW
        local display_name = fx_box_helpers.getDisplayName(fx.name)             -- get name of fx
        local btn_width = Default_FX_Width - 30
        local btn_height = 20
        if reaper.ImGui_Button(self.ctx, display_name, btn_width, btn_height) then        -- create window name button
            local is_remove_fx = reaper.ImGui_IsKeyDown(self.ctx, reaper.ImGui_Mod_Alt()) -- if ALT is held when clicking, remove fx
            if is_remove_fx then                                                          -- FIXME : state doesn’t update when removing fx
                reaper.TrackFX_Delete(self.state.Track.track, fx.index - 1)
            else
                local focused_fx_idx = reaper.TrackFX_GetChainVisible(self.state.Track.track) -- if not ALT, show fx
                local show_flag = focused_fx_idx == fx.index - 1 and 0 or
                    1                                                                         -- if fxchain window is open and the fx is already focused, hide it
                reaper.TrackFX_Show(self.state.Track.track, fx.index - 1, show_flag)
            end
        end

        fx_box:dragDropSource()         -- attach the drag/drop source to the preceding button
        reaper.ImGui_EndChild(self.ctx) -- END CHILD WINDOW
    end
    reaper.ImGui_PopStyleColor(self.ctx)
    reaper.ImGui_EndGroup(self.ctx)

    reaper.ImGui_SameLine(self.ctx, nil, 5)
end

---@param parent_state Rack
function fx_box:init(parent_state)
    self.state = parent_state.state
    self.actions = parent_state.actions
    self.ctx = parent_state.ctx
end

return fx_box
