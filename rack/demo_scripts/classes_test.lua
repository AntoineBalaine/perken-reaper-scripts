--[[
This file demonstrates how to create classes that can be instantiated.
--]]
local module = {}
module.__index = module

function module.new()
    local myClass = setmetatable({}, module)

    myClass.Property = "Hello, world!"

    return myClass
end

function module:ObjectMethod()
    print(self.Property)
end

local a = module.new()
a.Property = "first one"
local b = module.new()
b.Property = "second one"

print(a:ObjectMethod())
print(b:ObjectMethod())
