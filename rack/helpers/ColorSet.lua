---@class ColorSet
---@field base integer
---@field hovered integer
---@field active integer

local ColorSet = {}

---@param base integer
---@param hovered integer
---@param active integer
---@return ColorSet
function ColorSet.new(base, hovered, active)
    local self = setmetatable({}, { __index = ColorSet })
    self.base = base
    self.hovered = hovered
    self.active = active
    return self
end

---@param color integer
---@return ColorSet
function ColorSet.from(color)
    return ColorSet.new(color, color, color)
end

---@return ColorSet
function ColorSet.deAlpha(colorset)
    return {
        base = colorset.base & 0x55,
        hovered = colorset.hovered & 0x55,
        active = colorset.active & 0x55,
    }
end

return ColorSet
