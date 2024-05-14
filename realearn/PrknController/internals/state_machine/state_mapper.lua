---@class MODE
---@class MODE_STATE table<string, unknown>
---@field controls table<string, BUTTON|ENCODER>
---@field label? string not sure about this.
---use realearn encoders:
--one realearn instance per module
--swap module presets with button actions

--- action definitions when clicking a button.
local ActionDefs = {
    ["FX_CTRL"] = {
        ["Btn1"] = {
            label = "NxtPg",
            action = function() end
        },
        ["2"] = {
            label = "Track",
            action = 40296 -- Show track routing
        },
    },
    ["MODULE_SELECT"] = {
        buttons = {
            ["1"] = {
                label = "FX",
                action =
                    40271 -- Main Context action ID Show FX chain
            },
        },
        nextMode = "STRIP_SELECT"
    },
    ["STRIP_SELECT"] = {
        buttons = {
            ["1"] = {
                label = "Track",
                action = 40296 -- Show track routing
            },
        },
        nextMode = "SETTINGS"
    }
}

---Module map describes what realearn preset needs to be used for each module
local ModuleMap = {
    ["FX_CTRL"] = {
        EQ = {
            -- list of strips
            {
                fx = "reaEq", -- if fx param exists, check that it's loaded on currently selected track
                preset = "realearnPreset_EQ_ReaEq",
            },
            {
                fx = "craveEQ",
                preset = "realearnPreset_EQ_CraveEq",
            },
        },
        CMP = {
            {
                fx = "reaComp",
                preset = "realearnPreset_CMP_ReaComp"
            }
        }
    },
    ["TRK_CTRL"] = {
        EQ = {
            {
                preset = "realearnPreset_EQ_controlSmth"
            }
        }
    }
}

local function GetTrackFX()
    local selected_track = reaper.GetSelectedTrack(0, 0)
    -- get fx by name: expect the prknCtrl container to exist
    -- return false if not,
    -- get fx in container
end

local function validateChain(trackfx, expected_chain)
    --check that the current track's prknctrl chain matches that prescribed by the channelStrip.
    for k, v in ipairs(trackfx) do
        if expected_chain[k].name ~= v.name then
            return false
        end
        return true
    end
end

local function getModuleMap()
    return ModuleMap
end

---read current track ext state
--strip?
--  validate strip & load
--modules map
--load each module's realearn preset
local function SetMode()
    --[[
    read current track ext state.
    check what channel strip needs to be loaded for each module
    validate the strip and make changes if necessary
    call ModuleMap
    set the realern presets from module map

    ]]

    local state         = reaperState.get()[getTrackGUID()] -- get ext state

    state.mode          = "currentMode"
    local selectedChain = state.chain
    local validChain    = validateChain(GetTrackFX(), selectedChain)
    local moduleMap     = getModuleMap()[state.mode][context]
    if not validChain then
        local chain = mapChain(moduleMap) -- build the needed channel strip
        loadChain(chain)                  -- update any prknCtrl FX
    end
    ---@type {modulename, presetname}[]
    local presets = mapRelearnPresets(moduleMap) -- fetch realearn presets for each of the modules
    loadPresets(presets)
    -- set new global mode in ext state
    reaperState.set(state)
end

local function getActionDefs()
    return ActionDefs
end

---@param mode string
---@param context string
---@param btn_pressed string
local function buttonAction(mode, context, btn_pressed, ext_state)
    local action = getActionDefs()[mode][context][btn_pressed]
    action() -- might want to set state for pages
end

local function doInput(keyId, context)
    local state = reaperState.get() -- get ext state
    buttonAction(state.mode, keyId, context, state)
end

--[[
    STATE
    | loads
    v
    CONFIG
    | loads
    v
    DEFAULT STRIP
    | loads
    v
    DEFAULT MODE
    | calls
    v
    FX CTRL
    |
    |--------------------------------------------
    |               |               |           |
    MODULE_SELECT   STRIP_SELECT    SETTINGS    MAPPER_SCREEN
]]
