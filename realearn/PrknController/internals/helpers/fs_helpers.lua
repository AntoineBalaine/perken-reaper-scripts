local fs_helpers = {}

---@param path string
---@param extension string
function fs_helpers.build_prknctrl_path(path, extension)
    local info = debug.getinfo(1, "S")
    local Os_separator = package.config:sub(1, 1)
    local source = table.concat({ info.source:match(".*PrknController" .. Os_separator) })
    local internal_root_path = source:sub(2)
    local chain_path = table.concat({ internal_root_path, "config", "controller", path, extension }, Os_separator)
    return chain_path

end

---@param path any
---@return boolean
function fs_helpers.file_exists(path)
   local f=io.open(path,"r")
   if f~=nil then io.close(f) return true else return false end
end

return fs_helpers
