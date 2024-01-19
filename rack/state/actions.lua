--- Actions is a table containing the state of the mouse buttons
local actions = {}
local r = reaper

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

---@param ctx ImGui_Context
---@param Track Track
function actions:init(ctx, Track)
    self.ctx   = ctx
    self.Track = Track
    self.dock  = false ---@type boolean|nil
    return self
end

return actions
