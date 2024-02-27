---This is a port of imgui-rs-knobs
--https://github.com/DGriffin91/imgui-rs-knobs

local function rgbToHex(rgba)
    local r = math.floor(rgba[1] * 255)
    local g = math.floor(rgba[2] * 255)
    local b = math.floor(rgba[3] * 255)
    local a = math.floor(rgba[4] * 255)
    local hex = r << 24 | g << 16 | b << 8 | a
    return hex
end

---@class ColorSet
---@field base {[1]: number,[2]: number,[3]: number,[4]: number}
---@field hovered {[1]: number,[2]: number,[3]: number,[4]: number}
---@field active {[1]: number,[2]: number,[3]: number,[4]: number}
local ColorSet = {}

---@param base {[1]: number,[2]: number,[3]: number,[4]: number}
---@param hovered {[1]: number,[2]: number,[3]: number,[4]: number}
---@param active {[1]: number,[2]: number,[3]: number,[4]: number}
---@return ColorSet
function ColorSet.new(base, hovered, active)
    local self = setmetatable({}, { __index = ColorSet })
    self.base = base
    self.hovered = hovered
    self.active = active
    return self
end

---@param color {[1]: number,[2]: number,[3]: number,[4]: number}
---@return ColorSet
function ColorSet.from(color)
    return ColorSet.new(color, color, color)
end

---@class Knob
local Knob = {}



---@param size number
---@param radius number
---@param angle number
---@param color ColorSet
---@param filled boolean
---@param segments integer
function Knob:__draw_dot(
    size,
    radius,
    angle,
    color,
    filled,
    segments
)
    local dot_size = size * self._radius
    local dot_radius = radius * self._radius
    local circle_color

    if self._is_active then
        circle_color = color.active
    elseif self._is_hovered then
        circle_color = color.hovered
    else
        circle_color = color.base
    end
    if filled then
        reaper.ImGui_DrawList_AddCircleFilled(
            self._draw_list,
            self._center_x + math.cos(angle) * dot_radius,
            self._center_y + math.sin(angle) * dot_radius,
            dot_size,
            rgbToHex(circle_color),
            segments
        )
    else
        reaper.ImGui_DrawList_AddCircle(
            self._draw_list,
            self._center_x + math.cos(angle) * dot_radius,
            self._center_y + math.sin(angle) * dot_radius,
            dot_size,
            rgbToHex(circle_color),
            segments
        )
    end
end

---@param start number
---@param end_ number
---@param width number
---@param angle number
---@param color ColorSet
function Knob:__draw_tick(start, end_, width, angle, color)
    local tick_start = start * self._radius
    local tick_end = end_ * self._radius
    local angle_cos = math.cos(angle)
    local angle_sin = math.sin(angle)

    local line_color
    if self._is_active then
        line_color = color.active
    elseif self._is_hovered then
        line_color = color.hovered
    else
        line_color = color.base
    end

    reaper.ImGui_DrawList_AddLine(
        self._draw_list,
        self._center_x + angle_cos * tick_end,
        self._center_y + angle_sin * tick_end,
        self._center_x + angle_cos * tick_start,
        self._center_y + angle_sin * tick_start,
        rgbToHex(line_color),
        width * self._radius
    )
end

---@param size number
---@param color ColorSet
---@param filled boolean
---@param segments integer
function Knob:__draw_circle(size, color, filled, segments)
    local circle_radius = size * self._radius

    local circle_color
    if self._is_active then
        circle_color = color.active
    elseif self._is_hovered then
        circle_color = color.hovered
    else
        circle_color = color.base
    end
    if filled then
        reaper.ImGui_DrawList_AddCircleFilled(
            self._draw_list,
            self._center_x,
            self._center_y,
            circle_radius,
            rgbToHex(circle_color),
            segments
        )
    else
        reaper.ImGui_DrawList_AddCircle(
            self._draw_list,
            self._center_x,
            self._center_y,
            circle_radius,
            rgbToHex(circle_color),
            segments
        )
    end
end

---@param radius number
---@param size number
---@param start_angle number
---@param end_angle number
---@param color ColorSet
---@param track_size? number
function Knob:__draw_arc(
    radius,
    size,
    start_angle,
    end_angle,
    color,
    track_size
)
    local track_radius = radius * self._radius
    if track_size == nil then
        track_size = size * (self._radius + 0.1) * 0.5 + 0.0001
    end
    local circle_color
    if self._is_active then
        circle_color = color.active
    elseif self._is_hovered then
        circle_color = color.hovered
    else
        circle_color = color.base
    end

    reaper.ImGui_DrawList_PathArcTo(self._draw_list, self._center_x, self._center_y, track_radius * 0.95, start_angle,
        end_angle)
    reaper.ImGui_DrawList_PathStroke(self._draw_list, rgbToHex(circle_color), nil, track_size)
    reaper.ImGui_DrawList_PathClear(self._draw_list)
end

---In practice, you probably want to dodge creating a new knob at every loop…
---@param ctx ImGui_Context
---@param id string
---@param label string
---@param p_value number
---@param v_min number
---@param v_max number
---@param v_default number
---@param radius number
---@param controllable boolean
---@param label_format string
function Knob.new(
    ctx,
    id,
    label,
    p_value,
    v_min,
    v_max,
    v_default,
    radius,
    controllable,
    label_format
)
    ---@class Knob
    local new_knob = {}
    setmetatable(new_knob, { __index = Knob })
    local angle_min = math.pi * 0.75
    local angle_max = math.pi * 2.25
    local t = (p_value - v_min) / (v_max - v_min)
    local angle = angle_min + (angle_max - angle_min) * t
    local value_changed = false
    new_knob._ctx = ctx
    new_knob._id = id
    new_knob._label = label
    new_knob._p_value = p_value
    new_knob._v_min = v_min
    new_knob._v_max = v_max
    new_knob._v_default = v_default
    new_knob._radius = radius
    new_knob._label_format = label_format
    new_knob._controllable = controllable
    new_knob._value_changed = value_changed
    new_knob._angle = angle
    new_knob._angle_min = angle_min
    new_knob._angle_max = angle_max
    new_knob._t = t
    new_knob._draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    new_knob._is_active = reaper.ImGui_IsItemActive(ctx)
    new_knob._is_hovered = reaper.ImGui_IsItemHovered(ctx)
    local draw_cursor_x, draw_cursor_y = reaper.ImGui_GetCursorScreenPos(ctx)
    new_knob._center_x = draw_cursor_x + new_knob._radius
    new_knob._center_y = draw_cursor_y + new_knob._radius
    new_knob._angle_cos = math.cos(new_knob._angle)
    new_knob._angle_sin = math.sin(new_knob._angle)
    return new_knob
end

function Knob:__update()
    local draw_cursor_x, draw_cursor_y = reaper.ImGui_GetCursorScreenPos(self._ctx)
    self._center_x = draw_cursor_x + self._radius
    self._center_y = draw_cursor_y + self._radius

    local t = (self._p_value - self._v_min) / (self._v_max - self._v_min)
    self._angle = self._angle_min + (self._angle_max - self._angle_min) * t
end

---Draw the invisible button and handle the control
---@return boolean rv
---@return number|nil p_value
function Knob:__control()
    if not self._controllable then
        return false, nil
    end

    reaper.ImGui_InvisibleButton(self._ctx, self._id, self._radius * 2.0, self._radius * 2.0)
    self._is_hovered = reaper.ImGui_IsItemHovered(self._ctx)

    local value_changed = false
    local is_active = reaper.ImGui_IsItemActive(self._ctx)

    reaper.ImGui_SetConfigVar(self._ctx, reaper.ImGui_ConfigVar_MouseDragThreshold(), 0.0001)
    local _, delta_y = reaper.ImGui_GetMouseDragDelta(self._ctx, reaper.ImGui_GetCursorPosX(self._ctx),
        reaper.ImGui_GetCursorPosY(self._ctx))

    -- --Maybe this should be configurable
    local speed
    if reaper.ImGui_IsKeyDown(self._ctx, reaper.ImGui_Mod_Shift())
        or reaper.ImGui_IsKeyDown(self._ctx, reaper.ImGui_Mod_Alt()) then
        speed = 2000
    else
        speed = 200
    end

    if reaper.ImGui_IsMouseDoubleClicked(self._ctx, reaper.ImGui_MouseButton_Left()) and is_active then
        self._p_value = self._v_default
        value_changed = true
    elseif is_active and delta_y ~= 0.0 then
        local step = (self._v_max - self._v_min) / speed
        self._p_value = self._p_value - delta_y * step
        if self._p_value < self._v_min then self._p_value = self._v_min end
        if self._p_value > self._v_max then self._p_value = self._v_max end
        value_changed = true
        reaper.ImGui_ResetMouseDragDelta(self._ctx, reaper.ImGui_MouseButton_Left())
    end
    return value_changed, self._p_value
end

---@param circle_color ColorSet
---@param wiper_color ColorSet
---@param track_color ColorSet
function Knob:__wiper_knob(
    circle_color,
    wiper_color,
    track_color
)
    self:__draw_circle(0.7, circle_color, true, 0)
    self:__draw_arc(
        0.8,
        0.41,
        self._angle_min,
        self._angle_max,
        track_color
    )
    if self._t > 0.01 then
        self:__draw_arc(
            0.8,
            0.43,
            self._angle_min,
            self._angle,
            wiper_color
        )
    end
end

---@param  wiper_color ColorSet
---@param  track_color ColorSet
function Knob:__draw_wiper_only(
    wiper_color,
    track_color
)
    self:__draw_arc(
        0.8,
        0.41,
        self._angle_min,
        self._angle_max,
        track_color
    )
    if self._t > 0.01 then
        self:__draw_arc(0.8, 0.43, self._angle_min, self._angle, wiper_color)
    end
end

---@param circle_color ColorSet
---@param dot_color ColorSet
---@param track_color ColorSet
function Knob:__draw_wiper_dot_knob(
    circle_color,
    dot_color,
    track_color
)
    self:__draw_circle(0.6, circle_color, true, 32)
    self:__draw_arc(
        0.85,
        0.41,
        self._angle_min,
        self._angle_max,
        track_color
    )
    self:__draw_dot(0.1, 0.85, self._angle, dot_color, true, 12)
end

local function calculateTriangleVertices(centerX, centerY, radius)
    local vertices = {}

    -- Calculate the angles for each point
    local angle1 = 0
    local angle2 = (2 * math.pi) / 3
    local angle3 = (4 * math.pi) / 3

    -- Calculate the coordinates for each point
    local x1 = centerX + radius * math.cos(angle1)
    local y1 = centerY + radius * math.sin(angle1)
    table.insert(vertices, { x = x1, y = y1 })

    local x2 = centerX + radius * math.cos(angle2)
    local y2 = centerY + radius * math.sin(angle2)
    table.insert(vertices, { x = x2, y = y2 })

    local x3 = centerX + radius * math.cos(angle3)
    local y3 = centerY + radius * math.sin(angle3)
    table.insert(vertices, { x = x3, y = y3 })

    return vertices
end

function Knob:__draw_triangle(
    size,
    radius,
    angle,
    color,
    filled
)
    local dot_size = size * self._radius
    local dot_radius = radius * self._radius
    local circle_color

    if self._is_active then
        circle_color = color.active
    elseif self._is_hovered then
        circle_color = color.hovered
    else
        circle_color = color.base
    end


    local vertices = calculateTriangleVertices(
        self._center_x + math.cos(angle) * dot_radius,
        self._center_y + math.cos(angle) * dot_radius,
        dot_size)
    local c = vertices[1]
    local b = vertices[2]
    local a = vertices[3]
    if filled then
        reaper.ImGui_DrawList_AddTriangleFilled(self._draw_list, c.x, c.y, b.x, b.y, a.x, a.y, rgbToHex(circle_color))
        -- reaper.ImGui_DrawList_AddCircleFilled(
        --     self.draw_list,
        --     self.center_x + math.cos(angle) * dot_radius,
        --     self.center_y + math.sin(angle) * dot_radius,
        --     dot_size,
        --     rgbToHex(circle_color),
        --     segments
        -- )
    else
        reaper.ImGui_DrawList_AddTriangle(self._draw_list, c.x, c.y, b.x, b.y, a.x, a.y, rgbToHex(circle_color))
        -- reaper.ImGui_DrawList_AddCircle(
        --     self.draw_list,
        --     self.center_x + math.cos(angle) * dot_radius,
        --     self.center_y + math.sin(angle) * dot_radius,
        --     dot_size,
        --     rgbToHex(circle_color),
        --     segments
        -- )
    end
end

---@param circle_color ColorSet
---@param dot_color ColorSet
---@param track_color ColorSet
function Knob:__draw_readrum_knob(
    circle_color,
    dot_color,
    track_color
)
    self:__draw_circle(0.6, circle_color, true, 32)
    self:__draw_arc(
        0.7,
        0.4,
        self._angle_min,
        self._angle_max,
        track_color,
        2
    )

    if self._t > 0.01 then
        self:__draw_arc(0.7, 0.40, self._angle_min, self._angle, dot_color, 2)
    end
    self:__draw_dot(0.15, 0.45, self._angle, dot_color, true, 0)
    -- self:draw_triangle(0.1, 0.85, self.angle, dot_color, true, 12)
end

---@param circle_color ColorSet
---@param tick_color ColorSet
---@param track_color ColorSet
function Knob:__draw_imgui_knob(
    circle_color,
    tick_color,
    track_color
)
    self:__draw_circle(0.85, circle_color, true, 32)
    self:__draw_circle(0.4, track_color, true, 32)
    self:__draw_tick(0.45, 0.85, 0.08, self._angle, tick_color)
end

---@param circle_color ColorSet
---@param tick_color ColorSet
function Knob:__draw_tick_knob(
    circle_color,
    tick_color
)
    self:__draw_circle(0.7, circle_color, true, 32)
    self:__draw_tick(0.4, 0.7, 0.08, self._angle, tick_color)
end

---@param circle_color ColorSet
---@param dot_color ColorSet
function Knob:__draw_dot_knob(
    circle_color,
    dot_color
)
    self:__draw_circle(0.85, circle_color, true, 32)
    self:__draw_dot(0.12, 0.6, self._angle, dot_color, true, 12)
end

---@param circle_color ColorSet
---@param wiper_color ColorSet
function Knob:__draw_space_knob(
    circle_color,
    wiper_color
)
    self:__draw_circle(0.3 - self._t * 0.1, circle_color, true, 16)
    if self._t > 0.01 then
        self:__draw_arc(
            0.4,
            0.15,
            self._angle_min - 1.0,
            self._angle - 1.0,
            wiper_color
        )

        self:__draw_arc(
            0.6,
            0.15,
            self._angle_min + 1.0,
            self._angle + 1.0,
            wiper_color
        )

        self:__draw_arc(
            0.8,
            0.15,
            self._angle_min + 3.0,
            self._angle + 3.0,
            wiper_color
        )
    end
end

---@param steps integer
---@param circle_color ColorSet
---@param dot_color ColorSet
---@param step_color ColorSet
function Knob:__draw_stepped_knob(
    steps,
    circle_color,
    dot_color,
    step_color
)
    -- iterate through the steps
    for n = 1, steps do
        local a = n / (steps - 1)
        local angle = self._angle_min + (self._angle_max - self._angle_min) * a
        self:__draw_tick(0.7, 0.9, 0.04, angle, step_color)
    end
    self:__draw_circle(0.6, circle_color, true, 32)
    self:__draw_dot(0.12, 0.4, self._angle, dot_color, true, 12)
end

---@param tick_color ColorSet
---@param wiper_color ColorSet
---@param track_color ColorSet
function Knob:__draw_ableton_knob(
    tick_color, wiper_color, track_color)
    -- self:draw_circle(0.7, circle_color, true, 32)
    self:__draw_arc(0.9, 0.41, self._angle_min, self._angle_max, track_color, 2)
    self:__draw_tick(0.1, 0.9, 0.08, self._angle, tick_color)
    self:__draw_arc(0.9, 0.43, self._angle_min, self._angle, tick_color, 2)
end

---@param width number
function Knob:__knob_title(
    width
)
    local size_x, _ = reaper.ImGui_CalcTextSize(self._ctx, self._label, nil, nil, false, width)
    local old_cursor_pos_x, old_cursor_pos_y = reaper.ImGui_GetCursorPos(self._ctx)
    reaper.ImGui_SetCursorPos(
        self._ctx,
        old_cursor_pos_x + (width - size_x) * 0.5,
        old_cursor_pos_y
    )
    reaper.ImGui_Text(self._ctx, self._label)

    reaper.ImGui_SetCursorPos(
        self._ctx,
        old_cursor_pos_x,
        select(2, reaper.ImGui_GetCursorPos(self._ctx))
    )
end

---The style of knob that you want to draw
---@enum KnobVariant
Knob.KnobVariant = {
    wiper_knob = "wiper_knob",
    wiper_dot = "wiper_dot",
    wiper_only = "wiper_only",
    tick = "tick",
    dot = "dot",
    space = "space",
    stepped = "stepped",
    ableton = "ableton",
    readrum = "readrum",
    imgui = "imgui",
}


---List of flags that you can pass into the draw method
---@enum KnobFlags
Knob.KnobFlags = {
    NoTitle = 1, --- Hide the top title.
    NoInput = 2, --- Hide the bottom drag input.
    DragHorizontal = 3
}

function Knob:__with_drag()
    _, self._p_value = reaper.ImGui_DragDouble(
        self._ctx,
        "##" .. self._id .. "_KNOB_DRAG_CONTROL_",
        self._p_value,
        (self._v_max - self._v_min) / 1000.0,
        self._v_min,
        self._v_max,
        self._label_format,
        reaper.ImGui_SliderFlags_AlwaysClamp()
    )
    return self
end

---TODO accomodate the NoInput flag
---@param variant KnobVariant
---@param circle_color ColorSet
---@param dot_color ColorSet
---@param track_color? ColorSet
---@param flags? integer|KnobFlags
---@param steps? integer
function Knob:draw(variant, circle_color, dot_color, track_color, flags, steps)
    if flags == nil then
        flags = 0
    end
    self:__update()
    self:__control()

    local width = reaper.ImGui_GetTextLineHeight(self._ctx) * 4.0
    reaper.ImGui_PushItemWidth(self._ctx, width)
    if not (flags & self.KnobFlags.NoTitle == self.KnobFlags.NoTitle) then
        self:__knob_title(width)
    end
    if not (flags & self.KnobFlags.DragHorizontal == self.KnobFlags.DragHorizontal) then
        self:__with_drag()
    end
    reaper.ImGui_PopItemWidth(self._ctx)

    if variant == self.KnobVariant.wiper_knob then
        self:__wiper_knob(circle_color,
            dot_color,
            track_color or circle_color
        )
    elseif variant == self.KnobVariant.wiper_dot then
        self:__draw_wiper_dot_knob(circle_color,
            dot_color,
            track_color or circle_color
        )
    elseif variant == self.KnobVariant.wiper_only then
        self:__draw_wiper_only(circle_color,
            track_color or circle_color
        )
    elseif variant == self.KnobVariant.tick then
        self:__draw_tick_knob(circle_color,
            dot_color
        )
    elseif variant == self.KnobVariant.dot then
        self:__draw_dot_knob(circle_color,
            dot_color
        )
    elseif variant == self.KnobVariant.space then
        self:__draw_space_knob(circle_color,
            dot_color
        )
    elseif variant == self.KnobVariant.stepped then
        self:__draw_stepped_knob(steps or 0, circle_color,
            dot_color,
            track_color or circle_color
        )
    elseif variant == self.KnobVariant.ableton then
        self:__draw_ableton_knob(circle_color,
            dot_color,
            track_color or circle_color
        )
    elseif variant == self.KnobVariant.readrum then
        self:__draw_readrum_knob(circle_color,
            dot_color,
            track_color or dot_color
        )
    elseif variant == self.KnobVariant.imgui then
        self:__draw_imgui_knob(circle_color,
            dot_color,
            track_color or dot_color
        )
    end
    return self._p_value
end

---@param hsva {[1]: number, [2]: number, [3]: number, [4]: number}
---@return {[1]: number, [2]: number, [3]: number, [4]: number}
local function hsv2rgb(hsva)
    local h, s, v, a = hsva[1], hsva[2], hsva[3], hsva[4]
    local r, g, b

    local i = math.floor(h * 6)
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

return {
    rgbToHex = rgbToHex,
    hsv2rgb = hsv2rgb,
    ColorSet = ColorSet,
    Knob = Knob
}
