local table_helpers = {}

function table_helpers.namedTableLength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end

return table_helpers
