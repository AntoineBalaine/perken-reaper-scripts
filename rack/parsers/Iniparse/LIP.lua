--[[
	Copyright (c) 2012 Carreras Nicolas
	
	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:
	
	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.
	
	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
--]]
--- Lua INI Parser.
-- It has never been that simple to use INI files with Lua.
--@author Dynodzzo

local LIP = {};
---set LIP's config to be the default:
---```lua
---{trim = true
---lowercase = false}
---```
function LIP:init()
    LIP.config = {
        trim = true,      -- Trim whitespace around the separators
        lowercase = false -- Convert section and key names to lower case
    }
end

LIP.config = {
    trim = true,      -- Trim whitespace around the separators
    lowercase = false -- Convert section and key names to lower case
}
---@param line string The line to parse. [string]
---@param sep string The separator to use. [string]
function LIP.splitStr(line, sep)
    local param
    local value
    local i = 0
    while (i < #line) do
        i = i + 1
        if string.sub(line, i, i) == sep then
            param = line:sub(1, i - 1)
            value = line:sub(i + 1)
            break
        end
    end

    if param ~= nil and value ~= nil then
        ---trim whitespace from params/keys
        param = param:match('^%s*(.-)%s*$');
        if LIP.config.trim then
            value = value:match('^%s*(.-)%s*$');
        end
        if LIP.config.lowercase then
            param = param:lower();
        end
        if tonumber(value) then
            value = tonumber(value);
        elseif value == 'true' then
            value = true;
        elseif value == 'false' then
            value = false;
        end
        if tonumber(param) then
            param = tonumber(param);
        end
    end
    return param, value
end

---@param lines string[] The line to parse. [string]
---@return table data The table to fill with the parsed data. [table]
function LIP.parse_line(lines)
    local data = {};
    local section;
    ---if there are more than two empty lines in a row, then the previous section is over
    local empty_lines_in_a_row = 0
    for _, line in ipairs(lines) do
        if empty_lines_in_a_row >= 2 then
            empty_lines_in_a_row = 0
            section = nil
        end
        ---Remove comments from the line
        local no_comment_line = line:gsub('([;#]*)', "")
        line = no_comment_line
        if line == "" then
            ---count all empty lines, excluding comment lines
            ---so that we can detect when a section is over
            if no_comment_line then
                empty_lines_in_a_row = empty_lines_in_a_row + 1
            end
            goto continue
        else
            empty_lines_in_a_row = 0
        end
        local tempSection = line:match('^%[([^%[%]]+)%]$');
        if (tempSection) then
            section = tonumber(tempSection) and tonumber(tempSection) or tempSection;
            if LIP.config.lowercase then
                section = section:lower();
            end
            data[section] = data[section] or {};
            goto continue
        end
        local param, value = LIP.splitStr(line, '=')
        if not (param and value) then
            goto continue
        end
        if section then
            data[section][param] = value;
        else
            data[param] = value;
        end
        ::continue::
    end
    return data
end

---@param str string The string to parse. [string]
function LIP.parse(str)
    assert(type(str) == 'string', 'Parameter "str" must be a string.');
    local lines = {}
    for line in str:gmatch('[^\r\n]+') do
        table.insert(lines, line)
    end
    local data = LIP.parse_line(lines)
    return data;
end

---Returns a table containing all the data from the INI file.
---@param fileName string The name of the INI file to parse. [string]
---@return table The table containing all data from the INI file. [table]
function LIP.parse_file(fileName)
    assert(type(fileName) == 'string', 'Parameter "fileName" must be a string.');
    local file = assert(io.open(fileName, 'r'), 'Error loading file : ' .. fileName);
    local lines = {}
    for _, line in file:lines() do
        table.insert(lines, line)
    end
    file:close();
    local data = LIP.parse_line(lines)
    return data;
end

--- Saves all the data from a table to an INI file.
---@param fileName string The name of the INI file to fill. [string]
---@param data table The table containing all the data to store. [table]
function LIP.save(fileName, data)
    assert(type(fileName) == 'string', 'Parameter "fileName" must be a string.');
    assert(type(data) == 'table', 'Parameter "data" must be a table.');
    local file = assert(io.open(fileName, 'w+b'), 'Error loading file :' .. fileName);
    local contents = '';
    for section, param in pairs(data) do
        contents = contents .. ('[%s]\n'):format(section);
        for key, value in pairs(param) do
            contents = contents .. ('%s=%s\n'):format(key, tostring(value));
        end
        contents = contents .. '\n';
    end
    file:write(contents);
    file:close();
end

return LIP;
