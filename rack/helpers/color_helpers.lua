local color_helpers = {}
--
-- in order to desaturate, I want to subtract from s in hsva
-- however, already
---@param rgba integer
function color_helpers.desaturate(rgba)
    local r, g, b, _ = reaper.ImGui_ColorConvertU32ToDouble4(rgba)
    local h, s, v = reaper.ImGui_ColorConvertRGBtoHSV(r, g, b)

    r, g, b = reaper.ImGui_ColorConvertHSVtoRGB(h, s - 0.5, v)
    r = (r * 255) // 1 | 0 -- floor division
    g = (g * 255) // 1 | 0
    b = (b * 255) // 1 | 0
    local rv = r << 24 | g << 16 | b << 8 | 0xFF
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

---@param color integer
---@param amt integer
---@param no_alpha? boolean
---@return integer
function color_helpers.adjustBrightness(color, amt, no_alpha)
    local function fix_brightness(channel, delta)
        return math.min(255, math.max(0, channel + delta))
    end

    local alpha = color & 0xFF
    local blue = (color >> 8) & 0xFF
    local green = (color >> 16) & 0xFF
    local red = (color >> 24) & 0xFF

    red = fix_brightness(red, amt)
    green = fix_brightness(green, amt)
    blue = fix_brightness(blue, amt)
    alpha = no_alpha and alpha or fix_brightness(alpha, amt)

    return (alpha) | (blue << 8) | (green << 16) | (red << 24)
end

return color_helpers
