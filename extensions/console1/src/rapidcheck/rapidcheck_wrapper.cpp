#include "rapidcheck_wrapper.h"
#include <rapidcheck.h>
#include <string>
#include <vector>
#include <limits>

struct RC_TestContext {
    rc::Random random;
    std::string failure_reason;
    bool last_result;
};

RC_TestContext* rc_create_context() {
    return new RC_TestContext{rc::Random(), "", true};
}

void rc_destroy_context(RC_TestContext* ctx) {
    delete ctx;
}

bool rc_check_prop(RC_TestContext* ctx, rc_property_func property) {
    ctx->last_result = rc::check([property](void) {
        return property() != 0;
    });

    return ctx->last_result;
}

const char* rc_get_failure_reason(RC_TestContext* ctx) {
    if (ctx->last_result) {
        ctx->failure_reason = "No failure";
    } else {
        ctx->failure_reason = "Property failed";
    }
    return ctx->failure_reason.c_str();
}

int rc_generate_int(RC_TestContext* ctx, int min, int max) {
    return rc::Random(ctx->random).next() % (max - min + 1) + min;
}

RC_Param* rc_generate_param(RC_TestContext* ctx) {
    auto param = new RC_Param();
    
    // Generate random name
    std::string name = *rc::gen::string<std::string>();
    param->name = strdup(name.c_str());
    
    // Generate normalized value between 0.0 and 1.0
    param->normalized_value = static_cast<double>(rc::Random(ctx->random).next()) / static_cast<double>(std::numeric_limits<uint64_t>::max());
    
    // Generate formatted value
    std::string formatted = std::to_string(param->normalized_value);
    param->formatted_value = strdup(formatted.c_str());
    
    return param;
}

RC_FX* rc_generate_fx(RC_TestContext* ctx) {
    auto fx = new RC_FX();
    
    // Generate random GUID
    for (int i = 0; i < 16; i++) {
        fx->guid[i] = static_cast<uint8_t>(rc::Random(ctx->random).next() % 256);
    }
    
    // Random enabled state
    fx->enabled = rc::Random(ctx->random).next() % 2 == 1;
    
    // Generate random number of parameters (1-5 for testing)
    int param_count = rc::Random(ctx->random).next() % 5 + 1;
    fx->params = new RC_Param[param_count];
    fx->params_count = param_count;
    
    for (int i = 0; i < param_count; i++) {
        RC_Param* param = rc_generate_param(ctx);
        fx->params[i] = *param;
        delete param;
    }
    
    // Generate names
    std::string name = *rc::gen::string<std::string>();
    fx->named_configs.original_name = strdup(name.c_str());
    fx->named_configs.renamed_name = strdup(name.c_str());
    
    // Random gain reduction
    double random_value = static_cast<double>(rc::Random(ctx->random).next() % 6000) / 100.0;
    fx->named_configs.gain_reduction_db = -random_value; // Negative value between 0 and -60.0
    
    return fx;
}

void rc_free_param(RC_Param* param) {
    if (param) {
        free((void*)param->name);
        free((void*)param->formatted_value);
        delete param;
    }
}

void rc_free_fx(RC_FX* fx) {
    if (fx) {
        for (int i = 0; i < fx->params_count; i++) {
            free((void*)fx->params[i].name);
            free((void*)fx->params[i].formatted_value);
        }
        delete[] fx->params;
        free((void*)fx->named_configs.original_name);
        free((void*)fx->named_configs.renamed_name);
        delete fx;
    }
}
