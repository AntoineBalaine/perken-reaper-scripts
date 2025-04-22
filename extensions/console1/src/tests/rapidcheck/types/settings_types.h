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
    char* field;  // Pointer to null-terminated string
    RC_SettingType type;
    union {
        bool bool_value;
        char* string_value;  // Pointer to null-terminated string
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
