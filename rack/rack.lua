local info = debug.getinfo(1, "S")

local Os_separator = package.config:sub(1, 1)
local source = info.source:match(".*rack" .. Os_separator):sub(2)
package.path = package.path .. ";" .. source .. "?.lua"
---@type string
CurrentDirectory = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] -- GET DIRECTORY FOR REQUIRE
package.path = CurrentDirectory .. "?.lua;"

local menubar = require("components.menubar")
local actions = require("actions")

---@alias Rack_Context table

---This the rack's global context. It is NOT the same as the ImGui_Context
-- The rack's context is used to store global variables
---@type Rack_Context
local Ctx = { actions = actions }

---Rack module
local rack = {}

---Create the ImGui context and setup the window size
---@return ImGui_Context
function rack.SetupImGui()
    local flags = reaper.ImGui_ConfigFlags_DockingEnable()
    local ctx = reaper.ImGui_CreateContext("rack",
        flags)
    reaper.ImGui_SetNextWindowSize(ctx, 500, 440, reaper.ImGui_Cond_FirstUseEver())
    return ctx
end

---@param IgCtx ImGui_Context
function rack.display(IgCtx)
    if actions.dock ~= nil then                         -- if the user clicked «dock» or «undock»
        if actions.dock then
            reaper.ImGui_SetNextWindowDockID(IgCtx, -1) -- set to docked
            Ctx.actions.dock = nil
        else
            reaper.ImGui_SetNextWindowDockID(IgCtx, 0) -- set to undocked
            Ctx.actions.dock = nil
        end
    end
    reaper.ImGui_PushStyleColor(IgCtx, reaper.ImGui_Col_WindowBg(), --background color
        0x0000000)

    local window_flags =
        reaper.ImGui_WindowFlags_NoScrollWithMouse()
        + reaper.ImGui_WindowFlags_NoScrollbar()
        + reaper.ImGui_WindowFlags_MenuBar()
        + reaper.ImGui_WindowFlags_NoCollapse()
        + reaper.ImGui_WindowFlags_NoNav()
    local imgui_visible, imgui_open = reaper.ImGui_Begin(IgCtx, "rack", true,
        window_flags)
    if imgui_visible then
        --display the rack
        menubar:display()
    end


    reaper.ImGui_PopStyleColor(IgCtx) -- Remove background
    reaper.ImGui_End(IgCtx)
    if not imgui_open or reaper.ImGui_IsKeyPressed(IgCtx, 27) then
        reaper.ImGui_DestroyContext(IgCtx)
    else
        reaper.defer(function() rack.display(IgCtx) end)
    end
end

--- ImGuiContext
local IgCtx = rack.SetupImGui()
menubar:init(IgCtx, Ctx)

rack.display(IgCtx)
