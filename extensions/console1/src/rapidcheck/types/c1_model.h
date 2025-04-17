#ifndef C1_MODEL_H
#define C1_MODEL_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

// C-compatible representation of the C1Model
typedef struct {
    uint8_t values[256];
} RC_C1Model;

// Enum for C1 Control Change values (mirroring the Zig CCs enum)
typedef enum {
    // Comp module
    CC_Comp_Attack = 0x33,
    CC_Comp_DryWet = 0x32,
    CC_Comp_Ratio = 0x31,
    CC_Comp_Release = 0x30,
    CC_Comp_Thresh = 0x2f,
    CC_Comp_comp = 0x2e,
    CC_Comp_Mtr = 0x73,
    
    // EQ module
    CC_Eq_HiFrq = 0x53,
    CC_Eq_HiGain = 0x52,
    CC_Eq_HiMidFrq = 0x56,
    CC_Eq_HiMidGain = 0x55,
    CC_Eq_HiMidQ = 0x57,
    CC_Eq_LoFrq = 0x5c,
    CC_Eq_LoGain = 0x5b,
    CC_Eq_LoMidFrq = 0x59,
    CC_Eq_LoMidGain = 0x58,
    CC_Eq_LoMidQ = 0x5a,
    CC_Eq_eq = 0x50,
    CC_Eq_hp_shape = 0x5d,
    CC_Eq_lp_shape = 0x41,
    
    // Input module
    CC_Inpt_Gain = 0x6b,
    CC_Inpt_HiCut = 0x69,
    CC_Inpt_LoCut = 0x67,
    CC_Inpt_disp_mode = 0x68,
    CC_Inpt_disp_on = 0x66,
    CC_Inpt_filt_to_comp = 0x3d,
    CC_Inpt_phase_inv = 0x6c,
    CC_Inpt_preset = 0x3a,
    CC_Inpt_MtrLft = 0x6e,
    CC_Inpt_MtrRgt = 0x6f,
    
    // Output module
    CC_Out_MtrLft = 0x70,
    CC_Out_MtrRgt = 0x71,
    CC_Out_Drive = 0xf,
    CC_Out_DriveChar = 0x12,
    CC_Out_Pan = 0xa,
    CC_Out_Vol = 0x7,
    CC_Out_mute = 0xc,
    CC_Out_solo = 0xd,
    
    // Shape module
    CC_Shp_Mtr = 0x72,
    CC_Shp_Gate = 0x36,
    CC_Shp_GateRelease = 0x38,
    CC_Shp_Punch = 0x39,
    CC_Shp_hard_gate = 0x3b,
    CC_Shp_shape = 0x35,
    CC_Shp_sustain = 0x37,
    
    // Track module
    CC_Tr_ext_sidechain = 0x11,
    CC_Tr_order = 0xe,
    CC_Tr_pg_dn = 0x61,
    CC_Tr_pg_up = 0x60,
    CC_Tr_tr1 = 0x15,
    CC_Tr_tr2 = 0x16,
    CC_Tr_tr3 = 0x17,
    CC_Tr_tr4 = 0x18,
    CC_Tr_tr5 = 0x19,
    CC_Tr_tr6 = 0x1a,
    CC_Tr_tr7 = 0x1b,
    CC_Tr_tr8 = 0x1c,
    CC_Tr_tr9 = 0x1d,
    CC_Tr_tr10 = 0x1e,
    CC_Tr_tr11 = 0x1f,
    CC_Tr_tr12 = 0x20,
    CC_Tr_tr13 = 0x21,
    CC_Tr_tr14 = 0x22,
    CC_Tr_tr15 = 0x23,
    CC_Tr_tr16 = 0x24,
    CC_Tr_tr17 = 0x25,
    CC_Tr_tr18 = 0x26,
    CC_Tr_tr19 = 0x27,
    CC_Tr_tr20 = 0x28,
    CC_Tr_tr_copy = 0x7b,
    CC_Tr_tr_grp = 0x78,
    
    CC_COUNT
} RC_C1_CC;

// Function prototypes
void rc_c1model_init(RC_C1Model* model);
void rc_c1model_reset(RC_C1Model* model);
int rc_c1_cc_is_btn(RC_C1_CC cc);
void rc_c1model_update_value(RC_C1Model* model, RC_C1_CC cc, uint8_t value);
uint8_t rc_c1model_get_value(const RC_C1Model* model, RC_C1_CC cc);

#ifdef __cplusplus
}
#endif

