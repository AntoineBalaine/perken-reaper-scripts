-- dofile("/home/antoine/Documents/Experiments/lua/debug_connect.lua")
--[[
Based off Sexan’s fx browser.
Read the fx list from reaper’s api and display it in an ImGui window.
When user selects a plugin from the list, the component calls the reaper api load it.
Bear in mind that this runs on its own defer cycle,
The fx rack only invokes it from the outside, it doesn’t call its draw function directly.
]]
local os_separator = package.config:sub(1, 1)
local fx_parser = require("parsers.fx_parser")

---Coerce `Input` number to be between `Min` and `Max`
---@param Input number
---@param Min number
---@param Max number
---@return number
local function fitBetweenMinMax(Input, Min, Max)
    if Input >= Max then
        Input = Max
    elseif Input <= Min then
        Input = Min
    else
        Input = Input
    end
    return Input
end

---@class FXBrowser
local Browser = {}

---@param template string template's file name
---@param replace? boolean
---@return boolean retval
function Browser:loadTrackTemplate(template, replace)
    local track_template_path = reaper.GetResourcePath() .. os_separator .. "TrackTemplates" .. template
    if replace then
        local file = io.open(track_template_path, 'r')
        if file then
            local chunk = file:read('a')
            reaper.SetTrackStateChunk(self.track, chunk, true)
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
---@param ctx? ImGui_Context
---@param track? MediaTrack
function Browser:init(ctx, track)
    self.name = "Fx Browser"
    if not ctx then
        self.ctx = reaper.ImGui_CreateContext("fx browser")
    else
        self.ctx = ctx
    end
    if track then
        self.track = track
    end
    self.open = false
    self.last_used_fx = nil ---@type string last used fx name
    self.filter = "" ---@type string filter string from the user input
    self.selected_entry = nil ---@type number selected entry in the filtered fx list (used for keyboard navigation)
    self.filtered_fx = {} ---@type FX[]
    self.plugin_list,
    self.fx_tags,
    self.custom_categories,
    self.fx_chains,
    self.track_templates,
    self.plugin_by_type =
        fx_parser
        .GenerateFxList() ---pull the data from the fx parser module
    return self
end

---filter the plugins based on the user's input
---@param new_filter string
function Browser:filterActions(new_filter)
    if new_filter == "" then
        for k, _ in ipairs(self.filtered_fx) do
            self.filtered_fx[k] = nil
        end
        return
    end
    if new_filter == self.filter then return self.filtered_fx end
    new_filter = new_filter:match '^%s*(.*)' -- trim white space
    for k, _ in ipairs(self.filtered_fx) do
        self.filtered_fx[k] = nil
    end
    -- find plugins whichs name match the filter, and insert them into the filter_fx
    for _, fx in ipairs(self.plugin_list) do
        local name = fx.name:lower()
        local found = true
        for word in new_filter:gmatch("%S+") do
            if not name:find(word:lower(), 1, true) then
                found = false
                break
            end
        end
        if found then
            ---@class FX
            ---@field score number
            fx.score = fx.name:len() - new_filter:len()
            table.insert(self.filtered_fx, fx)
        end
    end
    if #self.filtered_fx > 2 then -- if there's multiple matches, sort them
        table.sort(self.filtered_fx,
            ---@param a FX
            ---@param b FX
            function(a, b)
                if (a.score < b.score) then
                    return true            -- primary sort on position -> a before b
                elseif (a.score > b.score) then
                    return false           -- primary sort on position -> b before a
                else
                    return a.name < b.name -- primary sort tied, resolve w secondary sort on rank
                end
            end)
    end
    self.filter = new_filter -- update the filter
end

---Draw the filter input box and the filtered fx list.
---@return boolean filtered_fx_len length of the filtered fx list
function Browser:filterBox()
    local MAX_FX_SIZE = 300
    reaper.ImGui_PushItemWidth(self.ctx, MAX_FX_SIZE)
    if reaper.ImGui_IsWindowAppearing(self.ctx) then -- focus the input box when the window appears
        reaper.ImGui_SetKeyboardFocusHere(self.ctx)
    end

    local _, new_filter = reaper.ImGui_InputTextWithHint(self.ctx, "##input", "SEARCH FX", self.filter) -- input box
    self:filterActions(new_filter)                                                                      -- get list of filtered fx based on user input

    self.selected_entry = fitBetweenMinMax(self.selected_entry or 1, 1, #self.filtered_fx)
    if #self.filtered_fx > 0 then
        ---set how many fx are displayed in the filter list
        local filter_height = #self.filtered_fx == 0 and 0 or
            (#self.filtered_fx > 40 and 20 * 17 or (17 * #self.filtered_fx))
        if reaper.ImGui_BeginChild(self.ctx, "##popupp", MAX_FX_SIZE, filter_height) then -- display filtered fx
            for i, fx in ipairs(self.filtered_fx) do
                if reaper.ImGui_Selectable(self.ctx, fx.name, i == self.selected_entry) then
                    reaper.TrackFX_AddByName(self.track, fx.name, false, -1000 - reaper.TrackFX_GetCount(self.track))
                    reaper.ImGui_CloseCurrentPopup(self.ctx)
                    self.last_used_fx = fx.name
                    self.open = false
                end
            end
            reaper.ImGui_EndChild(self.ctx)
        end
        -- keyboard navigation
        if reaper.ImGui_IsKeyPressed(self.ctx, reaper.ImGui_Key_Enter()) then -- add fx if «enter» is pressed
            local selected_fx = self.filtered_fx[self.selected_entry]
            reaper.TrackFX_AddByName(self.track, selected_fx.name, false,
                -1000 - reaper.TrackFX_GetCount(self.track))
            self.last_used_fx = selected_fx.name -- update state
            self.selected_entry = nil
            self.filter = ""
            reaper.ImGui_CloseCurrentPopup(self.ctx)
            self.open = false
        elseif reaper.ImGui_IsKeyPressed(self.ctx, reaper.ImGui_Key_UpArrow()) then -- navigate the filter list with arrows
            local updatedIdx = self.selected_entry - 1
            if updatedIdx > 0 then
                self.selected_entry = updatedIdx
            end
        elseif reaper.ImGui_IsKeyPressed(self.ctx, reaper.ImGui_Key_DownArrow()) then
            local updatedIdx = self.selected_entry + 1
            if updatedIdx <= filter_height then
                self.selected_entry = updatedIdx
            end
        end
    end
    if reaper.ImGui_IsKeyPressed(self.ctx, reaper.ImGui_Key_Escape()) then -- close the popup if «escape» is pressed
        self.filter = ""
        reaper.ImGui_CloseCurrentPopup(self.ctx)
    end
    return #self.filtered_fx > 0
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
                self.open = false
            else
                local template_str = table.concat({ directory.path, os_separator, file, extension })
                ---TODO figure out why Sexan calls this function twice in his implementation
                --currently this is adapted from Sexan's Fx browser
                local rv = self:loadTrackTemplate(template_str) -- ADD NEW TRACK FROM TEMPLATE
                if rv then
                    self:loadTrackTemplate(template_str, true)  -- REPLACE CURRENT TRACK WITH TEMPLATE
                    self.open = false
                end
            end
        end
    end
end

---Draw the given plugins list.
---@param list (FX|string)[]
---@param menu_name string
function Browser:drawFX(list, menu_name)
    if reaper.ImGui_BeginMenu(self.ctx, menu_name) then
        for _, plugin in ipairs(list) do
            local name = type(plugin) == "string" and plugin or plugin.name
            if reaper.ImGui_Selectable(self.ctx, name) then
                reaper.TrackFX_AddByName(self.track, name, false,
                    -1000 - reaper.TrackFX_GetCount(self.track))
                self.last_used_fx = name
                self.open = false
            end
        end

        reaper.ImGui_EndMenu(self.ctx)
    end
end

---draw fx categories menu eg. "CLAP", "VST", "VSTi", etc.
function Browser:drawAllPlugins()
    if reaper.ImGui_BeginMenu(self.ctx, "all plugins") then
        for category_name, category in pairs(self.plugin_by_type) do
            self:drawFX(category, category_name)
        end
        reaper.ImGui_EndMenu(self.ctx)
    end
end

function Browser:drawFxTags()
    if reaper.ImGui_BeginMenu(self.ctx, "developers") then -- developers list
        for developer_name, developer in pairs(self.fx_tags.developers) do
            self:drawFX(developer, developer_name)
        end
        reaper.ImGui_EndMenu(self.ctx)
    end
    if reaper.ImGui_BeginMenu(self.ctx, "custom categories") then -- custom categories list
        for category_name, category in pairs(self.fx_tags.categories) do
            self:drawFX(category, category_name)
        end
        reaper.ImGui_EndMenu(self.ctx)
    end
end

function Browser:drawMenus()
    local filtered_fx_count = self:filterBox()
    if filtered_fx_count then -- don't display the component if there's some filtered fx
        return
    end
    if reaper.ImGui_BeginMenu(self.ctx, "fx chains") then -- draw fx chains menu
        self:drawFxChainOrTrackTemplate(self.fx_chains, true)
        reaper.ImGui_EndMenu(self.ctx)
    end
    if reaper.ImGui_BeginMenu(self.ctx, "track templates") then -- draw track templates menu
        self:drawFxChainOrTrackTemplate(self.track_templates, false)
        reaper.ImGui_EndMenu(self.ctx)
    end

    self:drawAllPlugins()                                  -- draw all plugin menu
    self:drawFxTags()                                      -- draw plugin developers menu

    if reaper.ImGui_Selectable(self.ctx, "container") then -- add container if clicked
        reaper.TrackFX_AddByName(self.track, "Container", false,
            -1000 - reaper.TrackFX_GetCount(self.track))
        self.last_used_fx = "Container"
        self.open = false
    end
    if reaper.ImGui_Selectable(self.ctx, "video processor") then -- add video processor if clicked
        reaper.TrackFX_AddByName(self.track, "Video processor", false,
            -1000 - reaper.TrackFX_GetCount(self.track))
        self.last_used_fx = "Video processor"
        self.open = false
    end
    if self.last_used_fx then -- draw last used fx
        if reaper.ImGui_Selectable(self.ctx, "recent: " .. self.last_used_fx) then
            reaper.TrackFX_AddByName(self.track, self.last_used_fx, false,
                -1000 - reaper.TrackFX_GetCount(self.track))
            self.open = false
        end
    end
end

function Browser:RescanButton()
    if reaper.ImGui_Button(self.ctx, "RESCAN PLUGIN LIST") then -- "rescan" button
        self.plugin_list,
        self.fx_tags,
        self.custom_categories,
        self.fx_chains,
        self.track_templates,
        self.plugin_by_type =
            fx_parser
            .GenerateFxList() ---pull the data from the fx parser module, i.e. re-parse
    end
end

---Main loop function
--This runs at every defer cycle (every frame).
function Browser:main()
    if not self.open then
        return
    end
    self.track = reaper.GetSelectedTrack(0, 0)
    local visible, open = reaper.ImGui_Begin(self.ctx, self.name, true)
    self.open = open
    if visible then
        if self.track then
            self:RescanButton()
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

function Browser:Popup()
    reaper.ImGui_SetNextWindowSize(self.ctx, 400, 200)
    self.open = reaper.ImGui_BeginPopup(self.ctx, self.name)
    if self.open then
        self.open = true

        self.track = reaper.GetSelectedTrack(0, 0)
        if self.track then
            self:RescanButton()
            self:drawMenus()
        else
            reaper.ImGui_Text(self.ctx, "please select a track")
        end
        reaper.ImGui_EndPopup(self.ctx)
    end

    if self.open then
        reaper.defer(function() self:Popup() end)
    end
end

return Browser
