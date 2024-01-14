--[[
Parse the reaper-kb.ini file
Returns
{ ParseKeyMapFile, KeyMapScanner, KeyMapParser }
]]

local os_separator = package.config:sub(1, 1)

---@enum KeyContext
local KeyContext = {
    main = 0,
    midi = 32060,
}
---@param val string
---@return string|nil ModifierKey
function KeyContext:Match(val)
    -- convert val to number
    local num_val = tonumber(val)
    for k, v in pairs(self) do
        if v == num_val then
            return k
        end
    end
end

---@enum ModifierCode
local ModifierCode = {
    default = 1,
    Ctrl = 9,
    Ctrl_Shift = 13,
    Meta = 17,
    Meta_Shift = 21,
    Meta_Ctrl = 25,
    Meta_Ctrl_Shift = 29,
}

---@param val string
---@return string|nil ModifierKey
function ModifierCode:Match(val)
    -- convert val to number
    local num_val = tonumber(val)
    for k, v in pairs(self) do
        if v == num_val then
            return k
        end
    end
end

---@class KeyLine
---@field modifier_code ModifierCode
---@field ASCII_key_code string
---@field ActionID string|number
---@field Context KeyContext
---@field actionName string?

---use this to scan the lines of the keymap file.
---use `scanLines()` to get the result:
--
--```lua
--local lines ---@type string[] an array of lines from the keymap file
--local scan = KeyMapScanner(lines):scanLines()
--```
---@param lines string[]
local function KeyMapScanner(lines)
    local S = {}
    S.lines = lines
    S.curLine = ""
    S.curChar = 0
    ---@type string[]
    S.curScan = {}
    ---@type string[][]
    S.scans = {}
    S.isInQuotes = false
    S.curWord = ""
    ---@param line string
    function S:resetScan(line)
        S.curLine = line
        S.curChar = 0
        S.curScan = {}
    end

    function S:scanLines()
        for _, line in ipairs(self.lines) do
            S:resetScan(line)
            self:scanLine(line)
        end
        return S.scans
    end

    function S:insertCurWord()
        table.insert(S.curScan, S.curWord)
        S.curWord = ""
    end

    function S:isQuote()
        return string.sub(S.curLine, S.curChar, S.curChar) == "\""
    end

    function S:isComment()
        return string.sub(S.curLine, S.curChar - 1, S.curChar - 1) == " " and
            string.sub(S.curLine, S.curChar, S.curChar) == "#"
    end

    ---scan all tokens in current line,
    ---and once the line is put together as a string[],
    ---push it to the list of scanned lines
    function S:scanLine(line)
        while not self:isAtEnd() do
            S:advance()
            if S:isComment() and not S.isInQuotes then
                break
            end
            if S:isSpace() and not S.isInQuotes then
                S:insertCurWord()
            elseif S:isQuote() then
                if S.isInQuotes then
                    S.isInQuotes = false
                    S:insertCurWord()
                    S:advance()
                else
                    S.isInQuotes = true
                end
                goto continue
            else
                local curChar = string.sub(self.curLine, self.curChar, self.curChar)
                S.curWord = S.curWord .. curChar
            end
            ::continue::
        end
        if #S.curWord > 0 then
            S:insertCurWord()
        end

        if #S.curScan > 0 then
            table.insert(S.scans, S.curScan)
        end
        return S.curScan
    end

    function S:advance()
        S.curChar = S.curChar + 1
    end

    function S:isSpace()
        local char = string.sub(self.curLine, self.curChar, self.curChar)
        return char == " " or char == "\t"
    end

    function S:isAtEnd()
        return self.curChar >= #self.curLine
    end

    function S:peek()
        return string.sub(S.curLine, S.curChar, S.curChar)
    end

    return S
end



---use this to parse the output of the Scanner.
---start the Parser, and `parseLines()` to get the result
---@param scannedLines string[][]
function KeyMapParser(scannedLines)
    local p = {}
    p.scannedLines = scannedLines
    p.parsedLines = {}
    ---@return KeyLine[]
    function p:parseLines()
        -- iterate through the lines
        -- if the length of line is not 5, discard it
        -- else, build the representation as each index of the line

        for _, line in ipairs(self.scannedLines) do
            if #line ~= 5 then
                goto continue
            end
            local numberAction = tonumber(line[4], 10)
            local ModifierCodeIndex = ModifierCode:Match(line[2]) or ModifierCode.default
            local KeyContextIndex = KeyContext:Match(line[5]) or KeyContext.main
            ---@type KeyLine
            local keyLine = {
                modifier_code = ModifierCode[ModifierCodeIndex],
                ASCII_key_code = line[3],
                ActionID = numberAction and numberAction or line[4], -- do we need to convert to number?
                Context = KeyContext[KeyContextIndex],
            }
            p.insert(self.parsedLines, keyLine)
            ::continue::
        end
        return p.parsedLines
    end

    return p
end

---import contents of file
---break it up into lines
---@param path string
---@return string[]|nil
local function readFile(path)
    local file = io.open(path, "r")
    if not file then return end
    local lines = {}
    for line in file:lines() do
        table.insert(lines, line);
    end
    file:close()
    return lines
end


---remove SCR lines, which don't contain any key binding information
---@param lines string[]
---@return string[]
local function FilterKeys(lines)
    local keyLines = {}
    for _, line in ipairs(lines) do
        if line:sub(1, 3) == "KEY" then
            table.insert(keyLines, line)
        end
    end
    return keyLines
end

---Find an action's name by its command id.
---This hooks into reaper's actions list.
---@param commandID string|number
---@param section number 0: Main, 32060: MIDI Editor
---@return string
local function find_by_command_id(commandID, section)
    if reaper.APIExists("kbd_getTextFromCmd") then
        return reaper.kbd_getTextFromCmd(reaper.NamedCommandLookup(commandID .. ""), section == 1 and 0 or 32060)
    else
        return reaper.CF_GetCommandText(section, reaper.NamedCommandLookup(commandID .. ""))
    end
end

---TODO does this work?
---This function updates table's objects after assigning variables to them.
---Does this still work does it make the update in place in the table?
---@param parsedLines KeyLine[]
local function addActionNamesToKeyLines(parsedLines)
    local actionslist = require("definitions.extended_defaults.actions") -- todo chck settings: extended dfaults or standard
    local orderedActions = {}
    for i, action in ipairs(actionslist) do
        if type(action) ~= "table" then
            orderedActions[action] = i
        end
    end
    for _, keyObj in ipairs(parsedLines) do
        local actionDef_name = orderedActions[keyObj.ActionID]
        if not actionDef_name then
            actionDef_name = find_by_command_id(keyObj.ActionID, keyObj.Context)
        end
        keyObj.actionName = actionDef_name
    end
    return parsedLines
end

---take the path to the reaper-kb.ini file
local function ParseKeyMapFile()
    local path = reaper.GetResourcePath() .. os_separator .. "reaper-kb.ini"
    local lines = readFile(path)
    if not lines then return end
    local scannedLines = KeyMapScanner(lines):scanLines()
    local parsedLines = KeyMapParser(scannedLines):parseLines()
    parsedLines = addActionNamesToKeyLines(parsedLines)
    return parsedLines
end

return {
    ParseKeyMapFile = ParseKeyMapFile,
    KeyMapScanner = KeyMapScanner,
    KeyMapParser = KeyMapParser,
    readFile = readFile,
}
