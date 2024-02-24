dofile("/home/antoine/Documents/Experiments/lua/debug_connect.lua")
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
    reaper.ImGui_BeginTable(self.ctx, "##knobs", 7)
    local knobs = {}
    -- for i in ipairs(self.values) do
    --     local knob = Knobs.knob_with_drag(self.ctx,
    --         "knob" .. i,
    --         "Gain" .. i,
    --         self.values[i],
    --         self.min,
    --         self.max,
    --         self.default,
    --         self.format)
    --     table.insert(knobs, knob)
    -- end

    reaper.ImGui_TableNextColumn(self.ctx)
    Knobs.draw_wiper_knob(
    -- self.my_knob,
        Knobs.knob_with_drag(self.ctx,
            "knob1",
            "Gain1",
            self.values[1],
            self.min,
            self.max,
            self.default,
            self.format),
        self.colors.base,
        self.colors.base,
        self.colors.base
    )
    reaper.ImGui_TableNextColumn(self.ctx)
    Knobs.draw_wiper_dot_knob(
    -- self.my_knob,
        Knobs.knob_with_drag(self.ctx,
            "knob2",
            "Gain2",
            self.values[2],
            self.min,
            self.max,
            self.default,
            self.format),
        self.colors.base,
        self.colors.highlight,
        self.colors.lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    Knobs.draw_wiper_only_knob(
        Knobs.knob_with_drag(self.ctx,
            "knob3",
            "Gain3",
            self.values[3],
            self.min,
            self.max,
            self.default,
            self.format),
        self.colors.base,
        self.colors.lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    Knobs.draw_tick_knob(
        Knobs.knob_with_drag(self.ctx,
            "knob4",
            "Gain4",
            self.values[4],
            self.min,
            self.max,
            self.default,
            self.format),
        self.colors.base,
        self.colors.lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    Knobs.draw_dot_knob(
        Knobs.knob_with_drag(self.ctx,
            "knob5",
            "Gain5",
            self.values[5],
            self.min,
            self.max,
            self.default,
            self.format),
        self.colors.base,
        self.colors.lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    Knobs.draw_space_knob(
        Knobs.knob_with_drag(self.ctx,
            "knob6",
            "Gain6",
            self.values[6],
            self.min,
            self.max,
            self.default,
            self.format),
        self.colors.base,
        self.colors.lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    Knobs.draw_stepped_knob(
        Knobs.knob_with_drag(self.ctx,
            "knob7",
            "Gain7",
            self.values[7],
            self.min,
            self.max,
            self.default,
            self.format),
        7,
        self.colors.base,
        self.colors.highlight,
        self.colors.lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

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
    self.name = "knobs demo"
    self.values = { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 }
    self.min = -6.0;
    self.max = 6.0;
    self.default = 0.0;
    self.format = "%.2fdB";

    self.my_knob = Knobs.Knob.new(self.ctx,
        "knob1",
        self.values[1],
        self.min,
        self.max,
        self.default,
        reaper.ImGui_GetTextLineHeight(self.ctx) * 4.0 * 0.5,
        false)

    return self
end

demo:init():main()
