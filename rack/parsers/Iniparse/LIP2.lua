local Scanner = require('Scanner')
local LIP2 = {}

---default config object for the INI parser
---@class CONFIG
---@field separator string String to define the separator character. Default is the equal character (=).
---@field comment string String to specify the comment characters. Default is semicolon (;) and number sign (#).
---@field trim boolean By default, leading and trailing white spaces are trimmed. This can be overridden by setting false to this parameter.
---@field lowercase_keys boolean By default, the keys are not case sensitive. This can be changed by forcing the keys to be lowercase_keys by setting this parameter to true.
---@field escape false By default. C-like escape sequences are interpreted. If set to false then escape sequences are left unchanged.

---@type CONFIG
LIP2.config = {
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
---in the config object will override the default params.
---@param config? user_config
function LIP2:new(config)
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
function LIP2:trim(str)
    return str:match('^%s*(.-)%s*$')
end

---@param str string The string to parse. [string]
function LIP2:parse(str)
    assert(type(str) == 'string', 'Parameter "str" must be a string.');
    local lines = {}
    for line in str:gmatch('[^\r\n]+') do
        table.insert(lines, line)
    end
    local data = LIP2:parse_lines(lines)
    return data;
end

---@param lines string[] The line to parse. [string]
function LIP2:parse_lines(lines)
    ---@type Token[]
    local scan = Scanner:new(LIP2.config):scanLines(lines)
    self.curWord = ""
    local i = 0
    local data = {}
    local section = nil

    while not (i >= #scan) do
        i = i + 1
        local token = scan[i]
        if token.type == 1 then                --- expect section
            section = LIP2:trim(token.value)   --- section names should be trimmed
            if LIP2.config.lowercase_keys then --- lowercase_keys should apply to section names as well
                section = section:lower()
            end
            data[section] = data[section] or {}
        elseif token.type == 2 then
            if not scan[i + 1] or scan[i + 1].type ~= 3 then
                goto continue
            end
            local key = LIP2:trim(token.value)
            if LIP2.config.lowercase_keys then
                key = key:lower()
            end
            local value = scan[i + 1].value
            if LIP2.config.trim then
                value = LIP2:trim(value)
            end
            if section then
                data[section][key] = value
            else
                data[key] = value
            end
            i = i + 1
        end
        ::continue::
    end
    return data
end

return LIP2
