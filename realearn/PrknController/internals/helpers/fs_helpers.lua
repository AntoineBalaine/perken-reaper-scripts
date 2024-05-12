local fs_helpers = {}

local info = debug.getinfo(1, "S")
local os_separator = package.config:sub(1, 1)
    local source = table.concat({ info.source:match(".*PrknController" .. os_separator) })

---@param file_name string
---@param extension string
function fs_helpers.build_prknctrl_path(file_name, extension)
    local internal_root_path = source:sub(2)
    local chain_path = table.concat({ internal_root_path, "config", "controller", file_name, extension }, os_separator)
    return chain_path
end

function fs_helpers.concat(...)
    return table.concat({ ... }, os_separator)
end

function fs_helpers.getControllerConfigPath(controller_name)
    local internal_root_path = source:sub(2)
    local chain_path = table.concat({ internal_root_path, "config", "controller_mappings", controller_name },
        os_separator)
    return chain_path
end

---@param path any
---@return boolean
function fs_helpers.file_exists(path)
    local f = io.open(path, "r")
    if f ~= nil then
        io.close(f)
        return true
    else return false end
end

return fs_helpers
