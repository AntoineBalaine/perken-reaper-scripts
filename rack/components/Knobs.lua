---This is a port of imgui-rs-knobs
--TB TESTED
--https://github.com/DGriffin91/imgui-rs-knobs

---@param center {[1]: number, [2]: number}
---@param start {[1]: number, [2]: number}
---@param end_ {[1]: number, [2]: number}
---@return number c1.x, number c1.y, number c2.x, number c2.y
local function bezier_arc(center, start, end_)
    local ax = start[0] - center[0]
    local ay = start[1] - center[1]
    local bx = end_[0] - center[0]
    local by = end_[1] - center[1]
    local q1 = ax * ax + ay * ay
    local q2 = q1 + ax * bx + ay * by
    local k2 = (4.0 / 3.0) * ((2.0 * q1 * q2).sqrt() - q2) / (ax * by - ay * bx)

    return center[0] + ax - k2 * ay, center[1] + ay + k2 * ax,
        center[0] + bx + k2 * by, center[1] + by - k2 * bx
end


---FIXME
local function dummyConvertColor(color)
    return 0xFFFFFF00
end

---@param draw_list ImGui_DrawList
---@param center {[1]: number, [2]: number}
---@param radius number
---@param start_angle number
---@param end_angle number
---@param thickness number
---@param color number
---@param num_segments integer
local function draw_arc1(
    draw_list,
    center,
    radius,
    start_angle,
    end_angle,
    thickness,
    color,
    num_segments
)
    local start = { center[0] + math.cos(start_angle) * radius,
        center[1] + math.sin(start_angle) * radius,
    }

    local end_ = { center[0] + math.cos(end_angle) * radius,
        center[1] + math.sin(end_angle) * radius,
    }

    local c1_x, c1_y, c2_x, c2_y = bezier_arc(center, start, end_)

    ---Let’s pray that this works
    reaper.ImGui_DrawList_AddBezierQuadratic(draw_list, c1_x, c1_y, c2_x, c2_y, end_[1], end_[2], color, thickness,
        num_segments)
    reaper.ImGui_DrawList_AddBezierCubic(draw_list, start[1], start[2], c1_x, c1_y, c2_x, c2_y, end_[1], end_[2],
        color, thickness,
        num_segments)
end

---@param draw_list ImGui_DrawList
---@param center {[1]: number, [2]: number}
---@param radius number
---@param start_angle number
---@param end_angle number
---@param thickness number
---@param color {[1]: number,[2]: number,[3]: number,[4]: number}
---@param num_segments integer
---@param bezier_count integer
local function draw_arc(
    draw_list,
    center,
    radius,
    start_angle,
    end_angle,
    thickness,
    color,
    num_segments,
    bezier_count
)
    --- Overlap & angle of ends of bezier curves needs work, only looks good when not transperant
    local overlap = thickness * radius * 0.00001 * math.pi()
    local delta = end_angle - start_angle
    local bez_step = 1.0 / bezier_count
    local mid_angle = start_angle + overlap
    for _ in bezier_count do
        local mid_angle2 = delta * bez_step + mid_angle
        draw_arc1(
            draw_list,
            center,
            radius,
            mid_angle - overlap,
            mid_angle2 + overlap,
            thickness,
            dummyConvertColor(color),
            num_segments
        )
        mid_angle = mid_angle2
    end

    draw_arc1(
        draw_list,
        center,
        radius,
        mid_angle - overlap,
        end_angle,
        thickness,
        dummyConvertColor(color),
        num_segments
    )
end


---@param ctx ImGui_Context
---@param id string
---@param p_value number
---@param v_min number
---@param v_max number
---@param v_default number
---@param radius number
local function knob_control(
    ctx,
    id,
    p_value,
    v_min,
    v_max,
    v_default,
    radius
)
    reaper.ImGui_InvisibleButton(ctx, id, radius * 2.0, radius * 2.0)
    local value_changed = false
    --- TODO FIXME
    local is_active = reaper.ImGui_IsItemActive(ctx)

    reaper.ImGui_SetConfigVar(ctx, reaper.ImGui_ConfigVar_MouseDragThreshold(), 0.0001)
    local delta = reaper.ImGui_GetMouseDragDelta(ctx, reaper.ImGui_GetCursorPosX(ctx), reaper.Imgui_GetCursorPosY(ctx))


    -- --Maybe this should be configurable
    local speed
    if reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Shift())
        or reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Mod_Alt()) then
        speed = 2000
    else
        speed = 200
    end

    if reaper.ImGui_IsMouseDoubleClicked(ctx, reaper.ImGui_MouseButton_Left()) and is_active then
        p_value = v_default
        value_changed = true
    elseif is_active and delta[1] ~= 0.0 then
        local step = (v_max - v_min) / speed
        p_value = p_value - delta[1] * step
        if p_value < v_min then p_value = v_min end
        if p_value > v_max then p_value = v_max end
        value_changed = true
        reaper.ImGui_ResetMouseDragDelta(ctx, reaper.ImGui_MouseButton_Left())
    end
    return value_changed
end

---TODO implement as class with :new() and :from()
---@class ColorSet
---@field base {[1]: number,[2]: number,[3]: number,[4]: number}
---@field hovered {[1]: number,[2]: number,[3]: number,[4]: number}
---@field active {[1]: number,[2]: number,[3]: number,[4]: number}


---@class Knob
---@field ctx ImGui_Context
---@field label string,
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
local Knob = {}

---@param ctx ImGui_Context
---@param label string
---@param p_value number
---@param v_min number
---@param v_max number
---@param v_default number
---@param radius number
---@param controllable boolean
function Knob.new(
    ctx,
    label,
    p_value,
    v_min,
    v_max,
    v_default,
    radius,
    controllable
)
    local self = setmetatable({}, Knob)
    local angle_min = math.pi * 0.75
    local angle_max = math.pi * 2.25
    local t = (p_value - v_min) / (v_max - v_min)
    local angle = angle_min + (angle_max - angle_min) * t
    local screen_pos = reaper.ImGui_GetCursorPos(ctx)
    local value_changed = false
    if controllable then
        value_changed = knob_control(ctx, label, p_value, v_min, v_max, v_default, radius)
    end
    self.ctx = ctx
    self.label = label
    self.p_value = p_value
    self.v_min = v_min
    self.v_max = v_max
    self.v_default = v_default
    self.radius = radius
    self.screen_pos = screen_pos
    self.value_changed = value_changed
    self.angle = angle
    self.angle_min = angle_min
    self.angle_max = angle_max
    self.t = t
    self.draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    self.is_active = reaper.ImGui_IsItemActive(ctx)
    self.is_hovered = reaper.ImGui_IsItemHovered(ctx)
    self.center = { screen_pos[0] + radius, screen_pos[1] + radius }
    self.angle_cos = math.cos(angle)
    self.angle_sin = math.sin(angle)

    return self
end

---@param size number
---@param radius number
---@param angle number
---@param color ColorSet
---@param filled boolean
---@param segments integer
function Knob:draw_dot(
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

    reaper.ImGui_DrawList_AddCircle(
        self.draw_list,
        self.center[0] + math.cos(angle) * dot_radius,
        self.center[1] + math.sin(angle) * dot_radius,
        dot_size,
        dummyConvertColor(circle_color),
        segments
    )
end

---@param start number
---@param end_ number
---@param width number
---@param angle number
---@param color ColorSet
function Knob:draw_tick(start, end_, width, angle, color)
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
        self.center[0] + angle_cos * tick_end,
        self.center[1] + angle_sin * tick_end,
        self.center[0] + angle_cos * tick_start,
        self.center[1] + angle_sin * tick_start,
        dummyConvertColor(line_color),
        width * self.radius
    )
end

---@param size number
---@param color ColorSet
---@param filled boolean
---@param segments integer
function Knob:draw_circle(size, color, filled, segments)
    local circle_radius = size * self.radius

    local circle_color
    if self.is_active then
        circle_color = color.active
    elseif self.is_hovered then
        circle_color = color.hovered
    else
        circle_color = color.base
    end
    reaper.ImGui_DrawList_AddCircleFilled(
        self.draw_list,
        self.center[1],
        self.center[2],
        circle_radius,
        dummyConvertColor(circle_color),
        segments
    )
end

---@param radius number
---@param size number
---@param start_angle number
---@param end_angle number
---@param color ColorSet
---@param segments integer
---@param bezier_count integer
function Knob:draw_arc(
    radius,
    size,
    start_angle,
    end_angle,
    color,
    segments,
    bezier_count
)
    local track_radius = radius * self.radius
    local track_size = size * self.radius * 0.5 + 0.0001
    local circle_color
    if self.is_active then
        circle_color = color.active
    elseif self.is_hovered then
        circle_color = color.hovered
    else
        circle_color = color.base
    end
    draw_arc(
        self.draw_list,
        self.center,
        track_radius,
        start_angle,
        end_angle,
        track_size,
        color,
        segments,
        bezier_count
    )
end

---@param knob Knob
---@param circle_color ColorSet
---@param wiper_color ColorSet
---@param track_color ColorSet
function draw_wiper_knob(
    knob,
    circle_color,
    wiper_color,
    track_color
)
    knob:draw_circle(0.7, circle_color, true, 32)
    knob:draw_arc(
        0.8,
        0.41,
        knob.angle_min,
        knob.angle_max,
        track_color,
        16,
        2
    )
    if knob.t > 0.01 then
        knob:draw_arc(
            0.8,
            0.43,
            knob.angle_min,
            knob.angle,
            wiper_color,
            16,
            2)
    end
end

---@param knob Knob
---@param  wiper_color ColorSet
---@param  track_color ColorSet
function draw_wiper_only_knob(
    knob,
    wiper_color,
    track_color
)
    knob:draw_arc(
        0.8,
        0.41,
        knob.angle_min,
        knob.angle_max,
        track_color,
        32,
        2
    )
    if knob.t > 0.01 then
        knob:draw_arc(0.8, 0.43, knob.angle_min, knob.angle, wiper_color, 16, 2);
    end
end

---@param knob Knob
---@param circle_color ColorSet
---@param dot_color ColorSet
---@param track_color ColorSet
function draw_wiper_dot_knob(
    knob,
    circle_color,
    dot_color,
    track_color
)
    knob:draw_circle(0.6, circle_color, true, 32)
    knob:draw_arc(
        0.85,
        0.41,
        knob.angle_min,
        knob.angle_max,
        track_color,
        16,
        2
    )
    knob:draw_dot(0.1, 0.85, knob.angle, dot_color, true, 12)
end

---@param knob Knob
---@param circle_color ColorSet
---@param tick_color ColorSet
function draw_tick_knob(
    knob,
    circle_color,
    tick_color
)
    knob:draw_circle(0.7, circle_color, true, 32)
    knob:draw_tick(0.4, 0.7, 0.08, knob.angle, tick_color)
end

---@param knob Knob
---@param circle_color ColorSet
---@param dot_color ColorSet
function draw_dot_knob(
    knob,
    circle_color,
    dot_color
)
    knob:draw_circle(0.85, circle_color, true, 32)
    knob:draw_dot(0.12, 0.6, knob.angle, dot_color, true, 12)
end

---@param knob Knob
---@param circle_color ColorSet
---@param wiper_color ColorSet
function draw_space_knob(
    knob,
    circle_color,
    wiper_color
)
    knob:draw_circle(0.3 - knob.t * 0.1, circle_color, true, 16)
    if knob.t > 0.01 then
        knob:draw_arc(
            0.4,
            0.15,
            knob.angle_min - 1.0,
            knob.angle - 1.0,
            wiper_color,
            16,
            2
        )

        knob:draw_arc(
            0.6,
            0.15,
            knob.angle_min + 1.0,
            knob.angle + 1.0,
            wiper_color,
            16,
            2
        )

        knob:draw_arc(
            0.8,
            0.15,
            knob.angle_min + 3.0,
            knob.angle + 3.0,
            wiper_color,
            16,
            2
        )
    end
end

---@param knob Knob
---@param steps integer
---@param circle_color ColorSet
---@param dot_color ColorSet
---@param step_color ColorSet
function draw_stepped_knob(
    knob,
    steps,
    circle_color,
    dot_color,
    step_color
)
    -- iterate through the steps
    for n = 1, steps do
        local a = n / (steps - 1)
        local angle = knob.angle_min + (knob.angle_max - knob.angle_min) * a
        knob:draw_tick(0.7, 0.9, 0.04, angle, step_color)
    end
    knob:draw_circle(0.6, circle_color, true, 32)
    knob:draw_dot(0.12, 0.4, knob.angle, dot_color, true, 12)
end

---@param ctx ImGui_Context
---@param label string
---@param width number
function knob_title(
    ctx,
    label,
    width
)
    local size = reaper.ImGui_CalcTextSize(ctx, label, nil, nil, false, width)
    local old_cursor_pos = reaper.ImGui_GetCursorPos(ctx);
    reaper.Imgui_SetCursor(
        ctx,
        old_cursor_pos[0] + (width - size[0]) * 0.5,
        old_cursor_pos[1]
    )
    reaper.ImGui_Text(ctx, label)

    reaper.Imgui_SetCursor(
        ctx,
        old_cursor_pos[0],
        select(2, reaper.ImGui_GetCursorPos(ctx))
    )
end

---@param ctx ImGui_Context
---@param id string
---@param title string
---@param p_value number
---@param v_min number
---@param v_max number
---@param v_default number
---@param format string
function knob_with_drag(
    ctx,
    id,
    title,
    p_value,
    v_min,
    v_max,
    v_default,
    format
)
    local width = reaper.ImGui_GetTextLineHeight(ctx) * 4.0
    reaper.ImGui_PushItemWidth(ctx, width)
    knob_title(ctx, title, width)

    local knob = Knob.new(ctx, id, p_value, v_min, v_max, v_default, width * 0.5, true)
    -- reaper.ImGui_DragInt()
    -- add a drag here
    reaper.ImGui_DragDouble(
        ctx,
        "###" .. id .. "_KNOB_DRAG_CONTROL_",
        knob.p_value,
        (v_max - v_min) / 1000.0,
        v_min,
        v_max,
        format
    )
    reaper.ImGui_PopItemWidth(ctx)
    return knob
end
