local button_actions = {}

---@param state State
function button_actions.saveFxChainPreset(state)
    error("save fx chain preset not implemented")
end

---@param state State
function button_actions.openPresetSelector(state)
    error("save fx chain preset not implemented")
end

---@param state State
function button_actions.updateOrder(state)
    error("save fx chain preset not implemented")
    state.ext_state.routing = (state.routing + 1) % 3
    -- implement rest of update:
    --[[
 get index of first element in the fx
 use that as reference to move the rest of the fx
    ]]
end

---@param state State
function button_actions.updateExtSidechain(state)
    error("save ext sidechain not implemented")
    state.ext_state.ext_sc = (state.ext_sc + 1) % 3
end

---@param state State
function button_actions.toggleFiltToComp(state)
    error("save filters to comp not implemented")
    -- move input filters right before the compressor
    -- if compressor is set to receive external sidechain,
    -- set input filters to output to sidechain channels
    state.ext_state.filt_to_comp = (state.filt_to_comp + 1) % 2
end

return button_actions
