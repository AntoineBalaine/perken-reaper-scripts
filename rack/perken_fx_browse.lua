dofile("/home/antoine/Documents/Experiments/lua/debug_connect.lua")
local reaper = reaper
local os_separator = package.config:sub(1, 1)
package.path = debug.getinfo(1, "S").source:match [[^@?(.*[\/])[^\/]-$]] .. "?.lua;" -- GET DIRECTORY FOR REQUIRE
local fx_browser = require("fs_utils.perken_fx_browser")

local Browser = {}

---@param template string
---@param replace? boolean
---@return boolean retval
function Browser:loadTrackTemplate(template, replace)
    local track_template_path = reaper.GetResourcePath() .. os_separator .. "TrackTemplates" .. template
    if replace then
        local file = io.open(track_template_path, 'r')
        if file then
            local chunk = file:read('a')
            reaper.SetTrackStateChunk(self.TRACK, chunk, true)
            file:close()
            return true
        else
            return false
        end
    else
        reaper.Main_openProject(track_template_path)
        return true
    end
end

---Initialize the state of the Fx-Browser component.
--Pull the data from the fx parser module and create the ImGui context.
function Browser:init()
    self.WANT_REFRESH = nil
    self.LAST_USED_FX = nil
    self.ctx = reaper.ImGui_CreateContext("fx browser")
    self.plugin_list,
    self.fx_tags,
    self.custom_categories,
    self.fx_chains,
    self.track_templates,
    self.plugin_by_type =
        fx_browser
        .GenerateFxList() ---pull the data from the fx parser module
    return self
end

---Recursively draw the fx chains or track templates
---pass the `isFxChain` boolean to distinguish between the two
---@param directory Directory
---@param isFxChain boolean
function Browser:drawFxChainOrTrackTemplate(directory, isFxChain)
    local extension = isFxChain and ".RfxChain" or ".RTrackTemplate"
    for _, subdir in ipairs(directory.subdirs or {}) do -- directory display
        ---@type string
        ---format the path to only get the last folder name
        local fmt_path = subdir.path:reverse():match("([^" .. os_separator .. "]*)" .. os_separator):reverse()
        if reaper.ImGui_BeginMenu(self.ctx, fmt_path) then
            self:drawFxChainOrTrackTemplate(subdir, isFxChain) -- display the files in the current subdirectory
            reaper.ImGui_EndMenu(self.ctx)
        end
    end
    for _, file in ipairs(directory.files or {}) do -- files display
        if reaper.ImGui_Selectable(self.ctx, file) then
            if isFxChain then
                reaper.TrackFX_AddByName(self.track, table.concat({ directory.path, os_separator, file, extension }),
                    false,
                    -1000 - reaper.TrackFX_GetCount(self.track))
            else
                local template_str = table.concat({ directory.path, os_separator, file, extension })
                ---TODO figure out why Sexan calls this function twice in his implementation
                --currently this is adapted from Sexan's Fx browser
                local rv = self:loadTrackTemplate(template_str) -- ADD NEW TRACK FROM TEMPLATE
                if rv then
                    self:loadTrackTemplate(template_str, true)  -- REPLACE CURRENT TRACK WITH TEMPLATE
                end
            end
        end
    end
end

---Draw the full plugins list.
--Not very useful atm, might be better to split between types of plugins (instruments, fx, etc.).
function Browser:drawFX()
    if reaper.ImGui_BeginMenu(self.ctx, "all plugins") then
        for i, plugin in ipairs(self.plugin_list) do
            if reaper.ImGui_Selectable(self.ctx, plugin.name) then
                reaper.TrackFX_AddByName(self.track, plugin.name, false,
                    -1000 - reaper.TrackFX_GetCount(self.track))
                self.LAST_USED_FX = plugin.name
            end
        end

        reaper.ImGui_EndMenu(self.ctx)
    end
end

function Browser:drawMenus()
    if reaper.ImGui_BeginMenu(self.ctx, "fx chains") then -- draw fx chains menu
        self:drawFxChainOrTrackTemplate(self.fx_chains, true)
        reaper.ImGui_EndMenu(self.ctx)
    end
    if reaper.ImGui_BeginMenu(self.ctx, "track templates") then -- draw track templates menu
        self:drawFxChainOrTrackTemplate(self.track_templates, false)
        reaper.ImGui_EndMenu(self.ctx)
    end

    self:drawFX()                                          -- draw all plugins menu

    if reaper.ImGui_Selectable(self.ctx, "container") then -- add container if clicked
        reaper.TrackFX_AddByName(self.track, "Container", false,
            -1000 - reaper.TrackFX_GetCount(self.track))
        self.LAST_USED_FX = "Container"
    end
    if reaper.ImGui_Selectable(self.ctx, "video processor") then -- add video processor if clicked
        reaper.TrackFX_AddByName(self.track, "Video processor", false,
            -1000 - reaper.TrackFX_GetCount(self.track))
        self.LAST_USED_FX = "Video processor"
    end
    if self.LAST_USED_FX then
        if reaper.ImGui_Selectable(self.ctx, "recent: " .. self.LAST_USED_FX) then
            reaper.TrackFX_AddByName(self.track, self.LAST_USED_FX, false,
                -1000 - reaper.TrackFX_GetCount(self.track))
        end
    end
end

---Main loop function
--This runs at every defer cycle (every frame).
function Browser:main()
    self.track = reaper.GetSelectedTrack(0, 0)
    local visible, open = reaper.ImGui_Begin(self.ctx, "fx browser", true)
    if visible then
        if self.track then
            --UPDATE FX CHAINS (WE DONT NEED TO RESCAN EVERYTHING IF NEW CHAIN WAS CREATED BY SCRIPT)
            -- if self.WANT_REFRESH then
            --     self.WANT_REFRESH = nil
            --     fx_browser.UpdateChainsTrackTemplates(fx_browser.CAT)
            -- end
            -- RESCAN FILE LIST
            -- if reaper.ImGui_Button(self.ctx, "RESCAN PLUGIN LIST") then
            --     FX_LIST_TEST, CAT_TEST = fx_browser.makeFXFiles()
            -- end
            -- Frame()
            self:drawMenus()
        else
            reaper.ImGui_Text(self.ctx, "please select a track")
        end
        reaper.ImGui_End(self.ctx)
    end
    if open then
        reaper.defer(function() self:main() end)
    end
end

reaper.defer(function() Browser:init():main() end)
