// This struct defines the data the UI library needs to render. The host
// assembles it each frame from Globals fields and passes it to the UI lib.
// Because it only contains pointers into host-owned data (no copies), the
// assembly cost is negligible.
//
// This file intentionally avoids importing globals.zig, which is the root
// of the heavy transitive import graph (reaper.zig, fs_helpers.zig, etc.).

const imgui = @import("reaper_imgui");
const statemachine = @import("statemachine.zig");
const styles = @import("styles.zig");
const TranslationStore = @import("translations.zig").TranslationStore;
const SettingsPanel = @import("settings_panel.zig");
const FxMaps = @import("mappings_list.zig");
const Preferences = @import("settings.zig").Preferences;
const Theme = @import("theme/Theme.zig");
const fx_types = @import("fx_parser_types.zig");

pub const UiState = struct {
    state: *statemachine.State,
    translations: *TranslationStore,
    drwls_splitter: *imgui.DrawListSplitterPtr,
    mappings_list: *FxMaps,
    settings_panel: ?*SettingsPanel,
    preferences: *const Preferences,
    midi_connected: bool,
    // Because the host and UI lib each have their own copy of c1_theme.fonts
    // (they are separate compilation units), the host passes its font pointers
    // so the UI lib can set its copy before rendering.
    main_font: imgui.FontPtr,
    icon_font: imgui.FontPtr,
    // FX browser data — pointers into fx_parser module globals.
    fx_plugins_by_type: *fx_types.FxByType,
    fx_chains: *fx_types.Directory,
    track_templates: *fx_types.Directory,
    fx_tags: *fx_types.FxTags,
};
