local S = {}

---@enum TokenType
local TokenType = {
    section = 1,
    key = 2,
    value = 3
}

---@class Token
---@field type TokenType
---@field value string

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


---@param config CONFIG
function S:new(config)
    self.config = config
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

---@param lines string[]
---@return string[][]
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

---scan all tokens in current line,
---and once the line is put together as a string[],
---push it to the list of scanned lines
function S:scanLine()
    while not self:isAtEnd() do
        self:advance()

        if self.section and self:isLineBrk() and self:isLineBrk(self:peek()) then
            self.section = nil
            self:advance()
            self.curWord = ""
            goto continue
        elseif self:isComment() then
            while not self:isAtEnd() or not self:isLineBrk() do
                self:advance()
            end
            self.curWord = ""
            goto continue
        elseif self:isOpenBrkt() then
            self.section = self:sectionName()
            self:newToken(self.section, TokenType.section)
            goto continue
        else
            if self:isSeparator() and not self.separator_already_found then
                self:newToken(self.curWord, TokenType.key)
            elseif self:isLineBrk() then
                self:newToken(self.curWord, TokenType.value)
                break;
            else
                self.curWord = self.curWord .. self:peek()
            end
        end

        ::continue::
    end
    return self.scans
end

function S:sectionName()
    local start = self.curChar
    self:advance()

    while not self:isAtEnd() do
        if self:isCloseBrkt() then
            self:advance()
            return string.sub(self.curLine, start, self.curChar - 1)
        end
        self:advance()
    end

    self.curWord = ""
    return nil
end

function S:advance()
    self.curChar = self.curChar + 1
end

function S:isSpace()
    local char = self.curLine[self.curChar]
    return char == " " or char == "\t"
end

function S:isAtEnd()
    return self.curChar >= #self.curLine
end

function S:peek()
    return string.sub(self.curLine, self.curChar, self.curChar)
end

---@param tokenType TokenType
---@param str string
function S:newToken(str, tokenType)
    table.insert(self.scans, { type = tokenType, value = str })
    self.curWord = ""
end

return S
