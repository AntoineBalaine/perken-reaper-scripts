---@class ColorSet
---@field base integer
---@field hovered integer
---@field active integer
---@field text? integer
local ColorSet = {}

---@param base integer
---@param hovered integer
---@param active integer
---@param text? integer
---@return ColorSet
function ColorSet.new(base, hovered, active, text)
    local self = setmetatable({}, { __index = ColorSet })
    self.base = base
    self.hovered = hovered
    self.active = active
    if text then
        self.text = text
    end
    return self
end

---@param color integer
---@return ColorSet
function ColorSet.from(color)
    return ColorSet.new(color, color, color)
end

return ColorSet
