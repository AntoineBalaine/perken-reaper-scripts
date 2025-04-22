#include "rapidcheck_wrapper.h"
#include "settings_test.h"
#include "types/settings_types.h"
#include "settings_commands.cpp"
#include <rapidcheck.h>
#include <rapidcheck/state.h>
#include <string>
#include <vector>
#include <cstring>


// Clean up the test environment

// Generator for RC_SettingsUpdate
namespace rc {
    template<>
    struct Arbitrary<RC_SettingsUpdate> {
        static Gen<RC_SettingsUpdate> arbitrary() {
            return gen::exec([](void) {
                RC_SettingsUpdate update;
                
                // Generate a random field name
                std::vector<std::string> fieldNames = {
                    "show_startup_message", 
                    "show_feedback_window", 
                    "show_plugin_ui", 
                    "manual_routing", 
                    "log_to_file", 
                    "start_suspended", 
                    "language"
                };
                
                std::string fieldName = *gen::elementOf(fieldNames);
                std::strncpy(update.field, fieldName.c_str(), sizeof(update.field) - 1);
                update.field[sizeof(update.field) - 1] = '\0';
                
                // Decide if it's a boolean or string setting
                if (fieldName == "language") {
                    update.type = STRING_SETTING;
                    
                    // Generate a random language code
                    std::vector<std::string> languages = {"en", "de", "fr", "es", "it"};
                    std::string lang = *gen::elementOf(languages);
                    std::strncpy(update.value.string_value, lang.c_str(), sizeof(update.value.string_value) - 1);
                    update.value.string_value[sizeof(update.value.string_value) - 1] = '\0';
                } else {
                    update.type = BOOL_SETTING;
                    update.value.bool_value = *gen::arbitrary<bool>();
                }
                
                return update;
            });
        }
    };
}

extern "C" bool rc_run_settings_tests() {
    // Create the test environment
    RC_TestEnvironment env;
    env.zig_env = rc_initialize_zig_environment();

    if (!env.zig_env) {
        return false;
    }

    try {
        // Run the state machine test

        bool result = rc::check([&env](void) {  // Use reference to env
            // Model of settings state
            SettingsModel model;

            rc::state::check(model, 
                             env, 
                             rc::state::gen::execOneOfWithArgs<
                                OpenSettings,
                                SaveSettings,
                                CancelSettings,
                                ToggleSettings
                                // ScrollSettings,
                                // UpdateSettings
                             >());

            return true;
        });

        rc_cleanup_zig_environment(env.zig_env);

        return result;
    } catch (const std::exception& e) {
        // Handle exceptions
        if (env.zig_env != nullptr) {
            rc_cleanup_zig_environment(env.zig_env);
        }
        return false;
    }
}

// FIXME: implement the full RapidCheck state machine test for settings
// Run the settings tests
// extern "C" bool rc_run_settings_tests() {
//     // Minimal implementation that just returns true
//     return true;
// }
