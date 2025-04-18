#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    BOOL_SETTING,
    STRING_SETTING,
    // Could add INT_SETTING, FLOAT_SETTING, etc. in the future
} RC_SettingType;

typedef struct {
    char field[64];
    RC_SettingType type;
    union {
        bool bool_value;
        char *string_value;
        // Could add: int int_value;
        // Could add: float float_value;
    } value;
} RC_SettingsUpdate;

typedef enum {
    OPEN,
    SAVE,
    CANCEL,
    SCROLL,
    TOGGLE,
    UPDATE
} RC_SettingsActionType;

typedef struct {
    RC_SettingsActionType action_type;
    union {
        uint8_t scroll_pos;      // For SCROLL action
        RC_SettingsUpdate update; // For UPDATE action
    } data;
} RC_SettingsAction;

#ifdef __cplusplus
}
#endif 