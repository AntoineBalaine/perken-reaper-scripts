local color_helpers = {}
--
-- in order to desaturate, I want to subtract from s in hsva
-- however, already
---@param rgba integer
function color_helpers.desaturate(rgba)
    local r, g, b, a = reaper.ImGui_ColorConvertU32ToDouble4(rgba)
    local h, s, v = reaper.ImGui_ColorConvertRGBtoHSV(r, g, b)

    r, g, b = reaper.ImGui_ColorConvertHSVtoRGB(h, s - 0.5, v)
    r = (r * 255) // 1 | 0 -- floor division
    g = (g * 255) // 1 | 0
    b = (b * 255) // 1 | 0
    local rv = r << 24 | g << 16 | b << 8 | 0xFF
    return rv
end

return color_helpers
