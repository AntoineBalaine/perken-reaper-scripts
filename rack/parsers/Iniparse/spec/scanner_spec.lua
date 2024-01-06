if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

describe('Test the scanner', function()
    local scanner = require('Scanner')

    before_each(function()
        -- Default settings
        scanner:new()
    end)

    it('#scanner - scan key/value pairs', function()
        ---assert that the scanner can retrieve key/value pairs
        assert.equal(2, #scanner:new():scan('name = value'))
        ---assert that the second type will be a key
        assert.equal('= value', scanner:new():scan('name == value')[2].value)
        ---assert that the second type will be a key
        assert.equal(': value', scanner:new():scan('name =: value')[2].value)
        ---assert that the first token is a section name, of tokenType == 1
        ---assert that the scanner trims the brackets off the section name
        local section_token = scanner:new():scan('[section_test]')
        assert.equal(1, section_token[1].type)
        assert.equal('section_test', section_token[1].value)
        ---assert that the scanner will return tokens for comments
        assert.same(1, #scanner:new():scan('; this is a comment test'))
    end)

    it('#scanner - scan key/value pairs with comments at ends of lines', function()
        local scan = scanner:new():scan('name = value ; comment')
        -- { name = 'value ' }
        assert.equal(3, #scan)
        local key = scan[1]
        local value = scan[2]
        local comment = scan[3]
        assert.equal(TokenType.key, key.type)
        assert.equal(TokenType.value, value.type)
        assert.equal(TokenType.comment, comment.type)
    end)
end)
