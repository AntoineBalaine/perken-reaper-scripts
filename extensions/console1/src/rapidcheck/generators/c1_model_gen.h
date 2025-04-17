#ifndef C1_MODEL_GEN_H
#define C1_MODEL_GEN_H

#include <rapidcheck.h>
#include "../types/c1_model.h"
#include <vector>
#include <cstring>

namespace rc {

// Generator for C1 CC values
struct C1ControlUpdate {
    uint8_t cc;
    uint8_t value;
};

template<>
struct Arbitrary<C1ControlUpdate> {
    static Gen<C1ControlUpdate> arbitrary() {
        return gen::map(
            gen::tuple(
                gen::element(std::vector<uint8_t>{
                    // List of valid CC values from c1.zig

    CC_Comp_Attack , CC_Comp_DryWet , CC_Comp_Ratio , CC_Comp_Release , CC_Comp_Thresh , CC_Comp_comp , CC_Comp_Mtr ,
    
    // EQ module
    CC_Eq_HiFrq , CC_Eq_HiGain , CC_Eq_HiMidFrq , CC_Eq_HiMidGain , CC_Eq_HiMidQ , CC_Eq_LoFrq , CC_Eq_LoGain , CC_Eq_LoMidFrq , CC_Eq_LoMidGain , CC_Eq_LoMidQ , CC_Eq_eq , CC_Eq_hp_shape , CC_Eq_lp_shape ,
    
    // Input module
    CC_Inpt_Gain , CC_Inpt_HiCut , CC_Inpt_LoCut , CC_Inpt_disp_mode , CC_Inpt_disp_on , CC_Inpt_filt_to_comp , CC_Inpt_phase_inv , CC_Inpt_preset , CC_Inpt_MtrLft , CC_Inpt_MtrRgt ,
    
    // Output module
    CC_Out_MtrLft , CC_Out_MtrRgt , CC_Out_Drive , CC_Out_DriveChar , CC_Out_Pan , CC_Out_Vol , CC_Out_mute , CC_Out_solo ,
    
    // Shape module
    CC_Shp_Mtr , CC_Shp_Gate , CC_Shp_GateRelease , CC_Shp_Punch , CC_Shp_hard_gate , CC_Shp_shape , CC_Shp_sustain ,
    
    // Track module
    CC_Tr_ext_sidechain , CC_Tr_order , CC_Tr_pg_dn , CC_Tr_pg_up , CC_Tr_tr1 , CC_Tr_tr2 , CC_Tr_tr3 , CC_Tr_tr4 , CC_Tr_tr5 , CC_Tr_tr6 , CC_Tr_tr7 , CC_Tr_tr8 , CC_Tr_tr9 , CC_Tr_tr10 , CC_Tr_tr11 , CC_Tr_tr12 , CC_Tr_tr13 , CC_Tr_tr14 , CC_Tr_tr15 , CC_Tr_tr16 , CC_Tr_tr17 , CC_Tr_tr18 , CC_Tr_tr19 , CC_Tr_tr20 , CC_Tr_tr_copy , CC_Tr_tr_grp ,
                }),
                gen::inRange<uint8_t>(0, 127)  // Valid MIDI CC values
            ),
            [](const auto& tuple) {
                C1ControlUpdate update;
                update.cc = std::get<0>(tuple);
                update.value = std::get<1>(tuple);
                return update;
            }
        );
    }
};

// Generator for a sequence of C1 control updates
template<>
struct Arbitrary<std::vector<C1ControlUpdate>> {
    static Gen<std::vector<C1ControlUpdate>> arbitrary() {
        return gen::container<std::vector<C1ControlUpdate>>(
            gen::arbitrary<C1ControlUpdate>(),
            gen::inRange(0, 50)  // Generate between 0 and 50 updates
        );
    }
};

} // namespace rc

#endif // C1_MODEL_GEN_H

