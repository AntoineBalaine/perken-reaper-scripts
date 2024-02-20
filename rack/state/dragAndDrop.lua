--[[
list of drag and drop types.
This is used as an enum throughout the app.
]]

local drag_drop = {}

---@enum DragDropType
drag_drop.types = {
    add_fx = "add_fx",
    move_fx = "move_fx",
    drag_fx = "drag_fx",
    plink = "fx_plink",
}

return drag_drop
