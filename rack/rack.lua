local info = debug.getinfo(1, "S")

local Os_separator = package.config:sub(1, 1)
local source = info.source:match(".*rack" .. Os_separator):sub(2)
package.path = package.path .. ";" .. source .. "?.lua"
---@type string
CurrentDirectory = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] -- GET DIRECTORY FOR REQUIRE
package.path = CurrentDirectory .. "?.lua;"

local menubar = require("components.menubar")
local state = require("state.state")


---Rack module
local Rack = {}

---draw the fx list
function Rack:drawFxList()
    if not self.state.Track then
        return
    end
end

function Rack:main()
    if self.actions.dock ~= nil then                       -- if the user clicked «dock» or «undock»
        if self.actions.dock then
            reaper.ImGui_SetNextWindowDockID(self.ctx, -1) -- set to docked
            self.actions.dock = nil
        else
            reaper.ImGui_SetNextWindowDockID(self.ctx, 0) -- set to undocked
            self.actions.dock = nil
        end
    end
    reaper.ImGui_PushStyleColor(self.ctx, reaper.ImGui_Col_WindowBg(), --background color
        0x0000000)

    local imgui_visible, imgui_open = reaper.ImGui_Begin(self.ctx, "rack", true, self.window_flags)
    if imgui_visible then
        --display the rack
        menubar:display()
        self:drawFxList()
    end


    reaper.ImGui_PopStyleColor(self.ctx) -- Remove background
    reaper.ImGui_End(self.ctx)
    if not imgui_open or reaper.ImGui_IsKeyPressed(self.ctx, 27) then
        reaper.ImGui_DestroyContext(self.ctx)
    else
        reaper.defer(function() self:main() end)
    end
end

---Create the ImGui context and setup the window size
---@return ImGui_Context
function Rack:init()
    local window_flags =
        reaper.ImGui_WindowFlags_NoScrollWithMouse()
        + reaper.ImGui_WindowFlags_NoScrollbar()
        + reaper.ImGui_WindowFlags_MenuBar()
        + reaper.ImGui_WindowFlags_NoCollapse()
        + reaper.ImGui_WindowFlags_NoNav()
    self.window_flags = window_flags
    self.actions = { dock = false }
    local flags = reaper.ImGui_ConfigFlags_DockingEnable()
    local ctx = reaper.ImGui_CreateContext("rack",
        flags)
    reaper.ImGui_SetNextWindowSize(ctx, 500, 440, reaper.ImGui_Cond_FirstUseEver())
    self.ctx = ctx
    self.state = state:init()
    menubar:init(self) -- pass the rack to the menubar, so that it can access its internal state.
    return self
end

reaper.defer(function() Rack:init():main() end)
