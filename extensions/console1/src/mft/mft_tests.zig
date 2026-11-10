// Test aggregator for the MFT extension's pure-logic modules. The csurf and
// MIDI-out modules are excluded because their @cImport needs libc and the C++
// headers, which the plain test exe does not link; their logic paths depend on
// the REAPER runtime and are exercised in the app rather than in unit tests.
test {
    _ = @import("mft.zig");
    _ = @import("mft_state.zig");
    _ = @import("mft_mappings.zig");
    _ = @import("mft_map_store.zig");
    _ = @import("mft_fx.zig");
    _ = @import("mft_feedback.zig");
    _ = @import("mft_push.zig");
    _ = @import("mft_auto.zig");
    _ = @import("mft_port.zig");
    _ = @import("mft_fxsel.zig");
    _ = @import("mft_presets.zig");
    _ = @import("mft_settings_rows.zig");
    _ = @import("mft_order.zig");
    _ = @import("mft_actions.zig");
    _ = @import("mft_wizard.zig");
    _ = @import("mft_imgui.zig");
    _ = @import("mft_transport.zig");
    _ = @import("mft_preferences.zig");
    _ = @import("mft_settings.zig");
    _ = @import("mft_plugin_list.zig");
    _ = @import("mft_icons.zig");
    _ = @import("mft_colors.zig");
    _ = @import("mft_device.zig");
    // How the surface finds its MIDI devices again, which the console surface shares.
    _ = @import("midi_device_names");
}
