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

return table_helpers
