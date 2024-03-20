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
    local rv = r << 24 | g << 16 | b << 8 | a
    return rv
end

---@param hsva {[1]: number, [2]: number, [3]: number, [4]: number}
---@return {[1]: number, [2]: number, [3]: number, [4]: number}
function color_helpers.hsv2rgb(hsva)
    local h, s, v, a = hsva[1], hsva[2], hsva[3], hsva[4]
    local r, g, b

    local i = (h * 6) // 1 | 0 -- floor
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)

    i = i % 6

    if i == 0 then
        r, g, b = v, t, p
    elseif i == 1 then
        r, g, b = q, v, p
    elseif i == 2 then
        r, g, b = p, v, t
    elseif i == 3 then
        r, g, b = p, q, v
    elseif i == 4 then
        r, g, b = t, p, v
    elseif i == 5 then
        r, g, b = v, p, q
    end

    return { r, g, b, a }
end

return color_helpers
