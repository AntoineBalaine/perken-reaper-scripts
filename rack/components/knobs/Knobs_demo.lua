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
    local time = reaper.ImGui_GetTime(self.ctx)
    local h = math.abs(math.sin(time * 0.2))
    local s = math.abs(math.sin(time * 0.1)) * 0.5 + 0.4 * 0
    local highlight = ColorSet.new(
        hsv2rgb({ h, s, 0.75, 1.0 }),
        hsv2rgb({ h, s, 0.95, 1.0 }),
        hsv2rgb({ h, s, 1.0, 1.0 })
    )
    local base = ColorSet.new(
        hsv2rgb({ h, s, 0.5, 1.0 }),
        hsv2rgb({ h, s, 0.6, 1.0 }),
        hsv2rgb({ h, s, 0.7, 1.0 })
    )
    local lowlight = ColorSet.from(hsv2rgb({ h, s, 0.2, 1.0 }))

    reaper.ImGui_BeginTable(self.ctx, "##knobs", 7)
    local knobs = {}
    for i in ipairs(self.values) do
        local knob = Knobs.knob_with_drag(self.ctx,
            "knob" .. i,
            "Gain" .. i,
            self.values[i],
            self.min,
            self.max,
            self.default,
            self.format)
        table.insert(knobs, knob)
    end


    Knobs.draw_wiper_knob(
        knobs[1],
        base,
        highlight,
        lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    Knobs.draw_wiper_dot_knob(
        knobs[2],
        base,
        highlight,
        lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    Knobs.draw_wiper_only_knob(
        knobs[3],
        base,
        lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    Knobs.draw_tick_knob(
        knobs[4],
        base,
        lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    Knobs.draw_dot_knob(
        knobs[5],
        base,
        lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    Knobs.draw_space_knob(
        knobs[6],
        base,
        lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    Knobs.draw_stepped_knob(
        knobs[7],
        7,
        base,
        highlight,
        lowlight
    )
    reaper.ImGui_TableNextColumn(self.ctx)

    reaper.ImGui_EndTable(self.ctx)
end

function demo:main()
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_FrameBg(), self.colors.dark_gray1)
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_FrameBgHovered(), self.colors.dark_gray2)
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_FrameBgActive(), self.colors.dark_gray3)
    reaper.ImGui_SetNextWindowSize(self.ctx, 400, 200)

    local visible, open = reaper.ImGui_Begin(self.ctx, self.name, true)
    self.open = open
    if visible then
        reaper.ImGui_Text(self.ctx, "hello world")
        reaper.ImGui_End(self.ctx)
    end

    reaper.ImGui_PopStyleColor(self.ctx, 3)
    if open then
        reaper.defer(function() self:main() end)
    end
end

function demo:init()
    self.ctx = reaper.ImGui_CreateContext("fx browser")
    self.colors = {}
    self.colors.dark_gray1 = Knobs.rgbToHex({ 0.15, 0.15, 0.15, 1.0 })
    self.colors.dark_gray2 = Knobs.rgbToHex({ 0.15, 0.15, 0.15, 1.0 })
    self.colors.dark_gray3 = Knobs.rgbToHex({ 0.15, 0.15, 0.15, 1.0 })

    self.values = { 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 }
    self.min = -6.0;
    self.max = 6.0;
    self.default = 0.0;
    self.format = "%.2fdB";

    return self
end

demo:init():main()
