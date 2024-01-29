local fx_box_helpers = require("helpers.fx_box_helpers")
local drag_drop = require("state.dragAndDrop")
local fx_box = {}
local r = reaper
local winFlg = r.ImGui_WindowFlags_NoScrollWithMouse() + r.ImGui_WindowFlags_NoScrollbar()
local DefaultWidth = 220
local Default_FX_Width = 200
local Width = DefaultWidth
local BG_COL = 0x151515ff
local CLR_BtwnFXs_Btn_Hover = 0x77777744
local CLR_BtwnFXs_Btn_Active = 0x777777aa

--- call from fx_box:display() to insert spaces between fx windows,
--- display the fx browser, and drag and drop fx
function fx_box:spaceBtwFx()
    local ctx = self.ctx
    fx_box:dragDropTarget()
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonHovered(), CLR_BtwnFXs_Btn_Hover)
    r.ImGui_PushStyleColor(ctx, r.ImGui_Col_ButtonActive(), CLR_BtwnFXs_Btn_Active)

    if r.ImGui_Button(ctx, '##Button between Windows', 20, 220) then
        --- DISPLAY FX BROWSER
    end

    r.ImGui_PopStyleColor(ctx, 2)

    r.ImGui_SameLine(ctx, nil, 5)
end

function fx_box:dragDropTarget()
    if r.ImGui_BeginDragDropTarget(self.ctx) then
        Rv, Payload = r.ImGui_AcceptDragDropPayload(self.ctx, drag_drop.types.drag_fx)
        if Rv then
            reaper.ShowConsoleMsg("works!")
        end
        r.ImGui_EndDragDropTarget(self.ctx)
    end
end

function fx_box:dragDropSource()
    ----==  Drag and drop----
    if r.ImGui_BeginDragDropSource(self.ctx, r.ImGui_DragDropFlags_AcceptNoDrawDefaultRect()) then
        local fx_guid = self.state.Track.last_fx.guid
        r.ImGui_SetDragDropPayload(self.ctx, drag_drop.types.drag_fx, fx_guid)
        r.ImGui_EndDragDropSource(self.ctx)
        local DragDroppingFX = true
        if not self.actions.isAnyMouseDown then
            DragDroppingFX = false
        end
    end

    if self.actions.isAnyMouseDown == false and DragDroppingFX == true then
        DragDroppingFX = false
    end

    ----Drag and drop END----
end

---@param fx TrackFX
function fx_box:display(fx)
    self.fx = fx

    local is_first = fx.index == 1
    if is_first then
        self:spaceBtwFx() -- since we're adding space after each fx, let's also have that zone before the first fx
    end

    r.ImGui_BeginGroup(self.ctx)

    r.ImGui_PushStyleColor(self.ctx, r.ImGui_Col_ChildBg(), BG_COL)

    if r.ImGui_BeginChild(self.ctx, fx.name, Width, 220, nil, winFlg) then ----START CHILD WINDOW
        fx_box:dragDropSource()
        local display_name = fx_box_helpers.getDisplayName(fx.name)
        local btn_width = Default_FX_Width - 30
        local btn_height = 20
        r.ImGui_Button(self.ctx, display_name, btn_width, btn_height) -- create window name button
        r.ImGui_EndChild(self.ctx)                                    -- END CHILD WINDOW
    end
    r.ImGui_PopStyleColor(self.ctx)
    r.ImGui_EndGroup(self.ctx)

    r.ImGui_SameLine(self.ctx, nil, 5)
    self:spaceBtwFx() -- add a space between fx windows after each effect
end

---@param parent_state Rack
function fx_box:init(parent_state)
    self.state = parent_state.state
    self.actions = parent_state.actions
    self.ctx = parent_state.ctx
end

return fx_box
