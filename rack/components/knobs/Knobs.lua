-- dofile("/home/antoine/Documents/Experiments/lua/debug_connect.lua")
---This is a port of imgui-rs-knobs
--https://github.com/DGriffin91/imgui-rs-knobs

local text_helpers = require("helpers.text")
local ColorSet = require("helpers.ColorSet")
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
            circle_color,
            segments
        )
    else
        reaper.ImGui_DrawList_AddCircle(
            self._draw_list,
            self._center_x + math.cos(angle) * dot_radius,
            self._center_y + math.sin(angle) * dot_radius,
            dot_size,
            circle_color,
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
        line_color,
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
            circle_color,
            segments
        )
    else
        reaper.ImGui_DrawList_AddCircle(
            self._draw_list,
            self._center_x,
            self._center_y,
            circle_radius,
            circle_color,
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
    reaper.ImGui_DrawList_PathStroke(self._draw_list, circle_color, nil, track_size)
    reaper.ImGui_DrawList_PathClear(self._draw_list)
end

---In practice, you probably want to dodge creating a new knob at every loop…
---@param ctx ImGui_Context
---@param id string
---@param param ParamData
---@param radius number
---@param controllable boolean
---@param on_activate? function
---@param dot_color ColorSet
---@param track_color ColorSet
---@param circle_color ColorSet
---@param text_color integer
function Knob.new(
    ctx,
    id,
    param,
    radius,
    controllable,
    on_activate,
    dot_color,
    track_color,
    circle_color,
    text_color
)
    ---@class Knob
    local new_knob = {}
    setmetatable(new_knob, { __index = Knob })
    local angle_min = math.pi * 0.75
    local angle_max = math.pi * 2.25
    local t = (param.details.value - param.details.minval) / (param.details.maxval - param.details.minval)
    local angle = angle_min + (angle_max - angle_min) * t
    local value_changed = false
    new_knob._ctx = ctx
    new_knob._id = id
    new_knob._label = param.name
    new_knob._param = param
    new_knob._radius = radius
    new_knob._controllable = controllable
    new_knob._value_changed = value_changed
    new_knob._angle = angle
    new_knob._angle_min = angle_min
    new_knob._angle_max = angle_max
    new_knob._t = t
    new_knob._draw_list = reaper.ImGui_GetWindowDrawList(ctx)
    new_knob._is_active = reaper.ImGui_IsItemActive(ctx)
    new_knob._is_hovered = reaper.ImGui_IsItemHovered(ctx)
    new_knob._on_activate = on_activate
    local draw_cursor_x, draw_cursor_y = reaper.ImGui_GetCursorScreenPos(ctx)
    new_knob._center_x = draw_cursor_x + new_knob._radius
    new_knob._center_y = draw_cursor_y + new_knob._radius
    new_knob._angle_cos = math.cos(new_knob._angle)
    new_knob._angle_sin = math.sin(new_knob._angle)
    new_knob.dot_color = dot_color
    new_knob.track_color = track_color
    new_knob.text_color = text_color
    new_knob.circle_color = circle_color
    --- use when layout editor is open and the current param isn't selected
    new_knob._dot_color_editing = ColorSet.deAlpha(dot_color)
    --- use when layout editor is open and the current param isn't selected
    new_knob._track_color_editing = ColorSet.deAlpha(track_color)
    --- use when layout editor is open and the current param isn't selected
    new_knob._text_color_editing = text_color & 0x55
    --- use when layout editor is open and the current param isn't selected
    new_knob._circle_color_editing = ColorSet.deAlpha(circle_color)
    return new_knob
end

---@param box_width number
function Knob:__update(box_width)
    local draw_cursor_x, draw_cursor_y = reaper.ImGui_GetCursorScreenPos(self._ctx)
    local x_pos = draw_cursor_x + box_width / 2

    self._center_x = x_pos
    self._center_y = draw_cursor_y + self._radius

    local t = (self._param.details.value - self._param.details.minval) /
        (self._param.details.maxval - self._param.details.minval)
    self._angle = self._angle_min + (self._angle_max - self._angle_min) * t
end

---Draw the invisible button and handle the control
---if the knobs isn't changed, return the current value
---@return boolean rv
---@return number p_value
function Knob:__control()
    local indent_level = self._child_width / 2 - self._radius
    reaper.ImGui_Indent(self._ctx, indent_level)
    if reaper.ImGui_InvisibleButton(self._ctx, self._id, self._radius * 2.0, self._radius * 2.0) then
        if self._param.details.parent_fx.editing and self._param.details.parent_fx.setSelectedParam then
            self._param.details.parent_fx.setSelectedParam(self._param)
        end
    end


    reaper.ImGui_Unindent(self._ctx, indent_level)


    if not self._controllable then -- don’t process controls if the fx’s layout is being edited or knobs isn’t controllable
        return false, self._param.details.value
    end
    self._is_hovered = reaper.ImGui_IsItemHovered(self._ctx)

    local value_changed = false
    local is_active = reaper.ImGui_IsItemActive(self._ctx)
    if is_active ~= self._is_active then
        if is_active and self._on_activate then
            self._on_activate()
        end
        self._is_active = is_active
    end
    -- --Maybe this should be configurable
    local speed
    if reaper.ImGui_IsKeyDown(self._ctx, reaper.ImGui_Mod_Shift())
        or reaper.ImGui_IsKeyDown(self._ctx, reaper.ImGui_Mod_Alt()) then
        speed = 2000
    else
        speed = 200
    end

    local new_val = self._param.details.value
    if reaper.ImGui_IsMouseDoubleClicked(self._ctx, reaper.ImGui_MouseButton_Left()) and self._is_active then
        new_val = self._param.details.defaultval
        value_changed = true
    elseif self._is_active then
        reaper.ImGui_SetConfigVar(self._ctx, reaper.ImGui_ConfigVar_MouseDragThreshold(), 0.0001)
        local _, delta_y = reaper.ImGui_GetMouseDragDelta(self._ctx, reaper.ImGui_GetCursorPosX(self._ctx),
            reaper.ImGui_GetCursorPosY(self._ctx))

        if delta_y ~= 0.0 then
            local step = (self._param.details.maxval - self._param.details.minval) / speed
            new_val = self._param.details.value - delta_y * step
            if self._param.details.value < self._param.details.minval then new_val = self._param.details.minval end
            if self._param.details.value > self._param.details.maxval then new_val = self._param.details.maxval end
            value_changed = true
            reaper.ImGui_ResetMouseDragDelta(self._ctx, reaper.ImGui_MouseButton_Left())
        end
    end

    return value_changed, new_val
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
        reaper.ImGui_DrawList_AddTriangleFilled(self._draw_list, c.x, c.y, b.x, b.y, a.x, a.y, circle_color)
        -- reaper.ImGui_DrawList_AddCircleFilled(
        --     self.draw_list,
        --     self.center_x + math.cos(angle) * dot_radius,
        --     self.center_y + math.sin(angle) * dot_radius,
        --     dot_size,
        --     circle_color,
        --     segments
        -- )
    else
        reaper.ImGui_DrawList_AddTriangle(self._draw_list, c.x, c.y, b.x, b.y, a.x, a.y, circle_color)
        -- reaper.ImGui_DrawList_AddCircle(
        --     self.draw_list,
        --     self.center_x + math.cos(angle) * dot_radius,
        --     self.center_y + math.sin(angle) * dot_radius,
        --     dot_size,
        --     circle_color,
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
    -- self:__draw_triangle(0.1, 0.85, self.angle, dot_color, true, 12)
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
Knob.Flags = {
    NoTitle = 1, --- Hide the top title.
    NoInput = 2, --- Hide the bottom drag input.
    DragHorizontal = 3
}


---TODO figure out how to center the drag
function Knob:__with_drag()
    -- local str_w = reaper.ImGui_CalcTextSize(self._ctx, self._param.details.fmt_val or "")
    -- local padding = reaper.ImGui_GetStyleVar(self._ctx, reaper.ImGui_StyleVar_FramePadding()) * 2
    -- local cur_x = reaper.ImGui_GetCursorPosX(self._ctx)
    -- local x_pos = cur_x + box_width / 2 - str_w / 2
    --     - padding
    -- local x_pos = self._center_x - str_w / 2
    -- reaper.ImGui_SetCursorPos(self._ctx, x_pos, reaper.ImGui_GetCursorPosY(self._ctx))
    -- reaper.ImGui_SetCursorScreenPos(self._ctx, self._center_x - self._radius,
    --     self._center_y + self._radius)
    local changed, new_val = reaper.ImGui_DragDouble(
        self._ctx,
        "##" .. self._id .. "_KNOB_DRAG_CONTROL_",
        self._param.details.value,
        (self._param.details.maxval - self._param.details.minval) / 1000.0,
        self._param.details.minval,
        self._param.details.maxval,
        self._param.details.fmt_val,
        reaper.ImGui_SliderFlags_AlwaysClamp()
    )
    return changed, new_val
end

---TODO accomodate the NoInput flag
---@param variant KnobVariant
---@param flags? integer|KnobFlags
---@param param ParamData
---@param steps? integer
---@return boolean value_changed
---@return number new_value
function Knob:draw(variant,
                   flags,
                   steps,
                   param
)
    self._param = param
    local dot_color ---@type ColorSet
    local track_color ---@type ColorSet
    local circle_color ---@type ColorSet
    local text_color ---@type integer

    ---the ColorSet used by the knob when the fx’s layout is being edited and the current param isn't selected
    ---if the param is selected, the knob will use the regular colors
    if self._param.details.parent_fx.editing and not self._param._selected then
        dot_color = self._dot_color_editing
        track_color = self._track_color_editing
        text_color = self._text_color_editing
        circle_color = self._circle_color_editing
    else
        dot_color = self.dot_color
        track_color = self.track_color
        text_color = self.text_color
        circle_color = self.circle_color
    end

    local fxbox_pos_x, fxbox_pos_y         = reaper.ImGui_GetCursorPos(self._ctx)
    local fxbox_max_x, fx_box_max_y        = reaper.ImGui_GetWindowContentRegionMax(self._ctx)
    local fx_box_min_x, fx_box_min_y       = reaper.ImGui_GetWindowContentRegionMin(self._ctx)

    local screen_cursor_x, screen_cursor_y = reaper.ImGui_GetCursorScreenPos(self._ctx)
    self._child_width                      = self._radius * 2 * 1.5
    self._child_height                     = 20 + self._radius * 2 +
        reaper.ImGui_GetTextLineHeightWithSpacing(self._ctx) * 2

    -- don’t update the knob’s value if the fx’s layout is being edited
    if self._param.details.parent_fx.editing then
        self._controllable = false
        if not self._param.details.display_settings.Pos_X and not self._param.details.display_settings.Pos_Y then
            self._param.details.display_settings.Pos_X = fxbox_pos_x
            self._param.details.display_settings.Pos_Y = fxbox_pos_y
        else
            reaper.ImGui_SetCursorPosX(self._ctx, self._param.details.display_settings.Pos_X)
            reaper.ImGui_SetCursorPosY(self._ctx, self._param.details.display_settings.Pos_Y)
        end
    else
        self._controllable = true
    end
    if self._param.details.display_settings.Pos_X and self._param.details.display_settings.Pos_Y then
        reaper.ImGui_SetCursorPosX(self._ctx, self._param.details.display_settings.Pos_X)
        reaper.ImGui_SetCursorPosY(self._ctx, self._param.details.display_settings.Pos_Y)
    end

    --set background color to transparent
    reaper.ImGui_PushStyleColor(
        self._ctx,
        reaper.ImGui_Col_ChildBg(),
        0x00000000)
    reaper.ImGui_PushStyleVar(self._ctx, reaper.ImGui_StyleVar_WindowPadding(), 0, 0)
    local value_changed, new_val = false, self._param.details.value

    if reaper.ImGui_BeginChild(self._ctx, "##knob" .. self._param.details.guid, self._child_width, self._child_height, false,
            reaper.ImGui_WindowFlags_NoScrollbar()) then
        if flags == nil then
            flags = 0
        end

        if not (flags & self.Flags.NoTitle == self.Flags.NoTitle) then
            text_helpers.centerText(self._ctx, self._label, self._child_width, 2, nil, text_color)
        end

        self:__update(self._child_width)

        value_changed, new_val = self:__control()

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

        if not (flags & self.Flags.DragHorizontal == self.Flags.DragHorizontal) then
            text_helpers.centerText(self._ctx, self._param.details.fmt_val or "", self._child_width, 1, self
                ._child_width,
                text_color)
            --     local drag_changed, new_drag_val = self:__with_drag() -- FIXME
            --     if drag_changed then
            --         value_changed = drag_changed
            --         new_val = new_drag_val
            --     end
        end

        if self._param._selected then
            -- reaper.ImGui_DrawList_AddRectFilled(self._draw_list, draw_cursor_x, draw_cursor_y,
            --     draw_cursor_x + self._child_width,
            --     draw_cursor_y + child_height, 0xFFFFFFAA)
            reaper.ImGui_DrawList_AddRect(self._draw_list, screen_cursor_x, screen_cursor_y,
                screen_cursor_x + self._child_width,
                screen_cursor_y + self._child_height, 0xFF0000FF, 1.0, 0, 0.0)
        end
        self:EditControl(
            fxbox_pos_x,
            fxbox_pos_y,
            fxbox_max_x,
            fx_box_max_y,
            fx_box_min_x,
            fx_box_min_y
        )

        reaper.ImGui_EndChild(self._ctx)
    end

    reaper.ImGui_PopStyleVar(self._ctx)
    reaper.ImGui_PopStyleColor(self._ctx)
    return value_changed, (new_val or self._param.details.value)
end

---Overlay a button on top of the knob's frame
--- and retrieve whether the user is doing click+drag.
--- If so, update the knob frame's coordinates.
---
--It's easy to get confused, because this button's coordinates within the frame
--are not the same as the coordinates of the knob's frame within the fx box.
--That's why we're having to pass the details of the fx box as params.
function Knob:EditControl(
    fxbox_pos_x,
    fxbox_pos_y,
    fxbox_max_x,
    fx_box_max_y,
    fx_box_min_x,
    fx_box_min_y
)
    -- put knob at start of the current child window
    reaper.ImGui_SetCursorPosX(self._ctx, 0)
    reaper.ImGui_SetCursorPosY(self._ctx, 0)
    reaper.ImGui_Button(self._ctx, "##knob" .. self._param.details.guid, self._child_width - 2, self._child_height - 2)

    local is_active = reaper.ImGui_IsItemActive(self._ctx)

    if is_active then
        local delta_x, delta_y = reaper.ImGui_GetMouseDragDelta(
            self._ctx,
            self._param.details.display_settings.Pos_X or fxbox_pos_x,
            self._param.details.display_settings.Pos_Y or fxbox_pos_y)
        if delta_y ~= 0.0 and delta_x ~= 0.0 then
            local new_pos_x = (self._param.details.display_settings.Pos_X or fxbox_pos_x) + delta_x
            local new_pos_y = (self._param.details.display_settings.Pos_Y or fxbox_pos_y) + delta_y
            ---clamp the values within the current frame.
            ---TODO dunno why the frame is currently bigger than the window.
            if new_pos_x < fx_box_min_x then
                new_pos_x = fx_box_min_x
            elseif new_pos_x + self._child_width > fxbox_max_x then
                new_pos_x = fxbox_max_x - self._child_width
            end
            if new_pos_y < fx_box_min_y then
                new_pos_y = fx_box_min_y
            elseif new_pos_y + self._child_height > fx_box_max_y then
                new_pos_y = fx_box_max_y - self._child_height
            end

            self._param.details.display_settings.Pos_X = new_pos_x
            self._param.details.display_settings.Pos_Y = new_pos_y
            reaper.ImGui_ResetMouseDragDelta(self._ctx, reaper.ImGui_MouseButton_Left())
        end
    end
end

return Knob
