#ifndef FX_MODEL_H
#define FX_MODEL_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stddef.h>

// Param struct representing a plugin parameter
typedef struct {
    char* name;
    double normalized_value;
    char* formatted_value;
} RC_Param;

// Named configurations struct
typedef struct {
    char* original_name;
    char* renamed_name;
    double gain_reduction_db;  // Optional, NaN when not set
} RC_NamedConfigs;

// FX struct representing an effect plugin
typedef struct {
    unsigned char guid[16];  // 16 bytes for GUID
    bool enabled;
    RC_Param* params;
    size_t params_count;
    RC_NamedConfigs named_configs;
} RC_FX;

// Memory management functions
void rc_param_free(RC_Param* param);
void rc_named_configs_free(RC_NamedConfigs* configs);
void rc_fx_free(RC_FX* fx);

#ifdef __cplusplus
}
#endif

#endif // FX_MODEL_H
