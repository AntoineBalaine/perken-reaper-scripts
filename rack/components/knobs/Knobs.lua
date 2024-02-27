---This is a port of imgui-rs-knobs
--TB TESTED
--https://github.com/DGriffin91/imgui-rs-knobs

---@param rgba {[1]: number,[2]: number,[3]: number,[4]: number}
---@return number
local function rgbToHex___(rgba)
    local r = math.floor(rgba[1] * 255) * 256 * 256
    local g = math.floor(rgba[2] * 255) * 256
    local b = math.floor(rgba[3] * 255)
    local a = math.floor(rgba[4] * 255)
    return r + g + b + a
end

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
---@field ctx ImGui_Context
---@field id string
---@field label string
---@field label_format string
---@field p_value number
---@field v_min number
---@field v_max number
---@field v_default number
---@field radius number
---@field screen_pos {[1]: number, [2]: number}
---@field value_changed boolean
---@field center {[1]: number, [2]: number}
---@field draw_list ImGui_DrawList
---@field is_active boolean
---@field is_hovered boolean
---@field angle_min number
---@field angle_max number
---@field t number
---@field angle number
---@field angle_cos number
---@field angle_sin number
---@field controllable boolean
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
    local dot_size = size * self.radius
    local dot_radius = radius * self.radius
    local circle_color

    if self.is_active then
        circle_color = color.active
    elseif self.is_hovered then
        circle_color = color.hovered
    else
        circle_color = color.base
    end
    if filled then
        reaper.ImGui_DrawList_AddCircleFilled(
            self.draw_list,
            self.center[1] + math.cos(angle) * dot_radius,
            self.center[2] + math.sin(angle) * dot_radius,
            dot_size,
            rgbToHex(circle_color),
            segments
        )
    else
        reaper.ImGui_DrawList_AddCircle(
            self.draw_list,
            self.center[1] + math.cos(angle) * dot_radius,
            self.center[2] + math.sin(angle) * dot_radius,
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
    local tick_start = start * self.radius
    local tick_end = end_ * self.radius
    local angle_cos = math.cos(angle)
    local angle_sin = math.sin(angle)

    local line_color
    if self.is_active then
        line_color = color.active
    elseif self.is_hovered then
        line_color = color.hovered
    else
        line_color = color.base
    end

    reaper.ImGui_DrawList_AddLine(
        self.draw_list,
        self.center[1] + angle_cos * tick_end,
        self.center[2] + angle_sin * tick_end,
        self.center[1] + angle_cos * tick_start,
        self.center[2] + angle_sin * tick_start,
        rgbToHex(line_color),
        width * self.radius
    )
end

---@param size number
---@param color ColorSet
---@param filled boolean
---@param segments integer
function Knob:__draw_circle(size, color, filled, segments)
    local circle_radius = size * self.radius

    local circle_color
    if self.is_active then
        circle_color = color.active
    elseif self.is_hovered then
        circle_color = color.hovered
    else
        circle_color = color.base
    end
    if filled then
        reaper.ImGui_DrawList_AddCircleFilled(
            self.draw_list,
            self.center[1],
            self.center[2],
            circle_radius,
            rgbToHex(circle_color),
            segments
        )
    else
        reaper.ImGui_DrawList_AddCircle(
            self.draw_list,
            self.center[1],
            self.center[2],
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
    local track_radius = radius * self.radius
    if track_size == nil then
        track_size = size * (self.radius + 0.1) * 0.5 + 0.0001
    end
    local circle_color
    if self.is_active then
        circle_color = color.active
    elseif self.is_hovered then
        circle_color = color.hovered
    else
        circle_color = color.base
    end

    reaper.ImGui_DrawList_PathArcTo(self.draw_list, self.center[1], self.center[2], track_radius * 0.95, start_angle,
        end_angle)
    reaper.ImGui_DrawList_PathStroke(self.draw_list, rgbToHex(circle_color), nil, track_size)
    reaper.ImGui_DrawList_PathClear(self.draw_list)
end

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
    local self = setmetatable({}, { __index = Knob })
    local angle_min = math.pi * 0.75
    local angle_max = math.pi * 2.25
    local t = (p_value - v_min) / (v_max - v_min)
    local angle = angle_min + (angle_max - angle_min) * t
    local value_changed = false
    self.ctx = ctx
    self.id = id
    self.label = label
    self.p_value = p_value
    self.v_min = v_min
    self.v_max = v_max
    self.v_default = v_default
    self.radius = radius
    self.label_format = label_format
    self.controllable = controllable
    self.screen_pos = { reaper.ImGui_GetCursorScreenPos(ctx) }
    self.value_changed = value_changed
    self.angle = angle
    self.angle_min = angle_min
    self.angle_max = angle_max
    self.t = t
    self.draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    self.is_active = reaper.ImGui_IsItemActive(ctx)
    self.is_hovered = reaper.ImGui_IsItemHovered(ctx)
    local draw_cursor_x, draw_cursor_y = reaper.ImGui_GetCursorScreenPos(ctx)
    self.center = { draw_cursor_x + self.radius, draw_cursor_y + self.radius }
    self.angle_cos = math.cos(self.angle)
    self.angle_sin = math.sin(self.angle)

    return self
end

function Knob:__update()
    local draw_cursor_x, draw_cursor_y = reaper.ImGui_GetCursorScreenPos(self.ctx)
    ---FIXME don’t assign a table at every loop
    self.center = { draw_cursor_x + self.radius, draw_cursor_y + self.radius }

    local t = (self.p_value - self.v_min) / (self.v_max - self.v_min)
    self.angle = self.angle_min + (self.angle_max - self.angle_min) * t
end

---Draw the invisible button and handle the control
---@return boolean rv
---@return number|nil p_value
function Knob:__control()
    if not self.controllable then
        return false, nil
    end

    reaper.ImGui_InvisibleButton(self.ctx, self.id, self.radius * 2.0, self.radius * 2.0)
    self.is_hovered = reaper.ImGui_IsItemHovered(self.ctx)

    local value_changed = false
    local is_active = reaper.ImGui_IsItemActive(self.ctx)

    reaper.ImGui_SetConfigVar(self.ctx, reaper.ImGui_ConfigVar_MouseDragThreshold(), 0.0001)
    local _, delta_y = reaper.ImGui_GetMouseDragDelta(self.ctx, reaper.ImGui_GetCursorPosX(self.ctx),
        reaper.ImGui_GetCursorPosY(self.ctx))

    -- --Maybe this should be configurable
    local speed
    if reaper.ImGui_IsKeyDown(self.ctx, reaper.ImGui_Mod_Shift())
        or reaper.ImGui_IsKeyDown(self.ctx, reaper.ImGui_Mod_Alt()) then
        speed = 2000
    else
        speed = 200
    end

    if reaper.ImGui_IsMouseDoubleClicked(self.ctx, reaper.ImGui_MouseButton_Left()) and is_active then
        self.p_value = self.v_default
        value_changed = true
    elseif is_active and delta_y ~= 0.0 then
        local step = (self.v_max - self.v_min) / speed
        self.p_value = self.p_value - delta_y * step
        if self.p_value < self.v_min then self.p_value = self.v_min end
        if self.p_value > self.v_max then self.p_value = self.v_max end
        value_changed = true
        reaper.ImGui_ResetMouseDragDelta(self.ctx, reaper.ImGui_MouseButton_Left())
    end
    return value_changed, self.p_value
end

---@param circle_color ColorSet
---@param wiper_color ColorSet
---@param track_color ColorSet
function Knob:wiper_knob(
    circle_color,
    wiper_color,
    track_color
)
    self:__draw_circle(0.7, circle_color, true, 0)
    self:__draw_arc(
        0.8,
        0.41,
        self.angle_min,
        self.angle_max,
        track_color
    )
    if self.t > 0.01 then
        self:__draw_arc(
            0.8,
            0.43,
            self.angle_min,
            self.angle,
            wiper_color
        )
    end
end

---@param  wiper_color ColorSet
---@param  track_color ColorSet
function Knob:draw_wiper_only(
    wiper_color,
    track_color
)
    self:__draw_arc(
        0.8,
        0.41,
        self.angle_min,
        self.angle_max,
        track_color
    )
    if self.t > 0.01 then
        self:__draw_arc(0.8, 0.43, self.angle_min, self.angle, wiper_color)
    end
end

---@param circle_color ColorSet
---@param dot_color ColorSet
---@param track_color ColorSet
function Knob:draw_wiper_dot_knob(
    circle_color,
    dot_color,
    track_color
)
    self:__draw_circle(0.6, circle_color, true, 32)
    self:__draw_arc(
        0.85,
        0.41,
        self.angle_min,
        self.angle_max,
        track_color
    )
    self:__draw_dot(0.1, 0.85, self.angle, dot_color, true, 12)
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

function Knob:draw_triangle(
    size,
    radius,
    angle,
    color,
    filled,
    segments
)
    local dot_size = size * self.radius
    local dot_radius = radius * self.radius
    local circle_color

    if self.is_active then
        circle_color = color.active
    elseif self.is_hovered then
        circle_color = color.hovered
    else
        circle_color = color.base
    end


    local vertices = calculateTriangleVertices(
        self.center[1] + math.cos(angle) * dot_radius,
        self.center[2] + math.cos(angle) * dot_radius,
        dot_size)
    local c = vertices[1]
    local b = vertices[2]
    local a = vertices[3]
    if filled then
        reaper.ImGui_DrawList_AddTriangleFilled(self.draw_list, c.x, c.y, b.x, b.y, a.x, a.y, rgbToHex(circle_color))
        -- reaper.ImGui_DrawList_AddCircleFilled(
        --     self.draw_list,
        --     self.center[1] + math.cos(angle) * dot_radius,
        --     self.center[2] + math.sin(angle) * dot_radius,
        --     dot_size,
        --     rgbToHex(circle_color),
        --     segments
        -- )
    else
        reaper.ImGui_DrawList_AddTriangle(self.draw_list, c.x, c.y, b.x, b.y, a.x, a.y, rgbToHex(circle_color))
        -- reaper.ImGui_DrawList_AddCircle(
        --     self.draw_list,
        --     self.center[1] + math.cos(angle) * dot_radius,
        --     self.center[2] + math.sin(angle) * dot_radius,
        --     dot_size,
        --     rgbToHex(circle_color),
        --     segments
        -- )
    end
end

---@param circle_color ColorSet
---@param dot_color ColorSet
---@param track_color ColorSet
function Knob:draw_readrum_knob(
    circle_color,
    dot_color,
    track_color
)
    self:__draw_circle(0.6, circle_color, true, 32)
    self:__draw_arc(
        0.7,
        0.4,
        self.angle_min,
        self.angle_max,
        track_color,
        2
    )

    if self.t > 0.01 then
        self:__draw_arc(0.7, 0.40, self.angle_min, self.angle, dot_color, 2)
    end
    self:__draw_dot(0.15, 0.45, self.angle, dot_color, true, 0)
    -- self:draw_triangle(0.1, 0.85, self.angle, dot_color, true, 12)
end

---@param circle_color ColorSet
---@param tick_color ColorSet
---@param track_color ColorSet
function Knob:draw_imgui_knob(
    circle_color,
    tick_color,
    track_color
)
    self:__draw_circle(0.85, circle_color, true, 32)
    self:__draw_circle(0.4, track_color, true, 32)
    self:__draw_tick(0.45, 0.85, 0.08, self.angle, tick_color)
end

---@param circle_color ColorSet
---@param tick_color ColorSet
function Knob:draw_tick_knob(
    circle_color,
    tick_color
)
    self:__draw_circle(0.7, circle_color, true, 32)
    self:__draw_tick(0.4, 0.7, 0.08, self.angle, tick_color)
end

---@param circle_color ColorSet
---@param dot_color ColorSet
function Knob:draw_dot_knob(
    circle_color,
    dot_color
)
    self:__draw_circle(0.85, circle_color, true, 32)
    self:__draw_dot(0.12, 0.6, self.angle, dot_color, true, 12)
end

---@param circle_color ColorSet
---@param wiper_color ColorSet
function Knob:draw_space_knob(
    circle_color,
    wiper_color
)
    self:__draw_circle(0.3 - self.t * 0.1, circle_color, true, 16)
    if self.t > 0.01 then
        self:__draw_arc(
            0.4,
            0.15,
            self.angle_min - 1.0,
            self.angle - 1.0,
            wiper_color
        )

        self:__draw_arc(
            0.6,
            0.15,
            self.angle_min + 1.0,
            self.angle + 1.0,
            wiper_color
        )

        self:__draw_arc(
            0.8,
            0.15,
            self.angle_min + 3.0,
            self.angle + 3.0,
            wiper_color
        )
    end
end

---@param steps integer
---@param circle_color ColorSet
---@param dot_color ColorSet
---@param step_color ColorSet
function Knob:draw_stepped_knob(
    steps,
    circle_color,
    dot_color,
    step_color
)
    -- iterate through the steps
    for n = 1, steps do
        local a = n / (steps - 1)
        local angle = self.angle_min + (self.angle_max - self.angle_min) * a
        self:__draw_tick(0.7, 0.9, 0.04, angle, step_color)
    end
    self:__draw_circle(0.6, circle_color, true, 32)
    self:__draw_dot(0.12, 0.4, self.angle, dot_color, true, 12)
end

---@param tick_color ColorSet
---@param wiper_color ColorSet
---@param track_color ColorSet
function Knob:draw_ableton_knob(
    tick_color, wiper_color, track_color)
    -- self:draw_circle(0.7, circle_color, true, 32)
    self:__draw_arc(0.9, 0.41, self.angle_min, self.angle_max, track_color, 2)
    self:__draw_tick(0.1, 0.9, 0.08, self.angle, tick_color)
    self:__draw_arc(0.9, 0.43, self.angle_min, self.angle, tick_color, 2)
end

---@param width number
function Knob:knob_title(
    width
)
    local size_x, _ = reaper.ImGui_CalcTextSize(self.ctx, self.label, nil, nil, false, width)
    local old_cursor_pos_x, old_cursor_pos_y = reaper.ImGui_GetCursorPos(self.ctx)
    reaper.ImGui_SetCursorPos(
        self.ctx,
        old_cursor_pos_x + (width - size_x) * 0.5,
        old_cursor_pos_y
    )
    reaper.ImGui_Text(self.ctx, self.label)

    reaper.ImGui_SetCursorPos(
        self.ctx,
        old_cursor_pos_x,
        select(2, reaper.ImGui_GetCursorPos(self.ctx))
    )
end

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


---@enum KnobFlags
local KnobFlags = {
    NoTitle = 1, --- Hide the top title.
    NoInput = 2, --- Hide the bottom drag input.
    DragHorizontal = 3
}

function Knob:__with_drag()
    _, self.p_value = reaper.ImGui_DragDouble(
        self.ctx,
        "##" .. self.id .. "_KNOB_DRAG_CONTROL_",
        self.p_value,
        (self.v_max - self.v_min) / 1000.0,
        self.v_min,
        self.v_max,
        self.label_format,
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
    self:__update()
    self:__control()

    local width = reaper.ImGui_GetTextLineHeight(self.ctx) * 4.0
    reaper.ImGui_PushItemWidth(self.ctx, width)
    if not (flags & KnobFlags.NoTitle == KnobFlags.NoTitle) then
        self:knob_title(width)
    end
    if not (flags & KnobFlags.Drag_Horizontal == KnobFlags.Drag_Horizontal) then
        self:__with_drag()
    end
    reaper.ImGui_PopItemWidth(self.ctx)

    if variant == self.KnobVariant.wiper_knob then
        self:wiper_knob(circle_color,
            dot_color,
            track_color or circle_color
        )
    elseif variant == self.KnobVariant.wiper_dot then
        self:draw_wiper_dot_knob(circle_color,
            dot_color,
            track_color or circle_color
        )
    elseif variant == self.KnobVariant.wiper_only then
        self:draw_wiper_only(circle_color,
            track_color or circle_color
        )
    elseif variant == self.KnobVariant.tick then
        self:draw_tick_knob(circle_color,
            dot_color
        )
    elseif variant == self.KnobVariant.dot then
        self:draw_dot_knob(circle_color,
            dot_color
        )
    elseif variant == self.KnobVariant.space then
        self:draw_space_knob(circle_color,
            dot_color
        )
    elseif variant == self.KnobVariant.stepped then
        self:draw_stepped_knob(steps or 0, circle_color,
            dot_color,
            track_color or circle_color
        )
    elseif variant == self.KnobVariant.ableton then
        self:draw_ableton_knob(circle_color,
            dot_color,
            track_color or circle_color
        )
    elseif variant == self.KnobVariant.readrum then
        self:draw_readrum_knob(circle_color,
            dot_color,
            track_color or dot_color
        )
    elseif variant == self.KnobVariant.imgui then
        self:draw_imgui_knob(circle_color,
            dot_color,
            track_color or dot_color
        )
    end
    return self.p_value
end

---@param hsva {[1]: number, [2]: number, [3]: number, [4]: number}
---@return {[1]: number, [2]: number, [3]: number, [4]: number}
function hsv2rgb(hsva)
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
