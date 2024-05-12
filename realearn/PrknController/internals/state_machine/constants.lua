local constants = {}

---@class StateMachine
---@field btn_sequence string

---@type State
constants.defaultState = {
    btn_sequence = "",
}

---@enum ControllerId = {
constants.ControllerId = {
    Console1 = 1
}

---@enum ActionId
constants.ActionId = {
    disp_on = 1,
    disp_mode = 2,
    shift = 3,
    filt_to_comp = 4,
    phase_inv = 5,
    preset = 6,
    pg_up = 7,
    pg_dn = 8,
    tr1 = 9,
    tr2 = 10,
    tr3 = 11,
    tr4 = 12,
    tr5 = 13,
    tr6 = 14,
    tr7 = 15,
    tr8 = 16,
    tr9 = 17,
    tr10 = 18,
    tr11 = 19,
    tr12 = 20,
    tr13 = 21,
    tr14 = 22,
    tr15 = 23,
    tr16 = 24,
    tr17 = 25,
    tr18 = 26,
    tr19 = 27,
    tr20 = 28,
    shape = 29,
    hard_gate = 30,
    eq = 31,
    hp_shape = 32,
    lp_shape = 33,
    comp = 34,
    tr_grp = 35,
    tr_copy = 36,
    order = 37,
    ext_sidechain = 38,
    solo = 39,
    mute = 40,
}

return constants
