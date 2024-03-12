--[[
table helpers, to fill in some special needs that might be missing from the lua’s standard library.
]]
local table_helpers = {}

---@param T table<string, unknown>
---@return number
function table_helpers.namedTableLength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

---@param t unknown
function table_helpers.deepCopy(t)
    local t_type = type(t)
    local retval
    if t_type == 'table' then
        retval = {}
        for t, n in next, t, nil do
            retval[table_helpers.deepCopy(t)] = table_helpers.deepCopy(n)
        end
        setmetatable(retval, table_helpers.deepCopy(getmetatable(t)))
    else
        retval = t
    end
    return retval
end

---returns an iterator over the table
---@generic T
---@param T table<string, T>
---@return fun():string, T
function table_helpers.sortNamedTable(T)
    --- Sorts a named table by its keys.
    local keys = {}
    for key in pairs(T) do table.insert(keys, key) end
    table.sort(keys)
    local i = 0
    local iter = function()
        i = i + 1
        if keys[i] == nil then
            return nil
        else
            return keys[i], T[keys[i]]
        end
    end
    return iter
end

return table_helpers
