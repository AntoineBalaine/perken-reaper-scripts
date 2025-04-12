#include "rapidcheck_wrapper.h"
#include <rapidcheck.h>
#include <string>
#include <vector>

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
