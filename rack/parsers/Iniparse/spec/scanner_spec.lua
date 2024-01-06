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
        ---assert that the scanner will return an empty table if there only comments in the source
        assert.same(0, #scanner:new():scan('; this is a comment test'))
    end)
end)
