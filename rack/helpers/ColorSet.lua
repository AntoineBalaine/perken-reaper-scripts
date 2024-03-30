local color_helpers = require("helpers.color_helpers")
---@class ColorSet
---@field base integer
---@field hovered integer
---@field active integer

local ColorSet = {}

---@param base integer
---@return ColorSet
function ColorSet.new(base)
    local self = setmetatable({}, { __index = ColorSet })

    self.hovered = color_helpers.adjustBrightness(base, -30)
    self.base = base
    self.active = color_helpers.adjustBrightness(base, 50)
    return self
end

function ColorSet:update(new_base)
    self.hovered = color_helpers.adjustBrightness(new_base, -30)
    self.base = new_base
    self.active = color_helpers.adjustBrightness(new_base, 50)
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
