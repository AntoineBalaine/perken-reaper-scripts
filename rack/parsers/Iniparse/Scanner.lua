---INI scanner.
-- initialize with
--```lua
--scanner:new()

-- ```
local S = {}

---@enum TokenType
TokenType = {
    section = 1,
    key = 2,
    value = 3,
    comment = 4
}

---@class Token
---@field type TokenType
---@field lexeme string
---@field isString? boolean

S.config = {}
S.lines = {} ---@type string[]
S.curLineIdx = 0
S.curLine = ""
S.curChar = 0
---@type Token[]
S.scans = {}
S.isInQuotes = false
S.curWord = ""
S.separator_already_found = false


---use this method to initialize the scanner
--it sets up the config and resets all the fields
--after calling this function, you can call `scan(sourceStr)`
--e.g.:
--```lua
--scanner:new():scan(sourceStr)
--```
--config params can be passed in as a table, such as:
--```lua
--scanner:new({
--    separator = '=',
--    comment = ';#',
--    trim = true,
--    lowercase = false,
--    escape = false
--    })
--    :scan(sourceStr)
--```
---@see CONFIG
---@param config? CONFIG
function S:new(config)
    if config then
        for k, v in pairs(config) do
            self.config[k] = v
        end
    else
        self.config = {
            separator = '=',
            comment = ';#',
            trim = true,
            lowercase = false,
            escape = false
        }
    end
    self.lines = {}
    self.curLineIdx = 0
    self.curLine = ""
    self.curChar = 0
    self.scans = {}
    self.isInQuotes = false
    self.curWord = ""
    self.separator_already_found = false
    return self
end

---@param line string
function S:resetScan(line)
    self.curLine = line
    self.curChar = 0
    self.curWord = ""
    self.separator_already_found = false
end

---scan the source string and return a list of tokens
---@param source string
---@return TokenType[]
function S:scan(source)
    --split source into list of lines
    local lines = {}
    for line in source:gmatch('[^\r\n]+') do
        table.insert(lines, line)
    end
    return self:scanLines(lines)
end

---@param lines string[]
---@return TokenType[]
function S:scanLines(lines)
    self.lines = lines
    for lineIdx, line in ipairs(self.lines) do
        self.curLineIdx = lineIdx
        self:resetScan(line)
        self:scanLine()
    end
    return self.scans
end

function S:isQuote()
    return self.curLine[self.curChar] == "\""
end

function S:isSeparator()
    return string.sub(self.curLine, self.curChar, self.curChar) == self.config.separator
end

function S:isComment()
    ---split self.config.comment into a table of chars
    ---and check if the current char is one of them
    ---@type {string: nil|boolean}
    local commentChars = {}
    for i = 1, #self.config.comment do
        commentChars[string.sub(self.config.comment, i, i)] = true
    end
    local curChar = string.sub(self.curLine, self.curChar, self.curChar)
    return commentChars[curChar] or false
end

---@param str string
function S:trim_str(str)
    return str:match('^%s*(.-)%s*$')
end

function S:isOpenBrkt()
    return string.sub(self.curLine, self.curChar, self.curChar) == "["
end

function S:isCloseBrkt()
    return string.sub(self.curLine, self.curChar, self.curChar) == "]"
end

---if param is passed in, check if it's lineBreak
---else
---check if char at current posiiton is lineBreak
function S:isLineBrk(char)
    if char then
        return char == "\n"
    end
    return string.sub(self.curLine, self.curChar, self.curChar) == "\n"
end

---if param is passed in, check if it's WS
---else
---check if char at current posiiton is WS
---@param char? string
function S:isWS(char)
    if char then
        return char == " " or char == "\t"
    end
    return string.sub(self.curLine, self.curChar, self.curChar) == " "
end

---if param is passed in, check if it's WS
---else
---check if char at current posiiton is WS
---@param char? string
function S:isDoubleQuote(char)
    if char then
        return char == " " or char == "\t"
    end
    return string.sub(self.curLine, self.curChar, self.curChar) == '"'
end

---scan all tokens in current line,
---and once the line is put together as a string[],
---push it to the list of tokens `self.scans`
function S:scanLine()
    while not self:isAtEnd() do
        self:advance()

        if self.section and self:isLineBrk() and self:isLineBrk(self:peek()) then
            self.section = nil
            self:advance()
            self.curWord = ""
            goto continue
        elseif self:isDoubleQuote() then
            local scannedstr = self:string()
            if not scannedstr:match("^%s*$") then
                self:newToken(scannedstr, TokenType.value, true)
            end
            goto continue
        elseif self:isComment() then
            if self.curWord ~= "" then
                self:newToken(self.curWord, TokenType.value)
            end
            self:newToken(self:comment(), TokenType.comment)
            goto continue
        elseif self:isOpenBrkt() then
            self.section = self:sectionName()
            self:newToken(self.section, TokenType.section)
            goto continue
        else
            if self:isSeparator() then
                if not self.separator_already_found then
                    self.separator_already_found = true
                    self:newToken(self.curWord, TokenType.key)
                else
                    self.curWord = self.curWord .. self:peek()
                end
            elseif self:isLineBrk() then
                self:newToken(self.curWord, TokenType.value)
                break;
            else
                self.curWord = self.curWord .. self:peek()
            end
        end

        ::continue::
    end
    if self:isAtEnd() and self.curWord ~= "" then
        self:newToken(self.curWord, TokenType.value)
    end
    return self.scans
end

function S:string()
    local start = self.curChar
    self:advance()
    while not self:isAtEnd() do
        if self:isDoubleQuote() then
            local str = string.sub(self.curLine, start + 1, self.curChar - 1)
            return str
        else
            self:advance()
        end
    end

    self.curWord = ""
    return string.sub(self.curLine, start + 1, self.curChar - 1)
end

function S:sectionName()
    self:advance() ---skip the open bracket
    local start = self.curChar

    while not self:isAtEnd() do
        if self:isCloseBrkt() then
            local str = string.sub(self.curLine, start, self.curChar - 1)
            self:advance()
            return str
        else
            self:advance()
        end
    end

    self.curWord = ""
    return nil
end

function S:comment()
    self:advance() ---skip the comment char
    local start = self.curChar
    while not self:isAtEnd() do
        self:advance()
    end
    return string.sub(self.curLine, start, self.curChar)
end

function S:advance()
    self.curChar = self.curChar + 1
end

function S:isSpace()
    local char = self.curLine[self.curChar]
    return char == " " or char == "\t"
end

function S:isAtEnd()
    return self.curChar > #self.curLine
end

function S:peek()
    return string.sub(self.curLine, self.curChar, self.curChar)
end

---@param lexeme string
---@param tokenType TokenType
---@param isString? boolean indicate this is if the token was between double quotes - to prevent it from being trimmed
function S:newToken(lexeme, tokenType, isString)
    ---@type Token
    local token = { type = tokenType, lexeme = lexeme, isString = isString }
    table.insert(self.scans, token)
    self.curWord = ""
end

return S
