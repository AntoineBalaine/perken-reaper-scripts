#ifndef SETTINGS_TEST_H
#define SETTINGS_TEST_H

#include "rapidcheck_wrapper.h"
#include "types/settings_types.h"

#ifdef __cplusplus
extern "C" {
#endif

// Define the test environment structure
typedef struct RC_TestEnvironment {
    void* zig_env;  // Opaque pointer to the Zig environment
} RC_TestEnvironment;

// Functions for creating and managing the Zig test environment
void* rc_initialize_zig_environment(void);
void rc_cleanup_zig_environment(void* env);

// Dispatch a settings action to the Zig implementation
void rc_dispatch_settings_action(void* env, RC_SettingsAction action);

// Query functions for verifying state
bool rc_is_settings_panel_open(void* env);
uint8_t rc_get_settings_scroll_position(void* env);
bool rc_get_settings_bool(void* env, const char* field);
void rc_get_settings_string(void* env, const char* field, char* buffer, size_t buffer_size);

// Run stateful settings tests
bool rc_run_settings_tests();

#ifdef __cplusplus
}
#endif

#endif // SETTINGS_TEST_H
