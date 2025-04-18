#ifndef RAPIDCHECK_WRAPPER_H
#define RAPIDCHECK_WRAPPER_H

#include "types/fx_model.h"

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h> // Add this line to get bool type in C

typedef struct RC_TestContext RC_TestContext;
typedef int (*rc_property_func)(void);

RC_TestContext* rc_create_context();
void rc_destroy_context(RC_TestContext* ctx);
bool rc_check_prop(RC_TestContext* ctx, rc_property_func property);
const char* rc_get_failure_reason(RC_TestContext* ctx);
int rc_generate_int(RC_TestContext* ctx, int min, int max);

// FX model generation functions
RC_Param* rc_generate_param(RC_TestContext* ctx);
RC_FX* rc_generate_fx(RC_TestContext* ctx);
void rc_free_param(RC_Param* param);
void rc_free_fx(RC_FX* fx);

#ifdef __cplusplus
}
#endif

#endif // RAPIDCHECK_WRAPPER_H
