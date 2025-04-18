#include "c1_model.h"
#include <string.h>

void rc_c1model_init(RC_C1Model* model) {
    if (model) {
        memset(model->values, 0, sizeof(model->values));
    }
}

void rc_c1model_reset(RC_C1Model* model) {
    if (model) {
        memset(model->values, 0, sizeof(model->values));
    }
}

int rc_c1_cc_is_btn(RC_C1_CC cc) {
    // Match the Zig implementation's isBtn() method
    switch (cc) {
        case CC_Comp_comp:
        case CC_Eq_eq:
        case CC_Eq_hp_shape:
        case CC_Eq_lp_shape:
        case CC_Inpt_disp_mode:
        case CC_Inpt_disp_on:
        case CC_Inpt_filt_to_comp:
        case CC_Inpt_phase_inv:
        case CC_Inpt_preset:
        case CC_Out_mute:
        case CC_Out_solo:
        case CC_Shp_hard_gate:
        case CC_Shp_shape:
        case CC_Tr_ext_sidechain:
        case CC_Tr_order:
        case CC_Tr_pg_dn:
        case CC_Tr_pg_up:
        case CC_Tr_tr1:
        case CC_Tr_tr2:
        case CC_Tr_tr3:
        case CC_Tr_tr4:
        case CC_Tr_tr5:
        case CC_Tr_tr6:
        case CC_Tr_tr7:
        case CC_Tr_tr8:
        case CC_Tr_tr9:
        case CC_Tr_tr10:
        case CC_Tr_tr11:
        case CC_Tr_tr12:
        case CC_Tr_tr13:
        case CC_Tr_tr14:
        case CC_Tr_tr15:
        case CC_Tr_tr16:
        case CC_Tr_tr17:
        case CC_Tr_tr18:
        case CC_Tr_tr19:
        case CC_Tr_tr20:
        case CC_Tr_tr_copy:
        case CC_Tr_tr_grp:
            return 1;
        default:
            return 0;
    }
}

void rc_c1model_update_value(RC_C1Model* model, RC_C1_CC cc, uint8_t value) {
    if (!model) return;
    
    uint8_t validValue;
    
    if (rc_c1_cc_is_btn(cc)) {
        // For buttons, only use 0 or 127
        validValue = value > 0 ? 127 : 0;
    } else {
        // For knobs, use any value between 0 and 127
        validValue = value > 127 ? 127 : value;
    }
    
    // Store in the array using the CC enum value as index
    // Use the raw enum value as the index, matching Zig's behavior
    model->values[(uint8_t)cc] = validValue;
}

uint8_t rc_c1model_get_value(const RC_C1Model* model, RC_C1_CC cc) {
    if (!model) return 0;
    
    // Use the raw enum value as the index, matching Zig's behavior
    return model->values[(uint8_t)cc];
}

