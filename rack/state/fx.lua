local IniParse = require("parsers.Iniparse.IniParse")
local table_helpers = require("helpers.table")
---@class TrackFX
local fx = {}
fx.__index = fx

---create a new fx instance,
---to store state and layout information
---@param state State
---@param data FxData
---@param theme Theme
function fx.new(state, data, theme)
    ---@class TrackFX
    local self = setmetatable({}, fx)
    self.state = state
    self.enabled = data.enabled
    self.guid = data.guid
    self.name = data.name
    self.number = data.number
    self.param = data.param
    self.index = data.index
    ---@class FxDisplaySettings
    self.displaySettings = {
        height         = 220,
        Window_Width   = 220,
        fx_width       = 200,
        Title_Width    = 220 - 30,
        Edge_Rounding  = 0,
        Grb_Rounding   = 0,
        background     = theme.colors.selcol_tr2_bg.color,
        BorderColor    = theme.colors.col_gridlines2.color,
        Title_Clr      = 0x000000FF,
        Custom_Title   = nil,
        Param_Instance = nil,
        buttonStyle    = {
            background = theme.colors.col_buttonbg.color,
            text_enabled = theme.colors.col_toolbar_text_on.color,
            text_disabled = theme.colors.col_tcp_textsel.color
        }
    }
    self.displaySettings_copy = nil
    -- self.param_list
    -- number retval, number minval, number maxval = reaper.TrackFX_GetParam(MediaTrack track, integer fx, integer param)
    --
    -- ParamValue_At_Script_Start = r.TrackFX_GetParamNormalized(Track, FX_Idx, FxdCtx.FX[FxGUID][Fx_P].Num or 0)
    return self
end

---Check that the parse of the fx layout file
---contains all the expected properties in the object.
---@param parse table
local function isValidDisplaySettings(parse)
    if not parse.displaySettings
        or not parse.displaySettings.Edge_Rounding
        or not parse.displaySettings.Grb_Rounding
        or not parse.displaySettings.BgClr
        or not parse.displaySettings.Window_Width
        or not parse.displaySettings.Title_Width
        or not parse.displaySettings.Title_Clr
        or not parse.displaySettings.Custom_Title
        or not parse.displaySettings.Param_Instance
    then
        return false
    else
        return true
    end
end

---Pull any pre-saved layouts from the fx layouts.
---If there are none, the component will use the default.
function fx:getDisplaySettings()
    local file_name = self.state.project_directory .. self.name .. ".ini"
    ---@type table|nil
    local parse = IniParse:parse_file(file_name)
    if not parse then
        return
    elseif not isValidDisplaySettings(parse) then -- if file exists but doesn’t contain the expected content, it’s invalid
        reaper.MB(
            "invalid fx layout file " .. file_name,
            "Error", 0)
        return
    end
    self.displaySettings = parse.displaySettings ---@type FxDisplaySettings
    ---TODO possible optimization?
    --[[
What happens if user removes this fx but then re-adds it,
do we have to parse a second time for the same fx?
we could optionally just save the result of the parse somewhere until the next call.
    ]]
end

function fx:editLayout()
    --[[if user wants to edit the layout:
    Create a copy of the displaySettings, pass it to the editor and let the user edit the copy.
    Upon closing,
    if user saves, replace the original displaySettings with the copy, and write to file.
    if user closes without saving, replace the original displaySettings with the copy, but do no write to file
    if user discards, discard the copy.
    ]]
    self.displaySettings_copy = table_helpers.deepCopy(self.displaySettings)
end

---@enum EditLayoutCloseAction
local EditLayoutCloseAction = {
    "save",
    "close",
    "discard"
}

---When user closes the layout editor,
---if user saves, replace the original displaySettings with the copy, and write to file.
---if user closes without saving, replace the original displaySettings with the copy, but do not write to file.
---if user discards, discard the copy.
---@param action EditLayoutCloseAction
function fx:onEditLayoutClose(action)
    if action == EditLayoutCloseAction.save then -- save
        self.displaySettings = self.displaySettings_copy
        local file_name = self.state.project_directory .. self.name .. ".ini"
        IniParse.save(file_name, self.displaySettings)
        self.displaySettings_copy = nil
    elseif action == EditLayoutCloseAction.close then -- close without saving
        self.displaySettings = self.displaySettings_copy
        self.displaySettings_copy = nil
    else -- discard
        self.displaySettings_copy = nil
    end
end

return fx
