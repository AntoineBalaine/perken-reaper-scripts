#include "fx_model.h"
#include <stdlib.h>

void rc_param_free(RC_Param* param) {
    if (param) {
        free(param->name);
        free(param->formatted_value);
    }
}

void rc_named_configs_free(RC_NamedConfigs* configs) {
    if (configs) {
        free(configs->original_name);
        
        // Only free renamed_name if it's different from original_name
        if (configs->original_name != configs->renamed_name) {
            free(configs->renamed_name);
        }
        
    }
}

void rc_fx_free(RC_FX* fx) {
    if (fx) {
        // Free all parameters
        for (size_t i = 0; i < fx->params_count; i++) {
            rc_param_free(&fx->params[i]);
        }
        free(fx->params);
        
        // Free the named configurations
        rc_named_configs_free(&fx->named_configs);
    }
}
