--- Actions is a table containing the state of the mouse buttons
local actions = {}
local r = reaper

---Retrieve all of the user's mouse movements
function actions:update()
    self.isAnyMouseDown         = r.ImGui_IsAnyMouseDown(self.ctx)
    self.IsLeftClicked          = r.ImGui_IsMouseClicked(self.ctx, 0)       --- left mouse button
    self.IsLeftHeld             = r.ImGui_IsMouseDown(self.ctx, 0)          --- left mouse button
    self.IsRightClicked         = r.ImGui_IsMouseClicked(self.ctx, 1)       --- right mouse button
    self.IsRightHeld            = r.ImGui_IsMouseDown(self.ctx, 1)          --- right mouse button
    self.LeftClickCount         = r.ImGui_GetMouseClickedCount(self.ctx, 0) --- left mouse button
    self.LeftDoubleClick        = r.ImGui_IsMouseDoubleClicked(self.ctx, 0) --- left mouse button
    self.LeftDrag               = r.ImGui_IsMouseDragging(self.ctx, 0)      --- left mouse button
    self.LeftReleased           = r.ImGui_IsMouseReleased(self.ctx, 0)      --- left mouse button
    self.Left_MouseDownDuration = r.ImGui_GetMouseDownDuration(self.ctx, 0) --- left mouse button
    self.RightReleased          = r.ImGui_IsMouseReleased(self.ctx, 1)      --- right mouse button
end

---Determine wether or not to dock the window
function actions:manageDock()
    if self.actions.dock ~= nil then                       -- if the user clicked «dock» or «undock»
        if self.actions.dock then
            reaper.ImGui_SetNextWindowDockID(self.ctx, -1) -- set to docked
            self.actions.dock = nil
        else
            reaper.ImGui_SetNextWindowDockID(self.ctx, 0) -- set to undocked
            self.actions.dock = nil
        end
    end
end

---@param ctx ImGui_Context
---@param Track Track
function actions:init(ctx, Track)
    self.ctx   = ctx
    self.Track = Track
    self.dock  = false ---@type boolean|nil
    return self
end

return actions
