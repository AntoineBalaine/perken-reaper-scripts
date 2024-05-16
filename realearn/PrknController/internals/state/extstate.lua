---@enum Routing
local Routing = {
    eq_s_c = 1,
    s_c_eq = 2,
    s_eq_c = 3,
}

---@enum filt_to_comp
local filt_to_comp = {
    off = 1,
    on = 2
}

---@enum ext_sc
local ext_sc = {
    toShape = 1,
    toComp = 2,
    off = 3
}

---@class ExtStateModules
---@field eq string
---@field cmp string
---@field shp string
---@field input string
---@field output string

---@class ExtStateTrk
---@field modules ExtStateModules
---@field routing Routing
---@field ext_sc ext_sc
---@field filt_to_comp filt_to_comp

---@class ExtState
---@field tracks ExtStateTrk[]
---@field namespace string
---@field actionId ActionId|nil

---@type ExtState
local tracks = {
    tracks = {
        [1] = {
            modules = {
                eq = "ReaEq",
                cmp = "reacomp",
                shp = "reagate",
                input = "kazrog",
                output = "volume v5",
            },
            routing = Routing.eq_s_c,
            ext_sc = ext_sc.off,
            filt_to_comp = filt_to_comp.off,
        }
    },
    namespace = "console1",
    actionId = nil
}
