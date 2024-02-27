-- dofile("/home/antoine/Documents/Experiments/lua/debug_connect.lua")
local info = debug.getinfo(1, "S")
local internal_root_path = info.source:match(".*knobs."):sub(2)
local windows_files = internal_root_path:match("\\$")
if windows_files then
    package.path = package.path .. ";" .. internal_root_path .. "\\?.lua"
else
    package.path = package.path .. ";" .. internal_root_path .. "/?.lua"
end

local Knobs = require("Knobs")
local ColorSet = Knobs.ColorSet

local demo = {}

function demo:drawKnobs()
    reaper.ImGui_BeginTable(self.ctx, "##knobs", 10)

    reaper.ImGui_TableNextColumn(self.ctx)

    self.knobs[1]:draw(
        Knobs.Knob.KnobVariant.wiper_knob,
        self.colors.base,
        self.colors.highlight,
        self.colors.lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)


    self.knobs[2]:draw(
        Knobs.Knob.KnobVariant.draw_wiper_dot_knob,
        self.colors.base,
        self.colors.highlight,
        self.colors.lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    self.knobs[3]:draw(
        Knobs.Knob.KnobVariant.draw_wiper_only,
        self.colors.base,
        self.colors.highlight,
        self.colors.lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    self.knobs[4]:draw(
        Knobs.Knob.KnobVariant.draw_tick_knob,
        self.colors.base,
        self.colors.lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    self.knobs[5]:draw(
        Knobs.Knob.KnobVariant.draw_dot_knob,
        self.colors.base,
        self.colors.lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    self.knobs[6]:draw(
        Knobs.Knob.KnobVariant.draw_space_knob,
        self.colors.base,
        self.colors.lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    self.knobs[7]:draw(
        Knobs.Knob.KnobVariant.draw_stepped_knob,
        self.colors.base,
        self.colors.lowlight,
        nil,
        nil,
        7
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    self.knobs[8]:draw(
        Knobs.Knob.KnobVariant.draw_ableton_knob,
        self.colors.base,
        self.colors.highlight,
        self.colors.lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    self.knobs[9]:draw(
        Knobs.Knob.KnobVariant.draw_readrum_knob,
        self.colors.base,
        self.colors.highlight,
        self.colors.lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    self.knobs[10]:draw(
        Knobs.Knob.KnobVariant.draw_imgui_knob,
        self.colors.base,
        self.colors.highlight,
        self.colors.lowlight
    )
    reaper.ImGui_EndTable(self.ctx)
end

function demo:main()
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_FrameBg(), Knobs.rgbToHex(self.colors.gray.base))
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_FrameBgHovered(), Knobs.rgbToHex(self.colors.gray.active))
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_FrameBgActive(), Knobs.rgbToHex(self.colors.gray.hovered))

    local visible, open = reaper.ImGui_Begin(self.ctx, self.name, true, self.window_flags)
    self.open = open
    if visible then
        self:drawKnobs()
        reaper.ImGui_End(self.ctx)
    end

    reaper.ImGui_PopStyleColor(self.ctx, 3)
    if open then
        reaper.defer(function() self:main() end)
    end
end

function demo:init_colors()
    self.colors = {}
    local time = reaper.ImGui_GetTime(self.ctx)
    local h = math.abs(math.sin(time * 0.2))
    local s = math.abs(math.sin(time * 0.1)) * 0.5 + 0.4 * 0
    self.colors.highlight = ColorSet.new(
        hsv2rgb({ h, s, 0.75, 1.0 }),
        hsv2rgb({ h, s, 0.95, 1.0 }),
        hsv2rgb({ h, s, 1.0, 1.0 })
    )
    self.colors.base = ColorSet.new(
        hsv2rgb({ h, s, 0.5, 1.0 }),
        hsv2rgb({ h, s, 0.6, 1.0 }),
        hsv2rgb({ h, s, 0.7, 1.0 })
    )
    self.colors.lowlight = ColorSet.from(hsv2rgb({ h, s, 0.2, 1.0 }))

    local dark_gray1 = { 0.15, 0.15, 0.15, 1.0 }
    local dark_gray2 = { 0.15, 0.15, 0.15, 1.0 }
    local dark_gray3 = { 0.15, 0.15, 0.15, 1.0 }
    self.colors.gray = ColorSet.new(
        dark_gray1,
        dark_gray2,
        dark_gray3
    )
end

function demo:init()
    self.ctx = reaper.ImGui_CreateContext("fx browser")
    reaper.ImGui_SetNextWindowSize(self.ctx, 401, 200, reaper.ImGui_Cond_FirstUseEver())

    self.window_flags =
        reaper.ImGui_WindowFlags_NoScrollWithMouse()
        + reaper.ImGui_WindowFlags_NoScrollbar()
        + reaper.ImGui_WindowFlags_NoCollapse()
        + reaper.ImGui_WindowFlags_NoNav()

    self:init_colors()
    self.name     = "knobs demo"
    local min     = -6.0 -- use the same min/max for all the knobs
    local max     = 6.0
    local default = 0.0
    local format  = "%.2fdB"
    ---@type Knob[]
    self.knobs    = {}

    local width   = reaper.ImGui_GetTextLineHeight(self.ctx) * 4.0
    for idx, value in ipairs({ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 }) do
        table.insert(self.knobs,
            Knobs.Knob.new(self.ctx,
                "knob" .. idx,
                "Gain" .. idx,
                value,
                min,
                max,
                default,
                width * 0.5,
                true,
                format
            ))
    end

    return self
end

demo:init():main()
