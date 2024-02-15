Here's some rules about how your code should be written, if you plan on sending a PR. These rules are stringent and might be different from what you're used to when scripting for reaper. Sorry, not sorry: they’re meant to allow new-comers to the project to easily read and understand what's going on in the code. 
Also, it allows me to understand what you're trying to do, and it saves me the time of having to clean-up and refactor after you. Remember, nobody here wants to be your cleaning lady, so give me something that's readable.

Here's the rules:

1. ABSOLUTELY NO GLOBALS. No global variables. None whatsoever. Only use locals. If you need to access a parent-component's state from a child, pass it in a `init` function. If you really have to, temporary-use globals should be in a local `temp` table, and that table should be passed from the top-level file.
```lua
local application_state = {--[[some data here]]}
local temp_state = {my_temp_var: "something"}
local my_module = require("my_module")
my_module:init(application_state, temp_state)
```

2. Add TYPE ANNOTATIONS FOR EVERY FUNCTION. Everyone of them. Params and return values should be typed using LuaLs' annotation system.
```lua
---@param param1 string|nil
local my_function(param1) 
--[[do something here]]
end
```
3. Add DESCRIPTION COMMENTS FOR EVERY FUNCTION. That's for every function that is going to be used outside your module. Unless what the function does is perfectly clear from its name, add a description-blob.
```lua
---This is blob that describes what this function does.
---Here's how you can use it, and here's what it does
---```lua
---my_function() --do whatever this function needs to do…
---```
local my_function()
--[[do something here]]
end
```
5. USE MODULES. Aside from the `rack.lua` file, every file should return a table that contains its functions.
```lua
-- my_module.lua

---this is a description blob explaining what this module does.
local my_module = {}
function my_module.a_function()
--[[do something here]]
end
return my_module
```
6. TYPE EVERYONE OF YOUR TABLES. Everyone of them. Named-tables are marked as `class`, number-indexed table are marked as arrays `[]`.
```lua
---@type string[]
local my_table = { "hello", "world" }
---@class my_other_table
---@field name string
---@field age number
local my_other_table = { name = "me!", age = 1000 }
```
8. DON'T IGNORE LUALS' WARNINGS. If fixing the warnings makes you wrestle and re-write the code, that's a good thing.
9. Use ASSERT and PCALL when data types are unclear. This means: don't let the program crash, use error-handling using `pcall`.
10. FORMAT YOUR CODE. Use LuaLs’ formatter. Set it up and forget about it.
11. FUNCTIONS SHOULDN'T HAVE SIDE EFFECTS. Unless you're in a class or a component, any function that has an input should also have an output.
```lua
some_random_value = "bla" -- don’t use globals.
function rando_fun()
	some_random_value = "hello" -- hell, no!
end
```
12. DON’T RE-DECLARE VARIABLE NAMES. Don’t do it.
```lua
local rv, some_value = some_function()
local rv, some_other_value = some_other_function() -- hell, no!
```
13. DON’T SHORT-HAND NAME YOUR VARIABLES. No, it doesn’t save you time to short-hand variable names, it just sucks up *my* time trying to figure your code out.
```lua
local trs_vr_nm = "this is a terse variable name" -- why, though ?
```

