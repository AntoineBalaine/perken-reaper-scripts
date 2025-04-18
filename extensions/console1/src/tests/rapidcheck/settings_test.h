#ifndef SETTINGS_TEST_H
#define SETTINGS_TEST_H

#include "rapidcheck_wrapper.h"
#include "types/settings_types.h"

#ifdef __cplusplus
extern "C" {
#endif

// Dispatch a settings action to the Zig implementation
void rc_dispatch_settings_action(RC_TestEnvironment* env, RC_SettingsAction* action);

// Query functions for verifying state
bool rc_is_settings_panel_open(RC_TestEnvironment* env);
uint8_t rc_get_settings_scroll_position(RC_TestEnvironment* env);
bool rc_get_settings_bool(RC_TestEnvironment* env, const char* field);
void rc_get_settings_string(RC_TestEnvironment* env, const char* field, char* buffer, size_t buffer_size);

// Run stateful settings tests
bool rc_run_settings_tests();

#ifdef __cplusplus
}
#endif

#endif // SETTINGS_TEST_H
