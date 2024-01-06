if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end
describe('Test the scanner', function()
    local scanner = require('scanner')

    before_each(function()
        -- Default settings
        scanner:new()
    end)

    it('#scanner - basic test', function()

        assert.same({ name = 'value' }, scanner('name = value'))
        assert.same({ name = '= value' }, scanner.scanLine('name == value'))
        assert.same({ name = ': value' }, scanner.parse_line('name =: value'))
        assert.same({ section_test = {} }, scanner.parse_line('[section_test]'))
        assert.same({}, scanner.parse('; this is a comment test'))
    end)
end)
