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
    // Assuming CCs 0-15 are buttons (based on the enum definition)
    return (int)cc < 16;
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
    model->values[(int)cc % CC_COUNT] = validValue;
}

uint8_t rc_c1model_get_value(const RC_C1Model* model, RC_C1_CC cc) {
    if (!model) return 0;
    
    return model->values[(int)cc % CC_COUNT];
}

