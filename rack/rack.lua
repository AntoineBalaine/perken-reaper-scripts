local info = debug.getinfo(1, "S")

local Os_separator = package.config:sub(1, 1)
local source = info.source:match(".*rack" .. Os_separator):sub(2)
package.path = package.path .. ";" .. source .. "?.lua"
---@type string
CurrentDirectory = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] -- GET DIRECTORY FOR REQUIRE
package.path = CurrentDirectory .. "?.lua;"

-- local menubar = require("components.menubar")

local rack = {}

---Create the ImGui context and setup the window size
---@return ImGui_Context
function rack.SetupImGui()
    local ctx = reaper.ImGui_CreateContext("rack", reaper.ImGui_ConfigFlags_DockingEnable())
    reaper.ImGui_SetNextWindowSize(ctx, 500, 440, reaper.ImGui_Cond_FirstUseEver())
    return ctx
end

---@param ctx ImGui_Context
function rack.display(ctx)
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(),
        0x0000000)
    local imgui_visible, imgui_open = reaper.ImGui_Begin(ctx, "rack", true,
        reaper.ImGui_WindowFlags_AlwaysVerticalScrollbar())
    if imgui_visible then
        --display the rack
        reaper.ImGui_Text(ctx, 'Style Editor')
        -- menubar:init(ctx):display()
    end


    reaper.ImGui_PopStyleColor(ctx) -- Remove black opack background
    reaper.ImGui_End(ctx)
    if not imgui_open or reaper.ImGui_IsKeyPressed(ctx, 27) then
        reaper.ImGui_DestroyContext(ctx)
    else
        reaper.defer(function() rack.display(ctx) end)
    end
end

local ctx = rack.SetupImGui()
-- menubar:init(ctx)

rack.display(ctx)
