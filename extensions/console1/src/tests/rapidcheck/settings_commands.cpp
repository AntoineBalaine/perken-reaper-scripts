// src/rapidcheck/commands/settings_commands.cpp
#include "rapidcheck_wrapper.h"
#include "types/settings_types.h"
#include <string>
#include <vector>

// Model of settings state
class SettingsModel {
public:
    bool panel_open = false;
    int scroll_position = 0;
    std::unordered_map<std::string, bool> bool_settings;
    std::unordered_map<std::string, std::string> string_settings;
    
    SettingsModel() {
        // Initialize with default values
        bool_settings["show_startup_message"] = true;
        bool_settings["show_feedback_window"] = true;
        bool_settings["show_plugin_ui"] = true;
        bool_settings["manual_routing"] = false;
        bool_settings["log_to_file"] = false;
        bool_settings["start_suspended"] = false;
        string_settings["language"] = "en";
    }
};

// Open Settings Command
struct OpenSettings : rc::state::Command<SettingsModel, RC_TestEnvironment*> {
    void checkPreconditions(const SettingsModel& model) const override {
        RC_PRE(!model.panel_open);
    }

    void apply(SettingsModel& model) const override {
        model.panel_open = true;
    }

    void run(const SettingsModel& model, RC_TestEnvironment* env) const override {
        RC_SettingsAction action;
        action.action_type = RC_SettingsActionType::Open;
        
        rc_dispatch_settings_action(env, &action);
        
        RC_ASSERT(rc_is_settings_panel_open(env));
    }
};

// Save Settings Command
struct SaveSettings : rc::state::Command<SettingsModel, RC_TestEnvironment*> {
    void checkPreconditions(const SettingsModel& model) const override {
        RC_PRE(model.panel_open);
    }

    void apply(SettingsModel& model) const override {
        model.panel_open = false;
        // When saving, temp settings become permanent
    }

    void run(const SettingsModel& model, RC_TestEnvironment* env) const override {
        RC_SettingsAction action;
        action.action_type = RC_SettingsActionType::Save;
        
        rc_dispatch_settings_action(env, &action);
        
        RC_ASSERT(!rc_is_settings_panel_open(env));
        
        // Verify settings were saved
        // This would need to query the actual preferences
    }
};

// Cancel Settings Command
struct CancelSettings : rc::state::Command<SettingsModel, RC_TestEnvironment*> {
    void checkPreconditions(const SettingsModel& model) const override {
        RC_PRE(model.panel_open);
    }

    void apply(SettingsModel& model) const override {
        model.panel_open = false;
        // When canceling, temp settings are discarded
    }

    void run(const SettingsModel& model, RC_TestEnvironment* env) const override {
        RC_SettingsAction action;
        action.action_type = RC_SettingsActionType::Cancel;
        
        rc_dispatch_settings_action(env, &action);
        
        RC_ASSERT(!rc_is_settings_panel_open(env));
    }
};

// Scroll Settings Command
struct ScrollSettings : rc::state::Command<SettingsModel, RC_TestEnvironment*> {
    uint8_t position;
    
    explicit ScrollSettings(uint8_t pos) : position(pos) {}
    
    void checkPreconditions(const SettingsModel& model) const override {
        RC_PRE(model.panel_open);
    }

    void apply(SettingsModel& model) const override {
        model.scroll_position = position;
    }

    void run(const SettingsModel& model, RC_TestEnvironment* env) const override {
        RC_SettingsAction action;
        action.action_type = RC_SettingsActionType::Scroll;
        action.data.scroll_pos = position;
        
        rc_dispatch_settings_action(env, &action);
        
        RC_ASSERT(rc_get_settings_scroll_position(env) == position);
    }
};

// Toggle Settings Command
struct ToggleSettings : rc::state::Command<SettingsModel, RC_TestEnvironment*> {
    void checkPreconditions(const SettingsModel& model) const override {
        RC_PRE(model.panel_open);
    }

    void apply(SettingsModel& model) const override {
        // Toggle the setting at current scroll position
        // This would need knowledge of which setting is selected
    }

    void run(const SettingsModel& model, RC_TestEnvironment* env) const override {
        RC_SettingsAction action;
        action.action_type = RC_SettingsActionType::Toggle;
        
        rc_dispatch_settings_action(env, &action);
        
        // Verify toggle happened
    }
};

// Update Settings Command
struct UpdateSettings : rc::state::Command<SettingsModel, RC_TestEnvironment*> {
    RC_SettingsUpdate update;
    
    explicit UpdateSettings(const RC_SettingsUpdate& u) : update(u) {}
    
    void checkPreconditions(const SettingsModel& model) const override {
        RC_PRE(model.panel_open);
    }

    void apply(SettingsModel& model) const override {
        std::string field(update.field);
        if (update.type == BOOL_SETTING) {
            model.bool_settings[field] = update.value.bool_value;
        } else if (update.type == STRING_SETTING) {
            model.string_settings[field] = std::string(update.value.string_value);
        }
    }

    void run(const SettingsModel& model, RC_TestEnvironment* env) const override {
        RC_SettingsAction action;
        action.action_type = RC_SettingsActionType::Update;
        action.update = update;
        
        rc_dispatch_settings_action(env, &action);
        
        // Verify the setting was updated
        std::string field(update.field);
        if (update.type == BOOL_SETTING) {
            RC_ASSERT(rc_get_settings_bool(env, update.field) == update.value.bool_value);
        } else if (update.type == STRING_SETTING) {
            // Compare string value
            char buffer[128];
            rc_get_settings_string(env, update.field, buffer, sizeof(buffer));
            RC_ASSERT(std::string(buffer) == std::string(update.value.string_value));
        }
    }
};
