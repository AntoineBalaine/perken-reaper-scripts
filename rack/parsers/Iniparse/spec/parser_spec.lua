if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
end
describe('Test the parser', function()
    local IniParse = require 'parsers.Iniparse.IniParse'

    before_each(function()
        -- Default settings
        IniParse:new()
    end)

    it('#basic test', function()
        assert.same({ name = 'value' }, IniParse:parse('name = value'))
        assert.same({ name = '= value' }, IniParse:parse('name == value'))
        assert.same({ name = ': value' }, IniParse:parse('name =: value'))
        assert.same({ section_test = {} }, IniParse:parse('[section_test]'))
        assert.same({}, IniParse:parse('; this is a comment test'))
    end)

    it('#trim whitespaces test', function()
        assert.same({ name = 'value' }, IniParse:parse('name = value '))
        local z = IniParse:parse(' name = value ')
        assert.same({ name = 'value' }, z)
        local x = IniParse:parse('name =   value  ')
        assert.same({ name = 'value' }, x)
        local p = IniParse:parse('name = value test ')
        assert.same({ name = 'value test' }, p)
        assert.same({ name = 'value test', name2 = 'value test' }, IniParse:parse([[
name = value test
name2 = value test
]]))
    end)

    it('#notrim test', function()
        IniParse:new({
            trim = false
        })
        assert.same({ name = ' value ' }, IniParse:parse('name = value '))
        assert.same({ name = '  value  ' }, IniParse:parse('name =  value  '))
        assert.same({ name = ' value test ' }, IniParse:parse('name = value test '))
        assert.same({ name = 'value test' }, IniParse:parse('name =value test'))
        assert.same({ name = ' value test', name2 = 'value test' }, IniParse:parse([[
name = value test
name2 =value test
]]))
    end)

    it('#comment test', function()
        assert.same({}, IniParse:parse('; comment'))
        assert.same({}, IniParse:parse(' ; comment'))
        assert.same({ name = 'value' }, IniParse:parse('name = value ; comment'))
        assert.same({}, IniParse:parse('# comment'))
        assert.same({}, IniParse:parse [[
; comment
# comment
]])
    end)

    it('#lowercase test', function()
        IniParse:new({
            lowercase_keys = true
        })
        assert.same({ name = 'value' }, IniParse:parse('NAME = value'))
        assert.same({ _name = 'value' }, IniParse:parse('_Name = value'))
        assert.same({
            window = {
                size = '200,200'
            }
        }, IniParse:parse [[
[ WINDOW ]
Size = 200,200
]])
    end)

    it('#string test', function()
        assert.same({ name = '  value ' }, IniParse:parse('name = "  value "'))  -- add explicit whitespaces to string
        assert.same({ name = 'value' }, IniParse:parse('name =" ""value"'))      -- Ignore empty strings
        assert.same({ name = 'value' }, IniParse:parse('name = "value" '))       -- Whitespace before and after double quotes are trimmed
        assert.same({ name = ' \'value' }, IniParse:parse('name = " \'value" ')) -- test quote
        assert.same({ name = '\'value with quote' }, IniParse:parse [[
name = 'value with quote
]])
    end)

    it('custom #settings', function()
        IniParse:new({
            separator = ':',
            comment = '%!'
        })
        assert.same({ name = 'value' }, IniParse:parse('name : value'))
        assert.same({ name = ': value' }, IniParse:parse('name :: value'))
        assert.equal(0, #IniParse:parse('name = value')) -- Invalid key value-pairs are to be discarded
        assert.same({}, IniParse:parse('! this is a comment test'))
        assert.same({}, IniParse:parse('% this is a comment test'))
    end)

    it('#section label', function()
        assert.same({ section_test = {} }, IniParse:parse('[section_test]'))
        assert.same({ section_test1 = {} }, IniParse:parse('[section_test1]'))           -- test digit
        assert.same({ s1ection_test = {} }, IniParse:parse('[s1ection_test]'))           -- test digit
        assert.same({ section_test = {} }, IniParse:parse('[ section_test ]  '))         -- test space

        assert.same({ section_test = {} }, IniParse:parse('[ section_test ] # comment')) -- For some reason this works ?!
        -- assert.same({ section_test = {} }, ini.parse('[ section_test ] name = value\nname2 = value')) -- this works too
        -- Fail tests
        assert.same({ ["[ section_test"] = {} }, IniParse:parse('[[ section_test ]'))    -- allow brackets in section name
        assert.same({ ["section_test"] = {} }, IniParse:parse('[ section_test ]]'))
        assert.same({ ["[ section_test"] = {} }, IniParse:parse('[[ section_test ]]'))   -- ignore any chars after the first bracket in a section name
        assert.same({}, IniParse:parse('[test_section'))
        assert.same({}, IniParse:parse('test_section]'))                                 -- ignore invalid lines that dont have a k/v pair
        assert.same({ ["section test"] = {} }, IniParse:parse('[ section test ]'))
        assert.same({ ["section test"] = {} }, IniParse:parse('[ section test ] trash')) -- don't fail if invalid strings are found in a section's name's line
        assert.same({}, IniParse:parse('[1my_section_test]'))                            -- disallow section names that start with a digit
    end)

    it('Multi-lines no section', function()
        assert.same({
            project = 'My Game',
            version = '1.0.0'
        }, IniParse:parse [[
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
        }, IniParse:parse [[
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
        }, IniParse:parse [[
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
        }, IniParse:parse [[
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
        }, IniParse:parse [[

  [window]

 fullscreen = true
 size = 200,200

]])
    end)

    it('test #duplicate', function()
        -- if an INI file has duplicate sections, cumulate all their key/value pairs
        -- of some are overwritten, keep the last one
        assert.same({
            window = {
                fullscreen = 'false',
                version = '2.0',
                size = '200'
            }
        }, IniParse:parse [[
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
        assert.same({ name = 'value' }, IniParse:parse('name = value\n'))
        assert.same({ name = 'value\n' }, IniParse:parse('name = "value\n"'))
        assert.same({ name = 'value\\n' }, IniParse:parse('name = value\\n'))
        assert.same({ name = '\t value \n \\n' }, IniParse:parse [[
name = "\t value \n \\n"
]])
        IniParse.config {
            escape = false
        }
        assert.same({ name = '\\n \\\\t' }, IniParse:parse [[
name = "\n \\t"
]])
    end)

    it('test #file input', function()
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
                -- escaped_literal = '\n \\n' -- NOT IMPLEMENTED, I'm not handling escaped literals
            }
            -- MAKE sure to replace with absolute path
        }, IniParse:parse_file('/spec/test_windows.ini'))
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
                -- escaped_literal = '\n \\n' -- NOT IMPLEMENTED, I'm not handling escaped literals
            }
            -- MAKE sure to replace with absolute path
        }, IniParse:parse_file('/spec/test_unix.ini'))
        assert.is_nil(IniParse:parse_file('spec/does_not_exist.ini'))
    end)
end)
