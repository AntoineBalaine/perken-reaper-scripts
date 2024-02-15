# INI-parse
A small parser based on [Lua_INI_Parser](https://github.com/Dynodzzo/Lua_INI_Parser) using [ini.lua](https://github.com/lzubiaur/ini.lua)'s test suite

### Why another ini parser? 
My first reference - [Lua_INI_Parser](https://github.com/Dynodzzo/Lua_INI_Parser) - doesn't really support comments, and [ini.lua](https://github.com/lzubiaur/ini.lua) depends on [LPEG](https://www.inf.puc-rio.br/~roberto/lpeg/). I wanted a middle ground: no runtime dependencies, and inline comments. Plus, writing a small parser's fun.

# Usage
Add `IniParse.lua` file into your project folder.
Call it using __require__ function.
It will return a table containing read & write functions.

```lua
local IniParse = require("IniParse")
IniParse.load(fileName) -- Return a table containing key/value pairs from the file
IniParse.save(fileName, data) -- writes data object into the file.
```

## Examples
### Writing an *ini* file:

```lua
local IniParse = require 'IniParse';

local data =
{
	first_header =
	{
		something1 = 1,
		something2 = 2,
	},
	second_header =
	{
		something3 = 3,
		a_string = "here's a string",
		a_boolean = true,
	},
};

-- Data saving
IniParse.save('savedata.ini', data);
```
results in the following *.ini* file:
```ini
[first_hedaer]
something1=1
something2=2

[screen]
something3=3,
a_string="here's a string",
a_boolean=true,
```

### Reading an *ini* file:

```lua
local IniParse = require 'IniParse';

-- Data loading
local data = IniParse.load('savedata.ini');
assert.same({

})
print(data.sound.right); --> 80
print(data.screen.caption); --> Window's caption
print(data.screen.focused); --> true
````

It is also possible to give indexes instead of keys :

```lua
local data =
{
	{
		right = 40,
		50,
	},
	{
		'Some text',
		20,
		true,
	},
};
```

And we have to retrieve data using these indexes :

```lua
print(data[1][1]); --> 50
print(data[1].right) --> 40
print(data[2][1]); --> Some text
print(data[2][3]); --> true
```
# Things to know 

Comments starts with the semicolon (;) or number character (#). Comment-characters can be changed using the ini.config function (see configuration below). Blank lines and comment lines are ignored in the conversion.

```ini
; comment
mykey = myvalue # inline comments are ok.
```
# Config
The parser accepts a config object when instantiated. The config follows this shape:
```lua 
---default config object for the INI parser
---@class CONFIG
---@field separator string String to define the separator character. Default is the equal character (=).
---@field comment string String to specify the comment characters. Default is semicolon (;) and number sign (#).
---@field trim boolean By default, leading and trailing white spaces are trimmed. This can be overridden by setting false to this parameter.
---@field lowercase_keys boolean By default, the keys are not case sensitive. This can be changed by forcing the keys to be lowercase_keys by setting this parameter to true.
---@field escape false By default. C-like escape sequences are interpreted. If set to false, then escape sequences are left unchanged.
{
    separator = '=',
    comment = ';#',
    trim = true,
    lowercase_keys = false,
    escape = false
}
```

# Known issues
1. This parser does __not__ support line breaks in strings:
```ini
mykey = "myvalue\n"
```
2. Duplicate sections __do__ overwrite each other. __But__, if an INI file has duplicate sections, their key/value pairs are cumulated. 
```ini
[window]
fullscreen = true
size = 200

[window]
version = 1.0
fullscreen = false
version = 2.0
```
will result in 
```lua
{
    window = {
        fullscreen = 'false',
        version = '2.0',
        size = '200'
    }
}
```
2. Single quotes are __not__ accepted as string delimiters.
```ini
mykey = 'myvalue'
```
 will yield
 ```lua
{mykey = "'myvalue'"}
 ```

# Testing
You may optionally install busted to run the test suite.
```bash
sudo luarocks install busted
busted
```
