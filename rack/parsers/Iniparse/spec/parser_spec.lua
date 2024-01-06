if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end
describe('Test the parser', function()
    local LIP = require 'LIP2'

    before_each(function()
        -- Default settings
        LIP:new()
    end)

    it('#basic test', function()
        assert.same({ name = 'value' }, LIP:parse('name = value'))
        assert.same({ name = '= value' }, LIP:parse('name == value'))
        assert.same({ name = ': value' }, LIP:parse('name =: value'))
        assert.same({ section_test = {} }, LIP:parse('[section_test]'))
        assert.same({}, LIP:parse('; this is a comment test'))
    end)

    it('#trim whitespaces test', function()
        assert.same({ name = 'value' }, LIP:parse('name = value '))
        local z = LIP:parse(' name = value ')
        assert.same({ name = 'value' }, z)
        local x = LIP:parse('name =   value  ')
        assert.same({ name = 'value' }, x)
        local p = LIP:parse('name = value test ')
        assert.same({ name = 'value test' }, p)
        assert.same({ name = 'value test', name2 = 'value test' }, LIP:parse([[
name = value test
name2 = value test
]]))
    end)

    it('#notrim test', function()
        LIP:new({
            trim = false
        })
        assert.same({ name = ' value ' }, LIP:parse('name = value '))
        assert.same({ name = '  value  ' }, LIP:parse('name =  value  '))
        assert.same({ name = ' value test ' }, LIP:parse('name = value test '))
        assert.same({ name = 'value test' }, LIP:parse('name =value test'))
        assert.same({ name = ' value test', name2 = 'value test' }, LIP:parse([[
name = value test
name2 =value test
]]))
    end)

    it('#comment test', function()
        assert.same({}, LIP:parse('; comment'))
        assert.same({}, LIP:parse(' ; comment'))
        assert.same({ name = 'value' }, LIP:parse('name = value ; comment'))
        assert.same({}, LIP:parse('# comment'))
        assert.same({}, LIP:parse [[
; comment
# comment
]])
    end)

    it('#lowercase test', function()
        LIP:new({
            lowercase_keys = true
        })
        assert.same({ name = 'value' }, LIP:parse('NAME = value'))
        assert.same({ _name = 'value' }, LIP:parse('_Name = value'))
        assert.same({
            window = {
                size = '200,200'
            }
        }, LIP:parse [[
[ WINDOW ]
Size = 200,200
]])
    end)

    it('#string test', function()
        assert.same({ name = '  value ' }, LIP:parse('name = "  value "'))  -- add explicit whitespaces to string
        assert.same({ name = 'value' }, LIP:parse('name =" ""value"'))      -- Ignore empty strings
        assert.same({ name = 'value' }, LIP:parse('name = "value" '))       -- Whitespace before and after double quotes are trimmed
        assert.same({ name = ' \'value' }, LIP:parse('name = " \'value" ')) -- test quote
        assert.same({ name = '\'value with quote' }, LIP:parse [[
name = 'value with quote
]])
    end)

    it('custom #settings', function()
        LIP:new({
            separator = ':',
            comment = '%!'
        })
        assert.same({ name = 'value' }, LIP:parse('name : value'))
        assert.same({ name = ': value' }, LIP:parse('name :: value'))
        assert.is_nil(LIP:parse('name = value')) -- Must fail
        assert.same({}, LIP:parse('! this is a comment test'))
        assert.same({}, LIP:parse('% this is a comment test'))
    end)

    it('#section label', function()
        assert.same({ section_test = {} }, LIP:parse('[section_test]'))
        assert.same({ section_test1 = {} }, LIP:parse('[section_test1]'))           -- test digit
        assert.same({ s1ection_test = {} }, LIP:parse('[s1ection_test]'))           -- test digit
        assert.same({ section_test = {} }, LIP:parse('[ section_test ]  '))         -- test space

        assert.same({ section_test = {} }, LIP:parse('[ section_test ] # comment')) -- For some reason this works ?!
        -- assert.same({ section_test = {} }, ini.parse('[ section_test ] name = value\nname2 = value')) -- this works too
        -- Fail tests
        assert.is_nil(LIP:parse('[[ section_test ]'))
        assert.is_nil(LIP:parse('[ section_test ]]'))
        assert.is_nil(LIP:parse('[[ section_test ]]'))
        assert.is_nil(LIP:parse('[test_section'))
        assert.is_nil(LIP:parse('test_section]'))
        assert.is_nil(LIP:parse('[ section test ]'))
        assert.is_nil(LIP:parse('[ section test ] trash'))
        assert.is_nil(LIP:parse('[1my_section_test]')) -- fail because starts with a digit
    end)

    it('Multi-lines no section', function()
        assert.same({
            project = 'My Game',
            version = '1.0.0'
        }, LIP:parse [[
; Default
project = My Game
version = 1.0.0
]])
    end)

    it('Test default and one section', function()
        assert.same({
            project = 'My Game',
            version = '1.0.0',
            window = {
                fullscreen = 'true',
                size = '200,200'
            }
        }, LIP:parse [[
; Default
project = My Game
version = 1.0.0
[window]
fullscreen = true
size = 200,200
]])
    end)

    it('Test no default', function()
        assert.same({
            window = {
                fullscreen = 'true',
                size = '200,200'
            }
        }, LIP:parse [[
[window]
fullscreen = true
size = 200,200
]])
    end)

    it('Test multiple sections', function()
        assert.same({
            window = {
                fullscreen = 'true',
                size = '200,200',
            },
            app = {
                name = 'My Game',
                version = '1.0.0'
            }
        }, LIP:parse [[
[window]
; comment with space
fullscreen = true
size = 200,200
[app]
name = My Game
version = 1.0.0
]])
    end)

    it('Test empty lines and spaces', function()
        assert.same({
            window = {
                fullscreen = 'true',
                size = '200,200'
            }
        }, LIP:parse [[

  [window]

 fullscreen = true
 size = 200,200

]])
    end)

    it('test #duplicate', function()
        assert.same({
            window = {
                fullscreen = 'false',
                version = '2.0'
            }
        }, LIP:parse [[
[window]
fullscreen = true
size = 200

[window]
version = 1.0
fullscreen = false
version = 2.0
]])
    end)

    it('test #escape', function()
        assert.same({ name = 'value' }, LIP:parse('name = value\n'))
        assert.same({ name = 'value\n' }, LIP:parse('name = "value\n"'))
        assert.same({ name = 'value\\n' }, LIP:parse('name = value\\n'))
        assert.same({ name = '\t value \n \\n' }, LIP:parse [[
name = "\t value \n \\n"
]])
        LIP.config {
            escape = false
        }
        assert.same({ name = '\\n \\\\t' }, LIP:parse [[
name = "\n \\t"
]])
    end)

    --[[   it('test #file input', function()
    assert.same({
      foo = 'Hello',
      bar = 'World',
      window = {
        fullscreen = 'true',
        size = '200,200',
      },
      app = {
        name = 'My Game',
        version = '1.0.0',
        escaped_literal = '\n \\n'
      }
    }, LIP:parse_file('spec/test_win32.ini'))
    assert.same({
      foo = 'Hello',
      bar = 'World',
      window = {
        fullscreen = 'true',
        size = '200,200',
      },
      app = {
        name = 'My Game',
        version = '1.0.0',
        escaped_literal = '\n \\n'
      }
    }, LIP:parse_file('spec/test_unix.ini'))
    -- assert.same({},ini.parse_file('spec/invalid.ini'))
    assert_has_error(function() LIP:parse_file('spec/does_not_exist.ini') end)
  end) ]]
end)
