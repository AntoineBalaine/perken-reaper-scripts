if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end

describe('Test the scanner', function()
    local scanner = require('scanner')

    before_each(function()
        -- Default settings
        scanner:new()
    end)

    it('#scanner - scan key/value pairs', function()
        ---assert that the scanner can retrieve key/value pairs
        assert.equal(2, #scanner:new():scanLines('name = value'))
        ---assert that the second type will be a key
        assert.equal('= value', scanner.scanLines('name == value')[2].value)
        ---assert that the second type will be a key
        assert.equal(': value', scanner.scanLines('name =: value')[2].value)
        ---assert that the first token is a section name, of tokenType == 1
        assert.equal(1, scanner.scanLines('[section_test]')[1].type)
        ---assert that the scanner will return an empty table if there only comments in the source
        assert.same(0, #scanner.scanLines('; this is a comment test'))
    end)
end)
