--[[
Read the user settings from the file, or create a new one if it doesn’t exist.
]]
local Settings = {}
local IniParse = require("parsers.Iniparse.IniParse")



function Settings:read()
    local parse = IniParse:parse_file(self.path)
    if parse then
        assert(parse and parse.prefer_fx_chain, "user settings are invalid")
        self.prefer_fx_chain = parse.prefer_fx_chain
    else
        ---when opening fx from the rack, display them from the fx chain or in their own window
        self.prefer_fx_chain = true
    end
end

function Settings:save()
    IniParse.save(self.path, {
        prefer_fx_chain = self.prefer_fx_chain
    })
end

function Settings:init(project_directory)
    self.project_directory = project_directory
    local os_separator = package.config:sub(1, 1)
    ---user settings path
    self.path = table.concat({
        project_directory,
        "user_data",
        "user_settings.ini"
    }, os_separator)

    self:read()
    return self
end

return Settings
