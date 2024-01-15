local Scanner = require('IniScan')
---INI parser.
--initialize and parse with
--```lua
--IniParse:new():parse(sourceStr)
-- ```
local IniParse = {}

---default config object for the INI parser
---@class CONFIG
---@field separator string String to define the separator character. Default is the equal character (=).
---@field comment string String to specify the comment characters. Default is semicolon (;) and number sign (#).
---@field trim boolean By default, leading and trailing white spaces are trimmed. This can be overridden by setting false to this parameter.
---@field lowercase_keys boolean By default, the keys are not case sensitive. This can be changed by forcing the keys to be lowercase_keys by setting this parameter to true.
---@field escape false By default. C-like escape sequences are interpreted. If set to false, then escape sequences are left unchanged.

---@type CONFIG
IniParse.config = {
    separator = '=',
    comment = ';#',
    trim = true,
    lowercase_keys = false,
    escape = false
}

---a CONFIG object with all its params as optional.
---@see CONFIG
---@class user_config
---@field separator? string
---@field comment? string
---@field trim? boolean
---@field lowercase_keys? boolean
---@field escape? boolean

---pass an optionnal CONFIG object with all its params as optional.
---user can get a new parser, and any params that are passed
---in the config obj
--```lua
--local parser = LIP2:new({
--    separator = '=',
--    comment = ';#',
--    trim = true,
--    lowercase_keys = false,
--    escape = false
--    })
--    :parse(sourceStr)
--```
---@param config? user_config
function IniParse:new(config)
    self.config = {
        separator = '=',
        comment = ';#',
        trim = true,
        lowercase_keys = false,
        escape = false
    }
    if config then
        for k, v in pairs(config) do
            self.config[k] = v
        end
    end
end

---@param str string
function IniParse:trim(str)
    return str:match('^%s*(.-)%s*$')
end

---parse an INI source string and return a lua table
--containing the data.
---@param str string The string to parse. [string]
function IniParse:parse(str)
    assert(type(str) == 'string', 'Parameter "str" must be a string.');
    local lines = {}
    for line in str:gmatch('[^\r\n]+') do
        table.insert(lines, line)
    end
    local data = IniParse:parse_lines(lines)
    return data;
end

---@param lines string[] The line to be parsed. [string]
function IniParse:parse_lines(lines)
    ---@type Token[]
    local scan = Scanner:new(IniParse.config):scanLines(lines)
    self.curWord = ""
    local i = 0
    local data = {}
    local section = nil

    while not (i >= #scan) do
        i = i + 1
        local token = scan[i]
        if token.type == 1 then                    --- expect section
            section = IniParse:trim(token.lexeme)  --- section names should be trimmed
            if IniParse.config.lowercase_keys then --- lowercase_keys should apply to section names as well
                section = section:lower()
            end
            if section:match("^%d") then --- section names should not start with a digit
                section = nil
                goto continue
            end
            data[section] = data[section] or {}
        elseif token.type == 2 then
            if not scan[i + 1] or scan[i + 1].type ~= 3 then
                goto continue
            end
            local key = IniParse:trim(token.lexeme)
            if IniParse.config.lowercase_keys then
                key = key:lower()
            end
            local value = scan[i + 1]
            if IniParse.config.trim and not value.isString then
                value.lexeme = IniParse:trim(value.lexeme)
            end
            if section then
                data[section][key] = value.lexeme
            else
                data[key] = value.lexeme
            end
            i = i + 1
        end
        ::continue::
    end
    return data
end

---Takes an ABSOLUTE file path and parses the file.
--
--Will return nil if the file is not found.
---@param path string
---@return table|nil
function IniParse:parse_file(path)
    --get contents of file at path
    local file = io.open(path, 'r')
    if not file then
        return nil
    end
    local str = file:read('*a')
    file:close()
    return IniParse:parse(str)
end

return IniParse
