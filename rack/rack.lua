-- dofile("/home/antoine/Documents/Experiments/lua/debug_connect.lua")
local info = debug.getinfo(1, "S")

local Os_separator = package.config:sub(1, 1)
local source = info.source:match(".*rack" .. Os_separator):sub(2)
package.path = package.path .. ";" .. source .. "?.lua"
---@type string
CurrentDirectory = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] -- GET DIRECTORY FOR REQUIRE
package.path = CurrentDirectory .. "?.lua;"

local Fx_box = require("components.Fx_box")
local menubar = require("components.menubar")
local state = require("state.state")
local actions = require("state.actions")

---Rack module
---@class Rack
local Rack = {}

---draw the fx list
function Rack:drawFxList()
    if not self.state.Track then
        return
    end

    if self.state.Track.fx_list == nil or #self.state.Track.fx_list == 0 then
        --- pass `is_last` to `spaceBtwFx` to display the fx browser on click
        local is_last = true
        Fx_box:spaceBtwFx(is_last)
    end
    for n, fx in ipairs(self.state.Track.fx_list) do
        reaper.ImGui_PushID(self.ctx, n)
        Fx_box:display(fx)
        reaper.ImGui_PopID(self.ctx)
    end
end

function Rack:main()
    -- update state and actions at every loop
    self.state:update():getTrackFx()
    self.actions:update()
    self.actions:manageDock()

    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_WindowBg(), --background color
        0x0000000)

    local imgui_visible, imgui_open = reaper.ImGui_Begin(self.ctx, "rack", true, self.window_flags)
    if imgui_visible then
        --display the rack
        menubar:display()
        self:drawFxList()
    end


    reaper.ImGui_PopStyleColor(self.ctx) -- Remove background color
    reaper.ImGui_End(self.ctx)
    if not imgui_open or reaper.ImGui_IsKeyPressed(self.ctx, 27) then
        reaper.ImGui_DestroyContext(self.ctx)
    else
        reaper.defer(function() self:main() end)
    end
end

---Create the ImGui context and setup the window size
function Rack:init()
    local ctx_flags = reaper.ImGui_ConfigFlags_DockingEnable()
    self.ctx = reaper.ImGui_CreateContext("rack",
        ctx_flags)
    reaper.ImGui_SetNextWindowSize(self.ctx, 500, 440, reaper.ImGui_Cond_FirstUseEver())
    local window_flags =
        reaper.ImGui_WindowFlags_NoScrollWithMouse()
        + reaper.ImGui_WindowFlags_NoScrollbar()
        + reaper.ImGui_WindowFlags_MenuBar()
        + reaper.ImGui_WindowFlags_NoCollapse()
        + reaper.ImGui_WindowFlags_NoNav()
    self.window_flags = window_flags -- tb used in main()


    self.state = state:init()                               -- initialize state, query selected track and its fx
    self.actions = actions:init(self.ctx, self.state.Track) -- always init actions after state

    -- initialize components by passing them the rack's state
    Fx_box:init(self)
    menubar:init(self)
    return self
end

reaper.defer(function() Rack:init():main() end)
