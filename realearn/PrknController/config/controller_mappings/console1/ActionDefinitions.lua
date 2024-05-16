local button_actions = require("button_actions")

---TODO switch the needed defs to <S-action>
local defs = {
    bypass = "_XENAKIOS_BYPASSFXOFSELTRAX",
    ext_sidechain = button_actions.updateExtSidechain, -- switch inputs 3-4 to enter into shape or comp
    filt_to_comp = button_actions.toggleFiltToComp, --
    mute = 6,
    next_track = "_XENAKIOS_SELNEXTTRACK",             --pg_up
    order = button_actions.updateOrder,
    phase_inv = 40282,
    preset = button_actions.openPresetSelector,
    prev_track = "_XENAKIOS_SELPREVTRACK",             -- pg_dn
    savePreset = button_actions.saveFxChainPreset,
    solo = 7,
}
