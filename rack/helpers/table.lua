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

-- ---@param t unknown
-- function table_helpers.deepCopy(t)
--     local t_type = type(t)
--     local retval
--     if t_type == 'table' then
--         retval = {}
--         for t, n in next, t, nil do
--             retval[table_helpers.deepCopy(t)] = table_helpers.deepCopy(n)
--         end
--         setmetatable(retval, table_helpers.deepCopy(getmetatable(t)))
--     else
--         retval = t
--     end
--     return retval
-- end

---Scythe's deep copy function -- TODO investigate and credit original author
--- Performs a deep copy of the given table - any tables are recursively
-- deep-copied to the new table.
--
-- To explicitly prevent child tables from being deep-copied, set `.__noRecursion
-- = true`. This particularly important when working with circular references, as
-- deep-copying will lead to a stack overflow.
--
-- Adapted from: http://lua-users.org/wiki/CopyTable
---@param t     table
---@param copies? table
---@param exclude_keys? string[]
---@return      table
table_helpers.deepCopy = function(t, copies, exclude_keys)
    copies = copies or {}

    local copy
    if type(t) == "table" then
        if copies[t] then
            copy = copies[t]
        else
            -- Override so we don't end up working through circular references for
            -- elements, layers, etc
            if t.__noRecursion then
                copy = t
            else
                copy = {}
                for k, v in next, t, nil do
                    local found = false
                    if exclude_keys then
                        for _, exclude_key in ipairs(exclude_keys) do
                            if k == exclude_key then
                                found = true
                            end
                        end
                    end
                    if not found then
                        copy[table_helpers.deepCopy(k, copies, exclude_keys)] = table_helpers.deepCopy(v, copies,
                            exclude_keys)
                    end
                end
            end

            copies[t] = copy
            setmetatable(copy, table_helpers.deepCopy(getmetatable(t), copies))
        end
    else -- number, string, boolean, etc
        copy = t
    end
    return copy
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
