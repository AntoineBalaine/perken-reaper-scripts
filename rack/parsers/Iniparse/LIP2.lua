local LIP2 = {}
local Scanner = require('scanner')

---@class CONFIG
---@field separator string String to define the separator character. Default is the equal character (=).
---@field comment string String to specify the comment characters. Default is semicolon (;) and number sign (#).
---@field trim boolean By default, leading and trailing white spaces are trimmed. This can be overridden by setting false to this parameter.
---@field lowercase boolean By default, the keys are not case sensitive. This can be changed by forcing the keys to be lowercase by setting this parameter to true.
---@field escape false By default. C-like escape sequences are interpreted. If set to false then escape sequences are left unchanged.

---@type CONFIG
LIP2.config = {
    separator = '=',
    comment = ';#',
    trim = true,
    lowercase = false,
    escape = false
}
function LIP2:init()
end

---@param values {separator?: string, comment?: string, trim?: boolean, lowercase?: boolean, escape?: boolean}
function LIP2:set_config(values)
    local config = {
        separator = '=',
        comment = ';#',
        trim = true,
        lowercase = false,
        escape = false
    }
    if values.separator then
        config.separator = values.separator
    end
    if values.comment then
        config.comment = values.comment
    end
    if values.trim ~= nil then
        config.trim = values.trim
    end
    if values.lowercase ~= nil then
        config.lowercase = values.lowercase
    end
    if values.escape ~= nil then
        config.escape = values.escape
    end
    self.config = config
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
    ---@type Token[][]
    local scan = Scanner:new(LIP2.config):scan_lines(lines)
    self.curWord = ""
    local i = 0
    local data = {}
    local section = nil
    for _, scan_lines in ipairs(scan) do
        i = i + 1
        for _, line in ipairs(scan_lines) do
            if #line == 1 then --- expect section
                local token = scan_lines[1]
                section = token.value
                data[section] = data[section] or {}
            elseif #line == 2 then
                local key = scan_lines[1].value
                local value = scan_lines[2].value
                if section then
                    data[section][key] = value
                else
                    data[key] = value
                end
            elseif #line == 0 then
                section = nil
                -- throw
                -- parser
                -- error
            end
        end
    end
    return data
end
